import { query } from "../../db/query.js";
import { csvList } from "../../utils/columnFilters.js";
import { rootIdFor } from "./admin.shared.js";
import { getLocationsByIds, searchLocations, searchLocationsContains } from "../locations/locations.repository.js";

/**
 * Search-as-you-type options for the admin table header filters.
 *
 * Every kind answers `{ value, label, description, image }` — the value the matching list filter
 * reads, the name, one line of context (a location's path, an agent's company…) and a logo or
 * photo. `q` searches anywhere in the name; with no `q` the first records by name come back.
 * `ids` instead returns those records, so a filter applied from a link still shows names.
 *
 * Options are never worked out from listings (which owners, makes or places happen to have one).
 * `category` (a category slug) narrows a list by how a record is tied to that category itself:
 * - companies and individual sellers: their account's approved access to the category
 *   (`account_category_access`);
 * - agents: their company's approved access, or the category among their own specialties;
 * - makes / builders / manufacturers / developers: the brand kind the category uses (and, for
 *   aircraft, the segment: jets are fixed-wing, helicopters rotorcraft).
 * Places are offered whole, whatever the category. `ids` lookups ignore the category, so a chosen
 * value always shows its name.
 */
const LIMIT = 30;
const like = (q) => `%${q}%`;
const placeholders = (list) => list.map(() => "?").join(", ");

/** Each category's brands (`brands.kind`, and `aircraft_segment` where two categories share a kind). */
const BRANDS_BY_CATEGORY = Object.freeze({
  cars: { kind: "car_make" },
  yachts: { kind: "yacht_builder" },
  jets: { kind: "aircraft_manufacturer", segment: "fixed_wing" },
  helicopters: { kind: "aircraft_manufacturer", segment: "rotorcraft" },
  watches: { kind: "watch_brand" },
  "real-estate-developments": { kind: "property_developer" },
});

function categoryScope(category) {
  const slug = String(category ?? "").trim();
  if (!slug || slug === "all") return null;
  const rootId = rootIdFor(slug);
  return rootId ? { slug, rootId } : null;
}

/** An account (`accountColumn`) with approved access to the scope's category. */
const hasAccess = (accountColumn) =>
  `EXISTS (SELECT 1 FROM account_category_access ca WHERE ca.account_id = ${accountColumn} AND ca.category_id = ? AND ca.status = 'approved')`;

const LOCATION_TYPES = new Set(["country", "state", "city", "community", "subcommunity"]);
const LEVEL_LABEL = { country: "Country", state: "State / Region", city: "City", community: "Community", subcommunity: "Sub community" };

function locationOption(entity) {
  // The full chain up to the country, nearest first: "Dubai Marina › Dubai › Dubai › United Arab Emirates".
  const chain = [entity.ancestors.community, entity.ancestors.city, entity.ancestors.state, entity.ancestors.country]
    .filter((ancestor) => ancestor && ancestor.id !== entity.id)
    .map((ancestor) => ancestor.label);
  return {
    value: String(entity.locationId),
    label: entity.name,
    description: [LEVEL_LABEL[entity.type] || entity.type, chain.join(" › ")].filter(Boolean).join(" · "),
    path: [entity.name, ...chain],
    // No `image`: a place has no logo, and initials would add nothing beside its path.
  };
}

/** Every place in the location tree; ranked by tier and name, never by what is listed there. */
async function locations({ q, ids, types }) {
  const wanted = csvList(types).filter((type) => LOCATION_TYPES.has(type));
  if (ids.length) return (await getLocationsByIds(ids)).map(locationOption);
  const rows = q
    ? await searchLocationsContains({ q, types: wanted, limit: LIMIT, rankBy: "place" })
    : await searchLocations({ types: wanted, limit: LIMIT, rankBy: "place" });
  return rows.map(locationOption);
}

/**
 * Listing owners: companies ("org:<public id>") and individual sellers — the owner of an account
 * with no company ("user:<public id>").
 */
async function owners({ q, ids, scope }) {
  const orgIds = ids.filter((id) => id.startsWith("org:")).map((id) => id.slice(4));
  const userIds = ids.filter((id) => id.startsWith("user:")).map((id) => id.slice(5));
  if (ids.length) {
    const [orgs, users] = await Promise.all([
      orgIds.length ? query(`SELECT public_id, name, logo_url FROM organizations WHERE public_id IN (${placeholders(orgIds)})`, orgIds) : [],
      userIds.length ? query(`SELECT public_id, display_name, avatar_url FROM users WHERE public_id IN (${placeholders(userIds)})`, userIds) : [],
    ]);
    return [
      ...orgs.map((row) => ({ value: `org:${row.public_id}`, label: row.name, description: "Company", image: row.logo_url })),
      ...users.map((row) => ({ value: `user:${row.public_id}`, label: row.display_name, description: "Individual", image: row.avatar_url })),
    ];
  }
  const orgWhere = ["o.deleted_at IS NULL"];
  const orgParams = [];
  const userWhere = [
    "u.deleted_at IS NULL",
    "EXISTS (SELECT 1 FROM accounts ua WHERE ua.owner_user_id = u.id AND ua.deleted_at IS NULL AND NOT EXISTS (SELECT 1 FROM organizations uo WHERE uo.account_id = ua.id))",
  ];
  const userParams = [];
  if (q) {
    orgWhere.push("o.name LIKE ?");
    orgParams.push(like(q));
    userWhere.push("u.display_name LIKE ?");
    userParams.push(like(q));
  }
  if (scope) {
    orgWhere.push(hasAccess("o.account_id"));
    orgParams.push(scope.rootId);
    userWhere.push(`EXISTS (SELECT 1 FROM accounts sa WHERE sa.owner_user_id = u.id AND sa.deleted_at IS NULL AND NOT EXISTS (SELECT 1 FROM organizations so WHERE so.account_id = sa.id) AND ${hasAccess("sa.id")})`);
    userParams.push(scope.rootId);
  }
  const rows = await query(
    `SELECT * FROM (
       SELECT CONCAT('org:', o.public_id) AS value, o.name AS label, o.logo_url AS image, 'Company' AS description, 0 AS kind
         FROM organizations o WHERE ${orgWhere.join(" AND ")}
       UNION ALL
       SELECT CONCAT('user:', u.public_id), u.display_name, u.avatar_url, 'Individual', 1
         FROM users u WHERE ${userWhere.join(" AND ")}
     ) owners ORDER BY kind ASC, label ASC LIMIT ${LIMIT}`,
    [...orgParams, ...userParams]
  );
  return rows.map(({ value, label, image, description }) => ({ value, label, image, description }));
}

async function companies({ q, ids, scope }) {
  const conditions = ["o.deleted_at IS NULL"];
  const params = [];
  if (ids.length) {
    conditions.push(`o.public_id IN (${placeholders(ids)})`);
    params.push(...ids);
  } else {
    if (q) {
      conditions.push("(o.name LIKE ? OR o.legal_name LIKE ?)");
      params.push(like(q), like(q));
    }
    if (scope) {
      conditions.push(hasAccess("o.account_id"));
      params.push(scope.rootId);
    }
  }
  const rows = await query(
    `SELECT o.public_id, o.name, o.logo_url, co.name AS country, ct.name AS city
       FROM organizations o
       LEFT JOIN locations co ON co.id = o.country_id
       LEFT JOIN locations ct ON ct.id = o.city_id
      WHERE ${conditions.join(" AND ")}
      ORDER BY o.name ASC LIMIT ${LIMIT}`,
    params
  );
  return rows.map((row) => ({ value: row.public_id, label: row.name, description: [row.city, row.country].filter(Boolean).join(", ") || "Company", image: row.logo_url }));
}

async function agents({ q, ids, scope }) {
  const conditions = ["a.deleted_at IS NULL"];
  const params = [];
  if (ids.length) {
    conditions.push(`a.public_id IN (${placeholders(ids)})`);
    params.push(...ids);
  } else {
    if (q) {
      conditions.push("(a.display_name LIKE ? OR o.name LIKE ?)");
      params.push(like(q), like(q));
    }
    if (scope) {
      // Their company may work the category, or the category is one of their own specialties.
      conditions.push(`(${hasAccess("o.account_id")} OR EXISTS (SELECT 1 FROM agent_specialties sp JOIN categories sc ON sc.id = sp.category_id WHERE sp.agent_id = a.id AND COALESCE(sc.root_category_id, sc.id) = ?))`);
      params.push(scope.rootId, scope.rootId);
    }
  }
  const rows = await query(
    `SELECT a.public_id, a.display_name, a.photo_url, o.name AS company
       FROM agents a LEFT JOIN organizations o ON o.id = a.organization_id
      WHERE ${conditions.join(" AND ")}
      ORDER BY a.display_name ASC LIMIT ${LIMIT}`,
    params
  );
  return rows.map((row) => ({ value: row.public_id, label: row.display_name, description: row.company || "Independent agent", image: row.photo_url }));
}

/** Any user, by name or email (who uploaded a file…). */
async function users({ q, ids }) {
  const rows = await query(
    `SELECT u.public_id, u.display_name, u.email, u.avatar_url FROM users u
      WHERE u.deleted_at IS NULL
        ${ids.length ? `AND u.public_id IN (${placeholders(ids)})` : q ? "AND (u.display_name LIKE ? OR u.email LIKE ?)" : ""}
      ORDER BY u.display_name ASC LIMIT ${LIMIT}`,
    ids.length ? ids : q ? [like(q), like(q)] : []
  );
  return rows.map((row) => ({ value: row.public_id, label: row.display_name || row.email, description: row.email, image: row.avatar_url }));
}

/**
 * Brands: makes, builders, manufacturers, developers. With a category, the category's own brand
 * kind (see BRANDS_BY_CATEGORY); otherwise the `kinds` asked for. `value` is the id or the slug,
 * as the list asks.
 */
async function brands({ q, ids, kinds, scope, valueField = "id" }) {
  const byValue = valueField === "slug" ? "b.slug" : "CAST(b.id AS CHAR)";
  const conditions = ["b.deleted_at IS NULL"];
  const params = [];
  const own = scope ? BRANDS_BY_CATEGORY[scope.slug] : null;
  const wanted = own ? [own.kind] : csvList(kinds);
  if (wanted.length) {
    conditions.push(`b.kind IN (${placeholders(wanted)})`);
    params.push(...wanted);
  }
  if (own?.segment) {
    conditions.push("b.aircraft_segment = ?");
    params.push(own.segment);
  }
  if (ids.length) {
    conditions.push(`${byValue} IN (${placeholders(ids)})`);
    params.push(...ids);
  } else if (q) {
    conditions.push("b.name LIKE ?");
    params.push(like(q));
  }
  const rows = await query(
    `SELECT b.id, b.slug, b.name, b.logo_url, b.kind FROM brands b
      WHERE ${conditions.join(" AND ")} ORDER BY b.name ASC LIMIT ${LIMIT}`,
    params
  );
  return rows.map((row) => ({ value: valueField === "slug" ? row.slug : String(row.id), label: row.name, description: null, image: row.logo_url }));
}

/** Admin users (staff with a platform role), for Assigned To. */
async function admins({ q, ids }) {
  const rows = await query(
    `SELECT u.public_id, u.display_name, u.email, u.avatar_url,
            (SELECT GROUP_CONCAT(r.name ORDER BY r.sort_order SEPARATOR ', ') FROM user_roles ur
               JOIN roles r ON r.id = ur.role_id AND r.scope = 'platform' WHERE ur.user_id = u.id) AS roles
       FROM users u
      WHERE u.deleted_at IS NULL
        AND EXISTS (SELECT 1 FROM user_roles xr JOIN roles xro ON xro.id = xr.role_id AND xro.scope = 'platform' WHERE xr.user_id = u.id)
        ${ids.length ? `AND u.public_id IN (${placeholders(ids)})` : q ? "AND (u.display_name LIKE ? OR u.email LIKE ?)" : ""}
      ORDER BY u.display_name ASC LIMIT ${LIMIT}`,
    ids.length ? ids : q ? [like(q), like(q)] : []
  );
  return rows.map((row) => ({ value: row.public_id, label: row.display_name || row.email, description: row.roles || row.email, image: row.avatar_url }));
}

/**
 * The Property column's records themselves — listings, or developments when `types` is
 * "real-estate-developments" — found by title, reference or place, newest first. `types` may name
 * a category to keep to its listings.
 */
async function properties({ q, ids, types }) {
  const category = csvList(types)[0] ?? "";
  if (category === "real-estate-developments") {
    const wanted = ids.filter((id) => id.startsWith("project:")).map((id) => id.slice(8));
    if (ids.length && !wanted.length) return [];
    const rows = await query(
      `SELECT p.public_id, p.name, p.cover_image_url, CONCAT_WS(', ', NULLIF(cm.name, ''), NULLIF(ct.name, ''), NULLIF(co.name, '')) AS place
         FROM projects p
         LEFT JOIN locations cm ON cm.id = p.community_id
         LEFT JOIN locations ct ON ct.id = p.city_id
         LEFT JOIN locations co ON co.id = p.country_id
        WHERE p.deleted_at IS NULL
          ${wanted.length ? `AND p.public_id IN (${placeholders(wanted)})` : q ? "AND (p.name LIKE ? OR p.public_id LIKE ? OR cm.name LIKE ? OR ct.name LIKE ?)" : ""}
        ORDER BY p.created_at DESC LIMIT ${LIMIT}`,
      wanted.length ? wanted : q ? Array(4).fill(like(q)) : []
    );
    return rows.map((row) => ({ value: `project:${row.public_id}`, label: row.name, description: row.place || "Development", image: row.cover_image_url }));
  }
  const wanted = ids.filter((id) => id.startsWith("listing:")).map((id) => id.slice(8));
  if (ids.length && !wanted.length) return [];
  const rootId = category ? rootIdFor(category) : null;
  const conditions = ["l.deleted_at IS NULL"];
  const params = [];
  if (rootId) {
    conditions.push("l.root_category_id = ?");
    params.push(rootId);
  }
  if (wanted.length) {
    conditions.push(`l.public_id IN (${placeholders(wanted)})`);
    params.push(...wanted);
  } else if (q) {
    conditions.push("(l.title LIKE ? OR l.reference LIKE ? OR l.public_id = ? OR cm.name LIKE ? OR ct.name LIKE ?)");
    params.push(like(q), like(q), q, like(q), like(q));
  }
  const rows = await query(
    `SELECT l.public_id, l.title, l.reference, l.cover_image_url,
            CONCAT_WS(', ', NULLIF(cm.name, ''), NULLIF(ct.name, '')) AS place
       FROM listings l
       LEFT JOIN locations cm ON cm.id = l.community_id
       LEFT JOIN locations ct ON ct.id = l.city_id
      WHERE ${conditions.join(" AND ")}
      ORDER BY l.created_at DESC LIMIT ${LIMIT}`,
    params
  );
  return rows.map((row) => ({ value: `listing:${row.public_id}`, label: row.title, description: [row.reference, row.place].filter(Boolean).join(" · "), image: row.cover_image_url }));
}

const KINDS = {
  property: properties,
  location: locations,
  owner: owners,
  company: companies,
  agent: agents,
  user: users,
  brand: (input) => brands({ ...input, valueField: "id" }),
  developer: (input) => brands({ ...input, kinds: "property_developer", valueField: "slug" }),
  admin: admins,
};

export const LOOKUP_KINDS = Object.keys(KINDS);

export async function lookupOptions(kind, { q = "", ids = "", types = "", kinds = "", category = "" } = {}) {
  const run = KINDS[kind];
  if (!run) return null;
  return run({ q: String(q).trim().slice(0, 100), ids: csvList(ids, 100), types, kinds, scope: categoryScope(category) });
}
