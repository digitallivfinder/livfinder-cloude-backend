import { execute, query, queryOne } from "../../db/query.js";
import { ulid } from "../../utils/ids.js";
import logger from "../../config/logger.js";

/**
 * Produces notifications.
 *
 * `notifications` held 420 seeded rows, the read and mark-read endpoints existed, and nothing
 * anywhere wrote one — so the feature was fully modelled and completely inert. A seller learned
 * about an enquiry only by opening the inbox and noticing a new row.
 *
 * Two rules shape everything here.
 *
 * A notification must never break the thing it is announcing. Every function below swallows its
 * own errors and logs: an enquiry that was accepted, stored and is visible in the inbox must not
 * turn into a 500 because a notification row could not be inserted.
 *
 * Notifications go to people, not accounts. A row is per `user_id`, so an account with three
 * members produces three rows — each of them can read and dismiss their own.
 */

/** Everyone who should hear about something happening on an account. */
async function recipientsForAccount({ accountId, organizationId, agentId = null }, connection) {
  // The assigned agent first, if there is one: an inquiry routed to a named person is theirs.
  const rows = await query(
    `SELECT DISTINCT m.user_id
       FROM account_members m
      WHERE m.account_id = ?
        AND m.status = 'active'
        AND m.user_id IS NOT NULL
      UNION
     SELECT DISTINCT a.user_id
       FROM agents a
      WHERE a.id = ? AND a.user_id IS NOT NULL AND a.deleted_at IS NULL`,
    [accountId ?? 0, agentId ?? 0],
    connection
  );
  if (rows.length || !organizationId) return rows.map((row) => row.user_id);

  // An organization with no account membership rows still has agents who should be told.
  const fallback = await query(
    "SELECT DISTINCT user_id FROM agents WHERE organization_id = ? AND user_id IS NOT NULL AND deleted_at IS NULL LIMIT 20",
    [organizationId],
    connection
  );
  return fallback.map((row) => row.user_id);
}

/**
 * Writes one notification. Everything else in this file is a wrapper that decides the wording.
 *
 * `subjectType`/`subjectId` are recorded so a future digest or a "mark everything about this
 * listing read" can find related rows without parsing the action URL.
 */
export async function notify(
  { userId, type, title, body = null, actionUrl = null, icon = null, subjectType = null, subjectId = null, data = null },
  connection
) {
  if (!userId || !type || !title) return null;
  try {
    await execute(
      `INSERT INTO notifications
         (public_id, user_id, type, title, body, action_url, icon, subject_type, subject_id, data, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(3))`,
      [
        ulid(),
        userId,
        type,
        title.slice(0, 200),
        body ? String(body).slice(0, 1000) : null,
        actionUrl,
        icon,
        subjectType,
        subjectId,
        data ? JSON.stringify(data) : null,
      ],
      connection
    );
    return true;
  } catch (error) {
    logger.warn({ err: error, type, userId }, "notification not written");
    return false;
  }
}

/** Fan a notification out to every member of an account. */
export async function notifyAccount(scope, payload, connection) {
  try {
    const recipients = await recipientsForAccount(scope, connection);
    for (const userId of recipients) {
      await notify({ ...payload, userId }, connection);
    }
    return recipients.length;
  } catch (error) {
    logger.warn({ err: error, type: payload?.type }, "notification fan-out failed");
    return 0;
  }
}

/* -------------------------------------------------------------------------- */
/* The events worth telling someone about                                      */
/* -------------------------------------------------------------------------- */

export async function notifyNewInquiry({ listing, inquiry }, connection) {
  return notifyAccount(
    { accountId: listing.account_id, organizationId: listing.organization_id, agentId: listing.agent_id },
    {
      type: "inquiry.created",
      title: `New enquiry about ${listing.title ?? listing.reference}`,
      body: inquiry.message ? String(inquiry.message).slice(0, 240) : null,
      actionUrl: "/portal/inquiries",
      icon: "message",
      subjectType: "inquiry",
      subjectId: inquiry.id,
      data: { reference: inquiry.reference, buyer: inquiry.name },
    },
    connection
  );
}

export async function notifyNewBooking({ listing, booking }, connection) {
  return notifyAccount(
    { accountId: listing.account_id, organizationId: listing.organization_id, agentId: listing.agent_id },
    {
      type: "booking.requested",
      title: `Viewing requested for ${listing.title ?? listing.reference}`,
      body: booking.scheduledStart ? `Requested for ${booking.scheduledStart}.` : null,
      actionUrl: "/portal/bookings",
      icon: "calendar",
      subjectType: "booking",
      subjectId: booking.id,
      data: { reference: booking.reference },
    },
    connection
  );
}

export async function notifyNewOffer({ listing, offer }, connection) {
  return notifyAccount(
    { accountId: listing.account_id, organizationId: listing.organization_id, agentId: listing.agent_id },
    {
      type: "offer.received",
      title: `Offer received on ${listing.title ?? listing.reference}`,
      body: offer.amount ? `${offer.currency ?? ""} ${Number(offer.amount).toLocaleString("en-US")}`.trim() : null,
      actionUrl: "/portal/offers",
      icon: "tag",
      subjectType: "offer",
      subjectId: offer.id,
      data: { reference: offer.reference },
    },
    connection
  );
}

/**
 * A moderation decision. This one is the most valuable of the set: a rejected listing sits
 * invisible until its owner happens to look, and the reason is the only actionable part.
 */
export async function notifyListingModeration({ listing, decision, reason }, connection) {
  const wording = {
    approve: ["listing.approved", "Your listing is live", "check"],
    reject: ["listing.rejected", "Your listing was not approved", "alert"],
    unpublish: ["listing.unpublished", "Your listing was unpublished", "alert"],
    archive: ["listing.archived", "Your listing was archived", "archive"],
    flag: ["listing.flagged", "Your listing was flagged for review", "flag"],
  }[decision];
  if (!wording) return 0;
  const [type, title, icon] = wording;

  return notifyAccount(
    { accountId: listing.account_id, organizationId: listing.organization_id, agentId: listing.agent_id },
    {
      type,
      title: `${title}: ${listing.title ?? listing.reference}`,
      body: reason || null,
      actionUrl: "/portal/listings",
      icon,
      subjectType: "listing",
      subjectId: listing.id,
      data: { reference: listing.reference, decision },
    },
    connection
  );
}

export async function notifyVerificationDecision({ accountId, organizationId, decision, reason }, connection) {
  const approved = decision === "approve" || decision === "verified";
  return notifyAccount(
    { accountId, organizationId },
    {
      type: approved ? "verification.approved" : "verification.rejected",
      title: approved ? "Your account is verified" : "Verification needs more information",
      body: reason || null,
      actionUrl: "/portal/organization",
      icon: approved ? "shield-check" : "shield-alert",
      subjectType: "account",
      subjectId: accountId,
    },
    connection
  );
}

/** A public reply to a review the seller wrote, or a new review about them. */
export async function notifyNewReview({ organizationId, accountId, review }, connection) {
  return notifyAccount(
    { accountId, organizationId },
    {
      type: "review.received",
      title: `New ${review.rating ?? ""}-star review`.replace("  ", " "),
      body: review.body ? String(review.body).slice(0, 240) : null,
      actionUrl: "/portal/reviews",
      icon: "star",
      subjectType: "review",
      subjectId: review.id,
    },
    connection
  );
}

/** A message in a conversation, for every participant except the sender. */
export async function notifyNewMessage({ conversationId, senderUserId, preview }, connection) {
  try {
    const participants = await query(
      "SELECT user_id FROM conversation_participants WHERE conversation_id = ? AND user_id <> ? AND user_id IS NOT NULL",
      [conversationId, senderUserId ?? 0],
      connection
    );
    const sender = await queryOne("SELECT display_name FROM users WHERE id = ?", [senderUserId], connection);
    for (const participant of participants) {
      await notify(
        {
          userId: participant.user_id,
          type: "message.received",
          title: `New message from ${sender?.display_name ?? "a buyer"}`,
          body: preview ? String(preview).slice(0, 240) : null,
          actionUrl: "/portal/messages",
          icon: "message",
          subjectType: "conversation",
          subjectId: conversationId,
        },
        connection
      );
    }
    return participants.length;
  } catch (error) {
    logger.warn({ err: error }, "message notification failed");
    return 0;
  }
}
