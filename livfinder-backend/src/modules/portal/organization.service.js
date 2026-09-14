import crypto from "node:crypto";
import { z } from "zod";
import { query, queryOne, queryValue, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ulid, sha256, randomToken } from "../../utils/ids.js";
import { slugify } from "../../utils/slug.js";
import { resolveCategory, frontendCategoryId, CATEGORY_DEFINITIONS } from "../../utils/categories.js";
import { resolveLocation } from "../locations/locations.repository.js";
import { serializeAgent } from "../../serializers/organization.js";
import { getAssetByPublicId } from "../media/media.service.js";
import { isoDate, int, bool, num } from "../../serializers/primitives.js";

export const organizationUpdateSchema = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  legalName: z.string().trim().max(255).optional().or(z.literal("")),
  tagline: z.string().trim().max(255).optional().or(z.literal("")),
  description: z.string().trim().max(8000).optional().or(z.literal("")),
  email: z.string().trim().max(255).optional().or(z.literal("")),
  phone: z.string().trim().max(40).optional().or(z.literal("")),
  whatsapp: z.string().trim().max(40).optional().or(z.literal("")),
  website: z.string().trim().max(500).optional().or(z.literal("")),
  addressLine1: z.string().trim().max(255).optional().or(z.literal("")),
  addressLine2: z.string().trim().max(255).optional().or(z.literal("")),
  postalCode: z.string().trim().max(30).optional().or(z.literal("")),
  country: z.string().trim().max(120).optional().or(z.literal("")),
  city: z.string().trim().max(120).optional().or(z.literal("")),
  foundedYear: z.coerce.number().int().min(1600).max(2200).optional().nullable(),
  employeeCount: z.coerce.number().int().min(0).max(1_000_000).optional().nullable(),
  logoAssetId: z.string().max(40).optional().nullable(),
  coverAssetId: z.string().max(40).optional().nullable(),
  serviceAreas: z.array(z.union([z.string().max(120), z.number()])).max(50).optional(),
  seoTitle: z.string().trim().max(255).optional().or(z.literal("")),
  seoDescription: z.string().trim().max(500).optional().or(z.literal("")),
  // status, verification_status and is_publicly_visible are admin-controlled
  // and are deliberately absent from what a portal caller may send.
});

export const agentCreateSchema = z.object({
  firstName: z.string().trim().min(1).max(120),
  lastName: z.string().trim().min(1).max(120),
  displayName: z.string().trim().max(200).optional(),
  title: z.string().trim().max(120).optional().or(z.literal("")),
  email: z.string().trim().toLowerCase().email().max(255).optional().or(z.literal("")),
  phone: z.string().trim().max(40).optional().or(z.literal("")),
  whatsapp: z.string().trim().max(40).optional().or(z.literal("")),
  bio: z.string().trim().max(8000).optional().or(z.literal("")),
  licenseNumber: z.string().trim().max(120).optional().or(z.literal("")),
  experienceYears: z.coerce.number().int().min(0).max(80).optional(),
  photoAssetId: z.string().max(40).optional().nullable(),
  isPubliclyVisible: z.boolean().optional(),
  specialties: z.array(z.string().max(60)).max(20).optional(),
  serviceAreas: z.array(z.union([z.string().max(120), z.number()])).max(30).optional(),
  languages: z.array(z.string().max(60)).max(20).optional(),
});

export const agentUpdateSchema = agentCreateSchema.partial().extend({
  status: z.enum(["draft", "pending", "active", "inactive", "suspended"]).optional(),
});

export async function getOrganization(organizationId) {
  const row = await queryOne(
    `SELECT o.*, co.name AS country_name, co.slug AS country_slug,
            st.name AS state_name, ct.name AS city_name,
            a.public_id AS account_public_id, a.listing_quota, a.listing_used
       FROM organizations o
       LEFT JOIN accounts a ON a.id = o.account_id
       LEFT JOIN locations co ON co.id = o.country_id
       LEFT JOIN locations st ON st.id = o.state_id
       LEFT JOIN locations ct ON ct.id = o.city_id
      WHERE o.id = ? AND o.deleted_at IS NULL`,
    [organizationId]
  );
  if (!row) throw AppError.notFound("That organization was not found.");

  const [serviceAreas, licenses, branches, categories] = await Promise.all([
    query(
      `SELECT l.id, l.name, osa.is_primary FROM organization_service_areas osa
         JOIN locations l ON l.id = osa.location_id WHERE osa.organization_id = ?
        ORDER BY osa.is_primary DESC, l.name`,
      [organizationId]
    ),
    query(
      `SELECT license_type, license_number, issuing_authority, issued_at, expires_at, status
         FROM organization_licenses WHERE organization_id = ? ORDER BY expires_at DESC`,
      [organizationId]
    ),
    query(
      `SELECT id, name, address_line1, phone, email, whatsapp, is_headquarters, status
         FROM organization_branches WHERE organization_id = ? ORDER BY is_headquarters DESC, name`,
      [organizationId]
    ).catch(() => []),
    categoryAccess(organizationId),
  ]);

  return {
    id: row.public_id,
    organizationId: String(row.id),
    accountId: row.account_public_id,
    slug: row.slug,
    name: row.name,
    displayName: row.name,
    legalName: row.legal_name,
    kind: row.kind,
    tagline: row.tagline,
    description: row.description,
    logo: row.logo_url,
    coverImage: row.cover_image_url,
    email: row.email,
    phone: row.phone,
    whatsapp: row.whatsapp,
    website: row.website_url,
    addressLine1: row.address_line1,
    addressLine2: row.address_line2,
    postalCode: row.postal_code,
    country: row.country_name,
    countrySlug: row.country_slug,
    state: row.state_name,
    city: row.city_name,
    foundedYear: int(row.founded_year),
    employeeCount: int(row.employee_count),
    status: row.status,
    verificationStatus: row.verification_status,
    verifiedAt: isoDate(row.verified_at),
    isPubliclyVisible: bool(row.is_publicly_visible),
    publicUrl: bool(row.is_publicly_visible) ? `/companies/${row.slug}` : null,
    listingCount: int(row.listing_count) ?? 0,
    activeListingCount: int(row.active_listing_count) ?? 0,
    agentCount: int(row.agent_count) ?? 0,
    reviewCount: int(row.review_count) ?? 0,
    rating: num(row.rating_avg),
    listingQuota: int(row.listing_quota),
    listingUsed: int(row.listing_used) ?? 0,
    serviceAreas: serviceAreas.map((area) => ({ id: String(area.id), name: area.name, isPrimary: bool(area.is_primary) })),
    licenses: licenses.map((license) => ({
      type: license.license_type,
      number: license.license_number,
      authority: license.issuing_authority,
      issuedAt: isoDate(license.issued_at),
      expiresAt: isoDate(license.expires_at),
      status: license.status,
    })),
    branches: branches.map((branch) => ({
      id: String(branch.id),
      name: branch.name,
      address: branch.address_line1,
      phone: branch.phone,
      email: branch.email,
      isHeadquarters: bool(branch.is_headquarters),
    })),
    categories,
    seo: { title: row.seo_title, description: row.seo_description },
    createdAt: isoDate(row.created_at),
    updatedAt: isoDate(row.updated_at),
  };
}

export async function updateOrganization({ organizationId, payload, req }) {
  await withTransaction(async (connection) => {
    const assignments = [];
    const params = [];
    const set = (column, value) => {
      assignments.push(`${column} = ?`);
      params.push(value);
    };

    if (payload.name !== undefined) set("name", payload.name);
    if (payload.legalName !== undefined) set("legal_name", payload.legalName || null);
    if (payload.tagline !== undefined) set("tagline", payload.tagline || null);
    if (payload.description !== undefined) set("description", payload.description || null);
    if (payload.email !== undefined) set("email", payload.email || null);
    if (payload.phone !== undefined) set("phone", payload.phone || null);
    if (payload.whatsapp !== undefined) set("whatsapp", payload.whatsapp || null);
    if (payload.website !== undefined) set("website_url", payload.website || null);
    if (payload.addressLine1 !== undefined) set("address_line1", payload.addressLine1 || null);
    if (payload.addressLine2 !== undefined) set("address_line2", payload.addressLine2 || null);
    if (payload.postalCode !== undefined) set("postal_code", payload.postalCode || null);
    if (payload.foundedYear !== undefined) set("founded_year", payload.foundedYear);
    if (payload.employeeCount !== undefined) set("employee_count", payload.employeeCount);
    if (payload.seoTitle !== undefined) set("seo_title", payload.seoTitle || null);
    if (payload.seoDescription !== undefined) set("seo_description", payload.seoDescription || null);

    if (payload.country !== undefined) {
      const country = payload.country ? await resolveLocation(payload.country, { type: "country" }) : null;
      set("country_id", country?.id ?? null);
    }
    if (payload.city !== undefined) {
      const city = payload.city ? await resolveLocation(payload.city, { type: "city" }) : null;
      set("city_id", city?.id ?? null);
      if (city) set("state_id", city.state_id ?? null);
    }
    for (const [field, column] of [["logoAssetId", "logo_url"], ["coverAssetId", "cover_image_url"]]) {
      if (payload[field] === undefined) continue;
      if (payload[field] === null) {
        set(column, null);
        continue;
      }
      const asset = await getAssetByPublicId(payload[field]);
      if (!asset) throw AppError.validation("Some information is invalid.", { [field]: "That image was not found." });
      if (asset.account_id && String(asset.account_id) !== String(req.auth.activeAccountId)) {
        throw AppError.forbidden("That image belongs to another account.");
      }
      set(column, asset.url);
    }

    if (assignments.length) {
      await execute(`UPDATE organizations SET ${assignments.join(", ")} WHERE id = ?`, [...params, organizationId], connection);
    }

    if (payload.serviceAreas) {
      await execute("DELETE FROM organization_service_areas WHERE organization_id = ?", [organizationId], connection);
      for (const [index, area] of payload.serviceAreas.entries()) {
        const location = await resolveLocation(area);
        if (location) {
          await execute(
            "INSERT INTO organization_service_areas (organization_id, location_id, is_primary, created_at) VALUES (?, ?, ?, NOW(3))",
            [organizationId, location.id, index === 0 ? 1 : 0],
            connection
          );
        }
      }
    }
  });

  return getOrganization(organizationId);
}

/* -------------------------------------------------------------------------- */
/* Agents                                                                      */
/* -------------------------------------------------------------------------- */

export async function listAgents({ organizationId, page = 1, pageSize = 20, search = "", status = "all" }) {
  const conditions = ["a.organization_id = ?", "a.deleted_at IS NULL"];
  const params = [organizationId];
  if (status !== "all") {
    conditions.push("a.status = ?");
    params.push(status);
  }
  const term = String(search || "").trim();
  if (term) {
    conditions.push("(a.display_name LIKE ? OR a.email LIKE ?)");
    params.push(`%${term}%`, `%${term}%`);
  }
  const where = `WHERE ${conditions.join(" AND ")}`;
  const safePage = Math.max(1, Number(page) || 1);
  const safeSize = Math.min(100, Math.max(1, Number(pageSize) || 20));
  const offset = (safePage - 1) * safeSize;

  const [rows, total] = await Promise.all([
    query(
      `SELECT a.*, o.slug AS organization_slug, o.name AS organization_name, o.website_url AS organization_website
         FROM agents a LEFT JOIN organizations o ON o.id = a.organization_id
         ${where} ORDER BY a.is_featured DESC, a.display_name ASC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM agents a ${where}`, params),
  ]);

  return {
    data: rows.map((row) => ({
      ...serializeAgent(row),
      isPubliclyVisible: bool(row.is_publicly_visible),
      publicUrl: bool(row.is_publicly_visible) ? `/agents/${row.slug}` : null,
    })),
    total: Number(total || 0),
    page: safePage,
    pageSize: safeSize,
  };
}

async function uniqueAgentSlug(base, connection) {
  const root = slugify(base) || "agent";
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const candidate = attempt === 0 ? root : `${root}-${attempt + 1}`;
    const taken = await queryValue("SELECT id FROM agents WHERE slug = ? LIMIT 1", [candidate], connection);
    if (!taken) return candidate;
  }
  return `${root}-${Date.now()}`;
}

export async function createAgent({ organizationId, payload, req }) {
  const publicId = ulid();
  const agentId = await withTransaction(async (connection) => {
    const displayName = payload.displayName?.trim() || `${payload.firstName} ${payload.lastName}`.trim();
    const slug = await uniqueAgentSlug(displayName, connection);

    let photoUrl = null;
    if (payload.photoAssetId) {
      const asset = await getAssetByPublicId(payload.photoAssetId);
      if (asset) photoUrl = asset.url;
    }

    const result = await execute(
      `INSERT INTO agents
         (public_id, user_id, organization_id, first_name, last_name, display_name, slug, title,
          bio, photo_url, email, phone, whatsapp, license_number, experience_years,
          status, verification_status, is_publicly_visible, joined_at, created_at)
       VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', 'unverified', ?, CURDATE(), NOW(3))`,
      [
        publicId,
        organizationId,
        payload.firstName,
        payload.lastName,
        displayName,
        slug,
        payload.title || null,
        payload.bio || null,
        photoUrl,
        payload.email || null,
        payload.phone || null,
        payload.whatsapp || null,
        payload.licenseNumber || null,
        payload.experienceYears ?? null,
        payload.isPubliclyVisible === false ? 0 : 1,
      ],
      connection
    );
    const id = result.insertId;
    await applyAgentRelations({ agentId: id, payload, connection });
    await execute(
      "UPDATE organizations SET agent_count = (SELECT COUNT(*) FROM agents WHERE organization_id = ? AND deleted_at IS NULL) WHERE id = ?",
      [organizationId, organizationId],
      connection
    );
    return id;
  });

  const created = await queryOne(
    `SELECT a.*, o.slug AS organization_slug, o.name AS organization_name FROM agents a
       LEFT JOIN organizations o ON o.id = a.organization_id WHERE a.id = ?`,
    [agentId]
  );
  return { ...serializeAgent(created), agentId: String(agentId) };
}

export async function updateAgent({ organizationId, agentPublicId, payload, req }) {
  const agent = await queryOne(
    "SELECT id, public_id FROM agents WHERE public_id = ? AND organization_id = ? AND deleted_at IS NULL",
    [agentPublicId, organizationId]
  );
  // Scoped by organization: another agency's agent is simply not found.
  if (!agent) throw AppError.notFound("That agent was not found.");

  await withTransaction(async (connection) => {
    const assignments = [];
    const params = [];
    const set = (column, value) => {
      assignments.push(`${column} = ?`);
      params.push(value);
    };
    if (payload.firstName !== undefined) set("first_name", payload.firstName);
    if (payload.lastName !== undefined) set("last_name", payload.lastName);
    if (payload.displayName !== undefined) set("display_name", payload.displayName);
    if (payload.title !== undefined) set("title", payload.title || null);
    if (payload.bio !== undefined) set("bio", payload.bio || null);
    if (payload.email !== undefined) set("email", payload.email || null);
    if (payload.phone !== undefined) set("phone", payload.phone || null);
    if (payload.whatsapp !== undefined) set("whatsapp", payload.whatsapp || null);
    if (payload.licenseNumber !== undefined) set("license_number", payload.licenseNumber || null);
    if (payload.experienceYears !== undefined) set("experience_years", payload.experienceYears);
    if (payload.isPubliclyVisible !== undefined) set("is_publicly_visible", payload.isPubliclyVisible ? 1 : 0);
    if (payload.status !== undefined) set("status", payload.status);
    if (payload.photoAssetId !== undefined) {
      if (payload.photoAssetId === null) set("photo_url", null);
      else {
        const asset = await getAssetByPublicId(payload.photoAssetId);
        if (!asset) throw AppError.validation("Some information is invalid.", { photoAssetId: "That image was not found." });
        set("photo_url", asset.url);
      }
    }
    if (assignments.length) {
      await execute(`UPDATE agents SET ${assignments.join(", ")} WHERE id = ?`, [...params, agent.id], connection);
    }
    await applyAgentRelations({ agentId: agent.id, payload, connection });
  });

  const updated = await queryOne(
    `SELECT a.*, o.slug AS organization_slug, o.name AS organization_name FROM agents a
       LEFT JOIN organizations o ON o.id = a.organization_id WHERE a.id = ?`,
    [agent.id]
  );
  return { ...serializeAgent(updated), agentId: String(agent.id) };
}

async function applyAgentRelations({ agentId, payload, connection }) {
  if (payload.languages) {
    await execute("DELETE FROM agent_languages WHERE agent_id = ?", [agentId], connection);
    for (const name of payload.languages) {
      const language = await queryOne("SELECT id FROM languages WHERE name = ? OR code = ? LIMIT 1", [name, name], connection);
      if (language) {
        await execute(
          "INSERT IGNORE INTO agent_languages (agent_id, language_id, proficiency) VALUES (?, ?, 'fluent')",
          [agentId, language.id],
          connection
        );
      }
    }
  }
  if (payload.specialties) {
    await execute("DELETE FROM agent_specialties WHERE agent_id = ?", [agentId], connection);
    for (const [index, name] of payload.specialties.entries()) {
      const category = await queryOne(
        "SELECT id FROM categories WHERE name = ? OR slug = ? OR code = ? LIMIT 1",
        [name, name, name],
        connection
      );
      if (category) {
        await execute(
          "INSERT IGNORE INTO agent_specialties (agent_id, category_id, is_primary) VALUES (?, ?, ?)",
          [agentId, category.id, index === 0 ? 1 : 0],
          connection
        );
      }
    }
  }
  if (payload.serviceAreas) {
    await execute("DELETE FROM agent_service_areas WHERE agent_id = ?", [agentId], connection);
    for (const [index, area] of payload.serviceAreas.entries()) {
      const location = await resolveLocation(area);
      if (location) {
        await execute(
          "INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES (?, ?, ?)",
          [agentId, location.id, index === 0 ? 1 : 0],
          connection
        );
      }
    }
  }
}

/* -------------------------------------------------------------------------- */
/* Category access                                                             */
/* -------------------------------------------------------------------------- */

/** Category access is per account now; the portal still addresses it by org. */
async function accountIdForOrganization(organizationId) {
  return queryValue("SELECT account_id FROM organizations WHERE id = ? LIMIT 1", [organizationId]);
}

export async function categoryAccess(organizationId) {
  const accountId = organizationId ? await accountIdForOrganization(organizationId) : null;
  if (!accountId) {
    return CATEGORY_DEFINITIONS.map((definition) => ({
      id: `cat_${definition.frontendId}`,
      categoryId: definition.frontendId,
      label: definition.listingType,
      status: "unavailable",
      requestedAt: null,
      approvedAt: null,
    }));
  }
  const rows = await query(
    `SELECT aca.id, aca.status, aca.requested_at, aca.reviewed_at, aca.notes, aca.listing_quota,
            aca.listing_used, COALESCE(c.root_category_id, c.id) AS root_category_id, c.name
       FROM account_category_access aca
       JOIN categories c ON c.id = aca.category_id
      WHERE aca.account_id = ?`,
    [accountId]
  );
  const byCategory = new Map(rows.map((row) => [frontendCategoryId(row.root_category_id), row]));

  return CATEGORY_DEFINITIONS.map((definition) => {
    const row = byCategory.get(definition.frontendId);
    return {
      id: row ? `ac_${row.id}` : `cat_${definition.frontendId}`,
      categoryId: definition.frontendId,
      label: row?.name ?? definition.listingType,
      status: row ? (row.status === "approved" ? "active" : row.status === "revoked" ? "rejected" : row.status) : "available",
      requestedAt: isoDate(row?.requested_at),
      approvedAt: row?.status === "approved" ? isoDate(row?.reviewed_at) : null,
      rejectionReason: row?.status === "rejected" ? row.notes : null,
      listingQuota: int(row?.listing_quota),
      listingUsed: int(row?.listing_used) ?? 0,
    };
  });
}

export async function assertCategoryAccess({ organizationId, category }) {
  const definition = resolveCategory(category);
  if (!definition) throw AppError.validation("Some information is invalid.", { category: "Unknown category." });
  const accountId = await accountIdForOrganization(organizationId);
  const approved = accountId
    ? await queryValue(
        `SELECT aca.id FROM account_category_access aca
           JOIN categories c ON c.id = aca.category_id
          WHERE aca.account_id = ? AND COALESCE(c.root_category_id, c.id) = ? AND aca.status = 'approved'
          LIMIT 1`,
        [accountId, definition.rootId]
      )
    : null;
  if (!approved) {
    throw AppError.forbidden("This account has not been approved to list in that category.");
  }
  return true;
}

export async function requestCategoryAccess({ organizationId, categoryId, note, userId }) {
  const definition = resolveCategory(categoryId);
  if (!definition) throw AppError.validation("Some information is invalid.", { categoryId: "Unknown category." });
  const accountId = await accountIdForOrganization(organizationId);
  if (!accountId) throw AppError.notFound("That account was not found.");

  const existing = await queryOne(
    `SELECT aca.id, aca.status FROM account_category_access aca
       JOIN categories c ON c.id = aca.category_id
      WHERE aca.account_id = ? AND COALESCE(c.root_category_id, c.id) = ?
      LIMIT 1`,
    [accountId, definition.rootId]
  );
  if (existing && ["approved", "requested"].includes(existing.status)) {
    throw AppError.conflict("Access to that category has already been requested.");
  }

  if (existing) {
    await execute(
      "UPDATE account_category_access SET status = 'requested', requested_at = NOW(3), requested_by_user_id = ?, notes = ? WHERE id = ?",
      [userId, note || null, existing.id]
    );
  } else {
    await execute(
      `INSERT INTO account_category_access
         (account_id, category_id, status, listing_used, requested_at, requested_by_user_id, notes, created_at)
       VALUES (?, ?, 'requested', 0, NOW(3), ?, ?, NOW(3))`,
      [accountId, definition.rootId, userId, note || null]
    );
  }
  return { categoryId: definition.frontendId, status: "requested" };
}

export async function reviewAccessRequest({ organizationId, publicId, status, note, reviewerId }) {
  return withTransaction(async (connection) => {
    const request = await queryOne(
      "SELECT id, user_id, requested_role, status FROM access_requests WHERE public_id = ? AND organization_id = ?",
      [publicId, organizationId],
      connection
    );
    if (!request) throw AppError.notFound("That request was not found.");
    if (request.status !== "pending") throw AppError.conflict("That request has already been reviewed.");

    await execute(
      "UPDATE access_requests SET status = ?, reviewed_by_user_id = ?, reviewed_at = NOW(3), response_note = ? WHERE id = ?",
      [status, reviewerId, note || null, request.id],
      connection
    );

    if (status === "approved") {
      const accountId = await queryValue("SELECT account_id FROM organizations WHERE id = ?", [organizationId], connection);
      // Approving a request creates the membership; the two must not diverge.
      await execute(
        `INSERT INTO account_members
           (account_id, user_id, role, status, can_manage_listings, can_publish_listings, can_manage_leads, joined_at, created_at)
         VALUES (?, ?, ?, 'active', ?, 0, ?, NOW(3), NOW(3))
         ON DUPLICATE KEY UPDATE status = 'active', role = VALUES(role), joined_at = NOW(3)`,
        [
          accountId,
          request.user_id,
          request.requested_role,
          request.requested_role === "viewer" ? 0 : 1,
          request.requested_role === "viewer" ? 0 : 1,
        ],
        connection
      );
    }
    return { id: request.id, status };
  });
}

/* -------------------------------------------------------------------------- */
/* API clients                                                                 */
/* -------------------------------------------------------------------------- */

export async function createApiClient({ organizationId, name, scopes, userId }) {
  const accountId = await queryValue("SELECT account_id FROM organizations WHERE id = ?", [organizationId]);
  const publicId = ulid();
  const clientId = `lf_${crypto.randomBytes(16).toString("hex")}`;
  const secret = randomToken(32);

  await execute(
    `INSERT INTO api_clients
       (public_id, account_id, organization_id, name, client_id, secret_hash, secret_hint,
        scopes, rate_limit_per_minute, status, created_by_user_id, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, CAST(? AS JSON), 120, 'active', ?, NOW(3))`,
    [publicId, accountId, organizationId, name, clientId, sha256(secret), secret.slice(-6), JSON.stringify(scopes), userId]
  );

  // The secret is returned exactly once. Only its SHA-256 is stored, so it
  // cannot be recovered from the database later.
  return { id: publicId, name, clientId, secret, scopes, createdAt: new Date().toISOString() };
}

export async function revokeApiClient({ organizationId, publicId }) {
  const result = await execute(
    "UPDATE api_clients SET status = 'revoked', revoked_at = NOW(3) WHERE public_id = ? AND organization_id = ?",
    [publicId, organizationId]
  );
  if (!result.affectedRows) throw AppError.notFound("That credential was not found.");
  return true;
}
