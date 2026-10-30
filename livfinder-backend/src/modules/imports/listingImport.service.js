import path from "node:path";
import { z } from "zod";
import env from "../../config/env.js";
import { getPool } from "../../db/pool.js";
import { execute, query, queryOne, queryValue } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { sha256Hex } from "../../utils/ids.js";
import { safeFetch } from "../../utils/safeFetch.js";
import { slugify } from "../../utils/slug.js";
import { CATEGORY_PURPOSES, resolveCategory } from "../../utils/categories.js";
import { DETAIL_SCHEMAS, createListingSchema, updateListingSchema } from "../listings/listings.schemas.js";
import * as listingsService from "../listings/listings.service.js";
import { resolveCountryByCode, resolveLocation } from "../locations/locations.repository.js";
import { MAX_IMAGE_BYTES, storeImage } from "../media/media.service.js";
import { findMapping, recordUnmapped } from "../feeds/valueMappings.js";
import { removeListingMedia, reorderListingMedia } from "../media/listingMedia.service.js";
import { recordAudit } from "../system/audit.service.js";

/**
 * One listing in, one listing out: the shared path for every way a company pushes listings.
 *
 * A record is validated with the partner's own field names, translated into the payload the
 * portal already saves (`listingsService.createListing` / `updateListing`), and held to the same
 * rules as a listing made by hand: category approval, plan allowance, and re-approval of any
 * change to a live listing. The partner's id (`externalId`) is matched to our listing through
 * `external_references` under the company's own connection, so a partner can only ever reach the
 * listings it created for that company.
 */

export const IMPORT_CATEGORIES = ["real-estate", "cars", "yachts", "jets", "helicopters", "watches"];
export const MAX_IMAGES_PER_LISTING = 30;
// The same number as `feeds/listingRequirements.js`, which cannot be imported here at load time.
const MIN_IMAGES = 3;
const MAX_IMAGE_REDIRECTS = 3;
const IMAGE_TIMEOUT_MS = 20_000;
const IMAGE_CONCURRENCY = 4;
const CLOSED_STATUSES = new Set(["sold", "rented", "archived"]);

const text = (max) => z.string().trim().max(max);
const optionalText = (max) => text(max).optional().nullable();

export const listingRecordSchema = z
  .object({
    externalId: z
      .string()
      .trim()
      .min(1, "Give the listing's id in your system.")
      .max(191)
      .regex(/^\S+$/, "The id cannot contain spaces."),
    category: z.enum(IMPORT_CATEGORIES, { message: `Use one of: ${IMPORT_CATEGORIES.join(", ")}.` }),
    purpose: optionalText(20),
    propertyType: optionalText(80),
    title: z.string().trim().min(4, "Give a title of at least 4 characters.").max(255),
    subtitle: optionalText(255),
    description: optionalText(50_000),
    price: z.coerce.number().min(0).max(1e15).optional().nullable(),
    currency: z.string().trim().length(3, "Use a 3-letter currency code, such as AED.").toUpperCase().optional(),
    priceType: optionalText(20),
    pricePeriod: optionalText(20),
    isPriceHidden: z.boolean().optional(),
    location: z
      .object({
        id: z.union([z.string().max(40), z.number()]).optional(),
        country: optionalText(120),
        state: optionalText(180),
        city: optionalText(180),
        community: optionalText(180),
        subCommunity: optionalText(180),
      })
      .strict()
      .optional(),
    address: optionalText(500),
    postalCode: optionalText(30),
    latitude: z.coerce.number().min(-90).max(90).optional().nullable(),
    longitude: z.coerce.number().min(-180).max(180).optional().nullable(),
    hideExactLocation: z.boolean().optional(),
    agentEmail: z.string().trim().email("Give a valid email address.").max(255).optional().nullable(),
    contactName: optionalText(200),
    contactPhone: optionalText(40),
    contactWhatsapp: optionalText(40),
    contactEmail: optionalText(255),
    allowCall: z.boolean().optional(),
    allowWhatsapp: z.boolean().optional(),
    allowEmail: z.boolean().optional(),
    brand: optionalText(160),
    model: optionalText(180),
    features: z.array(text(120)).max(200).optional(),
    images: z
      .array(z.string().trim().url("Each image must be a full URL.").max(2000))
      .max(MAX_IMAGES_PER_LISTING, `Send at most ${MAX_IMAGES_PER_LISTING} images.`)
      .optional(),
    detail: z.record(z.string(), z.unknown()).optional(),
    seoTitle: optionalText(255),
    seoDescription: optionalText(500),
    status: z.enum(["draft", "pending_review"]).optional(),
  })
  .strict();

// Internal payload keys reported back under the names the partner sent.
const FIELD_NAMES = {
  categorySlug: "propertyType",
  locationId: "location",
  agentId: "agentEmail",
  mediaAssetIds: "images",
};

function fieldsFromIssues(issues, prefix = "") {
  const fields = {};
  for (const issue of issues) {
    const [head, ...rest] = issue.path.map(String);
    const name = [FIELD_NAMES[head] || head, ...rest].filter(Boolean).join(".");
    const key = `${prefix}${name}` || "_";
    if (!fields[key]) fields[key] = issue.code === "unrecognized_keys" ? `Unknown field(s): ${issue.keys.join(", ")}.` : issue.message;
  }
  return fields;
}

export function importValidationError(fields, message = "Some information in this listing is invalid.") {
  return new AppError(message, { status: 422, code: "VALIDATION_ERROR", fields });
}

/** Parses a raw record; throws a 422 with partner-facing field names. */
export function parseListingRecord(raw) {
  const parsed = listingRecordSchema.safeParse(raw ?? {});
  if (!parsed.success) throw importValidationError(fieldsFromIssues(parsed.error.issues));
  return parsed.data;
}

function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  }
  return value;
}

/** What "the same push again" means: the record, keys sorted, hashed. */
export function payloadHash(record) {
  return sha256Hex(JSON.stringify(stable(record))).slice(0, 32);
}

/* -------------------------------------------------------------------------- */
/* Resolving the partner's words into ours                                     */
/* -------------------------------------------------------------------------- */

async function resolvePropertyType(definition, value) {
  if (!value) return undefined;
  const slug = slugify(value);
  const row = await queryOne(
    `SELECT code FROM categories
      WHERE root_category_id = ? AND deleted_at IS NULL AND (code = ? OR slug = ? OR LOWER(name) = LOWER(?))
      LIMIT 1`,
    [definition.rootId, value, slug, value]
  );
  if (row) return row.code;
  // A type an admin mapped from a company's own word (Phase 5); otherwise it joins their queue.
  const mapped = await findMapping({ type: "category", value, scope: definition.rootId });
  if (mapped?.value) return mapped.value;
  await recordUnmapped({ type: "category", value, scope: definition.rootId, label: `${value} (${definition.label})` });
  const allowed = await query(
    "SELECT code FROM categories WHERE root_category_id = ? AND id <> ? AND deleted_at IS NULL ORDER BY sort_order, code LIMIT 40",
    [definition.rootId, definition.rootId]
  );
  throw new AppError("This listing uses a value LivFinder does not recognise.", {
    status: 422,
    code: "UNMAPPED_VALUE",
    fields: {
      propertyType: `Unknown property type "${value}".${allowed.length ? ` Use one of: ${allowed.map((r) => r.code).join(", ")}.` : ""}`,
    },
  });
}

const LOCATION_STEPS = [
  { key: "state", levels: ["state"], label: "state" },
  { key: "city", levels: ["city"], label: "city" },
  { key: "community", levels: ["community", "district"], label: "community" },
  { key: "subCommunity", levels: ["sub_community"], label: "sub-community" },
];

const ANCESTOR_COLUMN = { country: "country_id", state: "state_id", city: "city_id", community: "community_id" };

async function findCountry(value) {
  const byCode = await resolveCountryByCode(value);
  if (byCode) return byCode;
  return queryOne(
    `SELECT id, name FROM locations
      WHERE level = 'country' AND deleted_at IS NULL AND (slug = ? OR LOWER(name) = LOWER(?)) LIMIT 1`,
    [slugify(value), value]
  );
}

/** A place's own name and everything above it, for telling a client where it really is. */
const PLACE_WITH_PARENTS = `
  SELECT l.id, l.level, l.name, l.slug, co.id AS country_id, co.name AS country, st.name AS state, ci.name AS city, cm.name AS community
    FROM locations l
    LEFT JOIN locations co ON co.id = l.country_id
    LEFT JOIN locations st ON st.id = l.state_id
    LEFT JOIN locations ci ON ci.id = l.city_id
    LEFT JOIN locations cm ON cm.id = l.community_id`;

const whereItIs = (place) => [place.community, place.city, place.state, place.country].filter(Boolean).join(", ");

const sameName = (value, name) => slugify(String(value)) === slugify(String(name ?? ""));

/**
 * A place the client named that exists, but not under the parent it gave: "Texas" in the United
 * Arab Emirates. That is a mistake in the file, not a new place, so it is reported with where the
 * place really is and stays out of the admin's mapping queue.
 */
async function wrongParent(step, value, parentName) {
  const elsewhere = await query(
    `${PLACE_WITH_PARENTS}
      WHERE l.level IN (${step.levels.map(() => "?").join(", ")}) AND l.deleted_at IS NULL AND l.status = 'active'
        AND (l.slug = ? OR LOWER(l.name) = LOWER(?))
      ORDER BY l.active_listing_count DESC, l.id ASC LIMIT 3`,
    [...step.levels, slugify(value), value]
  );
  if (!elsewhere.length) return null;
  const places = elsewhere.map(whereItIs).filter(Boolean).join("; ");
  return importValidationError(
    { [`location.${step.key}`]: `The ${step.label} "${value}" is not in ${parentName}. LivFinder has it in: ${places}.` },
    "This listing's location does not fit together."
  );
}

/** Names sent beside a `location.id` must describe that same place; the id is never taken over them. */
async function assertNamesMatchId(location, id) {
  const place = await queryOne(`${PLACE_WITH_PARENTS} WHERE l.id = ?`, [id]);
  const own = (level) => (place.level === level ? place.name : null);
  const fields = {};
  const given = {
    state: place.state ?? own("state"),
    city: place.city ?? own("city"),
    community: place.community ?? own("community") ?? own("district"),
    subCommunity: own("sub_community"),
  };
  if (location.country) {
    const country = await findCountry(location.country);
    if (country?.id !== (place.country_id ?? place.id)) {
      fields["location.country"] = `The country "${location.country}" does not match location id ${id}, which is ${place.name}${whereItIs(place) ? `, ${whereItIs(place)}` : ""}.`;
    }
  }
  for (const [key, actual] of Object.entries(given)) {
    if (location[key] && !sameName(location[key], actual)) {
      fields[`location.${key}`] = `"${location[key]}" does not match location id ${id}, which is ${place.name}${whereItIs(place) ? `, ${whereItIs(place)}` : ""}.`;
    }
  }
  if (Object.keys(fields).length) throw importValidationError(fields, "This listing's location does not fit together.");
}

/** `location.id` (ours), or names walked down from the country. Returns our numeric location id. */
export async function resolveImportLocation(location) {
  if (!location) {
    throw importValidationError({ location: "Give the listing's location, at least its country." });
  }
  if (location.id !== undefined && location.id !== null && location.id !== "") {
    const row = await resolveLocation(location.id);
    if (!row) throw importValidationError({ "location.id": "That location id was not found." });
    await assertNamesMatchId(location, row.id);
    return row.id;
  }
  if (!location.country) throw importValidationError({ "location.country": "Give the country, as a 2-letter code or a name." });

  const country = await findCountry(location.country);
  if (!country) {
    throw new AppError("This listing uses a value LivFinder does not recognise.", {
      status: 422,
      code: "UNMAPPED_VALUE",
      fields: { "location.country": `No country "${location.country}" was found.` },
    });
  }

  let current = { id: country.id, level: "country", name: country.name };
  const chain = { country: country.id };
  for (const step of LOCATION_STEPS) {
    const value = location[step.key];
    if (!value) continue;
    // Constrained by every ancestor already matched, so "Downtown" resolves inside the right city.
    const conditions = [];
    const params = [];
    for (const [level, id] of Object.entries(chain)) {
      conditions.push(`l.${ANCESTOR_COLUMN[level]} = ?`);
      params.push(id);
    }
    const row = await queryOne(
      `SELECT l.id, l.level, l.name FROM locations l
        WHERE l.level IN (${step.levels.map(() => "?").join(", ")})
          AND l.deleted_at IS NULL AND l.status = 'active'
          AND (l.slug = ? OR LOWER(l.name) = LOWER(?))
          AND ${conditions.join(" AND ")}
        ORDER BY l.active_listing_count DESC, l.id ASC
        LIMIT 1`,
      [...step.levels, slugify(value), value, ...params]
    );
    // A place an admin mapped from the company's own name for it (Phase 5), within the same parent.
    const mapped = row ? null : await findMapping({ type: "location", value, scope: current.id });
    const match = row || (mapped?.id ? await queryOne("SELECT id, level, name FROM locations WHERE id = ? AND deleted_at IS NULL", [mapped.id]) : null);
    if (!match) {
      const misplaced = await wrongParent(step, value, current.name);
      if (misplaced) throw misplaced;
      await recordUnmapped({ type: "location", value, scope: current.id, label: `${value} (${step.label} in ${current.name})` });
      throw new AppError("This listing uses a value LivFinder does not recognise.", {
        status: 422,
        code: "UNMAPPED_VALUE",
        fields: {
          [`location.${step.key}`]: `No ${step.label} named "${value}" was found in ${current.name}. LivFinder has been asked to map it; the listing goes through on a later run.`,
        },
      });
    }
    chain[step.key === "subCommunity" ? "community" : step.key] = match.id;
    current = match;
  }
  return current.id;
}

async function resolveAgent(organizationId, email, warnings) {
  if (!organizationId) {
    if (email) warnings.push("Agents belong to companies; agentEmail was ignored for this account.");
    return null;
  }
  // A company with agents lists through one of them, as the portal form asks.
  const hasAgents = await queryValue("SELECT 1 FROM agents WHERE organization_id = ? AND deleted_at IS NULL LIMIT 1", [organizationId]);
  if (!email) {
    if (hasAgents) throw importValidationError({ agentEmail: "Give the email of the agent for this listing." });
    return null;
  }
  const row = await queryOne(
    `SELECT id FROM agents
      WHERE organization_id = ? AND LOWER(email) = LOWER(?) AND deleted_at IS NULL
      ORDER BY status = 'active' DESC, id ASC LIMIT 1`,
    [organizationId, email]
  );
  if (!row) throw importValidationError({ agentEmail: `No agent with the email ${email} is on this company.` });
  return row.id;
}

/* -------------------------------------------------------------------------- */
/* Images                                                                      */
/* -------------------------------------------------------------------------- */

// Stands in for the network in tests, as `setWebhookTransport` does for webhooks.
let fetchImage = downloadImage;
export function setImageFetcher(fn) {
  fetchImage = fn ?? downloadImage;
}

async function downloadImage(url) {
  // CDNs redirect image links all the time. Each hop goes through `safeFetch`, so a redirect
  // cannot lead to an address a client could not have sent directly.
  let current = url;
  let response;
  for (let hop = 0; hop <= MAX_IMAGE_REDIRECTS; hop += 1) {
    response = await safeFetch(current, { useAllowList: false, timeoutMs: IMAGE_TIMEOUT_MS, headers: { Accept: "image/*" }, redirect: "manual" });
    const location = response.headers.get("location");
    if (![301, 302, 303, 307, 308].includes(response.status) || !location) break;
    if (hop === MAX_IMAGE_REDIRECTS) throw new Error("the image link redirected too many times");
    current = new URL(location, current).href;
  }
  if (!response.ok) throw new Error(`the image host answered ${response.status}`);
  const declared = Number(response.headers.get("content-length"));
  if (declared && declared > MAX_IMAGE_BYTES) throw new Error("the image is larger than 15 MB");
  const buffer = Buffer.from(await response.arrayBuffer());
  if (buffer.length > MAX_IMAGE_BYTES) throw new Error("the image is larger than 15 MB");
  if (!buffer.length) throw new Error("the image is empty");
  return buffer;
}

/**
 * Fetches each URL once per company: a URL already imported for this connection reuses its
 * stored asset, so a re-push does not download unchanged photographs again.
 */
export async function importImages({ urls, ctx, accountId, userId }) {
  const results = new Array(urls.length);
  let next = 0;
  const worker = async () => {
    while (next < urls.length) {
      const index = next++;
      const url = urls[index];
      const urlKey = sha256Hex(url);
      try {
        const cached = await queryOne(
          `SELECT ma.id, ma.public_id FROM external_references er
             JOIN media_assets ma ON ma.id = er.entity_id AND ma.deleted_at IS NULL
            WHERE er.provider_id = ? AND er.connection_id = ? AND er.entity_type = 'media' AND er.external_id = ?
            LIMIT 1`,
          [ctx.providerId, ctx.connectionId, urlKey]
        );
        if (cached) {
          results[index] = { url, assetId: Number(cached.id), publicId: cached.public_id };
          continue;
        }
        const buffer = await fetchImage(url);
        let fileName = "image";
        try {
          fileName = path.basename(new URL(url).pathname) || "image";
        } catch { /* keep the default */ }
        const asset = await storeImage({ buffer, originalFileName: fileName, accountId, userId, scope: "listings", source: "api" });
        await execute(
          `INSERT INTO external_references
             (provider_id, connection_id, entity_type, entity_id, external_id, external_url, remote_status,
              first_synced_at, last_synced_at, last_success_at, sync_count, created_at)
           VALUES (?, ?, 'media', ?, ?, ?, 'live', NOW(3), NOW(3), NOW(3), 1, NOW(3))
           ON DUPLICATE KEY UPDATE entity_id = VALUES(entity_id), last_synced_at = NOW(3), sync_count = sync_count + 1`,
          [ctx.providerId, ctx.connectionId, asset.id, urlKey, url.slice(0, 500)]
        );
        results[index] = { url, assetId: Number(asset.id), publicId: asset.public_id };
      } catch (error) {
        results[index] = { url, error: error?.expose ? error.message : String(error?.message || "download failed") };
      }
    }
  };
  await Promise.all(Array.from({ length: Math.min(IMAGE_CONCURRENCY, urls.length) }, worker));
  return results;
}

/* -------------------------------------------------------------------------- */
/* Locking, quota, lookup                                                      */
/* -------------------------------------------------------------------------- */

/**
 * Serialises imports for one account. Two pushes at once could otherwise both pass the allowance
 * check, or both create a listing for the same new `externalId`. The lock lives on a dedicated
 * connection for as long as the work runs.
 */
async function withAccountLock(accountId, work) {
  const connection = await getPool().getConnection();
  const name = `lf_listing_import:${accountId}`;
  try {
    const [rows] = await connection.query("SELECT GET_LOCK(?, 60) AS acquired", [name]);
    if (Number(rows?.[0]?.acquired) !== 1) {
      throw AppError.serviceUnavailable("Another import for this company is still running. Try again shortly.");
    }
    try {
      return await work();
    } finally {
      await connection.query("SELECT RELEASE_LOCK(?)", [name]).catch(() => {});
    }
  } finally {
    connection.release();
  }
}

async function findReference(ctx, externalId) {
  return queryOne(
    `SELECT er.id AS reference_id, er.payload_hash, er.remote_status, er.entity_id AS listing_id
       FROM external_references er
      WHERE er.provider_id = ? AND er.connection_id = ? AND er.entity_type = 'listing' AND er.external_id = ?
      LIMIT 1`,
    [ctx.providerId, ctx.connectionId, externalId]
  );
}

async function loadListing(listingId) {
  return queryOne("SELECT * FROM listings WHERE id = ? AND deleted_at IS NULL", [listingId]);
}

export function publicListingUrl(listing) {
  if (!listing || listing.status !== "active" || !listing.canonical_path) return null;
  return `${String(env.FRONTEND_URL || "").replace(/\/$/, "")}${listing.canonical_path}`;
}

export function serializeImportedListing(listing, extra = {}) {
  return {
    listingId: listing.public_id,
    reference: listing.reference,
    title: listing.title,
    status: listing.status,
    moderationStatus: listing.moderation_status,
    rejectionReason: listing.status === "rejected" ? listing.rejection_reason ?? null : null,
    publicUrl: publicListingUrl(listing),
    updatedAt: listing.updated_at,
    ...extra,
  };
}

/* -------------------------------------------------------------------------- */
/* The import                                                                  */
/* -------------------------------------------------------------------------- */

/**
 * A place must be as deep as LivFinder's list goes, whether it came as names or as an id. Each
 * level looks at what its own place has under it: a country with no cities passes as a country, a
 * city with no communities as a city, a community with no sub-communities as a community. Where
 * the list stops, so does the rule (owner's rule, 2026-10-30). Clients find the places in the
 * location files (`/v1/public/feed-formats/locations/`).
 */
const LEVELS_BELOW = {
  country: [
    { column: "country_id", levels: ["city"], field: "city", label: "city" },
    { column: "country_id", levels: ["state"], field: "state", label: "state" },
  ],
  state: [{ column: "state_id", levels: ["city"], field: "city", label: "city" }],
  city: [{ column: "city_id", levels: ["community", "district"], field: "community", label: "community" }],
  community: [{ column: "community_id", levels: ["sub_community"], field: "subCommunity", label: "sub-community" }],
  district: [{ column: "community_id", levels: ["sub_community"], field: "subCommunity", label: "sub-community" }],
};

export async function assertLocationComplete(locationId) {
  const place = await queryOne("SELECT id, level, name FROM locations WHERE id = ?", [locationId]);
  for (const below of LEVELS_BELOW[place?.level] ?? []) {
    const child = await queryValue(
      `SELECT 1 FROM locations WHERE ${below.column} = ? AND level IN (${below.levels.map(() => "?").join(", ")})
          AND deleted_at IS NULL AND status = 'active' LIMIT 1`,
      [place.id, ...below.levels]
    );
    if (child) {
      throw importValidationError({ [below.field]: `Give the ${below.label} in ${place.name}. See the LivFinder location files.` });
    }
  }
}

/**
 * The listing's amenities by slug. One LivFinder does not have yet is added to its list, for this
 * category, so the listing shows exactly what the client sent (owner's rule, 2026-10-30).
 */
async function ensureFeatures(rootId, names) {
  const slugs = [];
  for (const name of [...new Set((names || []).map((value) => String(value).trim()).filter(Boolean))]) {
    const slug = slugify(name);
    const lookup = () => queryOne("SELECT id, slug FROM features WHERE slug = ? OR code = ? OR LOWER(name) = LOWER(?) LIMIT 1", [slug, slug, name]);
    let feature = await lookup();
    if (!feature) {
      await execute("INSERT IGNORE INTO features (code, slug, name, created_at) VALUES (?, ?, ?, NOW(3))", [slug, slug, name.slice(0, 120)]);
      feature = await lookup();
    }
    await execute("INSERT IGNORE INTO category_features (category_id, feature_id, sort_order) VALUES (?, ?, 999)", [rootId, feature.id]);
    slugs.push(feature.slug);
  }
  return slugs;
}

async function buildPayload({ record, definition, client }) {
  const warnings = [];
  // Imported here, not at the top: the feed formats are built from this module's schema.
  const { missingRequired } = await import("../feeds/listingRequirements.js");
  const missing = missingRequired(record.category, record);
  if (Object.keys(missing).length) throw importValidationError(missing);

  const purpose = record.purpose || undefined;
  const allowedPurposes = CATEGORY_PURPOSES[definition.listingType] || [];
  if (purpose && !allowedPurposes.includes(purpose)) {
    throw importValidationError({ purpose: `Use one of: ${allowedPurposes.join(", ")}.` });
  }

  // Detail fields are checked here, with unknown keys refused, so a typo is reported rather than dropped.
  if (record.detail) {
    const parsed = DETAIL_SCHEMAS[definition.listingType].strict().safeParse(record.detail);
    if (!parsed.success) throw importValidationError(fieldsFromIssues(parsed.error.issues, "detail."));
  }

  // Settled together, so a listing with an unknown type and an unknown place reports both at once.
  const settled = await Promise.allSettled([
    resolvePropertyType(definition, record.propertyType),
    resolveImportLocation(record.location).then(async (id) => {
      await assertLocationComplete(id);
      return id;
    }),
    resolveAgent(client.organizationId, record.agentEmail, warnings),
  ]);
  const failures = settled.filter((result) => result.status === "rejected").map((result) => result.reason);
  if (failures.length) {
    const fieldErrors = failures.filter((error) => error instanceof AppError && error.status === 422 && error.fields);
    if (fieldErrors.length !== failures.length) throw failures.find((error) => !fieldErrors.includes(error));
    throw new AppError(fieldErrors[0].message, {
      status: 422,
      code: fieldErrors.some((error) => error.code === "UNMAPPED_VALUE") ? "UNMAPPED_VALUE" : fieldErrors[0].code,
      fields: Object.assign({}, ...fieldErrors.map((error) => error.fields)),
    });
  }
  const [categorySlug, locationId, agentId] = settled.map((result) => result.value);

  const payload = {
    category: definition.dbCode,
    categorySlug,
    purpose,
    title: record.title,
    subtitle: record.subtitle ?? undefined,
    description: record.description ?? undefined,
    price: record.price ?? undefined,
    currency: record.currency,
    priceType: record.priceType ?? undefined,
    pricePeriod: record.pricePeriod ?? undefined,
    isPriceHidden: record.isPriceHidden,
    locationId: String(locationId),
    address: record.address ?? undefined,
    postalCode: record.postalCode ?? undefined,
    latitude: record.latitude ?? undefined,
    longitude: record.longitude ?? undefined,
    hideExactLocation: record.hideExactLocation,
    contactName: record.contactName ?? undefined,
    contactPhone: record.contactPhone ?? undefined,
    contactWhatsapp: record.contactWhatsapp ?? undefined,
    contactEmail: record.contactEmail ?? undefined,
    allowCall: record.allowCall,
    allowWhatsapp: record.allowWhatsapp,
    allowEmail: record.allowEmail,
    agentId: agentId === null ? undefined : String(agentId),
    brand: record.brand ?? undefined,
    model: record.model ?? undefined,
    features: record.features,
    detail: record.detail,
    seoTitle: record.seoTitle ?? undefined,
    seoDescription: record.seoDescription ?? undefined,
  };
  for (const key of Object.keys(payload)) if (payload[key] === undefined) delete payload[key];

  // The portal's own schema has the final say on every shared field (price types, periods, …).
  const checked = createListingSchema.safeParse(payload);
  if (!checked.success) throw importValidationError(fieldsFromIssues(checked.error.issues));
  return { payload: checked.data, warnings, agentAssigned: agentId !== null };
}

async function syncImages({ listing, desired, ctx }) {
  // Only gallery rows that came from this company's imports are ever removed or reordered.
  const rows = await query(
    `SELECT lm.id, lm.media_asset_id, (er.id IS NOT NULL) AS imported
       FROM listing_media lm
       LEFT JOIN external_references er
         ON er.entity_type = 'media' AND er.entity_id = lm.media_asset_id
        AND er.provider_id = ? AND er.connection_id = ?
      WHERE lm.listing_id = ? AND lm.media_type = 'image'
      ORDER BY lm.is_cover DESC, lm.sort_order ASC, lm.id ASC`,
    [ctx.providerId, ctx.connectionId, listing.id]
  );
  const wanted = new Set(desired.map(String));
  let changed = false;
  for (const row of rows) {
    if (Number(row.imported) && !wanted.has(String(row.media_asset_id))) {
      await removeListingMedia({ listingId: listing.id, mediaId: row.id });
      changed = true;
    }
  }
  const remaining = await query(
    "SELECT id, media_asset_id FROM listing_media WHERE listing_id = ? AND media_type = 'image' ORDER BY is_cover DESC, sort_order ASC, id ASC",
    [listing.id]
  );
  const position = new Map(desired.map((assetId, index) => [String(assetId), index]));
  const ordered = [...remaining].sort((a, b) => {
    const left = position.get(String(a.media_asset_id)) ?? Number.MAX_SAFE_INTEGER;
    const right = position.get(String(b.media_asset_id)) ?? Number.MAX_SAFE_INTEGER;
    return left - right;
  });
  if (ordered.some((row, index) => row.id !== remaining[index].id)) {
    await reorderListingMedia({ listingId: listing.id, orderedIds: ordered.map((row) => row.id) });
    changed = true;
  }
  return changed;
}

/**
 * Creates, updates or leaves one listing. Returns
 * `{ operation: 'create'|'update'|'unchanged', listing, warnings, media }` or throws an AppError
 * whose `fields` say what to fix.
 */
export async function importListing({ client, ctx, record, source = "api", importId = null, ip = null, requestId = null }) {
  const definition = resolveCategory(record.category);
  if (!definition || !IMPORT_CATEGORIES.includes(definition.dbCode)) {
    throw importValidationError({ category: `Use one of: ${IMPORT_CATEGORIES.join(", ")}.` });
  }
  const hash = payloadHash(record);

  return withAccountLock(client.accountId, async () => {
    let reference = await findReference(ctx, record.externalId);
    let listing = reference ? await loadListing(reference.listing_id) : null;
    // A listing made in the portal shows on the link under its reference. Sent back with that id
    // it is the same listing, from now on tied to this client's system, never a second copy.
    if (!reference) {
      const own = await queryOne(
        "SELECT id FROM listings WHERE reference = ? AND (account_id = ? OR organization_id <=> ?) AND deleted_at IS NULL LIMIT 1",
        [record.externalId, client.accountId, client.organizationId ?? -1]
      );
      if (own) {
        listing = await loadListing(own.id);
        reference = { reference_id: null, payload_hash: null, remote_status: null, listing_id: own.id };
      }
    }
    if (reference && !listing) {
      // The listing was deleted on LivFinder; the partner's id starts over as a new listing.
      await execute("DELETE FROM external_references WHERE id = ?", [reference.reference_id]);
      reference = null;
    }

    if (listing && reference.payload_hash === hash) {
      return { operation: "unchanged", listing, warnings: [], media: { attached: null, failed: [] } };
    }
    if (listing && Number(listing.root_category_id) !== definition.rootId) {
      throw importValidationError({
        category: "A listing's category cannot change. Withdraw it and push it again under a new externalId.",
      });
    }

    // By account, so an individual's feed (no organization) is held to the same rule (0063).
    const approved = await queryValue(
      `SELECT aca.id FROM account_category_access aca JOIN categories c ON c.id = aca.category_id
        WHERE aca.account_id = ? AND COALESCE(c.root_category_id, c.id) = ? AND aca.status = 'approved' LIMIT 1`,
      [client.accountId, definition.rootId]
    );
    if (!approved) {
      throw new AppError(`This account is not approved to list in ${definition.label}.`, {
        status: 403,
        code: "CATEGORY_NOT_APPROVED",
        fields: { category: "Ask LivFinder to approve this category for the account first." },
      });
    }

    const { payload, warnings } = await buildPayload({ record, definition, client });
    // A pushed listing arrives unpublished: the company picks in the portal which ones go live,
    // unless the push itself asks to submit it. Updates keep the status unless one is asked for.
    // The plan's storage and live limits are checked by `createListing` / `changeListingStatus`.
    const desiredStatus = record.status || (listing ? undefined : "draft");
    if (!listing) await listingsService.assertStorageAvailable(client.accountId);

    const imageUrls = [...new Set(record.images || [])];
    const imageResults = imageUrls.length
      ? await importImages({ urls: imageUrls, ctx, accountId: client.accountId, userId: client.createdByUserId })
      : [];
    const failedImages = imageResults.filter((result) => result.error).map(({ url, error }) => ({ url, reason: error }));
    // Two URLs can carry the same photograph; storage deduplicates the bytes, so attach it once.
    const seenAssets = new Set();
    const assets = imageResults.filter((result) => {
      if (!result.assetId || seenAssets.has(result.assetId)) return false;
      seenAssets.add(result.assetId);
      return true;
    });
    // Counted after downloading: three links are not three pictures if one is broken or a repeat.
    if (assets.length < MIN_IMAGES) {
      throw importValidationError({
        images: [
          `At least ${MIN_IMAGES} different images must load; ${assets.length} did.`,
          ...failedImages.map((failure) => `${failure.url}: ${failure.reason}`),
        ].join(" "),
      });
    }
    for (const failure of failedImages) warnings.push(`Image not added (${failure.reason}): ${failure.url}`);
    payload.features = await ensureFeatures(definition.rootId, record.features);

    let operation;
    if (!listing) {
      const created = await listingsService.createListing({
        payload: { ...payload, mediaAssetIds: assets.map((asset) => asset.publicId), status: desiredStatus },
        accountId: client.accountId,
        userId: client.createdByUserId,
        organizationId: client.organizationId,
        agentId: null,
        ip,
      });
      listing = await loadListing(created.listingId);
      operation = "create";
    } else {
      const updatePayload = updateListingSchema.parse({
        ...payload,
        mediaAssetIds: assets.map((asset) => asset.publicId),
      });
      // A live listing keeps its approved version on the site until a moderator approves this.
      await listingsService.holdOwnerChange({ listingId: listing.id, userId: client.createdByUserId, reason: "Updated by the listing feed" });
      await listingsService.updateListing({
        listing,
        payload: updatePayload,
        userId: client.createdByUserId,
        accountId: client.accountId,
        organizationId: client.organizationId,
      });
      if (record.images) await syncImages({ listing, desired: assets.map((asset) => asset.assetId), ctx });
      // The same rule as an owner editing in the portal: a live listing goes back to review,
      // anything else takes the requested draft / submit choice where that move is allowed.
      if (CLOSED_STATUSES.has(listing.status)) {
        warnings.push(`This listing is ${listing.status}; its details were updated but its status was not changed.`);
      } else {
        await listingsService.applyOwnerEditStatus({
          listing,
          requestedStatus: desiredStatus,
          edited: true,
          userId: client.createdByUserId,
        });
      }
      // A listing a feed run withdrew because it left the file is back in it: it returns to the
      // queue, never straight to the site (owner's rule, 2026-10-29).
      if (reference?.remote_status === "removed" && listing.status === "withdrawn") {
        try {
          await listingsService.changeListingStatus({
            listing: await loadListing(listing.id),
            toStatus: "pending_review",
            reason: "Back in the listing feed",
            userId: client.createdByUserId,
          });
        } catch (error) {
          if (!(error instanceof AppError) || error.status >= 500) throw error;
          warnings.push(`Back in the feed but not resubmitted: ${error.message}`);
        }
      }
      listing = await loadListing(listing.id);
      operation = "update";
    }

    await execute(
      "UPDATE listings SET source = ?, source_reference = ?, source_api_client_id = ? WHERE id = ?",
      [source, record.externalId.slice(0, 120), client.id, listing.id]
    );
    // A run with failed images is not remembered as done, so pushing it again retries them.
    const storedHash = failedImages.length ? null : hash;
    await execute(
      `INSERT INTO external_references
         (provider_id, connection_id, entity_type, entity_id, external_id, remote_status, payload_hash,
          first_synced_at, last_synced_at, last_success_at, sync_count, created_at)
       VALUES (?, ?, 'listing', ?, ?, 'live', ?, NOW(3), NOW(3), NOW(3), 1, NOW(3))
       ON DUPLICATE KEY UPDATE entity_id = VALUES(entity_id), payload_hash = VALUES(payload_hash), remote_status = 'live',
                               last_synced_at = NOW(3), last_success_at = NOW(3), sync_count = sync_count + 1`,
      [ctx.providerId, ctx.connectionId, listing.id, record.externalId, storedHash]
    );

    await recordAudit({
      action: operation === "create" ? "listing.imported" : "listing.import_updated",
      subjectType: "listing",
      subjectId: listing.id,
      subjectLabel: listing.title,
      userId: client.createdByUserId,
      actorType: "api",
      actorLabel: actorLabel(client),
      metadata: { externalId: record.externalId, importId, apiClientId: client.publicId, organizationId: client.organizationPublicId, sourceIp: client.ip },
      ip,
      requestId,
    });

    return {
      operation,
      listing,
      warnings,
      media: { attached: assets.length, failed: failedImages },
    };
  });
}

const actorLabel = (client) => (client.feedPublicId ? `Listing feed "${client.name}"` : `API key "${client.name}" (${client.clientId})`);

/**
 * Withdraws (or archives a draft of) a listing this company pushed.
 */
export async function withdrawImportedListing({ client, ctx, externalId, importId = null, ip = null, requestId = null }) {
  return withAccountLock(client.accountId, async () => {
    const reference = await findReference(ctx, externalId);
    const listing = reference ? await loadListing(reference.listing_id) : null;
    if (!listing) throw AppError.notFound(`No listing with the externalId "${externalId}" was pushed for this company.`);

    const target = ["pending_review", "active"].includes(listing.status)
      ? "withdrawn"
      : ["draft", "rejected"].includes(listing.status)
        ? "archived"
        : null;
    let changed = false;
    if (target) {
      const result = await listingsService.changeListingStatus({
        listing,
        toStatus: target,
        reason: "Withdrawn through the listing API",
        userId: client.createdByUserId,
      });
      changed = result.changed;
    }
    // Forget the last payload, so pushing the listing again resubmits it rather than reading as unchanged.
    await execute(
      "UPDATE external_references SET payload_hash = NULL, last_synced_at = NOW(3) WHERE id = ?",
      [reference.reference_id]
    );
    if (changed) {
      await recordAudit({
        action: "listing.import_withdrawn",
        subjectType: "listing",
        subjectId: listing.id,
        subjectLabel: listing.title,
        userId: client.createdByUserId,
        actorType: "api",
        actorLabel: actorLabel(client),
        metadata: { externalId, importId, apiClientId: client.publicId, sourceIp: client.ip },
        ip,
        requestId,
      });
    }
    return { operation: changed ? "delete" : "unchanged", listing: await loadListing(listing.id) };
  });
}

export async function findImportedListing({ ctx, externalId }) {
  const reference = await findReference(ctx, externalId);
  return reference ? loadListing(reference.listing_id) : null;
}

export async function listImportedListings({ ctx, updatedSince = null, status = null, page = 1, pageSize = 50 }) {
  const conditions = ["er.provider_id = ?", "er.connection_id = ?", "er.entity_type = 'listing'", "l.deleted_at IS NULL"];
  const params = [ctx.providerId, ctx.connectionId];
  if (updatedSince) {
    conditions.push("l.updated_at >= ?");
    params.push(new Date(updatedSince));
  }
  if (status) {
    conditions.push("l.status = ?");
    params.push(status);
  }
  const where = conditions.join(" AND ");
  const total = Number(
    await queryValue(`SELECT COUNT(*) FROM external_references er JOIN listings l ON l.id = er.entity_id WHERE ${where}`, params)
  );
  const rows = await query(
    `SELECT l.*, er.external_id FROM external_references er JOIN listings l ON l.id = er.entity_id
      WHERE ${where} ORDER BY l.updated_at DESC, l.id DESC LIMIT ? OFFSET ?`,
    [...params, pageSize, (page - 1) * pageSize]
  );
  return { rows, total };
}
