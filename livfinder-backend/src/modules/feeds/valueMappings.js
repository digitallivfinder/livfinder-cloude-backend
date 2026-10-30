import { execute, query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { importProviderId } from "../imports/importConnection.js";

/**
 * Mapping a company's own words to LivFinder's (Phase 5): place names and property types that do
 * not match ours exactly, from any feed format (LivFinder's own, Property Finder, Bayut) or the API.
 *
 * Rows live in `feed_value_mappings` under the import provider with no connection, so one admin
 * mapping serves every company. A location is scoped by the place it sits in (`scope_key` is the
 * parent location's id), because "Downtown" means one place inside Dubai and another elsewhere.
 * A value the import cannot match is queued (`is_unmapped = 1`, counted) for an admin to map; the
 * listing fails with a clear reason until then, and goes through on the feed's next run after.
 */

export const MAPPING_TYPES = ["location", "category"];

export const normalizeValue = (value) => String(value ?? "").trim().replace(/\s+/g, " ").toLowerCase().slice(0, 191);

/** The mapped LivFinder id for a value, or null. */
export async function findMapping({ type, value, scope = null }) {
  const providerId = await importProviderId().catch(() => null);
  if (!providerId || !value) return null;
  const row = await queryOne(
    `SELECT internal_id, internal_value FROM feed_value_mappings
      WHERE provider_id = ? AND connection_id IS NULL AND mapping_type = ? AND external_value = ?
        AND scope_key <=> ? AND is_unmapped = 0 AND is_active = 1 AND (internal_id IS NOT NULL OR internal_value IS NOT NULL)
      LIMIT 1`,
    [providerId, type, normalizeValue(value), scope === null ? null : String(scope)]
  );
  return row ? { id: row.internal_id === null ? null : Number(row.internal_id), value: row.internal_value } : null;
}

/** Puts a value the import could not match in the admin's queue, or counts it again. */
export async function recordUnmapped({ type, value, scope = null, label = null }) {
  const providerId = await importProviderId().catch(() => null);
  if (!providerId || !value) return;
  const external = normalizeValue(value);
  const scopeKey = scope === null ? null : String(scope);
  // `connection_id` is NULL, which the unique key cannot match on, so find the row first.
  const existing = await queryOne(
    `SELECT id FROM feed_value_mappings
      WHERE provider_id = ? AND connection_id IS NULL AND mapping_type = ? AND external_value = ? AND scope_key <=> ?
      LIMIT 1`,
    [providerId, type, external, scopeKey]
  );
  if (existing) {
    await execute("UPDATE feed_value_mappings SET seen_count = seen_count + 1, last_seen_at = NOW(3) WHERE id = ?", [existing.id]);
    return;
  }
  await execute(
    `INSERT INTO feed_value_mappings
       (provider_id, connection_id, mapping_type, direction, external_value, external_label, scope_key, is_unmapped, seen_count, last_seen_at)
     VALUES (?, NULL, ?, 'inbound', ?, ?, ?, 1, 1, NOW(3))`,
    [providerId, type, external, String(label || value).slice(0, 255), scopeKey]
  );
}

/* -------------------------------------------------------------------------- */
/* The admin's queue                                                           */
/* -------------------------------------------------------------------------- */

function serialize(row) {
  return {
    id: String(row.id),
    type: row.mapping_type,
    value: row.external_value,
    label: row.external_label,
    scope: row.scope_key,
    scopeName: row.scope_name ?? null,
    mapped: !row.is_unmapped,
    target: row.is_unmapped
      ? null
      : row.mapping_type === "location"
        ? { id: row.target_location_public_id, name: row.target_location_name }
        : { code: row.internal_value, name: row.target_category_name },
    seenCount: Number(row.seen_count) || 0,
    lastSeenAt: row.last_seen_at,
    updatedAt: row.updated_at,
  };
}

export async function listMappings({ status = "unmapped", type = null, page = 1, pageSize = 50 } = {}) {
  const providerId = await importProviderId();
  const conditions = ["m.provider_id = ?", "m.connection_id IS NULL", `m.mapping_type IN (${MAPPING_TYPES.map(() => "?").join(", ")})`, "m.is_active = 1"];
  const params = [providerId, ...MAPPING_TYPES];
  if (status === "unmapped") conditions.push("m.is_unmapped = 1");
  if (status === "mapped") conditions.push("m.is_unmapped = 0");
  if (type) {
    conditions.push("m.mapping_type = ?");
    params.push(type);
  }
  const where = `WHERE ${conditions.join(" AND ")}`;
  const offset = (Math.max(1, page) - 1) * pageSize;
  const [rows, total] = await Promise.all([
    query(
      `SELECT m.*, scope.name AS scope_name,
              target.public_id AS target_location_public_id, target.name AS target_location_name,
              cat.name AS target_category_name
         FROM feed_value_mappings m
         LEFT JOIN locations scope ON m.mapping_type = 'location' AND scope.id = m.scope_key
         LEFT JOIN locations target ON m.mapping_type = 'location' AND target.id = m.internal_id
         LEFT JOIN categories cat ON m.mapping_type = 'category' AND cat.code = m.internal_value AND cat.root_category_id = m.scope_key
         ${where}
        ORDER BY m.is_unmapped DESC, m.seen_count DESC, m.id DESC
        LIMIT ${Number(pageSize)} OFFSET ${offset}`,
      params
    ),
    queryOne(`SELECT COUNT(*) AS n FROM feed_value_mappings m ${where}`, params),
  ]);
  return { rows: rows.map(serialize), total: Number(total.n) };
}

async function loadMapping(id) {
  const providerId = await importProviderId();
  const row = await queryOne("SELECT * FROM feed_value_mappings WHERE id = ? AND provider_id = ? AND connection_id IS NULL", [id, providerId]);
  if (!row || !MAPPING_TYPES.includes(row.mapping_type)) throw AppError.notFound("That mapping was not found.");
  return row;
}

/**
 * What an admin can map a value to. A place name: places inside the one it was sent for, matching
 * `q`. A property type: the types of its category.
 */
export async function mappingCandidates(id, q = "") {
  const row = await loadMapping(id);
  if (row.mapping_type === "category") {
    return query(
      `SELECT code AS id, name, 'category' AS level, name AS label FROM categories
        WHERE root_category_id = ? AND id <> root_category_id AND deleted_at IS NULL ORDER BY sort_order, name`,
      [Number(row.scope_key)]
    );
  }
  const params = [];
  let within = "";
  if (row.scope_key) {
    within = "AND (l.country_id = ? OR l.state_id = ? OR l.city_id = ? OR l.community_id = ? OR l.parent_id = ?)";
    params.push(...Array(5).fill(Number(row.scope_key)));
  }
  const term = String(q || row.external_label || "").trim().slice(0, 80);
  return query(
    `SELECT l.public_id AS id, l.name, l.level,
            CONCAT_WS(', ', l.name, cm.name, ct.name, co.name) AS label
       FROM locations l
       LEFT JOIN locations cm ON cm.id = l.community_id AND cm.id <> l.id
       LEFT JOIN locations ct ON ct.id = l.city_id AND ct.id <> l.id
       LEFT JOIN locations co ON co.id = l.country_id
      WHERE l.deleted_at IS NULL AND l.status = 'active' AND l.level <> 'country' ${within}
        AND (l.name LIKE ? OR l.slug LIKE ?)
      ORDER BY l.active_listing_count DESC, l.depth ASC, l.name ASC
      LIMIT 20`,
    [...params, `%${term}%`, `%${term.toLowerCase().replace(/\s+/g, "-")}%`]
  );
}

/**
 * Saves an admin's mapping. It applies from the company's next push of those listings.
 */
export async function setMapping(id, { locationId = null, categoryCode = null }) {
  const row = await loadMapping(id);
  if (row.mapping_type === "location") {
    const target = await queryOne("SELECT id FROM locations WHERE (public_id = ? OR id = ?) AND deleted_at IS NULL", [
      String(locationId ?? ""),
      /^\d+$/.test(String(locationId ?? "")) ? Number(locationId) : 0,
    ]);
    if (!target) throw AppError.validation("Some information is invalid.", { locationId: "Choose a LivFinder location." });
    await execute("UPDATE feed_value_mappings SET internal_id = ?, internal_value = NULL, is_unmapped = 0 WHERE id = ?", [target.id, row.id]);
  } else {
    const category = await queryOne(
      "SELECT code FROM categories WHERE code = ? AND root_category_id = ? AND deleted_at IS NULL",
      [String(categoryCode ?? ""), Number(row.scope_key)]
    );
    if (!category) throw AppError.validation("Some information is invalid.", { categoryCode: "Choose one of this category's types." });
    await execute("UPDATE feed_value_mappings SET internal_id = NULL, internal_value = ?, is_unmapped = 0 WHERE id = ?", [category.code, row.id]);
  }
  return serialize({ ...(await loadMapping(id)) });
}

/** Drops a value from the queue (a typo the company should fix rather than one to map). */
export async function dismissMapping(id) {
  const row = await loadMapping(id);
  await execute("UPDATE feed_value_mappings SET is_active = 0 WHERE id = ?", [row.id]);
  return true;
}

