import logger from "../../config/logger.js";
import { contactsOf, markDelivered, markRead, typingAudience } from "./chat.service.js";

/**
 * What a connected chat client may say over the socket. Everything that writes data goes through
 * the service, which checks the person may act on that conversation; the socket adds nothing to
 * what the REST API allows.
 *
 *   typing    { conversationId, typing }   -> "typing" to the other participants
 *   delivered { conversationIds? }          -> grey ticks for the sender
 *   read      { conversationId }            -> blue ticks for the sender
 *   presence  { refs } (ack)                -> who of those contacts is online
 */

const BUCKET_SIZE = 30;
const BUCKET_REFILL_MS = 5_000;
const AUDIENCE_TTL_MS = 60_000;
const CONTACTS_TTL_MS = 5 * 60_000;

/** A small per-socket budget, so a looping client cannot flood the others or the database. */
function limiter() {
  let tokens = BUCKET_SIZE;
  let refilled = Date.now();
  return () => {
    const now = Date.now();
    if (now - refilled > BUCKET_REFILL_MS) {
      tokens = BUCKET_SIZE;
      refilled = now;
    }
    if (tokens <= 0) return false;
    tokens -= 1;
    return true;
  };
}

const conversationIdOf = (payload) => (typeof payload?.conversationId === "string" ? payload.conversationId.slice(0, 40) : null);

export function registerChatSocket(socket, { emitTo, presence }) {
  const { identity, ref } = socket.data;
  const allow = limiter();
  const audiences = new Map();
  let contacts = { refs: [], at: 0 };

  async function contactRefs() {
    if (Date.now() - contacts.at > CONTACTS_TTL_MS) contacts = { refs: await contactsOf(identity), at: Date.now() };
    return contacts.refs;
  }

  async function announce(online) {
    try {
      const refs = await contactRefs();
      if (refs.length) emitTo(refs, "presence", { ref, online, lastSeenAt: online ? null : new Date().toISOString() });
    } catch (error) {
      logger.debug({ err: error }, "presence announce failed");
    }
  }

  presence.connected(ref).then((cameOnline) => cameOnline && announce(true)).catch(() => {});
  // Everything waiting for this person has now reached a device.
  markDelivered(identity).catch((error) => logger.debug({ err: error }, "delivery receipts failed"));

  socket.on("disconnect", () => {
    presence.disconnected(ref).then((wentOffline) => wentOffline && announce(false)).catch(() => {});
  });

  socket.on("typing", async (payload) => {
    const conversationId = conversationIdOf(payload);
    if (!conversationId || !allow()) return;
    try {
      let audience = audiences.get(conversationId);
      if (!audience || Date.now() - audience.at > AUDIENCE_TTL_MS) {
        const found = await typingAudience(identity, conversationId).catch(() => null);
        audience = { refs: found?.refs ?? null, at: Date.now() };
        audiences.set(conversationId, audience);
      }
      if (!audience.refs?.length) return;
      emitTo(audience.refs, "typing", { conversationId, ref, name: identity.name, typing: payload.typing !== false });
    } catch (error) {
      logger.debug({ err: error }, "typing relay failed");
    }
  });

  socket.on("delivered", async (payload) => {
    if (!allow()) return;
    const ids = Array.isArray(payload?.conversationIds) ? payload.conversationIds.filter((id) => typeof id === "string").slice(0, 50) : null;
    await markDelivered(identity, ids).catch(() => {});
  });

  socket.on("read", async (payload, ack) => {
    const conversationId = conversationIdOf(payload);
    if (!conversationId || !allow()) return;
    const result = await markRead(identity, conversationId).catch(() => ({ read: false }));
    if (typeof ack === "function") ack(result);
  });

  socket.on("presence", async (payload, ack) => {
    if (typeof ack !== "function" || !allow()) return;
    try {
      // Only people this person actually chats with: presence is not a lookup service.
      let known = new Set(await contactRefs());
      // A thread started a moment ago is not in the cached list yet.
      const wanted = Array.isArray(payload?.refs) ? payload.refs : [];
      if (wanted.some((value) => !known.has(value)) && Date.now() - contacts.at > 10_000) {
        contacts.at = 0;
        known = new Set(await contactRefs());
      }
      const asked = Array.isArray(payload?.refs) ? payload.refs.filter((value) => typeof value === "string" && known.has(value)).slice(0, 100) : [];
      ack(await presence.lookup(asked));
    } catch {
      ack({});
    }
  });
}
