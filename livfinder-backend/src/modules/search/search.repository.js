import { query, queryValue } from "../../db/query.js";
import { resolveLocation } from "../locations/locations.repository.js";
import { normalizeSearchInput, SORT_MAP, RANGE_FILTERS, FACET_FILTERS, DETAIL_FILTERS } from "./searchFilters.js";
import { serializeListingCard } from "../../serializers/listing.js";

/**
 * Reads exclusively from `listing_search`, the maintained flat projection.
 * A result page is an indexed range scan over one table rather than a
 * seven-table join, and the projection only ever contains rows that pass
 * `v_public_listings` — publication, moderation and expiry are enforced by the
 * procedure that fills it, not re-derived per request.
 */
const CARD_COLUMNS = `
  ls.listing_id, ls.public_id, ls.reference, ls.root_category_id, ls.category_id,
  ls.category_slug, ls.purpose_slug, ls.title, ls.slug, ls.canonical_path,
  ls.cover_image_url, ls.image_count, ls.price, ls.currency_code, ls.price_base,
  ls.price_period, ls.location_label, ls.latitude, ls.longitude,
  ls.organization_id, ls.organization_name, ls.organization_logo_url,
  ls.agent_id, ls.agent_name, ls.agent_slug, ls.agent_photo_url,
  ls.is_featured, ls.is_premium, ls.is_verified, ls.is_exclusive, ls.has_virtual_tour,
  ls.spec_a, ls.spec_b, ls.spec_c, ls.spec_d, ls.spec_e, ls.spec_f, ls.spec_labels,
  ls.brand_id, ls.brand_model_id, ls.project_id, ls.quality_score, ls.published_at,
  ls.source_updated_at,
  co.slug AS country_slug, co.name AS country_name,
  st.slug AS state_slug,
  ct.slug AS city_slug,   ct.name AS city_name,
  cm.slug AS community_slug,
  org.slug AS organization_slug,
  br.slug AS brand_slug,  br.name AS brand_name,
  bm.slug AS brand_model_slug, bm.name AS brand_model_name`;

const CARD_JOINS = `
  LEFT JOIN locations co ON co.id = ls.country_id
  LEFT JOIN locations st ON st.id = ls.state_id
  LEFT JOIN locations ct ON ct.id = ls.city_id
  LEFT JOIN locations cm ON cm.id = ls.community_id
  LEFT JOIN organizations org ON org.id = ls.organization_id
  LEFT JOIN brands br ON br.id = ls.brand_id
  LEFT JOIN brand_models bm ON bm.id = ls.brand_model_id`;

async function locationConditions(filters, conditions, params) {
  // Resolve the deepest supplied level and filter on that one column: the
  // projection carries every ancestor id, so a community filter needs no join.
  const levels = [
    ["subCommunity", "subcommunity", "ls.sub_community_id"],
    ["community", "community", "ls.community_id"],
    ["city", "city", "ls.city_id"],
    ["state", "state", "ls.state_id"],
    ["country", "country", "ls.country_id"],
  ];
  const applied = [];
  for (const [key, type, column] of levels) {
    if (!filters[key]) continue;
    const row = await resolveLocation(filters[key], { type });
    if (!row) return { unresolved: key };
    conditions.push(`${column} = ?`);
    params.push(row.id);
    applied.push({ level: type, row });
  }

  // The multi-select `location` control sends opaque entity ids that may be at
  // any level. They are OR-ed together across whichever column each resolves to.
  const multi = (filters.locations || []).filter(
    (value) => !applied.some((entry) => String(entry.row.id) === String(value).split(":")[1])
  );
  const seen = new Set(applied.map((entry) => String(entry.row.id)));
  const clauses = [];
  for (const value of multi) {
    const row = await resolveLocation(value);
    if (!row || seen.has(String(row.id))) continue;
    seen.add(String(row.id));
    const column =
      row.level === "country" ? "ls.country_id"
      : row.level === "state" ? "ls.state_id"
      : row.level === "city" ? "ls.city_id"
      : row.level === "sub_community" ? "ls.sub_community_id"
      : "ls.community_id";
    clauses.push(`${column} = ?`);
    params.push(row.id);
  }
  if (clauses.length) conditions.push(`(${clauses.join(" OR ")})`);
  return { unresolved: null, applied };
}

/**
 * The `brands.kind` a category's makes live under.
 *
 * Jets and helicopters genuinely share `aircraft_manufacturer` — that is the schema,
 * not a bug. Scoping by kind is what stops a watch brand resolving a car make when
 * the two share a slug.
 */
const BRAND_KIND_BY_CATEGORY = Object.freeze({
  "real-estate": "property_developer",
  cars: "car_make",
  yachts: "yacht_builder",
  jets: "aircraft_manufacturer",
  helicopters: "aircraft_manufacturer",
  watches: "watch_brand",
});

export function brandKindForCategory(category) {
  return BRAND_KIND_BY_CATEGORY[String(category || "").toLowerCase()] || null;
}

async function resolveBrand(filters, conditions, params) {
  const modelSlug = filters.model
    ? String(filters.model).replace(/^model:[^:]*:/, "").replace(/^(model|collection):/, "")
    : null;
  if (filters.make) {
    const slug = String(filters.make).replace(/^(make|brand|manufacturer):/, "");
    // `brands` has `is_active` and `deleted_at`; it has no `status` column at all, so
    // this query threw and every make/builder/manufacturer/brand filter answered 500.
    const kind = brandKindForCategory(filters.listingType);
    const brandId = await queryValue(
      `SELECT id FROM brands
        WHERE slug = ? AND is_active = 1 AND deleted_at IS NULL
          ${kind ? "AND kind = ?" : ""}
        LIMIT 1`,
      kind ? [slug, kind] : [slug]
    );
    if (!brandId) return { unresolved: "make" };
    conditions.push("ls.brand_id = ?");
    params.push(brandId);

    if (modelSlug) {
      // `brand_models` has `is_active` but no `deleted_at`.
      const modelId = await queryValue(
        `SELECT id FROM brand_models WHERE brand_id = ? AND slug = ? AND is_active = 1 LIMIT 1`,
        [brandId, modelSlug]
      );
      if (!modelId) return { unresolved: "model" };
      conditions.push("ls.brand_model_id = ?");
      params.push(modelId);
    }
  } else if (modelSlug) {
    // A standalone model must never degrade to an unfiltered catalogue search.
    // Resolve it only when it is unique within this marketplace; an unknown or
    // ambiguous slug is an impossible search and therefore returns zero rows.
    const kind = brandKindForCategory(filters.listingType);
    if (!kind) return { unresolved: "model" };
    const matches = await query(
      `SELECT bm.id, bm.brand_id
         FROM brand_models bm
         JOIN brands b ON b.id = bm.brand_id
        WHERE bm.slug = ? AND bm.is_active = 1
          AND b.kind = ? AND b.is_active = 1 AND b.deleted_at IS NULL
        LIMIT 2`,
      [modelSlug, kind]
    );
    if (matches.length !== 1) return { unresolved: "model" };
    conditions.push("ls.brand_id = ?", "ls.brand_model_id = ?");
    params.push(matches[0].brand_id, matches[0].id);
  }
  return { unresolved: null };
}

export async function buildSearchQuery(rawFilters = {}) {
  const filters = normalizeSearchInput(rawFilters);
  const conditions = [];
  const params = [];
  const joins = [];

  if (filters.rootCategoryId) {
    conditions.push("ls.root_category_id = ?");
    params.push(filters.rootCategoryId);
  }
  if (filters.categorySlug) {
    conditions.push("ls.category_slug = ?");
    params.push(filters.categorySlug);
  }
  if (filters.purposeSlug) {
    conditions.push("ls.purpose_slug = ?");
    params.push(filters.purposeSlug);
  }

  const location = await locationConditions(filters, conditions, params);
  if (location.unresolved) return { impossible: true, filters };

  const brand = await resolveBrand(filters, conditions, params);
  if (brand.unresolved) return { impossible: true, filters };

  if (filters.minPrice !== null) {
    conditions.push("ls.price_base >= ?");
    params.push(filters.minPrice);
  }
  if (filters.maxPrice !== null) {
    conditions.push("ls.price_base <= ?");
    params.push(filters.maxPrice);
  }
  if (filters.currency) {
    conditions.push("ls.currency_code = ?");
    params.push(filters.currency.toUpperCase());
  }
  if (filters.featured) conditions.push("ls.is_featured = 1");
  if (filters.verified) conditions.push("ls.is_verified = 1");
  if (filters.exclusive) conditions.push("ls.is_exclusive = 1");
  if (filters.organizationId) {
    conditions.push("ls.organization_id = ?");
    params.push(Number(filters.organizationId));
  }
  if (filters.agentId) {
    conditions.push("ls.agent_id = ?");
    params.push(Number(filters.agentId));
  }
  if (filters.projectId) {
    conditions.push("ls.project_id = ?");
    params.push(Number(filters.projectId));
  }
  /**
   * "Show me the properties in this development", addressed safely.
   *
   * `project` is a public ULID or slug and is resolved against `project_search`,
   * which holds only published projects — so an unpublished or archived project
   * cannot be used to enumerate its inventory, and an unknown reference makes
   * the search impossible rather than returning the whole catalogue.
   */
  if (filters.projectRef) {
    const resolved = await queryValue(
      "SELECT project_id FROM project_search WHERE public_id = ? OR slug = ? LIMIT 1",
      [filters.projectRef, filters.projectRef]
    );
    if (!resolved) return { impossible: true, filters };
    conditions.push("ls.project_id = ?");
    params.push(Number(resolved));
  }

  // Bedrooms/bathrooms are multi-select "3, 4, 5+" chips, not a range.
  if (filters.bedrooms.length && filters.listingType === "real-estate") {
    conditions.push(`ls.spec_a IN (${filters.bedrooms.map(() => "?").join(", ")})`);
    params.push(...filters.bedrooms);
  }
  if (filters.bathrooms.length && filters.listingType === "real-estate") {
    conditions.push(`ls.spec_b IN (${filters.bathrooms.map(() => "?").join(", ")})`);
    params.push(...filters.bathrooms);
  }

  for (const range of RANGE_FILTERS[filters.listingType] || []) {
    const min = filters.ranges[range.min];
    const max = filters.ranges[range.max];
    if (min !== null && min !== undefined) {
      conditions.push(`ls.${range.column} >= ?`);
      params.push(min);
    }
    if (max !== null && max !== undefined) {
      conditions.push(`ls.${range.column} <= ?`);
      params.push(max);
    }
  }

  for (const [key, column] of Object.entries(FACET_FILTERS[filters.listingType] || {})) {
    const value = filters.facets[key];
    if (!value) continue;
    conditions.push(`ls.${column} = ?`);
    params.push(value);
  }

  for (const [key, spec] of Object.entries(DETAIL_FILTERS[filters.listingType] || {})) {
    const value = filters.detailFilters[key];
    if (value === null || value === undefined || value === "") continue;
    if (!joins.some((join) => join.includes(` ${spec.alias} `))) {
      joins.push(`JOIN ${spec.table} ${spec.alias} ON ${spec.alias}.listing_id = ls.listing_id`);
    }
    if (spec.op === "like") {
      conditions.push(`${spec.alias}.${spec.column} LIKE ?`);
      params.push(`%${String(value).slice(0, 60)}%`);
    } else if (spec.op === "bool") {
      conditions.push(`${spec.alias}.${spec.column} = ?`);
      params.push(value === true || value === "1" || value === "true" ? 1 : 0);
    } else {
      conditions.push(`${spec.alias}.${spec.column} = ?`);
      params.push(String(value).slice(0, 60));
    }
  }

  if (filters.keyword) {
    // Prefix-anchored on reference so "LF-2431" is an exact hit, contains on the
    // rest. The projection keeps title and location_label on one row, so this
    // stays a single-table scan.
    conditions.push("(ls.title LIKE ? OR ls.location_label LIKE ? OR ls.reference = ?)");
    params.push(`%${filters.keyword}%`, `%${filters.keyword}%`, filters.keyword.toUpperCase());
  }

  return {
    impossible: false,
    filters,
    where: conditions.length ? `WHERE ${conditions.join(" AND ")}` : "",
    joinSql: joins.join("\n"),
    params,
    orderBy: SORT_MAP[filters.sort] || SORT_MAP.featured,
  };
}

export async function searchListings(rawFilters = {}, { limit = 20, offset = 0, withTotal = true } = {}) {
  const built = await buildSearchQuery(rawFilters);
  if (built.impossible) return { rows: [], total: 0, filters: built.filters };

  const safeLimit = Math.min(100, Math.max(1, Number(limit) || 20));
  const safeOffset = Math.max(0, Math.min(100_000, Number(offset) || 0));

  const rows = await query(
    `SELECT ${CARD_COLUMNS}
       FROM listing_search ls
       ${built.joinSql}
       ${CARD_JOINS}
       ${built.where}
      ORDER BY ${built.orderBy}
      LIMIT ${safeLimit} OFFSET ${safeOffset}`,
    built.params
  );

  let total = rows.length + safeOffset;
  if (withTotal) {
    total = Number(
      await queryValue(
        `SELECT COUNT(*) AS total FROM listing_search ls ${built.joinSql} ${built.where}`,
        built.params
      )
    );
  }

  return { rows: rows.map(serializeListingCard), total, filters: built.filters };
}

export async function countListings(rawFilters = {}) {
  const built = await buildSearchQuery(rawFilters);
  if (built.impossible) return 0;
  return Number(
    await queryValue(
      `SELECT COUNT(*) AS total FROM listing_search ls ${built.joinSql} ${built.where}`,
      built.params
    )
  );
}

/** Distinct facet values with counts, for the filter sidebar. */
export async function facetCounts(rawFilters, column) {
  const allowed = new Set(["facet_a", "facet_b", "facet_c", "category_slug", "purpose_slug", "currency_code"]);
  if (!allowed.has(column)) throw new TypeError(`unsupported facet column: ${column}`);
  const built = await buildSearchQuery(rawFilters);
  if (built.impossible) return [];
  return query(
    `SELECT ls.${column} AS value, COUNT(*) AS count
       FROM listing_search ls ${built.joinSql} ${built.where}
      ${built.where ? "AND" : "WHERE"} ls.${column} IS NOT NULL
      GROUP BY ls.${column}
      ORDER BY count DESC
      LIMIT 60`,
    built.params
  );
}

/**
 * Countries that hold listings, with a count and a photograph, under whatever filters apply.
 *
 * The homepage explore strip used `locations.listing_count` — a rollup across every category —
 * so "Spain 14" sat under Yachts while the yacht catalogue held nothing in Spain at all. Counting
 * through `listing_search` with the caller's filters makes the number specific to the category
 * being browsed, and only countries that actually have inventory come back.
 *
 * `locations` carries no imagery, so the tile borrows the cover photograph of the best listing it
 * is counting: the country shown under Real Estate is illustrated by a property, under Yachts by
 * a yacht. GROUP_CONCAT ordered by the same ranking the search uses, sliced to its first element,
 * picks that row without a correlated subquery or a second round trip. The separator is a space
 * because a raw space cannot appear in a URL, and only the first entry is read, so the 1024-byte
 * group_concat_max_len cannot truncate it (cover_image_url is VARCHAR(500)).
 */
export async function countryFacets(rawFilters = {}, { limit = 12 } = {}) {
  const built = await buildSearchQuery(rawFilters);
  if (built.impossible) return [];
  // Inlined rather than bound: LIMIT placeholders are not usable on a prepared statement here,
  // and this is a clamped integer, never caller text.
  const bounded = Math.min(Math.max(Number.parseInt(limit, 10) || 12, 1), 60);
  return query(
    `SELECT co.id AS id,
            co.slug AS slug,
            co.name AS name,
            COUNT(*) AS count,
            SUBSTRING_INDEX(
              GROUP_CONCAT(
                ls.cover_image_url
                ORDER BY ls.is_featured DESC, ls.quality_score DESC, ls.published_at DESC
                SEPARATOR ' '
              ),
              ' ', 1
            ) AS image
       FROM listing_search ls
       JOIN locations co ON co.id = ls.country_id
       ${built.joinSql} ${built.where}
      GROUP BY co.id, co.slug, co.name
      ORDER BY count DESC, co.name ASC
      LIMIT ${bounded}`,
    built.params
  );
}

export { CARD_COLUMNS, CARD_JOINS };
