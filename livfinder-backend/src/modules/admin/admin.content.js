import {
  query, queryOne, queryValue, adminPagination, adminList, int, num, bool, isoDate, frontendCategoryId,
} from "./admin.shared.js";
import { htmlToBlocks } from "../../serializers/editorial.js";
import * as options from "./admin.options.js";

/**
 * Admin content reads: articles, media library, reviews and reports.
 */

/* -------------------------------------------------------------------------- */
/* Articles                                                                    */
/* -------------------------------------------------------------------------- */

export async function listAdminArticles({ status = "all", search = "", category = "", author = "", page = 1, pageSize = 10 } = {}) {
  const conditions = ["p.deleted_at IS NULL"];
  const params = [];
  const joins = ["LEFT JOIN authors au ON au.id = p.author_id"];

  if (status !== "all") {
    conditions.push("p.status = ?");
    params.push(status);
  }
  if (search) {
    conditions.push("(p.title LIKE ? OR p.slug LIKE ? OR p.excerpt LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (author) {
    conditions.push("au.slug = ?");
    params.push(author);
  }
  if (category) {
    joins.push(`JOIN post_terms pt ON pt.post_id = p.id
                JOIN editorial_terms t ON t.id = pt.term_id AND t.taxonomy = 'category' AND t.slug = ?`);
    params.unshift(category);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT DISTINCT p.id, p.public_id, p.title, p.slug, p.excerpt, p.status, p.visibility,
              p.post_type, p.cover_image_url, p.cover_image_alt, p.reading_time_minutes,
              p.published_at, p.scheduled_for, p.is_featured, p.view_count, p.created_at, p.updated_at,
              p.seo_title, p.seo_description, p.canonical_url, p.is_indexable,
              au.public_id AS author_public_id, au.name AS author_name, au.slug AS author_slug,
              au.avatar_url AS author_avatar
         FROM posts p ${joins.join("\n")} ${where}
        ORDER BY p.updated_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(DISTINCT p.id) FROM posts p ${joins.join("\n")} ${where}`, params),
    queryOne(
      `SELECT COUNT(*) AS total, SUM(status = 'published') AS published, SUM(status = 'draft') AS draft,
              SUM(status = 'scheduled') AS scheduled, SUM(status = 'archived') AS archived,
              SUM(status = 'in_review') AS inReview
         FROM posts WHERE deleted_at IS NULL`
    ),
  ]);

  const ids = rows.map((row) => row.id);
  const terms = ids.length
    ? await query(
        `SELECT pt.post_id, t.slug, t.name, t.taxonomy FROM post_terms pt
           JOIN editorial_terms t ON t.id = pt.term_id
          WHERE pt.post_id IN (${ids.map(() => "?").join(", ")})`,
        ids
      )
    : [];
  const byPost = terms.reduce((map, term) => {
    const list = map.get(String(term.post_id)) || [];
    list.push(term);
    map.set(String(term.post_id), list);
    return map;
  }, new Map());

  return adminList({
    items: rows.map((row) => serializeAdminArticle(row, byPost.get(String(row.id)) || [])),
    total,
    page: safePage,
    pageSize: safeSize,
    summary: {
      total: int(summary?.total) ?? 0,
      published: int(summary?.published) ?? 0,
      draft: int(summary?.draft) ?? 0,
      scheduled: int(summary?.scheduled) ?? 0,
      archived: int(summary?.archived) ?? 0,
      inReview: int(summary?.inReview) ?? 0,
    },
    options: {
      authors: await options.authors(),
      categories: await options.editorialCategories(),
      statuses: options.staticOptions(["draft", "in_review", "scheduled", "published", "archived"]),
    },
  });
}

function serializeAdminArticle(row, terms) {
  const byTaxonomy = (taxonomy) => terms.filter((term) => term.taxonomy === taxonomy);
  return {
    id: row.public_id,
    postId: String(row.id),
    reference: `ART-${String(row.id).padStart(5, "0")}`,
    title: row.title,
    slug: row.slug,
    excerpt: row.excerpt,
    standfirst: row.excerpt,
    status: row.status,
    visibility: row.visibility,
    postType: row.post_type,
    heroImage: row.cover_image_url ? { src: row.cover_image_url, alt: row.cover_image_alt } : null,
    readingTimeMinutes: int(row.reading_time_minutes) ?? 0,
    publishedAt: isoDate(row.published_at),
    scheduledAt: isoDate(row.scheduled_for),
    featured: bool(row.is_featured),
    views: int(row.view_count) ?? 0,
    authorId: row.author_public_id,
    author: row.author_public_id
      ? { id: row.author_public_id, fullName: row.author_name, slug: row.author_slug, photo: row.author_avatar }
      : null,
    categories: byTaxonomy("category").map((term) => term.slug),
    primaryCategory: byTaxonomy("category")[0] ? { slug: byTaxonomy("category")[0].slug, label: byTaxonomy("category")[0].name } : null,
    topics: byTaxonomy("topic").map((term) => term.slug),
    primaryTopic: byTaxonomy("topic")[0] ? { slug: byTaxonomy("topic")[0].slug, label: byTaxonomy("topic")[0].name } : null,
    tags: byTaxonomy("tag").map((term) => term.name),
    destinationSlug: byTaxonomy("destination")[0]?.slug ?? null,
    seo: { title: row.seo_title, description: row.seo_description, canonical: row.canonical_url, indexable: bool(row.is_indexable) },
    createdAt: isoDate(row.created_at),
    updatedAt: isoDate(row.updated_at),
  };
}

export async function getAdminArticle(identifier) {
  const row = await queryOne(
    `SELECT p.*, au.public_id AS author_public_id, au.name AS author_name, au.slug AS author_slug,
            au.avatar_url AS author_avatar, au.bio AS author_bio, au.title AS author_role,
            au.is_active AS author_active
       FROM posts p LEFT JOIN authors au ON au.id = p.author_id
      WHERE (p.public_id = ? OR p.slug = ?) AND p.deleted_at IS NULL LIMIT 1`,
    [identifier, identifier]
  );
  if (!row) return null;
  const terms = await query(
    `SELECT t.slug, t.name, t.taxonomy FROM post_terms pt JOIN editorial_terms t ON t.id = pt.term_id
      WHERE pt.post_id = ?`,
    [row.id]
  );
  return {
    ...serializeAdminArticle(row, terms),
    contentHtml: row.body,
    body: row.body_format === "blocks" ? JSON.parse(row.body || "[]") : htmlToBlocks(row.body),
    biography: row.author_bio,
    author: row.author_public_id
      ? {
          id: row.author_public_id,
          fullName: row.author_name,
          slug: row.author_slug,
          photo: row.author_avatar,
          role: row.author_role,
          biography: row.author_bio,
          publicPageEnabled: bool(row.author_active),
        }
      : null,
  };
}

export async function adminArticleOptions() {
  const [categories, topics, tags, destinations, authors] = await Promise.all([
    query("SELECT slug, name FROM editorial_terms WHERE taxonomy = 'category' ORDER BY sort_order, name"),
    query("SELECT slug, name FROM editorial_terms WHERE taxonomy = 'topic' ORDER BY sort_order, name"),
    query("SELECT slug, name FROM editorial_terms WHERE taxonomy = 'tag' ORDER BY name"),
    query("SELECT slug, name FROM editorial_terms WHERE taxonomy = 'destination' ORDER BY name"),
    query("SELECT public_id, name, slug, avatar_url, title FROM authors WHERE is_active = 1 ORDER BY name"),
  ]);
  return {
    categories: categories.map((row) => ({ value: row.slug, label: row.name })),
    topics: topics.map((row) => ({ value: row.slug, label: row.name })),
    tags: tags.map((row) => ({ value: row.slug, label: row.name })),
    destinations: destinations.map((row) => ({ value: row.slug, label: row.name })),
    authors: authors.map((row) => ({ id: row.public_id, value: row.public_id, label: row.name, slug: row.slug, photo: row.avatar_url, role: row.title })),
    statuses: ["draft", "in_review", "scheduled", "published", "archived"],
  };
}

/* -------------------------------------------------------------------------- */
/* Media library                                                               */
/* -------------------------------------------------------------------------- */

export async function listAdminMedia({ type = "all", search = "", folder = "", usage = "", page = 1, pageSize = 24 } = {}) {
  const conditions = ["m.deleted_at IS NULL"];
  const params = [];
  if (type !== "all") {
    conditions.push("m.media_type = ?");
    params.push(type);
  }
  if (search) {
    conditions.push("(m.original_file_name LIKE ? OR m.file_name LIKE ? OR m.alt_text LIKE ? OR m.caption LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
  }
  if (folder) {
    conditions.push("f.path = ?");
    params.push(folder);
  }
  if (usage === "unused") conditions.push("m.reference_count = 0");
  if (usage === "used") conditions.push("m.reference_count > 0");

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT m.id, m.public_id, m.media_type, m.url, m.cdn_url, m.storage_path, m.storage_disk,
              m.file_name, m.original_file_name, m.mime_type, m.extension, m.file_size_bytes,
              m.width, m.height, m.duration_seconds, m.alt_text, m.caption, m.credit,
              m.reference_count, m.created_at, m.updated_at, m.source, m.checksum,
              f.path AS folder_path, u.display_name AS uploaded_by
         FROM media_assets m
         LEFT JOIN media_folders f ON f.id = m.folder_id
         LEFT JOIN users u ON u.id = m.uploaded_by_user_id
         ${where} ORDER BY m.created_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM media_assets m LEFT JOIN media_folders f ON f.id = m.folder_id ${where}`, params),
    queryOne(
      `SELECT COUNT(*) AS total, COALESCE(SUM(file_size_bytes), 0) AS storage_used,
              SUM(media_type = 'image') AS image, SUM(media_type = 'video') AS video,
              SUM(media_type = 'document') AS document, SUM(reference_count = 0) AS unused
         FROM media_assets WHERE deleted_at IS NULL`
    ),
  ]);

  return adminList({
    items: rows.map(serializeAdminMedia),
    total,
    page: safePage,
    pageSize: safeSize,
    summary: {
      total: int(summary?.total) ?? 0,
      storageUsedBytes: Number(summary?.storage_used || 0),
      image: int(summary?.image) ?? 0,
      video: int(summary?.video) ?? 0,
      document: int(summary?.document) ?? 0,
      unused: int(summary?.unused) ?? 0,
    },
    options: {
      categories: await options.editorialCategories(),
      uploaders: await options.uploaders(),
      formats: await options.distinct("media_assets", "mime_type", { where: "AND deleted_at IS NULL", limit: 40 }),
      types: options.staticOptions(["image", "video", "document", "audio"]),
    },
  });
}

function serializeAdminMedia(row) {
  return {
    id: row.public_id,
    assetId: String(row.id),
    reference: `MED-${String(row.id).padStart(6, "0")}`,
    mediaType: row.media_type,
    type: row.media_type,
    title: row.original_file_name || row.file_name,
    originalFilename: row.original_file_name,
    publicUrl: row.cdn_url || row.url,
    href: row.cdn_url || row.url,
    poster: row.media_type === "image" ? row.cdn_url || row.url : null,
    mimeType: row.mime_type,
    extension: row.extension,
    fileSize: Number(row.file_size_bytes || 0),
    width: int(row.width),
    height: int(row.height),
    duration: int(row.duration_seconds),
    altText: row.alt_text,
    caption: row.caption,
    credit: row.credit,
    usage: { references: int(row.reference_count) ?? 0 },
    storage: { disk: row.storage_disk, key: row.storage_path },
    provider: row.storage_disk,
    folder: row.folder_path,
    source: row.source,
    checksum: row.checksum,
    uploadedBy: row.uploaded_by,
    createdAt: isoDate(row.created_at),
    updatedAt: isoDate(row.updated_at),
  };
}

export async function getAdminMedia(identifier) {
  const row = await queryOne(
    `SELECT m.*, f.path AS folder_path, u.display_name AS uploaded_by
       FROM media_assets m
       LEFT JOIN media_folders f ON f.id = m.folder_id
       LEFT JOIN users u ON u.id = m.uploaded_by_user_id
      WHERE m.public_id = ? AND m.deleted_at IS NULL LIMIT 1`,
    [identifier]
  );
  if (!row) return null;
  const [renditions, listings] = await Promise.all([
    query("SELECT preset_code, url, width, height, format, file_size_bytes FROM media_renditions WHERE media_asset_id = ?", [row.id]),
    query(
      `SELECT l.public_id, l.reference, l.title FROM listing_media lm
         JOIN listings l ON l.id = lm.listing_id WHERE lm.media_asset_id = ? LIMIT 50`,
      [row.id]
    ),
  ]);
  return {
    ...serializeAdminMedia(row),
    renditions: renditions.map((rendition) => ({
      code: rendition.preset_code,
      url: rendition.url,
      width: int(rendition.width),
      height: int(rendition.height),
      format: rendition.format,
      fileSize: Number(rendition.file_size_bytes || 0),
    })),
    usage: {
      references: int(row.reference_count) ?? 0,
      listings: listings.map((listing) => ({ id: listing.public_id, reference: listing.reference, title: listing.title })),
    },
  };
}

export async function adminMediaOptions() {
  const [folders, types] = await Promise.all([
    query("SELECT id, name, path FROM media_folders ORDER BY path LIMIT 200"),
    query("SELECT media_type AS value, COUNT(*) AS count FROM media_assets WHERE deleted_at IS NULL GROUP BY media_type"),
  ]);
  return {
    folders: folders.map((row) => ({ value: row.path, label: row.name })),
    types: types.map((row) => ({ value: row.value, label: row.value, count: Number(row.count) })),
    usageCategories: [
      { value: "used", label: "In use" },
      { value: "unused", label: "Unused" },
    ],
  };
}

/* -------------------------------------------------------------------------- */
/* Reviews                                                                     */
/* -------------------------------------------------------------------------- */

/**
 * What a review is about, resolved to something the admin can open.
 *
 * The Reviews table and detail screen both read a `target` object with a title, a
 * subtitle and an href; the endpoint sent only `targetType`, `targetId` and the
 * reviewed organization's name. Every row therefore rendered "Unavailable" and the
 * detail card was empty. As with reports, a link appears only where an admin screen
 * for that subject exists — listings (Real Estate) and companies — and an `agent`
 * subject stays plain text.
 */
async function resolveReviewTargets(rows) {
  const idsOf = (type) => [...new Set(rows.filter((row) => row.subject_type === type && row.subject_id).map((row) => String(row.subject_id)))];
  const placeholders = (ids) => ids.map(() => "?").join(", ");
  const resolved = new Map();

  const listingIds = idsOf("listing");
  if (listingIds.length) {
    const listings = await query(
      `SELECT l.id, l.reference, l.title, c.slug AS root_slug
         FROM listings l
         LEFT JOIN categories c ON c.id = COALESCE(l.root_category_id, l.category_id)
        WHERE l.id IN (${placeholders(listingIds)})`,
      listingIds
    );
    for (const listing of listings) {
      resolved.set(`listing:${listing.id}`, {
        title: listing.title,
        subtitle: listing.reference,
        href: listing.root_slug === "real-estate" && listing.reference ? `/admin/listings/real-estate/${listing.reference}` : null,
      });
    }
  }

  const organizationIds = idsOf("organization");
  if (organizationIds.length) {
    const organizations = await query(
      `SELECT o.id, o.public_id, o.name, o.legal_name FROM organizations o WHERE o.id IN (${placeholders(organizationIds)})`,
      organizationIds
    );
    for (const organization of organizations) {
      resolved.set(`organization:${organization.id}`, {
        title: organization.name || organization.legal_name,
        subtitle: organization.public_id,
        href: `/admin/companies/${organization.public_id}`,
      });
    }
  }

  const agentIds = idsOf("agent");
  if (agentIds.length) {
    const agents = await query(
      `SELECT a.id, a.slug, u.display_name, o.name AS organization_name
         FROM agents a
         LEFT JOIN users u ON u.id = a.user_id
         LEFT JOIN organizations o ON o.id = a.organization_id
        WHERE a.id IN (${placeholders(agentIds)})`,
      agentIds
    );
    for (const agent of agents) {
      // There is no admin agent detail route, so this one is deliberately unlinked.
      resolved.set(`agent:${agent.id}`, { title: agent.display_name, subtitle: agent.organization_name, href: null });
    }
  }

  return resolved;
}

function reviewTarget(row, targets) {
  const live = row.subject_id ? targets.get(`${row.subject_type}:${row.subject_id}`) : null;
  return {
    title: live?.title ?? row.organization_name ?? null,
    subtitle: live?.subtitle ?? null,
    href: live?.href ?? null,
    removed: Boolean(row.subject_id) && !live,
  };
}

export async function listAdminReviews({ status = "all", search = "", targetType = "", rating = "", sort = "newest", page = 1, pageSize = 10 } = {}) {
  const conditions = ["r.deleted_at IS NULL"];
  const params = [];
  // The Reviews screen has always shown a "Sort by" control; it was never read here.
  const order = sort === "oldest" ? "ASC" : "DESC";
  if (status !== "all") {
    conditions.push("r.status = ?");
    params.push(status);
  }
  if (targetType) {
    conditions.push("r.subject_type = ?");
    params.push(targetType);
  }
  if (rating) {
    conditions.push("r.rating = ?");
    params.push(Number(rating));
  }
  if (search) {
    conditions.push("(r.title LIKE ? OR r.body LIKE ? OR r.author_name LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT r.id, r.public_id, r.subject_type, r.subject_id, r.author_name, r.author_email,
              r.rating, r.title, r.body, r.status, r.moderation_note, r.moderated_at,
              r.is_verified_transaction, r.helpful_count, r.report_count, r.published_at,
              r.created_at, r.author_user_id,
              o.name AS organization_name, o.public_id AS organization_public_id,
              mu.display_name AS moderated_by_name,
              rr.body AS response_body
         FROM reviews r
         LEFT JOIN organizations o ON o.id = r.organization_id
         LEFT JOIN users mu ON mu.id = r.moderated_by_user_id
         LEFT JOIN review_responses rr ON rr.review_id = r.id
         ${where} ORDER BY r.created_at ${order} LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM reviews r ${where}`, params),
    queryOne(
      `SELECT COUNT(*) AS total, AVG(rating) AS averageRating,
              SUM(status = 'published') AS published, SUM(status = 'pending') AS pending,
              SUM(status = 'rejected') AS rejected, SUM(status = 'archived') AS archived
         FROM reviews WHERE deleted_at IS NULL`
    ),
  ]);

  const targets = await resolveReviewTargets(rows);

  return adminList({
    items: rows.map((row) => ({
      id: row.public_id,
      reviewId: String(row.id),
      reference: `RV-${String(row.id).padStart(6, "0")}`,
      target: reviewTarget(row, targets),
      targetType: row.subject_type,
      targetId: row.subject_id ? String(row.subject_id) : null,
      targetName: row.organization_name,
      organizationId: row.organization_public_id,
      reviewerId: row.author_user_id ? String(row.author_user_id) : null,
      reviewerName: row.author_name,
      reviewerEmail: row.author_email,
      rating: num(row.rating),
      title: row.title,
      body: row.body,
      status: row.status,
      internalNotes: row.moderation_note,
      moderation: { note: row.moderation_note, by: row.moderated_by_name, at: isoDate(row.moderated_at) },
      verified: bool(row.is_verified_transaction),
      helpfulCount: int(row.helpful_count) ?? 0,
      reportCount: int(row.report_count) ?? 0,
      response: row.response_body ? { exists: true, body: row.response_body } : { exists: false },
      submittedAt: isoDate(row.created_at),
      reviewedAt: isoDate(row.moderated_at),
      publishedAt: isoDate(row.published_at),
      reviewedBy: row.moderated_by_name,
    })),
    total,
    page: safePage,
    pageSize: safeSize,
    summary: {
      total: int(summary?.total) ?? 0,
      averageRating: summary?.averageRating ? Number(Number(summary.averageRating).toFixed(2)) : 0,
      published: int(summary?.published) ?? 0,
      pending: int(summary?.pending) ?? 0,
      rejected: int(summary?.rejected) ?? 0,
      archived: int(summary?.archived) ?? 0,
    },
    options: {
      statuses: ["pending", "published", "rejected", "archived"],
      targetTypes: ["organization", "agent", "listing"],
      rejectionReasons: ["Off topic", "Abusive language", "Not a genuine transaction", "Duplicate", "Personal data"],
      reviewerTypes: ["buyer", "seller", "tenant"],
      categories: options.marketplaceCategories(),
    },
  });
}

export async function getAdminReview(identifier) {
  const result = await listAdminReviews({ pageSize: 1, search: "" });
  const row = await queryOne("SELECT id FROM reviews WHERE public_id = ? LIMIT 1", [identifier]);
  if (!row) return null;
  const single = await listAdminReviews({ pageSize: 200 });
  return single.items.find((item) => item.id === identifier) || null;
}

/**
 * The "Reviewer History" tab needs a customer profile plus their other reviews and
 * lead activity — the admin-only marketplace context described in the UI. A review's
 * author is not always a registered user (guest checkout reviews have no
 * `author_user_id`), so this falls back to the name/email captured on the review
 * itself rather than failing the whole tab.
 */
export async function adminReviewerHistory(reviewerId, fallback = {}) {
  const userId = Number(reviewerId) || 0;
  const user = userId
    ? await queryOne(
        `SELECT u.id, u.email, u.phone_e164, u.display_name, u.status AS account_status, u.created_at,
                at.code AS account_type_code
           FROM users u
           LEFT JOIN accounts a ON a.id = u.default_account_id
           LEFT JOIN account_types at ON at.id = a.account_type_id
          WHERE u.id = ? AND u.deleted_at IS NULL`,
        [userId]
      )
    : null;

  const [reviewRows, reviewSummary, leadRows, leadSummary] = userId
    ? await Promise.all([
        query(
          `SELECT r.id, r.public_id, r.subject_type, r.subject_id, r.rating, r.title, r.status, r.created_at,
                  o.name AS organization_name
             FROM reviews r LEFT JOIN organizations o ON o.id = r.organization_id
            WHERE r.author_user_id = ? AND r.deleted_at IS NULL
            ORDER BY r.created_at DESC LIMIT 50`,
          [userId]
        ),
        queryOne(
          `SELECT COUNT(*) AS total, SUM(status = 'published') AS published, SUM(status = 'rejected') AS rejected
             FROM reviews WHERE author_user_id = ? AND deleted_at IS NULL`,
          [userId]
        ),
        query(
          `SELECT l.reference, l.status, l.created_at, c.name AS category_name, li.title AS listing_title
             FROM leads l
             LEFT JOIN categories c ON c.id = l.category_id
             LEFT JOIN listings li ON li.id = l.primary_listing_id
            WHERE l.user_id = ? AND l.deleted_at IS NULL
            ORDER BY l.created_at DESC LIMIT 20`,
          [userId]
        ),
        queryOne(
          `SELECT COUNT(*) AS totalLeads, COUNT(DISTINCT primary_listing_id) AS listingsContacted,
                  MAX(last_activity_at) AS lastInteraction
             FROM leads WHERE user_id = ? AND deleted_at IS NULL`,
          [userId]
        ),
      ])
    : [[], null, [], null];

  const targets = await resolveReviewTargets(reviewRows);

  return {
    reviewer: {
      name: user?.display_name || fallback.name || "Unknown reviewer",
      reference: user ? `IND-${String(user.id).padStart(5, "0")}` : "—",
      email: user?.email || fallback.email || null,
      phone: user?.phone_e164 || null,
      accountType: user?.account_type_code || "visitor",
      accountStatus: user?.account_status || "guest",
      memberSince: user ? isoDate(user.created_at) : null,
    },
    reviewSummary: {
      total: int(reviewSummary?.total) ?? 0,
      published: int(reviewSummary?.published) ?? 0,
      rejected: int(reviewSummary?.rejected) ?? 0,
    },
    reviews: reviewRows.map((row) => ({
      id: row.public_id,
      reference: `RV-${String(row.id).padStart(6, "0")}`,
      target: reviewTarget(row, targets),
      targetType: row.subject_type,
      rating: num(row.rating),
      status: row.status,
      submittedAt: isoDate(row.created_at),
    })),
    leadSummary: {
      totalLeads: int(leadSummary?.totalLeads) ?? 0,
      listingsContacted: int(leadSummary?.listingsContacted) ?? 0,
      lastInteraction: leadSummary?.lastInteraction ? isoDate(leadSummary.lastInteraction) : null,
    },
    leads: leadRows.map((row) => ({
      id: row.reference,
      reference: row.reference,
      listing: row.listing_title,
      category: row.category_name,
      status: row.status,
      date: isoDate(row.created_at),
    })),
  };
}

/* -------------------------------------------------------------------------- */
/* Reports                                                                     */
/* -------------------------------------------------------------------------- */

export async function listAdminReports({ status = "all", search = "", priority = "", entityType = "", reason = "", from = "", to = "", sort = "newest", page = 1, pageSize = 10 } = {}) {
  const conditions = [];
  const params = [];
  if (status !== "all") {
    conditions.push("r.status = ?");
    params.push(status);
  }
  if (priority) {
    conditions.push("r.priority = ?");
    params.push(priority);
  }
  if (entityType) {
    conditions.push("r.subject_type = ?");
    params.push(entityType);
  }
  if (search) {
    conditions.push("(r.reference LIKE ? OR r.details LIKE ? OR r.reporter_email LIKE ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }
  // The Reports screen offered Reason, Date Range and Sort controls that were sent in
  // the URL and then ignored here, so every one of them was a filter that did nothing.
  if (reason) {
    conditions.push("rr.code = ?");
    params.push(reason);
  }
  if (from) {
    conditions.push("r.created_at >= ?");
    params.push(`${from} 00:00:00`);
  }
  if (to) {
    conditions.push("r.created_at <= ?");
    params.push(`${to} 23:59:59`);
  }

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
  const order = sort === "oldest" ? "ASC" : "DESC";
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary, reasons] = await Promise.all([
    query(
      `SELECT r.id, r.public_id, r.reference, r.subject_type, r.subject_id, r.subject_snapshot,
              r.details, r.reporter_email, r.status, r.priority, r.resolution, r.resolution_note,
              r.resolved_at, r.due_at, r.report_count, r.created_at, r.updated_at,
              rr.name AS reason_name, rr.code AS reason_code, rr.is_severe,
              au.display_name AS assigned_to_name, au.public_id AS assigned_to_id,
              ru.display_name AS reporter_name
         FROM reports r
         LEFT JOIN report_reasons rr ON rr.id = r.reason_id
         LEFT JOIN users au ON au.id = r.assigned_to_user_id
         LEFT JOIN users ru ON ru.id = r.reporter_user_id
         ${where} ORDER BY r.created_at ${order} LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM reports r LEFT JOIN report_reasons rr ON rr.id = r.reason_id ${where}`, params),
    // The stored enum is new/triaged/in_review/escalated/resolved/dismissed/duplicate.
    // This counted `status = 'open'`, which is not one of them, so the Reports screen's
    // "Open" metric read 0 with fourteen untouched reports sitting in the queue.
    queryOne(
      `SELECT COUNT(*) AS total, SUM(status = 'new') AS newCount, SUM(status = 'triaged') AS triaged,
              SUM(status = 'in_review') AS inReview, SUM(status = 'escalated') AS escalated,
              SUM(status = 'resolved') AS resolved, SUM(status = 'dismissed') AS dismissed,
              SUM(status = 'duplicate') AS duplicateCount
         FROM reports`
    ),
    query("SELECT code, name FROM report_reasons WHERE is_active = 1 ORDER BY sort_order"),
  ]);

  const subjects = await resolveReportSubjects(rows);

  return adminList({
    items: rows.map((row) => ({
      id: row.public_id,
      reportId: String(row.id),
      reference: row.reference,
      entityType: row.subject_type,
      entityId: row.subject_id ? String(row.subject_id) : null,
      entity: reportEntity(row, subjects),
      reason: row.reason_name,
      reasonCode: row.reason_code,
      severe: bool(row.is_severe),
      description: row.details,
      reporter: { name: row.reporter_name, email: row.reporter_email },
      status: row.status,
      priority: row.priority,
      assignedTo: row.assigned_to_id ? { id: row.assigned_to_id, name: row.assigned_to_name } : null,
      resolution: row.resolution,
      notes: row.resolution_note,
      reportsSubmitted: int(row.report_count) ?? 1,
      dateReported: isoDate(row.created_at),
      lastUpdated: isoDate(row.updated_at),
      resolvedAt: isoDate(row.resolved_at),
      dueAt: isoDate(row.due_at),
    })),
    total,
    page: safePage,
    pageSize: safeSize,
    summary: {
      total: int(summary?.total) ?? 0,
      new: int(summary?.newCount) ?? 0,
      triaged: int(summary?.triaged) ?? 0,
      inReview: int(summary?.inReview) ?? 0,
      escalated: int(summary?.escalated) ?? 0,
      resolved: int(summary?.resolved) ?? 0,
      dismissed: int(summary?.dismissed) ?? 0,
      duplicate: int(summary?.duplicateCount) ?? 0,
    },
    options: {
      statuses: ["new", "triaged", "in_review", "escalated", "resolved", "dismissed", "duplicate"],
      priorities: ["low", "normal", "high", "urgent"],
      reasons: reasons.map((row) => ({ value: row.code, label: row.name })),
      // `types` and `categories` used to be published here too. A report has one
      // subject dimension — `subject_type` — and no category at all, so the screen's
      // "Report Type" and "Category" selects could never filter anything.
      entities: options.staticOptions(["listing", "agent", "organization", "review", "message", "user", "project"]),
      // The Resolve dialog offered four outcomes of its own invention; these are the
      // values `reports.resolution` accepts.
      resolutions: [
        { value: "no_action", label: "No further action" },
        { value: "content_edited", label: "Content corrected" },
        { value: "content_removed", label: "Content removed" },
        { value: "listing_unpublished", label: "Listing unpublished" },
        { value: "account_warned", label: "Warning issued" },
        { value: "account_suspended", label: "Account suspended" },
        { value: "account_banned", label: "Account banned" },
        { value: "escalated_legal", label: "Escalated to legal" },
      ],
    },
  });
}

/**
 * Resolves what a report is about into something the admin can open.
 *
 * `reports.subject_snapshot` holds only what was true when the report was filed —
 * a title and a reference. The admin Reports table and detail screen were written
 * against a mock that also carried `href`, `subtitle`, `image` and `id`, so every
 * row rendered `<Link href={undefined}>`: Next refuses that, and the whole Reports
 * section fell to the error boundary.
 *
 * Nothing is invented here. A subject gets a link only where an admin route really
 * exists — real-estate listings, companies and reviews — and the current title is
 * read from the live row so a renamed listing is not reported under its old name.
 * An `agent` subject has no admin detail route, so it stays plain text.
 */
async function resolveReportSubjects(rows) {
  const idsOf = (type) => [...new Set(rows.filter((row) => row.subject_type === type && row.subject_id).map((row) => String(row.subject_id)))];
  const placeholders = (ids) => ids.map(() => "?").join(", ");
  const resolved = new Map();
  const remember = (type, id, value) => resolved.set(`${type}:${id}`, value);

  const listingIds = idsOf("listing");
  if (listingIds.length) {
    const listings = await query(
      `SELECT l.id, l.reference, l.title, c.slug AS root_slug
         FROM listings l
         LEFT JOIN categories c ON c.id = COALESCE(l.root_category_id, l.category_id)
        WHERE l.id IN (${placeholders(listingIds)})`,
      listingIds
    );
    for (const listing of listings) {
      remember("listing", String(listing.id), {
        title: listing.title,
        reference: listing.reference,
        // Only Real Estate has an admin listing detail route today.
        href: listing.root_slug === "real-estate" && listing.reference ? `/admin/listings/real-estate/${listing.reference}` : null,
      });
    }
  }

  const organizationIds = idsOf("organization");
  if (organizationIds.length) {
    const organizations = await query(
      `SELECT o.id, o.public_id, o.name, o.legal_name
         FROM organizations o WHERE o.id IN (${placeholders(organizationIds)})`,
      organizationIds
    );
    for (const organization of organizations) {
      remember("organization", String(organization.id), {
        title: organization.name || organization.legal_name,
        reference: organization.public_id,
        href: `/admin/companies/${organization.public_id}`,
      });
    }
  }

  const reviewIds = idsOf("review");
  if (reviewIds.length) {
    const reviews = await query(
      `SELECT r.id, r.public_id, r.title
         FROM reviews r WHERE r.id IN (${placeholders(reviewIds)})`,
      reviewIds
    );
    for (const review of reviews) {
      // `reviews` has no reference column; the admin vocabulary builds one from the id,
      // the same way `listAdminReviews` does.
      const reference = `RV-${String(review.id).padStart(6, "0")}`;
      remember("review", String(review.id), {
        title: review.title || reference,
        reference,
        href: `/admin/reviews/${review.public_id}`,
      });
    }
  }

  return resolved;
}

/**
 * The subject as it stands now, falling back to the filing-time snapshot when the
 * row has since been deleted. `href` is null rather than absent so the client can
 * tell "no destination" from "not loaded".
 */
function reportEntity(row, subjects) {
  const snapshot = typeof row.subject_snapshot === "string" ? safeJson(row.subject_snapshot) : row.subject_snapshot;
  const live = row.subject_id ? subjects.get(`${row.subject_type}:${row.subject_id}`) : null;
  return {
    title: live?.title ?? snapshot?.title ?? null,
    reference: live?.reference ?? snapshot?.reference ?? null,
    href: live?.href ?? null,
    // True when the subject row is gone; the report still has to be reviewable.
    removed: Boolean(row.subject_id) && !live,
  };
}

function safeJson(value) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

export async function getAdminReport(identifier) {
  const row = await queryOne("SELECT id FROM reports WHERE public_id = ? OR reference = ? LIMIT 1", [identifier, identifier]);
  if (!row) return null;
  const list = await listAdminReports({ pageSize: 200 });
  const report = list.items.find((item) => item.reportId === String(row.id));
  if (!report) return null;
  const actions = await query(
    `SELECT ra.action_type, ra.from_value, ra.to_value, ra.note, ra.created_at, u.display_name AS actor_name
       FROM report_actions ra LEFT JOIN users u ON u.id = ra.actor_user_id
      WHERE ra.report_id = ? ORDER BY ra.created_at ASC`,
    [row.id]
  );
  return {
    ...report,
    actions: actions.map((action) => ({
      type: action.action_type,
      from: action.from_value,
      to: action.to_value,
      note: action.note,
      actorName: action.actor_name,
      at: isoDate(action.created_at),
    })),
    activity: actions.map((action) => ({
      type: action.action_type,
      text: action.note || `${action.action_type}`,
      actor: action.actor_name,
      date: isoDate(action.created_at),
    })),
  };
}
