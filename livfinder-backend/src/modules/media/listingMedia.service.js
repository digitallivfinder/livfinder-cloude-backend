import { query, queryOne, queryValue, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { getStorage } from "../../config/storage.js";
import { listRenditions, softDeleteAsset, thumbnailFrom } from "./media.service.js";
import { refreshListingSearch } from "../listings/listings.repository.js";
import env from "../../config/env.js";

/**
 * The gallery is `listing_media` rows ordered by `sort_order`, with exactly one
 * `is_cover`. Every mutation here re-derives the listing's denormalised
 * `cover_image_url` and `image_count` and refreshes the search projection, so a
 * reordered gallery is visible on the results page too.
 */
export async function listListingMedia(listingId, { includePrivate = false } = {}) {
  const rows = await query(
    `SELECT lm.id, lm.media_asset_id, lm.media_type, lm.url, lm.thumbnail_url, lm.alt_text,
            lm.caption, lm.tag, lm.sort_order, lm.is_cover, lm.is_public, lm.created_at,
            ma.public_id, ma.width, ma.height, ma.file_size_bytes, ma.mime_type
       FROM listing_media lm
       LEFT JOIN media_assets ma ON ma.id = lm.media_asset_id
      WHERE lm.listing_id = ?${includePrivate ? "" : " AND lm.is_public = 1"}
      ORDER BY lm.is_cover DESC, lm.sort_order ASC, lm.id ASC`,
    [Number(listingId)]
  );
  return rows.map(serializeListingMediaRow);
}

export function serializeListingMediaRow(row) {
  return {
    id: String(row.id),
    mediaId: String(row.id),
    assetId: row.public_id || (row.media_asset_id ? String(row.media_asset_id) : null),
    mediaType: row.media_type,
    url: row.url,
    thumbnailUrl: row.thumbnail_url || row.url,
    alt: row.alt_text || "",
    altText: row.alt_text || "",
    caption: row.caption || null,
    tag: row.tag || null,
    sortOrder: Number(row.sort_order || 0),
    isCover: row.is_cover === 1,
    isPublic: row.is_public === 1,
    width: row.width === null || row.width === undefined ? null : Number(row.width),
    height: row.height === null || row.height === undefined ? null : Number(row.height),
    sizeBytes: row.file_size_bytes === null || row.file_size_bytes === undefined ? null : Number(row.file_size_bytes),
    mimeType: row.mime_type || null,
  };
}

export async function attachAssetToListing(
  {
    listingId,
    assetId,
    mediaType = "image",
    altText = null,
    caption = null,
    tag = null,
    isCover = null,
    promoteOverLegacy = false,
  },
  executor
) {
  const asset = await queryOne(
    "SELECT id, url, public_id FROM media_assets WHERE id = ? AND deleted_at IS NULL",
    [Number(assetId)],
    executor
  );
  if (!asset) throw AppError.badRequest("That media item no longer exists.");

  const renditions = await listRenditions(asset.id);
  const nextSort = Number(
    (await queryValue(
      "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM listing_media WHERE listing_id = ?",
      [Number(listingId)],
      executor
    )) || 0
  );
  const existingCount = Number(
    (await queryValue("SELECT COUNT(*) FROM listing_media WHERE listing_id = ?", [Number(listingId)], executor)) || 0
  );
  let shouldBeCover = isCover === true || (isCover === null && existingCount === 0);
  // Seed rows make existingCount nonzero even before the owner uploads any photographs.
  // In that case the first actual upload used to leave the seeded cover in place forever.
  // An explicit choice or an existing real cover must still win.
  if (isCover === null && existingCount > 0 && mediaType === "image" && promoteOverLegacy) {
    const current = await queryOne(
      `SELECT url FROM listing_media
        WHERE listing_id = ? AND media_type = 'image' AND is_public = 1
        ORDER BY is_cover DESC, sort_order ASC, id ASC LIMIT 1`,
      [Number(listingId)],
      executor
    );
    let seeded = false;
    try {
      const url = new URL(current?.url);
      seeded = ["http:", "https:"].includes(url.protocol) && url.hostname === env.MEDIA_LEGACY_CDN_HOST;
    } catch { /* A relative URL is not a legacy CDN URL. */ }
    shouldBeCover = !current || seeded;
  }

  if (shouldBeCover) {
    await execute("UPDATE listing_media SET is_cover = 0 WHERE listing_id = ?", [Number(listingId)], executor);
  }

  const result = await execute(
    `INSERT INTO listing_media
       (listing_id, media_asset_id, media_type, url, thumbnail_url, alt_text, caption, tag,
        sort_order, is_cover, is_public, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW(3))`,
    [
      Number(listingId),
      asset.id,
      mediaType,
      asset.url,
      thumbnailFrom(renditions, asset.url),
      altText,
      caption,
      tag,
      nextSort,
      shouldBeCover ? 1 : 0,
    ],
    executor
  );

  await execute(
    "UPDATE media_assets SET reference_count = reference_count + 1, last_referenced_at = NOW(3) WHERE id = ?",
    [asset.id],
    executor
  );

  return result.insertId;
}

export async function syncListingMediaCounters(listingId, executor) {
  const cover = await queryOne(
    `SELECT url, alt_text FROM listing_media
      WHERE listing_id = ? AND media_type = 'image' AND is_public = 1
      ORDER BY is_cover DESC, sort_order ASC, id ASC LIMIT 1`,
    [Number(listingId)],
    executor
  );
  await execute(
    `UPDATE listings l
        SET l.cover_image_url = ?,
            l.cover_image_alt = ?,
            l.image_count = (SELECT COUNT(*) FROM listing_media m
                              WHERE m.listing_id = l.id AND m.media_type = 'image' AND m.is_public = 1),
            l.video_count = (SELECT COUNT(*) FROM listing_media m
                              WHERE m.listing_id = l.id AND m.media_type = 'video'),
            l.has_floor_plan = EXISTS (SELECT 1 FROM listing_media m
                              WHERE m.listing_id = l.id AND m.media_type = 'floor_plan'),
            l.has_virtual_tour = EXISTS (SELECT 1 FROM listing_media m
                              WHERE m.listing_id = l.id AND m.media_type = 'virtual_tour'),
            l.has_brochure = EXISTS (SELECT 1 FROM listing_media m
                              WHERE m.listing_id = l.id AND m.media_type = 'document')
      WHERE l.id = ?`,
    [cover?.url ?? null, cover?.alt_text ?? null, Number(listingId)],
    executor
  );
}

export async function reorderListingMedia({ listingId, orderedIds }) {
  await withTransaction(async (connection) => {
    const rows = await query(
      "SELECT id FROM listing_media WHERE listing_id = ?",
      [Number(listingId)],
      connection
    );
    const owned = new Set(rows.map((row) => String(row.id)));
    const requested = orderedIds.map(String);
    // Reordering may not add, drop, or borrow an item from another listing.
    if (requested.length !== owned.size || requested.some((id) => !owned.has(id))) {
      throw AppError.badRequest("The gallery order does not match this listing's media.");
    }
    for (const [index, id] of requested.entries()) {
      await execute(
        "UPDATE listing_media SET sort_order = ?, is_cover = ? WHERE id = ? AND listing_id = ?",
        [index, index === 0 ? 1 : 0, Number(id), Number(listingId)],
        connection
      );
    }
    await syncListingMediaCounters(listingId, connection);
  });
  await refreshListingSearch(Number(listingId));
  return listListingMedia(listingId);
}

export async function updateListingMediaItem({ listingId, mediaId, altText, caption, tag, isCover }) {
  await withTransaction(async (connection) => {
    const row = await queryOne(
      "SELECT id FROM listing_media WHERE id = ? AND listing_id = ?",
      [Number(mediaId), Number(listingId)],
      connection
    );
    if (!row) throw AppError.notFound("That gallery item was not found.");

    if (isCover === true) {
      await execute("UPDATE listing_media SET is_cover = 0 WHERE listing_id = ?", [Number(listingId)], connection);
    }
    await execute(
      `UPDATE listing_media
          SET alt_text = COALESCE(?, alt_text),
              caption  = COALESCE(?, caption),
              tag      = COALESCE(?, tag),
              is_cover = COALESCE(?, is_cover)
        WHERE id = ? AND listing_id = ?`,
      [
        altText ?? null,
        caption ?? null,
        tag ?? null,
        isCover === undefined ? null : isCover ? 1 : 0,
        Number(mediaId),
        Number(listingId),
      ],
      connection
    );
    await syncListingMediaCounters(listingId, connection);
  });
  await refreshListingSearch(Number(listingId));
  return listListingMedia(listingId);
}

export async function removeListingMedia({ listingId, mediaId }) {
  // Captured inside the transaction: after the DELETE the association is gone,
  // so the asset id has to be read before the row is removed.
  let assetId = null;
  await withTransaction(async (connection) => {
    const row = await queryOne(
      "SELECT id, media_asset_id, is_cover FROM listing_media WHERE id = ? AND listing_id = ?",
      [Number(mediaId), Number(listingId)],
      connection
    );
    if (!row) throw AppError.notFound("That gallery item was not found.");
    assetId = row.media_asset_id;

    await execute("DELETE FROM listing_media WHERE id = ?", [row.id], connection);

    // Close the gap left in sort_order so the next reorder is not sparse.
    const remaining = await query(
      "SELECT id FROM listing_media WHERE listing_id = ? ORDER BY is_cover DESC, sort_order ASC, id ASC",
      [Number(listingId)],
      connection
    );
    for (const [index, item] of remaining.entries()) {
      await execute(
        "UPDATE listing_media SET sort_order = ?, is_cover = ? WHERE id = ?",
        [index, index === 0 ? 1 : 0, item.id],
        connection
      );
    }
    await syncListingMediaCounters(listingId, connection);
  });

  if (assetId) await softDeleteAsset(assetId);
  await refreshListingSearch(Number(listingId));
  return listListingMedia(listingId);
}

export { getStorage };
