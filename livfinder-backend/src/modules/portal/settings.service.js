import { z } from "zod";
import net from "node:net";
import { query, queryOne, queryValue, execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { isoDate, bool, int } from "../../serializers/primitives.js";

/**
 * Portal account settings: preferences, notification channels and the privacy
 * centre.
 *
 * These map onto existing tables — `users` for preferences,
 * `notification_preferences` for channels, `user_consents` and
 * `data_subject_requests` for privacy — rather than a new settings store.
 */
const NOTIFICATION_TYPES = [
  { type: "inquiry.received", label: "New inquiries", description: "Someone asks about one of your listings." },
  { type: "message.received", label: "New messages", description: "A reply arrives in your inbox." },
  { type: "booking.requested", label: "Viewing requests", description: "A buyer asks for a viewing or inspection." },
  { type: "offer.received", label: "Offers", description: "An offer is made on one of your listings." },
  { type: "listing.moderated", label: "Listing decisions", description: "A listing is approved, rejected or about to expire." },
  { type: "review.received", label: "Reviews", description: "Someone reviews you or your company." },
  { type: "billing.event", label: "Billing", description: "Invoices, renewals and payment failures." },
  { type: "product.updates", label: "Product updates", description: "Occasional news about LivFinder." },
];

const CONSENT_TYPES = [
  { type: "marketing_email", label: "Marketing email", description: "Occasional email about LivFinder." },
  { type: "marketing_sms", label: "Marketing SMS", description: "Text messages about LivFinder." },
  { type: "marketing_whatsapp", label: "Marketing WhatsApp", description: "WhatsApp messages about LivFinder." },
  { type: "cookies_analytics", label: "Analytics cookies", description: "Helps us understand how the site is used." },
  { type: "cookies_marketing", label: "Marketing cookies", description: "Used to measure advertising." },
  { type: "data_sharing", label: "Share my enquiries with partner agencies", description: "Lets partners follow up directly." },
];

export const accountSettingsSchema = z.object({
  language: z.string().trim().max(12).optional(),
  currency: z.string().trim().length(3).toUpperCase().optional(),
  timezone: z.string().trim().max(64).optional(),
  areaUnit: z.enum(["sqft", "sqm"]).optional(),
  marketingOptIn: z.boolean().optional(),
});

export async function getAccountSettings(userId) {
  const user = await queryOne(
    `SELECT u.email, u.email_verified_at, u.phone_e164, u.timezone, u.preferred_area_unit,
            u.marketing_opt_in, u.mfa_enabled, u.created_at,
            lang.code AS language_code, cur.code AS currency_code
       FROM users u
       LEFT JOIN languages lang ON lang.id = u.preferred_language_id
       LEFT JOIN currencies cur ON cur.id = u.preferred_currency_id
      WHERE u.id = ?`,
    [userId]
  );
  if (!user) throw AppError.notFound();

  const [languages, currencies, sessions] = await Promise.all([
    query("SELECT code, name FROM languages WHERE is_active = 1 ORDER BY sort_order, name"),
    query("SELECT code, name, symbol FROM currencies WHERE is_active = 1 ORDER BY sort_order, code"),
    query(
      `SELECT public_id, device_type, user_agent, created_at, last_used_at
         FROM user_sessions WHERE user_id = ? AND revoked_at IS NULL AND expires_at > NOW(3)
        ORDER BY last_used_at DESC LIMIT 20`,
      [userId]
    ),
  ]);

  return {
    email: user.email,
    emailVerified: Boolean(user.email_verified_at),
    phone: user.phone_e164,
    language: user.language_code || "en",
    currency: user.currency_code || "AED",
    timezone: user.timezone,
    areaUnit: user.preferred_area_unit || "sqft",
    marketingOptIn: bool(user.marketing_opt_in),
    mfaEnabled: bool(user.mfa_enabled),
    memberSince: isoDate(user.created_at),
    options: {
      languages: languages.map((row) => ({ value: row.code, label: row.name })),
      currencies: currencies.map((row) => ({ value: row.code, label: `${row.code} — ${row.name}` })),
      areaUnits: [
        { value: "sqft", label: "Square feet" },
        { value: "sqm", label: "Square metres" },
      ],
    },
    activeSessions: sessions.map((row) => ({
      id: row.public_id,
      deviceType: row.device_type,
      userAgent: row.user_agent,
      createdAt: isoDate(row.created_at),
      lastUsedAt: isoDate(row.last_used_at),
    })),
  };
}

export async function updateAccountSettings(userId, payload) {
  const assignments = [];
  const params = [];

  if (payload.language !== undefined) {
    const languageId = await queryValue("SELECT id FROM languages WHERE code = ? AND is_active = 1", [payload.language]);
    if (!languageId) throw AppError.validation("Some information is invalid.", { language: "Unsupported language." });
    assignments.push("preferred_language_id = ?");
    params.push(languageId);
  }
  if (payload.currency !== undefined) {
    const currencyId = await queryValue("SELECT id FROM currencies WHERE code = ? AND is_active = 1", [payload.currency]);
    if (!currencyId) throw AppError.validation("Some information is invalid.", { currency: "Unsupported currency." });
    assignments.push("preferred_currency_id = ?");
    params.push(currencyId);
  }
  if (payload.timezone !== undefined) {
    assignments.push("timezone = ?");
    params.push(payload.timezone);
  }
  if (payload.areaUnit !== undefined) {
    assignments.push("preferred_area_unit = ?");
    params.push(payload.areaUnit);
  }
  if (payload.marketingOptIn !== undefined) {
    assignments.push("marketing_opt_in = ?");
    params.push(payload.marketingOptIn ? 1 : 0);
  }
  if (assignments.length) {
    await execute(`UPDATE users SET ${assignments.join(", ")} WHERE id = ?`, [...params, userId]);
  }
  return getAccountSettings(userId);
}

/* -------------------------------------------------------------------------- */
/* Notifications                                                               */
/* -------------------------------------------------------------------------- */

export const notificationSettingsSchema = z.object({
  preferences: z
    .array(
      z.object({
        type: z.string().trim().min(1).max(80),
        email: z.boolean().optional(),
        push: z.boolean().optional(),
        sms: z.boolean().optional(),
        whatsapp: z.boolean().optional(),
        inApp: z.boolean().optional(),
      })
    )
    .max(50),
});

export async function getNotificationSettings(userId) {
  const rows = await query(
    `SELECT notification_type, email_enabled, push_enabled, sms_enabled, whatsapp_enabled, in_app_enabled
       FROM notification_preferences WHERE user_id = ?`,
    [userId]
  );
  const byType = new Map(rows.map((row) => [row.notification_type, row]));

  return {
    channels: [
      { key: "email", label: "Email", status: "active" },
      { key: "inApp", label: "In-app", status: "active" },
      { key: "push", label: "Push", status: "not-connected" },
      { key: "sms", label: "SMS", status: "not-connected" },
      { key: "whatsapp", label: "WhatsApp", status: "not-connected" },
    ],
    preferences: NOTIFICATION_TYPES.map((definition) => {
      const stored = byType.get(definition.type);
      return {
        ...definition,
        // No stored row means the platform default: email and in-app on.
        email: stored ? bool(stored.email_enabled) : true,
        inApp: stored ? bool(stored.in_app_enabled) : true,
        push: stored ? bool(stored.push_enabled) : false,
        sms: stored ? bool(stored.sms_enabled) : false,
        whatsapp: stored ? bool(stored.whatsapp_enabled) : false,
      };
    }),
  };
}

export async function updateNotificationSettings(userId, payload) {
  const known = new Set(NOTIFICATION_TYPES.map((definition) => definition.type));
  await withTransaction(async (connection) => {
    for (const preference of payload.preferences) {
      // Only a notification type the platform actually sends can be stored.
      if (!known.has(preference.type)) continue;
      await execute(
        `INSERT INTO notification_preferences
           (user_id, notification_type, email_enabled, push_enabled, sms_enabled, whatsapp_enabled, in_app_enabled, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, NOW(3))
         ON DUPLICATE KEY UPDATE
           email_enabled = VALUES(email_enabled), push_enabled = VALUES(push_enabled),
           sms_enabled = VALUES(sms_enabled), whatsapp_enabled = VALUES(whatsapp_enabled),
           in_app_enabled = VALUES(in_app_enabled), updated_at = NOW(3)`,
        [
          userId,
          preference.type,
          preference.email === false ? 0 : 1,
          preference.push ? 1 : 0,
          preference.sms ? 1 : 0,
          preference.whatsapp ? 1 : 0,
          preference.inApp === false ? 0 : 1,
        ],
        connection
      );
    }
  });
  return getNotificationSettings(userId);
}

/* -------------------------------------------------------------------------- */
/* Privacy                                                                     */
/* -------------------------------------------------------------------------- */

export const consentSchema = z.object({
  consents: z
    .array(z.object({ type: z.string().trim().min(1).max(60), granted: z.boolean() }))
    .max(20),
});

export const dataRequestSchema = z.object({
  requestType: z.enum(["export", "deletion", "rectification", "restriction", "objection"]),
  notes: z.string().trim().max(1000).optional(),
});

function ipToBinary(ip) {
  if (!ip) return null;
  const clean = String(ip).replace(/^::ffff:/, "");
  return net.isIPv4(clean) ? Buffer.from(clean.split(".").map(Number)) : null;
}

export async function getPrivacySettings(userId) {
  const [consents, requests, terms] = await Promise.all([
    query(
      `SELECT c1.consent_type, c1.is_granted, c1.created_at, c1.policy_version
         FROM user_consents c1
         JOIN (SELECT consent_type, MAX(id) AS id FROM user_consents WHERE user_id = ? GROUP BY consent_type) latest
           ON latest.id = c1.id`,
      [userId]
    ),
    query(
      `SELECT public_id, request_type, status, notes, result_url, due_at, completed_at, created_at
         FROM data_subject_requests WHERE user_id = ? ORDER BY created_at DESC LIMIT 20`,
      [userId]
    ),
    queryOne("SELECT terms_accepted_at FROM users WHERE id = ?", [userId]),
  ]);

  const byType = new Map(consents.map((row) => [row.consent_type, row]));
  return {
    termsAcceptedAt: isoDate(terms?.terms_accepted_at),
    consents: CONSENT_TYPES.map((definition) => {
      const stored = byType.get(definition.type);
      return {
        ...definition,
        // Consent is opt-in: absent means not granted.
        granted: stored ? bool(stored.is_granted) : false,
        updatedAt: isoDate(stored?.created_at),
        policyVersion: stored?.policy_version ?? null,
      };
    }),
    requests: requests.map((row) => ({
      id: row.public_id,
      type: row.request_type,
      status: row.status,
      notes: row.notes,
      resultUrl: row.result_url,
      dueAt: isoDate(row.due_at),
      completedAt: isoDate(row.completed_at),
      createdAt: isoDate(row.created_at),
    })),
  };
}

export async function updateConsents({ userId, payload, ip }) {
  const known = new Set(CONSENT_TYPES.map((definition) => definition.type));
  await withTransaction(async (connection) => {
    for (const consent of payload.consents) {
      if (!known.has(consent.type)) continue;
      // Consent is append-only: a withdrawal is a new row, not an edit, so the
      // history of what was agreed and when survives.
      await execute(
        `INSERT INTO user_consents (user_id, consent_type, is_granted, policy_version, source, ip_address, created_at)
         VALUES (?, ?, ?, ?, 'portal_settings', ?, NOW(3))`,
        [userId, consent.type, consent.granted ? 1 : 0, "2026-01", ipToBinary(ip)],
        connection
      );
    }
    // The user record carries the marketing flag the mailer reads.
    const marketing = payload.consents.find((consent) => consent.type === "marketing_email");
    if (marketing) {
      await execute(
        "UPDATE users SET marketing_opt_in = ?, marketing_opt_in_at = IF(?, NOW(3), marketing_opt_in_at) WHERE id = ?",
        [marketing.granted ? 1 : 0, marketing.granted ? 1 : 0, userId],
        connection
      ).catch(async () => {
        await execute("UPDATE users SET marketing_opt_in = ? WHERE id = ?", [marketing.granted ? 1 : 0, userId], connection);
      });
    }
  });
  return getPrivacySettings(userId);
}

export async function createDataRequest({ userId, payload }) {
  const open = await queryOne(
    `SELECT id FROM data_subject_requests
      WHERE user_id = ? AND request_type = ? AND status IN ('pending','in_progress') LIMIT 1`,
    [userId, payload.requestType]
  );
  if (open) throw AppError.conflict("A request of that kind is already open.");

  const publicId = ulid();
  await execute(
    `INSERT INTO data_subject_requests
       (public_id, user_id, request_type, status, notes, due_at, created_at)
     VALUES (?, ?, ?, 'pending', ?, DATE_ADD(NOW(3), INTERVAL 30 DAY), NOW(3))`,
    [publicId, userId, payload.requestType, payload.notes || null]
  );
  return { id: publicId, status: "pending", requestType: payload.requestType };
}

export { NOTIFICATION_TYPES, CONSENT_TYPES };
