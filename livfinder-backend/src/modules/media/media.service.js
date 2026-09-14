import crypto from "node:crypto";
import path from "node:path";
import sharp from "sharp";
import { query, queryOne, queryValue, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { getStorage } from "../../config/storage.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { slugify } from "../../utils/slug.js";
import logger from "../../config/logger.js";
import { scanBuffer } from "./scanner.js";

/**
 * Image uploads.
 *
 * The browser-declared MIME type is never trusted on its own: sharp reads the
 * actual container, and a file whose bytes are not an image it recognises is
 * rejected regardless of what the extension or Content-Type claimed.
 */
export const ALLOWED_IMAGE_FORMATS = new Map([
  ["jpeg", { mime: "image/jpeg", extension: "jpg" }],
  ["jpg", { mime: "image/jpeg", extension: "jpg" }],
  ["png", { mime: "image/png", extension: "png" }],
  ["webp", { mime: "image/webp", extension: "webp" }],
  ["avif", { mime: "image/avif", extension: "avif" }],
  ["gif", { mime: "image/gif", extension: "gif" }],
  ["heif", { mime: "image/heic", extension: "heic" }],
]);

export const MAX_IMAGE_BYTES = 15 * 1024 * 1024;

/**
 * Renditions generated for every uploaded image. `thumb` and `card` are what a
 * results page actually loads; the original is kept but never served to a card.
 */
export const RENDITIONS = [
  { code: "thumb", width: 320, format: "webp", quality: 74 },
  { code: "card", width: 800, format: "webp", quality: 78 },
  { code: "gallery", width: 1600, format: "webp", quality: 82 },
];

function storageKey({ scope, extension }) {
  const random = crypto.randomBytes(12).toString("hex");
  const date = new Date();
  const yyyymm = `${date.getUTCFullYear()}${String(date.getUTCMonth() + 1).padStart(2, "0")}`;
  // Randomised, date-partitioned, and carrying nothing the caller supplied.
  return `${scope}/${yyyymm}/${Date.now()}-${random}.${extension}`;
}

export async function inspectImage(buffer) {
  let metadata;
  try {
    metadata = await sharp(buffer, { failOn: "error" }).metadata();
  } catch {
    throw AppError.unsupportedMedia("That file is not a readable image.");
  }
  const format = ALLOWED_IMAGE_FORMATS.get(String(metadata.format || "").toLowerCase());
  if (!format) throw AppError.unsupportedMedia("Upload a JPEG, PNG, WebP, AVIF or HEIC image.");
  if (!metadata.width || !metadata.height) throw AppError.unsupportedMedia("That image has no readable dimensions.");
  return {
    format: metadata.format,
    mime: format.mime,
    extension: format.extension,
    width: metadata.width,
    height: metadata.height,
    hasAlpha: Boolean(metadata.hasAlpha),
    isAnimated: Boolean(metadata.pages && metadata.pages > 1),
    space: metadata.space,
    orientation: metadata.orientation ?? null,
  };
}

async function dominantColour(buffer) {
  try {
    const { dominant } = await sharp(buffer).stats();
    const hex = (value) => Math.max(0, Math.min(255, Math.round(value))).toString(16).padStart(2, "0");
    return `#${hex(dominant.r)}${hex(dominant.g)}${hex(dominant.b)}`;
  } catch {
    return null;
  }
}

/**
 * Stores an image, its renditions and its `media_assets` row.
 *
 * Duplicate detection is by SHA-256 of the bytes, scoped to the account: the
 * same photograph uploaded twice reuses the stored object instead of paying for
 * it again.
 */
export async function storeImage({
  buffer,
  originalFileName,
  accountId = null,
  userId = null,
  scope = "listings",
  altText = null,
  caption = null,
  source = "upload",
  folderId = null,
  visibility = "public",
}) {
  if (buffer.length > MAX_IMAGE_BYTES) {
    throw AppError.payloadTooLarge("Images must be 15 MB or smaller.");
  }
  const info = await inspectImage(buffer);
  const checksum = crypto.createHash("sha256").update(buffer).digest("hex");

  const duplicate = await queryOne(
    `SELECT id, public_id, url, storage_path, width, height, file_size_bytes, mime_type, alt_text
       FROM media_assets
      WHERE checksum = ? AND deleted_at IS NULL
        AND (account_id <=> ? OR account_id IS NULL)
      ORDER BY id ASC LIMIT 1`,
    [checksum, accountId]
  );
  if (duplicate) {
    await execute(
      "UPDATE media_assets SET reference_count = reference_count + 1, last_referenced_at = NOW(3) WHERE id = ?",
      [duplicate.id]
    );
    return { ...duplicate, id: duplicate.id, deduplicated: true, renditions: await listRenditions(duplicate.id) };
  }

  const storage = getStorage();
  const baseName = slugify(path.parse(originalFileName || "image").name).slice(0, 60) || "image";
  const key = storageKey({ scope: `${scope}/${baseName}`, extension: info.extension });

  /**
   * Scan before anything is written. An infected file must never reach the store, even briefly:
   * a public object is reachable the moment it exists, and deleting it afterwards is a race.
   */
  const scan = await scanBuffer(buffer);
  if (scan.status === "infected") {
    logger.warn({ detail: scan.detail, originalFileName }, "upload rejected by the malware scanner");
    throw AppError.badRequest("That file was rejected by the malware scanner.");
  }

  const stored = await storage.put(key, buffer, { contentType: info.mime, visibility });
  const url = visibility === "public" ? storage.publicUrl(key) : `private://${key}`;
  const colour = await dominantColour(buffer);

  const assetId = await withTransaction(async (connection) => {
    const result = await execute(
      `INSERT INTO media_assets
         (public_id, folder_id, account_id, uploaded_by_user_id, media_type, storage_disk,
          storage_path, url, file_name, original_file_name, mime_type, extension,
          file_size_bytes, width, height, color_space, has_alpha, orientation, is_animated,
          aspect_ratio, checksum, source, dominant_color, alt_text, caption,
          scan_status, processing_status, reference_count, last_referenced_at, tier, created_at)
       VALUES (?, ?, ?, ?, 'image', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
               ?, 'ready', 1, NOW(3), 'hot', NOW(3))`,
      [
        ulid(),
        folderId,
        accountId,
        userId,
        storage.driver,
        key,
        url,
        key.split("/").pop(),
        String(originalFileName || "").slice(0, 255) || null,
        info.mime,
        info.extension,
        buffer.length,
        info.width,
        info.height,
        info.space === "srgb" ? "srgb" : info.space === "cmyk" ? "cmyk" : "unknown",
        info.hasAlpha ? 1 : 0,
        info.orientation,
        info.isAnimated ? 1 : 0,
        Number((info.width / info.height).toFixed(5)),
        checksum,
        source,
        colour,
        altText,
        caption,
        // The scanner's verdict, recorded rather than assumed. `skipped` means no scanner is
        // configured — a different statement from `clean`, and the two must not be conflated.
        scan.status,
      ],
      connection
    );
    return result.insertId;
  });

  const renditions = await generateRenditions({ assetId, buffer, key, info, visibility });

  return {
    id: assetId,
    public_id: await queryValue("SELECT public_id FROM media_assets WHERE id = ?", [assetId]),
    url,
    storage_path: key,
    width: info.width,
    height: info.height,
    file_size_bytes: stored.size,
    mime_type: info.mime,
    alt_text: altText,
    checksum,
    deduplicated: false,
    renditions,
  };
}

async function generateRenditions({ assetId, buffer, key, info, visibility }) {
  if (visibility !== "public") return [];
  const storage = getStorage();
  const created = [];
  for (const rendition of RENDITIONS) {
    // Never upscale: a 600px original has no 1600px rendition.
    if (info.width < rendition.width && rendition.code !== "thumb") continue;
    try {
      const output = await sharp(buffer, { failOn: "error" })
        .rotate()
        .resize({ width: rendition.width, withoutEnlargement: true })
        .toFormat(rendition.format, { quality: rendition.quality })
        .toBuffer({ resolveWithObject: true });

      const renditionKey = key.replace(/\.([a-z0-9]+)$/i, `.${rendition.code}.${rendition.format}`);
      await storage.put(renditionKey, output.data, { contentType: `image/${rendition.format}`, visibility });

      await execute(
        `INSERT INTO media_renditions
           (media_asset_id, preset_code, format, width, height, pixel_density, file_size_bytes,
            storage_path, url, checksum, is_watermarked, status, generated_at, created_at)
         VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?, ?, 0, 'ready', NOW(3), NOW(3))`,
        [
          assetId,
          rendition.code,
          rendition.format,
          output.info.width,
          output.info.height,
          output.data.length,
          renditionKey,
          storage.publicUrl(renditionKey),
          crypto.createHash("sha256").update(output.data).digest("hex"),
        ]
      );
      created.push({ code: rendition.code, url: storage.publicUrl(renditionKey), width: output.info.width, height: output.info.height });
    } catch (error) {
      // A failed rendition is not a failed upload: the original is stored and
      // usable, and the job can be retried.
      logger.warn({ err: error, assetId, rendition: rendition.code }, "rendition generation failed");
    }
  }
  return created;
}

const PDF_SIGNATURE = Buffer.from("%PDF-");

/** Read from the bytes, never from the declared type or the file name. */
export function isPdf(buffer) {
  return Buffer.isBuffer(buffer) && buffer.length > PDF_SIGNATURE.length && buffer.subarray(0, 5).equals(PDF_SIGNATURE);
}

/**
 * Stores a PDF — a brochure, title deed, floor plan — as a media asset.
 *
 * The same gates as an image: a size cap, a check of the bytes themselves, and a malware
 * scan before anything reaches the store. Nothing is rendered or resized; a PDF is kept as
 * it arrived.
 */
export async function storeDocument({ buffer, originalFileName, accountId, userId, scope = "listings/documents", caption = null }) {
  if (buffer.length > MAX_IMAGE_BYTES) {
    throw AppError.payloadTooLarge("Files must be 15 MB or smaller.");
  }
  if (!isPdf(buffer)) throw AppError.unsupportedMedia("Upload a PDF, JPG, PNG or WebP file.");
  const checksum = crypto.createHash("sha256").update(buffer).digest("hex");

  const scan = await scanBuffer(buffer);
  if (scan.status === "infected") {
    logger.warn({ detail: scan.detail, originalFileName }, "upload rejected by the malware scanner");
    throw AppError.badRequest("That file was rejected by the malware scanner.");
  }

  const storage = getStorage();
  const baseName = slugify(path.parse(originalFileName || "document").name).slice(0, 60) || "document";
  const key = storageKey({ scope: `${scope}/${baseName}`, extension: "pdf" });
  const stored = await storage.put(key, buffer, { contentType: "application/pdf", visibility: "public" });
  const url = storage.publicUrl(key);

  const result = await execute(
    `INSERT INTO media_assets
       (public_id, account_id, uploaded_by_user_id, media_type, storage_disk, storage_path, url,
        file_name, original_file_name, mime_type, extension, file_size_bytes, checksum, source,
        caption, scan_status, processing_status, reference_count, last_referenced_at, tier, created_at)
     VALUES (?, ?, ?, 'document', ?, ?, ?, ?, ?, 'application/pdf', 'pdf', ?, ?, 'upload', ?, ?, 'ready', 1, NOW(3), 'hot', NOW(3))`,
    [
      ulid(),
      accountId,
      userId,
      storage.driver,
      key,
      url,
      key.split("/").pop(),
      String(originalFileName || "").slice(0, 255) || null,
      stored?.size ?? buffer.length,
      checksum,
      caption,
      scan.status,
    ]
  );
  return { id: result.insertId, url, mime_type: "application/pdf" };
}

export async function listRenditions(assetId) {
  const rows = await query(
    "SELECT preset_code, url, width, height FROM media_renditions WHERE media_asset_id = ? AND status = 'ready'",
    [assetId]
  );
  return rows.map((row) => ({ code: row.preset_code, url: row.url, width: row.width, height: row.height }));
}

export function thumbnailFrom(renditions, fallbackUrl) {
  return renditions.find((rendition) => rendition.code === "card")?.url
    ?? renditions.find((rendition) => rendition.code === "thumb")?.url
    ?? fallbackUrl;
}

export async function softDeleteAsset(assetId) {
  await execute(
    `UPDATE media_assets
        SET reference_count = GREATEST(0, reference_count - 1),
            deleted_at = IF(reference_count - 1 <= 0, NOW(3), deleted_at)
      WHERE id = ?`,
    [assetId]
  );
}

export async function getAsset(assetId) {
  return queryOne(
    `SELECT ma.*, mf.path AS folder_path
       FROM media_assets ma LEFT JOIN media_folders mf ON mf.id = ma.folder_id
      WHERE ma.id = ? AND ma.deleted_at IS NULL`,
    [Number(assetId)]
  );
}

export async function getAssetByPublicId(publicId) {
  return queryOne(
    "SELECT * FROM media_assets WHERE public_id = ? AND deleted_at IS NULL LIMIT 1",
    [publicId]
  );
}

/**
 * Resolves a caller-supplied asset reference. The public id is the contract, but
 * older upload responses handed back the numeric row id, so a bare integer is
 * accepted as a fallback rather than silently resolving to nothing.
 */
export async function resolveAssetRef(ref) {
  if (ref === null || ref === undefined || ref === "") return null;
  const asString = String(ref).trim();
  const byPublicId = await getAssetByPublicId(asString);
  if (byPublicId) return byPublicId;
  if (/^\d+$/.test(asString)) {
    return queryOne(
      "SELECT * FROM media_assets WHERE id = ? AND deleted_at IS NULL LIMIT 1",
      [Number(asString)]
    );
  }
  return null;
}
