import { Router } from "express";
import multer from "multer";
import { z } from "zod";
import { asyncHandler } from "../../middleware/errors.js";
import { requireAdmin, requireAuth, requirePermission } from "../../middleware/auth.js";
import { uploadLimiter, writeLimiter } from "../../middleware/rateLimit.js";
import { query } from "../../db/query.js";
import { auditFromRequest } from "../system/audit.service.js";
import { MAPPING_TYPES, dismissMapping, listMappings, mappingCandidates, setMapping } from "./valueMappings.js";
import { validate } from "../../middleware/validation.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse, listResponse } from "../../utils/http.js";
import { FEED_CATEGORIES, feedFormat, feedFormatIndex } from "./feedFormats.js";
import { MAX_FEED_BYTES, parseFeed } from "./feedParser.js";
import { csvTemplate, sampleAllXml, sampleXml, xmlSchema } from "./feedTemplates.js";

/**
 * The feed formats (Phase 3 of feeds): what a company's file must look like, per category, and a
 * way to check a file against it before pushing it.
 *
 *   GET  /v1/public/feed-formats                          every category, version and downloads
 *   GET  /v1/public/feed-formats/all/sample.xml           a sample of the all-categories file
 *   GET  /v1/public/feed-formats/locations/:file.csv      countries, states, cities, communities, sub-communities
 *   GET  /v1/public/feed-formats/:category                the field-by-field specification
 *   GET  /v1/public/feed-formats/:category/template.csv   a CSV template with an example row
 *   GET  /v1/public/feed-formats/:category/schema.xsd     the XML schema
 *   GET  /v1/public/feed-formats/:category/sample.xml     a sample XML file
 *   POST /v1/portal/feed-formats/:category/check          parse an uploaded file; nothing is saved
 */

export const publicFeedFormatsRouter = Router();
export const portalFeedFormatsRouter = Router();
export const adminFeedMappingsRouter = Router();

const categoryParam = z.object({ category: z.enum(FEED_CATEGORIES, { message: `Use one of: ${FEED_CATEGORIES.join(", ")}.` }) });

publicFeedFormatsRouter.get(
  "/feed-formats",
  asyncHandler(async (req, res) => res.json({ data: feedFormatIndex() }))
);

const COUNTRY = { label: "country", column: "country_id" };
const STATE = { label: "state", column: "state_id" };
const CITY = { label: "city", column: "city_id" };
const COMMUNITY = { label: "community", column: "community_id" };

const LOCATION_FILES = {
  countries: { levels: ["country"], parents: [] },
  states: { levels: ["state"], parents: [COUNTRY] },
  cities: { levels: ["city"], parents: [COUNTRY, STATE] },
  communities: { levels: ["community", "district"], parents: [COUNTRY, STATE, CITY] },
  "sub-communities": { levels: ["sub_community"], parents: [COUNTRY, STATE, CITY, COMMUNITY] },
};

/**
 * Every place listings can be filed under, one file per level, built from the live table, so a
 * place LivFinder adds is in the next download.
 */
for (const file of Object.keys(LOCATION_FILES)) {
  publicFeedFormatsRouter.get(
    `/feed-formats/locations/${file}.csv`,
    asyncHandler(async (req, res) => {
      res.setHeader("Content-Type", "text/csv; charset=utf-8");
      res.setHeader("Content-Disposition", `attachment; filename="livfinder-${file}.csv"`);
      res.setHeader("Cache-Control", "public, max-age=3600");
      await writeLocationFile(res, LOCATION_FILES[file]);
      return res.end();
    })
  );
}

publicFeedFormatsRouter.get(
  "/feed-formats/all/sample.xml",
  asyncHandler(async (req, res) => {
    res.setHeader("Content-Type", "application/xml; charset=utf-8");
    res.setHeader("Content-Disposition", 'attachment; filename="livfinder-all-categories.xml"');
    res.setHeader("Cache-Control", "public, max-age=3600");
    return res.send(sampleAllXml());
  })
);

publicFeedFormatsRouter.get(
  "/feed-formats/:category",
  validate({ params: categoryParam }),
  asyncHandler(async (req, res) => {
    const format = feedFormat(req.params.category);
    const keysOf = (requirement) => format.fields.filter((field) => field.requirement === requirement).map((field) => field.key);
    // The answer at a glance: `required: false` alone cannot tell "never" from "sometimes".
    const summary = { required: keysOf("required"), conditional: keysOf("conditional"), optional: keysOf("optional") };
    return res.json(detailResponse({ ...format, summary }));
  })
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

const csvText = (value) => {
  const text = String(value ?? "");
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
};

async function writeLocationFile(res, { levels, parents }) {
  const headers = parents.flatMap(({ label }) => [`${label}Id`, label]);
  res.write(`${["locationId", "name", ...headers].join(",")}\r\n`);
  const joins = parents.map(({ label, column }) => `LEFT JOIN locations ${label} ON ${label}.id = l.${column}`).join("\n         ");
  const columns = parents.map(({ label }) => `, ${label}.id AS ${label}_id, ${label}.name AS ${label}_name`).join("");
  let after = 0;
  for (;;) {
    const rows = await query(
      `SELECT l.id, l.name${columns}
         FROM locations l
         ${joins}
        WHERE l.id > ? AND l.deleted_at IS NULL AND l.status = 'active' AND l.level IN (${levels.map(() => "?").join(", ")})
        ORDER BY l.id ASC LIMIT 5000`,
      [after, ...levels]
    );
    if (!rows.length) return;
    const lines = rows.map((row) =>
      [row.id, row.name, ...parents.flatMap(({ label }) => [row[`${label}_id`], row[`${label}_name`]])].map(csvText).join(",")
    );
    res.write(`${lines.join("\r\n")}\r\n`);
    after = rows[rows.length - 1].id;
  }
}

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_FEED_BYTES, files: 1 } });

/**
 * Checks a file the way a push would read it and reports every row, without saving
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
