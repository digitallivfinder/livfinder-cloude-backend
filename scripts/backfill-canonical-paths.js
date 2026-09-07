#!/usr/bin/env node
/**
 * Rewrites `listings.canonical_path` to the user-facing marketplace URL
 * contract the frontend routes already implement.
 *
 * The seed ships a different shape (it inserts the purpose and uses the ISO
 * country code), which the frontend's `splitMarketplacePath` would read as a
 * country segment. The column stays the single source of truth for a listing's
 * URL — this brings its *value* in line with the routes, rather than having the
 * frontend recompute a URL per request.
 *
 * Idempotent: re-running it is a no-op once every row already matches.
 */
import { query, execute } from "../src/db/query.js";
import { withTransaction } from "../src/db/transaction.js";
import { closePool } from "../src/db/pool.js";
import { buildCanonicalPath } from "../src/utils/canonicalPath.js";
import { categoryByRootId } from "../src/utils/categories.js";
import logger from "../src/config/logger.js";

const BATCH = 500;

function pathFor(row) {
  const definition = categoryByRootId(row.root_category_id);
  if (!definition) return null;
  return buildCanonicalPath({
    rootCategoryId: Number(row.root_category_id),
    slug: row.slug,
    location: {
      country: row.country_slug,
      state: row.state_slug,
      city: row.city_slug,
      community: row.community_slug,
      subCommunity: row.sub_community_slug,
    },
    brandSlug: row.brand_slug,
    modelSlug: row.brand_model_slug,
    year: row.year_value,
  });
}

export async function backfillCanonicalPaths({ dryRun = false } = {}) {
  const rows = await query(
    `SELECT l.id, l.slug, l.canonical_path, l.root_category_id,
            co.slug AS country_slug, st.slug AS state_slug, ct.slug AS city_slug,
            cm.slug AS community_slug, sc.slug AS sub_community_slug,
            br.slug AS brand_slug, bm.slug AS brand_model_slug,
            COALESCE(veh.model_year, mar.build_year, av.year_built, tp.year_of_production) AS year_value
       FROM listings l
       LEFT JOIN locations co ON co.id = l.country_id
       LEFT JOIN locations st ON st.id = l.state_id
       LEFT JOIN locations ct ON ct.id = l.city_id
       LEFT JOIN locations cm ON cm.id = l.community_id
       LEFT JOIN locations sc ON sc.id = l.sub_community_id
       LEFT JOIN brands br ON br.id = l.brand_id
       LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
       LEFT JOIN listing_vehicle veh   ON veh.listing_id = l.id
       LEFT JOIN listing_marine mar    ON mar.listing_id = l.id
       LEFT JOIN listing_aviation av   ON av.listing_id  = l.id
       LEFT JOIN listing_timepiece tp  ON tp.listing_id  = l.id
      WHERE l.deleted_at IS NULL
      ORDER BY l.id`,
    []
  );

  const seen = new Map();
  const updates = [];
  for (const row of rows) {
    let path = pathFor(row);
    if (!path) continue;
    // canonical_path is UNIQUE. Slugs already carry the listing id, so a
    // collision means two rows genuinely share one; disambiguate rather than
    // let the write fail.
    if (seen.has(path)) path = `${path}-${row.id}`;
    seen.set(path, row.id);
    if (path !== row.canonical_path) updates.push({ id: row.id, path });
  }

  if (dryRun) return { total: rows.length, changed: updates.length, updates: updates.slice(0, 10) };

  for (let index = 0; index < updates.length; index += BATCH) {
    const batch = updates.slice(index, index + BATCH);
    // A batch is one transaction: a half-rewritten URL set would 404 live pages.
    await withTransaction(async (connection) => {
      for (const update of batch) {
        await execute("UPDATE listings SET canonical_path = ? WHERE id = ?", [update.path, update.id], connection);
      }
    });
  }

  // The projection carries its own copy of canonical_path.
  await execute("CALL sp_refresh_listing_search(NULL)", []);

  return { total: rows.length, changed: updates.length };
}

const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop());
if (isMain) {
  const dryRun = process.argv.includes("--dry-run");
  backfillCanonicalPaths({ dryRun })
    .then((result) => {
      logger.info(result, dryRun ? "canonical path backfill (dry run)" : "canonical path backfill complete");
      return closePool();
    })
    .then(() => process.exit(0))
    .catch(async (error) => {
      logger.error({ err: error }, "canonical path backfill failed");
      await closePool();
      process.exit(1);
    });
}
