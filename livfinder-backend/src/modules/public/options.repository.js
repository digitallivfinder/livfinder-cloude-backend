import { query } from "../../db/query.js";
import { resolveCategory } from "../../utils/categories.js";
import { SPEC_MAP } from "../search/searchFilters.js";
import { isPropertySegment } from "../search/propertySegments.js";
import { resolveLocation, searchLocations, toEntity } from "../locations/locations.repository.js";

/**
 * `brands.kind` is how the catalogue separates makes from builders from
 * manufacturers from watch brands, and it is what a category filter must scope
 * to — otherwise a car search offers Feadship.
 */
const BRAND_KIND = {
  "real-estate": "property_developer",
  cars: "car_make",
  yachts: "yacht_builder",
  jets: "aircraft_manufacturer",
  helicopters: "aircraft_manufacturer",
  watches: "watch_brand",
};

/**
 * Jets and helicopters share `brands.kind = 'aircraft_manufacturer'` (deliberately —
 * see `search.repository.js`), so `kind` alone cannot tell a jet maker from a
 * helicopter maker. `brands.aircraft_segment` (migration 0046) is the finer signal;
 * every other kind has exactly one segment, so it does not apply to them.
 */
const AIRCRAFT_SEGMENT = { jets: "fixed_wing", helicopters: "rotorcraft" };

/** Matches the frontend's entity id vocabulary exactly. */
const PARENT_TYPE = { cars: "make", watches: "brand", "real-estate": "developer" };
const CHILD_TYPE = { watches: "collection" };

function parentType(listingType) {
  return PARENT_TYPE[listingType] || "manufacturer";
}
function childType(listingType) {
  return CHILD_TYPE[listingType] || "model";
}

function brandEntity(row, listingType) {
  const type = parentType(listingType);
  return {
    id: `${type}:${row.slug}`,
    slug: row.slug,
    label: row.name,
    type,
    parentId: null,
    parent: null,
    value: `${type}:${row.slug}`,
    listingCount: Number(row.active_listing_count ?? row.listing_count ?? 0),
    logo: row.logo_url || null,
  };
}

function modelEntity(row, listingType) {
  const parent = brandEntity({ slug: row.brand_slug, name: row.brand_name, logo_url: null, listing_count: 0 }, listingType);
  const type = childType(listingType);
  return {
    id: `model:${row.brand_slug}:${row.slug}`,
    slug: row.slug,
    label: row.name,
    type,
    parentId: parent.id,
    parent,
    value: `model:${row.brand_slug}:${row.slug}`,
    secondaryLabel: row.brand_name,
    listingCount: Number(row.listing_count ?? 0),
  };
}

export async function listBrands(listingType, { q = null, limit = 40, onlyWithListings = true } = {}) {
  const kind = BRAND_KIND[listingType];
  if (!kind) return [];
  const definition = resolveCategory(listingType);
  const params = [kind];
  const conditions = ["b.kind = ?", "b.is_active = 1", "b.deleted_at IS NULL"];
  const segment = AIRCRAFT_SEGMENT[listingType];
  if (segment) {
    conditions.push("b.aircraft_segment = ?");
    params.push(segment);
  }
  if (q) {
    conditions.push("(b.name LIKE ? OR b.slug LIKE ?)");
    params.push(`${q}%`, `${q}%`);
  }

  /**
   * Counted against this category's listings, not the brand's catalogue-wide rollup.
   *
   * `brands.kind` is too coarse on its own: jets and helicopters share
   * `aircraft_manufacturer`, so the helicopter menu offered Gulfstream, Bombardier, Cessna and
   * six more with no helicopter behind them — nine of fourteen options returned an empty page —
   * while the number beside each one counted that brand's aircraft of every kind.
   *
   * Joining the projection scopes both the list and the count to the marketplace being browsed.
   * `onlyWithListings` then means what it says: a brand this category has nothing from is not
   * offered at all.
   */
  let joinSql = "";
  let countExpr = "b.active_listing_count";
  const joinParams = [];
  if (definition?.rootId) {
    joinSql = `LEFT JOIN (
        SELECT brand_id, COUNT(*) AS n FROM listing_search
         WHERE root_category_id = ? AND brand_id IS NOT NULL
         GROUP BY brand_id
      ) live ON live.brand_id = b.id`;
    countExpr = "COALESCE(live.n, 0)";
    joinParams.push(definition.rootId);
    if (onlyWithListings) conditions.push("live.n > 0");
  } else if (onlyWithListings) {
    conditions.push("b.active_listing_count > 0");
  }

  const safeLimit = Math.min(200, Math.max(1, Number(limit) || 40));
  const rows = await query(
    `SELECT b.id, b.slug, b.name, b.logo_url, b.listing_count,
            ${countExpr} AS active_listing_count
       FROM brands b
       ${joinSql}
      WHERE ${conditions.join(" AND ")}
      ORDER BY ${countExpr} DESC, b.sort_order ASC, b.name ASC
      LIMIT ${safeLimit}`,
    [...joinParams, ...params]
  );
  return rows.map((row) => brandEntity(row, listingType));
}

export async function listModels(listingType, { brandSlug = null, q = null, limit = 60, onlyWithListings = true } = {}) {
  const kind = BRAND_KIND[listingType];
  if (!kind) return [];
  // Scoped to this category for the same reason as `listBrands`: jets and helicopters share a
  // brand kind, so an unscoped count offers models the marketplace has nothing from.
  const definition = resolveCategory(listingType);
  const params = [kind];
  const conditions = ["b.kind = ?", "bm.is_active = 1", "b.is_active = 1", "b.deleted_at IS NULL"];
  const segment = AIRCRAFT_SEGMENT[listingType];
  if (segment) {
    conditions.push("b.aircraft_segment = ?");
    params.push(segment);
  }
  if (brandSlug) {
    conditions.push("b.slug = ?");
    params.push(String(brandSlug).replace(/^[a-z]+:/, ""));
  }
  if (q) {
    conditions.push("(bm.name LIKE ? OR bm.slug LIKE ?)");
    params.push(`${q}%`, `${q}%`);
  }
  // The count comes from the search projection rather than `brand_models.listing_count`.
  // That counter is 0 for every one of the 177 seeded models, and filtering on it
  // meant every dependent model/collection list answered empty — picking a make
  // offered no models at all.
  if (onlyWithListings) conditions.push("live.n > 0");
  const safeLimit = Math.min(200, Math.max(1, Number(limit) || 60));
  const rows = await query(
    `SELECT bm.id, bm.slug, bm.name, COALESCE(live.n, 0) AS listing_count,
            b.slug AS brand_slug, b.name AS brand_name
       FROM brand_models bm
       JOIN brands b ON b.id = bm.brand_id
       LEFT JOIN (
         SELECT brand_model_id, COUNT(*) AS n
           FROM listing_search
          WHERE brand_model_id IS NOT NULL${definition?.rootId ? " AND root_category_id = ?" : ""}
          GROUP BY brand_model_id
       ) live ON live.brand_model_id = bm.id
      WHERE ${conditions.join(" AND ")}
      ORDER BY listing_count DESC, bm.sort_order ASC, bm.name ASC
      LIMIT ${safeLimit}`,
    definition?.rootId ? [definition.rootId, ...params] : params
  );
  return rows.map((row) => modelEntity(row, listingType));
}

/** Sub-categories, e.g. the real-estate property types or the yacht types. */
export async function listCategoryTypes(listingType, { q = null, limit = 60, segment = null, all = false } = {}) {
  const definition = resolveCategory(listingType);
  if (!definition) return [];
  const safeLimit = Math.min(200, Math.max(1, Number(limit) || 60));
  // Real estate's Residential / Commercial: the types tagged with it or with "both" (0077), and
  // their counts from that segment's listings only.
  const seg = definition.listingType === "real-estate" && isPropertySegment(segment) ? segment : null;
  const liveParams = [definition.rootId];
  let liveFilter = "";
  if (seg) {
    liveFilter = " AND property_segment = ?";
    liveParams.push(seg);
  }
  const params = [definition.rootId];
  let filter = "";
  if (q) {
    filter += " AND c.name LIKE ?";
    params.push(`${q}%`);
  }
  if (seg) {
    filter += " AND c.property_segment IN (?, 'both')";
    params.push(seg);
  }
  /**
   * Counted from the projection, and ordered by it.
   *
   * `categories.active_listing_count` is a stored rollup that drifts, and the list is what the
   * category strip and the type filter both draw on — a type with nothing behind it is an option
   * that can only ever return an empty page. `all` (the add / edit forms) lifts that: a listing
   * may be the first of its type, so every active type is offered, in catalogue order.
   */
  const rows = await query(
    `SELECT c.id, c.slug, c.name, c.property_segment, COALESCE(live.n, 0) AS live_count
       FROM categories c
       ${all ? "LEFT JOIN" : "JOIN"} (
         SELECT category_slug, COUNT(*) AS n FROM listing_search
          WHERE root_category_id = ? AND category_slug IS NOT NULL${liveFilter}
          GROUP BY category_slug
       ) live ON live.category_slug = c.slug
      WHERE c.root_category_id = ? AND c.id <> c.root_category_id
        AND c.status = 'active' AND c.is_visible = 1 AND c.deleted_at IS NULL${filter}
      ORDER BY ${all ? "c.sort_order ASC, c.name ASC" : "live.n DESC, c.sort_order ASC, c.name ASC"}
      LIMIT ${safeLimit}`,
    [...liveParams, ...params]
  );
  return rows.map((row) => ({
    id: `category:${row.slug}`,
    /**
     * The slug, not the display name.
     *
     * `value` is what the filter sends to the API, and the API matches `category_slug` — so
     * emitting "Apartment" here produced zero results while "apartments" returned 14. The name
     * belongs in `label`, which is what the control renders.
     */
    value: row.slug,
    slug: row.slug,
    label: row.name,
    type: "propertyType",
    // residential | commercial | both, for real estate; lets a form re-check a chosen type.
    segment: row.property_segment ?? null,
    listingCount: Number(row.live_count || 0),
  }));
}


/**
 * The years actually present in a category, newest first.
 *
 * Every category offered a hardcoded 1987-2026 regardless of its catalogue, which is wrong in
 * both directions: watches reach back to 1971 and would be unreachable before 1987, while cars
 * start at 2016 so thirty of the offered years match nothing at all.
 *
 * Which spec column holds the year differs per category — `spec_a` for cars and aircraft,
 * `spec_b` for yachts, `spec_e` for real estate — so it is read from `SPEC_MAP`, the same map
 * `sp_refresh_listing_search` writes against, rather than a second copy that could drift.
 */
async function listYears(listingType) {
  const definition = resolveCategory(listingType);
  const spec = SPEC_MAP[listingType];
  if (!definition || !spec) return [];
  const column = Object.keys(spec).find(
    (key) => key.startsWith("spec_") && /^year/i.test(String(spec[key] || ""))
  );
  if (!column) return [];
  const rows = await query(
    `SELECT ${column} AS value, COUNT(*) AS listing_count
       FROM listing_search
      WHERE root_category_id = ? AND ${column} IS NOT NULL AND ${column} <> ''
      GROUP BY ${column}
      ORDER BY CAST(${column} AS UNSIGNED) DESC`,
    [definition.rootId]
  );
  return rows.map((row) => ({
    id: `year:${row.value}`,
    value: String(row.value),
    slug: String(row.value),
    label: String(row.value),
    type: "year",
    listingCount: Number(row.listing_count),
  }));
}

/** Distinct values actually present in the projection, so no dead filter option. */
async function facetValues(listingType, column, { limit = 40 } = {}) {
  const definition = resolveCategory(listingType);
  if (!definition) return [];
  const allowed = new Set(["facet_a", "facet_b", "facet_c"]);
  if (!allowed.has(column)) return [];
  const safeLimit = Math.min(100, Math.max(1, Number(limit) || 40));
  const rows = await query(
    `SELECT ${column} AS value, COUNT(*) AS listing_count
       FROM listing_search
      WHERE root_category_id = ? AND ${column} IS NOT NULL AND ${column} <> ''
      GROUP BY ${column}
      ORDER BY listing_count DESC
      LIMIT ${safeLimit}`,
    [definition.rootId]
  );
  return rows.map((row) => ({
    id: `${column}:${row.value}`,
    value: row.value,
    slug: row.value,
    label: humanise(row.value),
    type: column,
    listingCount: Number(row.listing_count),
  }));
}

function humanise(value) {
  return String(value)
    .replace(/[_-]+/g, " ")
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

/** An ENUM column's values, in the order the column declares them. */
async function enumOptions(table, column, type) {
  const rows = await query(
    `SELECT COLUMN_TYPE AS column_type FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [table, column]
  );
  const match = /^enum\((.*)\)$/i.exec(rows[0]?.column_type || "");
  if (!match) return [];
  return [...match[1].matchAll(/'((?:[^']|'')*)'/g)].map(([, raw]) => {
    const value = raw.replace(/''/g, "'");
    return { id: `${type}:${value}`, value, slug: value, label: humanise(value), type };
  });
}

/**
 * The amenities a marketplace offers, from the feature catalogue linked to its root category —
 * never from what listings happen to carry. Each row names its group so a menu can section them.
 */
async function listAmenities(listingType, { q = null } = {}) {
  const definition = resolveCategory(listingType);
  if (!definition) return [];
  const params = [definition.rootId];
  let filter = "";
  if (q) {
    filter = " AND f.name LIKE ?";
    params.push(`%${q}%`);
  }
  const rows = await query(
    `SELECT f.slug, f.name, fg.code AS group_code, fg.name AS group_name
       FROM category_features cf
       JOIN features f ON f.id = cf.feature_id AND f.is_filterable = 1
       LEFT JOIN feature_groups fg ON fg.id = f.feature_group_id
      WHERE cf.category_id = ?${filter}
      ORDER BY fg.sort_order IS NULL, fg.sort_order, cf.sort_order, f.sort_order, f.name`,
    params
  );
  return rows.map((row) => ({
    id: `amenity:${row.slug}`,
    value: row.slug,
    slug: row.slug,
    label: row.name,
    group: row.group_name || null,
    groupCode: row.group_code || null,
    type: "amenity",
  }));
}

const FACET_KEY_COLUMN = {
  "real-estate": { furnishing: "facet_a", completion: "facet_b", completionStatus: "facet_b", ownershipType: "facet_c" },
  cars: { transmission: "facet_a", fuelType: "facet_b", condition: "facet_c" },
  yachts: { yachtType: "facet_a", hullMaterial: "facet_b" },
  jets: { aircraftType: "facet_a", engineProgram: "facet_b" },
  helicopters: { helicopterType: "facet_a", aircraftType: "facet_a", engineProgram: "facet_b" },
  watches: { movement: "facet_a", condition: "facet_b", caseMaterial: "facet_c" },
};

/**
 * Serves the homepage and listing-page async filter menus.
 *
 * `filterKey` is the frontend's own naming (carModel, yachtType, brand …); the
 * mapping to a data source lives here so the frontend keeps its vocabulary.
 */
export async function filterOptions(category, filterKey, { q = null, parent = null, limit = 30, preferCountry = null, all = false } = {}) {
  const definition = resolveCategory(category);
  const listingType = definition?.listingType || "real-estate";

  if (filterKey === "location") {
    /**
     * `preferCountry` is the header's selected country. It orders rather than filters, so the
     * visitor's own market comes first and everywhere else is still reachable by typing — asked
     * for as "prefer that country's locations but show all others as well".
     */
    let preferCountryId = null;
    if (preferCountry) {
      const row = await resolveLocation(preferCountry, { type: "country" });
      preferCountryId = row?.id ?? null;
    }
    /**
     * `parent` (a location id such as `city:12`) narrows the menu to the places inside that one —
     * at any depth, busiest first — so a picker with Dubai selected can offer Dubai Marina and
     * Downtown rather than the whole world again. An unknown parent offers nothing.
     */
    let ancestorId = null;
    if (parent) {
      const row = await resolveLocation(parent);
      if (!row) return [];
      ancestorId = row.id;
    }
    const rows = await searchLocations({
      q,
      types: ["country", "state", "city", "community", "subcommunity"],
      limit,
      ancestorId,
      preferCountryId: ancestorId ? null : preferCountryId,
      // Scopes both the counts and the menu itself to the marketplace being browsed, which
      // supersedes the catalogue-wide `onlyWithListings` gate — that one let a place with
      // listings in some other category through, and then returned nothing when picked.
      // `all=true` lifts it: an agent's service areas can be any place, listings or not.
      categoryRootId: all ? null : definition?.rootId ?? null,
    });
    return rows;
  }

  if (["make", "brand", "builder", "manufacturer", "developer"].includes(filterKey)) {
    return listBrands(listingType, { q, limit, onlyWithListings: !all });
  }

  if (["model", "carModel", "yachtModel", "aircraftModel", "helicopterModel", "watchModel", "collection"].includes(filterKey)) {
    return listModels(listingType, { brandSlug: parent, q, limit, onlyWithListings: !all });
  }

  if (filterKey === "year") {
    return listYears(listingType);
  }

  if (["propertyType", "category", "assetType"].includes(filterKey)) {
    // Real estate's `parent` is the Residential / Commercial segment; `all` is the forms' full list.
    const segment = listingType === "real-estate" && isPropertySegment(parent) ? parent : null;
    return listCategoryTypes(listingType, { q, limit, segment, all });
  }

  if (listingType === "real-estate" && filterKey === "propertySegment") {
    // The values of the `listings.property_segment` column, in its order.
    return enumOptions("listings", "property_segment", "propertySegment");
  }

  if (listingType === "real-estate" && filterKey === "rentPeriod") {
    return enumOptions("listing_real_estate", "rent_period", "rentPeriod");
  }

  if (filterKey === "amenities") {
    return listAmenities(listingType, { q });
  }

  const column = FACET_KEY_COLUMN[listingType]?.[filterKey];
  if (column) {
    let values = await facetValues(listingType, column, { limit });
    // Under Construction is folded into Off Plan; it is no longer offered as its own status.
    // The website's status toggle is All / Ready / Off Plan: Under Construction is folded into Off
    // Plan and Shell and core is counted as Ready, so neither is offered on its own.
    if (listingType === "real-estate" && column === "facet_b") {
      values = values.filter((option) => !["under_construction", "shell_and_core"].includes(option.value));
    }
    return q ? values.filter((option) => option.label.toLowerCase().startsWith(q.toLowerCase())) : values;
  }

  if (filterKey === "year") {
    const rows = await query(
      `SELECT DISTINCT spec_a AS value FROM listing_search
        WHERE root_category_id = ? AND spec_a BETWEEN 1900 AND 2100
        ORDER BY spec_a DESC LIMIT 80`,
      [definition?.rootId ?? 2]
    );
    return rows.map((row) => ({ id: `year:${row.value}`, value: String(row.value), label: String(row.value), type: "year" }));
  }

  return [];
}

/** The single combined "search anything" menu on a category page. */
export async function searchOptions(category, { q = null, limit = 30 } = {}) {
  const definition = resolveCategory(category);
  const listingType = definition?.listingType || "real-estate";
  const perSource = Math.max(5, Math.floor(limit / 3));

  const [locations, brands, types] = await Promise.all([
    searchLocations({ q, types: ["country", "state", "city", "community", "subcommunity"], limit: perSource, onlyWithListings: !q }),
    listBrands(listingType, { q, limit: perSource }),
    listCategoryTypes(listingType, { q, limit: perSource }),
  ]);

  const models = q ? await listModels(listingType, { q, limit: perSource }) : [];

  return [
    ...locations.map((entity) => ({ ...entity, type: "location" })),
    ...brands,
    ...models,
    ...types,
  ].slice(0, limit);
}

export async function popularSearches(category, { limit = 12 } = {}) {
  const definition = resolveCategory(category);
  const listingType = definition?.listingType || "real-estate";
  if (listingType === "real-estate") {
    const rows = await searchLocations({
      types: ["city", "community"],
      limit,
      onlyWithListings: true,
    });
    return rows.map((entity) => ({ ...entity, type: "location" }));
  }
  return listBrands(listingType, { limit });
}

/**
 * Validates `/cars/{make}/{model}/{year}` style path segments against the real
 * catalogue, so an invented make 404s instead of rendering an empty page.
 */
export async function resolveAssetHierarchy(category, segments = []) {
  const definition = resolveCategory(category);
  const listingType = definition?.listingType;
  if (!listingType) return { valid: false, labels: [], entities: [] };
  if (!segments.length) return { valid: true, labels: [], entities: [] };

  const [brandSlug, modelSlug, yearSegment] = segments;
  const kind = BRAND_KIND[listingType];
  const brandRow = await query(
    `SELECT id, slug, name, logo_url, listing_count, active_listing_count
       FROM brands WHERE slug = ? AND kind = ? AND deleted_at IS NULL LIMIT 1`,
    [brandSlug, kind]
  );
  if (!brandRow.length) return { valid: false, labels: [], entities: [] };
  const brand = brandEntity(brandRow[0], listingType);
  if (!modelSlug) return { valid: true, labels: [brand.label], entities: [brand], parent: brand };

  const modelRow = await query(
    `SELECT bm.id, bm.slug, bm.name, bm.listing_count, b.slug AS brand_slug, b.name AS brand_name
       FROM brand_models bm JOIN brands b ON b.id = bm.brand_id
      WHERE b.id = ? AND bm.slug = ? LIMIT 1`,
    [brandRow[0].id, modelSlug]
  );
  if (!modelRow.length) return { valid: false, labels: [], entities: [] };
  const model = modelEntity(modelRow[0], listingType);

  if (yearSegment && !/^\d{4}$/.test(yearSegment)) return { valid: false, labels: [], entities: [] };
  return {
    valid: true,
    labels: [brand.label, model.label, yearSegment].filter(Boolean),
    entities: [brand, model],
    parent: brand,
    record: model,
    year: yearSegment || null,
  };
}

export async function categoryCounts() {
  const rows = await query(
    `SELECT c.id, c.code, c.slug, c.name, c.name_plural, c.hero_image_url,
            COUNT(ls.listing_id) AS listing_count
       FROM categories c
       LEFT JOIN listing_search ls ON ls.root_category_id = c.id
      WHERE c.parent_id IS NULL AND c.status = 'active'
      GROUP BY c.id
      ORDER BY c.sort_order ASC, c.id ASC`,
    []
  );
  return rows.map((row) => ({
    id: row.code,
    slug: row.slug,
    label: row.name_plural || row.name,
    heroImage: row.hero_image_url || null,
    count: Number(row.listing_count || 0),
  }));
}

export { toEntity };
