import { query, queryOne, execute, callProcedure } from "../../db/query.js";
import { serializeListingDetail } from "../../serializers/listing.js";
import { serializeCompany, serializeAgent } from "../../serializers/organization.js";
import { categoryByRootId } from "../../utils/categories.js";

const LISTING_COLUMNS = `
  l.*,
  cat.slug AS category_slug, cat.name AS category_name,
  root.code AS root_category_code,
  pur.slug AS purpose_slug, pur.code AS purpose_code,
  co.slug AS country_slug, co.name AS country_name,
  st.slug AS state_slug,   st.name AS state_name,
  ct.slug AS city_slug,    ct.name AS city_name,
  cm.slug AS community_slug, cm.name AS community_name,
  sc.slug AS sub_community_slug, sc.name AS sub_community_name,
  br.slug AS brand_slug, br.name AS brand_name,
  bm.slug AS brand_model_slug, bm.name AS brand_model_name`;

const LISTING_JOINS = `
  JOIN categories cat  ON cat.id  = l.category_id
  JOIN categories root ON root.id = l.root_category_id
  JOIN purposes   pur  ON pur.id  = l.purpose_id
  LEFT JOIN locations co ON co.id = l.country_id
  LEFT JOIN locations st ON st.id = l.state_id
  LEFT JOIN locations ct ON ct.id = l.city_id
  LEFT JOIN locations cm ON cm.id = l.community_id
  LEFT JOIN locations sc ON sc.id = l.sub_community_id
  LEFT JOIN brands br ON br.id = l.brand_id
  LEFT JOIN brand_models bm ON bm.id = l.brand_model_id`;

const DETAIL_TABLE_BY_ROOT = {
  1: "listing_real_estate",
  2: "listing_vehicle",
  3: "listing_marine",
  4: "listing_aviation",
  5: "listing_aviation",
  6: "listing_timepiece",
};

/**
 * `source` decides which base relation the lookup runs against:
 *   "public" — v_public_listings, so an unpublished row is a 404 no matter what
 *              id the caller knows.
 *   "any"    — the raw table, for the owner's portal and for admin.
 */
function baseRelation(source) {
  return source === "public" ? "v_public_listings" : "listings";
}

async function loadRelated(listing, { includePrivate = false } = {}) {
  const listingId = listing.id;
  const detailTable = DETAIL_TABLE_BY_ROOT[Number(listing.root_category_id)];

  const [detail, media, features, attributes, organization, agent, project] = await Promise.all([
    detailTable
      ? queryOne(`SELECT * FROM ${detailTable} WHERE listing_id = ?`, [listingId])
      : null,
    query(
      `SELECT lm.id, lm.media_asset_id, lm.media_type, lm.url, lm.thumbnail_url, lm.alt_text,
              lm.caption, lm.tag, lm.sort_order, lm.is_cover, lm.is_public,
              ma.public_id, ma.width, ma.height, ma.file_size_bytes, ma.mime_type
         FROM listing_media lm
         LEFT JOIN media_assets ma ON ma.id = lm.media_asset_id
        WHERE lm.listing_id = ?${includePrivate ? "" : " AND lm.is_public = 1"}
        ORDER BY lm.is_cover DESC, lm.sort_order ASC, lm.id ASC`,
      [listingId]
    ),
    query(
      `SELECT f.id, f.slug, f.name, f.icon, f.is_premium AS is_highlighted, fg.name AS group_name
         FROM listing_features lf
         JOIN features f ON f.id = lf.feature_id
         LEFT JOIN feature_groups fg ON fg.id = f.feature_group_id
        WHERE lf.listing_id = ?
        ORDER BY f.is_premium DESC, fg.sort_order ASC, f.sort_order ASC, f.name ASC`,
      [listingId]
    ),
    query(
      `SELECT a.code, a.name, a.unit_code AS unit, a.data_type,
              lav.value_text, lav.value_numeric AS value_number, lav.value_boolean,
              lav.value_date, ao.label AS option_label
         FROM listing_attribute_values lav
         JOIN attributes a ON a.id = lav.attribute_id
         LEFT JOIN attribute_options ao ON ao.id = lav.attribute_option_id
        WHERE lav.listing_id = ?
        ORDER BY a.is_highlight DESC, a.name ASC`,
      [listingId]
    ),
    listing.organization_id ? loadOrganizationSummary(listing.organization_id) : null,
    listing.agent_id ? loadAgentSummary(listing.agent_id) : null,
    listing.project_id
      ? queryOne(
          `SELECT public_id, name, slug, status, expected_completion_date FROM projects WHERE id = ?`,
          [listing.project_id]
        )
      : null,
  ]);

  return { detail, media, features, attributes, organization, agent, project };
}

export async function loadOrganizationSummary(organizationId) {
  const row = await queryOne(
    `SELECT o.id, o.public_id, o.slug, o.name, o.legal_name, o.kind, o.tagline, o.description,
            o.logo_url, o.cover_image_url, o.email, o.phone, o.whatsapp, o.website_url,
            o.address_line1, o.address_line2, o.status, o.verification_status, o.verified_at,
            o.is_publicly_visible, o.is_featured, o.listing_count, o.active_listing_count,
            o.agent_count, o.review_count, o.rating_avg, o.response_time_minutes,
            o.founded_year, o.employee_count, o.seo_title, o.seo_description,
            o.created_at, o.updated_at,
            co.name AS country_name, co.slug AS country_slug,
            st.name AS state_name, ct.name AS city_name
       FROM organizations o
       LEFT JOIN locations co ON co.id = o.country_id
       LEFT JOIN locations st ON st.id = o.state_id
       LEFT JOIN locations ct ON ct.id = o.city_id
      WHERE o.id = ? AND o.deleted_at IS NULL`,
    [organizationId]
  );
  if (!row) return null;
  const [serviceAreas, categories] = await Promise.all([
    query(
      `SELECT l.name FROM organization_service_areas osa
         JOIN locations l ON l.id = osa.location_id
        WHERE osa.organization_id = ? ORDER BY l.depth ASC, l.name ASC LIMIT 25`,
      [organizationId]
    ),
    query(
      `SELECT COALESCE(c.root_category_id, c.id) AS root_category_id, oca.status
         FROM organization_category_access oca
         JOIN categories c ON c.id = oca.category_id
        WHERE oca.organization_id = ? AND oca.status = 'approved'`,
      [organizationId]
    ),
  ]);
  return serializeCompany(row, {
    serviceAreas: serviceAreas.map((area) => area.name),
    categories,
  });
}

export async function loadAgentSummary(agentId) {
  const row = await queryOne(
    `SELECT a.*, o.slug AS organization_slug, o.name AS organization_name, o.website_url AS organization_website
       FROM agents a
       LEFT JOIN organizations o ON o.id = a.organization_id
      WHERE a.id = ? AND a.deleted_at IS NULL`,
    [agentId]
  );
  if (!row) return null;
  const [languages, specialties, serviceAreas] = await Promise.all([
    query(
      `SELECT lang.name FROM agent_languages al JOIN languages lang ON lang.id = al.language_id
        WHERE al.agent_id = ?
        ORDER BY FIELD(al.proficiency, 'native', 'fluent', 'conversational', 'basic'), lang.name ASC`,
      [agentId]
    ),
    query(
      `SELECT c.name FROM agent_specialties asp
         JOIN categories c ON c.id = asp.category_id
        WHERE asp.agent_id = ?
        ORDER BY asp.is_primary DESC, c.name ASC LIMIT 12`,
      [agentId]
    ),
    query(
      `SELECT l.name FROM agent_service_areas asa JOIN locations l ON l.id = asa.location_id
        WHERE asa.agent_id = ? ORDER BY l.depth ASC, l.name ASC LIMIT 20`,
      [agentId]
    ),
  ]);
  return serializeAgent(row, {
    languages: languages.map((row) => row.name),
    specialties: specialties.map((row) => row.name).filter(Boolean),
    serviceAreas: serviceAreas.map((row) => row.name),
  });
}

async function fetchListingRow({ id, publicId, reference, canonicalPath, slug }, source) {
  const relation = baseRelation(source);
  const conditions = [];
  const params = [];
  if (id) { conditions.push("l.id = ?"); params.push(Number(id)); }
  if (publicId) { conditions.push("l.public_id = ?"); params.push(publicId); }
  if (reference) { conditions.push("l.reference = ?"); params.push(reference); }
  if (canonicalPath) { conditions.push("l.canonical_path = ?"); params.push(canonicalPath); }
  if (slug) { conditions.push("l.slug = ?"); params.push(slug); }
  if (!conditions.length) return null;

  return queryOne(
    `SELECT ${LISTING_COLUMNS}
       FROM ${relation} l
       ${LISTING_JOINS}
      WHERE ${conditions.join(" OR ")}
      LIMIT 1`,
    params
  );
}

export async function getListingDetail(identifier, { source = "public", includePrivate = false } = {}) {
  const listing = await fetchListingRow(identifier, source);
  if (!listing) return null;
  const related = await loadRelated(listing, { includePrivate });
  return { raw: listing, ...related, detail: serializeListingDetail({ listing, ...related }) };
}

export async function getListingByPath(pathname, { source = "public" } = {}) {
  return getListingDetail({ canonicalPath: pathname }, { source });
}

/** Owner/admin lookup: the raw row plus the ids an authorization check needs. */
export async function getListingOwnership(identifier) {
  const conditions = [];
  const params = [];
  if (identifier.id) { conditions.push("l.id = ?"); params.push(Number(identifier.id)); }
  if (identifier.publicId) { conditions.push("l.public_id = ?"); params.push(identifier.publicId); }
  if (identifier.reference) { conditions.push("l.reference = ?"); params.push(identifier.reference); }
  if (!conditions.length) return null;
  return queryOne(
    `SELECT l.id, l.public_id, l.reference, l.account_id, l.organization_id, l.agent_id,
            l.created_by_user_id, l.status, l.moderation_status, l.root_category_id,
            l.category_id, l.purpose_id, l.slug, l.canonical_path, l.deleted_at
       FROM listings l
      WHERE (${conditions.join(" OR ")}) AND l.deleted_at IS NULL
      LIMIT 1`,
    params
  );
}

/**
 * Refreshes the flat read model for one listing. Called after every write that
 * can change what a results page shows; the procedure also removes the row when
 * the listing no longer qualifies as public.
 */
export async function refreshListingSearch(listingId, executor) {
  await callProcedure("sp_refresh_listing_search", [listingId], executor);
}

export async function recordStatusChange({ listingId, fromStatus, toStatus, userId, reason }, executor) {
  await execute(
    `INSERT INTO listing_status_history (listing_id, from_status, to_status, changed_by_user_id, reason, changed_at)
     VALUES (?, ?, ?, ?, ?, NOW(3))`,
    [listingId, fromStatus || null, toStatus, userId || null, reason || null],
    executor
  );
}

export async function nextReference(executor) {
  // References are LF-NNNN. Take the current maximum and step past it; the
  // UNIQUE index on `reference` is the real guarantee.
  const row = await queryOne(
    `SELECT MAX(CAST(SUBSTRING(reference, 4) AS UNSIGNED)) AS max_ref
       FROM listings WHERE reference LIKE 'LF-%'`,
    [],
    executor
  );
  const next = Number(row?.max_ref || 2000) + 1;
  return `LF-${next}`;
}

export { LISTING_COLUMNS, LISTING_JOINS, DETAIL_TABLE_BY_ROOT, categoryByRootId };
