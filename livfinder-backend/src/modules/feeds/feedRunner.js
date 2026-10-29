import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute, query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { sha256Hex } from "../../utils/ids.js";
import { assertSafeUrl, safeFetch } from "../../utils/safeFetch.js";
import { resolveCategory } from "../../utils/categories.js";
import { isAddonActive } from "../accounts/addons.service.js";
import { notifyAccount, notifyStaff } from "../system/notifications.service.js";
import { ensureImportConnection } from "../imports/importConnection.js";
import * as importsRepo from "../imports/imports.repository.js";
import { processImport } from "../imports/importRunner.js";
import { withdrawImportedListing } from "../imports/listingImport.service.js";
import { MAX_FEED_BYTES, parseFeed } from "./feedParser.js";
import { SCHEDULE_MINUTES, WATCH_INTERVAL_MINUTES, feedClientFor, getFeedSource } from "./feedSources.repository.js";
import { importDevelopmentsRun } from "./developmentImport.service.js";

/**
 * Runs a company's feed (0063): fetch the file, skip it if nothing changed, import every entry
 * unpublished, and withdraw what left the file, unless that would take too much at once.
 *
 * A run is an ordinary `feed_imports` row tied to its feed, processed by the same runner as an API
 * batch, so results show in the same places (portal, admin, partner API). One run per feed at a
 * time: `running_since` claims it.
 */

const FETCH_TIMEOUT_MS = 60_000;
const MAX_REDIRECTS = 3;
const ERROR_AFTER_FAILURES = 5;

const minutesFromNow = (minutes) => new Date(Date.now() + minutes * 60_000);

/* -------------------------------------------------------------------------- */
/* Fetching                                                                    */
/* -------------------------------------------------------------------------- */

/**
 * Fetches the file, following up to three redirects, each checked like the first address.
 * `conditional` sends the last ETag / Last-Modified, and a 304 comes back as `{ notModified }`.
 */
export async function fetchFeedFile(url, { etag = null, lastModified = null, conditional = true } = {}) {
  const headers = { Accept: "application/xml, text/xml, text/csv, text/plain;q=0.9, */*;q=0.5", "User-Agent": "LivFinder-Feed/1.0" };
  if (conditional && etag) headers["If-None-Match"] = etag;
  if (conditional && lastModified) headers["If-Modified-Since"] = lastModified;
  let current = url;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop += 1) {
    const response = await safeFetch(current, {
      useAllowList: false,
      timeoutMs: FETCH_TIMEOUT_MS,
      redirect: "manual",
      headers,
    });
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get("location");
      if (!location) throw new AppError("The feed address redirects without saying where.", { status: 422, code: "FEED_FETCH_FAILED" });
      current = new URL(location, current).toString();
      await assertSafeUrl(current, { useAllowList: false });
      continue;
    }
    if (response.status === 304) return { notModified: true };
    if (!response.ok) {
      throw new AppError(`The feed address answered ${response.status}.`, { status: 422, code: "FEED_FETCH_FAILED" });
    }
    const declared = Number(response.headers.get("content-length"));
    if (declared && declared > MAX_FEED_BYTES) {
      throw new AppError(`The feed file is larger than ${MAX_FEED_BYTES / 1024 / 1024} MB.`, { status: 422, code: "FEED_TOO_LARGE" });
    }
    const buffer = Buffer.from(await response.arrayBuffer());
    if (buffer.length > MAX_FEED_BYTES) {
      throw new AppError(`The feed file is larger than ${MAX_FEED_BYTES / 1024 / 1024} MB.`, { status: 422, code: "FEED_TOO_LARGE" });
    }
    return {
      buffer,
      etag: response.headers.get("etag"),
      lastModified: response.headers.get("last-modified"),
      contentType: response.headers.get("content-type") || "",
      finalUrl: current,
    };
  }
  throw new AppError("The feed address redirects too many times.", { status: 422, code: "FEED_FETCH_FAILED" });
}

function formatOf(feed, file) {
  if (feed.format !== "auto") return feed.format;
  const type = file.contentType.toLowerCase();
  if (type.includes("xml")) return "xml";
  if (type.includes("csv")) return "csv";
  const path = (() => {
    try {
      return new URL(file.finalUrl).pathname.toLowerCase();
    } catch {
      return "";
    }
  })();
  if (path.endsWith(".xml")) return "xml";
  if (path.endsWith(".csv")) return "csv";
  return undefined; // the parser looks at the first character
}

/** Fetches and reads a feed without saving anything: the portal's "Test feed". */
export async function testFeed({ url, category, format = "auto" }) {
  const file = await fetchFeedFile(url, { conditional: false });
  const result = parseFeed({ category, format: formatOf({ format }, file), content: file.buffer });
  const failed = result.items.filter((item) => item.errors);
  return {
    category,
    format: result.format,
    source: result.source,
    version: result.version,
    sizeBytes: file.buffer.length,
    total: result.items.length,
    valid: result.items.length - failed.length,
    invalid: failed.length,
    warnings: result.warnings,
    rows: failed.slice(0, 500).map((item) => ({ row: item.row, externalId: item.externalId, errors: item.errors })),
  };
}

/* -------------------------------------------------------------------------- */
/* Bookkeeping                                                                 */
/* -------------------------------------------------------------------------- */

async function scheduleNext(feed, assignments = [], params = []) {
  await execute(
    `UPDATE feed_sources
        SET ${[...assignments, "last_checked_at = NOW(3)", "next_check_at = ?", "running_since = NULL"].join(", ")}
      WHERE id = ?`,
    [...params, minutesFromNow(WATCH_INTERVAL_MINUTES), feed.id]
  );
}

async function recordFailure(feed, error, client, ctx) {
  const message = String(error?.message || "The feed could not be read.").slice(0, 500);
  // A file that could not be read still leaves a run behind, so the company sees why in its history.
  if (client && ctx) {
    const run = await importsRepo.createImportRun({
      client,
      ctx,
      type: "full",
      total: 0,
      status: "failed",
      feed: { id: feed.id, url: feed.url, maxRemovalPercent: feed.max_removal_percent },
    });
    await execute("UPDATE feed_imports SET error_message = ?, finished_at = NOW(3) WHERE id = ?", [message, run.id]);
    await execute("UPDATE feed_sources SET last_import_id = ? WHERE id = ?", [run.id, feed.id]);
  }
  const failures = (Number(feed.consecutive_failures) || 0) + 1;
  const giveUp = failures >= ERROR_AFTER_FAILURES;
  await scheduleNext(
    feed,
    ["consecutive_failures = ?", "last_error = ?", "next_run_at = ?", ...(giveUp ? ["status = 'error'"] : [])],
    [failures, message, minutesFromNow(SCHEDULE_MINUTES[feed.schedule] || 1440)]
  );
  if (giveUp || failures === 1) {
    await notifyAccount(
      { accountId: feed.account_id, organizationId: feed.organization_id },
      {
        type: "feed.failed",
        title: giveUp ? `Your ${feed.category} feed was paused after ${failures} failed runs` : `Your ${feed.category} feed could not be read`,
        body: message,
        actionUrl: "/portal/integrations",
        icon: "alert",
        subjectType: "feed_source",
        subjectId: feed.id,
      }
    ).catch(() => {});
  }
  return { outcome: "failed", error: message };
}

/* -------------------------------------------------------------------------- */
/* Removals                                                                    */
/* -------------------------------------------------------------------------- */

/** The feed's own listings that are live or waiting: the ones a removal would withdraw. */
async function feedListings(feed, ctx) {
  const definition = resolveCategory(feed.category);
  return query(
    `SELECT er.external_id, l.id
       FROM external_references er
       JOIN listings l ON l.id = er.entity_id AND l.deleted_at IS NULL
      WHERE er.provider_id = ? AND er.connection_id = ? AND er.entity_type = 'listing'
        AND COALESCE(er.remote_status, 'live') <> 'removed'
        AND l.source = 'feed' AND l.root_category_id = ? AND l.status IN ('active', 'pending_review')`,
    [ctx.providerId, ctx.connectionId, definition.rootId]
  );
}

/** More than `max_removal_percent` of the feed's listings, and more than two, holds the run. */
export function removalNeedsHold(toRemove, base, maxPercent) {
  return toRemove > Math.max(2, Math.ceil((base * maxPercent) / 100));
}

async function withdrawItems({ run, items, client, ctx }) {
  for (const item of items) {
    try {
      const outcome = await withdrawImportedListing({ client, ctx, externalId: item.external_id, importId: run.public_id, removedFromFeed: true });
      await importsRepo.recordItemSuccess(item.id, run.id, { ...outcome, warnings: [] });
    } catch (error) {
      await importsRepo.recordItemFailure(item.id, error).catch(() => {});
    }
  }
}

async function applyRemovals({ feed, run, presentIds, client, ctx }) {
  const live = await feedListings(feed, ctx);
  const gone = live.filter((row) => !presentIds.has(row.external_id));
  if (!gone.length) return { removed: 0, held: false };

  const held = removalNeedsHold(gone.length, live.length, Number(feed.max_removal_percent) || 20);
  for (const row of gone) {
    await execute(
      `INSERT INTO feed_import_items (import_id, external_id, entity_type, entity_id, operation, status, error_message, processed_at)
       VALUES (?, ?, 'listing', ?, 'delete', ?, ?, NULL)`,
      [run.id, row.external_id, row.id, held ? "skipped" : "queued", held ? "Waiting for LivFinder: too many listings left the file at once." : null]
    );
  }
  if (held) {
    const reason = `${gone.length} of ${live.length} listings left the file at once (limit ${feed.max_removal_percent}%). Nothing was withdrawn.`;
    await execute("UPDATE feed_imports SET status = 'held_for_review', hold_reason = ? WHERE id = ?", [reason, run.id]);
    await execute("UPDATE feed_sources SET held_import_id = ? WHERE id = ?", [run.id, feed.id]);
    const payload = {
      type: "feed.removals_held",
      title: `A ${feed.category} feed run is waiting for review`,
      body: reason,
      icon: "alert",
      subjectType: "feed_import",
      subjectId: run.id,
      data: { importId: run.public_id },
    };
    await notifyAccount({ accountId: feed.account_id, organizationId: feed.organization_id }, { ...payload, actionUrl: "/portal/integrations" }).catch(() => {});
    await notifyStaff("listings.moderate", { ...payload, actionUrl: `/admin/imports/${run.public_id}` }).catch(() => {});
    return { removed: 0, held: true, waiting: gone.length };
  }
  const items = await query(
    "SELECT id, external_id FROM feed_import_items WHERE import_id = ? AND operation = 'delete' AND status = 'queued'",
    [run.id]
  );
  await withdrawItems({ run, items, client, ctx });
  return { removed: gone.length, held: false };
}

async function loadHeldRun(importPublicId) {
  const run = await queryOne(
    "SELECT id, public_id, status, feed_source_id, provider_id, connection_id FROM feed_imports WHERE public_id = ?",
    [importPublicId]
  );
  if (!run) throw AppError.notFound("That import was not found.");
  if (run.status !== "held_for_review" || !run.feed_source_id) throw AppError.conflict("That import is not waiting for review.");
  return run;
}

/** An admin lets a held run's withdrawals go ahead. */
export async function releaseHeldRun(importPublicId) {
  const run = await loadHeldRun(importPublicId);
  const client = await feedClientFor(run.feed_source_id);
  const ctx = { providerId: Number(run.provider_id), connectionId: Number(run.connection_id) };
  const items = await query(
    "SELECT id, external_id FROM feed_import_items WHERE import_id = ? AND operation = 'delete' AND status = 'skipped'",
    [run.id]
  );
  await withdrawItems({ run, items, client, ctx });
  await execute("UPDATE feed_imports SET hold_reason = CONCAT(COALESCE(hold_reason, ''), ' Released by LivFinder.') WHERE id = ?", [run.id]);
  const status = await importsRepo.finalizeImport(run.id);
  await execute("UPDATE feed_sources SET held_import_id = NULL WHERE held_import_id = ?", [run.id]);
  return { status, withdrawn: items.length };
}

/** An admin keeps the listings a held run would have withdrawn. */
export async function discardHeldRun(importPublicId) {
  const run = await loadHeldRun(importPublicId);
  await execute(
    `UPDATE feed_import_items SET error_message = 'Kept: LivFinder did not withdraw it.', processed_at = NOW(3)
      WHERE import_id = ? AND operation = 'delete' AND status = 'skipped'`,
    [run.id]
  );
  await execute("UPDATE feed_imports SET hold_reason = CONCAT(COALESCE(hold_reason, ''), ' Kept by LivFinder.') WHERE id = ?", [run.id]);
  const status = await importsRepo.finalizeImport(run.id);
  await execute("UPDATE feed_sources SET held_import_id = NULL WHERE held_import_id = ?", [run.id]);
  return { status };
}

/* -------------------------------------------------------------------------- */
/* A run                                                                       */
/* -------------------------------------------------------------------------- */

/**
 * Runs one feed. `conditional` asks the server whether the file changed (the 10-minute watch);
 * a scheduled run fetches it outright. Either way, bytes identical to the last run do nothing.
 */
export async function runFeed(feedId, { conditional = true, fetchFile = fetchFeedFile } = {}) {
  const claim = await execute(
    `UPDATE feed_sources SET running_since = NOW(3)
      WHERE id = ? AND status = 'active' AND (running_since IS NULL OR running_since < DATE_SUB(NOW(3), INTERVAL 30 MINUTE))`,
    [feedId]
  );
  if (!claim.affectedRows) return { outcome: "busy" };
  const feed = await getFeedSource(feedId);
  let client = null;
  let ctx = null;
  try {
    if (!(await isAddonActive(feed.account_id, "integrations"))) {
      await scheduleNext(feed, ["last_error = ?", "next_run_at = ?"], ["The Integrations add-on is off, so the feed is not fetched.", minutesFromNow(SCHEDULE_MINUTES[feed.schedule])]);
      return { outcome: "addon_inactive" };
    }
    client = await feedClientFor(feed.id);
    if (client.status !== "active") {
      await scheduleNext(feed, ["last_error = ?", "next_run_at = ?"], ["The account is not active.", minutesFromNow(SCHEDULE_MINUTES[feed.schedule])]);
      return { outcome: "account_inactive" };
    }
    ctx = await ensureImportConnection({ organizationId: feed.organization_id, accountId: feed.account_id, name: "Listing feeds and API" });

    // `fetchFile` stands in for the network in tests only; the real fetcher refuses local addresses.
    const file = await fetchFile(feed.url, { etag: feed.etag, lastModified: feed.last_modified, conditional });
    if (file.notModified) {
      await scheduleNext(feed, ["consecutive_failures = 0", "last_error = NULL"]);
      return { outcome: "not_modified" };
    }
    const checksum = sha256Hex(file.buffer);
    const cache = ["etag = ?", "last_modified = ?"];
    const cacheParams = [file.etag ? file.etag.slice(0, 255) : null, file.lastModified ? file.lastModified.slice(0, 100) : null];
    const nextRun = minutesFromNow(SCHEDULE_MINUTES[feed.schedule] || 1440);
    if (checksum === feed.last_checksum) {
      await scheduleNext(feed, [...cache, "consecutive_failures = 0", "last_error = NULL", "next_run_at = ?"], [...cacheParams, nextRun]);
      return { outcome: "unchanged" };
    }

    const parsed = parseFeed({ category: feed.category, format: formatOf(feed, file), content: file.buffer });
    const runMeta = {
      id: feed.id,
      url: feed.url,
      checksum,
      sizeBytes: file.buffer.length,
      maxRemovalPercent: feed.max_removal_percent,
      entityType: parsed.entity === "development" ? "project" : "listing",
    };
    const run = await importsRepo.createImportRun({
      client,
      ctx,
      type: "full",
      total: parsed.items.length,
      status: parsed.entity === "development" ? "running" : "queued",
      feed: runMeta,
    });
    const runRow = { id: run.id, public_id: run.publicId };
    const itemError = (item) => new AppError("This entry in the feed is invalid.", { status: 422, code: "VALIDATION_ERROR", fields: item.errors });
    await importsRepo.addImportItems(
      run.id,
      parsed.items.map((item) => ({ row: item.row, externalId: item.externalId, raw: item.record, error: item.errors ? itemError(item) : undefined })),
      { entityType: runMeta.entityType }
    );

    let removal = { removed: 0, held: false };
    if (parsed.entity === "development") {
      await importDevelopmentsRun({ feed, run: runRow, client, ctx });
    } else {
      await processImport(run.id);
      const presentIds = new Set(parsed.items.map((item) => item.externalId).filter(Boolean));
      removal = await applyRemovals({ feed, run: runRow, presentIds, client, ctx });
    }
    let status = await importsRepo.finalizeImport(run.id);
    if (removal.held) {
      await execute("UPDATE feed_imports SET status = 'held_for_review' WHERE id = ?", [run.id]);
      status = "held_for_review";
    }
    await scheduleNext(
      feed,
      [...cache, "last_checksum = ?", "last_changed_at = NOW(3)", "last_run_at = NOW(3)", "last_import_id = ?", "consecutive_failures = 0", "last_error = NULL", "next_run_at = ?"],
      [...cacheParams, checksum, run.id, nextRun]
    );
    return { outcome: "imported", importId: run.publicId, status, ...removal };
  } catch (error) {
    if (!(error instanceof AppError) || error.status >= 500) logger.error({ err: error, feedId }, "feed run failed");
    return recordFailure(feed, error, client, ctx);
  }
}

/* -------------------------------------------------------------------------- */
/* The scheduler                                                               */
/* -------------------------------------------------------------------------- */

/**
 * One pass: full runs that are due, then the 10-minute watch checks that are due. Feeds run one
 * after another, so a slow server never piles up work.
 */
export async function runDueFeeds({ limit = 10 } = {}) {
  const due = await query(
    `SELECT id, (next_run_at IS NOT NULL AND next_run_at <= NOW(3)) AS full_run
       FROM feed_sources
      WHERE status = 'active' AND running_since IS NULL
        AND ((next_run_at IS NOT NULL AND next_run_at <= NOW(3))
          OR (watch_changes = 1 AND next_check_at IS NOT NULL AND next_check_at <= NOW(3)))
      ORDER BY COALESCE(LEAST(next_run_at, next_check_at), next_run_at) ASC
      LIMIT ${Number(limit)}`
  );
  const results = [];
  for (const row of due) results.push(await runFeed(row.id, { conditional: !Number(row.full_run) }));
  return results;
}

export function startFeedScheduler({ intervalMs = 60 * 1000 } = {}) {
  if (env.isTest) return null;
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      await runDueFeeds();
    } catch (error) {
      logger.error({ err: error }, "feed scheduler failed");
    } finally {
      running = false;
    }
  };
  const timer = setInterval(tick, intervalMs);
  timer.unref?.();
  return timer;
}

