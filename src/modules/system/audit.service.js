import net from "node:net";
import { execute } from "../../db/query.js";
import logger from "../../config/logger.js";

function ipToBinary(ip) {
  if (!ip) return null;
  const clean = String(ip).replace(/^::ffff:/, "");
  if (net.isIPv4(clean)) return Buffer.from(clean.split(".").map(Number));
  return null;
}

// Never persisted, whatever a caller passes in metadata.
const FORBIDDEN_KEYS = new Set([
  "password", "passwordhash", "password_hash", "currentpassword", "newpassword",
  "token", "sessiontoken", "refreshtoken", "authorization", "cookie", "secret",
  "secretkey", "apikey", "cardnumber", "cvc", "iban",
]);

export function scrub(value, depth = 0) {
  if (value === null || value === undefined || depth > 4) return value;
  if (Array.isArray(value)) return value.slice(0, 50).map((entry) => scrub(entry, depth + 1));
  if (typeof value !== "object") return value;
  const result = {};
  for (const [key, entry] of Object.entries(value)) {
    if (FORBIDDEN_KEYS.has(key.toLowerCase())) {
      result[key] = "[redacted]";
      continue;
    }
    result[key] = scrub(entry, depth + 1);
  }
  return result;
}

/**
 * Writes one row to the partitioned audit log.
 *
 * Auditing is never allowed to fail the operation it is describing — a broken
 * log line must not roll back a listing approval — so a failure here is logged
 * and swallowed. It *is* written inside the caller's transaction when one is
 * supplied, so a rolled-back change leaves no audit trail claiming it happened.
 */
export async function recordAudit(
  {
    action,
    subjectType,
    subjectId = null,
    subjectLabel = null,
    userId = null,
    actorType = "user",
    actorLabel = null,
    impersonatorUserId = null,
    changes = null,
    metadata = null,
    ip = null,
    userAgent = null,
    requestId = null,
    sessionId = null,
  },
  executor
) {
  try {
    await execute(
      `INSERT INTO audit_logs
         (occurred_at, actor_user_id, actor_type, actor_label, impersonator_user_id,
          action, subject_type, subject_id, subject_label, changes, metadata,
          ip_address, user_agent, request_id, session_id)
       VALUES (NOW(3), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        userId,
        userId ? actorType : "system",
        actorLabel,
        impersonatorUserId,
        String(action).slice(0, 80),
        String(subjectType || "system").slice(0, 60),
        subjectId ? Number(subjectId) : null,
        subjectLabel ? String(subjectLabel).slice(0, 255) : null,
        changes ? JSON.stringify(scrub(changes)) : null,
        metadata ? JSON.stringify(scrub(metadata)) : null,
        ipToBinary(ip),
        userAgent ? String(userAgent).slice(0, 500) : null,
        requestId ? String(requestId).replace(/-/g, "").slice(0, 26).toUpperCase() : null,
        sessionId ? Number(sessionId) : null,
      ],
      executor
    );
  } catch (error) {
    logger.error({ err: error, action }, "audit write failed");
  }
}

/** Convenience wrapper that pulls actor and trace details off the request. */
export function auditFromRequest(req, payload, executor) {
  return recordAudit(
    {
      ...payload,
      userId: payload.userId ?? req.auth?.user?.id ?? null,
      actorLabel: payload.actorLabel ?? req.auth?.user?.email ?? null,
      impersonatorUserId: req.auth?.impersonatedByUserId ?? null,
      ip: payload.ip ?? req.ip,
      userAgent: payload.userAgent ?? req.get("user-agent"),
      requestId: payload.requestId ?? req.id,
      sessionId: payload.sessionId ?? req.auth?.sessionId ?? null,
    },
    executor
  );
}
