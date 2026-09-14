import { Router } from "express";
import { z } from "zod";
import { asyncHandler } from "../../middleware/errors.js";
import { validate, q } from "../../middleware/validation.js";
import { writeLimiter } from "../../middleware/rateLimit.js";
import { requireAuth, requireAccount, requireAccountCapability } from "../../middleware/auth.js";
import { AppError } from "../../utils/errors.js";
import { listResponse, detailResponse } from "../../utils/http.js";
import { auditFromRequest } from "../system/audit.service.js";
import { requireAccountId, requireOrganizationId, assertListingAccess } from "./authorization.js";
import * as portalRepo from "./portal.repository.js";
import * as engagement from "./engagement.repository.js";
import * as listingsService from "../listings/listings.service.js";
import * as listingsRepo from "../listings/listings.repository.js";
import * as profileService from "./profile.service.js";
import * as organizationService from "./organization.service.js";
import * as settingsService from "./settings.service.js";
import { createListingSchema, updateListingSchema, listingStatusSchema } from "../listings/listings.schemas.js";
import { listListingMedia } from "../media/listingMedia.service.js";
import { query, queryOne, execute, callProcedure } from "../../db/query.js";
import { developmentSchema, upsertDevelopment } from "../admin/admin.mutations.js";
import { getAdminDevelopment } from "../admin/admin.catalog.js";
import { developmentAttachments } from "../projects/developmentAttachments.service.js";
import { withTransaction } from "../../db/transaction.js";
import { ulid } from "../../utils/ids.js";

const router = Router();

// Everything below this line requires a signed-in caller with an active
// membership. Nothing in the portal is reachable without one.
router.use(requireAuth, requireAccount);

const scope = (req) => ({
  accountId: requireAccountId(req),
  organizationId: req.auth.activeMembership?.organization_id ?? null,
  userId: req.auth.user.id,
  agentId: req.auth.agent?.id ?? null,
});

const listQuery = z
  .object({
    page: z.coerce.number().int().min(1).max(2000).optional(),
    pageSize: z.coerce.number().int().min(1).max(100).optional(),
    status: z.string().trim().max(40).optional(),
    category: z.string().trim().max(40).optional(),
    search: z.string().trim().max(200).optional(),
    sort: z.string().trim().max(40).optional(),
    listing: z.string().trim().max(64).optional(),
    from: z.string().trim().max(30).optional(),
    to: z.string().trim().max(30).optional(),
    view: z.string().trim().max(20).optional(),
    location: z.string().trim().max(120).optional(),
    filter: z.string().trim().max(30).optional(),
    conversationId: z.string().trim().max(64).optional(),
  })
  .partial();

/* -------------------------------------------------------------------------- */
/* Dashboard                                                                   */
/* -------------------------------------------------------------------------- */

router.get(
  "/dashboard",
  asyncHandler(async (req, res) => {
    const { accountId, organizationId } = scope(req);
    return res.json(detailResponse(await portalRepo.accountDashboard({ accountId, organizationId })));
  })
);

/* -------------------------------------------------------------------------- */
/* Listings                                                                    */
/* -------------------------------------------------------------------------- */

router.get(
  "/listings",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { accountId, agentId } = scope(req);
    // An agent-role member sees only their own inventory.
    const restrictToAgent = req.auth.activeMembership?.role === "agent" ? agentId : null;
    const result = await portalRepo.listAccountListings({
      accountId,
      status: params.status || "all",
      category: params.category || "all",
      search: params.search || "",
      sort: params.sort || "newest",
      page: params.page || 1,
      pageSize: params.pageSize || 5,
      agentId: restrictToAgent,
    });
    return res.json({
      ...listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }),
      counts: result.counts,
      overview: result.overview,
    });
  })
);

router.get(
  "/listings/:id",
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.id, "view");
    const detail = await listingsRepo.getListingDetail({ id: listing.id }, { source: "any", includePrivate: true });
    const media = await listListingMedia(listing.id, { includePrivate: true });
    const summary = await portalRepo.getAccountListing({ accountId: listing.account_id, identifier: listing.public_id });
    return res.json(
      detailResponse({
        ...detail.detail,
        status: listing.status,
        moderationStatus: listing.moderation_status,
        // The owner's own listing is the one place this belongs — admin already
        // knows why it rejected something. Never leaked outside `rejected`, so a
        // stale value from a listing's earlier lifecycle can't resurface later.
        rejectionReason: listing.moderation_status === "rejected" ? listing.rejection_reason || null : null,
        media,
        gallery: media,
        summary: summary ? portalRepo.serializePortalListing(summary) : null,
      })
    );
  })
);

router.post(
  "/listings",
  writeLimiter,
  requireAccountCapability("can_manage_listings"),
  validate({ body: createListingSchema }),
  asyncHandler(async (req, res) => {
    const { accountId, organizationId, userId, agentId } = scope(req);

    // Quota is enforced server-side; the form's own count is advisory.
    const account = await queryOne(
      "SELECT listing_quota, listing_used FROM accounts WHERE id = ?",
      [accountId]
    );
    if (account?.listing_quota !== null && Number(account.listing_used) >= Number(account.listing_quota)) {
      throw AppError.conflict("This account has used its listing allowance. Upgrade the plan to add more.");
    }

    // Organizations may only list in a category they have been approved for.
    if (organizationId) {
      await organizationService.assertCategoryAccess({ organizationId, category: req.body.category });
    }

    const created = await listingsService.createListing({
      payload: req.body,
      accountId,
      userId,
      organizationId,
      agentId,
      ip: req.ip,
    });

    await auditFromRequest(req, {
      action: "listing.created",
      subjectType: "listing",
      subjectId: created.listingId,
      subjectLabel: req.body.title,
      metadata: { category: req.body.category, status: created.status },
    });

    const summary = await portalRepo.getAccountListing({ accountId, identifier: created.publicId });
    return res.status(201).json(detailResponse(portalRepo.serializePortalListing(summary)));
  })
);

router.patch(
  "/listings/:id",
  writeLimiter,
  requireAccountCapability("can_manage_listings"),
  validate({ body: updateListingSchema }),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.id, "edit");
    const { accountId, organizationId, userId } = scope(req);
    await listingsService.updateListing({ listing, payload: req.body, userId, accountId, organizationId });
    // A live listing the owner changes goes back for review (off the public site until approved
    // again); any other listing takes the edit form's "Save draft" / "Submit for review" choice.
    // A platform user editing through the portal is not the owner and changes no status here.
    const statusChange = req.auth.platform.roles.length
      ? { changed: false }
      : await listingsService.applyOwnerEditStatus({
          listing,
          requestedStatus: req.body.status,
          edited: Object.keys(req.body).some((key) => key !== "status"),
          userId,
        });
    await auditFromRequest(req, {
      action: "listing.updated",
      subjectType: "listing",
      subjectId: listing.id,
      subjectLabel: listing.title,
      changes: req.body,
      ...(statusChange.changed ? { metadata: { statusChange } } : {}),
    });
    const summary = await portalRepo.getAccountListing({ accountId: listing.account_id, identifier: listing.public_id });
    return res.json(detailResponse(portalRepo.serializePortalListing(summary)));
  })
);

router.patch(
  "/listings/:id/status",
  writeLimiter,
  requireAccountCapability("can_manage_listings"),
  validate({ body: listingStatusSchema }),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.id, "edit");
    // Publishing is a moderator action; the portal may submit for review.
    if (req.body.status === "active" && !req.auth.platform.roles.length) {
      throw AppError.forbidden("Listings become live after review. Submit it for review instead.");
    }
    const result = await listingsService.changeListingStatus({
      listing,
      toStatus: req.body.status,
      reason: req.body.reason,
      userId: req.auth.user.id,
    });
    await auditFromRequest(req, {
      action: "listing.status_changed",
      subjectType: "listing",
      subjectId: listing.id,
      changes: result,
    });
    const summary = await portalRepo.getAccountListing({ accountId: listing.account_id, identifier: listing.public_id });
    return res.json(detailResponse(portalRepo.serializePortalListing(summary)));
  })
);

router.delete(
  "/listings/:id",
  writeLimiter,
  requireAccountCapability("can_manage_listings"),
  asyncHandler(async (req, res) => {
    const listing = await assertListingAccess(req, req.params.id, "edit");
    // A listing is archived, never destroyed: inquiries, offers and audit rows
    // reference it.
    await listingsService.archiveListing({ listing, userId: req.auth.user.id, reason: req.body?.reason });
    await auditFromRequest(req, { action: "listing.archived", subjectType: "listing", subjectId: listing.id });
    return res.json(detailResponse({ archived: true, id: listing.public_id }));
  })
);

/* -------------------------------------------------------------------------- */
/* Inquiries, leads, messages                                                  */
/* -------------------------------------------------------------------------- */

router.get(
  "/inquiries",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { accountId, organizationId } = scope(req);
    const result = await engagement.listInquiries({ accountId, organizationId, ...params });
    return res.json({
      ...listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }),
      counts: result.counts,
      listings: result.listings,
    });
  })
);

router.patch(
  "/inquiries/:id",
  writeLimiter,
  requireAccountCapability("can_manage_leads"),
  validate({
    body: z.object({
      // Every `inquiries.status` value: viewing_scheduled and negotiating were readable but not settable.
      status: z.enum(["new", "contacted", "qualified", "viewing_scheduled", "negotiating", "won", "lost", "closed", "spam"]).optional(),
      priority: z.enum(["low", "normal", "high", "urgent"]).optional(),
      assignedAgentId: z.string().max(64).nullable().optional(),
      note: z.string().trim().max(2000).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { accountId, organizationId } = scope(req);
    const inquiry = await queryOne(
      `SELECT id, public_id, status FROM inquiries
        WHERE public_id = ? AND (account_id = ? OR organization_id <=> ?) AND deleted_at IS NULL`,
      [req.params.id, accountId, organizationId]
    );
    if (!inquiry) throw AppError.notFound("That inquiry was not found.");

    await withTransaction(async (connection) => {
      const assignments = [];
      const params = [];
      if (req.body.status) {
        assignments.push("status = ?");
        params.push(req.body.status === "spam" ? "lost" : req.body.status);
        if (req.body.status === "spam") assignments.push("is_spam = 1");
        if (req.body.status !== "new") assignments.push("first_response_at = COALESCE(first_response_at, NOW(3))");
      }
      if (req.body.priority) {
        assignments.push("priority = ?");
        params.push(req.body.priority);
      }
      if (req.body.assignedAgentId !== undefined) {
        const agent = req.body.assignedAgentId
          ? await queryOne(
              "SELECT id FROM agents WHERE public_id = ? AND organization_id <=> ? AND deleted_at IS NULL",
              [req.body.assignedAgentId, organizationId],
              connection
            )
          : null;
        if (req.body.assignedAgentId && !agent) {
          throw AppError.validation("Some information is invalid.", { assignedAgentId: "That agent is not on this account." });
        }
        assignments.push("assigned_to_agent_id = ?", "assigned_at = NOW(3)");
        params.push(agent?.id ?? null);
      }
      assignments.push("last_activity_at = NOW(3)");

      await execute(`UPDATE inquiries SET ${assignments.join(", ")} WHERE id = ?`, [...params, inquiry.id], connection);

      if (req.body.status && req.body.status !== inquiry.status) {
        await execute(
          // The column is `reason`, not `note` — the insert had never run, so every status
          // change through this endpoint failed with a 500 rather than recording its history.
          `INSERT INTO inquiry_status_history (inquiry_id, from_status, to_status, changed_by_user_id, reason, changed_at)
           VALUES (?, ?, ?, ?, ?, NOW(3))`,
          [inquiry.id, inquiry.status, req.body.status, req.auth.user.id, req.body.note || null],
          connection
        );
      }
      if (req.body.note) {
        await execute(
          `INSERT INTO inquiry_notes (inquiry_id, user_id, note, is_internal, created_at)
           VALUES (?, ?, ?, 1, NOW(3))`,
          [inquiry.id, req.auth.user.id, req.body.note],
          connection
        );
      }
    });

    await auditFromRequest(req, {
      action: "inquiry.updated",
      subjectType: "inquiry",
      subjectId: inquiry.id,
      changes: req.body,
    });
    return res.json(detailResponse({ id: inquiry.public_id, updated: true }));
  })
);

router.get(
  "/leads",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { accountId, organizationId } = scope(req);
    const result = await engagement.listLeads({ accountId, organizationId, ...params });
    return res.json(listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }));
  })
);

router.patch(
  "/leads/:id",
  writeLimiter,
  requireAccountCapability("can_manage_leads"),
  validate({
    body: z.object({
      stageId: z.coerce.number().int().positive().optional(),
      status: z.enum(["new", "working", "qualified", "unqualified", "converted", "lost", "dormant"]).optional(),
      ownerAgentId: z.string().max(64).nullable().optional(),
      note: z.string().trim().max(2000).optional(),
      nextActionAt: z.string().max(40).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { accountId, organizationId } = scope(req);
    const lead = await queryOne(
      `SELECT id, public_id, stage_id, status FROM leads
        WHERE public_id = ? AND (account_id = ? OR organization_id <=> ?) AND deleted_at IS NULL`,
      [req.params.id, accountId, organizationId]
    );
    if (!lead) throw AppError.notFound("That lead was not found.");

    // Stage change and its history row are one transaction; a pipeline whose
    // history disagrees with its current stage is unauditable.
    await withTransaction(async (connection) => {
      const assignments = ["last_activity_at = NOW(3)"];
      const params = [];
      if (req.body.stageId && req.body.stageId !== lead.stage_id) {
        const stage = await queryOne(
          "SELECT id, name, stage_type FROM lead_pipeline_stages WHERE id = ?",
          [req.body.stageId],
          connection
        );
        if (!stage) throw AppError.validation("Some information is invalid.", { stageId: "Unknown pipeline stage." });
        assignments.push("stage_id = ?", "stage_type = ?", "stage_entered_at = NOW(3)");
        params.push(stage.id, stage.stage_type);
        await execute(
          `INSERT INTO lead_stage_history (lead_id, from_stage_id, to_stage_id, changed_by_user_id, note, changed_at)
           VALUES (?, ?, ?, ?, ?, NOW(3))`,
          [lead.id, lead.stage_id, stage.id, req.auth.user.id, req.body.note || null],
          connection
        );
      }
      if (req.body.status) {
        assignments.push("status = ?");
        params.push(req.body.status);
      }
      if (req.body.ownerAgentId !== undefined) {
        const agent = req.body.ownerAgentId
          ? await queryOne("SELECT id FROM agents WHERE public_id = ? AND organization_id <=> ?", [req.body.ownerAgentId, organizationId], connection)
          : null;
        if (req.body.ownerAgentId && !agent) {
          throw AppError.validation("Some information is invalid.", { ownerAgentId: "That agent is not on this account." });
        }
        assignments.push("owner_agent_id = ?", "assigned_at = NOW(3)", "assignment_method = 'manual'");
        params.push(agent?.id ?? null);
      }
      if (req.body.nextActionAt) {
        assignments.push("next_action_at = ?");
        params.push(new Date(req.body.nextActionAt));
      }
      await execute(`UPDATE leads SET ${assignments.join(", ")} WHERE id = ?`, [...params, lead.id], connection);

      if (req.body.note) {
        await execute(
          // `subject_line` and `user_id` — the previous names did not exist, so adding a note
          // to a lead failed with a 500 rather than recording anything.
          `INSERT INTO activities (public_id, organization_id, lead_id, contact_id, activity_type, subject_line, body,
                                   user_id, occurred_at, created_at, updated_at)
           SELECT ?, l.organization_id, l.id, l.contact_id, 'note', 'Portal note', ?, ?, NOW(3), NOW(3), NOW(3)
             FROM leads l WHERE l.id = ?`,
          [ulid(), req.body.note, req.auth.user.id, lead.id],
          connection
        );
      }
    });

    await auditFromRequest(req, { action: "lead.updated", subjectType: "lead", subjectId: lead.id, changes: req.body });
    return res.json(detailResponse({ id: lead.public_id, updated: true }));
  })
);

router.get(
  "/messages",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { userId, organizationId } = scope(req);
    const result = await engagement.listConversations({
      userId,
      organizationId,
      filter: params.filter || "all",
      conversationId: params.conversationId || null,
    });
    return res.json(detailResponse(result));
  })
);

router.post(
  "/messages/:conversationId",
  writeLimiter,
  validate({ body: z.object({ body: z.string().trim().min(1, "Write a message.").max(5000) }) }),
  asyncHandler(async (req, res) => {
    const { userId } = scope(req);
    const conversation = await queryOne(
      `SELECT c.id, c.public_id FROM conversations c
         JOIN conversation_participants cp ON cp.conversation_id = c.id AND cp.user_id = ?
        WHERE c.public_id = ? LIMIT 1`,
      [userId, req.params.conversationId]
    );
    if (!conversation) throw AppError.notFound("That conversation was not found.");

    const publicId = ulid();
    await withTransaction(async (connection) => {
      await execute(
        `INSERT INTO messages (public_id, conversation_id, sender_user_id, sender_type, body,
                               body_format, status, channel, created_at)
         VALUES (?, ?, ?, 'user', ?, 'text', 'sent', 'in_app', NOW(3))`,
        [publicId, conversation.id, userId, req.body.body],
        connection
      );
      await execute(
        `UPDATE conversations
            SET last_message_at = NOW(3), last_message_preview = ?, last_message_by_user_id = ?,
                message_count = message_count + 1
          WHERE id = ?`,
        [req.body.body.slice(0, 200), userId, conversation.id],
        connection
      );
      // Everyone except the sender gains an unread.
      await execute(
        "UPDATE conversation_participants SET unread_count = unread_count + 1 WHERE conversation_id = ? AND user_id <> ?",
        [conversation.id, userId],
        connection
      );
      await execute(
        "UPDATE conversation_participants SET unread_count = 0, last_read_at = NOW(3) WHERE conversation_id = ? AND user_id = ?",
        [conversation.id, userId],
        connection
      );
    });
    return res.status(201).json(detailResponse({ id: publicId, sent: true }));
  })
);

router.post(
  "/messages/:conversationId/read",
  asyncHandler(async (req, res) => {
    const { userId } = scope(req);
    await execute(
      `UPDATE conversation_participants cp
         JOIN conversations c ON c.id = cp.conversation_id
          SET cp.unread_count = 0, cp.last_read_at = NOW(3)
        WHERE c.public_id = ? AND cp.user_id = ?`,
      [req.params.conversationId, userId]
    );
    return res.json(detailResponse({ read: true }));
  })
);

/* -------------------------------------------------------------------------- */
/* Bookings, offers, reviews                                                   */
/* -------------------------------------------------------------------------- */

router.get(
  "/bookings",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { accountId, organizationId } = scope(req);
    const result = await engagement.listBookings({ accountId, organizationId, ...params });
    return res.json({
      ...listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }),
      counts: result.counts,
      summary: result.summary,
      view: result.view,
    });
  })
);

router.patch(
  "/bookings/:id",
  writeLimiter,
  validate({
    body: z.object({
      status: z.enum(["requested", "confirmed", "rescheduled", "completed", "cancelled", "no_show"]).optional(),
      scheduledStart: z.string().max(40).optional(),
      scheduledEnd: z.string().max(40).optional(),
      notes: z.string().trim().max(2000).optional(),
      cancellationReason: z.string().trim().max(500).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { accountId, organizationId } = scope(req);
    const booking = await queryOne(
      `SELECT id, public_id, status FROM bookings
        WHERE public_id = ? AND (account_id = ? OR organization_id <=> ?) AND deleted_at IS NULL`,
      [req.params.id, accountId, organizationId]
    );
    if (!booking) throw AppError.notFound("That booking was not found.");

    await withTransaction(async (connection) => {
      const assignments = [];
      const params = [];
      if (req.body.status) {
        assignments.push("status = ?");
        params.push(req.body.status);
        if (req.body.status === "confirmed") assignments.push("confirmed_at = NOW(3)");
        if (req.body.status === "completed") assignments.push("completed_at = NOW(3)");
        if (req.body.status === "cancelled") assignments.push("cancelled_at = NOW(3)");
      }
      if (req.body.scheduledStart) {
        assignments.push("scheduled_start = ?");
        params.push(new Date(req.body.scheduledStart));
      }
      if (req.body.scheduledEnd) {
        assignments.push("scheduled_end = ?");
        params.push(new Date(req.body.scheduledEnd));
      }
      if (req.body.notes !== undefined) {
        assignments.push("internal_notes = ?");
        params.push(req.body.notes);
      }
      if (req.body.cancellationReason) {
        assignments.push("cancellation_reason = ?");
        params.push(req.body.cancellationReason);
      }
      if (!assignments.length) return;
      await execute(`UPDATE bookings SET ${assignments.join(", ")} WHERE id = ?`, [...params, booking.id], connection);
      if (req.body.status && req.body.status !== booking.status) {
        await execute(
          `INSERT INTO booking_status_history (booking_id, from_status, to_status, changed_by_user_id, reason, changed_at)
           VALUES (?, ?, ?, ?, ?, NOW(3))`,
          [booking.id, booking.status, req.body.status, req.auth.user.id, req.body.cancellationReason || null],
          connection
        );
      }
    });

    await auditFromRequest(req, { action: "booking.updated", subjectType: "booking", subjectId: booking.id, changes: req.body });
    return res.json(detailResponse({ id: booking.public_id, updated: true }));
  })
);

router.get(
  "/offers",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { accountId, organizationId } = scope(req);
    const result = await engagement.listOffers({ accountId, organizationId, ...params });
    return res.json({
      ...listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }),
      counts: result.counts,
      summary: result.summary,
      view: result.view,
      listings: [],
    });
  })
);

router.patch(
  "/offers/:id",
  writeLimiter,
  validate({
    body: z.object({
      status: z.enum(["accepted", "declined", "countered", "withdrawn", "expired"]),
      responseNote: z.string().trim().max(1000).optional(),
      counterAmount: z.coerce.number().min(0).max(1e15).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const { accountId, organizationId } = scope(req);
    const offer = await queryOne(
      `SELECT id, public_id, status, listing_id, currency_code, amount FROM offers
        WHERE public_id = ? AND (account_id = ? OR organization_id <=> ?) AND deleted_at IS NULL`,
      [req.params.id, accountId, organizationId]
    );
    if (!offer) throw AppError.notFound("That offer was not found.");
    if (["accepted", "declined", "withdrawn"].includes(offer.status)) {
      throw AppError.conflict("That offer has already been resolved.");
    }

    await withTransaction(async (connection) => {
      await execute(
        `UPDATE offers SET status = ?, responded_at = NOW(3), responded_by_user_id = ?, response_note = ?
          WHERE id = ?`,
        [req.body.status, req.auth.user.id, req.body.responseNote || null, offer.id],
        connection
      );
      await execute(
        `INSERT INTO offer_events (offer_id, event_type, from_status, to_status, actor_user_id, amount, note, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW(3))`,
        [
          offer.id,
          req.body.status,
          offer.status,
          req.body.status,
          req.auth.user.id,
          req.body.counterAmount ?? null,
          req.body.responseNote || null,
        ],
        connection
      );
    });

    await auditFromRequest(req, { action: "offer.responded", subjectType: "offer", subjectId: offer.id, changes: req.body });
    return res.json(detailResponse({ id: offer.public_id, status: req.body.status }));
  })
);

router.get(
  "/reviews",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const { organizationId, agentId } = scope(req);
    const result = await engagement.listReviews({ organizationId, agentId, ...params });
    return res.json({
      ...listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }),
      counts: result.counts,
      summary: result.summary,
    });
  })
);

router.post(
  "/reviews/:id/response",
  writeLimiter,
  validate({ body: z.object({ body: z.string().trim().min(1, "Write a response.").max(4000) }) }),
  asyncHandler(async (req, res) => {
    const { organizationId } = scope(req);
    const review = await queryOne(
      "SELECT id, public_id FROM reviews WHERE public_id = ? AND organization_id <=> ? AND deleted_at IS NULL",
      [req.params.id, organizationId]
    );
    if (!review) throw AppError.notFound("That review was not found.");
    await execute(
      `INSERT INTO review_responses (review_id, responder_user_id, body, status, created_at)
       VALUES (?, ?, ?, 'published', NOW(3))
       ON DUPLICATE KEY UPDATE body = VALUES(body), updated_at = NOW(3)`,
      [review.id, req.auth.user.id, req.body.body]
    );
    await auditFromRequest(req, { action: "review.responded", subjectType: "review", subjectId: review.id });
    return res.status(201).json(detailResponse({ id: review.public_id, responded: true }));
  })
);

/* -------------------------------------------------------------------------- */
/* Favourites and saved searches                                               */
/* -------------------------------------------------------------------------- */

router.get(
  "/favourites",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const result = await engagement.listFavourites({ userId: req.auth.user.id, ...params });
    return res.json({
      ...listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }),
      countsByCategory: result.countsByCategory,
      locations: result.locations,
    });
  })
);

router.get(
  "/saved-searches",
  asyncHandler(async (req, res) => res.json({ data: await engagement.listSavedSearches({ userId: req.auth.user.id }) }))
);

/* -------------------------------------------------------------------------- */
/* Profile and organization                                                    */
/* -------------------------------------------------------------------------- */

router.get(
  "/profile",
  asyncHandler(async (req, res) => res.json(detailResponse(await profileService.getProfile(req))))
);

router.patch(
  "/profile",
  writeLimiter,
  validate({ body: profileService.profileUpdateSchema }),
  asyncHandler(async (req, res) => {
    const profile = await profileService.updateProfile(req, req.body);
    await auditFromRequest(req, { action: "profile.updated", subjectType: "user", subjectId: req.auth.user.id, changes: req.body });
    return res.json(detailResponse(profile));
  })
);

router.get(
  "/organization",
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    return res.json(detailResponse(await organizationService.getOrganization(organizationId)));
  })
);

router.patch(
  "/organization",
  writeLimiter,
  requireAccountCapability("can_manage_organization"),
  validate({ body: organizationService.organizationUpdateSchema }),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    const organization = await organizationService.updateOrganization({ organizationId, payload: req.body, req });
    await auditFromRequest(req, {
      action: "organization.updated",
      subjectType: "organization",
      subjectId: organizationId,
      changes: req.body,
    });
    return res.json(detailResponse(organization));
  })
);

router.get(
  "/organization/agents",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    const params = q(req);
    const result = await organizationService.listAgents({ organizationId, ...params });
    return res.json(listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }));
  })
);

router.post(
  "/organization/agents",
  writeLimiter,
  requireAccountCapability("can_manage_members"),
  validate({ body: organizationService.agentCreateSchema }),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    const agent = await organizationService.createAgent({ organizationId, payload: req.body, req });
    await auditFromRequest(req, { action: "agent.created", subjectType: "agent", subjectId: agent.agentId, subjectLabel: agent.fullName });
    return res.status(201).json(detailResponse(agent));
  })
);

router.patch(
  "/organization/agents/:id",
  writeLimiter,
  requireAccountCapability("can_manage_members"),
  validate({ body: organizationService.agentUpdateSchema }),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    const agent = await organizationService.updateAgent({ organizationId, agentPublicId: req.params.id, payload: req.body, req });
    await auditFromRequest(req, { action: "agent.updated", subjectType: "agent", subjectId: agent.agentId, changes: req.body });
    return res.json(detailResponse(agent));
  })
);

/* -------------------------------------------------------------------------- */
/* Category access                                                             */
/* -------------------------------------------------------------------------- */

router.get(
  "/categories",
  asyncHandler(async (req, res) => {
    const organizationId = req.auth.activeMembership?.organization_id ?? null;
    return res.json({ data: await organizationService.categoryAccess(organizationId) });
  })
);

router.post(
  "/category-requests",
  writeLimiter,
  validate({ body: z.object({ categoryId: z.string().trim().min(1).max(40), note: z.string().trim().max(1000).optional() }) }),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    const request = await organizationService.requestCategoryAccess({
      organizationId,
      categoryId: req.body.categoryId,
      note: req.body.note,
      userId: req.auth.user.id,
    });
    await auditFromRequest(req, {
      action: "category_access.requested",
      subjectType: "organization",
      subjectId: organizationId,
      metadata: { categoryId: req.body.categoryId },
    });
    return res.status(201).json(detailResponse(request));
  })
);

router.get(
  "/category-requests",
  asyncHandler(async (req, res) => {
    const organizationId = req.auth.activeMembership?.organization_id ?? null;
    const rows = await organizationService.categoryAccess(organizationId);
    return res.json({ data: rows.filter((row) => row.status !== "active") });
  })
);

/* -------------------------------------------------------------------------- */
/* Access requests, integrations                                               */
/* -------------------------------------------------------------------------- */

router.get(
  "/access-requests",
  asyncHandler(async (req, res) => {
    const organizationId = req.auth.activeMembership?.organization_id ?? null;
    if (!organizationId) return res.json({ data: [] });
    const rows = await query(
      `SELECT ar.public_id, ar.requested_role, ar.status, ar.message, ar.created_at,
              ar.reviewed_at, ar.response_note, u.display_name, u.email, u.avatar_url
         FROM access_requests ar JOIN users u ON u.id = ar.user_id
        WHERE ar.organization_id = ?
        ORDER BY ar.created_at DESC LIMIT 100`,
      [organizationId]
    );
    return res.json({
      data: rows.map((row) => ({
        id: row.public_id,
        requestedRole: row.requested_role,
        status: row.status,
        message: row.message,
        responseNote: row.response_note,
        requestedAt: row.created_at,
        reviewedAt: row.reviewed_at,
        user: { name: row.display_name, email: row.email, avatar: row.avatar_url },
      })),
    });
  })
);

router.patch(
  "/access-requests/:id",
  writeLimiter,
  requireAccountCapability("can_manage_members"),
  validate({ body: z.object({ status: z.enum(["approved", "rejected", "cancelled"]), note: z.string().trim().max(500).optional() }) }),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    const result = await organizationService.reviewAccessRequest({
      organizationId,
      publicId: req.params.id,
      status: req.body.status,
      note: req.body.note,
      reviewerId: req.auth.user.id,
    });
    await auditFromRequest(req, {
      action: "access_request.reviewed",
      subjectType: "access_request",
      subjectId: result.id,
      changes: req.body,
    });
    return res.json(detailResponse(result));
  })
);

router.get(
  "/integrations",
  requireAccountCapability("can_view_integrations"),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    const rows = await query(
      `SELECT ac.public_id, ac.name, ac.status, ac.scopes, ac.last_used_at, ac.created_at,
              ac.rate_limit_per_minute
         FROM api_clients ac WHERE ac.organization_id = ? ORDER BY ac.created_at DESC`,
      [organizationId]
    );
    return res.json({
      data: rows.map((row) => ({
        id: row.public_id,
        name: row.name,
        status: row.status,
        scopes: typeof row.scopes === "string" ? JSON.parse(row.scopes || "[]") : row.scopes || [],
        rateLimitPerMinute: row.rate_limit_per_minute,
        lastUsedAt: row.last_used_at,
        createdAt: row.created_at,
        // The secret is shown once at creation and never again.
        secret: null,
      })),
    });
  })
);

router.post(
  "/integrations/credentials",
  writeLimiter,
  requireAccountCapability("can_view_integrations"),
  validate({ body: z.object({ name: z.string().trim().min(1).max(120), scopes: z.array(z.string().max(60)).max(30).optional() }) }),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    const created = await organizationService.createApiClient({
      organizationId,
      name: req.body.name,
      scopes: req.body.scopes || ["listings:read"],
      userId: req.auth.user.id,
    });
    await auditFromRequest(req, { action: "api_client.created", subjectType: "api_client", subjectId: created.id });
    return res.status(201).json(detailResponse(created));
  })
);

router.delete(
  "/integrations/credentials/:id",
  writeLimiter,
  requireAccountCapability("can_view_integrations"),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    await organizationService.revokeApiClient({ organizationId, publicId: req.params.id });
    await auditFromRequest(req, { action: "api_client.revoked", subjectType: "api_client", metadata: { id: req.params.id } });
    return res.json(detailResponse({ revoked: true }));
  })
);

/* -------------------------------------------------------------------------- */
/* Finance                                                                     */
/* -------------------------------------------------------------------------- */

router.get(
  "/payments",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const params = q(req);
    const result = await engagement.listPayments({ accountId: requireAccountId(req), ...params });
    return res.json({
      ...listResponse(result.data, { page: result.page, pageSize: result.pageSize, total: result.total }),
      exportRows: result.exportRows,
      summary: result.summary,
    });
  })
);

router.get(
  "/billing",
  requireAccountCapability("can_manage_billing"),
  asyncHandler(async (req, res) => {
    const params = q(req) || {};
    return res.json(detailResponse(await engagement.accountBilling({ accountId: requireAccountId(req), ...params })));
  })
);

router.get(
  "/payouts",
  requireAccountCapability("can_manage_billing"),
  asyncHandler(async (req, res) => {
    const params = q(req) || {};
    return res.json(detailResponse(await engagement.accountPayouts({ accountId: requireAccountId(req), ...params })));
  })
);

/* -------------------------------------------------------------------------- */
/* Account settings                                                            */
/* -------------------------------------------------------------------------- */

router.get(
  "/settings/account",
  asyncHandler(async (req, res) => res.json(detailResponse(await settingsService.getAccountSettings(req.auth.user.id))))
);

router.patch(
  "/settings/account",
  writeLimiter,
  validate({ body: settingsService.accountSettingsSchema }),
  asyncHandler(async (req, res) => {
    const settings = await settingsService.updateAccountSettings(req.auth.user.id, req.body);
    await auditFromRequest(req, {
      action: "settings.account_updated",
      subjectType: "user",
      subjectId: req.auth.user.id,
      changes: req.body,
    });
    return res.json(detailResponse(settings));
  })
);

router.get(
  "/settings/notifications",
  asyncHandler(async (req, res) =>
    res.json(detailResponse(await settingsService.getNotificationSettings(req.auth.user.id)))
  )
);

router.patch(
  "/settings/notifications",
  writeLimiter,
  validate({ body: settingsService.notificationSettingsSchema }),
  asyncHandler(async (req, res) => {
    const settings = await settingsService.updateNotificationSettings(req.auth.user.id, req.body);
    await auditFromRequest(req, {
      action: "settings.notifications_updated",
      subjectType: "user",
      subjectId: req.auth.user.id,
    });
    return res.json(detailResponse(settings));
  })
);

router.get(
  "/settings/privacy",
  asyncHandler(async (req, res) => res.json(detailResponse(await settingsService.getPrivacySettings(req.auth.user.id))))
);

router.patch(
  "/settings/privacy",
  writeLimiter,
  validate({ body: settingsService.consentSchema }),
  asyncHandler(async (req, res) => {
    const settings = await settingsService.updateConsents({
      userId: req.auth.user.id,
      payload: req.body,
      ip: req.ip,
    });
    await auditFromRequest(req, {
      action: "consent.updated",
      subjectType: "user",
      subjectId: req.auth.user.id,
      changes: req.body.consents,
    });
    return res.json(detailResponse(settings));
  })
);

router.post(
  "/settings/privacy/requests",
  writeLimiter,
  validate({ body: settingsService.dataRequestSchema }),
  asyncHandler(async (req, res) => {
    const request = await settingsService.createDataRequest({ userId: req.auth.user.id, payload: req.body });
    await auditFromRequest(req, {
      action: "data_subject_request.created",
      subjectType: "user",
      subjectId: req.auth.user.id,
      metadata: { requestType: req.body.requestType },
    });
    return res.status(201).json(detailResponse(request));
  })
);

/** Sign out of every other device. */
router.post(
  "/settings/account/sign-out-everywhere",
  writeLimiter,
  asyncHandler(async (req, res) => {
    const { revokeAllSessions } = await import("../auth/sessions.js");
    await revokeAllSessions(req.auth.user.id);
    await auditFromRequest(req, { action: "auth.logout_all", subjectType: "user", subjectId: req.auth.user.id });
    return res.json(detailResponse({ signedOut: true }));
  })
);

/* -------------------------------------------------------------------------- */
/* Developments                                                                */
/* -------------------------------------------------------------------------- */

/**
 * A developer's own developments.
 *
 * A development is a `projects` row owned by the caller's organization. The portal may
 * create one, edit it and submit it for review — never publish it: publication,
 * rejection and the reason stay with LivFinder moderators (admin
 * `PATCH /developments/:id`), exactly as with listings. Everything is scoped to the
 * caller's organization, and another organization's development answers 404, never 403,
 * so its existence is not confirmed. Before this there was no portal endpoint at all and
 * the portal's Developments form could only preview.
 */
// No `developerId`: the brand comes from the organization (defaultDeveloperBrand), not the client.
const PORTAL_DEVELOPMENT_KEYS = [
  "name", "tagline", "description", "highlights", "projectType", "ownershipType",
  "status", "launchStatus", "launchDate", "constructionStartDate", "handoverDate", "completionPercentage",
  "totalUnits", "availableUnits", "buildingCount", "minPrice", "maxPrice", "currencyCode",
  "countryId", "stateId", "cityId", "communityId", "subCommunityId", "address", "latitude", "longitude",
  "coverImageUrl", "brochureUrl", "videoUrl", "amenities", "unitTypes", "paymentPlans", "paymentPlan",
  "gallery", "masterplan", "video", "brochure", "floorPlans", "documents",
];
// Moderation, visibility, featuring and SEO are LivFinder's, so they are not in the pick.
const portalDevelopmentSchema = developmentSchema
  .pick(Object.fromEntries(PORTAL_DEVELOPMENT_KEYS.map((key) => [key, true])))
  .extend({ submit: z.boolean().optional() });

const PORTAL_DEVELOPMENT_SELECT = `
  SELECT p.id, p.public_id, p.name, p.slug, p.tagline, p.description, p.project_type,
         p.status AS lifecycle_status, p.moderation_status, p.rejection_reason, p.is_publicly_visible,
         p.published_at, p.canonical_path, p.cover_image_url, p.min_price, p.max_price, p.currency_code,
         p.total_units, p.available_units, p.handover_date, p.created_at, p.updated_at,
         b.name AS developer_name,
         co.name AS country_name, ct.name AS city_name, cm.name AS community_name,
         (SELECT COUNT(*) FROM inquiries i WHERE i.project_id = p.id AND i.deleted_at IS NULL) AS inquiry_count
    FROM projects p
    LEFT JOIN brands b ON b.id = p.developer_brand_id
    LEFT JOIN locations co ON co.id = p.country_id
    LEFT JOIN locations ct ON ct.id = p.city_id
    LEFT JOIN locations cm ON cm.id = p.community_id`;

// The portal's listing vocabulary, so the shared list and detail screens read developments:
// `rawStatus` is what the status badge keys on, `status` is the tab the record sits under.
const RAW_STATUS_BY_MODERATION = {
  draft: "draft", pending: "pending_review", published: "active", rejected: "rejected", archived: "archived",
};
const TAB_BY_MODERATION = { draft: "draft", pending: "pending", published: "active", rejected: "rejected", archived: "archived" };
const LABEL_BY_MODERATION = { draft: "Draft", pending: "Pending", published: "Active", rejected: "Rejected", archived: "Archived" };
// A development is never sold/rented or expired, so those two tabs are simply empty.
const MODERATION_BY_TAB = { active: "published", pending: "pending", draft: "draft", rejected: "rejected", archived: "archived" };
const DEVELOPMENT_SORTS = {
  newest: "p.created_at DESC",
  oldest: "p.created_at ASC",
  priceDesc: "p.min_price DESC",
  priceAsc: "p.min_price ASC",
  inquiries: "inquiry_count DESC",
  updated: "p.updated_at DESC",
  views: "p.created_at DESC",
};
const iso = (value) => (value ? new Date(value).toISOString() : null);
const amount = (value) => (value === null || value === undefined ? null : Number(value));

function serializePortalDevelopment(row) {
  const published = row.moderation_status === "published" && Number(row.is_publicly_visible) === 1;
  const moderation = row.moderation_status;
  const cover = row.cover_image_url ? { url: row.cover_image_url, alt: row.name } : null;
  return {
    id: row.public_id,
    reference: row.slug,
    title: row.name,
    name: row.name,
    tagline: row.tagline,
    subtitle: row.tagline,
    description: row.description || "",
    category: "realEstateDevelopment",
    listingType: "real-estate-developments",
    purpose: "sale",
    projectType: row.project_type,
    developmentStatus: row.lifecycle_status,
    developerName: row.developer_name || null,
    // The list's "Owner / agent" column: a development is marketed under its developer.
    agentName: row.developer_name || null,
    rawStatus: RAW_STATUS_BY_MODERATION[moderation] || moderation,
    status: TAB_BY_MODERATION[moderation] || moderation,
    statusLabel: LABEL_BY_MODERATION[moderation] || moderation,
    moderationStatus: moderation,
    // Only while rejected: a reason belongs to one rejection (same rule as listings).
    rejectionReason: moderation === "rejected" ? row.rejection_reason || null : null,
    // `formatted` is what the shared detail screen prints as "Price"; without it a development
    // read "Price: Not provided" beside its own minimum price.
    price: row.min_price !== null
      ? {
          amount: amount(row.min_price),
          currency: row.currency_code || "AED",
          formatted: portalRepo.formatMoney({ amount: amount(row.min_price), currency: row.currency_code || "AED" }),
        }
      : null,
    priceMin: amount(row.min_price),
    priceMax: amount(row.max_price),
    priceRange: { min: amount(row.min_price), max: amount(row.max_price), currency: row.currency_code || null },
    totalUnits: amount(row.total_units),
    availableUnits: amount(row.available_units),
    handoverDate: row.handover_date ? iso(row.handover_date).slice(0, 10) : null,
    locationLabel: [row.community_name, row.city_name, row.country_name].filter(Boolean).join(", ") || null,
    image: cover ? { src: cover.url, alt: cover.alt } : null,
    coverImage: cover,
    gallery: cover ? [{ id: "cover", url: cover.url, alt: cover.alt, isCover: true }] : [],
    features: [],
    specs: [],
    metrics: { views: null, inquiries: Number(row.inquiry_count || 0) },
    inquiryCount: Number(row.inquiry_count || 0),
    viewCount: null,
    favouriteCount: null,
    publicUrl: published ? row.canonical_path : null,
    canonicalUrl: published ? row.canonical_path : null,
    createdAt: iso(row.created_at),
    updatedAt: iso(row.updated_at),
    publishedAt: iso(row.published_at),
    expiresAt: null,
  };
}

async function ownDevelopment(req, identifier) {
  const organizationId = requireOrganizationId(req);
  const row = await queryOne(
    `${PORTAL_DEVELOPMENT_SELECT}
      WHERE (p.public_id = ? OR p.slug = ?) AND p.organization_id = ? AND p.deleted_at IS NULL
      LIMIT 1`,
    [String(identifier), String(identifier), organizationId]
  );
  if (!row) throw AppError.notFound("That development was not found.");
  return row;
}

/**
 * The whole record, for the detail and edit screens: units, payment plans, amenities, gallery
 * and the location ids the form's picker needs — read through the admin reader so there is one
 * definition of a development, then shaped into the portal's listing-detail vocabulary.
 */
async function portalDevelopmentDetail(row) {
  const base = serializePortalDevelopment(row);
  const full = await getAdminDevelopment(row.public_id);
  if (!full) return base;
  const location = full.location || {};
  const gallery = full.media?.gallery || [];
  const hasPrimary = gallery.some((item) => item.primary);
  const tier = (key) => location[key] || "";
  return {
    ...base,
    description: full.description?.body || base.description,
    developerId: full.developer?.id || null,
    developerName: full.developer?.name || base.developerName,
    launchDate: full.launch?.launchDate || null,
    completionPercentage: full.construction?.completionPercentage ?? null,
    currency: row.currency_code || "AED",
    locationIds: {
      country: tier("countryId"),
      state: tier("stateId"),
      city: tier("cityId"),
      community: tier("communityId"),
      subCommunity: tier("subCommunityId"),
    },
    locationNames: {
      country: tier("country"),
      state: tier("state"),
      city: tier("city"),
      community: tier("community"),
      subCommunity: tier("subCommunity"),
    },
    address: location.address || "",
    latitude: location.latitude ?? null,
    longitude: location.longitude ?? null,
    amenities: full.amenities || [],
    features: (full.amenities || []).map((label) => ({ name: label, slug: label })),
    // Real gallery attachments when there are any; a seeded project may have only a cover URL.
    gallery: gallery.length
      ? gallery.map((item, index) => ({
          id: item.id,
          url: item.url,
          alt: item.label || row.name,
          isCover: hasPrimary ? Boolean(item.primary) : index === 0,
        }))
      : base.gallery,
    unitTypes: full.unitTypes || [],
    paymentPlans: full.paymentPlans || [],
    // Floor plans, brochure, documents, video and tours — listed on the Media tab and in the form.
    documents: await developmentAttachments(row.id),
  };
}

/**
 * Media a developer may attach: files this account uploaded, or files already on this very
 * development (a seeded or admin-added image survives an edit). Anything else — another
 * account's upload, addressed by a guessed or leaked id — is refused.
 */
const DEVELOPMENT_MEDIA_ROLES = ["gallery", "masterplan", "video", "brochure", "floorPlans", "documents"];
async function assertOwnDevelopmentMedia(req, payload, projectId = null) {
  const ids = [
    ...new Set(
      DEVELOPMENT_MEDIA_ROLES.flatMap((role) => (payload[role] || []).map((entry) => entry?.mediaAssetId).filter(Boolean))
    ),
  ];
  if (!ids.length) return;
  const accountId = requireAccountId(req);
  const rows = await query(
    `SELECT a.public_id FROM media_assets a
      WHERE a.public_id IN (${ids.map(() => "?").join(", ")}) AND a.deleted_at IS NULL
        AND (a.account_id = ?
             OR EXISTS (SELECT 1 FROM media_attachments ma
                         WHERE ma.media_asset_id = a.id AND ma.attachable_type = 'project' AND ma.attachable_id = ?))`,
    [...ids, accountId, projectId ?? 0]
  );
  const allowed = new Set(rows.map((row) => row.public_id));
  if (ids.some((id) => !allowed.has(id))) {
    throw AppError.validation("Some information is invalid.", {
      mediaAssetId: "Only files uploaded by this account can be attached to its development.",
    });
  }
}

/**
 * The developer brand a new development is filed under: the one this organization already
 * markets its projects under. A client does not pick a brand — naming another developer's brand
 * would misattribute the project — and LivFinder can change it during review.
 */
async function defaultDeveloperBrand(organizationId) {
  const row = await queryOne(
    `SELECT b.public_id
       FROM projects p
       JOIN brands b ON b.id = p.developer_brand_id AND b.deleted_at IS NULL
      WHERE p.organization_id = ? AND p.deleted_at IS NULL
      GROUP BY b.id, b.public_id
      ORDER BY COUNT(*) DESC, b.id ASC
      LIMIT 1`,
    [organizationId]
  );
  return row?.public_id || null;
}

router.get(
  "/developments",
  validate({ query: listQuery }),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    const { status = "all", search, sort, page, pageSize } = q(req);
    const conditions = ["p.organization_id = ?", "p.deleted_at IS NULL"];
    const params = [organizationId];
    if (status && status !== "all") {
      // The portal's tab names, or a moderation status named directly.
      const moderation =
        MODERATION_BY_TAB[status] ?? (Object.values(MODERATION_BY_TAB).includes(status) ? status : null);
      if (moderation) {
        conditions.push("p.moderation_status = ?");
        params.push(moderation);
      } else {
        conditions.push("1 = 0");
      }
    }
    const term = String(search || "").trim();
    if (term) {
      conditions.push("(p.name LIKE ? OR p.slug LIKE ?)");
      params.push(`%${term}%`, `%${term}%`);
    }
    const where = conditions.join(" AND ");
    const size = Math.min(Math.max(Number(pageSize) || 12, 1), 100);
    const current = Math.max(Number(page) || 1, 1);

    const [rows, totalRow, countRows] = await Promise.all([
      query(
        `${PORTAL_DEVELOPMENT_SELECT}
          WHERE ${where}
          ORDER BY ${DEVELOPMENT_SORTS[sort] || DEVELOPMENT_SORTS.newest}, p.id DESC
          LIMIT ${size} OFFSET ${(current - 1) * size}`,
        params
      ),
      queryOne(`SELECT COUNT(*) AS total FROM projects p WHERE ${where}`, params),
      query(
        "SELECT moderation_status, COUNT(*) AS n FROM projects WHERE organization_id = ? AND deleted_at IS NULL GROUP BY moderation_status",
        [organizationId]
      ),
    ]);
    const byModeration = Object.fromEntries(countRows.map((row) => [row.moderation_status, Number(row.n)]));
    const counts = {
      all: Object.values(byModeration).reduce((sum, value) => sum + value, 0),
      ...Object.fromEntries(Object.entries(MODERATION_BY_TAB).map(([tab, moderation]) => [tab, byModeration[moderation] || 0])),
      soldOrRented: 0,
      expired: 0,
    };
    return res.json({
      ...listResponse(rows.map(serializePortalDevelopment), {
        page: current,
        pageSize: size,
        total: Number(totalRow?.total || 0),
      }),
      counts,
    });
  })
);

router.get(
  "/developments/:id",
  asyncHandler(async (req, res) => res.json(detailResponse(await portalDevelopmentDetail(await ownDevelopment(req, req.params.id)))))
);

router.post(
  "/developments",
  writeLimiter,
  requireAccountCapability("can_manage_listings"),
  validate({ body: portalDevelopmentSchema }),
  asyncHandler(async (req, res) => {
    const organizationId = requireOrganizationId(req);
    // Only a developer approved for the category may submit one (0051 backfilled the grants).
    await organizationService.assertCategoryAccess({ organizationId, category: "real-estate-developments" });
    const { submit, ...payload } = req.body;
    await assertOwnDevelopmentMedia(req, payload);
    const developerId = await defaultDeveloperBrand(organizationId);

    const created = await upsertDevelopment({
      identifier: null,
      payload: { ...payload, ...(developerId ? { developerId } : {}), acceptsInquiries: true },
      userId: req.auth.user.id,
    });
    await execute(
      `UPDATE projects
          SET organization_id = ?, moderation_status = ?, is_publicly_visible = 0, rejection_reason = NULL, updated_at = NOW(3)
        WHERE public_id = ?`,
      [organizationId, submit ? "pending" : "draft", created.id]
    );
    const row = await ownDevelopment(req, created.id);
    await callProcedure("sp_refresh_project_search", [row.id]);

    await auditFromRequest(req, {
      action: submit ? "development.submitted" : "development.created",
      subjectType: "project",
      subjectId: row.id,
      subjectLabel: row.name,
      metadata: { moderationStatus: row.moderation_status },
    });
    return res.status(201).json(detailResponse(serializePortalDevelopment(row)));
  })
);

router.patch(
  "/developments/:id",
  writeLimiter,
  requireAccountCapability("can_manage_listings"),
  validate({ body: portalDevelopmentSchema.partial() }),
  asyncHandler(async (req, res) => {
    const current = await ownDevelopment(req, req.params.id);
    if (current.moderation_status === "archived") {
      throw AppError.conflict("An archived development cannot be edited.");
    }
    const { submit, ...payload } = req.body;
    await assertOwnDevelopmentMedia(req, payload, current.id);
    const edited = Object.keys(payload).length > 0;
    if (edited) {
      await upsertDevelopment({ identifier: current.public_id, payload, userId: req.auth.user.id });
    }
    // Approval covers the version a moderator reviewed: a published development the developer
    // changes in any way — a unit, a milestone, a photo — goes back into the queue and off the
    // public site, exactly like an explicit resubmission. It used to be saved live in place.
    const wasLive = current.moderation_status === "published";
    if (submit || (wasLive && edited)) {
      // Resubmission: back into the queue, off the public site, the old reason cleared.
      await execute(
        "UPDATE projects SET moderation_status = 'pending', rejection_reason = NULL, is_publicly_visible = 0, updated_at = NOW(3) WHERE id = ?",
        [current.id]
      );
      await callProcedure("sp_refresh_project_search", [current.id]);
    }
    const row = await ownDevelopment(req, current.public_id);
    await auditFromRequest(req, {
      action: submit ? "development.resubmitted" : "development.updated",
      subjectType: "project",
      subjectId: row.id,
      subjectLabel: row.name,
      metadata: { moderationStatus: row.moderation_status },
    });
    return res.json(detailResponse(serializePortalDevelopment(row)));
  })
);

export default router;
