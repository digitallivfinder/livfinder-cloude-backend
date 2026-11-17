import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute } from "../../db/query.js";
import { queueEmail } from "../email/send.js";
import { notify } from "../system/notifications.service.js";
import * as presence from "../../realtime/presence.js";

/**
 * Telling people about a message they are not online to see.
 *
 * Someone with the chat open gets it over the socket and nothing else. Everyone else gets an
 * in-app notification and, at most once every EMAIL_GAP_MINUTES per conversation, an email. A
 * burst of ten messages is one email, not ten. A muted thread sends nothing.
 *
 * Guests get a link that opens the site's chat widget (`?chat=open`); the widget asks them to sign
 * in, as every chat on the site does. There is no separate /chat page any more.
 */

const EMAIL_GAP_MINUTES = 15;

const participantRef = (row) =>
  row.user_public_id ? `u:${row.user_public_id}` : row.guest_public_id ? `g:${row.guest_public_id}` : null;

function linkFor(row, conversation) {
  const base = env.FRONTEND_URL.replace(/\/+$/, "");
  const id = encodeURIComponent(conversation.public_id);
  if (row.guest_public_id) return `${base}/?chat=open&conversation=${id}`;
  if (row.role === "admin" || row.role === "observer") return `${base}/admin/support-chats?conversation=${id}`;
  return `${base}/portal/messages?conversation=${id}`;
}

export async function notifyOfflineRecipients({ conversation, participants, sender, message }) {
  const senderRef = sender.type === "user" ? `u:${sender.publicId}` : `g:${sender.publicId}`;
  const recipients = participants.filter((row) => participantRef(row) && participantRef(row) !== senderRef && !row.left_at);
  if (!recipients.length) return 0;
  const online = await presence.lookup(recipients.map(participantRef));
  const preview = message.body ? message.body.slice(0, 240) : "Sent you a file.";
  const senderName = sender.type === "user" ? sender.name : `${sender.name} (visitor)`;
  let emailed = 0;

  for (const row of recipients) {
    if (online[participantRef(row)]?.online) continue;
    const link = linkFor(row, conversation);

    if (row.user_id) {
      await notify({
        userId: row.user_id,
        type: "message.received",
        title: `New message from ${senderName}`,
        body: preview,
        actionUrl: new URL(link).pathname + new URL(link).search,
        icon: "message",
        subjectType: "conversation",
        subjectId: conversation.id,
      });
    }
    if (row.is_muted) continue;

    // One email per quiet spell: the update both checks and claims the slot, so two API
    // instances sending at once cannot both email.
    const claimed = await execute(
      `UPDATE conversation_participants SET last_emailed_at = NOW(3)
        WHERE id = ? AND (last_emailed_at IS NULL OR last_emailed_at < DATE_SUB(NOW(3), INTERVAL ${EMAIL_GAP_MINUTES} MINUTE))`,
      [row.id]
    );
    if (!claimed.affectedRows) continue;
    const to = row.user_email || row.guest_email;
    if (!to) continue;

    const about = conversation.kind === "support" ? "LivFinder Support" : conversation.subject || "your conversation";
    const id = await queueEmail({
      template: "chat.message",
      to,
      userId: row.user_id ?? null,
      data: { senderName, about, preview, url: link, guest: Boolean(row.guest_public_id) },
    });
    if (id) emailed += 1;
    else logger.warn({ conversationId: conversation.id }, "chat email not queued");
  }
  return emailed;
}
