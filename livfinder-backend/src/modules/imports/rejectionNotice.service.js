import logger from "../../config/logger.js";
import { query, queryOne } from "../../db/query.js";
import { notifyAccount } from "../system/notifications.service.js";

/** Enough to act on in one email; the rest are in the portal, with every reason. */
const MAX_LISTED = 100;

function reasonsOf(item) {
  const body = typeof item.errors === "string" ? JSON.parse(item.errors) : item.errors;
  const fields = body?.fields;
  if (fields && Object.keys(fields).length) return Object.entries(fields).map(([field, message]) => `${field}: ${message}`);
  return [item.error_message || "This listing could not be imported."];
}

function titleOf(item) {
  const raw = typeof item.raw_payload === "string" ? JSON.parse(item.raw_payload) : item.raw_payload;
  return raw?.title || raw?.name || null;
}

/**
 * Tells the client which listings of an import were rejected and exactly why: a portal
 * notification, and an email to the account's owners. One message per import, not one per
 * listing, so a bad file does not send thousands of emails.
 */
export async function notifyRejectedListings(importId) {
  const run = await queryOne(
    "SELECT id, public_id, account_id, organization_id, failed_count, total_rows FROM feed_imports WHERE id = ?",
    [importId]
  );
  if (!run || !Number(run.failed_count)) return;
  const items = await query(
    `SELECT source_row, external_id, raw_payload, errors, error_message
       FROM feed_import_items WHERE import_id = ? AND status = 'failed' ORDER BY source_row ASC, id ASC LIMIT ${MAX_LISTED}`,
    [importId]
  );
  const failed = Number(run.failed_count);
  const title = `${failed} of ${run.total_rows} ${run.total_rows === 1 ? "listing was" : "listings were"} rejected`;
  const listed = items.map((item) => ({
    row: item.source_row,
    id: item.external_id || "no id",
    title: titleOf(item),
    reasons: reasonsOf(item),
  }));
  const first = listed[0];

  await notifyAccount(
    { accountId: run.account_id, organizationId: run.organization_id },
    {
      type: "listing_import.failed_items",
      title,
      body: `${first.id}: ${first.reasons[0]}`.slice(0, 240),
      actionUrl: "/portal/integrations",
      icon: "alert",
      subjectType: "feed_import",
      subjectId: importId,
      data: { importId: run.public_id },
    }
  ).catch(() => {});

  const { emailAccount } = await import("../email/send.js");
  await emailAccount(
    { accountId: run.account_id, organizationId: run.organization_id, roles: ["owner"] },
    "integrations.import_rejected",
    { failed, total: Number(run.total_rows), items: listed, more: Math.max(0, failed - listed.length) },
    { dedupeKey: `import.rejected:${run.id}` }
  ).catch((error) => logger.warn({ err: error, importId }, "rejected listings email not queued"));
}
