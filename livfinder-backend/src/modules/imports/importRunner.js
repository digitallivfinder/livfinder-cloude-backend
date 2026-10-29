import logger from "../../config/logger.js";
import env from "../../config/env.js";
import { execute, query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { notifyAccount } from "../system/notifications.service.js";
import { importProviderId } from "./importConnection.js";
import { feedClientFor } from "../feeds/feedSources.repository.js";
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
    const outcome = await importListing({ client, ctx, record, source: "api", importId: importRun.publicId, ip, requestId });
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
export async function runWithdrawal({ client, ctx, externalId, ip, userAgent, requestId }) {
  const importRun = await repo.createImportRun({ client, ctx, type: "single", total: 1, status: "running", ip, userAgent });
  const [itemId] = await repo.addImportItems(importRun.id, [{ row: 1, externalId, raw: { externalId, action: "withdraw" } }]);
  try {
    const outcome = await withdrawImportedListing({ client, ctx, externalId, importId: importRun.publicId, ip, requestId });
    await repo.recordItemSuccess(itemId, importRun.id, { ...outcome, warnings: [] });
    await repo.finalizeImport(importRun.id);
    return { importRun, outcome };
  } catch (error) {
    await repo.recordItemFailure(itemId, error).catch(() => {});
    await repo.finalizeImport(importRun.id).catch(() => {});
    throw attach(error, importRun);
  }
}

/**
 * Accepts up to 100 listings. Each is checked against the record schema now, so obvious mistakes
 * come back in this response; the rest are queued and processed in the background.
 */
export async function createBulkImport({ client, ctx, listings, ip, userAgent }) {
  const seen = new Set();
  const items = listings.map((raw, index) => {
    const row = index + 1;
    const externalId = typeof raw?.externalId === "string" ? raw.externalId.trim() : null;
    try {
      const record = parseListingRecord(raw);
      if (seen.has(record.externalId)) {
        throw new AppError("This externalId appears more than once in the batch.", {
          status: 422,
          code: "DUPLICATE_IN_BATCH",
          fields: { externalId: "Send each listing once per batch." },
        });
      }
      seen.add(record.externalId);
      return { row, externalId: record.externalId, raw: record };
    } catch (error) {
      return { row, externalId, raw, error };
    }
  });

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
    `SELECT ac.id, ac.public_id, ac.name, ac.client_id, ac.status, ac.created_by_user_id, ac.organization_id,
            COALESCE(ac.account_id, o.account_id) AS account_id, o.public_id AS organization_public_id,
            o.status AS organization_status
       FROM api_clients ac JOIN organizations o ON o.id = ac.organization_id
      WHERE ac.id = ?`,
    [run.api_client_id]
  );
  if (!row) return null;
  return {
    id: row.id,
    publicId: row.public_id,
    name: row.name,
    clientId: row.client_id,
    status: row.status,
    organizationStatus: row.organization_status,
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
    `SELECT id, public_id, connection_id, provider_id, api_client_id, feed_source_id, organization_id, account_id,
            INET6_NTOA(source_ip) AS source_ip
       FROM feed_imports WHERE id = ?`,
    [importId]
  );
  const ctx = { providerId: Number(run.provider_id), connectionId: Number(run.connection_id) };
  // A feed run (0063) imports as its feed; everything else as the API key that pushed it.
  const client = run.feed_source_id ? await feedClientFor(run.feed_source_id) : run.api_client_id ? await clientForRun(run) : null;
  const source = run.feed_source_id ? "feed" : "api";
  const items = await query(
    "SELECT id, raw_payload FROM feed_import_items WHERE import_id = ? AND status = 'queued' ORDER BY source_row ASC, id ASC",
    [importId]
  );

  for (const item of items) {
    try {
      // A key revoked, or a company suspended, after the batch was accepted stops the rest of it.
      if (!client || client.status !== "active" || client.organizationStatus !== "active") {
        throw new AppError(`The ${source === "feed" ? "feed" : "API key"} or account was disabled before this listing was processed.`, {
          status: 401,
          code: "API_KEY_INVALID",
        });
      }
      await assertAddonActive(client.accountId, "integrations");
      const raw = typeof item.raw_payload === "string" ? JSON.parse(item.raw_payload) : item.raw_payload;
      const record = parseListingRecord(raw);
      const outcome = await importListing({ client, ctx, record, source, importId: run.public_id, ip: run.source_ip });
      await repo.recordItemSuccess(item.id, importId, outcome);
    } catch (error) {
      if (!(error instanceof AppError) || error.status >= 500) {
        logger.error({ err: error, importId: run.public_id, itemId: item.id }, "listing import item failed");
      }
      await repo.recordItemFailure(item.id, error).catch((writeError) => logger.error({ err: writeError }, "import item result not recorded"));
    }
  }

  const status = await repo.finalizeImport(importId);
  if (status === "partial" || status === "failed") {
    const failed = await queryOne("SELECT failed_count, total_rows FROM feed_imports WHERE id = ?", [importId]);
    await notifyAccount(
      { accountId: run.account_id, organizationId: run.organization_id },
      {
        type: "listing_import.failed_items",
        title: `${failed.failed_count} of ${failed.total_rows} listings in an API import failed`,
        body: "Open API & Integrations to see what needs fixing.",
        actionUrl: "/portal/integrations",
        icon: "alert",
        subjectType: "feed_import",
        subjectId: importId,
        data: { importId: run.public_id },
      }
    ).catch(() => {});
  }
  return status;
}

/** Picks up imports left queued, or stranded mid-run by a restart, and processes them. */
export async function runQueuedImports() {
  const providerId = await importProviderId().catch(() => null);
  if (!providerId) return 0;
  await execute(
    `UPDATE feed_imports fi SET fi.status = 'queued'
      WHERE fi.provider_id = ? AND fi.status = 'running' AND fi.started_at < DATE_SUB(NOW(3), INTERVAL 15 MINUTE)
        AND EXISTS (SELECT 1 FROM feed_import_items fii WHERE fii.import_id = fi.id AND fii.status = 'queued')`,
    [providerId]
  );
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
