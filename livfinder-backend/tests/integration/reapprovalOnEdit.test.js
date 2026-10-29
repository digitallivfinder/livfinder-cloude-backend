import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, adminEmail, cleanupListings, cleanupProjects, ensureTestPassword, execute, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * An owner's change to a live listing waits for a moderator; the site keeps the approved version.
 *
 * Approval covers the version a moderator reviewed. Any owner change (the edit form, or any media
 * action: a photo added, removed, reordered or re-captioned, a file, a link) opens a pending
 * revision (migration 0060). The listing stays live and the public page, the search results and
 * the URL keep showing the approved version until a moderator approves the change; a rejection
 * sends reasons back and leaves the approved version up. Walked for every listing category.
 *
 * Developments follow the same rule (migration 0061), below.
 */
const PASSWORD = "LivFinder!2026";
const createdListings = [];
const createdProjects = [];

async function ownerForCategory(categoryId) {
  return queryOne(
    `SELECT u.email, a.id AS account_id
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
       JOIN account_category_access aca ON aca.account_id = a.id AND aca.status = 'approved' AND aca.category_id = ?
      WHERE u.status = 'active' AND u.deleted_at IS NULL
        -- Room under both plan limits (0059), so creating the test listing is not refused.
        AND (a.listing_quota IS NULL OR a.listing_used + 5 < a.listing_quota)
        AND (a.storage_quota IS NULL OR a.storage_used + 5 < a.storage_quota)
      ORDER BY u.id LIMIT 1`,
    [categoryId]
  );
}

async function locationRef(level) {
  const row = await queryOne(
    `SELECT id FROM locations WHERE level = ? AND status = 'active'${level === "community" ? " AND active_listing_count > 0" : ""} LIMIT 1`,
    [level]
  );
  return `${level}:${row.id}`;
}

const statusOf = (publicId) =>
  queryOne("SELECT status, moderation_status FROM listings WHERE public_id = ?", [publicId]);

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
});

afterAll(async () => {
  for (const publicId of createdListings) {
    await execute(
      "DELETE n FROM notifications n JOIN listings l ON l.id = n.subject_id WHERE n.subject_type = 'listing' AND n.type LIKE 'listing.revision_%' AND l.public_id = ?",
      [publicId]
    );
  }
  await cleanupListings(createdListings);
  await cleanupProjects(createdProjects);
  await closePool();
});

const CASES = [
  { category: "real-estate", categoryId: 1, categorySlug: "apartments", locationLevel: "community", detail: { bedrooms: 2, bathrooms: 2, builtAreaSqft: 1200 } },
  { category: "cars", categoryId: 2, categorySlug: "supercars", locationLevel: "city", detail: { modelYear: 2023, transmission: "automatic" } },
  { category: "yachts", categoryId: 3, categorySlug: "motor-yachts", locationLevel: "city", detail: { buildYear: 2021 } },
  { category: "jets", categoryId: 4, categorySlug: "light-jets", locationLevel: "city", detail: { yearBuilt: 2019 } },
  { category: "helicopters", categoryId: 5, categorySlug: "light-helicopter", locationLevel: "city", detail: { yearBuilt: 2020 } },
  { category: "watches", categoryId: 6, categorySlug: "dive-watches", locationLevel: "city", detail: { yearOfProduction: 2022 } },
];

describe.each(CASES)("an owner's change to a live $category listing", ({ category, categoryId, categorySlug, locationLevel, detail }) => {
  const portal = client();
  const admin = client();
  let id = null;
  let approvedPath = null;

  const moderate = async (body) => {
    const response = await admin.send("patch", `/v1/admin/listings/${id}/moderation`, body);
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    return response.body.data;
  };
  const publicPage = async () => {
    const response = await client().get(`/v1/public/listings/${id}`);
    expect(response.status).toBe(200);
    return response.body.data;
  };
  const row = () => queryOne("SELECT status, moderation_status, canonical_path, pending_revision_id FROM listings WHERE public_id = ?", [id]);

  beforeAll(async () => {
    const owner = await ownerForCategory(categoryId);
    expect(owner, `a seeded owner with ${category} access`).toBeTruthy();
    await portal.login(owner.email, PASSWORD);
    await admin.login(await adminEmail("super_admin"), PASSWORD);
    await admin.stepUp();

    const created = await portal.send("post", "/v1/portal/listings", {
      category,
      categorySlug,
      purpose: category === "yachts" ? "charter" : "sale",
      title: `QA reapproval ${category} ${Date.now()}`,
      subtitle: "Approved subtitle",
      description: `<p>Exercises re-approval after an owner edit for ${category}.</p>`,
      price: 250000,
      currency: category === "watches" ? "USD" : "AED",
      locationId: await locationRef(locationLevel),
      detail,
      status: "pending_review",
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    id = created.body.data.id;
    createdListings.push(id);
    await moderate({ decision: "approve" });
    approvedPath = (await row()).canonical_path;
    expect((await publicPage()).subtitle).toBe("Approved subtitle");
  });

  it("an edit stays queued: the listing stays live and the site keeps the approved version and URL", async () => {
    const response = await portal.send("patch", `/v1/portal/listings/${id}`, {
      subtitle: "Edited after approval",
      title: `QA reapproval ${category} renamed ${Date.now()}`,
    });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    const now = await row();
    expect(now).toMatchObject({ status: "active", moderation_status: "approved", canonical_path: approvedPath });
    expect(now.pending_revision_id).toBeTruthy();
    const page = await publicPage();
    expect(page.subtitle).toBe("Approved subtitle");

    const own = (await portal.get(`/v1/portal/listings/${id}`)).body.data;
    expect(own.subtitle).toBe("Edited after approval");
    expect(own.pendingChanges).toMatchObject({ status: "pending" });
  });

  it("a media change alone (a video link) joins the same pending change, and is not public yet", async () => {
    const response = await portal.send("post", `/v1/media/listings/${id}/links`, {
      mediaType: "video",
      url: "https://www.youtube.com/watch?v=aqz-KE-bpKQ",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect((await row()).status).toBe("active");
    expect(JSON.stringify((await publicPage()).documents)).not.toContain("youtube.com");
  });

  it("the moderator sees what changed against the approved version", async () => {
    const detail = (await admin.get(`/v1/admin/listings/${id}`)).body.data;
    expect(detail.pendingChanges.status).toBe("pending");
    expect(detail.pendingChanges.changeLog).toHaveLength(2);
    const fields = detail.pendingChanges.changes.fields.map((item) => item.field);
    expect(fields).toEqual(expect.arrayContaining(["title", "subtitle"]));
    expect(detail.pendingChanges.changes.fields.find((item) => item.field === "subtitle")).toMatchObject({
      before: "Approved subtitle",
      after: "Edited after approval",
    });
    expect(detail.pendingChanges.changes.documents.added).toHaveLength(1);
  });

  it("rejecting sends the reasons back and keeps the approved version live", async () => {
    await moderate({ decision: "reject", reason: "Remove the renamed title.", fields: { title: "Keep the original title." } });
    expect(await row()).toMatchObject({ status: "active", moderation_status: "approved" });
    expect((await publicPage()).subtitle).toBe("Approved subtitle");
    const own = (await portal.get(`/v1/portal/listings/${id}`)).body.data;
    expect(own.pendingChanges).toMatchObject({
      status: "rejected",
      rejectionReason: "Remove the renamed title.",
      rejectionFields: { title: "Keep the original title." },
    });
    const notice = await queryOne(
      "SELECT n.type FROM notifications n JOIN listings l ON l.id = n.subject_id WHERE l.public_id = ? AND n.type = 'listing.revision_rejected' LIMIT 1",
      [id]
    );
    expect(notice).toBeTruthy();
  });

  it("the owner's next edit resubmits, and approval publishes all of it at once", async () => {
    const response = await portal.send("patch", `/v1/portal/listings/${id}`, { subtitle: "Edited again" });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect((await portal.get(`/v1/portal/listings/${id}`)).body.data.pendingChanges.status).toBe("pending");

    await moderate({ decision: "approve" });
    const now = await row();
    expect(now).toMatchObject({ status: "active", pending_revision_id: null });
    expect(now.canonical_path).not.toBe(approvedPath);
    const page = await publicPage();
    expect(page.subtitle).toBe("Edited again");
    expect(JSON.stringify(page.documents)).toContain("youtube.com");
    expect((await portal.get(`/v1/portal/listings/${id}`)).body.data.pendingChanges).toBeNull();
  });

  it("an owner status change that is not an edit (marking it sold) opens no pending change", async () => {
    const response = await portal.send("patch", `/v1/portal/listings/${id}/status`, {
      status: category === "yachts" ? "rented" : "sold",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(await row()).toMatchObject({ status: category === "yachts" ? "rented" : "sold", pending_revision_id: null });
  });
});

describe("the edit form's own status choice on a listing that is not live", () => {
  const portal = client();
  const admin = client();
  let id = null;

  beforeAll(async () => {
    const owner = await ownerForCategory(1);
    await portal.login(owner.email, PASSWORD);
    await admin.login(await adminEmail("super_admin"), PASSWORD);
    await admin.stepUp();
    const created = await portal.send("post", "/v1/portal/listings", {
      category: "real-estate",
      categorySlug: "apartments",
      purpose: "sale",
      title: `QA resubmit ${Date.now()}`,
      description: "<p>Exercises resubmission from the edit form.</p>",
      price: 900000,
      currency: "AED",
      locationId: await locationRef("community"),
      detail: { bedrooms: 1, bathrooms: 1, builtAreaSqft: 700 },
      status: "pending_review",
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    id = created.body.data.id;
    createdListings.push(id);
    const reject = await admin.send("patch", `/v1/admin/listings/${id}/moderation`, {
      decision: "reject",
      reason: "Add the service charge, then resubmit.",
    });
    expect(reject.status).toBe(200);
  });

  it("an edit to a rejected listing alone leaves it rejected", async () => {
    await portal.send("patch", `/v1/portal/listings/${id}`, { subtitle: "Service charge added" });
    expect((await statusOf(id)).moderation_status).toBe("rejected");
  });

  it("'Submit for review' from the edit form actually resubmits it", async () => {
    const response = await portal.send("patch", `/v1/portal/listings/${id}`, {
      subtitle: "Service charge AED 18/sqft",
      status: "pending_review",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(await statusOf(id)).toEqual({ status: "pending_review", moderation_status: "pending" });
  });
});

describe("a developer's change to a live development", () => {
  const developer = client();
  const admin = client();
  let id = null;
  let name = null;

  const moderation = () =>
    queryOne("SELECT moderation_status, is_publicly_visible AS visible FROM projects WHERE public_id = ?", [id]);

  beforeAll(async () => {
    const owner = await queryOne(
      `SELECT u.email
         FROM users u
         JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
         JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
         JOIN organizations o ON o.account_id = a.id AND o.deleted_at IS NULL
         JOIN account_category_access aca ON aca.account_id = a.id AND aca.category_id = 7 AND aca.status = 'approved'
        WHERE u.status = 'active' AND u.deleted_at IS NULL
        ORDER BY u.id LIMIT 1`
    );
    await developer.login(owner.email, PASSWORD);
    await admin.login(await adminEmail("super_admin"), PASSWORD);
    await admin.stepUp();
    const community = await queryOne("SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1");
    name = `QA reapproval development ${Date.now()}`;
    const created = await developer.send("post", "/v1/portal/developments", {
      name,
      minPrice: 1200000,
      currencyCode: "AED",
      totalUnits: 50,
      availableUnits: 40,
      communityId: community.id,
      status: "announced",
      submit: true,
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    id = created.body.data.id;
    createdProjects.push(id);
    const publish = await admin.send("patch", `/v1/admin/developments/${id}`, { name, moderationStatus: "published" });
    expect(publish.status, JSON.stringify(publish.body)).toBe(200);
    expect((await client().get(`/v1/public/projects/${id}`)).status).toBe(200);
  });

  it("an edit stays queued: the development stays published and the site keeps the approved version", async () => {
    const response = await developer.send("patch", `/v1/portal/developments/${id}`, { availableUnits: 35 });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(await moderation()).toEqual({ moderation_status: "published", visible: 1 });
    const page = await client().get(`/v1/public/projects/${id}`);
    expect(page.status).toBe(200);
    expect(page.body.data.availableUnits ?? page.body.data.inventory?.availableUnits).not.toBe(35);
    const own = (await developer.get(`/v1/portal/developments/${id}`)).body.data;
    expect(own.availableUnits).toBe(35);
    expect(own.pendingChanges).toMatchObject({ status: "pending" });
  });

  it("the moderator sees the change, can send it back, and the developer sees why", async () => {
    const response = await admin.get(`/v1/admin/developments/${id}`);
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    const detail = response.body.data;
    expect(detail.pendingChanges.status).toBe("pending");
    expect(detail.pendingChanges.changes.fields.length).toBeGreaterThan(0);
    const reject = await admin.send("patch", `/v1/admin/developments/${id}/changes`, { decision: "reject", reason: "Confirm the unit count." });
    expect(reject.status, JSON.stringify(reject.body)).toBe(200);
    expect(await moderation()).toEqual({ moderation_status: "published", visible: 1 });
    const own = (await developer.get(`/v1/portal/developments/${id}`)).body.data;
    expect(own.pendingChanges).toMatchObject({ status: "rejected", rejectionReason: "Confirm the unit count." });
  });

  it("the next edit resubmits, and approving publishes it", async () => {
    expect((await developer.send("patch", `/v1/portal/developments/${id}`, { availableUnits: 34 })).status).toBe(200);
    expect((await developer.get(`/v1/portal/developments/${id}`)).body.data.pendingChanges.status).toBe("pending");
    const approve = await admin.send("patch", `/v1/admin/developments/${id}/changes`, { decision: "approve" });
    expect(approve.status, JSON.stringify(approve.body)).toBe(200);
    const pending = await queryOne("SELECT pending_revision_id FROM projects WHERE public_id = ?", [id]);
    expect(pending.pending_revision_id).toBeNull();
    const own = await developer.get(`/v1/portal/developments/${id}`);
    expect(own.body.data.availableUnits).toBe(34);
    expect(own.body.data.pendingChanges).toBeNull();
  });

  /**
   * The developer's own floor plans, brochure, documents and links. Only the admin wizard could
   * add these before; the portal had no way to attach a floor plan or a brochure at all.
   */
  const PDF = Buffer.from("%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n");
  const uploadFile = (who, fields) => {
    let request = who.agent
      .post(`/v1/media/developments/${id}/files`)
      .set("X-CSRF-Token", who.csrfToken)
      .set("Accept", "application/json");
    for (const [key, value] of Object.entries(fields)) request = request.field(key, value);
    return request.attach("files", PDF, { filename: "attachment.pdf", contentType: "application/pdf" });
  };

  it("a floor plan uploaded to a live development is listed, and waits for approval while it stays live", async () => {
    const response = await uploadFile(developer, { mediaType: "floor_plan", caption: "Level 12 — 2BR" });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect(response.body.data.some((item) => item.type === "floor_plan" && item.label === "Level 12 — 2BR")).toBe(true);
    expect(await moderation()).toEqual({ moderation_status: "published", visible: 1 });
    expect((await developer.get(`/v1/portal/developments/${id}`)).body.data.pendingChanges.status).toBe("pending");
    expect(JSON.stringify((await client().get(`/v1/public/projects/${id}`)).body.data)).not.toContain("Level 12 — 2BR");
  });

  it("adds a brochure, a typed document and a video link, all listed on the development", async () => {
    expect((await uploadFile(developer, { mediaType: "document", tag: "brochure", caption: "Sales brochure" })).status).toBe(201);
    expect((await uploadFile(developer, { mediaType: "document", tag: "price_list", caption: "Price list" })).status).toBe(201);
    const refused = await uploadFile(developer, { mediaType: "document", tag: "title_deed", caption: "Wrong type" });
    expect(refused.status).toBe(422);
    const link = await developer.send("post", `/v1/media/developments/${id}/links`, {
      mediaType: "video",
      url: "https://www.youtube.com/watch?v=aqz-KE-bpKQ",
    });
    expect(link.status, JSON.stringify(link.body)).toBe(201);

    const detail = (await developer.get(`/v1/portal/developments/${id}`)).body.data;
    const kinds = detail.documents.map((item) => `${item.type}:${item.documentType ?? ""}`);
    expect(kinds).toEqual(expect.arrayContaining(["floor_plan:", "document:brochure", "document:price_list", "video:"]));
    const admin = await queryOne("SELECT video_url FROM projects WHERE public_id = ?", [id]);
    expect(admin.video_url).toContain("youtube.com");
  });

  it("removes an attachment", async () => {
    const before = (await developer.get(`/v1/media/developments/${id}/attachments`)).body.data;
    const plan = before.find((item) => item.type === "floor_plan");
    const removed = await developer.send("delete", `/v1/media/developments/${id}/attachments/${plan.id}`);
    expect(removed.status, JSON.stringify(removed.body)).toBe(200);
    expect(removed.body.data.some((item) => item.id === plan.id)).toBe(false);
  });

  it("another account can neither see nor change them", async () => {
    const outsider = await queryOne(
      `SELECT u.email FROM users u
         JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
         JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
        WHERE u.status = 'active' AND u.deleted_at IS NULL
          AND a.id <> (SELECT o.account_id FROM projects p JOIN organizations o ON o.id = p.organization_id WHERE p.public_id = ?)
        ORDER BY u.id LIMIT 1`,
      [id]
    );
    const other = client();
    await other.login(outsider.email, PASSWORD);
    expect((await other.get(`/v1/media/developments/${id}/attachments`)).status).toBe(404);
    expect((await uploadFile(other, { mediaType: "floor_plan", caption: "hijack" })).status).toBe(404);
  });
});
