import { query, queryOne } from "../../db/query.js";
import { CATEGORY_DEFINITIONS } from "../../utils/categories.js";

/**
 * Filter-option sets for the admin list screens.
 *
 * Every admin table renders a row of Select controls above it, and each one
 * reads `result.options.<name>`. Those sets are shared across screens —
 * `countries` alone is read by fourteen views — so they are built once here
 * rather than per endpoint.
 *
 * Each loader returns `[{ id, name }]`, the shape the Selects map over. A few
 * screens read `value`/`label` instead, so both spellings are emitted; the cost
 * is two extra keys per row and it removes a whole class of "the dropdown is
 * empty" bug.
 */

const pair = (id, name) => ({ id, name, value: id, label: name });

/** Locations at one tier, optionally scoped to a parent. */
async function locationTier(level, { parentId = null, limit = 500 } = {}) {
  const rows = await query(
    `SELECT id, name, slug, parent_id
       FROM locations
      WHERE level = ? AND deleted_at IS NULL AND status = 'active'
        ${parentId ? "AND parent_id = ?" : ""}
      ORDER BY active_listing_count DESC, name ASC
      LIMIT ${Number(limit)}`,
    parentId ? [level, parentId] : [level]
  );
  return rows.map((row) => ({ ...pair(String(row.id), row.name), slug: row.slug, parentId: row.parent_id ? String(row.parent_id) : null }));
}

export const countries = () => locationTier("country");
export const states = (parentId) => locationTier("state", { parentId });
export const cities = (parentId) => locationTier("city", { parentId });
export const communities = (parentId) => locationTier("community", { parentId });
export const subCommunities = (parentId) => locationTier("sub_community", { parentId });

/** A flat, mixed-tier location list for screens with a single Location select. */
export async function locations(limit = 300) {
  const rows = await query(
    `SELECT id, name, level FROM locations
      WHERE deleted_at IS NULL AND status = 'active' AND active_listing_count > 0
      ORDER BY active_listing_count DESC LIMIT ${Number(limit)}`
  );
  return rows.map((row) => ({ ...pair(String(row.id), row.name), level: row.level }));
}

export async function packages() {
  const rows = await query("SELECT id, name, code FROM plans WHERE is_active = 1 ORDER BY sort_order ASC");
  return rows.map((row) => ({ ...pair(String(row.id), row.name), code: row.code }));
}

export async function agents(organizationId = null) {
  const rows = await query(
    `SELECT id, public_id, display_name FROM agents
      WHERE deleted_at IS NULL ${organizationId ? "AND organization_id = ?" : ""}
      ORDER BY display_name ASC LIMIT 500`,
    organizationId ? [organizationId] : []
  );
  return rows.map((row) => pair(row.public_id, row.display_name));
}

export async function authors() {
  const rows = await query("SELECT id, public_id, name FROM authors WHERE is_active = 1 ORDER BY name ASC LIMIT 200");
  return rows.map((row) => pair(row.public_id, row.name));
}

/** Editorial taxonomy terms — what the Blog and Media screens call "categories". */
export async function editorialCategories() {
  const rows = await query(
    "SELECT id, name, slug FROM editorial_terms WHERE taxonomy = 'category' ORDER BY name ASC LIMIT 200"
  );
  return rows.map((row) => ({ ...pair(String(row.id), row.name), slug: row.slug }));
}

/** The six marketplace roots, for screens that filter by marketplace category. */
export function marketplaceCategories() {
  return CATEGORY_DEFINITIONS.map((definition) => pair(definition.listingType, definition.label));
}

/** Child categories of one root — "property types", "collections", and so on. */
export async function categoryTypes(rootCategoryId) {
  if (!rootCategoryId) return [];
  const rows = await query(
    `SELECT id, code, name, slug FROM categories
      WHERE root_category_id = ? AND parent_id IS NOT NULL AND deleted_at IS NULL
      ORDER BY sort_order ASC, name ASC LIMIT 200`,
    [rootCategoryId]
  );
  return rows.map((row) => ({ ...pair(row.code || String(row.id), row.name), slug: row.slug }));
}

/**
 * `segment` disambiguates a `kind` two categories share — today only
 * `aircraft_manufacturer` (jets `fixed_wing` vs helicopters `rotorcraft`,
 * `brands.aircraft_segment`, migration 0046). Every other kind has none.
 */
export async function brandsOfKind(kind, segment = null) {
  const rows = await query(
    `SELECT id, name, slug FROM brands
      WHERE kind = ? AND deleted_at IS NULL AND is_active = 1${segment ? " AND aircraft_segment = ?" : ""}
      ORDER BY name ASC LIMIT 400`,
    segment ? [kind, segment] : [kind]
  );
  return rows.map((row) => ({ ...pair(String(row.id), row.name), slug: row.slug }));
}

export async function brandModels(kind, segment = null) {
  const rows = await query(
    `SELECT bm.id, bm.name, bm.slug, bm.brand_id
       FROM brand_models bm JOIN brands b ON b.id = bm.brand_id
      WHERE b.kind = ? AND bm.is_active = 1${segment ? " AND b.aircraft_segment = ?" : ""}
      ORDER BY bm.name ASC LIMIT 600`,
    segment ? [kind, segment] : [kind]
  );
  return rows.map((row) => ({ ...pair(String(row.id), row.name), slug: row.slug, brandId: String(row.brand_id) }));
}

/** Developers are brands of kind `property_developer`; `projects.developer_brand_id` points at them. */
export async function developers() {
  // Valued by slug, because that is what the developments filter compares
  // against and what the public `?developer=` parameter carries. It used to be
  // the numeric brand id, so choosing a developer filtered on an id against a
  // slug column and returned nothing at all.
  const rows = await query(
    `SELECT DISTINCT b.id, b.name, b.slug FROM brands b
       JOIN projects p ON p.developer_brand_id = b.id AND p.deleted_at IS NULL
      WHERE b.deleted_at IS NULL ORDER BY b.name ASC LIMIT 300`
  ).catch(() => []);
  const source = rows.length
    ? rows
    : await query(
        "SELECT id, name, slug FROM brands WHERE kind = 'property_developer' AND deleted_at IS NULL AND is_active = 1 ORDER BY name ASC LIMIT 400"
      ).catch(() => []);
  return source.map((row) => ({ ...pair(row.slug, row.name), id: String(row.id), slug: row.slug }));
}

export async function handoverYears() {
  const rows = await query(
    `SELECT DISTINCT YEAR(handover_date) AS y FROM projects
      WHERE handover_date IS NOT NULL AND deleted_at IS NULL
      ORDER BY y ASC LIMIT 40`
  ).catch(() => []);
  return rows.filter((row) => row.y).map((row) => pair(String(row.y), String(row.y)));
}

/** Distinct non-null values of one column, as an option list. */
export async function distinct(table, column, { where = "", params = [], limit = 100 } = {}) {
  if (!/^[a-z_][a-z0-9_]*$/i.test(table) || !/^[a-z_][a-z0-9_]*$/i.test(column)) {
    throw new TypeError(`unsafe identifier: ${table}.${column}`);
  }
  const rows = await query(
    `SELECT DISTINCT ${column} AS v FROM ${table}
      WHERE ${column} IS NOT NULL AND ${column} <> '' ${where}
      ORDER BY ${column} ASC LIMIT ${Number(limit)}`,
    params
  ).catch(() => []);
  return rows.map((row) => pair(String(row.v), humanise(row.v)));
}

/** A fixed vocabulary, given as codes. */
export const staticOptions = (values) =>
  values.map((value) =>
    typeof value === "string" ? pair(value, humanise(value)) : pair(value.id, value.name)
  );

export function humanise(value) {
  return String(value)
    .replace(/[._-]/g, " ")
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

export async function roleOptions() {
  const rows = await query("SELECT id, code, name FROM roles WHERE scope = 'platform' ORDER BY sort_order ASC");
  return rows.map((row) => ({ ...pair(String(row.id), row.name), code: row.code }));
}

export async function uploaders() {
  const rows = await query(
    `SELECT DISTINCT u.id, u.display_name FROM media_assets m
       JOIN users u ON u.id = m.uploaded_by_user_id
      WHERE m.deleted_at IS NULL ORDER BY u.display_name ASC LIMIT 200`
  ).catch(() => []);
  return rows.map((row) => pair(String(row.id), row.display_name));
}

export async function reportReasons() {
  const rows = await query(
    "SELECT id, code, name FROM report_reasons WHERE is_active = 1 ORDER BY sort_order ASC LIMIT 100"
  ).catch(() => []);
  return rows.map((row) => pair(String(row.id), row.name || humanise(row.code)));
}

export { pair, locationTier };
