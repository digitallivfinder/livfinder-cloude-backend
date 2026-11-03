import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute } from "../../db/query.js";
import { sendMail } from "../system/mail.service.js";
import { notify } from "../system/notifications.service.js";
import * as presence from "../../realtime/presence.js";
import { resumeToken } from "./identity.js";

/**
 * Telling people about a message they are not online to see.
 *
 * Someone with the chat open gets it over the socket and nothing else. Everyone else gets an
 * in-app notification and, at most once every EMAIL_GAP_MINUTES per conversation, an email. A
 * burst of ten messages is one email, not ten. A muted thread sends nothing.
 *
 * Guests have no account to sign in to, so their email carries a resume link that opens the chat.
 */

const EMAIL_GAP_MINUTES = 15;

const participantRef = (row) =>
  row.user_public_id ? `u:${row.user_public_id}` : row.guest_public_id ? `g:${row.guest_public_id}` : null;

function linkFor(row, conversation) {
  const base = env.FRONTEND_URL.replace(/\/+$/, "");
  const id = encodeURIComponent(conversation.public_id);
  if (row.guest_public_id) return `${base}/chat?resume=${encodeURIComponent(resumeToken(row.guest_public_id))}&conversation=${id}`;
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
    try {
      await sendMail({
        to,
        subject: `New message from ${senderName} — ${about}`,
        text: [
          `${senderName} wrote:`,
          "",
          preview,
          "",
          `Reply here: ${link}`,
          "",
          row.guest_public_id
            ? "This link signs you in to the chat on this device. Do not forward it."
            : "You are receiving this because you were not online when the message arrived.",
        ].join("\n"),
      });
      emailed += 1;
    } catch (error) {
      logger.warn({ err: error }, "chat email failed");
    }
  }
  return emailed;
}
