import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupListings, cleanupUsers, client, createDisposablePortalOwner, execute, queryOne } from "../helpers/testApp.js";
import { createListingSchema } from "../../src/modules/listings/listings.schemas.js";
import { changeListingStatus, createListing } from "../../src/modules/listings/listings.service.js";
import { decideCategoryAccess, moderateListing } from "../../src/modules/admin/admin.mutations.js";
import { sitemapEntries } from "../../src/modules/public/sitemap.repository.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Sold, rented and withdrawn listings stay reachable (migration 0062).
 *
 * The owner's rule: a closed listing leaves search, lists and ads, but its page keeps working at
 * the same URL with no banner, stays in the sitemap for its ranking, and still takes enquiries.
 * A listing LivFinder itself unpublished is gone; an expired one lapsed and is gone too.
 * Revoking a category withdraws the account's listings in it, the same way.
 *
 * Runs on a throwaway account, so no real company's listings are touched.
 */
const created = [];
const visitorEmail = `qa-closed-${Date.now()}@example.com`;
let owner = null;
let accountId = null;
let city = null;

const row = (publicId) => queryOne("SELECT * FROM listings WHERE public_id = ?", [publicId]);
const publicPage = (publicId) => client().get(`/v1/public/listings/${publicId}`);
const inSearch = async (publicId) => Boolean(await queryOne("SELECT 1 AS ok FROM listing_search WHERE public_id = ?", [publicId]));
const inSitemap = async (path) => (await sitemapEntries("cars")).some((entry) => entry.url === path);

async function liveListing(title) {
  const payload = createListingSchema.parse({
    category: "cars",
    categorySlug: "supercars",
    purpose: "sale",
    title: `${title} ${Date.now()}`,
    description: "<p>Exercises closed-listing reachability.</p>",
    price: 300000,
    currency: "AED",
    locationId: `city:${city.id}`,
    detail: { modelYear: 2022 },
    status: "pending_review",
  });
  const result = await createListing({ payload, accountId, userId: owner.id, organizationId: null, agentId: null, ip: null });
  created.push(result.publicId);
  await changeListingStatus({ listing: await row(result.publicId), toStatus: "active", userId: null, byPlatform: true });
  return row(result.publicId);
}

beforeAll(async () => {
  owner = await createDisposablePortalOwner({ prefix: "closed-listings" });
  ({ account_id: accountId } = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [owner.id]));
  await execute("UPDATE accounts SET listing_quota = NULL, storage_quota = NULL WHERE id = ?", [accountId]);
  city = await queryOne("SELECT id FROM locations WHERE level = 'city' AND status = 'active' LIMIT 1");
});

afterAll(async () => {
  await execute("DELETE FROM crm_contacts WHERE primary_email_normalized = ?", [visitorEmail]);
  await cleanupListings(created);
  if (owner) await cleanupUsers([owner.email]);
  await closePool();
});

describe("a sold listing", () => {
  let listing = null;

  beforeAll(async () => {
    listing = await liveListing("QA closed sold");
    expect((await publicPage(listing.public_id)).status).toBe(200);
    expect(await inSearch(listing.public_id)).toBe(true);
    await changeListingStatus({ listing, toStatus: "sold", userId: owner.id });
  });

  it("leaves search but keeps its page at the same URL", async () => {
    expect(await inSearch(listing.public_id)).toBe(false);
    const page = await publicPage(listing.public_id);
    expect(page.status).toBe(200);
    expect(page.body.data.canonicalPath).toBe(listing.canonical_path);
    const byPath = await client().get(`/v1/public/listings/by-path?path=${encodeURIComponent(listing.canonical_path)}`);
    expect(byPath.body.data?.id).toBe(listing.public_id);
  });

  it("stays in the sitemap", async () => {
    expect(await inSitemap(listing.canonical_path)).toBe(true);
  });

  it("still takes enquiries, which reach the owner", async () => {
    const response = await client().send("post", "/v1/inquiries", {
      listingId: listing.public_id,
      name: "QA Closed Visitor",
      email: visitorEmail,
      message: "Is anything similar coming up for sale?",
      inquiryType: "general",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    const inquiry = await queryOne("SELECT account_id FROM inquiries WHERE listing_id = ? LIMIT 1", [listing.id]);
    expect(Number(inquiry.account_id)).toBe(Number(accountId));
  });
});

describe("listings whose page is gone", () => {
  it("one LivFinder unpublished is a 404 and leaves the sitemap, until approved again", async () => {
    const listing = await liveListing("QA closed unpublished");
    await moderateListing({ identifier: listing.public_id, decision: "unpublish", reason: "Policy", userId: null });
    expect((await row(listing.public_id)).status).toBe("withdrawn");
    expect((await publicPage(listing.public_id)).status).toBe(404);
    expect(await inSitemap(listing.canonical_path)).toBe(false);

    await moderateListing({ identifier: listing.public_id, decision: "approve", userId: null });
    expect((await publicPage(listing.public_id)).status).toBe(200);
    expect(await inSearch(listing.public_id)).toBe(true);
  });

  it("one withdrawn before it was ever published is a 404", async () => {
    const payload = createListingSchema.parse({
      category: "cars",
      categorySlug: "supercars",
      purpose: "sale",
      title: `QA closed never live ${Date.now()}`,
      price: 100000,
      currency: "AED",
      locationId: `city:${city.id}`,
      detail: { modelYear: 2021 },
      status: "pending_review",
    });
    const result = await createListing({ payload, accountId, userId: owner.id, organizationId: null, agentId: null, ip: null });
    created.push(result.publicId);
    await changeListingStatus({ listing: await row(result.publicId), toStatus: "withdrawn", userId: owner.id });
    expect((await publicPage(result.publicId)).status).toBe(404);
  });
});

describe("revoking a category", () => {
  it("withdraws the account's listings in it, and their pages keep working", async () => {
    await execute(
      `INSERT INTO account_category_access (account_id, category_id, status, listing_used, requested_at, created_at)
       VALUES (?, 2, 'approved', 0, NOW(3), NOW(3))
       ON DUPLICATE KEY UPDATE status = 'approved'`,
      [accountId]
    );
    const listing = await liveListing("QA closed revoked");
    const result = await decideCategoryAccess({ accountId, categoryId: "cars", decision: "revoke", userId: null });
    expect(result.listingsWithdrawn).toBeGreaterThanOrEqual(1);
    expect((await row(listing.public_id)).status).toBe("withdrawn");
    expect(await inSearch(listing.public_id)).toBe(false);
    expect((await publicPage(listing.public_id)).status).toBe(200);
  });
});
