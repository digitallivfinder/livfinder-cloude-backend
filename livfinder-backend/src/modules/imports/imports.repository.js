import { execute, query, queryOne, queryValue } from "../../db/query.js";
import { ulid } from "../../utils/ids.js";
import { importProviderId } from "./importConnection.js";
import { publicListingUrl } from "./listingImport.service.js";

/**
 * Import runs and their per-listing results (`feed_imports`, `feed_import_items`), and the
 * provenance of an imported listing. Shared by the partner API, the company's portal screen and
 * the admin screen; every read here is limited to the `livfinder_import` provider.
 */

const IMPORT_TYPE_LABEL = { single: "single", api_push: "bulk", full: "file" };

function parseJson(value, fallback) {
  if (value === null || value === undefined) return fallback;
  if (typeof value === "object") return value;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}

/* -------------------------------------------------------------------------- */
/* Writing                                                                     */
/* -------------------------------------------------------------------------- */

export async function createImportRun({ client, ctx, type, total, status, ip, userAgent, file = null }) {
  const publicId = ulid();
  const result = await execute(
    `INSERT INTO feed_imports
       (public_id, connection_id, provider_id, organization_id, account_id, api_client_id, feed_source_id,
        source_url, source_checksum, source_size_bytes, deletion_mode, max_deletion_percent, source_ip,
        source_user_agent, import_type, entity_type, status, total_rows, started_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, INET6_ATON(?), ?, ?, ?, ?, ?, ?, NOW(3))`,
    [
      publicId,
      ctx.connectionId,
      ctx.providerId,
      client.organizationId,
      client.accountId,
      client.id,
      null,
      null,
      // A pushed file: its fingerprint and size, for the import's record.
      file?.checksum ?? null,
      file?.sizeBytes ?? null,
      "none",
      20,
      ip || null,
      userAgent ? String(userAgent).slice(0, 300) : null,
      type,
      file?.entityType ?? "listing",
      status,
      total,
      status === "running" ? new Date() : null,
    ]
  );
  return { id: result.insertId, publicId };
}

/** `items`: `{ row, externalId, raw, error? }`. An item with `error` is stored as already failed. */
export async function addImportItems(importId, items, { entityType = "listing" } = {}) {
  const ids = [];
  for (const item of items) {
    const failed = Boolean(item.error);
    const result = await execute(
      `INSERT INTO feed_import_items
         (import_id, source_row, external_id, entity_type, operation, status, raw_payload, errors, error_message, processed_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        importId,
        item.row ?? null,
        item.externalId ? String(item.externalId).slice(0, 191) : null,
        entityType,
        failed ? "fail" : "create",
        failed ? "failed" : "queued",
        JSON.stringify(item.raw ?? null),
        failed ? JSON.stringify(errorBody(item.error)) : null,
        failed ? String(item.error.message || "").slice(0, 1000) : null,
        failed ? new Date() : null,
      ]
    );
    ids.push(result.insertId);
  }
  return ids;
}

export function errorBody(error) {
  return {
    code: error?.code || "IMPORT_FAILED",
    message: error?.expose === false ? "Something went wrong on our side." : error?.message || "The listing could not be imported.",
    ...(error?.fields && Object.keys(error.fields).length ? { fields: error.fields } : {}),
  };
}

export async function recordItemSuccess(itemId, importId, outcome) {
  const warnings = outcome.warnings || [];
  await execute(
    `UPDATE feed_import_items
        SET entity_id = ?, operation = ?, status = ?, warnings = ?, errors = NULL, error_message = NULL, processed_at = NOW(3)
      WHERE id = ?`,
    [outcome.listing?.id ?? null, outcome.operation, warnings.length ? "warning" : "success", warnings.length ? JSON.stringify(warnings) : null, itemId]
  );
  const attached = Number(outcome.media?.attached) || 0;
  const failed = outcome.media?.failed?.length || 0;
  if (attached || failed) {
    await execute(
      "UPDATE feed_imports SET media_downloaded = media_downloaded + ?, media_failed = media_failed + ? WHERE id = ?",
      [attached, failed, importId]
    );
  }
}

export async function recordItemFailure(itemId, error) {
  await execute(
    `UPDATE feed_import_items
        SET operation = 'fail', status = 'failed', errors = ?, error_message = ?, processed_at = NOW(3)
      WHERE id = ?`,
    [JSON.stringify(errorBody(error)), String(errorBody(error).message).slice(0, 1000), itemId]
  );
}

/** Recounts a run from its items and closes it once nothing is left queued. */
export async function finalizeImport(importId) {
  const counts = await queryOne(
    `SELECT COUNT(*) AS total,
            SUM(status = 'queued') AS queued,
            SUM(status = 'failed') AS failed,
            SUM(operation = 'create' AND status IN ('success','warning')) AS created,
            SUM(operation = 'update' AND status IN ('success','warning')) AS updated,
            SUM(operation = 'unchanged' AND status IN ('success','warning')) AS unchanged,
            SUM(operation = 'delete' AND status IN ('success','warning')) AS deleted
       FROM feed_import_items WHERE import_id = ?`,
    [importId]
  );
  const total = Number(counts.total) || 0;
  const failed = Number(counts.failed) || 0;
  const queued = Number(counts.queued) || 0;
  const done = queued === 0;
  const status = !done ? "running" : total && failed === total ? "failed" : failed ? "partial" : "completed";
  await execute(
    `UPDATE feed_imports
        SET total_rows = ?, created_count = ?, updated_count = ?, unchanged_count = ?, failed_count = ?, deleted_count = ?,
            status = ?,
            finished_at = ${done ? "NOW(3)" : "NULL"},
            duration_ms = ${done ? "GREATEST(0, TIMESTAMPDIFF(MICROSECOND, COALESCE(started_at, created_at), NOW(3)) DIV 1000)" : "NULL"},
            error_message = ?
      WHERE id = ?`,
    [
      total,
      Number(counts.created) || 0,
      Number(counts.updated) || 0,
      Number(counts.unchanged) || 0,
      failed,
      Number(counts.deleted) || 0,
      status,
      failed ? `${failed} of ${total} listing${total === 1 ? "" : "s"} failed.` : null,
      importId,
    ]
  );
  return status;
}

/* -------------------------------------------------------------------------- */
/* Reading                                                                     */
/* -------------------------------------------------------------------------- */

const IMPORT_COLUMNS = `
  fi.id, fi.public_id, fi.import_type, fi.status, fi.total_rows, fi.created_count, fi.updated_count,
  fi.unchanged_count, fi.failed_count, fi.deleted_count, fi.media_downloaded, fi.media_failed,
  fi.error_message, fi.started_at, fi.finished_at, fi.duration_ms, fi.created_at,
  INET6_NTOA(fi.source_ip) AS source_ip, fi.source_user_agent,
  o.public_id AS organization_public_id, o.name AS organization_name,
  ac.public_id AS api_client_public_id, ac.name AS api_client_name, ac.client_id AS api_client_client_id,
  ac.status AS api_client_status`;

const IMPORT_FROM = `
  FROM feed_imports fi
  LEFT JOIN organizations o ON o.id = fi.organization_id
  LEFT JOIN api_clients ac ON ac.id = fi.api_client_id`;

export function serializeImport(row) {
  return {
    id: row.public_id,
    type: IMPORT_TYPE_LABEL[row.import_type] || row.import_type,
    status: row.status,
    counts: {
      total: Number(row.total_rows) || 0,
      created: Number(row.created_count) || 0,
      updated: Number(row.updated_count) || 0,
      unchanged: Number(row.unchanged_count) || 0,
      withdrawn: Number(row.deleted_count) || 0,
      failed: Number(row.failed_count) || 0,
    },
    images: { downloaded: Number(row.media_downloaded) || 0, failed: Number(row.media_failed) || 0 },
    message: row.error_message,
    source: {
      ip: row.source_ip,
      userAgent: row.source_user_agent,
      apiKey: row.api_client_public_id
        ? { id: row.api_client_public_id, name: row.api_client_name, clientId: row.api_client_client_id, status: row.api_client_status }
        : null,
    },
    company: row.organization_public_id ? { id: row.organization_public_id, name: row.organization_name } : null,
    createdAt: row.created_at,
    startedAt: row.started_at,
    finishedAt: row.finished_at,
    durationMs: row.duration_ms === null ? null : Number(row.duration_ms),
  };
}

export async function listImports({ organizationId = null, accountId = null, organizationPublicId = null, apiClientPublicId = null, status = null, type = null, search = null, page = 1, pageSize = 20 } = {}) {
  const providerId = await importProviderId();
  const conditions = ["fi.provider_id = ?"];
  const params = [providerId];
  if (organizationId) {
    conditions.push("fi.organization_id = ?");
    params.push(organizationId);
  }
  // An individual's runs (no organization) are theirs by account.
  if (accountId) {
    conditions.push("fi.account_id = ?");
    params.push(accountId);
  }
  if (organizationPublicId) {
    conditions.push("o.public_id = ?");
    params.push(organizationPublicId);
  }
  if (apiClientPublicId) {
    conditions.push("ac.public_id = ?");
    params.push(apiClientPublicId);
  }
  if (status) {
    conditions.push("fi.status = ?");
    params.push(status);
  }
  if (type) {
    conditions.push("fi.import_type = ?");
    params.push(type === "bulk" ? "api_push" : type);
  }
  if (search) {
    conditions.push("(fi.public_id = ? OR o.name LIKE ? OR ac.name LIKE ? OR ac.client_id = ?)");
    params.push(search, `%${search}%`, `%${search}%`, search);
  }
  const where = `WHERE ${conditions.join(" AND ")}`;
  const total = Number(await queryValue(`SELECT COUNT(*) ${IMPORT_FROM} ${where}`, params));
  const rows = await query(
    `SELECT ${IMPORT_COLUMNS} ${IMPORT_FROM} ${where} ORDER BY fi.created_at DESC, fi.id DESC LIMIT ? OFFSET ?`,
    [...params, pageSize, (page - 1) * pageSize]
  );
  return { rows: rows.map(serializeImport), total };
}

/** `organizationId` limits the lookup to one company; omit it only for admins. */
export async function getImportRow(publicId, { organizationId = null, accountId = null } = {}) {
  const providerId = await importProviderId();
  const scope = organizationId ? "AND fi.organization_id = ?" : accountId ? "AND fi.account_id = ?" : "";
  return queryOne(
    `SELECT ${IMPORT_COLUMNS} ${IMPORT_FROM}
      WHERE fi.public_id = ? AND fi.provider_id = ? ${scope}
      LIMIT 1`,
    [publicId, providerId, ...(organizationId ? [organizationId] : accountId ? [accountId] : [])]
  );
}

export function serializeItem(row) {
  const errors = parseJson(row.errors, null);
  return {
    id: String(row.id),
    row: row.source_row === null ? null : Number(row.source_row),
    externalId: row.external_id,
    operation: row.operation === "fail" ? null : row.operation === "delete" ? "withdraw" : row.operation,
    status: row.status,
    error: errors,
    warnings: parseJson(row.warnings, []),
    processedAt: row.processed_at,
    listing: row.listing_public_id
      ? {
          id: row.listing_public_id,
          reference: row.listing_reference,
          title: row.listing_title,
          status: row.listing_status,
          publicUrl: publicListingUrl({ status: row.listing_status, canonical_path: row.listing_canonical_path }),
        }
      : null,
  };
}

export async function listImportItems(importId, { status = null, search = null, page = 1, pageSize = 50 } = {}) {
  const conditions = ["fii.import_id = ?"];
  const params = [importId];
  if (status === "failed") conditions.push("fii.status = 'failed'");
  else if (status === "warning") conditions.push("fii.status = 'warning'");
  else if (status === "succeeded") conditions.push("fii.status IN ('success','warning')");
  else if (status === "queued") conditions.push("fii.status = 'queued'");
  if (search) {
    conditions.push("(fii.external_id LIKE ? OR l.reference = ? OR l.title LIKE ?)");
    params.push(`%${search}%`, search, `%${search}%`);
  }
  const from = `FROM feed_import_items fii LEFT JOIN listings l ON l.id = fii.entity_id AND l.deleted_at IS NULL`;
  const where = `WHERE ${conditions.join(" AND ")}`;
  const total = Number(await queryValue(`SELECT COUNT(*) ${from} ${where}`, params));
  const rows = await query(
    `SELECT fii.id, fii.source_row, fii.external_id, fii.operation, fii.status, fii.errors, fii.warnings, fii.processed_at,
            l.public_id AS listing_public_id, l.reference AS listing_reference, l.title AS listing_title,
            l.status AS listing_status, l.canonical_path AS listing_canonical_path
       ${from} ${where}
      ORDER BY fii.source_row IS NULL, fii.source_row ASC, fii.id ASC
      LIMIT ? OFFSET ?`,
    [...params, pageSize, (page - 1) * pageSize]
  );
  return { rows: rows.map(serializeItem), total };
}

/* -------------------------------------------------------------------------- */
/* Provenance                                                                  */
/* -------------------------------------------------------------------------- */

/**
 * Where a listing came from: the channel, the partner's id, the API key and company that sent
 * it, and every import that created or changed it with the caller's IP. `organizationId` limits
 * the answer to a company's own listing.
 */
export async function listingSource(listingRef, { organizationId = null } = {}) {
  const listing = await queryOne(
    `SELECT l.id, l.public_id, l.reference, l.title, l.status, l.source, l.source_reference, l.created_at,
            l.organization_id, o.public_id AS organization_public_id, o.name AS organization_name,
            ac.public_id AS api_client_public_id, ac.name AS api_client_name, ac.client_id AS api_client_client_id,
            ac.status AS api_client_status
       FROM listings l
       LEFT JOIN organizations o ON o.id = l.organization_id
       LEFT JOIN api_clients ac ON ac.id = l.source_api_client_id
      WHERE (l.public_id = ? OR l.reference = ?) AND l.deleted_at IS NULL
        ${organizationId ? "AND l.organization_id = ?" : ""}
      LIMIT 1`,
    organizationId ? [listingRef, listingRef, organizationId] : [listingRef, listingRef]
  );
  if (!listing) return null;

  const providerId = await importProviderId();
  const history = await query(
    `SELECT fii.operation, fii.status, fii.processed_at, fii.external_id, fi.public_id AS import_public_id,
            fi.import_type, INET6_NTOA(fi.source_ip) AS source_ip, fi.source_user_agent,
            ac.public_id AS api_client_public_id, ac.name AS api_client_name, ac.client_id AS api_client_client_id
       FROM feed_import_items fii
       JOIN feed_imports fi ON fi.id = fii.import_id AND fi.provider_id = ?
       LEFT JOIN api_clients ac ON ac.id = fi.api_client_id
      WHERE fii.entity_id = ? AND fii.entity_type = 'listing' AND fii.status IN ('success','warning')
      ORDER BY fii.processed_at DESC, fii.id DESC
      LIMIT 20`,
    [providerId, listing.id]
  );

  return {
    listing: { id: listing.public_id, reference: listing.reference, title: listing.title, status: listing.status, createdAt: listing.created_at },
    company: listing.organization_public_id ? { id: listing.organization_public_id, name: listing.organization_name } : null,
    channel: listing.source,
    externalId: ["api", "import", "feed"].includes(listing.source) ? listing.source_reference : null,
    apiKey: listing.api_client_public_id
      ? { id: listing.api_client_public_id, name: listing.api_client_name, clientId: listing.api_client_client_id, status: listing.api_client_status }
      : null,
    history: history.map((row) => ({
      importId: row.import_public_id,
      importType: IMPORT_TYPE_LABEL[row.import_type] || row.import_type,
      operation: row.operation === "delete" ? "withdraw" : row.operation,
      status: row.status,
      at: row.processed_at,
      externalId: row.external_id,
      sourceIp: row.source_ip,
      userAgent: row.source_user_agent,
      apiKey: row.api_client_public_id ? { id: row.api_client_public_id, name: row.api_client_name, clientId: row.api_client_client_id } : null,
    })),
  };
}

/* -------------------------------------------------------------------------- */
/* API keys, for admins                                                        */
/* -------------------------------------------------------------------------- */

export function serializeApiClient(row) {
  return {
    id: row.public_id,
    name: row.name,
    clientId: row.client_id,
    secretHint: row.secret_hint ? `••••${row.secret_hint}` : null,
    status: row.status,
    scopes: parseJson(row.scopes, []),
    allowedIps: parseJson(row.allowed_ips, []),
    rateLimitPerMinute: Number(row.rate_limit_per_minute) || null,
    lastUsedAt: row.last_used_at,
    expiresAt: row.expires_at,
    createdAt: row.created_at,
    revokedAt: row.revoked_at,
    company: row.organization_public_id ? { id: row.organization_public_id, name: row.organization_name } : null,
    createdBy: row.creator_email ? { name: row.creator_name, email: row.creator_email } : null,
    importCount: row.import_count === undefined ? undefined : Number(row.import_count) || 0,
  };
}

export async function listApiClients({ organizationPublicId = null, status = null, search = null, page = 1, pageSize = 20 } = {}) {
  const conditions = ["ac.organization_id IS NOT NULL"];
  const params = [];
  if (organizationPublicId) {
    conditions.push("o.public_id = ?");
    params.push(organizationPublicId);
  }
  if (status) {
    conditions.push("ac.status = ?");
    params.push(status);
  }
  if (search) {
    conditions.push("(ac.name LIKE ? OR ac.client_id = ? OR o.name LIKE ?)");
    params.push(`%${search}%`, search, `%${search}%`);
  }
  const from = `FROM api_clients ac
    JOIN organizations o ON o.id = ac.organization_id
    LEFT JOIN users u ON u.id = ac.created_by_user_id`;
  const where = `WHERE ${conditions.join(" AND ")}`;
  const total = Number(await queryValue(`SELECT COUNT(*) ${from} ${where}`, params));
  const rows = await query(
    `SELECT ac.*, o.public_id AS organization_public_id, o.name AS organization_name,
            u.display_name AS creator_name, u.email AS creator_email,
            (SELECT COUNT(*) FROM feed_imports fi WHERE fi.api_client_id = ac.id) AS import_count
       ${from} ${where}
      ORDER BY ac.status = 'active' DESC, ac.last_used_at IS NULL, ac.last_used_at DESC, ac.created_at DESC
      LIMIT ? OFFSET ?`,
    [...params, pageSize, (page - 1) * pageSize]
  );
  return { rows: rows.map(serializeApiClient), total };
}

export async function getApiClientRow(publicId) {
  return queryOne(
    `SELECT ac.*, o.public_id AS organization_public_id, o.name AS organization_name
       FROM api_clients ac JOIN organizations o ON o.id = ac.organization_id
      WHERE ac.public_id = ? LIMIT 1`,
    [publicId]
  );
}
