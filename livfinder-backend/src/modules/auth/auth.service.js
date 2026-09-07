import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { query, queryOne, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ulid, randomToken, sha256 } from "../../utils/ids.js";
import { hashPassword, verifyPassword, passwordPolicyError } from "./passwords.js";
import { createSession, revokeSession, revokeAllSessions } from "./sessions.js";
import { recordAudit } from "../system/audit.service.js";
import { sendMail } from "../system/mail.service.js";

const TOKEN_TTL = {
  password_reset: 60 * 60 * 1000,
  email_verification: 24 * 60 * 60 * 1000,
};

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

async function findUserByEmail(email) {
  return queryOne(
    `SELECT id, public_id, email, email_normalized, email_verified_at, password_hash, session_epoch,
            status, display_name, first_name, last_name, avatar_url, default_account_id,
            failed_login_count, locked_until, deleted_at
       FROM users WHERE email_normalized = ? LIMIT 1`,
    [normalizeEmail(email)]
  );
}

/**
 * Sign-in.
 *
 * The failure message is identical for "no such user", "wrong password" and
 * "not active", so the endpoint does not confirm which addresses are
 * registered. The rate limiter is keyed on IP+email upstream.
 */
export async function login({ email, password, ip, userAgent }) {
  const genericFailure = AppError.unauthorized("Email or password is incorrect.");
  const user = await findUserByEmail(email);

  if (!user || user.deleted_at) {
    // Still spend the time a verify would take, so a missing account is not
    // detectable by response timing.
    await verifyPassword("$argon2id$v=19$m=19456,t=2,p=1$c29tZXNhbHR2YWx1ZQ$0000000000000000000000000000000000000000000", password);
    throw genericFailure;
  }

  if (user.locked_until && new Date(user.locked_until) > new Date()) {
    throw AppError.tooManyRequests("Too many failed attempts. Try again later.");
  }

  const { valid, needsRehash } = await verifyPassword(user.password_hash, password);
  if (!valid) {
    await execute(
      `UPDATE users
          SET failed_login_count = failed_login_count + 1,
              locked_until = IF(failed_login_count + 1 >= 10, DATE_ADD(NOW(3), INTERVAL 15 MINUTE), locked_until)
        WHERE id = ?`,
      [user.id]
    );
    await recordAudit({
      action: "auth.login_failed",
      subjectType: "user",
      subjectId: user.id,
      userId: user.id,
      metadata: { reason: "bad_password" },
      ip,
    });
    throw genericFailure;
  }

  if (user.status !== "active") {
    if (user.status === "pending_verification") {
      throw new AppError("Verify your email address before signing in.", {
        status: 403,
        code: "EMAIL_NOT_VERIFIED",
      });
    }
    throw genericFailure;
  }

  return withTransaction(async (connection) => {
    if (needsRehash) {
      // Migrate the stored hash to Argon2id now that the plaintext is in hand.
      const upgraded = await hashPassword(password);
      await execute(
        "UPDATE users SET password_hash = ?, password_updated_at = NOW(3) WHERE id = ?",
        [upgraded, user.id],
        connection
      );
    }
    await execute(
      `UPDATE users
          SET failed_login_count = 0, locked_until = NULL,
              last_login_at = NOW(3), last_seen_at = NOW(3), login_count = login_count + 1
        WHERE id = ?`,
      [user.id],
      connection
    );

    const session = await createSession(
      {
        userId: user.id,
        sessionEpoch: user.session_epoch,
        activeAccountId: user.default_account_id,
        ip,
        userAgent,
      },
      connection
    );

    await recordAudit(
      { action: "auth.login", subjectType: "user", subjectId: user.id, userId: user.id, ip },
      connection
    );

    return { user, session };
  });
}

export async function logout({ sessionId, userId, everywhere = false, ip }) {
  if (everywhere) {
    await withTransaction(async (connection) => {
      await revokeAllSessions(userId, connection);
      await recordAudit(
        { action: "auth.logout_all", subjectType: "user", subjectId: userId, userId, ip },
        connection
      );
    });
    return;
  }
  await revokeSession(sessionId);
  await recordAudit({ action: "auth.logout", subjectType: "user", subjectId: userId, userId, ip });
}

async function issueToken({ userId, purpose, target, ip }, executor) {
  const token = randomToken(32);
  const ttl = TOKEN_TTL[purpose] ?? 60 * 60 * 1000;
  // One live token per purpose: issuing a new reset link invalidates the old.
  await execute(
    `UPDATE user_tokens SET consumed_at = NOW(3)
      WHERE user_id = ? AND purpose = ? AND consumed_at IS NULL`,
    [userId, purpose],
    executor
  );
  await execute(
    `INSERT INTO user_tokens (user_id, purpose, token_hash, target, attempts, created_at, expires_at)
     VALUES (?, ?, ?, ?, 0, NOW(3), DATE_ADD(NOW(3), INTERVAL ? SECOND))`,
    [userId, purpose, sha256(token), target || null, Math.floor(ttl / 1000)],
    executor
  );
  return token;
}

async function consumeToken({ token, purpose }, executor) {
  const row = await queryOne(
    `SELECT id, user_id, target, attempts FROM user_tokens
      WHERE token_hash = ? AND purpose = ? AND consumed_at IS NULL AND expires_at > NOW(3)
      LIMIT 1`,
    [sha256(token), purpose],
    executor
  );
  if (!row) return null;
  await execute("UPDATE user_tokens SET consumed_at = NOW(3) WHERE id = ?", [row.id], executor);
  return row;
}

/**
 * Always reports success. Whether an address is registered is not something an
 * unauthenticated caller gets to learn.
 */
export async function requestPasswordReset({ email, ip }) {
  const user = await findUserByEmail(email);
  if (!user || user.deleted_at || user.status === "banned") return { sent: true };

  const token = await issueToken({ userId: user.id, purpose: "password_reset", target: user.email, ip });
  const resetUrl = `${env.FRONTEND_URL}/reset-password?token=${encodeURIComponent(token)}`;
  await sendMail({
    to: user.email,
    subject: "Reset your LivFinder password",
    text: `Use this link within the hour to choose a new password:\n\n${resetUrl}\n\nIf you did not ask for this, nothing has changed and you can ignore this message.`,
  });
  await recordAudit({ action: "auth.password_reset_requested", subjectType: "user", subjectId: user.id, userId: user.id, ip });
  return { sent: true };
}

export async function resetPassword({ token, password, ip }) {
  const policyError = passwordPolicyError(password);
  if (policyError) throw AppError.validation("Some information is invalid.", { password: policyError });

  return withTransaction(async (connection) => {
    const row = await consumeToken({ token, purpose: "password_reset" }, connection);
    if (!row) throw AppError.badRequest("That reset link is no longer valid. Request a new one.");

    const hash = await hashPassword(password);
    await execute(
      "UPDATE users SET password_hash = ?, password_updated_at = NOW(3), failed_login_count = 0, locked_until = NULL WHERE id = ?",
      [hash, row.user_id],
      connection
    );
    // A password change ends every existing session.
    await revokeAllSessions(row.user_id, connection);
    await recordAudit(
      { action: "auth.password_reset", subjectType: "user", subjectId: row.user_id, userId: row.user_id, ip },
      connection
    );
    return { userId: row.user_id };
  });
}

export async function changePassword({ userId, currentPassword, newPassword, ip, keepSessionId }) {
  const user = await queryOne("SELECT id, email, password_hash FROM users WHERE id = ?", [userId]);
  if (!user) throw AppError.notFound();

  const { valid } = await verifyPassword(user.password_hash, currentPassword);
  if (!valid) throw AppError.validation("Some information is invalid.", { currentPassword: "That password is not correct." });

  const policyError = passwordPolicyError(newPassword, { email: user.email });
  if (policyError) throw AppError.validation("Some information is invalid.", { newPassword: policyError });

  await withTransaction(async (connection) => {
    const hash = await hashPassword(newPassword);
    await execute(
      "UPDATE users SET password_hash = ?, password_updated_at = NOW(3) WHERE id = ?",
      [hash, userId],
      connection
    );
    await revokeAllSessions(userId, connection);
    await recordAudit({ action: "auth.password_changed", subjectType: "user", subjectId: userId, userId, ip }, connection);
  });

  // The caller stays signed in on this device; every other session is gone.
  const user2 = await queryOne("SELECT session_epoch, default_account_id FROM users WHERE id = ?", [userId]);
  return createSession({
    userId,
    sessionEpoch: user2.session_epoch,
    activeAccountId: user2.default_account_id,
    ip,
    userAgent: keepSessionId,
  });
}

export async function sendEmailVerification({ userId, ip }) {
  const user = await queryOne("SELECT id, email, email_verified_at FROM users WHERE id = ?", [userId]);
  if (!user) throw AppError.notFound();
  if (user.email_verified_at) return { alreadyVerified: true };

  const token = await issueToken({ userId, purpose: "email_verification", target: user.email, ip });
  const verifyUrl = `${env.FRONTEND_URL}/verify-email?token=${encodeURIComponent(token)}`;
  await sendMail({
    to: user.email,
    subject: "Confirm your LivFinder email address",
    text: `Confirm your address to finish setting up your account:\n\n${verifyUrl}`,
  });
  return { sent: true };
}

export async function verifyEmail({ token, ip }) {
  return withTransaction(async (connection) => {
    const row = await consumeToken({ token, purpose: "email_verification" }, connection);
    if (!row) throw AppError.badRequest("That confirmation link is no longer valid.");
    await execute(
      `UPDATE users
          SET email_verified_at = NOW(3),
              status = IF(status = 'pending_verification', 'active', status)
        WHERE id = ?`,
      [row.user_id],
      connection
    );
    await recordAudit(
      { action: "auth.email_verified", subjectType: "user", subjectId: row.user_id, userId: row.user_id, ip },
      connection
    );
    return { userId: row.user_id };
  });
}

/**
 * OAuth.
 *
 * The provider table (`user_identities`) and the callback exchange are
 * implemented; the client id/secret for each provider are deployment
 * configuration. With none configured the endpoints report the provider as
 * unavailable rather than pretending to redirect.
 */
export function configuredOAuthProviders() {
  const providers = [];
  for (const provider of ["google", "apple", "facebook", "linkedin"]) {
    const clientId = process.env[`OAUTH_${provider.toUpperCase()}_CLIENT_ID`];
    const clientSecret = process.env[`OAUTH_${provider.toUpperCase()}_CLIENT_SECRET`];
    if (clientId && clientSecret) {
      providers.push({
        provider,
        clientId,
        clientSecret,
        authorizeUrl: process.env[`OAUTH_${provider.toUpperCase()}_AUTHORIZE_URL`],
        tokenUrl: process.env[`OAUTH_${provider.toUpperCase()}_TOKEN_URL`],
        userInfoUrl: process.env[`OAUTH_${provider.toUpperCase()}_USERINFO_URL`],
        scope: process.env[`OAUTH_${provider.toUpperCase()}_SCOPE`] || "openid email profile",
      });
    }
  }
  return providers;
}

/** Links or creates a user from a verified provider identity. */
export async function upsertOAuthIdentity({ provider, subject, email, displayName, avatarUrl, ip, userAgent }) {
  return withTransaction(async (connection) => {
    const existing = await queryOne(
      "SELECT user_id FROM user_identities WHERE provider = ? AND provider_uid = ? LIMIT 1",
      [provider, subject],
      connection
    );

    let userId = existing?.user_id;
    if (!userId) {
      const byEmail = email ? await findUserByEmail(email) : null;
      if (byEmail) {
        userId = byEmail.id;
      } else {
        const result = await execute(
          `INSERT INTO users (public_id, email, email_normalized, email_verified_at, password_hash,
                              status, first_name, last_name, display_name, avatar_url, created_at)
           VALUES (?, ?, ?, NOW(3), ?, 'active', ?, ?, ?, ?, NOW(3))`,
          [
            ulid(),
            email,
            normalizeEmail(email),
            // No local password: this account signs in through the provider.
            await hashPassword(randomToken(32)),
            (displayName || "").split(" ")[0] || "Member",
            (displayName || "").split(" ").slice(1).join(" ") || "",
            displayName || email,
            avatarUrl || null,
          ],
          connection
        );
        userId = result.insertId;
      }
      await execute(
        `INSERT INTO user_identities (user_id, provider, provider_uid, email, raw_profile, created_at, last_used_at)
         VALUES (?, ?, ?, ?, CAST(? AS JSON), NOW(3), NOW(3))`,
        [userId, provider, subject, email || null, JSON.stringify({ displayName, avatarUrl })],
        connection
      );
    }

    const user = await queryOne("SELECT session_epoch, default_account_id FROM users WHERE id = ?", [userId], connection);
    const session = await createSession(
      { userId, sessionEpoch: user.session_epoch, activeAccountId: user.default_account_id, ip, userAgent },
      connection
    );
    await recordAudit({ action: "auth.oauth_login", subjectType: "user", subjectId: userId, userId, metadata: { provider }, ip }, connection);
    return { userId, session };
  });
}

export { findUserByEmail, normalizeEmail, issueToken, consumeToken };
