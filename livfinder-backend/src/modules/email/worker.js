import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute, query, queryOne } from "../../db/query.js";
import { sendMail } from "../system/mail.service.js";
import { CATEGORIES, isOptional } from "./catalog.js";
import { localClock, siteUrl } from "./format.js";
import { preferencesFor, suppressionFor, unsubscribeToken } from "./preferences.js";
import { renderEmail } from "./render.js";
import { TEMPLATES } from "./templates/index.js";

/**
 * The email worker. Every tick it claims due rows in `email_messages`, checks suppressions and the
 * person's preferences, renders the template in their timezone, currency and area unit, sends it
 * and records the outcome. A failure is retried after 1, 5, 15 and 60 minutes and 6 hours, then
 * the row is marked failed and shows in admin → Emails.
 *
 * Each row is claimed with a conditional UPDATE, so two API instances never send the same email.
 */

const RETRY_MINUTES = [1, 5, 15, 60, 360];
const CLAIM_MINUTES = 3;

let ratesCache = { at: 0, rates: {} };
async function fxRates() {
  if (Date.now() - ratesCache.at < 10 * 60 * 1000) return ratesCache.rates;
  const rows = await query(
    "SELECT quote_code, rate FROM fx_rates_latest WHERE base_code = (SELECT code FROM currencies WHERE is_base = 1 LIMIT 1)"
  ).catch(() => []);
  ratesCache = { at: Date.now(), rates: Object.fromEntries(rows.map((row) => [row.quote_code, Number(row.rate)])) };
  return ratesCache.rates;
}

/** What a template needs to know about the reader. Guests and leads get the platform defaults. */
async function readerFor(row) {
  const user = row.user_id
    ? await queryOne(
        `SELECT u.id, u.email, u.first_name, u.display_name, u.timezone, u.preferred_area_unit, u.status,
                cur.code AS currency_code, lang.code AS language_code,
                EXISTS (SELECT 1 FROM user_roles ur JOIN roles r ON r.id = ur.role_id AND r.scope = 'platform' WHERE ur.user_id = u.id) AS is_staff,
                EXISTS (SELECT 1 FROM account_members m WHERE m.user_id = u.id AND m.status = 'active') AS is_member
           FROM users u
           LEFT JOIN currencies cur ON cur.id = u.preferred_currency_id
           LEFT JOIN languages lang ON lang.id = u.preferred_language_id
          WHERE u.id = ?`,
        [row.user_id]
      )
    : null;
  return {
    userId: user?.id ?? null,
    email: row.to_email,
    name: user?.display_name || row.to_name || null,
    firstName: user?.first_name || (row.to_name ? String(row.to_name).split(" ")[0] : null),
    timezone: user?.timezone || env.EMAIL_DEFAULT_TIMEZONE,
    currency: user?.currency_code || null,
    areaUnit: user?.preferred_area_unit || "sqft",
    // Copy is English; the layout already supports right-to-left for Arabic templates.
    locale: "en",
    isStaff: Boolean(user?.is_staff),
    isSeller: Boolean(user?.is_member),
    banned: user?.status === "banned",
  };
}

const DEFAULT_REASONS = {
  security: "You get this because of activity on your LivFinder account.",
  account: "You get this because you have a LivFinder account.",
  billing: "You get this because you manage billing for a LivFinder account.",
  receipts: "You get this because of something you sent on LivFinder.",
  staff: "You get this because of your LivFinder staff role.",
};

function settingsUrlFor(reader) {
  if (!reader.userId) return null;
  return siteUrl("/portal/settings/notifications");
}

/** Builds the message for a row. Also used by the admin preview and "resend". */
export async function composeMessage(row, { forceDark = false } = {}) {
  const template = TEMPLATES[row.template_key];
  if (!template) throw new Error(`Unknown email template: ${row.template_key}`);
  const data = typeof row.data === "string" ? JSON.parse(row.data) : row.data ?? {};
  const reader = await readerFor(row);
  const ctx = { recipient: reader, rates: await fxRates() };
  const output = template.render(data, ctx);
  const category = template.category;
  const optional = isOptional(category);
  const unsubscribeUrl = optional ? siteUrl(`/email-preferences?token=${encodeURIComponent(unsubscribeToken(row.to_email, category))}`) : null;
  const { html, text } = renderEmail({
    subject: output.subject,
    preheader: output.preheader,
    heading: output.heading,
    blocks: output.blocks,
    locale: reader.locale,
    forceDark,
    footer: {
      reason: output.reason ?? DEFAULT_REASONS[category] ?? `You get this because ${CATEGORIES[category].label.toLowerCase()} emails are on for your account.`,
      settingsUrl: settingsUrlFor(reader),
      unsubscribeUrl,
      reference: row.public_id,
    },
  });

  const headers = { "X-LivFinder-Template": row.template_key, "X-Entity-Ref-ID": row.public_id };
  if (optional) {
    headers["List-Unsubscribe"] = `<${siteUrl(`/v1/email/unsubscribe?token=${encodeURIComponent(unsubscribeToken(row.to_email, category))}`)}>`;
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click";
  }
  // Every stream sends from the one no-reply sender.
  const from = env.MAIL_FROM;
  return {
    to: row.to_email,
    from,
    subject: output.subject,
    text,
    html,
    headers,
    replyTo: row.reply_to || undefined,
    attachments: data._attachments,
  };
}

async function settle(row, status, { reason = null, error = null, messageId = null, provider = null, retryAt = null } = {}) {
  await execute(
    `UPDATE email_messages
        SET status = ?, status_reason = ?, last_error = ?, provider_message_id = COALESCE(?, provider_message_id), provider = COALESCE(?, provider),
            sent_at = IF(? = 'sent', NOW(3), sent_at), send_after = COALESCE(?, send_after), claimed_until = NULL
      WHERE id = ?`,
    [status, reason, error ? String(error).slice(0, 500) : null, messageId, provider, status, retryAt, row.id]
  );
}

/** Is this row held for the person's daily digest instead of sent now? */
async function holdForDigest(row, template) {
  if (!template.digestible || !row.user_id) return false;
  const preferences = await preferencesFor(row.user_id);
  return preferences[template.category]?.frequency === "daily";
}

async function deliverOne(row) {
  const template = TEMPLATES[row.template_key];
  if (!template) return settle(row, "failed", { error: "Unknown template" });

  // Preferences and suppressions are read at send time, so a change made after queueing counts.
  if (row.user_id && isOptional(template.category)) {
    const preferences = await preferencesFor(row.user_id);
    if (preferences[template.category] && !preferences[template.category].email) {
      return settle(row, "skipped", { reason: `${CATEGORIES[template.category].label} emails are off` });
    }
  }
  const suppressed = await suppressionFor(row.to_email, template.category);
  if (suppressed) return settle(row, "suppressed", { reason: suppressed });
  if (row.template_key !== "digest.daily" && (await holdForDigest(row, template))) {
    return settle(row, "held", { reason: "waiting for the daily summary" });
  }

  try {
    const message = await composeMessage(row);
    const result = await sendMail(message);
    await execute("UPDATE email_messages SET subject = ? WHERE id = ?", [String(message.subject).slice(0, 255), row.id]);
    return settle(row, "sent", { messageId: result?.messageId ?? null, provider: result?.driver ?? null });
  } catch (error) {
    const attempt = Number(row.attempts);
    const giveUp = attempt > RETRY_MINUTES.length;
    logger.warn({ err: error, emailId: row.public_id, attempt }, giveUp ? "email failed for good" : "email failed, will retry");
    return settle(row, giveUp ? "failed" : "queued", {
      error: error.message,
      retryAt: giveUp ? null : new Date(Date.now() + RETRY_MINUTES[attempt - 1] * 60_000),
    });
  }
}

/** Sends due emails (or exactly `ids`). Returns how many were handled. */
export async function deliverDue({ limit = 50, ids = null } = {}) {
  // A worker that died mid-send leaves its claim behind; it expires and the row is tried again.
  await execute("UPDATE email_messages SET status = 'queued', claimed_until = NULL WHERE status = 'sending' AND claimed_until < NOW(3)");
  const candidates = ids?.length
    ? await query(`SELECT id FROM email_messages WHERE id IN (${ids.map(() => "?").join(",")}) AND status = 'queued'`, ids)
    : await query(
        `SELECT id FROM email_messages WHERE status = 'queued' AND send_after <= NOW(3) ORDER BY priority ASC, send_after ASC LIMIT ${Number(limit)}`
      );
  let handled = 0;
  for (const { id } of candidates) {
    const claim = await execute(
      `UPDATE email_messages SET status = 'sending', attempts = attempts + 1, claimed_until = DATE_ADD(NOW(3), INTERVAL ${CLAIM_MINUTES} MINUTE)
        WHERE id = ? AND status = 'queued'`,
      [id]
    );
    if (!claim.affectedRows) continue;
    const row = await queryOne("SELECT * FROM email_messages WHERE id = ?", [id]);
    await deliverOne(row);
    handled += 1;
  }
  return handled;
}

/* -------------------------------------------------------------------------- */
/* Daily digest                                                                */
/* -------------------------------------------------------------------------- */

const DIGEST_HOUR = 8;

/**
 * At 08:00 in each person's timezone, everything held for them becomes one summary email.
 * Runs every tick; the dedupe key makes it once per person per day.
 */
export async function sendDueDigests() {
  const people = await query(
    `SELECT m.user_id, MAX(u.timezone) AS timezone, COUNT(*) AS held
       FROM email_messages m JOIN users u ON u.id = m.user_id
      WHERE m.status = 'held' GROUP BY m.user_id`
  );
  const { queueEmail } = await import("./send.js");
  let sent = 0;
  for (const person of people) {
    const clock = localClock(person.timezone);
    if (clock.hour < DIGEST_HOUR) continue;
    const held = await query(
      "SELECT id, category, subject, template_key, data, to_email, to_name, public_id, user_id, created_at FROM email_messages WHERE user_id = ? AND status = 'held' ORDER BY created_at",
      [person.user_id]
    );
    if (!held.length) continue;
    const sections = {};
    for (const row of held) {
      let subject = row.subject;
      if (!subject) {
        try {
          subject = TEMPLATES[row.template_key].render(typeof row.data === "string" ? JSON.parse(row.data) : row.data, { recipient: {}, rates: {} }).subject;
        } catch {
          subject = TEMPLATES[row.template_key]?.label ?? row.template_key;
        }
      }
      (sections[row.category] ??= []).push({ subject, at: row.created_at });
    }
    const id = await queueEmail({
      template: "digest.daily",
      to: held[0].to_email,
      toName: held[0].to_name,
      userId: person.user_id,
      data: {
        total: held.length,
        sections: Object.entries(sections).map(([key, items]) => ({ title: CATEGORIES[key]?.label ?? key, items })),
      },
      dedupeKey: `digest.daily:${person.user_id}:${clock.day}`,
    });
    if (id) {
      await execute(
        `UPDATE email_messages SET status = 'digested', status_reason = ? WHERE id IN (${held.map(() => "?").join(",")}) AND status = 'held'`,
        [`in daily summary ${clock.day}`, ...held.map((row) => row.id)]
      );
      sent += 1;
    }
  }
  return sent;
}

export function startEmailWorker({ intervalMs = 15 * 1000 } = {}) {
  if (env.isTest || !env.EMAIL_WORKER_ENABLED) return null;
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      await deliverDue();
    } catch (error) {
      if ((await import("./send.js")).missingEmailTables(error)) return; // migration 0081 not applied yet
      logger.error({ err: error }, "email worker failed");
    } finally {
      running = false;
    }
  };
  tick();
  const timer = setInterval(tick, intervalMs);
  timer.unref?.();
  return timer;
}
