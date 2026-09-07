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
import { query, queryOne, execute } from "../../db/query.js";
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
    await auditFromRequest(req, {
      action: "listing.updated",
      subjectType: "listing",
      subjectId: listing.id,
      subjectLabel: listing.title,
      changes: req.body,
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
      status: z.enum(["new", "contacted", "qualified", "won", "lost", "closed", "spam"]).optional(),
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
          `INSERT INTO inquiry_notes (inquiry_id, user_id, body, is_internal, created_at)
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

export default router;
