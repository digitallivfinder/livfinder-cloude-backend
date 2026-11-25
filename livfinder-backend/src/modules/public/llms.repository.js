import { query } from "../../db/query.js";
import { categoryByRootId } from "../../utils/categories.js";
import { descriptionToText } from "../../utils/richText.js";

/**
 * Bulk, compact facts for the website's llms files (`/llms-full.txt`, `/{category}/llms-full.txt`,
 * `/blogs/llms-full.txt`).
 *
 * Live listings only: a sold or withdrawn listing keeps its page (0062) but an AI answer that
 * offers it as available would be wrong, so it is not described here. No seller emails or phone
 * numbers — a reader is sent to the listing page, where the seller's own contact buttons are.
 */
const KIND_TO_ROOT = { "real-estate": 1, cars: 2, yachts: 3, jets: 4, helicopters: 5, watches: 6 };
export const LLMS_PAGE_SIZE = 5000;

function paging({ page, pageSize } = {}) {
  const size = Math.min(LLMS_PAGE_SIZE, Math.max(1, Number(pageSize) || LLMS_PAGE_SIZE));
  return { limit: size, offset: (Math.max(1, Math.floor(Number(page) || 1)) - 1) * size };
}

function specs(value) {
  if (!value) return {};
  if (typeof value === "object") return value;
  try {
    return JSON.parse(value) || {};
  } catch {
    return {};
  }
}

const day = (value) => (value ? new Date(value).toISOString().slice(0, 10) : null);

/** One page of a category's live listings, best quality first. */
async function listings(category, options) {
  const rootId = KIND_TO_ROOT[category];
  if (!rootId) return [];
  const { limit, offset } = paging(options);
  const rows = await query(
    `SELECT ls.title, ls.canonical_path, ls.purpose_slug, ls.price, ls.currency_code, ls.price_period,
            l.is_price_hidden, ls.location_label, ls.organization_name, ls.spec_labels, ls.root_category_id,
            br.name AS brand_name, bm.name AS model_name, ls.source_updated_at, ls.category_slug
       FROM listing_search ls
       JOIN listings l ON l.id = ls.listing_id
       LEFT JOIN brands br ON br.id = ls.brand_id
       LEFT JOIN brand_models bm ON bm.id = ls.brand_model_id
      WHERE ls.root_category_id = ?
      ORDER BY ls.quality_score DESC, ls.listing_id DESC
      LIMIT ${limit} OFFSET ${offset}`,
    [rootId]
  );
  return rows.map((row) => ({
    title: row.title,
    url: row.canonical_path,
    category: categoryByRootId(row.root_category_id)?.frontendId ?? null,
    type: row.category_slug || null,
    purpose: row.purpose_slug === "for-rent" ? "rent" : row.purpose_slug === "for-charter" ? "charter" : "sale",
    price: row.is_price_hidden || row.price === null ? null : { amount: Number(row.price), currency: row.currency_code, period: row.price_period || null },
    location: row.location_label || null,
    brand: row.brand_name || null,
    model: row.model_name || null,
    specs: specs(row.spec_labels),
    seller: row.organization_name || null,
    updated: day(row.source_updated_at),
  }));
}

async function projects(options) {
  const { limit, offset } = paging(options);
  const rows = await query(
    `SELECT name, canonical_path, developer_name, tagline, source_updated_at
       FROM project_search
      ORDER BY project_id DESC
      LIMIT ${limit} OFFSET ${offset}`
  );
  return rows.map((row) => ({ title: row.name, url: row.canonical_path, developer: row.developer_name || null, summary: row.tagline || null, updated: day(row.source_updated_at) }));
}

/** Clean text of a post body: HTML or Markdown as text, blocks as the text they hold. */
function bodyText(body, format) {
  if (!body) return "";
  if (format === "blocks") {
    const texts = [];
    const walk = (node) => {
      if (!node) return;
      if (typeof node === "string") return;
      if (Array.isArray(node)) return node.forEach(walk);
      for (const key of ["text", "title", "heading", "caption", "quote"]) if (typeof node[key] === "string") texts.push(node[key]);
      for (const value of Object.values(node)) if (value && typeof value === "object") walk(value);
    };
    walk(specs(body));
    return descriptionToText(texts.join("\n\n"));
  }
  return descriptionToText(body);
}

async function posts(options) {
  const { limit, offset } = paging(options);
  const rows = await query(
    `SELECT slug, title, excerpt, body, body_format, published_at, updated_at
       FROM posts
      WHERE status = 'published' AND visibility = 'public' AND deleted_at IS NULL
        AND published_at <= NOW(3) AND is_indexable = 1
      ORDER BY published_at DESC
      LIMIT ${limit} OFFSET ${offset}`
  );
  return rows.map((row) => ({
    title: row.title,
    url: `/blogs/${row.slug}`,
    summary: row.excerpt || null,
    text: bodyText(row.body, row.body_format),
    published: day(row.published_at),
    updated: day(row.updated_at),
  }));
}

/** How many entries each kind holds, so the website knows how many llms-full pages there are. */
async function counts() {
  const [live, projectCount, postCount] = await Promise.all([
    query("SELECT root_category_id, COUNT(*) AS total FROM listing_search GROUP BY root_category_id", []),
    query("SELECT COUNT(*) AS total FROM project_search", []),
    query(
      `SELECT COUNT(*) AS total FROM posts
        WHERE status = 'published' AND visibility = 'public' AND deleted_at IS NULL AND published_at <= NOW(3) AND is_indexable = 1`,
      []
    ),
  ]);
  const result = { projects: Number(projectCount[0]?.total || 0), blogs: Number(postCount[0]?.total || 0), pageSize: LLMS_PAGE_SIZE };
  for (const [kind, rootId] of Object.entries(KIND_TO_ROOT)) result[kind] = Number(live.find((row) => row.root_category_id === rootId)?.total || 0);
  return result;
}

export async function llmsEntries(kind, { category, page, pageSize } = {}) {
  if (kind === "counts") return counts();
  if (kind === "listings") return listings(category, { page, pageSize });
  if (kind === "projects") return projects({ page, pageSize });
  if (kind === "posts") return posts({ page, pageSize });
  return [];
}
