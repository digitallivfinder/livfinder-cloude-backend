import crypto from "node:crypto";
import { execute, query, queryOne } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { encryptSecret, decryptSecret } from "../../utils/secrets.js";
import { AppError } from "../../utils/errors.js";
import { hashPassword, verifyPassword } from "./passwords.js";

/**
 * Time-based one-time passwords, and step-up.
 *
 * SEC-IAM-002 makes MFA mandatory for workforce, privileged and seller-administrator accounts,
 * and SEC-IAM-011 requires re-authentication before nine high-risk actions. Neither existed:
 * `user_mfa_factors` was an empty table and `users.mfa_enabled` was surfaced read-only, so it
 * could be displayed but never become true.
 *
 * TOTP is implemented here rather than pulled in, for two reasons. RFC 6238 is HMAC over a
 * counter — about thirty lines against Node's own crypto — and the alternative is a dependency
 * holding the one secret in the system that must never leak. Nothing exotic is used: SHA-1,
 * 6 digits, a 30-second step, which is what every authenticator app expects.
 *
 * Secrets are encrypted at rest with the same AES-256-GCM helper as payment credentials, and
 * the plaintext is returned exactly once — during enrolment, so the user can scan it.
 */

const DIGITS = 6;
const STEP_SECONDS = 30;
/** One step either side, for clock drift. Wider would meaningfully extend a stolen code's life. */
const WINDOW = 1;
const RECOVERY_CODE_COUNT = 10;

/* -------------------------------------------------------------------------- */
/* Base32, because that is what authenticator apps read                        */
/* -------------------------------------------------------------------------- */

const ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";

export function base32Encode(buffer) {
  let bits = 0;
  let value = 0;
  let output = "";
  for (const byte of buffer) {
    value = (value << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      output += ALPHABET[(value >>> (bits - 5)) & 31];
      bits -= 5;
    }
  }
  if (bits > 0) output += ALPHABET[(value << (5 - bits)) & 31];
  return output;
}

export function base32Decode(input) {
  let bits = 0;
  let value = 0;
  const output = [];
  for (const char of String(input).toUpperCase().replace(/=+$/, "").replace(/\s/g, "")) {
    const index = ALPHABET.indexOf(char);
    if (index === -1) throw AppError.badRequest("That secret is not valid.");
    value = (value << 5) | index;
    bits += 5;
    if (bits >= 8) {
      output.push((value >>> (bits - 8)) & 255);
      bits -= 8;
    }
  }
  return Buffer.from(output);
}

/* -------------------------------------------------------------------------- */
/* RFC 6238                                                                    */
/* -------------------------------------------------------------------------- */

export function totpCode(secretBase32, counter) {
  const key = base32Decode(secretBase32);
  const buffer = Buffer.alloc(8);
  buffer.writeBigUInt64BE(BigInt(counter));
  const digest = crypto.createHmac("sha1", key).update(buffer).digest();
  // Dynamic truncation, RFC 4226 §5.4.
  const offset = digest[digest.length - 1] & 0x0f;
  const binary =
    ((digest[offset] & 0x7f) << 24) |
    ((digest[offset + 1] & 0xff) << 16) |
    ((digest[offset + 2] & 0xff) << 8) |
    (digest[offset + 3] & 0xff);
  return String(binary % 10 ** DIGITS).padStart(DIGITS, "0");
}

/**
 * Verifies a code across the accepted window.
 *
 * Compared with `timingSafeEqual`. A one-in-a-million code that leaks through a timing side
 * channel is still a code.
 */
export function verifyTotp(secretBase32, submitted, at = Date.now()) {
  const candidate = String(submitted ?? "").replace(/\s/g, "");
  if (!/^\d{6}$/.test(candidate)) return false;
  const counter = Math.floor(at / 1000 / STEP_SECONDS);
  for (let drift = -WINDOW; drift <= WINDOW; drift += 1) {
    const expected = totpCode(secretBase32, counter + drift);
    if (crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(candidate))) return true;
  }
  return false;
}

/* -------------------------------------------------------------------------- */
/* Enrolment                                                                   */
/* -------------------------------------------------------------------------- */

/**
 * Starts enrolment: generates a secret, stores it unconfirmed, and returns the provisioning URI.
 *
 * The factor is deliberately created in an unconfirmed state. A user who scans a QR code and
 * then closes the tab must not end up locked out by a factor they never proved they can use —
 * `mfa_enabled` only becomes true once a code from that secret verifies.
 */
export async function beginTotpEnrolment({ userId, label = "LivFinder" }) {
  const user = await queryOne("SELECT id, email, mfa_enabled FROM users WHERE id = ? AND deleted_at IS NULL", [userId]);
  if (!user) throw AppError.notFound("That user was not found.");

  const secret = base32Encode(crypto.randomBytes(20));

  await withTransaction(async (connection) => {
    // Only one pending TOTP enrolment at a time; restarting replaces it.
    await execute(
      "DELETE FROM user_mfa_factors WHERE user_id = ? AND factor_type = 'totp' AND confirmed_at IS NULL",
      [userId],
      connection
    );
    await execute(
      `INSERT INTO user_mfa_factors (user_id, factor_type, secret_encrypted, label, is_primary, created_at)
       VALUES (?, 'totp', ?, ?, 0, NOW(3))`,
      [userId, encryptSecret(secret), String(label).slice(0, 120)],
      connection
    );
  });

  const issuer = encodeURIComponent("LivFinder");
  const account = encodeURIComponent(user.email);
  return {
    secret,
    // Scanned by the authenticator app. The secret appears here and nowhere else afterwards.
    otpauthUrl: `otpauth://totp/${issuer}:${account}?secret=${secret}&issuer=${issuer}&digits=${DIGITS}&period=${STEP_SECONDS}`,
    digits: DIGITS,
    period: STEP_SECONDS,
  };
}

/**
 * Confirms enrolment with a code from the app, turns MFA on, and issues recovery codes.
 *
 * Recovery codes are hashed exactly like passwords and shown once. A user who loses their phone
 * without them needs an administrator, which is the correct amount of friction.
 */
export async function confirmTotpEnrolment({ userId, code }) {
  const factor = await queryOne(
    `SELECT id, secret_encrypted FROM user_mfa_factors
      WHERE user_id = ? AND factor_type = 'totp' AND confirmed_at IS NULL
      ORDER BY created_at DESC LIMIT 1`,
    [userId]
  );
  if (!factor) throw AppError.badRequest("Start setting up authentication first.");

  const secret = decryptSecret(factor.secret_encrypted?.toString?.("utf8") ?? factor.secret_encrypted);
  if (!secret) throw AppError.internal();
  if (!verifyTotp(secret, code)) throw AppError.badRequest("That code is not correct. Check your authenticator app.");

  const recoveryCodes = Array.from({ length: RECOVERY_CODE_COUNT }, () =>
    crypto.randomBytes(5).toString("hex").toUpperCase().match(/.{1,5}/g).join("-")
  );

  await withTransaction(async (connection) => {
    await execute(
      "UPDATE user_mfa_factors SET confirmed_at = NOW(3), is_primary = 1 WHERE id = ?",
      [factor.id],
      connection
    );
    await execute("UPDATE users SET mfa_enabled = 1 WHERE id = ?", [userId], connection);
    await execute(
      "DELETE FROM user_mfa_factors WHERE user_id = ? AND factor_type = 'recovery_code'",
      [userId],
      connection
    );
    for (const recovery of recoveryCodes) {
      // Hashed, not encrypted: a recovery code is a credential to be checked, never read back.
      // eslint-disable-next-line no-await-in-loop
      const hashed = await hashPassword(recovery);
      // eslint-disable-next-line no-await-in-loop
      await execute(
        `INSERT INTO user_mfa_factors (user_id, factor_type, secret_encrypted, label, is_primary, confirmed_at, created_at)
         VALUES (?, 'recovery_code', ?, 'Recovery code', 0, NOW(3), NOW(3))`,
        [userId, hashed],
        connection
      );
    }
  });

  // Returned once. There is no endpoint that will show them again.
  return { enabled: true, recoveryCodes };
}

/** Turns MFA off. Requires a current code, so a hijacked session cannot quietly disable it. */
export async function disableMfa({ userId, code }) {
  const enabled = await isMfaEnabled(userId);
  if (!enabled) return { enabled: false };
  const ok = await verifyMfaCode({ userId, code });
  if (!ok) throw AppError.badRequest("That code is not correct.");

  await withTransaction(async (connection) => {
    await execute("DELETE FROM user_mfa_factors WHERE user_id = ?", [userId], connection);
    await execute("UPDATE users SET mfa_enabled = 0 WHERE id = ?", [userId], connection);
  });
  return { enabled: false };
}

export async function isMfaEnabled(userId) {
  const row = await queryOne("SELECT mfa_enabled FROM users WHERE id = ?", [userId]);
  return Boolean(row?.mfa_enabled);
}

/**
 * Verifies a submitted code against the user's TOTP factor, then their recovery codes.
 *
 * A recovery code is consumed on use — that is what makes it single-use, and it is why this
 * cannot be a pure function.
 */
export async function verifyMfaCode({ userId, code }) {
  if (!code) return false;

  const totp = await queryOne(
    `SELECT id, secret_encrypted FROM user_mfa_factors
      WHERE user_id = ? AND factor_type = 'totp' AND confirmed_at IS NOT NULL LIMIT 1`,
    [userId]
  );
  if (totp) {
    const secret = decryptSecret(totp.secret_encrypted?.toString?.("utf8") ?? totp.secret_encrypted);
    if (secret && verifyTotp(secret, code)) {
      await execute("UPDATE user_mfa_factors SET last_used_at = NOW(3) WHERE id = ?", [totp.id]);
      return true;
    }
  }

  const recovery = await query(
    `SELECT id, secret_encrypted FROM user_mfa_factors
      WHERE user_id = ? AND factor_type = 'recovery_code' AND confirmed_at IS NOT NULL`,
    [userId]
  );
  for (const candidate of recovery) {
    const hash = candidate.secret_encrypted?.toString?.("utf8") ?? candidate.secret_encrypted;
    // `verifyPassword` returns `{ valid, needsRehash }`, not a boolean. Treating the object as
    // truthy would make every recovery code match — including a wrong one.
    // eslint-disable-next-line no-await-in-loop
    const result = await verifyPassword(hash, String(code).trim().toUpperCase());
    if (result?.valid) {
      await execute("DELETE FROM user_mfa_factors WHERE id = ?", [candidate.id]);
      return true;
    }
  }
  return false;
}

/** How many recovery codes remain, so the UI can prompt before the user runs out. */
export async function mfaStatus(userId) {
  const [enabled, remaining] = await Promise.all([
    isMfaEnabled(userId),
    queryOne(
      `SELECT COUNT(*) AS total FROM user_mfa_factors
        WHERE user_id = ? AND factor_type = 'recovery_code' AND confirmed_at IS NOT NULL`,
      [userId]
    ),
  ]);
  return { enabled, recoveryCodesRemaining: Number(remaining?.total ?? 0) };
}
