import crypto from "node:crypto";
import env from "../config/env.js";
import { AppError } from "../utils/errors.js";

const SAFE_METHODS = new Set(["GET", "HEAD", "OPTIONS"]);

/**
 * Signed double-submit CSRF.
 *
 * The cookie holds `<random>.<hmac>`; the client echoes the whole value in the
 * X-CSRF-Token header. An attacker on another origin can neither read the
 * cookie nor forge the HMAC, and because the token is bound to the session id
 * it cannot be lifted from an anonymous response and replayed against a
 * signed-in one.
 *
 * The cookie is deliberately readable by JavaScript — that is how the browser
 * client echoes it. It carries no authority on its own.
 */
function sign(value, sessionKey) {
  return crypto
    .createHmac("sha256", env.SESSION_SECRET)
    .update(`${value}.${sessionKey}`)
    .digest("base64url");
}

function sessionKeyFor(req) {
  return req.cookies?.[env.SESSION_COOKIE_NAME]
    ? crypto.createHash("sha256").update(req.cookies[env.SESSION_COOKIE_NAME]).digest("base64url").slice(0, 22)
    : "anonymous";
}

export function issueCsrfToken(req, res) {
  const random = crypto.randomBytes(24).toString("base64url");
  const token = `${random}.${sign(random, sessionKeyFor(req))}`;
  res.cookie(env.CSRF_COOKIE_NAME, token, {
    httpOnly: false,
    secure: env.isProduction,
    sameSite: env.COOKIE_SAMESITE,
    domain: env.COOKIE_DOMAIN,
    path: "/",
    maxAge: 12 * 60 * 60 * 1000,
  });
  return token;
}

function verify(token, req) {
  if (typeof token !== "string" || !token.includes(".")) return false;
  const [random, mac] = token.split(".");
  if (!random || !mac) return false;
  const expected = sign(random, sessionKeyFor(req));
  const a = Buffer.from(mac);
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

export function csrfProtection(req, res, next) {
  if (SAFE_METHODS.has(req.method)) return next();

  // Server-to-server callers (the Next.js server components, a native client)
  // authenticate with a bearer-style API key rather than a cookie, so they are
  // not exposed to CSRF and are exempt.
  if (!req.cookies?.[env.SESSION_COOKIE_NAME] && !req.cookies?.[env.CSRF_COOKIE_NAME]) {
    return next();
  }

  const header = req.get("x-csrf-token") || req.body?._csrf;
  const cookie = req.cookies?.[env.CSRF_COOKIE_NAME];

  if (!header || !cookie || header !== cookie || !verify(header, req)) {
    return next(
      new AppError("This request could not be verified. Refresh the page and try again.", {
        status: 403,
        code: "CSRF_TOKEN_INVALID",
      })
    );
  }
  return next();
}

export function csrfTokenRoute(req, res) {
  const token = issueCsrfToken(req, res);
  res.json({ data: { csrfToken: token } });
}
