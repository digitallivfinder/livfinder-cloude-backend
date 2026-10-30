import logger from "../../config/logger.js";
import { query, queryOne } from "../../db/query.js";
import { notifyAccount } from "../system/notifications.service.js";
import { sendMail } from "../system/mail.service.js";

/** Enough to act on in one email; the rest are in the portal, with every reason. */
const MAX_LISTED = 100;

const escapeHtml = (value) =>
  String(value ?? "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

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

  const owners = await query(
    `SELECT DISTINCT u.email FROM account_members m JOIN users u ON u.id = m.user_id
      WHERE m.account_id = ? AND m.role = 'owner' AND m.status = 'active' AND u.email IS NOT NULL`,
    [run.account_id]
  );
  if (!owners.length) return;

  const more = failed > listed.length ? `\n…and ${failed - listed.length} more. See them all under API & Integrations in the portal.` : "";
  const text = [
    `${title} and did not come in. Fix them and send them again; the others were not affected.`,
    "",
    ...listed.flatMap((item) => [`Row ${item.row} · ${item.id}${item.title ? ` · ${item.title}` : ""}`, ...item.reasons.map((reason) => `  - ${reason}`), ""]),
  ].join("\n") + more;
  const html = `<p>${escapeHtml(title)} and did not come in. Fix them and send them again; the others were not affected.</p>${listed
    .map(
      (item) =>
        `<p><strong>Row ${escapeHtml(item.row)} · ${escapeHtml(item.id)}${item.title ? ` · ${escapeHtml(item.title)}` : ""}</strong></p><ul>${item.reasons
          .map((reason) => `<li>${escapeHtml(reason)}</li>`)
          .join("")}</ul>`
    )
    .join("")}${more ? `<p>${escapeHtml(more.trim())}</p>` : ""}`;

  for (const owner of owners) {
    await sendMail({ to: owner.email, subject: `LivFinder: ${title}`, text, html }).catch((error) =>
      logger.warn({ err: error, importId }, "rejected listings email not sent")
    );
  }
}
