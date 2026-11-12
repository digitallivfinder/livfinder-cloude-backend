/**
 * Residential / Commercial, as the API defines it over real estate's leaf categories.
 *
 * The category tree has no segment column, so the grouping lives here: one definition that the
 * filter-options menu (which types to offer for a segment) and the search (which listings a
 * segment matches) both read, so the two cannot disagree. A type may belong to both — a plot or a
 * whole building can be either. Every type not named under Commercial is Residential.
 */
export const PROPERTY_SEGMENTS = [
  { value: "residential", label: "Residential" },
  { value: "commercial", label: "Commercial" },
];

/** Leaf categories (slugs) that are commercial. */
export const COMMERCIAL_TYPES = ["offices", "retail", "buildings", "plots"];

/** Commercial types that are also residential. */
export const BOTH_SEGMENT_TYPES = ["buildings", "plots"];

const COMMERCIAL = new Set(COMMERCIAL_TYPES);
const BOTH = new Set(BOTH_SEGMENT_TYPES);
const COMMERCIAL_ONLY = COMMERCIAL_TYPES.filter((slug) => !BOTH.has(slug));

export function isPropertySegment(value) {
  return PROPERTY_SEGMENTS.some((segment) => segment.value === value);
}

export function propertyTypeInSegment(slug, segment) {
  if (!segment) return true;
  if (segment === "commercial") return COMMERCIAL.has(slug);
  if (segment === "residential") return !COMMERCIAL.has(slug) || BOTH.has(slug);
  return false;
}

/**
 * The search condition for a segment, on `listing_search.category_slug`.
 *
 * Commercial is a closed list. Residential is "everything that is not commercial-only", so a new
 * residential type is matched the day it is added; a listing with no category stays residential.
 */
export function segmentCondition(segment, column = "ls.category_slug") {
  if (segment === "commercial") {
    return { sql: `${column} IN (${COMMERCIAL_TYPES.map(() => "?").join(", ")})`, params: [...COMMERCIAL_TYPES] };
  }
  if (segment === "residential") {
    return {
      sql: `(${column} IS NULL OR ${column} NOT IN (${COMMERCIAL_ONLY.map(() => "?").join(", ")}))`,
      params: [...COMMERCIAL_ONLY],
    };
  }
  return null;
}

/**
 * The same two segments over a development's `project_type`. Mixed-use and hospitality
 * developments hold both kinds of space, so they answer either.
 */
export const PROJECT_TYPES_BY_SEGMENT = {
  residential: ["residential", "mixed_use", "branded_residence", "master_community", "hospitality"],
  commercial: ["commercial", "mixed_use", "hospitality"],
};
