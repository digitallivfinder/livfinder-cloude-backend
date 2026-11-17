import crypto from "node:crypto";
import express, { Router } from "express";
import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute, queryOne } from "../../db/query.js";
import { asyncHandler } from "../../middleware/errors.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse } from "../../utils/http.js";
import { CATEGORIES } from "./catalog.js";
import { normalizeEmail, readUnsubscribeToken, resubscribe, suppress, unsubscribe } from "./preferences.js";

/**
 * Public email endpoints, mounted at /v1/email ahead of CSRF:
 *
 *   GET  /unsubscribe?token=   what the link is for (the website's /email-preferences page shows it)
 *   POST /unsubscribe?token=   unsubscribe. Also the RFC 8058 one-click target that Gmail and
 *                              Yahoo call from their own "Unsubscribe" button, with no cookie.
 *   POST /resubscribe?token=   undo, from the same page
 *   POST /events/:provider     bounces and complaints from the mail provider (postmark, ses,
 *                              sendgrid, or a generic { email, event }) with EMAIL_WEBHOOK_SECRET
 */
export const emailPublicRouter = Router();

const maskEmail = (email) => email.replace(/^(.)(.*)(@.*)$/, (_, first, middle, domain) => `${first}${"•".repeat(Math.min(6, middle.length))}${domain}`);

function tokenFrom(req) {
  const parsed = readUnsubscribeToken(req.query.token || req.body?.token);
  if (!parsed) throw AppError.badRequest("That link is not valid. Use the link from the newest email, or change your choices in Notification settings.");
  return parsed;
}

emailPublicRouter.get(
  "/unsubscribe",
  asyncHandler(async (req, res) => {
    const { email, category } = tokenFrom(req);
    const suppressed = await queryOne("SELECT id FROM email_suppressions WHERE email = ? AND scope IN ('all', ?) LIMIT 1", [email, category]);
    res.json(detailResponse({ email: maskEmail(email), category, label: CATEGORIES[category].label, description: CATEGORIES[category].description, optional: CATEGORIES[category].optional, unsubscribed: Boolean(suppressed) }));
  })
);

emailPublicRouter.post(
  "/unsubscribe",
  express.urlencoded({ extended: false }),
  express.json(),
  asyncHandler(async (req, res) => {
    const parsed = tokenFrom(req);
    const result = await unsubscribe(parsed);
    await execute(
      "INSERT INTO email_events (email, event, detail, created_at) VALUES (?, 'unsubscribed', ?, NOW(3))",
      [parsed.email, parsed.category]
    ).catch(() => {});
    res.json(detailResponse({ ...result, email: maskEmail(parsed.email), label: CATEGORIES[parsed.category].label }));
  })
);

emailPublicRouter.post(
  "/resubscribe",
  express.json(),
  asyncHandler(async (req, res) => {
    const parsed = tokenFrom(req);
    const result = await resubscribe(parsed);
    res.json(detailResponse({ ...result, email: maskEmail(parsed.email), label: CATEGORIES[parsed.category].label }));
  })
);

/* -------------------------------------------------------------------------- */
/* Provider events                                                             */
/* -------------------------------------------------------------------------- */

/** Turns each provider's payload into [{ email, event, providerMessageId, detail, hard }]. */
export function normalizeProviderEvents(provider, body) {
  const out = [];
  if (provider === "postmark") {
    const type = body?.RecordType;
    if (type === "Bounce") out.push({ email: body.Email, event: body.Type === "HardBounce" || body.Inactive ? "bounced" : "soft_bounced", providerMessageId: body.MessageID, detail: body.Description || body.Type });
    if (type === "SpamComplaint") out.push({ email: body.Email, event: "complained", providerMessageId: body.MessageID, detail: "Spam complaint" });
    if (type === "Delivery") out.push({ email: body.Recipient, event: "delivered", providerMessageId: body.MessageID });
    return out;
  }
  if (provider === "ses") {
    // SNS wraps the SES notification as a JSON string in Message.
    const message = typeof body?.Message === "string" ? JSON.parse(body.Message) : body?.Message ?? body;
    const id = message?.mail?.messageId;
    if (message?.notificationType === "Bounce" || message?.eventType === "Bounce") {
      const hard = message.bounce?.bounceType === "Permanent";
      for (const recipient of message.bounce?.bouncedRecipients ?? []) out.push({ email: recipient.emailAddress, event: hard ? "bounced" : "soft_bounced", providerMessageId: id, detail: recipient.diagnosticCode || message.bounce?.bounceSubType });
    }
    if (message?.notificationType === "Complaint" || message?.eventType === "Complaint") {
      for (const recipient of message.complaint?.complainedRecipients ?? []) out.push({ email: recipient.emailAddress, event: "complained", providerMessageId: id, detail: message.complaint?.complaintFeedbackType || "Complaint" });
    }
    if (message?.notificationType === "Delivery" || message?.eventType === "Delivery") {
      for (const email of message.delivery?.recipients ?? []) out.push({ email, event: "delivered", providerMessageId: id });
    }
    return out;
  }
  if (provider === "sendgrid") {
    for (const item of Array.isArray(body) ? body : [body]) {
      const map = { bounce: item.type === "blocked" ? "soft_bounced" : "bounced", dropped: "rejected", spamreport: "complained", delivered: "delivered", deferred: "soft_bounced" };
      if (map[item.event]) out.push({ email: item.email, event: map[item.event], providerMessageId: String(item.sg_message_id || "").split(".")[0], detail: item.reason || item.event });
    }
    return out;
  }
  // Generic: { email, event: bounced|soft_bounced|complained|delivered, messageId, detail }
  for (const item of Array.isArray(body) ? body : [body]) {
    if (item?.email && item?.event) out.push({ email: item.email, event: item.event, providerMessageId: item.messageId, detail: item.detail });
  }
  return out;
}

const SOFT_BOUNCE_LIMIT = 3;

async function recordProviderEvent(provider, item, raw) {
  const email = normalizeEmail(item.email);
  if (!email) return;
  const message = item.providerMessageId
    ? await queryOne("SELECT id FROM email_messages WHERE provider_message_id = ? OR provider_message_id = ? LIMIT 1", [item.providerMessageId, `<${item.providerMessageId}>`])
    : null;
  await execute(
    "INSERT INTO email_events (message_id, email, event, provider, detail, payload, created_at) VALUES (?, ?, ?, ?, ?, ?, NOW(3))",
    [message?.id ?? null, email, item.event, provider, item.detail ? String(item.detail).slice(0, 500) : null, JSON.stringify(raw ?? null)]
  );
  if (message && item.event === "delivered") await execute("UPDATE email_messages SET delivered_at = NOW(3) WHERE id = ?", [message.id]);
  if (message && (item.event === "bounced" || item.event === "soft_bounced")) await execute("UPDATE email_messages SET bounced_at = NOW(3) WHERE id = ?", [message.id]);

  if (item.event === "bounced" || item.event === "rejected") await suppress(email, { reason: "hard_bounce", detail: item.detail });
  if (item.event === "complained") await suppress(email, { reason: "complaint", detail: item.detail });
  if (item.event === "soft_bounced") {
    const recent = await queryOne(
      "SELECT COUNT(*) AS n FROM email_events WHERE email = ? AND event = 'soft_bounced' AND created_at >= DATE_SUB(NOW(3), INTERVAL 7 DAY)",
      [email]
    );
    if (Number(recent?.n) >= SOFT_BOUNCE_LIMIT) await suppress(email, { reason: "soft_bounce", detail: `${recent.n} soft bounces in 7 days` });
  }
}

function secretMatches(req) {
  if (!env.EMAIL_WEBHOOK_SECRET) return false;
  const given = String(req.query.secret || req.get("x-livfinder-secret") || "");
  const expected = env.EMAIL_WEBHOOK_SECRET;
  return given.length === expected.length && crypto.timingSafeEqual(Buffer.from(given), Buffer.from(expected));
}

emailPublicRouter.post(
  "/events/:provider",
  // SES posts through SNS as text/plain JSON.
  express.text({ type: ["text/plain", "application/json"], limit: "1mb" }),
  asyncHandler(async (req, res) => {
    if (!secretMatches(req)) throw AppError.notFound();
    const provider = String(req.params.provider).toLowerCase();
    let body = req.body;
    if (typeof body === "string") {
      try {
        body = JSON.parse(body);
      } catch {
        throw AppError.badRequest("Expected JSON.");
      }
    }
    // SNS asks once to confirm the subscription; the URL is Amazon's and only fetched for SNS.
    if (provider === "ses" && body?.Type === "SubscriptionConfirmation" && /^https:\/\/sns\.[a-z0-9-]+\.amazonaws\.com\//.test(body.SubscribeURL || "")) {
      await fetch(body.SubscribeURL).catch((error) => logger.warn({ err: error }, "SNS subscription confirmation failed"));
      return res.json(detailResponse({ confirmed: true }));
    }
    const events = normalizeProviderEvents(provider, body);
    for (const item of events) await recordProviderEvent(provider, item, body);
    res.json(detailResponse({ received: events.length }));
  })
);
