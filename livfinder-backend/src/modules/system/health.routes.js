import { Router } from "express";
import { pingDatabase } from "../../db/pool.js";
import { getStorage } from "../../config/storage.js";
import env from "../../config/env.js";
import { asyncHandler } from "../../middleware/errors.js";
import { cacheEnabled, withRedis } from "../../cache/redis.js";

const router = Router();
const startedAt = Date.now();

/** Liveness: the process is up. Never touches the database. */
router.get("/", (req, res) => {
  res.json({
    data: {
      status: "ok",
      service: "livfinder-api",
      environment: env.NODE_ENV,
      uptimeSeconds: Math.round((Date.now() - startedAt) / 1000),
      timestamp: new Date().toISOString(),
    },
  });
});

/** Readiness: the database answers. Reported separately on purpose. */
router.get(
  "/database",
  asyncHandler(async (req, res) => {
    try {
      const result = await pingDatabase();
      res.json({
        data: {
          status: "ok",
          database: result.database,
          serverVersion: result.version,
          timestamp: new Date().toISOString(),
        },
      });
    } catch (error) {
      // The reason stays in the log; the response says only that it is down.
      req.log?.error({ err: error }, "database health check failed");
      res.status(503).json({
        error: {
          code: "DATABASE_UNAVAILABLE",
          message: "The database is not reachable.",
          traceId: req.id,
        },
      });
    }
  })
);

router.get("/storage", (req, res) => {
  res.json({ data: { status: "ok", driver: getStorage().driver } });
});

/** The public response cache. "disabled" and "unavailable" are not failures: reads use MySQL. */
router.get(
  "/cache",
  asyncHandler(async (req, res) => {
    if (!cacheEnabled()) return res.json({ data: { status: "disabled" } });
    const started = Date.now();
    const pong = await withRedis((redis) => redis.ping());
    res.json({
      data: pong === "PONG" ? { status: "ok", latencyMs: Date.now() - started } : { status: "unavailable" },
    });
  })
);

export default router;
