import { query, queryOne, adminPagination, int, num, isoDate, frontendCategoryId } from "./admin.shared.js";
import { CATEGORY_DEFINITIONS } from "../../utils/categories.js";

/**
 * Admin dashboard.
 *
 * Every counter here is a COUNT over the rows the corresponding screen then
 * lists — the audit finding this schema was built to answer. Nothing is
 * hardcoded and nothing is approximated.
 */
export async function adminDashboard() {
  const [kpis, statusCounts, trend, inventory, categories, activity, inquiries] = await Promise.all([
    dashboardKpis(),
    listingStatusOverview(),
    listingTrendSeries(),
    recentInventory(),
    categoryBreakdown(),
    recentActivity(),
    inquiryBreakdown(),
  ]);

  return {
    kpis,
    // The Listings Overview chart plots a daily series, so this is an array of
    // { label, newListings, sold }. The status tallies keep their own key rather
    // than overloading this one.
    listingsOverview: trend,
    listingStatusCounts: statusCounts,
    listingInventory: inventory,
    // `listings` is what RecentListings reads; `listingInventory` stays so
    // nothing already reading it breaks.
    listings: inventory,
    listingSummary: categories,
    categories,
    activities: activity,
    inquiries,
    analytics: await analyticsSeries(),
  };
}

/**
 * Thirty days of new-versus-sold listings for the Listings Overview chart.
 *
 * The window is anchored to the most recent listing rather than to today: the
 * seeded catalogue was generated in the past, and anchoring on NOW() draws a
 * flat line through an empty month.
 */
async function listingTrendSeries(days = 30) {
  const anchorRow = await queryOne(
    "SELECT COALESCE(MAX(created_at), NOW(3)) AS anchor FROM listings WHERE deleted_at IS NULL"
  );
  const anchor = new Date(anchorRow?.anchor ?? Date.now());

  const [created, sold] = await Promise.all([
    query(
      `SELECT DATE(created_at) AS day, COUNT(*) AS n
         FROM listings
        WHERE deleted_at IS NULL AND created_at > DATE_SUB(?, INTERVAL ? DAY)
        GROUP BY DATE(created_at)`,
      [anchor, days]
    ),
    query(
      `SELECT DATE(sold_at) AS day, COUNT(*) AS n
         FROM listings
        WHERE deleted_at IS NULL AND sold_at IS NOT NULL AND sold_at > DATE_SUB(?, INTERVAL ? DAY)
        GROUP BY DATE(sold_at)`,
      [anchor, days]
    ),
  ]);

  const key = (value) => new Date(value).toISOString().slice(0, 10);
  const createdBy = new Map(created.map((row) => [key(row.day), int(row.n) ?? 0]));
  const soldBy = new Map(sold.map((row) => [key(row.day), int(row.n) ?? 0]));

  // Every day in the window is emitted, empty ones included — a chart that drops
  // gaps compresses time and misreports the trend.
  const series = [];
  for (let offset = days - 1; offset >= 0; offset -= 1) {
    const day = new Date(anchor);
    day.setDate(day.getDate() - offset);
    const stamp = key(day);
    series.push({
      date: stamp,
      // Formatted in UTC to match `stamp`; the default local zone shifts the
      // label a day away from the date it is labelling.
      label: day.toLocaleDateString("en", { day: "numeric", month: "short", timeZone: "UTC" }),
      newListings: createdBy.get(stamp) ?? 0,
      sold: soldBy.get(stamp) ?? 0,
    });
  }
  return series;
}

/** Inquiries by status, for the Inquiries Overview bars. */
async function inquiryBreakdown() {
  const row = await queryOne(
    `SELECT SUM(status = 'new') AS fresh,
            SUM(status = 'contacted') AS contacted,
            SUM(status = 'qualified') AS qualified,
            SUM(status IN ('won','closed')) AS won,
            SUM(status = 'lost') AS lost
       FROM inquiries WHERE deleted_at IS NULL AND is_spam = 0`
  );
  return [
    { label: "New", count: int(row?.fresh) ?? 0, color: "#3894df" },
    { label: "Contacted", count: int(row?.contacted) ?? 0, color: "#7c6cd4" },
    { label: "Qualified", count: int(row?.qualified) ?? 0, color: "#4caf79" },
    { label: "Won", count: int(row?.won) ?? 0, color: "#2f9e6d" },
    { label: "Lost", count: int(row?.lost) ?? 0, color: "#d1495b" },
  ];
}

async function dashboardKpis() {
  const [listings, organizations, agents, leads, users, revenue] = await Promise.all([
    queryOne(
      `SELECT COUNT(*) AS total,
              SUM(status = 'active') AS active,
              SUM(status = 'pending_review') AS pending,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL 30 DAY)) AS recent,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL 60 DAY) AND created_at < DATE_SUB(NOW(3), INTERVAL 30 DAY)) AS previous
         FROM listings WHERE deleted_at IS NULL`
    ),
    queryOne(
      `SELECT COUNT(*) AS total, SUM(verification_status = 'pending') AS pending
         FROM organizations WHERE deleted_at IS NULL`
    ),
    queryOne("SELECT COUNT(*) AS total FROM agents WHERE deleted_at IS NULL"),
    queryOne(
      `SELECT COUNT(*) AS total,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL 30 DAY)) AS recent,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL 60 DAY) AND created_at < DATE_SUB(NOW(3), INTERVAL 30 DAY)) AS previous
         FROM leads WHERE deleted_at IS NULL`
    ),
    queryOne("SELECT COUNT(*) AS total FROM users WHERE deleted_at IS NULL"),
    queryOne(
      `SELECT COALESCE(SUM(amount_base), 0) AS total
         FROM payments WHERE status = 'succeeded' AND paid_at >= DATE_SUB(NOW(3), INTERVAL 30 DAY)`
    ),
  ]);

  const trend = (recent, previous) => {
    const a = Number(recent || 0);
    const b = Number(previous || 0);
    if (!b) return a ? 100 : 0;
    return Number((((a - b) / b) * 100).toFixed(1));
  };

  return [
    {
      id: "listings",
      label: "Total listings",
      value: int(listings?.total) ?? 0,
      trend: trend(listings?.recent, listings?.previous),
      tone: "default",
      detail: `${int(listings?.active) ?? 0} active`,
    },
    {
      id: "pendingListings",
      label: "Pending review",
      value: int(listings?.pending) ?? 0,
      trend: null,
      tone: int(listings?.pending) > 0 ? "warning" : "default",
      detail: "Awaiting moderation",
    },
    {
      id: "companies",
      label: "Companies",
      value: int(organizations?.total) ?? 0,
      trend: null,
      tone: "default",
      detail: `${int(organizations?.pending) ?? 0} pending verification`,
    },
    { id: "agents", label: "Agents", value: int(agents?.total) ?? 0, trend: null, tone: "default", detail: null },
    {
      id: "leads",
      label: "Leads",
      value: int(leads?.total) ?? 0,
      trend: trend(leads?.recent, leads?.previous),
      tone: "default",
      detail: `${int(leads?.recent) ?? 0} in the last 30 days`,
    },
    { id: "users", label: "Users", value: int(users?.total) ?? 0, trend: null, tone: "default", detail: null },
    {
      id: "revenue",
      label: "Revenue (30d)",
      value: Math.round(num(revenue?.total) ?? 0),
      trend: null,
      tone: "positive",
      detail: "AED, settled payments",
    },
  ];
}

async function listingStatusOverview() {
  const row = await queryOne(
    `SELECT COUNT(*) AS total,
            SUM(status = 'active') AS approved,
            SUM(status = 'pending_review') AS pending,
            SUM(status = 'rejected') AS rejected,
            SUM(status IN ('sold','rented')) AS sold,
            SUM(status IN ('archived','withdrawn')) AS archived,
            SUM(published_at >= DATE_SUB(NOW(3), INTERVAL 7 DAY)) AS newListings
       FROM listings WHERE deleted_at IS NULL`
  );
  return {
    all: int(row?.total) ?? 0,
    approved: int(row?.approved) ?? 0,
    pending: int(row?.pending) ?? 0,
    rejected: int(row?.rejected) ?? 0,
    sold: int(row?.sold) ?? 0,
    archived: int(row?.archived) ?? 0,
    newListings: int(row?.newListings) ?? 0,
  };
}

async function recentInventory() {
  const rows = await query(
    `SELECT l.public_id, l.reference, l.title, l.status, l.price, l.currency_code,
            COALESCE(
              l.cover_image_url,
              (SELECT lm.url FROM listing_media lm
                 WHERE lm.listing_id = l.id AND lm.media_type = 'image'
                 ORDER BY lm.is_cover DESC, lm.sort_order ASC, lm.id ASC LIMIT 1),
              (SELECT lm.url FROM listing_media lm JOIN media_assets ma ON ma.id = lm.media_asset_id
                 WHERE lm.listing_id = l.id AND ma.media_type = 'image'
                 ORDER BY lm.sort_order ASC, lm.id ASC LIMIT 1)
            ) AS cover_image_url,
            l.created_at, l.root_category_id,
            cat.name AS category_name,
            CONCAT_WS(', ', NULLIF(cm.name, ''), NULLIF(ct.name, ''), NULLIF(co.name, '')) AS location,
            COALESCE(org.name, u.display_name) AS owner,
            re.bedrooms, re.bathrooms,
            veh.model_year, veh.mileage_km,
            mar.build_year, mar.length_overall_ft,
            av.year_built, av.passenger_capacity, av.range_nm, av.total_time_hours, av.aircraft_type,
            tp.reference_number, tp.year_of_production,
            br.name AS brand_name, bm.name AS model_name
       FROM listings l
       JOIN categories cat ON cat.id = l.category_id
       LEFT JOIN locations ct ON ct.id = l.city_id
       LEFT JOIN locations co ON co.id = l.country_id
       LEFT JOIN locations cm ON cm.id = l.community_id
       LEFT JOIN organizations org ON org.id = l.organization_id
       LEFT JOIN users u ON u.id = l.created_by_user_id
       LEFT JOIN brands br ON br.id = l.brand_id
       LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
       LEFT JOIN listing_real_estate re ON re.listing_id = l.id
       LEFT JOIN listing_vehicle veh ON veh.listing_id = l.id
       LEFT JOIN listing_marine mar ON mar.listing_id = l.id
       LEFT JOIN listing_aviation av ON av.listing_id = l.id
       LEFT JOIN listing_timepiece tp ON tp.listing_id = l.id
      WHERE l.deleted_at IS NULL
      ORDER BY l.created_at DESC
      LIMIT 40`
  );

  return rows.map((row) => {
    const categoryId = frontendCategoryId(row.root_category_id);
    const base = {
      id: row.public_id,
      reference: row.reference,
      categoryId: categoryDashboardSlug(row.root_category_id),
      title: row.title,
      status: adminListingStatus(row.status),
      price: row.price ? `${row.currency_code} ${Math.round(num(row.price)).toLocaleString("en")}` : "On request",
      image: row.cover_image_url,
      location: row.location,
      owner: row.owner,
      ownerInitials: initialsOf(row.owner),
      dateAdded: isoDate(row.created_at),
      propertyType: row.category_name,
    };
    if (categoryId === "realEstate") return { ...base, beds: int(row.bedrooms), baths: int(row.bathrooms) };
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
  });
}

function categoryDashboardSlug(rootCategoryId) {
  return CATEGORY_DEFINITIONS.find((definition) => definition.rootId === Number(rootCategoryId))?.listingType ?? null;
}

export function adminListingStatus(status) {
  if (status === "active") return "approved";
  if (status === "pending_review") return "pending";
  if (status === "withdrawn") return "archived";
  return status;
}

export function initialsOf(name) {
  return String(name || "")
    .split(" ")
    .filter(Boolean)
    .map((part) => part[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

async function categoryBreakdown() {
  const rows = await query(
    `SELECT c.id, c.code, c.slug, c.name, c.name_plural,
            COUNT(l.id) AS total,
            SUM(l.status = 'active') AS approved,
            SUM(l.status = 'pending_review') AS pending,
            SUM(l.status = 'rejected') AS rejected,
            SUM(l.status IN ('sold','rented')) AS sold,
            SUM(l.status IN ('archived','withdrawn')) AS archived
       FROM categories c
       LEFT JOIN listings l ON l.root_category_id = c.id AND l.deleted_at IS NULL
      WHERE c.parent_id IS NULL
      GROUP BY c.id
      ORDER BY c.sort_order ASC`
  );
  return rows.map((row, index) => ({
    id: row.code,
    categoryId: row.code,
    label: row.name_plural || row.name,
    slug: row.slug,
    all: int(row.total) ?? 0,
    total: int(row.total) ?? 0,
    // `count` and `color` are what the Listings by Category donut reads. The
    // palette is positional and stable because the query orders by sort_order.
    count: int(row.total) ?? 0,
    color: CATEGORY_COLORS[index % CATEGORY_COLORS.length],
    approved: int(row.approved) ?? 0,
    pending: int(row.pending) ?? 0,
    rejected: int(row.rejected) ?? 0,
    sold: int(row.sold) ?? 0,
    archived: int(row.archived) ?? 0,
  }));
}

const CATEGORY_COLORS = ["#3894df", "#7c6cd4", "#4caf79", "#e0a33e", "#d1495b", "#2aa3a3", "#a4649c"];

async function recentActivity() {
  const rows = await query(
    `SELECT a.occurred_at, a.action, a.subject_type, a.subject_id, a.subject_label,
            a.actor_label, u.display_name AS actor_name
       FROM audit_logs a
       LEFT JOIN users u ON u.id = a.actor_user_id
      ORDER BY a.occurred_at DESC
      LIMIT 20`
  );
  return rows.map((row, index) => ({
    id: `act_${index}_${new Date(row.occurred_at).getTime()}`,
    type: row.action,
    title: humaniseAction(row.action),
    detail: row.subject_label || `${row.subject_type} #${row.subject_id ?? ""}`.trim(),
    actorName: row.actor_name || row.actor_label || "System",
    actorType: row.actor_name ? "user" : "system",
    at: isoDate(row.occurred_at),
    createdAt: isoDate(row.occurred_at),
  }));
}

function humaniseAction(action) {
  return String(action)
    .replace(/[._]/g, " ")
    .replace(/\b\w/g, (character) => character.toUpperCase());
}

async function analyticsSeries() {
  const rows = await query(
    `SELECT stat_date, SUM(page_views) AS views, SUM(inquiries) AS inquiries, SUM(new_listings) AS listings
       FROM platform_daily_stats
      WHERE stat_date >= DATE_SUB((SELECT MAX(stat_date) FROM platform_daily_stats), INTERVAL 29 DAY)
      GROUP BY stat_date ORDER BY stat_date ASC`
  ).catch(() => []);

  const points = rows.map((row) => ({
    date: row.stat_date,
    views: int(row.views) ?? 0,
    inquiries: int(row.inquiries) ?? 0,
    listings: int(row.listings) ?? 0,
  }));

  /**
   * AnalyticsGrid renders each card's sparkline into a 0..45 viewBox and plots
   * `45 - value`, so the series has to arrive pre-scaled to that band rather
   * than as raw counts — raw page views would draw far outside the box.
   */
  const spark = (key) => {
    const values = points.map((point) => point[key]);
    const max = Math.max(...values, 1);
    return values.map((value) => Number(((value / max) * 40).toFixed(2)));
  };

  const card = (id, label, key, format = (value) => value.toLocaleString("en")) => {
    const values = points.map((point) => point[key]);
    const total = values.reduce((sum, value) => sum + value, 0);
    // Trend compares the two halves of the window against each other.
    const half = Math.floor(values.length / 2);
    const previous = values.slice(0, half).reduce((sum, value) => sum + value, 0);
    const recent = values.slice(half).reduce((sum, value) => sum + value, 0);
    const trend = previous ? Number((((recent - previous) / previous) * 100).toFixed(1)) : recent ? 100 : 0;
    return { id, label, value: format(total), trend, points: spark(key) };
  };

  return [
    card("views", "Page views", "views"),
    card("inquiries", "Inquiries", "inquiries"),
    card("listings", "New listings", "listings"),
  ];
}

/** Per-category admin dashboard (the `/admin/listings/:category/dashboard` screens). */

/** The three windows the category Dashboard's period control offers. */
const DASHBOARD_PERIOD_DAYS = { "7d": 7, "30d": 30, "90d": 90 };

/** Donut slice colours, in the order the breakdown returns them. */
const BREAKDOWN_COLORS = ["#2563eb", "#7c3aed", "#16a34a", "#f59e0b", "#dc2626", "#0891b2", "#db2777", "#65a30d"];

const percentChange = (current, previous) => {
  const now = Number(current) || 0;
  const before = Number(previous) || 0;
  if (before === 0) return now === 0 ? 0 : 100;
  return Math.round(((now - before) / before) * 100);
};

export async function categoryDashboard(categorySlug, { period = "30d" } = {}) {
  const definition = CATEGORY_DEFINITIONS.find((entry) => entry.listingType === categorySlug || entry.dbCode === categorySlug);
  if (!definition) return null;

  // `days` is only ever one of three integers from DASHBOARD_PERIOD_DAYS, never request text,
  // which is why it is safe to interpolate into the INTERVAL expressions below (MySQL will not
  // take a placeholder there).
  const safePeriod = DASHBOARD_PERIOD_DAYS[period] ? period : "30d";
  const days = DASHBOARD_PERIOD_DAYS[safePeriod];
  const root = definition.rootId;

  const [totals, leads, statusRows, breakdownRows, topListings, trend, viewTotals, activity] = await Promise.all([
    queryOne(
      `SELECT COUNT(*) AS total,
              SUM(status = 'active') AS active,
              SUM(status = 'pending_review') AS pending,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS added,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL ${days * 2} DAY)
                  AND created_at < DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS added_previous,
              SUM(status = 'active' AND created_at >= DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS active_added,
              SUM(status = 'active' AND created_at >= DATE_SUB(NOW(3), INTERVAL ${days * 2} DAY)
                  AND created_at < DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS active_added_previous,
              SUM(status = 'pending_review' AND created_at >= DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS pending_added,
              SUM(status = 'pending_review' AND created_at >= DATE_SUB(NOW(3), INTERVAL ${days * 2} DAY)
                  AND created_at < DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS pending_added_previous,
              COALESCE(SUM(view_count), 0) AS views
         FROM listings WHERE root_category_id = ? AND deleted_at IS NULL`,
      [root]
    ),
    queryOne(
      `SELECT COUNT(*) AS total,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS recent,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL ${days * 2} DAY)
                  AND created_at < DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS recent_previous,
              SUM(status = 'new') AS available
         FROM leads WHERE root_category_id = ? AND deleted_at IS NULL`,
      [root]
    ),
    query(
      `SELECT status, COUNT(*) AS total FROM listings
        WHERE root_category_id = ? AND deleted_at IS NULL
        GROUP BY status ORDER BY total DESC`,
      [root]
    ),
    // The breakdown dimension is the listing's own sub-category — "Motor Yacht", "Villa",
    // "Chronograph" — which is what every category's breakdown title actually names.
    query(
      `SELECT c.name, COUNT(*) AS total
         FROM listings l JOIN categories c ON c.id = l.category_id
        WHERE l.root_category_id = ? AND l.deleted_at IS NULL AND l.status = 'active'
        GROUP BY c.id ORDER BY total DESC LIMIT 8`,
      [root]
    ),
    query(
      `SELECT l.public_id, l.reference, l.title, l.view_count, l.inquiry_count,
              COALESCE(
                l.cover_image_url,
                (SELECT lm.url FROM listing_media lm
                   WHERE lm.listing_id = l.id AND lm.media_type = 'image'
                   ORDER BY lm.is_cover DESC, lm.sort_order ASC, lm.id ASC LIMIT 1),
                (SELECT lm.url FROM listing_media lm JOIN media_assets ma ON ma.id = lm.media_asset_id
                   WHERE lm.listing_id = l.id AND ma.media_type = 'image'
                   ORDER BY lm.sort_order ASC, lm.id ASC LIMIT 1)
              ) AS cover_image_url,
              l.price, l.currency_code, l.status
         FROM listings l
        WHERE l.root_category_id = ? AND l.deleted_at IS NULL AND l.status = 'active'
        ORDER BY l.view_count DESC LIMIT 5`,
      [root]
    ),
    query(
      `SELECT s.stat_date, SUM(s.views) AS views, SUM(s.inquiries) AS inquiries
         FROM listing_daily_stats s
        WHERE s.category_id IN (SELECT id FROM categories WHERE root_category_id = ?)
          AND s.stat_date >= DATE_SUB((SELECT MAX(stat_date) FROM listing_daily_stats), INTERVAL ${days - 1} DAY)
        GROUP BY s.stat_date ORDER BY s.stat_date ASC`,
      [root]
    ).catch(() => []),
    queryOne(
      `SELECT COALESCE(SUM(s.views), 0) AS current_views,
              COALESCE(SUM(CASE WHEN s.stat_date < DATE_SUB(m.latest, INTERVAL ${days - 1} DAY)
                                THEN s.views ELSE 0 END), 0) AS previous_views
         FROM listing_daily_stats s
         JOIN (SELECT MAX(stat_date) AS latest FROM listing_daily_stats) m
        WHERE s.category_id IN (SELECT id FROM categories WHERE root_category_id = ?)
          AND s.stat_date >= DATE_SUB(m.latest, INTERVAL ${days * 2 - 1} DAY)`,
      [root]
    ).catch(() => null),
    query(
      `SELECT l.public_id AS id, l.title, h.to_status, h.changed_at
         FROM listing_status_history h JOIN listings l ON l.id = h.listing_id
        WHERE l.root_category_id = ? AND l.deleted_at IS NULL
        ORDER BY h.changed_at DESC LIMIT 8`,
      [root]
    ).catch(() => []),
  ]);

  const currentViews = Number(viewTotals?.current_views ?? 0);
  const previousViews = Number(viewTotals?.previous_views ?? 0);

  // Listings added and leads received are keyed by date so the trend chart can carry all three
  // series on the same x-axis as the daily views/inquiries the stats table already holds.
  const [addedByDay, leadsByDay] = await Promise.all([
    query(
      `SELECT DATE(created_at) AS stat_date, COUNT(*) AS total FROM listings
        WHERE root_category_id = ? AND deleted_at IS NULL
          AND created_at >= DATE_SUB(NOW(3), INTERVAL ${days} DAY)
        GROUP BY DATE(created_at)`,
      [root]
    ),
    query(
      `SELECT DATE(created_at) AS stat_date, COUNT(*) AS total FROM leads
        WHERE root_category_id = ? AND deleted_at IS NULL
          AND created_at >= DATE_SUB(NOW(3), INTERVAL ${days} DAY)
        GROUP BY DATE(created_at)`,
      [root]
    ),
  ]);
  // mysql2 hands a DATE column back as a JS Date, so normalise before keying/labelling.
  const dayKey = (value) => (value instanceof Date ? value.toISOString() : String(value)).slice(0, 10);
  const addedMap = new Map(addedByDay.map((row) => [dayKey(row.stat_date), int(row.total) ?? 0]));
  const leadsMap = new Map(leadsByDay.map((row) => [dayKey(row.stat_date), int(row.total) ?? 0]));
  const dayLabel = (value) =>
    new Date(`${dayKey(value)}T00:00:00Z`).toLocaleDateString("en-GB", { day: "2-digit", month: "short", timeZone: "UTC" });

  const breakdownTotal = breakdownRows.reduce((sum, row) => sum + (int(row.total) ?? 0), 0);

  return {
    categoryId: definition.listingType,
    slug: definition.listingType,
    label: definition.label,
    period: safePeriod,
    periodDays: days,
    summary: {
      totalListings: int(totals?.total) ?? 0,
      activeListings: int(totals?.active) ?? 0,
      pendingListings: int(totals?.pending) ?? 0,
      listingsAdded: int(totals?.added) ?? 0,
      totalViews: int(totals?.views) ?? 0,
      leads: int(leads?.total) ?? 0,
      newLeads: int(leads?.recent) ?? 0,
      leadsAvailable: int(leads?.available) ?? 0,
    },
    // Percentage change of this window against the window immediately before it.
    trends: {
      totalListings: percentChange(totals?.added, totals?.added_previous),
      activeListings: percentChange(totals?.active_added, totals?.active_added_previous),
      pendingListings: percentChange(totals?.pending_added, totals?.pending_added_previous),
      newLeads: percentChange(leads?.recent, leads?.recent_previous),
      totalViews: percentChange(currentViews, previousViews),
    },
    listingStatus: Object.fromEntries(statusRows.map((row) => [row.status, int(row.total) ?? 0])),
    breakdown: breakdownRows.map((row, index) => ({
      name: row.name,
      value: int(row.total) ?? 0,
      color: BREAKDOWN_COLORS[index % BREAKDOWN_COLORS.length],
    })),
    breakdownTotal,
    topListings: topListings.map((row) => ({
      id: row.public_id,
      reference: row.reference,
      title: row.title,
      views: int(row.view_count) ?? 0,
      leads: int(row.inquiry_count) ?? 0,
      inquiries: int(row.inquiry_count) ?? 0,
      image: row.cover_image_url,
      status: row.status === "active" ? "published" : row.status === "pending_review" ? "pending" : row.status,
      price: row.price ? `${row.currency_code} ${Math.round(num(row.price)).toLocaleString("en")}` : "On request",
    })),
    recentActivity: activity.map((row, index) => ({
      id: `${row.id}-${index}`,
      title: `${row.title} — ${String(row.to_status || "").replaceAll("_", " ")}`,
      timestamp: isoDate(row.changed_at),
    })),
    performanceTrend: trend.map((row) => ({
      date: dayKey(row.stat_date),
      label: dayLabel(row.stat_date),
      views: int(row.views) ?? 0,
      inquiries: int(row.inquiries) ?? 0,
      listingsAdded: addedMap.get(dayKey(row.stat_date)) ?? 0,
      leads: leadsMap.get(dayKey(row.stat_date)) ?? 0,
    })),
    // Three real superlatives from the same window, in the order the frontend labels them.
    insights: [
      topListings[0] ? { key: "topPerformer", value: topListings[0].title } : null,
      [...topListings].sort((a, b) => (b.inquiry_count ?? 0) - (a.inquiry_count ?? 0))[0]
        ? { key: "highestInterest", value: [...topListings].sort((a, b) => (b.inquiry_count ?? 0) - (a.inquiry_count ?? 0))[0].title }
        : null,
      breakdownRows[0] ? { key: "bestPerformer", value: breakdownRows[0].name } : null,
    ].filter(Boolean),
  };
}


/**
 * The Real Estate Developments dashboard reads `projects`, not `listings` — developments are a
 * distinct inventory concept, so it cannot share categoryDashboard's listing queries. It returns
 * the identical view-model shape so the same CategoryDashboardView renders it.
 */
export async function developmentsDashboard({ period = "30d" } = {}) {
  const safePeriod = DASHBOARD_PERIOD_DAYS[period] ? period : "30d";
  const days = DASHBOARD_PERIOD_DAYS[safePeriod];

  const [totals, leads, statusRows, breakdownRows, topProjects, activity] = await Promise.all([
    queryOne(
      `SELECT COUNT(*) AS total,
              SUM(is_publicly_visible = 1 AND status NOT IN ('cancelled','on_hold')) AS active,
              SUM(is_publicly_visible = 0) AS pending,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS added,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL ${days * 2} DAY)
                  AND created_at < DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS added_previous,
              COALESCE(SUM(listing_count), 0) AS listing_total,
              COALESCE(SUM(total_units), 0) AS units,
              COALESCE(SUM(available_units), 0) AS available
         FROM projects WHERE deleted_at IS NULL`
    ),
    queryOne(
      `SELECT COUNT(*) AS total,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS recent,
              SUM(created_at >= DATE_SUB(NOW(3), INTERVAL ${days * 2} DAY)
                  AND created_at < DATE_SUB(NOW(3), INTERVAL ${days} DAY)) AS recent_previous
         FROM leads WHERE project_id IS NOT NULL AND deleted_at IS NULL`
    ).catch(() => null),
    query("SELECT status, COUNT(*) AS total FROM projects WHERE deleted_at IS NULL GROUP BY status ORDER BY total DESC"),
    // Every project sits under the same Real Estate category, so grouping by category would
    // produce one slice. The developer is the dimension that actually varies.
    query(
      `SELECT COALESCE(b.name, 'Independent') AS name, COUNT(*) AS total
         FROM projects p LEFT JOIN brands b ON b.id = p.developer_brand_id
        WHERE p.deleted_at IS NULL GROUP BY b.id ORDER BY total DESC LIMIT 8`
    ),
    query(
      `SELECT p.public_id, p.slug, p.name, p.status, p.listing_count, p.min_price, p.currency_code,
              p.cover_image_url, p.total_units, p.available_units
         FROM projects p WHERE p.deleted_at IS NULL
        ORDER BY p.listing_count DESC, p.total_units DESC LIMIT 5`
    ),
    query(
      `SELECT public_id AS id, name, status, updated_at FROM projects
        WHERE deleted_at IS NULL ORDER BY updated_at DESC LIMIT 8`
    ),
  ]);

  const addedByDay = await query(
    `SELECT DATE(created_at) AS stat_date, COUNT(*) AS total FROM projects
      WHERE deleted_at IS NULL AND created_at >= DATE_SUB(NOW(3), INTERVAL ${days} DAY)
      GROUP BY DATE(created_at) ORDER BY stat_date ASC`
  );
  // mysql2 hands a DATE column back as a JS Date, so normalise before keying/labelling.
  const dayKey = (value) => (value instanceof Date ? value.toISOString() : String(value)).slice(0, 10);
  const dayLabel = (value) =>
    new Date(`${dayKey(value)}T00:00:00Z`).toLocaleDateString("en-GB", { day: "2-digit", month: "short", timeZone: "UTC" });

  return {
    categoryId: "real-estate-developments",
    slug: "real-estate-developments",
    label: "Real Estate Developments",
    period: safePeriod,
    periodDays: days,
    summary: {
      totalListings: int(totals?.total) ?? 0,
      activeListings: int(totals?.active) ?? 0,
      pendingListings: int(totals?.pending) ?? 0,
      listingsAdded: int(totals?.added) ?? 0,
      // A development has no view counter of its own; its reach is the inventory it publishes.
      totalViews: int(totals?.listing_total) ?? 0,
      leads: int(leads?.total) ?? 0,
      newLeads: int(leads?.recent) ?? 0,
      leadsAvailable: int(totals?.available) ?? 0,
    },
    trends: {
      totalListings: percentChange(totals?.added, totals?.added_previous),
      activeListings: percentChange(totals?.added, totals?.added_previous),
      pendingListings: 0,
      newLeads: percentChange(leads?.recent, leads?.recent_previous),
      totalViews: 0,
    },
    listingStatus: Object.fromEntries(statusRows.map((row) => [row.status, int(row.total) ?? 0])),
    breakdown: breakdownRows.map((row, index) => ({
      name: row.name,
      value: int(row.total) ?? 0,
      color: BREAKDOWN_COLORS[index % BREAKDOWN_COLORS.length],
    })),
    topListings: topProjects.map((row) => ({
      id: row.public_id,
      reference: row.slug,
      title: row.name,
      views: int(row.total_units) ?? 0,
      leads: int(row.listing_count) ?? 0,
      image: row.cover_image_url,
      status: row.status,
      price: row.min_price ? `${row.currency_code} ${Math.round(num(row.min_price)).toLocaleString("en")}` : "On request",
    })),
    recentActivity: activity.map((row, index) => ({
      id: `${row.id}-${index}`,
      title: `${row.name} — ${String(row.status || "").replaceAll("_", " ")}`,
      timestamp: isoDate(row.updated_at),
    })),
    performanceTrend: addedByDay.map((row) => ({
      date: dayKey(row.stat_date),
      label: dayLabel(row.stat_date),
      listingsAdded: int(row.total) ?? 0,
      leads: 0,
      views: 0,
      inquiries: 0,
    })),
    insights: [
      topProjects[0] ? { key: "topPerformer", value: topProjects[0].name } : null,
      breakdownRows[0] ? { key: "highestInterest", value: breakdownRows[0].name } : null,
      statusRows[0] ? { key: "bestPerformer", value: String(statusRows[0].status).replaceAll("_", " ") } : null,
    ].filter(Boolean),
  };
}
