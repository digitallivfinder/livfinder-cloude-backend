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
  { url: "/about-us", priority: 0.5, changeFrequency: "monthly" },
  { url: "/countries", priority: 0.7, changeFrequency: "weekly" },
  // `/companies` canonicalises to `/agencies`; listing both advertised a URL that points elsewhere.
  { url: "/agencies", priority: 0.7, changeFrequency: "weekly" },
  { url: "/agents", priority: 0.7, changeFrequency: "weekly" },
  { url: "/contact-us", priority: 0.4, changeFrequency: "monthly" },
];

const KIND_TO_ROOT = { properties: 1, "real-estate": 1, cars: 2, yachts: 3, jets: 4, helicopters: 5, watches: 6 };

function iso(value) {
  if (!value) return new Date().toISOString().slice(0, 10);
  return new Date(value).toISOString().slice(0, 10);
}

/** A cover image for image sitemaps, only when the row actually has one. */
function images(url, title) {
  return url ? [{ url, title: title || undefined }] : undefined;
}

async function listingRows(rootCategoryId = null, limit = 20000) {
  const params = [];
  let filter = "";
  if (rootCategoryId) {
    filter = "WHERE ls.root_category_id = ?";
    params.push(rootCategoryId);
  }
  const safeLimit = Math.min(50000, Math.max(1, limit));
  return query(
    `SELECT ls.canonical_path, ls.title, ls.cover_image_url, ls.source_updated_at, ls.is_featured
       FROM listing_search ls ${filter}
      ORDER BY ls.published_at DESC
      LIMIT ${safeLimit}`,
    params
  );
}

/**
 * Sold, rented and withdrawn listings whose page still works (v_reachable_listings, 0062). They
 * stay in the sitemap so the page keeps its ranking; they are not hub pages' content, so
 * `hubEntries` keeps reading the live projection only.
 */
async function closedListingRows(rootCategoryId = null, limit = 20000) {
  const params = [];
  let filter = "";
  if (rootCategoryId) {
    filter = "AND l.root_category_id = ?";
    params.push(rootCategoryId);
  }
  const safeLimit = Math.min(50000, Math.max(1, limit));
  return query(
    `SELECT l.canonical_path, l.title, l.cover_image_url, l.updated_at AS source_updated_at, 0 AS is_featured
       FROM v_reachable_listings l
      WHERE l.status IN ('sold', 'rented', 'withdrawn') AND l.canonical_path IS NOT NULL ${filter}
      ORDER BY l.published_at DESC
      LIMIT ${safeLimit}`,
    params
  );
}

async function listingEntries(rootCategoryId = null, limit = 20000) {
  const [live, closed] = await Promise.all([listingRows(rootCategoryId, limit), closedListingRows(rootCategoryId, limit)]);
  const rows = [...live, ...closed].slice(0, Math.min(50000, Math.max(1, limit)));
  return rows.map((row) => ({
    url: row.canonical_path,
    title: row.title,
    lastModified: iso(row.source_updated_at),
    changeFrequency: "daily",
    priority: row.is_featured ? 0.9 : 0.75,
    images: images(row.cover_image_url, row.title),
  }));
}

/**
 * The browse pages of one category: every location (real estate) or make/model/year (assets)
 * that holds at least one public listing.
 *
 * They are read off the listings' own canonical paths — every proper prefix of a canonical path
 * below the category root is a hierarchy page that resolves and lists that listing — so a hub
 * cannot be listed unless it has something on it, and an empty city never reaches the sitemap.
 */
export async function hubEntries(kind) {
  const rootId = KIND_TO_ROOT[kind];
  if (!rootId) return [];
  const rows = await listingRows(rootId, 50000);
  const hubs = new Map();
  for (const row of rows) {
    const segments = String(row.canonical_path || "").split("/").filter(Boolean);
    // segments[0] is the category root (already in the static sitemap); the last is the listing.
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

export async function sitemapEntries(kind = "all", { category } = {}) {
  if (kind === "static") {
    return STATIC_PATHS.map((entry) => ({ ...entry, lastModified: iso(null) }));
  }

  if (kind === "hubs") return hubEntries(category);

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

  if (kind === "countries") {
    const rows = await query(
      `SELECT slug, name, updated_at FROM locations
        WHERE level = 'country' AND status = 'active' AND deleted_at IS NULL AND active_listing_count > 0
        ORDER BY active_listing_count DESC LIMIT 250`,
      []
    );
    return rows.map((row) => ({
      url: `/countries/${row.slug}`,
      title: row.name,
      lastModified: iso(row.updated_at),
      changeFrequency: "weekly",
      priority: 0.7,
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
    const rows = await query(
      `SELECT canonical_path, name, cover_image_url, source_updated_at, is_featured
         FROM project_search
        ORDER BY is_featured DESC, published_at DESC
        LIMIT 20000`
    );
    return rows.map((row) => ({
      url: row.canonical_path,
      title: row.name,
      images: images(row.cover_image_url, row.name),
      lastModified: iso(row.source_updated_at),
      changeFrequency: "weekly",
      priority: row.is_featured ? 0.9 : 0.75,
    }));
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
  return listingEntries(rootId);
}

export { STATIC_PATHS };
