import { z } from "zod";
import { query, queryOne, queryValue, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { slugify } from "../../utils/slug.js";
import { resolveCategory } from "../../utils/categories.js";
import { changeListingStatus, softDeleteListing, syncAccountListingUsageForListing } from "../listings/listings.service.js";
import { refreshListingSearch, recordStatusChange } from "../listings/listings.repository.js";
import { htmlToBlocks } from "../../serializers/editorial.js";
import { callProcedure } from "../../db/query.js";
import { splitPhone } from "../../utils/phone.js";
import { notifyListingModeration, notifyVerificationDecision } from "../system/notifications.service.js";

/**
 * Admin write operations.
 *
 * Every one of these is a real business action with a status history or audit
 * row behind it — approving a listing writes to `listing_status_history`,
 * verifying an organisation resolves the `verification_request`, and so on.
 */

/* -------------------------------------------------------------------------- */
/* Listing moderation                                                          */
/* -------------------------------------------------------------------------- */

export const moderateListingSchema = z.object({
  decision: z.enum(["approve", "reject", "flag", "unpublish", "archive", "feature", "unfeature"]),
  reason: z.string().trim().max(500).optional(),
  note: z.string().trim().max(1000).optional(),
});

export async function moderateListing({ identifier, decision, reason, note, userId }) {
  const listing = await queryOne(
    `SELECT id, public_id, reference, title, status, moderation_status, is_featured,
            account_id, organization_id, agent_id
       FROM listings WHERE (public_id = ? OR reference = ?) AND deleted_at IS NULL LIMIT 1`,
    [identifier, identifier]
  );
  if (!listing) throw AppError.notFound("That listing was not found.");

  if (decision === "feature" || decision === "unfeature") {
    await execute("UPDATE listings SET is_featured = ? WHERE id = ?", [decision === "feature" ? 1 : 0, listing.id]);
    await refreshListingSearch(listing.id);
    return { id: listing.public_id, featured: decision === "feature" };
  }

  if (decision === "approve") {
    await withTransaction(async (connection) => {
      await execute(
        `UPDATE listings
            SET status = 'active', moderation_status = 'approved', rejection_reason = NULL,
                published_at = COALESCE(published_at, NOW(3)),
                expires_at = COALESCE(expires_at, DATE_ADD(NOW(3), INTERVAL 90 DAY))
          WHERE id = ?`,
        [listing.id],
        connection
      );
      await recordStatusChange(
        { listingId: listing.id, fromStatus: listing.status, toStatus: "active", userId, reason: note || "approved" },
        connection
      );
      // Approving e.g. an archived listing takes an allowance slot again.
      await syncAccountListingUsageForListing(listing.id, connection);
      await execute(
        "UPDATE moderation_queue SET status = 'approved', reviewed_by_user_id = ?, reviewed_at = NOW(3), decision_note = ? WHERE subject_type = 'listing' AND subject_id = ? AND status = 'pending'",
        [userId, note || null, listing.id],
        connection
      );
    });
    await refreshListingSearch(listing.id);
    // The owner has no other way to learn the outcome — a rejected listing simply stops
    // appearing, and the reason is the only actionable part of the decision.
    await notifyListingModeration({ listing, decision, reason: note });
    return { id: listing.public_id, status: "approved" };
  }

  if (decision === "reject") {
    if (!reason) throw AppError.validation("Some information is invalid.", { reason: "Give a reason for the rejection." });
    await withTransaction(async (connection) => {
      await execute(
        "UPDATE listings SET status = 'rejected', moderation_status = 'rejected', rejection_reason = ? WHERE id = ?",
        [reason, listing.id],
        connection
      );
      await recordStatusChange(
        { listingId: listing.id, fromStatus: listing.status, toStatus: "rejected", userId, reason },
        connection
      );
      await syncAccountListingUsageForListing(listing.id, connection);
      await execute(
        "UPDATE moderation_queue SET status = 'rejected', reviewed_by_user_id = ?, reviewed_at = NOW(3), decision_note = ? WHERE subject_type = 'listing' AND subject_id = ? AND status = 'pending'",
        [userId, reason, listing.id],
        connection
      );
    });
    await refreshListingSearch(listing.id);
    await notifyListingModeration({ listing, decision, reason });
    return { id: listing.public_id, status: "rejected" };
  }

  if (decision === "flag") {
    await execute("UPDATE listings SET moderation_status = 'flagged' WHERE id = ?", [listing.id]);
    await notifyListingModeration({ listing, decision, reason: note });
    return { id: listing.public_id, status: "flagged" };
  }

  const toStatus = decision === "archive" ? "archived" : "withdrawn";
  await changeListingStatus({ listing, toStatus, reason: reason || note, userId, byPlatform: true });
  await notifyListingModeration({ listing, decision, reason: reason || note });
  return { id: listing.public_id, status: toStatus };
}

export async function deleteAdminListing({ identifier, userId }) {
  const listing = await queryOne(
    "SELECT id, public_id, status FROM listings WHERE (public_id = ? OR reference = ?) AND deleted_at IS NULL",
    [identifier, identifier]
  );
  if (!listing) throw AppError.notFound("That listing was not found.");
  await softDeleteListing({ listing, userId });
  return { id: listing.public_id, deleted: true };
}

/* -------------------------------------------------------------------------- */
/* Verification and account state                                              */
/* -------------------------------------------------------------------------- */

export const verificationDecisionSchema = z.object({
  decision: z.enum(["approve", "reject", "request_changes"]),
  note: z.string().trim().max(1000).optional(),
  reason: z.string().trim().max(500).optional(),
});

export async function decideVerification({ subjectType, identifier, decision, note, reason, userId }) {
  const table = subjectType === "organization" ? "organizations" : subjectType === "agent" ? "agents" : "accounts";
  const subject = await queryOne(`SELECT id, public_id FROM ${table} WHERE public_id = ? LIMIT 1`, [identifier]);
  if (!subject) throw AppError.notFound("That record was not found.");

  const status = decision === "approve" ? "approved" : decision === "reject" ? "rejected" : "in_review";

  await withTransaction(async (connection) => {
    await execute(
      `UPDATE verification_requests
          SET status = ?, reviewed_by_user_id = ?, reviewed_at = NOW(3),
              decision_notes = ?, rejection_reason = ?
        WHERE subject_type = ? AND subject_id = ? AND status IN ('pending','in_review')`,
      [status, userId, note || null, decision === "reject" ? reason || null : null, subjectType, subject.id],
      connection
    );

    if (subjectType === "organization") {
      await execute(
        `UPDATE organizations
            SET verification_status = ?, verified_at = ?, status = ?, is_publicly_visible = ?
          WHERE id = ?`,
        [
          decision === "approve" ? "verified" : decision === "reject" ? "rejected" : "pending",
          decision === "approve" ? new Date() : null,
          decision === "approve" ? "active" : "pending",
          decision === "approve" ? 1 : 0,
          subject.id,
        ],
        connection
      );
      // The account behind the organisation moves with it.
      await execute(
        `UPDATE accounts a JOIN organizations o ON o.account_id = a.id
            SET a.verification_status = ?, a.status = ?, a.verified_at = ?
          WHERE o.id = ?`,
        [
          decision === "approve" ? "verified" : decision === "reject" ? "rejected" : "pending",
          decision === "approve" ? "active" : "pending",
          decision === "approve" ? new Date() : null,
          subject.id,
        ],
        connection
      );
    } else if (subjectType === "agent") {
      await execute(
        "UPDATE agents SET verification_status = ?, verified_at = ?, status = ? WHERE id = ?",
        [
          decision === "approve" ? "verified" : decision === "reject" ? "rejected" : "pending",
          decision === "approve" ? new Date() : null,
          decision === "approve" ? "active" : "pending",
          subject.id,
        ],
        connection
      );
    } else {
      await execute(
        "UPDATE accounts SET verification_status = ?, verified_at = ?, status = ? WHERE id = ?",
        [
          decision === "approve" ? "verified" : decision === "reject" ? "rejected" : "pending",
          decision === "approve" ? new Date() : null,
          decision === "approve" ? "active" : "pending",
          subject.id,
        ],
        connection
      );
    }
  });

  return { id: subject.public_id, decision, status };
}

export const accountStateSchema = z.object({
  status: z.enum(["active", "pending", "suspended", "archived", "closed", "inactive", "draft"]),
  reason: z.string().trim().max(500).optional(),
});

export async function setOrganizationState({ identifier, status, reason, userId }) {
  const organization = await queryOne("SELECT id, public_id, account_id FROM organizations WHERE public_id = ? LIMIT 1", [identifier]);
  if (!organization) throw AppError.notFound("That company was not found.");
  const allowed = new Set(["draft", "pending", "active", "suspended", "archived"]);
  if (!allowed.has(status)) throw AppError.badRequest("Unsupported status for a company.");

  await withTransaction(async (connection) => {
    await execute(
      "UPDATE organizations SET status = ?, is_publicly_visible = ? WHERE id = ?",
      [status, status === "active" ? 1 : 0, organization.id],
      connection
    );
    if (organization.account_id) {
      await execute(
        "UPDATE accounts SET status = ? WHERE id = ?",
        [status === "active" ? "active" : status === "suspended" ? "suspended" : status === "archived" ? "closed" : "pending", organization.account_id],
        connection
      );
    }
    // Suspending a company must take its listings off the marketplace.
    if (status !== "active") {
      await execute(
        "UPDATE listings SET status = 'withdrawn' WHERE organization_id = ? AND status = 'active'",
        [organization.id],
        connection
      );
    }
  });
  await callProcedure("sp_refresh_listing_search", [null]);
  return { id: organization.public_id, status };
}

export async function setAgentState({ identifier, status, reason, userId }) {
  const agent = await queryOne("SELECT id, public_id FROM agents WHERE public_id = ? LIMIT 1", [identifier]);
  if (!agent) throw AppError.notFound("That agent was not found.");
  const allowed = new Set(["draft", "pending", "active", "inactive", "suspended"]);
  if (!allowed.has(status)) throw AppError.badRequest("Unsupported status for an agent.");
  await execute(
    "UPDATE agents SET status = ?, is_publicly_visible = ? WHERE id = ?",
    [status, status === "active" ? 1 : 0, agent.id]
  );
  await callProcedure("sp_refresh_listing_search", [null]);
  return { id: agent.public_id, status };
}

/**
 * Two access-management rules the admin UI shows as disabled menu items. They are enforced here
 * because the UI is only presentation: an admin who crafts the request by hand must hit the same
 * wall. Both protect against locking the platform out of its own back office.
 *
 *  - An admin cannot move their own account out of `active` (self-lockout).
 *  - The last active Super Administrator cannot be deactivated, nor have the role taken away,
 *    while no other active Super Administrator exists.
 *
 * `nextRoleIds` is only supplied by the internal-user editor; a status change passes it as null.
 */
/**
 * Resolved by code, not assumed to be id 1. `roles.code` is the stable identifier; the id is
 * whatever the seed loader assigned, and the two only agree by coincidence.
 */
let superAdminRoleId = null;
async function getSuperAdminRoleId(connection) {
  if (superAdminRoleId != null) return superAdminRoleId;
  superAdminRoleId = await queryValue("SELECT id FROM roles WHERE code = 'super_admin' LIMIT 1", [], connection);
  return superAdminRoleId;
}

async function assertAccessChangeAllowed({ targetUserId, actingUserId, nextStatus, nextRoleIds }, connection) {
  const isSelf = actingUserId != null && String(targetUserId) === String(actingUserId);
  const leavesActive = nextStatus != null && nextStatus !== "active";

  if (isSelf && leavesActive) {
    throw AppError.forbidden("You cannot change your own account status. Ask another administrator to do it.");
  }

  const superAdminId = await getSuperAdminRoleId();
  const losesSuperAdmin = Array.isArray(nextRoleIds) && !nextRoleIds.map(Number).includes(Number(superAdminId));
  if (!leavesActive && !losesSuperAdmin) return;

  const isSuperAdmin = await queryValue(
    `SELECT 1 FROM user_roles ur JOIN users u ON u.id = ur.user_id
      WHERE ur.user_id = ? AND ur.role_id = ? AND u.status = 'active' AND u.deleted_at IS NULL LIMIT 1`,
    [targetUserId, superAdminId],
    connection
  );
  if (!isSuperAdmin) return;

  const otherActive = await queryValue(
    `SELECT COUNT(*) FROM user_roles ur JOIN users u ON u.id = ur.user_id
      WHERE ur.role_id = ? AND ur.user_id <> ? AND u.status = 'active' AND u.deleted_at IS NULL`,
    [superAdminId, targetUserId],
    connection
  );
  if (Number(otherActive) > 0) return;

  throw AppError.conflict(
    "This is the only active Super Administrator. Assign Super Administrator to another account before changing this one."
  );
}

/**
 * Ends every live session for a user and forces a fresh sign-in.
 *
 * Bumping `session_epoch` is what actually does it: `resolveSession` compares the session's
 * stored epoch against the user's, so every issued cookie stops resolving at once — including
 * ones on devices nobody has access to. Revoking the rows as well is belt and braces, and it
 * gives the session list something honest to show.
 *
 * The password is left alone. Invalidating credentials and invalidating sessions are different
 * remedies, and conflating them means "sign this person out" also locks them out.
 */
export async function resetUserAccess({ identifier, actorUserId }) {
  const user = await queryOne(
    "SELECT id, public_id, display_name FROM users WHERE (public_id = ? OR email = ?) AND deleted_at IS NULL LIMIT 1",
    [identifier, identifier]
  );
  if (!user) throw AppError.notFound("That user was not found.");

  let revoked = 0;
  await withTransaction(async (connection) => {
    await execute("UPDATE users SET session_epoch = session_epoch + 1 WHERE id = ?", [user.id], connection);
    const result = await execute(
      "UPDATE user_sessions SET revoked_at = NOW(3) WHERE user_id = ? AND revoked_at IS NULL",
      [user.id],
      connection
    );
    revoked = result.affectedRows ?? 0;
    // Outstanding password-reset and verification links are invalidated too: an unused link
    // is a live credential, and "reset this person's access" has to mean all of it.
    await execute(
      "UPDATE user_tokens SET consumed_at = NOW(3) WHERE user_id = ? AND consumed_at IS NULL AND expires_at > NOW(3)",
      [user.id],
      connection
    ).catch(() => {});
  });

  return { id: user.public_id, sessionsRevoked: revoked, actorUserId };
}

export async function setUserState({ identifier, status, reason, userId }) {
  const user = await queryOne("SELECT id, public_id FROM users WHERE public_id = ? AND deleted_at IS NULL LIMIT 1", [identifier]);
  if (!user) throw AppError.notFound("That user was not found.");
  const allowed = new Set(["active", "suspended", "banned", "closed", "pending_verification"]);
  if (!allowed.has(status)) throw AppError.badRequest("Unsupported status for a user.");
  await assertAccessChangeAllowed({ targetUserId: user.id, actingUserId: userId, nextStatus: status, nextRoleIds: null });
  await withTransaction(async (connection) => {
    await execute(
      "UPDATE users SET status = ?, suspended_reason = ? WHERE id = ?",
      [status, status === "suspended" || status === "banned" ? reason || null : null, user.id],
      connection
    );
    // Suspension ends every live session immediately.
    if (status !== "active") {
      await execute("UPDATE users SET session_epoch = session_epoch + 1 WHERE id = ?", [user.id], connection);
      await execute("UPDATE user_sessions SET revoked_at = NOW(3) WHERE user_id = ? AND revoked_at IS NULL", [user.id], connection);
    }
  });
  return { id: user.public_id, status };
}

/* -------------------------------------------------------------------------- */
/* Category access                                                             */
/* -------------------------------------------------------------------------- */

export const categoryAccessSchema = z.object({
  categoryId: z.string().trim().min(1).max(40),
  decision: z.enum(["approve", "reject", "revoke"]),
  note: z.string().trim().max(1000).optional(),
  listingQuota: z.coerce.number().int().min(0).max(100000).optional().nullable(),
});

/**
 * Grant, reject or revoke a category for one account — a company or an
 * individual. The caller resolves `accountId` from an organisation public id or
 * a user public id; every category (Real Estate Developments included) is a row
 * in `account_category_access`.
 */
async function resolveAccountId({ accountId, organizationPublicId, userPublicId }) {
  if (accountId) return Number(accountId);
  if (organizationPublicId) {
    return queryValue("SELECT account_id FROM organizations WHERE public_id = ? AND deleted_at IS NULL LIMIT 1", [organizationPublicId]);
  }
  if (userPublicId) {
    return queryValue(
      `SELECT am.account_id
         FROM users u
         JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
        WHERE u.public_id = ? AND u.deleted_at IS NULL
        LIMIT 1`,
      [userPublicId]
    );
  }
  return null;
}

export async function decideCategoryAccess({ accountId, organizationPublicId, userPublicId, categoryId, decision, note, listingQuota, userId }) {
  const resolvedAccountId = await resolveAccountId({ accountId, organizationPublicId, userPublicId });
  if (!resolvedAccountId) throw AppError.notFound("That account was not found.");
  accountId = resolvedAccountId;
  const definition = resolveCategory(categoryId);
  if (!definition) throw AppError.validation("Some information is invalid.", { categoryId: "Unknown category." });

  const status = decision === "approve" ? "approved" : decision === "reject" ? "rejected" : "revoked";
  const result = await execute(
    `UPDATE account_category_access aca
       JOIN categories c ON c.id = aca.category_id
        SET aca.status = ?, aca.reviewed_at = NOW(3), aca.reviewed_by_user_id = ?,
            aca.notes = ?, aca.listing_quota = COALESCE(?, aca.listing_quota)
      WHERE aca.account_id = ? AND COALESCE(c.root_category_id, c.id) = ?`,
    [status, userId, note || null, listingQuota ?? null, accountId, definition.rootId]
  );
  if (!result.affectedRows) {
    await execute(
      `INSERT INTO account_category_access
         (account_id, category_id, status, listing_quota, listing_used, requested_at,
          reviewed_at, reviewed_by_user_id, notes, created_at)
       VALUES (?, ?, ?, ?, 0, NOW(3), NOW(3), ?, ?, NOW(3))`,
      [accountId, definition.rootId, status, listingQuota ?? null, userId, note || null]
    );
  }
  return { accountId: String(accountId), categoryId: definition.frontendId, status };
}

/* -------------------------------------------------------------------------- */
/* Leads                                                                       */
/* -------------------------------------------------------------------------- */

/**
 * The admin Leads screen speaks a pipeline vocabulary (new / qualified / follow-up / viewing /
 * closed / lost); the table stores a coarse `status` plus a stage. Both are accepted here: a
 * screen value becomes the status + stage the Leads summary counts it under (admin.crm.js
 * leadSummary), so the tab a lead is moved to is the tab it then appears in.
 */
const SCREEN_LEAD_STATUS = {
  new: { status: "open", stageType: "new" },
  qualified: { status: "open", stageType: "qualified" },
  "follow-up": { status: "open", stageType: "contacted" },
  viewing: { status: "open", stageType: "proposal" },
  closed: { status: "won", stageType: "won" },
  lost: { status: "lost", stageType: "lost" },
};

export const leadUpdateSchema = z.object({
  status: z
    .enum(["open", "won", "lost", "disqualified", "archived", "new", "qualified", "follow-up", "viewing", "closed"])
    .optional(),
  stageId: z.coerce.number().int().positive().optional(),
  ownerAgentId: z.string().max(64).nullable().optional(),
  // The edit drawer offered "medium"; the column's word for it is "normal".
  priority: z
    .enum(["low", "normal", "medium", "high", "urgent"])
    .transform((value) => (value === "medium" ? "normal" : value))
    .optional(),
  note: z.string().trim().max(2000).optional(),
});

export async function updateAdminLead({ identifier, payload, userId }) {
  const lead = await queryOne(
    `SELECT id, public_id, pipeline_id, stage_id, stage_type, status, organization_id, contact_id, primary_listing_id
       FROM leads WHERE (public_id = ? OR reference = ?) AND deleted_at IS NULL`,
    [identifier, identifier]
  );
  if (!lead) throw AppError.notFound("That lead was not found.");

  const screen = SCREEN_LEAD_STATUS[payload.status];
  const status = screen ? screen.status : payload.status;

  await withTransaction(async (connection) => {
    const assignments = ["last_activity_at = NOW(3)"];
    const params = [];
    if (status) {
      assignments.push("status = ?");
      params.push(status);
      assignments.push(status === "open" ? "closed_at = NULL" : "closed_at = COALESCE(closed_at, NOW(3))");
    }
    if (payload.priority) {
      assignments.push("priority = ?");
      params.push(payload.priority);
    }
    let stage = null;
    if (payload.stageId) {
      stage = await queryOne("SELECT id, stage_type FROM lead_pipeline_stages WHERE id = ?", [payload.stageId], connection);
      if (!stage) throw AppError.validation("Some information is invalid.", { stageId: "Unknown stage." });
    } else if (screen) {
      stage = await queryOne(
        `SELECT id, stage_type FROM lead_pipeline_stages
          WHERE stage_type = ? AND is_active = 1 AND (pipeline_id = ? OR ? IS NULL)
          ORDER BY pipeline_id = ? DESC, sort_order ASC LIMIT 1`,
        [screen.stageType, lead.pipeline_id, lead.pipeline_id, lead.pipeline_id],
        connection
      );
    }
    if (stage && stage.id !== lead.stage_id) {
      assignments.push("stage_id = ?", "stage_type = ?", "stage_entered_at = NOW(3)");
      params.push(stage.id, stage.stage_type);
      // Real columns are `reason` / `created_at` (+ the from/to stage types); this used to write
      // `note` / `changed_at`, which do not exist, so every stage change from the admin 500'd.
      await execute(
        `INSERT INTO lead_stage_history
           (lead_id, from_stage_id, to_stage_id, from_stage_type, to_stage_type, changed_by_user_id, changed_by, reason, created_at)
         VALUES (?, ?, ?, ?, ?, ?, 'user', ?, NOW(3))`,
        [lead.id, lead.stage_id, stage.id, lead.stage_type, stage.stage_type, userId, payload.note ? payload.note.slice(0, 300) : null],
        connection
      );
    }
    if (payload.ownerAgentId !== undefined) {
      const agent = payload.ownerAgentId
        ? await queryOne("SELECT id FROM agents WHERE public_id = ? AND deleted_at IS NULL", [payload.ownerAgentId], connection)
        : null;
      if (payload.ownerAgentId && !agent) {
        throw AppError.validation("Some information is invalid.", { ownerAgentId: "That agent was not found." });
      }
      assignments.push("owner_agent_id = ?", "assigned_at = NOW(3)", "assignment_method = 'manual'", "reassignment_count = reassignment_count + 1");
      params.push(agent?.id ?? null);
    }
    await execute(`UPDATE leads SET ${assignments.join(", ")} WHERE id = ?`, [...params, lead.id], connection);

    if (payload.note) {
      // `activities` needs its polymorphic subject and uses `subject_line` / `user_id`; this wrote
      // `subject` / `created_by_user_id` (neither exists) and no subject, so every admin note 500'd.
      await execute(
        `INSERT INTO activities
           (public_id, organization_id, subject_type, subject_id, lead_id, contact_id,
            activity_type, direction, subject_line, body, user_id, occurred_at, created_at, updated_at)
         VALUES (?, COALESCE(?, (SELECT organization_id FROM listings WHERE id = ?)), 'lead', ?, ?, ?,
                 'note', 'internal', 'Admin note', ?, ?, NOW(3), NOW(3), NOW(3))`,
        [ulid(), lead.organization_id, lead.primary_listing_id, lead.id, lead.id, lead.contact_id, payload.note, userId],
        connection
      );
    }
  });

  return { id: lead.public_id, updated: true };
}

/* -------------------------------------------------------------------------- */
/* Reviews and reports                                                         */
/* -------------------------------------------------------------------------- */

export const reviewModerationSchema = z.object({
  decision: z.enum(["publish", "reject", "archive", "restore"]),
  note: z.string().trim().max(1000).optional(),
});

export async function moderateReview({ identifier, decision, note, userId }) {
  const review = await queryOne("SELECT id, public_id, status FROM reviews WHERE public_id = ? AND deleted_at IS NULL", [identifier]);
  if (!review) throw AppError.notFound("That review was not found.");
  const status = decision === "publish" ? "published" : decision === "reject" ? "rejected" : decision === "archive" ? "archived" : "pending";
  await execute(
    `UPDATE reviews SET status = ?, moderation_note = ?, moderated_by_user_id = ?, moderated_at = NOW(3),
            published_at = IF(? = 'published', COALESCE(published_at, NOW(3)), published_at)
      WHERE id = ?`,
    [status, note || null, userId, status, review.id]
  );
  return { id: review.public_id, status };
}

/** The stored `reports.resolution` vocabulary, published to the admin UI. */
export const REPORT_RESOLUTIONS = Object.freeze([
  "no_action", "content_removed", "content_edited", "listing_unpublished",
  "account_warned", "account_suspended", "account_banned", "escalated_legal",
]);

export const reportActionSchema = z.object({
  // `triage` moves a report into review without touching its assignment. Without it
  // the admin's "Start Review" button had to send `assign` with no assignee, which
  // cleared whoever was already on the report.
  action: z.enum(["assign", "triage", "resolve", "dismiss", "escalate", "reopen", "note"]),
  assignToUserId: z.string().max(64).optional(),
  // `reports.resolution` is an enum. This accepted any string up to 60 characters, so
  // the admin's own resolution list ("Content corrected", "Warning issued") was
  // rejected by MySQL and every Resolve returned 500.
  resolution: z.enum(REPORT_RESOLUTIONS).optional(),
  note: z.string().trim().max(1000).optional(),
  priority: z.enum(["low", "normal", "high", "urgent"]).optional(),
});

export async function actOnReport({ identifier, payload, userId }) {
  const report = await queryOne(
    "SELECT id, public_id, status, assigned_to_user_id FROM reports WHERE public_id = ? OR reference = ? LIMIT 1",
    [identifier, identifier]
  );
  if (!report) throw AppError.notFound("That report was not found.");

  // `reports.status` is enum('new','triaged','in_review','escalated','resolved',
  // 'dismissed','duplicate'). Reopening wrote "open", which is not one of them: under
  // STRICT_TRANS_TABLES that is an error, so the Reopen action could only ever fail.
  // A reopened report goes back to the queue as `triaged` — it has been looked at.
  const nextStatus = {
    assign: "in_review",
    triage: "in_review",
    resolve: "resolved",
    dismiss: "dismissed",
    escalate: "escalated",
    reopen: "triaged",
    note: report.status,
  }[payload.action];

  await withTransaction(async (connection) => {
    const assignments = ["status = ?"];
    const params = [nextStatus];
    if (payload.priority) {
      assignments.push("priority = ?");
      params.push(payload.priority);
    }
    if (payload.action === "assign") {
      const assignee = payload.assignToUserId
        ? await queryOne("SELECT id FROM users WHERE public_id = ? AND deleted_at IS NULL", [payload.assignToUserId], connection)
        : null;
      if (payload.assignToUserId && !assignee) {
        throw AppError.validation("Some information is invalid.", { assignToUserId: "That user was not found." });
      }
      assignments.push("assigned_to_user_id = ?", "assigned_at = NOW(3)");
      params.push(assignee?.id ?? null);
    }
    if (payload.action === "resolve" || payload.action === "dismiss") {
      // A dismissal is by definition "nothing was done to the content"; the reason for
      // it belongs in the note. Resolving without naming an outcome means the same.
      assignments.push("resolution = ?", "resolution_note = ?", "resolved_by_user_id = ?", "resolved_at = NOW(3)");
      params.push(payload.action === "dismiss" ? "no_action" : payload.resolution || "no_action", payload.note || null, userId);
    }
    await execute(`UPDATE reports SET ${assignments.join(", ")} WHERE id = ?`, [...params, report.id], connection);

    /**
     * `report_actions.action_type` is its own enum, in the past tense:
     * created/assigned/unassigned/status_changed/priority_changed/note_added/
     * escalated/resolved/dismissed/reopened/content_actioned.
     *
     * The request verb was inserted verbatim — "assign", "resolve", "note" — and not
     * one of those is a member. Under STRICT_TRANS_TABLES MySQL rejects the row, the
     * transaction rolls back, and the request 500s: every admin report action failed,
     * for every action, since the endpoint was written.
     */
    const actionType = {
      assign: payload.assignToUserId ? "assigned" : "unassigned",
      triage: "status_changed",
      resolve: "resolved",
      dismiss: "dismissed",
      escalate: "escalated",
      reopen: "reopened",
      note: "note_added",
    }[payload.action];

    await execute(
      `INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, is_internal, created_at)
       VALUES (?, ?, ?, ?, ?, ?, 1, NOW(3))`,
      [report.id, actionType, report.status, nextStatus, payload.note || null, userId],
      connection
    );
  });

  return { id: report.public_id, status: nextStatus };
}

/* -------------------------------------------------------------------------- */
/* Editorial                                                                   */
/* -------------------------------------------------------------------------- */

export const articleSchema = z.object({
  title: z.string().trim().min(3).max(255),
  slug: z.string().trim().max(280).optional(),
  excerpt: z.string().trim().max(600).optional().or(z.literal("")),
  contentHtml: z.string().max(500_000).optional().or(z.literal("")),
  postType: z.enum(["article", "guide", "news", "market_report", "press_release", "interview", "video", "case_study"]).optional(),
  status: z.enum(["draft", "in_review", "scheduled", "published", "archived"]).optional(),
  visibility: z.enum(["public", "members", "private"]).optional(),
  authorId: z.string().max(40).optional().nullable(),
  coverImageAssetId: z.string().max(40).optional().nullable(),
  coverImageAlt: z.string().trim().max(255).optional(),
  readingTimeMinutes: z.coerce.number().int().min(1).max(600).optional(),
  isFeatured: z.boolean().optional(),
  scheduledFor: z.string().max(40).optional().nullable(),
  categories: z.array(z.string().max(180)).max(10).optional(),
  topics: z.array(z.string().max(180)).max(10).optional(),
  tags: z.array(z.string().max(180)).max(30).optional(),
  destinations: z.array(z.string().max(180)).max(10).optional(),
  seoTitle: z.string().trim().max(255).optional().or(z.literal("")),
  seoDescription: z.string().trim().max(500).optional().or(z.literal("")),
});

async function uniquePostSlug(base, excludeId, connection) {
  const root = slugify(base) || "article";
  for (let attempt = 0; attempt < 50; attempt += 1) {
    const candidate = attempt === 0 ? root : `${root}-${attempt + 1}`;
    const taken = await queryValue(
      "SELECT id FROM posts WHERE slug = ? AND (? = 0 OR id <> ?) LIMIT 1",
      [candidate, excludeId ? 1 : 0, excludeId || 0],
      connection
    );
    if (!taken) return candidate;
  }
  return `${root}-${Date.now()}`;
}

async function syncPostTerms({ postId, payload, connection }) {
  const groups = [
    ["category", payload.categories],
    ["topic", payload.topics],
    ["tag", payload.tags],
    ["destination", payload.destinations],
  ].filter(([, values]) => Array.isArray(values));
  if (!groups.length) return;

  for (const [taxonomy, values] of groups) {
    await execute(
      `DELETE pt FROM post_terms pt JOIN editorial_terms t ON t.id = pt.term_id
        WHERE pt.post_id = ? AND t.taxonomy = ?`,
      [postId, taxonomy],
      connection
    );
    for (const value of values) {
      let term = await queryOne(
        "SELECT id FROM editorial_terms WHERE taxonomy = ? AND (slug = ? OR name = ?) LIMIT 1",
        [taxonomy, slugify(value), value],
        connection
      );
      if (!term && taxonomy === "tag") {
        // Tags are authored freely; categories and topics are curated and must
        // already exist.
        const created = await execute(
          "INSERT INTO editorial_terms (taxonomy, name, slug, post_count, created_at) VALUES ('tag', ?, ?, 0, NOW(3))",
          [value, slugify(value)],
          connection
        );
        term = { id: created.insertId };
      }
      if (term) {
        await execute("INSERT IGNORE INTO post_terms (post_id, term_id) VALUES (?, ?)", [postId, term.id], connection);
      }
    }
  }
}

export async function createArticle({ payload, userId }) {
  const publicId = ulid();
  const postId = await withTransaction(async (connection) => {
    const slug = await uniquePostSlug(payload.slug || payload.title, null, connection);
    const author = payload.authorId
      ? await queryOne("SELECT id FROM authors WHERE public_id = ? LIMIT 1", [payload.authorId], connection)
      : null;
    const cover = payload.coverImageAssetId
      ? await queryOne("SELECT url FROM media_assets WHERE public_id = ? AND deleted_at IS NULL", [payload.coverImageAssetId], connection)
      : null;

    const status = payload.status || "draft";
    const result = await execute(
      `INSERT INTO posts
         (public_id, author_id, post_type, title, slug, excerpt, body, body_format,
          cover_image_url, cover_image_alt, reading_time_minutes, status, visibility,
          published_at, scheduled_for, is_featured, seo_title, seo_description,
          canonical_url, is_indexable, created_by_user_id, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'html', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, NOW(3))`,
      [
        publicId,
        author?.id ?? null,
        payload.postType || "article",
        payload.title,
        slug,
        payload.excerpt || null,
        payload.contentHtml || null,
        cover?.url ?? null,
        payload.coverImageAlt || null,
        payload.readingTimeMinutes ?? estimateReadingTime(payload.contentHtml),
        status,
        payload.visibility || "public",
        status === "published" ? new Date() : null,
        payload.scheduledFor ? new Date(payload.scheduledFor) : null,
        payload.isFeatured ? 1 : 0,
        payload.seoTitle || null,
        payload.seoDescription || null,
        `/blogs/${slug}`,
        userId,
      ],
      connection
    );
    await syncPostTerms({ postId: result.insertId, payload, connection });
    return result.insertId;
  });
  return { id: publicId, postId: String(postId) };
}

function estimateReadingTime(html) {
  if (!html) return 3;
  const words = htmlToBlocks(html)
    .map((block) => (block.text || (block.items || []).join(" ") || ""))
    .join(" ")
    .split(/\s+/).length;
  return Math.max(1, Math.round(words / 220));
}

export async function updateArticle({ identifier, payload, userId }) {
  const post = await queryOne("SELECT id, public_id, status, slug FROM posts WHERE public_id = ? AND deleted_at IS NULL", [identifier]);
  if (!post) throw AppError.notFound("That article was not found.");

  await withTransaction(async (connection) => {
    const assignments = [];
    const params = [];
    const set = (column, value) => {
      assignments.push(`${column} = ?`);
      params.push(value);
    };
    if (payload.title !== undefined) set("title", payload.title);
    if (payload.slug !== undefined) set("slug", await uniquePostSlug(payload.slug, post.id, connection));
    if (payload.excerpt !== undefined) set("excerpt", payload.excerpt || null);
    if (payload.contentHtml !== undefined) {
      set("body", payload.contentHtml || null);
      set("body_format", "html");
      if (payload.readingTimeMinutes === undefined) set("reading_time_minutes", estimateReadingTime(payload.contentHtml));
    }
    if (payload.postType !== undefined) set("post_type", payload.postType);
    if (payload.visibility !== undefined) set("visibility", payload.visibility);
    if (payload.readingTimeMinutes !== undefined) set("reading_time_minutes", payload.readingTimeMinutes);
    if (payload.isFeatured !== undefined) set("is_featured", payload.isFeatured ? 1 : 0);
    if (payload.scheduledFor !== undefined) set("scheduled_for", payload.scheduledFor ? new Date(payload.scheduledFor) : null);
    if (payload.seoTitle !== undefined) set("seo_title", payload.seoTitle || null);
    if (payload.seoDescription !== undefined) set("seo_description", payload.seoDescription || null);
    if (payload.coverImageAssetId !== undefined) {
      const cover = payload.coverImageAssetId
        ? await queryOne("SELECT url FROM media_assets WHERE public_id = ? AND deleted_at IS NULL", [payload.coverImageAssetId], connection)
        : null;
      set("cover_image_url", cover?.url ?? null);
    }
    if (payload.coverImageAlt !== undefined) set("cover_image_alt", payload.coverImageAlt || null);
    if (payload.authorId !== undefined) {
      const author = payload.authorId
        ? await queryOne("SELECT id FROM authors WHERE public_id = ? LIMIT 1", [payload.authorId], connection)
        : null;
      set("author_id", author?.id ?? null);
    }
    if (payload.status !== undefined) {
      set("status", payload.status);
      if (payload.status === "published") set("published_at", new Date());
    }
    if (assignments.length) {
      await execute(`UPDATE posts SET ${assignments.join(", ")} WHERE id = ?`, [...params, post.id], connection);
    }
    await syncPostTerms({ postId: post.id, payload, connection });
  });

  return { id: post.public_id, updated: true };
}

export async function setArticleStatus({ identifier, status, userId }) {
  const post = await queryOne("SELECT id, public_id FROM posts WHERE public_id = ? AND deleted_at IS NULL", [identifier]);
  if (!post) throw AppError.notFound("That article was not found.");
  await execute(
    `UPDATE posts SET status = ?, published_at = IF(? = 'published', COALESCE(published_at, NOW(3)), published_at) WHERE id = ?`,
    [status, status, post.id]
  );
  return { id: post.public_id, status };
}

export async function deleteArticle({ identifier }) {
  const result = await execute("UPDATE posts SET deleted_at = NOW(3), status = 'archived' WHERE public_id = ? AND deleted_at IS NULL", [identifier]);
  if (!result.affectedRows) throw AppError.notFound("That article was not found.");
  return { id: identifier, deleted: true };
}

/* -------------------------------------------------------------------------- */
/* Media                                                                       */
/* -------------------------------------------------------------------------- */

export const mediaUpdateSchema = z.object({
  altText: z.string().trim().max(255).optional(),
  caption: z.string().trim().max(500).optional(),
  credit: z.string().trim().max(255).optional(),
  folder: z.string().trim().max(500).optional().nullable(),
});

export async function updateMediaAsset({ identifier, payload }) {
  const asset = await queryOne("SELECT id, public_id FROM media_assets WHERE public_id = ? AND deleted_at IS NULL", [identifier]);
  if (!asset) throw AppError.notFound("That media item was not found.");
  const folder = payload.folder
    ? await queryOne("SELECT id FROM media_folders WHERE path = ? LIMIT 1", [payload.folder])
    : null;
  await execute(
    `UPDATE media_assets
        SET alt_text = COALESCE(?, alt_text), caption = COALESCE(?, caption),
            credit = COALESCE(?, credit), folder_id = COALESCE(?, folder_id)
      WHERE id = ?`,
    [payload.altText ?? null, payload.caption ?? null, payload.credit ?? null, folder?.id ?? null, asset.id]
  );
  return { id: asset.public_id, updated: true };
}

export async function archiveMediaAsset({ identifier }) {
  const asset = await queryOne(
    "SELECT id, public_id, reference_count FROM media_assets WHERE public_id = ? AND deleted_at IS NULL",
    [identifier]
  );
  if (!asset) throw AppError.notFound("That media item was not found.");
  // An asset still attached to a listing is not deletable; that would leave a
  // gallery pointing at nothing.
  if (Number(asset.reference_count) > 0) {
    throw AppError.conflict("That file is still used by a listing. Remove it there first.");
  }
  await execute("UPDATE media_assets SET deleted_at = NOW(3) WHERE id = ?", [asset.id]);
  return { id: asset.public_id, archived: true };
}

/* -------------------------------------------------------------------------- */
/* Locations, categories, roles and internal users                             */
/* -------------------------------------------------------------------------- */

export const locationSchema = z.object({
  name: z.string().trim().min(1).max(180),
  slug: z.string().trim().max(180).optional(),
  level: z.enum(["country", "state", "city", "district", "community", "sub_community"]),
  parentId: z.union([z.string(), z.number()]).optional().nullable(),
  status: z.enum(["active", "inactive", "draft"]).optional(),
  latitude: z.coerce.number().min(-90).max(90).optional().nullable(),
  longitude: z.coerce.number().min(-180).max(180).optional().nullable(),
  isCoreMarket: z.boolean().optional(),
});

export async function createLocation({ payload, userId }) {
  return withTransaction(async (connection) => {
    let parent = null;
    if (payload.parentId) {
      parent = await queryOne(
        "SELECT id, level, depth, country_id, state_id, city_id, community_id FROM locations WHERE public_id = ? OR id = ? LIMIT 1",
        [String(payload.parentId), /^\d+$/.test(String(payload.parentId)) ? Number(payload.parentId) : 0],
        connection
      );
      if (!parent) throw AppError.validation("Some information is invalid.", { parentId: "That parent location was not found." });
    } else if (payload.level !== "country") {
      throw AppError.validation("Some information is invalid.", { parentId: "A parent is required below country level." });
    }

    const publicId = ulid();
    const slug = slugify(payload.slug || payload.name);
    const result = await execute(
      `INSERT INTO locations
         (public_id, parent_id, level, depth, name, name_ascii, slug, path, path_ids,
          country_id, state_id, city_id, community_id, latitude, longitude,
          status, is_searchable, is_core_market, source, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, '', '', ?, ?, ?, ?, ?, ?, ?, 1, ?, 'manual', NOW(3))`,
      [
        publicId,
        parent?.id ?? null,
        payload.level,
        parent ? Number(parent.depth) + 1 : 0,
        payload.name,
        payload.name,
        slug,
        parent?.country_id ?? null,
        parent?.state_id ?? (parent?.level === "state" ? parent.id : null),
        parent?.city_id ?? (parent?.level === "city" ? parent.id : null),
        parent?.community_id ?? (parent?.level === "community" ? parent.id : null),
        payload.latitude ?? null,
        payload.longitude ?? null,
        payload.status || "active",
        payload.isCoreMarket ? 1 : 0,
      ],
      connection
    );

    // Fix the ancestor columns for the new row now that its own id exists.
    const own = payload.level === "country" ? "country_id" : payload.level === "state" ? "state_id" : payload.level === "city" ? "city_id" : payload.level === "community" || payload.level === "district" ? "community_id" : null;
    if (own) {
      await execute(`UPDATE locations SET ${own} = ? WHERE id = ?`, [result.insertId, result.insertId], connection);
    }
    return { id: publicId, locationId: String(result.insertId) };
  }).then(async (created) => {
    // The closure table and denormalised paths are rebuilt by the routine that
    // owns them rather than patched by hand.
    await callProcedure("sp_location_rebuild_tree", []);
    return created;
  });
}

export async function updateLocation({ identifier, payload }) {
  const location = await queryOne("SELECT id, public_id FROM locations WHERE public_id = ? AND deleted_at IS NULL", [identifier]);
  if (!location) throw AppError.notFound("That location was not found.");
  const assignments = [];
  const params = [];
  if (payload.name !== undefined) {
    assignments.push("name = ?", "name_ascii = ?");
    params.push(payload.name, payload.name);
  }
  if (payload.slug !== undefined) {
    assignments.push("slug = ?");
    params.push(slugify(payload.slug));
  }
  if (payload.status !== undefined) {
    assignments.push("status = ?");
    params.push(payload.status);
  }
  if (payload.latitude !== undefined) {
    assignments.push("latitude = ?");
    params.push(payload.latitude);
  }
  if (payload.longitude !== undefined) {
    assignments.push("longitude = ?");
    params.push(payload.longitude);
  }
  if (payload.isCoreMarket !== undefined) {
    assignments.push("is_core_market = ?");
    params.push(payload.isCoreMarket ? 1 : 0);
  }
  if (!assignments.length) return { id: location.public_id, updated: false };
  await execute(`UPDATE locations SET ${assignments.join(", ")} WHERE id = ?`, [...params, location.id]);
  return { id: location.public_id, updated: true };
}

export async function archiveLocation({ identifier }) {
  const location = await queryOne("SELECT id, public_id FROM locations WHERE public_id = ? AND deleted_at IS NULL", [identifier]);
  if (!location) throw AppError.notFound("That location was not found.");
  const inUse = await queryValue(
    "SELECT COUNT(*) FROM listings WHERE (location_id = ? OR city_id = ? OR community_id = ? OR sub_community_id = ?) AND deleted_at IS NULL",
    [location.id, location.id, location.id, location.id]
  );
  if (Number(inUse) > 0) {
    throw AppError.conflict(`${inUse} listings still reference that location. Move them first.`);
  }
  await execute("UPDATE locations SET status = 'inactive', deleted_at = NOW(3) WHERE id = ?", [location.id]);
  return { id: location.public_id, archived: true };
}

export const categorySchema = z.object({
  name: z.string().trim().min(1).max(120),
  namePlural: z.string().trim().max(120).optional(),
  slug: z.string().trim().max(80).optional(),
  description: z.string().trim().max(2000).optional().or(z.literal("")),
  parentCategory: z.string().trim().max(40).optional(),
  status: z.enum(["active", "inactive", "draft"]).optional(),
  sortOrder: z.coerce.number().int().min(0).max(10000).optional(),
});

export async function upsertCategory({ identifier, payload, userId }) {
  return withTransaction(async (connection) => {
    if (identifier) {
      const category = await queryOne("SELECT id, public_id FROM categories WHERE public_id = ? AND deleted_at IS NULL", [identifier], connection);
      if (!category) throw AppError.notFound("That category was not found.");
      const assignments = [];
      const params = [];
      if (payload.name !== undefined) {
        assignments.push("name = ?");
        params.push(payload.name);
      }
      if (payload.namePlural !== undefined) {
        assignments.push("name_plural = ?");
        params.push(payload.namePlural);
      }
      if (payload.slug !== undefined) {
        assignments.push("slug = ?");
        params.push(slugify(payload.slug));
      }
      if (payload.description !== undefined) {
        assignments.push("description = ?");
        params.push(payload.description || null);
      }
      if (payload.status !== undefined) {
        assignments.push("status = ?");
        params.push(payload.status);
      }
      if (payload.sortOrder !== undefined) {
        assignments.push("sort_order = ?");
        params.push(payload.sortOrder);
      }
      if (assignments.length) {
        await execute(`UPDATE categories SET ${assignments.join(", ")} WHERE id = ?`, [...params, category.id], connection);
      }
      return { id: category.public_id, updated: true };
    }

    const parent = resolveCategory(payload.parentCategory);
    if (!parent) throw AppError.validation("Some information is invalid.", { parentCategory: "Choose a marketplace category." });
    const publicId = ulid();
    const slug = slugify(payload.slug || payload.namePlural || payload.name);
    const parentRow = await queryOne("SELECT id, path FROM categories WHERE id = ?", [parent.rootId], connection);
    const result = await execute(
      `INSERT INTO categories
         (public_id, parent_id, root_category_id, code, slug, name, name_plural, depth, path,
          description, status, is_visible, sort_order, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, 1, ?, NOW(3))`,
      [
        publicId,
        parent.rootId,
        parent.rootId,
        slugify(payload.name),
        slug,
        payload.name,
        payload.namePlural || payload.name,
        `${parentRow?.path || parent.dbCode}/${slug}`,
        payload.description || null,
        payload.status || "active",
        payload.sortOrder ?? 100,
      ],
      connection
    );
    return { id: publicId, categoryId: String(result.insertId), created: true };
  });
}

export const roleSchema = z.object({
  name: z.string().trim().min(1).max(120),
  description: z.string().trim().max(500).optional().or(z.literal("")),
  databasePermissions: z.array(z.string().max(100)).max(200).optional(),
  /**
   * Which marketplace categories this role covers. An empty array — or the field omitted —
   * means every category, which is the sensible default and keeps every existing role working.
   * Anything listed here narrows the role: see migration 0032 for why the category lives on the
   * grant rather than inside the permission code.
   */
  categoryScope: z.array(z.string().max(60)).max(50).optional(),
});

export async function upsertRole({ identifier, payload, userId }) {
  return withTransaction(async (connection) => {
    let roleId;
    if (identifier) {
      const role = await queryOne("SELECT id, is_system FROM roles WHERE (id = ? OR code = ?) AND scope = 'platform'", [
        /^\d+$/.test(String(identifier)) ? Number(identifier) : 0,
        String(identifier),
      ], connection);
      if (!role) throw AppError.notFound("That role was not found.");
      roleId = role.id;
      await execute("UPDATE roles SET name = ?, description = ? WHERE id = ?", [payload.name, payload.description || null, roleId], connection);
    } else {
      const code = slugify(payload.name).replace(/-/g, "_").slice(0, 60);
      const existing = await queryValue("SELECT id FROM roles WHERE code = ?", [code], connection);
      if (existing) throw AppError.conflict("A role with that name already exists.");
      const result = await execute(
        `INSERT INTO roles (code, name, description, scope, is_system, sort_order, created_at)
         VALUES (?, ?, ?, 'platform', 0, 100, NOW(3))`,
        [code, payload.name, payload.description || null],
        connection
      );
      roleId = result.insertId;
    }

    if (payload.databasePermissions) {
      const submitted = [...new Set(payload.databasePermissions)];
      // Resolve the whole set in one read, and refuse the request if any code is unknown.
      // The previous behaviour skipped unrecognised codes silently, so a role saved from the
      // matrix could keep almost nothing and report success — the administrator saw a saved
      // role, the user holding it saw an empty portal, and nothing anywhere said why.
      const known = submitted.length
        ? await query(
            `SELECT id, code FROM permissions WHERE code IN (${submitted.map(() => "?").join(", ")})`,
            submitted,
            connection
          )
        : [];
      const knownCodes = new Set(known.map((row) => row.code));
      const unknown = submitted.filter((code) => !knownCodes.has(code));
      if (unknown.length) {
        throw AppError.validation("Some permissions are not recognised.", {
          databasePermissions: `Unknown permission ${unknown.slice(0, 5).join(", ")}${unknown.length > 5 ? "…" : ""}.`,
        });
      }

      await execute("DELETE FROM role_permissions WHERE role_id = ?", [roleId], connection);
      for (const row of known) {
        await execute(
          "INSERT IGNORE INTO role_permissions (role_id, permission_id) VALUES (?, ?)",
          [roleId, row.id],
          connection
        );
      }
    }

    if (payload.categoryScope) {
      const categories = [...new Set(payload.categoryScope)];
      const unknownCategory = categories.filter((value) => !resolveCategory(value));
      if (unknownCategory.length) {
        throw AppError.validation("Some categories are not recognised.", {
          categoryScope: `Unknown category ${unknownCategory.join(", ")}.`,
        });
      }
      await execute("DELETE FROM role_scopes WHERE role_id = ? AND scope_type = 'category'", [roleId], connection);
      for (const value of categories) {
        await execute(
          "INSERT IGNORE INTO role_scopes (role_id, scope_type, scope_value, created_at) VALUES (?, 'category', ?, NOW(3))",
          [roleId, resolveCategory(value).listingType],
          connection
        );
      }
    }

    return { id: String(roleId) };
  });
}

export async function deleteRole({ identifier }) {
  const role = await queryOne("SELECT id, is_system FROM roles WHERE (id = ? OR code = ?) AND scope = 'platform'", [
    /^\d+$/.test(String(identifier)) ? Number(identifier) : 0,
    String(identifier),
  ]);
  if (!role) throw AppError.notFound("That role was not found.");
  if (role.is_system) throw AppError.conflict("System roles cannot be deleted.");
  const inUse = await queryValue("SELECT COUNT(*) FROM user_roles WHERE role_id = ?", [role.id]);
  if (Number(inUse) > 0) throw AppError.conflict(`${inUse} users still hold that role.`);
  await execute("DELETE FROM roles WHERE id = ?", [role.id]);
  return { deleted: true };
}

export const internalUserSchema = z.object({
  firstName: z.string().trim().min(1).max(120),
  lastName: z.string().trim().min(1).max(120),
  email: z.string().trim().toLowerCase().email().max(255),
  phone: z.string().trim().max(40).optional().or(z.literal("")),
  roleIds: z.array(z.coerce.number().int().positive()).max(10).optional(),
  status: z.enum(["active", "suspended", "pending_verification"]).optional(),
});

export async function upsertInternalUser({ identifier, payload, userId }) {
  return withTransaction(async (connection) => {
    let targetId;
    if (identifier) {
      const user = await queryOne("SELECT id FROM users WHERE public_id = ? AND deleted_at IS NULL", [identifier], connection);
      if (!user) throw AppError.notFound("That user was not found.");
      targetId = user.id;
      await assertAccessChangeAllowed(
        { targetUserId: targetId, actingUserId: userId, nextStatus: payload.status ?? null, nextRoleIds: payload.roleIds ?? null },
        connection
      );
      const phone = splitPhone(payload.phone);
      await execute(
        `UPDATE users
            SET first_name = ?, last_name = ?, display_name = ?,
                phone_country_code = ?, phone_number = ?, status = COALESCE(?, status)
          WHERE id = ?`,
        [
          payload.firstName,
          payload.lastName,
          `${payload.firstName} ${payload.lastName}`,
          phone.countryCode,
          phone.number,
          payload.status ?? null,
          targetId,
        ],
        connection
      );
    } else {
      const existing = await queryValue("SELECT id FROM users WHERE email_normalized = ?", [payload.email], connection);
      if (existing) throw AppError.conflict("A user with that email already exists.");
      const { hashPassword } = await import("../auth/passwords.js");
      const { randomToken } = await import("../../utils/ids.js");
      const result = await execute(
        `INSERT INTO users
           (public_id, email, email_normalized, phone_country_code, phone_number, password_hash,
            password_updated_at, status, first_name, last_name, display_name, created_at)
         VALUES (?, ?, ?, ?, ?, ?, NOW(3), 'pending_verification', ?, ?, ?, NOW(3))`,
        [
          ulid(),
          payload.email,
          payload.email,
          splitPhone(payload.phone).countryCode,
          splitPhone(payload.phone).number,
          // A random unusable password: the invitee sets their own via reset.
          await hashPassword(randomToken(32)),
          payload.firstName,
          payload.lastName,
          `${payload.firstName} ${payload.lastName}`,
        ],
        connection
      );
      targetId = result.insertId;
    }

    if (payload.roleIds) {
      await execute("DELETE FROM user_roles WHERE user_id = ?", [targetId], connection);
      for (const roleId of payload.roleIds) {
        const role = await queryValue("SELECT id FROM roles WHERE id = ? AND scope = 'platform'", [roleId], connection);
        if (role) {
          await execute(
            "INSERT IGNORE INTO user_roles (user_id, role_id, granted_by_user_id, granted_at) VALUES (?, ?, ?, NOW(3))",
            [targetId, role, userId],
            connection
          );
        }
      }
    }

    const publicId = await queryValue("SELECT public_id FROM users WHERE id = ?", [targetId], connection);
    return { id: publicId, userId: String(targetId) };
  });
}

/* -------------------------------------------------------------------------- */
/* Organizations, agents and packages                                          */
/* -------------------------------------------------------------------------- */
/**
 * The admin company/individual/agent screens were built against these operations and had
 * nowhere to send them — the Gap Register's "built UI, missing endpoint" row. Each one writes
 * the same tables the portal writes, so a change made by staff and a change made by the owner
 * are indistinguishable afterwards, which is what an audit needs.
 */

export const organizationProfileSchema = z.object({
  name: z.string().trim().min(1).max(200).optional(),
  legalName: z.string().trim().max(200).optional().nullable(),
  tagline: z.string().trim().max(255).optional().nullable(),
  description: z.string().trim().max(5000).optional().nullable(),
  email: z.string().trim().toLowerCase().email().max(255).optional().nullable(),
  phone: z.string().trim().max(40).optional().nullable(),
  whatsapp: z.string().trim().max(40).optional().nullable(),
  websiteUrl: z.string().trim().max(255).optional().nullable(),
  addressLine1: z.string().trim().max(255).optional().nullable(),
  postalCode: z.string().trim().max(30).optional().nullable(),
  countryId: z.coerce.number().int().positive().optional().nullable(),
  stateId: z.coerce.number().int().positive().optional().nullable(),
  cityId: z.coerce.number().int().positive().optional().nullable(),
  communityId: z.coerce.number().int().positive().optional().nullable(),
  foundedYear: z.coerce.number().int().min(1600).max(2200).optional().nullable(),
  employeeCount: z.coerce.number().int().min(0).max(1000000).optional().nullable(),
  seoTitle: z.string().trim().max(255).optional().nullable(),
  seoDescription: z.string().trim().max(500).optional().nullable(),
  isPubliclyVisible: z.boolean().optional(),
});

const ORGANIZATION_COLUMNS = {
  name: "name",
  legalName: "legal_name",
  tagline: "tagline",
  description: "description",
  email: "email",
  phone: "phone",
  whatsapp: "whatsapp",
  websiteUrl: "website_url",
  addressLine1: "address_line1",
  postalCode: "postal_code",
  countryId: "country_id",
  stateId: "state_id",
  cityId: "city_id",
  communityId: "community_id",
  foundedYear: "founded_year",
  employeeCount: "employee_count",
  seoTitle: "seo_title",
  seoDescription: "seo_description",
  isPubliclyVisible: "is_publicly_visible",
};

export async function updateOrganizationProfile({ identifier, payload }) {
  const organization = await queryOne(
    "SELECT id, public_id, name FROM organizations WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL LIMIT 1",
    [identifier, identifier]
  );
  if (!organization) throw AppError.notFound("That company was not found.");

  const assignments = [];
  const params = [];
  for (const [key, column] of Object.entries(ORGANIZATION_COLUMNS)) {
    if (payload[key] === undefined) continue;
    assignments.push(`${column} = ?`);
    params.push(typeof payload[key] === "boolean" ? (payload[key] ? 1 : 0) : payload[key]);
  }
  if (!assignments.length) return { id: organization.public_id, updated: false };

  await execute(`UPDATE organizations SET ${assignments.join(", ")}, updated_at = NOW(3) WHERE id = ?`, [
    ...params,
    organization.id,
  ]);
  return { id: organization.public_id, updated: true };
}

export const agentSchema = z.object({
  firstName: z.string().trim().min(1).max(120),
  lastName: z.string().trim().min(1).max(120),
  email: z.string().trim().toLowerCase().email().max(255).optional().nullable(),
  phone: z.string().trim().max(40).optional().nullable(),
  whatsapp: z.string().trim().max(40).optional().nullable(),
  title: z.string().trim().max(120).optional().nullable(),
  bio: z.string().trim().max(4000).optional().nullable(),
  licenseNumber: z.string().trim().max(80).optional().nullable(),
  experienceYears: z.coerce.number().int().min(0).max(80).optional().nullable(),
  organizationId: z.string().trim().max(60).optional().nullable(),
  status: z.enum(["active", "inactive", "suspended"]).optional(),
  isPubliclyVisible: z.boolean().optional(),
});

export async function upsertAgent({ identifier, payload, userId }) {
  return withTransaction(async (connection) => {
    let organizationId = null;
    if (payload.organizationId) {
      const organization = await queryOne(
        "SELECT id FROM organizations WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL",
        [payload.organizationId, payload.organizationId],
        connection
      );
      if (!organization) throw AppError.validation("Some information is invalid.", { organizationId: "That company was not found." });
      organizationId = organization.id;
    }

    const displayName = `${payload.firstName} ${payload.lastName}`.trim();
    const columns = {
      first_name: payload.firstName,
      last_name: payload.lastName,
      display_name: displayName,
      title: payload.title ?? null,
      bio: payload.bio ?? null,
      email: payload.email ?? null,
      phone: payload.phone ?? null,
      whatsapp: payload.whatsapp ?? null,
      license_number: payload.licenseNumber ?? null,
      experience_years: payload.experienceYears ?? null,
      ...(payload.status ? { status: payload.status } : {}),
      ...(payload.isPubliclyVisible === undefined ? {} : { is_publicly_visible: payload.isPubliclyVisible ? 1 : 0 }),
      ...(organizationId ? { organization_id: organizationId } : {}),
    };

    if (identifier) {
      const agent = await queryOne(
        "SELECT id, public_id FROM agents WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL LIMIT 1",
        [identifier, identifier],
        connection
      );
      if (!agent) throw AppError.notFound("That agent was not found.");
      const keys = Object.keys(columns);
      await execute(
        `UPDATE agents SET ${keys.map((key) => `${key} = ?`).join(", ")}, updated_at = NOW(3) WHERE id = ?`,
        [...keys.map((key) => columns[key]), agent.id],
        connection
      );
      return { id: agent.public_id, updated: true };
    }

    // A slug has to be unique and readable; the id keeps it collision-free without a retry loop.
    const publicId = ulid();
    const base = slugify(displayName).slice(0, 120) || "agent";
    const result = await execute(
      `INSERT INTO agents (public_id, organization_id, first_name, last_name, display_name, slug, title, bio,
                           email, phone, whatsapp, license_number, experience_years, status,
                           verification_status, is_publicly_visible, joined_at, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'unverified', ?, NOW(3), NOW(3), NOW(3))`,
      [
        publicId,
        organizationId,
        payload.firstName,
        payload.lastName,
        displayName,
        base,
        payload.title ?? null,
        payload.bio ?? null,
        payload.email ?? null,
        payload.phone ?? null,
        payload.whatsapp ?? null,
        payload.licenseNumber ?? null,
        payload.experienceYears ?? null,
        payload.status ?? "active",
        payload.isPubliclyVisible === false ? 0 : 1,
      ],
      connection
    );
    await execute("UPDATE agents SET slug = ? WHERE id = ?", [`${base}-${result.insertId}`, result.insertId], connection);
    if (organizationId) {
      await execute(
        `UPDATE organizations SET agent_count = (SELECT COUNT(*) FROM agents a WHERE a.organization_id = ? AND a.deleted_at IS NULL)
          WHERE id = ?`,
        [organizationId, organizationId],
        connection
      );
    }
    return { id: publicId, created: true, actorUserId: userId };
  });
}

export const packageChangeSchema = z.object({
  packageId: z.coerce.number().int().positive(),
  note: z.string().trim().max(500).optional(),
});

/**
 * Moves an account onto a different plan.
 *
 * Deliberately does not take money. There is no billing provider connected, and a screen that
 * silently implied a charge had been raised would be worse than one that plainly does not.
 * The plan and its entitlements change; the invoice is a separate concern for when payments
 * exist.
 */
export async function changeAccountPackage({ identifier, payload }) {
  const account = await queryOne(
    `SELECT a.id, a.public_id FROM accounts a
      LEFT JOIN organizations o ON o.account_id = a.id
      WHERE a.public_id = ? OR o.public_id = ? OR o.slug = ? LIMIT 1`,
    [identifier, identifier, identifier]
  );
  if (!account) throw AppError.notFound("That account was not found.");

  const plan = await queryOne(
    "SELECT id, name, listing_quota, featured_quota, billing_interval FROM plans WHERE id = ? AND is_active = 1",
    [payload.packageId]
  );
  if (!plan) throw AppError.validation("Some information is invalid.", { packageId: "That package is not available." });

  // The plan lives on `subscriptions`, not on the account: an account can have had several over
  // time and the history is what billing and entitlement questions are answered from. So the
  // current one is switched, or one is opened if the account has never had a plan.
  await withTransaction(async (connection) => {
    const current = await queryOne(
      "SELECT id FROM subscriptions WHERE account_id = ? AND status IN ('active','trialing','past_due') ORDER BY created_at DESC LIMIT 1",
      [account.id],
      connection
    );
    if (current) {
      await execute(
        `UPDATE subscriptions SET plan_id = ?, listing_quota = ?, featured_quota = ?, billing_interval = ?, updated_at = NOW(3)
          WHERE id = ?`,
        [plan.id, plan.listing_quota ?? 0, plan.featured_quota ?? 0, plan.billing_interval ?? "monthly", current.id],
        connection
      );
    } else {
      await execute(
        `INSERT INTO subscriptions (public_id, account_id, plan_id, status, amount, currency_code, billing_interval,
                                    current_period_start, current_period_end, listing_quota, listing_used,
                                    featured_quota, featured_used, auto_renew, created_at, updated_at)
         VALUES (?, ?, ?, 'active', 0, 'AED', ?, NOW(3), DATE_ADD(NOW(3), INTERVAL 1 MONTH), ?, 0, ?, 0, 1, NOW(3), NOW(3))`,
        [ulid(), account.id, plan.id, plan.billing_interval ?? "monthly", plan.listing_quota ?? 0, plan.featured_quota ?? 0],
        connection
      );
    }
    // The account's own quota mirrors the plan so quota checks stay one indexed read.
    await execute(
      "UPDATE accounts SET listing_quota = ?, featured_quota = ?, updated_at = NOW(3) WHERE id = ?",
      [plan.listing_quota ?? 0, plan.featured_quota ?? 0, account.id],
      connection
    );
  });

  return { id: account.public_id, packageId: String(plan.id), packageName: plan.name, chargeRaised: false };
}

/* -------------------------------------------------------------------------- */
/* Real-estate developments                                                    */
/* -------------------------------------------------------------------------- */
/**
 * A development is a `projects` row plus its unit types, payment plans and
 * milestones, amenities, media, floor plans and documents. All of it is written
 * in one transaction: a project that appears without the payment plan an
 * operator entered alongside it is a half-saved record, and no screen would
 * surface the difference.
 *
 * The wizard collected roughly sixty fields and twelve of them were persisted —
 * the tagline, project type, launch status, ownership type, moderation status,
 * highlights, marketing heading, building count, construction start, address,
 * unit types, amenities, every payment plan after the first, every milestone,
 * and all media were dropped on submit. The schema below is the whole form.
 *
 * Status vocabulary is snake_case on the wire, always. The wizard offers
 * "Under Construction" and "on-hold"; `normalizeStatusValue` maps a label or a
 * hyphenated value onto the stored one so an existing form cannot silently
 * write a status the column rejects, and an unknown value is a validation error
 * rather than a default.
 */

/** `Under Construction`, `under-construction` and `under_construction` are one value. */
function normalizeStatusValue(value) {
  return String(value ?? "")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
}

const enumIn = (allowed, label) =>
  z
    .string()
    .trim()
    .max(60)
    .transform(normalizeStatusValue)
    .refine((value) => allowed.includes(value), {
      message: `${label} must be one of: ${allowed.join(", ")}.`,
    });

const DEVELOPMENT_LIFECYCLE = [
  "announced",
  "presale",
  "under_construction",
  "completed",
  "handed_over",
  "on_hold",
  "cancelled",
];
const DEVELOPMENT_LAUNCH = ["coming_soon", "upcoming", "launched", "sold_out"];
const DEVELOPMENT_MODERATION = ["draft", "pending", "published", "rejected", "archived"];
const DEVELOPMENT_PROJECT_TYPES = [
  "residential",
  "commercial",
  "mixed_use",
  "hospitality",
  "branded_residence",
  "master_community",
];
const DEVELOPMENT_OWNERSHIP = ["freehold", "leasehold", "commonhold", "usufruct", "musataha", "other", "unknown"];
const DEVELOPMENT_UNIT_TYPES = [
  "apartment",
  "penthouse",
  "duplex",
  "villa",
  "townhouse",
  "studio",
  "loft",
  "office",
  "retail",
  "warehouse",
  "plot",
  "floor",
  "whole_building",
  "other",
];
const DEVELOPMENT_AVAILABILITY = ["available", "limited", "sold_out", "coming_soon"];
const PAYMENT_PLAN_TYPES = ["construction_linked", "time_linked", "post_handover", "cash", "custom"];
const MILESTONE_TRIGGERS = [
  "booking",
  "contract",
  "construction_percent",
  "months_from_booking",
  "months_from_handover",
  "handover",
  "date",
];
const DOCUMENT_TYPES = [
  "brochure",
  "floor_plan",
  "price_list",
  "payment_plan",
  "title_deed",
  "survey",
  "inspection_report",
  "service_charge",
  "spec_sheet",
  "maintenance_log",
  "registration",
  "insurance",
  "contract",
  "noc",
  "valuation",
  "other",
];
const DOCUMENT_VISIBILITY = ["public", "gated", "restricted", "internal"];

const nullableDate = z.string().trim().max(20).optional().nullable();

const unitTypeSchema = z.object({
  unitType: enumIn(DEVELOPMENT_UNIT_TYPES, "Unit type"),
  name: z.string().trim().max(160).optional().nullable(),
  bedrooms: z.coerce.number().int().min(0).max(60).optional().nullable(),
  bathrooms: z.coerce.number().min(0).max(60).optional().nullable(),
  minSize: z.coerce.number().min(0).max(1e9).optional().nullable(),
  maxSize: z.coerce.number().min(0).max(1e9).optional().nullable(),
  areaUnit: z.string().trim().max(20).optional().nullable(),
  startingPrice: z.coerce.number().min(0).max(1e15).optional().nullable(),
  maxPrice: z.coerce.number().min(0).max(1e15).optional().nullable(),
  currencyCode: z.string().trim().length(3).optional().nullable(),
  availability: enumIn(DEVELOPMENT_AVAILABILITY, "Availability").optional(),
  availableUnits: z.coerce.number().int().min(0).max(100000).optional().nullable(),
  totalUnits: z.coerce.number().int().min(0).max(100000).optional().nullable(),
  sortOrder: z.coerce.number().int().min(0).max(1000).optional(),
});

const milestoneSchema = z.object({
  name: z.string().trim().min(1).max(200),
  triggerType: enumIn(MILESTONE_TRIGGERS, "Milestone trigger").optional(),
  constructionPercent: z.coerce.number().min(0).max(100).optional().nullable(),
  monthsOffset: z.coerce.number().int().min(0).max(600).optional().nullable(),
  date: nullableDate,
  percentage: z.coerce.number().min(0).max(100).optional().nullable(),
  amount: z.coerce.number().min(0).max(1e15).optional().nullable(),
  currencyCode: z.string().trim().length(3).optional().nullable(),
  notes: z.string().trim().max(300).optional().nullable(),
});

const paymentPlanSchema = z.object({
  name: z.string().trim().min(1).max(200),
  description: z.string().trim().max(1000).optional().nullable(),
  planType: enumIn(PAYMENT_PLAN_TYPES, "Payment plan type").optional(),
  downPaymentPercent: z.coerce.number().min(0).max(100).optional().nullable(),
  duringConstructionPercent: z.coerce.number().min(0).max(100).optional().nullable(),
  onHandoverPercent: z.coerce.number().min(0).max(100).optional().nullable(),
  postHandoverPercent: z.coerce.number().min(0).max(100).optional().nullable(),
  postHandoverMonths: z.coerce.number().int().min(0).max(600).optional().nullable(),
  waivesRegistrationFee: z.boolean().optional(),
  serviceChargeWaiverYears: z.coerce.number().int().min(0).max(30).optional().nullable(),
  guaranteedReturnPercent: z.coerce.number().min(0).max(100).optional().nullable(),
  guaranteedReturnYears: z.coerce.number().int().min(0).max(30).optional().nullable(),
  milestones: z.array(milestoneSchema).max(40).optional(),
});

const mediaRefSchema = z.object({
  mediaAssetId: z.string().trim().min(1).max(64),
  caption: z.string().trim().max(500).optional().nullable(),
  isPrimary: z.boolean().optional(),
  sortOrder: z.coerce.number().int().min(0).max(1000).optional(),
});

const floorPlanSchema = z.object({
  name: z.string().trim().min(1).max(160),
  unitType: z.string().trim().max(80).optional().nullable(),
  bedrooms: z.coerce.number().int().min(0).max(50).optional().nullable(),
  mediaAssetId: z.string().trim().max(64).optional().nullable(),
  floorLevel: z.coerce.number().int().min(-20).max(300).optional().nullable(),
  areaSqm: z.coerce.number().min(0).max(1e7).optional().nullable(),
  areaSqft: z.coerce.number().min(0).max(1e7).optional().nullable(),
  requiresLead: z.boolean().optional(),
  isPublic: z.boolean().optional(),
  sortOrder: z.coerce.number().int().min(0).max(1000).optional(),
});

const documentSchema = z.object({
  title: z.string().trim().min(1).max(255),
  documentType: enumIn(DOCUMENT_TYPES, "Document type").optional(),
  description: z.string().trim().max(1000).optional().nullable(),
  visibility: enumIn(DOCUMENT_VISIBILITY, "Document visibility").optional(),
  mediaAssetId: z.string().trim().max(64).optional().nullable(),
  version: z.string().trim().max(40).optional().nullable(),
});

export const developmentSchema = z.object({
  name: z.string().trim().min(1).max(200),
  tagline: z.string().trim().max(255).optional().nullable(),
  description: z.string().trim().max(8000).optional().nullable(),
  marketingHeading: z.string().trim().max(255).optional().nullable(),
  highlights: z.array(z.string().trim().max(300)).max(30).optional(),
  developerId: z.string().trim().max(60).optional().nullable(),
  categoryId: z.coerce.number().int().positive().optional().nullable(),
  projectType: enumIn(DEVELOPMENT_PROJECT_TYPES, "Project type").optional(),
  ownershipType: enumIn(DEVELOPMENT_OWNERSHIP, "Ownership type").optional(),

  // Three separate concepts, never collapsed into one field.
  status: enumIn(DEVELOPMENT_LIFECYCLE, "Development status").optional(),
  launchStatus: enumIn(DEVELOPMENT_LAUNCH, "Launch status").optional(),
  moderationStatus: enumIn(DEVELOPMENT_MODERATION, "Moderation status").optional(),
  // Set alongside `moderationStatus: "rejected"`; cleared automatically in
  // `upsertDevelopment` once the moderation status moves away from "rejected".
  rejectionReason: z.string().trim().max(500).optional().nullable(),

  launchDate: nullableDate,
  constructionStartDate: nullableDate,
  handoverDate: nullableDate,
  completionPercentage: z.coerce.number().min(0).max(100).optional().nullable(),
  totalUnits: z.coerce.number().int().min(0).max(100000).optional().nullable(),
  availableUnits: z.coerce.number().int().min(0).max(100000).optional().nullable(),
  buildingCount: z.coerce.number().int().min(0).max(1000).optional().nullable(),
  minPrice: z.coerce.number().min(0).optional().nullable(),
  maxPrice: z.coerce.number().min(0).optional().nullable(),
  currencyCode: z.string().trim().length(3).optional().nullable(),

  countryId: z.coerce.number().int().positive().optional().nullable(),
  stateId: z.coerce.number().int().positive().optional().nullable(),
  cityId: z.coerce.number().int().positive().optional().nullable(),
  communityId: z.coerce.number().int().positive().optional().nullable(),
  subCommunityId: z.coerce.number().int().positive().optional().nullable(),
  address: z.string().trim().max(255).optional().nullable(),
  latitude: z.coerce.number().min(-90).max(90).optional().nullable(),
  longitude: z.coerce.number().min(-180).max(180).optional().nullable(),

  coverImageUrl: z.string().trim().max(500).optional().nullable(),
  brochureUrl: z.string().trim().max(500).optional().nullable(),
  // A hosted video URL (YouTube / Vimeo / a direct link). An uploaded video goes
  // through the `video` media role instead; the two are mutually exclusive and
  // the detail tab clears one when it sets the other. Empty string clears it.
  videoUrl: z
    .string()
    .trim()
    .max(500)
    .optional()
    .nullable()
    .transform((value) => (value === undefined ? undefined : value || null)),
  amenities: z.array(z.string().trim().max(160)).max(120).optional(),
  unitTypes: z.array(unitTypeSchema).max(60).optional(),
  paymentPlans: z.array(paymentPlanSchema).max(12).optional(),
  gallery: z.array(mediaRefSchema).max(80).optional(),
  masterplan: z.array(mediaRefSchema).max(6).optional(),
  video: z.array(mediaRefSchema).max(4).optional(),
  brochure: z.array(mediaRefSchema).max(4).optional(),
  floorPlans: z.array(floorPlanSchema).max(60).optional(),
  documents: z.array(documentSchema).max(40).optional(),

  isFeatured: z.boolean().optional(),
  acceptsInquiries: z.boolean().optional(),
  isPubliclyVisible: z.boolean().optional(),
  seoTitle: z.string().trim().max(255).optional().nullable(),
  seoDescription: z.string().trim().max(500).optional().nullable(),

  /**
   * Retained so an existing caller sending a single plan still works. It is
   * folded into `paymentPlans` before anything is written, so there is one code
   * path and one validation rule.
   */
  paymentPlan: paymentPlanSchema.optional().nullable(),
});

const DEVELOPMENT_COLUMNS = {
  name: "name",
  tagline: "tagline",
  description: "description",
  marketingHeading: "marketing_heading",
  projectType: "project_type",
  ownershipType: "ownership_type",
  status: "status",
  launchStatus: "launch_status",
  moderationStatus: "moderation_status",
  rejectionReason: "rejection_reason",
  launchDate: "launch_date",
  constructionStartDate: "construction_start_date",
  handoverDate: "handover_date",
  completionPercentage: "completion_percentage",
  totalUnits: "total_units",
  availableUnits: "available_units",
  buildingCount: "building_count",
  minPrice: "min_price",
  maxPrice: "max_price",
  currencyCode: "currency_code",
  countryId: "country_id",
  stateId: "state_id",
  cityId: "city_id",
  communityId: "community_id",
  subCommunityId: "sub_community_id",
  address: "address_line1",
  latitude: "latitude",
  longitude: "longitude",
  coverImageUrl: "cover_image_url",
  brochureUrl: "brochure_url",
  videoUrl: "video_url",
  isFeatured: "is_featured",
  acceptsInquiries: "accepts_inquiries",
  isPubliclyVisible: "is_publicly_visible",
  seoTitle: "seo_title",
  seoDescription: "seo_description",
  categoryId: "category_id",
};

/**
 * A plan's instalments have to describe the whole price.
 *
 * Checked against the milestones when there are any and against the four
 * headline percentages otherwise, because those are two spellings of the same
 * schedule and an operator fills in one or the other. A plan summing to 90%
 * under-bills every buyer on it and nothing downstream would catch it.
 */
function validatePaymentPlan(plan, index) {
  const field = (key) => `paymentPlans.${index}.${key}`;
  const milestones = plan.milestones || [];
  const percentageMilestones = milestones.filter(
    (milestone) => milestone.percentage !== null && milestone.percentage !== undefined
  );
  if (percentageMilestones.length) {
    // Mixed schedules are legitimate — a fixed instalment alongside percentages —
    // but then the percentages alone cannot be expected to reach 100.
    const hasFixedAmounts = milestones.some(
      (milestone) => milestone.amount !== null && milestone.amount !== undefined
    );
    const total = percentageMilestones.reduce((sum, milestone) => sum + Number(milestone.percentage), 0);
    if (!hasFixedAmounts && Math.abs(total - 100) > 0.01) {
      throw AppError.validation("A payment plan's milestones must add up to 100%.", {
        [field("milestones")]: `The milestones on "${plan.name}" currently total ${Number(total.toFixed(2))}%.`,
      });
    }
    return;
  }
  const headline =
    Number(plan.downPaymentPercent ?? 0) +
    Number(plan.duringConstructionPercent ?? 0) +
    Number(plan.onHandoverPercent ?? 0) +
    Number(plan.postHandoverPercent ?? 0);
  if (headline === 0) return; // A plan with no percentages at all is a cash plan.
  if (Math.abs(headline - 100) > 0.01) {
    throw AppError.validation("The payment plan must add up to 100%.", {
      [field("downPaymentPercent")]: `The instalments on "${plan.name}" currently total ${Number(headline.toFixed(2))}%.`,
    });
  }
}

async function writePaymentPlans({ projectId, plans, developerBrandId }, connection) {
  if (plans === undefined) return;
  plans.forEach(validatePaymentPlan);

  // Replaced wholesale: the form edits the full set, and a diff would leave a
  // plan an operator deleted still attached. ON DELETE CASCADE takes the
  // milestones with them.
  await execute("DELETE FROM project_payment_plans WHERE project_id = ?", [projectId], connection);

  for (const plan of plans) {
    const result = await execute(
      `INSERT INTO project_payment_plans
         (project_id, developer_brand_id, name, description, plan_type,
          down_payment_percent, during_construction_percent, on_handover_percent,
          post_handover_percent, post_handover_months, waives_registration_fee,
          service_charge_waiver_years, guaranteed_return_percent, guaranteed_return_years,
          is_active, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW(3), NOW(3))`,
      [
        projectId,
        developerBrandId,
        plan.name,
        plan.description ?? null,
        plan.planType ?? "construction_linked",
        plan.downPaymentPercent ?? null,
        plan.duringConstructionPercent ?? null,
        plan.onHandoverPercent ?? null,
        plan.postHandoverPercent ?? null,
        plan.postHandoverMonths ?? null,
        plan.waivesRegistrationFee ? 1 : 0,
        plan.serviceChargeWaiverYears ?? null,
        plan.guaranteedReturnPercent ?? null,
        plan.guaranteedReturnYears ?? null,
      ],
      connection
    );
    const planId = result.insertId;
    for (const [index, milestone] of (plan.milestones || []).entries()) {
      await execute(
        `INSERT INTO payment_plan_milestones
           (plan_id, sequence_number, name, trigger_type, construction_percent, months_offset,
            fixed_date, amount_percent, fixed_amount, currency_code, notes)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          planId,
          index + 1,
          milestone.name,
          milestone.triggerType ?? "months_from_booking",
          milestone.constructionPercent ?? null,
          milestone.monthsOffset ?? null,
          milestone.date || null,
          milestone.percentage ?? null,
          milestone.amount ?? null,
          milestone.currencyCode ?? null,
          milestone.notes ?? null,
        ],
        connection
      );
    }
  }
}

async function writeAmenities({ projectId, amenities }, connection) {
  if (amenities === undefined) return;
  await execute("DELETE FROM project_amenities WHERE project_id = ?", [projectId], connection);
  const seen = new Set();
  for (const [index, label] of amenities.entries()) {
    const slug = slugify(label).slice(0, 120);
    if (!slug || seen.has(slug)) continue;
    seen.add(slug);
    await execute(
      "INSERT INTO project_amenities (project_id, slug, label, sort_order, created_at) VALUES (?, ?, ?, ?, NOW(3))",
      [projectId, slug, label.slice(0, 160), index],
      connection
    );
  }
  // The legacy JSON column is kept in step so nothing reading it goes stale.
  await execute("UPDATE projects SET amenities = ? WHERE id = ?", [JSON.stringify(amenities), projectId], connection);
}

async function writeUnitTypes({ projectId, unitTypes }, connection) {
  if (unitTypes === undefined) return;
  await execute("DELETE FROM project_unit_types WHERE project_id = ?", [projectId], connection);
  for (const [index, unit] of unitTypes.entries()) {
    const areaUnitId = unit.areaUnit
      ? await queryValue("SELECT id FROM measurement_units WHERE code = ? LIMIT 1", [unit.areaUnit], connection)
      : null;
    await execute(
      `INSERT INTO project_unit_types
         (public_id, project_id, unit_type, name, bedrooms, bathrooms, min_size, max_size, area_unit_id,
          starting_price, max_price, currency_code, availability, available_units, total_units, sort_order,
          created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(3), NOW(3))`,
      [
        ulid(),
        projectId,
        unit.unitType,
        unit.name ?? null,
        unit.bedrooms ?? null,
        unit.bathrooms ?? null,
        unit.minSize ?? null,
        unit.maxSize ?? null,
        areaUnitId ?? null,
        unit.startingPrice ?? null,
        unit.maxPrice ?? null,
        unit.currencyCode ?? null,
        unit.availability ?? "available",
        unit.availableUnits ?? null,
        unit.totalUnits ?? null,
        unit.sortOrder ?? index,
      ],
      connection
    );
  }
}

/** Resolves a media asset's public id to its row, refusing an unknown one. */
async function resolveMediaAsset(publicId, connection) {
  if (!publicId) return null;
  const asset = await queryOne(
    "SELECT id, COALESCE(cdn_url, url) AS url FROM media_assets WHERE public_id = ? AND deleted_at IS NULL LIMIT 1",
    [publicId],
    connection
  );
  if (!asset) {
    throw AppError.validation("Some information is invalid.", {
      mediaAssetId: "That file was not found in the media library.",
    });
  }
  return asset;
}

/**
 * Media, as attachments rather than as file objects held in browser state.
 *
 * The wizard kept uploads in a React state array and posted none of them, so a
 * gallery survived exactly as long as the tab did. Assets are uploaded through
 * the media library first and referenced here by public id.
 */
async function writeMedia({ projectId, payload }, connection) {
  const roles = { gallery: payload.gallery, masterplan: payload.masterplan, video: payload.video, brochure: payload.brochure };
  for (const [role, entries] of Object.entries(roles)) {
    if (entries === undefined) continue;
    await execute(
      "DELETE FROM media_attachments WHERE attachable_type = 'project' AND attachable_id = ? AND role = ?",
      [projectId, role],
      connection
    );
    for (const [index, entry] of entries.entries()) {
      const asset = await resolveMediaAsset(entry.mediaAssetId, connection);
      await execute(
        `INSERT INTO media_attachments
           (media_asset_id, attachable_type, attachable_id, role, sort_order, is_primary, caption, created_at)
         VALUES (?, 'project', ?, ?, ?, ?, ?, NOW(3))
         ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order), is_primary = VALUES(is_primary), caption = VALUES(caption)`,
        [asset.id, projectId, role, entry.sortOrder ?? index, entry.isPrimary ? 1 : 0, entry.caption ?? null],
        connection
      );
    }
    // The card reads `cover_image_url`; keeping it in step with the primary
    // gallery image is what stops a project publishing with a blank tile.
    if (role === "gallery") {
      const primary = entries.find((entry) => entry.isPrimary) || entries[0];
      const asset = primary ? await resolveMediaAsset(primary.mediaAssetId, connection) : null;
      await execute("UPDATE projects SET cover_image_url = ? WHERE id = ?", [asset?.url ?? null, projectId], connection);
    }
  }

  if (payload.floorPlans !== undefined) {
    await execute("DELETE FROM floor_plans WHERE project_id = ?", [projectId], connection);
    for (const [index, plan] of payload.floorPlans.entries()) {
      const asset = plan.mediaAssetId ? await resolveMediaAsset(plan.mediaAssetId, connection) : null;
      await execute(
        `INSERT INTO floor_plans
           (project_id, name, unit_type, bedrooms, floor_level, media_asset_id, total_area_sqm,
            total_area_sqft, is_public, requires_lead, sort_order, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(3), NOW(3))`,
        [
          projectId,
          plan.name,
          plan.unitType ?? null,
          plan.bedrooms ?? null,
          plan.floorLevel ?? null,
          asset?.id ?? null,
          plan.areaSqm ?? null,
          plan.areaSqft ?? null,
          plan.isPublic === false ? 0 : 1,
          plan.requiresLead ? 1 : 0,
          plan.sortOrder ?? index,
        ],
        connection
      );
    }
  }

  if (payload.documents !== undefined) {
    // Soft-deleted rather than removed: a document may already have access
    // grants and download history attached to it.
    await execute(
      "UPDATE documents SET deleted_at = NOW(3) WHERE owner_type = 'project' AND owner_id = ? AND deleted_at IS NULL",
      [projectId],
      connection
    );
    for (const document of payload.documents) {
      const asset = document.mediaAssetId ? await resolveMediaAsset(document.mediaAssetId, connection) : null;
      await execute(
        `INSERT INTO documents
           (public_id, media_asset_id, owner_type, owner_id, document_type, title, description,
            visibility, version, status, created_at, updated_at)
         VALUES (?, ?, 'project', ?, ?, ?, ?, ?, ?, 'active', NOW(3), NOW(3))`,
        [
          ulid(),
          asset?.id ?? null,
          projectId,
          document.documentType ?? "other",
          document.title,
          document.description ?? null,
          document.visibility ?? "gated",
          document.version ?? null,
        ],
        connection
      );
    }
  }
}

/**
 * `published_at` is set the first time a project becomes published and is never
 * moved by a later edit — it is the publication date, not the last-saved date,
 * and the sitemap and the "recently launched" rail both read it.
 */
function publicationAssignments(payload, current) {
  const assignments = [];
  const params = [];
  const nextModeration = payload.moderationStatus ?? current?.moderation_status;
  const becomingPublished =
    nextModeration === "published" && payload.isPubliclyVisible !== false && !current?.published_at;
  if (becomingPublished) {
    assignments.push("published_at = NOW(3)");
  }
  // Publication is one decision expressed in two columns; keeping them in step
  // here means no screen has to reason about a published-but-invisible project.
  if (payload.moderationStatus !== undefined && payload.isPubliclyVisible === undefined) {
    assignments.push("is_publicly_visible = ?");
    params.push(nextModeration === "published" ? 1 : 0);
  }
  // A rejection reason belongs to one rejection. Once the moderation status
  // moves off "rejected" — republished, restored to draft, whatever comes next
  // — the old reason would otherwise linger and read as live. `DEVELOPMENT_COLUMNS`
  // already writes an explicitly-sent `rejectionReason` (the Reject action always
  // sends one); this only clears it when the caller did not.
  if (
    payload.moderationStatus !== undefined &&
    nextModeration !== "rejected" &&
    payload.rejectionReason === undefined &&
    current?.rejection_reason
  ) {
    assignments.push("rejection_reason = NULL");
  }
  return { assignments, params };
}

/**
 * Fill in the ancestors of whatever location the operator actually picked.
 *
 * The form asks for a community; the canonical path needs country, state, city
 * and community, and a filter needs every tier the project sits under. Deriving
 * them from `locations`' own denormalised ancestry means an operator cannot
 * produce a project filed under a city in the wrong state, and cannot end up
 * with a truncated public URL because a tier they never saw was left null.
 *
 * Explicit values win: an operator who did set a tier is not overruled.
 */
async function resolveLocationAncestry(payload, connection) {
  const deepest =
    payload.subCommunityId ?? payload.communityId ?? payload.cityId ?? payload.stateId ?? payload.countryId ?? null;
  if (!deepest) return {};
  const row = await queryOne(
    "SELECT id, level, country_id, state_id, city_id, community_id FROM locations WHERE id = ? AND deleted_at IS NULL LIMIT 1",
    [deepest],
    connection
  );
  if (!row) {
    throw AppError.validation("Some information is invalid.", { communityId: "That location was not found." });
  }
  const own = {
    country: row.level === "country" ? row.id : row.country_id,
    state: row.level === "state" ? row.id : row.state_id,
    city: row.level === "city" ? row.id : row.city_id,
    community: ["community", "district"].includes(row.level) ? row.id : row.community_id,
    subCommunity: ["sub_community", "building"].includes(row.level) ? row.id : null,
  };
  return {
    countryId: payload.countryId ?? own.country ?? null,
    stateId: payload.stateId ?? own.state ?? null,
    cityId: payload.cityId ?? own.city ?? null,
    communityId: payload.communityId ?? own.community ?? null,
    subCommunityId: payload.subCommunityId ?? own.subCommunity ?? null,
  };
}

export async function upsertDevelopment({ identifier, payload, userId }) {
  // A single `paymentPlan` from an older caller becomes the one-element set, so
  // there is one write path and one validation rule.
  const plans = payload.paymentPlans ?? (payload.paymentPlan ? [payload.paymentPlan] : undefined);

  const projectId = await withTransaction(async (connection) => {
    let developerBrandId = null;
    if (payload.developerId) {
      const brand = await queryOne(
        "SELECT id FROM brands WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL LIMIT 1",
        [payload.developerId, payload.developerId],
        connection
      );
      if (!brand) throw AppError.validation("Some information is invalid.", { developerId: "That developer was not found." });
      developerBrandId = brand.id;
    }

    const located = { ...payload, ...(await resolveLocationAncestry(payload, connection)) };

    const assignments = [];
    const params = [];
    for (const [key, column] of Object.entries(DEVELOPMENT_COLUMNS)) {
      if (located[key] === undefined) continue;
      assignments.push(`${column} = ?`);
      params.push(typeof located[key] === "boolean" ? (located[key] ? 1 : 0) : located[key]);
    }
    if (payload.highlights !== undefined) {
      assignments.push("highlights = ?");
      params.push(JSON.stringify(payload.highlights));
    }
    if (developerBrandId) {
      assignments.push("developer_brand_id = ?");
      params.push(developerBrandId);
    }

    let project;
    if (identifier) {
      project = await queryOne(
        "SELECT id, public_id, slug, moderation_status, published_at, rejection_reason FROM projects WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL LIMIT 1",
        [identifier, identifier],
        connection
      );
      if (!project) throw AppError.notFound("That development was not found.");
    } else {
      const publicId = ulid();
      const base = slugify(payload.name).slice(0, 180) || "development";
      // Every project hangs off the Real Estate root; the caller may narrow it
      // to a sub-category but has no natural place on the form to be asked.
      const categoryId =
        payload.categoryId ??
        (await queryValue("SELECT id FROM categories WHERE code = 'real-estate' AND depth = 0 LIMIT 1", [], connection));
      const result = await execute(
        `INSERT INTO projects (public_id, name, slug, category_id, status, moderation_status,
                               is_publicly_visible, listing_count, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, 'draft', 0, 0, NOW(3), NOW(3))`,
        [publicId, payload.name, base, categoryId, payload.status ?? "announced"],
        connection
      );
      await execute("UPDATE projects SET slug = ? WHERE id = ?", [`${base}-${result.insertId}`, result.insertId], connection);
      project = { id: result.insertId, public_id: publicId, slug: `${base}-${result.insertId}`, moderation_status: "draft", published_at: null };
    }

    const publication = publicationAssignments(payload, project);
    const allAssignments = [...assignments, ...publication.assignments];
    if (allAssignments.length) {
      await execute(
        `UPDATE projects SET ${allAssignments.join(", ")}, updated_at = NOW(3) WHERE id = ?`,
        [...params, ...publication.params, project.id],
        connection
      );
    }

    await writePaymentPlans({ projectId: project.id, plans, developerBrandId }, connection);
    await writeAmenities({ projectId: project.id, amenities: payload.amenities }, connection);
    await writeUnitTypes({ projectId: project.id, unitTypes: payload.unitTypes }, connection);
    await writeMedia({ projectId: project.id, payload }, connection);

    /**
     * The canonical path is rebuilt inside the same transaction, every time.
     *
     * A slug or location edit that left a stale path would either 404 the
     * project or leave two URLs claiming it. `sp_rebuild_project_canonical_path`
     * is the only writer of that column, so this is the one call site.
     */
    await callProcedure("sp_rebuild_project_canonical_path", [project.id], connection);
    return { id: project.id, publicId: project.public_id, created: !identifier };
  });

  /**
   * The public projection is refreshed after the transaction commits.
   *
   * It reads the committed row — including the visibility rules that decide
   * whether the project belongs in it at all — so refreshing inside the
   * transaction would project uncommitted state, and an unpublish would leave
   * the row searchable until the next write.
   */
  await callProcedure("sp_refresh_project_search", [projectId.id]);

  return projectId.created
    ? { id: projectId.publicId, created: true, actorUserId: userId }
    : { id: projectId.publicId, updated: true };
}

export async function archiveDevelopment({ identifier }) {
  const project = await queryOne(
    "SELECT id, public_id, listing_count FROM projects WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL LIMIT 1",
    [identifier, identifier]
  );
  if (!project) throw AppError.notFound("That development was not found.");
  // Listings point at the project; removing it under them would orphan live inventory.
  const live = await queryValue(
    "SELECT COUNT(*) FROM listings WHERE project_id = ? AND deleted_at IS NULL AND status = 'active'",
    [project.id]
  );
  if (Number(live) > 0) {
    throw AppError.conflict(`${live} active listings still belong to this development.`);
  }
  await execute(
    "UPDATE projects SET deleted_at = NOW(3), is_publicly_visible = 0, moderation_status = 'archived' WHERE id = ?",
    [project.id]
  );
  // Out of the projection immediately: an archived project has no public page,
  // and leaving the row would keep it in results and in the sitemap.
  await callProcedure("sp_refresh_project_search", [project.id]);
  return { id: project.public_id, archived: true };
}

/* -------------------------------------------------------------------------- */
/* Brands and models                                                           */
/* -------------------------------------------------------------------------- */
/**
 * Inventory breadth was capped by a SQL file.
 *
 * Listing creation verifies the brand and model against the catalogue and refuses anything not
 * in it ("That make is not in the catalogue."). The catalogue was seeded once by
 * `031_brands.sql` and no endpoint could add to it, so onboarding a marque meant a migration.
 * These close that: taxonomy is data, and administrators who hold `taxonomy.create` maintain it.
 */
export const brandSchema = z.object({
  name: z.string().trim().min(1).max(160),
  kind: z.enum(["car_make", "yacht_builder", "aircraft_manufacturer", "watch_brand", "property_developer"]),
  description: z.string().trim().max(4000).optional().nullable(),
  logoUrl: z.string().trim().max(500).optional().nullable(),
  websiteUrl: z.string().trim().max(255).optional().nullable(),
  countryId: z.coerce.number().int().positive().optional().nullable(),
  foundedYear: z.coerce.number().int().min(1600).max(2200).optional().nullable(),
  isLuxury: z.boolean().optional(),
  isActive: z.boolean().optional(),
  sortOrder: z.coerce.number().int().min(0).max(10000).optional(),
});

export const brandModelSchema = z.object({
  brandId: z.string().trim().max(60),
  name: z.string().trim().min(1).max(160),
  parentId: z.string().trim().max(60).optional().nullable(),
  referenceCode: z.string().trim().max(80).optional().nullable(),
  bodyType: z.string().trim().max(60).optional().nullable(),
  productionStartYear: z.coerce.number().int().min(1600).max(2200).optional().nullable(),
  productionEndYear: z.coerce.number().int().min(1600).max(2200).optional().nullable(),
  isActive: z.boolean().optional(),
});

export async function upsertBrand({ identifier, payload }) {
  return withTransaction(async (connection) => {
    const columns = {
      name: payload.name,
      kind: payload.kind,
      description: payload.description ?? null,
      logo_url: payload.logoUrl ?? null,
      website_url: payload.websiteUrl ?? null,
      country_id: payload.countryId ?? null,
      founded_year: payload.foundedYear ?? null,
      is_luxury: payload.isLuxury ? 1 : 0,
      is_active: payload.isActive === false ? 0 : 1,
      sort_order: payload.sortOrder ?? 0,
    };

    if (identifier) {
      const brand = await queryOne(
        "SELECT id, public_id FROM brands WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL LIMIT 1",
        [identifier, identifier],
        connection
      );
      if (!brand) throw AppError.notFound("That brand was not found.");
      const keys = Object.keys(columns);
      await execute(
        `UPDATE brands SET ${keys.map((key) => `${key} = ?`).join(", ")}, updated_at = NOW(3) WHERE id = ?`,
        [...keys.map((key) => columns[key]), brand.id],
        connection
      );
      return { id: brand.public_id, updated: true };
    }

    // Slugs are the public URL segment for a brand, so a collision is a real conflict rather
    // than something to paper over with a suffix.
    const slug = slugify(payload.name).slice(0, 160);
    const clash = await queryValue("SELECT id FROM brands WHERE slug = ? AND kind = ?", [slug, payload.kind], connection);
    if (clash) throw AppError.conflict("A brand with that name already exists in this category.");

    const publicId = ulid();
    const keys = Object.keys(columns);
    await execute(
      `INSERT INTO brands (public_id, slug, ${keys.join(", ")}, created_at, updated_at)
       VALUES (?, ?, ${keys.map(() => "?").join(", ")}, NOW(3), NOW(3))`,
      [publicId, slug, ...keys.map((key) => columns[key])],
      connection
    );
    return { id: publicId, created: true };
  });
}

export async function archiveBrand({ identifier }) {
  const brand = await queryOne(
    "SELECT id, public_id FROM brands WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL LIMIT 1",
    [identifier, identifier]
  );
  if (!brand) throw AppError.notFound("That brand was not found.");
  const live = await queryValue("SELECT COUNT(*) FROM listings WHERE brand_id = ? AND deleted_at IS NULL", [brand.id]);
  if (Number(live) > 0) throw AppError.conflict(`${live} listings still use this brand.`);
  await execute("UPDATE brands SET deleted_at = NOW(3), is_active = 0 WHERE id = ?", [brand.id]);
  return { id: brand.public_id, archived: true };
}

export async function upsertBrandModel({ identifier, payload }) {
  return withTransaction(async (connection) => {
    const brand = await queryOne(
      "SELECT id FROM brands WHERE (public_id = ? OR slug = ?) AND deleted_at IS NULL LIMIT 1",
      [payload.brandId, payload.brandId],
      connection
    );
    if (!brand) throw AppError.validation("Some information is invalid.", { brandId: "That brand was not found." });

    let parentId = null;
    if (payload.parentId) {
      const parent = await queryOne(
        "SELECT id, brand_id FROM brand_models WHERE (id = ? OR slug = ?) LIMIT 1",
        [/^\d+$/.test(String(payload.parentId)) ? Number(payload.parentId) : 0, String(payload.parentId)],
        connection
      );
      // A model whose parent belongs to a different marque would make the catalogue tree lie.
      if (!parent || String(parent.brand_id) !== String(brand.id)) {
        throw AppError.validation("Some information is invalid.", { parentId: "That parent model belongs to a different brand." });
      }
      parentId = parent.id;
    }

    if (payload.productionEndYear && payload.productionStartYear && payload.productionEndYear < payload.productionStartYear) {
      throw AppError.validation("Some information is invalid.", {
        productionEndYear: "Production cannot end before it starts.",
      });
    }

    const columns = {
      brand_id: brand.id,
      parent_id: parentId,
      name: payload.name,
      reference_code: payload.referenceCode ?? null,
      body_type: payload.bodyType ?? null,
      production_start_year: payload.productionStartYear ?? null,
      production_end_year: payload.productionEndYear ?? null,
      is_active: payload.isActive === false ? 0 : 1,
    };

    if (identifier) {
      const model = await queryOne(
        "SELECT id FROM brand_models WHERE id = ? OR slug = ? LIMIT 1",
        [/^\d+$/.test(String(identifier)) ? Number(identifier) : 0, String(identifier)],
        connection
      );
      if (!model) throw AppError.notFound("That model was not found.");
      const keys = Object.keys(columns);
      await execute(
        `UPDATE brand_models SET ${keys.map((key) => `${key} = ?`).join(", ")}, updated_at = NOW(3) WHERE id = ?`,
        [...keys.map((key) => columns[key]), model.id],
        connection
      );
      return { id: String(model.id), updated: true };
    }

    const slug = slugify(payload.name).slice(0, 160);
    const clash = await queryValue("SELECT id FROM brand_models WHERE brand_id = ? AND slug = ?", [brand.id, slug], connection);
    if (clash) throw AppError.conflict("That brand already has a model with this name.");

    const keys = Object.keys(columns);
    const result = await execute(
      `INSERT INTO brand_models (slug, ${keys.join(", ")}, created_at, updated_at)
       VALUES (?, ${keys.map(() => "?").join(", ")}, NOW(3), NOW(3))`,
      [slug, ...keys.map((key) => columns[key])],
      connection
    );
    return { id: String(result.insertId), created: true };
  });
}

export async function archiveBrandModel({ identifier }) {
  const model = await queryOne(
    "SELECT id FROM brand_models WHERE id = ? OR slug = ? LIMIT 1",
    [/^\d+$/.test(String(identifier)) ? Number(identifier) : 0, String(identifier)]
  );
  if (!model) throw AppError.notFound("That model was not found.");
  const live = await queryValue("SELECT COUNT(*) FROM listings WHERE brand_model_id = ? AND deleted_at IS NULL", [model.id]);
  if (Number(live) > 0) throw AppError.conflict(`${live} listings still use this model.`);
  await execute("UPDATE brand_models SET is_active = 0 WHERE id = ?", [model.id]);
  return { id: String(model.id), archived: true };
}
