import {
  query, queryOne, queryValue, adminPagination, adminList, int, num, bool, isoDate, isoDay,
  frontendCategoryId, categoryIdsFor, rootIdFor,
} from "./admin.shared.js";
import { adminListingStatus, initialsOf } from "./admin.dashboard.js";
import * as options from "./admin.options.js";
import { CATEGORY_DEFINITIONS } from "../../utils/categories.js";
import { AppError } from "../../utils/errors.js";
import {
  LAUNCH_STATUSES,
  OWNERSHIP_TYPES,
  PROJECT_STATUSES,
  PROJECT_TYPES,
  UNIT_TYPES,
} from "../projects/projects.filters.js";

/**
 * Admin catalogue reads: listings, developments, companies, individuals,
 * agents, locations and categories.
 *
 * The admin surface reads the raw tables, not `v_public_listings` — its job is
 * to see the unpublished rows. Authorization for that lives on the route.
 */

/* -------------------------------------------------------------------------- */
/* Listings                                                                    */
/* -------------------------------------------------------------------------- */

const ADMIN_STATUS_TO_DB = {
  approved: ["active"],
  pending: ["pending_review"],
  rejected: ["rejected"],
  sold: ["sold", "rented"],
  archived: ["archived", "withdrawn"],
  draft: ["draft"],
  expired: ["expired"],
};

export async function listAdminListings({
  category = "real-estate",
  status = "all",
  search = "",
  owner = "",
  location = "",
  sort = "newest",
  page = 1,
  pageSize = 10,
  scopedRootIds = null,
} = {}) {
  const definition = CATEGORY_DEFINITIONS.find((entry) => entry.listingType === category || entry.dbCode === category);
  const conditions = ["l.deleted_at IS NULL"];
  const params = [];

  if (definition) {
    conditions.push("l.root_category_id = ?");
    params.push(definition.rootId);
  }
  // A category-scoped role sees a filtered list rather than an error: the page still works,
  // it just contains what they are allowed to work on. An empty array means the role is
  // scoped to nothing at all, so nothing matches.
  if (Array.isArray(scopedRootIds)) {
    if (!scopedRootIds.length) {
      conditions.push("1 = 0");
    } else {
      conditions.push(`l.root_category_id IN (${scopedRootIds.map(() => "?").join(", ")})`);
      params.push(...scopedRootIds);
    }
  }
  const statuses = ADMIN_STATUS_TO_DB[status];
  if (statuses) {
    conditions.push(`l.status IN (${statuses.map(() => "?").join(", ")})`);
    params.push(...statuses);
  }
  if (search) {
    conditions.push("(l.title LIKE ? OR l.reference LIKE ? OR l.public_id = ?)");
    params.push(`%${search}%`, `%${search}%`, search);
  }
  if (owner) {
    conditions.push("(org.name LIKE ? OR u.display_name LIKE ?)");
    params.push(`%${owner}%`, `%${owner}%`);
  }
  if (location) {
    conditions.push("(ct.name LIKE ? OR cm.name LIKE ? OR co.name LIKE ?)");
    params.push(`%${location}%`, `%${location}%`, `%${location}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });
  const orderBy =
    { newest: "l.created_at DESC", oldest: "l.created_at ASC", priceDesc: "l.price DESC", priceAsc: "l.price ASC", views: "l.view_count DESC" }[sort] ||
    "l.created_at DESC";

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT l.id, l.public_id, l.reference, l.title, l.status, l.moderation_status, l.price,
              l.currency_code, l.cover_image_url, l.created_at, l.published_at, l.updated_at,
              l.view_count, l.inquiry_count, l.root_category_id,
              cat.name AS category_name,
              CONCAT_WS(', ', NULLIF(cm.name, ''), NULLIF(ct.name, ''), NULLIF(co.name, '')) AS location,
              COALESCE(org.name, u.display_name) AS owner,
              org.public_id AS organization_public_id,
              ag.display_name AS agent_name,
              br.name AS brand_name, bm.name AS model_name,
              re.bedrooms, re.bathrooms, re.built_area_sqft,
              veh.model_year, veh.mileage_km,
              mar.build_year, mar.length_overall_ft,
              av.year_built, av.passenger_capacity, av.range_nm, av.total_time_hours, av.aircraft_type,
              tp.reference_number, tp.year_of_production
         FROM listings l
         JOIN categories cat ON cat.id = l.category_id
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations cm ON cm.id = l.community_id
         LEFT JOIN organizations org ON org.id = l.organization_id
         LEFT JOIN users u ON u.id = l.created_by_user_id
         LEFT JOIN agents ag ON ag.id = l.agent_id
         LEFT JOIN brands br ON br.id = l.brand_id
         LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
         LEFT JOIN listing_real_estate re ON re.listing_id = l.id
         LEFT JOIN listing_vehicle veh ON veh.listing_id = l.id
         LEFT JOIN listing_marine mar ON mar.listing_id = l.id
         LEFT JOIN listing_aviation av ON av.listing_id = l.id
         LEFT JOIN listing_timepiece tp ON tp.listing_id = l.id
         ${where}
        ORDER BY ${orderBy} LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(
      `SELECT COUNT(*) FROM listings l
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations cm ON cm.id = l.community_id
         LEFT JOIN organizations org ON org.id = l.organization_id
         LEFT JOIN users u ON u.id = l.created_by_user_id
         ${where}`,
      params
    ),
    listingSummaryFor(definition?.rootId ?? null),
  ]);

  return adminList({
    items: rows.map(serializeAdminListingRow),
    total,
    page: safePage,
    pageSize: safeSize,
    summary,
    options: await listingFilterOptions(definition),
  });
}

/**
 * The Select controls above the listings table. Each marketplace category names
 * the same two axes differently — a car has a make and a model, a yacht a
 * builder and a model, a watch a brand and a collection — so every alias is
 * emitted and the view picks the pair its category uses.
 */
async function listingFilterOptions(definition) {
  const [makes, builders, manufacturers, watchBrands, carModels, yachtModels, aircraftModels, watchModels, propertyTypes, locationList] =
    await Promise.all([
      options.brandsOfKind("car_make"),
      options.brandsOfKind("yacht_builder"),
      options.brandsOfKind("aircraft_manufacturer"),
      options.brandsOfKind("watch_brand"),
      options.brandModels("car_make"),
      options.brandModels("yacht_builder"),
      options.brandModels("aircraft_manufacturer"),
      options.brandModels("watch_brand"),
      options.categoryTypes(1),
      options.locations(200),
    ]);

  const modelsFor = {
    cars: carModels,
    yachts: yachtModels,
    jets: aircraftModels,
    helicopters: aircraftModels,
    watches: watchModels,
  };
  const brandsFor = {
    cars: makes,
    yachts: builders,
    jets: manufacturers,
    helicopters: manufacturers,
    watches: watchBrands,
  };
  const type = definition?.listingType ?? null;

  return {
    makes,
    builders,
    manufacturers,
    brands: brandsFor[type] ?? [...makes, ...builders, ...manufacturers, ...watchBrands],
    models: modelsFor[type] ?? [],
    collections: watchModels,
    propertyTypes,
    conditions: options.staticOptions(["new", "used", "certified_pre_owned", "unworn", "excellent", "good", "fair"]),
    locations: locationList,
    statuses: options.staticOptions(["approved", "pending", "rejected", "archived", "draft", "sold"]),
  };
}

/**
 * Selects above the Developments table.
 *
 * Every option here is the value the filter actually matches on, not a display
 * string that happened to be near it: the developer select sent a brand id to a
 * filter comparing slugs, and the property-type and location selects were handed
 * `{value,label}` objects by a view that spread them into `{value: option}` —
 * so all three rendered or matched nothing. A control that cannot filter is
 * worse than a missing one.
 */
async function developmentFilterOptions() {
  const [developers, handoverYears, locationList] = await Promise.all([
    options.developers(),
    options.handoverYears(),
    developmentLocationOptions(),
  ]);
  return {
    developers,
    handoverYears,
    locations: locationList,
    // The vocabulary `project_unit_types.unit_type` stores, which is what the
    // filter compares against.
    propertyTypes: options.staticOptions([...UNIT_TYPES]),
    projectTypes: options.staticOptions([...PROJECT_TYPES]),
    developmentStatuses: options.staticOptions([...PROJECT_STATUSES]),
    launchStatuses: options.staticOptions([...LAUNCH_STATUSES]),
    moderationStatuses: options.staticOptions(["draft", "pending", "published", "rejected", "archived"]),
    ownershipTypes: options.staticOptions([...OWNERSHIP_TYPES]),
  };
}

/** Locations that actually hold a development, so the select cannot offer an empty filter. */
async function developmentLocationOptions() {
  const rows = await query(
    `SELECT l.id, l.name, l.level, COUNT(*) AS project_count
       FROM (SELECT country_id AS location_id FROM projects WHERE deleted_at IS NULL AND country_id IS NOT NULL
             UNION ALL SELECT state_id FROM projects WHERE deleted_at IS NULL AND state_id IS NOT NULL
             UNION ALL SELECT city_id FROM projects WHERE deleted_at IS NULL AND city_id IS NOT NULL
             UNION ALL SELECT community_id FROM projects WHERE deleted_at IS NULL AND community_id IS NOT NULL) t
       JOIN locations l ON l.id = t.location_id
      GROUP BY l.id, l.name, l.level
      ORDER BY project_count DESC, l.name ASC
      LIMIT 200`
  );
  return rows.map((row) => ({ value: String(row.id), label: row.name, level: row.level }));
}

/** Selects above the Companies and Individuals tables. */
async function companyFilterOptions() {
  const [countries, packages] = await Promise.all([options.countries(), options.packages()]);
  return {
    countries,
    packages,
    categories: options.marketplaceCategories(),
    statuses: options.staticOptions(["active", "pending", "suspended", "inactive"]),
  };
}

/**
 * Selects above a Locations table. Each tier filters by its ancestors, so a tier
 * only ships the levels above it — shipping all five would put 161k rows in a
 * dropdown nobody opened.
 */
async function locationFilterOptions(tier) {
  const wanted = {
    country: [],
    state: ["countries"],
    city: ["countries", "states"],
    community: ["countries", "states", "cities"],
    subCommunity: ["countries", "states", "cities", "communities"],
  }[tier] ?? [];
  const loaders = { countries: options.countries, states: options.states, cities: options.cities, communities: options.communities };
  const entries = await Promise.all(wanted.map(async (name) => [name, await loaders[name]()]));
  return Object.fromEntries(entries);
}

async function listingSummaryFor(rootCategoryId) {
  const row = await queryOne(
    `SELECT COUNT(*) AS total,
            SUM(status = 'active') AS approved,
            SUM(status = 'pending_review') AS pending,
            SUM(status = 'rejected') AS rejected,
            SUM(status IN ('sold','rented')) AS sold,
            SUM(status IN ('archived','withdrawn')) AS archived,
            SUM(status = 'draft') AS draft
       FROM listings
      WHERE deleted_at IS NULL${rootCategoryId ? " AND root_category_id = ?" : ""}`,
    rootCategoryId ? [rootCategoryId] : []
  );
  return {
    total: int(row?.total) ?? 0,
    all: int(row?.total) ?? 0,
    approved: int(row?.approved) ?? 0,
    pending: int(row?.pending) ?? 0,
    rejected: int(row?.rejected) ?? 0,
    sold: int(row?.sold) ?? 0,
    archived: int(row?.archived) ?? 0,
    draft: int(row?.draft) ?? 0,
  };
}

export function serializeAdminListingRow(row) {
  const categoryId = frontendCategoryId(row.root_category_id);
  const base = {
    id: row.public_id,
    listingId: String(row.id),
    reference: row.reference,
    title: row.title,
    status: adminListingStatus(row.status),
    rawStatus: row.status,
    moderationStatus: row.moderation_status,
    price: row.price ? `${row.currency_code} ${Math.round(num(row.price)).toLocaleString("en")}` : "On request",
    priceValue: num(row.price),
    currency: row.currency_code,
    image: row.cover_image_url,
    location: row.location,
    owner: row.owner,
    ownerInitials: initialsOf(row.owner),
    organizationId: row.organization_public_id,
    agentName: row.agent_name,
    categoryId,
    category: categoryId,
    propertyType: row.category_name,
    views: int(row.view_count) ?? 0,
    inquiries: int(row.inquiry_count) ?? 0,
    dateAdded: isoDate(row.created_at),
    publishedAt: isoDate(row.published_at),
    updatedAt: isoDate(row.updated_at),
  };
  if (categoryId === "realEstate") {
    return { ...base, beds: int(row.bedrooms), baths: int(row.bathrooms), area: num(row.built_area_sqft) };
  }
  if (categoryId === "car") {
    return { ...base, make: row.brand_name, model: row.model_name, year: int(row.model_year), mileage: int(row.mileage_km) };
  }
  if (categoryId === "yacht") {
    return { ...base, builder: row.brand_name, model: row.model_name, year: int(row.build_year), length: num(row.length_overall_ft), yachtType: row.category_name };
  }
  if (categoryId === "jet" || categoryId === "helicopter") {
    return {
      ...base,
      manufacturer: row.brand_name,
      model: row.model_name,
      year: int(row.year_built),
      passengers: int(row.passenger_capacity),
      // The helicopters table's Capacity column reads `capacity`; jets read `passengers`. One
      // number, two names, because the two screens were written separately.
      capacity: int(row.passenger_capacity),
      range: int(row.range_nm),
      flightHours: int(row.total_time_hours),
      aircraftType: row.aircraft_type,
      helicopterType: row.aircraft_type,
    };
  }
  if (categoryId === "watch") {
    return { ...base, brand: row.brand_name, collection: row.model_name, watchReference: row.reference_number, year: int(row.year_of_production) };
  }
  return base;
}

/* -------------------------------------------------------------------------- */
/* Developments (projects) — a distinct domain from marketplace listings.       */
/* -------------------------------------------------------------------------- */

export async function listAdminDevelopments({
  status = "all",
  search = "",
  developer = "",
  developmentStatus = "",
  projectType = "",
  propertyType = "",
  handoverYear = "",
  location = "",
  priceMin = "",
  priceMax = "",
  sort = "newest",
  page = 1,
  pageSize = 10,
} = {}) {
  const conditions = ["p.deleted_at IS NULL"];
  const params = [];

  /**
   * The tabs are the moderation state, not the lifecycle.
   *
   * They always were — Draft, Pending Review, Published, Rejected, Archived —
   * but the filter compared them against `projects.status`, which holds
   * `announced`/`under_construction`/…, so no tab except "All" ever matched a
   * row. Publication is now its own column and the tabs read it.
   */
  if (status && status !== "all") {
    conditions.push("p.moderation_status = ?");
    params.push(status);
  }
  if (developmentStatus) {
    conditions.push("p.status = ?");
    params.push(developmentStatus);
  }
  if (projectType) {
    conditions.push("p.project_type = ?");
    params.push(projectType);
  }
  if (search) {
    // Placed against what the box promises — "development, developer, location
    // or Ref No" — rather than name and slug alone.
    conditions.push(
      "(p.name LIKE ? OR p.slug LIKE ? OR p.public_id = ? OR b.name LIKE ? OR co.name LIKE ? OR ct.name LIKE ? OR cm.name LIKE ?)"
    );
    params.push(`%${search}%`, `%${search}%`, search, `%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (developer) {
    // Accepts either the slug the public URL uses or the brand's public id, so
    // the select and a hand-typed filter agree.
    conditions.push("(b.slug = ? OR b.public_id = ?)");
    params.push(developer, developer);
  }
  if (handoverYear) {
    conditions.push("YEAR(p.handover_date) = ?");
    params.push(Number(handoverYear));
  }
  if (location) {
    conditions.push("? IN (p.country_id, p.state_id, p.city_id, p.community_id, p.sub_community_id)");
    params.push(Number(location));
  }
  if (propertyType) {
    conditions.push("EXISTS (SELECT 1 FROM project_unit_types ut WHERE ut.project_id = p.id AND ut.unit_type = ?)");
    params.push(propertyType);
  }
  if (priceMin !== "" && priceMin !== null && priceMin !== undefined) {
    conditions.push("p.min_price >= ?");
    params.push(Number(priceMin));
  }
  if (priceMax !== "" && priceMax !== null && priceMax !== undefined) {
    conditions.push("p.min_price <= ?");
    params.push(Number(priceMax));
  }

  const joins = `
    LEFT JOIN brands b ON b.id = p.developer_brand_id
    LEFT JOIN locations co ON co.id = p.country_id
    LEFT JOIN locations st ON st.id = p.state_id
    LEFT JOIN locations ct ON ct.id = p.city_id
    LEFT JOIN locations cm ON cm.id = p.community_id`;
  const where = `WHERE ${conditions.join(" AND ")}`;
  const orderBy = sort === "oldest" ? "p.created_at ASC" : "p.created_at DESC";
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT p.id, p.public_id, p.name, p.slug, p.canonical_path, p.tagline, p.project_type,
              p.status, p.launch_status, p.ownership_type, p.moderation_status, p.published_at,
              p.completion_percentage, p.launch_date, p.construction_start_date, p.handover_date,
              p.total_units, p.available_units, p.building_count,
              p.min_price, p.max_price, p.currency_code, p.cover_image_url,
              p.is_featured, p.accepts_inquiries, p.is_publicly_visible, p.listing_count,
              p.created_at, p.updated_at,
              b.id AS developer_id, b.name AS developer_name, b.slug AS developer_slug,
              b.public_id AS developer_public_id, b.logo_url AS developer_logo_url,
              co.name AS country_name, st.name AS state_name, ct.name AS city_name, cm.name AS community_name,
              cat.name AS category_name,
              (SELECT COUNT(*) FROM inquiries i WHERE i.project_id = p.id) AS lead_count
         FROM projects p
         ${joins}
         LEFT JOIN categories cat ON cat.id = p.category_id
         ${where}
        ORDER BY ${orderBy} LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM projects p ${joins} ${where}`, params),
    queryOne(
      // Counted per moderation state so every tab and card has a real source.
      `SELECT COUNT(*) AS total,
              SUM(moderation_status = 'draft') AS draft,
              SUM(moderation_status = 'pending') AS pending,
              SUM(moderation_status = 'published') AS published,
              SUM(moderation_status = 'rejected') AS rejected,
              SUM(moderation_status = 'archived') AS archived,
              SUM(status = 'announced') AS upcoming,
              SUM(launch_status = 'launched') AS launch,
              SUM(status = 'under_construction') AS underConstruction,
              SUM(status IN ('completed','handed_over')) AS handover
         FROM projects WHERE deleted_at IS NULL`
    ),
  ]);

  return adminList({
    items: rows.map(serializeAdminDevelopment),
    total,
    page: safePage,
    pageSize: safeSize,
    summary: {
      total: int(summary?.total) ?? 0,
      draft: int(summary?.draft) ?? 0,
      pending: int(summary?.pending) ?? 0,
      published: int(summary?.published) ?? 0,
      rejected: int(summary?.rejected) ?? 0,
      archived: int(summary?.archived) ?? 0,
      upcoming: int(summary?.upcoming) ?? 0,
      launch: int(summary?.launch) ?? 0,
      underConstruction: int(summary?.underConstruction) ?? 0,
      handover: int(summary?.handover) ?? 0,
    },
    options: await developmentFilterOptions(),
  });
}

/**
 * The admin row DTO.
 *
 * `developer` is an object — id, slug, name, logo — because every screen that
 * reads it needs at least two of those, and the string it used to be forced the
 * edit form to match a name back to an id by comparing display text.
 */
function serializeAdminDevelopment(row) {
  return {
    id: row.public_id,
    projectId: String(row.id),
    reference: row.public_id,
    name: row.name,
    slug: row.slug,
    tagline: row.tagline,
    canonicalPath: row.canonical_path,
    publicUrl: row.moderation_status === "published" && bool(row.is_publicly_visible) ? row.canonical_path : null,

    developer: row.developer_public_id
      ? {
          id: row.developer_public_id,
          slug: row.developer_slug,
          name: row.developer_name,
          logoUrl: row.developer_logo_url,
        }
      : null,
    developerId: row.developer_public_id,

    projectType: row.project_type,
    // Lifecycle, launch and moderation are three answers to three different
    // questions and are reported as three fields.
    developmentStatus: row.status,
    launchStatus: row.launch_status,
    moderationStatus: row.moderation_status,
    ownershipType: row.ownership_type,
    status: row.status,
    published: bool(row.is_publicly_visible) && row.moderation_status === "published",
    publishedAt: isoDate(row.published_at),
    featured: bool(row.is_featured),
    acceptInquiries: bool(row.accepts_inquiries),

    completionPercentage: int(row.completion_percentage) ?? 0,
    construction: {
      completionPercentage: int(row.completion_percentage),
      constructionStartedAt: isoDay(row.construction_start_date),
    },
    constructionStartedAt: isoDay(row.construction_start_date),
    launch: {
      status: row.launch_status,
      launchDate: isoDay(row.launch_date),
      startingPrice: { amount: num(row.min_price), currency: row.currency_code },
    },
    handover: {
      date: isoDay(row.handover_date),
      expectedCompletionDate: isoDay(row.handover_date),
      ...quarterOf(row.handover_date),
    },
    expectedCompletionAt: isoDay(row.handover_date),
    expectedCompletionDate: isoDay(row.handover_date),

    totalUnits: int(row.total_units),
    availableUnits: int(row.available_units),
    buildingsCount: int(row.building_count),
    startingPrice: { amount: num(row.min_price), currency: row.currency_code },
    priceRange: { min: num(row.min_price), max: num(row.max_price), currency: row.currency_code },
    currency: row.currency_code,
    coverImage: row.cover_image_url,

    location: {
      country: row.country_name,
      state: row.state_name,
      city: row.city_name,
      community: row.community_name,
      display: [row.community_name, row.city_name, row.state_name, row.country_name].filter(Boolean).join(", "),
    },
    country: row.country_name,
    city: row.city_name,
    community: row.community_name,
    category: row.category_name,

    listingsCount: int(row.listing_count) ?? 0,
    leadsCount: int(row.lead_count) ?? 0,
    dateAdded: isoDate(row.created_at),
    updatedAt: isoDate(row.updated_at),
  };
}

/** `2027-06-14` → `{ quarter: "Q2", year: 2027 }`, the shape the wizard edits. */
function quarterOf(value) {
  const day = isoDay(value);
  if (!day) return { quarter: null, year: null };
  return { quarter: `Q${Math.floor((Number(day.slice(5, 7)) - 1) / 3) + 1}`, year: Number(day.slice(0, 4)) };
}

/**
 * The full admin record.
 *
 * The wizard round-trips through this: everything it can set, it can read back.
 * Before, it read back twelve of the sixty-odd fields it collected, so opening a
 * saved development for editing silently reset the rest to their defaults.
 */
export async function getAdminDevelopment(identifier) {
  const row = await queryOne(
    `SELECT p.*,
            b.id AS developer_id, b.name AS developer_name, b.slug AS developer_slug,
            b.public_id AS developer_public_id, b.logo_url AS developer_logo_url,
            co.name AS country_name, st.name AS state_name, ct.name AS city_name, cm.name AS community_name,
            sc.name AS sub_community_name,
            cat.name AS category_name,
            (SELECT COUNT(*) FROM inquiries i WHERE i.project_id = p.id) AS lead_count
       FROM projects p
       LEFT JOIN brands b ON b.id = p.developer_brand_id
       LEFT JOIN locations co ON co.id = p.country_id
       LEFT JOIN locations st ON st.id = p.state_id
       LEFT JOIN locations ct ON ct.id = p.city_id
       LEFT JOIN locations cm ON cm.id = p.community_id
       LEFT JOIN locations sc ON sc.id = p.sub_community_id
       LEFT JOIN categories cat ON cat.id = p.category_id
      WHERE p.public_id = ? OR p.slug = ? LIMIT 1`,
    [identifier, identifier]
  );
  if (!row) return null;

  const [paymentPlans, milestones, unitTypes, amenities, media, documents, floorPlans, tours, listings] =
    await Promise.all([
      query(
        `SELECT id, name, description, plan_type, down_payment_percent, during_construction_percent,
                on_handover_percent, post_handover_percent, post_handover_months,
                waives_registration_fee, service_charge_waiver_years,
                guaranteed_return_percent, guaranteed_return_years
           FROM project_payment_plans WHERE project_id = ? AND is_active = 1 ORDER BY id ASC`,
        [row.id]
      ),
      query(
        `SELECT m.plan_id, m.sequence_number, m.name, m.trigger_type, m.construction_percent,
                m.months_offset, m.fixed_date, m.amount_percent, m.fixed_amount, m.currency_code, m.notes
           FROM payment_plan_milestones m
           JOIN project_payment_plans pp ON pp.id = m.plan_id
          WHERE pp.project_id = ? ORDER BY m.plan_id ASC, m.sequence_number ASC`,
        [row.id]
      ),
      query(
        `SELECT ut.public_id, ut.unit_type, ut.name, ut.bedrooms, ut.bathrooms, ut.min_size, ut.max_size,
                ut.starting_price, ut.max_price, ut.currency_code, ut.availability,
                ut.available_units, ut.total_units, ut.sort_order, mu.code AS area_unit
           FROM project_unit_types ut
           LEFT JOIN measurement_units mu ON mu.id = ut.area_unit_id
          WHERE ut.project_id = ? ORDER BY ut.sort_order ASC, ut.id ASC`,
        [row.id]
      ),
      query("SELECT slug, label, category, sort_order FROM project_amenities WHERE project_id = ? ORDER BY sort_order ASC", [row.id]),
      query(
        `SELECT ma.role, ma.sort_order, ma.is_primary, ma.caption,
                a.public_id, COALESCE(a.cdn_url, a.url) AS url, a.file_name, a.mime_type
           FROM media_attachments ma
           JOIN media_assets a ON a.id = ma.media_asset_id
          WHERE ma.attachable_type = 'project' AND ma.attachable_id = ?
          ORDER BY ma.role ASC, ma.is_primary DESC, ma.sort_order ASC`,
        [row.id]
      ),
      // The admin read is not the public read: an operator must see restricted
      // and internal documents, which is exactly what the public DTO must not.
      query(
        `SELECT d.public_id, d.document_type, d.title, d.description, d.visibility, d.status,
                d.page_count, d.file_size_bytes, d.version, COALESCE(a.cdn_url, a.url) AS url
           FROM documents d
           LEFT JOIN media_assets a ON a.id = d.media_asset_id
          WHERE d.owner_type = 'project' AND d.owner_id = ? AND d.deleted_at IS NULL
          ORDER BY d.document_type ASC, d.id ASC`,
        [row.id]
      ),
      query(
        `SELECT fp.id, fp.name, fp.floor_level, fp.total_area_sqm, fp.total_area_sqft,
                fp.requires_lead, fp.is_public, fp.sort_order, COALESCE(a.cdn_url, a.url) AS url
           FROM floor_plans fp
           LEFT JOIN media_assets a ON a.id = fp.media_asset_id
          WHERE fp.project_id = ? ORDER BY fp.sort_order ASC, fp.id ASC`,
        [row.id]
      ),
      query(
        `SELECT public_id, title, tour_type, provider, embed_url, status
           FROM virtual_tours WHERE project_id = ? ORDER BY id ASC`,
        [row.id]
      ),
      query(
        `SELECT l.public_id, l.reference, l.title, l.status, l.price, l.currency_code, l.cover_image_url
           FROM listings l WHERE l.project_id = ? AND l.deleted_at IS NULL
          ORDER BY l.created_at DESC LIMIT 50`,
        [row.id]
      ),
    ]);

  const highlights = (() => {
    const parsed = typeof row.highlights === "string" ? safeJson(row.highlights, []) : row.highlights || [];
    return Array.isArray(parsed) ? parsed.filter(Boolean) : [];
  })();
  const jsonAmenities = typeof row.amenities === "string" ? safeJson(row.amenities, []) : row.amenities || [];
  const mediaByRole = (role) => media.filter((item) => item.role === role);
  const asMedia = (item) => ({
    id: item.public_id,
    src: item.url,
    url: item.url,
    filename: item.file_name,
    label: item.caption || item.file_name,
    primary: bool(item.is_primary),
    sortOrder: int(item.sort_order) ?? 0,
    mimeType: item.mime_type,
  });

  const bedroomCounts = unitTypes
    .map((item) => int(item.bedrooms))
    .filter((value) => value !== null && value !== undefined);

  return {
    ...serializeAdminDevelopment(row),
    description: {
      heading: row.marketing_heading,
      body: row.description,
      overview: row.description,
      seoTitle: row.seo_title,
      meta: row.seo_description,
      slug: row.slug,
    },
    highlights,
    marketingHeading: row.marketing_heading,
    address: row.address_line1,
    location: {
      country: row.country_name,
      state: row.state_name,
      city: row.city_name,
      community: row.community_name,
      subCommunity: row.sub_community_name,
      countryId: row.country_id ? String(row.country_id) : "",
      stateId: row.state_id ? String(row.state_id) : "",
      cityId: row.city_id ? String(row.city_id) : "",
      communityId: row.community_id ? String(row.community_id) : "",
      subCommunityId: row.sub_community_id ? String(row.sub_community_id) : "",
      address: row.address_line1,
      display: [row.community_name, row.city_name, row.state_name, row.country_name].filter(Boolean).join(", "),
      latitude: num(row.latitude),
      longitude: num(row.longitude),
    },
    latitude: num(row.latitude),
    longitude: num(row.longitude),
    // Rows first; the legacy JSON column is reported alongside so nothing that
    // predates the table is invisible to an operator.
    amenities: amenities.length ? amenities.map((item) => item.label) : (Array.isArray(jsonAmenities) ? jsonAmenities : []),
    amenityRecords: amenities.map((item) => ({ slug: item.slug, label: item.label, category: item.category })),
    propertyTypes: [...new Set(unitTypes.map((item) => item.unit_type))],
    /**
     * Only the unit types that actually state a bedroom count.
     *
     * `?? 0` counted a bedroom-less unit type — an office, a plot, a whole building — as a
     * zero-bedroom home, so a development selling 8-bedroom villas alongside retail reported a
     * range starting at 0. A missing bedroom count is not a studio; the range is null when no
     * unit type declares one.
     */
    bedroomRange: bedroomCounts.length
      ? { min: Math.min(...bedroomCounts), max: Math.max(...bedroomCounts) }
      : null,
    unitTypes: unitTypes.map((item) => ({
      id: item.public_id,
      type: item.unit_type,
      name: item.name,
      bedrooms: int(item.bedrooms),
      bathrooms: num(item.bathrooms),
      sizeRange: { min: num(item.min_size), max: num(item.max_size), unit: item.area_unit },
      startingPrice: { amount: num(item.starting_price), currency: item.currency_code },
      maxPrice: { amount: num(item.max_price), currency: item.currency_code },
      availability: item.availability,
      availableUnits: int(item.available_units),
      totalUnits: int(item.total_units),
      sortOrder: int(item.sort_order) ?? 0,
    })),
    paymentPlans: paymentPlans.map((plan) => ({
      id: String(plan.id),
      name: plan.name,
      description: plan.description,
      type: plan.plan_type,
      downPaymentPercent: num(plan.down_payment_percent),
      duringConstructionPercent: num(plan.during_construction_percent),
      onHandoverPercent: num(plan.on_handover_percent),
      postHandoverPercent: num(plan.post_handover_percent),
      postHandoverMonths: int(plan.post_handover_months),
      waivesRegistrationFee: bool(plan.waives_registration_fee),
      serviceChargeWaiverYears: int(plan.service_charge_waiver_years),
      guaranteedReturnPercent: num(plan.guaranteed_return_percent),
      guaranteedReturnYears: int(plan.guaranteed_return_years),
      milestones: milestones
        .filter((milestone) => String(milestone.plan_id) === String(plan.id))
        .map((milestone) => ({
          id: `${plan.id}-${milestone.sequence_number}`,
          sequence: int(milestone.sequence_number),
          label: milestone.name,
          name: milestone.name,
          timing: milestone.trigger_type,
          triggerType: milestone.trigger_type,
          constructionPercent: num(milestone.construction_percent),
          monthsOffset: int(milestone.months_offset),
          date: isoDay(milestone.fixed_date),
          percentage: num(milestone.amount_percent),
          amount: num(milestone.fixed_amount),
          notes: milestone.notes,
        })),
    })),
    media: {
      gallery: mediaByRole("gallery").map(asMedia),
      masterplan: mediaByRole("masterplan").map(asMedia)[0] || null,
      video: mediaByRole("video").map((item) => ({ id: item.public_id, url: item.url, uploadType: "Upload" }))[0] || null,
      brochure: mediaByRole("brochure").map(asMedia)[0] || null,
      floorPlans: floorPlans.map((plan) => ({
        id: String(plan.id),
        title: plan.name,
        floorLevel: int(plan.floor_level),
        areaSqm: num(plan.total_area_sqm),
        areaSqft: num(plan.total_area_sqft),
        requiresLead: bool(plan.requires_lead),
        isPublic: bool(plan.is_public),
        url: plan.url,
      })),
      documents: documents.map((document) => ({
        id: document.public_id,
        type: document.document_type,
        title: document.title,
        description: document.description,
        visibility: document.visibility,
        status: document.status,
        pageCount: int(document.page_count),
        fileSizeBytes: int(document.file_size_bytes),
        version: document.version,
        url: document.url,
      })),
      virtualTours: tours.map((tour) => ({
        id: tour.public_id,
        title: tour.title,
        type: tour.tour_type,
        provider: tour.provider,
        embedUrl: tour.embed_url,
        status: tour.status,
      })),
    },
    brochureUrl: row.brochure_url,
    seo: { title: row.seo_title, description: row.seo_description },
    listings: listings.map((unit) => ({
      id: unit.public_id,
      reference: unit.reference,
      title: unit.title,
      status: adminListingStatus(unit.status),
      price: unit.price ? `${unit.currency_code} ${Math.round(num(unit.price)).toLocaleString("en")}` : "On request",
      image: unit.cover_image_url,
    })),
  };
}

function safeJson(value, fallback) {
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
}


export async function listDevelopers({ search = "", limit = 100 } = {}) {
  const params = ["property_developer"];
  let filter = "";
  if (search) {
    filter = " AND (b.name LIKE ? OR b.slug LIKE ?)";
    params.push(`%${search}%`, `%${search}%`);
  }
  const safeLimit = Math.min(500, Math.max(1, Number(limit) || 100));
  const rows = await query(
    `SELECT b.public_id, b.name, b.slug, b.logo_url, b.website_url, b.description,
            co.name AS country_name,
            (SELECT COUNT(*) FROM projects p WHERE p.developer_brand_id = b.id AND p.deleted_at IS NULL) AS project_count
       FROM brands b
       LEFT JOIN locations co ON co.id = b.country_id
      WHERE b.kind = ? AND b.deleted_at IS NULL${filter}
      ORDER BY b.name ASC LIMIT ${safeLimit}`,
    params
  );
  return rows.map((row) => ({
    id: row.public_id,
    name: row.name,
    slug: row.slug,
    logoUrl: row.logo_url,
    website: row.website_url,
    description: row.description,
    country: row.country_name,
    projectCount: int(row.project_count) ?? 0,
  }));
}

export async function getDeveloper(identifier) {
  const developers = await listDevelopers({ limit: 500 });
  return developers.find((developer) => developer.id === identifier || developer.slug === identifier) || null;
}

/* -------------------------------------------------------------------------- */
/* Companies, individuals and agents                                           */
/* -------------------------------------------------------------------------- */

export async function listAdminCompanies({ status = "all", search = "", category = "", country = "", page = 1, pageSize = 10 } = {}) {
  const conditions = ["o.deleted_at IS NULL"];
  const params = [];
  if (status !== "all") {
    conditions.push("o.status = ?");
    params.push(status);
  }
  if (search) {
    conditions.push("(o.name LIKE ? OR o.legal_name LIKE ? OR o.slug LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (country) {
    conditions.push("co.slug = ?");
    params.push(country);
  }
  const rootId = category ? rootIdFor(category) : null;
  const joins = [];
  if (rootId) {
    joins.push(`JOIN organization_category_access oca ON oca.organization_id = o.id AND oca.status = 'approved'
                JOIN categories occ ON occ.id = oca.category_id AND COALESCE(occ.root_category_id, occ.id) = ?`);
    params.unshift(rootId);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT o.id, o.public_id, o.name, o.legal_name, o.slug, o.kind, o.status,
              o.verification_status, o.email, o.phone, o.whatsapp, o.website_url,
              o.address_line1, o.logo_url, o.listing_count, o.active_listing_count,
              o.agent_count, o.created_at, o.updated_at,
              co.id AS country_id, co.name AS country_name,
              st.id AS state_id, st.name AS state_name,
              ct.id AS city_id, ct.name AS city_name,
              a.public_id AS account_public_id,
              (SELECT COUNT(*) FROM inquiries i WHERE i.organization_id = o.id AND i.deleted_at IS NULL) AS inquiry_count,
              (SELECT MAX(l.updated_at) FROM listings l WHERE l.organization_id = o.id) AS last_activity_at
         FROM organizations o
         ${joins.join("\n")}
         LEFT JOIN accounts a ON a.id = o.account_id
         LEFT JOIN locations co ON co.id = o.country_id
         LEFT JOIN locations st ON st.id = o.state_id
         LEFT JOIN locations ct ON ct.id = o.city_id
         ${where}
        GROUP BY o.id
        ORDER BY o.created_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(
      `SELECT COUNT(DISTINCT o.id) FROM organizations o ${joins.join("\n")}
         LEFT JOIN locations co ON co.id = o.country_id ${where}`,
      params
    ),
    queryOne(
      `SELECT COUNT(*) AS total, SUM(o.status = 'active') AS active, SUM(o.status = 'pending') AS pending,
              SUM(o.status = 'suspended') AS suspended,
              SUM(o.verification_status = 'pending') AS awaitingVerification,
              SUM(EXISTS (SELECT 1 FROM api_clients ac
                           WHERE ac.organization_id = o.id AND ac.revoked_at IS NULL
                             AND ac.status = 'active')) AS apiEnabled,
              SUM((SELECT COUNT(*) FROM organization_category_access oca
                    WHERE oca.organization_id = o.id AND oca.status = 'approved') > 1) AS multiCategory
         FROM organizations o WHERE o.deleted_at IS NULL`
    ),
  ]);

  const ids = rows.map((row) => row.id);
  const categoryAccess = ids.length
    ? await query(
        `SELECT oca.organization_id, COALESCE(c.root_category_id, c.id) AS root_category_id, oca.status
           FROM organization_category_access oca JOIN categories c ON c.id = oca.category_id
          WHERE oca.organization_id IN (${ids.map(() => "?").join(", ")})`,
        ids
      )
    : [];
  const accessByOrg = categoryAccess.reduce((map, row) => {
    const list = map.get(String(row.organization_id)) || [];
    list.push(row);
    map.set(String(row.organization_id), list);
    return map;
  }, new Map());

  return adminList({
    items: rows.map((row) => {
      const access = accessByOrg.get(String(row.id)) || [];
      return {
        id: row.public_id,
        organizationId: String(row.id),
        accountId: row.account_public_id,
        reference: `CMP-${String(row.id).padStart(5, "0")}`,
        businessName: row.name,
        legalName: row.legal_name,
        slug: row.slug,
        businessType: row.kind,
        type: "company",
        status: row.status,
        verificationStatus: row.verification_status,
        email: row.email,
        phone: row.phone,
        secondaryPhone: row.whatsapp,
        website: row.website_url,
        address: row.address_line1,
        logoUrl: row.logo_url,
        countryId: row.country_id ? String(row.country_id) : null,
        country: row.country_name,
        stateId: row.state_id ? String(row.state_id) : null,
        state: row.state_name,
        cityId: row.city_id ? String(row.city_id) : null,
        city: row.city_name,
        listings: int(row.active_listing_count) ?? 0,
        totalListings: int(row.listing_count) ?? 0,
        agents: int(row.agent_count) ?? 0,
        // The table columns read these two names. Supplied alongside the others rather than
        // renamed, because the detail screens read `listings`/`agents`.
        listingCount: int(row.listing_count) ?? 0,
        agentCount: int(row.agent_count) ?? 0,
        inquiries: int(row.inquiry_count) ?? 0,
        enabledCategories: categoryIdsFor(access.filter((entry) => entry.status === "approved").map((entry) => entry.root_category_id)),
        requestedCategories: categoryIdsFor(access.filter((entry) => entry.status === "requested").map((entry) => entry.root_category_id)),
        primaryCategory: categoryIdsFor(access.filter((entry) => entry.status === "approved").map((entry) => entry.root_category_id))[0] ?? null,
        dateAdded: isoDate(row.created_at),
        lastActivityAt: isoDate(row.last_activity_at || row.updated_at),
      };
    }),
    total,
    page: safePage,
    pageSize: safeSize,
    summary: {
      total: int(summary?.total) ?? 0,
      active: int(summary?.active) ?? 0,
      pending: int(summary?.pending) ?? 0,
      suspended: int(summary?.suspended) ?? 0,
      awaitingVerification: int(summary?.awaitingVerification) ?? 0,
      apiEnabled: int(summary?.apiEnabled) ?? 0,
      multiCategory: int(summary?.multiCategory) ?? 0,
    },
    options: await companyFilterOptions(),
  });
}

export async function getAdminCompany(identifier) {
  const list = await listAdminCompanies({ pageSize: 1, page: 1 });
  const row = await queryOne(
    `SELECT o.id FROM organizations o WHERE o.public_id = ? OR o.slug = ? LIMIT 1`,
    [identifier, identifier]
  );
  if (!row) return null;
  const result = await listAdminCompanies({ search: "", pageSize: 200 });
  const company = result.items.find((item) => item.organizationId === String(row.id));
  if (!company) return null;

  const [agents, listings, activity, subscription] = await Promise.all([
    query(
      `SELECT public_id, display_name, email, phone, status, created_at
         FROM agents WHERE organization_id = ? AND deleted_at IS NULL ORDER BY display_name`,
      [row.id]
    ),
    query(
      `SELECT public_id, reference, title, status, price, currency_code, cover_image_url, created_at
         FROM listings WHERE organization_id = ? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 50`,
      [row.id]
    ),
    query(
      `SELECT occurred_at, action, subject_type, subject_label FROM audit_logs
        WHERE subject_type = 'organization' AND subject_id = ? ORDER BY occurred_at DESC LIMIT 25`,
      [row.id]
    ),
    queryOne(
      `SELECT s.status, s.current_period_end, s.amount, s.currency_code, p.name AS plan_name, p.public_id AS plan_public_id
         FROM subscriptions s JOIN plans p ON p.id = s.plan_id
         JOIN organizations o ON o.account_id = s.account_id
        WHERE o.id = ? AND s.status IN ('trialing','active','past_due') ORDER BY s.id DESC LIMIT 1`,
      [row.id]
    ),
  ]);

  return {
    ...company,
    agentList: agents.map((agent) => ({
      id: agent.public_id,
      name: agent.display_name,
      email: agent.email,
      phone: agent.phone,
      status: agent.status,
      dateAdded: isoDate(agent.created_at),
    })),
    listingList: listings.map((listing) => ({
      id: listing.public_id,
      reference: listing.reference,
      title: listing.title,
      status: adminListingStatus(listing.status),
      price: listing.price ? `${listing.currency_code} ${Math.round(num(listing.price)).toLocaleString("en")}` : "On request",
      image: listing.cover_image_url,
      dateAdded: isoDate(listing.created_at),
    })),
    activity: activity.map((entry) => ({
      at: isoDate(entry.occurred_at),
      type: entry.action,
      detail: entry.subject_label,
    })),
    packageId: subscription?.plan_public_id ?? null,
    packageBilling: subscription
      ? {
          planName: subscription.plan_name,
          status: subscription.status,
          renewsOn: isoDay(subscription.current_period_end),
          amount: num(subscription.amount),
          currency: subscription.currency_code,
        }
      : null,
  };
}

export async function listAdminIndividuals({ status = "all", search = "", page = 1, pageSize = 10 } = {}) {
  // "Individuals" are personal/lister accounts: a user with an account that is
  // not backed by an organization.
  const conditions = ["u.deleted_at IS NULL", "a.deleted_at IS NULL", "at.requires_organization = 0"];
  const params = [];
  if (status !== "all") {
    conditions.push("a.status = ?");
    params.push(status);
  }
  if (search) {
    conditions.push("(u.display_name LIKE ? OR u.email LIKE ?)");
    params.push(`%${search}%`, `%${search}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT u.id, u.public_id, u.first_name, u.last_name, u.display_name, u.email, u.phone_e164,
              u.avatar_url, u.created_at, u.last_seen_at,
              a.id AS account_id, a.public_id AS account_public_id, a.status AS account_status,
              a.verification_status, at.code AS account_type_code,
              co.id AS country_id, co.name AS country_name,
              ct.id AS city_id, ct.name AS city_name,
              ag.public_id AS agent_public_id, ag.bio, ag.title,
              (SELECT COUNT(*) FROM listings l WHERE l.account_id = a.id AND l.deleted_at IS NULL) AS listing_count
         FROM users u
         JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
         JOIN accounts a ON a.id = am.account_id
         JOIN account_types at ON at.id = a.account_type_id
         LEFT JOIN locations co ON co.id = u.country_id
         LEFT JOIN locations ct ON ct.id = u.city_id
         LEFT JOIN agents ag ON ag.user_id = u.id AND ag.deleted_at IS NULL
         ${where}
        ORDER BY u.created_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(
      `SELECT COUNT(*) FROM users u
         JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
         JOIN accounts a ON a.id = am.account_id
         JOIN account_types at ON at.id = a.account_type_id ${where}`,
      params
    ),
    queryOne(
      `SELECT COUNT(*) AS total, SUM(a.status = 'active') AS active, SUM(a.status = 'pending') AS pending,
              COALESCE(SUM(a.listing_used), 0) AS totalListings,
              SUM(a.listing_used > 1) AS multiCategory
         FROM accounts a JOIN account_types at ON at.id = a.account_type_id
        WHERE at.requires_organization = 0 AND a.deleted_at IS NULL`
    ),
  ]);

  return adminList({
    items: rows.map((row) => ({
      id: row.public_id,
      userId: String(row.id),
      accountId: row.account_public_id,
      reference: `IND-${String(row.id).padStart(5, "0")}`,
      firstName: row.first_name,
      lastName: row.last_name,
      displayName: row.display_name,
      email: row.email,
      phone: row.phone_e164,
      secondaryPhone: null,
      avatar: row.avatar_url,
      profession: row.title,
      bio: row.bio,
      type: "individual",
      status: row.account_status,
      verificationStatus: row.verification_status,
      accountType: row.account_type_code,
      countryId: row.country_id ? String(row.country_id) : null,
      country: row.country_name,
      cityId: row.city_id ? String(row.city_id) : null,
      city: row.city_name,
      address: null,
      listings: int(row.listing_count) ?? 0,
      listingCount: int(row.listing_count) ?? 0,
      enabledCategories: row.account_type_code === "lister" ? ["realEstate"] : [],
      primaryCategory: row.account_type_code === "lister" ? "realEstate" : null,
      agentId: row.agent_public_id,
      dateAdded: isoDate(row.created_at),
      lastActivityAt: isoDate(row.last_seen_at || row.created_at),
    })),
    total,
    page: safePage,
    pageSize: safeSize,
    summary: {
      total: int(summary?.total) ?? 0,
      active: int(summary?.active) ?? 0,
      pending: int(summary?.pending) ?? 0,
      multiCategory: int(summary?.multiCategory) ?? 0,
      totalListings: int(summary?.totalListings) ?? 0,
    },
    options: await companyFilterOptions(),
  });
}

export async function getAdminIndividual(identifier) {
  const result = await listAdminIndividuals({ pageSize: 200 });
  return result.items.find((item) => item.id === identifier || item.userId === identifier) || null;
}

export async function listAdminAgents({ status = "all", search = "", organizationId = null, page = 1, pageSize = 10 } = {}) {
  const conditions = ["a.deleted_at IS NULL"];
  const params = [];
  if (status !== "all") {
    conditions.push("a.status = ?");
    params.push(status);
  }
  if (search) {
    conditions.push("(a.display_name LIKE ? OR a.email LIKE ? OR a.slug LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (organizationId) {
    conditions.push("o.public_id = ?");
    params.push(organizationId);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total] = await Promise.all([
    query(
      `SELECT a.id, a.public_id, a.first_name, a.last_name, a.display_name, a.slug, a.email,
              a.phone, a.title, a.status, a.verification_status, a.is_publicly_visible,
              a.active_listing_count, a.listing_count, a.created_at, a.updated_at, a.photo_url,
              o.public_id AS organization_public_id, o.name AS organization_name,
              u.public_id AS user_public_id
         FROM agents a
         LEFT JOIN organizations o ON o.id = a.organization_id
         LEFT JOIN users u ON u.id = a.user_id
         ${where}
        ORDER BY a.created_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM agents a LEFT JOIN organizations o ON o.id = a.organization_id ${where}`, params),
  ]);

  const ids = rows.map((row) => row.id);
  const specialties = ids.length
    ? await query(
        `SELECT asp.agent_id, COALESCE(c.root_category_id, c.id) AS root_category_id
           FROM agent_specialties asp JOIN categories c ON c.id = asp.category_id
          WHERE asp.agent_id IN (${ids.map(() => "?").join(", ")})`,
        ids
      )
    : [];
  const byAgent = specialties.reduce((map, row) => {
    const list = map.get(String(row.agent_id)) || [];
    list.push(row.root_category_id);
    map.set(String(row.agent_id), list);
    return map;
  }, new Map());

  return adminList({
    items: rows.map((row) => ({
      id: row.public_id,
      agentId: String(row.id),
      reference: `AGT-${String(row.id).padStart(5, "0")}`,
      firstName: row.first_name,
      lastName: row.last_name,
      displayName: row.display_name,
      slug: row.slug,
      email: row.email,
      phone: row.phone,
      role: row.title || "Agent",
      photo: row.photo_url,
      status: row.status,
      verificationStatus: row.verification_status,
      isPubliclyVisible: bool(row.is_publicly_visible),
      parentId: row.organization_public_id,
      parentType: row.organization_public_id ? "company" : "individual",
      parentName: row.organization_name,
      userId: row.user_public_id,
      listings: int(row.active_listing_count) ?? 0,
      totalListings: int(row.listing_count) ?? 0,
      listingCount: int(row.listing_count) ?? 0,
      agentCount: int(row.agent_count) ?? 0,
      enabledCategories: categoryIdsFor(byAgent.get(String(row.id)) || []),
      dateAdded: isoDate(row.created_at),
      lastActivityAt: isoDate(row.updated_at),
    })),
    total,
    page: safePage,
    pageSize: safeSize,
  });
}

export async function getAdminAgent(identifier) {
  const result = await listAdminAgents({ pageSize: 200 });
  const agent = result.items.find((item) => item.id === identifier || item.agentId === identifier);
  if (!agent) return null;
  const listings = await query(
    `SELECT public_id, reference, title, status, price, currency_code, cover_image_url, created_at
       FROM listings WHERE agent_id = ? AND deleted_at IS NULL ORDER BY created_at DESC LIMIT 50`,
    [agent.agentId]
  );
  return {
    ...agent,
    listingList: listings.map((row) => ({
      id: row.public_id,
      reference: row.reference,
      title: row.title,
      status: adminListingStatus(row.status),
      price: row.price ? `${row.currency_code} ${Math.round(num(row.price)).toLocaleString("en")}` : "On request",
      image: row.cover_image_url,
      dateAdded: isoDate(row.created_at),
    })),
  };
}

/* -------------------------------------------------------------------------- */
/* Locations and categories                                                    */
/* -------------------------------------------------------------------------- */

const LEVEL_BY_TIER = {
  country: "country",
  state: "state",
  city: "city",
  community: "community",
  subCommunity: "sub_community",
  "sub-community": "sub_community",
};

export async function listAdminLocations({ tier, parentId = null, search = "", status = "all", page = 1, pageSize = 20 } = {}) {
  const level = LEVEL_BY_TIER[tier];
  if (!level) throw AppError.badRequest("Unknown location tier.");

  const conditions = ["l.deleted_at IS NULL", "l.level = ?"];
  const params = [level];
  if (parentId) {
    const parent = await queryOne("SELECT id FROM locations WHERE public_id = ? OR id = ? LIMIT 1", [
      String(parentId),
      /^\d+$/.test(String(parentId)) ? Number(parentId) : 0,
    ]);
    if (parent) {
      conditions.push("l.parent_id = ?");
      params.push(parent.id);
    }
  }
  if (status !== "all") {
    conditions.push("l.status = ?");
    params.push(status);
  }
  if (search) {
    conditions.push("(l.name LIKE ? OR l.slug LIKE ?)");
    params.push(`%${search}%`, `%${search}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total] = await Promise.all([
    query(
      `SELECT l.id, l.public_id, l.name, l.slug, l.level, l.status, l.active_listing_count,
              l.listing_count, l.created_at, l.updated_at, l.latitude, l.longitude,
              l.country_id, l.state_id, l.city_id, l.community_id,
              co.name AS country_name, st.name AS state_name, ct.name AS city_name, cm.name AS community_name,
              (SELECT COUNT(*) FROM locations c WHERE c.parent_id = l.id AND c.deleted_at IS NULL) AS child_count
         FROM locations l
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations st ON st.id = l.state_id
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations cm ON cm.id = l.community_id
         ${where}
        ORDER BY l.active_listing_count DESC, l.name ASC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM locations l ${where}`, params),
  ]);

  return adminList({
    items: rows.map((row) => ({
      id: row.public_id,
      locationId: String(row.id),
      name: row.name,
      code: row.slug,
      slug: row.slug,
      level: row.level,
      status: row.status,
      countryId: row.country_id ? String(row.country_id) : null,
      country: row.country_name,
      stateId: row.state_id ? String(row.state_id) : null,
      state: row.state_name,
      cityId: row.city_id ? String(row.city_id) : null,
      city: row.city_name,
      communityId: row.community_id ? String(row.community_id) : null,
      community: row.community_name,
      latitude: num(row.latitude),
      longitude: num(row.longitude),
      listings: int(row.active_listing_count) ?? 0,
      childCount: int(row.child_count) ?? 0,
      dateAdded: isoDate(row.created_at),
      updatedAt: isoDate(row.updated_at),
    })),
    total,
    page: safePage,
    pageSize: safeSize,
    options: await locationFilterOptions(tier),
  });
}

export async function getAdminLocation(identifier) {
  const row = await queryOne(
    `SELECT l.id, l.public_id, l.name, l.slug, l.level, l.status, l.active_listing_count,
            l.created_at, l.updated_at, l.latitude, l.longitude, l.parent_id,
            l.country_id, l.state_id, l.city_id, l.community_id,
            co.name AS country_name, st.name AS state_name, ct.name AS city_name, cm.name AS community_name
       FROM locations l
       LEFT JOIN locations co ON co.id = l.country_id
       LEFT JOIN locations st ON st.id = l.state_id
       LEFT JOIN locations ct ON ct.id = l.city_id
       LEFT JOIN locations cm ON cm.id = l.community_id
      WHERE l.public_id = ? OR l.id = ? LIMIT 1`,
    [String(identifier), /^\d+$/.test(String(identifier)) ? Number(identifier) : 0]
  );
  if (!row) return null;
  return {
    id: row.public_id,
    locationId: String(row.id),
    name: row.name,
    code: row.slug,
    slug: row.slug,
    level: row.level,
    status: row.status,
    parentId: row.parent_id ? String(row.parent_id) : null,
    countryId: row.country_id ? String(row.country_id) : null,
    country: row.country_name,
    stateId: row.state_id ? String(row.state_id) : null,
    state: row.state_name,
    cityId: row.city_id ? String(row.city_id) : null,
    city: row.city_name,
    communityId: row.community_id ? String(row.community_id) : null,
    community: row.community_name,
    latitude: num(row.latitude),
    longitude: num(row.longitude),
    listings: int(row.active_listing_count) ?? 0,
    dateAdded: isoDate(row.created_at),
    updatedAt: isoDate(row.updated_at),
  };
}

/** Cascading select options: only the tiers that actually have children. */
export async function locationHierarchyOptions({ countryId = null, stateId = null, cityId = null, communityId = null } = {}) {
  const countries = await query(
    `SELECT public_id, id, name, slug FROM locations
      WHERE level = 'country' AND status = 'active' AND deleted_at IS NULL AND active_listing_count > 0
      ORDER BY active_listing_count DESC, name LIMIT 250`
  );
  const options = { countries: countries.map(toOption), states: [], cities: [], communities: [], subCommunities: [] };

  const resolveParent = async (value) =>
    value
      ? queryOne("SELECT id FROM locations WHERE public_id = ? OR id = ? LIMIT 1", [
          String(value),
          /^\d+$/.test(String(value)) ? Number(value) : 0,
        ])
      : null;

  const country = await resolveParent(countryId);
  if (country) {
    options.states = (
      await query(
        "SELECT public_id, id, name, slug FROM locations WHERE parent_id = ? AND level = 'state' AND deleted_at IS NULL ORDER BY name LIMIT 400",
        [country.id]
      )
    ).map(toOption);
  }
  const state = await resolveParent(stateId);
  if (state) {
    options.cities = (
      await query(
        "SELECT public_id, id, name, slug FROM locations WHERE parent_id = ? AND level = 'city' AND deleted_at IS NULL ORDER BY active_listing_count DESC, name LIMIT 400",
        [state.id]
      )
    ).map(toOption);
  }
  const city = await resolveParent(cityId);
  if (city) {
    options.communities = (
      await query(
        "SELECT public_id, id, name, slug FROM locations WHERE parent_id = ? AND level IN ('community','district') AND deleted_at IS NULL ORDER BY name LIMIT 400",
        [city.id]
      )
    ).map(toOption);
  }
  const community = await resolveParent(communityId);
  if (community) {
    options.subCommunities = (
      await query(
        "SELECT public_id, id, name, slug FROM locations WHERE parent_id = ? AND level = 'sub_community' AND deleted_at IS NULL ORDER BY name LIMIT 400",
        [community.id]
      )
    ).map(toOption);
  }
  return options;
}

function toOption(row) {
  return { id: row.public_id, value: String(row.id), label: row.name, slug: row.slug };
}

export async function listAdminCategories({ search = "", status = "all", parent = null, page = 1, pageSize = 50 } = {}) {
  const conditions = ["c.deleted_at IS NULL"];
  const params = [];
  if (status !== "all") {
    conditions.push("c.status = ?");
    params.push(status);
  }
  if (search) {
    conditions.push("(c.name LIKE ? OR c.slug LIKE ?)");
    params.push(`%${search}%`, `%${search}%`);
  }
  if (parent) {
    const rootId = rootIdFor(parent);
    if (rootId) {
      conditions.push("c.root_category_id = ? AND c.id <> c.root_category_id");
      params.push(rootId);
    }
  }
  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total] = await Promise.all([
    query(
      `SELECT c.id, c.public_id, c.name, c.name_plural, c.slug, c.code, c.description, c.status,
              c.sort_order, c.parent_id, c.root_category_id, c.listing_count, c.active_listing_count,
              c.created_at, c.updated_at, p.name AS parent_name
         FROM categories c LEFT JOIN categories p ON p.id = c.parent_id
         ${where} ORDER BY c.sort_order ASC, c.name ASC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM categories c ${where}`, params),
  ]);

  return adminList({
    items: rows.map((row) => ({
      id: row.public_id,
      categoryId: String(row.id),
      name: row.name,
      namePlural: row.name_plural,
      slug: row.slug,
      code: row.code,
      description: row.description,
      status: row.status,
      sortOrder: int(row.sort_order) ?? 0,
      parentId: row.parent_id ? String(row.parent_id) : null,
      parentName: row.parent_name,
      rootCategory: frontendCategoryId(row.root_category_id),
      listings: int(row.active_listing_count) ?? 0,
      totalListings: int(row.listing_count) ?? 0,
      dateAdded: isoDate(row.created_at),
      updatedAt: isoDate(row.updated_at),
    })),
    total,
    page: safePage,
    pageSize: safeSize,
  });
}

export async function getAdminCategory(identifier) {
  const result = await listAdminCategories({ pageSize: 200 });
  return result.items.find((item) => item.id === identifier || item.categoryId === identifier || item.slug === identifier) || null;
}

export async function listAdminPackages() {
  const rows = await query(
    `SELECT p.public_id, p.code, p.name, p.description, p.tier, p.billing_interval, p.trial_days,
            p.listing_quota, p.featured_quota, p.agent_seat_quota, p.lead_quota, p.is_active, p.is_public,
            pp.amount, pp.currency_code
       FROM plans p
       LEFT JOIN plan_prices pp ON pp.plan_id = p.id AND pp.is_active = 1
      ORDER BY p.sort_order ASC`
  );
  return rows.map((row) => ({
    id: row.public_id,
    code: row.code,
    name: row.name,
    subtitle: row.description,
    tier: row.tier,
    billingCycle: row.billing_interval,
    trialDays: int(row.trial_days) ?? 0,
    priceAnnual: num(row.amount),
    currency: row.currency_code || "AED",
    listingLimit: int(row.listing_quota),
    featuredListingsAllowance: int(row.featured_quota),
    agentLimit: int(row.agent_seat_quota),
    inquiriesLimit: int(row.lead_quota),
    categoryLimit: null,
    apiAccess: row.tier >= 4,
    apiCallsLimit: null,
    storageLimitGb: null,
    prioritySupport: row.tier >= 3,
    customDomains: row.tier >= 5,
    isActive: bool(row.is_active),
    isPublic: bool(row.is_public),
  }));
}

export async function listBusinessActivity({ organizationId = null, limit = 50 } = {}) {
  const params = [];
  let filter = "";
  if (organizationId) {
    const organization = await queryOne("SELECT id FROM organizations WHERE public_id = ?", [organizationId]);
    if (organization) {
      filter = "WHERE (a.subject_type = 'organization' AND a.subject_id = ?)";
      params.push(organization.id);
    }
  }
  const safeLimit = Math.min(200, Math.max(1, Number(limit) || 50));
  const rows = await query(
    `SELECT a.occurred_at, a.action, a.subject_type, a.subject_id, a.subject_label,
            a.actor_label, u.display_name AS actor_name
       FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_user_id
       ${filter}
      ORDER BY a.occurred_at DESC LIMIT ${safeLimit}`,
    params
  );
  return rows.map((row, index) => ({
    id: `ba_${index}_${new Date(row.occurred_at).getTime()}`,
    type: row.action,
    category: String(row.action).split(".")[0],
    title: String(row.action).replace(/[._]/g, " "),
    description: row.subject_label,
    detail: row.subject_label,
    actorName: row.actor_name || row.actor_label || "System",
    actorType: row.actor_name ? "user" : "system",
    at: isoDate(row.occurred_at),
    createdAt: isoDate(row.occurred_at),
  }));
}

export async function listOwnerListings({ ownerType, ownerId, page = 1, pageSize = 20 } = {}) {
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });
  const conditions = ["l.deleted_at IS NULL"];
  const params = [];
  if (ownerType === "company") {
    conditions.push("org.public_id = ?");
    params.push(ownerId);
  } else if (ownerType === "agent") {
    conditions.push("ag.public_id = ?");
    params.push(ownerId);
  } else {
    conditions.push("u.public_id = ?");
    params.push(ownerId);
  }
  const where = `WHERE ${conditions.join(" AND ")}`;
  const [rows, total] = await Promise.all([
    query(
      `SELECT l.id, l.public_id, l.reference, l.title, l.status, l.moderation_status, l.price,
              l.currency_code, l.cover_image_url, l.created_at, l.published_at, l.updated_at,
              l.view_count, l.inquiry_count, l.root_category_id, cat.name AS category_name,
              CONCAT_WS(', ', NULLIF(cm.name, ''), NULLIF(ct.name, ''), NULLIF(co.name, '')) AS location,
              COALESCE(org.name, u.display_name) AS owner, org.public_id AS organization_public_id,
              ag.display_name AS agent_name, br.name AS brand_name, bm.name AS model_name
         FROM listings l
         JOIN categories cat ON cat.id = l.category_id
         LEFT JOIN organizations org ON org.id = l.organization_id
         LEFT JOIN agents ag ON ag.id = l.agent_id
         LEFT JOIN users u ON u.id = l.created_by_user_id
         LEFT JOIN locations ct ON ct.id = l.city_id
         LEFT JOIN locations co ON co.id = l.country_id
         LEFT JOIN locations cm ON cm.id = l.community_id
         LEFT JOIN brands br ON br.id = l.brand_id
         LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
         ${where} ORDER BY l.created_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(
      `SELECT COUNT(*) FROM listings l
         LEFT JOIN organizations org ON org.id = l.organization_id
         LEFT JOIN agents ag ON ag.id = l.agent_id
         LEFT JOIN users u ON u.id = l.created_by_user_id ${where}`,
      params
    ),
  ]);
  return adminList({ items: rows.map(serializeAdminListingRow), total, page: safePage, pageSize: safeSize });
}
