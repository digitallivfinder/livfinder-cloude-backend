import crypto from "node:crypto";
import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute, query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { randomToken, sha256, ulid } from "../../utils/ids.js";
import { assertSafeUrl, safeFetch } from "../../utils/safeFetch.js";
import { decryptSecret, encryptSecret } from "../../utils/secrets.js";
import { isAddonActive } from "../accounts/addons.service.js";
import { notifyAccount } from "../system/notifications.service.js";
import { deliverableAccount, loadLead } from "./leadExport.service.js";

/**
 * Webhooks (Phase 6, 0064): LivFinder POSTs each event to the company's own endpoint, as part of
 * the Integrations add-on. One endpoint per company, carrying the agent of each lead; the company
 * routes it on their side (owner's rule, 2026-10-29).
 *
 * Every request is signed: `LivFinder-Signature: t=<unix seconds>,v1=<hex HMAC-SHA256 of
 * "<t>.<raw body>" with the endpoint's secret>`. `LivFinder-Event-Id` is the same on every retry,
 * so a receiver can drop a repeat. A delivery that does not get a 2xx is retried after 1 minute,
 * 5 minutes, 30 minutes, 2 hours and 12 hours, then given up. An endpoint that keeps failing is
 * marked failing, and switched off after 20 failures in a row (the company is told).
 *
 * `webhook_deliveries` is the outbox: an event is written there when it happens and the worker
 * delivers it, so a slow or broken endpoint never holds up the visitor who sent the enquiry.
 * Rows without an `event_id` predate this and are never sent.
 */

export const WEBHOOK_EVENTS = Object.freeze([
  "lead.created",
  "lead.updated",
  "listing.changes_approved",
  "listing.changes_rejected",
  "development.changes_approved",
  "development.changes_rejected",
]);
const RETRY_MINUTES = [1, 5, 30, 120, 720];
const DISABLE_AFTER = 20;
const TIMEOUT_MS = 10_000;

const json = (value, fallback) => {
  if (value === null || value === undefined) return fallback;
  if (typeof value !== "string") return value;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
};

function serializeWebhook(row) {
  return {
    id: row.public_id,
    name: row.name,
    url: row.target_url,
    events: json(row.events, []),
    status: row.status,
    secretHint: row.secret_hint ? `••••${row.secret_hint}` : null,
    consecutiveFailures: Number(row.consecutive_failures) || 0,
    lastSuccessAt: row.last_success_at,
    lastFailureAt: row.last_failure_at,
    createdAt: row.created_at,
  };
}

async function assertUrl(url) {
  try {
    await assertSafeUrl(url, { useAllowList: false });
  } catch (error) {
    throw AppError.validation("Some information is invalid.", { url: error.message });
  }
}

async function ownWebhook(accountId, publicId) {
  const row = await queryOne("SELECT * FROM webhooks WHERE public_id = ? AND account_id = ? AND secret_encrypted IS NOT NULL", [publicId, accountId]);
  if (!row) throw AppError.notFound("That webhook was not found.");
  return row;
}

export async function listWebhooks(accountId) {
  const rows = await query("SELECT * FROM webhooks WHERE account_id = ? AND secret_encrypted IS NOT NULL ORDER BY created_at DESC", [accountId]);
  return rows.map(serializeWebhook);
}

function newSecret() {
  return `whsec_${randomToken(24)}`;
}

/** Creates an endpoint. The secret is returned this once and never again. */
export async function createWebhook({ accountId, name, url, events, userId }) {
  await assertUrl(url);
  const secret = newSecret();
  const publicId = ulid();
  await execute(
    `INSERT INTO webhooks (public_id, account_id, name, target_url, events, secret_hash, secret_encrypted, secret_hint, status, created_by_user_id)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', ?)`,
    [publicId, accountId, name, url, JSON.stringify(events), sha256(secret), encryptSecret(secret), secret.slice(-4), userId ?? null]
  );
  const row = await ownWebhook(accountId, publicId);
  return { ...serializeWebhook(row), secret };
}

export async function updateWebhook({ accountId, publicId, name, url, events, status }) {
  const row = await ownWebhook(accountId, publicId);
  const assignments = [];
  const params = [];
  if (name !== undefined) {
    assignments.push("name = ?");
    params.push(name);
  }
  if (url !== undefined) {
    await assertUrl(url);
    assignments.push("target_url = ?");
    params.push(url);
  }
  if (events !== undefined) {
    assignments.push("events = ?");
    params.push(JSON.stringify(events));
  }
  if (status !== undefined) {
    assignments.push("status = ?");
    params.push(status);
    if (status === "active") assignments.push("consecutive_failures = 0");
  }
  if (assignments.length) await execute(`UPDATE webhooks SET ${assignments.join(", ")} WHERE id = ?`, [...params, row.id]);
  return serializeWebhook(await ownWebhook(accountId, publicId));
}

export async function rotateWebhookSecret({ accountId, publicId }) {
  const row = await ownWebhook(accountId, publicId);
  const secret = newSecret();
  await execute("UPDATE webhooks SET secret_hash = ?, secret_encrypted = ?, secret_hint = ? WHERE id = ?", [
    sha256(secret),
    encryptSecret(secret),
    secret.slice(-4),
    row.id,
  ]);
  return { ...serializeWebhook(await ownWebhook(accountId, publicId)), secret };
}

export async function deleteWebhook({ accountId, publicId }) {
  const row = await ownWebhook(accountId, publicId);
  await execute("DELETE FROM webhooks WHERE id = ?", [row.id]);
  return true;
}

export async function listDeliveries({ accountId, publicId, limit = 20 }) {
  const row = await ownWebhook(accountId, publicId);
  const rows = await query(
    `SELECT event_id, event_type, status, attempts, response_status, last_error, duration_ms, next_retry_at, delivered_at, created_at
       FROM webhook_deliveries WHERE webhook_id = ? AND event_id IS NOT NULL ORDER BY id DESC LIMIT ${Math.min(100, Number(limit) || 20)}`,
    [row.id]
  );
  return rows.map((item) => ({
    eventId: item.event_id,
    event: item.event_type,
    status: item.status,
    attempts: Number(item.attempts),
    responseStatus: item.response_status === null ? null : Number(item.response_status),
    error: item.last_error,
    durationMs: item.duration_ms === null ? null : Number(item.duration_ms),
    nextRetryAt: item.status === "pending" ? item.next_retry_at : null,
    deliveredAt: item.delivered_at,
    createdAt: item.created_at,
  }));
}

/* -------------------------------------------------------------------------- */
/* Events                                                                      */
/* -------------------------------------------------------------------------- */

let kick = null;

/**
 * Writes an event to the outbox of every endpoint of the account subscribed to it. Nothing is
 * written while the Integrations add-on is off. Returns the event id, or null.
 */
export async function enqueueEvent({ accountId, event, data, webhookIds = null, deliverNow = true }) {
  if (!accountId || !(await isAddonActive(accountId, "integrations"))) return null;
  const hooks = await query(
    `SELECT id FROM webhooks
      WHERE account_id = ? AND secret_encrypted IS NOT NULL AND status IN ('active', 'failing')
        ${webhookIds ? `AND id IN (${webhookIds.map(() => "?").join(", ")})` : "AND JSON_CONTAINS(events, JSON_QUOTE(?))"}`,
    webhookIds ? [accountId, ...webhookIds] : [accountId, event]
  );
  if (!hooks.length) return null;
  const eventId = ulid();
  const payload = JSON.stringify({ id: eventId, type: event, createdAt: new Date().toISOString(), data });
  for (const hook of hooks) {
    await execute(
      `INSERT INTO webhook_deliveries (webhook_id, event_id, event_type, payload, status, attempts, next_retry_at, created_at)
       VALUES (?, ?, ?, ?, 'pending', 0, NOW(3), NOW(3))`,
      [hook.id, eventId, event, payload]
    );
  }
  if (deliverNow && !env.isTest) {
    clearImmediate(kick);
    kick = setImmediate(() => deliverDue().catch((error) => logger.error({ err: error }, "webhook delivery failed")));
  }
  return eventId;
}

/** A lead was created or changed: tell the company's endpoints, if the lead may go out. */
export async function emitLeadEvent(kind, id, event) {
  try {
    const accountId = await deliverableAccount(kind, id);
    if (!accountId) return null;
    const lead = await loadLead(kind, id);
    if (!lead) return null;
    return await enqueueEvent({ accountId, event, data: { lead } });
  } catch (error) {
    // An event that could not be written must never fail the enquiry that caused it.
    logger.error({ err: error, kind, id, event }, "lead event not recorded");
    return null;
  }
}

/** The same, for a lead known by its public id (bookings and offers are answered by it). */
export async function emitLeadEventByPublicId(kind, publicId, event) {
  const table = { inquiry: "inquiries", booking: "bookings", offer: "offers" }[kind];
  const row = table ? await queryOne(`SELECT id FROM ${table} WHERE public_id = ?`, [publicId]).catch(() => null) : null;
  return row ? emitLeadEvent(kind, Number(row.id), event) : null;
}

/* -------------------------------------------------------------------------- */
/* Delivery                                                                    */
/* -------------------------------------------------------------------------- */

// Tests stand in for the network here; the real transport refuses local addresses.
let transport = safeFetch;
export function setWebhookTransport(fn) {
  transport = fn || safeFetch;
}

export function signPayload(secret, body, timestamp = Math.floor(Date.now() / 1000)) {
  const signature = crypto.createHmac("sha256", secret).update(`${timestamp}.${body}`).digest("hex");
  return `t=${timestamp},v1=${signature}`;
}

async function deliverOne(delivery) {
  const secret = decryptSecret(delivery.secret_encrypted);
  const body = typeof delivery.payload === "string" ? delivery.payload : JSON.stringify(delivery.payload);
  const attempt = Number(delivery.attempts) + 1;
  const started = Date.now();
  let status = null;
  let error = null;
  let responseText = null;
  try {
    if (!secret) throw new Error("the endpoint's secret could not be read");
    const response = await transport(delivery.target_url, {
      useAllowList: false,
      timeoutMs: TIMEOUT_MS,
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "LivFinder-Webhooks/1.0",
        "LivFinder-Event": delivery.event_type,
        "LivFinder-Event-Id": delivery.event_id,
        "LivFinder-Delivery": String(delivery.id),
        "LivFinder-Signature": signPayload(secret, body),
      },
      body,
    });
    status = response.status;
    responseText = (await response.text().catch(() => "")).slice(0, 2000);
    if (!response.ok) error = `The endpoint answered ${status}.`;
  } catch (caught) {
    error = String(caught?.message || "The endpoint could not be reached.").slice(0, 500);
  }
  const duration = Date.now() - started;

  if (!error) {
    await execute(
      `UPDATE webhook_deliveries SET status = 'delivered', attempts = ?, response_status = ?, response_body = ?, last_error = NULL,
              duration_ms = ?, delivered_at = NOW(3), next_retry_at = NULL WHERE id = ?`,
      [attempt, status, responseText, duration, delivery.id]
    );
    await execute(
      `UPDATE webhooks SET last_success_at = NOW(3), consecutive_failures = 0, status = IF(status = 'failing', 'active', status) WHERE id = ?`,
      [delivery.webhook_id]
    );
    return { delivered: true, status };
  }

  const giveUp = attempt > RETRY_MINUTES.length;
  await execute(
    `UPDATE webhook_deliveries SET status = ?, attempts = ?, response_status = ?, response_body = ?, last_error = ?, duration_ms = ?,
            next_retry_at = ? WHERE id = ?`,
    [
      giveUp ? "abandoned" : "pending",
      attempt,
      status,
      responseText,
      error,
      duration,
      giveUp ? null : new Date(Date.now() + RETRY_MINUTES[attempt - 1] * 60_000),
      delivery.id,
    ]
  );
  const failures = Number(delivery.consecutive_failures) + 1;
  const disable = failures >= DISABLE_AFTER;
  await execute(
    `UPDATE webhooks SET last_failure_at = NOW(3), consecutive_failures = ?, status = ? WHERE id = ? AND status <> 'paused'`,
    [failures, disable ? "disabled" : "failing", delivery.webhook_id]
  );
  if (disable && delivery.webhook_status !== "disabled") {
    await notifyAccount(
      { accountId: delivery.account_id },
      {
        type: "webhook.disabled",
        title: `Webhook "${delivery.webhook_name}" was switched off`,
        body: `It failed ${failures} times in a row (last: ${error}). Fix the endpoint and turn it back on in API & Integrations.`,
        actionUrl: "/portal/integrations",
        icon: "alert",
        subjectType: "webhook",
        subjectId: delivery.webhook_id,
      }
    ).catch(() => {});
  }
  return { delivered: false, status, error, willRetry: !giveUp };
}

/** Sends every delivery that is due, one at a time; each is claimed first so no two workers send it. */
export async function deliverDue({ limit = 50, deliveryIds = null } = {}) {
  const due = await query(
    `SELECT d.id FROM webhook_deliveries d JOIN webhooks w ON w.id = d.webhook_id
      WHERE d.event_id IS NOT NULL AND d.status = 'pending' AND d.next_retry_at <= NOW(3)
        AND w.status IN ('active', 'failing') AND w.secret_encrypted IS NOT NULL
        ${deliveryIds ? `AND d.id IN (${deliveryIds.map(() => "?").join(", ")})` : ""}
      ORDER BY d.next_retry_at ASC, d.id ASC LIMIT ${Number(limit)}`,
    deliveryIds || []
  );
  const results = [];
  for (const { id } of due) {
    // The claim: push the retry time out, so a second worker skips it while this one sends.
    const claim = await execute(
      "UPDATE webhook_deliveries SET next_retry_at = DATE_ADD(NOW(3), INTERVAL 5 MINUTE) WHERE id = ? AND status = 'pending' AND next_retry_at <= NOW(3)",
      [id]
    );
    if (!claim.affectedRows) continue;
    const delivery = await queryOne(
      `SELECT d.id, d.webhook_id, d.event_id, d.event_type, d.payload, d.attempts,
              w.target_url, w.secret_encrypted, w.consecutive_failures, w.status AS webhook_status, w.name AS webhook_name, w.account_id
         FROM webhook_deliveries d JOIN webhooks w ON w.id = d.webhook_id WHERE d.id = ?`,
      [id]
    );
    results.push({ id, ...(await deliverOne(delivery)) });
  }
  return results;
}

/** Sends a `ping` to one endpoint now and reports what came back. */
export async function sendTestEvent({ accountId, publicId }) {
  const row = await ownWebhook(accountId, publicId);
  if (!(await isAddonActive(accountId, "integrations"))) {
    throw new AppError("The Integrations add-on is off, so nothing is sent.", { status: 403, code: "ADDON_INACTIVE" });
  }
  // Sent here, not by the background worker, so the answer can be reported straight back.
  const eventId = await enqueueEvent({
    accountId,
    event: "ping",
    data: { message: "A test event from LivFinder." },
    webhookIds: [row.id],
    deliverNow: false,
  });
  const delivery = await queryOne("SELECT id FROM webhook_deliveries WHERE event_id = ? AND webhook_id = ?", [eventId, row.id]);
  const [result] = await deliverDue({ deliveryIds: [delivery.id] });
  return result ?? { delivered: false, error: "The test was already being sent." };
}

export function startWebhookWorker({ intervalMs = 30 * 1000 } = {}) {
  if (env.isTest) return null;
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      await deliverDue();
    } catch (error) {
      logger.error({ err: error }, "webhook worker failed");
    } finally {
      running = false;
    }
  };
  const timer = setInterval(tick, intervalMs);
  timer.unref?.();
  return timer;
}
