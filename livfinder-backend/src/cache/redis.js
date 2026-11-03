import { createClient } from "redis";
import env from "../config/env.js";
import logger from "../config/logger.js";

/**
 * The one Redis connection the API holds.
 *
 * The cache is an accelerator, never a dependency: when Redis is unset, down or slow, every
 * caller gets `null` back and reads MySQL as if the cache did not exist. Commands therefore fail
 * fast — no offline queue, and a short timeout on each call — so an outage costs a few
 * milliseconds per request rather than a hung page.
 */
let client = null;
let connecting = null;
const readyListeners = new Set();

export const cacheEnabled = () => env.cacheEnabled;
export const isCacheReady = () => Boolean(client?.isReady);
export const cacheKey = (...parts) => [env.CACHE_PREFIX, ...parts].join(":");

/** Called every time the connection becomes usable again, including after an outage. */
export function onCacheReady(listener) {
  readyListeners.add(listener);
  return () => readyListeners.delete(listener);
}

export async function connectCache() {
  if (!env.cacheEnabled) return null;
  if (client) return connecting ?? client;
  client = createClient({
    url: env.REDIS_URL,
    disableOfflineQueue: true,
    socket: {
      connectTimeout: 2000,
      // Keep retrying for as long as the process lives, backing off to one attempt every 5s.
      reconnectStrategy: (retries) => Math.min(100 * 2 ** retries, 5000),
    },
  });
  let lastError = 0;
  client.on("error", (error) => {
    // A refused connection repeats on every retry; one line a minute is enough to see it.
    if (Date.now() - lastError > 60_000) logger.warn({ err: { code: error.code, message: error.message } }, "redis unavailable");
    lastError = Date.now();
  });
  client.on("ready", () => {
    logger.info("redis ready");
    for (const listener of readyListeners) {
      Promise.resolve()
        .then(listener)
        .catch((error) => logger.error({ err: error }, "redis ready listener failed"));
    }
  });
  connecting = client
    .connect()
    .then(() => client)
    .catch((error) => {
      // The reconnect strategy keeps trying in the background.
      logger.warn({ err: { code: error.code, message: error.message } }, "redis not reachable at boot");
      return client;
    })
    .finally(() => {
      connecting = null;
    });
  return connecting;
}

export async function closeCache() {
  if (!client) return;
  const current = client;
  client = null;
  try {
    await current.close();
  } catch {
    current.destroy();
  }
}

/**
 * Runs one command against Redis, or answers `fallback` when the cache is off, disconnected,
 * failing or slower than CACHE_COMMAND_TIMEOUT_MS.
 */
export async function withRedis(run, fallback = null) {
  if (!client?.isReady) return fallback;
  let timer;
  try {
    return await Promise.race([
      run(client),
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error("redis command timed out")), env.CACHE_COMMAND_TIMEOUT_MS);
      }),
    ]);
  } catch (error) {
    logger.debug({ err: { message: error.message } }, "redis command failed");
    return fallback;
  } finally {
    clearTimeout(timer);
  }
}

/** Whether a command can be attempted at all; failures inside `withRedis` still fall back. */
export const redisClient = () => (client?.isReady ? client : null);
