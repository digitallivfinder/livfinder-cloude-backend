import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, adminEmail, cleanupProjects, ensureTestPassword, execute, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * The Real Estate Developments workflow, end to end — the same bar as the six listing
 * categories in `leadLifecycle.test.js`:
 *
 *   1. A developer submits a development from the client portal (pending review).
 *   2. Admin sees it pending, with exactly the data submitted.
 *   3. Rejecting requires a reason; the developer sees it; resubmitting clears it.
 *   4. Admin publishes it and it is live on the public site.
 *   5. A website visitor enquires, and it becomes an admin lead under Developments.
 *   6. The owning developer sees it — as an enquiry and as a CRM lead — and processes it.
 *   7. A competing developer sees none of it; an account without the category cannot submit.
 *
 * Before this, the portal had no development endpoint (its form only previewed), a
 * development enquiry never became an admin lead, and no developer held the category.
 */
const PASSWORD = "LivFinder!2026";
const created = [];
const visitorEmails = [];

/** An owner of a developer organization that owns developments and holds the category. */
async function developerOwner(excludeAccountId = 0) {
  return queryOne(
    `SELECT u.email, a.id AS account_id, o.id AS organization_id
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
       JOIN organizations o ON o.account_id = a.id AND o.deleted_at IS NULL
       JOIN account_category_access aca ON aca.account_id = a.id AND aca.category_id = 7 AND aca.status = 'approved'
      WHERE u.status = 'active' AND u.deleted_at IS NULL AND a.id <> ?
        AND EXISTS (SELECT 1 FROM projects p WHERE p.organization_id = o.id AND p.deleted_at IS NULL)
      ORDER BY u.id LIMIT 1`,
    [excludeAccountId]
  );
}

/** An organization owner who has NOT been approved for Developments. */
async function ownerWithoutDevelopments() {
  return queryOne(
    `SELECT u.email
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
       JOIN organizations o ON o.account_id = a.id AND o.deleted_at IS NULL
      WHERE u.status = 'active' AND u.deleted_at IS NULL
        AND NOT EXISTS (SELECT 1 FROM account_category_access aca
                         WHERE aca.account_id = a.id AND aca.category_id = 7 AND aca.status = 'approved')
      ORDER BY u.id LIMIT 1`
  );
}

const developer = client();
const competitor = client();
const admin = client();
let owner = null;
let rival = null;
let publicId = null;
let inquiryId = null;
let name = null;
let communityId = null;

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  owner = await developerOwner();
  expect(owner, "a developer owner with Developments access").toBeTruthy();
  rival = await developerOwner(owner.account_id);
  expect(rival, "a second, competing developer").toBeTruthy();
  await developer.login(owner.email, PASSWORD);
  await competitor.login(rival.email, PASSWORD);
  await admin.login(await adminEmail("super_admin"), PASSWORD);
  await admin.stepUp();

  communityId = (
    await queryOne("SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1")
  ).id;
});

afterAll(async () => {
  await cleanupProjects(created);
  for (const email of visitorEmails) {
    await execute("DELETE FROM crm_contacts WHERE primary_email_normalized = ?", [email.toLowerCase()]);
  }
  await closePool();
});

describe("real development lifecycle", () => {
  it("1. the developer submits a development from the portal", async () => {
    name = `QA Development ${Date.now()}`;
    const response = await developer.send("post", "/v1/portal/developments", {
      name,
      tagline: "Real QA development lifecycle",
      description: "<p>Created by the development lifecycle QA suite.</p>",
      projectType: "residential",
      status: "announced",
      // Ignored: the brand is the organization's own, never the client's pick.
      developerId: "emaar",
      minPrice: 1500000,
      maxPrice: 4500000,
      currencyCode: "AED",
      totalUnits: 120,
      availableUnits: 80,
      communityId,
      handoverDate: "2028-12-31",
      amenities: ["Swimming pool", "Gym"],
      unitTypes: [{ unitType: "apartment", name: "1BR Apartment", bedrooms: 1, startingPrice: 1500000, availableUnits: 40 }],
      paymentPlans: [
        {
          name: "Payment plan",
          planType: "custom",
          milestones: [
            { name: "Booking", percentage: 20 },
            { name: "On handover", percentage: 80 },
          ],
        },
      ],
      submit: true,
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    publicId = response.body.data.id;
    created.push(publicId);
    // The portal's listing vocabulary: badge on `rawStatus`, tab on `status`.
    expect(response.body.data).toMatchObject({
      moderationStatus: "pending",
      rawStatus: "pending_review",
      status: "pending",
      title: name,
    });

    const owned = await queryOne(
      `SELECT p.organization_id, p.is_publicly_visible, b.public_id AS brand
         FROM projects p LEFT JOIN brands b ON b.id = p.developer_brand_id WHERE p.public_id = ?`,
      [publicId]
    );
    const orgBrand = await queryOne(
      `SELECT b.public_id FROM projects p JOIN brands b ON b.id = p.developer_brand_id
        WHERE p.organization_id = ? AND p.public_id <> ? AND p.deleted_at IS NULL
        GROUP BY b.id, b.public_id ORDER BY COUNT(*) DESC, b.id ASC LIMIT 1`,
      [owner.organization_id, publicId]
    );
    expect(owned).toEqual({ organization_id: owner.organization_id, is_publicly_visible: 0, brand: orgBrand.public_id });

    const mine = await developer.get("/v1/portal/developments");
    expect(mine.body.data.some((item) => item.id === publicId)).toBe(true);
    const pendingTab = await developer.get("/v1/portal/developments", { status: "pending", pageSize: 100 });
    expect(pendingTab.body.data.map((item) => item.id)).toContain(publicId);
    expect(pendingTab.body.data.every((item) => item.status === "pending")).toBe(true);
    expect(pendingTab.body.counts.pending).toBeGreaterThanOrEqual(1);
    expect(pendingTab.body.pageInfo.total).toBe(pendingTab.body.counts.pending);
    const searched = await developer.get("/v1/portal/developments", { search: name });
    expect(searched.body.data.map((item) => item.id)).toEqual([publicId]);
    const soldTab = await developer.get("/v1/portal/developments", { status: "soldOrRented" });
    expect(soldTab.body.data).toEqual([]);
  });

  it("1b. the developer's own detail round-trips units, payment plan, amenities and location", async () => {
    const detail = (await developer.get(`/v1/portal/developments/${publicId}`)).body.data;
    expect(detail.unitTypes).toHaveLength(1);
    expect(detail.unitTypes[0]).toMatchObject({ type: "apartment", name: "1BR Apartment", bedrooms: 1, availableUnits: 40 });
    expect(detail.paymentPlans[0].milestones.map((m) => [m.name, m.percentage])).toEqual([
      ["Booking", 20],
      ["On handover", 80],
    ]);
    expect(detail.amenities).toEqual(["Swimming pool", "Gym"]);
    expect(detail.locationIds.community).toBe(String(communityId));
    expect(detail.priceMax).toBe(4500000);
  });

  it("2. admin sees it pending, with exactly the data submitted", async () => {
    const pending = await admin.get("/v1/admin/developments", { status: "pending", pageSize: 100 });
    expect(pending.status).toBe(200);
    expect(pending.body.items.some((item) => item.id === publicId), "in the pending queue").toBe(true);

    const detail = (await admin.get(`/v1/admin/developments/${publicId}`)).body.data;
    expect(detail.name).toBe(name);
    expect(detail.startingPrice).toEqual({ amount: 1500000, currency: "AED" });
    expect(detail.totalUnits).toBe(120);
    expect(detail.availableUnits).toBe(80);
    expect(detail.moderationStatus).toBe("pending");
  });

  it("3. it is not public before approval", async () => {
    expect((await client().get(`/v1/public/projects/${publicId}`)).status).toBe(404);
  });

  it("4. admin cannot reject without a reason", async () => {
    const response = await admin.send("patch", `/v1/admin/developments/${publicId}`, { name, moderationStatus: "rejected" });
    expect(response.status).toBe(422);
  });

  it("5. rejects with a reason — the developer sees why, and it stays off the site", async () => {
    const reason = "Payment plan does not total 100% — please correct and resubmit.";
    const response = await admin.send("patch", `/v1/admin/developments/${publicId}`, {
      name,
      moderationStatus: "rejected",
      rejectionReason: reason,
    });
    expect(response.status, JSON.stringify(response.body)).toBe(200);

    const own = await developer.get(`/v1/portal/developments/${publicId}`);
    expect(own.body.data).toMatchObject({ moderationStatus: "rejected", status: "rejected", rejectionReason: reason });
    expect((await client().get(`/v1/public/projects/${publicId}`)).status).toBe(404);
  });

  it("6. the developer resubmits — back in the queue, the old reason cleared", async () => {
    const response = await developer.send("patch", `/v1/portal/developments/${publicId}`, { availableUnits: 75, submit: true });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(response.body.data).toMatchObject({ moderationStatus: "pending", rejectionReason: null, availableUnits: 75 });
  });

  it("6b. the developer cannot attach another account's file", async () => {
    const foreign = await queryOne(
      `SELECT a.public_id FROM media_assets a
        WHERE a.deleted_at IS NULL AND (a.account_id IS NULL OR a.account_id <> ?)
          AND NOT EXISTS (SELECT 1 FROM media_attachments ma JOIN projects p ON p.id = ma.attachable_id
                           WHERE ma.media_asset_id = a.id AND ma.attachable_type = 'project' AND p.public_id = ?)
        LIMIT 1`,
      [owner.account_id, publicId]
    );
    expect(foreign, "some other account's media asset").toBeTruthy();
    const response = await developer.send("patch", `/v1/portal/developments/${publicId}`, {
      gallery: [{ mediaAssetId: foreign.public_id, isPrimary: true }],
    });
    expect(response.status).toBe(422);
    const still = (await developer.get(`/v1/portal/developments/${publicId}`)).body.data;
    expect(still.moderationStatus).toBe("pending");
  });

  it("7. admin publishes it and it is live on the public site with the same data", async () => {
    const response = await admin.send("patch", `/v1/admin/developments/${publicId}`, { name, moderationStatus: "published" });
    expect(response.status, JSON.stringify(response.body)).toBe(200);

    const live = await client().get(`/v1/public/projects/${publicId}`);
    expect(live.status, JSON.stringify(live.body)).toBe(200);
    expect(JSON.stringify(live.body.data)).toContain(name);

    const own = await developer.get(`/v1/portal/developments/${publicId}`);
    expect(own.body.data).toMatchObject({ moderationStatus: "published", status: "active" });
    expect(own.body.data.publicUrl).toBeTruthy();
  });

  it("8. a website visitor enquires about it, with no session", async () => {
    const email = `qa-visitor-development-${Date.now()}@example.com`;
    visitorEmails.push(email);
    const response = await client().send("post", "/v1/inquiries", {
      projectId: publicId,
      name: "QA Visitor",
      email,
      phone: "+971500000098",
      message: "Is the payment plan still available? Real QA development enquiry.",
      inquiryType: "general",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
  });

  it("9. it is now an admin lead, filed under Developments, with the message", async () => {
    const leads = await admin.get("/v1/admin/leads", { category: "real-estate-developments", pageSize: 50, sort: "newest" });
    expect(leads.status).toBe(200);
    const lead = leads.body.items.find((item) => item.property?.id === publicId);
    expect(lead, `a Developments lead for ${publicId}`).toBeTruthy();
    expect(lead.property.title).toBe(name);
    expect(lead.contact?.name || `${lead.contact?.firstName} ${lead.contact?.lastName}`).toContain("QA Visitor");

    const detail = (await admin.get(`/v1/admin/leads/${lead.id}`)).body.data;
    expect(detail.activities[0].body).toContain("Real QA development enquiry");

    const cars = await admin.get("/v1/admin/leads", { category: "cars", pageSize: 50, sort: "newest" });
    expect(cars.body.items.some((item) => item.property?.id === publicId)).toBe(false);
  });

  it("10. the owning developer sees it — as an enquiry and as a CRM lead", async () => {
    const enquiries = await developer.get("/v1/portal/inquiries", { pageSize: 50 });
    const enquiry = enquiries.body.data.find((row) => row.project?.id === publicId);
    expect(enquiry, "the developer's own development enquiry").toBeTruthy();
    expect(enquiry.project.name).toBe(name);
    inquiryId = enquiry.id;

    const inCategory = await developer.get("/v1/portal/inquiries", { category: "realEstateDevelopment", pageSize: 50 });
    expect(inCategory.body.data.some((row) => row.id === inquiryId)).toBe(true);
    expect(inCategory.body.data.every((row) => row.project)).toBe(true);

    const onItsPage = await developer.get("/v1/portal/inquiries", { listing: publicId, pageSize: 50 });
    expect(onItsPage.body.data.map((row) => row.id)).toContain(inquiryId);

    const crm = await developer.get("/v1/portal/leads", { pageSize: 100 });
    const lead = crm.body.data.find((row) => row.listingId === publicId);
    expect(lead, "the CRM lead on the developer's Leads page").toBeTruthy();
    expect(lead).toMatchObject({ categoryId: "realEstateDevelopment", listingTitle: name });
  });

  it("11. the developer processes it — status change and a note", async () => {
    const update = await developer.send("patch", `/v1/portal/inquiries/${inquiryId}`, {
      status: "contacted",
      note: "Called back about the payment plan — QA development lifecycle.",
    });
    expect(update.status, JSON.stringify(update.body)).toBe(200);
    const after = await developer.get("/v1/portal/inquiries", { listing: publicId, pageSize: 50 });
    expect(after.body.data.find((row) => row.id === inquiryId).status).toBe("contacted");
  });

  it("12. a competing developer sees none of it and can touch none of it", async () => {
    expect(rival.account_id).not.toBe(owner.account_id);

    const theirs = await competitor.get("/v1/portal/inquiries", { pageSize: 100 });
    expect(theirs.body.data.filter((row) => row.id === inquiryId || row.project?.id === publicId)).toEqual([]);
    const theirLeads = await competitor.get("/v1/portal/leads", { pageSize: 100 });
    expect(theirLeads.body.data.filter((row) => row.listingId === publicId)).toEqual([]);
    const theirDevelopments = await competitor.get("/v1/portal/developments");
    expect(theirDevelopments.body.data.some((item) => item.id === publicId)).toBe(false);

    expect((await competitor.send("patch", `/v1/portal/inquiries/${inquiryId}`, { status: "contacted" })).status).toBe(404);
    expect((await competitor.get(`/v1/portal/developments/${publicId}`)).status).toBe(404);
    expect((await competitor.send("patch", `/v1/portal/developments/${publicId}`, { tagline: "hijack" })).status).toBe(404);
  });

  it("13. an account without Developments access cannot submit one", async () => {
    const outsider = await ownerWithoutDevelopments();
    expect(outsider, "an organization owner without the category").toBeTruthy();
    const api = client();
    await api.login(outsider.email, PASSWORD);
    const response = await api.send("post", "/v1/portal/developments", { name: `QA Refused ${Date.now()}`, communityId });
    expect(response.status).toBe(403);
    const stray = await queryOne("SELECT public_id FROM projects WHERE name LIKE 'QA Refused %' LIMIT 1");
    if (stray) created.push(stray.public_id);
    expect(stray).toBeFalsy();
  });
});
