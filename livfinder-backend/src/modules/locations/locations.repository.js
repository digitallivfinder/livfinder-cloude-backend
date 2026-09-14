import { query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";

// The frontend's location entity ids are `type:key` strings. `type` is the
// frontend's own vocabulary (subcommunity, not sub_community).
const LEVEL_TO_TYPE = {
  country: "country",
  state: "state",
  city: "city",
  district: "community",
  community: "community",
  sub_community: "subcommunity",
  building: "subcommunity",
};
const TYPE_TO_LEVELS = {
  country: ["country"],
  state: ["state"],
  city: ["city"],
  community: ["community", "district"],
  subcommunity: ["sub_community"],
};

const SELECT_COLUMNS = `
  l.id, l.public_id, l.parent_id, l.level, l.depth, l.name, l.slug, l.path,
  l.country_id, l.state_id, l.city_id, l.community_id,
  l.latitude, l.longitude, l.active_listing_count, l.listing_count, l.is_core_market, l.is_featured,
  co.name AS country_name, co.slug AS country_slug,
  st.name AS state_name,   st.slug AS state_slug,
  ct.name AS city_name,    ct.slug AS city_slug,
  cm.name AS community_name, cm.slug AS community_slug`;

const FROM_CLAUSE = `
  FROM locations l
  LEFT JOIN locations co ON co.id = l.country_id
  LEFT JOIN locations st ON st.id = l.state_id
  LEFT JOIN locations ct ON ct.id = l.city_id
  LEFT JOIN locations cm ON cm.id = l.community_id`;

export function toEntity(row) {
  if (!row) return null;
  const type = LEVEL_TO_TYPE[row.level] || row.level;
  const ancestors = {};
  if (row.country_id) ancestors.country = { id: `country:${row.country_id}`, slug: row.country_slug, label: row.country_name, type: "country" };
  if (row.state_id) ancestors.state = { id: `state:${row.state_id}`, slug: row.state_slug, label: row.state_name, type: "state" };
  if (row.city_id) ancestors.city = { id: `city:${row.city_id}`, slug: row.city_slug, label: row.city_name, type: "city" };
  if (row.community_id) ancestors.community = { id: `community:${row.community_id}`, slug: row.community_slug, label: row.community_name, type: "community" };

  const self = {
    id: `${type}:${row.id}`,
    locationId: Number(row.id),
    publicId: row.public_id,
    slug: row.slug,
    label: row.name,
    name: row.name,
    type,
    level: row.level,
    depth: Number(row.depth),
    parentId: row.parent_id ? entityIdForParent(row) : null,
    latitude: row.latitude === null ? null : Number(row.latitude),
    longitude: row.longitude === null ? null : Number(row.longitude),
    // The category-scoped count when the caller asked for one; the catalogue-wide rollup
    // otherwise, which is all a category-agnostic caller can mean.
    listingCount: Number(
      row.category_listing_count ?? row.active_listing_count ?? 0
    ),
    isCoreMarket: row.is_core_market === 1,
  };
  ancestors[type] = self;
  const secondary = [ancestors.community, ancestors.city, ancestors.state, ancestors.country]
    .filter((ancestor) => ancestor && ancestor.id !== self.id)
    .map((ancestor) => ancestor.label)
    .join(", ");

  return { ...self, value: self.id, ancestors, secondaryLabel: secondary || null, path: ancestors };
}

function entityIdForParent(row) {
  // The parent's level is one step up the chain the row already carries.
  const order = ["country", "state", "city", "community"];
  const ownIndex = order.indexOf(LEVEL_TO_TYPE[row.level]);
  for (let index = ownIndex - 1; index >= 0; index -= 1) {
    const key = order[index];
    const id = row[`${key === "community" ? "community" : key}_id`];
    if (id && String(id) !== String(row.id)) return `${key}:${id}`;
  }
  return null;
}

/** Accepts `country:1231`, a numeric id, or a slug (optionally with a level). */
export async function resolveLocation(value, { type } = {}) {
  if (value === null || value === undefined || value === "") return null;
  const raw = String(value).trim();

  const typed = /^([a-z_]+):(\d+)$/.exec(raw);
  if (typed) {
    return queryOne(`SELECT ${SELECT_COLUMNS} ${FROM_CLAUSE} WHERE l.id = ? AND l.deleted_at IS NULL`, [Number(typed[2])]);
  }
  if (/^\d+$/.test(raw)) {
    return queryOne(`SELECT ${SELECT_COLUMNS} ${FROM_CLAUSE} WHERE l.id = ? AND l.deleted_at IS NULL`, [Number(raw)]);
  }

  const levels = type ? TYPE_TO_LEVELS[type] : null;
  const params = [raw];
  let levelFilter = "";
  if (levels?.length) {
    levelFilter = ` AND l.level IN (${levels.map(() => "?").join(", ")})`;
    params.push(...levels);
  }
  // Slugs are unique per level in practice but not globally; prefer the shallower
  // and busier match so `/real-estate/dubai` resolves to the emirate, not a
  // same-named community somewhere else.
  return queryOne(
    `SELECT ${SELECT_COLUMNS} ${FROM_CLAUSE}
      WHERE l.slug = ? AND l.deleted_at IS NULL AND l.status = 'active'${levelFilter}
      ORDER BY l.depth ASC, l.active_listing_count DESC, l.id ASC
      LIMIT 1`,
    params
  );
}

export async function getLocationById(id) {
  return queryOne(`SELECT ${SELECT_COLUMNS} ${FROM_CLAUSE} WHERE l.id = ? AND l.deleted_at IS NULL`, [Number(id)]);
}

/**
 * Typeahead over 161k rows. Never returns the whole tree: the caller supplies a
 * query or a parent, and the limit is capped.
 */
export async function searchLocations({ q, types = [], parentId = null, countryId = null, preferCountryId = null, categoryRootId = null, limit = 20, onlyWithListings = false } = {}) {
  const conditions = ["l.deleted_at IS NULL", "l.status = 'active'", "l.is_searchable = 1"];
  const params = [];

  const levels = types.flatMap((type) => TYPE_TO_LEVELS[type] || [type]);
  if (levels.length) {
    conditions.push(`l.level IN (${levels.map(() => "?").join(", ")})`);
    params.push(...levels);
  }
  if (parentId) {
    conditions.push("l.parent_id = ?");
    params.push(Number(parentId));
  }
  if (countryId) {
    conditions.push("l.country_id = ?");
    params.push(Number(countryId));
  }
  if (onlyWithListings) conditions.push("l.active_listing_count > 0");

  let ranking = "l.active_listing_count DESC, l.is_core_market DESC, l.depth ASC, l.name ASC";
  if (q) {
    // Prefix match first so "Dub" surfaces Dubai above "Old Dubai Road".
    conditions.push("(l.slug LIKE ? OR l.name LIKE ? OR l.name_ascii LIKE ?)");
    params.push(`${q}%`, `${q}%`, `${q}%`);
    ranking = "l.active_listing_count DESC, l.is_core_market DESC, CHAR_LENGTH(l.name) ASC, l.name ASC";
  }

  const safeLimit = Math.min(50, Math.max(1, Number(limit) || 20));

  /**
   * Listing counts for the category being browsed, not the catalogue-wide rollup.
   *
   * `locations.active_listing_count` counts every category at once, so the location menu offered
   * "Dubai 46" while the real-estate list held 20 — and offered places like Palm Jumeirah, which
   * has no listings at all, so picking one returned an empty page and read as a broken control.
   *
   * A listing records its whole ancestor chain, so one pass over the projection — 308 rows —
   * gives every location its own total at whatever tier it sits. Cheap enough to join per query,
   * and it doubles as the filter that keeps empty places out of the menu.
   */
  let fromClause = FROM_CLAUSE;
  let selectColumns = `${SELECT_COLUMNS}, NULL AS category_listing_count`;
  const joinParams = [];
  if (categoryRootId) {
    const tiers = ["country_id", "state_id", "city_id", "community_id", "sub_community_id"];
    const union = tiers
      .map((tier) => `SELECT ${tier} AS location_id FROM listing_search WHERE root_category_id = ? AND ${tier} IS NOT NULL`)
      .join(" UNION ALL ");
    fromClause = `${FROM_CLAUSE}
  JOIN (SELECT location_id, COUNT(*) AS n FROM (${union}) tiers GROUP BY location_id) lc ON lc.location_id = l.id`;
    selectColumns = `${SELECT_COLUMNS}, lc.n AS category_listing_count`;
    joinParams.push(...tiers.map(() => Number(categoryRootId)));
    // An inner join is the filter: a location with nothing in this category is not offered,
    // because selecting it could only ever produce an empty result set.
    ranking = ranking.replace("l.active_listing_count DESC", "lc.n DESC");
  }

  const run = async (extraCondition, extraParams, rowLimit) =>
    query(
      `SELECT ${selectColumns} ${fromClause}
        WHERE ${[...conditions, ...(extraCondition ? [extraCondition] : [])].join(" AND ")}
        ORDER BY ${ranking}
        LIMIT ${rowLimit}`,
      [...joinParams, ...params, ...extraParams]
    );

  /**
   * The selected country comes first, but never takes the whole list.
   *
   * `countryId` is a hard filter — "locations in this country". `preferCountryId` is a
   * preference, and sorting alone was not enough to honour it: ordering by `country_id = ?` put
   * the United States first for "Palm", and the United States has more than thirty matches, so
   * Palma and Palm Jumeirah fell off the end entirely — preferred in effect meant exclusive.
   *
   * Two bounded reads instead, so the rest of the world keeps a guaranteed share of the list:
   * roughly two thirds to the chosen country, the remainder to everywhere else, and any slots
   * the chosen country cannot fill are handed back. Disjoint by country, so no de-duplication.
   */
  if (preferCountryId) {
    const preferredShare = Math.max(1, Math.ceil(safeLimit * 0.6));
    const preferred = await run("l.country_id = ?", [Number(preferCountryId)], preferredShare);
    const remaining = safeLimit - preferred.length;
    if (remaining <= 0) return preferred.map(toEntity);
    const others = await run("(l.country_id IS NULL OR l.country_id <> ?)", [Number(preferCountryId)], remaining);
    return [...preferred, ...others].map(toEntity);
  }

  const rows = await run(null, [], safeLimit);
  return rows.map(toEntity);
}

/** Wider search used when a prefix match returns too little. */
export async function searchLocationsContains({ q, types = [], limit = 20 }) {
  if (!q) return [];
  const levels = types.flatMap((type) => TYPE_TO_LEVELS[type] || [type]);
  const params = [`%${q}%`, `%${q}%`];
  let levelFilter = "";
  if (levels.length) {
    levelFilter = ` AND l.level IN (${levels.map(() => "?").join(", ")})`;
    params.push(...levels);
  }
  const safeLimit = Math.min(50, Math.max(1, Number(limit) || 20));
  const rows = await query(
    `SELECT ${SELECT_COLUMNS} ${FROM_CLAUSE}
      WHERE l.deleted_at IS NULL AND l.status = 'active' AND l.is_searchable = 1
        AND (l.name LIKE ? OR l.name_ascii LIKE ?)${levelFilter}
      ORDER BY l.active_listing_count DESC, l.is_core_market DESC, CHAR_LENGTH(l.name) ASC
      LIMIT ${safeLimit}`,
    params
  );
  return rows.map(toEntity);
}

/**
 * Walks a `/real-estate/{country}/{state}/{city}/…` path, checking at each step
 * that the child really sits under the parent. A city that belongs to another
 * state is a 404, not a silent match.
 */
export async function resolveLocationPath(segments = []) {
  const order = ["country", "state", "city", "community", "subcommunity"];
  const entities = [];
  let parent = null;

  for (const [index, slug] of segments.entries()) {
    const type = order[index];
    if (!type) return { valid: false, entities };
    const levels = TYPE_TO_LEVELS[type];
    const params = [slug, ...levels];
    let parentClause = "";
    if (parent) {
      parentClause = " AND l.parent_id = ?";
      params.push(parent.id);
    } else if (index > 0) {
      return { valid: false, entities };
    }
    const row = await queryOne(
      `SELECT ${SELECT_COLUMNS} ${FROM_CLAUSE}
        WHERE l.slug = ? AND l.level IN (${levels.map(() => "?").join(", ")})
          AND l.deleted_at IS NULL AND l.status = 'active'${parentClause}
        ORDER BY l.active_listing_count DESC, l.id ASC
        LIMIT 1`,
      params
    );
    if (!row) return { valid: false, entities };
    entities.push(toEntity(row));
    parent = row;
  }
  return { valid: true, entities, labels: entities.map((entity) => entity.label) };
}

export async function listCountries({ onlyWithListings = true, limit = 250 } = {}) {
  const safeLimit = Math.min(250, Math.max(1, Number(limit) || 250));
  return query(
    `SELECT ${SELECT_COLUMNS} ${FROM_CLAUSE}
      WHERE l.level = 'country' AND l.deleted_at IS NULL AND l.status = 'active'
        ${onlyWithListings ? "AND l.active_listing_count > 0" : ""}
      ORDER BY l.active_listing_count DESC, l.name ASC
      LIMIT ${safeLimit}`,
    []
  );
}

export async function listChildren(parentId, { limit = 100, q = null } = {}) {
  const safeLimit = Math.min(500, Math.max(1, Number(limit) || 100));
  const params = [Number(parentId)];
  let search = "";
  let ranking = "l.active_listing_count DESC, l.name ASC";
  if (q) {
    // One parent's children can outrun a page — a state holds up to 1,757 cities — so a
    // picker narrows within the parent. Contains rather than prefix, since the set is
    // already small, with prefix matches first so "Dub" lists Dubai before Old Dubai Road.
    const like = String(q).replace(/[\\%_]/g, "\\$&");
    search = " AND (l.name LIKE ? OR l.name_ascii LIKE ?)";
    params.push(`%${like}%`, `%${like}%`, `${like}%`);
    ranking = `CASE WHEN l.name LIKE ? THEN 0 ELSE 1 END, ${ranking}`;
  }
  return query(
    `SELECT ${SELECT_COLUMNS} ${FROM_CLAUSE}
      WHERE l.parent_id = ? AND l.deleted_at IS NULL AND l.status = 'active'${search}
      ORDER BY ${ranking}
      LIMIT ${safeLimit}`,
    params
  );
}

export async function requireLocation(value, options) {
  const row = await resolveLocation(value, options);
  if (!row) throw AppError.notFound("That location could not be found.");
  return row;
}

export { LEVEL_TO_TYPE, TYPE_TO_LEVELS, SELECT_COLUMNS, FROM_CLAUSE };

/**
 * ISO 3166-1 alpha-2 country code → the seeded country row.
 *
 * The edge tells us the visitor is in "AE"; the catalogue knows countries only by name and slug —
 * `locations` carries no ISO column, and `meta` is NULL on all 250 rows. Rather than a migration
 * or a hand-maintained 250-entry table that would drift from the seed data, the map is derived
 * once from ICU's own region names (`Intl.DisplayNames`, which ships with Node) and reconciled
 * against whatever countries are actually in the database.
 *
 * Three passes, because ICU and the seed data do not always agree on a name:
 *   1. exact slug          — "ES" → "Spain" → `spain`
 *   2. `&` spelled out     — "TC" → "Turks & Caicos Islands" → `turks-and-caicos-islands`
 *   3. leading-words match — "HK" → "Hong Kong SAR China" matches the seeded "Hong Kong S.A.R."
 * Anything still unresolved simply has no mapping, and the caller falls back to the country with
 * the most listings — a wrong guess is never shown.
 */
let countryCodeMapPromise = null;

const slugifyName = (value) =>
  String(value)
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");

/**
 * Where ICU's region name and the seeded name disagree beyond what the passes below can bridge.
 *
 * ICU renamed TR to "Türkiye" in CLDR 42; the catalogue seeds it as "Turkey", and the two share
 * only a prefix, so no amount of normalising connects them. Keyed by ISO code and checked against
 * the database, so an entry for a country that is not seeded simply does nothing.
 */
const COUNTRY_CODE_ALIASES = { TR: "turkey" };

async function buildCountryCodeMap() {
  const rows = await query(
    `SELECT id, slug, name FROM locations
      WHERE level = 'country' AND deleted_at IS NULL AND status = 'active'`
  );
  const bySlug = new Map(rows.map((row) => [row.slug, row]));
  // "hong kong s a r" → row, so a leading-words comparison can find it.
  const byWords = rows.map((row) => ({ row, words: slugifyName(row.name).split("-").filter(Boolean) }));

  let display;
  try {
    display = new Intl.DisplayNames(["en"], { type: "region" });
  } catch {
    return new Map();
  }

  const map = new Map();
  for (let first = 65; first <= 90; first += 1) {
    for (let second = 65; second <= 90; second += 1) {
      const code = String.fromCharCode(first) + String.fromCharCode(second);

      const alias = COUNTRY_CODE_ALIASES[code] && bySlug.get(COUNTRY_CODE_ALIASES[code]);
      if (alias) {
        map.set(code, alias);
        continue;
      }

      let name;
      try {
        name = display.of(code);
      } catch {
        continue;
      }
      // ICU echoes the code back for anything it does not recognise.
      if (!name || name === code) continue;

      const slug = slugifyName(name);
      const exact = bySlug.get(slug);
      if (exact) {
        map.set(code, exact);
        continue;
      }
      // "Hong Kong SAR China" vs "Hong Kong S.A.R." — agree on the leading words, differ after.
      const words = slug.split("-").filter(Boolean);
      const prefixed = byWords.filter(
        (entry) => entry.words.length >= 2 && entry.words[0] === words[0] && entry.words[1] === words[1]
      );
      if (prefixed.length === 1) map.set(code, prefixed[0].row);
    }
  }
  return map;
}

/** Returns the country row for an ISO alpha-2 code, or null when it cannot be resolved. */
export async function resolveCountryByCode(code) {
  const normalized = String(code || "").trim().toUpperCase();
  if (!/^[A-Z]{2}$/.test(normalized)) return null;
  if (!countryCodeMapPromise) {
    countryCodeMapPromise = buildCountryCodeMap().catch((error) => {
      // Never cache a failure: the next request should be able to try again.
      countryCodeMapPromise = null;
      throw error;
    });
  }
  const map = await countryCodeMapPromise;
  return map.get(normalized) || null;
}
