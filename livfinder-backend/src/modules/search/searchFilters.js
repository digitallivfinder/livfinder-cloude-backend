import { resolveCategory } from "../../utils/categories.js";
import { asArray, toInt, toNumber, toBool, cleanString } from "../../utils/http.js";

/**
 * The listing_search spec/facet slots, per root category. Mirrors the mapping
 * `sp_refresh_listing_search` writes; changing one without the other silently
 * filters on the wrong column, so they are documented together here.
 */
export const SPEC_MAP = {
  "real-estate": {
    spec_a: "bedrooms", spec_b: "bathrooms", spec_c: "builtAreaSqft", spec_d: "plotAreaSqft",
    spec_e: "yearBuilt", spec_f: "floorNumber",
    facet_a: "furnishing", facet_b: "completionStatus", facet_c: "ownershipType",
  },
  cars: {
    spec_a: "year", spec_b: "mileageKm", spec_c: "horsepower", spec_d: "engineSizeCc",
    spec_e: "seats", spec_f: "doors",
    facet_a: "transmission", facet_b: "fuelType", facet_c: "condition",
  },
  yachts: {
    spec_a: "lengthFt", spec_b: "year", spec_c: "cabins", spec_d: "guests",
    spec_e: "engineHours", spec_f: "maxSpeedKnots",
    facet_a: "vesselType", facet_b: "hullMaterial", facet_c: "charterOrSale",
  },
  jets: {
    spec_a: "year", spec_b: "flightHours", spec_c: "passengerCapacity", spec_d: "rangeNm",
    spec_e: "cycles", spec_f: "cruiseSpeedKts",
    facet_a: "aircraftType", facet_b: "engineProgram", facet_c: null,
  },
  helicopters: {
    spec_a: "year", spec_b: "flightHours", spec_c: "passengerCapacity", spec_d: "rangeNm",
    spec_e: "cycles", spec_f: "cruiseSpeedKts",
    facet_a: "aircraftType", facet_b: "engineProgram", facet_c: null,
  },
  watches: {
    spec_a: "year", spec_b: "caseDiameterMm", spec_c: "powerReserveHours", spec_d: "waterResistanceM",
    spec_e: "jewels", spec_f: null,
    facet_a: "movement", facet_b: "condition", facet_c: "caseMaterial",
  },
};

/**
 * Which incoming API key maps to which listing_search column, per category.
 * Range keys carry `{ column, min, max }`; equality keys carry `{ column }`.
 */
const RANGE_FILTERS = {
  "real-estate": [
    { column: "spec_a", min: "bedroomsMin", max: "bedroomsMax" },
    { column: "spec_b", min: "bathroomsMin", max: "bathroomsMax" },
    { column: "spec_c", min: "areaMin", max: "areaMax" },
    { column: "spec_e", min: "yearMin", max: "yearMax" },
  ],
  cars: [
    { column: "spec_a", min: "yearMin", max: "yearMax" },
    { column: "spec_b", min: "mileageMin", max: "mileageMax" },
    { column: "spec_c", min: "horsepowerMin", max: "horsepowerMax" },
  ],
  yachts: [
    { column: "spec_a", min: "lengthMin", max: "lengthMax" },
    { column: "spec_b", min: "yearMin", max: "yearMax" },
    { column: "spec_c", min: "cabinsMin", max: "cabinsMax" },
  ],
  jets: [
    { column: "spec_a", min: "yearMin", max: "yearMax" },
    { column: "spec_b", min: "flightHoursMin", max: "flightHoursMax" },
    { column: "spec_c", min: "passengerCapacity", max: "passengerCapacityMax" },
    { column: "spec_d", min: "rangeMin", max: "rangeMax" },
  ],
  helicopters: [
    { column: "spec_a", min: "yearMin", max: "yearMax" },
    { column: "spec_b", min: "flightHoursMin", max: "flightHoursMax" },
    { column: "spec_c", min: "passengerCapacity", max: "passengerCapacityMax" },
    { column: "spec_d", min: "rangeMin", max: "rangeMax" },
  ],
  watches: [
    { column: "spec_a", min: "yearMin", max: "yearMax" },
    { column: "spec_b", min: "caseDiameterMin", max: "caseDiameterMax" },
  ],
};

const FACET_FILTERS = {
  "real-estate": { furnishing: "facet_a", completionStatus: "facet_b", ownershipType: "facet_c" },
  cars: { transmission: "facet_a", fuelType: "facet_b", condition: "facet_c" },
  yachts: { yachtType: "facet_a", hullMaterial: "facet_b" },
  jets: { aircraftType: "facet_a", engineProgram: "facet_b" },
  helicopters: { aircraftType: "facet_a", engineProgram: "facet_b" },
  watches: { movement: "facet_a", condition: "facet_b", caseMaterial: "facet_c" },
};

/**
 * Filters that cannot be served from the projection and require the detail
 * table. Requesting one adds a single join — it does not degrade the common path.
 */
const DETAIL_FILTERS = {
  cars: {
    exteriorColor: { table: "listing_vehicle", alias: "d_veh", column: "exterior_color", op: "like" },
    interiorColor: { table: "listing_vehicle", alias: "d_veh", column: "interior_color", op: "like" },
    drivetrain: { table: "listing_vehicle", alias: "d_veh", column: "drivetrain", op: "eq" },
    bodyType: { table: "listing_vehicle", alias: "d_veh", column: "body_type", op: "eq" },
  },
  "real-estate": {
    viewType: { table: "listing_real_estate", alias: "d_re", column: "view_type", op: "like" },
    isNewBuild: { table: "listing_real_estate", alias: "d_re", column: "is_new_build", op: "bool" },
  },
  watches: {
    dialColor: { table: "listing_timepiece", alias: "d_tp", column: "dial_color", op: "like" },
    isFullSet: { table: "listing_timepiece", alias: "d_tp", column: "is_full_set", op: "bool" },
  },
  yachts: {
    homePort: { table: "listing_marine", alias: "d_mar", column: "home_port", op: "like" },
  },
};

export const SORT_MAP = {
  featured: "ls.is_featured DESC, ls.boost_score DESC, ls.quality_score DESC, ls.published_at DESC, ls.listing_id DESC",
  newest: "ls.published_at DESC, ls.listing_id DESC",
  oldest: "ls.published_at ASC, ls.listing_id ASC",
  priceAsc: "ls.price_base IS NULL, ls.price_base ASC, ls.listing_id DESC",
  priceDesc: "ls.price_base IS NULL, ls.price_base DESC, ls.listing_id DESC",
  "price-asc": "ls.price_base IS NULL, ls.price_base ASC, ls.listing_id DESC",
  "price-desc": "ls.price_base IS NULL, ls.price_base DESC, ls.listing_id DESC",
  relevance: "ls.quality_score DESC, ls.published_at DESC, ls.listing_id DESC",
  popular: "ls.boost_score DESC, ls.quality_score DESC, ls.listing_id DESC",
};

const PURPOSE_SLUGS = { sale: "for-sale", buy: "for-sale", rent: "for-rent", charter: "for-charter", lease: "for-lease", auction: "auction" };

/** Normalises whatever the frontend sent into a validated, typed filter set. */
export function normalizeSearchInput(input = {}) {
  const definition = resolveCategory(input.category || input.listingType);
  const listingType = definition?.listingType || null;

  const locations = asArray(input.location).concat(
    [input.area, input.community, input.city, input.state, input.country].filter(Boolean)
  );

  return {
    definition,
    listingType,
    rootCategoryId: definition?.rootId ?? null,
    categorySlug: cleanString(input.propertyType ?? input.categorySlug ?? input.type, 80),
    purposeSlug: PURPOSE_SLUGS[String(input.transactionType || input.purpose || "").toLowerCase()] || null,
    country: input.country ?? null,
    state: input.state ?? null,
    city: input.city ?? null,
    community: input.area ?? input.community ?? null,
    subCommunity: input.subcommunity ?? input.subCommunity ?? null,
    locations,
    minPrice: toNumber(input.minPrice ?? input.priceMin),
    maxPrice: toNumber(input.maxPrice ?? input.priceMax),
    currency: cleanString(input.currency, 3),
    keyword: cleanString(input.keyword ?? input.q ?? input.search, 120),
    featured: toBool(input.featured),
    verified: toBool(input.verified),
    exclusive: toBool(input.exclusive),
    make: input.make ?? input.brand ?? input.manufacturer ?? null,
    model: input.model ?? input.collection ?? null,
    /**
     * The internal key, and only ever from internal code.
     *
     * `listingSearchQuery` has a `catchall`, so an unrecognised query parameter
     * still reaches here as a string — which meant `?projectId=2` filtered by a
     * raw database id and let anyone walk the table by counting. A query string
     * is always a string; a server-side caller passes the number it already
     * holds. Requiring the number is what makes the distinction unforgeable.
     */
    projectId: typeof input.projectId === "number" ? input.projectId : null,
    // The public spelling: a ULID or slug, resolved against the published
    // projection in the repository. Never a database id from a URL.
    projectRef: cleanString(input.project, 220),
    organizationId: input.organizationId ?? null,
    agentId: input.agentId ?? null,
    bedrooms: asArray(input.bedrooms ?? input.beds).map(toInt).filter((value) => value !== null),
    bathrooms: asArray(input.bathrooms ?? input.baths).map(toInt).filter((value) => value !== null),
    ranges: Object.fromEntries(
      (RANGE_FILTERS[listingType] || []).flatMap((range) => [
        [range.min, toNumber(input[range.min])],
        [range.max, toNumber(input[range.max])],
      ])
    ),
    facets: Object.fromEntries(
      Object.keys(FACET_FILTERS[listingType] || {}).map((key) => [key, cleanString(input[key], 60)])
    ),
    detailFilters: Object.fromEntries(
      Object.keys(DETAIL_FILTERS[listingType] || {}).map((key) => [key, input[key] ?? null])
    ),
    sort: SORT_MAP[input.sort] ? input.sort : "featured",
    rawSort: input.sort || "featured",
  };
}

export { RANGE_FILTERS, FACET_FILTERS, DETAIL_FILTERS };
