#!/usr/bin/env node
/**
 * Moves an environment's uploads from the local storage driver to S3.
 *
 * 1. Copies every file under LOCAL_STORAGE_PATH/public and /private to the bucket under the
 *    same key (public/<key>, private/<key>) through S3StorageAdapter.put(), so content type
 *    and cache-control match a normal upload. An object already in the bucket with the same
 *    size is skipped.
 * 2. Rewrites public media URLs stored in the database — media_assets, renditions and every
 *    denormalised cover/logo/avatar column listed in TARGETS — from the local form
 *    (/media/<key>, <loopback>/media/<key>, <old base>/<key>) to <new base>/<key>, and marks
 *    media_assets.storage_disk = 's3'. private:// values and cdn.livfinder.com URLs are never
 *    touched (see src/utils/s3MediaUrl.js).
 * 3. Flushes the Redis public cache.
 *
 * Dry run by default: reads the disk, the bucket listing and the database, and prints what
 * would change. Nothing is written without --apply. Re-running is safe at any point.
 *
 *   node scripts/migrate-media-to-s3.js [--apply] [--to <new public base>] [--from <old base>]...
 *        [--skip-files] [--skip-db] [--concurrency 8] [--sample 5]
 *
 * --to defaults to STORAGE_PUBLIC_BASE_URL. When that is still the local base (the shell has
 * not been switched to the S3 env block), it is treated as an old base and --to is required.
 * Runbook: docs/storage-s3-migration.md.
 */
import fs from "node:fs/promises";
import path from "node:path";
import env from "../src/config/env.js";
import logger from "../src/config/logger.js";
import { query } from "../src/db/query.js";
import { withTransaction } from "../src/db/transaction.js";
import { closePool } from "../src/db/pool.js";
import { s3MediaUrl, s3MediaUrlDeep } from "../src/utils/s3MediaUrl.js";

// kind: "text" (one URL), "lines" (newline-separated URLs), "json" (URLs anywhere inside).
// Tables or columns that do not exist in this database are skipped.
export const TARGETS = [
  ["media_assets", "url"], ["media_assets", "cdn_url"], ["media_assets", "variants", "json"],
  ["media_renditions", "url"], ["media_renditions", "cdn_url"],
  ["listing_media", "url"], ["listing_media", "thumbnail_url"],
  ["listings", "cover_image_url"],
  ["listing_search", "cover_image_url"], ["listing_search", "agent_photo_url"], ["listing_search", "organization_logo_url"],
  ["listing_revisions", "approved_snapshot", "json"],
  ["projects", "cover_image_url"], ["projects", "brochure_url"], ["projects", "video_url"],
  ["project_search", "cover_image_url"], ["project_search", "developer_logo_url"], ["project_search", "gallery_urls", "lines"],
  ["project_revisions", "approved_snapshot", "json"],
  ["agents", "photo_url"], ["users", "avatar_url"], ["authors", "avatar_url"],
  ["organizations", "logo_url"], ["organizations", "cover_image_url"],
  ["brands", "logo_url"], ["lenders", "logo_url"], ["integration_providers", "logo_url"],
  ["ad_advertisers", "logo_url"], ["ad_creatives", "asset_url"],
  ["buildings", "cover_image_url"], ["categories", "hero_image_url"], ["collections", "cover_image_url"],
  ["editorial_terms", "cover_image_url"], ["location_landing_pages", "hero_image_url"],
  ["posts", "cover_image_url"], ["posts", "og_image_url"],
  ["seo_meta", "og_image_url"], ["seo_meta", "twitter_image_url"], ["seo_page_overrides", "og_image_url"],
  ["sitemap_entries", "images", "json"],
  ["floor_plans", "interactive_svg_url"],
  ["video_assets", "hls_manifest_url"], ["video_assets", "dash_manifest_url"],
  ["video_assets", "thumbnail_sprite_url"], ["video_assets", "thumbnail_vtt_url"],
  ["dev_board_cards", "cover_image_url"], ["dev_board_comments", "image_url"], ["dev_board_settings", "background_image_url"],
  // Normally private://, which is left alone; listed so a stray public URL is not missed.
  ["verification_documents", "file_url"], ["account_type_change_documents", "file_url"],
  ["organization_licenses", "document_url"], ["message_attachments", "file_url"],
].map(([table, column, kind = "text"]) => ({ table, column, kind }));

const CONTENT_TYPES = {
  jpg: "image/jpeg", jpeg: "image/jpeg", png: "image/png", webp: "image/webp", gif: "image/gif",
  avif: "image/avif", heic: "image/heic", svg: "image/svg+xml", pdf: "application/pdf",
  mp4: "video/mp4", webm: "video/webm", m3u8: "application/vnd.apple.mpegurl", vtt: "text/vtt",
  json: "application/json", txt: "text/plain", csv: "text/csv", xml: "application/xml",
};
// Half-finished downloads and OS litter never belong in the bucket.
const SKIP_FILE = (name) => name.startsWith(".") || name.endsWith(".part") || name.endsWith(".tmp");
const BATCH = 500;
const LOOPBACK_HOSTS = new Set(["localhost", "127.0.0.1", "[::1]"]);

export function contentTypeFor(key) {
  return CONTENT_TYPES[path.extname(key).slice(1).toLowerCase()] || "application/octet-stream";
}

function parseArgs(argv) {
  const options = { apply: false, from: [], to: null, skipFiles: false, skipDb: false, concurrency: 8, sample: 5 };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    const next = () => {
      const value = argv[++index];
      if (value === undefined) throw new Error(`${arg} needs a value`);
      return value;
    };
    if (arg === "--apply") options.apply = true;
    else if (arg === "--dry-run") options.apply = false;
    else if (arg === "--from") options.from.push(next());
    else if (arg === "--to") options.to = next();
    else if (arg === "--skip-files") options.skipFiles = true;
    else if (arg === "--skip-db") options.skipDb = true;
    else if (arg === "--concurrency") options.concurrency = Math.max(1, Number(next()) || 8);
    else if (arg === "--sample") options.sample = Math.max(0, Number(next()) || 0);
    else throw new Error(`unknown argument: ${arg}`);
  }
  return options;
}

const trimBase = (value) => String(value || "").replace(/\/+$/, "");
const isLoopbackBase = (value) => {
  try {
    return LOOPBACK_HOSTS.has(new URL(value).hostname);
  } catch {
    return true;
  }
};

function resolveBases(options) {
  const envBase = trimBase(env.STORAGE_PUBLIC_BASE_URL);
  const to = trimBase(options.to || envBase);
  if (!/^https?:\/\//.test(to) || isLoopbackBase(to) || /\/media$/.test(to)) {
    throw new Error(
      `the new public base looks local (${to}). Export the S3 env block (STORAGE_PUBLIC_BASE_URL=https://<bucket>.s3.<region>.amazonaws.com/public) or pass --to.`
    );
  }
  const from = [...new Set([...options.from.map(trimBase), ...(envBase && envBase !== to ? [envBase] : [])])];
  if (from.includes(to)) throw new Error(`--from and --to are the same base: ${to}`);
  return { to, from };
}

const formatBytes = (bytes) => {
  const units = ["B", "KB", "MB", "GB"];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  return `${value.toFixed(unit ? 1 : 0)} ${units[unit]}`;
};

async function walk(root) {
  const files = [];
  async function visit(dir) {
    let entries;
    try {
      entries = await fs.readdir(dir, { withFileTypes: true });
    } catch (error) {
      if (error.code === "ENOENT") return;
      throw error;
    }
    for (const entry of entries) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) await visit(full);
      else if (entry.isFile() && !SKIP_FILE(entry.name)) {
        const stats = await fs.stat(full);
        files.push({ key: path.relative(root, full).split(path.sep).join("/"), full, size: stats.size });
      } else if (entry.isFile()) files.push({ key: path.relative(root, full), full, size: 0, skipped: true });
    }
  }
  await visit(root);
  return files;
}

async function listBucket(adapter, visibility) {
  const { ListObjectsV2Command } = await import("@aws-sdk/client-s3");
  const prefix = `${visibility}/`;
  const sizes = new Map();
  let token;
  do {
    const page = await adapter.client.send(
      new ListObjectsV2Command({ Bucket: adapter.bucket, Prefix: prefix, ContinuationToken: token })
    );
    for (const item of page.Contents ?? []) sizes.set(item.Key.slice(prefix.length), item.Size);
    token = page.NextContinuationToken;
  } while (token);
  return sizes;
}

async function runPool(items, concurrency, worker) {
  let cursor = 0;
  const runners = Array.from({ length: Math.min(concurrency, items.length) }, async () => {
    while (cursor < items.length) {
      const item = items[cursor++];
      await worker(item);
    }
  });
  await Promise.all(runners);
}

async function migrateFiles({ adapter, apply, concurrency, sample }) {
  const root = path.resolve(process.cwd(), env.LOCAL_STORAGE_PATH);
  const report = { root, bucket: adapter?.bucket ?? null, visibilities: {}, publicKeys: new Set() };
  for (const visibility of ["public", "private"]) {
    const all = await walk(path.join(root, visibility));
    const files = all.filter((file) => !file.skipped);
    if (visibility === "public") for (const file of files) report.publicKeys.add(file.key);
    const remote = adapter ? await listBucket(adapter, visibility) : null;
    const plan = { upload: [], replace: [], same: 0 };
    for (const file of files) {
      const existing = remote?.get(file.key);
      if (existing === undefined) plan.upload.push(file);
      else if (existing !== file.size) plan.replace.push(file);
      else plan.same += 1;
    }
    const pending = [...plan.upload, ...plan.replace];
    const stats = {
      files: files.length,
      bytes: files.reduce((sum, file) => sum + file.size, 0),
      ignored: all.filter((file) => file.skipped).map((file) => file.key),
      alreadyInBucket: plan.same,
      toUpload: plan.upload.length,
      toReplace: plan.replace.length,
      bytesToSend: pending.reduce((sum, file) => sum + file.size, 0),
      sample: pending.slice(0, sample).map((file) => `${visibility}/${file.key} (${contentTypeFor(file.key)}, ${formatBytes(file.size)})`),
      uploaded: 0,
      failed: [],
    };
    if (apply && pending.length) {
      let done = 0;
      await runPool(pending, concurrency, async (file) => {
        try {
          const body = await fs.readFile(file.full);
          await adapter.put(file.key, body, { contentType: contentTypeFor(file.key), visibility });
          stats.uploaded += 1;
        } catch (error) {
          stats.failed.push({ key: file.key, error: error.message });
        }
        done += 1;
        if (done % 500 === 0) logger.info({ visibility, done, of: pending.length }, "uploading");
      });
    }
    report.visibilities[visibility] = stats;
  }
  return report;
}

async function describeColumns() {
  const rows = await query(
    `SELECT c.TABLE_NAME AS table_name, c.COLUMN_NAME AS column_name, c.DATA_TYPE AS data_type,
            c.CHARACTER_MAXIMUM_LENGTH AS max_length, c.COLUMN_KEY AS column_key, t.TABLE_TYPE AS table_type
       FROM information_schema.COLUMNS c
       JOIN information_schema.TABLES t ON t.TABLE_SCHEMA = c.TABLE_SCHEMA AND t.TABLE_NAME = c.TABLE_NAME
      WHERE c.TABLE_SCHEMA = DATABASE()
      ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION`,
    []
  );
  const tables = new Map();
  for (const row of rows) {
    if (!tables.has(row.table_name)) tables.set(row.table_name, { type: row.table_type, columns: new Map(), pk: [] });
    const table = tables.get(row.table_name);
    table.columns.set(row.column_name, { type: row.data_type, maxLength: row.max_length == null ? null : Number(row.max_length) });
    if (row.column_key === "PRI") table.pk.push(row.column_name);
  }
  return tables;
}

const quote = (identifier) => `\`${identifier.replace(/`/g, "``")}\``;

function rewriteValue(kind, value, options, maxLength) {
  if (value == null) return { next: value };
  if (kind === "json") {
    const decoded = typeof value === "string" ? JSON.parse(value) : value;
    const rewritten = s3MediaUrlDeep(decoded, options);
    return rewritten === decoded ? { next: value } : { next: JSON.stringify(rewritten), changed: true };
  }
  if (kind === "lines") {
    const lines = String(value).split("\n");
    const rewritten = lines.map((line) => s3MediaUrl(line, options));
    if (rewritten.every((line, index) => line === lines[index])) return { next: value };
    // A projection truncated to its column: drop whole trailing URLs rather than cut one.
    while (maxLength && rewritten.join("\n").length > maxLength && rewritten.length > 1) rewritten.pop();
    return { next: rewritten.join("\n"), changed: true };
  }
  const next = s3MediaUrl(value, options);
  return next === value ? { next: value } : { next, changed: true };
}

// Rows the rewrite might touch: anything mentioning /media/ or an old base.
function candidateFilter(column, kind, legacyBases) {
  const expression = kind === "json" ? `CAST(${quote(column)} AS CHAR)` : quote(column);
  const patterns = ["%/media/%", ...legacyBases.map((base) => `%${base.replace(/[\\%_]/g, "\\$&")}/%`)];
  return { sql: patterns.map(() => `${expression} LIKE ?`).join(" OR "), params: patterns };
}

async function planColumn(target, schema, options, legacyBases, publicKeys) {
  const table = schema.get(target.table);
  const column = table?.columns.get(target.column);
  if (!table || table.type !== "BASE TABLE" || !column) return { ...target, missing: true };
  if (!table.pk.length) return { ...target, error: "table has no primary key" };
  const filter = candidateFilter(target.column, target.kind, legacyBases);
  const rows = await query(
    `SELECT ${table.pk.map(quote).join(", ")}, ${quote(target.column)} AS value
       FROM ${quote(target.table)} WHERE ${filter.sql}`,
    filter.params
  );
  const changes = [];
  const tooLong = [];
  const missingFiles = [];
  for (const row of rows) {
    const { next, changed } = rewriteValue(target.kind, row.value, options, column.maxLength);
    if (!changed) continue;
    if (column.maxLength && next.length > column.maxLength) {
      tooLong.push(row.value);
      continue;
    }
    const original = typeof row.value === "string" ? row.value : JSON.stringify(row.value);
    changes.push({ pk: table.pk.map((name) => row[name]), before: original, after: next });
    if (target.kind === "text") {
      const key = next.slice(options.publicBaseUrl.length + 1);
      let decoded = key;
      try {
        decoded = decodeURIComponent(key);
      } catch {
        // keep the raw key
      }
      if (publicKeys && !publicKeys.has(decoded)) missingFiles.push(decoded);
    }
  }
  return { ...target, pk: table.pk, scanned: rows.length, changes, tooLong, missingFiles };
}

async function applyColumn(plan) {
  const where = plan.pk.map((name) => `${quote(name)} = ?`).join(" AND ");
  const setter = plan.kind === "json" ? "CAST(? AS JSON)" : "?";
  let updated = 0;
  for (let index = 0; index < plan.changes.length; index += BATCH) {
    const batch = plan.changes.slice(index, index + BATCH);
    await withTransaction(async (connection) => {
      for (const change of batch) {
        const result = await query(
          `UPDATE ${quote(plan.table)} SET ${quote(plan.column)} = ${setter} WHERE ${where}`,
          [change.after, ...change.pk],
          connection
        );
        updated += result.affectedRows;
      }
    });
  }
  return updated;
}

// Columns outside TARGETS that still hold local media URLs — reported, never changed.
async function scanLeftovers(schema, legacyBases) {
  const targeted = new Set(TARGETS.map((target) => `${target.table}.${target.column}`));
  const patterns = ["/media/%", "%://localhost%/media/%", "%://127.0.0.1%/media/%", "%://[::1]%/media/%",
    ...legacyBases.map((base) => `%${base.replace(/[\\%_]/g, "\\$&")}/%`)];
  const textTypes = new Set(["char", "varchar", "tinytext", "text", "mediumtext", "longtext", "json"]);
  const found = [];
  for (const [tableName, table] of schema) {
    if (table.type !== "BASE TABLE") continue;
    for (const [columnName, column] of table.columns) {
      if (!textTypes.has(column.type) || targeted.has(`${tableName}.${columnName}`)) continue;
      const expression = column.type === "json" ? `CAST(${quote(columnName)} AS CHAR)` : quote(columnName);
      const [row] = await query(
        `SELECT COUNT(*) AS n FROM ${quote(tableName)} WHERE ${patterns.map(() => `${expression} LIKE ?`).join(" OR ")}`,
        patterns
      );
      if (Number(row.n)) found.push({ column: `${tableName}.${columnName}`, rows: Number(row.n) });
    }
  }
  return found;
}

async function flushPublicCache() {
  if (!env.REDIS_URL) return "REDIS_URL is not set; nothing to flush";
  const { closeCache, connectCache, isCacheReady } = await import("../src/cache/redis.js");
  const { invalidateNow } = await import("../src/cache/invalidation.js");
  const { ALL_TAGS } = await import("../src/cache/cacheTags.js");
  await connectCache();
  if (!isCacheReady()) {
    await closeCache();
    return "redis is not reachable — run `npm run cache:flush` once it is";
  }
  await invalidateNow(ALL_TAGS);
  await closeCache();
  return "public cache invalidated";
}

export async function migrateMediaToS3(options) {
  const { to, from } = resolveBases(options);
  const urlOptions = { publicBaseUrl: to, legacyBaseUrls: from, protectedHosts: [env.MEDIA_LEGACY_CDN_HOST] };
  const mode = options.apply ? "APPLY" : "DRY RUN";
  console.log(`\n== migrate-media-to-s3 (${mode}) ==`);
  console.log(`new public base : ${to}`);
  console.log(`old bases       : ${from.length ? from.join(", ") : "(none)"} + loopback/relative /media/`);

  let adapter = null;
  if (env.STORAGE_BUCKET) {
    const { S3StorageAdapter } = await import("../src/storage/s3Storage.js");
    adapter = new S3StorageAdapter({ publicBaseUrl: to });
  } else if (options.apply && !options.skipFiles) {
    throw new Error("STORAGE_BUCKET is not set; --apply needs the S3 env block (or --skip-files).");
  }
  console.log(`bucket          : ${adapter ? `${adapter.bucket} (${env.STORAGE_REGION ?? "us-east-1"})` : "(not configured — bucket not compared)"}`);

  let files = null;
  if (!options.skipFiles) {
    files = await migrateFiles({ adapter, apply: options.apply, concurrency: options.concurrency, sample: options.sample });
    console.log(`\n-- files under ${files.root} --`);
    for (const [visibility, stats] of Object.entries(files.visibilities)) {
      console.log(
        `${visibility.padEnd(8)} ${String(stats.files).padStart(6)} files  ${formatBytes(stats.bytes).padStart(9)}` +
          `  in bucket: ${stats.alreadyInBucket}  to upload: ${stats.toUpload}  size differs: ${stats.toReplace}` +
          `  (${formatBytes(stats.bytesToSend)} to send)`
      );
      if (stats.ignored.length) console.log(`         ignored: ${stats.ignored.join(", ")}`);
      for (const line of stats.sample) console.log(`         e.g. ${line}`);
      if (options.apply) console.log(`         uploaded: ${stats.uploaded}  failed: ${stats.failed.length}`);
      for (const failure of stats.failed.slice(0, 10)) console.log(`         FAILED ${failure.key}: ${failure.error}`);
    }
  }
  const fileFailures = files ? Object.values(files.visibilities).reduce((sum, stats) => sum + stats.failed.length, 0) : 0;

  let changedRows = 0;
  if (!options.skipDb) {
    const schema = await describeColumns();
    const plans = [];
    for (const target of TARGETS) {
      plans.push(await planColumn(target, schema, urlOptions, from, files?.publicKeys ?? null));
    }
    const [{ n: localAssets }] = await query("SELECT COUNT(*) AS n FROM media_assets WHERE storage_disk = 'local'", []);
    const [{ n: totalAssets }] = await query("SELECT COUNT(*) AS n FROM media_assets", []);

    console.log("\n-- database --");
    console.log(`media_assets: ${totalAssets} rows, ${localAssets} with storage_disk='local' → 's3'`);
    for (const plan of plans) {
      if (plan.missing) continue;
      if (plan.error) {
        console.log(`${`${plan.table}.${plan.column}`.padEnd(44)} SKIPPED: ${plan.error}`);
        continue;
      }
      if (!plan.changes.length && !plan.tooLong.length) continue;
      console.log(
        `${`${plan.table}.${plan.column}`.padEnd(44)} ${String(plan.changes.length).padStart(6)} to rewrite` +
          (plan.tooLong.length ? `, ${plan.tooLong.length} too long for the column (left as is)` : "") +
          (plan.missingFiles.length ? `, ${plan.missingFiles.length} point at a file not on disk` : "")
      );
      for (const change of plan.changes.slice(0, options.sample)) {
        console.log(`    ${change.before.slice(0, 140)}\n  → ${change.after.slice(0, 140)}`);
      }
    }
    const missingFiles = [...new Set(plans.flatMap((plan) => plan.missingFiles ?? []))];
    if (missingFiles.length) {
      console.log(`\n${missingFiles.length} rewritten URLs have no file under storage/public (broken before and after):`);
      for (const key of missingFiles.slice(0, options.sample)) console.log(`    ${key}`);
    }
    const leftovers = await scanLeftovers(schema, from);
    if (leftovers.length) {
      console.log("\nOther columns mentioning local media (not rewritten; logs and history are expected here):");
      for (const leftover of leftovers) console.log(`    ${leftover.column.padEnd(44)} ${leftover.rows} rows`);
    }
    const totalChanges = plans.reduce((sum, plan) => sum + (plan.changes?.length ?? 0), 0);
    console.log(`\ntotal: ${totalChanges} values to rewrite in ${plans.filter((plan) => plan.changes?.length).length} columns`);

    if (options.apply) {
      if (fileFailures) {
        throw new Error(`${fileFailures} files failed to upload; database left unchanged. Re-run to retry.`);
      }
      for (const plan of plans) {
        if (plan.changes?.length) changedRows += await applyColumn(plan);
      }
      const result = await query("UPDATE media_assets SET storage_disk = 's3' WHERE storage_disk = 'local'", []);
      changedRows += result.affectedRows;
      console.log(`updated ${changedRows} rows (including ${result.affectedRows} storage_disk flips)`);
    }
  }

  if (options.apply) {
    console.log(`cache: ${await flushPublicCache()}`);
  } else {
    console.log("\nDry run — nothing was written. Re-run with --apply to copy files and rewrite URLs.");
  }
  if (fileFailures) throw new Error(`${fileFailures} files failed to upload`);
  return { changedRows };
}

const isMain = process.argv[1] && import.meta.url.endsWith(process.argv[1].split("/").pop());
if (isMain) {
  let options;
  try {
    options = parseArgs(process.argv.slice(2));
  } catch (error) {
    console.error(error.message);
    process.exit(2);
  }
  migrateMediaToS3(options)
    .then(() => closePool())
    .then(() => process.exit(0))
    .catch(async (error) => {
      logger.error({ err: error }, "media migration failed");
      console.error(`\nFAILED: ${error.message}`);
      await closePool();
      process.exit(1);
    });
}
