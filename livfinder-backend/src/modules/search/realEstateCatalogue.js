/**
 * Real estate types and amenities follow Property Finder's lists (owner decision, 2026-11-23;
 * migration 0083). The lists themselves live in the database (`categories`, `features` +
 * `category_features`); this module holds only what turns other people's words into them:
 *
 * - the codes LivFinder used before 0083, so an older feed, API client or pending edit still
 *   resolves (`plot` → `land`, `mansion` → `villa` …);
 * - Property Finder's own two-letter codes, which feeds in PF's XML format send;
 * - `offered_for`: the purposes a type is offered for in each segment, where PF narrows it.
 */

/** Pre-0083 property type codes and slugs → the type that replaced them. */
export const LEGACY_TYPE_CODES = Object.freeze({
  plot: "land",
  plots: "land",
  "industrial-land": "land",
  island: "land",
  islands: "land",
  "private-island": "land",
  vineyard: "land",
  vineyards: "land",
  mansion: "villa",
  mansions: "villa",
  estate: "villa",
  estates: "villa",
  chalet: "villa",
  chalets: "villa",
  office: "office-space",
  offices: "office-space",
  showroom: "show-room",
  showrooms: "show-room",
  "labour-camp": "labor-camp",
  "labour-camps": "labor-camp",
  "bulk-unit": "bulk-sale-unit",
  "bulk-units": "bulk-sale-unit",
  "commercial-floor": "full-floor",
  "commercial-floors": "full-floor",
  "hotel-apartments": "hotel-apartment",
  "hotel-hotel-apartment": "hotel-apartment",
});

/** Pre-0083 type slugs (the URLs and saved searches use slugs) → the slug that replaced them. */
export const LEGACY_TYPE_SLUGS = Object.freeze({
  plots: "land",
  "industrial-land": "land",
  islands: "land",
  vineyards: "land",
  mansions: "villas",
  estates: "villas",
  chalets: "villas",
  offices: "office-spaces",
  showrooms: "show-rooms",
  "labour-camps": "labor-camps",
  "bulk-units": "bulk-sale-units",
  "commercial-floors": "full-floors",
});

/** A real-estate type slug from a URL or saved search → the current slug. */
export function currentTypeSlug(slug) {
  if (!slug) return slug;
  return LEGACY_TYPE_SLUGS[String(slug).trim().toLowerCase()] || slug;
}

/** Real-estate amenity slugs from a URL or saved search → PF's (sea-view → view-of-water …). */
export function currentAmenitySlugs(slugs) {
  return [...new Set((slugs || []).map((slug) => AMENITY_ALIASES[slug] || slug))];
}

/** Types that come in a sale and a rent version on PF; the purpose picks the right one. */
const RENT_VERSION = Object.freeze({ "bulk-sale-unit": "bulk-rent-unit" });
const SALE_VERSION = Object.freeze({ "bulk-rent-unit": "bulk-sale-unit" });

/** Property Finder's XML property type codes → LivFinder type codes. */
export const PF_TYPE_CODES = Object.freeze({
  AP: "apartment",
  VH: "villa",
  TH: "townhouse",
  PH: "penthouse",
  CD: "compound",
  DX: "duplex",
  FF: "full-floor",
  HF: "half-floor",
  WB: "whole-building",
  LP: "land",
  BU: "bulk-sale-unit",
  BW: "bungalow",
  HA: "hotel-apartment",
  OF: "office-space",
  RE: "retail",
  WH: "warehouse",
  SH: "shop",
  SR: "show-room",
  FA: "factory",
  LC: "labor-camp",
  SA: "staff-accommodation",
  BC: "business-centre",
  CW: "co-working-space",
  FM: "farm",
});

/**
 * A type code as sent → the current code, before it is looked up. Unknown words pass through
 * unchanged (the lookup also matches names and slugs, and reports what it cannot place).
 */
export function currentTypeCode(value, purpose = null) {
  if (value === null || value === undefined || value === "") return value;
  const text = String(value).trim();
  const key = text.toLowerCase().replace(/[\s_]+/g, "-");
  let code = LEGACY_TYPE_CODES[key] || PF_TYPE_CODES[text.toUpperCase()] || null;
  if (!code) return text;
  if (purpose === "rent" && RENT_VERSION[code]) code = RENT_VERSION[code];
  if (purpose === "sale" && SALE_VERSION[code]) code = SALE_VERSION[code];
  return code;
}

/**
 * Types that became "both" in 0083 but belonged to one segment before: a listing that does not
 * say keeps the segment it would have had, so API clients and feeds written before 0083 still
 * work. Land and Whole Building were already "both" and still need the segment said.
 */
export const DEFAULT_SEGMENT_FOR_BOTH = Object.freeze({
  villa: "residential",
  "hotel-apartment": "residential",
  "full-floor": "commercial",
  "half-floor": "commercial",
  "bulk-sale-unit": "commercial",
  "bulk-rent-unit": "commercial",
});

/** `categories.offered_for` as an object, or null (no narrowing). */
export function parseOfferedFor(value) {
  if (!value) return null;
  if (typeof value === "object") return value;
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

/**
 * Whether a type may be listed for `purpose` in `segment`. A type with no `offered_for` is
 * offered for every purpose in each segment it belongs to.
 */
export function typeOfferedFor(offeredFor, segment, purpose) {
  const rules = parseOfferedFor(offeredFor);
  if (!rules || !purpose) return true;
  if (segment) return Array.isArray(rules[segment]) && rules[segment].includes(purpose);
  return Object.values(rules).some((purposes) => Array.isArray(purposes) && purposes.includes(purpose));
}

/** The SQL condition for "offered for this purpose (in this segment)", on `categories` alias `c`. */
export function offeredForCondition({ segment = null, purpose = null, alias = "c" } = {}) {
  if (!purpose) return null;
  if (segment) {
    return {
      sql: `(${alias}.offered_for IS NULL OR JSON_CONTAINS(JSON_EXTRACT(${alias}.offered_for, ?), JSON_QUOTE(?)))`,
      params: [`$.${segment}`, purpose],
    };
  }
  // No segment: offered for the purpose in at least one segment.
  return {
    sql: `(${alias}.offered_for IS NULL OR JSON_SEARCH(${alias}.offered_for, 'one', ?) IS NOT NULL)`,
    params: [purpose],
  };
}

/** Purposes spelled the way feeds and forms send them → `sale` / `rent`. */
export function normalizePurpose(value) {
  const text = String(value ?? "").trim().toLowerCase();
  if (!text) return null;
  if (["rent", "rental", "lease", "to-rent", "for-rent", "rr", "cr"].includes(text)) return "rent";
  if (["sale", "buy", "sell", "for-sale", "rs", "cs"].includes(text)) return "sale";
  return text;
}

/**
 * Amenity words other systems send → the PF amenity slug. PF's two-letter codes, the names
 * LivFinder used before 0083 that 0083 merged into a PF amenity, and common spellings.
 * Anything else is not one of ours: the listing is kept and the push reports it.
 */
export const AMENITY_ALIASES = Object.freeze({
  // Property Finder codes
  AC: "central-a-c",
  MR: "maids-room",
  BA: "balcony",
  SP: "shared-pool",
  SS: "shared-spa",
  SY: "shared-gym",
  CS: "concierge-service",
  CP: "covered-parking",
  VW: "view-of-water",
  BL: "view-of-landmark",
  PA: "pets-allowed",
  ST: "study",
  PG: "private-garden",
  PP: "private-pool",
  PY: "private-gym",
  PJ: "private-jacuzzi",
  BW: "built-in-wardrobes",
  WC: "walk-in-closet",
  BK: "built-in-kitchen-appliances",
  MS: "maid-service",
  PR: "childrens-play-area",
  CO: "childrens-pool",
  BR: "barbecue-area",
  // Earlier LivFinder names and common spellings
  "central-ac": "central-a-c",
  "central-air-conditioning": "central-a-c",
  "air-conditioning": "central-a-c",
  "maid-s-room": "maids-room",
  "maid-room": "maids-room",
  terrace: "balcony",
  "balcony-terrace": "balcony",
  "swimming-pool": "shared-pool",
  "infinity-pool": "shared-pool",
  pool: "shared-pool",
  spa: "shared-spa",
  sauna: "shared-spa",
  "steam-room": "shared-spa",
  gym: "shared-gym",
  gymnasium: "shared-gym",
  concierge: "concierge-service",
  "manned-reception": "concierge-service",
  "concierge-security": "concierge-service",
  "basement-parking": "covered-parking",
  parking: "covered-parking",
  "sea-view": "view-of-water",
  "marina-view": "view-of-water",
  "lake-view": "view-of-water",
  beachfront: "view-of-water",
  "water-view": "view-of-water",
  "burj-khalifa-view": "view-of-landmark",
  "landmark-view": "view-of-landmark",
  "pet-friendly": "pets-allowed",
  "pets-allowed": "pets-allowed",
  "study-home-office": "study",
  "study-room": "study",
  jacuzzi: "private-jacuzzi",
  "built-in-wardrobe": "built-in-wardrobes",
  wardrobes: "built-in-wardrobes",
  "kitchen-appliances": "built-in-kitchen-appliances",
  "fitted-kitchen-appliances": "built-in-kitchen-appliances",
  housekeeping: "maid-service",
  "kids-play-area": "childrens-play-area",
  "children-s-play-area": "childrens-play-area",
  "play-area": "childrens-play-area",
  "kids-pool": "childrens-pool",
  "children-s-pool": "childrens-pool",
  "bbq-area": "barbecue-area",
  bbq: "barbecue-area",
  "barbeque-area": "barbecue-area",
});

/** An amenity word → the slug to look up (an alias when one is known, else its own slug). */
export function amenityLookupSlug(value, slugify) {
  const text = String(value ?? "").trim();
  if (!text) return null;
  const upper = text.toUpperCase();
  if (/^[A-Z]{2}$/.test(upper) && AMENITY_ALIASES[upper]) return AMENITY_ALIASES[upper];
  const slug = slugify(text);
  return AMENITY_ALIASES[slug] || slug;
}
