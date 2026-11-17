import crypto from "node:crypto";
import env from "../../config/env.js";
import { execute, query, queryOne } from "../../db/query.js";
import { CATEGORIES, CATEGORY_KEYS, isOptional } from "./catalog.js";

/**
 * Who may be emailed about what.
 *
 * A person's choice per category lives in `notification_preferences` (keyed by the catalogue
 * category). No row means the default: email on, sent straight away. Marketing categories
 * (product news) also need marketing consent; the newsletter has its own double opt-in list.
 *
 * Suppressions stop mail to an address: a hard bounce or complaint stops every optional email,
 * an unsubscribe stops one category. Security, account, billing and receipt emails are never
 * suppressed by an unsubscribe, and are tried even after a bounce so a person can always reset a
 * password once they fix their mailbox.
 */

export const normalizeEmail = (email) => String(email || "").trim().toLowerCase();

export async function preferencesFor(userId) {
  if (!userId) return {};
  // Before migration 0081 there is no email_frequency column; everything is then "instant".
  const rows = await query(
    "SELECT notification_type, email_enabled, email_frequency FROM notification_preferences WHERE user_id = ?",
    [userId]
  ).catch(() => query("SELECT notification_type, email_enabled, 'instant' AS email_frequency FROM notification_preferences WHERE user_id = ?", [userId]));
  const stored = Object.fromEntries(rows.map((row) => [row.notification_type, row]));
  const user = await queryOne("SELECT marketing_opt_in FROM users WHERE id = ?", [userId]);
  return Object.fromEntries(
    CATEGORY_KEYS.map((key) => {
      const row = stored[key];
      const category = CATEGORIES[key];
      const fallbackEnabled = category.marketing ? Boolean(user?.marketing_opt_in) : true;
      return [
        key,
        {
          email: category.optional ? (row ? Boolean(row.email_enabled) : fallbackEnabled) : true,
          frequency: row?.email_frequency === "daily" && category.digest ? "daily" : "instant",
        },
      ];
    })
  );
}

/** `changes` = { leads: { email: true, frequency: "daily" }, ... }; unknown or fixed categories are ignored. */
export async function savePreferences(userId, changes = {}) {
  for (const [key, change] of Object.entries(changes)) {
    if (!isOptional(key) || !change || typeof change !== "object") continue;
    const frequency = change.frequency === "daily" && CATEGORIES[key].digest ? "daily" : "instant";
    await execute(
      `INSERT INTO notification_preferences (user_id, notification_type, email_enabled, email_frequency, updated_at)
       VALUES (?, ?, ?, ?, NOW(3))
       ON DUPLICATE KEY UPDATE email_enabled = VALUES(email_enabled), email_frequency = VALUES(email_frequency), updated_at = NOW(3)`,
      [userId, key, change.email === false ? 0 : 1, frequency]
    );
    // Turning a category back on lifts an earlier one-click unsubscribe for it.
    if (change.email !== false) {
      const user = await queryOne("SELECT email FROM users WHERE id = ?", [userId]);
      if (user?.email) {
        await execute("DELETE FROM email_suppressions WHERE email = ? AND scope = ? AND reason = 'unsubscribe'", [normalizeEmail(user.email), key]);
      }
    }
  }
  return preferencesFor(userId);
}

/** Null when the address may be mailed for this category, otherwise the reason it may not. */
export async function suppressionFor(email, category) {
  if (!isOptional(category)) {
    const blocked = await queryOne("SELECT reason FROM email_suppressions WHERE email = ? AND scope = 'all' AND reason = 'manual' LIMIT 1", [normalizeEmail(email)]);
    return blocked ? "blocked by an administrator" : null;
  }
  const row = await queryOne(
    "SELECT reason, scope FROM email_suppressions WHERE email = ? AND scope IN ('all', ?) ORDER BY scope = 'all' DESC LIMIT 1",
    [normalizeEmail(email), category]
  );
  return row ? `${row.reason.replace(/_/g, " ")}${row.scope === "all" ? "" : ` (${row.scope})`}` : null;
}

export async function suppress(email, { scope = "all", reason, detail = null, userId = null }) {
  await execute(
    `INSERT INTO email_suppressions (email, scope, reason, detail, created_by_user_id, created_at)
     VALUES (?, ?, ?, ?, ?, NOW(3))
     ON DUPLICATE KEY UPDATE reason = VALUES(reason), detail = VALUES(detail), created_at = NOW(3)`,
    [normalizeEmail(email), scope, reason, detail ? String(detail).slice(0, 500) : null, userId]
  );
}

/* -------------------------------------------------------------------------- */
/* One-click unsubscribe links                                                 */
/* -------------------------------------------------------------------------- */

const sign = (payload) => crypto.createHmac("sha256", env.SESSION_SECRET).update(`email-unsubscribe:${payload}`).digest("base64url");

export function unsubscribeToken(email, category) {
  const payload = Buffer.from(JSON.stringify({ e: normalizeEmail(email), c: category })).toString("base64url");
  return `${payload}.${sign(payload)}`;
}

/** `{ email, category }` from a token, or null when it was altered. */
export function readUnsubscribeToken(token) {
  const [payload, signature] = String(token || "").split(".");
  if (!payload || !signature) return null;
  const expected = sign(payload);
  if (expected.length !== signature.length || !crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature))) return null;
  try {
    const { e, c } = JSON.parse(Buffer.from(payload, "base64url").toString("utf8"));
    if (!e || !CATEGORIES[c]) return null;
    return { email: e, category: c };
  } catch {
    return null;
  }
}

/** Applies an unsubscribe link: the person's preference if they have an account, and a suppression. */
export async function unsubscribe({ email, category }) {
  if (!isOptional(category)) return { email, category, status: "required" };
  await suppress(email, { scope: category, reason: "unsubscribe" });
  const user = await queryOne("SELECT id FROM users WHERE email_normalized = ? AND deleted_at IS NULL LIMIT 1", [normalizeEmail(email)]);
  if (user) {
    await execute(
      `INSERT INTO notification_preferences (user_id, notification_type, email_enabled, updated_at)
       VALUES (?, ?, 0, NOW(3)) ON DUPLICATE KEY UPDATE email_enabled = 0, updated_at = NOW(3)`,
      [user.id, category]
    );
  }
  if (category === "newsletter") {
    await execute(
      "UPDATE newsletter_subscribers SET status = 'unsubscribed', unsubscribed_at = NOW(3), updated_at = NOW(3) WHERE email = ? AND status <> 'unsubscribed'",
      [normalizeEmail(email)]
    );
  }
  if (category === "alerts" && user) {
    await execute("UPDATE saved_searches SET alerts_enabled = 0 WHERE user_id = ? AND deleted_at IS NULL", [user.id]);
  }
  return { email, category, status: "unsubscribed" };
}

/** Undo from the confirmation page ("I clicked by mistake"). */
export async function resubscribe({ email, category }) {
  await execute("DELETE FROM email_suppressions WHERE email = ? AND scope = ? AND reason = 'unsubscribe'", [normalizeEmail(email), category]);
  const user = await queryOne("SELECT id FROM users WHERE email_normalized = ? AND deleted_at IS NULL LIMIT 1", [normalizeEmail(email)]);
  if (user) {
    await execute(
      "UPDATE notification_preferences SET email_enabled = 1, updated_at = NOW(3) WHERE user_id = ? AND notification_type = ?",
      [user.id, category]
    );
  }
  if (category === "newsletter") {
    await execute(
      "UPDATE newsletter_subscribers SET status = 'subscribed', unsubscribed_at = NULL, updated_at = NOW(3) WHERE email = ? AND status = 'unsubscribed' AND confirmed_at IS NOT NULL",
      [normalizeEmail(email)]
    );
  }
  return { email, category, status: "subscribed" };
}
