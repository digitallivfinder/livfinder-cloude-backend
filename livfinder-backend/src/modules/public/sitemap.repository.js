import { query } from "../../db/query.js";

/**
 * The sitemap is built from the visibility view, not from a fixture list, so a
 * URL cannot reach sitemap.xml unless the page behind it actually renders.
 */
const STATIC_PATHS = [
  { url: "/", priority: 1, changeFrequency: "daily" },
  { url: "/real-estate", priority: 0.8, changeFrequency: "daily" },
  { url: "/projects", priority: 0.8, changeFrequency: "daily" },
  { url: "/cars", priority: 0.8, changeFrequency: "daily" },
  { url: "/jets", priority: 0.8, changeFrequency: "daily" },
  { url: "/yachts", priority: 0.8, changeFrequency: "daily" },
  { url: "/helicopters", priority: 0.8, changeFrequency: "daily" },
  { url: "/watches", priority: 0.8, changeFrequency: "daily" },
  { url: "/blogs", priority: 0.7, changeFrequency: "daily" },
  { url: "/countries", priority: 0.7, changeFrequency: "weekly" },
  // The directory's one URL; `/agencies` permanently redirects here.
  { url: "/companies", priority: 0.7, changeFrequency: "weekly" },
  { url: "/agents", priority: 0.7, changeFrequency: "weekly" },
  { url: "/contact-us", priority: 0.4, changeFrequency: "monthly" },
  { url: "/sitemap", priority: 0.3, changeFrequency: "weekly" },
];

const KIND_TO_ROOT = { properties: 1, "real-estate": 1, cars: 2, yachts: 3, jets: 4, helicopters: 5, watches: 6 };

/**
 * A `lastmod` date, or nothing. An unknown date used to read as today, which tells crawlers every
 * page changed on every visit — they learn to ignore the field, so it is left out instead.
 */
function iso(value) {
  if (!value) return undefined;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date.toISOString().slice(0, 10);
}

/** A browse page with fewer live listings than this is thin: noindex, and out of the sitemap. */
export const THIN_HUB_MIN_LISTINGS = 3;
/** The most URLs one sitemap file holds (the protocol's limit is 50,000; smaller is quicker). */
export const SITEMAP_PAGE_SIZE = 10000;
const LEGACY_LIMIT = 50000;
const MAX_IMAGES = 5;

function paging({ page, pageSize } = {}) {
  const size = Math.min(LEGACY_LIMIT, Math.max(1, Number(pageSize) || LEGACY_LIMIT));
  const number = Math.max(1, Math.floor(Number(page) || 1));
  return { limit: size, offset: (number - 1) * size };
}

/** A cover image for image sitemaps, only when the row actually has one. */
function images(url, title) {
  return url ? [{ url, title: title || undefined }] : undefined;
}

/** Every live listing's path and date: the source of a category's browse pages. */
async function livePathRows(rootCategoryId) {
  return query(
    `SELECT ls.canonical_path, ls.source_updated_at
       FROM listing_search ls
      WHERE ls.root_category_id = ?`,
    [rootCategoryId]
  );
}

/**
 * One page of a category's listing URLs: live listings first, then the sold, rented and withdrawn
 * ones whose page still works (v_reachable_listings, 0062 — the owner's rule of 2026-10-29: they
 * keep their URL and stay in the sitemap so the page keeps its ranking). Ordered by id so a page
 * holds the same listings from one request to the next.
 */
async function listingPageRows(rootCategoryId, options) {
  const { limit, offset } = paging(options);
  return query(
    `SELECT u.id, u.canonical_path, u.title, u.cover_image_url, u.updated
       FROM (
         SELECT ls.listing_id AS id, ls.canonical_path, ls.title, ls.cover_image_url, ls.source_updated_at AS updated, 0 AS closed
           FROM listing_search ls
          WHERE ls.root_category_id = ?
         UNION ALL
         SELECT l.id, l.canonical_path, l.title, l.cover_image_url, l.updated_at AS updated, 1 AS closed
           FROM v_reachable_listings l
          WHERE l.status IN ('sold', 'rented', 'withdrawn') AND l.canonical_path IS NOT NULL AND l.root_category_id = ?
       ) u
      ORDER BY u.closed, u.id DESC
      LIMIT ${limit} OFFSET ${offset}`,
    [rootCategoryId, rootCategoryId]
  );
}

/** Up to five public photos per listing, cover first, for the image sitemap. */
async function listingPhotos(ids) {
  if (!ids.length) return new Map();
  const rows = await query(
    `SELECT listing_id, url, alt_text
       FROM listing_media
      WHERE listing_id IN (${ids.map(() => "?").join(",")}) AND media_type = 'image' AND is_public = 1
      ORDER BY listing_id, is_cover DESC, sort_order, id`,
    ids
  );
  const byListing = new Map();
  for (const row of rows) {
    const list = byListing.get(String(row.listing_id)) || [];
    if (list.length < MAX_IMAGES) list.push({ url: row.url, title: row.alt_text || undefined });
    byListing.set(String(row.listing_id), list);
  }
  return byListing;
}

async function listingEntries(rootCategoryId, options) {
  const rows = await listingPageRows(rootCategoryId, options);
  const photos = await listingPhotos(rows.map((row) => row.id));
  return rows.map((row) => {
    const gallery = photos.get(String(row.id)) || [];
    return {
      url: row.canonical_path,
      title: row.title,
      lastModified: iso(row.updated),
      images: gallery.length ? gallery.map((image) => ({ ...image, title: image.title || row.title || undefined })) : images(row.cover_image_url, row.title),
    };
  });
}

/** How many URLs each paged section holds, so the sitemap index knows how many files to list. */
async function sectionCounts() {
  const [live, closed, projects] = await Promise.all([
    query("SELECT root_category_id, COUNT(*) AS total FROM listing_search GROUP BY root_category_id", []),
    query(
      `SELECT root_category_id, COUNT(*) AS total FROM v_reachable_listings
        WHERE status IN ('sold', 'rented', 'withdrawn') AND canonical_path IS NOT NULL GROUP BY root_category_id`,
      []
    ),
    query("SELECT COUNT(*) AS total FROM project_search", []),
  ]);
  const byRoot = {};
  for (const row of [...live, ...closed]) byRoot[row.root_category_id] = (byRoot[row.root_category_id] || 0) + Number(row.total);
  const counts = { projects: Number(projects[0]?.total || 0) };
  for (const [kind, rootId] of Object.entries(KIND_TO_ROOT)) if (kind !== "real-estate") counts[kind] = byRoot[rootId] || 0;
  return { ...counts, pageSize: SITEMAP_PAGE_SIZE };
}

/**
 * The browse pages of one category: every location (real estate) or make/model/year (assets)
 * that holds at least one public listing.
 *
 * They are read off the listings' own canonical paths — every proper prefix of a canonical path
 * below the category root is a hierarchy page that resolves and lists that listing — so a hub
 * cannot be listed unless it has something on it, and an empty city never reaches the sitemap.
 */
export async function hubEntries(kind, { minListings = THIN_HUB_MIN_LISTINGS } = {}) {
  const rootId = KIND_TO_ROOT[kind];
  if (!rootId) return [];
  return hubsFromPaths(await livePathRows(rootId)).filter((hub) => hub.listingCount >= minListings);
}

/**
 * The location pages above a set of canonical paths. segments[0] is the root (already in the
 * static sitemap); the last segment is the listing or project itself.
 */
function hubsFromPaths(rows) {
  const hubs = new Map();
  for (const row of rows) {
    const segments = String(row.canonical_path || "").split("/").filter(Boolean);
    for (let depth = 2; depth < segments.length; depth += 1) {
      const url = `/${segments.slice(0, depth).join("/")}`;
      const lastModified = iso(row.source_updated_at);
      const hub = hubs.get(url);
      if (!hub) hubs.set(url, { url, depth, count: 1, lastModified });
      else {
        hub.count += 1;
        if (lastModified > hub.lastModified) hub.lastModified = lastModified;
      }
    }
  }
  return [...hubs.values()]
    .sort((a, b) => a.depth - b.depth || b.count - a.count || a.url.localeCompare(b.url))
    .map(({ url, depth, count, lastModified }) => ({
      url,
      lastModified,
      changeFrequency: "daily",
      priority: Math.max(0.5, 0.8 - (depth - 2) * 0.05),
      listingCount: count,
    }));
}

/**
 * The magazine's archive pages: categories, topics, tags and destinations that hold a post,
 * plus active authors who have written one. An empty archive is a thin page and stays out.
 */
async function blogTaxonomyEntries() {
  const [terms, authors] = await Promise.all([
    query(
      `SELECT t.taxonomy, t.slug, t.name, t.updated_at
         FROM editorial_terms t
        WHERE t.taxonomy IN ('category', 'topic', 'tag', 'destination') AND t.post_count > 0
        ORDER BY FIELD(t.taxonomy, 'category', 'topic', 'destination', 'tag'), t.sort_order, t.name`,
      []
    ),
    query(
      "SELECT slug, name, updated_at FROM authors WHERE is_active = 1 AND post_count > 0 ORDER BY name",
      []
    ),
  ]);
  return [
    ...terms.map((row) => ({
      url: `/blogs/${row.taxonomy}/${row.slug}`,
      title: row.name,
      lastModified: iso(row.updated_at),
      changeFrequency: "weekly",
      priority: row.taxonomy === "tag" ? 0.4 : 0.5,
    })),
    ...authors.map((row) => ({
      url: `/blogs/author/${row.slug}`,
      title: row.name,
      lastModified: iso(row.updated_at),
      changeFrequency: "weekly",
      priority: 0.4,
    })),
  ];
}

export async function sitemapEntries(kind = "all", { category, page, pageSize, minListings } = {}) {
  // The static pages have no reliable change date: no `lastmod` rather than an invented one.
  if (kind === "static") return STATIC_PATHS.map(({ url }) => ({ url }));

  if (kind === "counts") return sectionCounts();

  if (kind === "hubs") return hubEntries(category, minListings === undefined ? {} : { minListings });

  if (kind === "blog-taxonomy") return blogTaxonomyEntries();

  if (kind === "companies") {
    const rows = await query(
      "SELECT slug, name, logo_url, updated_at FROM v_public_organizations ORDER BY active_listing_count DESC LIMIT 5000",
      []
    );
    return rows.map((row) => ({
      url: `/companies/${row.slug}`,
      title: row.name,
      images: images(row.logo_url, row.name),
      lastModified: iso(row.updated_at),
      changeFrequency: "weekly",
      priority: 0.8,
    }));
  }

  if (kind === "agents") {
    const rows = await query(
      "SELECT slug, display_name, photo_url, updated_at FROM v_public_agents ORDER BY active_listing_count DESC LIMIT 5000",
      []
    );
    return rows.map((row) => ({
      url: `/agents/${row.slug}`,
      title: row.display_name,
      images: images(row.photo_url, row.display_name),
      lastModified: iso(row.updated_at),
      changeFrequency: "weekly",
      priority: 0.7,
    }));
  }

  if (kind === "blogs") {
    const rows = await query(
      `SELECT slug, title, cover_image_url, updated_at FROM posts
        WHERE status = 'published' AND visibility = 'public' AND deleted_at IS NULL
          AND published_at <= NOW(3) AND is_indexable = 1
        ORDER BY published_at DESC LIMIT 5000`,
      []
    );
    return rows.map((row) => ({
      url: `/blogs/${row.slug}`,
      title: row.title,
      images: images(row.cover_image_url, row.title),
      lastModified: iso(row.updated_at),
      changeFrequency: "monthly",
      priority: 0.6,
    }));
  }

  /**
   * Projects.
   *
   * Straight off `project_search`, which holds only published, publicly visible,
   * non-cancelled projects with a canonical path — so a draft, an archived
   * project or one whose developer has been removed cannot reach the sitemap,
   * and every URL in it renders a page.
   */
  if (kind === "projects") {
    const { limit, offset } = paging({ page, pageSize });
    const rows = await query(
      `SELECT canonical_path, name, cover_image_url, source_updated_at, is_featured
         FROM project_search
        ORDER BY project_id DESC
        LIMIT ${limit} OFFSET ${offset}`
    );
    // The Developments location pages (/projects/{country}/…) are real results pages again
    // since 2026-11-14; they used to redirect into Real Estate Off Plan. They are listed with the
    // first page, from every project's path, and only when they hold enough projects.
    const hubs = offset
      ? []
      : hubsFromPaths(await query("SELECT canonical_path, source_updated_at FROM project_search", [])).filter(
          (hub) => hub.listingCount >= (minListings ?? THIN_HUB_MIN_LISTINGS)
        );
    return [
      ...hubs,
      ...rows.map((row) => ({
        url: row.canonical_path,
        title: row.name,
        images: images(row.cover_image_url, row.name),
        lastModified: iso(row.source_updated_at),
        changeFrequency: "weekly",
        priority: row.is_featured ? 0.9 : 0.75,
      })),
    ];
  }

  /**
   * There is deliberately no developer sitemap.
   *
   * A developer is a query filter — `/projects?developer=emaar` — and every
   * filtered variation canonicalises to the unfiltered location URL, so listing
   * one here would advertise a URL that tells crawlers to index a different
   * page. It becomes a sitemap entry the day it becomes an indexable landing
   * page with a canonical of its own, and not before.
   */
  // Every category has its own child sitemap now, so "all" is the static surface alone —
  // kept as an alias of "static" for callers that still ask for it.
  if (kind === "all") return sitemapEntries("static");

  const rootId = KIND_TO_ROOT[kind];
  if (!rootId) return [];
  return listingEntries(rootId, { page, pageSize });
}

export { STATIC_PATHS };
