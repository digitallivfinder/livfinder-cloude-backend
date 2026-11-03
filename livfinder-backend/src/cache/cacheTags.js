/**
 * Which slice of public data a write touches, read off the SQL statement itself.
 *
 * Every write in the API goes through db/query.js, so classifying the statement there catches
 * all of them (portal, admin, partner pushes, imports, the maintenance jobs) without each
 * service having to remember to invalidate. A tag is coarse on purpose: a listing write
 * invalidates every cached response that reads listings. Writes are rare next to reads on a
 * marketplace, and coarse tags cannot miss a dependent page the way per-record keys can.
 */

export const TAGS = Object.freeze({
  listings: "listings",
  organizations: "organizations",
  projects: "projects",
  editorial: "editorial",
  locations: "locations",
  taxonomy: "taxonomy",
  // Bumped once per API start, so a response shape changed by a deploy is never served from
  // entries the previous build wrote.
  deploy: "deploy",
});

export const ALL_TAGS = Object.freeze(Object.values(TAGS));

/**
 * Tables written on every public visit or that no public response reads: they must never
 * invalidate the cache, or a busy site would flush it on each page view. Checked first.
 */
const IGNORED = [
  /_daily_stats$/,
  /_daily$/,
  /^analytics_/,
  /^search_(queries|result_events|daily_stats|query_daily_stats|zero_result_queries|experiment_exposures|index_queue)$/,
  /^(user_sessions|web_sessions|audit_logs|system_logs|api_request_logs|api_usage_daily|rate_limit_counters|idempotency_keys)$/,
  /^(notifications|notification_deliveries|outbox_events|jobs|job_runs|queue_messages|dead_letter_messages|distributed_locks)$/,
  /^(media_usage_daily|media_processing_jobs|video_transcode_jobs|upload_sessions|upload_parts)$/,
  /^(listing_revisions|project_revisions|listing_status_history|listing_price_history)$/,
];

const RULES = [
  [TAGS.listings, /^(listings|listing_.+|featured_placements|promotion_purchases|media_.+|floor_plans|floor_plan_rooms|virtual_tours|tour_.+|video_assets|property_units|search_.+)$/],
  [TAGS.organizations, /^(organizations|organization_.+|agents|agent_.+|reviews|review_responses|accounts|account_category_access|account_members|users|subscriptions)$/],
  [TAGS.projects, /^(projects|project_.+|buildings|building_floors)$/],
  [TAGS.editorial, /^(posts|post_.+|authors|editorial_.+|pages|page_translations|faqs|kb_.+)$/],
  [TAGS.locations, /^(locations|location_.+)$/],
  [
    TAGS.taxonomy,
    /^(categories|category_.+|attributes|attribute_.+|features|feature_groups|feature_translations|brands|brand_models|purposes|currencies|fx_rates|fx_rates_latest|measurement_units|languages|settings|navigation_menus|menu_items|redirects|robots_rules|seo_.+|sitemap_.+|slug_history|structured_data_.+|facet_indexation_rules)$/,
  ],
];

/** Stored procedures that rebuild public projections. */
const PROCEDURES = {
  sp_refresh_listing_search: [TAGS.listings],
  sp_listings_within_radius: [],
  sp_rebuild_spatial_points: [TAGS.listings, TAGS.locations],
  sp_refresh_project_search: [TAGS.projects],
  sp_rebuild_project_canonical_path: [TAGS.projects],
  sp_location_rebuild_tree: [TAGS.locations],
  sp_location_refresh_counts: [TAGS.locations],
};

export function tagsForTable(table) {
  const name = String(table || "").toLowerCase();
  if (!name || IGNORED.some((pattern) => pattern.test(name))) return [];
  return RULES.filter(([, pattern]) => pattern.test(name)).map(([tag]) => tag);
}

export function tagsForProcedure(name) {
  // An unknown procedure may touch anything public.
  return PROCEDURES[String(name).toLowerCase()] ?? ALL_TAGS.filter((tag) => tag !== TAGS.deploy);
}

const IDENT = "`?(?:[a-z0-9_]+`?\\.)?`?([a-z0-9_]+)`?";

function stripComments(sql) {
  return sql.replace(/\/\*[\s\S]*?\*\//g, " ").replace(/--[^\n]*/g, " ").trim();
}

/**
 * The tables a statement writes, or [] for a read. Multi-table UPDATE and DELETE list every
 * table they join, which can over-invalidate but never under-invalidates.
 */
export function tablesWritten(sql) {
  const text = stripComments(String(sql || ""));
  const verb = text.slice(0, 8).toUpperCase();

  if (verb.startsWith("INSERT") || verb.startsWith("REPLACE")) {
    const match = new RegExp(`^(?:insert|replace)\\s+(?:(?:low_priority|delayed|high_priority|ignore)\\s+)*(?:into\\s+)?${IDENT}`, "i").exec(text);
    return match ? [match[1].toLowerCase()] : [];
  }

  let head = null;
  if (verb.startsWith("UPDATE")) head = text.slice(6).split(/\bset\b/i)[0];
  else if (verb.startsWith("DELETE")) head = (text.split(/\bfrom\b/i)[1] || "").split(/\b(?:where|order\s+by|limit)\b/i)[0];
  else if (/^(truncate|alter|drop)\b/i.test(text)) head = text.replace(/^(truncate|alter|drop)\s+table\s+/i, "");
  if (head === null) return [];

  const tables = new Set();
  const pattern = new RegExp(`(?:^|,|\\bjoin\\b)\\s*(?:low_priority\\s+|ignore\\s+)*\\(?\\s*${IDENT}`, "gi");
  for (const match of head.trim().matchAll(pattern)) tables.add(match[1].toLowerCase());
  return [...tables];
}

export function tagsForStatement(sql) {
  const tags = new Set();
  for (const table of tablesWritten(sql)) for (const tag of tagsForTable(table)) tags.add(tag);
  return [...tags];
}
