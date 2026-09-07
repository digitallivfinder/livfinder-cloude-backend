import { query } from "../../db/query.js";

/**
 * The sitemap is built from the visibility view, not from a fixture list, so a
 * URL cannot reach sitemap.xml unless the page behind it actually renders.
 */
const STATIC_PATHS = [
  { url: "/", priority: 1, changeFrequency: "daily" },
  { url: "/search", priority: 0.7, changeFrequency: "weekly" },
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
  { url: "/companies", priority: 0.7, changeFrequency: "weekly" },
  { url: "/agents", priority: 0.7, changeFrequency: "weekly" },
  { url: "/contact-us", priority: 0.4, changeFrequency: "monthly" },
];

const KIND_TO_ROOT = { properties: 1, "real-estate": 1, cars: 2, yachts: 3, jets: 4, helicopters: 5, watches: 6 };

function iso(value) {
  if (!value) return new Date().toISOString().slice(0, 10);
  return new Date(value).toISOString().slice(0, 10);
}

async function listingEntries(rootCategoryId = null, limit = 20000) {
  const params = [];
  let filter = "";
  if (rootCategoryId) {
    filter = "WHERE ls.root_category_id = ?";
    params.push(rootCategoryId);
  }
  const safeLimit = Math.min(50000, Math.max(1, limit));
  const rows = await query(
    `SELECT ls.canonical_path, ls.source_updated_at, ls.is_featured
       FROM listing_search ls ${filter}
      ORDER BY ls.published_at DESC
      LIMIT ${safeLimit}`,
    params
  );
  return rows.map((row) => ({
    url: row.canonical_path,
    lastModified: iso(row.source_updated_at),
    changeFrequency: "daily",
    priority: row.is_featured ? 0.9 : 0.75,
  }));
}

export async function sitemapEntries(kind = "all") {
  if (kind === "companies") {
    const rows = await query(
      "SELECT slug, updated_at FROM v_public_organizations ORDER BY active_listing_count DESC LIMIT 5000",
      []
    );
    return rows.map((row) => ({
      url: `/companies/${row.slug}`,
      lastModified: iso(row.updated_at),
      changeFrequency: "weekly",
      priority: 0.8,
    }));
  }

  if (kind === "agents") {
    const rows = await query(
      "SELECT slug, updated_at FROM v_public_agents ORDER BY active_listing_count DESC LIMIT 5000",
      []
    );
    return rows.map((row) => ({
      url: `/agents/${row.slug}`,
      lastModified: iso(row.updated_at),
      changeFrequency: "weekly",
      priority: 0.7,
    }));
  }

  if (kind === "blogs") {
    const rows = await query(
      `SELECT slug, updated_at FROM posts
        WHERE status = 'published' AND visibility = 'public' AND deleted_at IS NULL
          AND published_at <= NOW(3) AND is_indexable = 1
        ORDER BY published_at DESC LIMIT 5000`,
      []
    );
    return rows.map((row) => ({
      url: `/blogs/${row.slug}`,
      lastModified: iso(row.updated_at),
      changeFrequency: "monthly",
      priority: 0.6,
    }));
  }

  if (kind === "countries") {
    const rows = await query(
      `SELECT slug, updated_at FROM locations
        WHERE level = 'country' AND status = 'active' AND deleted_at IS NULL AND active_listing_count > 0
        ORDER BY active_listing_count DESC LIMIT 250`,
      []
    );
    return rows.map((row) => ({
      url: `/countries/${row.slug}`,
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
      `SELECT canonical_path, source_updated_at, is_featured
         FROM project_search
        ORDER BY is_featured DESC, published_at DESC
        LIMIT 20000`
    );
    return rows.map((row) => ({
      url: row.canonical_path,
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
  if (kind === "all") {
    // The index sitemap: the static surface plus the categories with no
    // dedicated child sitemap file.
    const extras = await listingEntries(null, 500);
    return [
      ...STATIC_PATHS.map((entry) => ({ ...entry, lastModified: iso(null) })),
      ...extras.filter((entry) => entry.url.startsWith("/helicopters/") || entry.url.startsWith("/watches/")),
    ];
  }

  const rootId = KIND_TO_ROOT[kind];
  if (!rootId) return [];
  return listingEntries(rootId);
}

export { STATIC_PATHS };
