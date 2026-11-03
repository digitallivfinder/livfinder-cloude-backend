import { createHash } from "node:crypto";
import env from "../config/env.js";
import logger from "../config/logger.js";
import { cacheKey, redisClient, withRedis } from "../cache/redis.js";
import { hasUnpublishedInvalidation, tagKey } from "../cache/invalidation.js";
import { ALL_TAGS, TAGS } from "../cache/cacheTags.js";

/**
 * Redis response cache for GET /v1/public/*.
 *
 * Nothing under /v1/public reads req.auth, so one copy of a response serves every visitor.
 * An entry is reused while the tag counters it was stamped with still match (see
 * cache/invalidation.js), so a write anywhere in the API takes effect on the next request.
 *
 *   HIT    fresh entry, the route never runs
 *   STALE  older than CACHE_PUBLIC_TTL_SECONDS but not invalidated; served while the single
 *          request holding the refresh lock rebuilds it (no stampede when a hot key expires)
 *   MISS   rebuilt by this request; concurrent misses on this instance wait for it
 *   BYPASS cache unavailable or the route is not cached
 *
 * The cached body is the final JSON string, after legacyMediaRewrite, so a hit sends identical
 * bytes to the miss that stored it.
 */

/** Routes reading one slice depend on fewer tags, so fewer writes invalidate them. */
const ROUTE_TAGS = [
  [/^\/(blogs|editorial|articles|authors)(\/|$)/, [TAGS.editorial, TAGS.organizations]],
  [/^\/(country-codes)(\/|$)/, [TAGS.locations]],
  [/^\/(feed-formats|listing-formats)(\/|$)/, [TAGS.taxonomy]],
];

export function tagsForPath(path) {
  const tags = ROUTE_TAGS.find(([pattern]) => pattern.test(path))?.[1] ?? ALL_TAGS;
  return tags.includes(TAGS.deploy) ? tags : [...tags, TAGS.deploy];
}

/** Same URL in any query order is one entry. */
export function requestCacheKey(req) {
  const url = new URL(req.originalUrl, "http://cache.local");
  const params = [...url.searchParams.entries()].sort(([a, av], [b, bv]) => (a === b ? (av < bv ? -1 : 1) : a < b ? -1 : 1));
  const normalised = `${url.pathname}?${new URLSearchParams(params).toString()}`;
  return cacheKey("pub", createHash("sha1").update(normalised).digest("base64url"));
}

const inflight = new Map();

/**
 * An entry is one string: a small JSON header line, then the response body exactly as it was
 * sent. A hit writes those bytes straight out — no JSON.parse, no re-serialising, no second pass
 * of the media rewrite — which is most of what a hit would otherwise cost on a large page.
 */
function decode(raw) {
  if (!raw) return null;
  const split = raw.indexOf("\n");
  if (split < 0) return null;
  try {
    return { ...JSON.parse(raw.slice(0, split)), body: raw.slice(split + 1) };
  } catch {
    return null;
  }
}

const encode = (meta, body) => `${JSON.stringify(meta)}\n${body}`;

function send(res, entry, state) {
  res.setHeader("X-Cache", state);
  res.setHeader("Age", String(Math.max(0, Math.round((Date.now() - entry.t) / 1000))));
  if (entry.c) res.setHeader("Cache-Control", entry.c);
  // res.send still sets the ETag and answers a matching If-None-Match with 304.
  res.status(200).type("application/json; charset=utf-8").send(entry.body);
}

export function publicResponseCache() {
  if (!env.cacheEnabled) return (req, res, next) => next();

  const ttlMs = env.CACHE_PUBLIC_TTL_SECONDS * 1000;
  const lifetimeSeconds = env.CACHE_PUBLIC_TTL_SECONDS + env.CACHE_STALE_SECONDS;

  return async function publicCache(req, res, next) {
    if (req.method !== "GET" || !redisClient()) {
      res.setHeader("X-Cache", "BYPASS");
      return next();
    }

    const key = requestCacheKey(req);
    const lockKey = `${key}:lock`;
    const tags = tagsForPath(req.path);
    if (hasUnpublishedInvalidation(tags)) {
      res.setHeader("X-Cache", "BYPASS");
      return next();
    }
    // One round trip: the entry and the counters it must still match.
    const lookup = await withRedis((redis) => Promise.all([redis.get(key), redis.mGet(tags.map(tagKey))]));
    if (!lookup) {
      res.setHeader("X-Cache", "BYPASS");
      return next();
    }
    const [raw, versionList] = lookup;
    const versions = versionList.map((value) => value ?? "0");
    const entry = decode(raw);
    const valid = entry && entry.v?.length === versions.length && entry.v.every((value, index) => value === versions[index]);

    let ownsLock = false;
    if (valid) {
      if (Date.now() - entry.t < ttlMs) return send(res, entry, "HIT");
      // Expired by age only. Whoever takes the lock rebuilds; everyone else keeps the old copy.
      ownsLock = (await withRedis((redis) => redis.set(lockKey, "1", { NX: true, PX: 10_000 }))) === "OK";
      if (!ownsLock) return send(res, entry, "STALE");
    } else {
      // Invalid or absent. Requests already waiting on this instance share one rebuild.
      const running = inflight.get(key);
      if (running) {
        const shared = await running;
        if (shared) return send(res, shared, "HIT");
        res.setHeader("X-Cache", "MISS");
        return next();
      }
    }

    let settle;
    inflight.set(key, new Promise((resolve) => (settle = resolve)));
    let captured = null;
    const finish = () => {
      if (!settle) return;
      inflight.delete(key);
      settle(captured);
      settle = null;
      if (ownsLock) withRedis((redis) => redis.del(lockKey));
    };
    res.on("finish", finish);
    res.on("close", finish);

    // res.json (and legacyMediaRewrite around it) ends in res.send with the final string.
    const originalSend = res.send;
    res.send = function sendAndCache(body) {
      res.send = originalSend;
      const type = String(res.getHeader("Content-Type") || "");
      if (res.statusCode === 200 && typeof body === "string" && type.includes("json")) {
        // Stamped with the counters read *before* the route queried MySQL: a write that lands
        // meanwhile bumps them, so this copy is already invalid rather than silently stale.
        const meta = { t: Date.now(), v: versions, c: res.getHeader("Cache-Control") || undefined };
        const serialised = encode(meta, body);
        if (Buffer.byteLength(serialised) <= env.CACHE_MAX_ENTRY_BYTES) {
          captured = { ...meta, body };
          withRedis((redis) => redis.set(key, serialised, { EX: lifetimeSeconds }));
        } else {
          logger.debug({ path: req.path }, "public response too large to cache");
        }
      }
      res.setHeader("X-Cache", "MISS");
      return originalSend.call(res, body);
    };
    return next();
  };
}

export default publicResponseCache;
