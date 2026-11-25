import { query, queryValue } from "../../db/query.js";

/**
 * The facts a browse page states about itself — `/real-estate/united-arab-emirates/dubai`,
 * `/cars/ferrari` — for its intro paragraph and FAQ: how many live listings, for sale and for
 * rent; the asking-price range for sale (in the platform base currency, hidden prices left out);
 * the most common types; the child areas or models with the most listings; how many companies
 * list there. Read from the search projection, so it describes exactly what the page lists.
 */
const KIND_TO_ROOT = { "real-estate": 1, cars: 2, yachts: 3, jets: 4, helicopters: 5, watches: 6 };

const likePrefix = (path) => `${String(path).replace(/[\\%_]/g, (char) => `\\${char}`)}/%`;

export async function hubSummary(category, path) {
  const rootId = KIND_TO_ROOT[category];
  const clean = `/${String(path || "").split("?")[0].split("/").filter(Boolean).join("/")}`;
  if (!rootId || !clean.startsWith(`/${category}`)) return null;
  // The category home summarises the whole category; a deeper page only what sits beneath it.
  const where = clean === `/${category}` ? "ls.root_category_id = ?" : "ls.root_category_id = ? AND ls.canonical_path LIKE ?";
  const params = clean === `/${category}` ? [rootId] : [rootId, likePrefix(clean)];

  const [totals, types, paths, baseCurrency] = await Promise.all([
    query(
      `SELECT ls.purpose_slug,
              COUNT(*) AS total,
              MIN(CASE WHEN l.is_price_hidden = 0 THEN ls.price_base END) AS min_base,
              MAX(CASE WHEN l.is_price_hidden = 0 THEN ls.price_base END) AS max_base 
         FROM listing_search ls JOIN listings l ON l.id = ls.listing_id
        WHERE ${where}
        GROUP BY ls.purpose_slug`,
      params
    ),
    query(
      `SELECT c.name, COUNT(*) AS total
         FROM listing_search ls JOIN categories c ON c.id = ls.category_id
        WHERE ${where} AND c.parent_id IS NOT NULL
        GROUP BY c.id, c.name
        ORDER BY total DESC, c.name
        LIMIT 5`,
      params
    ),
    query(`SELECT ls.canonical_path FROM listing_search ls WHERE ${where}`, params),
    queryValue("SELECT code FROM currencies WHERE is_base = 1 LIMIT 1", []),
  ]);

  const depth = clean.split("/").filter(Boolean).length;
  const children = new Map();
  for (const row of paths) {
    const segments = String(row.canonical_path).split("/").filter(Boolean);
    // A child browse page sits one level down and still has a listing beneath it.
    if (segments.length <= depth + 1) continue;
    const child = `/${segments.slice(0, depth + 1).join("/")}`;
    children.set(child, (children.get(child) || 0) + 1);
  }

  const byPurpose = Object.fromEntries(totals.map((row) => [row.purpose_slug, row]));
  const sale = byPurpose["for-sale"];
  const rent = byPurpose["for-rent"];
  const total = totals.reduce((sum, row) => sum + Number(row.total), 0);
  return {
    path: clean,
    total,
    sale: { count: Number(sale?.total || 0), minPrice: sale?.min_base == null ? null : Number(sale.min_base), maxPrice: sale?.max_base == null ? null : Number(sale.max_base) },
    rentCount: Number(rent?.total || 0),
    currency: baseCurrency || null,
    // Listings with no company (individual sellers) are not companies.
    companies: Number(
      (await query(`SELECT COUNT(DISTINCT ls.organization_id) AS total FROM listing_search ls WHERE ${where} AND ls.organization_id IS NOT NULL`, params))[0]?.total || 0
    ),
    types: types.map((row) => ({ name: row.name, count: Number(row.total) })),
    children: [...children.entries()]
      .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
      // Twelve: the intro names the top three, the page's "Browse" links show them all.
      .slice(0, 12)
      .map(([url, count]) => ({ url, count })),
  };
}
