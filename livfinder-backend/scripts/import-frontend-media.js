#!/usr/bin/env node
/**
 * Imports the listing imagery that ships in the frontend's `public/` directory
 * into backend-managed storage, and attaches it to seeded listings that have no
 * real gallery yet.
 *
 * What is imported and what is not
 * --------------------------------
 * Imported: `public/images/properties/*` and `public/images/featured-categories/*`
 * — photographs of assets, which are user content and belong in the media store.
 * Left alone: brand marks, UI icons, fonts, and the decorative background
 * (`right-background.svg`, `realestate-bg.jpeg`). Those are part of the
 * interface, not the catalogue, and stay as static frontend assets.
 *
 * Existing data is preserved
 * --------------------------
 * A listing whose `listing_media` rows already point at a reachable file is
 * skipped. The seed ships `cdn.livfinder.com` URLs that resolve to nothing in
 * development; those are the ones this replaces, and only for the listings it
 * is asked to cover.
 *
 * Idempotent: images are deduplicated by SHA-256, and a listing that already
 * has imported media is not touched on a second run.
 *
 *   node scripts/import-frontend-media.js [--frontend ../frontend] [--limit 200] [--dry-run]
 */
import fs from "node:fs/promises";
import path from "node:path";
import { query, queryOne, queryValue, execute } from "../src/db/query.js";
import { withTransaction } from "../src/db/transaction.js";
import { closePool } from "../src/db/pool.js";
import { storeImage } from "../src/modules/media/media.service.js";
import { attachAssetToListing, syncListingMediaCounters } from "../src/modules/media/listingMedia.service.js";
import { refreshListingSearch } from "../src/modules/listings/listings.repository.js";
import { categoryByRootId } from "../src/utils/categories.js";
import logger from "../src/config/logger.js";

// Which frontend directories map to which marketplace categories.
const SOURCES = [
  { dir: "images/properties", rootCategoryIds: [1], folder: "/listings/real-estate" },
  { dir: "images/featured-categories", rootCategoryIds: [1, 2, 3, 4, 5, 6], folder: "/listings", byName: true },
];

// Files that are interface, not catalogue.
const EXCLUDE = new Set(["right-background.svg", "realestate-bg.jpeg", "floorplan.webp"]);
const IMAGE_EXTENSIONS = new Set([".jpg", ".jpeg", ".png", ".webp", ".avif"]);

// featured-categories/<name>.jpg maps to a root category by file name.
const CATEGORY_BY_FILENAME = {
  "real-estate": 1,
  cars: 2,
  yachts: 3,
  jets: 4,
  helicopters: 5,
  watches: 6,
};

function parseArgs(argv) {
  const args = { frontend: "../frontend", limit: 240, dryRun: false };
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === "--frontend") args.frontend = argv[++index];
    else if (argv[index] === "--limit") args.limit = Number(argv[++index]);
    else if (argv[index] === "--dry-run") args.dryRun = true;
  }
  return args;
}

async function collectFiles(frontendRoot) {
  const collected = [];
  for (const source of SOURCES) {
    const directory = path.resolve(frontendRoot, "public", source.dir);
    let entries;
    try {
      entries = await fs.readdir(directory);
    } catch {
      continue;
    }
    for (const entry of entries.sort()) {
      if (EXCLUDE.has(entry)) continue;
      if (!IMAGE_EXTENSIONS.has(path.extname(entry).toLowerCase())) continue;
      const rootCategoryIds = source.byName
        ? [CATEGORY_BY_FILENAME[path.parse(entry).name]].filter(Boolean)
        : source.rootCategoryIds;
      if (!rootCategoryIds.length) continue;
      collected.push({
        absolutePath: path.join(directory, entry),
        fileName: entry,
        rootCategoryIds,
        folder: source.folder,
      });
    }
  }
  return collected;
}

/** A media row counts as usable when its URL is served by this deployment. */
function isImportedUrl(url) {
  return typeof url === "string" && !url.includes("cdn.livfinder.com");
}

async function listingsNeedingMedia(rootCategoryId, limit) {
  const rows = await query(
    `SELECT l.id, l.public_id, l.reference, l.title, l.root_category_id,
            (SELECT COUNT(*) FROM listing_media lm
              WHERE lm.listing_id = l.id AND lm.url NOT LIKE 'https://cdn.livfinder.com/%') AS imported_count
       FROM listings l
      WHERE l.root_category_id = ? AND l.deleted_at IS NULL
      ORDER BY (l.status = 'active') DESC, l.is_featured DESC, l.id ASC
      LIMIT ${Math.max(1, Math.min(2000, Number(limit) || 100))}`,
    [rootCategoryId]
  );
  return rows.filter((row) => Number(row.imported_count) === 0);
}

async function folderId(pathValue) {
  return queryValue("SELECT id FROM media_folders WHERE path = ? LIMIT 1", [pathValue]);
}

export async function importFrontendMedia({ frontend = "../frontend", limit = 240, dryRun = false } = {}) {
  const frontendRoot = path.resolve(process.cwd(), frontend);
  const files = await collectFiles(frontendRoot);
  if (!files.length) {
    return { uploaded: 0, attached: 0, listingsTouched: 0, files: 0, note: "no importable images found" };
  }

  const summary = { files: files.length, uploaded: 0, deduplicated: 0, attached: 0, listingsTouched: 0, skipped: 0 };
  if (dryRun) {
    return { ...summary, dryRun: true, sample: files.slice(0, 5).map((file) => file.fileName) };
  }

  // 1. Upload each file once. The checksum makes a re-run reuse the stored
  //    object instead of writing a second copy.
  const assetsByCategory = new Map();
  for (const file of files) {
    const buffer = await fs.readFile(file.absolutePath);
    const asset = await storeImage({
      buffer,
      originalFileName: file.fileName,
      accountId: null,
      userId: null,
      scope: "listings/imported",
      altText: null,
      source: "migration",
      folderId: await folderId(file.folder),
    });
    if (asset.deduplicated) summary.deduplicated += 1;
    else summary.uploaded += 1;
    for (const rootCategoryId of file.rootCategoryIds) {
      const list = assetsByCategory.get(rootCategoryId) || [];
      list.push(asset);
      assetsByCategory.set(rootCategoryId, list);
    }
  }

  // 2. Attach them to listings that have no served gallery, round-robin so the
  //    same photograph is not the cover of forty listings in a row.
  for (const [rootCategoryId, assets] of assetsByCategory) {
    if (!assets.length) continue;
    const definition = categoryByRootId(rootCategoryId);
    const targets = await listingsNeedingMedia(rootCategoryId, limit);

    for (const [index, listing] of targets.entries()) {
      const gallery = [
        assets[index % assets.length],
        assets[(index + 1) % assets.length],
        assets[(index + 2) % assets.length],
      ].filter((asset, position, list) => list.findIndex((entry) => entry.id === asset.id) === position);

      await withTransaction(async (connection) => {
        // Remove the unreachable seeded rows for this listing, then attach.
        await execute(
          "DELETE FROM listing_media WHERE listing_id = ? AND url LIKE 'https://cdn.livfinder.com/%'",
          [listing.id],
          connection
        );
        for (const asset of gallery) {
          await attachAssetToListing(
            {
              listingId: listing.id,
              assetId: asset.id,
              altText: `${listing.title} — ${definition?.listingType ?? "listing"} photography`,
            },
            connection
          );
          summary.attached += 1;
        }
        await syncListingMediaCounters(listing.id, connection);
      });

      await refreshListingSearch(listing.id);
      summary.listingsTouched += 1;
    }
  }

  // 3. Category hero imagery, so the homepage tiles resolve too.
  for (const file of files.filter((entry) => entry.folder === "/listings" && CATEGORY_BY_FILENAME[path.parse(entry.fileName).name])) {
    const rootCategoryId = CATEGORY_BY_FILENAME[path.parse(file.fileName).name];
    const asset = (assetsByCategory.get(rootCategoryId) || []).find((entry) => entry.storage_path?.includes(path.parse(file.fileName).name));
    if (!asset) continue;
    await execute("UPDATE categories SET hero_image_url = ? WHERE id = ? AND (hero_image_url IS NULL OR hero_image_url LIKE 'https://cdn.livfinder.com/%')", [asset.url, rootCategoryId]);
  }

  return summary;
}

const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop());
if (isMain) {
  const args = parseArgs(process.argv.slice(2));
  importFrontendMedia(args)
    .then(async (summary) => {
      logger.info(summary, "frontend media import complete");
      await closePool();
      process.exit(0);
    })
    .catch(async (error) => {
      logger.error({ err: error }, "frontend media import failed");
      await closePool();
      process.exit(1);
    });
}
