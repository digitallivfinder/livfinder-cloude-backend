import crypto from "node:crypto";
import net from "node:net";
import rateLimit from "express-rate-limit";
import env from "../config/env.js";
import logger from "../config/logger.js";
import { execute, queryOne } from "../db/query.js";
import { AppError } from "../utils/errors.js";
import { sha256 } from "../utils/ids.js";
import { importProviderId } from "../modules/imports/importConnection.js";

/**
 * API-key authentication for the partner API (`/v1/partner/*`).
 *
 * A company's system signs every request with a key the company created in Portal > API &
 * Integrations: `Authorization: Basic base64(client_id:secret)`. The key belongs to exactly one
 * organization, so the key alone decides whose account a listing lands in — nothing in a request
 * body can name another company.
 *
 * A key is accepted only when it is active, unexpired, its organization and account are active,
 * the caller's IP is on the key's allow-list (when it has one), and it holds the route's scope.
 * The first four answer the same 401, so a caller cannot tell which of them failed.
 */

export const API_SCOPES = Object.freeze(["listings:read", "listings:write"]);

// `listings:write` covers reading back what was written.
const IMPLIED = { "listings:write": ["listings:read"] };

function parseBasic(header) {
  const match = /^Basic\s+([A-Za-z0-9+/=_-]+)\s*$/i.exec(header || "");
  if (!match) return null;
  let decoded;
  try {
    decoded = Buffer.from(match[1], "base64").toString("utf8");
  } catch {
    return null;
  }
  const separator = decoded.indexOf(":");
  if (separator <= 0) return null;
  return { clientId: decoded.slice(0, separator), secret: decoded.slice(separator + 1) };
}

function parseJsonArray(value) {
  if (Array.isArray(value)) return value;
  if (typeof value === "string" && value.trim()) {
    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }
  return [];
}

export function normalizeIp(ip) {
  const value = String(ip || "").trim();
  return value.startsWith("::ffff:") && net.isIPv4(value.slice(7)) ? value.slice(7) : value;
}

/** Exact addresses and CIDR ranges, IPv4 or IPv6. An empty list allows any address. */
export function ipAllowed(ip, allowedIps) {
  const list = parseJsonArray(allowedIps).map((entry) => String(entry).trim()).filter(Boolean);
  if (!list.length) return true;
  const address = normalizeIp(ip);
  const family = net.isIPv4(address) ? "ipv4" : net.isIPv6(address) ? "ipv6" : null;
  if (!family) return false;
  const blocks = new net.BlockList();
  for (const entry of list) {
    const [base, bits] = entry.split("/");
    const baseFamily = net.isIPv4(base) ? "ipv4" : net.isIPv6(base) ? "ipv6" : null;
    if (!baseFamily) continue;
    if (bits === undefined) blocks.addAddress(base, baseFamily);
    else if (/^\d+$/.test(bits)) blocks.addSubnet(base, Number(bits), baseFamily);
  }
  return blocks.check(address, family);
}

export function scopesGrant(scopes, required) {
  const held = new Set();
  for (const scope of parseJsonArray(scopes)) {
    held.add(scope);
    for (const implied of IMPLIED[scope] || []) held.add(implied);
  }
  return held.has(required);
}

const invalidKey = () =>
  new AppError("The API key is not valid.", { status: 401, code: "API_KEY_INVALID" });

async function resolveClient(credentials) {
  const row = await queryOne(
    `SELECT ac.id, ac.public_id, ac.name, ac.client_id, ac.secret_hash, ac.scopes, ac.allowed_ips,
            ac.rate_limit_per_minute, ac.status, ac.expires_at, ac.created_by_user_id,
            ac.organization_id, COALESCE(ac.account_id, o.account_id) AS account_id,
            o.public_id AS organization_public_id, o.name AS organization_name, o.status AS organization_status,
            o.deleted_at AS organization_deleted_at,
            a.status AS account_status
       FROM api_clients ac
       JOIN organizations o ON o.id = ac.organization_id
       JOIN accounts a ON a.id = COALESCE(ac.account_id, o.account_id)
      WHERE ac.client_id = ?
      LIMIT 1`,
    [credentials.clientId]
  );
  // Hash the presented secret whether or not the key exists, so a missing key costs the same.
  const presented = sha256(credentials.secret);
  if (!row) return null;
  const stored = Buffer.isBuffer(row.secret_hash) ? row.secret_hash : Buffer.from(row.secret_hash || "");
  if (stored.length !== presented.length || !crypto.timingSafeEqual(stored, presented)) return null;
  if (row.status !== "active") return null;
  if (row.expires_at && new Date(row.expires_at) <= new Date()) return null;
  if (row.organization_deleted_at || row.organization_status !== "active") return null;
  if (row.account_status !== "active") return null;
  return row;
}

/** Signs the request in as an API key holding `scope`. Sets `req.apiClient`. */
export function requireApiClient(scope) {
  return async (req, res, next) => {
    try {
      const header = req.get("authorization");
      if (!header) {
        throw new AppError("Send the API key as HTTP Basic credentials: client id and secret.", {
          status: 401,
          code: "API_KEY_REQUIRED",
        });
      }
      const credentials = parseBasic(header);
      if (!credentials) throw invalidKey();

      const row = await resolveClient(credentials);
      if (!row) {
        logger.warn({ clientId: credentials.clientId.slice(0, 40), ip: req.ip }, "partner api: key refused");
        throw invalidKey();
      }

      // Identified from here on, so the request log can attribute even a refusal below.
      req.apiClient = {
        id: row.id,
        publicId: row.public_id,
        name: row.name,
        clientId: row.client_id,
        organizationId: row.organization_id,
        organizationPublicId: row.organization_public_id,
        organizationName: row.organization_name,
        accountId: row.account_id,
        createdByUserId: row.created_by_user_id ?? null,
        rateLimitPerMinute: Number(row.rate_limit_per_minute) || 60,
        scopes: parseJsonArray(row.scopes),
        ip: normalizeIp(req.ip),
      };

      if (!ipAllowed(req.ip, row.allowed_ips)) {
        throw new AppError("This API key cannot be used from this IP address.", { status: 403, code: "IP_NOT_ALLOWED" });
      }
      if (scope && !scopesGrant(row.scopes, scope)) {
        throw new AppError(`This API key does not have the "${scope}" scope.`, { status: 403, code: "SCOPE_MISSING" });
      }

      execute(
        `UPDATE api_clients SET last_used_at = NOW(3)
          WHERE id = ? AND (last_used_at IS NULL OR last_used_at < DATE_SUB(NOW(3), INTERVAL 1 MINUTE))`,
        [row.id]
      ).catch(() => {});
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

/** One budget per key, sized by the key's own `rate_limit_per_minute`. */
export const apiClientLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: (req) => req.apiClient?.rateLimitPerMinute || 60,
  keyGenerator: (req) => `api-client:${req.apiClient?.id ?? "anonymous"}`,
  standardHeaders: "draft-7",
  legacyHeaders: false,
  skip: () => env.isTest,
  handler: (req, res, next) => next(AppError.tooManyRequests("This API key is over its per-minute limit.")),
});

/**
 * Writes one `api_request_logs` row per partner request once the response is sent: the key,
 * the templated endpoint, status, timing, the caller's IP and user agent, and for failures a
 * short excerpt of the request and of the error. Never blocks or fails the request.
 */
export function logPartnerRequest(req, res, next) {
  const started = process.hrtime.bigint();
  let responseBody = null;
  const originalJson = res.json.bind(res);
  res.json = (body) => {
    responseBody = body;
    return originalJson(body);
  };

  res.on("finish", () => {
    const status = res.statusCode;
    const failed = status >= 400;
    const durationMs = Number((process.hrtime.bigint() - started) / 1_000_000n);
    const endpoint = `${req.baseUrl}${req.route?.path ?? req.path}`.slice(0, 255);
    const excerpt = (value) => {
      if (value === undefined || value === null) return null;
      try {
        return JSON.stringify(value).slice(0, 2000);
      } catch {
        return null;
      }
    };
    importProviderId()
      .catch(() => null)
      .then((providerId) =>
        execute(
          `INSERT INTO api_request_logs
             (occurred_at, direction, api_client_id, provider_id, organization_id, method, endpoint, full_path,
              api_version, status_code, duration_ms, request_bytes, request_body_excerpt, response_body_excerpt,
              error_code, error_message, was_rate_limited, idempotency_key, ip_address, user_agent)
           VALUES (NOW(3), 'inbound', ?, ?, ?, ?, ?, ?, 'v1', ?, ?, ?, ?, ?, ?, ?, ?, ?, INET6_ATON(?), ?)`,
          [
            req.apiClient?.id ?? null,
            providerId,
            req.apiClient?.organizationId ?? null,
            req.method,
            endpoint,
            req.originalUrl.slice(0, 500),
            status,
            durationMs,
            Number(req.get("content-length")) || null,
            failed ? excerpt(req.body) : null,
            failed ? excerpt(responseBody) : null,
            failed ? String(responseBody?.error?.code || "").slice(0, 60) || null : null,
            failed ? String(responseBody?.error?.message || "").slice(0, 500) || null : null,
            status === 429 ? 1 : 0,
            req.get("idempotency-key")?.slice(0, 120) || null,
            normalizeIp(req.ip) || null,
            req.get("user-agent")?.slice(0, 300) || null,
          ]
        )
      )
      .catch((error) => logger.warn({ err: error }, "partner api request not logged"));
  });
  next();
}
