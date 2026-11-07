import { Server } from "socket.io";
import { createAdapter } from "@socket.io/redis-adapter";
import { createClient } from "redis";
import env from "../config/env.js";
import logger from "../config/logger.js";
import { isOriginAllowed } from "../middleware/security.js";
import { resolveSession } from "../modules/auth/sessions.js";
import { BOOT_WAIT_MS, waitFor } from "../cache/redis.js";
import { loadAccountMemberships, loadPlatformAccess } from "../modules/auth/rbac.js";
import { GUEST_COOKIE, guestFromToken, identityFromAuth, refFor, canViewSupport } from "../modules/chat/identity.js";
import * as presence from "./presence.js";

/**
 * The live connection behind chat.
 *
 * The socket only *carries* events. Messages are sent over the REST API (CSRF-checked,
 * rate-limited, idempotent through a client ref) and the API then pushes them here, so there is
 * one write path and a page without a live connection still works.
 *
 * Rooms are per person, never per conversation: `u:<userPublicId>`, `g:<guestPublicId>`, plus
 * `staff:support` for everyone who may read the support inbox. The server decides who receives an
 * event from the conversation's participants, so a client cannot subscribe itself to a thread it
 * does not belong to.
 *
 * With Redis configured, the Redis adapter relays events between API instances. Its connections
 * are separate from the cache's: they keep an offline queue, so a short Redis outage delays
 * events instead of dropping them, and a single instance still delivers locally meanwhile.
 *
 * The socket lives under /v1/realtime so the frontend's same-origin /v1 proxy carries it
 * (long-polling through the proxy, WebSocket wherever the API is reached directly).
 */

export const SOCKET_PATH = "/v1/realtime";
export const STAFF_ROOM = "staff:support";

let io = null;
let adapterClients = [];

/** Every value of one cookie, in header order (a browser can hold two with the same name). */
function readCookieValues(header, name) {
  const tokens = [];
  const prefix = `${name}=`;
  for (const part of String(header || "").split(";")) {
    const pair = part.trim();
    if (!pair.startsWith(prefix)) continue;
    try {
      const value = decodeURIComponent(pair.slice(prefix.length));
      if (value && !tokens.includes(value)) tokens.push(value);
    } catch {
      // Not a token.
    }
  }
  return tokens;
}

/** The same identity attachSession + identityFromRequest would give an HTTP request. */
export async function identityFromHandshake(headers) {
  for (const token of readCookieValues(headers.cookie, env.SESSION_COOKIE_NAME)) {
    const session = await resolveSession(token);
    if (!session) continue;
    const [platform, memberships] = await Promise.all([
      loadPlatformAccess(session.user_id),
      loadAccountMemberships(session.user_id),
    ]);
    return identityFromAuth({
      user: {
        id: session.user_id,
        publicId: session.user_public_id,
        email: session.email,
        displayName: session.display_name,
        firstName: session.first_name,
        lastName: session.last_name,
        avatarUrl: session.avatar_url,
      },
      platform,
      memberships,
    });
  }
  for (const token of readCookieValues(headers.cookie, GUEST_COOKIE)) {
    const guest = await guestFromToken(token);
    if (guest) return guest;
  }
  return null;
}

async function attachRedisAdapter(server) {
  if (!env.cacheEnabled || !env.REDIS_URL) return;
  const pub = createClient({
    url: env.REDIS_URL,
    socket: { connectTimeout: 2000, reconnectStrategy: (retries) => Math.min(100 * 2 ** retries, 5000) },
  });
  const sub = pub.duplicate();
  let lastError = 0;
  for (const client of [pub, sub]) {
    client.on("error", (error) => {
      if (Date.now() - lastError > 60_000) logger.warn({ err: { code: error.code, message: error.message } }, "realtime redis unavailable");
      lastError = Date.now();
    });
  }
  adapterClients = [pub, sub];
  // A refused first connection never rejects (the reconnect strategy keeps retrying), so boot
  // must not await it: the socket server has to start either way. The adapter is attached at
  // once; until Redis answers, its commands wait in the clients' offline queue and every event
  // is still delivered to this instance's own sockets.
  const connected = Promise.all([pub.connect(), sub.connect()]).then(
    () => logger.info("realtime relaying through redis"),
    (error) => logger.warn({ err: { code: error.code, message: error.message } }, "realtime redis connect failed"),
  );
  server.adapter(createAdapter(pub, sub, { key: `${env.CACHE_PREFIX}:rt` }));
  await Promise.race([connected, waitFor(BOOT_WAIT_MS)]);
  if (!pub.isReady) logger.warn("realtime redis not reachable at boot; local delivery until it is");
}

export async function startRealtime(httpServer) {
  if (io) return io;
  const allowed = new Set(env.allowedOrigins);
  io = new Server(httpServer, {
    path: SOCKET_PATH,
    // Answer `/v1/realtime?…` as well as `/v1/realtime/?…`. The website's same-origin /v1 proxy
    // (Next.js) redirects away the trailing slash, and with it the socket got the API's 404, so
    // the live site only showed new messages after a refresh.
    addTrailingSlash: false,
    serveClient: false,
    // Cross-site WebSocket hijacking: a socket carries the session cookie, so only the site's
    // own origins may open one. A request without an Origin (a native client, a server) has no
    // ambient browser credentials to abuse.
    allowRequest: (req, callback) => {
      const origin = req.headers.origin;
      callback(null, !origin || isOriginAllowed(origin, { allowed, isProduction: env.isProduction }));
    },
    cors: {
      origin: (origin, callback) => callback(null, !origin || isOriginAllowed(origin, { allowed, isProduction: env.isProduction })),
      credentials: true,
    },
    maxHttpBufferSize: 64 * 1024,
    pingInterval: 25_000,
    pingTimeout: 20_000,
    connectionStateRecovery: { maxDisconnectionDuration: 2 * 60 * 1000 },
  });

  await attachRedisAdapter(io);

  io.use(async (socket, next) => {
    try {
      const identity = await identityFromHandshake(socket.handshake.headers);
      if (!identity) return next(new Error("unauthorized"));
      socket.data.identity = identity;
      socket.data.ref = refFor(identity);
      return next();
    } catch (error) {
      logger.warn({ err: error }, "realtime handshake failed");
      return next(new Error("unavailable"));
    }
  });

  const { registerChatSocket } = await import("../modules/chat/chat.socket.js");

  io.on("connection", (socket) => {
    const { identity, ref } = socket.data;
    socket.join(ref);
    if (canViewSupport(identity)) socket.join(STAFF_ROOM);
    const heartbeat = setInterval(() => presence.refresh(ref).catch(() => {}), presence.HEARTBEAT_MS);
    heartbeat.unref();
    socket.on("disconnect", () => clearInterval(heartbeat));
    // Presence changes go only to people who share a thread with this person.
    registerChatSocket(socket, { emitTo, presence });
  });

  logger.info({ path: SOCKET_PATH }, "realtime ready");
  return io;
}

/** Sends an event to people (refs) and, optionally, the support staff room. */
export function emitTo(refs, event, payload, { staff = false, exceptSocketId = null } = {}) {
  if (!io) return;
  const rooms = [...new Set(refs.filter(Boolean))];
  if (staff) rooms.push(STAFF_ROOM);
  if (!rooms.length) return;
  let target = io.to(rooms);
  if (exceptSocketId) target = target.except(exceptSocketId);
  target.emit(event, payload);
}

export async function stopRealtime() {
  if (!io) return;
  await new Promise((resolve) => io.close(() => resolve()));
  io = null;
  await Promise.allSettled(adapterClients.map((client) => client.quit()));
  adapterClients = [];
}

export const realtimeReady = () => Boolean(io);
