import { query, queryOne, queryValue } from "../../db/query.js";
import { bool, int, isoDate, isoDay, num } from "../../serializers/primitives.js";
import { frontendCategoryId, resolveCategory, CATEGORY_DEFINITIONS } from "../../utils/categories.js";
import { assertCategoryScope, categoryScopeFilter } from "../../middleware/auth.js";

/**
 * Shared helpers for the admin surface.
 *
 * The admin frontend reads its own vocabulary (`reference`, `dateAdded`,
 * `enabledCategories`, `primaryCategory`, `lastActivityAt`…). Serialising to
 * that vocabulary here is what let the admin repository switch from fixtures to
 * live data without touching a single screen.
 */
export function adminPagination({ page = 1, pageSize = 10 } = {}) {
  const safePage = Math.max(1, Number(page) || 1);
  const safeSize = Math.min(200, Math.max(1, Number(pageSize) || 10));
  return { page: safePage, pageSize: safeSize, offset: (safePage - 1) * safeSize };
}

/** Admin lists answer `{ items, total, page, pageSize, totalPages, summary, options }`. */
export function adminList({ items, total, page, pageSize, summary = undefined, options = undefined, extra = {} }) {
  return {
    items,
    total: Number(total || 0),
    page,
    pageSize,
    totalPages: Math.max(1, Math.ceil(Number(total || 0) / pageSize)),
    ...(summary === undefined ? {} : { summary }),
    ...(options === undefined ? {} : { options }),
    ...extra,
  };
}

export function categoryIdsFor(rootCategoryIds = []) {
  return [...new Set(rootCategoryIds.map((id) => frontendCategoryId(id)).filter(Boolean))];
}

export function rootIdFor(categoryValue) {
  return resolveCategory(categoryValue)?.rootId ?? null;
}

export const ADMIN_CATEGORY_SLUGS = CATEGORY_DEFINITIONS.map((definition) => definition.listingType);

/** `LF-2847` style human reference, falling back to the opaque id. */
export function referenceOf(row, prefix = "LF") {
  return row.reference || (row.public_id ? `${prefix}-${String(row.public_id).slice(-6)}` : String(row.id));
}

export async function locationName(id) {
  if (!id) return null;
  return queryValue("SELECT name FROM locations WHERE id = ?", [Number(id)]);
}

/** Counts by an enum column, returned as a plain object keyed by value. */
export async function countsByColumn({ table, column, where = "", params = [] }) {
  const allowedTables = new Set([
    "listings", "organizations", "agents", "leads", "crm_contacts", "reviews", "reports",
    "posts", "media_assets", "projects", "users", "inquiries", "system_logs", "locations",
  ]);
  if (!allowedTables.has(table)) throw new TypeError(`counts not defined for ${table}`);
  if (!/^[a-z_]+$/.test(column)) throw new TypeError(`unsafe column ${column}`);
  const rows = await query(
    `SELECT ${column} AS value, COUNT(*) AS count FROM ${table} ${where} GROUP BY ${column}`,
    params
  );
  const result = { total: 0 };
  for (const row of rows) {
    result[row.value] = Number(row.count);
    result.total += Number(row.count);
  }
  return result;
}

export { bool, int, isoDate, isoDay, num, frontendCategoryId, query, queryOne, queryValue };

/**
 * Category scope for a resource the caller addressed by id.
 *
 * `requireCategoryScope` handles the endpoints where the category is in the URL. This is for the
 * rest: the row has to be read before anyone can say which category it belongs to, so the check
 * lands in the handler rather than the middleware chain. Same outcome either way — a role scoped
 * to cars cannot touch a yacht.
 */
export function assertRootCategoryScope(req, rootCategoryId) {
  if (rootCategoryId == null) return;
  const definition = CATEGORY_DEFINITIONS.find((entry) => String(entry.rootId) === String(rootCategoryId));
  assertCategoryScope(req, definition?.listingType ?? null);
}

/** The root category ids a caller may see, or null when they are unrestricted. */
export function scopedRootCategoryIds(req) {
  const allowed = categoryScopeFilter(req);
  if (!allowed) return null;
  return CATEGORY_DEFINITIONS.filter((entry) => allowed.includes(entry.listingType)).map((entry) => entry.rootId);
}

/**
 * Route guard for endpoints addressed by listing id.
 *
 * The mutation handlers each read their own listing, so threading the request through all of
 * them to check a scope would touch a dozen signatures. One indexed lookup here instead, before
 * the handler runs, and every listing route is covered the same way — including any added later,
 * because the guard sits in the route definition rather than inside the business logic.
 */
export function scopeListingParam(param = "id") {
  return async (req, res, next) => {
    try {
      const identifier = req.params?.[param];
      if (!identifier) return next();
      const row = await queryOne(
        "SELECT root_category_id FROM listings WHERE (public_id = ? OR reference = ?) AND deleted_at IS NULL LIMIT 1",
        [identifier, identifier]
      );
      // A missing listing is the handler's 404 to raise, with its own wording.
      if (row) assertRootCategoryScope(req, row.root_category_id);
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

/** The same, for a development addressed by id. */
export function scopeDevelopmentParam(param = "id") {
  return async (req, res, next) => {
    try {
      const identifier = req.params?.[param];
      if (!identifier) return next();
      const row = await queryOne(
        "SELECT category_id FROM projects WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL LIMIT 1",
        [identifier, identifier]
      );
      if (row) {
        const category = await queryOne("SELECT root_category_id FROM categories WHERE id = ?", [row.category_id]);
        assertRootCategoryScope(req, category?.root_category_id);
      }
      return next();
    } catch (error) {
      return next(error);
    }
  };
}
