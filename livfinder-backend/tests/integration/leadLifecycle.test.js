import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, adminEmail, cleanupListings, ensureTestPassword, execute, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * The real end-to-end lifecycle, walked for every category:
 *
 *   1. Create a listing as its portal owner (pending review).
 *   2. Admin sees it and moderates it (approve with a reason logged; a
 *      separate case proves reject-with-reason too).
 *   3. An approved listing is live on the public site.
 *   4. A visitor submits a public enquiry against it — no session, exactly
 *      the marketplace contact form's own request.
 *   5. Admin's Leads module shows the enquiry as a real lead, with an
 *      activity entry — not the seed-only fixture data it used to be limited
 *      to (see `adminCrm.test.js`; migration 0049 is what makes this possible
 *      at all — before it, a public enquiry never became an admin lead).
 *   6. The listing's owner sees the SAME enquiry in their own portal Leads
 *      page (`/v1/portal/inquiries` — one physical row, two views).
 *   7. The owner processes it (status change + a note), exactly the portal
 *      action a lister takes.
 */
const PASSWORD = "LivFinder!2026";
const createdListings = [];
// Each enquiry creates a real `crm_contacts` row too (deduped by email, and every
// run uses a fresh email) — removed in afterAll so runs don't pile up in the dev DB.
const visitorEmails = [];

async function ownerForCategory(categoryId) {
  return queryOne(
    `SELECT u.email, a.id AS account_id
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
       JOIN account_category_access aca ON aca.account_id = a.id AND aca.status = 'approved' AND aca.category_id = ?
      WHERE u.status = 'active' AND u.deleted_at IS NULL
      ORDER BY u.id LIMIT 1`,
    [categoryId]
  );
}

/**
 * A different client with access to the same category — a competitor in the same marketplace
 * is the case that matters for "a lead only lands on its own client's portal".
 */
async function otherClientForCategory(categoryId, excludeAccountId) {
  return queryOne(
    `SELECT u.email, a.id AS account_id
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
       JOIN account_category_access aca ON aca.account_id = a.id AND aca.status = 'approved' AND aca.category_id = ?
      WHERE u.status = 'active' AND u.deleted_at IS NULL AND a.id <> ?
      ORDER BY u.id LIMIT 1`,
    [categoryId, excludeAccountId]
  );
}

async function locationRef(level) {
  const row = await queryOne(
    `SELECT id FROM locations WHERE level = ? AND status = 'active'${level === "community" ? " AND active_listing_count > 0" : ""} LIMIT 1`,
    [level]
  );
  return `${level}:${row.id}`;
}

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
});

afterAll(async () => {
  // cleanupListings deletes each listing's leads before the listing itself — the
  // FK is ON DELETE SET NULL, so deleting only the listing left property-less
  // leads behind, and the admin Leads page crashed on them.
  await cleanupListings(createdListings);
  for (const email of visitorEmails) {
    await execute("DELETE FROM crm_contacts WHERE primary_email_normalized = ?", [email.toLowerCase()]);
  }
  await closePool();
});

const CASES = [
  // `check`: one category-specific field that must reach admin and the public page unchanged.
  { category: "real-estate", categoryId: 1, categorySlug: "apartments", locationLevel: "community", detail: { bedrooms: 2, bathrooms: 2, builtAreaSqft: 1200 }, check: ["bedrooms", 2] },
  { category: "cars", categoryId: 2, categorySlug: "supercars", locationLevel: "city", detail: { modelYear: 2023, transmission: "automatic" }, check: ["modelYear", 2023] },
  { category: "yachts", categoryId: 3, categorySlug: "motor-yachts", locationLevel: "city", detail: { buildYear: 2021 }, check: ["buildYear", 2021] },
  { category: "jets", categoryId: 4, categorySlug: "light-jets", locationLevel: "city", detail: { yearBuilt: 2019 }, check: ["yearBuilt", 2019] },
  { category: "helicopters", categoryId: 5, categorySlug: "light-helicopter", locationLevel: "city", detail: { yearBuilt: 2020 }, check: ["yearBuilt", 2020] },
  { category: "watches", categoryId: 6, categorySlug: "dive-watches", locationLevel: "city", detail: { yearOfProduction: 2022 }, check: ["yearOfProduction", 2022] },
];

describe.each(CASES)("real lead lifecycle — $category", ({ category, categoryId, categorySlug, locationLevel, detail, check }) => {
  const portal = client();
  const admin = client();
  let listingPublicId = null;
  let listingId = null;
  let ownerAccountId = null;
  let inquiryId = null;
  const [checkField, checkValue] = check;

  beforeAll(async () => {
    const owner = await ownerForCategory(categoryId);
    expect(owner, `a seeded owner with ${category} access`).toBeTruthy();
    ownerAccountId = owner.account_id;
    await portal.login(owner.email, PASSWORD);
    await admin.login(await adminEmail("super_admin"), PASSWORD);
    await admin.stepUp();
  });

  it("1. the owner creates a listing from the portal", async () => {
    const response = await portal.send("post", "/v1/portal/listings", {
      category,
      categorySlug,
      purpose: category === "yachts" ? "charter" : "sale",
      title: `QA lifecycle ${category} ${Date.now()}`,
      description: `<p>Created by the lead-lifecycle QA suite for ${category}.</p>`,
      price: 500000,
      currency: category === "watches" ? "USD" : "AED",
      locationId: await locationRef(locationLevel),
      detail,
      status: "pending_review",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    listingPublicId = response.body.data.id;
    listingId = response.body.data.dbId ?? (await queryOne("SELECT id FROM listings WHERE public_id = ?", [listingPublicId])).id;
    createdListings.push(listingPublicId);
    // Submitted at creation, so it is in moderation — this used to be written as 'not_submitted'
    // and the portal showed "Moderation: Not submitted" on a listing in the admin queue.
    const row = await queryOne("SELECT status, moderation_status FROM listings WHERE public_id = ?", [listingPublicId]);
    expect(row).toEqual({ status: "pending_review", moderation_status: "pending" });
  });

  it("2. admin sees it pending and approves it with an audit trail", async () => {
    const list = await admin.get("/v1/admin/listings", { category, status: "pending", pageSize: 50 });
    expect(list.status).toBe(200);
    expect(list.body.items.some((item) => item.id === listingPublicId), "listing appears in the pending queue").toBe(true);

    const approve = await admin.send("patch", `/v1/admin/listings/${listingPublicId}/moderation`, { decision: "approve" });
    expect(approve.status, JSON.stringify(approve.body)).toBe(200);

    const detailResponse = await admin.get(`/v1/admin/listings/${listingPublicId}`);
    expect(detailResponse.body.data.moderationStatus).toBe("approved");
    expect(detailResponse.body.data.status).toBe("active");

    // With all the data: what the owner submitted is what the admin reviews.
    const data = detailResponse.body.data;
    expect(data.listingType).toBe(category);
    expect(data.title).toContain(`QA lifecycle ${category}`);
    expect(data.price).toEqual({ amount: 500000, currency: category === "watches" ? "USD" : "AED" });
    expect(data[checkField], `${category} ${checkField} in the admin detail`).toBe(checkValue);
  });

  it("3. the approved listing is live on the public site", async () => {
    const response = await client().get(`/v1/public/listings/${listingPublicId}`);
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(response.body.data.title).toContain(category);
    // The public page shows the same data the admin approved.
    expect(response.body.data.price).toEqual({ amount: 500000, currency: category === "watches" ? "USD" : "AED" });
    expect(response.body.data[checkField], `${category} ${checkField} on the public page`).toBe(checkValue);
  });

  it("4. a website visitor submits a real enquiry against it, with no session", async () => {
    const anonymous = client(); // never logs in — this is the public contact form
    const email = `qa-visitor-${category}-${Date.now()}@example.com`;
    visitorEmails.push(email);
    const response = await anonymous.send("post", "/v1/inquiries", {
      listingId: listingPublicId,
      name: "QA Visitor",
      email,
      phone: "+971500000099",
      message: `Is this ${category} listing still available? Real QA lifecycle enquiry.`,
      inquiryType: "general",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect(response.body.data.submitted).toBe(true);
  });

  it("5. the enquiry is now a real admin lead, with an activity entry", async () => {
    const leads = await admin.get("/v1/admin/leads", { category, pageSize: 50, sort: "newest" });
    expect(leads.status).toBe(200);
    const lead = leads.body.items.find((item) => item.property?.id === listingPublicId || item.propertyId === listingPublicId);
    expect(lead, `a lead for ${category} listing ${listingPublicId} among ${leads.body.items.length} leads`).toBeTruthy();
    expect(lead.contact?.name || `${lead.contact?.firstName} ${lead.contact?.lastName}`).toContain("QA Visitor");

    const detailResponse = await admin.get(`/v1/admin/leads/${lead.id}`);
    expect(detailResponse.status).toBe(200);
    expect(detailResponse.body.data.activities.length).toBeGreaterThan(0);
    expect(detailResponse.body.data.activities[0].body).toContain("Real QA lifecycle enquiry");
  });

  it("6. the listing's own owner sees the same enquiry in their portal Leads page", async () => {
    const response = await portal.get("/v1/portal/inquiries", { pageSize: 50 });
    expect(response.status).toBe(200);
    const inquiry = response.body.data.find((row) => row.listing?.id === listingPublicId || row.listingId === listingPublicId);
    expect(inquiry, `the portal owner's own enquiry for this listing among ${response.body.data.length}`).toBeTruthy();
    inquiryId = inquiry.id;
  });

  it("7. the owner processes the enquiry — status change and a note", async () => {
    const response = await portal.get("/v1/portal/inquiries", { pageSize: 50 });
    const inquiry = response.body.data.find((row) => row.listing?.id === listingPublicId || row.listingId === listingPublicId);
    const update = await portal.send("patch", `/v1/portal/inquiries/${inquiry.id}`, {
      status: "contacted",
      note: "Called the visitor back — QA lifecycle test.",
    });
    expect(update.status, JSON.stringify(update.body)).toBe(200);

    const after = await portal.get("/v1/portal/inquiries", { pageSize: 50 });
    const updated = after.body.data.find((row) => row.id === inquiry.id);
    expect(updated.status).toBe("contacted");
  });

  it("8. no other client can see, process or open it — the lead lands only on its own portal", async () => {
    const other = await otherClientForCategory(categoryId, ownerAccountId);
    expect(other, `another client with ${category} access`).toBeTruthy();
    expect(other.account_id).not.toBe(ownerAccountId);
    const competitor = client();
    await competitor.login(other.email, PASSWORD);

    const theirs = await competitor.get("/v1/portal/inquiries", { pageSize: 100 });
    expect(theirs.status).toBe(200);
    const leaked = theirs.body.data.filter(
      (row) => row.id === inquiryId || row.listing?.id === listingPublicId || row.listingId === listingPublicId
    );
    expect(leaked, `${category} enquiry visible to another client`).toEqual([]);

    const process = await competitor.send("patch", `/v1/portal/inquiries/${inquiryId}`, { status: "contacted" });
    expect(process.status).toBe(404);

    const listing = await competitor.get(`/v1/portal/listings/${listingPublicId}`);
    expect(listing.status).toBe(404);

    // Admin files the lead under its own category only.
    const otherCategory = category === "watches" ? "cars" : "watches";
    const wrongCategory = await admin.get("/v1/admin/leads", { category: otherCategory, pageSize: 50, sort: "newest" });
    expect(wrongCategory.body.items.some((item) => item.property?.id === listingPublicId)).toBe(false);
  });
});

/**
 * The reject path, once per listing-bearing category — a reason is required,
 * is stored, and the listing is no longer publicly reachable.
 */
describe.each(CASES)("real reject-with-reason lifecycle — $category", ({ category, categoryId, categorySlug, locationLevel, detail }) => {
  const portal = client();
  const admin = client();
  let listingPublicId = null;

  beforeAll(async () => {
    const owner = await ownerForCategory(categoryId);
    await portal.login(owner.email, PASSWORD);
    await admin.login(await adminEmail("super_admin"), PASSWORD);
    await admin.stepUp();

    const response = await portal.send("post", "/v1/portal/listings", {
      category,
      categorySlug,
      purpose: category === "yachts" ? "charter" : "sale",
      title: `QA reject ${category} ${Date.now()}`,
      description: `<p>Created to exercise the reject path for ${category}.</p>`,
      price: 500000,
      currency: category === "watches" ? "USD" : "AED",
      locationId: await locationRef(locationLevel),
      detail,
      status: "pending_review",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    listingPublicId = response.body.data.id;
    createdListings.push(listingPublicId);
  });

  it("refuses a reject without a reason", async () => {
    const response = await admin.send("patch", `/v1/admin/listings/${listingPublicId}/moderation`, { decision: "reject" });
    expect(response.status).toBe(422);
  });

  it("rejects with a reason, and the listing is no longer public", async () => {
    const reject = await admin.send("patch", `/v1/admin/listings/${listingPublicId}/moderation`, {
      decision: "reject",
      reason: "Photos do not match the description — please resubmit.",
    });
    expect(reject.status, JSON.stringify(reject.body)).toBe(200);

    const detailResponse = await admin.get(`/v1/admin/listings/${listingPublicId}`);
    expect(detailResponse.body.data.moderationStatus).toBe("rejected");

    const publicResponse = await client().get(`/v1/public/listings/${listingPublicId}`);
    expect(publicResponse.status).toBe(404);
  });

  it("the owner can see why their own listing was rejected", async () => {
    const ownListing = await portal.get(`/v1/portal/listings/${listingPublicId}`);
    expect(ownListing.status).toBe(200);
    expect(ownListing.body.data.moderationStatus).toBe("rejected");
    expect(ownListing.body.data.rejectionReason).toBe("Photos do not match the description — please resubmit.");
  });

  it("the reason is cleared once the listing is approved on resubmission", async () => {
    await admin.send("patch", `/v1/admin/listings/${listingPublicId}/moderation`, { decision: "approve" });
    const ownListing = await portal.get(`/v1/portal/listings/${listingPublicId}`);
    expect(ownListing.body.data.moderationStatus).toBe("approved");
    expect(ownListing.body.data.rejectionReason).toBeNull();
  });
});
