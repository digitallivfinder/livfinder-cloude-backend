import crypto from "node:crypto";
import path from "node:path";
import sharp from "sharp";
import { execute, inClause, query, queryOne } from "../../db/query.js";
import { getStorage } from "../../config/storage.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import logger from "../../config/logger.js";
import { scanBuffer } from "../media/scanner.js";

/**
 * Files shared in a chat.
 *
 *  - Uploaded before the message that carries them (message_id NULL until it is sent), so the
 *    composer can show progress and a preview. Only the uploader can see or send an unsent file;
 *    an upload never sent is deleted by the sweep after a day.
 *  - Always private storage, read back through GET /v1/chat/attachments/:id after the same
 *    participant check as the thread itself. Nothing in a chat has a public URL.
 *  - The bytes must match the extension (magic numbers), and every file goes through the
 *    malware scanner when one is configured.
 *  - Photos are re-encoded: that strips EXIF, including GPS, which phone photos carry and which
 *    would otherwise tell the other side where the picture was taken. A small preview is stored
 *    alongside for the thread.
 */

export const MAX_ATTACHMENT_BYTES = 20 * 1024 * 1024;
export const MAX_ATTACHMENTS_PER_MESSAGE = 10;
const MAX_IMAGE_EDGE = 2560;
const PREVIEW_EDGE = 640;

const DOCUMENT_TYPES = Object.freeze({
  pdf: { mime: "application/pdf", magic: ["25504446"] },
  doc: { mime: "application/msword", magic: ["d0cf11e0"] },
  xls: { mime: "application/vnd.ms-excel", magic: ["d0cf11e0"] },
  docx: { mime: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", magic: ["504b0304"] },
  xlsx: { mime: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", magic: ["504b0304"] },
  pptx: { mime: "application/vnd.openxmlformats-officedocument.presentationml.presentation", magic: ["504b0304"] },
  txt: { mime: "text/plain", magic: null },
  csv: { mime: "text/csv", magic: null },
});

const IMAGE_FORMATS = Object.freeze({
  jpeg: { mime: "image/jpeg", extension: "jpg" },
  png: { mime: "image/png", extension: "png" },
  webp: { mime: "image/webp", extension: "webp" },
  gif: { mime: "image/gif", extension: "gif" },
  heif: { mime: "image/jpeg", extension: "jpg" },
  avif: { mime: "image/jpeg", extension: "jpg" },
});

const isImageMime = (mime) => /^image\//.test(String(mime || ""));

export function attachmentDto(row) {
  const stored = Boolean(row.storage_key);
  const url = stored ? `/v1/chat/attachments/${row.public_id}` : /^https?:\/\//.test(row.file_url || "") ? row.file_url : null;
  return {
    id: row.public_id,
    name: row.file_name,
    mimeType: row.mime_type,
    size: row.file_size_bytes === null ? null : Number(row.file_size_bytes),
    isImage: isImageMime(row.mime_type),
    width: row.width ?? null,
    height: row.height ?? null,
    url,
    previewUrl: stored && row.preview_key ? `${url}?preview=1` : isImageMime(row.mime_type) ? url : null,
    downloadUrl: stored ? `${url}?download=1` : url,
  };
}

const safeName = (name) =>
  String(name || "file")
    .replace(/[\\/]/g, "_")
    .replace(/[\u0000-\u001F\u007F"<>|*?:]/g, "")
    .trim()
    .slice(0, 200) || "file";

function chatKey(extension) {
  const now = new Date();
  return `chat/${now.getUTCFullYear()}/${String(now.getUTCMonth() + 1).padStart(2, "0")}/${ulid()}${crypto.randomBytes(4).toString("hex")}.${extension}`;
}

function looksLikeText(buffer) {
  const sample = buffer.subarray(0, 4096);
  // NUL bytes mean binary; a text file pretending otherwise is refused.
  return !sample.includes(0);
}

async function prepareImage(buffer) {
  let metadata;
  try {
    metadata = await sharp(buffer, { failOn: "error" }).metadata();
  } catch {
    return null;
  }
  const format = IMAGE_FORMATS[String(metadata.format || "").toLowerCase()];
  if (!format) return null;

  // Animated GIFs keep their frames; everything else is re-encoded without metadata.
  if (metadata.format === "gif") {
    const preview = await sharp(buffer, { animated: false }).resize(PREVIEW_EDGE, PREVIEW_EDGE, { fit: "inside", withoutEnlargement: true }).webp({ quality: 70 }).toBuffer();
    return { body: buffer, mime: format.mime, extension: "gif", width: metadata.width, height: metadata.height, preview };
  }
  const pipeline = sharp(buffer, { failOn: "error" }).rotate().resize(MAX_IMAGE_EDGE, MAX_IMAGE_EDGE, { fit: "inside", withoutEnlargement: true });
  const encoded =
    format.extension === "png"
      ? await pipeline.png({ compressionLevel: 9 }).toBuffer({ resolveWithObject: true })
      : format.extension === "webp"
        ? await pipeline.webp({ quality: 85 }).toBuffer({ resolveWithObject: true })
        : await pipeline.jpeg({ quality: 85, mozjpeg: true }).toBuffer({ resolveWithObject: true });
  const preview = await sharp(encoded.data).resize(PREVIEW_EDGE, PREVIEW_EDGE, { fit: "inside", withoutEnlargement: true }).webp({ quality: 72 }).toBuffer();
  return {
    body: encoded.data,
    mime: format.mime,
    extension: format.extension,
    width: encoded.info.width,
    height: encoded.info.height,
    preview,
  };
}

function prepareDocument(buffer, originalName) {
  const extension = path.extname(String(originalName || "")).slice(1).toLowerCase();
  const type = Object.hasOwn(DOCUMENT_TYPES, extension) ? DOCUMENT_TYPES[extension] : null;
  if (!type) return null;
  if (type.magic && !type.magic.some((magic) => buffer.subarray(0, magic.length / 2).equals(Buffer.from(magic, "hex")))) return null;
  if (!type.magic && !looksLikeText(buffer)) return null;
  return { body: buffer, mime: type.mime, extension };
}

/** Stores one file for a conversation the uploader may write to (checked by the caller). */
export async function storeAttachment({ identity, conversationId, file }) {
  if (!file?.buffer?.length) throw AppError.badRequest("Choose a file to send.");
  if (file.buffer.length > MAX_ATTACHMENT_BYTES) throw AppError.payloadTooLarge("Files must be 20 MB or smaller.");

  const prepared = (await prepareImage(file.buffer)) || prepareDocument(file.buffer, file.originalname);
  if (!prepared) {
    throw AppError.unsupportedMedia("Send a photo (JPG, PNG, WebP, GIF, HEIC) or a PDF, Word, Excel, PowerPoint, TXT or CSV file.");
  }

  const scan = await scanBuffer(file.buffer);
  if (scan.status === "infected") {
    logger.warn({ detail: scan.detail }, "chat attachment rejected by the malware scanner");
    throw AppError.badRequest("That file was rejected by the virus scanner.");
  }

  const storage = getStorage();
  const key = chatKey(prepared.extension);
  await storage.put(key, prepared.body, { contentType: prepared.mime, visibility: "private" });
  let previewKey = null;
  if (prepared.preview) {
    previewKey = key.replace(/\.[a-z0-9]+$/, ".preview.webp");
    await storage.put(previewKey, prepared.preview, { contentType: "image/webp", visibility: "private" });
  }

  const baseName = safeName(path.basename(String(file.originalname || "file"), path.extname(String(file.originalname || ""))));
  const fileName = `${baseName}.${prepared.extension}`;
  const publicId = ulid();
  await execute(
    `INSERT INTO message_attachments
       (public_id, message_id, conversation_id, file_name, file_url, mime_type, file_size_bytes, storage_key, preview_key,
        width, height, scan_status, uploaded_by_user_id, uploaded_by_guest_id, created_at)
     VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(3))`,
    [
      publicId,
      conversationId,
      fileName,
      `private://${key}`,
      prepared.mime,
      prepared.body.length,
      key,
      previewKey,
      prepared.width ?? null,
      prepared.height ?? null,
      scan.status,
      identity.type === "user" ? identity.userId : null,
      identity.type === "guest" ? identity.guestId : null,
    ]
  );
  return attachmentDto({
    public_id: publicId,
    file_name: fileName,
    mime_type: prepared.mime,
    file_size_bytes: prepared.body.length,
    width: prepared.width,
    height: prepared.height,
    storage_key: key,
    preview_key: previewKey,
  });
}

/** Attaches the sender's own unsent uploads in this conversation to the message just written. */
export async function claimPendingAttachments(identity, conversationId, messageId, attachmentIds, connection) {
  const ids = inClause(attachmentIds.map(String).slice(0, MAX_ATTACHMENTS_PER_MESSAGE));
  if (!ids) return 0;
  const owner = identity.type === "user" ? "uploaded_by_user_id" : "uploaded_by_guest_id";
  const result = await execute(
    `UPDATE message_attachments SET message_id = ?
      WHERE public_id IN ${ids.sql} AND conversation_id = ? AND message_id IS NULL AND ${owner} = ?`,
    [messageId, ...ids.params, conversationId, identity.type === "user" ? identity.userId : identity.guestId],
    connection
  );
  if ((result.affectedRows || 0) !== ids.params.length) {
    throw AppError.badRequest("One of the files is no longer available. Attach it again.");
  }
  return result.affectedRows;
}

/** The row behind an attachment id, with the conversation it belongs to. */
export async function findAttachment(publicId) {
  return queryOne(
    `SELECT a.id, a.public_id, a.message_id, a.conversation_id, a.file_name, a.mime_type, a.storage_key, a.preview_key,
            a.uploaded_by_user_id, a.uploaded_by_guest_id, a.file_url,
            COALESCE(c.public_id, mc.public_id) AS conversation_public_id, m.deleted_at AS message_deleted_at
       FROM message_attachments a
       LEFT JOIN conversations c ON c.id = a.conversation_id
       LEFT JOIN messages m ON m.id = a.message_id
       LEFT JOIN conversations mc ON mc.id = m.conversation_id
      WHERE a.public_id = ? LIMIT 1`,
    [String(publicId)]
  );
}

export async function readAttachmentBytes(row, { preview = false } = {}) {
  const key = preview && row.preview_key ? row.preview_key : row.storage_key;
  return {
    body: await getStorage().get(key, { visibility: "private" }),
    mimeType: preview && row.preview_key ? "image/webp" : row.mime_type,
  };
}

/** Uploads nobody sent within a day. */
export async function sweepPendingAttachments() {
  const rows = await query(
    `SELECT id, storage_key, preview_key FROM message_attachments
      WHERE message_id IS NULL AND storage_key IS NOT NULL AND created_at < DATE_SUB(NOW(3), INTERVAL 1 DAY)
      LIMIT 500`
  );
  const storage = getStorage();
  for (const row of rows) {
    for (const key of [row.storage_key, row.preview_key].filter(Boolean)) {
      await storage.delete(key, { visibility: "private" }).catch(() => {});
    }
    await execute("DELETE FROM message_attachments WHERE id = ?", [row.id]);
  }
  return rows.length;
}
