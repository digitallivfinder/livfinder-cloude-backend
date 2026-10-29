import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute, query, queryOne } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { sendMail } from "../system/mail.service.js";
import { notifyAccount } from "../system/notifications.service.js";
import { getListingDetail, refreshListingSearch } from "./listings.repository.js";

/**
 * Pending revisions (migration 0060): an owner's change to a live listing waits for a moderator,
 * and the site keeps showing the approved version meanwhile.
 *
 * The owner keeps editing the listing's own tables through every existing path (the portal
 * form, photos, files, links, the import API). The first change to a live listing opens a
 * revision holding a snapshot of the public page as approved, and points
 * `listings.pending_revision_id` at it. While it is set the public page is served from that
 * snapshot, the search projection keeps the approved row (guard in `sp_refresh_listing_search`)
 * and the URL does not move (`updateListing` defers the slug rewrite).
 *
 * Approving publishes the listing as it now stands; rejecting keeps the approved version live
 * and sends the reasons back. The owner's next change makes a rejected revision pending again.
 * A full moderation decision on the listing itself (approving it out of review, archiving it)
 * closes the revision, since the moderator then reviewed the whole listing.
 */

const OPEN = ["pending", "rejected"];

// Live figures a frozen page still shows current: they are counters and platform flags, not
// anything the owner wrote.
const LIVE_FIELDS = ["viewCount", "inquiryCount", "favouriteCount", "featured", "sponsored", "verified", "badges", "organization"];

export const json = (value, fallback = null) => {
  if (value === null || value === undefined) return fallback;
  if (typeof value !== "string") return value;
  try {
    return JSON.parse(value);
  } catch {
    return fallback;
  }
};

async function approvedSnapshot(listingId) {
  const result = await getListingDetail({ id: listingId }, { source: "any", includePrivate: false });
  return result?.detail ?? null;
}

/**
 * Call before applying an owner's change to a listing. On a live listing it opens (or reopens)
 * the revision so the approved version is captured before anything changes. Returns the revision
 * id, or null when the listing is not live (an edit to a draft needs no revision).
 */
export async function beginOwnerChange({ listingId, userId, change }) {
  const current = await queryOne("SELECT status, pending_revision_id FROM listings WHERE id = ? AND deleted_at IS NULL", [listingId]);
  if (!current) return null;
  if (!current.pending_revision_id && current.status !== "active") return null;

  // Captured outside the transaction: it reads through the pool. Nothing has changed yet, and a
  // second change racing this one finds the revision the first one opened below.
  const snapshot = current.pending_revision_id ? null : await approvedSnapshot(listingId);
  const entry = { change: String(change || "Changed").slice(0, 200), at: new Date().toISOString(), userId: userId ?? null };

  return withTransaction(async (connection) => {
    const row = await queryOne("SELECT status, pending_revision_id FROM listings WHERE id = ? FOR UPDATE", [listingId], connection);
    if (row.pending_revision_id) {
      await execute(
        `UPDATE listing_revisions
            SET status = 'pending', last_changed_at = NOW(3),
                change_log = JSON_ARRAY_APPEND(COALESCE(change_log, JSON_ARRAY()), '$', CAST(? AS JSON))
          WHERE id = ?`,
        [JSON.stringify(entry), row.pending_revision_id],
        connection
      );
      return Number(row.pending_revision_id);
    }
    if (row.status !== "active" || !snapshot) return null;
    const inserted = await execute(
      `INSERT INTO listing_revisions
         (public_id, listing_id, status, approved_snapshot, change_log, submitted_by_user_id, submitted_at, last_changed_at)
       VALUES (?, ?, 'pending', ?, JSON_ARRAY(CAST(? AS JSON)), ?, NOW(3), NOW(3))`,
      [ulid(), listingId, JSON.stringify(snapshot), JSON.stringify(entry), userId ?? null],
      connection
    );
    await execute("UPDATE listings SET pending_revision_id = ? WHERE id = ?", [inserted.insertId, listingId], connection);
    return Number(inserted.insertId);
  });
}

/** Closes an open revision without a decision on it (the whole listing was moderated). */
export async function closeOpenRevision(listingId, connection, status = "superseded") {
  const row = await queryOne("SELECT pending_revision_id FROM listings WHERE id = ?", [listingId], connection);
  if (!row?.pending_revision_id) return false;
  await execute(
    "UPDATE listing_revisions SET status = ?, reviewed_at = COALESCE(reviewed_at, NOW(3)) WHERE id = ?",
    [status, row.pending_revision_id],
    connection
  );
  await execute("UPDATE listings SET pending_revision_id = NULL WHERE id = ?", [listingId], connection);
  return true;
}

/** The public page while a revision is open: the approved snapshot with live counters. */
export async function frozenDetail(raw, liveDetail) {
  const revision = await queryOne("SELECT approved_snapshot FROM listing_revisions WHERE id = ?", [raw.pending_revision_id]);
  const snapshot = json(revision?.approved_snapshot);
  if (!snapshot) return liveDetail;
  const frozen = { ...snapshot };
  for (const key of LIVE_FIELDS) if (key in liveDetail) frozen[key] = liveDetail[key];
  return frozen;
}

/* -------------------------------------------------------------------------- */
/* The comparison a moderator reviews                                          */
/* -------------------------------------------------------------------------- */

// Derived, duplicated or volatile parts of the page DTO that would only repeat a real change.
const IGNORED = new Set([
  "listingId", "descriptionHtml", "descriptionText", "propertyUrl", "canonicalUrl", "media", "amenities",
  "hierarchy", "country", "state", "city", "area", "subCommunity", "locationIds",
  "make", "model", "brand", "collection", "manufacturer", "organizationId", "agentId",
  "viewCount", "inquiryCount", "favouriteCount", "featured", "sponsored", "verified", "badges", "organization",
  "status", "updatedAt", "publishedAt", "createdAt", "expiresAt", "etag",
  // A development's record (0061): counters, moderation and identity, not the developer's content.
  "id", "projectId", "publicUrl", "published", "moderationStatus", "rejectionReason", "listingsCount",
  "leadsCount", "listings", "dateAdded",
]);

const LABELS = {
  title: "Title", subtitle: "Subtitle", description: "Description", price: "Price", priceType: "Price type",
  pricePeriod: "Price period", isPriceHidden: "Price hidden", locationLabel: "Location", address: "Address",
  latitude: "Latitude", longitude: "Longitude", categoryName: "Property type", purpose: "Purpose",
  brandName: "Brand", modelName: "Model", features: "Features", attributes: "Attributes", contact: "Contact",
  agent: "Agent", project: "Development", seo: "SEO", coverImage: "Cover image", detail: "Specifications",
  slug: "URL slug", canonicalPath: "URL",
  // Developments
  name: "Name", tagline: "Tagline", developer: "Developer", projectType: "Project type",
  developmentStatus: "Construction status", launchStatus: "Launch status", ownershipType: "Ownership",
  completionPercentage: "Completion %", totalUnits: "Total units", availableUnits: "Available units",
  buildingsCount: "Buildings", startingPrice: "Starting price", priceRange: "Price range", currency: "Currency",
  handover: "Handover", launch: "Launch", expectedCompletionDate: "Expected completion", highlights: "Highlights",
  marketingHeading: "Marketing heading", amenities: "Amenities", unitTypes: "Unit types", paymentPlans: "Payment plans",
  media: "Media", brochureUrl: "Brochure", location: "Location", bedroomRange: "Bedrooms", propertyTypes: "Property types",
};

// Key order is not meaningful: MySQL's JSON type stores the snapshot's keys reordered.
function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  }
  return value ?? null;
}
const same = (a, b) => JSON.stringify(stable(a)) === JSON.stringify(stable(b));

// The SEO title and description fall back to the title and description; only what the owner set
// for SEO themselves is a change of its own.
function ownSeo(page) {
  const seo = page?.seo;
  // Only the listing page derives its SEO; other records (a development) carry their own.
  if (!seo || typeof seo !== "object" || typeof page.title !== "string") return seo;
  const description = typeof page.description === "string" ? page.description : "";
  return {
    ...seo,
    title: seo.title === page.title ? null : seo.title,
    description: seo.description === description.slice(0, 300) ? null : seo.description,
  };
}

function show(value) {
  if (value === null || value === undefined || value === "") return null;
  if (Array.isArray(value)) return value.map((item) => (item && typeof item === "object" ? item.name ?? item.label ?? JSON.stringify(item) : item));
  if (typeof value === "object") {
    if ("amount" in value && "currency" in value) return value.amount === null ? null : `${value.currency} ${Number(value.amount).toLocaleString("en")}`;
    if ("name" in value && Object.keys(value).length > 2) return value.name;
    return value;
  }
  return value;
}

function mediaDiff(before = [], after = [], key) {
  const ids = (items) => new Map(items.map((item) => [String(item.mediaId ?? item.id), item]));
  const was = ids(before);
  const now = ids(after);
  const added = [...now.entries()].filter(([id]) => !was.has(id)).map(([, item]) => item);
  const removed = [...was.entries()].filter(([id]) => !now.has(id)).map(([, item]) => item);
  const changed = [...now.entries()]
    .filter(([id, item]) => was.has(id) && !same({ ...was.get(id), sortOrder: 0 }, { ...item, sortOrder: 0 }))
    .map(([, item]) => item);
  const keep = [...now.keys()].filter((id) => was.has(id));
  const reordered = key === "gallery" && !same(keep, [...was.keys()].filter((id) => now.has(id)));
  return { added, removed, changed, reordered };
}

/** Field-level differences between the approved page and the listing as it now stands. */
export function compareDetails(beforePage, afterPage) {
  const before = beforePage ? { ...beforePage, seo: ownSeo(beforePage) } : beforePage;
  const after = afterPage ? { ...afterPage, seo: ownSeo(afterPage) } : afterPage;
  const fields = [];
  for (const key of new Set([...Object.keys(before || {}), ...Object.keys(after || {})])) {
    if (IGNORED.has(key) || key === "gallery" || key === "documents") continue;
    if (key === "detail" && before?.detail && after?.detail) {
      for (const sub of new Set([...Object.keys(before.detail), ...Object.keys(after.detail)])) {
        if (!same(before.detail[sub], after.detail[sub])) {
          fields.push({ field: `detail.${sub}`, label: sub, before: show(before.detail[sub]), after: show(after.detail[sub]) });
        }
      }
      continue;
    }
    if (!same(before?.[key], after?.[key])) {
      fields.push({ field: key, label: LABELS[key] || key, before: show(before?.[key]), after: show(after?.[key]) });
    }
  }
  return {
    fields,
    gallery: mediaDiff(before?.gallery, after?.gallery, "gallery"),
    documents: mediaDiff(before?.documents, after?.documents, "documents"),
  };
}

export function serializeRevision(row) {
  if (!row) return null;
  return {
    id: row.public_id,
    status: row.status,
    submittedAt: row.submitted_at,
    lastChangedAt: row.last_changed_at,
    reviewedAt: row.reviewed_at,
    rejectionReason: row.rejection_reason ?? null,
    rejectionFields: json(row.rejection_fields, {}),
    changeLog: json(row.change_log, []),
  };
}

/** The open revision of a listing, for the owner's portal (no comparison). */
export async function openRevisionSummary(listingId) {
  const row = await queryOne(
    `SELECT r.* FROM listings l JOIN listing_revisions r ON r.id = l.pending_revision_id WHERE l.id = ?`,
    [listingId]
  );
  return serializeRevision(row);
}

/** The open revision with its comparison, for a moderator. */
export async function revisionForReview(listingId) {
  const row = await queryOne(
    `SELECT r.* FROM listings l JOIN listing_revisions r ON r.id = l.pending_revision_id WHERE l.id = ?`,
    [listingId]
  );
  if (!row) return null;
  const before = json(row.approved_snapshot, {});
  const after = (await approvedSnapshot(listingId)) || {};
  return { ...serializeRevision(row), changes: compareDetails(before, after) };
}

/* -------------------------------------------------------------------------- */
/* Decisions                                                                   */
/* -------------------------------------------------------------------------- */

export async function ownerEmails(accountId) {
  const rows = await query(
    `SELECT DISTINCT u.email FROM account_members am JOIN users u ON u.id = am.user_id
      WHERE am.account_id = ? AND am.status = 'active' AND am.role = 'owner' AND u.deleted_at IS NULL AND u.email IS NOT NULL`,
    [accountId]
  );
  return rows.map((row) => row.email);
}

async function tellOwner(listing, { type, title, body, emailSubject, emailText }) {
  await notifyAccount(
    { accountId: listing.account_id, organizationId: listing.organization_id, agentId: listing.agent_id },
    {
      type,
      title: `${title}: ${listing.title ?? listing.reference}`,
      body,
      actionUrl: `/portal/listings/${listing.public_id}`,
      icon: type.endsWith("rejected") ? "alert" : "check",
      subjectType: "listing",
      subjectId: listing.id,
      data: { reference: listing.reference },
    }
  );
  const emails = await ownerEmails(listing.account_id).catch(() => []);
  const link = `${String(env.FRONTEND_URL || "").replace(/\/$/, "")}/portal/listings/${listing.public_id}`;
  for (const to of emails) {
    await sendMail({ to, subject: emailSubject, text: `${emailText}\n\n${link}` }).catch((error) =>
      logger.warn({ err: error, listingId: listing.id }, "revision email not sent")
    );
  }
}

/** Tells the company's own systems about a decision on its changes (webhook, Phase 6). */
async function emitRevisionEvent(listing, event, extra = {}) {
  try {
    const { enqueueEvent } = await import("../leads/webhooks.service.js");
    const externalId = await queryOne(
      `SELECT er.external_id FROM external_references er JOIN integration_connections ic ON ic.id = er.connection_id
        WHERE er.entity_type = 'listing' AND er.entity_id = ? AND ic.account_id = ? LIMIT 1`,
      [listing.id, listing.account_id]
    );
    await enqueueEvent({
      accountId: listing.account_id,
      event,
      data: { listing: { id: listing.public_id, reference: listing.reference, externalId: externalId?.external_id ?? null, title: listing.title }, ...extra },
    });
  } catch (error) {
    logger.warn({ err: error, listingId: listing.id }, "revision event not recorded");
  }
}

async function loadForDecision(listingId) {
  const listing = await queryOne(
    `SELECT l.id, l.public_id, l.reference, l.title, l.status, l.account_id, l.organization_id, l.agent_id,
            l.pending_revision_id, r.status AS revision_status
       FROM listings l LEFT JOIN listing_revisions r ON r.id = l.pending_revision_id
      WHERE l.id = ?`,
    [listingId]
  );
  if (!listing?.pending_revision_id) throw AppError.conflict("This listing has no changes waiting for approval.");
  return listing;
}

/** Publishes the listing as it now stands. */
export async function approveRevision({ listingId, userId }) {
  const listing = await loadForDecision(listingId);
  if (listing.revision_status !== "pending") throw AppError.conflict("These changes were already sent back to the owner.");
  const { rewriteCanonicalPath } = await import("./listings.service.js");
  await withTransaction(async (connection) => {
    await execute(
      "UPDATE listing_revisions SET status = 'approved', reviewed_by_user_id = ?, reviewed_at = NOW(3) WHERE id = ?",
      [userId ?? null, listing.pending_revision_id],
      connection
    );
    await execute("UPDATE listings SET pending_revision_id = NULL WHERE id = ?", [listingId], connection);
    // The URL follows the approved title and location only now.
    await rewriteCanonicalPath(listingId, connection);
  });
  await refreshListingSearch(listingId);
  await emitRevisionEvent(listing, "listing.changes_approved");
  await tellOwner(listing, {
    type: "listing.revision_approved",
    title: "Your changes are live",
    body: null,
    emailSubject: `Your changes to ${listing.title} are live`,
    emailText: `LivFinder approved your changes to ${listing.title} (${listing.reference}). The listing now shows them.`,
  });
  return { status: "approved" };
}

/** Sends the changes back with reasons; the approved version stays live. */
export async function rejectRevision({ listingId, userId, reason, fields = null }) {
  const listing = await loadForDecision(listingId);
  if (!reason?.trim()) throw AppError.validation("Some information is invalid.", { reason: "Tell the owner what needs fixing." });
  await execute(
    `UPDATE listing_revisions
        SET status = 'rejected', reviewed_by_user_id = ?, reviewed_at = NOW(3), rejection_reason = ?, rejection_fields = ?
      WHERE id = ?`,
    [userId ?? null, reason.trim().slice(0, 1000), fields ? JSON.stringify(fields) : null, listing.pending_revision_id]
  );
  const issues = fields ? Object.entries(fields).map(([field, message]) => `- ${field}: ${message}`).join("\n") : "";
  await emitRevisionEvent(listing, "listing.changes_rejected", { reason: reason.trim(), fields: fields || {} });
  await tellOwner(listing, {
    type: "listing.revision_rejected",
    title: "Your changes were not approved",
    body: reason.trim(),
    emailSubject: `Your changes to ${listing.title} need attention`,
    emailText: `LivFinder did not approve your latest changes to ${listing.title} (${listing.reference}). The listing still shows the last approved version.\n\nReason: ${reason.trim()}${issues ? `\n\n${issues}` : ""}\n\nFix the listing and save it again to resubmit.`,
  });
  return { status: "rejected" };
}
