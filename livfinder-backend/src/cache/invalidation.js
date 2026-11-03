import env from "../config/env.js";
import logger from "../config/logger.js";
import { cacheKey, onCacheReady, withRedis } from "./redis.js";
import { ALL_TAGS, TAGS, tagsForProcedure, tagsForStatement } from "./cacheTags.js";

/**
 * Tag-version invalidation.
 *
 * Each tag has a counter in Redis (`lf:tag:<tag>`). A cached response records the counters of
 * the tags it depends on as they were *before* its queries ran; it is valid only while they are
 * unchanged. Invalidating is one INCR per tag — no KEYS/SCAN, no list of dependent keys to
 * maintain, and it works across every API instance sharing the Redis. Old entries are never
 * deleted, they just stop matching and age out on their TTL.
 *
 * Counters have no TTL, so the Redis instance must evict with `volatile-*`, never `allkeys-*`:
 * an evicted counter would restart at 1 and could match entries written under the old 1.
 */

export const tagKey = (tag) => cacheKey("tag", tag);

const pending = new Set();
let flushTimer = null;
let missedWhileDown = false;
// Statements on a connection inside withTransaction: held until the commit.
const transactionScopes = new WeakMap();

// Tags sent to Redis but not yet acknowledged.
const publishing = new Set();
// A write on a connection that is not inside withTransaction may still be uncommitted when it
// is seen, so a reader could re-cache the old row after the first bump. The second bump, once
// the caller has had time to commit, discards that copy.
const UNSCOPED_REBUMP_MS = 2000;

async function flush() {
  flushTimer = null;
  if (!pending.size) return;
  const tags = [...pending];
  pending.clear();
  for (const tag of tags) publishing.add(tag);
  const ok = await withRedis(async (redis) => {
    const multi = redis.multi();
    for (const tag of tags) multi.incr(tagKey(tag));
    await multi.exec();
    return true;
  }, false);
  for (const tag of tags) publishing.delete(tag);
  if (!ok) missedWhileDown = true;
}

/**
 * Whether this process has a write on any of `tags` that Redis has not acknowledged yet. The
 * cache bypasses such reads, so a page reloaded straight after a save never sees the old copy.
 */
export function hasUnpublishedInvalidation(tags) {
  if (!pending.size && !publishing.size) return false;
  return tags.some((tag) => pending.has(tag) || publishing.has(tag));
}

export function invalidateTags(tags) {
  if (!env.cacheEnabled || !tags?.length) return;
  for (const tag of tags) pending.add(tag);
  // setImmediate batches every write issued in the same turn (a bulk import's loop) into one
  // MULTI, and still lands before the write request has finished responding.
  if (!flushTimer) flushTimer = setImmediate(flush);
}

export const invalidateAll = () => invalidateTags(ALL_TAGS.filter((tag) => tag !== TAGS.deploy));

/** Bumps every tag now and waits for it — for scripts and the boot-time deploy bump. */
export async function invalidateNow(tags = ALL_TAGS) {
  for (const tag of tags) pending.add(tag);
  clearImmediate(flushTimer);
  await flush();
}

/** Publishes whatever is waiting now — a CLI script calls this before it exits. */
export async function flushInvalidations() {
  clearImmediate(flushTimer);
  await flush();
}

// Writes that happened while Redis was unreachable were never recorded against it, so whatever
// it still holds may predate them. Treat everything as changed once it is back.
onCacheReady(async () => {
  if (!missedWhileDown) return;
  missedWhileDown = false;
  logger.info("redis back after missed invalidations; invalidating every tag");
  await invalidateNow(ALL_TAGS.filter((tag) => tag !== TAGS.deploy));
});

const isPool = (executor) => typeof executor?.getConnection === "function";

/** Called by db/query.js for every statement. Reads cost one string check. */
export function noteStatement(sql, executor) {
  if (!env.cacheEnabled) return;
  const tags = tagsForStatement(sql);
  if (tags.length) record(tags, executor);
}

export function noteProcedure(name, executor) {
  if (!env.cacheEnabled) return;
  const tags = tagsForProcedure(name);
  if (tags.length) record(tags, executor);
}

function record(tags, executor) {
  if (!executor || isPool(executor)) return invalidateTags(tags); // autocommit: already durable
  const scope = transactionScopes.get(executor);
  if (scope) {
    for (const tag of tags) scope.add(tag);
    return;
  }
  invalidateTags(tags);
  setTimeout(() => invalidateTags(tags), UNSCOPED_REBUMP_MS).unref?.();
}

/** db/transaction.js: collect the transaction's writes and publish them only on commit. */
export function beginTransactionScope(connection) {
  if (env.cacheEnabled) transactionScopes.set(connection, new Set());
}

export function endTransactionScope(connection, { committed }) {
  const scope = transactionScopes.get(connection);
  transactionScopes.delete(connection);
  if (committed && scope?.size) invalidateTags([...scope]);
}
