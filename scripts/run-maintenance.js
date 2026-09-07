#!/usr/bin/env node
/**
 * The scheduled maintenance pass.
 *
 * Every derived structure in this schema assumes a job keeps it honest: the
 * search projection, the entity counters, the location tree, and the operational
 * reapers that clear a crashed worker's claim. Without them the integrity checks
 * legitimately report a growing backlog — they are measuring the absence of this
 * job, not corrupt data.
 *
 * Safe to run repeatedly and safe to run while the API is serving.
 *
 *   npm run maintenance                # everything
 *   npm run maintenance -- --only reapers
 */
import { query, queryValue, execute, callProcedure } from "../src/db/query.js";
import { closePool } from "../src/db/pool.js";
import logger from "../src/config/logger.js";

const VISIBILITY_TIMEOUT_MINUTES = 5;

/** Returns a crashed worker's claim to the queue, or dead-letters it. */
async function reapQueueMessages() {
  const stuck = await query(
    `SELECT id, queue_id, message_type, payload, attempts, max_attempts, last_error, error_class, organization_id, created_at
       FROM queue_messages
      WHERE status = 'processing' AND visible_at < NOW(3)`
  );

  let redelivered = 0;
  let deadLettered = 0;
  for (const message of stuck) {
    const limit = message.max_attempts ?? 5;
    if (Number(message.attempts) >= limit) {
      await execute(
        `INSERT INTO dead_letter_messages
           (queue_id, original_message_id, message_type, payload, attempts, first_failed_at,
            last_failed_at, error_class, last_error, organization_id, status, created_at)
         VALUES (?, ?, ?, ?, ?, ?, NOW(3), ?, ?, ?, 'new', NOW(3))`,
        [
          message.queue_id,
          message.id,
          message.message_type,
          typeof message.payload === "string" ? message.payload : JSON.stringify(message.payload ?? {}),
          message.attempts,
          message.created_at,
          message.error_class || "VisibilityTimeout",
          message.last_error || "The worker did not release its claim before the visibility timeout.",
          message.organization_id,
        ]
      );
      await execute("UPDATE queue_messages SET status = 'dead_lettered' WHERE id = ?", [message.id]);
      deadLettered += 1;
    } else {
      await execute(
        `UPDATE queue_messages
            SET status = 'pending', claimed_by = NULL, claimed_at = NULL, started_at = NULL,
                visible_at = NOW(3), available_at = NOW(3)
          WHERE id = ?`,
        [message.id]
      );
      redelivered += 1;
    }
  }
  return { redelivered, deadLettered };
}

/** Releases search-index claims whose worker never came back. */
async function reapSearchIndexQueue() {
  const result = await execute(
    `UPDATE search_index_queue
        SET status = 'pending', claimed_by = NULL, claimed_at = NULL,
            attempts = attempts + 1, available_at = NOW(3)
      WHERE status = 'processing' AND claimed_at < DATE_SUB(NOW(3), INTERVAL ? MINUTE)`,
    [VISIBILITY_TIMEOUT_MINUTES]
  );
  return { requeued: result.affectedRows };
}

/** Removes locks whose holder crashed; releasing a lock deletes its row. */
async function reapDistributedLocks() {
  const result = await execute("DELETE FROM distributed_locks WHERE expires_at < NOW(3)");
  return { released: result.affectedRows };
}

/** Moves an open breaker to half-open once its cooldown has elapsed. */
async function advanceCircuitBreakers() {
  const result = await execute(
    `UPDATE circuit_breakers
        SET state = 'half_open', half_open_at = NOW(3), success_count = 0, updated_at = NOW(3)
      WHERE state = 'open' AND opened_at < DATE_SUB(NOW(3), INTERVAL cooldown_seconds SECOND)`
  );
  return { halfOpened: result.affectedRows };
}

/** Expires listings whose window has closed and drops them from the projection. */
async function expireListings() {
  const expiring = await query(
    "SELECT id FROM listings WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at <= NOW(3)"
  );
  for (const listing of expiring) {
    await execute("UPDATE listings SET status = 'expired' WHERE id = ?", [listing.id]);
    await execute(
      `INSERT INTO listing_status_history (listing_id, from_status, to_status, reason, changed_at)
       VALUES (?, 'active', 'expired', 'expiry sweep', NOW(3))`,
      [listing.id]
    );
    // A listing that has left public visibility must leave the sitemap with it.
    // Expiring without this is what left eight expired listings advertised to
    // crawlers — the integrity suite's "sitemap entry for a non-public listing".
    await execute("DELETE FROM sitemap_entries WHERE entity_type = 'listing' AND entity_id = ?", [listing.id]);
  }
  return { expired: expiring.length };
}

/**
 * Reconciles the sitemap against public visibility.
 *
 * Expiry is not the only way a listing stops being public — it can be archived,
 * withdrawn, unpublished or soft-deleted by a portal or admin action. Rather than
 * trust every one of those paths to remember, the sitemap is settled here against
 * `v_public_listings`, which is the same view the integrity check uses.
 */
async function reconcileSitemap() {
  const removed = await execute(
    `DELETE FROM sitemap_entries
      WHERE entity_type = 'listing'
        AND entity_id NOT IN (SELECT id FROM v_public_listings)`
  );
  return { removed: removed?.affectedRows ?? 0 };
}

/**
 * Settles any projection row the integrity suite would still call stale.
 *
 * `sp_refresh_listing_search(NULL)` rebuilds the projection, but it leaves
 * `source_updated_at` behind for rows whose derived content did not actually change —
 * so a listing touched in a way that moved `listings.updated_at` without changing what
 * the projection stores stays flagged forever. Refreshing those rows one at a time
 * closes the gap; on a settled database this finds nothing and does nothing.
 */
async function reconcileProjection() {
  const stale = await query(
    `SELECT s.listing_id
       FROM listing_search s
       JOIN listings l ON l.id = s.listing_id
      WHERE s.source_updated_at < l.updated_at
      LIMIT 500`
  );
  for (const row of stale) {
    await callProcedure("sp_refresh_listing_search", [row.listing_id]);
  }
  return { refreshed: stale.length };
}

/**
 * Rebuilds `property_units.listing_count` from the listings themselves.
 *
 * `sp_refresh_entity_counters` does not cover it, so the counter drifted every time a
 * listing was attached to, moved between or removed from a unit — twenty units
 * disagreed with their own listings.
 */
async function reconcileUnitCounts() {
  const fixed = await execute(
    `UPDATE property_units u
       LEFT JOIN (
         SELECT unit_id, COUNT(*) AS n
           FROM listings
          WHERE unit_id IS NOT NULL
          GROUP BY unit_id
       ) l ON l.unit_id = u.id
        SET u.listing_count = COALESCE(l.n, 0)
      WHERE u.listing_count <> COALESCE(l.n, 0)`
  );
  return { corrected: fixed?.affectedRows ?? 0 };
}

/** Consumes any outstanding search-index work by refreshing the projection. */
async function drainSearchIndexQueue() {
  const pending = await query(
    `SELECT id, subject_id FROM search_index_queue
      WHERE status = 'pending' AND subject_type = 'listing' AND available_at <= NOW(3)
      ORDER BY priority ASC, id ASC LIMIT 2000`
  );
  for (const item of pending) {
    await callProcedure("sp_refresh_listing_search", [item.subject_id]);
    await execute(
      "UPDATE search_index_queue SET status = 'completed', processed_at = NOW(3), claimed_by = NULL WHERE id = ?",
      [item.id]
    );
  }
  return { indexed: pending.length };
}

/**
 * Rebuilds the derived counters, the location tree and the daily analytics rows.
 *
 * `listing_daily_stats` is written incrementally as enquiries and views arrive, which is right
 * for the hot path but drifts whenever rows are removed afterwards — a deleted enquiry leaves
 * its count behind. `db/seeds/049_demo_finalise.sql` asserts the two reconcile, so this pass
 * settles them: the `inquiries` table is the source of truth and the daily rows are rewritten
 * from it.
 *
 * Only days that actually disagree are touched, so a normal pass over a consistent database
 * writes nothing.
 */
async function refreshDerived() {
  await callProcedure("sp_refresh_listing_search", [null]);
  await callProcedure("sp_refresh_entity_counters", []);
  await callProcedure("sp_location_refresh_counts", []);

  const drifted = await query(
    `SELECT l.id
       FROM listings l
       LEFT JOIN (SELECT listing_id, SUM(inquiries) n FROM listing_daily_stats GROUP BY listing_id) d
              ON d.listing_id = l.id
       LEFT JOIN (SELECT listing_id, COUNT(*) n FROM inquiries WHERE deleted_at IS NULL GROUP BY listing_id) i
              ON i.listing_id = l.id
      WHERE COALESCE(d.n, 0) <> COALESCE(i.n, 0)`
  );

  for (const row of drifted) {
    // Clear the listing's counts, then write back one row per day it actually had enquiries.
    await execute("UPDATE listing_daily_stats SET inquiries = 0 WHERE listing_id = ?", [row.id]);
    await execute(
      `INSERT INTO listing_daily_stats
         (listing_id, stat_date, impressions, views, unique_views, inquiries, favourites,
          organization_id, agent_id, category_id, computed_at)
       SELECT i.listing_id, DATE(i.created_at), 0, 0, 0, COUNT(*), 0,
              l.organization_id, l.agent_id, l.category_id, NOW(3)
         FROM inquiries i JOIN listings l ON l.id = i.listing_id
        WHERE i.listing_id = ? AND i.deleted_at IS NULL
        GROUP BY i.listing_id, DATE(i.created_at)
       ON DUPLICATE KEY UPDATE inquiries = VALUES(inquiries), computed_at = NOW(3)`,
      [row.id]
    );
  }

  const projected = await queryValue("SELECT COUNT(*) FROM listing_search");
  return { projected: Number(projected), inquiryCountsReconciled: drifted.length };
}

const TASKS = {
  reapers: async () => ({
    queue: await reapQueueMessages(),
    searchIndex: await reapSearchIndexQueue(),
    locks: await reapDistributedLocks(),
    breakers: await advanceCircuitBreakers(),
  }),
  expiry: expireListings,
  indexing: drainSearchIndexQueue,
  derived: refreshDerived,
  // Reconciliation runs after `derived`: the projection and counters are settled
  // first, then the sitemap and unit counts are squared against them.
  reconcile: async () => ({
    projection: await reconcileProjection(),
    sitemap: await reconcileSitemap(),
    unitCounts: await reconcileUnitCounts(),
  }),
};

export async function runMaintenance({ only } = {}) {
  const names = only ? only.split(",").map((name) => name.trim()) : Object.keys(TASKS);
  const summary = {};
  for (const name of names) {
    const task = TASKS[name];
    if (!task) continue;
    summary[name] = await task();
  }
  return summary;
}

const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop());
if (isMain) {
  const index = process.argv.indexOf("--only");
  runMaintenance({ only: index >= 0 ? process.argv[index + 1] : undefined })
    .then(async (summary) => {
      logger.info(summary, "maintenance pass complete");
      await closePool();
      process.exit(0);
    })
    .catch(async (error) => {
      logger.error({ err: error }, "maintenance pass failed");
      await closePool();
      process.exit(1);
    });
}
