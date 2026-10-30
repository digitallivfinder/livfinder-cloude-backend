import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  client,
  ensureTestPassword,
  execute,
  findPortalOwner,
  findSecondPortalOwner,
  query,
  queryOne,
} from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * The lead workspace a client with no CRM runs from the portal: a manual lead walked through
 * the funnel, with notes, a document, a viewing and a follow-up, and another client locked out.
 */
const suffix = Date.now();
const email = `workspace-${suffix}@example.test`;
const pdf = Buffer.from("%PDF-1.4\n% lead document\n");
let owner;
let portal;
let leadId;
let contactIds = [];

const lead = async () => (await portal.get(`/v1/portal/leads/${leadId}`)).body.data;

beforeAll(async () => {
  await ensureTestPassword();
  owner = await findPortalOwner();
  portal = client();
  await portal.login(owner.email);
  const created = await portal.send("post", "/v1/portal/leads", {
    category: "realEstate",
    name: "Workspace Buyer",
    email,
    phone: "+971 50 123 4567",
    source: "walk_in",
    note: "Met at the sales office",
  });
  expect(created.status).toBe(201);
  leadId = created.body.data.id;
});

afterAll(async () => {
  const row = await queryOne("SELECT id, contact_id FROM leads WHERE public_id = ?", [leadId]);
  if (row) {
    const assets = await query("SELECT media_asset_id FROM documents WHERE owner_type = 'lead' AND owner_id = ?", [row.id]);
    await execute("DELETE FROM documents WHERE owner_type = 'lead' AND owner_id = ?", [row.id]);
    for (const asset of assets) await execute("DELETE FROM media_assets WHERE id = ?", [asset.media_asset_id]);
    await execute("DELETE FROM booking_status_history WHERE booking_id IN (SELECT id FROM bookings WHERE lead_id = ?)", [row.id]);
    await execute("DELETE FROM bookings WHERE lead_id = ?", [row.id]);
    await execute("DELETE FROM leads WHERE id = ?", [row.id]);
    contactIds = row.contact_id ? [row.contact_id] : [];
    for (const id of contactIds) await execute("DELETE FROM crm_contacts WHERE id = ?", [id]);
  }
  await closePool();
});

describe("a manual lead", () => {
  it("needs a phone or an email", async () => {
    const response = await portal.send("post", "/v1/portal/leads", { category: "realEstate", name: "No Contact" });
    expect(response.status).toBe(422);
  });

  it("starts at New with its note and a tidy phone number", async () => {
    const detail = await lead();
    expect(detail).toMatchObject({ status: "new", contactName: "Workspace Buyer", contactPhone: "+971501234567", categoryId: "realEstate" });
    expect(detail.notes.map((note) => note.body)).toEqual(["Met at the sales office"]);
  });

  it("appears in the account's list as a funnel step", async () => {
    const list = await portal.get("/v1/portal/leads", { search: email });
    expect(list.body.data.map((row) => [row.id, row.status])).toEqual([[leadId, "new"]]);
  });
});

describe("a manual lead in Developments", () => {
  it("is filed under the Developments category, with no project needed", async () => {
    const developer = await queryOne(
      `SELECT u.email FROM users u
         JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
         JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
         JOIN organizations o ON o.account_id = a.id AND o.deleted_at IS NULL
         JOIN account_category_access aca ON aca.account_id = a.id AND aca.category_id = 7 AND aca.status = 'approved'
        LIMIT 1`
    );
    const seller = client();
    await seller.login(developer.email);
    const created = await seller.send("post", "/v1/portal/leads", {
      category: "realEstateDevelopment",
      name: "Developments Buyer",
      phone: "+971500000002",
      source: "phone",
    });
    expect(created.status).toBe(201);
    try {
      expect(created.body.data.categoryId).toBe("realEstateDevelopment");
      const detail = await seller.get(`/v1/portal/leads/${created.body.data.id}`);
      expect(detail.body.data).toMatchObject({ categoryId: "realEstateDevelopment", listingId: null, status: "new" });
    } finally {
      const row = await queryOne("SELECT contact_id FROM leads WHERE public_id = ?", [created.body.data.id]);
      await execute("DELETE FROM leads WHERE public_id = ?", [created.body.data.id]);
      if (row?.contact_id) await execute("DELETE FROM crm_contacts WHERE id = ?", [row.contact_id]);
    }
  });
});

describe("the funnel", () => {
  it("moves a lead and records it", async () => {
    const response = await portal.send("patch", `/v1/portal/leads/${leadId}`, { step: "contacted" });
    expect(response.status).toBe(200);
    const detail = await lead();
    expect(detail.status).toBe("contacted");
    expect(detail.activity.map((entry) => entry.title)).toContain("Moved to Contacted");
    const history = await query(
      "SELECT h.to_stage_type FROM lead_stage_history h JOIN leads l ON l.id = h.lead_id WHERE l.public_id = ?",
      [leadId]
    );
    expect(history.map((row) => row.to_stage_type)).toEqual(["contacted"]);
  });

  it("refuses Lost without a reason", async () => {
    const response = await portal.send("patch", `/v1/portal/leads/${leadId}`, { step: "lost" });
    expect(response.status).toBe(422);
    expect((await lead()).status).toBe("contacted");
  });

  it("records the reason, closes the lead, and reopens it cleanly", async () => {
    await portal.send("patch", `/v1/portal/leads/${leadId}`, { step: "lost", lostReason: "budget", lostNote: "Over budget" });
    expect(await lead()).toMatchObject({ status: "lost", lostReason: "budget", lostNote: "Over budget" });
    const closed = await queryOne("SELECT status, closed_at FROM leads WHERE public_id = ?", [leadId]);
    expect(closed.status).toBe("lost");
    expect(closed.closed_at).not.toBeNull();

    await portal.send("patch", `/v1/portal/leads/${leadId}`, { step: "contacted" });
    expect(await lead()).toMatchObject({ status: "contacted", lostReason: null, lostNote: null });
  });
});

describe("notes and follow-ups", () => {
  it("adds and deletes a note", async () => {
    await portal.send("post", `/v1/portal/leads/${leadId}/notes`, { body: "Prefers evenings" });
    const note = (await lead()).notes.find((entry) => entry.body === "Prefers evenings");
    expect(note).toBeTruthy();
    await portal.send("delete", `/v1/portal/leads/${leadId}/notes/${note.id}`);
    expect((await lead()).notes.map((entry) => entry.body)).not.toContain("Prefers evenings");
  });

  it("sets and clears a follow-up", async () => {
    await portal.send("patch", `/v1/portal/leads/${leadId}`, { nextActionAt: "2030-01-01T09:00:00.000Z", nextActionNote: "Call back" });
    expect(await lead()).toMatchObject({ nextActionNote: "Call back" });
    await portal.send("patch", `/v1/portal/leads/${leadId}`, { nextActionAt: null });
    expect(await lead()).toMatchObject({ nextActionAt: null, nextActionNote: null });
  });
});

describe("documents", () => {
  const upload = (name, body) =>
    portal.agent
      .post(`/v1/portal/leads/${leadId}/documents`)
      .set("X-CSRF-Token", portal.csrfToken)
      .attach("file", body, name);

  it("refuses a file whose bytes do not match its name", async () => {
    const response = await upload("offer.pdf", Buffer.from("MZ not a pdf"));
    expect(response.status).toBe(415);
  });

  it("stores, returns and removes a private document", async () => {
    const created = await upload("Offer letter.pdf", pdf);
    expect(created.status).toBe(201);
    const document = (await lead()).documents[0];
    expect(document).toMatchObject({ title: "Offer letter.pdf", mimeType: "application/pdf" });

    const file = await portal.get(`/v1/portal/leads/${leadId}/documents/${document.id}`);
    expect(file.status).toBe(200);
    expect(file.headers["content-disposition"]).toContain("attachment");
    expect(file.headers["cache-control"]).toContain("no-store");

    await portal.send("delete", `/v1/portal/leads/${leadId}/documents/${document.id}`);
    expect((await lead()).documents).toEqual([]);
  });
});

describe("viewings", () => {
  it("adds a confirmed booking, moves the lead, and shows on Bookings", async () => {
    const start = new Date(Date.now() + 7 * 86400000).toISOString();
    const created = await portal.send("post", `/v1/portal/leads/${leadId}/viewings`, { scheduledStart: start, location: "Sales office" });
    expect(created.status).toBe(201);

    const detail = await lead();
    expect(detail.status).toBe("viewing");
    expect(detail.viewings[0]).toMatchObject({ status: "confirmed", location: "Sales office", type: "viewing" });

    const bookings = await portal.get("/v1/portal/bookings", { search: created.body.data.reference, status: "all" });
    expect(bookings.body.data.map((row) => [row.id, row.leadId])).toEqual([[created.body.data.id, leadId]]);
  });

  it("does not pull a lead back from further along", async () => {
    await portal.send("patch", `/v1/portal/leads/${leadId}`, { step: "negotiating" });
    await portal.send("post", `/v1/portal/leads/${leadId}/viewings`, { scheduledStart: new Date(Date.now() + 86400000).toISOString() });
    expect((await lead()).status).toBe("negotiating");
  });

  it("refuses a time in the past and a closed lead", async () => {
    const past = await portal.send("post", `/v1/portal/leads/${leadId}/viewings`, { scheduledStart: "2020-01-01T00:00:00.000Z" });
    expect(past.status).toBe(422);
    await portal.send("patch", `/v1/portal/leads/${leadId}`, { step: "won" });
    const closed = await portal.send("post", `/v1/portal/leads/${leadId}/viewings`, { scheduledStart: new Date(Date.now() + 86400000).toISOString() });
    expect(closed.status).toBe(400);
  });
});

describe("an individual seller", () => {
  it("gets a lead from a public enquiry, with no organization or CRM contact", async () => {
    const listing = await queryOne(
      `SELECT l.public_id, l.id, l.account_id FROM v_reachable_listings l
        JOIN account_members am ON am.account_id = l.account_id AND am.role = 'owner' AND am.status = 'active'
       WHERE l.organization_id IS NULL AND l.account_id IS NOT NULL LIMIT 1`
    );
    expect(listing).toBeTruthy();
    const visitor = `individual-${suffix}@example.test`;
    const sent = await client().send("post", "/v1/inquiries", {
      listingId: listing.public_id,
      name: "Individual Buyer",
      email: visitor,
      message: "Is this still for sale?",
      consent: true,
    });
    expect(sent.status).toBe(201);

    const row = await queryOne(
      "SELECT id, organization_id, account_id, contact_id FROM leads WHERE email = ? AND primary_listing_id = ?",
      [visitor, listing.id]
    );
    try {
      expect(row).toMatchObject({ organization_id: null, contact_id: null });
      expect(Number(row.account_id)).toBe(Number(listing.account_id));
    } finally {
      await execute("UPDATE inquiries SET lead_id = NULL WHERE email = ?", [visitor]);
      await execute("DELETE FROM inquiries WHERE email = ?", [visitor]);
      if (row) await execute("DELETE FROM leads WHERE id = ?", [row.id]);
      await execute("UPDATE listings SET inquiry_count = GREATEST(inquiry_count - 1, 0), updated_at = updated_at WHERE id = ?", [listing.id]);
    }
  });
});

describe("an older inquiry with no lead", () => {
  it("gets one the first time it is opened, then keeps it", async () => {
    const inquiry = await queryOne(
      `SELECT i.id, i.public_id, u.email AS owner_email
         FROM inquiries i
         JOIN account_members am ON am.account_id = i.account_id AND am.role = 'owner' AND am.status = 'active'
         JOIN users u ON u.id = am.user_id
        WHERE i.lead_id IS NULL AND i.deleted_at IS NULL
          AND NOT EXISTS (SELECT 1 FROM lead_inquiries li WHERE li.inquiry_id = i.id)
        LIMIT 1`
    );
    if (!inquiry) return;
    const seller = client();
    await seller.login(inquiry.owner_email);
    const first = await seller.send("post", `/v1/portal/inquiries/${inquiry.public_id}/lead`, {});
    try {
      expect(first.status).toBe(200);
      const second = await seller.send("post", `/v1/portal/inquiries/${inquiry.public_id}/lead`, {});
      expect(second.body.data.id).toBe(first.body.data.id);
    } finally {
      await execute("UPDATE inquiries SET lead_id = NULL WHERE id = ?", [inquiry.id]);
      if (first.body?.data?.id) await execute("DELETE FROM leads WHERE public_id = ?", [first.body.data.id]);
    }
  });
});

describe("another client", () => {
  it("cannot read or change this lead", async () => {
    const other = await findSecondPortalOwner(owner.account_id);
    const competitor = client();
    await competitor.login(other.email);
    expect((await competitor.get(`/v1/portal/leads/${leadId}`)).status).toBe(404);
    expect((await competitor.send("patch", `/v1/portal/leads/${leadId}`, { step: "won" })).status).toBe(404);
    expect((await competitor.send("post", `/v1/portal/leads/${leadId}/notes`, { body: "x" })).status).toBe(404);
  });
});
