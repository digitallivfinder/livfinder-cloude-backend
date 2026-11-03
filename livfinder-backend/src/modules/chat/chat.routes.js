import { Router } from "express";
import multer from "multer";
import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import { z } from "zod";
import env from "../../config/env.js";
import { asyncHandler } from "../../middleware/errors.js";
import { validate, q } from "../../middleware/validation.js";
import { uploadLimiter } from "../../middleware/rateLimit.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse } from "../../utils/http.js";
import {
  GUEST_COOKIE,
  canReplySupport,
  guestCookieOptions,
  guestFromToken,
  identityFromAuth,
  identityFromRequest,
  refFor,
  requireIdentity,
  resumeGuest,
} from "./identity.js";
import * as chat from "./chat.service.js";
import { MAX_ATTACHMENT_BYTES, findAttachment, readAttachmentBytes, storeAttachment } from "./attachments.js";

/**
 * /v1/chat — live chat for visitors (signed in or guests), clients and LivFinder staff.
 *
 * Mounted after the CSRF middleware, so every write needs the double-submit token, guests
 * included. Reads and writes both resolve the caller through identity.js, and the service checks
 * the caller belongs to the conversation; a conversation that is not theirs is a 404.
 */
const router = Router();

const limiterBase = {
  standardHeaders: "draft-7",
  legacyHeaders: false,
  handler: (req, res, next) => next(AppError.tooManyRequests("You are sending messages too quickly. Wait a moment and try again.")),
  skip: () => env.isTest,
};

/** Per person, not per IP: a busy office behind one address is many people. */
const personKey = (req) =>
  req.auth?.user ? `u:${req.auth.user.id}` : req.cookies?.[GUEST_COOKIE] ? `g:${String(req.cookies[GUEST_COOKIE]).slice(0, 16)}` : `ip:${ipKeyGenerator(req.ip)}`;

const sendLimiter = rateLimit({ ...limiterBase, windowMs: 60_000, limit: 40, keyGenerator: personKey });
// New threads, and above all new guests, are what a spammer needs most of.
const startLimiter = rateLimit({ ...limiterBase, windowMs: 10 * 60_000, limit: 12, keyGenerator: (req) => `ip:${ipKeyGenerator(req.ip)}` });

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: MAX_ATTACHMENT_BYTES, files: 1 } });

const idParam = z.object({ id: z.string().trim().min(1).max(40) });

const messageBody = z.object({
  message: z.string().max(5000, "Messages can be up to 5,000 characters.").optional().default(""),
  attachmentIds: z.array(z.string().max(40)).max(10).optional().default([]),
  clientRef: z.string().max(64).regex(/^[A-Za-z0-9_-]+$/).optional().nullable(),
});

const startBody = messageBody.extend({
  kind: z.enum(["enquiry", "support"]),
  listingId: z.string().max(220).optional(),
  projectId: z.string().max(220).optional(),
  agentId: z.string().max(220).optional(),
  organizationId: z.string().max(220).optional(),
  topic: z.string().trim().max(200).optional(),
  sourceUrl: z.string().max(700).optional(),
});

/* ---------------------------------------------------------------------------------------------
 * Who am I
 * ------------------------------------------------------------------------------------------- */

router.get(
  "/me",
  asyncHandler(async (req, res) => {
    res.setHeader("Cache-Control", "private, no-store");
    let identity = identityFromAuth(req.auth);
    // A guest who has since signed in with the same address keeps their chats.
    if (identity && req.cookies?.[GUEST_COOKIE]) {
      const guest = await guestFromToken(req.cookies[GUEST_COOKIE]);
      if (guest && req.auth.user.emailVerifiedAt && guest.email === String(req.auth.user.email).toLowerCase()) {
        await chat.claimGuestThreads(guest, identity);
        res.clearCookie(GUEST_COOKIE, { ...guestCookieOptions(), maxAge: undefined });
      }
    }
    if (!identity) identity = await identityFromRequest(req);
    if (!identity) return res.json(detailResponse({ identity: null, unreadTotal: 0 }));
    return res.json(
      detailResponse({
        identity: {
          type: identity.type,
          ref: refFor(identity),
          name: identity.name,
          email: identity.email ?? null,
          isStaff: identity.type === "user" && canReplySupport(identity),
        },
        unreadTotal: await chat.unreadTotal(identity),
      })
    );
  })
);

/** Opens a chat from an emailed link on any device. */
router.post(
  "/resume",
  startLimiter,
  validate({ body: z.object({ token: z.string().min(10).max(300) }) }),
  asyncHandler(async (req, res) => {
    const guest = await resumeGuest(req.body.token, res);
    return res.json(detailResponse({ identity: { type: "guest", ref: refFor(guest), name: guest.name, email: guest.email } }));
  })
);

/** "Not you?" — forgets the guest on this device. Their chats stay reachable by email link. */
router.post(
  "/guest/forget",
  asyncHandler(async (req, res) => {
    res.clearCookie(GUEST_COOKIE, { ...guestCookieOptions(), maxAge: undefined });
    return res.json(detailResponse({ forgotten: true }));
  })
);

/* ---------------------------------------------------------------------------------------------
 * Conversations
 * ------------------------------------------------------------------------------------------- */

router.get(
  "/conversations",
  validate({
    query: z.object({
      scope: z.enum(["mine", "support"]).optional().default("mine"),
      kind: z.enum(["enquiry", "support"]).optional(),
      filter: z.enum(["all", "unread", "archived", "open", "closed", "mine", "unassigned"]).optional().default("all"),
      q: z.string().max(80).optional(),
      before: z.string().max(40).optional(),
      limit: z.coerce.number().int().min(1).max(100).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    res.setHeader("Cache-Control", "private, no-store");
    const identity = await identityFromRequest(req);
    if (!identity) return res.json(detailResponse({ conversations: [], unreadTotal: 0, nextBefore: null }));
    const params = q(req);
    return res.json(
      detailResponse(
        await chat.listConversations(identity, {
          scope: params.scope,
          kind: params.kind,
          filter: params.filter,
          search: params.q,
          before: params.before,
          limit: params.limit,
        })
      )
    );
  })
);

router.post(
  "/conversations",
  startLimiter,
  sendLimiter,
  validate({ body: startBody }),
  asyncHandler(async (req, res) => {
    // New chats need an account (owner decision, 2026-11-03): the website asks the visitor to sign
    // in first. Guests from before keep the chats they already have.
    const identity = identityFromAuth(req.auth);
    if (!identity) throw AppError.unauthorized("Sign in to start a chat.");
    // Without a message this only opens the chat (an existing one, or a new empty one that only
    // its opener sees until the first message), so the person writes in the chat itself.
    const started =
      req.body.kind === "support" ? await chat.startSupport(identity, req.body, req) : await chat.startEnquiry(identity, req.body, req);
    return res.status(started.created ? 201 : 200).json(
      detailResponse({
        ...started,
        identity: { type: identity.type, ref: refFor(identity), name: identity.name, email: identity.email ?? null },
      })
    );
  })
);

/** Companies and agents a person can start a chat with, by name. */
router.get(
  "/directory",
  validate({ query: z.object({ q: z.string().trim().min(2).max(80) }) }),
  asyncHandler(async (req, res) => {
    res.setHeader("Cache-Control", "private, no-store");
    return res.json(detailResponse({ results: await chat.searchDirectory(q(req).q) }));
  })
);

router.get(
  "/conversations/:id",
  validate({ params: idParam, query: z.object({ before: z.string().max(40).optional() }) }),
  asyncHandler(async (req, res) => {
    res.setHeader("Cache-Control", "private, no-store");
    const identity = await requireIdentity(req);
    return res.json(detailResponse(await chat.getConversation(identity, req.params.id, { before: q(req).before })));
  })
);

router.post(
  "/conversations/:id/messages",
  sendLimiter,
  validate({ params: idParam, body: messageBody }),
  asyncHandler(async (req, res) => {
    const identity = await requireIdentity(req);
    const message = await chat.sendMessage(identity, req.params.id, req.body, req);
    return res.status(201).json(detailResponse({ message }));
  })
);

router.post(
  "/conversations/:id/attachments",
  uploadLimiter,
  validate({ params: idParam }),
  upload.single("file"),
  asyncHandler(async (req, res) => {
    const identity = await requireIdentity(req);
    const { conversation } = await chat.writableConversation(identity, req.params.id);
    const attachment = await storeAttachment({ identity, conversationId: conversation.id, file: req.file });
    return res.status(201).json(detailResponse({ attachment }));
  })
);

router.post(
  "/conversations/:id/read",
  validate({ params: idParam }),
  asyncHandler(async (req, res) => {
    const identity = await requireIdentity(req);
    return res.json(detailResponse(await chat.markRead(identity, req.params.id)));
  })
);

router.patch(
  "/conversations/:id",
  validate({
    params: idParam,
    body: z.object({ archived: z.boolean().optional(), muted: z.boolean().optional(), blocked: z.boolean().optional() }),
  }),
  asyncHandler(async (req, res) => {
    const identity = await requireIdentity(req);
    const result = {};
    if (req.body.archived !== undefined) Object.assign(result, await chat.setArchived(identity, req.params.id, req.body.archived));
    if (req.body.muted !== undefined) Object.assign(result, await chat.setMuted(identity, req.params.id, req.body.muted));
    if (req.body.blocked !== undefined) Object.assign(result, await chat.setBlocked(identity, req.params.id, req.body.blocked, req));
    return res.json(detailResponse(result));
  })
);

router.post(
  "/conversations/:id/report",
  startLimiter,
  validate({
    params: idParam,
    body: z.object({
      reason: z.enum(["spam", "harassment", "offensive_content", "impersonation", "privacy", "other"]).optional().default("other"),
      details: z.string().trim().max(2000).optional().default(""),
    }),
  }),
  asyncHandler(async (req, res) => {
    const identity = await requireIdentity(req);
    return res.status(201).json(detailResponse(await chat.reportConversation(identity, req.params.id, req.body, req)));
  })
);

/* ---------------------------------------------------------------------------------------------
 * Files
 * ------------------------------------------------------------------------------------------- */

router.get(
  "/attachments/:id",
  validate({ params: idParam }),
  asyncHandler(async (req, res) => {
    const identity = await requireIdentity(req);
    const row = await findAttachment(req.params.id);
    if (!row || row.message_deleted_at) throw AppError.notFound("That file is no longer available.");
    if (!row.message_id) {
      // Not sent yet: only its uploader may look at it.
      const mine =
        identity.type === "user" ? String(row.uploaded_by_user_id) === String(identity.userId) : String(row.uploaded_by_guest_id) === String(identity.guestId);
      if (!mine) throw AppError.notFound("That file is no longer available.");
    } else {
      await chat.readableConversation(identity, row.conversation_public_id);
    }
    if (!row.storage_key) {
      if (/^https?:\/\//.test(row.file_url || "")) return res.redirect(row.file_url);
      throw AppError.notFound("That file is no longer available.");
    }
    const preview = req.query.preview === "1";
    const { body, mimeType } = await readAttachmentBytes(row, { preview });
    const inline = !req.query.download && /^(image\/(jpeg|png|webp|gif)|application\/pdf)$/.test(mimeType);
    res.setHeader("Cache-Control", "private, max-age=3600");
    res.setHeader("X-Content-Type-Options", "nosniff");
    // A file is never a page: no scripts, even if a browser decides to render it.
    res.setHeader("Content-Security-Policy", "default-src 'none'; img-src 'self' data:; style-src 'unsafe-inline'; sandbox");
    res.setHeader(
      "Content-Disposition",
      `${inline ? "inline" : "attachment"}; filename="${row.file_name.replace(/[^\w. -]/g, "_")}"; filename*=UTF-8''${encodeURIComponent(row.file_name)}`
    );
    res.type(mimeType);
    return res.send(body);
  })
);

/* ---------------------------------------------------------------------------------------------
 * Staff: the support inbox
 * ------------------------------------------------------------------------------------------- */

async function requireStaff(req) {
  const identity = identityFromAuth(req.auth);
  if (!identity) throw AppError.unauthorized();
  return identity;
}

router.get(
  "/support/counts",
  asyncHandler(async (req, res) => res.json(detailResponse(await chat.supportCounts(await requireStaff(req)))))
);

router.post(
  "/support/start",
  sendLimiter,
  validate({ body: z.object({ accountId: z.union([z.string().max(40), z.number().int()]), message: z.string().trim().min(1).max(5000), topic: z.string().trim().max(200).optional() }) }),
  asyncHandler(async (req, res) => {
    const staff = await requireStaff(req);
    return res.status(201).json(detailResponse(await chat.startSupportWithAccount(staff, req.body, req)));
  })
);

router.post(
  "/support/:id/assign",
  validate({ params: idParam, body: z.object({ toMe: z.boolean().optional().default(true), userId: z.string().max(40).optional() }) }),
  asyncHandler(async (req, res) => {
    const staff = await requireStaff(req);
    return res.json(detailResponse(await chat.assignSupport(staff, req.params.id, req.body, req)));
  })
);

router.post(
  "/support/:id/status",
  validate({ params: idParam, body: z.object({ status: z.enum(["open", "closed"]) }) }),
  asyncHandler(async (req, res) => {
    const staff = await requireStaff(req);
    return res.json(detailResponse(await chat.setSupportStatus(staff, req.params.id, req.body.status, req)));
  })
);

export default router;
