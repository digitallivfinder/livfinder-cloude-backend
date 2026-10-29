import { Router } from "express";
import { z } from "zod";
import { asyncHandler } from "../../middleware/errors.js";
import { requireAccountCapability, requireAuth } from "../../middleware/auth.js";
import { generalLimiter, writeLimiter } from "../../middleware/rateLimit.js";
import { validate } from "../../middleware/validation.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse } from "../../utils/http.js";
import { assertAddonActive } from "../accounts/addons.service.js";
import { auditFromRequest } from "../system/audit.service.js";
import { requireAccountId } from "../portal/authorization.js";
import { LEAD_FEED_VERSION, leadsToCsv, leadsToXml, listLeadsSince } from "./leadExport.service.js";
import { accountForToken, createFeedToken, listFeedTokens, revokeFeedToken } from "./leadFeedTokens.service.js";
import {
  WEBHOOK_EVENTS,
  createWebhook,
  deleteWebhook,
  listDeliveries,
  listWebhooks,
  rotateWebhookSecret,
  sendTestEvent,
  updateWebhook,
} from "./webhooks.service.js";

/**
 * Leads out (Phase 6, 0064), all part of the Integrations add-on:
 *
 *   GET  /v1/partner/leads                       (API key, leads:read) the lead feed: JSON, ?format=xml|csv
 *   GET  /v1/lead-feeds/:token.(json|xml|csv)    the same, behind a read-only address for URL-only CRMs
 *   GET  /v1/portal/leads/export.csv             every lead in a date range, for a person with no CRM
 *   /v1/portal/webhooks…, /v1/portal/lead-feed-tokens…   managing endpoints and addresses
 *
 * The feed is the full history in the order things changed. Keep the `nextCursor` of each page and
 * pass it back as `cursor`: the next call returns only what is new or changed since.
 */

export const partnerLeadsRouter = Router();
export const leadFeedRouter = Router();
export const portalLeadsRouter = Router();

const feedQuery = z.object({
  cursor: z.string().trim().max(200).optional(),
  limit: z.coerce.number().int().min(1).max(200).optional(),
  format: z.enum(["json", "xml", "csv"]).optional(),
});

async function sendFeed(res, accountId, { cursor, limit, format = "json" }) {
  await assertAddonActive(accountId, "integrations");
  const page = await listLeadsSince({ accountId, cursor, limit });
  res.setHeader("Cache-Control", "no-store");
  res.setHeader("X-Next-Cursor", page.nextCursor ?? "");
  res.setHeader("X-Has-More", page.hasMore ? "true" : "false");
  if (format === "xml") return res.type("application/xml").send(leadsToXml(page));
  if (format === "csv") return res.type("text/csv").send(leadsToCsv(page.leads));
  return res.json({ version: LEAD_FEED_VERSION, data: page.leads, nextCursor: page.nextCursor, hasMore: page.hasMore });
}

/** Mounted inside the partner router, after its API-key sign-in (`signedIn("leads:read")`). */
export function mountPartnerLeads(router, signedIn) {
  router.get(
    "/leads",
    ...signedIn("leads:read"),
    validate({ query: feedQuery }),
    asyncHandler(async (req, res) => sendFeed(res, req.apiClient.accountId, req.validatedQuery || {}))
  );
}

leadFeedRouter.get(
  "/lead-feeds/:file",
  generalLimiter,
  validate({ query: feedQuery.omit({ format: true }) }),
  asyncHandler(async (req, res) => {
    const match = /^(lft_[A-Za-z0-9_-]{20,64})\.(json|xml|csv)$/.exec(req.params.file);
    const accountId = match ? await accountForToken(match[1]) : null;
    // One answer for a wrong or revoked address, so the address space cannot be probed.
    if (!accountId) throw AppError.notFound("That lead feed address is not valid.");
    return sendFeed(res, accountId, { ...(req.validatedQuery || {}), format: match[2] });
  })
);

/* -------------------------------------------------------------------------- */
/* Portal                                                                      */
/* -------------------------------------------------------------------------- */

const integrations = [requireAuth, requireAccountCapability("can_view_integrations")];

portalLeadsRouter.get(
  "/leads/export.csv",
  requireAuth,
  requireAccountCapability("can_manage_leads"),
  validate({
    query: z.object({
      from: z.string().trim().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
      to: z.string().trim().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const accountId = requireAccountId(req);
    await assertAddonActive(accountId, "integrations");
    const { from, to } = req.validatedQuery || {};
    const start = from ? new Date(`${from}T00:00:00Z`) : null;
    const end = to ? new Date(`${to}T23:59:59.999Z`) : null;
    // Read the whole history in pages and keep what was received in the range.
    const leads = [];
    let cursor = null;
    for (let guard = 0; guard < 500; guard += 1) {
      const page = await listLeadsSince({ accountId, cursor, limit: 200 });
      for (const lead of page.leads) {
        const created = new Date(lead.createdAt);
        if ((!start || created >= start) && (!end || created <= end)) leads.push(lead);
      }
      if (!page.hasMore) break;
      cursor = page.nextCursor;
    }
    leads.sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)));
    await auditFromRequest(req, { action: "leads.exported", subjectType: "account", subjectLabel: String(accountId), metadata: { from, to, count: leads.length } });
    res.setHeader("Content-Disposition", `attachment; filename="livfinder-leads${from ? `-${from}` : ""}${to ? `-to-${to}` : ""}.csv"`);
    res.setHeader("Cache-Control", "no-store");
    return res.type("text/csv").send(leadsToCsv(leads));
  })
);

const webhookBody = z.object({
  name: z.string().trim().min(1).max(160),
  url: z.string().trim().url("Give the full https:// address of your endpoint.").max(700),
  events: z.array(z.enum(WEBHOOK_EVENTS)).min(1, "Choose at least one event.").max(WEBHOOK_EVENTS.length),
});

portalLeadsRouter.get(
  "/webhooks",
  ...integrations,
  asyncHandler(async (req, res) => {
    const accountId = requireAccountId(req);
    const [webhooks, tokens] = await Promise.all([listWebhooks(accountId), listFeedTokens(accountId)]);
    return res.json({ data: { events: WEBHOOK_EVENTS, webhooks, leadFeedTokens: tokens } });
  })
);

portalLeadsRouter.post(
  "/webhooks",
  writeLimiter,
  ...integrations,
  validate({ body: webhookBody }),
  asyncHandler(async (req, res) => {
    const accountId = requireAccountId(req);
    await assertAddonActive(accountId, "integrations");
    const created = await createWebhook({ accountId, ...req.body, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "webhook.created", subjectType: "webhook", subjectLabel: created.id, metadata: { url: created.url, events: created.events } });
    return res.status(201).json(detailResponse(created));
  })
);

portalLeadsRouter.patch(
  "/webhooks/:id",
  writeLimiter,
  ...integrations,
  validate({ body: webhookBody.partial().extend({ status: z.enum(["active", "paused"]).optional() }) }),
  asyncHandler(async (req, res) => {
    const result = await updateWebhook({ accountId: requireAccountId(req), publicId: req.params.id, ...req.body });
    await auditFromRequest(req, { action: "webhook.updated", subjectType: "webhook", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

portalLeadsRouter.delete(
  "/webhooks/:id",
  writeLimiter,
  ...integrations,
  asyncHandler(async (req, res) => {
    await deleteWebhook({ accountId: requireAccountId(req), publicId: req.params.id });
    await auditFromRequest(req, { action: "webhook.deleted", subjectType: "webhook", subjectLabel: req.params.id });
    return res.json(detailResponse({ deleted: true }));
  })
);

portalLeadsRouter.post(
  "/webhooks/:id/rotate-secret",
  writeLimiter,
  ...integrations,
  asyncHandler(async (req, res) => {
    const result = await rotateWebhookSecret({ accountId: requireAccountId(req), publicId: req.params.id });
    await auditFromRequest(req, { action: "webhook.secret_rotated", subjectType: "webhook", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

portalLeadsRouter.post(
  "/webhooks/:id/test",
  writeLimiter,
  ...integrations,
  asyncHandler(async (req, res) => res.json(detailResponse(await sendTestEvent({ accountId: requireAccountId(req), publicId: req.params.id }))))
);

portalLeadsRouter.get(
  "/webhooks/:id/deliveries",
  ...integrations,
  asyncHandler(async (req, res) => res.json({ data: await listDeliveries({ accountId: requireAccountId(req), publicId: req.params.id }) }))
);

portalLeadsRouter.post(
  "/lead-feed-tokens",
  writeLimiter,
  ...integrations,
  validate({ body: z.object({ name: z.string().trim().min(1).max(120) }) }),
  asyncHandler(async (req, res) => {
    const accountId = requireAccountId(req);
    await assertAddonActive(accountId, "integrations");
    const created = await createFeedToken({ accountId, name: req.body.name, userId: req.auth.user.id });
    await auditFromRequest(req, { action: "lead_feed_token.created", subjectType: "lead_feed_token", subjectLabel: created.id });
    return res.status(201).json(detailResponse(created));
  })
);

portalLeadsRouter.delete(
  "/lead-feed-tokens/:id",
  writeLimiter,
  ...integrations,
  asyncHandler(async (req, res) => {
    await revokeFeedToken({ accountId: requireAccountId(req), publicId: req.params.id });
    await auditFromRequest(req, { action: "lead_feed_token.revoked", subjectType: "lead_feed_token", subjectLabel: req.params.id });
    return res.json(detailResponse({ revoked: true }));
  })
);
