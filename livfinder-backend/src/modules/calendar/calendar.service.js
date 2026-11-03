import crypto from "node:crypto";
import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute, query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { safeFetch } from "../../utils/safeFetch.js";
import { decryptSecret, encryptSecret } from "../../utils/secrets.js";
import { sendMail } from "../system/mail.service.js";
import { buildInvite } from "./ics.js";

/**
 * Viewings in people's calendars.
 *
 * Every confirmed viewing emails both sides an invite, which needs no permission. Anyone who
 * chose to connect Google Calendar also gets the event written there. Connecting is separate
 * from signing in and asks only for `calendar.events`. All of this follows a booking change
 * that has already been saved, so nothing here can fail that change.
 */
const AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth";
const TOKEN_URL = "https://oauth2.googleapis.com/token";
const REVOKE_URL = "https://oauth2.googleapis.com/revoke";
const USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo";
const EVENTS_URL = "https://www.googleapis.com/calendar/v3/calendars/primary/events";
const CALENDAR_SCOPE = "https://www.googleapis.com/auth/calendar.events";

const TYPE_LABELS = {
  viewing: "Viewing",
  inspection: "Inspection",
  sea_trial: "Sea trial",
  test_drive: "Test drive",
  charter: "Charter",
  consultation: "Consultation",
};
const CANCELLED = new Set(["cancelled", "no_show"]);

const clientId = () => process.env.OAUTH_GOOGLE_CLIENT_ID;
const clientSecret = () => process.env.OAUTH_GOOGLE_CLIENT_SECRET;

export const googleCalendarConfigured = () => Boolean(clientId() && clientSecret());

export async function connectionStatus(userId) {
  const connection = await queryOne(
    "SELECT provider_email, status, connected_at FROM calendar_connections WHERE user_id = ? AND provider = 'google'",
    [userId]
  );
  return {
    configured: googleCalendarConfigured(),
    connected: connection?.status === "active",
    needsReconnect: connection?.status === "revoked",
    email: connection?.provider_email ?? null,
  };
}

export function authorizeUrl({ redirectUri, state }) {
  const url = new URL(AUTHORIZE_URL);
  url.searchParams.set("client_id", clientId());
  url.searchParams.set("redirect_uri", redirectUri);
  url.searchParams.set("response_type", "code");
  url.searchParams.set("scope", `openid email ${CALENDAR_SCOPE}`);
  // A refresh token is only issued with offline access, and reliably only on a consent prompt.
  url.searchParams.set("access_type", "offline");
  url.searchParams.set("prompt", "consent");
  url.searchParams.set("state", state);
  return url.toString();
}

async function requestToken(params) {
  const response = await safeFetch(TOKEN_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded", Accept: "application/json" },
    body: new URLSearchParams({ client_id: clientId(), client_secret: clientSecret(), ...params }),
  });
  const payload = await response.json().catch(() => ({}));
  return { ok: response.ok, payload };
}

export async function completeConnection({ userId, code, redirectUri }) {
  const { ok, payload } = await requestToken({ grant_type: "authorization_code", code, redirect_uri: redirectUri });
  if (!ok || !payload.refresh_token) throw AppError.badRequest("Google Calendar could not be connected.");
  // Google lets a person untick a permission on its consent screen.
  if (!String(payload.scope ?? "").split(" ").includes(CALENDAR_SCOPE)) {
    throw AppError.badRequest("Calendar access was not granted.");
  }
  const profile = await safeFetch(USERINFO_URL, {
    headers: { Authorization: `Bearer ${payload.access_token}`, Accept: "application/json" },
  });
  const email = profile.ok ? (await profile.json()).email ?? null : null;
  await execute(
    `INSERT INTO calendar_connections (user_id, provider, provider_email, refresh_token_enc, scope, status)
     VALUES (?, 'google', ?, ?, ?, 'active')
     ON DUPLICATE KEY UPDATE provider_email = VALUES(provider_email), refresh_token_enc = VALUES(refresh_token_enc),
       scope = VALUES(scope), status = 'active', last_error = NULL, connected_at = NOW(3)`,
    [userId, email, encryptSecret(payload.refresh_token), payload.scope ?? null]
  );
}

export async function disconnect(userId) {
  const connection = await queryOne(
    "SELECT refresh_token_enc FROM calendar_connections WHERE user_id = ? AND provider = 'google'",
    [userId]
  );
  if (!connection) return;
  // Removed here regardless: a failure at Google must not leave the person connected on our side.
  await execute("DELETE FROM booking_calendar_events WHERE user_id = ? AND provider = 'google'", [userId]);
  await execute("DELETE FROM calendar_connections WHERE user_id = ? AND provider = 'google'", [userId]);
  const token = decryptSecret(connection.refresh_token_enc);
  if (!token) return;
  await safeFetch(REVOKE_URL, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ token }),
  }).catch((error) => logger.warn({ err: error, userId }, "google calendar token could not be revoked"));
}

async function accessToken(userId) {
  const connection = await queryOne(
    "SELECT refresh_token_enc FROM calendar_connections WHERE user_id = ? AND provider = 'google' AND status = 'active'",
    [userId]
  );
  if (!connection) return null;
  const { ok, payload } = await requestToken({
    grant_type: "refresh_token",
    refresh_token: decryptSecret(connection.refresh_token_enc),
  });
  if (ok && payload.access_token) return payload.access_token;
  // `invalid_grant` means the person removed access at Google; the portal offers a reconnect.
  await execute(
    "UPDATE calendar_connections SET status = 'revoked', last_error = ? WHERE user_id = ? AND provider = 'google'",
    [String(payload.error ?? "token refresh failed").slice(0, 255), userId]
  );
  return null;
}

async function loadBooking(bookingId) {
  return queryOne(
    `SELECT b.id, b.public_id, b.reference, b.booking_type, b.status, b.scheduled_start, b.scheduled_end, b.user_id,
            b.contact_name, b.contact_email, b.contact_phone, b.meeting_location, b.account_id,
            l.title AS listing_title,
            ag.user_id AS agent_user_id, ag.display_name AS agent_name, ag.email AS agent_email, ag.phone AS agent_phone,
            o.name AS organization_name, o.email AS organization_email,
            owner.id AS owner_user_id, owner.display_name AS owner_name, owner.email AS owner_email
       FROM bookings b
       LEFT JOIN listings l ON l.id = b.listing_id
       LEFT JOIN agents ag ON ag.id = b.agent_id
       LEFT JOIN organizations o ON o.id = b.organization_id
       LEFT JOIN accounts a ON a.id = b.account_id
       LEFT JOIN users owner ON owner.id = a.owner_user_id
      WHERE b.id = ?`,
    [bookingId]
  );
}

/** Each side sees the other's contact details, and neither address is shown as a guest. */
function describe(booking) {
  const type = TYPE_LABELS[booking.booking_type] ?? "Viewing";
  const title = booking.listing_title ?? booking.reference;
  const sellerName = booking.organization_name ?? booking.agent_name ?? booking.owner_name ?? "LivFinder";
  const customerLines = [`Booking ${booking.reference}`, `With: ${sellerName}`, booking.agent_phone && `Phone: ${booking.agent_phone}`];
  const sellerLines = [
    `Booking ${booking.reference}`,
    `Customer: ${booking.contact_name ?? "Customer"}`,
    booking.contact_email && `Email: ${booking.contact_email}`,
    booking.contact_phone && `Phone: ${booking.contact_phone}`,
  ];
  return {
    start: booking.scheduled_start,
    end: booking.scheduled_end ?? new Date(new Date(booking.scheduled_start).getTime() + 60 * 60 * 1000),
    location: booking.meeting_location ?? null,
    customer: {
      email: booking.contact_email,
      userId: booking.user_id,
      summary: `${type}: ${title}`,
      description: customerLines.filter(Boolean).join("\n"),
    },
    seller: {
      email: booking.agent_email ?? booking.organization_email ?? booking.owner_email,
      userId: booking.agent_user_id ?? booking.owner_user_id,
      summary: `${type}: ${title} with ${booking.contact_name ?? "customer"}`,
      description: sellerLines.filter(Boolean).join("\n"),
    },
  };
}

async function emailInvite(booking, details, side, method) {
  if (!side.email) return;
  const cancelled = method === "CANCEL";
  const ics = buildInvite({
    uid: `${booking.public_id}-${crypto.createHash("sha256").update(side.email).digest("hex").slice(0, 8)}@livfinder.com`,
    // Larger on every send, so a calendar always treats the newest as current.
    sequence: Math.floor(Date.now() / 1000),
    method,
    start: details.start,
    end: details.end,
    summary: side.summary,
    description: side.description,
    location: details.location,
    organizer: env.MAIL_FROM,
    attendee: side.email,
  });
  const when = new Date(details.start).toUTCString();
  await sendMail({
    to: side.email,
    subject: `${cancelled ? "Cancelled" : "Confirmed"}: ${side.summary}`,
    text: `${side.summary}\n${when}${details.location ? `\n${details.location}` : ""}\n\n${side.description}\n\n${
      cancelled ? "This has been cancelled." : "The attached invite adds this to your calendar."
    }`,
    attachments: [
      { filename: "invite.ics", content: ics, contentType: `text/calendar; charset=utf-8; method=${method}` },
    ],
  });
}

async function googleRequest(url, token, options = {}) {
  return safeFetch(url, {
    ...options,
    headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json", Accept: "application/json" },
  });
}

async function writeGoogleEvent(booking, details, side) {
  const token = await accessToken(side.userId);
  if (!token) return;
  const existing = await queryOne(
    "SELECT external_event_id FROM booking_calendar_events WHERE booking_id = ? AND user_id = ? AND provider = 'google'",
    [booking.id, side.userId]
  );
  const body = JSON.stringify({
    summary: side.summary,
    description: side.description,
    location: details.location ?? undefined,
    start: { dateTime: new Date(details.start).toISOString() },
    end: { dateTime: new Date(details.end).toISOString() },
  });
  if (existing) {
    const updated = await googleRequest(`${EVENTS_URL}/${encodeURIComponent(existing.external_event_id)}`, token, { method: "PATCH", body });
    if (updated.ok) return;
    // Deleted by hand in the calendar: the booking still stands, so it is written again.
    if (updated.status !== 404 && updated.status !== 410) throw new Error(`google calendar update failed: ${updated.status}`);
    await execute("DELETE FROM booking_calendar_events WHERE booking_id = ? AND user_id = ? AND provider = 'google'", [booking.id, side.userId]);
  }
  const created = await googleRequest(EVENTS_URL, token, { method: "POST", body });
  if (!created.ok) throw new Error(`google calendar create failed: ${created.status}`);
  const event = await created.json();
  await execute(
    "INSERT INTO booking_calendar_events (booking_id, user_id, provider, external_event_id) VALUES (?, ?, 'google', ?)",
    [booking.id, side.userId, event.id]
  );
}

async function removeGoogleEvents(booking) {
  const events = await query(
    "SELECT user_id, external_event_id FROM booking_calendar_events WHERE booking_id = ? AND provider = 'google'",
    [booking.id]
  );
  for (const event of events) {
    const token = await accessToken(event.user_id);
    if (token) {
      const removed = await googleRequest(`${EVENTS_URL}/${encodeURIComponent(event.external_event_id)}`, token, { method: "DELETE" });
      if (!removed.ok && removed.status !== 404 && removed.status !== 410) {
        throw new Error(`google calendar delete failed: ${removed.status}`);
      }
    }
    await execute("DELETE FROM booking_calendar_events WHERE booking_id = ? AND user_id = ?", [booking.id, event.user_id]);
  }
}

const attempt = (label, bookingId, work) =>
  Promise.resolve()
    .then(work)
    .catch((error) => logger.error({ err: error, bookingId }, label));

/**
 * Call after a booking is saved. Confirming it or moving a confirmed one sends the invite and
 * writes the events; cancelling one that had been confirmed takes them back.
 */
export async function publishBookingChange(bookingId, { previousStatus = null, previousStart = null } = {}) {
  await attempt("booking calendar update failed", bookingId, async () => {
    const booking = await loadBooking(bookingId);
    if (!booking) return;
    const details = describe(booking);
    const sides = [details.customer, details.seller];
    const wasLive = previousStatus === "confirmed" || previousStatus === "rescheduled";
    const moved = previousStart !== null && new Date(previousStart).getTime() !== new Date(booking.scheduled_start).getTime();

    if (CANCELLED.has(booking.status)) {
      if (!wasLive) return;
      await attempt("booking calendar events could not be removed", bookingId, () => removeGoogleEvents(booking));
      for (const side of sides) await attempt("cancellation invite failed", bookingId, () => emailInvite(booking, details, side, "CANCEL"));
      return;
    }
    if (booking.status !== "confirmed" || (previousStatus === "confirmed" && !moved)) return;
    for (const side of sides) {
      await attempt("booking invite failed", bookingId, () => emailInvite(booking, details, side, "REQUEST"));
      if (side.userId) await attempt("google calendar event failed", bookingId, () => writeGoogleEvent(booking, details, side));
    }
  });
}
