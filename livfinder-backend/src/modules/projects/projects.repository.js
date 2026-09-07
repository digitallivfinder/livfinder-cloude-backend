import { query, queryOne, queryValue } from "../../db/query.js";
import { resolveLocation } from "../locations/locations.repository.js";
import { asArray, toNumber } from "../../utils/http.js";
import {
  AVAILABILITY,
  DEFAULT_SORT,
  FACET_COLUMNS,
  MULTI_FILTERS,
  NEARING_COMPLETION_THRESHOLD,
  PROJECT_STATUSES,
  SORT_MAP,
} from "./projects.filters.js";

/**
 * Public project reads.
 *
 * Every list, facet and country count in here scans `project_search` and
 * nothing else. That projection only ever contains publicly visible projects —
 * `sp_refresh_project_search` applies the rule once, at write time — so
 * visibility is not something a caller can forget to add to a WHERE clause.
 *
 * The detail read starts from the same projection for the same reason: a
 * project that is not in it has no public page, whatever `projects` says.
 */

const CARD_COLUMNS = `
  ps.project_id, ps.public_id, ps.name, ps.slug, ps.canonical_path, ps.tagline,
  ps.developer_brand_id, ps.developer_slug, ps.developer_name, ps.developer_logo_url,
  ps.country_id, ps.state_id, ps.city_id, ps.community_id, ps.sub_community_id,
  ps.location_label, ps.latitude, ps.longitude,
  ps.project_type, ps.status, ps.launch_status, ps.ownership_type,
  ps.launch_date, ps.handover_date, ps.handover_year, ps.completion_percentage,
  ps.total_units, ps.available_units, ps.building_count,
  ps.min_price, ps.max_price, ps.min_price_base, ps.currency_code,
  ps.bedrooms_min, ps.bedrooms_max, ps.area_min, ps.area_max,
  ps.unit_types, ps.bedroom_values, ps.availability,
  ps.payment_plan_count, ps.min_down_payment_percent, ps.has_post_handover, ps.payment_plan_types,
  ps.cover_image_url, ps.gallery_urls, ps.image_count, ps.is_featured, ps.accepts_inquiries,
  ps.active_listing_count, ps.published_at, ps.source_updated_at,
  co.slug AS country_slug, co.name AS country_name,
  st.slug AS state_slug,   st.name AS state_name,
  ct.slug AS city_slug,    ct.name AS city_name,
  cm.slug AS community_slug, cm.name AS community_name`;

const CARD_JOINS = `
  LEFT JOIN locations co ON co.id = ps.country_id
  LEFT JOIN locations st ON st.id = ps.state_id
  LEFT JOIN locations ct ON ct.id = ps.city_id
  LEFT JOIN locations cm ON cm.id = ps.community_id`;

/** `2027`, `2027-06` and `2027-06-30` all mean a date; a bare year is a whole year. */
function handoverBoundary(value, edge) {
  const raw = String(value ?? "").trim();
  if (!raw) return null;
  if (/^\d{4}$/.test(raw)) return edge === "from" ? `${raw}-01-01` : `${raw}-12-31`;
  if (/^\d{4}-\d{2}$/.test(raw)) {
    if (edge === "from") return `${raw}-01`;
    // Last day of that month, without a calendar table: the first of the next
    // month minus a day, computed by SQL rather than guessed at here.
    return `${raw}-01`;
  }
  if (/^\d{4}-\d{2}-\d{2}$/.test(raw)) return raw;
  return null;
}

function isMonth(value) {
  return /^\d{4}-\d{2}$/.test(String(value ?? "").trim());
}

/**
 * Location, from the URL path and from the multi-select control.
 *
 * The path levels are exact — `/projects/uae/dubai/dubai-marina` means all three
 * — and an unresolvable segment makes the whole search impossible rather than
 * silently broadening it. The `location` control sends opaque `city:123` ids at
 * any tier, which are OR-ed across whichever column each resolves to.
 */
async function locationConditions(filters, conditions, params) {
  const levels = [
    ["subCommunity", "subcommunity", "ps.sub_community_id"],
    ["community", "community", "ps.community_id"],
    ["city", "city", "ps.city_id"],
    ["state", "state", "ps.state_id"],
    ["country", "country", "ps.country_id"],
  ];
  const applied = [];
  for (const [key, type, column] of levels) {
    if (!filters[key]) continue;
    const row = await resolveLocation(filters[key], { type });
    if (!row) return { unresolved: key };
    conditions.push(`${column} = ?`);
    params.push(row.id);
    applied.push(String(row.id));
  }

  const seen = new Set(applied);
  const clauses = [];
  for (const value of asArray(filters.location)) {
    const row = await resolveLocation(value);
    if (!row || seen.has(String(row.id))) continue;
    seen.add(String(row.id));
    const column =
      row.level === "country" ? "ps.country_id"
      : row.level === "state" ? "ps.state_id"
      : row.level === "city" ? "ps.city_id"
      : row.level === "sub_community" ? "ps.sub_community_id"
      : "ps.community_id";
    clauses.push(`${column} = ?`);
    params.push(row.id);
  }
  if (clauses.length) conditions.push(`(${clauses.join(" OR ")})`);
  return { unresolved: null };
}

/**
 * Developer, by slug, repeatable.
 *
 * Resolved against `brands` of kind `property_developer` so an unknown or
 * inactive developer makes the search impossible instead of returning the
 * unfiltered catalogue — the failure mode where a filter appears to work.
 */
async function developerConditions(filters, conditions, params) {
  const slugs = asArray(filters.developer).map((value) => String(value).slice(0, 160));
  if (!slugs.length) return { unresolved: null };
  const rows = await query(
    `SELECT id, slug FROM brands
      WHERE kind = 'property_developer' AND deleted_at IS NULL AND is_active = 1
        AND slug IN (${slugs.map(() => "?").join(", ")})`,
    slugs
  );
  if (rows.length !== new Set(slugs).size) return { unresolved: "developer" };
  conditions.push(`ps.developer_brand_id IN (${rows.map(() => "?").join(", ")})`);
  params.push(...rows.map((row) => row.id));
  return { unresolved: null };
}

/** Bedrooms are "1, 2, 3+" chips against the project's declared unit types. */
function bedroomConditions(filters, conditions, params) {
  const values = asArray(filters.beds ?? filters.bedrooms)
    .map((value) => String(value).trim())
    .filter((value) => /^\d{1,2}\+?$/.test(value));
  if (!values.length) return;
  const clauses = [];
  for (const value of values) {
    if (value.endsWith("+")) {
      clauses.push("ps.bedrooms_max >= ?");
      params.push(Number.parseInt(value, 10));
    } else {
      // FIND_IN_SET against the declared set, not a range test: a project
      // offering studios and 3-beds must not answer a 2-bed filter.
      clauses.push("FIND_IN_SET(?, ps.bedroom_values)");
      params.push(value);
    }
  }
  conditions.push(`(${clauses.join(" OR ")})`);
}

/**
 * Lifecycle status, plus the derived `nearing_completion`.
 *
 * Selecting it alongside real statuses ORs cleanly, so "Under construction or
 * nearing completion" is one condition rather than two contradictory ones.
 */
function statusConditions(filters, conditions, params) {
  const values = asArray(filters.status).map((value) => String(value).trim());
  if (!values.length) return;
  const stored = values.filter((value) => PROJECT_STATUSES.includes(value));
  const wantsNearing = values.includes("nearing_completion");
  const clauses = [];
  if (stored.length) {
    clauses.push(`ps.status IN (${stored.map(() => "?").join(", ")})`);
    params.push(...stored);
  }
  if (wantsNearing) {
    clauses.push("(ps.status = 'under_construction' AND ps.completion_percentage >= ?)");
    params.push(NEARING_COMPLETION_THRESHOLD);
  }
  // Every supplied value was unknown: that is an impossible filter, not no filter.
  if (!clauses.length) clauses.push("1 = 0");
  conditions.push(`(${clauses.join(" OR ")})`);
}

export async function buildProjectQuery(filters = {}) {
  const conditions = [];
  const params = [];

  const location = await locationConditions(filters, conditions, params);
  if (location.unresolved) return { impossible: true };

  const developer = await developerConditions(filters, conditions, params);
  if (developer.unresolved) return { impossible: true };

  statusConditions(filters, conditions, params);
  bedroomConditions(filters, conditions, params);

  for (const filter of MULTI_FILTERS) {
    const values = asArray(filters[filter.key])
      .map((value) => String(value).trim())
      .filter((value) => filter.values.includes(value));
    const supplied = asArray(filters[filter.key]).length;
    if (!supplied) continue;
    if (!values.length) return { impossible: true };
    if (filter.csv) {
      conditions.push(`(${values.map(() => `FIND_IN_SET(?, ${filter.column})`).join(" OR ")})`);
    } else {
      conditions.push(`${filter.column} IN (${values.map(() => "?").join(", ")})`);
    }
    params.push(...values);
  }

  const handoverFrom = handoverBoundary(filters.handoverFrom, "from");
  const handoverTo = handoverBoundary(filters.handoverTo, "to");
  if (handoverFrom) {
    conditions.push("ps.handover_date >= ?");
    params.push(handoverFrom);
  }
  if (handoverTo) {
    // A month boundary means "to the end of that month", expressed in SQL so
    // month lengths and leap years are the database's problem, not this file's.
    conditions.push(isMonth(filters.handoverTo) ? "ps.handover_date < DATE_ADD(?, INTERVAL 1 MONTH)" : "ps.handover_date <= ?");
    params.push(handoverTo);
  }

  const priceMin = toNumber(filters.priceMin ?? filters.minPrice);
  const priceMax = toNumber(filters.priceMax ?? filters.maxPrice);
  if (priceMin !== null) {
    conditions.push("ps.min_price_base >= ?");
    params.push(priceMin);
  }
  if (priceMax !== null) {
    conditions.push("ps.min_price_base <= ?");
    params.push(priceMax);
  }
  if (filters.currency) {
    conditions.push("ps.currency_code = ?");
    params.push(String(filters.currency).toUpperCase().slice(0, 3));
  }

  const areaMin = toNumber(filters.areaMin);
  const areaMax = toNumber(filters.areaMax);
  if (areaMin !== null) {
    conditions.push("ps.area_max >= ?");
    params.push(areaMin);
  }
  if (areaMax !== null) {
    conditions.push("ps.area_min <= ?");
    params.push(areaMax);
  }

  const maxDownPayment = toNumber(filters.maxDownPayment);
  if (maxDownPayment !== null) {
    conditions.push("ps.min_down_payment_percent <= ?");
    params.push(maxDownPayment);
  }

  const completionMin = toNumber(filters.completionMin);
  if (completionMin !== null) {
    conditions.push("ps.completion_percentage >= ?");
    params.push(completionMin);
  }

  if (filters.featured === true || filters.featured === "1" || filters.featured === "true") {
    conditions.push("ps.is_featured = 1");
  }

  if (filters.developerId) {
    conditions.push("ps.developer_brand_id = ?");
    params.push(Number(filters.developerId));
  }

  const keyword = typeof filters.q === "string" ? filters.q.trim().slice(0, 120) : "";
  if (keyword) {
    conditions.push("(ps.name LIKE ? OR ps.tagline LIKE ? OR ps.location_label LIKE ? OR ps.developer_name LIKE ?)");
    params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`, `%${keyword}%`);
  }

  return {
    impossible: false,
    where: conditions.length ? `WHERE ${conditions.join(" AND ")}` : "",
    params,
    orderBy: SORT_MAP[filters.sort] || SORT_MAP[DEFAULT_SORT],
    sort: SORT_MAP[filters.sort] ? filters.sort : DEFAULT_SORT,
  };
}

export async function searchProjects(filters = {}, { limit = 24, offset = 0, withTotal = true } = {}) {
  const built = await buildProjectQuery(filters);
  if (built.impossible) return { rows: [], total: 0, sort: DEFAULT_SORT };

  const safeLimit = Math.min(100, Math.max(1, Number(limit) || 24));
  const safeOffset = Math.max(0, Math.min(100_000, Number(offset) || 0));

  const rows = await query(
    `SELECT ${CARD_COLUMNS}
       FROM project_search ps
       ${CARD_JOINS}
       ${built.where}
      ORDER BY ${built.orderBy}
      LIMIT ${safeLimit} OFFSET ${safeOffset}`,
    built.params
  );

  const total = withTotal
    ? Number(await queryValue(`SELECT COUNT(*) FROM project_search ps ${built.where}`, built.params))
    : rows.length + safeOffset;

  return { rows, total, sort: built.sort };
}

export async function countProjects(filters = {}) {
  const built = await buildProjectQuery(filters);
  if (built.impossible) return 0;
  return Number(await queryValue(`SELECT COUNT(*) FROM project_search ps ${built.where}`, built.params));
}

/**
 * Facet counts under the caller's own filters.
 *
 * Every option list on the Projects pages comes from here, so a control never
 * offers a value the catalogue does not hold and never prints a count the
 * result page then contradicts.
 */
export async function projectFacets(filters = {}, facetKey) {
  const facet = FACET_COLUMNS[facetKey];
  if (!facet) throw new TypeError(`unsupported project facet: ${facetKey}`);
  const built = await buildProjectQuery(filters);
  if (built.impossible) return [];

  if (facet.csv) {
    // A comma-separated aggregate cannot be grouped directly. The candidate
    // vocabulary is small and fixed for unit and plan types; bedrooms are
    // enumerated from what the projection actually holds.
    const values =
      facet.values ||
      (await query(`SELECT DISTINCT bedroom_values FROM project_search WHERE bedroom_values IS NOT NULL`))
        .flatMap((row) => String(row.bedroom_values).split(","))
        .filter(Boolean)
        .filter((value, index, list) => list.indexOf(value) === index)
        .sort((a, b) => Number(a) - Number(b));
    if (!values.length) return [];
    /**
     * One aliased column per candidate value.
     *
     * The aliases are load-bearing: every one of these SUMs is the same
     * expression text, so without them MySQL names all N columns identically,
     * the driver collapses them into a single key on the result object, and
     * every count but one disappears — a Property type menu that reads "no
     * options available" over a catalogue that has them.
     */
    const rows = await query(
      `SELECT ${values.map((_, index) => `SUM(FIND_IN_SET(?, ${facet.column}) > 0) AS c${index}`).join(", ")}
         FROM project_search ps ${built.where}`,
      [...values, ...built.params]
    );
    const counts = rows[0] || {};
    return values
      .map((value, index) => ({ value, count: Number(counts[`c${index}`]) || 0 }))
      .filter((entry) => entry.count > 0);
  }

  const label = facet.labelColumn ? `, MIN(${facet.labelColumn}) AS label` : "";
  const rows = await query(
    `SELECT ${facet.column} AS value, COUNT(*) AS count${label}
       FROM project_search ps ${built.where}
      ${built.where ? "AND" : "WHERE"} ${facet.column} IS NOT NULL
      GROUP BY ${facet.column}
      ORDER BY count DESC
      LIMIT 200`,
    built.params
  );
  return rows.map((row) => ({ value: row.value, count: Number(row.count), label: row.label ?? null }));
}

/**
 * Countries holding publicly visible projects, with counts and a photograph.
 *
 * The count is projects, never listings: the countries directory browsed under
 * Projects must not advertise a property total and then open a project page.
 */
export async function projectCountryFacets(filters = {}, { limit = 60 } = {}) {
  const built = await buildProjectQuery(filters);
  if (built.impossible) return [];
  const bounded = Math.min(Math.max(Number.parseInt(limit, 10) || 60, 1), 250);
  return query(
    `SELECT co.slug AS slug, co.name AS name, co.id AS location_id, COUNT(*) AS count,
            SUBSTRING_INDEX(
              GROUP_CONCAT(ps.cover_image_url ORDER BY ps.is_featured DESC, ps.published_at DESC SEPARATOR ' '),
              ' ', 1
            ) AS image
       FROM project_search ps
       JOIN locations co ON co.id = ps.country_id
       ${built.where}
      GROUP BY co.id, co.slug, co.name
      ORDER BY count DESC, co.name ASC
      LIMIT ${bounded}`,
    built.params
  );
}

/** The one row behind a canonical `/projects/...` path. */
export async function getProjectRowByPath(pathname) {
  return queryOne(
    `SELECT ${CARD_COLUMNS} FROM project_search ps ${CARD_JOINS} WHERE ps.canonical_path = ? LIMIT 1`,
    [String(pathname).slice(0, 500)]
  );
}

export async function getProjectRowByIdentifier(identifier) {
  return queryOne(
    `SELECT ${CARD_COLUMNS} FROM project_search ps ${CARD_JOINS}
      WHERE ps.public_id = ? OR ps.slug = ? LIMIT 1`,
    [String(identifier).slice(0, 64), String(identifier).slice(0, 220)]
  );
}

/**
 * A published project's canonical path from any identifier it might be quoted by.
 *
 * Used to answer "is this path a project, and is it the right one?" without
 * loading the whole detail, and to turn a non-canonical but resolvable path into
 * a permanent redirect.
 */
export async function resolveProjectCanonicalPath({ path, slug, publicId } = {}) {
  const row = await queryOne(
    `SELECT canonical_path FROM project_search
      WHERE canonical_path = ? OR slug = ? OR public_id = ? LIMIT 1`,
    [String(path || "").slice(0, 500), String(slug || "").slice(0, 220), String(publicId || "").slice(0, 64)]
  );
  return row?.canonical_path || null;
}

/* -------------------------------------------------------------------------- */
/* Detail                                                                      */
/* -------------------------------------------------------------------------- */

export async function getProjectChildren(projectId, { includeGatedDocuments = false } = {}) {
  const [record, unitTypes, paymentPlans, milestones, amenities, media, documents, floorPlans, tours, buildings] =
    await Promise.all([
      queryOne(
        `SELECT p.id, p.public_id, p.description, p.marketing_heading, p.highlights, p.amenities,
                p.address_line1, p.brochure_url, p.seo_title, p.seo_description,
                p.construction_start_date, p.organization_id,
                b.public_id AS developer_public_id, b.slug AS developer_slug, b.name AS developer_name,
                b.logo_url AS developer_logo_url, b.description AS developer_description,
                b.website_url AS developer_website, b.founded_year AS developer_founded_year,
                dc.name AS developer_country
           FROM projects p
           LEFT JOIN brands b ON b.id = p.developer_brand_id
           LEFT JOIN locations dc ON dc.id = b.country_id
          WHERE p.id = ? LIMIT 1`,
        [projectId]
      ),
      query(
        `SELECT ut.public_id, ut.unit_type, ut.name, ut.bedrooms, ut.bathrooms, ut.min_size, ut.max_size,
                ut.starting_price, ut.max_price, ut.currency_code, ut.availability,
                ut.available_units, ut.total_units, ut.sort_order,
                mu.code AS area_unit
           FROM project_unit_types ut
           LEFT JOIN measurement_units mu ON mu.id = ut.area_unit_id
          WHERE ut.project_id = ?
          ORDER BY ut.sort_order ASC, ut.bedrooms ASC, ut.id ASC`,
        [projectId]
      ),
      query(
        `SELECT id, name, description, plan_type, down_payment_percent, during_construction_percent,
                on_handover_percent, post_handover_percent, post_handover_months,
                waives_registration_fee, service_charge_waiver_years,
                guaranteed_return_percent, guaranteed_return_years
           FROM project_payment_plans
          WHERE project_id = ? AND is_active = 1
          ORDER BY id ASC`,
        [projectId]
      ),
      query(
        `SELECT m.plan_id, m.sequence_number, m.name, m.trigger_type, m.construction_percent,
                m.months_offset, m.fixed_date, m.amount_percent, m.fixed_amount, m.currency_code, m.notes
           FROM payment_plan_milestones m
           JOIN project_payment_plans pp ON pp.id = m.plan_id
          WHERE pp.project_id = ? AND pp.is_active = 1
          ORDER BY m.plan_id ASC, m.sequence_number ASC`,
        [projectId]
      ),
      query(
        `SELECT slug, label, category FROM project_amenities
          WHERE project_id = ? ORDER BY sort_order ASC, label ASC`,
        [projectId]
      ),
      query(
        `SELECT ma.role, ma.sort_order, ma.is_primary, ma.caption,
                a.public_id, COALESCE(a.cdn_url, a.url) AS url, a.width, a.height, a.mime_type, a.alt_text
           FROM media_attachments ma
           JOIN media_assets a ON a.id = ma.media_asset_id
          WHERE ma.attachable_type = 'project' AND ma.attachable_id = ?
          ORDER BY ma.role ASC, ma.is_primary DESC, ma.sort_order ASC, ma.id ASC`,
        [projectId]
      ),
      /**
       * Document visibility is decided in SQL, not in the serializer.
       *
       * `restricted` and `internal` never leave the database on a public read —
       * a title deed must not appear in a DTO, in metadata or in a sitemap even
       * as a name. `gated` is listed (so the page can say a brochure exists and
       * offer the enquiry that unlocks it) but carries no file URL unless the
       * caller has already earned access.
       */
      query(
        `SELECT d.public_id, d.document_type, d.title, d.description, d.visibility,
                d.page_count, d.file_size_bytes, d.version,
                CASE WHEN d.visibility = 'public' OR ? = 1 THEN COALESCE(a.cdn_url, a.url) ELSE NULL END AS url
           FROM documents d
           LEFT JOIN media_assets a ON a.id = d.media_asset_id
          WHERE d.owner_type = 'project' AND d.owner_id = ?
            AND d.deleted_at IS NULL AND d.status = 'active'
            AND d.visibility IN ('public', 'gated')
            AND (d.expires_at IS NULL OR d.expires_at > NOW(3))
          ORDER BY d.document_type ASC, d.id ASC`,
        [includeGatedDocuments ? 1 : 0, projectId]
      ),
      query(
        `SELECT fp.name, fp.floor_level, fp.total_area_sqm, fp.total_area_sqft, fp.requires_lead,
                fp.sort_order, COALESCE(a.cdn_url, a.url) AS url
           FROM floor_plans fp
           LEFT JOIN media_assets a ON a.id = fp.media_asset_id
          WHERE fp.project_id = ? AND fp.is_public = 1
          ORDER BY fp.sort_order ASC, fp.id ASC`,
        [projectId]
      ),
      query(
        `SELECT vt.public_id, vt.title, vt.tour_type, vt.provider, vt.embed_url, COALESCE(a.cdn_url, a.url) AS thumbnail_url
           FROM virtual_tours vt
           LEFT JOIN media_assets a ON a.id = vt.thumbnail_asset_id
          WHERE vt.project_id = ? AND vt.status = 'ready' AND vt.is_public = 1
          ORDER BY vt.id ASC`,
        [projectId]
      ),
      query(
        `SELECT public_id, name, slug, building_type, floors_above_ground, total_units,
                status, completion_year, handover_date
           FROM buildings
          WHERE project_id = ? AND deleted_at IS NULL AND is_publicly_visible = 1
          ORDER BY name ASC`,
        [projectId]
      ),
    ]);

  return { record, unitTypes, paymentPlans, milestones, amenities, media, documents, floorPlans, tours, buildings };
}

/** Similar projects, other projects by the same developer, recently launched. */
export async function getRelatedProjects(row, { limit = 6 } = {}) {
  const exclude = row.project_id;
  const [similar, byDeveloper, recent] = await Promise.all([
    query(
      `SELECT ${CARD_COLUMNS} FROM project_search ps ${CARD_JOINS}
        WHERE ps.project_id <> ?
          AND (ps.community_id = ? OR ps.city_id = ? OR ps.country_id = ?)
        ORDER BY (ps.community_id = ?) DESC, (ps.city_id = ?) DESC, ps.is_featured DESC, ps.published_at DESC
        LIMIT ${Number(limit)}`,
      [exclude, row.community_id, row.city_id, row.country_id, row.community_id, row.city_id]
    ),
    row.developer_brand_id
      ? query(
          `SELECT ${CARD_COLUMNS} FROM project_search ps ${CARD_JOINS}
            WHERE ps.developer_brand_id = ? AND ps.project_id <> ?
            ORDER BY ps.is_featured DESC, ps.published_at DESC
            LIMIT ${Number(limit)}`,
          [row.developer_brand_id, exclude]
        )
      : Promise.resolve([]),
    query(
      `SELECT ${CARD_COLUMNS} FROM project_search ps ${CARD_JOINS}
        WHERE ps.project_id <> ? AND ps.launch_date IS NOT NULL
        ORDER BY ps.launch_date DESC
        LIMIT ${Number(limit)}`,
      [exclude]
    ),
  ]);
  return { similar, byDeveloper, recent };
}

/* -------------------------------------------------------------------------- */
/* Developers                                                                  */
/* -------------------------------------------------------------------------- */

/**
 * Public developers.
 *
 * Only developers with at least one publicly visible project — the count comes
 * from the projection, so the directory cannot list a developer whose page
 * would then be empty, and the number beside a name is the number of projects
 * the filter will actually return.
 */
export async function listPublicDevelopers({ q = null, limit = 60, offset = 0, countryId = null } = {}) {
  const conditions = ["b.kind = 'property_developer'", "b.deleted_at IS NULL", "b.is_active = 1"];
  const params = [];
  if (q) {
    conditions.push("(b.name LIKE ? OR b.slug LIKE ?)");
    params.push(`${q}%`, `${q}%`);
  }
  if (countryId) {
    conditions.push("EXISTS (SELECT 1 FROM project_search ps WHERE ps.developer_brand_id = b.id AND ps.country_id = ?)");
    params.push(Number(countryId));
  }
  const where = `WHERE ${conditions.join(" AND ")} AND pc.project_count > 0`;
  const safeLimit = Math.min(200, Math.max(1, Number(limit) || 60));
  const safeOffset = Math.max(0, Number(offset) || 0);

  const from = `
    FROM brands b
    JOIN (SELECT developer_brand_id, COUNT(*) AS project_count
            FROM project_search WHERE developer_brand_id IS NOT NULL
           GROUP BY developer_brand_id) pc ON pc.developer_brand_id = b.id
    LEFT JOIN locations co ON co.id = b.country_id`;

  const [rows, total] = await Promise.all([
    query(
      `SELECT b.public_id, b.name, b.slug, b.logo_url, b.website_url, b.description,
              b.founded_year, co.name AS country_name, co.slug AS country_slug,
              pc.project_count
         ${from} ${where}
        ORDER BY pc.project_count DESC, b.name ASC
        LIMIT ${safeLimit} OFFSET ${safeOffset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) ${from} ${where}`, params),
  ]);
  return { rows, total: Number(total) || 0 };
}

export async function getPublicDeveloper(slug) {
  return queryOne(
    `SELECT b.id, b.public_id, b.name, b.slug, b.logo_url, b.website_url, b.description,
            b.founded_year, co.name AS country_name, co.slug AS country_slug,
            (SELECT COUNT(*) FROM project_search ps WHERE ps.developer_brand_id = b.id) AS project_count
       FROM brands b
       LEFT JOIN locations co ON co.id = b.country_id
      WHERE b.kind = 'property_developer' AND b.deleted_at IS NULL AND b.is_active = 1
        AND (b.slug = ? OR b.public_id = ?)
      LIMIT 1`,
    [String(slug).slice(0, 160), String(slug).slice(0, 64)]
  );
}

/**
 * The option list behind one filter control.
 *
 * Backed by the same projection the results come from, so a developer, unit
 * type, handover year or availability offered here is one that returns rows.
 */
export async function projectFilterOptions(filterKey, { q = null, limit = 60, filters = {} } = {}) {
  const key = String(filterKey);
  if (key === "developer") {
    const { rows } = await listPublicDevelopers({ q, limit });
    return rows.map((row) => ({
      value: row.slug,
      label: row.name,
      slug: row.slug,
      count: Number(row.project_count) || 0,
      logoUrl: row.logo_url,
    }));
  }
  if (key === "location") {
    /**
     * Locations that actually hold projects, with their whole ancestry.
     *
     * The ancestors are the point: a Projects URL is a path, and choosing a
     * community has to produce `/projects/{country}/{state}/{city}/{community}`.
     * Returning the chosen row alone left the caller able to filter by a
     * community it could not express in a URL — the filter applied, the address
     * bar did not change, and a copied link reproduced a different page.
     */
    const rows = await query(
      `SELECT l.id, l.slug, l.name, l.level, COUNT(*) AS count,
              co.slug AS country_slug, co.name AS country_name,
              st.slug AS state_slug,   st.name AS state_name,
              ct.slug AS city_slug,    ct.name AS city_name,
              cm.slug AS community_slug, cm.name AS community_name
         FROM (SELECT country_id AS location_id FROM project_search WHERE country_id IS NOT NULL
               UNION ALL SELECT state_id FROM project_search WHERE state_id IS NOT NULL
               UNION ALL SELECT city_id FROM project_search WHERE city_id IS NOT NULL
               UNION ALL SELECT community_id FROM project_search WHERE community_id IS NOT NULL) t
         JOIN locations l ON l.id = t.location_id
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations st ON st.id = l.state_id
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations cm ON cm.id = l.community_id
        ${q ? "WHERE l.name LIKE ?" : ""}
        GROUP BY l.id, l.slug, l.name, l.level, co.slug, co.name, st.slug, st.name,
                 ct.slug, ct.name, cm.slug, cm.name
        ORDER BY count DESC, l.name ASC
        LIMIT ${Math.min(100, Math.max(1, Number(limit) || 60))}`,
      q ? [`${q}%`] : []
    );
    return rows.map((row) => {
      const type = row.level === "sub_community" ? "subcommunity" : row.level;
      const level = (slug, name) => (slug ? { slug, name } : null);
      const ancestors = {
        country: level(row.country_slug, row.country_name),
        state: level(row.state_slug, row.state_name),
        city: level(row.city_slug, row.city_name),
        community: level(row.community_slug, row.community_name),
      };
      // `locations` denormalises a row's own tier into its ancestry columns for
      // some levels and not others, so the row itself is filled in explicitly.
      if (["country", "state", "city", "community"].includes(type)) {
        ancestors[type] = { slug: row.slug, name: row.name };
      }
      return {
        value: `${type}:${row.id}`,
        id: `${type}:${row.id}`,
        label: row.name,
        slug: row.slug,
        type,
        count: Number(row.count) || 0,
        ancestors,
        secondaryLabel:
          [ancestors.city?.name, ancestors.state?.name, ancestors.country?.name]
            .filter((name) => name && name !== row.name)
            .join(", ") || null,
      };
    });
  }
  if (key === "handover" || key === "handoverYear") {
    const rows = await projectFacets(filters, "handoverYear");
    return rows
      .filter((row) => row.value)
      .sort((a, b) => Number(a.value) - Number(b.value))
      .map((row) => ({ value: String(row.value), label: String(row.value), count: row.count }));
  }
  if (key === "availability") {
    const rows = await projectFacets(filters, "availability");
    const order = new Map(AVAILABILITY.map((value, index) => [value, index]));
    return rows
      .sort((a, b) => (order.get(a.value) ?? 99) - (order.get(b.value) ?? 99))
      .map((row) => ({ value: row.value, label: row.value, count: row.count }));
  }
  if (FACET_COLUMNS[key]) {
    const rows = await projectFacets(filters, key);
    return rows.map((row) => ({ value: String(row.value), label: row.label || String(row.value), count: row.count }));
  }
  return [];
}

export { CARD_COLUMNS, CARD_JOINS };
