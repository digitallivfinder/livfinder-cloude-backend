import { Router } from "express";
import multer from "multer";
import { z } from "zod";
import { asyncHandler } from "../../middleware/errors.js";
import { requireAccountCapability, requireAdmin, requireAuth, requirePermission } from "../../middleware/auth.js";
import { uploadLimiter, writeLimiter } from "../../middleware/rateLimit.js";
import { queryValue } from "../../db/query.js";
import { assertSafeUrl } from "../../utils/safeFetch.js";
import { resolveCategory } from "../../utils/categories.js";
import { assertAddonActive, isAddonActive } from "../accounts/addons.service.js";
import { auditFromRequest } from "../system/audit.service.js";
import { requireAccountId } from "../portal/authorization.js";
import {
  deleteAccountFeed,
  feedIdForPublicId,
  getAccountFeed,
  listAccountFeeds,
  listAllFeeds,
  requestRun,
  saveAccountFeed,
  serializeFeed,
  setFeedStatus,
} from "./feedSources.repository.js";
import { testFeed } from "./feedRunner.js";
import { MAPPING_TYPES, dismissMapping, listMappings, mappingCandidates, setMapping } from "./valueMappings.js";
import { validate } from "../../middleware/validation.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse, listResponse } from "../../utils/http.js";
import { FEED_CATEGORIES, feedFormat, feedFormatIndex } from "./feedFormats.js";
import { MAX_FEED_BYTES, parseFeed } from "./feedParser.js";
import { csvTemplate, sampleXml, xmlSchema } from "./feedTemplates.js";

/**
 * The feed formats (Phase 3 of feeds): what a company's file must look like, per category, and a
 * way to check a file against it before connecting a feed.
 *
 *   GET  /v1/public/feed-formats                          every category, version and downloads
 *   GET  /v1/public/feed-formats/:category                the field-by-field specification
 *   GET  /v1/public/feed-formats/:category/template.csv   a CSV template with an example row
 *   GET  /v1/public/feed-formats/:category/schema.xsd     the XML schema
 *   GET  /v1/public/feed-formats/:category/sample.xml     a sample XML file
 *   POST /v1/portal/feed-formats/:category/check          parse an uploaded file; nothing is saved
 *
 * And the account's own feeds (Phase 4, 0063), one URL per category:
 *
 *   GET    /v1/portal/feeds                   every category: its feed, if any, and whether it is open
 *   PUT    /v1/portal/feeds/:category         set the URL, format, schedule, change watch, on/off
 *   DELETE /v1/portal/feeds/:category         stop and forget the feed (listings stay)
 *   POST   /v1/portal/feeds/:category/run     fetch within a minute
 *   POST   /v1/portal/feeds/:category/test    fetch and read now, without saving anything
 */

export const publicFeedFormatsRouter = Router();
export const portalFeedFormatsRouter = Router();
export const adminFeedMappingsRouter = Router();

const categoryParam = z.object({ category: z.enum(FEED_CATEGORIES, { message: `Use one of: ${FEED_CATEGORIES.join(", ")}.` }) });

publicFeedFormatsRouter.get(
  "/feed-formats",
  asyncHandler(async (req, res) => res.json({ data: feedFormatIndex() }))
);

publicFeedFormatsRouter.get(
  "/feed-formats/:category",
  validate({ params: categoryParam }),
  asyncHandler(async (req, res) => res.json(detailResponse(feedFormat(req.params.category))))
);

const download = (contentType, extension, build) =>
  asyncHandler(async (req, res) => {
    const { category } = req.params;
    const format = feedFormat(category);
    res.setHeader("Content-Type", `${contentType}; charset=utf-8`);
    res.setHeader("Content-Disposition", `attachment; filename="livfinder-${category}-v${format.version}.${extension}"`);
    res.setHeader("Cache-Control", "public, max-age=3600");
    return res.send(build(category));
  });

publicFeedFormatsRouter.get(
  "/feed-formats/:category/template.csv",
  validate({ params: categoryParam }),
  download("text/csv", "csv", csvTemplate)
);
publicFeedFormatsRouter.get(
  "/feed-formats/:category/schema.xsd",
  validate({ params: categoryParam }),
  download("application/xml", "xsd", xmlSchema)
);
publicFeedFormatsRouter.get(
  "/feed-formats/:category/sample.xml",
  validate({ params: categoryParam }),
  download("application/xml", "xml", sampleXml)
);

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_FEED_BYTES, files: 1 } });

/**
 * Checks a file the way a feed run would read it and reports every row, without saving
 * anything. Matching values to LivFinder's own (property types, locations, agents) and fetching
 * images happen on a real run.
 */
portalFeedFormatsRouter.post(
  "/feed-formats/:category/check",
  uploadLimiter,
  requireAuth,
  validate({ params: categoryParam }),
  upload.single("file"),
  asyncHandler(async (req, res) => {
    if (!req.file) throw AppError.badRequest("Attach the feed file as `file`.");
    const name = String(req.file.originalname || "").toLowerCase();
    const format = name.endsWith(".xml") ? "xml" : name.endsWith(".csv") ? "csv" : undefined;
    const result = parseFeed({ category: req.params.category, format, content: req.file.buffer });
    const failed = result.items.filter((item) => item.errors);
    return res.json(
      detailResponse({
        category: result.category,
        version: result.version,
        format: result.format,
        source: result.source,
        total: result.items.length,
        valid: result.items.length - failed.length,
        invalid: failed.length,
        warnings: result.warnings,
        rows: failed.slice(0, 500).map((item) => ({ row: item.row, externalId: item.externalId, errors: item.errors })),
      })
    );
  })
);

/* -------------------------------------------------------------------------- */
/* The account's feeds                                                         */
/* -------------------------------------------------------------------------- */

async function hasCategoryAccess(accountId, category) {
  const rootId = category === "developments" ? 7 : resolveCategory(category)?.rootId;
  if (!rootId) return false;
  return Boolean(
    await queryValue(
      `SELECT aca.id FROM account_category_access aca JOIN categories c ON c.id = aca.category_id
        WHERE aca.account_id = ? AND COALESCE(c.root_category_id, c.id) = ? AND aca.status = 'approved' LIMIT 1`,
      [accountId, rootId]
    )
  );
}

const feedBody = z
  .object({
    url: z.string().trim().url("Give the full address of the file, starting with https://.").max(1000).optional(),
    format: z.enum(["auto", "xml", "csv"]).optional(),
    schedule: z.enum(["hourly", "every_6_hours", "daily"]).optional(),
    watchChanges: z.boolean().optional(),
    status: z.enum(["active", "paused"]).optional(),
  })
  .refine((body) => Object.keys(body).length > 0, { message: "Nothing to change." });

portalFeedFormatsRouter.get(
  "/feeds",
  requireAuth,
  requireAccountCapability("can_view_integrations"),
  asyncHandler(async (req, res) => {
    const accountId = requireAccountId(req);
    const [feeds, addonActive] = await Promise.all([listAccountFeeds(accountId), isAddonActive(accountId, "integrations")]);
    const categories = [];
    for (const category of FEED_CATEGORIES) {
      categories.push({
        category,
        label: feedFormat(category).label,
        version: feedFormat(category).version,
        hasAccess: await hasCategoryAccess(accountId, category),
        feed: serializeFeed(feeds.find((feed) => feed.category === category)),
      });
    }
    return res.json({ data: { addonActive, categories } });
  })
);

portalFeedFormatsRouter.put(
  "/feeds/:category",
  writeLimiter,
  requireAuth,
  requireAccountCapability("can_view_integrations"),
  validate({ params: categoryParam, body: feedBody }),
  asyncHandler(async (req, res) => {
    const accountId = requireAccountId(req);
    const { category } = req.params;
    await assertAddonActive(accountId, "integrations");
    if (!(await hasCategoryAccess(accountId, category))) {
      throw AppError.forbidden(`This account is not approved for ${feedFormat(category).label}, so it cannot have a feed for it.`);
    }
    if (category === "developments" && !req.auth.activeMembership?.organization_id) {
      throw AppError.forbidden("Development feeds belong to developer companies.");
    }
    const existing = await getAccountFeed(accountId, category);
    if (!existing && !req.body.url) throw AppError.validation("Some information is invalid.", { url: "Give the feed's address." });
    if (req.body.url) {
      try {
        await assertSafeUrl(req.body.url, { useAllowList: false });
      } catch (error) {
        throw AppError.validation("Some information is invalid.", { url: error.message });
      }
    }
    const feed = await saveAccountFeed({
      accountId,
      organizationId: req.auth.activeMembership?.organization_id ?? null,
      category,
      ...req.body,
      userId: req.auth.user.id,
    });
    await auditFromRequest(req, { action: existing ? "feed.updated" : "feed.created", subjectType: "feed_source", subjectId: feed.id, changes: req.body });
    return res.status(existing ? 200 : 201).json(detailResponse(serializeFeed(feed)));
  })
);

portalFeedFormatsRouter.delete(
  "/feeds/:category",
  writeLimiter,
  requireAuth,
  requireAccountCapability("can_view_integrations"),
  validate({ params: categoryParam }),
  asyncHandler(async (req, res) => {
    const accountId = requireAccountId(req);
    await deleteAccountFeed(accountId, req.params.category);
    await auditFromRequest(req, { action: "feed.deleted", subjectType: "feed_source", subjectLabel: req.params.category });
    return res.json(detailResponse({ deleted: true }));
  })
);

async function ownFeed(req) {
  const feed = await getAccountFeed(requireAccountId(req), req.params.category);
  if (!feed) throw AppError.notFound("There is no feed for that category yet.");
  return feed;
}

portalFeedFormatsRouter.post(
  "/feeds/:category/run",
  writeLimiter,
  requireAuth,
  requireAccountCapability("can_view_integrations"),
  validate({ params: categoryParam }),
  asyncHandler(async (req, res) => {
    const feed = await ownFeed(req);
    await assertAddonActive(feed.account_id, "integrations");
    if (feed.status !== "active") throw AppError.conflict("Turn the feed on before running it.");
    const { at } = await requestRun(feed.id);
    return res.status(202).json(detailResponse({ queued: true, fetchAfter: at, message: "The feed will be fetched shortly (at most once every 2 minutes)." }));
  })
);

portalFeedFormatsRouter.post(
  "/feeds/:category/test",
  writeLimiter,
  requireAuth,
  requireAccountCapability("can_view_integrations"),
  validate({ params: categoryParam, body: z.object({ url: z.string().trim().url().max(1000).optional() }).partial() }),
  asyncHandler(async (req, res) => {
    const accountId = requireAccountId(req);
    const saved = await getAccountFeed(accountId, req.params.category);
    const url = req.body?.url || saved?.url;
    if (!url) throw AppError.validation("Some information is invalid.", { url: "Give the feed's address." });
    const report = await testFeed({ url, category: req.params.category, format: saved?.format ?? "auto" });
    return res.json(detailResponse(report));
  })
);

/* -------------------------------------------------------------------------- */
/* Admin: the mapping queue (Phase 5)                                          */
/* -------------------------------------------------------------------------- */
/*
 *   GET    /v1/admin/feed-mappings                   unmatched (or mapped) place names and types
 *   GET    /v1/admin/feed-mappings/:id/candidates    what one can be mapped to
 *   PUT    /v1/admin/feed-mappings/:id               map it
 *   DELETE /v1/admin/feed-mappings/:id               drop it from the queue
 */

const adminOnly = [requireAuth, requireAdmin, requirePermission("listings.moderate")];
const mappingId = z.object({ id: z.string().regex(/^\d+$/) });

adminFeedMappingsRouter.get(
  "/feed-mappings",
  ...adminOnly,
  validate({
    query: z.object({
      status: z.enum(["unmapped", "mapped", "all"]).optional(),
      type: z.enum(MAPPING_TYPES).optional(),
      page: z.coerce.number().int().min(1).max(10_000).optional(),
      pageSize: z.coerce.number().int().min(1).max(100).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { status = "unmapped", type, page = 1, pageSize = 50 } = req.validatedQuery || {};
    const result = await listMappings({ status, type, page, pageSize });
    return res.json(listResponse(result.rows, { page, pageSize, total: result.total }));
  })
);

adminFeedMappingsRouter.get(
  "/feed-mappings/:id/candidates",
  ...adminOnly,
  validate({ params: mappingId, query: z.object({ q: z.string().trim().max(80).optional() }) }),
  asyncHandler(async (req, res) => res.json({ data: await mappingCandidates(Number(req.params.id), req.validatedQuery?.q) }))
);

adminFeedMappingsRouter.put(
  "/feed-mappings/:id",
  writeLimiter,
  ...adminOnly,
  validate({
    params: mappingId,
    body: z
      .object({ locationId: z.string().trim().max(40).optional(), categoryCode: z.string().trim().max(80).optional() })
      .refine((body) => body.locationId || body.categoryCode, { message: "Choose what it maps to." }),
  }),
  asyncHandler(async (req, res) => {
    const result = await setMapping(Number(req.params.id), req.body);
    await auditFromRequest(req, { action: "feed_mapping.set", subjectType: "feed_value_mapping", subjectLabel: req.params.id, changes: req.body });
    return res.json(detailResponse(result));
  })
);

adminFeedMappingsRouter.delete(
  "/feed-mappings/:id",
  writeLimiter,
  ...adminOnly,
  validate({ params: mappingId }),
  asyncHandler(async (req, res) => {
    await dismissMapping(Number(req.params.id));
    await auditFromRequest(req, { action: "feed_mapping.dismissed", subjectType: "feed_value_mapping", subjectLabel: req.params.id });
    return res.json(detailResponse({ dismissed: true }));
  })
);

/* -------------------------------------------------------------------------- */
/* Admin: the feed monitor (Phase 7)                                           */
/* -------------------------------------------------------------------------- */
/*
 *   GET   /v1/admin/feeds                 every company's feeds; ?problem=1 for the ones needing a look
 *   PATCH /v1/admin/feeds/:id             pause a feed, or turn it back on
 *   POST  /v1/admin/feeds/:id/run         fetch it within a minute
 */

const feedMonitor = [requireAuth, requireAdmin, requirePermission("api.view")];

adminFeedMappingsRouter.get(
  "/feeds",
  ...feedMonitor,
  validate({
    query: z.object({
      status: z.enum(["active", "paused", "error"]).optional(),
      category: z.enum(FEED_CATEGORIES).optional(),
      problem: z.enum(["0", "1"]).optional(),
      search: z.string().trim().max(120).optional(),
      page: z.coerce.number().int().min(1).max(10_000).optional(),
      pageSize: z.coerce.number().int().min(1).max(100).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { status, category, problem, search, page = 1, pageSize = 50 } = req.validatedQuery || {};
    const result = await listAllFeeds({ status, category, problem: problem === "1", search, page, pageSize });
    return res.json(listResponse(result.rows, { page, pageSize, total: result.total }));
  })
);

adminFeedMappingsRouter.patch(
  "/feeds/:id",
  writeLimiter,
  requireAuth,
  requireAdmin,
  requirePermission("listings.moderate"),
  validate({ body: z.object({ status: z.enum(["active", "paused"]) }) }),
  asyncHandler(async (req, res) => {
    const result = await setFeedStatus(req.params.id, req.body.status);
    await auditFromRequest(req, { action: `feed.${req.body.status === "active" ? "resumed" : "paused"}_by_admin`, subjectType: "feed_source", subjectLabel: req.params.id });
    return res.json(detailResponse(result));
  })
);

adminFeedMappingsRouter.post(
  "/feeds/:id/run",
  writeLimiter,
  requireAuth,
  requireAdmin,
  requirePermission("listings.moderate"),
  asyncHandler(async (req, res) => {
    const feed = await feedIdForPublicId(req.params.id);
    if (feed.status !== "active") throw AppError.conflict("Turn the feed on before running it.");
    await requestRun(feed.id);
    await auditFromRequest(req, { action: "feed.run_by_admin", subjectType: "feed_source", subjectLabel: req.params.id });
    return res.status(202).json(detailResponse({ queued: true }));
  })
);
