import { Router } from "express";
import { z } from "zod";
import env from "../../config/env.js";
import { asyncHandler } from "../../middleware/errors.js";
import { validate } from "../../middleware/validation.js";
import { authLimiter, writeLimiter } from "../../middleware/rateLimit.js";
import { requireAuth } from "../../middleware/auth.js";
import { issueCsrfToken } from "../../middleware/csrf.js";
import { sessionCookieOptions, setActiveAccount } from "../auth/sessions.js";
import { serializeSession } from "../auth/session.serializer.js";
import { detailResponse } from "../../utils/http.js";
import { AppError } from "../../utils/errors.js";
import { PHONE_LENGTH_MESSAGE } from "../../utils/phone.js";
import * as accountsService from "./accounts.service.js";
import { ORGANIZATION_KINDS } from "./accounts.service.js";
import * as sellerApplication from "./sellerApplication.service.js";
import * as teamInvitations from "./teamInvitation.service.js";
import * as verificationService from "./verification.service.js";
import { queryOne } from "../../db/query.js";

const router = Router();

const personName = (message) =>
  z.string().trim().min(1, message).max(120).regex(/^[^<>]*\p{L}[^<>]*$/u, message);

const internationalPhone = z
  .string()
  .trim()
  .regex(/^\+[1-9]\d{6,14}$/, PHONE_LENGTH_MESSAGE);

const webAddress = z
  .string()
  .trim()
  .max(500)
  .refine((value) => {
    try {
      const url = new URL(value);
      return ["http:", "https:"].includes(url.protocol) && url.hostname.includes(".");
    } catch {
      return false;
    }
  }, "Enter a valid website address.");

const required = (message) => z.string({ message }).trim().min(1, message);

const signupDocuments = z
  .array(z.object({ uploadId: z.string(), documentType: z.string().max(80), fileName: z.string().max(255).optional() }))
  .optional();

const hasCountry = (value) => Boolean(value.countryId || value.country);
const countryRule = { message: "Choose your country.", path: ["country"] };

const baseSignup = {
  firstName: personName("Enter your first name."),
  lastName: personName("Enter your last name."),
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255),
  phone: z.string({ message: "Enter a valid phone number." }).pipe(internationalPhone),
  country: z.string().trim().max(120).optional().or(z.literal("")),
  countryId: z.string().trim().max(40).optional().or(z.literal("")),
  city: z.string().trim().max(120).optional().or(z.literal("")),
  cityId: z.string().trim().max(40).optional().or(z.literal("")),
  password: z.string().min(1, "Choose a password.").max(200),
  confirmPassword: z.string().max(200).optional(),
  agreements: z.union([z.boolean(), z.literal("true"), z.literal("on")]).optional(),
  marketingOptIn: z.boolean().optional(),
};

const personalSignupSchema = z
  .object({
    ...baseSignup,
    displayName: required("Enter your display name.").pipe(z.string().min(2, "Enter your display name.").max(200)),
    bio: required("Add a professional bio.").pipe(z.string().max(12000, "Keep your bio shorter.")),
    title: z.string().trim().max(120).optional().or(z.literal("")),
    categoryId: z.string().trim().max(40).optional(),
    license: z.string().trim().max(120).optional().or(z.literal("")),
    intendsToList: z.boolean().optional(),
    verificationRequestId: z.union([z.string(), z.number()]).optional(),
    documents: signupDocuments,
  })
  .refine(hasCountry, countryRule)
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
    legalName: z.string().trim().min(2, "Enter the legal name.").max(255).regex(/\p{L}/u, "Enter the legal name."),
    publicName: required("Enter the public name.").pipe(z.string().min(2, "Enter the public name.").max(200)),
    organizationType: required("Choose the organization type.").refine(
      (value) => ORGANIZATION_KINDS.includes(value),
      "Choose the organization type."
    ),
    registrationNumber: required("Enter the registration number.").pipe(
      z.string().regex(/^(?=.*\d)[\p{L}\d][\p{L}\d ./-]{2,119}$/u, "Enter a valid registration number.")
    ),
    issuingAuthority: z.string().trim().max(160).optional().or(z.literal("")),
    website: webAddress.optional().or(z.literal("")),
    organizationEmail: required("Enter the organization email.").pipe(
      z.string().toLowerCase().email("Enter a valid email address.").max(255)
    ),
    organizationPhone: z.string({ message: "Enter a valid phone number." }).pipe(internationalPhone),
    address: required("Enter the address.").pipe(z.string().min(8, "Enter the full address.").max(500)),
    description: required("Add a company profile.").pipe(z.string().max(12000, "Keep the company profile shorter.")),
    categoryId: z.string().trim().min(1, "Choose a marketplace category.").max(40),
    documents: signupDocuments,
  })
  .refine(hasCountry, countryRule)
  .refine((value) => !value.confirmPassword || value.confirmPassword === value.password, {
    message: "Passwords must match.",
    path: ["confirmPassword"],
  })
  .refine((value) => value.agreements === true || value.agreements === "true" || value.agreements === "on", {
    message: "Agreement is required.",
    path: ["agreements"],
  });

const memberSignupSchema = z.object({
  name: z.string().trim().min(2, "Enter your name.").max(200).regex(/^[^<>]*\p{L}[^<>]*$/u, "Enter your name."),
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255),
  password: z.string().min(1, "Choose a password.").max(200),
  agreements: z.literal(true, { message: "Accept the terms to continue." }),
});

const personalApplication = z.object({
  accountType: z.literal("personal"),
  phone: internationalPhone,
  countryId: required("Choose your country."),
  cityId: z.string().trim().max(40).optional().or(z.literal("")),
  displayName: required("Enter your display name.").pipe(z.string().min(2, "Enter your display name.").max(200)),
  bio: required("Add a professional bio.").pipe(z.string().max(12000, "Keep your bio shorter.")),
  license: z.string().trim().max(120).optional().or(z.literal("")),
  categoryId: required("Choose a marketplace category.").pipe(z.string().max(40)),
  documents: z.array(z.object({ uploadId: z.string(), documentType: z.string().max(80), fileName: z.string().max(255).optional() })),
});

const organizationApplication = personalApplication.omit({ accountType: true, displayName: true, bio: true, license: true }).extend({
  accountType: z.literal("organization"),
  legalName: z.string().trim().min(2, "Enter the legal name.").max(255).regex(/\p{L}/u, "Enter the legal name."),
  publicName: required("Enter the public name.").pipe(z.string().min(2, "Enter the public name.").max(200)),
  organizationType: required("Choose the organization type.").refine((value) => ORGANIZATION_KINDS.includes(value), "Choose the organization type."),
  registrationNumber: required("Enter the registration number.").pipe(
    z.string().regex(/^(?=.*\d)[\p{L}\d][\p{L}\d ./-]{2,119}$/u, "Enter a valid registration number.")
  ),
  website: webAddress.optional().or(z.literal("")),
  organizationEmail: required("Enter the organization email.").pipe(z.string().toLowerCase().email("Enter a valid email address.").max(255)),
  organizationPhone: internationalPhone,
  address: required("Enter the address.").pipe(z.string().min(8, "Enter the full address.").max(500)),
  description: required("Add a company profile.").pipe(z.string().max(12000, "Keep the company profile shorter.")),
});

function establishSession(req, res, session) {
  const maxAge = new Date(session.expiresAt).getTime() - Date.now();
  res.cookie(env.SESSION_COOKIE_NAME, session.token, sessionCookieOptions(maxAge));
  return issueCsrfToken({ ...req, cookies: { ...req.cookies, [env.SESSION_COOKIE_NAME]: session.token } }, res);
}

router.post(
  "/member/signup",
  authLimiter,
  validate({ body: memberSignupSchema }),
  asyncHandler(async (req, res) => {
    const result = await accountsService.signupMember(req.body, { ip: req.ip, userAgent: req.get("user-agent") });
    const csrfToken = establishSession(req, res, result.session);
    const session = await serializeSession(result.userId);
    return res.status(201).json(detailResponse({ ...session, csrfToken }));
  })
);

router.post(
  "/invitations/preview",
  authLimiter,
  validate({ body: z.object({ token: z.string().min(20).max(200) }) }),
  asyncHandler(async (req, res) => res.json(detailResponse(await teamInvitations.previewInvitation(req.body.token))))
);

router.post(
  "/invitations/accept",
  authLimiter,
  validate({ body: teamInvitations.invitationAcceptSchema }),
  asyncHandler(async (req, res) => {
    const result = await teamInvitations.acceptInvitation({
      input: req.body,
      auth: req.auth,
      ip: req.ip,
      userAgent: req.get("user-agent"),
    });
    if (result.session) {
      const csrfToken = establishSession(req, res, result.session);
      return res.status(201).json(detailResponse({ ...(await serializeSession(result.userId)), csrfToken }));
    }
    await setActiveAccount(req.auth.sessionId, result.accountId);
    return res.json(detailResponse(await serializeSession(result.userId, { sessionId: req.auth.sessionId, activeAccountId: result.accountId })));
  })
);

router.get(
  "/seller-application",
  requireAuth,
  asyncHandler(async (req, res) => res.json(detailResponse(await sellerApplication.applicationStatus(req))))
);

router.post(
  "/seller-application",
  writeLimiter,
  requireAuth,
  validate({ body: z.discriminatedUnion("accountType", [personalApplication, organizationApplication]) }),
  asyncHandler(async (req, res) => res.status(201).json(detailResponse(await sellerApplication.submitApplication(req, req.body))))
);

router.post(
  "/personal/signup",
  authLimiter,
  validate({ body: personalSignupSchema }),
  asyncHandler(async (req, res) => {
    await verificationService.assertSignupDocuments(req.body.documents);
    const result = await accountsService.signupPersonal(req.body, {
      ip: req.ip,
      userAgent: req.get("user-agent"),
    });
    if (req.body.documents?.length) {
      await verificationService.attachUploadedDocuments({
        verificationRequestId: result.verificationId,
        userId: result.userId,
        atSignup: true,
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
    await verificationService.assertSignupDocuments(req.body.documents);
    const result = await accountsService.signupOrganization(req.body, {
      ip: req.ip,
      userAgent: req.get("user-agent"),
    });
    if (req.body.documents?.length) {
      await verificationService.attachUploadedDocuments({
        verificationRequestId: result.verificationId,
        userId: result.userId,
        atSignup: true,
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
const uploadRequest = z.object({
  fileName: z.string().trim().min(1).max(255),
  mimeType: z.string().trim().min(1).max(120),
  fileSizeBytes: z.coerce.number().int().min(1).max(25 * 1024 * 1024),
  documentType: z.string().trim().min(1).max(80),
});

router.post(
  "/verification/uploads/presign",
  writeLimiter,
  requireAuth,
  validate({ body: uploadRequest }),
  asyncHandler(async (req, res) => {
    const target = await verificationService.presignVerificationUpload({
      userId: req.auth.user.id,
      accountId: req.auth.activeAccountId,
      ...req.body,
    });
    return res.json(detailResponse(target));
  })
);

/**
 * The same target for someone still applying. The application carries their documents
 * but has no account until it is submitted, and a new account's session only works once
 * its email is verified, so this step cannot require one.
 */
router.post(
  "/verification/uploads/signup-presign",
  writeLimiter,
  validate({ body: uploadRequest }),
  asyncHandler(async (req, res) => {
    return res.json(detailResponse(await verificationService.presignVerificationUpload(req.body)));
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
        .array(z.object({ uploadId: z.string().min(1).max(200), documentType: z.string().min(1).max(80), fileName: z.string().max(255).optional() }))
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
