import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupListings, cleanupUsers, createDisposablePortalOwner, execute, queryOne } from "../helpers/testApp.js";
import { createListingSchema } from "../../src/modules/listings/listings.schemas.js";
import { changeListingStatus, createListing } from "../../src/modules/listings/listings.service.js";
import { closePool } from "../../src/db/pool.js";

/**
 * The plan's two listing limits (migration 0059), on a throwaway account so no real company's
 * limits are touched:
 *
 * - storage: every listing the account holds except archived ones;
 * - live: listings live or waiting for approval, plus an optional cap per category.
 */
const created = [];
let owner = null;
let accountId = null;
let city = null;

const usage = () => queryOne("SELECT listing_used, storage_used FROM accounts WHERE id = ?", [accountId]);
const listingRow = (publicId) => queryOne("SELECT * FROM listings WHERE public_id = ?", [publicId]);

async function make(status) {
  const payload = createListingSchema.parse({
    category: "cars",
    categorySlug: "supercars",
    purpose: "sale",
    title: `QA limits ${Date.now()} ${created.length}`,
    description: "<p>Exercises the live and storage limits.</p>",
    price: 300000,
    currency: "AED",
    locationId: `city:${city.id}`,
    detail: { modelYear: 2022 },
    status,
  });
  const result = await createListing({ payload, accountId, userId: owner.id, organizationId: null, agentId: null, ip: null });
  created.push(result.publicId ?? result.id);
  return listingRow(result.publicId ?? result.id);
}

beforeAll(async () => {
  owner = await createDisposablePortalOwner({ prefix: "listing-limits" });
  ({ account_id: accountId } = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [owner.id]));
  await execute("UPDATE accounts SET listing_quota = 1, storage_quota = 2 WHERE id = ?", [accountId]);
  city = await queryOne("SELECT id FROM locations WHERE level = 'city' AND status = 'active' LIMIT 1");
});

afterAll(async () => {
  await cleanupListings(created.filter(Boolean));
  if (owner) await cleanupUsers([owner.email]);
  await closePool();
});

describe("live and storage limits", () => {
  let draft = null;
  let submitted = null;

  it("a draft takes storage but no live slot", async () => {
    draft = await make("draft");
    expect(await usage()).toMatchObject({ listing_used: 0, storage_used: 1 });
  });

  it("a listing submitted for review takes a live slot too", async () => {
    submitted = await make("pending_review");
    expect(await usage()).toMatchObject({ listing_used: 1, storage_used: 2 });
  });

  it("refuses a new listing once storage is full", async () => {
    await expect(make("draft")).rejects.toMatchObject({ status: 409, code: "STORAGE_LIMIT_REACHED" });
  });

  it("refuses to submit a draft once the live limit is reached", async () => {
    await expect(changeListingStatus({ listing: draft, toStatus: "pending_review", userId: owner.id })).rejects.toMatchObject({
      status: 409,
      code: "LIVE_LIMIT_REACHED",
    });
  });

  it("withdrawing frees the live slot but keeps the storage", async () => {
    await changeListingStatus({ listing: submitted, toStatus: "withdrawn", userId: owner.id });
    expect(await usage()).toMatchObject({ listing_used: 0, storage_used: 2 });
  });

  it("archiving frees storage", async () => {
    await changeListingStatus({ listing: await listingRow(submitted.public_id), toStatus: "archived", userId: owner.id });
    expect(await usage()).toMatchObject({ listing_used: 0, storage_used: 1 });
  });

  it("holds an account to the live cap of a category", async () => {
    await execute("UPDATE accounts SET listing_quota = NULL WHERE id = ?", [accountId]);
    await execute(
      `INSERT INTO account_category_access (account_id, category_id, status, listing_quota, listing_used, requested_at, created_at)
       VALUES (?, 2, 'approved', 0, 0, NOW(3), NOW(3))
       ON DUPLICATE KEY UPDATE listing_quota = 0`,
      [accountId]
    );
    await expect(changeListingStatus({ listing: draft, toStatus: "pending_review", userId: owner.id })).rejects.toMatchObject({
      status: 409,
      code: "CATEGORY_LIVE_LIMIT_REACHED",
    });
    await execute("UPDATE account_category_access SET listing_quota = NULL WHERE account_id = ? AND category_id = 2", [accountId]);
    await changeListingStatus({ listing: draft, toStatus: "pending_review", userId: owner.id });
    expect(await usage()).toMatchObject({ listing_used: 1, storage_used: 1 });
  });
});
