import { query } from "../../db/query.js";
import { CATEGORY_DEFINITIONS } from "../../utils/categories.js";

/**
 * There is one permission vocabulary now.
 *
 * This file used to translate between two: 26 coarse database codes that the server enforced,
 * and ~141 granular ids the admin frontend drew checkboxes from. The translation is what made
 * the Role Access matrix lie — ticking "Cars → Edit" resolved back to a plain `listings.edit`,
 * so the role could edit every category.
 *
 * Migration 0032 collapsed both into `<domain>.<action>`, with the category moved out of the key
 * and onto the grant as a scope. The frontend now speaks the same codes the server enforces, so
 * nothing needs mapping and this module is a thin pass-through: it exists to expand a super
 * admin to the full set and to answer "what codes are there" without every caller doing its own
 * query.
 */

const CATEGORY_TYPES = CATEGORY_DEFINITIONS.map((definition) => definition.listingType);
const LOCATION_LEVELS = ["country", "state", "city", "community", "subCommunity"];

/**
 * The catalogue, cached for the process.
 *
 * Permissions change only by migration, so a cache is safe and saves a query on every session
 * resolve. `refreshPermissionUniverse()` exists for the test suite, which does change them.
 */
let universe = null;

export async function loadPermissionUniverse() {
  if (universe) return universe;
  const rows = await query("SELECT code FROM permissions ORDER BY code");
  universe = rows.map((row) => row.code);
  return universe;
}

export function refreshPermissionUniverse() {
  universe = null;
}

/** Synchronous view of the cache, for callers that cannot await. Empty until first load. */
export function adminPermissionUniverse() {
  return universe ?? [];
}

/**
 * The codes a caller holds, as the frontend should see them.
 *
 * A super admin holds everything — materialised rather than special-cased in the UI, so the
 * Role Access matrix and the nav both render from one list and cannot disagree about it.
 */
export function toAdminPermissions(dbCodes, { isSuperAdmin = false } = {}) {
  if (isSuperAdmin && universe?.length) return [...universe];
  return [...new Set(dbCodes)].sort();
}

export { CATEGORY_TYPES, LOCATION_LEVELS };
