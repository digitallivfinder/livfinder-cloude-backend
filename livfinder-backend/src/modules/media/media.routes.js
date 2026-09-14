import { Router } from "express";
import multer from "multer";
import { z } from "zod";
import { asyncHandler } from "../../middleware/errors.js";
import { validate } from "../../middleware/validation.js";
import { uploadLimiter } from "../../middleware/rateLimit.js";
import { requireAuth, requireAccountCapability } from "../../middleware/auth.js";
import * as devAttachments from "../projects/developmentAttachments.service.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse } from "../../utils/http.js";
import { getStorage } from "../../config/storage.js";
import { LocalStorageAdapter } from "../../storage/localStorage.js";
import * as mediaService from "./media.service.js";
import * as listingMedia from "./listingMedia.service.js";
import { assertListingAccess } from "../portal/authorization.js";
import { categoryAllowsMedia, categoryDocumentTypes } from "../../utils/categoryMedia.js";
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
    /**
     * Short-lived, and revalidated after that.
     *
     * These are generated, not uploaded: the bytes change whenever the mark's design changes,
     * and at a day's `max-age` every browser that had seen the old one kept serving it for a
     * day afterwards — a redesign looked like it had not shipped. An hour, then an ETag check,
     * costs almost nothing for an SVG this small and keeps the rendered mark honest.
     */
    res.setHeader("Cache-Control", "public, max-age=3600, must-revalidate");
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
        // Both ids are the public id: every attach path (listing create,
        // `POST /listings/:id/media`) resolves media by `public_id`, and the
        // listing-media serializer reports `assetId` the same way. Handing back
        // the numeric row id here silently broke gallery attach on create.
        id: asset.public_id,
        assetId: asset.public_id,
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

/**
 * Any media change an owner makes to a live listing — a photo added, removed, reordered or
 * re-captioned, a file or a link — sends it back for review, exactly like an edit to its text:
 * the public page would otherwise show media no moderator has seen. A platform user is not the
 * owner and their change sends nothing back.
 */
async function sendBackIfLive(req, listing, reason) {
  if (req.auth.platform?.roles?.length) return;
  if (listing.status !== "active") return;
  const { sendBackForReview } = await import("../listings/listings.service.js");
  await sendBackForReview({ listingId: listing.id, userId: req.auth.user.id, reason: `${reason} by the owner after approval` });
}

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
        // This asset was created from bytes supplied in this authenticated request. Unlike
        // historical seed rows, that provenance is reliable enough to replace a seeded cover.
        promoteOverLegacy: true,
      });
    }

    // Attaching an existing library asset: it must belong to this account, or
    // be an unowned platform asset.
    for (const publicId of attachAssetIds) {
      const asset = await mediaService.resolveAssetRef(publicId);
      if (!asset) throw AppError.badRequest("One of the selected media items no longer exists.");
      if (asset.account_id && String(asset.account_id) !== String(req.auth.activeAccountId)) {
        throw AppError.forbidden("That media item belongs to another account.");
      }
      await listingMedia.attachAssetToListing({ listingId: listing.id, assetId: asset.id });
    }

    await listingMedia.syncListingMediaCounters(listing.id);
    const { refreshListingSearch } = await import("../listings/listings.repository.js");
    await refreshListingSearch(listing.id);
    await sendBackIfLive(req, listing, "Photos added");

    await auditFromRequest(req, {
      action: "listing.media_added",
      subjectType: "listing",
      subjectId: listing.id,
      metadata: { uploaded: files.length, attached: attachAssetIds.length },
    });

    return res.status(201).json({ data: await listingMedia.listListingMedia(listing.id, { includePrivate: true }) });
  })
);

/**
 * Floor plans and documents: a PDF or an image, attached under its own media type so it
 * never joins the gallery or becomes the cover. A document carries its type — title deed,
 * brochure, NOC — in `tag`.
 */
const FILE_MEDIA_TYPES = ["floor_plan", "document"];

router.post(
  "/listings/:listingId/files",
  uploadLimiter,
  requireAuth,
  validate({ params: listingIdParam }),
  upload.array("files", 10),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.listingId, "edit");
    const files = req.files || [];
    if (!files.length) throw AppError.badRequest("Attach at least one file.");

    const mediaType = String(req.body.mediaType || "");
    if (!FILE_MEDIA_TYPES.includes(mediaType)) {
      throw AppError.validation("Some information is invalid.", { mediaType: "Choose floor plan or document." });
    }
    if (mediaType === "floor_plan" && !categoryAllowsMedia(listing.root_category_id, "floor_plan")) {
      throw AppError.validation("Some information is invalid.", { mediaType: "Floor plans are only for real estate listings." });
    }
    const tag = req.body.tag ? String(req.body.tag) : null;
    if (mediaType === "document") {
      const allowed = categoryDocumentTypes(listing.root_category_id);
      if (!listingMedia.LISTING_DOCUMENT_TYPES.includes(tag) || !allowed.includes(tag)) {
        throw AppError.validation("Some information is invalid.", { tag: "Choose a document type for this category." });
      }
    }
    const caption = String(req.body.caption || "").trim().slice(0, 500) || null;

    for (const file of files) {
      const owner = { buffer: file.buffer, originalFileName: file.originalname, accountId: req.auth.activeAccountId, userId: req.auth.user.id };
      let stored;
      if (mediaService.isPdf(file.buffer)) {
        stored = await mediaService.storeDocument({ ...owner, caption });
      } else {
        try {
          stored = await mediaService.storeImage({ ...owner, scope: "listings", caption });
        } catch (error) {
          if (error?.status === 415) throw AppError.unsupportedMedia("Upload a PDF, JPG, PNG or WebP file.");
          throw error;
        }
      }
      await listingMedia.attachAssetToListing({
        listingId: listing.id,
        assetId: stored.id,
        mediaType,
        caption: caption || String(file.originalname || "").slice(0, 500) || null,
        tag: mediaType === "document" ? tag : null,
        isCover: false,
      });
    }

    await listingMedia.syncListingMediaCounters(listing.id);
    const { refreshListingSearch } = await import("../listings/listings.repository.js");
    await refreshListingSearch(listing.id);
    await sendBackIfLive(req, listing, "Files added");
    await auditFromRequest(req, {
      action: "listing.media_added",
      subjectType: "listing",
      subjectId: listing.id,
      metadata: { uploaded: files.length, mediaType },
    });
    return res.status(201).json({ data: await listingMedia.listListingMedia(listing.id, { includePrivate: true }) });
  })
);

const httpsUrl = z
  .string()
  .trim()
  .url()
  .max(700)
  .refine((value) => /^https:\/\//i.test(value), "Use an https:// link.");

/** Videos and virtual tours are links to where they are hosted, never uploaded bytes. */
router.post(
  "/listings/:listingId/links",
  requireAuth,
  validate({
    params: listingIdParam,
    body: z.object({
      mediaType: z.enum(["video", "virtual_tour"]),
      url: httpsUrl,
      caption: z.string().trim().max(500).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.listingId, "edit");
    if (!categoryAllowsMedia(listing.root_category_id, req.body.mediaType)) {
      throw AppError.validation("Some information is invalid.", {
        mediaType: req.body.mediaType === "virtual_tour"
          ? "Virtual tours are only for real estate listings."
          : "That media type is not available for this category.",
      });
    }
    const data = await listingMedia.addListingLink({
      listingId: listing.id,
      mediaType: req.body.mediaType,
      url: req.body.url,
      caption: req.body.caption || null,
    });
    await sendBackIfLive(req, listing, "Link added");
    await auditFromRequest(req, {
      action: "listing.media_added",
      subjectType: "listing",
      subjectId: listing.id,
      metadata: { linked: 1, mediaType: req.body.mediaType },
    });
    return res.status(201).json({ data });
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
    await sendBackIfLive(req, listing, "Photos reordered");
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
      url: httpsUrl.optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.listingId, "edit");
    const data = await listingMedia.updateListingMediaItem({
      listingId: listing.id,
      mediaId: req.params.mediaId,
      ...req.body,
    });
    await sendBackIfLive(req, listing, "Media updated");
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
    await sendBackIfLive(req, listing, "Media removed");
    await auditFromRequest(req, {
      action: "listing.media_removed",
      subjectType: "listing",
      subjectId: listing.id,
      metadata: { mediaId: req.params.mediaId },
    });
    return res.json({ data });
  })
);

/* --------------------------------------------------------------------------
 * Development files and links — the developer's own, from the portal
 *
 * Floor plans, the brochure and documents (PDF or image), a video and virtual tours. Only the
 * admin wizard could add these before; the portal had no way to attach a floor plan or a
 * brochure to a development. A change to a published development sends it back for review.
 * ------------------------------------------------------------------------ */
const developmentParams = z.object({ projectId: z.string().trim().min(1).max(200) });

async function afterDevelopmentChange(req, project) {
  if (req.auth.platform?.roles?.length) return;
  await devAttachments.sendDevelopmentBackForReview(project);
}

router.get(
  "/developments/:projectId/attachments",
  requireAuth,
  validate({ params: developmentParams }),
  asyncHandler(async (req, res) => {
    const project = await devAttachments.ownedDevelopment(req.auth.activeAccountId, req.params.projectId);
    return res.json({ data: await devAttachments.developmentAttachments(project.id) });
  })
);

router.post(
  "/developments/:projectId/files",
  uploadLimiter,
  requireAuth,
  requireAccountCapability("can_manage_listings"),
  validate({ params: developmentParams }),
  upload.array("files", 10),
  asyncHandler(async (req, res) => {
    const project = await devAttachments.ownedDevelopment(req.auth.activeAccountId, req.params.projectId);
    const files = req.files || [];
    if (!files.length) throw AppError.badRequest("Attach at least one file.");
    const mediaType = String(req.body.mediaType || "");
    if (!FILE_MEDIA_TYPES.includes(mediaType)) {
      throw AppError.validation("Some information is invalid.", { mediaType: "Choose floor plan or document." });
    }
    const tag = req.body.tag ? String(req.body.tag) : null;
    if (mediaType === "document" && !devAttachments.DEVELOPMENT_DOCUMENT_TYPES.includes(tag)) {
      throw AppError.validation("Some information is invalid.", { tag: "Choose a document type for this development." });
    }
    const caption = String(req.body.caption || "").trim().slice(0, 255) || null;

    for (const file of files) {
      const owner = { buffer: file.buffer, originalFileName: file.originalname, accountId: req.auth.activeAccountId, userId: req.auth.user.id };
      let stored;
      if (mediaService.isPdf(file.buffer)) {
        stored = await mediaService.storeDocument({ ...owner, caption });
      } else {
        try {
          stored = await mediaService.storeImage({ ...owner, scope: "listings", caption });
        } catch (error) {
          if (error?.status === 415) throw AppError.unsupportedMedia("Upload a PDF, JPG, PNG or WebP file.");
          throw error;
        }
      }
      await devAttachments.attachDevelopmentFile({
        projectId: project.id,
        assetId: stored.id,
        mediaType,
        documentType: tag,
        caption: caption || String(file.originalname || "").slice(0, 255) || null,
        userId: req.auth.user.id,
      });
    }

    await afterDevelopmentChange(req, project);
    await auditFromRequest(req, {
      action: "development.media_added",
      subjectType: "project",
      subjectId: project.id,
      metadata: { uploaded: files.length, mediaType },
    });
    return res.status(201).json({ data: await devAttachments.developmentAttachments(project.id) });
  })
);

router.post(
  "/developments/:projectId/links",
  requireAuth,
  requireAccountCapability("can_manage_listings"),
  validate({
    params: developmentParams,
    body: z.object({
      mediaType: z.enum(["video", "virtual_tour"]),
      url: httpsUrl,
      caption: z.string().trim().max(255).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const project = await devAttachments.ownedDevelopment(req.auth.activeAccountId, req.params.projectId);
    await devAttachments.addDevelopmentLink({ projectId: project.id, ...req.body });
    await afterDevelopmentChange(req, project);
    await auditFromRequest(req, {
      action: "development.media_added",
      subjectType: "project",
      subjectId: project.id,
      metadata: { linked: 1, mediaType: req.body.mediaType },
    });
    return res.status(201).json({ data: await devAttachments.developmentAttachments(project.id) });
  })
);

router.delete(
  "/developments/:projectId/attachments/:attachmentId",
  requireAuth,
  requireAccountCapability("can_manage_listings"),
  validate({ params: developmentParams.extend({ attachmentId: z.string().trim().min(1).max(120) }) }),
  asyncHandler(async (req, res) => {
    const project = await devAttachments.ownedDevelopment(req.auth.activeAccountId, req.params.projectId);
    await devAttachments.removeDevelopmentAttachment({ projectId: project.id, attachmentId: req.params.attachmentId });
    await afterDevelopmentChange(req, project);
    await auditFromRequest(req, {
      action: "development.media_removed",
      subjectType: "project",
      subjectId: project.id,
      metadata: { attachmentId: req.params.attachmentId },
    });
    return res.json({ data: await devAttachments.developmentAttachments(project.id) });
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
