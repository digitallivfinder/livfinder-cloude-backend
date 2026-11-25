import logger from "../../config/logger.js";
import env from "../../config/env.js";
import { execute, query, queryOne } from "../../db/query.js";
import { retryTransient } from "../../db/retry.js";
import { AppError } from "../../utils/errors.js";
import { notifyRejectedListings } from "./rejectionNotice.service.js";
import { importProviderId } from "./importConnection.js";
import { importDevelopmentsRun, withdrawImportedDevelopment } from "../feeds/developmentImport.service.js";
import { assertAddonActive } from "../accounts/addons.service.js";
import * as repo from "./imports.repository.js";
import { importListing, parseListingRecord, withdrawImportedListing } from "./listingImport.service.js";

export const MAX_BULK_LISTINGS = 100;

/**
 * Runs pushes as recorded imports. A single push runs while the caller waits; a bulk push is
 * accepted at once and processed in the background, one listing at a time, each in its own
 * transaction, so one bad listing never blocks the rest.
 */

function attach(error, importRun) {
  if (error && typeof error === "object") error.importId = importRun.publicId;
  return error;
}

/** One listing, answered straight away. Returns `{ importRun, outcome }` or throws (with `importId`). */
export async function runSingleImport({ client, ctx, record, ip, userAgent, requestId }) {
  const importRun = await repo.createImportRun({ client, ctx, type: "single", total: 1, status: "running", ip, userAgent });
  const [itemId] = await repo.addImportItems(importRun.id, [{ row: 1, externalId: record.externalId, raw: record }]);
  try {
    const outcome = await retryTransient(() => importListing({ client, ctx, record, source: "api", importId: importRun.publicId, ip, requestId }), { label: "listing import" });
    await repo.recordItemSuccess(itemId, importRun.id, outcome);
    await repo.finalizeImport(importRun.id);
    return { importRun, outcome };
  } catch (error) {
    await repo.recordItemFailure(itemId, error).catch(() => {});
    await repo.finalizeImport(importRun.id).catch(() => {});
    throw attach(error, importRun);
  }
}

/** A withdrawal, recorded like any other change so it shows in the company's history. */
/**
 * A takedown by externalId: a pushed listing or, for a developer company, a pushed development.
 * A development's outcome carries `project` (and `listing` for the import log, as its own run does).
 */
async function withdrawPushed(args) {
  try {
    return await withdrawImportedListing(args);
  } catch (error) {
    if (error?.status !== 404 || !args.client?.organizationId) throw error;
    const outcome = await withdrawImportedDevelopment(args);
    return { ...outcome, listing: outcome.project };
  }
}

export async function runWithdrawal({ client, ctx, externalId, ip, userAgent, requestId }) {
  const importRun = await repo.createImportRun({ client, ctx, type: "single", total: 1, status: "running", ip, userAgent });
  const [itemId] = await repo.addImportItems(importRun.id, [{ row: 1, externalId, raw: { externalId, action: "withdraw" } }]);
  try {
    const outcome = await retryTransient(() => withdrawPushed({ client, ctx, externalId, importId: importRun.publicId, ip, requestId }), { label: "listing withdrawal" });
    await repo.recordItemSuccess(itemId, importRun.id, { ...outcome, warnings: [] });
    await repo.finalizeImport(importRun.id);
    return { importRun, outcome };
  } catch (error) {
    await repo.recordItemFailure(itemId, error).catch(() => {});
    await repo.finalizeImport(importRun.id).catch(() => {});
    throw attach(error, importRun);
  }
}

const EXTERNAL_ID = /^\S{1,191}$/;

/**
 * Accepts up to 100 changes: listings to create or update, and `withdrawals` (externalIds to take
 * down). Each is checked now, so obvious mistakes come back in this response; the rest are queued
 * and processed in the background. Rows are numbered listings first, then withdrawals.
 */
export async function createBulkImport({ client, ctx, listings = [], withdrawals = [], ip, userAgent }) {
  const seen = new Set();
  const duplicate = () =>
    new AppError("This externalId appears more than once in the batch.", {
      status: 422,
      code: "DUPLICATE_IN_BATCH",
      fields: { externalId: "Send each listing once per batch." },
    });
  const upserts = listings.map((raw, index) => {
    const row = index + 1;
    const externalId = typeof raw?.externalId === "string" ? raw.externalId.trim() : null;
    try {
      const record = parseListingRecord(raw);
      if (seen.has(record.externalId)) throw duplicate();
      seen.add(record.externalId);
      return { row, externalId: record.externalId, raw: record };
    } catch (error) {
      return { row, externalId, raw, error };
    }
  });
  const takedowns = withdrawals.map((value, index) => {
    const row = listings.length + index + 1;
    const externalId = typeof value === "string" ? value.trim() : null;
    const raw = { externalId, withdraw: true };
    if (!externalId || !EXTERNAL_ID.test(externalId)) {
      const error = new AppError("Some information in this withdrawal is invalid.", {
        status: 422,
        code: "VALIDATION_ERROR",
        fields: { externalId: "Give the listing's id in your system: up to 191 characters, no spaces." },
      });
      return { row, externalId, raw, error };
    }
    if (seen.has(externalId)) return { row, externalId, raw, error: duplicate() };
    seen.add(externalId);
    return { row, externalId, raw };
  });
  const items = [...upserts, ...takedowns];

  const accepted = items.filter((item) => !item.error).length;
  const importRun = await repo.createImportRun({
    client,
    ctx,
    type: "api_push",
    total: items.length,
    status: accepted ? "queued" : "running",
    ip,
    userAgent,
  });
  await repo.addImportItems(importRun.id, items);
  if (accepted) {
    // Started on the next tick so the caller gets its 202 first. The runner in server.js picks
    // the import up again if this process stops before it finishes.
    setImmediate(() => processImport(importRun.id).catch((error) => logger.error({ err: error }, "bulk import failed")));
  } else {
    await repo.finalizeImport(importRun.id);
    await notifyRejectedListings(importRun.id).catch((error) => logger.error({ err: error }, "rejection notice failed"));
  }

  return {
    importRun,
    accepted,
    rejected: items
      .filter((item) => item.error)
      .map((item) => ({ row: item.row, externalId: item.externalId, error: repo.errorBody(item.error) })),
  };
}

async function clientForRun(run) {
  const row = await queryOne(
    `SELECT ac.id, ac.public_id, ac.name, ac.client_id, ac.status, ac.expires_at, ac.created_by_user_id, ac.organization_id,
            COALESCE(ac.account_id, o.account_id) AS account_id, o.public_id AS organization_public_id,
            o.status AS organization_status, o.deleted_at AS organization_deleted_at, a.status AS account_status
       FROM api_clients ac
       LEFT JOIN organizations o ON o.id = ac.organization_id
       LEFT JOIN accounts a ON a.id = COALESCE(ac.account_id, o.account_id)
      WHERE ac.id = ?`,
    [run.api_client_id]
  );
  if (!row) return null;
  // The same checks the request itself passed (middleware/apiClient.js): a key that expired, or
  // an account closed, while the batch waited stops it like a revoked key.
  const expired = row.expires_at && new Date(row.expires_at) <= new Date();
  const accountClosed = row.account_status !== "active";
  return {
    id: row.id,
    publicId: row.public_id,
    name: row.name,
    clientId: row.client_id,
    status: expired || accountClosed ? "inactive" : row.status,
    // An individual's key has no organization to be suspended.
    organizationStatus: row.organization_id ? (row.organization_deleted_at ? "deleted" : row.organization_status) : "active",
    organizationId: row.organization_id,
    organizationPublicId: row.organization_public_id,
    accountId: row.account_id,
    createdByUserId: row.created_by_user_id ?? null,
    ip: run.source_ip,
  };
}

/** Processes the queued items of one bulk import. Safe to call twice: only one call claims it. */
export async function processImport(importId) {
  const claim = await execute(
    "UPDATE feed_imports SET status = 'running', started_at = COALESCE(started_at, NOW(3)) WHERE id = ? AND status = 'queued'",
    [importId]
  );
  if (!claim.affectedRows) return null;

  const run = await queryOne(
    `SELECT id, public_id, connection_id, provider_id, api_client_id, import_type, entity_type, organization_id, account_id,
            INET6_NTOA(source_ip) AS source_ip
       FROM feed_imports WHERE id = ?`,
    [importId]
  );
  const ctx = { providerId: Number(run.provider_id), connectionId: Number(run.connection_id) };
  const client = run.api_client_id ? await clientForRun(run) : null;
  // A pushed XML or CSV file is a `full` import; its listings are marked as coming from a feed.
  const source = run.import_type === "full" ? "feed" : "api";
  const items = await query(
    "SELECT id, raw_payload FROM feed_import_items WHERE import_id = ? AND status = 'queued' ORDER BY source_row ASC, id ASC",
    [importId]
  );

  // Developments have their own import; a revoked key or suspended company still stops them.
  const developments = run.entity_type === "project" && client?.status === "active" && client.organizationStatus === "active";
  if (developments) await importDevelopmentsRun({ run, client, ctx });

  for (const item of developments ? [] : items) {
    // Another worker that picked this import up again may have done this one already.
    const still = await queryOne("SELECT status FROM feed_import_items WHERE id = ?", [item.id]);
    if (still?.status !== "queued") continue;
    try {
      // A key revoked, or a company suspended, after the batch was accepted stops the rest of it.
      if (!client || client.status !== "active" || client.organizationStatus !== "active") {
        throw new AppError("The API key or account was disabled before this listing was processed.", {
          status: 401,
          code: "API_KEY_INVALID",
        });
      }
      await assertAddonActive(client.accountId, "integrations");
      const raw = typeof item.raw_payload === "string" ? JSON.parse(item.raw_payload) : item.raw_payload;
      // A deadlock with the photo downloader (writing the same listings' media) is run again.
      const outcome = await retryTransient(
        () =>
          raw.withdraw
            ? withdrawPushed({ client, ctx, externalId: raw.externalId, importId: run.public_id, ip: run.source_ip })
            : importListing({ client, ctx, record: parseListingRecord(raw), source, importId: run.public_id, ip: run.source_ip }),
        { label: "listing import item" }
      );
      await repo.recordItemSuccess(item.id, importId, outcome);
    } catch (error) {
      if (!(error instanceof AppError) || error.status >= 500) {
        logger.error({ err: error, importId: run.public_id, itemId: item.id }, "listing import item failed");
      }
      await repo.recordItemFailure(item.id, error).catch((writeError) => logger.error({ err: writeError }, "import item result not recorded"));
    }
  }

  const status = await repo.finalizeImport(importId);
  if (status === "partial" || status === "failed") await notifyRejectedListings(importId).catch((error) => logger.error({ err: error }, "rejection notice failed"));
  return status;
}

// A running import with no listing processed for this long is taken to have stopped (a restart).
const STALLED_MINUTES = 5;

/** Puts back in the queue any running import that has stopped making progress (a restart). */
export async function requeueStalledImports(providerId) {
  // Stranded = nothing processed for a while, not merely started long ago: a 16,000-listing file
  // runs for half an hour or more, and must not get a second worker while the first is busy.
  const result = await execute(
    `UPDATE feed_imports fi SET fi.status = 'queued'
      WHERE fi.provider_id = ? AND fi.status = 'running' AND fi.started_at < DATE_SUB(NOW(3), INTERVAL ${STALLED_MINUTES} MINUTE)
        AND EXISTS (SELECT 1 FROM feed_import_items fii WHERE fii.import_id = fi.id AND fii.status = 'queued')
        AND NOT EXISTS (
          SELECT 1 FROM feed_import_items done
           WHERE done.import_id = fi.id AND done.status <> 'queued' AND done.processed_at > DATE_SUB(NOW(3), INTERVAL ${STALLED_MINUTES} MINUTE)
        )`,
    [providerId]
  );
  return result.affectedRows;
}

/** Picks up imports left queued, or stranded mid-run by a restart, and processes them. */
export async function runQueuedImports() {
  const providerId = await importProviderId().catch(() => null);
  if (!providerId) return 0;
  await requeueStalledImports(providerId);
  const due = await query(
    `SELECT id FROM feed_imports
      WHERE provider_id = ? AND status = 'queued' AND created_at < DATE_SUB(NOW(3), INTERVAL 10 SECOND)
      ORDER BY created_at ASC LIMIT 20`,
    [providerId]
  );
  for (const row of due) await processImport(row.id);
  return due.length;
}

export function startImportRunner({ intervalMs = 60 * 1000 } = {}) {
  if (env.isTest) return null;
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      await runQueuedImports();
    } catch (error) {
      logger.error({ err: error }, "listing import runner failed");
    } finally {
      running = false;
    }
  };
  const timer = setInterval(tick, intervalMs);
  timer.unref?.();
  return timer;
}
