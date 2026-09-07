import helmet from "helmet";
import cors from "cors";
import env from "../config/env.js";
import { AppError } from "../utils/errors.js";

export function securityHeaders() {
  return helmet({
    // The API returns JSON and serves locally-stored media; it renders no HTML,
    // so the default CSP would only ever apply to error pages.
    contentSecurityPolicy: {
      useDefaults: true,
      directives: {
        defaultSrc: ["'none'"],
        imgSrc: ["'self'", "data:"],
        frameAncestors: ["'none'"],
        // helmet's default upgrade-insecure-requests breaks local http media.
        upgradeInsecureRequests: env.isProduction ? [] : null,
      },
    },
    crossOriginResourcePolicy: { policy: "cross-origin" },
    crossOriginEmbedderPolicy: false,
    referrerPolicy: { policy: "strict-origin-when-cross-origin" },
    hsts: env.isProduction ? { maxAge: 15552000, includeSubDomains: true } : false,
  });
}

/**
 * `localhost` and `127.0.0.1` are different origins to a browser, so a developer who opens the
 * site on one spelling while the allowlist names the other gets every request blocked and a page
 * that never finishes loading. Outside production we therefore accept any loopback origin; the
 * configured allowlist is still the only thing that counts in production.
 */
const LOOPBACK_ORIGIN = /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/;

export function isOriginAllowed(origin, { allowed, isProduction }) {
  if (allowed.has(origin)) return true;
  return !isProduction && LOOPBACK_ORIGIN.test(origin);
}

export function corsMiddleware() {
  const allowed = new Set(env.allowedOrigins);
  return cors({
    origin(origin, callback) {
      // No Origin header: same-origin, curl, or a server-side fetch. Allowed —
      // those requests carry no ambient browser credentials from another site.
      if (!origin) return callback(null, true);
      if (isOriginAllowed(origin, { allowed, isProduction: env.isProduction })) return callback(null, true);
      return callback(AppError.forbidden("Origin not allowed."));
    },
    // Never "*" together with credentials; the origin is echoed explicitly.
    credentials: true,
    methods: ["GET", "POST", "PATCH", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Accept", "X-CSRF-Token", "X-Request-ID", "X-Livfinder-Client"],
    exposedHeaders: ["X-Request-ID"],
    maxAge: 600,
  });
}
