/**
 * Residential / Commercial.
 *
 * A real-estate listing stores its own segment (`listings.property_segment`, copied into
 * `listing_search` by the projection), chosen before its property type. Each property type says
 * which segment it belongs to (`categories.property_segment`: residential, commercial, or both for
 * Plot and Whole Building), and the types offered follow the chosen segment. Both lists are read
 * from the database (migration 0077); nothing here is a list of types.
 */

/** Mirrors the `listings.property_segment` ENUM; used to validate input, never to build menus. */
export const PROPERTY_SEGMENT_VALUES = ["residential", "commercial"];

export function isPropertySegment(value) {
  return PROPERTY_SEGMENT_VALUES.includes(value);
}

/** Accepts "Residential", "commercial", "R", "C" (feeds and CSVs spell it many ways). */
export function normalizeSegment(value) {
  const text = String(value ?? "").trim().toLowerCase();
  if (!text) return null;
  if (text === "r" || text.startsWith("resid")) return "residential";
  if (text === "c" || text.startsWith("commer")) return "commercial";
  return text;
}

/** Whether a property type (its `categories.property_segment`) may be listed under `segment`. */
export function typeFitsSegment(typeSegment, segment) {
  return !typeSegment || typeSegment === "both" || typeSegment === segment;
}

/** The search condition for a segment, on the projection's stored copy. */
export function segmentCondition(segment, column = "ls.property_segment") {
  if (!isPropertySegment(segment)) return null;
  return { sql: `${column} = ?`, params: [segment] };
}

/**
 * The same two segments over a development's `project_type`. Mixed-use and hospitality
 * developments hold both kinds of space, so they answer either.
 */
export const PROJECT_TYPES_BY_SEGMENT = {
  residential: ["residential", "mixed_use", "branded_residence", "master_community", "hospitality"],
  commercial: ["commercial", "mixed_use", "hospitality"],
};
