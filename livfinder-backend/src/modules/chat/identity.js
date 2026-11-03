import crypto from "node:crypto";
import env from "../../config/env.js";
import { execute, queryOne } from "../../db/query.js";
import { randomToken, sha256Hex as sha256 } from "../../utils/ids.js";
import { AppError } from "../../utils/errors.js";
import { hasPlatformPermission } from "../auth/rbac.js";

/**
 * Who is chatting.
 *
 * A signed-in person is their user. A visitor without an account is a chat guest: a row in
 * chat_guests, recognised by a random token in an httpOnly cookie. Only the token's hash is
 * stored, the same rule as user_sessions, so a database leak cannot be replayed as a guest.
 *
 * An identity is a plain object the service and the socket layer both use:
 *   { type: "user",  userId, publicId, name, avatar, memberships, platform }
 *   { type: "guest", guestId, publicId, name, email, phone }
 * and `ref` ("u:<publicId>" / "g:<publicId>") names it on the wire and in socket rooms.
 */

export const GUEST_COOKIE = "livfinder_chat_guest";
const GUEST_TTL_MS = 90 * 24 * 60 * 60 * 1000;
const RESUME_TTL_MS = 30 * 24 * 60 * 60 * 1000;

export const refFor = (identity) => (identity.type === "user" ? `u:${identity.publicId}` : `g:${identity.publicId}`);

export function guestCookieOptions() {
  return {
    httpOnly: true,
    secure: env.isProduction,
    sameSite: env.COOKIE_SAMESITE,
    domain: env.COOKIE_DOMAIN,
    path: "/",
    maxAge: GUEST_TTL_MS,
  };
}

export function identityFromAuth(auth) {
  if (!auth?.user) return null;
  return {
    type: "user",
    userId: auth.user.id,
    publicId: auth.user.publicId,
    name: auth.user.displayName || [auth.user.firstName, auth.user.lastName].filter(Boolean).join(" ") || auth.user.email,
    email: auth.user.email,
    avatar: auth.user.avatarUrl || null,
    memberships: auth.memberships || [],
    platform: auth.platform || null,
  };
}

export async function guestFromToken(token) {
  if (!token) return null;
  const row = await queryOne(
    "SELECT id, public_id, name, email, phone, claimed_by_user_id FROM chat_guests WHERE token_hash = ? LIMIT 1",
    [sha256(String(token))]
  );
  if (!row) return null;
  return { type: "guest", guestId: row.id, publicId: row.public_id, name: row.name, email: row.email, phone: row.phone };
}

/** The signed-in user if there is one, otherwise the guest the cookie names. */
export async function identityFromRequest(req) {
  const user = identityFromAuth(req.auth);
  if (user) return user;
  return guestFromToken(req.cookies?.[GUEST_COOKIE]);
}

export async function requireIdentity(req) {
  const identity = await identityFromRequest(req);
  if (!identity) throw AppError.unauthorized("Start a chat first.");
  return identity;
}

/* ---------------------------------------------------------------------------------------------
 * Resume links: an emailed link that signs a guest back in on any device.
 *
 * Stateless (HMAC over the guest id and an expiry), so a reply email needs no table write. Using
 * one rotates the cookie token, which signs out the guest's other devices: whoever holds the
 * mailbox holds the chat, and a forwarded old cookie stops working.
 * ------------------------------------------------------------------------------------------- */

function resumeKey() {
  return crypto.createHash("sha256").update(`livfinder.chat.resume:${env.SESSION_SECRET}`).digest();
}

export function resumeToken(guestPublicId, now = Date.now()) {
  const expires = Math.floor((now + RESUME_TTL_MS) / 1000);
  const payload = `${guestPublicId}.${expires}`;
  const signature = crypto.createHmac("sha256", resumeKey()).update(payload).digest("base64url");
  return `${payload}.${signature}`;
}

export function verifyResumeToken(token, now = Date.now()) {
  const [publicId, expires, signature] = String(token || "").split(".");
  if (!publicId || !expires || !signature) return null;
  const expected = crypto.createHmac("sha256", resumeKey()).update(`${publicId}.${expires}`).digest();
  const given = Buffer.from(signature, "base64url");
  if (given.length !== expected.length || !crypto.timingSafeEqual(given, expected)) return null;
  if (Number(expires) * 1000 < now) return null;
  return publicId;
}

export async function resumeGuest(token, res) {
  const publicId = verifyResumeToken(token);
  if (!publicId) throw AppError.forbidden("That chat link has expired. Start a new chat from the website.");
  const guest = await queryOne("SELECT id, public_id, name, email, phone FROM chat_guests WHERE public_id = ?", [publicId]);
  if (!guest) throw AppError.notFound("That chat is no longer available.");
  const fresh = randomToken(32);
  // Opening the emailed link proves the address.
  await execute(
    "UPDATE chat_guests SET token_hash = ?, email_verified_at = COALESCE(email_verified_at, NOW(3)), last_seen_at = NOW(3) WHERE id = ?",
    [sha256(fresh), guest.id]
  );
  res.cookie(GUEST_COOKIE, fresh, guestCookieOptions());
  return { type: "guest", guestId: guest.id, publicId: guest.public_id, name: guest.name, email: guest.email, phone: guest.phone };
}

/* ---------------------------------------------------------------------------------------------
 * Staff
 * ------------------------------------------------------------------------------------------- */

export const canViewSupport = (identity) =>
  identity?.type === "user" && hasPlatformPermission(identity.platform, "supportChat.view");
export const canReplySupport = (identity) =>
  identity?.type === "user" && hasPlatformPermission(identity.platform, "supportChat.reply");

/** Accounts whose enquiry inbox this user works: owners, admins and lead managers. */
export function teamAccountIds(identity) {
  if (identity?.type !== "user") return [];
  return identity.memberships
    .filter(
      (membership) =>
        (membership.membership_status ?? "active") === "active" &&
        (membership.role === "owner" || membership.role === "admin" || Number(membership.can_manage_leads) === 1)
    )
    .map((membership) => membership.account_id);
}
