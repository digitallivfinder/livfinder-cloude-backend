import { query, queryOne, int, isoDay } from "./admin.shared.js";
import { CATEGORY_DEFINITIONS } from "../../utils/categories.js";
import { sitemapEntries } from "../public/sitemap.repository.js";

/**
 * Admin SEO & Analytics.
 *
 * Only live sources are read here:
 *   - `listing_daily_stats` — one row per listing per day, written by every listing page view
 *     (engagement.routes `/listings/:id/view`) and every inquiry. Always joined to listings that
 *     still exist: deleted listings (test runs share the dev DB) would otherwise inflate totals;
 *   - `listing_search` + `listings` — exactly the listings the public site serves, so every
 *     SEO check below describes a page Google can actually crawl;
 *   - `sitemapEntries` — the same function `/sitemap.xml` is built from.
 *
 * The SEO-platform tables from migration 0017 (keyword_rankings, search_console_metrics,
 * core_web_vitals, backlinks, …) are seed data with no writer, so they are deliberately not read:
 * showing them would present invented rankings as measurements.
 */

export const SEO_PERIODS = Object.freeze({ "7d": 7, "30d": 30, "90d": 90 });

/** Search engines show roughly this much of a title / description before cutting it. */
export const TITLE_MAX = 60;
export const TITLE_MIN = 25;
export const DESCRIPTION_MIN = 70;
export const THIN_CONTENT_WORDS = 60;
export const MIN_PHOTOS = 3;
const SAMPLE_LIMIT = 50;

/** The sections `/sitemap.xml` links to — mirrors frontend `(website)/_lib/seo/sitemaps.js`. */
const SITEMAP_SECTIONS = [
  { key: "real-estate", label: "Real estate", sources: [["hubs", "real-estate"], ["properties"]] },
  { key: "projects", label: "Developments", sources: [["projects"]] },
  { key: "cars", label: "Cars", sources: [["hubs", "cars"], ["cars"]] },
  { key: "yachts", label: "Yachts", sources: [["hubs", "yachts"], ["yachts"]] },
  { key: "jets", label: "Private jets", sources: [["hubs", "jets"], ["jets"]] },
  { key: "helicopters", label: "Helicopters", sources: [["hubs", "helicopters"], ["helicopters"]] },
  { key: "watches", label: "Watches", sources: [["hubs", "watches"], ["watches"]] },
  { key: "blogs", label: "Magazine", sources: [["blogs"], ["blog-taxonomy"]] },
  { key: "companies", label: "Companies", sources: [["companies"]] },
  { key: "agents", label: "Agents", sources: [["agents"]] },
  { key: "static", label: "Site pages", sources: [["static"]] },
];

const ROOT_BY_ID = new Map(CATEGORY_DEFINITIONS.map((definition) => [definition.rootId, definition]));

const percentChange = (current, previous) => {
  if (!previous) return current ? 100 : 0;
  return Number((((current - previous) / previous) * 100).toFixed(1));
};

/** Same cleanup the public metadata does: no HTML, single spaces, no "| Liv Finder" suffix. */
export function plainText(value) {
  return String(value ?? "").replace(/<[^>]*>/g, " ").replace(/&nbsp;/gi, " ").replace(/\s+/g, " ").trim();
}
export function effectiveTitle(row) {
  return plainText(row.seo_title || row.title).replace(/\s*[|–—-]\s*Liv\s?Finder(\s+Magazine)?\s*$/i, "").trim();
}
export function effectiveDescription(row) {
  return plainText(row.seo_description) || plainText(row.description);
}

/**
 * The SEO checks, run over the public listings. Each returns the listings that fail it; the
 * rules are the ones search engines document (title and snippet length, unique titles, an image
 * for the result card) plus thin content and photo count, which decide whether a page ranks.
 */
export function seoChecks(rows) {
  const titleCounts = new Map();
  for (const row of rows) {
    const key = effectiveTitle(row).toLowerCase();
    if (key) titleCounts.set(key, (titleCounts.get(key) || 0) + 1);
  }
  const words = (text) => (text ? text.split(" ").length : 0);
  const checks = [
    {
      key: "duplicate-title",
      label: "Duplicate page title",
      severity: "high",
      help: "Several live listings share this title, so search engines cannot tell the pages apart. Make each title name what is unique about the listing.",
      test: (row) => (titleCounts.get(effectiveTitle(row).toLowerCase()) || 0) > 1,
      detail: (row) => `Shared by ${titleCounts.get(effectiveTitle(row).toLowerCase())} listings`,
    },
    {
      key: "missing-description",
      label: "Missing meta description",
      severity: "high",
      help: "No SEO description and no listing description, so the search result shows no summary.",
      test: (row) => !effectiveDescription(row),
      detail: () => "No description",
    },
    {
      key: "short-description",
      label: `Meta description under ${DESCRIPTION_MIN} characters`,
      severity: "medium",
      help: "Short snippets get rewritten by search engines. Aim for 120–160 characters that say why someone should click.",
      test: (row) => {
        const text = effectiveDescription(row);
        return Boolean(text) && text.length < DESCRIPTION_MIN;
      },
      detail: (row) => `${effectiveDescription(row).length} characters`,
    },
    {
      key: "long-title",
      label: `Title over ${TITLE_MAX} characters`,
      severity: "medium",
      help: "Search results cut the title off after about 60 characters, hiding the end of it.",
      test: (row) => effectiveTitle(row).length > TITLE_MAX,
      detail: (row) => `${effectiveTitle(row).length} characters`,
    },
    {
      key: "short-title",
      label: `Title under ${TITLE_MIN} characters`,
      severity: "low",
      help: "Very short titles leave out the location and type people search for.",
      test: (row) => {
        const title = effectiveTitle(row);
        return Boolean(title) && title.length < TITLE_MIN;
      },
      detail: (row) => `${effectiveTitle(row).length} characters`,
    },
    {
      key: "thin-content",
      label: `Listing text under ${THIN_CONTENT_WORDS} words`,
      severity: "medium",
      help: "Pages with very little text are treated as thin content and rank poorly.",
      test: (row) => words(plainText(row.description)) < THIN_CONTENT_WORDS,
      detail: (row) => `${words(plainText(row.description))} words`,
    },
    {
      key: "no-image",
      label: "No cover image",
      severity: "high",
      help: "Without an image the page has no social card and cannot appear in image search.",
      test: (row) => !row.cover_image_url,
      detail: () => "No image",
    },
    {
      key: "few-photos",
      label: `Fewer than ${MIN_PHOTOS} photos`,
      severity: "low",
      help: "Listings with only one or two photos get fewer clicks from search results.",
      test: (row) => Boolean(row.cover_image_url) && (int(row.image_count) ?? 0) < MIN_PHOTOS,
      detail: (row) => `${int(row.image_count) ?? 0} photo${int(row.image_count) === 1 ? "" : "s"}`,
    },
  ];

  const failingIds = new Set();
  const results = checks.map((check) => {
    const failing = rows.filter((row) => check.test(row));
    // Listings that share a title are listed side by side, so each group can be fixed together.
    if (check.key === "duplicate-title") failing.sort((a, b) => effectiveTitle(a).localeCompare(effectiveTitle(b)));
    failing.forEach((row) => failingIds.add(row.listing_id));
    return {
      key: check.key,
      label: check.label,
      severity: check.severity,
      help: check.help,
      count: failing.length,
      listings: failing.slice(0, SAMPLE_LIMIT).map((row) => ({ ...listingRef(row), detail: check.detail(row) })),
    };
  });
  return { checks: results, listingsWithIssues: failingIds.size };
}

function listingRef(row) {
  const definition = ROOT_BY_ID.get(int(row.root_category_id));
  return {
    id: row.public_id,
    reference: row.reference,
    title: effectiveTitle(row) || "Untitled listing",
    category: definition?.label ?? "Other",
    categorySlug: definition?.listingType ?? null,
    company: row.organization_name || null,
    publicPath: row.canonical_path || null,
  };
}

async function sitemapCoverage() {
  const sections = await Promise.all(
    SITEMAP_SECTIONS.map(async (section) => {
      const batches = await Promise.all(
        section.sources.map(([kind, category]) => sitemapEntries(kind, category ? { category } : {}).catch(() => []))
      );
      const urls = new Set(batches.flat().map((entry) => entry?.url).filter(Boolean));
      return { key: section.key, label: section.label, urls: urls.size };
    })
  );
  return { total: sections.reduce((sum, section) => sum + section.urls, 0), sections };
}

export async function seoAnalytics({ period = "30d" } = {}) {
  const safePeriod = SEO_PERIODS[period] ? period : "30d";
  // One of three integers from SEO_PERIODS, never request text: safe inside INTERVAL below.
  const days = SEO_PERIODS[safePeriod];

  const anchorRow = await queryOne("SELECT COALESCE(MAX(stat_date), CURDATE()) AS latest FROM listing_daily_stats");
  const latest = anchorRow?.latest ?? new Date();

  const [totals, trendRows, newListingRows, categoryRows, liveRows, topRows, healthRows, sitemap] = await Promise.all([
    queryOne(
      `SELECT COALESCE(SUM(CASE WHEN stat_date > DATE_SUB(?, INTERVAL ${days} DAY) THEN views END), 0) AS views,
              COALESCE(SUM(CASE WHEN stat_date > DATE_SUB(?, INTERVAL ${days} DAY) THEN inquiries END), 0) AS inquiries,
              COALESCE(SUM(CASE WHEN stat_date <= DATE_SUB(?, INTERVAL ${days} DAY) THEN views END), 0) AS previous_views,
              COALESCE(SUM(CASE WHEN stat_date <= DATE_SUB(?, INTERVAL ${days} DAY) THEN inquiries END), 0) AS previous_inquiries,
              COUNT(DISTINCT CASE WHEN stat_date > DATE_SUB(?, INTERVAL ${days} DAY) AND views > 0 THEN s.listing_id END) AS viewed_listings
         FROM listing_daily_stats s
         JOIN listings l ON l.id = s.listing_id AND l.deleted_at IS NULL
        WHERE stat_date > DATE_SUB(?, INTERVAL ${days * 2} DAY) AND stat_date <= ?`,
      [latest, latest, latest, latest, latest, latest, latest]
    ),
    query(
      `SELECT stat_date, SUM(views) AS views, SUM(inquiries) AS inquiries
         FROM listing_daily_stats s
         JOIN listings l ON l.id = s.listing_id AND l.deleted_at IS NULL
        WHERE stat_date > DATE_SUB(?, INTERVAL ${days} DAY) AND stat_date <= ?
        GROUP BY stat_date ORDER BY stat_date ASC`,
      [latest, latest]
    ),
    query(
      `SELECT DATE(published_at) AS day, COUNT(*) AS n
         FROM listings
        WHERE deleted_at IS NULL AND published_at > DATE_SUB(?, INTERVAL ${days} DAY) AND published_at < DATE_ADD(?, INTERVAL 1 DAY)
        GROUP BY DATE(published_at)`,
      [latest, latest]
    ),
    query(
      `SELECT c.root_category_id, SUM(s.views) AS views, SUM(s.inquiries) AS inquiries
         FROM listing_daily_stats s
         JOIN listings l ON l.id = s.listing_id AND l.deleted_at IS NULL
         JOIN categories c ON c.id = s.category_id
        WHERE s.stat_date > DATE_SUB(?, INTERVAL ${days} DAY) AND s.stat_date <= ?
        GROUP BY c.root_category_id`,
      [latest, latest]
    ),
    query("SELECT root_category_id, COUNT(*) AS live FROM listing_search GROUP BY root_category_id"),
    query(
      `SELECT l.public_id, l.reference, l.title, l.seo_title, l.root_category_id, l.canonical_path, l.status,
              o.name AS organization_name, SUM(s.views) AS views, SUM(s.inquiries) AS inquiries
         FROM listing_daily_stats s
         JOIN listings l ON l.id = s.listing_id AND l.deleted_at IS NULL
         LEFT JOIN organizations o ON o.id = l.organization_id
        WHERE s.stat_date > DATE_SUB(?, INTERVAL ${days} DAY) AND s.stat_date <= ?
        GROUP BY l.id
        HAVING views > 0
        ORDER BY views DESC, inquiries DESC
        LIMIT 10`,
      [latest, latest]
    ),
    query(
      `SELECT ls.listing_id, ls.public_id, ls.reference, ls.root_category_id, ls.canonical_path, ls.organization_name,
              ls.image_count, COALESCE(ls.cover_image_url, l.cover_image_url) AS cover_image_url,
              l.title, l.seo_title, l.seo_description, l.description
         FROM listing_search ls JOIN listings l ON l.id = ls.listing_id
        ORDER BY ls.published_at DESC
        LIMIT 20000`
    ),
    sitemapCoverage(),
  ]);

  const views = int(totals?.views) ?? 0;
  const inquiries = int(totals?.inquiries) ?? 0;
  const previousViews = int(totals?.previous_views) ?? 0;
  const previousInquiries = int(totals?.previous_inquiries) ?? 0;
  const rate = (a, b) => (b ? Number(((a / b) * 100).toFixed(2)) : 0);

  // A point for every day in the window, zero where nothing happened, so the line never skips.
  const byDay = new Map(trendRows.map((row) => [isoDay(row.stat_date), row]));
  const listingsByDay = new Map(newListingRows.map((row) => [isoDay(row.day), int(row.n) ?? 0]));
  const end = new Date(`${isoDay(latest)}T00:00:00Z`);
  const trend = Array.from({ length: days }, (_, index) => {
    const date = new Date(end);
    date.setUTCDate(end.getUTCDate() - (days - 1 - index));
    const key = date.toISOString().slice(0, 10);
    const row = byDay.get(key);
    return {
      date: key,
      views: int(row?.views) ?? 0,
      leads: int(row?.inquiries) ?? 0,
      listingsAdded: listingsByDay.get(key) ?? 0,
    };
  });

  const liveByRoot = new Map(liveRows.map((row) => [int(row.root_category_id), int(row.live) ?? 0]));
  const trafficByRoot = new Map(categoryRows.map((row) => [int(row.root_category_id), row]));
  const categories = CATEGORY_DEFINITIONS.filter((definition) => definition.rootId !== 7)
    .map((definition) => {
      const row = trafficByRoot.get(definition.rootId);
      const categoryViews = int(row?.views) ?? 0;
      const categoryInquiries = int(row?.inquiries) ?? 0;
      return {
        key: definition.listingType,
        label: definition.label,
        liveListings: liveByRoot.get(definition.rootId) ?? 0,
        views: categoryViews,
        inquiries: categoryInquiries,
        inquiryRate: rate(categoryInquiries, categoryViews),
        share: views ? Number(((categoryViews / views) * 100).toFixed(1)) : 0,
      };
    })
    .sort((a, b) => b.views - a.views);

  const health = seoChecks(healthRows);
  const liveListings = healthRows.length;

  return {
    period: safePeriod,
    periodDays: days,
    asOf: isoDay(latest),
    kpis: {
      views: { value: views, previous: previousViews, change: percentChange(views, previousViews) },
      inquiries: { value: inquiries, previous: previousInquiries, change: percentChange(inquiries, previousInquiries) },
      inquiryRate: {
        value: rate(inquiries, views),
        previous: rate(previousInquiries, previousViews),
        change: Number((rate(inquiries, views) - rate(previousInquiries, previousViews)).toFixed(2)),
      },
      viewedListings: int(totals?.viewed_listings) ?? 0,
      indexedPages: sitemap.total,
      liveListings,
      healthyListings: liveListings - health.listingsWithIssues,
    },
    trend,
    categories,
    topListings: topRows.map((row) => ({
      ...listingRef(row),
      status: row.status,
      views: int(row.views) ?? 0,
      inquiries: int(row.inquiries) ?? 0,
      inquiryRate: rate(int(row.inquiries) ?? 0, int(row.views) ?? 0),
    })),
    sitemap,
    health: {
      liveListings,
      listingsWithIssues: health.listingsWithIssues,
      score: liveListings ? Math.round(((liveListings - health.listingsWithIssues) / liveListings) * 100) : 100,
      checks: health.checks,
    },
  };
}

