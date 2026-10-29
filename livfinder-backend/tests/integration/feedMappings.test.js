import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupListings, cleanupUsers, createDisposablePortalOwner, execute, query, queryOne } from "../helpers/testApp.js";
import { saveAccountFeed } from "../../src/modules/feeds/feedSources.repository.js";
import { runFeed } from "../../src/modules/feeds/feedRunner.js";
import { dismissMapping, listMappings, mappingCandidates, setMapping } from "../../src/modules/feeds/valueMappings.js";
import { closePool } from "../../src/db/pool.js";

/**
 * The mapping queue (Phase 5): a company's own place name that LivFinder does not know fails the
 * listing with a clear reason and joins the admin's queue, scoped to the place it was sent for;
 * once an admin maps it, the feed's next run takes the listing in. Runs on a throwaway account;
 * the mapping rows it creates are removed.
 */

const suffix = Date.now();
const unknownCommunity = `QA Marina Quarter ${suffix}`;
const unknownType = `QA Sky Loft ${suffix}`;
let owner = null;
let accountId = null;
let feed = null;
let dubai = null;
let community = null;

const header = "externalId,title,price,currency,country,city,community,propertyType,bedrooms";
const file = `${header}\nRE-1,Apartment in a place we call our own,1500000,AED,AE,Dubai,${unknownCommunity},${unknownType},2\n`;
const serve = (body) => async (url) => ({ buffer: Buffer.from(body), etag: null, lastModified: null, contentType: "text/csv", finalUrl: url });
const queued = async () => (await listMappings({ status: "unmapped", pageSize: 100 })).rows.filter((row) => row.value.includes(String(suffix)));

beforeAll(async () => {
  owner = await createDisposablePortalOwner({ prefix: "feed-mappings" });
  ({ account_id: accountId } = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [owner.id]));
  await execute("UPDATE accounts SET listing_quota = NULL, storage_quota = NULL WHERE id = ?", [accountId]);
  await execute(
    `INSERT INTO account_category_access (account_id, category_id, status, listing_used, requested_at, created_at)
     VALUES (?, 1, 'approved', 0, NOW(3), NOW(3)) ON DUPLICATE KEY UPDATE status = 'approved'`,
    [accountId]
  );
  await execute(
    `INSERT INTO account_addons (public_id, account_id, addon_code, status, started_at)
     VALUES (?, ?, 'integrations', 'active', NOW(3)) ON DUPLICATE KEY UPDATE status = 'active'`,
    [`01QAMAP${String(suffix).slice(-10)}${accountId}`.slice(0, 26).padEnd(26, "0"), accountId]
  );
  dubai = await queryOne(
    `SELECT ci.id FROM locations ci JOIN locations co ON co.id = ci.country_id
      WHERE ci.level = 'city' AND ci.slug = 'dubai' AND co.slug = 'united-arab-emirates' AND ci.deleted_at IS NULL LIMIT 1`
  );
  community = await queryOne(
    "SELECT public_id, name FROM locations WHERE city_id = ? AND level = 'community' AND deleted_at IS NULL ORDER BY active_listing_count DESC LIMIT 1",
    [dubai.id]
  );
  feed = await saveAccountFeed({ accountId, organizationId: null, category: "real-estate", url: "https://feeds.example.com/re.csv", userId: owner.id });
});

afterAll(async () => {
  const listings = await query("SELECT public_id FROM listings WHERE account_id = ?", [accountId]);
  await cleanupListings(listings.map((item) => item.public_id));
  await execute("DELETE FROM feed_value_mappings WHERE external_value LIKE ?", [`%${suffix}%`]);
  await execute("DELETE FROM integration_connections WHERE account_id = ? AND organization_id IS NULL", [accountId]);
  if (owner) await cleanupUsers([owner.email]);
  await closePool();
});

describe("the mapping queue", () => {
  it("fails a listing with an unknown place name, and queues the name within its city", async () => {
    const result = await runFeed(feed.id, { fetchFile: serve(file) });
    expect(result).toMatchObject({ outcome: "imported", status: "failed" });
    const item = await queryOne(
      "SELECT fi.errors FROM feed_import_items fi JOIN feed_imports r ON r.id = fi.import_id WHERE r.public_id = ?",
      [result.importId]
    );
    expect(JSON.stringify(item.errors)).toContain(unknownCommunity);

    const [row] = await queued();
    expect(row).toMatchObject({ type: "location", value: unknownCommunity.toLowerCase(), scope: String(dubai.id), mapped: false });
  });

  it("offers places inside that city, and once mapped the next run imports the listing", async () => {
    const [locationRow] = await queued();
    const candidates = await mappingCandidates(Number(locationRow.id), community.name);
    expect(candidates.map((candidate) => candidate.id)).toContain(community.public_id);
    await setMapping(Number(locationRow.id), { locationId: community.public_id });

    // The property type is unknown too: the run fails on it next, and queues it.
    const second = await runFeed(feed.id, { fetchFile: serve(file) });
    expect(second.status).toBe("failed");
    const typeRow = (await queued()).find((row) => row.type === "category");
    expect(typeRow).toBeTruthy();
    const types = await mappingCandidates(Number(typeRow.id));
    expect(types.map((type) => type.id)).toContain("apartment");
    await setMapping(Number(typeRow.id), { categoryCode: "apartment" });

    const third = await runFeed(feed.id, { fetchFile: serve(file) });
    expect(third).toMatchObject({ outcome: "imported", status: "completed" });
    const listing = await queryOne(
      `SELECT l.status, c.code AS type, loc.public_id AS community
         FROM listings l JOIN categories c ON c.id = l.category_id LEFT JOIN locations loc ON loc.id = l.community_id
        WHERE l.account_id = ? AND l.deleted_at IS NULL`,
      [accountId]
    );
    expect(listing).toMatchObject({ status: "draft", type: "apartment", community: community.public_id });
    expect(await queued()).toEqual([]);
  });

  it("drops a value from the queue when an admin dismisses it", async () => {
    await execute(
      `INSERT INTO feed_value_mappings (provider_id, connection_id, mapping_type, direction, external_value, external_label, scope_key, is_unmapped, seen_count)
       SELECT id, NULL, 'location', 'inbound', ?, 'typo', ?, 1, 1 FROM integration_providers WHERE code = 'livfinder_import'`,
      [`qa typo ${suffix}`, String(dubai.id)]
    );
    const [row] = await queued();
    await dismissMapping(Number(row.id));
    expect(await queued()).toEqual([]);
  });
});
