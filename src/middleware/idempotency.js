import crypto from "node:crypto";
import { execute, queryOne } from "../db/query.js";
import { AppError } from "../utils/errors.js";
import logger from "../config/logger.js";

/**
 * Idempotency-Key handling.
 *
 * SEC-API-004 requires it and 23 catalogue entries are marked idempotent, but the header was
 * never read: `idempotency_keys` existed and stayed empty. The consequence is concrete rather
 * than theoretical — a buyer whose connection drops mid-request taps "Send enquiry" again and
 * two enquiries reach the seller, or two offers land on one listing. References are allocated
 * with `MAX(...)+1`, so retries also collide on the unique index and fail confusingly.
 *
 * How it behaves:
 *
 *   no header            — proceed as normal. Not mandatory, so an existing caller is unaffected.
 *   first use of a key   — a row is claimed, the handler runs, its status and body are stored.
 *   replay, completed    — the stored response is returned. Same key, same answer, no second write.
 *   replay, in flight    — 409. Two concurrent attempts with one key is a client bug, and
 *                          guessing which should win is worse than saying so.
 *   same key, different  — 422. A key is a promise about one specific request; letting a
 *   request body           different body ride an old key would hide a real mistake.
 *
 * Only successful responses are stored (2xx). Replaying a failure would pin a transient error in
 * place for the whole retention window, when retrying is exactly what the caller should do.
 */

const RETENTION_HOURS = 24;

/** A stable fingerprint of what was asked, so a replay can be told from a different request. */
function hashRequest(req) {
  const body = req.body === undefined ? "" : JSON.stringify(req.body);
  return crypto.createHash("sha256").update(`${req.method}\n${req.originalUrl}\n${body}`).digest("hex");
}

export function idempotency({ scope = "api" } = {}) {
  return async function idempotencyMiddleware(req, res, next) {
    const key = req.get("idempotency-key");
    if (!key || req.method === "GET" || req.method === "HEAD") return next();
    if (key.length > 200) return next(AppError.badRequest("Idempotency-Key is too long."));

    const requestHash = hashRequest(req);
    const endpoint = req.route?.path ? `${req.method} ${req.baseUrl}${req.route.path}` : `${req.method} ${req.path}`;

    try {
      const existing = await queryOne(
        "SELECT * FROM idempotency_keys WHERE idempotency_key = ? AND scope = ? LIMIT 1",
        [key, scope]
      );

      if (existing) {
        if (existing.request_hash !== requestHash) {
          return next(
            AppError.validation("That Idempotency-Key was used for a different request.", {
              "Idempotency-Key": "Use a new key for a new request.",
            })
          );
        }
        if (existing.status === "completed") {
          res.setHeader("Idempotency-Replayed", "true");
          const body = existing.response_body ? JSON.parse(existing.response_body) : null;
          return res.status(existing.response_status || 200).json(body);
        }
        // Still in flight.
        return next(AppError.conflict("That request is already being processed."));
      }

      // Claim the key. The unique index is what actually decides the race: two requests arriving
      // together, one insert wins and the other lands here as a duplicate.
      try {
        await execute(
          `INSERT INTO idempotency_keys
             (idempotency_key, scope, user_id, account_id, endpoint, request_method, request_hash,
              status, locked_at, created_at, expires_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, 'in_progress', NOW(3), NOW(3), DATE_ADD(NOW(3), INTERVAL ? HOUR))`,
          [
            key,
            scope,
            req.auth?.user?.id ?? null,
            req.auth?.activeAccountId ?? null,
            endpoint.slice(0, 255),
            req.method,
            requestHash,
            RETENTION_HOURS,
          ]
        );
      } catch (error) {
        if (error?.cause?.code === "ER_DUP_ENTRY" || error?.code === "ER_DUP_ENTRY") {
          return next(AppError.conflict("That request is already being processed."));
        }
        throw error;
      }
    } catch (error) {
      // The store being unavailable must not block writes outright: losing duplicate protection
      // is bad, refusing every payment and enquiry is worse.
      logger.warn({ err: error, key }, "idempotency store unavailable; proceeding without it");
      return next();
    }

    // Capture the response so a replay can be answered from it.
    const originalJson = res.json.bind(res);
    res.json = (body) => {
      const status = res.statusCode || 200;
      const stored = status >= 200 && status < 300;
      execute(
        `UPDATE idempotency_keys
            SET status = ?, response_status = ?, response_body = ?, completed_at = NOW(3), locked_at = NULL
          WHERE idempotency_key = ? AND scope = ?`,
        [stored ? "completed" : "failed", status, stored ? JSON.stringify(body) : null, key, scope]
      ).catch((error) => logger.warn({ err: error, key }, "idempotency result not recorded"));
      return originalJson(body);
    };

    return next();
  };
}

export default idempotency;
