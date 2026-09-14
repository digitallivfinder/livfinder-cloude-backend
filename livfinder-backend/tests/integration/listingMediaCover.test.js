import { afterAll, beforeAll, describe, expect, it } from "vitest";
import sharp from "sharp";
import { client, cleanupListings, ensureTestPassword, queryOne } from "../helpers/testApp.js";
import { query } from "../../src/db/query.js";
import { closePool } from "../../src/db/pool.js";

/**
 * The gallery cover contract, exercised per category against the real database:
 *
 *   1. every image the add-listing form carried into create is attached;
 *   2. setting the cover on image k writes image k's URL to `listings.cover_image_url`
 *      (the denormalised field the cards and the search projection read);
 *   3. deleting the cover promotes another image — the row's `is_cover` and the
 *      listing's `cover_image_url` both move to a surviving photo, never to null
 *      while an image remains.
 *
 * The cover / counter logic lives in `media/listingMedia.service.js`
 * (`syncListingMediaCounters`) and is category-independent — the same
 * `/v1/media/listings/:id/*` endpoints back the admin listing-detail media tab
 * and the client-portal media manager, so this covers both surfaces. Helicopters
 * have no seeded `account_category_access` row locally, so they cannot be created
 * here; jets share the exact code path.
 */
const PASSWORD = "LivFinder!2026";
const created = [];

async function png(seed = 1) {
  return sharp({ create: { width: 300, height: 200, channels: 3, background: { r: 20 + seed * 25, g: 80, b: 140 } } })
    .png()
    .toBuffer();
}

/** An active portal owner whose account is approved for `categoryId`. */
async function ownerForCategory(categoryId) {
  return queryOne(
    `SELECT u.email
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
       JOIN account_category_access aca ON aca.account_id = a.id AND aca.status = 'approved' AND aca.category_id = ?
      WHERE u.status = 'active' AND u.deleted_at IS NULL
      ORDER BY u.id LIMIT 1`,
    [categoryId]
  );
}

const CASES = [
  { category: "real-estate", categoryId: 1, categorySlug: "apartments", locationLevel: "community", detail: { bedrooms: 1, bathrooms: 1, builtAreaSqft: 700 } },
  { category: "cars", categoryId: 2, categorySlug: "supercars", locationLevel: "city", detail: { year: 2023 } },
  { category: "yachts", categoryId: 3, categorySlug: "motor-yachts", locationLevel: "city", detail: { buildYear: 2020 } },
  { category: "jets", categoryId: 4, categorySlug: "light-jets", locationLevel: "city", detail: { yearBuilt: 2019 } },
  { category: "watches", categoryId: 6, categorySlug: "dive-watches", locationLevel: "city", detail: {} },
];

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
});

afterAll(async () => {
  await cleanupListings(created);
  await closePool();
});

async function locationRef(level) {
  const row = await queryOne(
    `SELECT id FROM locations WHERE level = ? AND status = 'active'${level === "community" ? " AND active_listing_count > 0" : ""} LIMIT 1`,
    [level]
  );
  return `${level}:${row.id}`;
}

async function coverUrl(publicId) {
  const row = await queryOne("SELECT cover_image_url FROM listings WHERE public_id = ?", [publicId]);
  return row?.cover_image_url ?? null;
}

describe.each(CASES)("gallery cover contract — $category", ({ category, categoryId, categorySlug, locationLevel, detail }) => {
  const portal = client();
  let publicId = null;
  const images = () =>
    portal
      .get(`/v1/media/listings/${publicId}/media`)
      .then((response) => response.body.data.filter((row) => row.mediaType === "image"));

  beforeAll(async () => {
    const owner = await ownerForCategory(categoryId);
    expect(owner, `a seeded owner with category ${categoryId} access`).toBeTruthy();
    await portal.login(owner.email, PASSWORD);

    const uploaded = await portal.agent
      .post("/v1/media/upload")
      .set("X-CSRF-Token", portal.csrfToken)
      .set("Accept", "application/json")
      .attach("files", await png(1), "one.png")
      .attach("files", await png(2), "two.png")
      .attach("files", await png(3), "three.png");
    expect(uploaded.status).toBe(201);
    const mediaAssetIds = uploaded.body.data.map((row) => row.assetId);
    expect(mediaAssetIds).toHaveLength(3);

    const response = await portal.send("post", "/v1/portal/listings", {
      category,
      categorySlug,
      purpose: "sale",
      title: `Cover contract ${category} ${Date.now()}`,
      description: "<p>Cover contract</p>",
      price: 1500000,
      currency: "AED",
      locationId: await locationRef(locationLevel),
      detail,
      mediaAssetIds,
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    publicId = response.body.data.id;
    created.push(publicId);
  });

  it("attaches every image carried into create, with exactly one cover", async () => {
    const gallery = await images();
    expect(gallery).toHaveLength(3);
    expect(gallery.filter((row) => row.isCover)).toHaveLength(1);
    // The denormalised field agrees with the flagged row.
    expect(await coverUrl(publicId)).toBe(gallery.find((row) => row.isCover).url);
  });

  it("moves listings.cover_image_url when the cover is set on another image", async () => {
    const gallery = await images();
    const target = gallery.find((row) => !row.isCover);
    const patched = await portal.send("patch", `/v1/media/listings/${publicId}/media/${target.mediaId}`, {
      isCover: true,
    });
    expect(patched.status).toBe(200);

    const after = await images();
    const cover = after.filter((row) => row.isCover);
    expect(cover).toHaveLength(1);
    expect(cover[0].mediaId).toBe(target.mediaId);
    expect(await coverUrl(publicId)).toBe(target.url);
  });

  it("promotes another image when the cover is deleted", async () => {
    const before = await images();
    const cover = before.find((row) => row.isCover);
    const survivors = before.filter((row) => row.mediaId !== cover.mediaId).map((row) => row.url);

    const deleted = await portal.send("delete", `/v1/media/listings/${publicId}/media/${cover.mediaId}`);
    expect(deleted.status).toBe(200);

    const after = await images();
    expect(after).toHaveLength(2);
    const newCover = after.filter((row) => row.isCover);
    expect(newCover).toHaveLength(1);
    expect(survivors).toContain(newCover[0].url);
    // The listing's denormalised cover followed the promotion and is still a real image.
    const url = await coverUrl(publicId);
    expect(url).toBe(newCover[0].url);
    expect(survivors).toContain(url);
  });
});
