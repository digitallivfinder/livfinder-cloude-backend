import env from "../config/env.js";
import { AppError } from "../utils/errors.js";
import { resolveSession, touchSession } from "../modules/auth/sessions.js";
import {
  loadAccountMemberships,
  loadAgentProfile,
  loadPlatformAccess,
  hasPlatformPermission,
  hasAnyPlatformPermission,
} from "../modules/auth/rbac.js";

function readSessionToken(req) {
  return req.cookies?.[env.SESSION_COOKIE_NAME] || null;
}

/**
 * Populates req.auth when a valid session cookie is present. Never rejects —
 * requireAuth and the permission guards do that, so public endpoints can also
 * personalise (favourite state, for example) without branching.
 */
export async function attachSession(req, res, next) {
  try {
    const token = readSessionToken(req);
    if (!token) return next();

    const session = await resolveSession(token);
    if (!session) return next();

    const [platform, memberships, agent] = await Promise.all([
      loadPlatformAccess(session.user_id),
      loadAccountMemberships(session.user_id),
      loadAgentProfile(session.user_id),
    ]);

    const activeAccountId =
      memberships.find((m) => String(m.account_id) === String(session.active_account_id))?.account_id ??
      memberships.find((m) => String(m.account_id) === String(session.default_account_id))?.account_id ??
      memberships[0]?.account_id ??
      null;

    req.auth = {
      sessionId: session.session_id,
      sessionPublicId: session.session_public_id,
      impersonatedByUserId: session.impersonated_by_user_id,
      user: {
        id: session.user_id,
        publicId: session.user_public_id,
        email: session.email,
        displayName: session.display_name,
        firstName: session.first_name,
        lastName: session.last_name,
        avatarUrl: session.avatar_url,
        emailVerifiedAt: session.email_verified_at,
        status: session.user_status,
      },
      platform,
      memberships,
      activeAccountId,
      activeMembership: memberships.find((m) => String(m.account_id) === String(activeAccountId)) || null,
      agent,
    };

    // Fire-and-forget: a failed last_used_at write must not fail the request.
    touchSession(session.session_id).catch(() => {});
    return next();
  } catch (error) {
    return next(error);
  }
}

export function requireAuth(req, res, next) {
  if (!req.auth?.user) return next(AppError.unauthorized());
  return next();
}

export function requireVerifiedEmail(req, res, next) {
  if (!req.auth?.user) return next(AppError.unauthorized());
  if (!req.auth.user.emailVerifiedAt) {
    return next(AppError.forbidden("Verify your email address to continue."));
  }
  return next();
}

/** Platform permission gate for the admin surface. */
export function requirePermission(...codes) {
  return (req, res, next) => {
    if (!req.auth?.user) return next(AppError.unauthorized());
    if (!hasAnyPlatformPermission(req.auth.platform, codes)) {
      return next(AppError.forbidden());
    }
    return next();
  };
}

/**
 * Step-up re-authentication — SEC-IAM-011.
 *
 * Requires the session to have re-proved itself recently before a high-risk action. The proof
 * lives on `user_sessions.stepped_up_at`, so it authorises *this browser* for a window rather
 * than the user everywhere — a step-up on a laptop must not silently authorise the same action
 * from a phone.
 *
 * A refusal is 403 with `code: "STEP_UP_REQUIRED"` so the client can open the prompt and retry,
 * rather than showing a generic "not allowed" for something the user is in fact allowed to do.
 */
export function requireStepUp({ withinMinutes = 15 } = {}) {
  return async (req, res, next) => {
    try {
      if (!req.auth?.user) return next(AppError.unauthorized());
      const { queryOne } = await import("../db/query.js");
      const row = await queryOne(
        "SELECT stepped_up_at FROM user_sessions WHERE id = ? LIMIT 1",
        [req.auth.sessionId]
      );
      const at = row?.stepped_up_at ? new Date(row.stepped_up_at).getTime() : 0;
      if (!at || Date.now() - at > withinMinutes * 60_000) {
        const error = AppError.forbidden("Confirm it is you before continuing.");
        error.code = "STEP_UP_REQUIRED";
        return next(error);
      }
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

/**
 * Category scope — enforced separately from the permission itself.
 *
 * `requirePermission("listings.edit")` answers whether the caller may edit listings at all.
 * This answers whether they may edit *this* one, given the categories their roles cover. Both
 * have to hold; a "Cars Moderator" who holds `listings.moderate` must still be refused a yacht.
 *
 * 404 rather than 403 on a scoped-out resource, matching how ownership is handled elsewhere:
 * confirming that a record exists is itself a disclosure.
 */
export function assertCategoryScope(req, categoryCode) {
  const scopes = req.auth?.platform?.scopes;
  if (!scopes || scopes.allCategories) return;
  if (!categoryCode) return;
  if (!scopes.categories.has(String(categoryCode))) {
    throw AppError.notFound("That record was not found.");
  }
}

/** True/false form, for list queries that filter rather than reject. */
export function categoryScopeFilter(req) {
  const scopes = req.auth?.platform?.scopes;
  if (!scopes || scopes.allCategories) return null;
  return [...scopes.categories];
}

/**
 * Route guard for endpoints whose category is knowable from the request — a `:category` path
 * parameter or a `category` query value. Resources identified only by id are checked inside the
 * service, once the row has been read.
 */
export function requireCategoryScope(source = "params", key = "category") {
  return (req, res, next) => {
    try {
      const value = source === "query" ? req.query?.[key] : req.params?.[key];
      if (value) assertCategoryScope(req, value);
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

/** Any platform role at all — the admin shell itself. */
export function requireAdmin(req, res, next) {
  if (!req.auth?.user) return next(AppError.unauthorized());
  if (!req.auth.platform?.roles?.length) return next(AppError.forbidden());
  return next();
}

/** Portal gate: the caller must hold an active membership on some account. */
export function requireAccount(req, res, next) {
  if (!req.auth?.user) return next(AppError.unauthorized());
  if (!req.auth.activeMembership) {
    return next(AppError.forbidden("This account cannot use the client portal."));
  }
  return next();
}

/** Portal capability gate, e.g. requireAccountCapability("can_manage_listings"). */
export function requireAccountCapability(capability) {
  return (req, res, next) => {
    if (!req.auth?.user) return next(AppError.unauthorized());
    const membership = req.auth.activeMembership;
    if (!membership) return next(AppError.forbidden());
    // An owner holds every capability on their own account regardless of the
    // per-membership flags, which exist to *restrict* delegated members.
    if (membership.role === "owner" || membership[capability] === 1) return next();
    return next(AppError.forbidden());
  };
}

export { hasPlatformPermission };
