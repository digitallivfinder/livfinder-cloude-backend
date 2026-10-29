import { execute, query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";

/**
 * Feed sources (migration 0063): one feed URL per account per category, never one per office.
 */

export const SCHEDULE_MINUTES = Object.freeze({ hourly: 60, every_6_hours: 360, daily: 1440 });
export const WATCH_INTERVAL_MINUTES = 10;

const FEED_COLUMNS = `
  fs.id, fs.public_id, fs.account_id, fs.organization_id, fs.category, fs.url, fs.format, fs.schedule,
  fs.watch_changes, fs.status, fs.max_removal_percent, fs.etag, fs.last_modified, fs.last_checksum,
  fs.last_checked_at, fs.last_changed_at, fs.last_run_at, fs.last_import_id, fs.held_import_id,
  fs.next_run_at, fs.next_check_at, fs.running_since, fs.consecutive_failures, fs.last_error,
  fs.created_by_user_id, fs.created_at, fs.updated_at,
  li.public_id AS last_import_public_id, li.status AS last_import_status,
  hi.public_id AS held_import_public_id`;

const FEED_FROM = `
  FROM feed_sources fs
  LEFT JOIN feed_imports li ON li.id = fs.last_import_id
  LEFT JOIN feed_imports hi ON hi.id = fs.held_import_id`;

export async function getFeedSource(id) {
  return queryOne(`SELECT ${FEED_COLUMNS} ${FEED_FROM} WHERE fs.id = ?`, [id]);
}

export async function getAccountFeed(accountId, category) {
  return queryOne(`SELECT ${FEED_COLUMNS} ${FEED_FROM} WHERE fs.account_id = ? AND fs.category = ?`, [accountId, category]);
}

export async function listAccountFeeds(accountId) {
  return query(`SELECT ${FEED_COLUMNS} ${FEED_FROM} WHERE fs.account_id = ? ORDER BY fs.category`, [accountId]);
}

export function serializeFeed(row) {
  if (!row) return null;
  return {
    id: row.public_id,
    category: row.category,
    url: row.url,
    format: row.format,
    schedule: row.schedule,
    watchChanges: Boolean(row.watch_changes),
    status: row.status,
    maxRemovalPercent: Number(row.max_removal_percent),
    lastCheckedAt: row.last_checked_at,
    lastChangedAt: row.last_changed_at,
    lastRunAt: row.last_run_at,
    nextRunAt: row.next_run_at,
    nextCheckAt: row.watch_changes ? row.next_check_at : null,
    running: Boolean(row.running_since),
    lastImport: row.last_import_public_id ? { id: row.last_import_public_id, status: row.last_import_status } : null,
    heldImport: row.held_import_public_id ? { id: row.held_import_public_id } : null,
    consecutiveFailures: Number(row.consecutive_failures) || 0,
    lastError: row.last_error,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

/** Creates or changes an account's feed for one category. A new or moved URL runs straight away. */
export async function saveAccountFeed({ accountId, organizationId, category, url, format, schedule, watchChanges, status, userId }) {
  const existing = await getAccountFeed(accountId, category);
  if (!existing) {
    await execute(
      `INSERT INTO feed_sources
         (public_id, account_id, organization_id, category, url, format, schedule, watch_changes, status,
          next_run_at, next_check_at, created_by_user_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(3), NOW(3), ?)`,
      [ulid(), accountId, organizationId ?? null, category, url, format ?? "auto", schedule ?? "daily", watchChanges === false ? 0 : 1, status ?? "active", userId ?? null]
    );
    return getAccountFeed(accountId, category);
  }
  const moved = url !== undefined && url !== existing.url;
  const assignments = [];
  const params = [];
  const set = (column, value) => {
    assignments.push(`${column} = ?`);
    params.push(value);
  };
  if (url !== undefined) set("url", url);
  if (format !== undefined) set("format", format);
  if (schedule !== undefined) set("schedule", schedule);
  if (watchChanges !== undefined) set("watch_changes", watchChanges ? 1 : 0);
  if (status !== undefined) set("status", status);
  if (moved) {
    // A different file: nothing about the old one's caching applies.
    assignments.push("etag = NULL", "last_modified = NULL", "last_checksum = NULL", "next_run_at = NOW(3)", "next_check_at = NOW(3)");
  }
  if (status === "active" && existing.status !== "active") {
    assignments.push("consecutive_failures = 0", "last_error = NULL", "next_run_at = NOW(3)", "next_check_at = NOW(3)");
  }
  if (assignments.length) await execute(`UPDATE feed_sources SET ${assignments.join(", ")} WHERE id = ?`, [...params, existing.id]);
  return getAccountFeed(accountId, category);
}

export async function deleteAccountFeed(accountId, category) {
  const feed = await getAccountFeed(accountId, category);
  if (!feed) throw AppError.notFound("There is no feed for that category.");
  if (feed.running_since) throw AppError.conflict("This feed is running. Try again when the run has finished.");
  await execute("DELETE FROM feed_sources WHERE id = ?", [feed.id]);
  return true;
}

// "Run now" and the refresh ping fetch a feed at most this often, however often they are called.
export const MIN_MINUTES_BETWEEN_REQUESTED_RUNS = 2;

/**
 * Asks for a run at the next scheduler tick ("Run now", or the company's refresh ping), but never
 * sooner than two minutes after the last fetch: a CRM that pings on every edit gets one fetch per
 * window. Returns when the fetch will happen.
 */
export async function requestRun(feedId) {
  await execute(
    `UPDATE feed_sources
        SET next_run_at = GREATEST(NOW(3), COALESCE(DATE_ADD(last_checked_at, INTERVAL ${MIN_MINUTES_BETWEEN_REQUESTED_RUNS} MINUTE), NOW(3))),
            next_check_at = GREATEST(NOW(3), COALESCE(DATE_ADD(last_checked_at, INTERVAL ${MIN_MINUTES_BETWEEN_REQUESTED_RUNS} MINUTE), NOW(3)))
      WHERE id = ?`,
    [feedId]
  );
  const row = await queryOne("SELECT next_run_at FROM feed_sources WHERE id = ?", [feedId]);
  return { at: row?.next_run_at ?? null };
}

/**
 * The client an import runs as for a feed: the shape the import takes from an API key, with the
 * feed in place of the key. It is active while the feed, the account and its organization are.
 */
export async function feedClientFor(feedSourceId) {
  const row = await queryOne(
    `SELECT fs.id, fs.public_id, fs.category, fs.status, fs.created_by_user_id, fs.account_id, fs.organization_id,
            a.status AS account_status, o.public_id AS organization_public_id, o.status AS organization_status
       FROM feed_sources fs
       JOIN accounts a ON a.id = fs.account_id
       LEFT JOIN organizations o ON o.id = fs.organization_id
      WHERE fs.id = ?`,
    [feedSourceId]
  );
  if (!row) return null;
  const active = row.account_status === "active" && (!row.organization_id || row.organization_status === "active");
  return {
    id: null,
    publicId: null,
    feedId: row.id,
    feedPublicId: row.public_id,
    name: `${row.category} feed`,
    clientId: null,
    status: active ? "active" : "suspended",
    organizationStatus: active ? "active" : "suspended",
    organizationId: row.organization_id ?? null,
    organizationPublicId: row.organization_public_id ?? null,
    accountId: row.account_id,
    createdByUserId: row.created_by_user_id ?? null,
    ip: null,
  };
}

/* -------------------------------------------------------------------------- */
/* Admin: every company's feeds (Phase 7)                                      */
/* -------------------------------------------------------------------------- */

/**
 * The feed monitor. `problem` narrows to feeds that need a look: stopped after errors, failing
 * now, or holding a run for review.
 */
export async function listAllFeeds({ status = null, category = null, problem = false, search = null, page = 1, pageSize = 50 } = {}) {
  const conditions = ["1 = 1"];
  const params = [];
  if (status) {
    conditions.push("fs.status = ?");
    params.push(status);
  }
  if (category) {
    conditions.push("fs.category = ?");
    params.push(category);
  }
  if (problem) conditions.push("(fs.status = 'error' OR fs.consecutive_failures > 0 OR fs.held_import_id IS NOT NULL)");
  if (search) {
    conditions.push("(a.name LIKE ? OR o.name LIKE ? OR fs.url LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  const where = `WHERE ${conditions.join(" AND ")}`;
  const from = `
    FROM feed_sources fs
    JOIN accounts a ON a.id = fs.account_id
    LEFT JOIN organizations o ON o.id = fs.organization_id
    LEFT JOIN feed_imports li ON li.id = fs.last_import_id
    LEFT JOIN feed_imports hi ON hi.id = fs.held_import_id`;
  const offset = (Math.max(1, page) - 1) * pageSize;
  const [rows, total] = await Promise.all([
    query(
      `SELECT ${FEED_COLUMNS.trim()}, a.public_id AS account_public_id, a.name AS account_name,
              o.public_id AS organization_public_id, o.name AS organization_name,
              li.created_count, li.updated_count, li.failed_count, li.deleted_count, li.total_rows
         ${from} ${where}
        ORDER BY (fs.held_import_id IS NOT NULL) DESC, (fs.status = 'error') DESC, fs.consecutive_failures DESC, fs.updated_at DESC
        LIMIT ${Number(pageSize)} OFFSET ${offset}`,
      params
    ),
    queryOne(`SELECT COUNT(*) AS n ${from} ${where}`, params),
  ]);
  return {
    rows: rows.map((row) => ({
      ...serializeFeed(row),
      account: { id: row.account_public_id, name: row.organization_name || row.account_name },
      organizationId: row.organization_public_id ?? null,
      lastRunCounts: row.last_import_public_id
        ? {
            total: Number(row.total_rows) || 0,
            created: Number(row.created_count) || 0,
            updated: Number(row.updated_count) || 0,
            failed: Number(row.failed_count) || 0,
            withdrawn: Number(row.deleted_count) || 0,
          }
        : null,
    })),
    total: Number(total.n),
  };
}

/** An admin pauses a company's feed, or turns it back on. */
export async function setFeedStatus(publicId, status) {
  const feed = await queryOne("SELECT id FROM feed_sources WHERE public_id = ?", [publicId]);
  if (!feed) throw AppError.notFound("That feed was not found.");
  await execute(
    `UPDATE feed_sources SET status = ?${status === "active" ? ", consecutive_failures = 0, last_error = NULL, next_run_at = NOW(3), next_check_at = NOW(3)" : ""} WHERE id = ?`,
    [status, feed.id]
  );
  return serializeFeed(await getFeedSource(feed.id));
}

export async function feedIdForPublicId(publicId) {
  const feed = await queryOne("SELECT id, status FROM feed_sources WHERE public_id = ?", [publicId]);
  if (!feed) throw AppError.notFound("That feed was not found.");
  return feed;
}
