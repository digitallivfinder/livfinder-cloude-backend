import { Router } from "express";
import { z } from "zod";
import { requireAdmin, requireAuth, requirePermission } from "../../middleware/auth.js";
import { asyncHandler } from "../../middleware/errors.js";
import { writeLimiter } from "../../middleware/rateLimit.js";
import { q, validate } from "../../middleware/validation.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse, listResponse } from "../../utils/http.js";
import { execute } from "../../db/query.js";
import { auditFromRequest } from "../system/audit.service.js";
import { normalizeAllowedIps } from "../portal/organization.service.js";
import * as repo from "./imports.repository.js";
import { discardHeldRun, releaseHeldRun } from "../feeds/feedRunner.js";

/**
 * Admin view of the listing API: every company's imports with their per-listing results, every
 * API key with the power to suspend or revoke it, and the source of any listing.
 * Mounted at /v1/admin in app.js.
 */
const router = Router();

const listQuery = z.object({
  page: z.coerce.number().int().min(1).max(10_000).optional(),
  pageSize: z.coerce.number().int().min(1).max(100).optional(),
  status: z.string().trim().max(30).optional(),
  type: z.enum(["single", "bulk"]).optional(),
  search: z.string().trim().max(120).optional(),
  company: z.string().trim().max(40).optional(),
  apiKey: z.string().trim().max(40).optional(),
});

router.get(
  "/listing-imports",
  requireAuth,
  requireAdmin,
  requirePermission("api.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const { page = 1, pageSize = 20, status, type, search, company, apiKey } = q(req);
    const result = await repo.listImports({
      organizationPublicId: company || null,
      apiClientPublicId: apiKey || null,
      status: status || null,
      type: type || null,
      search: search || null,
      page,
      pageSize,
    });
    return res.json(listResponse(result.rows, { page, pageSize, total: result.total }));
  })
);

/** A feed run held because too many listings left the file at once (0063): withdraw them, or keep them. */
router.post(
  "/listing-imports/:importId/release",
  writeLimiter,
  requireAuth,
  requireAdmin,
  requirePermission("listings.moderate"),
  asyncHandler(async (req, res) => {
    const result = await releaseHeldRun(req.params.importId);
    await auditFromRequest(req, { action: "feed_import.released", subjectType: "feed_import", subjectLabel: req.params.importId, metadata: result });
    return res.json(detailResponse(result));
  })
);

router.post(
  "/listing-imports/:importId/discard",
  writeLimiter,
  requireAuth,
  requireAdmin,
  requirePermission("listings.moderate"),
  asyncHandler(async (req, res) => {
    const result = await discardHeldRun(req.params.importId);
    await auditFromRequest(req, { action: "feed_import.kept", subjectType: "feed_import", subjectLabel: req.params.importId, metadata: result });
    return res.json(detailResponse(result));
  })
);

async function findImport(req) {
  const row = await repo.getImportRow(req.params.importId);
  if (!row) throw AppError.notFound("That import was not found.");
  return row;
}

router.get(
  "/listing-imports/:importId",
  requireAuth,
  requireAdmin,
  requirePermission("api.view"),
  asyncHandler(async (req, res) => res.json(detailResponse(repo.serializeImport(await findImport(req)))))
);

router.get(
  "/listing-imports/:importId/items",
  requireAuth,
  requireAdmin,
  requirePermission("api.view"),
  validate({
    query: z.object({
      page: z.coerce.number().int().min(1).max(10_000).optional(),
      pageSize: z.coerce.number().int().min(1).max(100).optional(),
      status: z.enum(["failed", "warning", "succeeded", "queued"]).optional(),
      search: z.string().trim().max(191).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const row = await findImport(req);
    const { page = 1, pageSize = 50, status, search } = q(req);
    const result = await repo.listImportItems(row.id, { status, search, page, pageSize });
    return res.json(listResponse(result.rows, { page, pageSize, total: result.total }));
  })
);

/** Where a listing came from — channel, the partner's id, API key, company, and every import with its IP. */
router.get(
  "/listing-sources/:listingRef",
  requireAuth,
  requireAdmin,
  requirePermission("api.view", "listings.view"),
  asyncHandler(async (req, res) => {
    const source = await repo.listingSource(req.params.listingRef);
    if (!source) throw AppError.notFound("No listing with that id or reference was found.");
    return res.json(detailResponse(source));
  })
);

router.get(
  "/api-clients",
  requireAuth,
  requireAdmin,
  requirePermission("api.view"),
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const { page = 1, pageSize = 20, status, search, company } = q(req);
    const result = await repo.listApiClients({
      organizationPublicId: company || null,
      status: ["active", "suspended", "revoked"].includes(status) ? status : null,
      search: search || null,
      page,
      pageSize,
    });
    return res.json(listResponse(result.rows, { page, pageSize, total: result.total }));
  })
);

/** Suspend, reactivate or revoke any company's key, or set its IP allow-list. Revoking is final. */
router.patch(
  "/api-clients/:id",
  requireAuth,
  requireAdmin,
  writeLimiter,
  requirePermission("api.manage"),
  validate({
    body: z
      .object({
        status: z.enum(["active", "suspended", "revoked"]).optional(),
        allowedIps: z.array(z.string().trim().max(64)).max(20).optional(),
        reason: z.string().trim().max(300).optional(),
      })
      .refine((body) => body.status !== undefined || body.allowedIps !== undefined, { message: "Send a status or allowedIps." }),
  }),
  asyncHandler(async (req, res) => {
    const row = await repo.getApiClientRow(req.params.id);
    if (!row) throw AppError.notFound("That API key was not found.");
    if (row.status === "revoked" && req.body.status && req.body.status !== "revoked") {
      throw AppError.conflict("A revoked key cannot be turned back on. The company can create a new one.");
    }
    const assignments = [];
    const params = [];
    if (req.body.status && req.body.status !== row.status) {
      assignments.push("status = ?");
      params.push(req.body.status);
      if (req.body.status === "revoked") assignments.push("revoked_at = NOW(3)");
    }
    if (req.body.allowedIps !== undefined) {
      assignments.push("allowed_ips = CAST(? AS JSON)");
      params.push(JSON.stringify(normalizeAllowedIps(req.body.allowedIps)));
    }
    if (assignments.length) {
      await execute(`UPDATE api_clients SET ${assignments.join(", ")} WHERE id = ?`, [...params, row.id]);
    }
    await auditFromRequest(req, {
      action: req.body.status ? `api_client.${req.body.status === "active" ? "reactivated" : req.body.status}` : "api_client.updated",
      subjectType: "api_client",
      subjectId: row.id,
      subjectLabel: `${row.name} (${row.organization_name})`,
      changes: req.body,
    });
    const [updated] = (await repo.listApiClients({ search: row.client_id, pageSize: 1 })).rows;
    return res.json(detailResponse(updated));
  })
);

export default router;
