import net from "node:net";
import env from "../../config/env.js";
import { query, queryOne, execute } from "../../db/query.js";
import { ulid, randomToken, sha256 } from "../../utils/ids.js";

const SESSION_TTL_MS = () => env.SESSION_TTL_DAYS * 24 * 60 * 60 * 1000;

function ipToBinary(ip) {
  if (!ip) return null;
  const clean = ip.replace(/^::ffff:/, "");
  if (net.isIPv4(clean)) {
    return Buffer.from(clean.split(".").map((part) => Number(part)));
  }
  if (net.isIPv6(clean)) {
    const parts = clean.split("::");
    const head = parts[0] ? parts[0].split(":") : [];
    const tail = parts[1] !== undefined ? (parts[1] ? parts[1].split(":") : []) : [];
    const fill = new Array(8 - head.length - tail.length).fill("0");
    const groups = parts.length > 1 ? [...head, ...fill, ...tail] : head;
    if (groups.length !== 8) return null;
    const buffer = Buffer.alloc(16);
    groups.forEach((group, index) => buffer.writeUInt16BE(parseInt(group || "0", 16), index * 2));
    return buffer;
  }
  return null;
}

function deviceTypeFrom(userAgent = "") {
  const ua = userAgent.toLowerCase();
  if (/bot|crawler|spider/.test(ua)) return "bot";
  if (/ipad|tablet/.test(ua)) return "tablet";
  if (/mobi|android|iphone/.test(ua)) return "mobile";
  if (ua) return "desktop";
  return "other";
}

/**
 * Creates a server-side session row and returns the opaque token that goes in
 * the cookie. Only the SHA-256 of the token is stored, so a database read does
 * not yield a usable credential.
 */
export async function createSession(
  { userId, sessionEpoch, activeAccountId = null, ip, userAgent, impersonatedByUserId = null },
  executor
) {
  const token = randomToken(32);
  const expiresAt = new Date(Date.now() + SESSION_TTL_MS());
  await execute(
    `INSERT INTO user_sessions
       (public_id, user_id, token_hash, session_epoch, active_account_id, ip_address,
        user_agent, device_type, impersonated_by_user_id, created_at, last_used_at, expires_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(3), NOW(3), ?)`,
    [
      ulid(),
      userId,
      sha256(token),
      sessionEpoch,
      activeAccountId,
      ipToBinary(ip),
      (userAgent || "").slice(0, 500) || null,
      deviceTypeFrom(userAgent),
      impersonatedByUserId,
      expiresAt,
    ],
    executor
  );
  return { token, expiresAt };
}

/**
 * Resolves a cookie token to the live session and its user.
 *
 * The session_epoch comparison is what makes "sign out everywhere" a single
 * UPDATE on users: every session issued before the bump is dead without its row
 * being touched.
 */
export async function resolveSession(token) {
  if (!token) return null;
  const row = await queryOne(
    `SELECT s.id            AS session_id,
            s.public_id     AS session_public_id,
            s.user_id,
            s.active_account_id,
            s.session_epoch AS session_epoch,
            s.expires_at,
            s.impersonated_by_user_id,
            u.public_id     AS user_public_id,
            u.email,
            u.status        AS user_status,
            u.session_epoch AS user_epoch,
            u.display_name,
            u.first_name,
            u.last_name,
            u.avatar_url,
            u.email_verified_at,
            u.default_account_id,
            u.locked_until,
            u.deleted_at
       FROM user_sessions s
       JOIN users u ON u.id = s.user_id
      WHERE s.token_hash = ?
        AND s.revoked_at IS NULL
        AND s.expires_at > NOW(3)
      LIMIT 1`,
    [sha256(token)]
  );
  if (!row) return null;
  if (row.deleted_at) return null;
  if (row.session_epoch !== row.user_epoch) return null;
  if (row.user_status !== "active") return null;
  return row;
}

export async function touchSession(sessionId) {
  await execute("UPDATE user_sessions SET last_used_at = NOW(3) WHERE id = ?", [sessionId]);
}

export async function revokeSession(sessionId, executor) {
  await execute(
    "UPDATE user_sessions SET revoked_at = NOW(3) WHERE id = ? AND revoked_at IS NULL",
    [sessionId],
    executor
  );
}

/** Sign out everywhere: bump the epoch and mark the live rows revoked. */
export async function revokeAllSessions(userId, executor) {
  await execute("UPDATE users SET session_epoch = session_epoch + 1 WHERE id = ?", [userId], executor);
  await execute(
    "UPDATE user_sessions SET revoked_at = NOW(3) WHERE user_id = ? AND revoked_at IS NULL",
    [userId],
    executor
  );
}

export async function setActiveAccount(sessionId, accountId) {
  await execute("UPDATE user_sessions SET active_account_id = ? WHERE id = ?", [accountId, sessionId]);
}

export async function listUserSessions(userId) {
  return query(
    `SELECT public_id, device_type, user_agent, created_at, last_used_at, expires_at, revoked_at
       FROM user_sessions
      WHERE user_id = ?
      ORDER BY last_used_at DESC
      LIMIT 50`,
    [userId]
  );
}

/**
 * Revokes one of the caller's own sessions.
 *
 * Scoped to `user_id` in the statement rather than checked beforehand: a caller who guesses
 * another user's session id changes nothing, and the endpoint cannot be turned into an oracle
 * for whether that id exists.
 *
 * The current session is refused rather than revoked. Signing yourself out from the device list
 * is confusing — there is a Sign out button for that — and it would leave the page holding a
 * cookie the server no longer honours.
 */
export async function revokeUserSession({ userId, sessionPublicId, currentSessionId }) {
  const session = await queryOne(
    "SELECT id, public_id, revoked_at FROM user_sessions WHERE public_id = ? AND user_id = ? LIMIT 1",
    [sessionPublicId, userId]
  );
  if (!session) return { found: false };
  if (String(session.id) === String(currentSessionId)) return { found: true, current: true, revoked: false };
  if (session.revoked_at) return { found: true, current: false, revoked: false, alreadyRevoked: true };

  await execute("UPDATE user_sessions SET revoked_at = NOW(3) WHERE id = ?", [session.id]);
  return { found: true, current: false, revoked: true };
}

export const sessionCookieOptions = (maxAgeMs) => ({
  httpOnly: true,
  secure: env.isProduction,
  sameSite: env.COOKIE_SAMESITE,
  domain: env.COOKIE_DOMAIN,
  path: "/",
  maxAge: maxAgeMs,
});
