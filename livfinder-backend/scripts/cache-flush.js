#!/usr/bin/env node
/**
 * Invalidates every cached public response.
 *
 * The API invalidates by itself on every write it makes. Run this after changing data any other
 * way — db/tools/load.sh, a migration, SQL typed into a client — so the site stops serving the
 * old copies before their TTL runs out.
 *
 *   npm run cache:flush
 */
import env from "../src/config/env.js";
import logger from "../src/config/logger.js";
import { closeCache, connectCache, isCacheReady } from "../src/cache/redis.js";
import { invalidateNow } from "../src/cache/invalidation.js";
import { ALL_TAGS } from "../src/cache/cacheTags.js";

if (!env.REDIS_URL) {
  logger.info("REDIS_URL is not set; there is no cache to flush");
  process.exit(0);
}
await connectCache();
if (!isCacheReady()) {
  logger.error("redis is not reachable");
  await closeCache();
  process.exit(1);
}
await invalidateNow(ALL_TAGS);
logger.info({ tags: ALL_TAGS }, "public cache invalidated");
await closeCache();
process.exit(0);
