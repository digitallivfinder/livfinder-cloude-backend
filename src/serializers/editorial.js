import { bool, int, isoDay, jsonField } from "./primitives.js";

const ENTITIES = {
  "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": '"', "&#39;": "'", "&apos;": "'",
  "&nbsp;": " ", "&mdash;": "—", "&ndash;": "–", "&hellip;": "…", "&rsquo;": "’", "&lsquo;": "‘",
  "&ldquo;": "“", "&rdquo;": "”", "&pound;": "£", "&euro;": "€",
};

function decodeEntities(value) {
  return String(value)
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&[a-z]+;|&#\d+;/gi, (entity) => ENTITIES[entity.toLowerCase()] ?? entity);
}

function stripTags(html) {
  return decodeEntities(String(html).replace(/<[^>]*>/g, "")).replace(/\s+/g, " ").trim();
}

/**
 * Converts a stored HTML article body into the block array the ArticleBody
 * renderer consumes.
 *
 * Doing this on the server keeps the frontend free of `dangerouslySetInnerHTML`
 * and keeps one rendering path for articles regardless of how the body was
 * authored.
 */
export function htmlToBlocks(html) {
  if (!html) return [];
  const blocks = [];
  const pattern = /<(p|h2|h3|h4|ul|ol|blockquote|figure|table)\b[^>]*>([\s\S]*?)<\/\1>/gi;
  let match;
  while ((match = pattern.exec(html)) !== null) {
    const [, tag, inner] = match;
    const lower = tag.toLowerCase();
    if (lower === "p") {
      const text = stripTags(inner);
      if (text) blocks.push({ type: "paragraph", text });
    } else if (lower === "h2" || lower === "h3" || lower === "h4") {
      const text = stripTags(inner);
      if (text) blocks.push({ type: "heading", level: Number(lower.slice(1)), text });
    } else if (lower === "ul" || lower === "ol") {
      const items = [...inner.matchAll(/<li\b[^>]*>([\s\S]*?)<\/li>/gi)]
        .map((item) => stripTags(item[1]))
        .filter(Boolean);
      if (items.length) blocks.push({ type: "list", items });
    } else if (lower === "blockquote") {
      const text = stripTags(inner);
      if (text) blocks.push({ type: "quote", text });
    } else if (lower === "figure") {
      const src = /<img[^>]*\ssrc=["']([^"']+)["']/i.exec(inner)?.[1];
      const alt = /<img[^>]*\salt=["']([^"']*)["']/i.exec(inner)?.[1] || "";
      const caption = /<figcaption\b[^>]*>([\s\S]*?)<\/figcaption>/i.exec(inner)?.[1];
      if (src) blocks.push({ type: "image", src, alt, caption: caption ? stripTags(caption) : undefined });
    }
  }
  if (!blocks.length) {
    // A body with no recognised markup still has to render.
    const text = stripTags(html);
    if (text) blocks.push({ type: "paragraph", text });
  }
  return blocks;
}

export function serializeAuthor(row) {
  if (!row) return null;
  return {
    id: row.public_id || `author_${row.id}`,
    slug: row.slug,
    fullName: row.name,
    role: row.title || "Contributor",
    biography: row.bio || "",
    photo: row.avatar_url || "",
    email: row.email || null,
    socialLinks: jsonField(row.social_links, {}),
    postCount: int(row.post_count) ?? 0,
    publicPageEnabled: bool(row.is_active),
  };
}

export function serializeTerm(row) {
  if (!row) return null;
  return {
    id: String(row.id),
    slug: row.slug,
    label: row.name,
    name: row.name,
    taxonomy: row.taxonomy,
    description: row.description || "",
    image: row.cover_image_url || null,
    cover: row.cover_image_url || null,
    postCount: int(row.post_count) ?? 0,
    featured: bool(row.is_featured),
  };
}

/**
 * Article projection matching the shape the editorial components already read:
 * `heroImage`, `primaryCategory`, `categories[]`, `topics[]`, `tags[]`,
 * `destinations[]`, `author`, `body[]`.
 */
export function serializeArticle(row, { terms = [], author = null, includeBody = false } = {}) {
  const byTaxonomy = (taxonomy) => terms.filter((term) => term.taxonomy === taxonomy);
  const categories = byTaxonomy("category");
  const topics = byTaxonomy("topic");
  const tags = byTaxonomy("tag");
  const destinations = byTaxonomy("destination");
  const primaryCategory = categories.find((term) => String(term.id) === String(row.primary_term_id)) || categories[0];
  const primaryTopic = topics.find((term) => String(term.id) === String(row.primary_term_id)) || topics[0];

  return {
    id: row.public_id || `post_${row.id}`,
    postId: String(row.id),
    slug: row.slug,
    status: row.status,
    public: row.visibility === "public",
    title: row.title,
    excerpt: row.excerpt || "",
    standfirst: row.excerpt || "",
    format: formatLabel(row.post_type),
    postType: row.post_type,
    heroImage: row.cover_image_url
      ? { src: row.cover_image_url, alt: row.cover_image_alt || row.title, width: 1600, height: 1000 }
      : null,
    primaryCategory: primaryCategory ? { slug: primaryCategory.slug, label: primaryCategory.name } : null,
    categories: categories.map((term) => term.slug),
    primaryTopic: primaryTopic ? { slug: primaryTopic.slug, label: primaryTopic.name } : null,
    topics: topics.map((term) => term.slug),
    tags: tags.map((term) => term.name),
    destinations: destinations.map((term) => ({
      slug: term.slug,
      name: term.name,
      country: term.name,
      region: null,
    })),
    author: serializeAuthor(author),
    publishedAt: isoDay(row.published_at),
    updatedAt: isoDay(row.updated_at),
    readingTimeMinutes: int(row.reading_time_minutes) ?? 5,
    featured: bool(row.is_featured),
    featuredPriority: bool(row.is_pinned) ? 1 : null,
    trending: bool(row.is_pinned) || (int(row.view_count) ?? 0) > 500,
    viewCount: int(row.view_count) ?? 0,
    canonicalUrl: row.canonical_url || `/blogs/${row.slug}`,
    seo: {
      title: row.seo_title || row.title,
      description: row.seo_description || row.excerpt || "",
      indexable: bool(row.is_indexable),
    },
    relatedArticleIds: [],
    explicitDenyFlags: [],
    ...(includeBody ? { body: row.body_format === "blocks" ? jsonField(row.body, []) : htmlToBlocks(row.body) } : {}),
  };
}

function formatLabel(postType) {
  return {
    article: "Article",
    guide: "Guide",
    news: "News",
    market_report: "Market Report",
    press_release: "Press Release",
    interview: "Interview",
    video: "Video",
    case_study: "Case Study",
  }[postType] || "Article";
}
