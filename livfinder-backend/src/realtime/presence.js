import { cacheKey, withRedis } from "../cache/redis.js";

/**
 * Who is online, across API instances.
 *
 * Each person has a counter of open sockets in Redis (`lf:online:<ref>`). Every socket refreshes
 * its TTL on a heartbeat, so an instance that dies without decrementing is forgotten within
 * ONLINE_TTL. Last seen is written to Redis on the last disconnect; it is not written to `users`,
 * whose writes invalidate the public cache.
 *
 * Without Redis, an in-process map gives the same answers for a single instance.
 */

export const HEARTBEAT_MS = 45_000;
const ONLINE_TTL_SECONDS = 120;
const SEEN_TTL_SECONDS = 30 * 24 * 60 * 60;

const local = new Map();
const localSeen = new Map();

const onlineKey = (ref) => cacheKey("online", ref);
const seenKey = (ref) => cacheKey("seen", ref);

/** Returns true when this is the person's first open socket. */
export async function connected(ref) {
  local.set(ref, (local.get(ref) ?? 0) + 1);
  const count = await withRedis(async (redis) => {
    const value = await redis.incr(onlineKey(ref));
    await redis.expire(onlineKey(ref), ONLINE_TTL_SECONDS);
    return value;
  });
  return (count ?? local.get(ref)) === 1;
}

export async function refresh(ref) {
  await withRedis((redis) => redis.expire(onlineKey(ref), ONLINE_TTL_SECONDS));
}

/** Returns true when that was the person's last open socket. */
export async function disconnected(ref) {
  const next = Math.max(0, (local.get(ref) ?? 1) - 1);
  if (next) local.set(ref, next);
  else local.delete(ref);
  const now = new Date().toISOString();
  const count = await withRedis(async (redis) => {
    const value = await redis.decr(onlineKey(ref));
    if (value <= 0) {
      await redis.del(onlineKey(ref));
      await redis.set(seenKey(ref), now, { EX: SEEN_TTL_SECONDS });
    }
    return value;
  });
  const offline = (count ?? next) <= 0;
  if (offline) localSeen.set(ref, now);
  return offline;
}

/** `{ [ref]: { online, lastSeenAt } }` for the refs asked about. */
export async function lookup(refs) {
  const unique = [...new Set(refs.filter(Boolean))];
  if (!unique.length) return {};
  const fromRedis = await withRedis(async (redis) => {
    const [online, seen] = await Promise.all([redis.mGet(unique.map(onlineKey)), redis.mGet(unique.map(seenKey))]);
    return { online, seen };
  });
  const result = {};
  unique.forEach((ref, index) => {
    const online = fromRedis ? Number(fromRedis.online[index] ?? 0) > 0 : (local.get(ref) ?? 0) > 0;
    const lastSeenAt = fromRedis ? fromRedis.seen[index] ?? null : localSeen.get(ref) ?? null;
    result[ref] = { online, lastSeenAt: online ? null : lastSeenAt };
  });
  return result;
}

export async function isOnline(ref) {
  return Boolean((await lookup([ref]))[ref]?.online);
}
