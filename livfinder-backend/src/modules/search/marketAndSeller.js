/**
 * Real estate's Market and Listed by filters, shared by the search and by the options the
 * website's menus offer, so the two can never disagree.
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
export function sellerTypeOptions(enumValues) {
  const known = Object.keys(SELLER_TYPE_COPY).filter((value) => enumValues.includes(value));
  const rest = enumValues.filter((value) => !SELLER_TYPE_COPY[value]);
  return [...known, ...rest].map((value) => ({
    id: `listedBy:${value}`,
    value,
    slug: value,
    label: SELLER_TYPE_COPY[value]?.label || String(value).replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase()),
    hint: SELLER_TYPE_COPY[value]?.hint || null,
    type: "listedBy",
  }));
}
