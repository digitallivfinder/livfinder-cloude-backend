import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, adminEmail, ensureTestPassword, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Admin lead and contact detail — against the real database.
 *
 * Found during a full go-live review: `getAdminLead` and `getAdminContact` both
 * queried `activities`/`lead_stage_history` columns that do not exist
 * (`subject`, `created_by_user_id`, `h.changed_at`, `h.note`) and
 * `leadFilterOptions` queried `crm_contacts.email`, which is `primary_email`.
 * Every one of these was wrapped in `.catch(() => [])`, so the request never
 * failed — it just silently returned an empty Activity timeline, an empty
 * Stage History, and an empty "Contact" filter dropdown, on every lead and
 * every contact, in every one of the seven categories, on live.
 */
const PASSWORD = "LivFinder!2026";
const admin = client();

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  await admin.login(await adminEmail("super_admin"), PASSWORD);
  await admin.stepUp();
});

afterAll(async () => {
  await closePool();
});

describe("lead detail", () => {
  it("returns a non-empty activity timeline for a lead with real activity", async () => {
    const row = await queryOne(
      `SELECT l.public_id FROM activities a
         JOIN leads l ON l.id = a.lead_id
        WHERE a.lead_id IS NOT NULL AND a.deleted_at IS NULL
        GROUP BY a.lead_id, l.public_id
        ORDER BY COUNT(*) DESC LIMIT 1`
    );
    expect(row, "a seeded lead with activity").toBeTruthy();

    const response = await admin.get(`/v1/admin/leads/${row.public_id}`);
    expect(response.status).toBe(200);
    expect(response.body.data.activities.length).toBeGreaterThan(0);
    for (const activity of response.body.data.activities) {
      expect(activity.id).toBeTruthy();
      // `title` came from the non-existent `subject` column before the fix —
      // it silently read undefined for every row.
      expect(activity.title, JSON.stringify(activity)).toBeTruthy();
      expect(activity.at).toBeTruthy();
    }
  });

  it("returns a non-empty stage history for a lead that has moved stages", async () => {
    const row = await queryOne(
      `SELECT l.public_id FROM lead_stage_history h
         JOIN leads l ON l.id = h.lead_id
        GROUP BY h.lead_id, l.public_id
        ORDER BY COUNT(*) DESC LIMIT 1`
    );
    expect(row, "a seeded lead with stage history").toBeTruthy();

    const response = await admin.get(`/v1/admin/leads/${row.public_id}`);
    expect(response.status).toBe(200);
    expect(response.body.data.stageHistory.length).toBeGreaterThan(0);
    for (const entry of response.body.data.stageHistory) {
      expect(entry.to, JSON.stringify(entry)).toBeTruthy();
      // `at` came from the non-existent `h.changed_at` column before the fix.
      expect(entry.at, JSON.stringify(entry)).toBeTruthy();
    }
  });

  it("works the same way for a lead in every category", async () => {
    for (const category of ["real-estate", "cars", "yachts", "jets", "helicopters", "watches"]) {
      const list = await admin.get("/v1/admin/leads", { category, pageSize: 1 });
      const leadId = list.body.items[0]?.id;
      if (!leadId) continue; // category has no seeded leads locally; not this test's concern
      const response = await admin.get(`/v1/admin/leads/${leadId}`);
      expect(response.status, category).toBe(200);
      expect(Array.isArray(response.body.data.activities), category).toBe(true);
      expect(Array.isArray(response.body.data.stageHistory), category).toBe(true);
    }
  });
});

describe("contact detail", () => {
  it("returns a non-empty activity timeline for a contact with real activity", async () => {
    const row = await queryOne(
      `SELECT c.public_id FROM activities a
         JOIN crm_contacts c ON c.id = a.contact_id
        WHERE a.contact_id IS NOT NULL AND a.deleted_at IS NULL AND c.deleted_at IS NULL
        GROUP BY a.contact_id, c.public_id
        ORDER BY COUNT(*) DESC LIMIT 1`
    );
    expect(row, "a seeded contact with activity").toBeTruthy();

    const response = await admin.get(`/v1/admin/contacts/${row.public_id}`);
    expect(response.status).toBe(200);
    expect(response.body.data.activities.length).toBeGreaterThan(0);
    for (const activity of response.body.data.activities) {
      expect(activity.title, JSON.stringify(activity)).toBeTruthy();
    }
  });
});

describe("leads filter options", () => {
  it("the Contact picker is not silently empty", async () => {
    const response = await admin.get("/v1/admin/leads", { pageSize: 1 });
    expect(response.status).toBe(200);
    const contacts = response.body.options?.contacts ?? [];
    expect(contacts.length).toBeGreaterThan(0);
    // Every option resolves to a real name, not undefined from a dead `email` column.
    for (const option of contacts.slice(0, 20)) {
      expect(option.label, JSON.stringify(option)).toBeTruthy();
    }
  });
});
