import logger from "../../config/logger.js";
import { callProcedure, execute, query } from "../../db/query.js";
import { changeListingStatus } from "./listings.service.js";
import { refreshListingSearch } from "./listings.repository.js";

/**
 * Listing maintenance that time, not a request, triggers.
 *
 * There was no scheduler at all. A listing past its `expires_at` silently dropped out of the
 * public view (`v_public_listings` checks the date) but kept `status = 'active'`: the owner's
 * portal still called it live, it kept its allowance slot, it stayed in the search projection
 * and the sitemap, and its agent and organisation kept counting it. The integrity suite
 * reported exactly that. This sweep runs at boot and every ten minutes (server.js).
 */

/** Active listings past their end date become `expired` through the ordinary status change. */
export async function expireDueListings({ limit = 500 } = {}) {
  const due = await query(
    `SELECT id, public_id, status, account_id, agent_id, organization_id
       FROM listings
      WHERE status = 'active' AND deleted_at IS NULL
        AND expires_at IS NOT NULL AND expires_at <= NOW(3)
      ORDER BY expires_at
      LIMIT ${Number(limit)}`
  );
  for (const listing of due) {
    // byPlatform: expiry is the platform's transition, not an owner's.
    await changeListingStatus({ listing, toStatus: "expired", reason: "Listing period ended", userId: null, byPlatform: true });
  }
  return due.length;
}

/**
 * Projection rows whose source changed after they were written. A counter bump used to move
 * `updated_at` without a refresh; those writes now leave `updated_at` alone, and this catches
 * anything that still slips through.
 */
export async function refreshStaleProjections({ limit = 500 } = {}) {
  const stale = await query(
    `SELECT s.listing_id
       FROM listing_search s JOIN listings l ON l.id = s.listing_id
      WHERE s.source_updated_at < l.updated_at
      LIMIT ${Number(limit)}`
  );
  for (const row of stale) await refreshListingSearch(row.listing_id);
  return stale.length;
}

/** `sitemap_entries` is seeded, never rebuilt; entries for listings no longer public go. */
export async function pruneSitemapEntries() {
  const result = await execute(
    `DELETE FROM sitemap_entries
      WHERE entity_type = 'listing'
        AND entity_id NOT IN (SELECT id FROM v_public_listings)`
  );
  return result?.affectedRows ?? 0;
}

export async function runListingMaintenance() {
  const expired = await expireDueListings();
  // Every maintained rollup (agents, organisations, categories, brands, allowance usage — the
  // latter by the slot rule since 0053), recomputed from the rows. It runs before the staleness
  // pass so anything it touches is refreshed in the same run.
  await callProcedure("sp_refresh_entity_counters", []);
  const refreshed = await refreshStaleProjections();
  const pruned = await pruneSitemapEntries();
  return { expired, refreshed, pruned };
}

export function startListingMaintenance({ intervalMs = 10 * 60 * 1000 } = {}) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const result = await runListingMaintenance();
      if (result.expired || result.refreshed || result.pruned) logger.info(result, "listing maintenance");
    } catch (error) {
      logger.error({ err: error }, "listing maintenance failed");
    } finally {
      running = false;
    }
  };
  tick();
  const timer = setInterval(tick, intervalMs);
  timer.unref();
  return timer;
}
