import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { callProcedure, execute, queryOne } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { serializeProjectDetail } from "../../serializers/project.js";
import { sendMail } from "../system/mail.service.js";
import { notifyAccount } from "../system/notifications.service.js";
import * as searchRepo from "../search/search.repository.js";
import { compareDetails, json, ownerEmails, serializeRevision } from "../listings/listingRevisions.service.js";
import * as projectsRepo from "./projects.repository.js";

/**
 * Pending revisions for developments (migration 0061): the rule listings follow (0060), for a
 * published development. A developer's change waits for a moderator while the site keeps the
 * approved version.
 *
 * The first change opens a revision holding the approved public page (with and without gated
 * documents) and the developer's full record as approved, for the comparison, and points
 * `projects.pending_revision_id` at it. While it is set the public page is served from the
 * snapshot, `sp_refresh_project_search` keeps the approved row, and `upsertDevelopment` does not
 * rebuild the canonical path. Approving publishes the development as it now stands; rejecting
 * keeps the approved version live and sends the reasons back. An admin's own publication decision
 * on the whole development (unpublish, reject, archive) closes the revision.
 */

const LIVE_FIELDS = ["viewCount", "inquiryCount", "favouriteCount", "listings", "related", "activeListingCount"];

/** The public page for a row of the project projection. */
export async function projectPublicDetail(row, { includeGatedDocuments = false } = {}) {
  const children = await projectsRepo.getProjectChildren(row.project_id, { includeGatedDocuments });
  const [listings, related] = await Promise.all([
    // The project's own inventory, through the listing search so publication,
    // moderation and expiry are applied by the one place that owns those rules.
    searchRepo.searchListings({ category: "real-estate", projectId: row.project_id }, { limit: 12 }),
    projectsRepo.getRelatedProjects(row, { limit: 6 }),
  ]);
  return serializeProjectDetail({ row, ...children, listings: listings.rows, related });
}

async function reviewRecord(publicId) {
  // Imported lazily: the admin catalog imports a good deal, and only this needs it.
  const { getAdminDevelopment } = await import("../admin/admin.catalog.js");
  return getAdminDevelopment(publicId);
}

/**
 * Call before applying a developer's change. On a published development it opens (or reopens)
 * the revision so the approved version is captured first. Returns the revision id, or null.
 */
export async function beginDeveloperChange({ projectId, userId, change }) {
  const current = await queryOne(
    "SELECT public_id, moderation_status, is_publicly_visible, pending_revision_id FROM projects WHERE id = ? AND deleted_at IS NULL",
    [projectId]
  );
  if (!current) return null;
  const live = current.moderation_status === "published" && Number(current.is_publicly_visible) === 1;
  if (!current.pending_revision_id && !live) return null;

  let snapshot = null;
  if (!current.pending_revision_id) {
    const row = await projectsRepo.getProjectRowByIdentifier(current.public_id);
    if (!row) return null;
    snapshot = {
      public: await projectPublicDetail(row),
      unlocked: await projectPublicDetail(row, { includeGatedDocuments: true }),
      review: await reviewRecord(current.public_id),
    };
  }
  const entry = { change: String(change || "Changed").slice(0, 200), at: new Date().toISOString(), userId: userId ?? null };

  return withTransaction(async (connection) => {
    const row = await queryOne("SELECT pending_revision_id FROM projects WHERE id = ? FOR UPDATE", [projectId], connection);
    if (row.pending_revision_id) {
      await execute(
        `UPDATE project_revisions
            SET status = 'pending', last_changed_at = NOW(3),
                change_log = JSON_ARRAY_APPEND(COALESCE(change_log, JSON_ARRAY()), '$', CAST(? AS JSON))
          WHERE id = ?`,
        [JSON.stringify(entry), row.pending_revision_id],
        connection
      );
      return Number(row.pending_revision_id);
    }
    if (!snapshot) return null;
    const inserted = await execute(
      `INSERT INTO project_revisions
         (public_id, project_id, status, approved_snapshot, change_log, submitted_by_user_id, submitted_at, last_changed_at)
       VALUES (?, ?, 'pending', ?, JSON_ARRAY(CAST(? AS JSON)), ?, NOW(3), NOW(3))`,
      [ulid(), projectId, JSON.stringify(snapshot), JSON.stringify(entry), userId ?? null],
      connection
    );
    await execute("UPDATE projects SET pending_revision_id = ? WHERE id = ?", [inserted.insertId, projectId], connection);
    return Number(inserted.insertId);
  });
}

/** Closes an open revision without a decision on it (the whole development was moderated). */
export async function closeOpenProjectRevision(projectId, connection, status = "superseded") {
  const row = await queryOne("SELECT pending_revision_id FROM projects WHERE id = ?", [projectId], connection);
  if (!row?.pending_revision_id) return false;
  await execute(
    "UPDATE project_revisions SET status = ?, reviewed_at = COALESCE(reviewed_at, NOW(3)) WHERE id = ?",
    [status, row.pending_revision_id],
    connection
  );
  await execute("UPDATE projects SET pending_revision_id = NULL WHERE id = ?", [projectId], connection);
  return true;
}

/** The public page while a revision is open: the approved snapshot with live counters. */
export async function frozenProjectDetail(projectId, liveDetail, { includeGatedDocuments = false } = {}) {
  const row = await queryOne(
    `SELECT r.approved_snapshot FROM projects p JOIN project_revisions r ON r.id = p.pending_revision_id WHERE p.id = ?`,
    [projectId]
  );
  const snapshot = json(row?.approved_snapshot);
  const page = snapshot?.[includeGatedDocuments ? "unlocked" : "public"];
  if (!page) return liveDetail;
  const frozen = { ...page };
  for (const key of LIVE_FIELDS) if (key in liveDetail) frozen[key] = liveDetail[key];
  return frozen;
}

async function openRevisionRow(projectId) {
  return queryOne(
    `SELECT r.* FROM projects p JOIN project_revisions r ON r.id = p.pending_revision_id WHERE p.id = ?`,
    [projectId]
  );
}

/** The open revision, for the developer's portal (no comparison). */
export async function openProjectRevisionSummary(projectId) {
  return serializeRevision(await openRevisionRow(projectId));
}

/** The open revision with its comparison, for a moderator. */
export async function projectRevisionForReview(projectId) {
  const row = await openRevisionRow(projectId);
  if (!row) return null;
  const project = await queryOne("SELECT public_id FROM projects WHERE id = ?", [projectId]);
  const before = json(row.approved_snapshot, {})?.review || {};
  const after = (await reviewRecord(project.public_id)) || {};
  return { ...serializeRevision(row), changes: compareDetails(before, after) };
}

async function tellDeveloper(project, { type, title, body, emailSubject, emailText }) {
  const portalUrl = `/portal/developments/${project.public_id}`;
  await notifyAccount(
    { accountId: project.account_id, organizationId: project.organization_id },
    {
      type,
      title: `${title}: ${project.name}`,
      body,
      actionUrl: portalUrl,
      icon: type.endsWith("rejected") ? "alert" : "check",
      subjectType: "project",
      subjectId: project.id,
      data: { slug: project.slug },
    }
  );
  const emails = await ownerEmails(project.account_id).catch(() => []);
  const link = `${String(env.FRONTEND_URL || "").replace(/\/$/, "")}${portalUrl}`;
  for (const to of emails) {
    await sendMail({ to, subject: emailSubject, text: `${emailText}\n\n${link}` }).catch((error) =>
      logger.warn({ err: error, projectId: project.id }, "development revision email not sent")
    );
  }
}

/** Tells the developer's own systems about a decision on its changes (webhook, Phase 6). */
async function emitProjectEvent(project, event, extra = {}) {
  try {
    const { enqueueEvent } = await import("../leads/webhooks.service.js");
    const externalId = await queryOne(
      `SELECT er.external_id FROM external_references er JOIN integration_connections ic ON ic.id = er.connection_id
        WHERE er.entity_type = 'project' AND er.entity_id = ? AND ic.account_id = ? LIMIT 1`,
      [project.id, project.account_id]
    );
    await enqueueEvent({
      accountId: project.account_id,
      event,
      data: { development: { id: project.public_id, externalId: externalId?.external_id ?? null, name: project.name }, ...extra },
    });
  } catch (error) {
    logger.warn({ err: error, projectId: project.id }, "revision event not recorded");
  }
}

async function loadForDecision(projectId) {
  const project = await queryOne(
    `SELECT p.id, p.public_id, p.slug, p.name, p.organization_id, o.account_id, p.pending_revision_id,
            r.status AS revision_status
       FROM projects p
       LEFT JOIN organizations o ON o.id = p.organization_id
       LEFT JOIN project_revisions r ON r.id = p.pending_revision_id
      WHERE p.id = ?`,
    [projectId]
  );
  if (!project?.pending_revision_id) throw AppError.conflict("This development has no changes waiting for approval.");
  return project;
}

/** Publishes the development as it now stands. */
export async function approveProjectRevision({ projectId, userId }) {
  const project = await loadForDecision(projectId);
  if (project.revision_status !== "pending") throw AppError.conflict("These changes were already sent back to the developer.");
  await withTransaction(async (connection) => {
    await execute(
      "UPDATE project_revisions SET status = 'approved', reviewed_by_user_id = ?, reviewed_at = NOW(3) WHERE id = ?",
      [userId ?? null, project.pending_revision_id],
      connection
    );
    await execute("UPDATE projects SET pending_revision_id = NULL, updated_at = NOW(3) WHERE id = ?", [projectId], connection);
    // The URL follows the approved name and location only now.
    await callProcedure("sp_rebuild_project_canonical_path", [projectId], connection);
  });
  await callProcedure("sp_refresh_project_search", [projectId]);
  await emitProjectEvent(project, "development.changes_approved");
  await tellDeveloper(project, {
    type: "project.revision_approved",
    title: "Your changes are live",
    body: null,
    emailSubject: `Your changes to ${project.name} are live`,
    emailText: `LivFinder approved your changes to ${project.name}. The development now shows them.`,
  });
  return { status: "approved" };
}

/** Sends the changes back with reasons; the approved version stays live. */
export async function rejectProjectRevision({ projectId, userId, reason, fields = null }) {
  const project = await loadForDecision(projectId);
  if (!reason?.trim()) throw AppError.validation("Some information is invalid.", { reason: "Tell the developer what needs fixing." });
  await execute(
    `UPDATE project_revisions
        SET status = 'rejected', reviewed_by_user_id = ?, reviewed_at = NOW(3), rejection_reason = ?, rejection_fields = ?
      WHERE id = ?`,
    [userId ?? null, reason.trim().slice(0, 1000), fields ? JSON.stringify(fields) : null, project.pending_revision_id]
  );
  const issues = fields ? Object.entries(fields).map(([field, message]) => `- ${field}: ${message}`).join("\n") : "";
  await emitProjectEvent(project, "development.changes_rejected", { reason: reason.trim(), fields: fields || {} });
  await tellDeveloper(project, {
    type: "project.revision_rejected",
    title: "Your changes were not approved",
    body: reason.trim(),
    emailSubject: `Your changes to ${project.name} need attention`,
    emailText: `LivFinder did not approve your latest changes to ${project.name}. The development still shows the last approved version.\n\nReason: ${reason.trim()}${issues ? `\n\n${issues}` : ""}\n\nFix the development and save it again to resubmit.`,
  });
  return { status: "rejected" };
}
