import { createApp } from "./app.js";
import env from "./config/env.js";
import logger from "./config/logger.js";
import { closePool, pingDatabase } from "./db/pool.js";
import { getStorage } from "./config/storage.js";

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
});

async function shutdown(signal) {
  logger.info({ signal }, "shutting down");
  server.close(async () => {
    await closePool();
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
