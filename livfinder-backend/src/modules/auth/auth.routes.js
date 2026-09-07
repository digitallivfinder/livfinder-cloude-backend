import { Router } from "express";
import crypto from "node:crypto";
import { z } from "zod";
import env from "../../config/env.js";
import { asyncHandler } from "../../middleware/errors.js";
import { validate } from "../../middleware/validation.js";
import { authLimiter, sessionLimiter, writeLimiter } from "../../middleware/rateLimit.js";
import { requireAuth } from "../../middleware/auth.js";
import { issueCsrfToken } from "../../middleware/csrf.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse } from "../../utils/http.js";
import { sessionCookieOptions, listUserSessions, setActiveAccount } from "./sessions.js";
import * as authService from "./auth.service.js";
import { serializeSession } from "./session.serializer.js";
import { auditFromRequest } from "../system/audit.service.js";
import { safeFetch } from "../../utils/safeFetch.js";
import { execute, queryOne } from "../../db/query.js";
import * as mfa from "./mfa.service.js";

const router = Router();

const emailField = z.string().trim().toLowerCase().email("Enter a valid email address.").max(255);

const loginSchema = z.object({
  email: emailField,
  password: z.string().min(1, "Enter your password.").max(200),
  remember: z.boolean().optional(),
});

function setSessionCookie(res, session) {
  const maxAge = new Date(session.expiresAt).getTime() - Date.now();
  res.cookie(env.SESSION_COOKIE_NAME, session.token, sessionCookieOptions(maxAge));
}

function clearSessionCookie(res) {
  res.clearCookie(env.SESSION_COOKIE_NAME, { ...sessionCookieOptions(0), maxAge: undefined });
  res.clearCookie(env.CSRF_COOKIE_NAME, { path: "/", domain: env.COOKIE_DOMAIN });
}

router.post(
  "/login",
  authLimiter,
  validate({ body: loginSchema }),
  asyncHandler(async (req, res) => {
    const { user, session } = await authService.login({
      email: req.body.email,
      password: req.body.password,
      ip: req.ip,
      userAgent: req.get("user-agent"),
    });
    setSessionCookie(res, session);
    // The CSRF token is bound to the new session token, so it has to be
    // reissued at exactly this point.
    const csrfToken = issueCsrfToken({ ...req, cookies: { ...req.cookies, [env.SESSION_COOKIE_NAME]: session.token } }, res);
    const payload = await serializeSession(user.id, { sessionId: null });
    return res.json(detailResponse({ ...payload, csrfToken }));
  })
);

router.post(
  "/logout",
  requireAuth,
  asyncHandler(async (req, res) => {
    await authService.logout({
      sessionId: req.auth.sessionId,
      userId: req.auth.user.id,
      everywhere: req.body?.everywhere === true,
      ip: req.ip,
    });
    clearSessionCookie(res);
    return res.json(detailResponse({ signedOut: true }));
  })
);

router.get(
  "/session",
  sessionLimiter,
  asyncHandler(async (req, res) => {
    if (!req.auth?.user) {
      // 200 with a null session: "not signed in" is a normal answer for a page
      // that renders differently either way, not an error.
      return res.json(detailResponse(null));
    }
    const payload = await serializeSession(req.auth.user.id, { sessionId: req.auth.sessionId });
    const csrfToken = issueCsrfToken(req, res);
    return res.json(detailResponse({ ...payload, csrfToken }));
  })
);

router.get(
  "/sessions",
  requireAuth,
  asyncHandler(async (req, res) => {
    const rows = await listUserSessions(req.auth.user.id);
    return res.json({
      data: rows.map((row) => ({
        id: row.public_id,
        deviceType: row.device_type,
        userAgent: row.user_agent,
        createdAt: row.created_at,
        lastUsedAt: row.last_used_at,
        expiresAt: row.expires_at,
        revoked: Boolean(row.revoked_at),
        current: row.public_id === req.auth.sessionPublicId,
      })),
    });
  })
);

/**
 * Revokes a single device. The list this backs is the only place a user can discover that
 * someone else holds a live session as them, and "sign out everywhere" is a blunt instrument
 * when only one device is the problem.
 */
router.delete(
  "/sessions/:id",
  requireAuth,
  asyncHandler(async (req, res) => {
    const { revokeUserSession } = await import("./sessions.js");
    const result = await revokeUserSession({
      userId: req.auth.user.id,
      sessionPublicId: req.params.id,
      currentSessionId: req.auth.sessionId,
    });
    if (!result.found) throw AppError.notFound("That session was not found.");
    if (result.current) throw AppError.badRequest("Use Sign out to end the session you are using.");
    return res.json(detailResponse({ id: req.params.id, revoked: result.revoked }));
  })
);

router.post(
  "/active-account",
  requireAuth,
  validate({ body: z.object({ accountId: z.union([z.string(), z.number()]) }) }),
  asyncHandler(async (req, res) => {
    const membership = req.auth.memberships.find(
      (entry) => String(entry.account_id) === String(req.body.accountId) || entry.account_public_id === req.body.accountId
    );
    if (!membership) throw AppError.forbidden("You are not a member of that account.");
    await setActiveAccount(req.auth.sessionId, membership.account_id);
    const payload = await serializeSession(req.auth.user.id, {
      sessionId: req.auth.sessionId,
      activeAccountId: membership.account_id,
    });
    return res.json(detailResponse(payload));
  })
);

router.post(
  "/forgot-password",
  authLimiter,
  validate({ body: z.object({ email: emailField }) }),
  asyncHandler(async (req, res) => {
    await authService.requestPasswordReset({ email: req.body.email, ip: req.ip });
    // Deliberately identical whether or not the address exists.
    return res.json(detailResponse({ sent: true }));
  })
);

router.post(
  "/reset-password",
  authLimiter,
  validate({
    body: z.object({
      token: z.string().min(10).max(200),
      password: z.string().min(1).max(200),
    }),
  }),
  asyncHandler(async (req, res) => {
    await authService.resetPassword({ token: req.body.token, password: req.body.password, ip: req.ip });
    clearSessionCookie(res);
    return res.json(detailResponse({ reset: true }));
  })
);

/* -------------------------------------------------------------------------- */
/* Multi-factor authentication                                                 */
/* -------------------------------------------------------------------------- */
/**
 * SEC-IAM-002 makes MFA mandatory for workforce, privileged and seller-administrator accounts.
 * `user_mfa_factors` existed and stayed empty; `users.mfa_enabled` was read-only and could
 * never become true. See modules/auth/mfa.service.js.
 */

router.get(
  "/mfa",
  requireAuth,
  asyncHandler(async (req, res) => res.json(detailResponse(await mfa.mfaStatus(req.auth.user.id))))
);

router.post(
  "/mfa/totp",
  requireAuth,
  writeLimiter,
  validate({ body: z.object({ label: z.string().trim().max(120).optional() }).partial() }),
  asyncHandler(async (req, res) => {
    const result = await mfa.beginTotpEnrolment({ userId: req.auth.user.id, label: req.body.label });
    await auditFromRequest(req, { action: "mfa.enrolment_started", subjectType: "user", subjectId: req.auth.user.id });
    // The secret is in this response and in no other. It is never logged: the audit entry
    // above records that enrolment began, not what the secret is.
    return res.status(201).json(detailResponse(result));
  })
);

router.post(
  "/mfa/totp/confirm",
  requireAuth,
  authLimiter,
  validate({ body: z.object({ code: z.string().trim().min(6).max(10) }) }),
  asyncHandler(async (req, res) => {
    const result = await mfa.confirmTotpEnrolment({ userId: req.auth.user.id, code: req.body.code });
    await auditFromRequest(req, { action: "mfa.enabled", subjectType: "user", subjectId: req.auth.user.id });
    return res.json(detailResponse(result));
  })
);

router.delete(
  "/mfa",
  requireAuth,
  authLimiter,
  validate({ body: z.object({ code: z.string().trim().min(6).max(20) }) }),
  asyncHandler(async (req, res) => {
    const result = await mfa.disableMfa({ userId: req.auth.user.id, code: req.body.code });
    await auditFromRequest(req, { action: "mfa.disabled", subjectType: "user", subjectId: req.auth.user.id });
    return res.json(detailResponse(result));
  })
);

/**
 * Step-up — SEC-IAM-011.
 *
 * Re-proves the caller before a high-risk action. The proof is recorded on the session with a
 * timestamp; `requireStepUp` in middleware/auth.js checks its age. A password is accepted when
 * MFA is not enrolled, so the guard is usable before every account has a factor.
 */
router.post(
  "/step-up",
  requireAuth,
  authLimiter,
  validate({
    body: z.object({
      code: z.string().trim().min(6).max(20).optional(),
      password: z.string().min(1).max(200).optional(),
    }),
  }),
  asyncHandler(async (req, res) => {
    const enabled = await mfa.isMfaEnabled(req.auth.user.id);
    let proved = false;

    if (enabled) {
      if (!req.body.code) throw AppError.badRequest("Enter the code from your authenticator app.");
      proved = await mfa.verifyMfaCode({ userId: req.auth.user.id, code: req.body.code });
    } else if (req.body.password) {
      const { verifyPassword } = await import("./passwords.js");
      const row = await queryOne("SELECT password_hash FROM users WHERE id = ?", [req.auth.user.id]);
      // `verifyPassword` returns `{ valid, needsRehash }`; the object alone is always truthy.
      proved = Boolean(row) && (await verifyPassword(row.password_hash, req.body.password))?.valid === true;
    } else {
      throw AppError.badRequest("Confirm your password to continue.");
    }

    if (!proved) {
      await auditFromRequest(req, { action: "auth.step_up_failed", subjectType: "user", subjectId: req.auth.user.id });
      throw AppError.forbidden("That did not match. Try again.");
    }

    await execute("UPDATE user_sessions SET stepped_up_at = NOW(3) WHERE id = ?", [req.auth.sessionId]);
    await auditFromRequest(req, { action: "auth.stepped_up", subjectType: "user", subjectId: req.auth.user.id });
    return res.json(detailResponse({ steppedUpAt: new Date().toISOString(), validForMinutes: 15 }));
  })
);

router.post(
  "/change-password",
  requireAuth,
  validate({
    body: z.object({
      currentPassword: z.string().min(1).max(200),
      newPassword: z.string().min(1).max(200),
    }),
  }),
  asyncHandler(async (req, res) => {
    const session = await authService.changePassword({
      userId: req.auth.user.id,
      currentPassword: req.body.currentPassword,
      newPassword: req.body.newPassword,
      ip: req.ip,
      keepSessionId: req.get("user-agent"),
    });
    setSessionCookie(res, session);
    return res.json(detailResponse({ changed: true }));
  })
);

router.post(
  "/email/resend",
  authLimiter,
  requireAuth,
  asyncHandler(async (req, res) => {
    const result = await authService.sendEmailVerification({ userId: req.auth.user.id, ip: req.ip });
    return res.json(detailResponse(result));
  })
);

router.post(
  "/email/verify",
  authLimiter,
  validate({ body: z.object({ token: z.string().min(10).max(200) }) }),
  asyncHandler(async (req, res) => {
    await authService.verifyEmail({ token: req.body.token, ip: req.ip });
    return res.json(detailResponse({ verified: true }));
  })
);

/* --------------------------------------------------------------------------
 * OAuth
 *
 * The full exchange is implemented. Providers appear only when their client id
 * and secret are configured; with none set, the endpoint says so instead of
 * redirecting somewhere that cannot work.
 * ------------------------------------------------------------------------ */

const OAUTH_STATE_COOKIE = "livfinder_oauth_state";

router.get(
  "/oauth/providers",
  asyncHandler(async (req, res) => {
    const providers = authService.configuredOAuthProviders();
    return res.json({ data: providers.map((provider) => ({ provider: provider.provider, enabled: true })) });
  })
);

router.get(
  "/oauth/:provider",
  asyncHandler(async (req, res) => {
    const configured = authService.configuredOAuthProviders().find((entry) => entry.provider === req.params.provider);
    if (!configured) {
      throw AppError.notImplemented(
        `Sign-in with ${req.params.provider} is not configured on this server.`
      );
    }
    const state = crypto.randomBytes(24).toString("base64url");
    const nonce = crypto.randomBytes(16).toString("base64url");
    res.cookie(OAUTH_STATE_COOKIE, `${state}.${nonce}`, {
      httpOnly: true,
      secure: env.isProduction,
      sameSite: "lax",
      path: "/",
      maxAge: 10 * 60 * 1000,
    });
    const redirectUri = `${req.protocol}://${req.get("host")}/v1/auth/oauth/${req.params.provider}/callback`;
    const url = new URL(configured.authorizeUrl);
    url.searchParams.set("client_id", configured.clientId);
    url.searchParams.set("redirect_uri", redirectUri);
    url.searchParams.set("response_type", "code");
    url.searchParams.set("scope", configured.scope);
    url.searchParams.set("state", state);
    url.searchParams.set("nonce", nonce);
    return res.redirect(url.toString());
  })
);

router.get(
  "/oauth/:provider/callback",
  asyncHandler(async (req, res) => {
    const configured = authService.configuredOAuthProviders().find((entry) => entry.provider === req.params.provider);
    if (!configured) throw AppError.notImplemented();

    const cookie = req.cookies?.[OAUTH_STATE_COOKIE];
    const [expectedState] = String(cookie || "").split(".");
    if (!expectedState || expectedState !== req.query.state) {
      throw AppError.badRequest("That sign-in attempt could not be verified. Try again.");
    }
    res.clearCookie(OAUTH_STATE_COOKIE, { path: "/" });

    const redirectUri = `${req.protocol}://${req.get("host")}/v1/auth/oauth/${req.params.provider}/callback`;
    // Administrator-supplied URL: checked against the allow-list and private ranges before
    // the request leaves the process. See utils/safeFetch.js.
    const tokenResponse = await safeFetch(configured.tokenUrl, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
      body: new URLSearchParams({
        grant_type: "authorization_code",
        code: String(req.query.code || ""),
        redirect_uri: redirectUri,
        client_id: configured.clientId,
        client_secret: configured.clientSecret,
      }),
    });
    if (!tokenResponse.ok) throw AppError.badRequest("Sign-in with that provider failed.");
    const tokens = await tokenResponse.json();

    const profileResponse = await safeFetch(configured.userInfoUrl, {
      headers: { Authorization: `Bearer ${tokens.access_token}`, Accept: "application/json" },
    });
    if (!profileResponse.ok) throw AppError.badRequest("Sign-in with that provider failed.");
    const profile = await profileResponse.json();

    const { session } = await authService.upsertOAuthIdentity({
      provider: req.params.provider,
      subject: String(profile.sub || profile.id),
      email: profile.email,
      displayName: profile.name || profile.given_name,
      avatarUrl: profile.picture,
      ip: req.ip,
      userAgent: req.get("user-agent"),
    });
    setSessionCookie(res, session);
    return res.redirect(`${env.FRONTEND_URL}/portal/dashboard`);
  })
);

export default router;
