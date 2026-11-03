import { createApp } from "./app.js";
import env from "./config/env.js";
import logger from "./config/logger.js";
import { closePool, pingDatabase } from "./db/pool.js";
import { getStorage } from "./config/storage.js";
import { closeCache, connectCache } from "./cache/redis.js";
import { invalidateNow } from "./cache/invalidation.js";
import { TAGS } from "./cache/cacheTags.js";
import { startRealtime, stopRealtime } from "./realtime/realtime.js";

const app = createApp();

const server = app.listen(env.PORT, async () => {
  logger.info({ port: env.PORT, env: env.NODE_ENV }, "livfinder api listening");
  try {
    const database = await pingDatabase();
    logger.info({ database: database.database, version: database.version }, "database reachable");
  } catch (error) {
    // Log and keep serving: /health/database reports the failure, and the
    // process staying up is what lets an orchestrator see the readiness signal.
    logger.error({ err: error }, "database unreachable at boot");
  }
  logger.info({ driver: getStorage().driver }, "storage ready");

  // Redis is optional: without it (or while it is down) public reads go straight to MySQL.
  if (env.cacheEnabled) {
    await connectCache();
    // Entries written by the previous build may have a different response shape.
    await invalidateNow([TAGS.deploy]);
  }

  // Live chat: the socket server shares this HTTP server, under /v1/realtime.
  try {
    await startRealtime(server);
  } catch (error) {
    logger.error({ err: error }, "realtime could not be started");
  }

  // Root category ids are hardcoded in utils/categories.js as a starting point; this checks
  // them against the database so a reseed in a different order cannot silently misfile
  // everything the service reads by root id.
  try {
    const { reconcileCategoryIds } = await import("./utils/categories.js");
    const { query } = await import("./db/query.js");
    const corrections = await reconcileCategoryIds(query);
    if (corrections.length) logger.warn({ corrections }, "root category ids differ from the source defaults");
  } catch (error) {
    logger.error({ err: error }, "root category ids could not be reconciled");
  }

  // The permission catalogue is read once and cached: it changes only by migration, and every
  // session resolve would otherwise re-query it.
  try {
    const { loadPermissionUniverse } = await import("./modules/auth/adminPermissions.js");
    const codes = await loadPermissionUniverse();
    logger.info({ permissions: codes.length }, "permission catalogue loaded");
  } catch (error) {
    logger.error({ err: error }, "permission catalogue could not be loaded");
  }
  // Time-triggered listing maintenance — expiry, stale projections, sitemap, rollup counters.
  // There was no scheduler at all, so an expired listing stayed "active" everywhere but the view.
  if (env.NODE_ENV !== "test") {
    try {
      const { startListingMaintenance } = await import("./modules/listings/listings.jobs.js");
      startListingMaintenance();
    } catch (error) {
      logger.error({ err: error }, "listing maintenance could not be started");
    }
  }
  // Time-triggered billing maintenance — no payment provider exists to report a failed renewal
  // or a missed invoice itself, so this applies that outcome once it is genuinely overdue and
  // notifies the account, instead of the account looking permanently current.
  if (env.NODE_ENV !== "test") {
    try {
      const { startBillingMaintenance } = await import("./modules/accounts/billing.jobs.js");
      startBillingMaintenance();
    } catch (error) {
      logger.error({ err: error }, "billing maintenance could not be started");
    }
  }
  // Identity documents from abandoned signup applications do not stay in storage.
  if (env.NODE_ENV !== "test") {
    const { sweepAbandonedSignupUploads } = await import("./modules/accounts/verification.service.js");
    const sweep = () =>
      sweepAbandonedSignupUploads().catch((error) => logger.error({ err: error }, "signup upload sweep failed"));
    sweep();
    setInterval(sweep, 60 * 60 * 1000).unref();

    // A package change chosen for the next billing cycle takes effect on its renewal date.
    const { applyDuePlanChanges } = await import("./modules/accounts/accounts.service.js");
    const applyPlanChanges = () =>
      applyDuePlanChanges().catch((error) => logger.error({ err: error }, "scheduled plan changes failed"));
    applyPlanChanges();
    setInterval(applyPlanChanges, 60 * 60 * 1000).unref();

    // Chat files that were uploaded but never sent.
    const { sweepPendingAttachments } = await import("./modules/chat/attachments.js");
    const { sweepEmptyConversations } = await import("./modules/chat/chat.service.js");
    // …and chats that were opened but never written in.
    const sweepChatUploads = () => {
      sweepPendingAttachments().catch((error) => logger.error({ err: error }, "chat upload sweep failed"));
      sweepEmptyConversations().catch((error) => logger.error({ err: error }, "empty chat sweep failed"));
    };
    setInterval(sweepChatUploads, 60 * 60 * 1000).unref();
  }
  // Bulk listing imports run in the background; this resumes any a restart interrupted.
  if (env.NODE_ENV !== "test") {
    try {
      const { startImportRunner } = await import("./modules/imports/importRunner.js");
      startImportRunner();
    } catch (error) {
      logger.error({ err: error }, "listing import runner could not be started");
    }
    // Webhooks (0064): deliver lead events to companies' endpoints, with retries.
    try {
      const { startWebhookWorker } = await import("./modules/leads/webhooks.service.js");
      startWebhookWorker();
    } catch (error) {
      logger.error({ err: error }, "webhook worker could not be started");
    }
  }
});

async function shutdown(signal) {
  logger.info({ signal }, "shutting down");
  server.close(async () => {
    await Promise.allSettled([stopRealtime(), closePool(), closeCache()]);
    process.exit(0);
  });
  // Do not let a hung connection hold the process open forever.
  setTimeout(() => process.exit(1), 10_000).unref();
}

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));
process.on("unhandledRejection", (reason) => logger.error({ err: reason }, "unhandled rejection"));
process.on("uncaughtException", (error) => {
  logger.fatal({ err: error }, "uncaught exception");
  process.exit(1);
});

export default server;
