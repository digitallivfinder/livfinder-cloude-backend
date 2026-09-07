#!/usr/bin/env node
/**
 * Removes rows created by the smoke test and the integration suite.
 *
 * The suites clean up after themselves, but a run that is interrupted — or the
 * smoke test, which exercises the real create path on purpose — can leave a
 * listing or a saved search behind. This removes exactly those and nothing else.
 *
 *   npm run cleanup:test-artifacts
 */
import { rm } from "node:fs/promises";
import path from "node:path";
import { query, queryOne, execute } from "../src/db/query.js";
import { closePool } from "../src/db/pool.js";
import logger from "../src/config/logger.js";
import env from "../src/config/env.js";

const LISTING_TITLES = ["Smoke Test Villa%", "Integration Villa%", "Media Test Apartment%", "Mismatched development%", "Not allowed here%"];
/**
 * Storage prefixes the suites write under. Uploads are content-addressed, so a test image has no
 * distinguishing name — the prefix is what marks it, which is why the tests upload under their
 * own folder rather than the real one.
 */
const TEST_MEDIA_PREFIXES = ["listings/smoke-a/", "listings/smoke-b/", "listings/dedupe/", "listings/one/", "listings/two/", "health/"];

const MEDIA_CHILD_TABLES = ["media_renditions", "media_hashes", "media_exif", "media_attachments", "listing_media"];

const CHILD_TABLES = [
  "listing_search", "listing_media", "listing_features", "listing_attribute_values",
  "listing_status_history", "listing_price_history",
  "listing_real_estate", "listing_vehicle", "listing_marine", "listing_aviation", "listing_timepiece",
  "inquiries", "favourites", "bookings", "offers",
];

export async function cleanupTestArtifacts() {
  const summary = { listings: 0, savedSearches: 0, users: 0, articles: 0, roles: 0, mediaAssets: 0, mediaFiles: 0 };

  const listings = await query(
    `SELECT id, reference FROM listings WHERE ${LISTING_TITLES.map(() => "title LIKE ?").join(" OR ")}`,
    LISTING_TITLES
  );
  for (const listing of listings) {
    for (const table of CHILD_TABLES) {
      await execute(`DELETE FROM ${table} WHERE listing_id = ?`, [listing.id]).catch(() => {});
    }
    await execute("DELETE FROM listings WHERE id = ?", [listing.id]);
    summary.listings += 1;
  }

  summary.savedSearches = (await execute("DELETE FROM saved_searches WHERE name = 'Integration search'")).affectedRows;
  summary.articles = (await execute("DELETE FROM posts WHERE title LIKE 'Integration Article%'")).affectedRows;
  summary.roles = (await execute("DELETE FROM roles WHERE name LIKE 'Integration Role%' AND is_system = 0")).affectedRows;

  const users = await query("SELECT id FROM users WHERE email LIKE '%@example.test'");
  for (const user of users) {
    await execute("DELETE FROM user_sessions WHERE user_id = ?", [user.id]);
    await execute("DELETE FROM user_tokens WHERE user_id = ?", [user.id]);
    await execute("DELETE FROM account_members WHERE user_id = ?", [user.id]);
    await execute("DELETE FROM users WHERE id = ?", [user.id]).catch(() => {});
    summary.users += 1;
  }

  // Uploaded test media: the rows first (so nothing ever points at a missing file), then the
  // files. Only the local driver has files to remove; S3 objects are left to their lifecycle rule.
  for (const prefix of TEST_MEDIA_PREFIXES) {
    const assets = await query("SELECT id FROM media_assets WHERE storage_path LIKE ?", [`%${prefix}%`]);
    for (const asset of assets) {
      for (const table of MEDIA_CHILD_TABLES) {
        await execute(`DELETE FROM ${table} WHERE media_asset_id = ?`, [asset.id]).catch(() => {});
      }
      await execute("DELETE FROM media_assets WHERE id = ?", [asset.id]);
      summary.mediaAssets += 1;
    }
    if (env.STORAGE_DRIVER === "local") {
      const target = path.join(env.LOCAL_STORAGE_PATH, "public", prefix);
      await rm(target, { recursive: true, force: true })
        .then(() => { summary.mediaFiles += 1; })
        .catch(() => {});
    }
  }

  await execute("CALL sp_refresh_listing_search(NULL)", []);
  return summary;
}

const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop());
if (isMain) {
  cleanupTestArtifacts()
    .then(async (summary) => {
      logger.info(summary, "test artifacts removed");
      await closePool();
      process.exit(0);
    })
    .catch(async (error) => {
      logger.error({ err: error }, "cleanup failed");
      await closePool();
      process.exit(1);
    });
}
