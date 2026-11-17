import { Router } from "express";
import { z } from "zod";
import env from "../../config/env.js";
import { execute, query, queryOne } from "../../db/query.js";
import { asyncHandler } from "../../middleware/errors.js";
import { requireAdmin, requireAuth, requirePermission } from "../../middleware/auth.js";
import { q, validate } from "../../middleware/validation.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse, listResponse } from "../../utils/http.js";
import { ulid } from "../../utils/ids.js";
import { verifyTransport } from "../system/mail.service.js";
import { auditFromRequest } from "../system/audit.service.js";
import { CATEGORIES } from "./catalog.js";
import { normalizeEmail, suppress } from "./preferences.js";
import { queueEmail } from "./send.js";
import { TEMPLATES } from "./templates/index.js";
import { composeMessage, deliverDue } from "./worker.js";

/**
 * Admin → Emails (/v1/admin/emails): the sent log, template previews and test sends, the mail
 * connection, suppressions, and newsletter issues. Read with emails.view, act with emails.manage.
 */
const router = Router();
router.use(requireAuth, requireAdmin);

const STATUSES = ["queued", "held", "sending", "sent", "failed", "suppressed", "skipped", "digested"];

const listQuery = z.object({
  page: z.coerce.number().int().min(1).max(5000).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).optional(),
  q: z.string().trim().max(200).optional(),
  status: z.string().trim().max(200).optional(),
  template: z.string().trim().max(400).optional(),
  category: z.string().trim().max(400).optional(),
  from: z.string().trim().max(30).optional(),
  to: z.string().trim().max(30).optional(),
});

const csv = (value) => String(value || "").split(",").map((item) => item.trim()).filter(Boolean);

function serializeMessage(row) {
  return {
    id: row.public_id,
    template: row.template_key,
    templateLabel: TEMPLATES[row.template_key]?.label ?? row.template_key,
    category: row.category,
    categoryLabel: CATEGORIES[row.category]?.label ?? row.category,
    to: row.to_email,
    toName: row.to_name,
    subject: row.subject,
    status: row.status,
    statusReason: row.status_reason,
    attempts: row.attempts,
    lastError: row.last_error,
    provider: row.provider,
    createdAt: row.created_at,
    sendAfter: row.send_after,
    sentAt: row.sent_at,
    deliveredAt: row.delivered_at,
    bouncedAt: row.bounced_at,
  };
}

/* ----------------------------------- log ---------------------------------- */

router.get(
  "/emails",
  requirePermission("emails.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const input = q(req);
    const page = Number(input.page) || 1;
    const pageSize = Number(input.pageSize) || 20;
    const where = ["1 = 1"];
    const params = [];
    if (input.q) {
      where.push("(to_email LIKE ? OR subject LIKE ? OR public_id = ?)");
      params.push(`%${input.q}%`, `%${input.q}%`, input.q);
    }
    const statuses = csv(input.status).filter((value) => STATUSES.includes(value));
    if (statuses.length) { where.push(`status IN (${statuses.map(() => "?").join(",")})`); params.push(...statuses); }
    const templates = csv(input.template).filter((value) => TEMPLATES[value]);
    if (templates.length) { where.push(`template_key IN (${templates.map(() => "?").join(",")})`); params.push(...templates); }
    const categories = csv(input.category).filter((value) => CATEGORIES[value]);
    if (categories.length) { where.push(`category IN (${categories.map(() => "?").join(",")})`); params.push(...categories); }
    if (input.from) { where.push("created_at >= ?"); params.push(new Date(input.from)); }
    if (input.to) { where.push("created_at < DATE_ADD(?, INTERVAL 1 DAY)"); params.push(new Date(input.to)); }

    const [rows, total, summary] = await Promise.all([
      query(`SELECT * FROM email_messages WHERE ${where.join(" AND ")} ORDER BY id DESC LIMIT ${pageSize} OFFSET ${(page - 1) * pageSize}`, params),
      queryOne(`SELECT COUNT(*) AS n FROM email_messages WHERE ${where.join(" AND ")}`, params),
      queryOne(
        `SELECT SUM(status = 'sent') AS sent, SUM(status IN ('queued','sending')) AS queued, SUM(status = 'failed') AS failed,
                SUM(status = 'suppressed') AS suppressed, SUM(bounced_at IS NOT NULL) AS bounced
           FROM email_messages WHERE created_at >= DATE_SUB(NOW(3), INTERVAL 7 DAY)`
      ),
    ]);
    res.json({
      ...listResponse(rows.map(serializeMessage), { page, pageSize, total: Number(total?.n ?? 0) }),
      summary: Object.fromEntries(Object.entries(summary ?? {}).map(([key, value]) => [key, Number(value ?? 0)])),
      options: {
        statuses: STATUSES.map((value) => ({ value, label: value[0].toUpperCase() + value.slice(1) })),
        templates: Object.entries(TEMPLATES).map(([value, template]) => ({ value, label: template.label })),
        categories: Object.entries(CATEGORIES).map(([value, category]) => ({ value, label: category.label })),
      },
    });
  })
);

/* -------------------------------- templates ------------------------------- */

router.get(
  "/emails/templates",
  requirePermission("emails.view"),
  asyncHandler(async (req, res) => {
    const counts = await query(
      "SELECT template_key, COUNT(*) AS n, MAX(created_at) AS last FROM email_messages WHERE created_at >= DATE_SUB(NOW(3), INTERVAL 30 DAY) GROUP BY template_key"
    );
    const byKey = Object.fromEntries(counts.map((row) => [row.template_key, row]));
    res.json(
      detailResponse(
        Object.entries(TEMPLATES).map(([key, template]) => ({
          key,
          label: template.label,
          category: template.category,
          categoryLabel: CATEGORIES[template.category].label,
          optional: CATEGORIES[template.category].optional,
          digest: Boolean(template.digestible),
          sentLast30Days: Number(byKey[key]?.n ?? 0),
          lastSentAt: byKey[key]?.last ?? null,
        }))
      )
    );
  })
);

function sampleRow(key, to = "preview@livfinder.com") {
  const template = TEMPLATES[key];
  if (!template) throw AppError.notFound("That template was not found.");
  return { template_key: key, data: template.sample ?? {}, to_email: to, to_name: null, public_id: "PREVIEW", user_id: null, reply_to: null };
}

router.get(
  "/emails/templates/:key/preview",
  requirePermission("emails.view"),
  asyncHandler(async (req, res) => {
    const message = await composeMessage(sampleRow(req.params.key), { forceDark: req.query.theme === "dark" });
    if (req.query.format === "text") return res.type("text/plain").send(message.text);
    if (req.query.format === "json") return res.json(detailResponse({ subject: message.subject, text: message.text, html: message.html }));
    res.setHeader("Content-Security-Policy", "default-src 'none'; img-src * data:; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com");
    return res.type("html").send(message.html);
  })
);

router.post(
  "/emails/templates/:key/test",
  requirePermission("emails.manage"),
  validate({ body: z.object({ to: z.string().trim().toLowerCase().email("Enter a valid email address.") }) }),
  asyncHandler(async (req, res) => {
    const template = TEMPLATES[req.params.key];
    if (!template) throw AppError.notFound("That template was not found.");
    const id = await queueEmail({ template: req.params.key, to: req.body.to, data: template.sample ?? {}, priority: 1 });
    if (!id) throw AppError.badRequest("The test email could not be queued.");
    await deliverDue({ ids: [id] });
    const row = await queryOne("SELECT * FROM email_messages WHERE id = ?", [id]);
    await auditFromRequest(req, { action: "email.test_sent", subjectType: "email", subjectId: id, metadata: { template: req.params.key } }).catch(() => {});
    res.status(201).json(detailResponse(serializeMessage(row)));
  })
);

/* ----------------------------- connection --------------------------------- */

router.get(
  "/emails/settings",
  requirePermission("emails.view"),
  asyncHandler(async (req, res) =>
    res.json(
      detailResponse({
        driver: env.MAIL_DRIVER,
        host: env.SMTP_HOST,
        port: env.SMTP_PORT,
        user: env.SMTP_USER,
        passwordSet: Boolean(env.SMTP_PASSWORD),
        from: env.MAIL_FROM,
        fromName: env.MAIL_FROM_NAME,
        replyTo: env.MAIL_REPLY_TO,
        bounceWebhookConfigured: Boolean(env.EMAIL_WEBHOOK_SECRET),
        worker: env.EMAIL_WORKER_ENABLED,
      })
    )
  )
);

router.post(
  "/emails/settings/verify",
  requirePermission("emails.manage"),
  asyncHandler(async (req, res) => res.json(detailResponse(await verifyTransport())))
);

/* ------------------------------ suppressions ------------------------------ */

router.get(
  "/emails/suppressions",
  requirePermission("emails.view"),
  asyncHandler(async (req, res) => {
    const search = String(req.query.q || "").trim();
    const rows = await query(
      `SELECT id, email, scope, reason, detail, created_at FROM email_suppressions ${search ? "WHERE email LIKE ?" : ""} ORDER BY id DESC LIMIT 200`,
      search ? [`%${search}%`] : []
    );
    res.json(detailResponse(rows.map((row) => ({ id: row.id, email: row.email, scope: row.scope, scopeLabel: row.scope === "all" ? "All optional email" : CATEGORIES[row.scope]?.label ?? row.scope, reason: row.reason, detail: row.detail, createdAt: row.created_at }))));
  })
);

router.post(
  "/emails/suppressions",
  requirePermission("emails.manage"),
  validate({ body: z.object({ email: z.string().trim().toLowerCase().email("Enter a valid email address."), detail: z.string().trim().max(300).optional() }) }),
  asyncHandler(async (req, res) => {
    await suppress(req.body.email, { scope: "all", reason: "manual", detail: req.body.detail, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "email.suppressed", subjectType: "email", subjectId: null, metadata: { email: req.body.email } }).catch(() => {});
    res.status(201).json(detailResponse({ email: normalizeEmail(req.body.email) }));
  })
);

router.delete(
  "/emails/suppressions/:id",
  requirePermission("emails.manage"),
  asyncHandler(async (req, res) => {
    const result = await execute("DELETE FROM email_suppressions WHERE id = ?", [Number(req.params.id) || 0]);
    if (!result.affectedRows) throw AppError.notFound("That suppression was not found.");
    await auditFromRequest(req, { action: "email.unsuppressed", subjectType: "email", subjectId: Number(req.params.id) }).catch(() => {});
    res.json(detailResponse({ removed: true }));
  })
);

/* -------------------------------- newsletter ------------------------------ */

const campaignSchema = z.object({
  subject: z.string().trim().min(3, "Enter a subject.").max(200),
  preheader: z.string().trim().max(200).optional().or(z.literal("")),
  heading: z.string().trim().min(3, "Enter a heading.").max(200),
  body: z.string().trim().min(10, "Write the newsletter.").max(20000),
  ctaLabel: z.string().trim().max(80).optional().or(z.literal("")),
  ctaUrl: z.string().trim().url("Enter a full link starting with https://").max(500).optional().or(z.literal("")),
});

const serializeCampaign = (row) => ({
  id: row.public_id, subject: row.subject, preheader: row.preheader, heading: row.heading, body: row.body,
  ctaLabel: row.cta_label, ctaUrl: row.cta_url, status: row.status, recipientCount: row.recipient_count, sentAt: row.sent_at, createdAt: row.created_at,
});

router.get(
  "/emails/campaigns",
  requirePermission("emails.view"),
  asyncHandler(async (req, res) => {
    const [rows, audience] = await Promise.all([
      query("SELECT * FROM email_campaigns ORDER BY id DESC LIMIT 100"),
      queryOne("SELECT COUNT(*) AS n FROM newsletter_subscribers WHERE status = 'subscribed'"),
    ]);
    res.json(detailResponse({ campaigns: rows.map(serializeCampaign), subscribers: Number(audience?.n ?? 0) }));
  })
);

router.post(
  "/emails/campaigns",
  requirePermission("emails.manage"),
  validate({ body: campaignSchema }),
  asyncHandler(async (req, res) => {
    const publicId = ulid();
    await execute(
      `INSERT INTO email_campaigns (public_id, subject, preheader, heading, body, cta_label, cta_url, status, created_by_user_id, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'draft', ?, NOW(3))`,
      [publicId, req.body.subject, req.body.preheader || null, req.body.heading, req.body.body, req.body.ctaLabel || null, req.body.ctaUrl || null, req.auth.user.id]
    );
    res.status(201).json(detailResponse(serializeCampaign(await queryOne("SELECT * FROM email_campaigns WHERE public_id = ?", [publicId]))));
  })
);

router.get(
  "/emails/campaigns/:id/preview",
  requirePermission("emails.view"),
  asyncHandler(async (req, res) => {
    const row = await queryOne("SELECT * FROM email_campaigns WHERE public_id = ?", [req.params.id]);
    if (!row) throw AppError.notFound("That newsletter was not found.");
    const message = await composeMessage({ ...sampleRow("newsletter.campaign"), data: { subject: row.subject, preheader: row.preheader, heading: row.heading, body: row.body, ctaLabel: row.cta_label, ctaUrl: row.cta_url } });
    if (req.query.format === "json") return res.json(detailResponse({ subject: message.subject, html: message.html, text: message.text }));
    res.setHeader("Content-Security-Policy", "default-src 'none'; img-src * data:; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com");
    res.type("html").send(message.html);
  })
);

/** Sends a draft to every confirmed subscriber (or only `testTo`). Each address once. */
router.post(
  "/emails/campaigns/:id/send",
  requirePermission("emails.manage"),
  validate({ body: z.object({ testTo: z.string().trim().toLowerCase().email().optional() }) }),
  asyncHandler(async (req, res) => {
    const row = await queryOne("SELECT * FROM email_campaigns WHERE public_id = ?", [req.params.id]);
    if (!row) throw AppError.notFound("That newsletter was not found.");
    const data = { subject: row.subject, preheader: row.preheader, heading: row.heading, body: row.body, ctaLabel: row.cta_label, ctaUrl: row.cta_url };
    if (req.body.testTo) {
      const id = await queueEmail({ template: "newsletter.campaign", to: req.body.testTo, data: { ...data, subject: `[Test] ${row.subject}` }, campaignId: row.id, priority: 1 });
      return res.json(detailResponse({ test: true, queued: id ? 1 : 0 }));
    }
    if (row.status !== "draft") throw AppError.conflict("This newsletter was already sent.");
    await execute("UPDATE email_campaigns SET status = 'sending' WHERE id = ?", [row.id]);
    const subscribers = await query(
      "SELECT s.email, s.first_name, s.user_id FROM newsletter_subscribers s WHERE s.status = 'subscribed' ORDER BY s.id"
    );
    let queued = 0;
    for (const subscriber of subscribers) {
      const id = await queueEmail(
        { template: "newsletter.campaign", to: subscriber.email, toName: subscriber.first_name, userId: subscriber.user_id, data, campaignId: row.id, dedupeKey: `campaign:${row.id}:${normalizeEmail(subscriber.email)}`, priority: 9, sendNow: false },
      );
      if (id) queued += 1;
    }
    await execute("UPDATE email_campaigns SET status = 'sent', recipient_count = ?, sent_at = NOW(3) WHERE id = ?", [queued, row.id]);
    await auditFromRequest(req, { action: "email.campaign_sent", subjectType: "email_campaign", subjectId: row.id, metadata: { queued } }).catch(() => {});
    res.json(detailResponse({ queued }));
  })
);

/* ---------------------------------- one ----------------------------------- */

router.get(
  "/emails/:id",
  requirePermission("emails.view"),
  asyncHandler(async (req, res) => {
    const row = await queryOne("SELECT * FROM email_messages WHERE public_id = ?", [req.params.id]);
    if (!row) throw AppError.notFound("That email was not found.");
    const events = await query("SELECT event, provider, detail, created_at FROM email_events WHERE message_id = ? ORDER BY id", [row.id]);
    res.json(detailResponse({ ...serializeMessage(row), events: events.map((event) => ({ event: event.event, provider: event.provider, detail: event.detail, at: event.created_at })) }));
  })
);

/** The email as it renders now (tokens in links are the ones that were sent). */
router.get(
  "/emails/:id/render",
  requirePermission("emails.view"),
  asyncHandler(async (req, res) => {
    const row = await queryOne("SELECT * FROM email_messages WHERE public_id = ?", [req.params.id]);
    if (!row) throw AppError.notFound("That email was not found.");
    // Security emails carry live sign-in links; staff see the layout, not a usable link.
    const data = typeof row.data === "string" ? JSON.parse(row.data) : row.data;
    const masked = CATEGORIES[row.category]?.optional ? data : JSON.parse(JSON.stringify(data).replace(/token=[^"&\s]+/g, "token=REDACTED"));
    const message = await composeMessage({ ...row, data: masked }, { forceDark: req.query.theme === "dark" });
    if (req.query.format === "json") return res.json(detailResponse({ subject: message.subject, html: message.html, text: message.text }));
    res.setHeader("Content-Security-Policy", "default-src 'none'; img-src * data:; style-src 'unsafe-inline' https://fonts.googleapis.com; font-src https://fonts.gstatic.com");
    res.type("html").send(message.html);
  })
);

router.post(
  "/emails/:id/resend",
  requirePermission("emails.manage"),
  asyncHandler(async (req, res) => {
    const row = await queryOne("SELECT * FROM email_messages WHERE public_id = ?", [req.params.id]);
    if (!row) throw AppError.notFound("That email was not found.");
    const data = typeof row.data === "string" ? JSON.parse(row.data) : row.data;
    const id = await queueEmail({ template: row.template_key, to: row.to_email, toName: row.to_name, userId: row.user_id, accountId: row.account_id, data, replyTo: row.reply_to, priority: 1 });
    if (!id) throw AppError.badRequest("The email could not be queued again.");
    await auditFromRequest(req, { action: "email.resent", subjectType: "email", subjectId: row.id }).catch(() => {});
    res.status(201).json(detailResponse(serializeMessage(await queryOne("SELECT * FROM email_messages WHERE id = ?", [id]))));
  })
);

export default router;
