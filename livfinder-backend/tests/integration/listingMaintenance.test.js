import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, adminEmail, cleanupListings, ensureTestPassword, execute, queryOne } from "../helpers/testApp.js";
import { expireDueListings, runListingMaintenance } from "../../src/modules/listings/listings.jobs.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Time-triggered maintenance and the allowance rule.
 *
 * - An active listing past `expires_at` used to stay `active` forever (there was no scheduler):
 *   still "live" in the owner's portal, still in the search projection and the sitemap, still
 *   holding an allowance slot and still counted by its agent and organisation.
 * - `accounts.listing_used` was only ever incremented, so nothing freed a slot.
 * - A counter bump (an enquiry) moved `listings.updated_at`, so the projection looked stale.
 */
const PASSWORD = "LivFinder!2026";
const created = [];

const owner = client();
const admin = client();
let account = null;
let id = null;

const usage = () => queryOne("SELECT listing_used FROM accounts WHERE id = ?", [account.account_id]).then((r) => Number(r.listing_used));
const row = () => queryOne("SELECT id, status, agent_id, organization_id FROM listings WHERE public_id = ?", [id]);
const agentActive = (agentId) => queryOne("SELECT active_listing_count n FROM agents WHERE id = ?", [agentId]).then((r) => Number(r?.n ?? 0));
const orgActive = (orgId) => queryOne("SELECT active_listing_count n FROM organizations WHERE id = ?", [orgId]).then((r) => Number(r?.n ?? 0));
const inProjection = async () => Boolean(await queryOne("SELECT 1 ok FROM listing_search s JOIN listings l ON l.id = s.listing_id WHERE l.public_id = ?", [id]));

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  account = await queryOne(
    `SELECT u.email, a.id AS account_id
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
       JOIN account_category_access aca ON aca.account_id = a.id AND aca.status = 'approved' AND aca.category_id = 2
      WHERE u.status = 'active' AND u.deleted_at IS NULL
      ORDER BY u.id LIMIT 1`
  );
  await owner.login(account.email, PASSWORD);
  await admin.login(await adminEmail("super_admin"), PASSWORD);
  await admin.stepUp();
});

afterAll(async () => {
  await cleanupListings(created);
  await closePool();
});

describe("allowance usage follows the listings", () => {
  it("creating a listing takes a slot", async () => {
    const before = await usage();
    const city = await queryOne("SELECT id FROM locations WHERE level = 'city' AND status = 'active' LIMIT 1");
    const response = await owner.send("post", "/v1/portal/listings", {
      category: "cars",
      categorySlug: "supercars",
      purpose: "sale",
      title: `QA maintenance ${Date.now()}`,
      description: "<p>Exercises expiry, allowance and counters.</p>",
      price: 300000,
      currency: "AED",
      locationId: `city:${city.id}`,
      detail: { modelYear: 2022 },
      status: "pending_review",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    id = response.body.data.id;
    created.push(id);
    expect(await usage()).toBe(before + 1);
  });

  it("approval keeps the slot and moves the agent and organisation active counters", async () => {
    const before = await usage();
    const listing = await row();
    const agentBefore = listing.agent_id ? await agentActive(listing.agent_id) : null;
    const orgBefore = listing.organization_id ? await orgActive(listing.organization_id) : null;
    const response = await admin.send("patch", `/v1/admin/listings/${id}/moderation`, { decision: "approve" });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(await usage()).toBe(before);
    if (listing.agent_id) expect(await agentActive(listing.agent_id)).toBe(agentBefore + 1);
    if (listing.organization_id) expect(await orgActive(listing.organization_id)).toBe(orgBefore + 1);
  });

  it("an enquiry is a counter bump, not a content change — the projection stays fresh", async () => {
    const response = await client().send("post", "/v1/inquiries", {
      listingId: id,
      name: "QA Maintenance Visitor",
      email: `qa-maintenance-${Date.now()}@example.com`,
      message: "Counter bump should not make the projection stale.",
      inquiryType: "general",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    const stale = await queryOne(
      "SELECT COUNT(*) n FROM listing_search s JOIN listings l ON l.id = s.listing_id WHERE l.public_id = ? AND s.source_updated_at < l.updated_at",
      [id]
    );
    expect(Number(stale.n)).toBe(0);
    await execute("DELETE FROM crm_contacts WHERE primary_email_normalized LIKE 'qa-maintenance-%@example.com'");
  });
});

describe("expiry", () => {
  it("an active listing past its end date is expired by the sweep: off search, slot freed, counters moved", async () => {
    const listing = await row();
    expect(listing.status).toBe("active");
    expect(await inProjection()).toBe(true);
    const usageBefore = await usage();
    const agentBefore = listing.agent_id ? await agentActive(listing.agent_id) : null;
    const orgBefore = listing.organization_id ? await orgActive(listing.organization_id) : null;

    await execute("UPDATE listings SET expires_at = DATE_SUB(NOW(3), INTERVAL 1 MINUTE) WHERE id = ?", [listing.id]);
    const count = await expireDueListings();
    expect(count).toBeGreaterThanOrEqual(1);

    expect((await row()).status).toBe("expired");
    expect(await inProjection()).toBe(false);
    expect((await client().get(`/v1/public/listings/${id}`)).status).toBe(404);
    expect(await usage()).toBe(usageBefore - 1);
    if (listing.agent_id) expect(await agentActive(listing.agent_id)).toBe(agentBefore - 1);
    if (listing.organization_id) expect(await orgActive(listing.organization_id)).toBe(orgBefore - 1);
    const history = await queryOne(
      "SELECT from_status, to_status FROM listing_status_history WHERE listing_id = ? ORDER BY id DESC LIMIT 1",
      [listing.id]
    );
    expect(history).toMatchObject({ from_status: "active", to_status: "expired" });
  });

  it("the owner sees it as expired in the portal, and renewing it takes the slot back", async () => {
    const own = await owner.get(`/v1/portal/listings/${id}`);
    expect(own.body.data.status).toBe("expired");
    const before = await usage();
    const renew = await owner.send("patch", `/v1/portal/listings/${id}/status`, { status: "pending_review" });
    expect(renew.status, JSON.stringify(renew.body)).toBe(200);
    expect(await usage()).toBe(before + 1);
  });

  it("archiving frees the slot", async () => {
    const before = await usage();
    const archived = await owner.send("delete", `/v1/portal/listings/${id}`, { reason: "QA" });
    expect(archived.status, JSON.stringify(archived.body)).toBe(200);
    expect(await usage()).toBe(before - 1);
  });

  it("a full maintenance run leaves no drift behind", async () => {
    await runListingMaintenance();
    const drift = await queryOne(
      `SELECT
         (SELECT COUNT(*) FROM listing_search s WHERE s.listing_id NOT IN (SELECT id FROM v_public_listings)) AS projection,
         (SELECT COUNT(*) FROM sitemap_entries s WHERE s.entity_type = 'listing' AND s.entity_id NOT IN (SELECT id FROM v_public_listings)) AS sitemap,
         (SELECT COUNT(*) FROM listings WHERE status = 'active' AND deleted_at IS NULL AND expires_at <= NOW(3)) AS overdue`
    );
    expect(drift).toEqual({ projection: 0, sitemap: 0, overdue: 0 });
  });
});
