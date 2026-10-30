import { query } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { sha256Hex } from "../../utils/ids.js";
import logger from "../../config/logger.js";
import { resolveCategory } from "../../utils/categories.js";
import * as importsRepo from "../imports/imports.repository.js";
import { processImport } from "../imports/importRunner.js";
import { notifyRejectedListings } from "../imports/rejectionNotice.service.js";
import { DETAIL_COLUMNS, DETAIL_TABLE } from "../listings/listings.service.js";
import { scopeClause } from "../portal/engagement.repository.js";
import { IMPORT_CATEGORIES } from "../imports/listingImport.service.js";
import { FEED_CATEGORIES, feedFormat } from "./feedFormats.js";
import { parseFeed, parsePushedXml } from "./feedParser.js";

/**
 * A client's own XML and CSV links (Scenario 2, docs/integrations/LISTING-PUSH-PLAN.md). The
 * client's system pushes a file to its link, and the same link reads back all of its listings:
 * what it pushed, as it pushed it, and what was made in the portal.
 *
 * A push adds and updates; it never withdraws what is missing from the file. Each category in a
 * file becomes one import, processed by the same runner as a JSON batch, so its results show in
 * the same places.
 */

/** Reads the file and queues one import per category. A file that cannot be read throws a 422. */
export async function acceptPush({ client, ctx, category = null, content, ip, userAgent }) {
  const parsed = category ? [parseFeed({ category, format: "csv", content })] : parsePushedXml(content);
  const checksum = sha256Hex(content);

  const imports = [];
  // A file read from the link carries an empty section for every category with nothing in it.
  for (const result of parsed.filter((entry) => entry.items.length)) {
    const entityType = result.entity === "development" ? "project" : "listing";
    const rejected = result.items.filter((item) => item.errors);
    const accepted = result.items.length - rejected.length;
    const run = await importsRepo.createImportRun({
      client,
      ctx,
      type: "full",
      total: result.items.length,
      status: accepted ? "queued" : "running",
      ip,
      userAgent,
      file: { checksum, sizeBytes: content.length, entityType },
    });
    const invalid = (item) => new AppError("This entry in the file is invalid.", { status: 422, code: "VALIDATION_ERROR", fields: item.errors });
    await importsRepo.addImportItems(
      run.id,
      result.items.map((item) => ({ row: item.row, externalId: item.externalId, raw: item.record, error: item.errors ? invalid(item) : undefined })),
      { entityType }
    );
    if (accepted) {
      // Started on the next tick so the caller gets its 202 first. The runner in server.js picks
      // the import up again if this process stops before it finishes.
      setImmediate(() => processImport(run.id).catch((error) => logger.error({ err: error }, "pushed file import failed")));
    } else {
      await importsRepo.finalizeImport(run.id);
      await notifyRejectedListings(run.id).catch((error) => logger.error({ err: error }, "rejection notice failed"));
    }
    imports.push({
      id: run.publicId,
      category: result.category,
      total: result.items.length,
      accepted,
      rejected: rejected.slice(0, 500).map((item) => ({ row: item.row, externalId: item.externalId, errors: item.errors })),
      warnings: result.warnings,
    });
  }
  return { imports };
}

/** The categories an account is approved for, in format order. */
async function approvedCategories(accountId) {
  const roots = await query(
    `SELECT DISTINCT COALESCE(c.root_category_id, c.id) AS root_id
       FROM account_category_access aca JOIN categories c ON c.id = aca.category_id
      WHERE aca.account_id = ? AND aca.status = 'approved'`,
    [accountId]
  );
  const approved = new Set(roots.map((row) => Number(row.root_id)));
  return FEED_CATEGORIES.filter((category) => approved.has(category === "developments" ? 7 : resolveCategory(category)?.rootId));
}

const BATCH = 1000;
const LISTING_CATEGORIES = IMPORT_CATEGORIES.map((category) => ({ category, rootId: resolveCategory(category).rootId }));

/**
 * What a client last pushed for each of its listings, with each one's current LivFinder status.
 * It reads the stored push, not the listing: a pending edit or a moderator's change would
 * otherwise look like something the client sent, and pushing the file back would undo it.
 */
async function pushedEntries(ctx) {
  const latest = await query(
    `SELECT MAX(i.id) AS id
       FROM feed_import_items i JOIN feed_imports r ON r.id = i.import_id
      WHERE r.connection_id = ? AND i.status IN ('success', 'warning') AND i.operation <> 'delete'
      GROUP BY i.external_id, i.entity_type`,
    [ctx.connectionId]
  );
  const statuses = await query(
    `SELECT er.external_id, er.entity_type, er.entity_id, COALESCE(l.status, p.moderation_status) AS status
       FROM external_references er
       LEFT JOIN listings l ON er.entity_type = 'listing' AND l.id = er.entity_id AND l.deleted_at IS NULL
       LEFT JOIN projects p ON er.entity_type = 'project' AND p.id = er.entity_id AND p.deleted_at IS NULL
      WHERE er.provider_id = ? AND er.connection_id = ?`,
    [ctx.providerId, ctx.connectionId]
  );
  const statusOf = new Map(statuses.filter((row) => row.status).map((row) => [`${row.entity_type}:${row.external_id}`, row]));

  const entries = [];
  for (let start = 0; start < latest.length; start += BATCH) {
    const ids = latest.slice(start, start + BATCH).map((row) => row.id);
    const rows = await query(
      `SELECT external_id, entity_type, raw_payload FROM feed_import_items WHERE id IN (${ids.map(() => "?").join(", ")})`,
      ids
    );
    for (const row of rows) {
      const reference = statusOf.get(`${row.entity_type}:${row.external_id}`);
      if (!reference) continue; // deleted on LivFinder since
      const record = typeof row.raw_payload === "string" ? JSON.parse(row.raw_payload) : row.raw_payload;
      const category = row.entity_type === "project" ? "developments" : record?.category;
      if (feedFormat(category)) entries.push({ category, record, status: reference.status, entityId: reference.entity_id });
    }
  }
  return entries.sort((a, b) => String(a.record.externalId).localeCompare(String(b.record.externalId)));
}

const asDate = (value) => (value instanceof Date ? value.toISOString().slice(0, 10) : value);

/** The record a listing made in the portal would be pushed as, in the same fields as a file. */
function recordFromListing(row, { detail, images, features }) {
  const definition = LISTING_CATEGORIES.find((entry) => entry.rootId === Number(row.root_category_id));
  const detailValues = {};
  for (const [key, column] of Object.entries(DETAIL_COLUMNS[definition.category] ?? {})) {
    const value = detail?.[column];
    if (value !== null && value !== undefined) detailValues[key] = typeof value === "string" && /^-?\d+\.\d+$/.test(value) ? Number(value) : asDate(value);
  }
  return {
    // Its LivFinder reference: sending this back updates this listing, not a copy of it.
    externalId: row.source_reference || row.reference,
    category: definition.category,
    purpose: row.purpose_code,
    propertyType: row.category_code,
    title: row.title,
    subtitle: row.subtitle,
    description: row.description,
    price: row.price === null ? null : Number(row.price),
    currency: row.currency_code,
    priceType: row.price_type,
    pricePeriod: row.price_period,
    location: { country: row.country_name, state: row.state_name, city: row.city_name, community: row.community_name, subCommunity: row.sub_community_name },
    address: row.address,
    postalCode: row.postal_code,
    latitude: row.latitude === null ? null : Number(row.latitude),
    longitude: row.longitude === null ? null : Number(row.longitude),
    agentEmail: row.agent_email,
    contactName: row.contact_name,
    contactPhone: row.contact_phone,
    contactWhatsapp: row.contact_whatsapp,
    contactEmail: row.contact_email,
    brand: row.brand_name,
    model: row.model_name,
    features,
    images,
    seoTitle: row.seo_title,
    seoDescription: row.seo_description,
    detail: detailValues,
  };
}

const inList = (ids) => ids.map(() => "?").join(", ");

/** Every listing on the account that the client did not push, or whose push was not kept. */
async function accountListings(scope, skip, rootId = null) {
  const clause = scopeClause("l", scope);
  const rows = (await query(
    `SELECT l.*, pu.code AS purpose_code, c.code AS category_code, b.name AS brand_name, bm.name AS model_name, ag.email AS agent_email,
            co.name AS country_name, st.name AS state_name, ci.name AS city_name, cm.name AS community_name, sc.name AS sub_community_name
       FROM listings l
       LEFT JOIN purposes pu ON pu.id = l.purpose_id
       LEFT JOIN categories c ON c.id = l.category_id
       LEFT JOIN brands b ON b.id = l.brand_id
       LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
       LEFT JOIN agents ag ON ag.id = l.agent_id
       LEFT JOIN locations co ON co.id = l.country_id
       LEFT JOIN locations st ON st.id = l.state_id
       LEFT JOIN locations ci ON ci.id = l.city_id
       LEFT JOIN locations cm ON cm.id = l.community_id
       LEFT JOIN locations sc ON sc.id = l.sub_community_id
      WHERE ${clause.sql} AND l.deleted_at IS NULL ${rootId ? "AND l.root_category_id = ?" : ""}
      ORDER BY l.id ASC`,
    rootId ? [...clause.params, rootId] : clause.params
  )).filter((row) => !skip.has(Number(row.id)) && LISTING_CATEGORIES.some((entry) => entry.rootId === Number(row.root_category_id)));

  const entries = [];
  for (let start = 0; start < rows.length; start += BATCH) {
    const batch = rows.slice(start, start + BATCH);
    const ids = batch.map((row) => row.id);
    const [media, features] = await Promise.all([
      query(
        `SELECT listing_id, url FROM listing_media WHERE listing_id IN (${inList(ids)}) AND media_type = 'image' AND is_public = 1
          ORDER BY listing_id, is_cover DESC, sort_order ASC, id ASC`,
        ids
      ),
      query(`SELECT lf.listing_id, f.name FROM listing_features lf JOIN features f ON f.id = lf.feature_id WHERE lf.listing_id IN (${inList(ids)})`, ids),
    ]);
    const group = (list, value) => list.reduce((map, row) => map.set(row.listing_id, [...(map.get(row.listing_id) ?? []), value(row)]), new Map());
    const imagesOf = group(media, (row) => row.url);
    const featuresOf = group(features, (row) => row.name);
    const details = new Map();
    for (const definition of LISTING_CATEGORIES) {
      const inCategory = batch.filter((row) => Number(row.root_category_id) === definition.rootId).map((row) => row.id);
      if (!inCategory.length) continue;
      const found = await query(`SELECT * FROM ${DETAIL_TABLE[definition.category]} WHERE listing_id IN (${inList(inCategory)})`, inCategory);
      for (const row of found) details.set(row.listing_id, row);
    }
    for (const row of batch) {
      const record = recordFromListing(row, { detail: details.get(row.id), images: imagesOf.get(row.id) ?? [], features: featuresOf.get(row.id) ?? [] });
      entries.push({ category: record.category, record, status: row.status });
    }
  }
  return entries;
}

/** A development the client did not push, in the same fields as a file. */
function recordFromDevelopment(project) {
  const plans = (project.paymentPlans ?? []).map((plan) => ({ ...plan, planType: plan.type }));
  const units = (project.unitTypes ?? []).map((unit) => ({
    unitType: unit.type,
    name: unit.name,
    bedrooms: unit.bedrooms,
    bathrooms: unit.bathrooms,
    minSize: unit.sizeRange?.min,
    maxSize: unit.sizeRange?.max,
    areaUnit: unit.sizeRange?.unit,
    startingPrice: unit.startingPrice?.amount,
    maxPrice: unit.maxPrice?.amount,
    currency: unit.startingPrice?.currency,
    availability: unit.availability,
    availableUnits: unit.availableUnits,
    totalUnits: unit.totalUnits,
  }));
  return {
    externalId: project.reference || project.id,
    name: project.name,
    tagline: project.tagline,
    description: typeof project.description === "object" ? project.description?.body : project.description,
    marketingHeading: project.marketingHeading,
    highlights: project.highlights,
    projectType: project.projectType,
    ownershipType: project.ownershipType,
    status: project.developmentStatus,
    launchStatus: project.launchStatus,
    completionPercentage: project.completionPercentage,
    totalUnits: project.totalUnits,
    availableUnits: project.availableUnits,
    buildingCount: project.buildingsCount,
    minPrice: project.priceRange?.min ?? project.startingPrice,
    maxPrice: project.priceRange?.max,
    currency: project.currency,
    location: project.location,
    address: project.address,
    latitude: project.latitude,
    longitude: project.longitude,
    amenities: (project.amenities ?? []).map((amenity) => (typeof amenity === "string" ? amenity : amenity.name)),
    images: (project.media?.gallery ?? []).map((item) => item.url).filter(Boolean),
    brochureUrl: project.brochureUrl,
    seoTitle: project.seo?.title,
    seoDescription: project.seo?.description,
    unitTypes: units,
    paymentPlans: plans,
  };
}

async function accountDevelopments(scope, skip) {
  if (!scope.organizationId) return [];
  const projects = await query("SELECT id, public_id FROM projects WHERE organization_id = ? AND deleted_at IS NULL ORDER BY id ASC", [scope.organizationId]);
  const { getAdminDevelopment } = await import("../admin/admin.catalog.js");
  const entries = [];
  for (const project of projects.filter((row) => !skip.has(`project:${row.id}`))) {
    const full = await getAdminDevelopment(project.public_id);
    if (full) entries.push({ category: "developments", record: recordFromDevelopment(full), status: full.moderationStatus ?? full.status });
  }
  return entries;
}

async function everyEntry({ accountId, organizationId, ctx, category = null }) {
  const pushed = await pushedEntries(ctx);
  const skip = new Set(pushed.map((entry) => (entry.category === "developments" ? `project:${entry.entityId}` : Number(entry.entityId))));
  const scope = { accountId, organizationId };
  const definition = LISTING_CATEGORIES.find((entry) => entry.category === category);
  const listings = category === "developments" ? [] : await accountListings(scope, skip, definition?.rootId ?? null);
  const developments = !category || category === "developments" ? await accountDevelopments(scope, skip) : [];
  return [...pushed, ...listings, ...developments];
}

/** Every category the account can use, each with all of its listings. */
export async function pushedSections({ accountId, organizationId = null, ctx }) {
  const [categories, entries] = await Promise.all([approvedCategories(accountId), everyEntry({ accountId, organizationId, ctx })]);
  // A category whose access was later withdrawn still shows the listings in it.
  const names = new Set([...categories, ...entries.map((entry) => entry.category)]);
  return FEED_CATEGORIES.filter((category) => names.has(category)).map((category) => ({
    category,
    entries: entries.filter((entry) => entry.category === category),
  }));
}

export async function pushedInCategory({ accountId, organizationId = null, ctx, category }) {
  return (await everyEntry({ accountId, organizationId, ctx, category })).filter((entry) => entry.category === category);
}
