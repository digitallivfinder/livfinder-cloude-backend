/**
 * Real estate's Market and Listed by filters (Listed by also for Cars), and Cars' Condition
 * toggle, shared by the search and by the options the website's menus offer, so the two can
 * never disagree.
 *
 * Market — first-hand or not — is the listing's own `listing_real_estate.is_new_build` flag:
 * New Launch is a new build, Resale is everything else.
 *
 * Listed by is the seller account behind the listing: `accounts.seller_type` (0079) — a
 * Developer, a Company (an agency or brokerage) or an Individual (the owner). The menu's options
 * are that ENUM's values, so a seller type added later appears without a code change; the
 * labels below only rename the known ones the way buyers say them.
 */

/** In the order the menu lists them: Resale before New Launch. */
export const MARKETS = {
  resale: { label: "Resale", isNewBuild: 0 },
  new_launch: { label: "New Launch", isNewBuild: 1 },
};

export const MARKET_OPTIONS = Object.entries(MARKETS).map(([value, { label }]) => ({
  id: `market:${value}`,
  value,
  slug: value,
  label,
  type: "market",
}));

/** How the website names each seller type, in the order the menu lists them. */
export const SELLER_TYPE_COPY = {
  developer: { label: "Developer", hint: "New launches" },
  company: { label: "Agency", hint: "Brokers" },
  individual: { label: "Owner", hint: "Direct from owner" },
};

/**
 * Listed by in the other marketplaces (2026-11-23, Cars first): the same `accounts.seller_type`,
 * named the way that marketplace says it. Only the types listed are offered or searched; a
 * Developer sells new launches, so it belongs to real estate alone. A marketplace with no entry
 * here has no Listed by yet.
 */
export const SELLER_TYPE_COPY_BY_CATEGORY = {
  "real-estate": SELLER_TYPE_COPY,
  cars: {
    company: { label: "Dealer", hint: "Showrooms & dealers" },
    individual: { label: "Private seller", hint: "Direct from owner" },
  },
  yachts: {
    company: { label: "Broker", hint: "Yacht brokers & dealers" },
    individual: { label: "Private owner", hint: "Direct from owner" },
  },
  jets: {
    company: { label: "Broker", hint: "Aircraft brokers & dealers" },
    individual: { label: "Private owner", hint: "Direct from owner" },
  },
  helicopters: {
    company: { label: "Broker", hint: "Aircraft brokers & dealers" },
    individual: { label: "Private owner", hint: "Direct from owner" },
  },
  watches: {
    company: { label: "Dealer", hint: "Watch dealers & boutiques" },
    individual: { label: "Private seller", hint: "Direct from owner" },
  },
};

/** Whether `listingType` offers Listed by. */
export function hasListedBy(listingType) {
  return Object.prototype.hasOwnProperty.call(SELLER_TYPE_COPY_BY_CATEGORY, listingType);
}

/** Listed by values `listingType` searches on: real estate takes any ENUM-shaped value, the rest only their own. */
export function sellerTypesFor(listingType, types) {
  if (!hasListedBy(listingType)) return [];
  if (listingType === "real-estate") return types || [];
  return (types || []).filter((type) => SELLER_TYPE_COPY_BY_CATEGORY[listingType][type]);
}

/**
 * Cars' Condition toggle, in its order (owner, 2026-11-23): New, Used, Certified pre-owned. Fixed
 * rather than counted, so the toggle never reorders or loses a choice as stock changes. The other
 * `condition_type` values (classic, restored …) are still stored and searchable by value.
 */
export const CAR_CONDITION_OPTIONS = [
  ["new", "New"],
  ["used", "Used"],
  ["certified_pre_owned", "Certified pre-owned"],
].map(([value, label]) => ({ id: `condition:${value}`, value, slug: value, label, type: "condition" }));

/**
 * Yachts' Type toggle (owner, 2026-11-25): Motor, Sailing, Catamaran, Superyacht, from
 * `listing_marine.vessel_type`. Fixed, like cars' Condition. Superyacht also finds the mega yachts
 * (a mega yacht is a superyacht by size); the other vessel types stay searchable by value.
 */
export const YACHT_TYPE_OPTIONS = [
  ["motor_yacht", "Motor"],
  ["sailing_yacht", "Sailing"],
  ["catamaran", "Catamaran"],
  ["superyacht", "Superyacht"],
].map(([value, label]) => ({ id: `yachtType:${value}`, value, slug: value, label, type: "yachtType" }));

/** The stored vessel types a Type choice finds. */
export function yachtTypeValues(value) {
  return value === "superyacht" ? ["superyacht", "mega_yacht"] : [value];
}

/**
 * Aircraft Size toggles (owner, 2026-11-25), each grouping the stored `aircraft_type` values.
 * Jets: Light, Midsize, Heavy, Ultra long range; a turboprop is in none and shows under All.
 * Helicopters: Light, Medium, Heavy.
 */
const AIRCRAFT_SIZES = {
  jets: [
    ["light", "Light", ["very_light_jet", "light_jet"]],
    ["midsize", "Midsize", ["midsize_jet", "super_midsize_jet"]],
    ["heavy", "Heavy", ["heavy_jet", "vip_airliner"]],
    ["ultra_long_range", "Ultra long range", ["ultra_long_range"]],
  ],
  helicopters: [
    ["light", "Light", ["light_helicopter"]],
    ["medium", "Medium", ["medium_helicopter"]],
    ["heavy", "Heavy", ["heavy_helicopter"]],
  ],
};

/** `listingType`'s Size options, or none. */
export function aircraftSizeOptions(listingType) {
  return (AIRCRAFT_SIZES[listingType] || []).map(([value, label]) => ({ id: `size:${value}`, value, slug: value, label, type: "size" }));
}

/** The stored aircraft types a Size choice finds (none for an unknown size). */
export function aircraftSizeTypes(listingType, size) {
  return (AIRCRAFT_SIZES[listingType] || []).find(([value]) => value === size)?.[2] || [];
}

/**
 * Watches' middle row and pills (owner, 2026-11-25), fixed here rather than read from listings.
 *
 * Condition groups `listing_timepiece.condition_grade`: Unworn = new or unworn; Pre-owned = every
 * worn grade and restored. Full set is `is_full_set`. Gender names `gender`'s values. Case
 * material is free text on the listing, so each choice matches the words sellers write for it
 * ("18k rose gold", "Everose").
 */
const WATCH_CONDITIONS = [
  ["unworn", "Unworn", ["new", "unworn"]],
  ["pre_owned", "Pre-owned", ["excellent", "very_good", "good", "fair", "restored"]],
];
export const WATCH_CONDITION_OPTIONS = WATCH_CONDITIONS.map(([value, label]) => ({ id: `condition:${value}`, value, slug: value, label, type: "condition" }));

/** The stored condition grades a watch Condition choice finds (an older single grade finds itself). */
export function watchConditionGrades(value) {
  return WATCH_CONDITIONS.find(([key]) => key === value)?.[2] || [value];
}

export const WATCH_FULL_SET_OPTIONS = [{ id: "isFullSet:true", value: "true", slug: "true", label: "Full set", type: "isFullSet" }];

const GENDER_LABELS = { mens: "Men's", ladies: "Women's", unisex: "Unisex" };
/** Gender's options from the ENUM's values, named the way buyers say them. */
export function watchGenderOptions(enumValues) {
  return enumValues.map((value) => ({ id: `gender:${value}`, value, slug: value, label: GENDER_LABELS[value] || value, type: "gender" }));
}

export const WATCH_CASE_MATERIALS = {
  steel: { label: "Steel", words: ["steel"] },
  yellow_gold: { label: "Yellow gold", words: ["yellow gold"] },
  rose_gold: { label: "Rose gold", words: ["rose gold", "pink gold", "red gold", "everose", "sedna"] },
  white_gold: { label: "White gold", words: ["white gold"] },
  platinum: { label: "Platinum", words: ["platinum"] },
  titanium: { label: "Titanium", words: ["titanium"] },
  ceramic: { label: "Ceramic", words: ["ceramic"] },
  carbon: { label: "Carbon", words: ["carbon"] },
};
export const WATCH_CASE_MATERIAL_OPTIONS = Object.entries(WATCH_CASE_MATERIALS).map(([value, { label }]) => ({ id: `caseMaterial:${value}`, value, slug: value, label, type: "caseMaterial" }));

/** The words a case material choice matches; an unknown value matches itself. */
export function caseMaterialWords(value) {
  return WATCH_CASE_MATERIALS[value]?.words || [String(value).replace(/_/g, " ")];
}

export function isMarket(value) {
  return Object.prototype.hasOwnProperty.call(MARKETS, value);
}

/** `market` → the SQL that keeps only that market's listings, or null for none / unknown. */
export function marketCondition(market) {
  if (!isMarket(market)) return null;
  return {
    sql: "EXISTS (SELECT 1 FROM listing_real_estate d_mkt WHERE d_mkt.listing_id = ls.listing_id AND d_mkt.is_new_build = ?)",
    params: [MARKETS[market].isNewBuild],
  };
}

/** Seller type values from a query string: lower-case ENUM-shaped words, at most five. */
export function parseSellerTypes(values) {
  return [...new Set(values.map((value) => String(value).trim().toLowerCase()))]
    .filter((value) => /^[a-z][a-z_]{0,39}$/.test(value))
    .slice(0, 5);
}

/** Listed by → the SQL that keeps listings whose seller account is one of `types`. */
export function sellerTypeCondition(types) {
  if (!types?.length) return null;
  return {
    sql: `EXISTS (SELECT 1 FROM listings l_seller JOIN accounts a_seller ON a_seller.id = l_seller.account_id
                   WHERE l_seller.id = ls.listing_id AND a_seller.seller_type IN (${types.map(() => "?").join(", ")}))`,
    params: [...types],
  };
}

/**
 * The Listed by options from the ENUM's values: the known ones first, in the menu's order and
 * with their buyer-facing names, then any newer value with its own name.
 */
export function sellerTypeOptions(enumValues, listingType = "real-estate") {
  const copy = SELLER_TYPE_COPY_BY_CATEGORY[listingType];
  if (!copy) return [];
  const known = Object.keys(copy).filter((value) => enumValues.includes(value));
  // Real estate also lists a seller type added later; the other marketplaces only their own.
  const rest = listingType === "real-estate" ? enumValues.filter((value) => !copy[value]) : [];
  return [...known, ...rest].map((value) => ({
    id: `listedBy:${value}`,
    value,
    slug: value,
    label: copy[value]?.label || String(value).replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase()),
    hint: copy[value]?.hint || null,
    type: "listedBy",
  }));
}
