import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupListings, cleanupUsers, createDisposablePortalOwner, createTestApiKey, execute, pushFile, query, queryOne } from "../helpers/testApp.js";
import { dismissMapping, listMappings, mappingCandidates, setMapping } from "../../src/modules/feeds/valueMappings.js";
import { closePool } from "../../src/db/pool.js";
import { completeCsv, completeRecord, useFakeImages } from "../helpers/completeListing.js";

/**
 * The mapping queue (Phase 5): a company's own place name that LivFinder does not know fails the
 * listing with a clear reason and joins the admin's queue, scoped to the place it was sent for;
 * once an admin maps it, the next push takes the listing in. Runs on a throwaway account;
 * the mapping rows it creates are removed.
 */

const suffix = Date.now();
const unknownCommunity = `QA Marina Quarter ${suffix}`;
const unknownType = `QA Sky Loft ${suffix}`;
let owner = null;
let accountId = null;
let key = null;
let dubai = null;
let community = null;

const file = () =>
  completeCsv("real-estate", [
    completeRecord("real-estate", "RE-1", {
      title: "Apartment in a place we call our own",
      propertyType: unknownType,
      location: { country: "AE", city: "Dubai", community: unknownCommunity, subCommunity: community.sub_community },
    }),
  ]);
const push = () => pushFile(key, "/listings/real-estate.csv", file(), "text/csv");
// Searched by this run's suffix: the shared queue can hold thousands of real names ahead of these.
const queued = async () => (await listMappings({ status: "unmapped", pageSize: 100, sent: String(suffix) })).rows.filter((row) => row.value.includes(String(suffix)));

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
    `SELECT l.public_id, l.name, s.name AS sub_community FROM locations l
       JOIN locations s ON s.community_id = l.id AND s.level = 'sub_community' AND s.deleted_at IS NULL
      WHERE l.city_id = ? AND l.level = 'community' AND l.deleted_at IS NULL
      ORDER BY l.active_listing_count DESC LIMIT 1`,
    [dubai.id]
  );
  key = await createTestApiKey({ accountId, userId: owner.id });
  useFakeImages();
});

afterAll(async () => {
  const listings = await query("SELECT public_id FROM listings WHERE account_id = ?", [accountId]);
  await cleanupListings(listings.map((item) => item.public_id));
  await execute("DELETE FROM feed_value_mappings WHERE external_value LIKE ?", [`%${suffix}%`]);
  await execute("DELETE FROM integration_connections WHERE account_id = ? AND organization_id IS NULL", [accountId]);
  await execute("DELETE FROM api_clients WHERE account_id = ?", [accountId]);
  if (owner) await cleanupUsers([owner.email]);
  await closePool();
});

describe("the mapping queue", () => {
  it("fails a listing with an unknown place name, and queues the name within its city", async () => {
    const { imports: [result] } = await push();
    expect(result).toMatchObject({ status: "failed" });
    const item = await queryOne(
      "SELECT fi.errors FROM feed_import_items fi JOIN feed_imports r ON r.id = fi.import_id WHERE r.public_id = ?",
      [result.id]
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
    const { imports: [second] } = await push();
    expect(second.status).toBe("failed");
    const typeRow = (await queued()).find((row) => row.type === "category");
    expect(typeRow).toBeTruthy();
    const types = await mappingCandidates(Number(typeRow.id));
    expect(types.map((type) => type.id)).toContain("apartment");
    await setMapping(Number(typeRow.id), { categoryCode: "apartment" });

    const { imports: [third] } = await push();
    expect(third).toMatchObject({ status: "completed" });
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

describe("an unknown sub-community", () => {
  const unknownSub = `QA Tower ${suffix}`;

  it("takes the listing in under its community, keeps the name as its building, and queues it", async () => {
    const csv = completeCsv("real-estate", [
      completeRecord("real-estate", "RE-SUB-1", {
        title: "Apartment in a tower LivFinder does not list yet",
        propertyType: "apartment",
        location: { country: "AE", city: "Dubai", community: community.name, subCommunity: unknownSub },
      }),
    ]);
    const { imports: [result] } = await pushFile(key, "/listings/real-estate.csv", csv, "text/csv");
    expect(result.status, JSON.stringify(result)).toBe("completed");
    const listing = await queryOne(
      `SELECT loc.public_id AS community, l.sub_community_id, d.building_name
         FROM listings l LEFT JOIN locations loc ON loc.id = l.community_id
         LEFT JOIN listing_real_estate d ON d.listing_id = l.id
        WHERE l.account_id = ? AND l.source_reference = 'RE-SUB-1' AND l.deleted_at IS NULL`,
      [accountId]
    );
    expect(listing).toMatchObject({ community: community.public_id, sub_community_id: null, building_name: unknownSub });
    const item = await queryOne(
      "SELECT fi.status, fi.warnings FROM feed_import_items fi JOIN feed_imports r ON r.id = fi.import_id WHERE r.public_id = ?",
      [result.id]
    );
    expect(item.status).toBe("warning");
    expect(JSON.stringify(item.warnings)).toContain(unknownSub);
    expect((await queued()).find((row) => row.value === unknownSub.toLowerCase())).toMatchObject({ type: "location", mapped: false });
  });
});

describe("a sub-community named like one elsewhere", () => {
  it("is taken in under its own community, with a warning that says where LivFinder has that name", async () => {
    const other = await queryOne(
      `SELECT s.name FROM locations s JOIN locations c ON c.id = s.community_id
        WHERE s.level = 'sub_community' AND s.deleted_at IS NULL AND c.id <> (SELECT id FROM locations WHERE public_id = ?)
          AND s.name NOT IN (SELECT name FROM locations WHERE community_id = (SELECT id FROM locations WHERE public_id = ?))
        ORDER BY s.id LIMIT 1`,
      [community.public_id, community.public_id]
    );
    const csv = completeCsv("real-estate", [
      completeRecord("real-estate", "RE-SUB-2", {
        title: "Apartment in a building that shares a name with a place elsewhere",
        propertyType: "apartment",
        location: { country: "AE", city: "Dubai", community: community.name, subCommunity: other.name },
      }),
    ]);
    const { imports: [result] } = await pushFile(key, "/listings/real-estate.csv", csv, "text/csv");
    expect(result.status, JSON.stringify(result)).toBe("completed");
    const item = await queryOne(
      "SELECT fi.status, fi.warnings FROM feed_import_items fi JOIN feed_imports r ON r.id = fi.import_id WHERE r.public_id = ?",
      [result.id]
    );
    expect(item.status).toBe("warning");
    expect(JSON.stringify(item.warnings)).toContain("LivFinder has it in");
    await execute("DELETE FROM feed_value_mappings WHERE external_value = ? AND scope_key = ?", [other.name.toLowerCase(), String(await queryOne("SELECT id FROM locations WHERE public_id = ?", [community.public_id]).then((r) => r.id))]);
  });
});

describe("an import stopped between creating a listing and linking it", () => {
  it("adopts that listing on the next push instead of creating a second copy", async () => {
    const csv = completeCsv("real-estate", [
      completeRecord("real-estate", "RE-HALF-1", {
        title: "Apartment whose first import was cut short",
        propertyType: "apartment",
        location: { country: "AE", city: "Dubai", community: community.name, subCommunity: community.sub_community },
      }),
    ]);
    const first = (await pushFile(key, "/listings/real-estate.csv", csv, "text/csv")).imports[0];
    expect(first.status, JSON.stringify(first)).toBe("completed");
    const made = await queryOne("SELECT id, source, source_reference FROM listings WHERE account_id = ? AND source_reference = 'RE-HALF-1' AND deleted_at IS NULL", [accountId]);
    // Written with the listing itself, not afterwards.
    expect(made).toMatchObject({ source: "feed", source_reference: "RE-HALF-1" });
    // What a stop at that moment leaves behind: the listing, without its link.
    await execute("DELETE FROM external_references WHERE entity_type = 'listing' AND entity_id = ?", [made.id]);

    const again = (await pushFile(key, "/listings/real-estate.csv", csv, "text/csv")).imports[0];
    expect(again.status, JSON.stringify(again)).toBe("completed");
    const rows = await query("SELECT id FROM listings WHERE account_id = ? AND source_reference = 'RE-HALF-1' AND deleted_at IS NULL", [accountId]);
    expect(rows.map((row) => Number(row.id))).toEqual([Number(made.id)]);
  });
});
