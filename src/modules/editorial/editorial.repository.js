import { query, queryOne, queryValue } from "../../db/query.js";
import { serializeArticle, serializeAuthor, serializeTerm } from "../../serializers/editorial.js";

const POST_COLUMNS = `
  p.id, p.public_id, p.author_id, p.primary_term_id, p.post_type, p.title, p.slug, p.excerpt,
  p.cover_image_url, p.cover_image_alt, p.reading_time_minutes, p.status, p.visibility,
  p.published_at, p.is_featured, p.is_pinned, p.view_count, p.share_count,
  p.seo_title, p.seo_description, p.canonical_url, p.is_indexable, p.updated_at, p.body_format`;

/** Publication is a WHERE clause, not a caller decision. */
const PUBLIC_WHERE = `
  p.deleted_at IS NULL
  AND p.status = 'published'
  AND p.visibility = 'public'
  AND p.published_at IS NOT NULL
  AND p.published_at <= NOW(3)`;

async function decorate(rows, { includeBody = false } = {}) {
  if (!rows.length) return [];
  const ids = rows.map((row) => row.id);
  const placeholders = ids.map(() => "?").join(", ");
  const [terms, authors] = await Promise.all([
    query(
      `SELECT pt.post_id, t.id, t.slug, t.name, t.taxonomy, t.description, t.cover_image_url, t.post_count, t.is_featured
         FROM post_terms pt JOIN editorial_terms t ON t.id = pt.term_id
        WHERE pt.post_id IN (${placeholders})`,
      ids
    ),
    query(
      `SELECT * FROM authors WHERE id IN (${[...new Set(rows.map((row) => row.author_id).filter(Boolean))].map(() => "?").join(", ") || "NULL"})`,
      [...new Set(rows.map((row) => row.author_id).filter(Boolean))]
    ),
  ]);

  const termsByPost = terms.reduce((map, term) => {
    const list = map.get(String(term.post_id)) || [];
    list.push(term);
    map.set(String(term.post_id), list);
    return map;
  }, new Map());
  const authorById = new Map(authors.map((author) => [String(author.id), author]));

  return rows.map((row) =>
    serializeArticle(row, {
      terms: termsByPost.get(String(row.id)) || [],
      author: authorById.get(String(row.author_id)) || null,
      includeBody,
    })
  );
}

export async function listArticles({
  limit = 8,
  offset = 0,
  taxonomy = null,
  termSlug = null,
  authorSlug = null,
  q = null,
  featured = null,
  postType = null,
} = {}) {
  const conditions = [PUBLIC_WHERE];
  const params = [];
  const joins = [];

  if (taxonomy && termSlug) {
    joins.push(`JOIN post_terms pt ON pt.post_id = p.id
                JOIN editorial_terms t ON t.id = pt.term_id AND t.taxonomy = ? AND t.slug = ?`);
    params.push(taxonomy, termSlug);
  }
  if (authorSlug) {
    joins.push("JOIN authors au ON au.id = p.author_id AND au.slug = ?");
    params.push(authorSlug);
  }
  if (q) {
    conditions.push("(p.title LIKE ? OR p.excerpt LIKE ?)");
    params.push(`%${q}%`, `%${q}%`);
  }
  if (featured !== null) {
    conditions.push("p.is_featured = ?");
    params.push(featured ? 1 : 0);
  }
  if (postType) {
    conditions.push("p.post_type = ?");
    params.push(postType);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const safeLimit = Math.min(50, Math.max(1, Number(limit) || 8));
  const safeOffset = Math.max(0, Number(offset) || 0);

  const [rows, total] = await Promise.all([
    query(
      `SELECT ${POST_COLUMNS} FROM posts p ${joins.join("\n")} ${where}
        ORDER BY p.is_pinned DESC, p.published_at DESC, p.id DESC
        LIMIT ${safeLimit} OFFSET ${safeOffset}`,
      params
    ),
    queryValue(`SELECT COUNT(DISTINCT p.id) FROM posts p ${joins.join("\n")} ${where}`, params),
  ]);

  return { rows: await decorate(rows), total: Number(total || 0) };
}

export async function getArticle(slug) {
  const row = await queryOne(
    `SELECT ${POST_COLUMNS}, p.body FROM posts p WHERE p.slug = ? AND ${PUBLIC_WHERE} LIMIT 1`,
    [slug]
  );
  if (!row) return null;
  const [article] = await decorate([row], { includeBody: true });
  return article;
}

/** Related by shared terms, newest first, never the article itself. */
export async function relatedArticles(postId, limit = 3) {
  const safeLimit = Math.min(12, Math.max(1, Number(limit) || 3));
  const rows = await query(
    `SELECT ${POST_COLUMNS}, COUNT(*) AS shared
       FROM posts p
       JOIN post_terms pt ON pt.post_id = p.id
      WHERE pt.term_id IN (SELECT term_id FROM post_terms WHERE post_id = ?)
        AND p.id <> ?
        AND ${PUBLIC_WHERE}
      GROUP BY p.id
      ORDER BY shared DESC, p.published_at DESC
      LIMIT ${safeLimit}`,
    [Number(postId), Number(postId)]
  );
  return decorate(rows);
}

export async function recentArticles({ excludeId = null, limit = 4 } = {}) {
  const safeLimit = Math.min(24, Math.max(1, Number(limit) || 4));
  const params = [];
  let exclude = "";
  if (excludeId) {
    exclude = " AND p.public_id <> ? AND p.slug <> ?";
    params.push(excludeId, excludeId);
  }
  const rows = await query(
    `SELECT ${POST_COLUMNS} FROM posts p WHERE ${PUBLIC_WHERE}${exclude}
      ORDER BY p.published_at DESC LIMIT ${safeLimit}`,
    params
  );
  return decorate(rows);
}

export async function listTerms(taxonomy) {
  const rows = await query(
    `SELECT id, slug, name, taxonomy, description, cover_image_url, post_count, is_featured
       FROM editorial_terms WHERE taxonomy = ? ORDER BY sort_order ASC, name ASC`,
    [taxonomy]
  );
  return rows.map(serializeTerm);
}

export async function getTerm(taxonomy, slug) {
  const row = await queryOne(
    `SELECT id, slug, name, taxonomy, description, cover_image_url, post_count, is_featured
       FROM editorial_terms WHERE taxonomy = ? AND slug = ? LIMIT 1`,
    [taxonomy, slug]
  );
  return serializeTerm(row);
}

export async function getAuthor(slug) {
  const row = await queryOne("SELECT * FROM authors WHERE slug = ? AND is_active = 1 LIMIT 1", [slug]);
  return serializeAuthor(row);
}

export async function editorialHome() {
  const [featured, trending, latest, categories, destinations] = await Promise.all([
    listArticles({ featured: true, limit: 6 }),
    listArticles({ limit: 4 }),
    listArticles({ limit: 8 }),
    listTerms("category"),
    listTerms("destination"),
  ]);

  const sections = [];
  for (const category of categories.slice(0, 6)) {
    const { rows } = await listArticles({ taxonomy: "category", termSlug: category.slug, limit: 3 });
    if (rows.length >= 2) sections.push({ ...category, articles: rows });
  }

  return {
    lead: featured.rows[0] || latest.rows[0] || null,
    topStories: trending.rows,
    latest: latest.rows,
    destinations,
    categories,
    sections,
  };
}

export { PUBLIC_WHERE, POST_COLUMNS, decorate };
