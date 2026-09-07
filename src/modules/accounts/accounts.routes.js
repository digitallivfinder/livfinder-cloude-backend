import { Router } from "express";
import { z } from "zod";
import env from "../../config/env.js";
import { asyncHandler } from "../../middleware/errors.js";
import { validate } from "../../middleware/validation.js";
import { authLimiter, writeLimiter } from "../../middleware/rateLimit.js";
import { requireAuth } from "../../middleware/auth.js";
import { issueCsrfToken } from "../../middleware/csrf.js";
import { sessionCookieOptions } from "../auth/sessions.js";
import { serializeSession } from "../auth/session.serializer.js";
import { detailResponse } from "../../utils/http.js";
import { AppError } from "../../utils/errors.js";
import * as accountsService from "./accounts.service.js";
import * as verificationService from "./verification.service.js";
import { queryOne } from "../../db/query.js";

const router = Router();

const baseSignup = {
  firstName: z.string().trim().min(1, "Enter your first name.").max(120),
  lastName: z.string().trim().min(1, "Enter your last name.").max(120),
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255),
  phone: z.string().trim().max(40).optional().or(z.literal("")),
  country: z.string().trim().max(120).optional().or(z.literal("")),
  city: z.string().trim().max(120).optional().or(z.literal("")),
  password: z.string().min(1, "Choose a password.").max(200),
  confirmPassword: z.string().max(200).optional(),
  agreements: z.union([z.boolean(), z.literal("true"), z.literal("on")]).optional(),
  marketingOptIn: z.boolean().optional(),
};

const personalSignupSchema = z
  .object({
    ...baseSignup,
    displayName: z.string().trim().max(200).optional().or(z.literal("")),
    bio: z.string().trim().max(4000).optional().or(z.literal("")),
    title: z.string().trim().max(120).optional().or(z.literal("")),
    categoryId: z.string().trim().max(40).optional(),
    license: z.string().trim().max(120).optional().or(z.literal("")),
    intendsToList: z.boolean().optional(),
    verificationRequestId: z.union([z.string(), z.number()]).optional(),
    documents: z.array(z.object({ uploadId: z.string(), documentType: z.string().max(80) })).optional(),
  })
  .refine((value) => !value.confirmPassword || value.confirmPassword === value.password, {
    message: "Passwords must match.",
    path: ["confirmPassword"],
  })
  .refine((value) => value.agreements === true || value.agreements === "true" || value.agreements === "on", {
    message: "Agreement is required.",
    path: ["agreements"],
  });

const organizationSignupSchema = z
  .object({
    ...baseSignup,
    legalName: z.string().trim().min(1, "Enter the legal name.").max(255),
    publicName: z.string().trim().max(200).optional().or(z.literal("")),
    organizationType: z.string().trim().max(60).optional().or(z.literal("")),
    registrationNumber: z.string().trim().max(120).optional().or(z.literal("")),
    issuingAuthority: z.string().trim().max(160).optional().or(z.literal("")),
    website: z.string().trim().max(500).optional().or(z.literal("")),
    organizationEmail: z.string().trim().toLowerCase().max(255).optional().or(z.literal("")),
    organizationPhone: z.string().trim().max(40).optional().or(z.literal("")),
    address: z.string().trim().max(500).optional().or(z.literal("")),
    description: z.string().trim().max(4000).optional().or(z.literal("")),
    categoryId: z.string().trim().min(1, "Choose a marketplace category.").max(40),
    documents: z.array(z.object({ uploadId: z.string(), documentType: z.string().max(80) })).optional(),
  })
  .refine((value) => !value.confirmPassword || value.confirmPassword === value.password, {
    message: "Passwords must match.",
    path: ["confirmPassword"],
  })
  .refine((value) => value.agreements === true || value.agreements === "true" || value.agreements === "on", {
    message: "Agreement is required.",
    path: ["agreements"],
  });

function establishSession(req, res, session) {
  const maxAge = new Date(session.expiresAt).getTime() - Date.now();
  res.cookie(env.SESSION_COOKIE_NAME, session.token, sessionCookieOptions(maxAge));
  return issueCsrfToken({ ...req, cookies: { ...req.cookies, [env.SESSION_COOKIE_NAME]: session.token } }, res);
}

router.post(
  "/personal/signup",
  authLimiter,
  validate({ body: personalSignupSchema }),
  asyncHandler(async (req, res) => {
    const result = await accountsService.signupPersonal(req.body, {
      ip: req.ip,
      userAgent: req.get("user-agent"),
    });
    if (req.body.documents?.length) {
      await verificationService.attachUploadedDocuments({
        verificationRequestId: result.verificationId,
        userId: result.userId,
        documents: req.body.documents,
      });
    }
    const csrfToken = establishSession(req, res, result.session);
    const session = await serializeSession(result.userId);
    return res.status(201).json(
      detailResponse({
        ...session,
        csrfToken,
        state: "pending_verification",
        verificationRequestId: String(result.verificationId),
      })
    );
  })
);

router.post(
  "/organization/signup",
  authLimiter,
  validate({ body: organizationSignupSchema }),
  asyncHandler(async (req, res) => {
    const result = await accountsService.signupOrganization(req.body, {
      ip: req.ip,
      userAgent: req.get("user-agent"),
    });
    if (req.body.documents?.length) {
      await verificationService.attachUploadedDocuments({
        verificationRequestId: result.verificationId,
        userId: result.userId,
        documents: req.body.documents,
      });
    }
    const csrfToken = establishSession(req, res, result.session);
    const session = await serializeSession(result.userId);
    return res.status(201).json(
      detailResponse({
        ...session,
        csrfToken,
        state: "pending_verification",
        verificationRequestId: String(result.verificationId),
      })
    );
  })
);

/**
 * Presigned upload for a sensitive document.
 *
 * The response never contains storage credentials — only a short-lived,
 * single-object target. The object lands in the private tree and is not
 * reachable by URL.
 */
router.post(
  "/verification/uploads/presign",
  writeLimiter,
  requireAuth,
  validate({
    body: z.object({
      fileName: z.string().trim().min(1).max(255),
      mimeType: z.string().trim().min(1).max(120),
      fileSizeBytes: z.coerce.number().int().min(1).max(25 * 1024 * 1024),
      documentType: z.string().trim().min(1).max(80),
    }),
  }),
  asyncHandler(async (req, res) => {
    const target = await verificationService.presignVerificationUpload({
      userId: req.auth.user.id,
      accountId: req.auth.activeAccountId,
      ...req.body,
    });
    return res.json(detailResponse(target));
  })
);

router.post(
  "/verification/submit",
  writeLimiter,
  requireAuth,
  validate({
    body: z.object({
      subjectType: z.enum(["account", "organization", "agent"]).default("account"),
      documents: z
        .array(z.object({ uploadId: z.string().min(1).max(200), documentType: z.string().min(1).max(80) }))
        .min(1, "Attach at least one document."),
      notes: z.string().trim().max(1000).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const result = await verificationService.submitVerification({
      req,
      subjectType: req.body.subjectType,
      documents: req.body.documents,
      notes: req.body.notes,
    });
    return res.status(201).json(detailResponse(result));
  })
);

router.get(
  "/verification/status",
  requireAuth,
  asyncHandler(async (req, res) => {
    const status = await verificationService.verificationStatus(req);
    return res.json(detailResponse(status));
  })
);

router.get(
  "/me",
  requireAuth,
  asyncHandler(async (req, res) => {
    const session = await serializeSession(req.auth.user.id, {
      sessionId: req.auth.sessionId,
      activeAccountId: req.auth.activeAccountId,
    });
    return res.json(detailResponse(session));
  })
);

/** Availability check used by the signup form; deliberately rate-limited. */
router.get(
  "/email-available",
  authLimiter,
  asyncHandler(async (req, res) => {
    const email = String(req.query.email || "").trim().toLowerCase();
    if (!email || !email.includes("@")) throw AppError.badRequest("Enter a valid email address.");
    const existing = await queryOne("SELECT id FROM users WHERE email_normalized = ? LIMIT 1", [email]);
    return res.json(detailResponse({ available: !existing }));
  })
);

export default router;
