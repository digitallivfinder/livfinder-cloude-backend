import { query, queryOne, queryValue, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ownAgentClause } from "../../utils/tenantScope.js";
import { ulid } from "../../utils/ids.js";
import { slugify } from "../../utils/slug.js";
import { resolveCategory, categoryByRootId } from "../../utils/categories.js";
import { buildCanonicalPath } from "../../utils/canonicalPath.js";
import { resolveLocation } from "../locations/locations.repository.js";
import { sanitizeDescription } from "../../utils/richText.js";
import { DETAIL_SCHEMAS } from "./listings.schemas.js";
import { refreshListingSearch, recordStatusChange, nextReference } from "./listings.repository.js";
import { attachAssetToListing, syncListingMediaCounters } from "../media/listingMedia.service.js";
import { beginOwnerChange, closeOpenRevision } from "./listingRevisions.service.js";
import { resolveAssetRef } from "../media/media.service.js";

/**
 * A listing is never one row. Creating one writes:
 *   listings + the category's detail table + features + attributes + media
 * and, when it is publishable, the search projection.
 *
 * All of it happens inside a single transaction. A create that fails after the
 * `listings` INSERT must not leave a row with no detail record behind it.
 */

const DETAIL_TABLE = {
  "real-estate": "listing_real_estate",
  cars: "listing_vehicle",
  yachts: "listing_marine",
  jets: "listing_aviation",
  helicopters: "listing_aviation",
  watches: "listing_timepiece",
};

// camelCase payload key -> detail table column, per category.
const DETAIL_COLUMNS = {
  "real-estate": {
    bedrooms: "bedrooms", bathrooms: "bathrooms", halfBathrooms: "half_bathrooms",
    receptionRooms: "reception_rooms", maidRooms: "maid_rooms", parkingSpaces: "parking_spaces",
    builtAreaSqft: "built_area_sqft", builtAreaSqm: "built_area_sqm",
    plotAreaSqft: "plot_area_sqft", plotAreaSqm: "plot_area_sqm",
    floorNumber: "floor_number", totalFloors: "total_floors", unitNumber: "unit_number",
    buildingName: "building_name", yearBuilt: "year_built", completionStatus: "completion_status",
    handoverDate: "handover_date", furnishing: "furnishing", ownershipType: "ownership_type",
    viewType: "view_type", rentPeriod: "rent_period", chequesAccepted: "cheques_accepted",
    availableFrom: "available_from", permitNumber: "permit_number",
    isNewBuild: "is_new_build", isTenanted: "is_tenanted",
  },
  cars: {
    modelYear: "model_year", mileageKm: "mileage_km", bodyType: "body_type",
    transmission: "transmission", fuelType: "fuel_type", drivetrain: "drivetrain",
    engineSizeCc: "engine_size_cc", cylinders: "cylinders", horsepower: "horsepower",
    torqueNm: "torque_nm", topSpeedKmh: "top_speed_kmh", exteriorColor: "exterior_color",
    interiorColor: "interior_color", doors: "doors", seats: "seats",
    conditionType: "condition_type", steeringSide: "steering_side", vin: "vin",
    regionalSpec: "regional_spec", serviceHistory: "service_history", ownersCount: "owners_count",
    isAccidentFree: "is_accident_free", isLimitedEdition: "is_limited_edition",
  },
  yachts: {
    buildYear: "build_year", refitYear: "refit_year", lengthOverallM: "length_overall_m",
    lengthOverallFt: "length_overall_ft", beamM: "beam_m", draftM: "draft_m",
    grossTonnage: "gross_tonnage", vesselType: "vessel_type", hullMaterial: "hull_material",
    cabins: "cabins", berths: "berths", heads: "heads", guestsSleeping: "guests_sleeping",
    guestsCruising: "guests_cruising", crewCapacity: "crew_capacity", engineMake: "engine_make",
    engineModel: "engine_model", engineHours: "engine_hours",
    cruisingSpeedKnots: "cruising_speed_knots", maxSpeedKnots: "max_speed_knots",
    rangeNm: "range_nm", homePort: "home_port",
    isCharterAvailable: "is_charter_available", isVatPaid: "is_vat_paid",
  },
  jets: {
    aircraftType: "aircraft_type", yearBuilt: "year_built", yearRefurbished: "year_refurbished",
    totalTimeHours: "total_time_hours", totalLandings: "total_landings", cycles: "cycles",
    passengerCapacity: "passenger_capacity", crewCapacity: "crew_capacity", rangeNm: "range_nm",
    maxCruiseSpeedKts: "max_cruise_speed_kts", maxAltitudeFt: "max_altitude_ft",
    engineCount: "engine_count", engineMake: "engine_make", engineModel: "engine_model",
    engineProgram: "engine_program", avionicsSuite: "avionics_suite",
    interiorConfiguration: "interior_configuration", baseAirportCode: "base_airport_code",
    isCharterAvailable: "is_charter_available", charterHourlyRate: "charter_hourly_rate",
  },
  watches: {
    referenceNumber: "reference_number", yearOfProduction: "year_of_production",
    caseMaterial: "case_material", caseDiameterMm: "case_diameter_mm",
    caseThicknessMm: "case_thickness_mm", bezelMaterial: "bezel_material", crystal: "crystal",
    dialColor: "dial_color", dialType: "dial_type", braceletMaterial: "bracelet_material",
    movementType: "movement_type", caliber: "caliber", powerReserveHours: "power_reserve_hours",
    jewels: "jewels", waterResistanceM: "water_resistance_m", conditionGrade: "condition_grade",
    hasOriginalBox: "has_original_box", hasOriginalPapers: "has_original_papers",
    isFullSet: "is_full_set", isLimitedEdition: "is_limited_edition", gender: "gender",
  },
};
DETAIL_COLUMNS.helicopters = DETAIL_COLUMNS.jets;

const BRAND_KIND = {
  "real-estate": "property_developer",
  cars: "car_make",
  yachts: "yacht_builder",
  jets: "aircraft_manufacturer",
  helicopters: "aircraft_manufacturer",
  watches: "watch_brand",
};

// Jets and helicopters share `brands.kind = 'aircraft_manufacturer'`; `aircraft_segment`
// (migration 0046) is the finer signal that stops a helicopter listing resolving to a
// fixed-wing-only manufacturer, and vice versa.
const AIRCRAFT_SEGMENT = { jets: "fixed_wing", helicopters: "rotorcraft" };

async function resolveCategoryRow(definition, categorySlug, executor) {
  if (!categorySlug) return { categoryId: definition.rootId, rootCategoryId: definition.rootId };
  const row = await queryOne(
    `SELECT id, root_category_id FROM categories
      WHERE (slug = ? OR code = ?) AND root_category_id = ? AND deleted_at IS NULL LIMIT 1`,
    [categorySlug, categorySlug, definition.rootId],
    executor
  );
  // A category id that does not belong to the chosen root is rejected rather
  // than quietly falling back — that is how a car ends up filed as a villa.
  if (!row) {
    throw AppError.validation("Some information is invalid.", {
      categorySlug: "That type is not available in this category.",
    });
  }
  return { categoryId: row.id, rootCategoryId: row.root_category_id || definition.rootId };
}

async function resolvePurposeId(purpose, executor) {
  const code = purpose || "sale";
  const id = await queryValue("SELECT id FROM purposes WHERE code = ? LIMIT 1", [code], executor);
  if (!id) throw AppError.validation("Some information is invalid.", { purpose: "Unknown purpose." });
  return id;
}

async function resolveBrandAndModel({ definition, brand, model }, executor) {
  if (!brand) return { brandId: null, brandModelId: null, brandSlug: null, modelSlug: null };
  const brandSlug = slugify(String(brand).replace(/^[a-z]+:/, ""));
  const segment = AIRCRAFT_SEGMENT[definition.listingType];
  const brandRow = await queryOne(
    segment
      ? "SELECT id, slug FROM brands WHERE slug = ? AND kind = ? AND aircraft_segment = ? AND deleted_at IS NULL LIMIT 1"
      : "SELECT id, slug FROM brands WHERE slug = ? AND kind = ? AND deleted_at IS NULL LIMIT 1",
    segment
      ? [brandSlug, BRAND_KIND[definition.listingType], segment]
      : [brandSlug, BRAND_KIND[definition.listingType]],
    executor
  );
  if (!brandRow) {
    throw AppError.validation("Some information is invalid.", { brand: "That make is not in the catalogue." });
  }
  if (!model) return { brandId: brandRow.id, brandModelId: null, brandSlug: brandRow.slug, modelSlug: null };

  const modelSlug = slugify(String(model).replace(/^model:[^:]*:/, "").replace(/^[a-z]+:/, ""));
  const modelRow = await queryOne(
    "SELECT id, slug FROM brand_models WHERE brand_id = ? AND slug = ? LIMIT 1",
    [brandRow.id, modelSlug],
    executor
  );
  if (!modelRow) {
    // The relationship is verified, not assumed: a model must belong to the make.
    throw AppError.validation("Some information is invalid.", { model: "That model does not belong to the selected make." });
  }
  return { brandId: brandRow.id, brandModelId: modelRow.id, brandSlug: brandRow.slug, modelSlug: modelRow.slug };
}

async function resolveLocationChain(locationId, executor) {
  if (!locationId) return { locationId: null, countryId: null, stateId: null, cityId: null, communityId: null, subCommunityId: null, slugs: {} };
  const row = await resolveLocation(locationId);
  if (!row) throw AppError.validation("Some information is invalid.", { locationId: "That location could not be found." });
  return {
    locationId: row.id,
    countryId: row.country_id,
    stateId: row.state_id,
    cityId: row.city_id,
    communityId: row.level === "community" || row.level === "district" ? row.id : row.community_id,
    subCommunityId: row.level === "sub_community" ? row.id : null,
    slugs: {
      country: row.country_slug,
      state: row.state_slug,
      city: row.city_slug,
      community: row.level === "community" || row.level === "district" ? row.slug : row.community_slug,
      subCommunity: row.level === "sub_community" ? row.slug : null,
    },
  };
}

async function uniqueListingSlug(title, listingId, executor) {
  const base = slugify(title).slice(0, 200) || "listing";
  // Slugs carry the listing id, which is both readable and collision-free.
  return `${base}-${listingId}`;
}

/**
 * Real-estate inventory.
 *
 * The schema treats a property as a first-class record: `listings.unit_id` points at the
 * `property_units` row a listing is advertising, and `db/seeds/099_platform_finalise.sql`
 * asserts that every live real-estate listing resolves to one. A listing created through the
 * API therefore has to register its unit too, or it would break an invariant the seed data
 * upholds. The unit is derived from the listing's own location and real-estate detail.
 */
const UNIT_TYPE_BY_CATEGORY_CODE = {
  apartment: "apartment", villa: "villa", penthouse: "penthouse", townhouse: "townhouse",
  mansion: "villa", duplex: "duplex", chalet: "villa", estate: "villa", plot: "plot",
  "whole-building": "whole_building", office: "office", retail: "retail",
  "hotel-apartment": "apartment", island: "plot", vineyard: "plot",
};

const UNIT_TENURE = { freehold: "freehold", leasehold: "leasehold", commonhold: "commonhold", usufruct: "usufruct", musataha: "musataha" };

async function ensurePropertyUnit({ listingId, listing, detail, connection }) {
  const category = await queryOne("SELECT code FROM categories WHERE id = ?", [listing.categoryId], connection);
  const unitType = UNIT_TYPE_BY_CATEGORY_CODE[category?.code] || "other";
  const offPlan = detail?.completionStatus === "off_plan" || detail?.completionStatus === "under_construction";

  // Reuse the building the listing names, when the seeded inventory already knows it.
  const building = detail?.buildingName
    ? await queryOne(
        "SELECT id FROM buildings WHERE name = ? AND deleted_at IS NULL LIMIT 1",
        [detail.buildingName],
        connection
      )
    : null;

  const result = await execute(
    `INSERT INTO property_units
       (public_id, building_id, project_id, unit_number, floor_number, location_id, community_id,
        city_id, country_id, latitude, longitude, category_id, unit_type, bedrooms, bathrooms,
        built_up_area, plot_area, parking_spaces, view_type, tenure, occupancy_status, is_off_plan,
        handover_date, listing_count, active_listing_count, data_source, verification_status,
        last_listed_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 'manual', 'unverified',
             NOW(3), NOW(3), NOW(3))`,
    [
      ulid(),
      building?.id ?? null,
      listing.projectId ?? null,
      detail?.unitNumber || listing.reference,
      detail?.floorNumber ?? null,
      listing.locationId ?? null,
      listing.communityId ?? null,
      listing.cityId ?? null,
      listing.countryId ?? null,
      listing.latitude ?? null,
      listing.longitude ?? null,
      listing.categoryId,
      unitType,
      detail?.bedrooms ?? null,
      detail?.bathrooms ?? null,
      detail?.builtAreaSqm ?? null,
      detail?.plotAreaSqm ?? null,
      detail?.parkingSpaces ?? null,
      detail?.viewType ?? null,
      UNIT_TENURE[detail?.ownershipType] || "unknown",
      detail?.isTenanted ? "tenanted" : offPlan ? "off_plan" : "vacant",
      offPlan ? 1 : 0,
      detail?.handoverDate ?? null,
    ],
    connection
  );

  await execute(
    "UPDATE listings SET unit_id = ?, building_id = ? WHERE id = ?",
    [result.insertId, building?.id ?? null, listingId],
    connection
  );
  await syncUnitListingCountersForListing(listingId, connection);
  return result.insertId;
}

/**
 * Keeps a unit's listing counters in step with the listings that point at it. Takes the listing
 * rather than the unit so callers do not have to carry `unit_id` through every loader; a listing
 * with no unit (every non-real-estate category) matches nothing and costs one cheap statement.
 */
async function syncUnitListingCountersForListing(listingId, connection) {
  if (!listingId) return;
  await execute(
    `UPDATE property_units u
        SET u.listing_count = (SELECT COUNT(*) FROM listings l WHERE l.unit_id = u.id AND l.deleted_at IS NULL),
            u.active_listing_count = (SELECT COUNT(*) FROM listings l WHERE l.unit_id = u.id AND l.deleted_at IS NULL AND l.status = 'active')
      WHERE u.id = (SELECT unit_id FROM listings WHERE id = ?)`,
    [listingId],
    connection
  );
  // buildings.total_units is asserted against the units, not the listings, so it is untouched here.
}

async function writeDetail({ listingType, listingId, detail }, executor) {
  const table = DETAIL_TABLE[listingType];
  const columns = DETAIL_COLUMNS[listingType];
  if (!table || !columns) return;

  const schema = DETAIL_SCHEMAS[listingType];
  const parsed = schema.safeParse(detail || {});
  if (!parsed.success) {
    const fields = {};
    for (const issue of parsed.error.issues) fields[`detail.${issue.path.join(".")}`] = issue.message;
    throw AppError.validation("Some information is invalid.", fields);
  }

  const entries = Object.entries(parsed.data).filter(([, value]) => value !== undefined);
  const assignments = [];
  const params = [];
  for (const [key, value] of entries) {
    const column = columns[key];
    if (!column) continue;
    assignments.push(column);
    params.push(typeof value === "boolean" ? (value ? 1 : 0) : value);
  }

  if (!assignments.length) {
    await execute(`INSERT IGNORE INTO ${table} (listing_id) VALUES (?)`, [listingId], executor);
    return;
  }

  const columnList = ["listing_id", ...assignments];
  const placeholders = columnList.map(() => "?").join(", ");
  const updates = assignments.map((column) => `${column} = VALUES(${column})`).join(", ");
  await execute(
    `INSERT INTO ${table} (${columnList.join(", ")}) VALUES (${placeholders})
     ON DUPLICATE KEY UPDATE ${updates}`,
    [listingId, ...params],
    executor
  );
}

async function writeFeatures({ listingId, featureIds, featureSlugs }, executor) {
  if (!featureIds && !featureSlugs) return;
  const ids = new Set();
  for (const id of featureIds || []) {
    if (/^\d+$/.test(String(id))) ids.add(Number(id));
  }
  for (const slug of featureSlugs || []) {
    const row = await queryOne("SELECT id FROM features WHERE slug = ? OR code = ? LIMIT 1", [slugify(slug), slug], executor);
    if (row) ids.add(row.id);
  }
  await execute("DELETE FROM listing_features WHERE listing_id = ?", [listingId], executor);
  for (const id of ids) {
    // INSERT IGNORE rather than a pre-check: the composite key is the guarantee.
    await execute("INSERT IGNORE INTO listing_features (listing_id, feature_id) VALUES (?, ?)", [listingId, id], executor);
  }
}

async function writeAttributes({ listingId, attributes }, executor) {
  if (!attributes) return;
  await execute("DELETE FROM listing_attribute_values WHERE listing_id = ?", [listingId], executor);
  for (const [code, value] of Object.entries(attributes)) {
    if (value === null || value === undefined || value === "") continue;
    const attribute = await queryOne("SELECT id, data_type FROM attributes WHERE code = ? LIMIT 1", [code], executor);
    if (!attribute) continue;
    const columns = { value_text: null, value_numeric: null, value_boolean: null, value_date: null, attribute_option_id: null };
    if (attribute.data_type === "boolean") columns.value_boolean = value ? 1 : 0;
    else if (attribute.data_type === "integer" || attribute.data_type === "decimal") columns.value_numeric = Number(value);
    else if (attribute.data_type === "date") columns.value_date = String(value).slice(0, 10);
    else if (attribute.data_type === "enum") {
      const option = await queryOne(
        "SELECT id FROM attribute_options WHERE attribute_id = ? AND (value = ? OR label = ?) LIMIT 1",
        [attribute.id, String(value), String(value)],
        executor
      );
      if (!option) continue;
      columns.attribute_option_id = option.id;
    } else columns.value_text = String(value).slice(0, 500);

    await execute(
      `INSERT INTO listing_attribute_values
         (listing_id, attribute_id, value_numeric, value_text, value_boolean, value_date, attribute_option_id)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [listingId, attribute.id, columns.value_numeric, columns.value_text, columns.value_boolean, columns.value_date, columns.attribute_option_id],
      executor
    );
  }
}

/**
 * Every priced row carries `price_base` in the platform base currency (AED), so
 * a cross-currency price sort is one indexed comparison instead of a join and a
 * conversion per row. `fx_rates_latest` stores base -> quote, so converting a
 * quoted price back to base divides.
 */
async function baseCurrencyAmount(price, currencyCode, executor) {
  if (price === null || price === undefined) return null;
  const amount = Number(price);
  if (!Number.isFinite(amount)) return null;
  const baseCode = await queryValue("SELECT code FROM currencies WHERE is_base = 1 LIMIT 1", [], executor);
  if (!baseCode || baseCode === currencyCode) return Number(amount.toFixed(2));
  const rate = await queryValue(
    "SELECT rate FROM fx_rates_latest WHERE base_code = ? AND quote_code = ? LIMIT 1",
    [baseCode, currencyCode],
    executor
  );
  const factor = Number(rate);
  // With no published rate the quoted amount is stored unconverted rather than
  // silently multiplied by a guess; the nightly FX job corrects it.
  if (!Number.isFinite(factor) || factor <= 0) return Number(amount.toFixed(2));
  return Number((amount / factor).toFixed(2));
}

/**
 * Plan limits (migration 0059).
 *
 * Two limits, both set by an admin per plan and mirrored onto the account:
 *
 *   live      `listing_quota` / `listing_used`: listings live or waiting for approval. Waiting
 *             counts, so an account cannot queue more than its plan can show.
 *   storage   `storage_quota` / `storage_used`: every listing the account still holds, so
 *             everything except archived (and deleted) ones.
 *
 * NULL is "unlimited" for both. An optional live cap per category sits on
 * `account_category_access.listing_quota`. Listings beyond the live limit stay unpublished in
 * the portal; the owner picks which ones go live.
 *
 * Usage is recomputed from the rows on every change, never counted up: the old counter was
 * only ever incremented and drifted to 500/500 on an account with 26 listings (0052).
 */
export const LIVE_LIMIT_STATUSES = ["pending_review", "active"];

export async function syncAccountListingUsage(accountId, connection) {
  if (!accountId) return;
  await execute(
    `UPDATE accounts
        SET listing_used = (SELECT COUNT(*) FROM listings
                             WHERE account_id = ? AND deleted_at IS NULL AND status IN ('pending_review', 'active')),
            storage_used = (SELECT COUNT(*) FROM listings
                             WHERE account_id = ? AND deleted_at IS NULL AND status <> 'archived')
      WHERE id = ?`,
    [accountId, accountId, accountId],
    connection
  );
  await execute(
    `UPDATE account_category_access aca
       JOIN categories c ON c.id = aca.category_id
        SET aca.listing_used = (SELECT COUNT(*) FROM listings l
                                 WHERE l.account_id = aca.account_id
                                   AND l.root_category_id = COALESCE(c.root_category_id, c.id)
                                   AND l.deleted_at IS NULL AND l.status IN ('pending_review', 'active'))
      WHERE aca.account_id = ? AND COALESCE(c.root_category_id, c.id) <> 7`,
    [accountId],
    connection
  );
}

const UPGRADE_HINT = "Upgrade your plan to add more.";

/** Throws when the account already holds as many listings as its plan stores. */
export async function assertStorageAvailable(accountId, connection) {
  if (!accountId) return;
  const row = await queryOne(
    `SELECT a.storage_quota,
            (SELECT COUNT(*) FROM listings l
              WHERE l.account_id = a.id AND l.deleted_at IS NULL AND l.status <> 'archived') AS used
       FROM accounts a WHERE a.id = ?`,
    [accountId],
    connection
  );
  if (row && row.storage_quota !== null && Number(row.used) >= Number(row.storage_quota)) {
    throw new AppError(`Your plan allows ${row.storage_quota} listings in total. ${UPGRADE_HINT}`, {
      status: 409,
      code: "STORAGE_LIMIT_REACHED",
    });
  }
}

/**
 * Throws when one more listing live or waiting for approval would pass the account's live
 * limit, or the live cap of its category. Called when an owner submits a listing that does not
 * yet count (draft, rejected, expired, withdrawn); a moderator's own moves skip it.
 */
export async function assertLiveSlotAvailable({ accountId, rootCategoryId }, connection) {
  if (!accountId) return;
  const row = await queryOne(
    `SELECT a.listing_quota,
            (SELECT COUNT(*) FROM listings l
              WHERE l.account_id = a.id AND l.deleted_at IS NULL AND l.status IN ('pending_review', 'active')) AS used
       FROM accounts a WHERE a.id = ?`,
    [accountId],
    connection
  );
  if (row && row.listing_quota !== null && Number(row.used) >= Number(row.listing_quota)) {
    throw new AppError(`Your plan allows ${row.listing_quota} live listings. ${UPGRADE_HINT}`, {
      status: 409,
      code: "LIVE_LIMIT_REACHED",
    });
  }
  if (!rootCategoryId) return;
  const category = await queryOne(
    `SELECT aca.listing_quota, c.name,
            (SELECT COUNT(*) FROM listings l
              WHERE l.account_id = aca.account_id AND l.root_category_id = ? AND l.deleted_at IS NULL
                AND l.status IN ('pending_review', 'active')) AS used
       FROM account_category_access aca
       JOIN categories c ON c.id = aca.category_id
      WHERE aca.account_id = ? AND COALESCE(c.root_category_id, c.id) = ? AND aca.listing_quota IS NOT NULL
      LIMIT 1`,
    [rootCategoryId, accountId, rootCategoryId],
    connection
  );
  if (category && Number(category.used) >= Number(category.listing_quota)) {
    throw new AppError(`Your account allows ${category.listing_quota} live listings in ${category.name}. ${UPGRADE_HINT}`, {
      status: 409,
      code: "CATEGORY_LIVE_LIMIT_REACHED",
    });
  }
}

export async function syncAccountListingUsageForListing(listingId, connection, { previousAgentId = null } = {}) {
  const row = await queryOne(
    "SELECT account_id, agent_id, organization_id FROM listings WHERE id = ?",
    [listingId],
    connection
  );
  if (!row) return;
  await syncAccountListingUsage(row.account_id, connection);
  await syncOwnerListingCounters({ agentIds: [row.agent_id, previousAgentId], organizationId: row.organization_id }, connection);
}

/**
 * The agent's and organisation's listing counters, recounted for the rows a change touched —
 * the same definitions as the 0014 rollup and the integrity checks (all non-deleted listings,
 * and the `active` ones). Only the bulk rollup ever set them, and nothing ran it, so a listing
 * approved, withdrawn or expired left its agent and organisation counting the old state.
 */
export async function syncOwnerListingCounters({ agentIds = [], organizationId = null }, connection) {
  for (const agentId of [...new Set(agentIds.filter(Boolean))]) {
    await execute(
      `UPDATE agents
          SET listing_count = (SELECT COUNT(*) FROM listings WHERE agent_id = ? AND deleted_at IS NULL),
              active_listing_count = (SELECT COUNT(*) FROM listings WHERE agent_id = ? AND deleted_at IS NULL AND status = 'active')
        WHERE id = ?`,
      [agentId, agentId, agentId],
      connection
    );
  }
  if (organizationId) {
    await execute(
      `UPDATE organizations
          SET listing_count = (SELECT COUNT(*) FROM listings WHERE organization_id = ? AND deleted_at IS NULL),
              active_listing_count = (SELECT COUNT(*) FROM listings WHERE organization_id = ? AND deleted_at IS NULL AND status = 'active')
        WHERE id = ?`,
      [organizationId, organizationId, organizationId],
      connection
    );
  }
}

export async function createListing({ payload, accountId, userId, organizationId, agentId, ip }) {
  const definition = resolveCategory(payload.category);
  if (!definition) throw AppError.validation("Some information is invalid.", { category: "Unknown category." });

  return withTransaction(async (connection) => {
    const { categoryId, rootCategoryId } = await resolveCategoryRow(definition, payload.categorySlug, connection);
    await assertStorageAvailable(accountId, connection);
    if (payload.status === "pending_review") await assertLiveSlotAvailable({ accountId, rootCategoryId }, connection);
    const purposeId = await resolvePurposeId(payload.purpose, connection);
    const brandInfo = await resolveBrandAndModel({ definition, brand: payload.brand, model: payload.model }, connection);
    const location = await resolveLocationChain(payload.locationId, connection);

    // Server-controlled fields. A client may not set ownership, moderation
    // state, reference, or any counter, whatever it puts in the body.
    const reference = await nextReference(connection);
    const publicId = ulid();
    const currency = payload.currency || "AED";
    const priceBase = await baseCurrencyAmount(payload.price ?? null, currency, connection);

    let resolvedAgentId = null;
    if (payload.agentId) {
      const agentRow = await queryOne(
        `SELECT id FROM agents WHERE (public_id = ? OR id = ?) AND ${ownAgentClause({ organizationId, userId }).sql} AND deleted_at IS NULL LIMIT 1`,
        [String(payload.agentId), /^\d+$/.test(String(payload.agentId)) ? Number(payload.agentId) : 0, ...ownAgentClause({ organizationId, userId }).params],
        connection
      );
      if (!agentRow) throw AppError.validation("Some information is invalid.", { agentId: "That agent is not on this account." });
      resolvedAgentId = agentRow.id;
    } else if (agentId) {
      resolvedAgentId = agentId;
    }

    let resolvedProjectId = null;
    if (payload.projectId) {
      const projectRow = await queryOne(
        "SELECT id FROM projects WHERE (public_id = ? OR id = ?) AND deleted_at IS NULL LIMIT 1",
        [String(payload.projectId), /^\d+$/.test(String(payload.projectId)) ? Number(payload.projectId) : 0],
        connection
      );
      if (!projectRow) throw AppError.validation("Some information is invalid.", { projectId: "That development was not found." });
      resolvedProjectId = projectRow.id;
    }

    const status = payload.status === "pending_review" ? "pending_review" : "draft";

    const result = await execute(
      `INSERT INTO listings
         (public_id, reference, account_id, organization_id, agent_id, created_by_user_id,
          category_id, root_category_id, purpose_id, project_id, brand_id, brand_model_id,
          title, slug, subtitle, description, canonical_path,
          price, currency_code, price_base, price_type, price_period, is_price_hidden,
          location_id, country_id, state_id, city_id, community_id, sub_community_id,
          address, postal_code, latitude, longitude, hide_exact_location,
          status, moderation_status,
          contact_name, contact_phone, contact_whatsapp, contact_email,
          allow_call, allow_whatsapp, allow_email,
          seo_title, seo_description, source, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
               ?, ?, ?, ?, ?, ?,
               -- A listing created with "Submit for review" is submitted: it was written as
               -- 'not_submitted' regardless, so the portal showed "Moderation: Not submitted" on a
               -- listing waiting in the admin queue. MySQL lets a value refer to a column set
               -- earlier in the same row, so this follows the status just inserted.
               IF(status = 'pending_review', 'pending', 'not_submitted'),
               ?, ?, ?, ?, ?, ?, ?, ?, ?, 'manual', NOW(3))`,
      [
        publicId,
        reference,
        accountId,
        organizationId ?? null,
        resolvedAgentId,
        userId,
        categoryId,
        rootCategoryId,
        purposeId,
        resolvedProjectId,
        brandInfo.brandId,
        brandInfo.brandModelId,
        payload.title,
        // Placeholder: the real slug needs the auto-increment id.
        `pending-${publicId}`,
        payload.subtitle ?? null,
        sanitizeDescription(payload.description) ?? null,
        `/pending/${publicId}`,
        payload.price ?? null,
        currency,
        priceBase,
        payload.priceType || "fixed",
        payload.pricePeriod ?? null,
        payload.isPriceHidden ? 1 : 0,
        location.locationId,
        location.countryId,
        location.stateId,
        location.cityId,
        location.communityId,
        location.subCommunityId,
        payload.address ?? null,
        payload.postalCode ?? null,
        payload.latitude ?? null,
        payload.longitude ?? null,
        payload.hideExactLocation ? 1 : 0,
        status,
        payload.contactName ?? null,
        payload.contactPhone ?? null,
        payload.contactWhatsapp ?? null,
        payload.contactEmail ?? null,
        payload.allowCall === false ? 0 : 1,
        payload.allowWhatsapp === false ? 0 : 1,
        payload.allowEmail === false ? 0 : 1,
        payload.seoTitle ?? null,
        payload.seoDescription ?? null,
      ],
      connection
    );
    const listingId = result.insertId;

    const slug = await uniqueListingSlug(payload.title, listingId, connection);
    const canonicalPath = buildCanonicalPath({
      rootCategoryId,
      slug,
      location: location.slugs,
      brandSlug: brandInfo.brandSlug,
      modelSlug: brandInfo.modelSlug,
      year: detailYear(definition.listingType, payload.detail),
    });
    await execute(
      "UPDATE listings SET slug = ?, canonical_path = ? WHERE id = ?",
      [slug, canonicalPath, listingId],
      connection
    );

    await writeDetail({ listingType: definition.listingType, listingId, detail: payload.detail }, connection);
    if (definition.listingType === "real-estate") {
      await ensurePropertyUnit({
        listingId,
        listing: {
          categoryId,
          projectId: resolvedProjectId,
          reference,
          locationId: location.locationId ?? null,
          communityId: location.communityId ?? null,
          cityId: location.cityId ?? null,
          countryId: location.countryId ?? null,
          latitude: payload.latitude ?? null,
          longitude: payload.longitude ?? null,
        },
        detail: payload.detail,
        connection,
      });
    }
    await writeFeatures({ listingId, featureIds: payload.featureIds, featureSlugs: payload.features }, connection);
    await writeAttributes({ listingId, attributes: payload.attributes }, connection);

    for (const assetPublicId of payload.mediaAssetIds || []) {
      const asset = await resolveAssetRef(assetPublicId);
      if (!asset) continue;
      if (asset.account_id && String(asset.account_id) !== String(accountId)) {
        throw AppError.forbidden("One of the selected images belongs to another account.");
      }
      await attachAssetToListing({ listingId, assetId: asset.id, altText: asset.alt_text }, connection);
    }
    await syncListingMediaCounters(listingId, connection);

    await recordStatusChange({ listingId, fromStatus: null, toStatus: status, userId, reason: "created" }, connection);
    await syncAccountListingUsage(accountId, connection);

    return { listingId, publicId, reference, slug, canonicalPath, status };
  }).then(async (created) => {
    await refreshListingSearch(created.listingId);
    return created;
  });
}

function detailYear(listingType, detail = {}) {
  if (!detail) return null;
  return (
    detail.modelYear ?? detail.buildYear ?? detail.yearBuilt ?? detail.yearOfProduction ?? null
  );
}

export async function updateListing({ listing, payload, userId, accountId, organizationId }) {
  const definition = categoryByRootId(listing.root_category_id);
  if (!definition) throw AppError.internal();

  await withTransaction(async (connection) => {
    const assignments = [];
    const params = [];
    const set = (column, value) => {
      assignments.push(`${column} = ?`);
      params.push(value);
    };

    if (payload.title !== undefined) set("title", payload.title);
    if (payload.subtitle !== undefined) set("subtitle", payload.subtitle ?? null);
    // Rich text from the portal editor is rendered as HTML on the public page, so only the
    // allowlist in utils/richText.js is ever stored.
    if (payload.description !== undefined) set("description", sanitizeDescription(payload.description) ?? null);
    if (payload.priceType !== undefined) set("price_type", payload.priceType);
    if (payload.pricePeriod !== undefined) set("price_period", payload.pricePeriod ?? null);
    if (payload.isPriceHidden !== undefined) set("is_price_hidden", payload.isPriceHidden ? 1 : 0);
    if (payload.address !== undefined) set("address", payload.address ?? null);
    if (payload.postalCode !== undefined) set("postal_code", payload.postalCode ?? null);
    if (payload.latitude !== undefined) set("latitude", payload.latitude ?? null);
    if (payload.longitude !== undefined) set("longitude", payload.longitude ?? null);
    if (payload.hideExactLocation !== undefined) set("hide_exact_location", payload.hideExactLocation ? 1 : 0);
    if (payload.contactName !== undefined) set("contact_name", payload.contactName ?? null);
    if (payload.contactPhone !== undefined) set("contact_phone", payload.contactPhone ?? null);
    if (payload.contactWhatsapp !== undefined) set("contact_whatsapp", payload.contactWhatsapp ?? null);
    if (payload.contactEmail !== undefined) set("contact_email", payload.contactEmail ?? null);
    if (payload.allowCall !== undefined) set("allow_call", payload.allowCall ? 1 : 0);
    if (payload.allowWhatsapp !== undefined) set("allow_whatsapp", payload.allowWhatsapp ? 1 : 0);
    if (payload.allowEmail !== undefined) set("allow_email", payload.allowEmail ? 1 : 0);
    if (payload.seoTitle !== undefined) set("seo_title", payload.seoTitle ?? null);
    if (payload.seoDescription !== undefined) set("seo_description", payload.seoDescription ?? null);

    if (payload.price !== undefined) {
      const currency = payload.currency || (await queryValue("SELECT currency_code FROM listings WHERE id = ?", [listing.id], connection));
      set("price", payload.price ?? null);
      set("currency_code", currency);
      set("price_base", await baseCurrencyAmount(payload.price ?? null, currency, connection));
    } else if (payload.currency !== undefined) {
      set("currency_code", payload.currency);
    }

    if (payload.categorySlug !== undefined) {
      const { categoryId } = await resolveCategoryRow(definition, payload.categorySlug, connection);
      set("category_id", categoryId);
    }
    if (payload.purpose !== undefined) {
      set("purpose_id", await resolvePurposeId(payload.purpose, connection));
    }

    let brandInfo = null;
    if (payload.brand !== undefined) {
      brandInfo = await resolveBrandAndModel({ definition, brand: payload.brand, model: payload.model }, connection);
      set("brand_id", brandInfo.brandId);
      set("brand_model_id", brandInfo.brandModelId);
    }

    let location = null;
    if (payload.locationId !== undefined) {
      location = await resolveLocationChain(payload.locationId, connection);
      set("location_id", location.locationId);
      set("country_id", location.countryId);
      set("state_id", location.stateId);
      set("city_id", location.cityId);
      set("community_id", location.communityId);
      set("sub_community_id", location.subCommunityId);
    }

    if (payload.agentId !== undefined) {
      if (payload.agentId === null) set("agent_id", null);
      else {
        const agentRow = await queryOne(
          `SELECT id FROM agents WHERE (public_id = ? OR id = ?) AND ${ownAgentClause({ organizationId, userId }).sql} AND deleted_at IS NULL LIMIT 1`,
          [String(payload.agentId), /^\d+$/.test(String(payload.agentId)) ? Number(payload.agentId) : 0, ...ownAgentClause({ organizationId, userId }).params],
          connection
        );
        if (!agentRow) throw AppError.validation("Some information is invalid.", { agentId: "That agent is not on this account." });
        set("agent_id", agentRow.id);
      }
    }

    if (assignments.length) {
      await execute(`UPDATE listings SET ${assignments.join(", ")} WHERE id = ?`, [...params, listing.id], connection);
    }

    if (payload.detail !== undefined) {
      await writeDetail({ listingType: definition.listingType, listingId: listing.id, detail: payload.detail }, connection);
    }
    if (payload.featureIds !== undefined || payload.features !== undefined) {
      await writeFeatures({ listingId: listing.id, featureIds: payload.featureIds, featureSlugs: payload.features }, connection);
    }
    if (payload.attributes !== undefined) {
      await writeAttributes({ listingId: listing.id, attributes: payload.attributes }, connection);
    }
    if (payload.mediaAssetIds !== undefined) {
      for (const assetPublicId of payload.mediaAssetIds) {
        const asset = await resolveAssetRef(assetPublicId);
        if (!asset) continue;
        if (asset.account_id && String(asset.account_id) !== String(accountId)) {
          throw AppError.forbidden("One of the selected images belongs to another account.");
        }
        const alreadyLinked = await queryValue(
          "SELECT id FROM listing_media WHERE listing_id = ? AND media_asset_id = ? LIMIT 1",
          [listing.id, asset.id],
          connection
        );
        if (!alreadyLinked) {
          await attachAssetToListing({ listingId: listing.id, assetId: asset.id, altText: asset.alt_text }, connection);
        }
      }
      await syncListingMediaCounters(listing.id, connection);
    }

    // Title, location or brand changing means the canonical URL changes too. While a live
    // listing's changes wait for approval the URL stays put; approving rewrites it (0060).
    if (payload.title !== undefined || location || brandInfo) {
      const pending = await queryValue("SELECT pending_revision_id FROM listings WHERE id = ?", [listing.id], connection);
      if (!pending) await rewriteCanonicalPath(listing.id, connection);
    }
  });

  // Reassigning the agent moves a listing from one agent's counters to another's.
  if (payload.agentId !== undefined) {
    await syncAccountListingUsageForListing(listing.id, undefined, { previousAgentId: listing.agent_id ?? null });
  }
  await refreshListingSearch(listing.id);
  return true;
}

/** Rewrites a listing's slug and canonical path from its title, location, brand and year. */
export async function rewriteCanonicalPath(listingId, connection) {
  const current = await queryOne(
    `SELECT l.id, l.title, l.root_category_id,
            co.slug AS country_slug, st.slug AS state_slug, ct.slug AS city_slug,
            cm.slug AS community_slug, sc.slug AS sub_community_slug,
            br.slug AS brand_slug, bm.slug AS brand_model_slug,
            COALESCE(veh.model_year, mar.build_year, av.year_built, tp.year_of_production) AS year_value
       FROM listings l
       LEFT JOIN locations co ON co.id = l.country_id
       LEFT JOIN locations st ON st.id = l.state_id
       LEFT JOIN locations ct ON ct.id = l.city_id
       LEFT JOIN locations cm ON cm.id = l.community_id
       LEFT JOIN locations sc ON sc.id = l.sub_community_id
       LEFT JOIN brands br ON br.id = l.brand_id
       LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
       LEFT JOIN listing_vehicle veh ON veh.listing_id = l.id
       LEFT JOIN listing_marine mar ON mar.listing_id = l.id
       LEFT JOIN listing_aviation av ON av.listing_id = l.id
       LEFT JOIN listing_timepiece tp ON tp.listing_id = l.id
      WHERE l.id = ?`,
    [listingId],
    connection
  );
  const slug = await uniqueListingSlug(current.title, listingId, connection);
  const canonicalPath = buildCanonicalPath({
    rootCategoryId: current.root_category_id,
    slug,
    location: {
      country: current.country_slug,
      state: current.state_slug,
      city: current.city_slug,
      community: current.community_slug,
      subCommunity: current.sub_community_slug,
    },
    brandSlug: current.brand_slug,
    modelSlug: current.brand_model_slug,
    year: current.year_value,
  });
  await execute("UPDATE listings SET slug = ?, canonical_path = ? WHERE id = ?", [slug, canonicalPath, listingId], connection);
}

/**
 * Status transitions.
 *
 * Publishing is not a client decision: a portal caller may submit for review or
 * withdraw; only a moderator can make a listing active. `sp_refresh_listing_search`
 * adds or removes the projection row to match.
 */
const PORTAL_TRANSITIONS = {
  draft: ["pending_review", "archived"],
  pending_review: ["draft", "withdrawn", "archived"],
  active: ["sold", "rented", "withdrawn", "archived"],
  rejected: ["draft", "pending_review", "archived"],
  expired: ["pending_review", "archived"],
  sold: ["archived"],
  rented: ["archived"],
  withdrawn: ["pending_review", "archived"],
  archived: [],
};

export async function changeListingStatus({ listing, toStatus, reason, userId, byPlatform = false }) {
  const fromStatus = listing.status;
  if (fromStatus === toStatus) return { changed: false };

  if (!byPlatform) {
    const allowed = PORTAL_TRANSITIONS[fromStatus] || [];
    if (!allowed.includes(toStatus)) {
      throw AppError.conflict(`A listing that is ${fromStatus.replace("_", " ")} cannot be moved to ${toStatus.replace("_", " ")}.`);
    }
    // Submitting a listing that does not yet count toward the live limit takes a live slot.
    if (LIVE_LIMIT_STATUSES.includes(toStatus) && !LIVE_LIMIT_STATUSES.includes(fromStatus)) {
      await assertLiveSlotAvailable({ accountId: listing.account_id, rootCategoryId: listing.root_category_id });
    }
  }

  await withTransaction(async (connection) => {
    const extra = [];
    const params = [toStatus];
    if (toStatus === "pending_review") extra.push("moderation_status = 'pending'");
    if (toStatus === "active") {
      extra.push("moderation_status = 'approved'");
      extra.push("unpublished_by_platform_at = NULL");
      extra.push("published_at = COALESCE(published_at, NOW(3))");
      extra.push("expires_at = COALESCE(expires_at, DATE_ADD(NOW(3), INTERVAL 90 DAY))");
    }
    if (toStatus === "sold" || toStatus === "rented") extra.push("sold_at = NOW(3)");
    if (toStatus === "archived") extra.push("is_indexable = 0");

    await execute(
      `UPDATE listings SET status = ?${extra.length ? `, ${extra.join(", ")}` : ""} WHERE id = ?`,
      [...params, listing.id],
      connection
    );
    await recordStatusChange({ listingId: listing.id, fromStatus, toStatus, userId, reason }, connection);
    // A moderator publishing the whole listing reviewed every change in it; an archived listing
    // has nothing left to review.
    if ((toStatus === "active" && fromStatus !== "active") || toStatus === "archived") {
      await closeOpenRevision(listing.id, connection);
    }
    // A real-estate listing going in or out of `active` moves its unit's active counter.
    await syncUnitListingCountersForListing(listing.id, connection);
    // Archive, withdraw, sold/rented and expiry free an allowance slot; a resubmission takes one.
    await syncAccountListingUsageForListing(listing.id, connection);
  });

  await refreshListingSearch(listing.id);
  return { changed: true, fromStatus, toStatus };
}

/**
 * An owner's change to a live listing waits for a moderator (0060).
 *
 * Approval covers the version a moderator looked at. Once the owner changes anything (text,
 * price, specs, a photo, a document, the photo order) the change goes to the queue, while the
 * public site keeps showing the approved version until it is approved. Call this BEFORE the
 * change is applied: it captures the approved page first. A moderator's own edit is not an owner
 * change and never comes here.
 */
export async function holdOwnerChange({ listingId, userId, reason = "Changed by the owner after approval" }) {
  const revisionId = await beginOwnerChange({ listingId, userId, change: reason });
  return { changed: false, pendingRevision: Boolean(revisionId) };
}

/**
 * What an owner's edit does to the listing's status.
 *
 * A live listing keeps its status: the change itself waits as a pending revision (see
 * `holdOwnerChange`, called before the edit). Any other listing takes the status the edit form asked
 * for ("Save draft" / "Submit for review") where the portal may make that move. The form always
 * sent it and the update ignored it, so "Submit for review" on an edited rejected listing never
 * actually resubmitted it.
 */
export async function applyOwnerEditStatus({ listing, requestedStatus, edited, userId }) {
  if (listing.status === "active") return { changed: false };
  if (!requestedStatus || requestedStatus === listing.status) return { changed: false };
  if (!(PORTAL_TRANSITIONS[listing.status] || []).includes(requestedStatus)) return { changed: false };
  return changeListingStatus({ listing, toStatus: requestedStatus, reason: "Changed with an edit by the owner", userId });
}

export async function archiveListing({ listing, userId, reason }) {
  return changeListingStatus({ listing, toStatus: "archived", reason: reason || "archived by owner", userId });
}

export async function softDeleteListing({ listing, userId }) {
  await withTransaction(async (connection) => {
    await execute("UPDATE listings SET deleted_at = NOW(3), is_indexable = 0 WHERE id = ?", [listing.id], connection);
    await recordStatusChange(
      { listingId: listing.id, fromStatus: listing.status, toStatus: "archived", userId, reason: "deleted" },
      connection
    );
    await syncUnitListingCountersForListing(listing.id, connection);
    await syncAccountListingUsageForListing(listing.id, connection);
  });
  await refreshListingSearch(listing.id);
}

export { DETAIL_TABLE, DETAIL_COLUMNS };
