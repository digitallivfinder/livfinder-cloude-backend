import { Router } from "express";
import multer from "multer";
import { z } from "zod";
import { asyncHandler } from "../../middleware/errors.js";
import { validate } from "../../middleware/validation.js";
import { uploadLimiter } from "../../middleware/rateLimit.js";
import { requireAuth } from "../../middleware/auth.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse } from "../../utils/http.js";
import { getStorage } from "../../config/storage.js";
import { LocalStorageAdapter } from "../../storage/localStorage.js";
import * as mediaService from "./media.service.js";
import * as listingMedia from "./listingMedia.service.js";
import { assertListingAccess } from "../portal/authorization.js";
import { auditFromRequest } from "../system/audit.service.js";
import { readVerificationDocument } from "../accounts/verification.service.js";
import { queryOne } from "../../db/query.js";
import { renderPlaceholder } from "./placeholder.js";

const router = Router();

// Files stay in memory: they are validated, transcoded and handed to the
// storage adapter without ever being written to a temp path on this host.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: mediaService.MAX_IMAGE_BYTES, files: 20 },
});

/* --------------------------------------------------------------------------
 * Public media serving (local driver only)
 *
 * Mounted at /media before CSRF. With STORAGE_DRIVER=s3 these objects are
 * served by the bucket/CDN instead and this router is simply unused.
 * ------------------------------------------------------------------------ */
const publicRouter = Router();

/**
 * Stand-in imagery for seeded CDN paths. Mounted before the storage wildcard so it wins for
 * `/media/placeholder/...`; see placeholder.js for why this exists.
 */
publicRouter.get(
  "/placeholder/*splat",
  (req, res) => {
    const raw = req.params.splat ?? req.params[0] ?? "";
    const pathname = (Array.isArray(raw) ? raw : String(raw).split("/"))
      .map((segment) => decodeURIComponent(segment))
      .join("/");
    res.setHeader("Cache-Control", "public, max-age=86400");
    res.type("image/svg+xml");
    return res.send(renderPlaceholder(pathname));
  }
);

publicRouter.get(
  "/*splat",
  asyncHandler(async (req, res) => {
    const storage = getStorage();
    if (!(storage instanceof LocalStorageAdapter)) throw AppError.notFound();
    // Express 5 hands a wildcard back as an array of path segments.
    const raw = req.params.splat ?? req.params[0] ?? "";
    const key = (Array.isArray(raw) ? raw : String(raw).split("/"))
      .map((segment) => decodeURIComponent(segment))
      .join("/");
    const stat = await storage.stat(key, { visibility: "public" });
    if (!stat) {
      /**
       * The object is recorded but the bytes are not here — a storage volume that was not
       * restored alongside the database, or a file removed out of band. Serving the generated
       * stand-in keeps the page intact instead of scattering broken-image icons across it, and
       * the short cache means it starts working the moment the file reappears.
       *
       * Not a 200 lie: the status is 404, so a crawler or a monitor still sees a miss. Browsers
       * render the body of a 404 image response, which is the behaviour wanted here.
       */
      res.status(404);
      res.setHeader("Cache-Control", "public, max-age=60");
      res.type("image/svg+xml");
      return res.send(renderPlaceholder(key));
    }
    res.setHeader("Cache-Control", "public, max-age=31536000, immutable");
    res.setHeader("Content-Length", String(stat.size));
    res.type(key.split(".").pop());
    storage.createStream(key, { visibility: "public" }).pipe(res);
  })
);

/* --------------------------------------------------------------------------
 * Uploads
 * ------------------------------------------------------------------------ */

router.post(
  "/upload",
  uploadLimiter,
  requireAuth,
  upload.array("files", 20),
  asyncHandler(async (req, res) => {
    const files = req.files || (req.file ? [req.file] : []);
    if (!files.length) throw AppError.badRequest("Attach at least one image.");

    const results = [];
    for (const file of files) {
      const asset = await mediaService.storeImage({
        buffer: file.buffer,
        originalFileName: file.originalname,
        accountId: req.auth.activeAccountId,
        userId: req.auth.user.id,
        scope: String(req.body.scope || "listings").replace(/[^a-z0-9/-]/gi, "") || "listings",
        altText: req.body.altText ? String(req.body.altText).slice(0, 255) : null,
        caption: req.body.caption ? String(req.body.caption).slice(0, 500) : null,
      });
      results.push({
        id: asset.public_id,
        assetId: String(asset.id),
        url: asset.url,
        thumbnailUrl: mediaService.thumbnailFrom(asset.renditions || [], asset.url),
        width: asset.width,
        height: asset.height,
        sizeBytes: asset.file_size_bytes,
        mimeType: asset.mime_type,
        alt: asset.alt_text,
        renditions: asset.renditions || [],
        deduplicated: Boolean(asset.deduplicated),
      });
    }

    await auditFromRequest(req, {
      action: "media.uploaded",
      subjectType: "media_asset",
      metadata: { count: results.length },
    });
    return res.status(201).json({ data: results });
  })
);

/** The local driver's stand-in for a presigned PUT. */
router.put(
  "/direct-upload",
  uploadLimiter,
  express_raw(),
  asyncHandler(async (req, res) => {
    const storage = getStorage();
    if (!(storage instanceof LocalStorageAdapter)) throw AppError.notFound();
    const { key, visibility = "private", expires, signature } = req.query;
    if (!key || !storage.verifySignature(String(key), String(visibility), expires, signature)) {
      throw AppError.forbidden("That upload link is no longer valid.");
    }
    if (!Buffer.isBuffer(req.body) || !req.body.length) throw AppError.badRequest("No file content received.");
    await storage.put(String(key), req.body, {
      contentType: req.get("content-type"),
      visibility: String(visibility),
    });
    return res.status(200).json(detailResponse({ key: String(key), stored: true }));
  })
);

/** Reads a private object through a signed, expiring link. */
router.get(
  "/signed",
  asyncHandler(async (req, res) => {
    const storage = getStorage();
    if (!(storage instanceof LocalStorageAdapter)) throw AppError.notFound();
    const { key, visibility = "private", expires, signature } = req.query;
    if (!key || !storage.verifySignature(String(key), String(visibility), expires, signature)) {
      throw AppError.forbidden("That link is no longer valid.");
    }
    const body = await storage.get(String(key), { visibility: String(visibility) });
    res.setHeader("Cache-Control", "private, no-store");
    res.type(String(key).split(".").pop());
    return res.send(body);
  })
);

router.get(
  "/verification-documents/:id",
  requireAuth,
  asyncHandler(async (req, res) => {
    const document = await readVerificationDocument({ documentId: req.params.id, req });
    res.setHeader("Cache-Control", "private, no-store");
    res.setHeader("Content-Disposition", `inline; filename="${document.fileName.replace(/"/g, "")}"`);
    res.type(document.mimeType);
    return res.send(document.body);
  })
);

/* --------------------------------------------------------------------------
 * Listing galleries
 * ------------------------------------------------------------------------ */

const listingIdParam = z.object({ listingId: z.string().min(1).max(64) });

router.get(
  "/listings/:listingId/media",
  requireAuth,
  validate({ params: listingIdParam }),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.listingId, "view");
    return res.json({ data: await listingMedia.listListingMedia(listing.id, { includePrivate: true }) });
  })
);

router.post(
  "/listings/:listingId/media",
  uploadLimiter,
  requireAuth,
  validate({ params: listingIdParam }),
  upload.array("files", 20),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.listingId, "edit");
    const files = req.files || [];
    const attachAssetIds = req.body.assetIds
      ? String(req.body.assetIds).split(",").map((value) => value.trim()).filter(Boolean)
      : [];

    if (!files.length && !attachAssetIds.length) {
      throw AppError.badRequest("Attach at least one image.");
    }

    for (const file of files) {
      const asset = await mediaService.storeImage({
        buffer: file.buffer,
        originalFileName: file.originalname,
        accountId: req.auth.activeAccountId,
        userId: req.auth.user.id,
        scope: "listings",
        altText: req.body.altText ? String(req.body.altText).slice(0, 255) : null,
      });
      await listingMedia.attachAssetToListing({
        listingId: listing.id,
        assetId: asset.id,
        altText: asset.alt_text,
      });
    }

    // Attaching an existing library asset: it must belong to this account, or
    // be an unowned platform asset.
    for (const publicId of attachAssetIds) {
      const asset = await mediaService.getAssetByPublicId(publicId);
      if (!asset) throw AppError.badRequest("One of the selected media items no longer exists.");
      if (asset.account_id && String(asset.account_id) !== String(req.auth.activeAccountId)) {
        throw AppError.forbidden("That media item belongs to another account.");
      }
      await listingMedia.attachAssetToListing({ listingId: listing.id, assetId: asset.id });
    }

    await listingMedia.syncListingMediaCounters(listing.id);
    const { refreshListingSearch } = await import("../listings/listings.repository.js");
    await refreshListingSearch(listing.id);

    await auditFromRequest(req, {
      action: "listing.media_added",
      subjectType: "listing",
      subjectId: listing.id,
      metadata: { uploaded: files.length, attached: attachAssetIds.length },
    });

    return res.status(201).json({ data: await listingMedia.listListingMedia(listing.id, { includePrivate: true }) });
  })
);

router.patch(
  "/listings/:listingId/media/reorder",
  requireAuth,
  validate({
    params: listingIdParam,
    body: z.object({ order: z.array(z.union([z.string(), z.number()])).min(1).max(200) }),
  }),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.listingId, "edit");
    const data = await listingMedia.reorderListingMedia({
      listingId: listing.id,
      orderedIds: req.body.order,
    });
    await auditFromRequest(req, { action: "listing.media_reordered", subjectType: "listing", subjectId: listing.id });
    return res.json({ data });
  })
);

router.patch(
  "/listings/:listingId/media/:mediaId",
  requireAuth,
  validate({
    params: listingIdParam.extend({ mediaId: z.string().min(1).max(32) }),
    body: z.object({
      altText: z.string().trim().max(255).optional(),
      caption: z.string().trim().max(500).optional(),
      tag: z.string().trim().max(80).optional(),
      isCover: z.boolean().optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.listingId, "edit");
    const data = await listingMedia.updateListingMediaItem({
      listingId: listing.id,
      mediaId: req.params.mediaId,
      ...req.body,
    });
    await auditFromRequest(req, {
      action: "listing.media_updated",
      subjectType: "listing",
      subjectId: listing.id,
      changes: req.body,
    });
    return res.json({ data });
  })
);

router.delete(
  "/listings/:listingId/media/:mediaId",
  requireAuth,
  validate({ params: listingIdParam.extend({ mediaId: z.string().min(1).max(32) }) }),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.listingId, "edit");
    const data = await listingMedia.removeListingMedia({
      listingId: listing.id,
      mediaId: req.params.mediaId,
    });
    await auditFromRequest(req, {
      action: "listing.media_removed",
      subjectType: "listing",
      subjectId: listing.id,
      metadata: { mediaId: req.params.mediaId },
    });
    return res.json({ data });
  })
);

router.get(
  "/assets/:publicId",
  requireAuth,
  asyncHandler(async (req, res) => {
    const asset = await mediaService.getAssetByPublicId(req.params.publicId);
    if (!asset) throw AppError.notFound();
    if (asset.account_id && String(asset.account_id) !== String(req.auth.activeAccountId) && !req.auth.platform.roles.length) {
      throw AppError.forbidden();
    }
    return res.json(
      detailResponse({
        id: asset.public_id,
        url: asset.url,
        width: asset.width,
        height: asset.height,
        mimeType: asset.mime_type,
        alt: asset.alt_text,
        renditions: await mediaService.listRenditions(asset.id),
      })
    );
  })
);

// Raw body parser for the direct-upload PUT only.
function express_raw() {
  return (req, res, next) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > mediaService.MAX_IMAGE_BYTES) {
        req.destroy();
        next(AppError.payloadTooLarge());
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      req.body = Buffer.concat(chunks);
      next();
    });
    req.on("error", next);
  };
}

router.publicRouter = publicRouter;
export { publicRouter };
export default router;
