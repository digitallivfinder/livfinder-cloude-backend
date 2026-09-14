import { query, queryOne } from "../../db/query.js";
import { serializeCompany, serializeAgent } from "../../serializers/organization.js";

/**
 * Public reads go through v_public_organizations / v_public_agents, the views
 * that carry the visibility rules. An unpublished organisation is invisible
 * here even to a caller who knows its slug.
 */
const ORG_COLUMNS = `
  o.id, o.public_id, o.account_id, o.slug, o.name, o.legal_name, o.kind, o.tagline, o.description,
  o.logo_url, o.cover_image_url, o.email, o.phone, o.whatsapp, o.website_url,
  o.address_line1, o.address_line2, o.postal_code, o.status, o.verification_status, o.verified_at,
  o.is_publicly_visible, o.is_featured, o.listing_count, o.active_listing_count, o.agent_count,
  o.review_count, o.rating_avg, o.response_time_minutes, o.founded_year, o.employee_count,
  o.seo_title, o.seo_description, o.created_at, o.updated_at,
  co.name AS country_name, co.slug AS country_slug,
  st.name AS state_name, ct.name AS city_name`;

const ORG_JOINS = `
  LEFT JOIN locations co ON co.id = o.country_id
  LEFT JOIN locations st ON st.id = o.state_id
  LEFT JOIN locations ct ON ct.id = o.city_id`;

async function decorateOrganizations(rows) {
  if (!rows.length) return [];
  const ids = rows.map((row) => row.id);
  const placeholders = ids.map(() => "?").join(", ");
  // Batched: one query per relation for the whole page, not per row.
  const [areas, categories, licenses] = await Promise.all([
    query(
      `SELECT osa.organization_id, l.name FROM organization_service_areas osa
         JOIN locations l ON l.id = osa.location_id
        WHERE osa.organization_id IN (${placeholders})
        ORDER BY osa.is_primary DESC, l.depth ASC, l.name ASC`,
      ids
    ),
    query(
      `SELECT o.id AS organization_id, COALESCE(c.root_category_id, c.id) AS root_category_id
         FROM organizations o
         JOIN account_category_access aca ON aca.account_id = o.account_id AND aca.status = 'approved'
         JOIN categories c ON c.id = aca.category_id
        WHERE o.id IN (${placeholders})`,
      ids
    ),
    query(
      `SELECT ol.organization_id, ol.license_number, ol.license_type, ol.expires_at, ol.status,
              ol.issuing_authority AS authority_name
         FROM organization_licenses ol
        WHERE ol.organization_id IN (${placeholders})`,
      ids
    ),
  ]);

  const byOrg = (rows, key) =>
    rows.reduce((map, row) => {
      const list = map.get(String(row.organization_id)) || [];
      list.push(key ? row[key] : row);
      map.set(String(row.organization_id), list);
      return map;
    }, new Map());

  const areaMap = byOrg(areas, "name");
  const categoryMap = byOrg(categories);
  const licenseMap = byOrg(licenses);

  return rows.map((row) =>
    serializeCompany(row, {
      serviceAreas: [...new Set(areaMap.get(String(row.id)) || [])].slice(0, 25),
      categories: categoryMap.get(String(row.id)) || [],
      licenses: licenseMap.get(String(row.id)) || [],
    })
  );
}

export async function listPublicOrganizations({
  limit = 24,
  offset = 0,
  q = null,
  countryId = null,
  kind = null,
  rootCategoryId = null,
  sort = "featured",
} = {}) {
  const conditions = [];
  const params = [];
  const joins = [];

  if (q) {
    conditions.push("(o.name LIKE ? OR o.legal_name LIKE ? OR o.slug LIKE ?)");
    params.push(`%${q}%`, `%${q}%`, `${q}%`);
  }
  if (countryId) {
    conditions.push("o.country_id = ?");
    params.push(Number(countryId));
  }
  if (kind) {
    conditions.push("o.kind = ?");
    params.push(kind);
  }
  if (rootCategoryId) {
    joins.push(`JOIN account_category_access aca ON aca.account_id = o.account_id AND aca.status = 'approved'
                JOIN categories oc ON oc.id = aca.category_id AND COALESCE(oc.root_category_id, oc.id) = ?`);
    params.unshift(Number(rootCategoryId));
  }

  const orderBy =
    {
      featured: "o.is_featured DESC, o.active_listing_count DESC, o.name ASC",
      listings: "o.active_listing_count DESC, o.name ASC",
      rating: "o.rating_avg IS NULL, o.rating_avg DESC, o.review_count DESC",
      name: "o.name ASC",
      newest: "o.created_at DESC",
    }[sort] || "o.is_featured DESC, o.active_listing_count DESC, o.name ASC";

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
  const safeLimit = Math.min(100, Math.max(1, Number(limit) || 24));
  const safeOffset = Math.max(0, Number(offset) || 0);

  const [rows, totalRow] = await Promise.all([
    query(
      `SELECT ${ORG_COLUMNS}
         FROM v_public_organizations o
         ${joins.join("\n")}
         ${ORG_JOINS}
         ${where}
        ORDER BY ${orderBy}
        LIMIT ${safeLimit} OFFSET ${safeOffset}`,
      params
    ),
    queryOne(
      `SELECT COUNT(*) AS total FROM v_public_organizations o ${joins.join("\n")} ${where}`,
      params
    ),
  ]);

  return { rows: await decorateOrganizations(rows), total: Number(totalRow?.total || 0) };
}

export async function getPublicOrganization(slugOrId) {
  const row = await queryOne(
    `SELECT ${ORG_COLUMNS}
       FROM v_public_organizations o
       ${ORG_JOINS}
      WHERE o.slug = ? OR o.public_id = ?
      LIMIT 1`,
    [slugOrId, slugOrId]
  );
  if (!row) return null;
  const [company] = await decorateOrganizations([row]);
  return { raw: row, company };
}

const AGENT_COLUMNS = `
  a.id, a.public_id, a.user_id, a.organization_id, a.first_name, a.last_name, a.display_name,
  a.slug, a.title, a.bio, a.photo_url, a.email, a.phone, a.whatsapp, a.license_number,
  a.experience_years, a.status, a.verification_status, a.is_publicly_visible, a.is_featured,
  a.listing_count, a.active_listing_count, a.review_count, a.rating_avg,
  a.response_time_minutes, a.response_rate, a.joined_at, a.social_links,
  a.seo_title, a.seo_description,
  o.slug AS organization_slug, o.name AS organization_name, o.website_url AS organization_website`;

async function decorateAgents(rows) {
  if (!rows.length) return [];
  const ids = rows.map((row) => row.id);
  const placeholders = ids.map(() => "?").join(", ");
  const [languages, specialties, areas] = await Promise.all([
    query(
      `SELECT al.agent_id, lang.name FROM agent_languages al
         JOIN languages lang ON lang.id = al.language_id
        WHERE al.agent_id IN (${placeholders})
        ORDER BY FIELD(al.proficiency,'native','fluent','conversational','basic'), lang.name`,
      ids
    ),
    query(
      `SELECT asp.agent_id, c.name, COALESCE(c.root_category_id, c.id) AS root_category_id
         FROM agent_specialties asp JOIN categories c ON c.id = asp.category_id
        WHERE asp.agent_id IN (${placeholders})
        ORDER BY asp.is_primary DESC, c.name`,
      ids
    ),
    query(
      `SELECT asa.agent_id, l.name FROM agent_service_areas asa
         JOIN locations l ON l.id = asa.location_id
        WHERE asa.agent_id IN (${placeholders})
        ORDER BY asa.is_primary DESC, l.depth ASC, l.name`,
      ids
    ),
  ]);

  const group = (rows) =>
    rows.reduce((map, row) => {
      const list = map.get(String(row.agent_id)) || [];
      list.push(row);
      map.set(String(row.agent_id), list);
      return map;
    }, new Map());

  const languageMap = group(languages);
  const specialtyMap = group(specialties);
  const areaMap = group(areas);

  return rows.map((row) =>
    serializeAgent(row, {
      languages: [...new Set((languageMap.get(String(row.id)) || []).map((entry) => entry.name))],
      specialties: [...new Set((specialtyMap.get(String(row.id)) || []).map((entry) => entry.name))],
      serviceAreas: [...new Set((areaMap.get(String(row.id)) || []).map((entry) => entry.name))].slice(0, 20),
      categories: specialtyMap.get(String(row.id)) || [],
    })
  );
}

export async function listPublicAgents({
  limit = 24,
  offset = 0,
  q = null,
  organizationId = null,
  countryId = null,
  rootCategoryId = null,
  sort = "featured",
} = {}) {
  const conditions = [];
  const params = [];
  const joins = [];

  if (q) {
    conditions.push("(a.display_name LIKE ? OR a.slug LIKE ?)");
    params.push(`%${q}%`, `${q}%`);
  }
  if (organizationId) {
    conditions.push("a.organization_id = ?");
    params.push(Number(organizationId));
  }
  if (countryId) {
    conditions.push("a.country_id = ?");
    params.push(Number(countryId));
  }
  if (rootCategoryId) {
    joins.push(`JOIN agent_specialties asp2 ON asp2.agent_id = a.id
                JOIN categories ac ON ac.id = asp2.category_id AND COALESCE(ac.root_category_id, ac.id) = ?`);
    params.unshift(Number(rootCategoryId));
  }

  const orderBy =
    {
      featured: "a.is_featured DESC, a.active_listing_count DESC, a.display_name ASC",
      listings: "a.active_listing_count DESC, a.display_name ASC",
      rating: "a.rating_avg IS NULL, a.rating_avg DESC, a.review_count DESC",
      name: "a.display_name ASC",
    }[sort] || "a.is_featured DESC, a.active_listing_count DESC, a.display_name ASC";

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
  const safeLimit = Math.min(100, Math.max(1, Number(limit) || 24));
  const safeOffset = Math.max(0, Number(offset) || 0);

  const [rows, totalRow] = await Promise.all([
    query(
      `SELECT ${AGENT_COLUMNS}
         FROM v_public_agents a
         ${joins.join("\n")}
         LEFT JOIN organizations o ON o.id = a.organization_id
         ${where}
        ORDER BY ${orderBy}
        LIMIT ${safeLimit} OFFSET ${safeOffset}`,
      params
    ),
    queryOne(
      `SELECT COUNT(DISTINCT a.id) AS total FROM v_public_agents a ${joins.join("\n")} ${where}`,
      params
    ),
  ]);

  return { rows: await decorateAgents(rows), total: Number(totalRow?.total || 0) };
}

export async function getPublicAgent(slugOrId) {
  const row = await queryOne(
    `SELECT ${AGENT_COLUMNS}
       FROM v_public_agents a
       LEFT JOIN organizations o ON o.id = a.organization_id
      WHERE a.slug = ? OR a.public_id = ?
      LIMIT 1`,
    [slugOrId, slugOrId]
  );
  if (!row) return null;
  const [agent] = await decorateAgents([row]);
  return { raw: row, agent };
}

export { ORG_COLUMNS, ORG_JOINS, AGENT_COLUMNS, decorateAgents, decorateOrganizations };
