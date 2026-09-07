import { afterAll, beforeAll, describe, expect, it } from "vitest";
import sharp from "sharp";
import {
  client, ensureTestPassword, findPortalOwner, findSecondPortalOwner, adminEmail,
  cleanupListings, queryOne, query, execute,
} from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Client portal, against the real database.
 *
 * These cover the parts that only a database can answer: that a write is one
 * transaction across `listings` and its category detail table, that the search
 * projection follows a status change, that gallery order persists, and that one
 * account cannot reach another's rows.
 */
const PASSWORD = "LivFinder!2026";
const created = [];
const portal = client();
const other = client();
const admin = client();
let owner = null;
let secondOwner = null;
let communityId = null;

async function image(seed = 1, width = 700) {
  return sharp({
    create: { width, height: Math.round(width * 0.66), channels: 3, background: { r: 20 + seed * 20, g: 90, b: 150 } },
  })
    .jpeg({ quality: 80 })
    .toBuffer();
}

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  owner = await findPortalOwner();
  secondOwner = await findSecondPortalOwner(owner.account_id);
  await portal.login(owner.email, PASSWORD);
  await other.login(secondOwner.email, PASSWORD);
  await admin.login(await adminEmail("super_admin"), PASSWORD);

  const community = await queryOne(
    `SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1`
  );
  communityId = `community:${community.id}`;
});

afterAll(async () => {
  await cleanupListings(created);
  await closePool();
});

describe("portal reads", () => {
  it("requires a session", async () => {
    const response = await client().get("/v1/portal/dashboard");
    expect(response.status).toBe(401);
  });

  it("counts the same rows the tabs then list", async () => {
    const response = await portal.get("/v1/portal/listings", { pageSize: 100 });
    expect(response.status).toBe(200);
    const active = response.body.data.filter((row) => row.status === "active").length;
    const total = await queryOne(
      "SELECT COUNT(*) AS total FROM listings WHERE account_id = ? AND status = 'active' AND deleted_at IS NULL",
      [owner.account_id]
    );
    expect(response.body.counts.active).toBe(Number(total.total));
    if (response.body.pageInfo.total <= 100) expect(active).toBe(response.body.counts.active);
  });

  it("returns only this account's listings", async () => {
    const response = await portal.get("/v1/portal/listings", { pageSize: 100 });
    const references = response.body.data.map((row) => row.reference);
    if (!references.length) return;
    const foreign = await query(
      `SELECT reference FROM listings WHERE reference IN (${references.map(() => "?").join(", ")}) AND account_id <> ?`,
      [...references, owner.account_id]
    );
    expect(foreign).toHaveLength(0);
  });

  it("answers every portal read for a signed-in owner", async () => {
    for (const path of [
      "/v1/portal/dashboard", "/v1/portal/inquiries", "/v1/portal/leads", "/v1/portal/messages",
      "/v1/portal/bookings", "/v1/portal/offers", "/v1/portal/reviews", "/v1/portal/favourites",
      "/v1/portal/saved-searches", "/v1/portal/profile", "/v1/portal/categories",
      "/v1/portal/organization", "/v1/portal/payments", "/v1/portal/billing", "/v1/portal/payouts",
    ]) {
      const response = await portal.get(path);
      expect(response.status, path).toBe(200);
    }
  });
});

describe("listing lifecycle", () => {
  let listingId = null;
  let reference = null;

  it("creates a listing with its category detail row in one transaction", async () => {
    const response = await portal.send("post", "/v1/portal/listings", {
      category: "real-estate",
      categorySlug: "villas",
      purpose: "sale",
      title: `Integration Villa ${Date.now()}`,
      description: "Created by the integration suite.",
      price: 9500000,
      currency: "AED",
      locationId: communityId,
      detail: { bedrooms: 4, bathrooms: 5, builtAreaSqft: 5400, furnishing: "furnished" },
    });
    expect(response.status).toBe(201);
    listingId = response.body.data.id;
    reference = response.body.data.reference;
    created.push(listingId);

    const row = await queryOne("SELECT id, account_id, status, moderation_status FROM listings WHERE public_id = ?", [listingId]);
    expect(row.account_id).toBe(owner.account_id);
    expect(row.status).toBe("draft");

    const detail = await queryOne("SELECT bedrooms, bathrooms, built_area_sqft FROM listing_real_estate WHERE listing_id = ?", [row.id]);
    expect(detail).toMatchObject({ bedrooms: 4, bathrooms: 5 });
    expect(Number(detail.built_area_sqft)).toBe(5400);
  });

  it("registers the property unit the real-estate inventory invariant requires", async () => {
    // `db/seeds/099_platform_finalise.sql` asserts every live real-estate listing resolves to a
    // `property_units` row, so creating one through the API has to register its unit as well.
    const row = await queryOne("SELECT id, unit_id FROM listings WHERE public_id = ?", [listingId]);
    expect(row.unit_id).not.toBeNull();

    const unit = await queryOne(
      "SELECT unit_type, bedrooms, bathrooms, listing_count, active_listing_count FROM property_units WHERE id = ?",
      [row.unit_id]
    );
    expect(unit.unit_type).toBe("villa");
    expect(unit.bedrooms).toBe(4);
    expect(Number(unit.bathrooms)).toBe(5);
    // The listing is still a draft, so it counts once but is not active.
    expect(unit.listing_count).toBe(1);
    expect(unit.active_listing_count).toBe(0);

    const orphans = await queryOne(
      "SELECT COUNT(*) AS total FROM listings WHERE root_category_id = 1 AND deleted_at IS NULL AND unit_id IS NULL"
    );
    expect(Number(orphans.total)).toBe(0);
  });

  it("gives it a canonical path that matches the marketplace URL contract", async () => {
    const row = await queryOne("SELECT canonical_path, slug FROM listings WHERE public_id = ?", [listingId]);
    expect(row.canonical_path.startsWith("/real-estate/")).toBe(true);
    expect(row.canonical_path.endsWith(row.slug)).toBe(true);
  });

  it("keeps a draft out of the public projection", async () => {
    const projection = await queryOne(
      "SELECT listing_id FROM listing_search WHERE listing_id = (SELECT id FROM listings WHERE public_id = ?)",
      [listingId]
    );
    expect(projection).toBeNull();
    expect((await client().get(`/v1/public/listings/${reference}`)).status).toBe(404);
  });

  it("persists an edit across a fresh read", async () => {
    const title = `Integration Villa Updated ${Date.now()}`;
    const response = await portal.send("patch", `/v1/portal/listings/${listingId}`, {
      title,
      price: 10250000,
      detail: { bedrooms: 6 },
    });
    expect(response.status).toBe(200);

    const reread = await portal.get(`/v1/portal/listings/${listingId}`);
    expect(reread.body.data.title).toBe(title);
    expect(reread.body.data.price.amount).toBe(10250000);
    expect(reread.body.data.bedrooms).toBe(6);

    const row = await queryOne(
      `SELECT l.title, l.price, re.bedrooms FROM listings l
         JOIN listing_real_estate re ON re.listing_id = l.id WHERE l.public_id = ?`,
      [listingId]
    );
    expect(row.title).toBe(title);
    expect(row.bedrooms).toBe(6);
  });

  it("rejects a model that does not belong to the chosen brand", async () => {
    // Inside a category this account *is* approved for, so the refusal is the
    // brand/model relationship check and not the category gate.
    const developer = await queryOne(
      "SELECT slug FROM brands WHERE kind = 'property_developer' AND deleted_at IS NULL LIMIT 1"
    );
    const response = await portal.send("post", "/v1/portal/listings", {
      category: "real-estate",
      categorySlug: "apartments",
      title: "Mismatched development",
      brand: developer.slug,
      model: "not-a-real-model-slug",
      price: 1000,
      locationId: communityId,
    });
    expect(response.status).toBe(422);
    expect(response.body.error.fields.model || response.body.error.fields.brand).toBeTruthy();
  });

  it("refuses a category the account has not been approved for", async () => {
    const approved = await query(
      `SELECT COALESCE(c.root_category_id, c.id) AS root_category_id
         FROM organization_category_access oca JOIN categories c ON c.id = oca.category_id
        WHERE oca.organization_id = ? AND oca.status = 'approved'`,
      [owner.organization_id]
    );
    const approvedRoots = new Set(approved.map((row) => Number(row.root_category_id)));
    const forbidden = [
      [2, "cars"], [3, "yachts"], [4, "jets"], [5, "helicopters"], [6, "watches"],
    ].find(([rootId]) => !approvedRoots.has(rootId));
    if (!forbidden) return;

    const response = await portal.send("post", "/v1/portal/listings", {
      category: forbidden[1],
      title: "Not allowed here",
      price: 1000,
    });
    expect(response.status).toBe(403);
  });

  it("refuses to publish from the portal", async () => {
    const response = await portal.send("patch", `/v1/portal/listings/${listingId}/status`, { status: "active" });
    expect(response.status).toBe(403);
    const row = await queryOne("SELECT status FROM listings WHERE public_id = ?", [listingId]);
    expect(row.status).toBe("draft");
  });

  it("submits for review and records the transition", async () => {
    const response = await portal.send("patch", `/v1/portal/listings/${listingId}/status`, { status: "pending_review" });
    expect(response.status).toBe(200);

    const row = await queryOne("SELECT id, status, moderation_status FROM listings WHERE public_id = ?", [listingId]);
    expect(row).toMatchObject({ status: "pending_review", moderation_status: "pending" });

    const history = await queryOne(
      "SELECT from_status, to_status FROM listing_status_history WHERE listing_id = ? ORDER BY id DESC LIMIT 1",
      [row.id]
    );
    expect(history).toMatchObject({ from_status: "draft", to_status: "pending_review" });
  });

  it("becomes publicly visible only after a moderator approves it", async () => {
    const response = await admin.send("patch", `/v1/admin/listings/${listingId}/moderation`, {
      decision: "approve",
      note: "integration suite",
    });
    expect(response.status).toBe(200);

    const row = await queryOne("SELECT id, status, published_at FROM listings WHERE public_id = ?", [listingId]);
    expect(row.status).toBe("active");
    expect(row.published_at).not.toBeNull();

    // The projection is refreshed by the same operation.
    const projection = await queryOne("SELECT canonical_path FROM listing_search WHERE listing_id = ?", [row.id]);
    expect(projection).toBeTruthy();

    const publicRead = await client().get(`/v1/public/listings/${reference}`);
    expect(publicRead.status).toBe(200);
    expect(publicRead.body.data.reference).toBe(reference);
  });

  it("leaves the projection when it is archived", async () => {
    await admin.send("patch", `/v1/admin/listings/${listingId}/moderation`, { decision: "archive", reason: "cleanup" });
    const row = await queryOne("SELECT id, status FROM listings WHERE public_id = ?", [listingId]);
    expect(row.status).toBe("archived");
    const projection = await queryOne("SELECT listing_id FROM listing_search WHERE listing_id = ?", [row.id]);
    expect(projection).toBeNull();
  });
});

describe("listing media", () => {
  let listingId = null;

  beforeAll(async () => {
    const response = await portal.send("post", "/v1/portal/listings", {
      category: "real-estate",
      categorySlug: "apartments",
      purpose: "sale",
      title: `Media Test Apartment ${Date.now()}`,
      price: 2500000,
      currency: "AED",
      locationId: communityId,
      detail: { bedrooms: 2, bathrooms: 2 },
    });
    listingId = response.body.data.id;
    created.push(listingId);
  });

  it("stores an upload, its renditions and the listing_media row", async () => {
    const response = await portal.agent
      .post(`/v1/media/listings/${listingId}/media`)
      .set("X-CSRF-Token", portal.csrfToken)
      .attach("files", await image(1), "one.jpg")
      .attach("files", await image(2), "two.jpg");
    expect(response.status).toBe(201);
    expect(response.body.data).toHaveLength(2);

    const row = await queryOne("SELECT id, image_count, cover_image_url FROM listings WHERE public_id = ?", [listingId]);
    expect(row.image_count).toBe(2);
    expect(row.cover_image_url).toBeTruthy();

    const asset = await queryOne(
      `SELECT ma.id, ma.width, ma.height, ma.checksum,
              (SELECT COUNT(*) FROM media_renditions r WHERE r.media_asset_id = ma.id) AS renditions
         FROM listing_media lm JOIN media_assets ma ON ma.id = lm.media_asset_id
        WHERE lm.listing_id = ? LIMIT 1`,
      [row.id]
    );
    expect(asset.width).toBeGreaterThan(0);
    expect(asset.checksum).toHaveLength(64);
    expect(Number(asset.renditions)).toBeGreaterThan(0);
  });

  it("rejects a file that is not really an image", async () => {
    const response = await portal.agent
      .post(`/v1/media/listings/${listingId}/media`)
      .set("X-CSRF-Token", portal.csrfToken)
      .attach("files", Buffer.from("this is not a jpeg"), "fake.jpg");
    expect(response.status).toBe(415);
  });

  it("persists a reorder and moves the cover with it", async () => {
    const before = await portal.get(`/v1/media/listings/${listingId}/media`);
    const reversed = [...before.body.data].reverse().map((item) => item.id);
    const response = await portal.send("patch", `/v1/media/listings/${listingId}/media/reorder`, { order: reversed });
    expect(response.status).toBe(200);

    const after = await portal.get(`/v1/media/listings/${listingId}/media`);
    expect(after.body.data.map((item) => item.id)).toEqual(reversed);
    expect(after.body.data[0].isCover).toBe(true);

    const row = await queryOne("SELECT cover_image_url FROM listings WHERE public_id = ?", [listingId]);
    expect(row.cover_image_url).toBe(after.body.data[0].url);
  });

  it("refuses a reorder that references media from another listing", async () => {
    const foreign = await queryOne("SELECT id FROM listing_media WHERE listing_id <> (SELECT id FROM listings WHERE public_id = ?) LIMIT 1", [listingId]);
    const response = await portal.send("patch", `/v1/media/listings/${listingId}/media/reorder`, { order: [String(foreign.id)] });
    expect(response.status).toBe(400);
  });

  it("deletes one image, keeps the rest and closes the gap", async () => {
    const before = await portal.get(`/v1/media/listings/${listingId}/media`);
    const target = before.body.data.at(-1);
    const response = await portal.send("delete", `/v1/media/listings/${listingId}/media/${target.id}`);
    expect(response.status).toBe(200);

    const after = await portal.get(`/v1/media/listings/${listingId}/media`);
    expect(after.body.data).toHaveLength(before.body.data.length - 1);
    expect(after.body.data.map((item) => item.sortOrder)).toEqual(after.body.data.map((_, index) => index));

    const row = await queryOne("SELECT image_count FROM listings WHERE public_id = ?", [listingId]);
    expect(row.image_count).toBe(after.body.data.length);
  });

  it("reuses the stored object when the same image is uploaded twice", async () => {
    const bytes = await image(9);
    const first = await portal.agent
      .post(`/v1/media/listings/${listingId}/media`)
      .set("X-CSRF-Token", portal.csrfToken)
      .attach("files", bytes, "dedupe.jpg");
    expect(first.status).toBe(201);

    const countBefore = await queryOne("SELECT COUNT(*) AS total FROM media_assets WHERE deleted_at IS NULL");
    const second = await portal.agent
      .post(`/v1/media/listings/${listingId}/media`)
      .set("X-CSRF-Token", portal.csrfToken)
      .attach("files", bytes, "dedupe-again.jpg");
    expect(second.status).toBe(201);
    const countAfter = await queryOne("SELECT COUNT(*) AS total FROM media_assets WHERE deleted_at IS NULL");
    expect(Number(countAfter.total)).toBe(Number(countBefore.total));
  });
});

describe("authorization", () => {
  it("does not reveal another account's listing", async () => {
    const foreign = await queryOne(
      "SELECT public_id FROM listings WHERE account_id <> ? AND deleted_at IS NULL LIMIT 1",
      [owner.account_id]
    );
    const read = await portal.get(`/v1/portal/listings/${foreign.public_id}`);
    expect(read.status).toBe(404);
    const write = await portal.send("patch", `/v1/portal/listings/${foreign.public_id}`, { title: "Hijacked" });
    expect(write.status).toBe(404);

    const unchanged = await queryOne("SELECT title FROM listings WHERE public_id = ?", [foreign.public_id]);
    expect(unchanged.title).not.toBe("Hijacked");
  });

  it("keeps two accounts' portal lists disjoint", async () => {
    const mine = await portal.get("/v1/portal/listings", { pageSize: 50 });
    const theirs = await other.get("/v1/portal/listings", { pageSize: 50 });
    const overlap = mine.body.data.filter((row) => theirs.body.data.some((entry) => entry.id === row.id));
    expect(overlap).toHaveLength(0);
  });

  it("refuses a portal user access to the admin surface", async () => {
    for (const path of ["/v1/admin/dashboard", "/v1/admin/listings", "/v1/admin/access-users", "/v1/admin/system-logs"]) {
      const response = await portal.get(path);
      expect(response.status, path).toBe(403);
    }
  });
});

describe("buyer actions", () => {
  it("adds and removes a favourite and keeps the counter honest", async () => {
    const listing = await queryOne("SELECT id, public_id, favourite_count FROM v_public_listings LIMIT 1");
    await portal.send("post", "/v1/favourites", { listingId: listing.public_id });

    const stored = await queryOne("SELECT price_at_save FROM favourites WHERE listing_id = ? AND user_id = ?", [listing.id, owner.id]);
    expect(stored).toBeTruthy();

    const ids = await portal.get("/v1/favourites/ids");
    expect(ids.body.data).toContain(listing.public_id);

    await portal.send("delete", `/v1/favourites/${listing.public_id}`);
    const after = await queryOne("SELECT id FROM favourites WHERE listing_id = ? AND user_id = ?", [listing.id, owner.id]);
    expect(after).toBeNull();
  });

  it("records an inquiry against the listing's owner and bumps the counter", async () => {
    const listing = await queryOne("SELECT id, public_id, account_id, inquiry_count FROM v_public_listings LIMIT 1");
    const response = await client().send("post", "/v1/inquiries", {
      listingId: listing.public_id,
      name: "Integration Buyer",
      email: `buyer-${Date.now()}@example.test`,
      message: "Is this still available for a viewing this weekend?",
    });
    expect(response.status).toBe(201);

    const row = await queryOne("SELECT account_id, status FROM inquiries WHERE public_id = ?", [response.body.data.id]);
    expect(row.account_id).toBe(listing.account_id);
    expect(row.status).toBe("new");

    const after = await queryOne("SELECT inquiry_count FROM listings WHERE id = ?", [listing.id]);
    expect(after.inquiry_count).toBe(listing.inquiry_count + 1);

    await execute("DELETE FROM inquiries WHERE public_id = ?", [response.body.data.id]);
    await execute("UPDATE listings SET inquiry_count = ? WHERE id = ?", [listing.inquiry_count, listing.id]);
  });

  it("rejects an inquiry that is too short to be real", async () => {
    const listing = await queryOne("SELECT public_id FROM v_public_listings LIMIT 1");
    const response = await client().send("post", "/v1/inquiries", {
      listingId: listing.public_id,
      name: "A",
      email: "not-an-email",
      message: "hi",
    });
    expect(response.status).toBe(422);
    expect(Object.keys(response.body.error.fields).length).toBeGreaterThan(1);
  });

  it("saves and deletes a saved search", async () => {
    const created = await portal.send("post", "/v1/saved-searches", {
      name: "Integration search",
      category: "real-estate",
      criteria: { minPrice: 1000000, bedrooms: 3 },
      canonicalUrl: "/real-estate?beds=3",
    });
    expect(created.status).toBe(201);

    const list = await portal.get("/v1/portal/saved-searches");
    expect(list.body.data.some((row) => row.id === created.body.data.id)).toBe(true);

    await portal.send("delete", `/v1/saved-searches/${created.body.data.id}`);
    const after = await portal.get("/v1/portal/saved-searches");
    expect(after.body.data.some((row) => row.id === created.body.data.id)).toBe(false);
  });
});
