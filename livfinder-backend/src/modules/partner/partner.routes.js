import express, { Router } from "express";
import { z } from "zod";
import { generalLimiter } from "../../middleware/rateLimit.js";
import { apiClientLimiter, logPartnerRequest, requireApiClient } from "../../middleware/apiClient.js";
import { idempotency } from "../../middleware/idempotency.js";
import { validate, q } from "../../middleware/validation.js";
import { asyncHandler } from "../../middleware/errors.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse, listResponse } from "../../utils/http.js";
import { ensureImportConnection } from "../imports/importConnection.js";
import * as repo from "../imports/imports.repository.js";
import { MAX_BULK_LISTINGS, createBulkImport, runSingleImport, runWithdrawal } from "../imports/importRunner.js";
import {
  findImportedListing,
  listImportedListings,
  parseListingRecord,
  serializeImportedListing,
} from "../imports/listingImport.service.js";

/**
 * The partner API: a company's own system pushing listings into that company's LivFinder account.
 *
 * Mounted in app.js ahead of the global JSON parser (its 1 MB limit is too small for a batch) and
 * ahead of the session and CSRF middleware, which a key-signed server call never uses. Every
 * route is signed in with an API key (middleware/apiClient.js); the key decides the company.
 */
const router = Router();

router.use(express.json({ limit: "10mb" }));
router.use(generalLimiter);
router.use(logPartnerRequest);

const signedIn = (scope) => [requireApiClient(scope), apiClientLimiter];
const perKeyIdempotency = idempotency({ scope: (req) => `partner:${req.apiClient?.id ?? "unknown"}` });

const pageQuery = z.object({
  page: z.coerce.number().int().min(1).max(10_000).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).optional(),
});

async function connectionFor(req) {
  return ensureImportConnection({
    organizationId: req.apiClient.organizationId,
    accountId: req.apiClient.accountId,
    name: `Listing API — ${req.apiClient.organizationName}`,
  });
}

function sourceOf(req) {
  return { ip: req.apiClient.ip, userAgent: req.get("user-agent") || null, requestId: req.id };
}

function withImportHeader(res, error) {
  if (error?.importId) res.setHeader("X-Import-Id", error.importId);
}

/** Who this key is: lets a partner confirm which company its listings will land in. */
router.get(
  "/me",
  ...signedIn("listings:read"),
  asyncHandler(async (req, res) =>
    res.json(
      detailResponse({
        apiKey: { id: req.apiClient.publicId, name: req.apiClient.name, clientId: req.apiClient.clientId, scopes: req.apiClient.scopes },
        company: { id: req.apiClient.organizationPublicId, name: req.apiClient.organizationName },
        rateLimitPerMinute: req.apiClient.rateLimitPerMinute,
        callerIp: req.apiClient.ip,
      })
    )
  )
);

/** Create or update one listing, identified by the partner's own id. */
router.put(
  "/listings/:externalId",
  ...signedIn("listings:write"),
  perKeyIdempotency,
  asyncHandler(async (req, res) => {
    const body = req.body && typeof req.body === "object" && !Array.isArray(req.body) ? req.body : null;
    if (!body) throw AppError.badRequest("Send the listing as a JSON object.");
    if (body.externalId !== undefined && String(body.externalId).trim() !== req.params.externalId) {
      throw AppError.validation("Some information in this listing is invalid.", {
        externalId: "The externalId in the body must match the one in the URL.",
      });
    }
    const record = parseListingRecord({ ...body, externalId: req.params.externalId });
    const ctx = await connectionFor(req);
    const source = sourceOf(req);
    try {
      const { importRun, outcome } = await runSingleImport({ client: req.apiClient, ctx, record, ...source });
      res.setHeader("X-Import-Id", importRun.publicId);
      return res.status(outcome.operation === "create" ? 201 : 200).json(
        detailResponse(
          serializeImportedListing(outcome.listing, {
            externalId: record.externalId,
            operation: outcome.operation,
            importId: importRun.publicId,
            images: { attached: outcome.media.attached, failed: outcome.media.failed },
            warnings: outcome.warnings,
          })
        )
      );
    } catch (error) {
      withImportHeader(res, error);
      throw error;
    }
  })
);

/** Up to 100 listings at once; processed in the background, results per listing. */
router.post(
  "/imports",
  ...signedIn("listings:write"),
  perKeyIdempotency,
  validate({
    body: z.object({
      listings: z
        .array(z.unknown())
        .min(1, "Send at least one listing.")
        .max(MAX_BULK_LISTINGS, `Send at most ${MAX_BULK_LISTINGS} listings per request.`),
    }),
  }),
  asyncHandler(async (req, res) => {
    const ctx = await connectionFor(req);
    const { ip, userAgent } = sourceOf(req);
    const result = await createBulkImport({ client: req.apiClient, ctx, listings: req.body.listings, ip, userAgent });
    const row = await repo.getImportRow(result.importRun.publicId, { organizationId: req.apiClient.organizationId });
    res.setHeader("X-Import-Id", result.importRun.publicId);
    res.setHeader("Location", `/v1/partner/imports/${result.importRun.publicId}`);
    return res.status(202).json(
      detailResponse({
        ...repo.serializeImport(row),
        accepted: result.accepted,
        rejected: result.rejected,
      })
    );
  })
);

router.get(
  "/imports",
  ...signedIn("listings:read"),
  validate({ query: pageQuery.extend({ status: z.enum(["queued", "running", "completed", "partial", "failed"]).optional() }) }),
  asyncHandler(async (req, res) => {
    const { page = 1, pageSize = 20, status } = q(req);
    const result = await repo.listImports({ organizationId: req.apiClient.organizationId, status, page, pageSize });
    return res.json(listResponse(result.rows, { page, pageSize, total: result.total }));
  })
);

async function ownImport(req) {
  const row = await repo.getImportRow(req.params.importId, { organizationId: req.apiClient.organizationId });
  if (!row) throw AppError.notFound("That import was not found for this company.");
  return row;
}

router.get(
  "/imports/:importId",
  ...signedIn("listings:read"),
  asyncHandler(async (req, res) => res.json(detailResponse(repo.serializeImport(await ownImport(req)))))
);

router.get(
  "/imports/:importId/items",
  ...signedIn("listings:read"),
  validate({ query: pageQuery.extend({ status: z.enum(["failed", "warning", "succeeded", "queued"]).optional() }) }),
  asyncHandler(async (req, res) => {
    const row = await ownImport(req);
    const { page = 1, pageSize = 50, status } = q(req);
    const result = await repo.listImportItems(row.id, { status, page, pageSize });
    return res.json(listResponse(result.rows, { page, pageSize, total: result.total }));
  })
);

router.get(
  "/listings",
  ...signedIn("listings:read"),
  validate({
    query: pageQuery.extend({
      updatedSince: z.string().datetime({ offset: true }).optional(),
      status: z.enum(["draft", "pending_review", "active", "rejected", "expired", "sold", "rented", "withdrawn", "archived"]).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { page = 1, pageSize = 50, updatedSince, status } = q(req);
    const ctx = await connectionFor(req);
    const result = await listImportedListings({ ctx, updatedSince, status, page, pageSize });
    return res.json(
      listResponse(
        result.rows.map((row) => serializeImportedListing(row, { externalId: row.external_id })),
        { page, pageSize, total: result.total }
      )
    );
  })
);

router.get(
  "/listings/:externalId",
  ...signedIn("listings:read"),
  asyncHandler(async (req, res) => {
    const ctx = await connectionFor(req);
    const listing = await findImportedListing({ ctx, externalId: req.params.externalId });
    if (!listing) throw AppError.notFound(`No listing with the externalId "${req.params.externalId}" was pushed for this company.`);
    return res.json(detailResponse(serializeImportedListing(listing, { externalId: req.params.externalId })));
  })
);

router.delete(
  "/listings/:externalId",
  ...signedIn("listings:write"),
  perKeyIdempotency,
  asyncHandler(async (req, res) => {
    const ctx = await connectionFor(req);
    try {
      const { importRun, outcome } = await runWithdrawal({ client: req.apiClient, ctx, externalId: req.params.externalId, ...sourceOf(req) });
      res.setHeader("X-Import-Id", importRun.publicId);
      return res.json(
        detailResponse(
          serializeImportedListing(outcome.listing, {
            externalId: req.params.externalId,
            operation: outcome.operation === "delete" ? "withdraw" : "unchanged",
            importId: importRun.publicId,
          })
        )
      );
    } catch (error) {
      withImportHeader(res, error);
      throw error;
    }
  })
);

router.use((req, res, next) => next(AppError.notFound("No partner API route matches this request.")));

export default router;
