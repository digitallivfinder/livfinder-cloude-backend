/**
 * The public Projects filter contract.
 *
 * One place that knows every filter key, its type, and the column it compares
 * against. The repository builds SQL from this table rather than from a long
 * chain of `if (filters.x)`, so a new filter is a row here and an index on the
 * projection — and so the facet endpoint and the search endpoint cannot drift
 * apart about what a key means.
 *
 * Nothing here is a display string. Every value is the vocabulary
 * `project_search` stores, which is the vocabulary the public API accepts.
 */

/** Lifecycle — where the building is. Mirrors `projects.status`. */
export const PROJECT_STATUSES = Object.freeze([
  "announced",
  "presale",
  "under_construction",
  "completed",
  "handed_over",
  "on_hold",
  "cancelled",
]);

/** Sales state — where the sale is. Mirrors `projects.launch_status`. */
export const LAUNCH_STATUSES = Object.freeze(["coming_soon", "upcoming", "launched", "sold_out"]);

export const PROJECT_TYPES = Object.freeze([
  "residential",
  "commercial",
  "mixed_use",
  "hospitality",
  "branded_residence",
  "master_community",
]);

export const OWNERSHIP_TYPES = Object.freeze([
  "freehold",
  "leasehold",
  "commonhold",
  "usufruct",
  "musataha",
  "other",
  "unknown",
]);

export const UNIT_TYPES = Object.freeze([
  "apartment",
  "penthouse",
  "duplex",
  "villa",
  "townhouse",
  "studio",
  "loft",
  "office",
  "retail",
  "warehouse",
  "plot",
  "floor",
  "whole_building",
  "other",
]);

export const AVAILABILITY = Object.freeze(["available", "limited", "sold_out", "coming_soon"]);

export const PAYMENT_PLAN_TYPES = Object.freeze([
  "construction_linked",
  "time_linked",
  "post_handover",
  "cash",
  "custom",
]);

/**
 * `nearing_completion` is offered as a filter but is not a stored status.
 *
 * It is `under_construction` at or above this much completion. Storing it as a
 * seventh lifecycle value would let the two disagree the moment a percentage
 * moved; deriving it means they cannot.
 */
export const NEARING_COMPLETION_THRESHOLD = 80;

/**
 * Multi-select filters: `key` is the public query parameter, `column` the
 * projection column, `values` the accepted vocabulary.
 *
 * `csv` marks a column holding a comma-separated aggregate (`unit_types`,
 * `bedroom_values`, `payment_plan_types`), matched with FIND_IN_SET.
 */
export const MULTI_FILTERS = Object.freeze([
  { key: "projectType", column: "ps.project_type", values: PROJECT_TYPES },
  { key: "launchStatus", column: "ps.launch_status", values: LAUNCH_STATUSES },
  { key: "ownership", column: "ps.ownership_type", values: OWNERSHIP_TYPES },
  { key: "propertyType", column: "ps.unit_types", values: UNIT_TYPES, csv: true },
  { key: "availability", column: "ps.availability", values: AVAILABILITY },
  { key: "paymentPlan", column: "ps.payment_plan_types", values: PAYMENT_PLAN_TYPES, csv: true },
]);

export const SORT_MAP = Object.freeze({
  featured: "ps.is_featured DESC, ps.published_at DESC, ps.project_id DESC",
  // "Newest" is newest *launched*, and it is not a synonym for featured — the
  // real-estate page used to map it onto the featured order, so the control did
  // nothing and said it had.
  newest: "ps.launch_date IS NULL, ps.launch_date DESC, ps.published_at DESC",
  handoverSoonest: "ps.handover_date IS NULL, ps.handover_date ASC",
  handoverLatest: "ps.handover_date IS NULL, ps.handover_date DESC",
  priceAsc: "ps.min_price_base IS NULL, ps.min_price_base ASC",
  priceDesc: "ps.min_price_base IS NULL, ps.min_price_base DESC",
  completion: "ps.completion_percentage IS NULL, ps.completion_percentage DESC",
});

export const DEFAULT_SORT = "featured";

/** Facet columns the public facet endpoint will group on. */
export const FACET_COLUMNS = Object.freeze({
  projectType: { column: "ps.project_type" },
  status: { column: "ps.status" },
  launchStatus: { column: "ps.launch_status" },
  availability: { column: "ps.availability" },
  ownership: { column: "ps.ownership_type" },
  handoverYear: { column: "ps.handover_year" },
  // The public filter is called `handover`; the column it counts is the year.
  // Accepting both spellings means a caller using the filter's own name is not
  // met with "unsupported facet" for a facet that plainly exists.
  handover: { column: "ps.handover_year" },
  developer: { column: "ps.developer_slug", labelColumn: "ps.developer_name" },
  currency: { column: "ps.currency_code" },
  country: { column: "ps.country_id" },
  propertyType: { column: "ps.unit_types", csv: true, values: UNIT_TYPES },
  bedrooms: { column: "ps.bedroom_values", csv: true },
  paymentPlan: { column: "ps.payment_plan_types", csv: true, values: PAYMENT_PLAN_TYPES },
});
