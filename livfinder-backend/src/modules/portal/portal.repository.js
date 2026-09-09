import { query, queryOne, queryValue } from "../../db/query.js";
import { bool, int, isoDate, isoDay, num } from "../../serializers/primitives.js";
import { frontendCategoryId, categoryByRootId } from "../../utils/categories.js";

/**
 * Portal read model.
 *
 * Every projection here matches the shape the portal components already read
 * (`price.formatted`, `image.src`, `specs[]`, `metrics`, `statusLabel`), so the
 * switch from fixtures to live data needed no component changes.
 *
 * Every query is scoped by account_id. There is no portal read that is not.
 */
const STATUS_LABELS = {
  draft: "Draft",
  pending_review: "Pending",
  active: "Active",
  rejected: "Rejected",
  expired: "Expired",
  sold: "Sold",
  rented: "Rented",
  withdrawn: "Withdrawn",
  archived: "Archived",
};

// The portal's tab vocabulary differs from the database's status enum.
const TAB_TO_STATUSES = {
  all: null,
  active: ["active"],
  pending: ["pending_review"],
  soldOrRented: ["sold", "rented"],
  expired: ["expired"],
  draft: ["draft"],
  archived: ["archived", "withdrawn"],
  rejected: ["rejected"],
};

function formatMoney({ amount, currency }) {
  if (amount === null || amount === undefined) return null;
  try {
    return new Intl.NumberFormat("en", {
      style: "currency",
      currency: currency || "AED",
      maximumFractionDigits: 0,
    }).format(Number(amount));
  } catch {
    return `${currency || "AED"} ${Number(amount).toLocaleString("en")}`;
  }
}

function specsFor(row) {
  const definition = categoryByRootId(row.root_category_id);
  const listingType = definition?.listingType;
  const specs = [];
  const push = (id, label, value, icon) => {
    if (value === null || value === undefined || value === "") return;
    specs.push({ id, label, value: String(value), icon });
  };

  if (listingType === "real-estate") {
    push("beds", "Beds", row.bedrooms, "bed");
    push("baths", "Baths", row.bathrooms, "bath");
    push("area", "Area", row.built_area_sqft ? `${Math.round(num(row.built_area_sqft)).toLocaleString("en")} sqft` : null, "area");
    push("type", "Type", row.category_name, "home");
  } else if (listingType === "cars") {
    push("year", "Year", row.model_year, "calendar");
    push("gearbox", "Transmission", row.transmission ? titleize(row.transmission) : null, "settings");
    push("fuel", "Fuel", row.fuel_type ? titleize(row.fuel_type) : null, "fuel");
    push("mileage", "Mileage", row.mileage_km ? `${int(row.mileage_km).toLocaleString("en")} km` : null, "gauge");
  } else if (listingType === "yachts") {
    push("year", "Year", row.build_year, "calendar");
    push("length", "Length", row.length_overall_ft ? `${Math.round(num(row.length_overall_ft))} ft` : null, "ruler");
    push("cabins", "Cabins", row.cabins ? `${int(row.cabins)} Cabins` : null, "bed");
    push("guests", "Guests", row.guests_sleeping ? `${int(row.guests_sleeping)} Guests` : null, "users");
  } else if (listingType === "jets" || listingType === "helicopters") {
    push("year", "Year", row.year_built, "calendar");
    push("seats", "Seats", row.passenger_capacity ? `${int(row.passenger_capacity)} Seats` : null, "users");
    push("range", "Range", row.range_nm ? `${int(row.range_nm).toLocaleString("en")} nm` : null, "gauge");
    push("hours", "Hours", row.total_time_hours ? `${int(row.total_time_hours).toLocaleString("en")} hrs` : null, "clock");
  } else if (listingType === "watches") {
    push("year", "Year", row.year_of_production, "calendar");
    push("size", "Size", row.case_diameter_mm ? `${num(row.case_diameter_mm)}mm` : null, "ruler");
    push("material", "Material", row.case_material ? titleize(row.case_material) : null, "sparkles");
    push("movement", "Movement", row.movement_type ? titleize(row.movement_type) : null, "settings");
  }
  return specs;
}

function titleize(value) {
  return String(value).replace(/[_-]+/g, " ").replace(/\b\w/g, (character) => character.toUpperCase());
}

export function serializePortalListing(row) {
  const definition = categoryByRootId(row.root_category_id);
  const amount = num(row.price);
  const currency = row.currency_code || "AED";
  const dateSource = row.status === "expired" ? row.expires_at : row.created_at;
  return {
    id: row.public_id,
    listingId: String(row.id),
    reference: row.reference,
    title: row.title,
    categoryId: definition?.frontendId ?? null,
    category: definition?.frontendId ?? null,
    listingType: definition?.listingType ?? null,
    categoryLabel: definition ? categoryLabel(definition.listingType) : "Other",
    status: portalStatus(row.status),
    rawStatus: row.status,
    statusLabel: STATUS_LABELS[row.status] || row.status,
    moderationStatus: row.moderation_status,
    amount,
    currency,
    price: { amount, currency, formatted: formatMoney({ amount, currency }) },
    locationLabel: [row.sub_community_name, row.community_name, row.city_name, row.country_name].filter(Boolean).join(", "),
    imageSrc: row.cover_image_url || null,
    image: { src: row.cover_image_url || "/images/realestate-bg.jpeg", alt: row.cover_image_alt || row.title },
    imageCount: int(row.image_count) ?? 0,
    specs: specsFor(row),
    views: int(row.view_count) ?? 0,
    inquiries: int(row.inquiry_count) ?? 0,
    favourites: int(row.favourite_count) ?? 0,
    metrics: { views: int(row.view_count) ?? 0, inquiries: int(row.inquiry_count) ?? 0, favourites: int(row.favourite_count) ?? 0 },
    createdAt: isoDate(row.created_at),
    updatedAt: isoDate(row.updated_at),
    publishedAt: isoDate(row.published_at),
    expiresAt: isoDate(row.expires_at),
    dateLabel: dateSource
      ? `${row.status === "expired" ? "Expired" : "Added"} on ${new Intl.DateTimeFormat("en", {
          month: "short",
          day: "numeric",
          year: "numeric",
          timeZone: "UTC",
        }).format(new Date(dateSource))}`
      : null,
    publicUrl: row.status === "active" ? row.canonical_path : null,
    editUrl: `/portal/listings/${row.public_id}/edit`,
    availableActions: availableActions(row),
    agentName: row.agent_name || null,
    agentId: row.agent_public_id || null,
  };
}

function portalStatus(status) {
  if (status === "pending_review") return "pending";
  if (status === "withdrawn") return "archived";
  return status;
}

function availableActions(row) {
  const actions = [];
  if (row.status === "active") actions.push("view", "edit", "markSold", "withdraw");
  else if (row.status === "draft") actions.push("edit", "submit", "delete");
  else if (row.status === "pending_review") actions.push("edit", "withdraw");
  else if (row.status === "rejected") actions.push("edit", "resubmit");
  else if (row.status === "expired") actions.push("edit", "renew");
  else actions.push("view");
  return actions;
}

function categoryLabel(listingType) {
  return {
    "real-estate": "Real Estate",
    cars: "Cars",
    yachts: "Yachts",
    jets: "Private Jets",
    helicopters: "Helicopters",
    watches: "Watches",
  }[listingType] || "Other";
}

const PORTAL_LISTING_COLUMNS = `
  l.id, l.public_id, l.reference, l.title, l.slug, l.canonical_path, l.status, l.moderation_status,
  l.root_category_id, l.category_id, l.price, l.currency_code, l.cover_image_url, l.cover_image_alt,
  l.image_count, l.view_count, l.inquiry_count, l.favourite_count,
  l.created_at, l.updated_at, l.published_at, l.expires_at,
  cat.name AS category_name,
  ct.name AS city_name, co.name AS country_name, cm.name AS community_name, sc.name AS sub_community_name,
  ag.display_name AS agent_name, ag.public_id AS agent_public_id,
  re.bedrooms, re.bathrooms, re.built_area_sqft,
  veh.model_year, veh.transmission, veh.fuel_type, veh.mileage_km,
  mar.build_year, mar.length_overall_ft, mar.cabins, mar.guests_sleeping,
  av.year_built, av.passenger_capacity, av.range_nm, av.total_time_hours,
  tp.year_of_production, tp.case_diameter_mm, tp.case_material, tp.movement_type`;

const PORTAL_LISTING_JOINS = `
  JOIN categories cat ON cat.id = l.category_id
  LEFT JOIN locations ct ON ct.id = l.city_id
  LEFT JOIN locations co ON co.id = l.country_id
  LEFT JOIN locations cm ON cm.id = l.community_id
  LEFT JOIN locations sc ON sc.id = l.sub_community_id
  LEFT JOIN agents ag ON ag.id = l.agent_id
  LEFT JOIN listing_real_estate re ON re.listing_id = l.id
  LEFT JOIN listing_vehicle veh ON veh.listing_id = l.id
  LEFT JOIN listing_marine mar ON mar.listing_id = l.id
  LEFT JOIN listing_aviation av ON av.listing_id = l.id
  LEFT JOIN listing_timepiece tp ON tp.listing_id = l.id`;

export async function listAccountListings({
  accountId,
  status = "all",
  category = "all",
  search = "",
  sort = "newest",
  page = 1,
  pageSize = 10,
  agentId = null,
}) {
  const conditions = ["l.account_id = ?", "l.deleted_at IS NULL"];
  const params = [accountId];

  const statuses = TAB_TO_STATUSES[status];
  if (statuses) {
    conditions.push(`l.status IN (${statuses.map(() => "?").join(", ")})`);
    params.push(...statuses);
  }
  if (category && category !== "all") {
    const rootId = rootIdForFrontendCategory(category);
    if (rootId) {
      conditions.push("l.root_category_id = ?");
      params.push(rootId);
    } else {
      /**
       * A category the catalogue does not know matches nothing.
       *
       * This used to add no condition at all, so an unrecognised slug returned the account's
       * entire inventory as though no category had been asked for. The portal ships a
       * `real-estate-developments` category whose slug no listing category answers to, so its
       * page listed the owner's ordinary apartments and villas under "Developments" — wrong
       * records, presented as the thing they are not. An empty result is the honest answer.
       */
      conditions.push("1 = 0");
    }
  }
  if (agentId) {
    conditions.push("l.agent_id = ?");
    params.push(agentId);
  }
  const term = String(search || "").trim();
  if (term) {
    conditions.push("(l.title LIKE ? OR l.reference LIKE ? OR l.public_id = ?)");
    params.push(`%${term}%`, `%${term}%`, term);
  }

  const orderBy =
    {
      newest: "l.created_at DESC, l.id DESC",
      oldest: "l.created_at ASC, l.id ASC",
      priceDesc: "l.price IS NULL, l.price DESC",
      priceAsc: "l.price IS NULL, l.price ASC",
      views: "l.view_count DESC",
      inquiries: "l.inquiry_count DESC",
      updated: "l.updated_at DESC",
    }[sort] || "l.created_at DESC, l.id DESC";

  const safePage = Math.max(1, Number(page) || 1);
  const safeSize = Math.min(100, Math.max(1, Number(pageSize) || 10));
  const offset = (safePage - 1) * safeSize;
  const where = `WHERE ${conditions.join(" AND ")}`;

  const [rows, total, counts] = await Promise.all([
    query(
      `SELECT ${PORTAL_LISTING_COLUMNS} FROM listings l ${PORTAL_LISTING_JOINS} ${where}
        ORDER BY ${orderBy} LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM listings l ${where}`, params),
    // The counters read the same rows the tabs then show, from the view that
    // exists for exactly this reason.
    queryOne(
      `SELECT total, active, pending, drafts, sold_rented, expired, rejected
         FROM v_account_listing_counts WHERE account_id = ?`,
      [accountId]
    ),
  ]);

  const overview = {
    all: int(counts?.total) ?? 0,
    active: int(counts?.active) ?? 0,
    pending: int(counts?.pending) ?? 0,
    soldOrRented: int(counts?.sold_rented) ?? 0,
    expired: int(counts?.expired) ?? 0,
    draft: int(counts?.drafts) ?? 0,
    rejected: int(counts?.rejected) ?? 0,
  };

  return {
    data: rows.map(serializePortalListing),
    total: Number(total || 0),
    page: safePage,
    pageSize: safeSize,
    counts: overview,
    overview,
  };
}

export function rootIdForFrontendCategory(value) {
  const map = { realEstate: 1, car: 2, yacht: 3, jet: 4, helicopter: 5, watch: 6 };
  if (map[value]) return map[value];
  const byType = { "real-estate": 1, cars: 2, yachts: 3, jets: 4, helicopters: 5, watches: 6 };
  return byType[value] || null;
}

export async function getAccountListing({ accountId, identifier }) {
  return queryOne(
    `SELECT ${PORTAL_LISTING_COLUMNS} FROM listings l ${PORTAL_LISTING_JOINS}
      WHERE l.account_id = ? AND l.deleted_at IS NULL
        AND (l.public_id = ? OR l.reference = ?)
      LIMIT 1`,
    [accountId, String(identifier), String(identifier)]
  );
}

/* -------------------------------------------------------------------------- */
/* Dashboard                                                                   */
/* -------------------------------------------------------------------------- */

export async function accountDashboard({ accountId, organizationId }) {
  const [counts, totals, recentListings, recentInquiries, series] = await Promise.all([
    queryOne(
      `SELECT total, active, pending, drafts, sold_rented, expired, rejected
         FROM v_account_listing_counts WHERE account_id = ?`,
      [accountId]
    ),
    queryOne(
      `SELECT COALESCE(SUM(view_count), 0) AS views,
              COALESCE(SUM(inquiry_count), 0) AS inquiries,
              COALESCE(SUM(favourite_count), 0) AS favourites
         FROM listings WHERE account_id = ? AND deleted_at IS NULL`,
      [accountId]
    ),
    query(
      `SELECT ${PORTAL_LISTING_COLUMNS} FROM listings l ${PORTAL_LISTING_JOINS}
        WHERE l.account_id = ? AND l.deleted_at IS NULL
        ORDER BY l.updated_at DESC LIMIT 3`,
      [accountId]
    ),
    query(
      `SELECT i.public_id, i.name, i.message, i.status, i.created_at,
              l.title AS listing_title, l.cover_image_url
         FROM inquiries i
         LEFT JOIN listings l ON l.id = i.listing_id
        WHERE (i.account_id = ? OR i.organization_id <=> ?) AND i.deleted_at IS NULL AND i.is_spam = 0
        ORDER BY i.created_at DESC LIMIT 4`,
      [accountId, organizationId ?? null]
    ),
    // Read from the daily rollup, never from the raw event stream.
    performanceSeries(accountId),
  ]);

  const performance = buildPerformanceSeries(series);

  return {
    summary: {
      activeListings: { value: int(counts?.active) ?? 0, change: null, comparisonLabel: "this month" },
      totalViews: { value: int(totals?.views) ?? 0, change: null, comparisonLabel: null },
      newInquiries: { value: int(totals?.inquiries) ?? 0, change: null, comparisonLabel: "this week" },
      totalFavourites: { value: int(totals?.favourites) ?? 0, change: null, comparisonLabel: null },
    },
    performance,
    listingsOverview: {
      total: int(counts?.total) ?? 0,
      active: int(counts?.active) ?? 0,
      pending: int(counts?.pending) ?? 0,
      soldOrRented: int(counts?.sold_rented) ?? 0,
      expired: int(counts?.expired) ?? 0,
      draft: int(counts?.drafts) ?? 0,
    },
    recentInquiries: recentInquiries.map((row) => ({
      id: row.public_id,
      name: row.name,
      listingTitle: row.listing_title,
      message: row.message,
      relativeTime: relativeTime(row.created_at),
      status: row.status,
      avatar: row.cover_image_url || null,
    })),
    recentListings: recentListings.map(serializePortalListing),
  };
}

const PERFORMANCE_BUCKETS = 8;
const PERFORMANCE_BUCKET_DAYS = 4;

/**
 * Eight four-day buckets of views and inquiries.
 *
 * The window is anchored to the most recent day the rollup actually has for
 * this account rather than to today: a chart that silently reads zero because
 * the nightly job has not run yet is worse than one that shows the last real
 * period.
 */
async function performanceSeries(accountId) {
  const anchor = await queryValue(
    `SELECT MAX(d.stat_date) FROM listing_daily_stats d
       JOIN listings l ON l.id = d.listing_id
      WHERE l.account_id = ?`,
    [accountId]
  );
  if (!anchor) return { rows: [], anchor: null };
  const span = PERFORMANCE_BUCKETS * PERFORMANCE_BUCKET_DAYS;
  const rows = await query(
    `SELECT FLOOR(DATEDIFF(?, d.stat_date) / ?) AS bucket,
            COALESCE(SUM(d.views), 0) AS views,
            COALESCE(SUM(d.inquiries), 0) AS inquiries
       FROM listing_daily_stats d
       JOIN listings l ON l.id = d.listing_id
      WHERE l.account_id = ?
        AND d.stat_date <= ?
        AND d.stat_date > DATE_SUB(?, INTERVAL ? DAY)
      GROUP BY bucket`,
    [anchor, PERFORMANCE_BUCKET_DAYS, accountId, anchor, anchor, span]
  );
  return { rows, anchor };
}

function buildPerformanceSeries({ rows = [], anchor = null } = {}) {
  const labels = [];
  const views = [];
  const inquiries = [];
  const byBucket = new Map(rows.map((row) => [Number(row.bucket), row]));
  // mysql2 hands back a Date for a DATE column; a string arrives when the
  // driver is configured for date strings. Both have to work.
  const anchorDate = anchor
    ? new Date(`${(anchor instanceof Date ? anchor.toISOString() : String(anchor)).slice(0, 10)}T00:00:00Z`)
    : new Date();
  for (let index = PERFORMANCE_BUCKETS - 1; index >= 0; index -= 1) {
    const date = new Date(anchorDate.getTime() - index * PERFORMANCE_BUCKET_DAYS * 24 * 60 * 60 * 1000);
    labels.push(new Intl.DateTimeFormat("en", { month: "short", day: "numeric", timeZone: "UTC" }).format(date));
    const row = byBucket.get(index);
    views.push(int(row?.views) ?? 0);
    inquiries.push(int(row?.inquiries) ?? 0);
  }
  return { labels, views, inquiries };
}

export function relativeTime(value) {
  if (!value) return null;
  const delta = Date.now() - new Date(value).getTime();
  const minutes = Math.round(delta / 60000);
  if (minutes < 1) return "just now";
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  if (days === 1) return "Yesterday";
  if (days < 30) return `${days}d ago`;
  return new Intl.DateTimeFormat("en", { month: "short", day: "numeric", year: "numeric", timeZone: "UTC" }).format(new Date(value));
}

export { PORTAL_LISTING_COLUMNS, PORTAL_LISTING_JOINS, formatMoney, STATUS_LABELS, titleize, categoryLabel };
