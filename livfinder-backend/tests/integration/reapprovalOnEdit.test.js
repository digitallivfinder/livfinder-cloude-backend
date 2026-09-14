import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, adminEmail, cleanupListings, cleanupProjects, ensureTestPassword, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * A live listing or development that its owner changes goes back to moderation.
 *
 * Approval covers the version a moderator reviewed. Before this, an owner could change the text,
 * the price or the photos of an approved listing and the public page showed it straight away —
 * content nobody had checked. Now any owner change (the edit form, or any media action: a photo
 * added, removed, reordered or re-captioned, a file, a link) takes it off the public site and
 * back to `pending_review` until a moderator approves it again. Walked for all seven categories.
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

const lastTransition = (publicId) =>
  queryOne(
    `SELECT h.from_status, h.to_status
       FROM listing_status_history h JOIN listings l ON l.id = h.listing_id
      WHERE l.public_id = ? ORDER BY h.id DESC LIMIT 1`,
    [publicId]
  );

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
});

afterAll(async () => {
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

  const approve = async () => {
    const response = await admin.send("patch", `/v1/admin/listings/${id}/moderation`, { decision: "approve" });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(await statusOf(id)).toEqual({ status: "active", moderation_status: "approved" });
  };

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
    await approve();
    expect((await client().get(`/v1/public/listings/${id}`)).status).toBe(200);
  });

  it("a text edit sends it back for review and takes it off the public site", async () => {
    const response = await portal.send("patch", `/v1/portal/listings/${id}`, { subtitle: "Edited after approval" });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(await statusOf(id)).toEqual({ status: "pending_review", moderation_status: "pending" });
    expect(await lastTransition(id)).toMatchObject({ from_status: "active", to_status: "pending_review" });
    expect((await client().get(`/v1/public/listings/${id}`)).status).toBe(404);
  });

  it("re-approval puts the edited version back on the site", async () => {
    await approve();
    const live = await client().get(`/v1/public/listings/${id}`);
    expect(live.status).toBe(200);
    expect(JSON.stringify(live.body.data)).toContain("Edited after approval");
  });

  it("a media change alone — adding a video link — sends it back too", async () => {
    const response = await portal.send("post", `/v1/media/listings/${id}/links`, {
      mediaType: "video",
      url: "https://www.youtube.com/watch?v=aqz-KE-bpKQ",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect(await statusOf(id)).toEqual({ status: "pending_review", moderation_status: "pending" });
    expect((await client().get(`/v1/public/listings/${id}`)).status).toBe(404);
  });

  it("an owner status change that is not an edit (marking it sold) is not sent back", async () => {
    await approve();
    const response = await portal.send("patch", `/v1/portal/listings/${id}/status`, {
      status: category === "yachts" ? "rented" : "sold",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect((await statusOf(id)).status).toBe(category === "yachts" ? "rented" : "sold");
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

  it("any edit takes it off the site and back to pending", async () => {
    const response = await developer.send("patch", `/v1/portal/developments/${id}`, { availableUnits: 35 });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(await moderation()).toEqual({ moderation_status: "pending", visible: 0 });
    expect((await client().get(`/v1/public/projects/${id}`)).status).toBe(404);
  });

  it("re-publishing puts the edited version back", async () => {
    const publish = await admin.send("patch", `/v1/admin/developments/${id}`, { name, moderationStatus: "published" });
    expect(publish.status).toBe(200);
    expect(await moderation()).toEqual({ moderation_status: "published", visible: 1 });
    const own = await developer.get(`/v1/portal/developments/${id}`);
    expect(own.body.data.availableUnits).toBe(35);
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

  it("a floor plan uploaded to a live development is listed, and sends it back for review", async () => {
    const response = await uploadFile(developer, { mediaType: "floor_plan", caption: "Level 12 — 2BR" });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect(response.body.data.some((item) => item.type === "floor_plan" && item.label === "Level 12 — 2BR")).toBe(true);
    expect(await moderation()).toEqual({ moderation_status: "pending", visible: 0 });
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
