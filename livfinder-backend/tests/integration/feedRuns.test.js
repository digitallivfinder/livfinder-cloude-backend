import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupListings, cleanupUsers, createDisposablePortalOwner, execute, query, queryOne } from "../helpers/testApp.js";
import { getAccountFeed, requestRun, saveAccountFeed } from "../../src/modules/feeds/feedSources.repository.js";
import { discardHeldRun, releaseHeldRun, removalNeedsHold, runFeed } from "../../src/modules/feeds/feedRunner.js";
import { closePool } from "../../src/db/pool.js";

/**
 * A company's feed, end to end (0063), on a throwaway individual account (no organization, so
 * the individual path is covered too). The network is stood in for; everything else is real:
 * the run, the import, the listings, the removals and the safety hold.
 */

let owner = null;
let accountId = null;
let feed = null;
let city = null;
const header = "externalId,title,price,currency,country,city,modelYear,transmission";
const row = (id, title, year = 2022) => `${id},${title},300000,AED,${city.country},${city.name},${year},automatic`;
const csv = (...rows) => `${[header, ...rows].join("\n")}\n`;

/** A stand-in for the feed's server: the given body, or a 304 when asked conditionally. */
const serve = (body, { etag = '"v1"', notModified = false } = {}) => async (url, { conditional }) =>
  notModified && conditional
    ? { notModified: true }
    : { buffer: Buffer.from(body), etag, lastModified: null, contentType: body.startsWith("<") ? "application/xml" : "text/csv", finalUrl: url };

const listingsOf = () =>
  query(
    `SELECT l.public_id, l.status, l.source, er.external_id, er.remote_status
       FROM listings l
       JOIN external_references er ON er.entity_id = l.id AND er.entity_type = 'listing'
       JOIN integration_connections ic ON ic.id = er.connection_id AND ic.account_id = ? AND ic.organization_id IS NULL
      WHERE l.account_id = ? AND l.deleted_at IS NULL
      ORDER BY er.external_id`,
    [accountId, accountId]
  );
const byId = async (externalId) => (await listingsOf()).find((item) => item.external_id === externalId);
const runRow = (publicId) => queryOne("SELECT * FROM feed_imports WHERE public_id = ?", [publicId]);
const goLive = async (...ids) => {
  for (const id of ids) {
    const listing = await byId(id);
    await execute(
      "UPDATE listings SET status = 'active', moderation_status = 'approved', published_at = NOW(3), expires_at = DATE_ADD(NOW(3), INTERVAL 90 DAY) WHERE public_id = ?",
      [listing.public_id]
    );
  }
};

beforeAll(async () => {
  owner = await createDisposablePortalOwner({ prefix: "feed-runs" });
  ({ account_id: accountId } = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [owner.id]));
  await execute("UPDATE accounts SET listing_quota = NULL, storage_quota = NULL WHERE id = ?", [accountId]);
  await execute(
    `INSERT INTO account_category_access (account_id, category_id, status, listing_used, requested_at, created_at)
     VALUES (?, 2, 'approved', 0, NOW(3), NOW(3)) ON DUPLICATE KEY UPDATE status = 'approved'`,
    [accountId]
  );
  await execute(
    `INSERT INTO account_addons (public_id, account_id, addon_code, status, started_at)
     VALUES (?, ?, 'integrations', 'active', NOW(3)) ON DUPLICATE KEY UPDATE status = 'active'`,
    [`01QAFEED${String(Date.now()).slice(-10)}${accountId}`.slice(0, 26).padEnd(26, "0"), accountId]
  );
  city = await queryOne(
    `SELECT ci.name, co.name AS country FROM locations ci JOIN locations co ON co.id = ci.country_id
      WHERE ci.level = 'city' AND ci.status = 'active' AND co.slug = 'united-arab-emirates' LIMIT 1`
  );
  feed = await saveAccountFeed({ accountId, organizationId: null, category: "cars", url: "https://feeds.example.com/cars.csv", userId: owner.id });
});

afterAll(async () => {
  const listings = await query("SELECT public_id FROM listings WHERE account_id = ?", [accountId]);
  await cleanupListings(listings.map((item) => item.public_id));
  await execute("DELETE FROM integration_connections WHERE account_id = ? AND organization_id IS NULL", [accountId]);
  await execute("DELETE FROM notifications WHERE type LIKE 'feed.%' AND user_id = ?", [owner.id]);
  if (owner) await cleanupUsers([owner.email]);
  await closePool();
});

describe("a feed run", () => {
  it("imports every entry as a draft, from the feed, into the account", async () => {
    const result = await runFeed(feed.id, { fetchFile: serve(csv(row("CAR-1", "First car"), row("CAR-2", "Second car"), row("CAR-3", "Third car"))) });
    expect(result, JSON.stringify(result)).toMatchObject({ outcome: "imported", status: "completed" });
    const listings = await listingsOf();
    expect(listings.map((item) => [item.external_id, item.status, item.source])).toEqual([
      ["CAR-1", "draft", "feed"],
      ["CAR-2", "draft", "feed"],
      ["CAR-3", "draft", "feed"],
    ]);
    const run = await runRow(result.importId);
    expect(Number(run.feed_source_id)).toBe(Number(feed.id));
    expect(run.created_count).toBe(3);
  });

  it("does nothing when the file has not changed, or the server says so", async () => {
    const same = csv(row("CAR-1", "First car"), row("CAR-2", "Second car"), row("CAR-3", "Third car"));
    expect((await runFeed(feed.id, { conditional: false, fetchFile: serve(same) })).outcome).toBe("unchanged");
    expect((await runFeed(feed.id, { fetchFile: serve(same, { notModified: true }) })).outcome).toBe("not_modified");
  });

  it("withdraws a live listing that left the file; its page stays reachable", async () => {
    await goLive("CAR-1", "CAR-2", "CAR-3");
    const result = await runFeed(feed.id, { fetchFile: serve(csv(row("CAR-1", "First car"), row("CAR-2", "Second car"))) });
    expect(result).toMatchObject({ outcome: "imported", removed: 1, held: false });
    expect(await byId("CAR-3")).toMatchObject({ status: "withdrawn", remote_status: "removed" });
    expect((await byId("CAR-1")).status).toBe("active");
  });

  it("sends a listing that comes back into the file to the queue, not straight live", async () => {
    await runFeed(feed.id, { fetchFile: serve(csv(row("CAR-1", "First car"), row("CAR-2", "Second car"), row("CAR-3", "Third car back"))) });
    expect(await byId("CAR-3")).toMatchObject({ status: "pending_review", remote_status: "live" });
  });

  it("holds a run that would take too many listings at once, until an admin decides", async () => {
    const result = await runFeed(feed.id, { fetchFile: serve(csv()) });
    expect(result).toMatchObject({ outcome: "imported", held: true, waiting: 3 });
    expect((await runRow(result.importId)).status).toBe("held_for_review");
    expect((await listingsOf()).every((item) => item.status !== "withdrawn")).toBe(true);
    expect((await getAccountFeed(accountId, "cars")).held_import_id).toBeTruthy();

    const kept = await discardHeldRun(result.importId);
    expect(kept.status).not.toBe("held_for_review");
    expect((await listingsOf()).every((item) => item.status !== "withdrawn")).toBe(true);

    // The same empty file again changes nothing (the admin kept the listings); a new one is held again.
    expect((await runFeed(feed.id, { conditional: false, fetchFile: serve(csv()) })).outcome).toBe("unchanged");
    const again = await runFeed(feed.id, { fetchFile: serve(`${header}\r\n`, { etag: '"v-empty-2"' }) });
    expect(again.held).toBe(true);
    const released = await releaseHeldRun(again.importId);
    expect(released.withdrawn).toBe(3);
    expect((await listingsOf()).every((item) => item.status === "withdrawn")).toBe(true);
  });

  it("records a file it cannot read as a failed run, with the reason", async () => {
    const result = await runFeed(feed.id, { fetchFile: serve("<livfinder-feed category=\"yachts\" version=\"1\"></livfinder-feed>") });
    expect(result.outcome).toBe("failed");
    expect(result.error).toMatch(/set up for cars/);
    const saved = await getAccountFeed(accountId, "cars");
    expect(saved.consecutive_failures).toBeGreaterThanOrEqual(1);
    expect((await runRow(saved.last_import_public_id)).status).toBe("failed");
  });

  it("does not fetch while the Integrations add-on is off", async () => {
    await execute("UPDATE account_addons SET status = 'cancelled' WHERE account_id = ?", [accountId]);
    try {
      expect((await runFeed(feed.id, { fetchFile: serve(csv(row("CAR-9", "Ninth car"))) })).outcome).toBe("addon_inactive");
      expect(await byId("CAR-9")).toBeUndefined();
    } finally {
      await execute("UPDATE account_addons SET status = 'active' WHERE account_id = ?", [accountId]);
    }
  });
});

describe("asking for a run", () => {
  it("fetches at most once every two minutes, however often it is asked", async () => {
    await execute("UPDATE feed_sources SET last_checked_at = NOW(3) WHERE id = ?", [feed.id]);
    const { at } = await requestRun(feed.id);
    expect(new Date(at).getTime()).toBeGreaterThan(Date.now() + 60_000);
    await execute("UPDATE feed_sources SET last_checked_at = DATE_SUB(NOW(3), INTERVAL 5 MINUTE) WHERE id = ?", [feed.id]);
    const later = await requestRun(feed.id);
    expect(new Date(later.at).getTime()).toBeLessThanOrEqual(Date.now() + 1000);
  });
});

describe("the removal safety valve", () => {
  it("holds a mass removal but lets small, normal ones through", () => {
    expect(removalNeedsHold(3, 3, 20)).toBe(true);
    expect(removalNeedsHold(2, 10, 20)).toBe(false);
    expect(removalNeedsHold(30, 100, 20)).toBe(true);
    expect(removalNeedsHold(20, 100, 20)).toBe(false);
    expect(removalNeedsHold(1, 2, 20)).toBe(false);
  });
});
