import express from "express";
import cookieParser from "cookie-parser";
import pinoHttp from "pino-http";
import env from "./config/env.js";
import logger from "./config/logger.js";
import { requestIdMiddleware } from "./middleware/requestId.js";
import { errorHandler, notFoundHandler } from "./middleware/errors.js";
import { securityHeaders, corsMiddleware } from "./middleware/security.js";
import { generalLimiter } from "./middleware/rateLimit.js";
import { attachSession } from "./middleware/auth.js";
import { csrfProtection, csrfTokenRoute } from "./middleware/csrf.js";
import healthRouter from "./modules/system/health.routes.js";
import publicRouter from "./modules/public/public.routes.js";
import projectsPublicRouter from "./modules/projects/projects.routes.js";
import authRouter from "./modules/auth/auth.routes.js";
import accountsRouter from "./modules/accounts/accounts.routes.js";
import mediaRouter, { publicRouter as mediaPublicRouter } from "./modules/media/media.routes.js";
import portalRouter from "./modules/portal/portal.routes.js";
import adminRouter from "./modules/admin/admin.routes.js";
import engagementRouter from "./modules/engagement/engagement.routes.js";
import { legacyMediaRewrite } from "./middleware/legacyMedia.js";

export function createApp() {
  const app = express();

  if (env.TRUST_PROXY) app.set("trust proxy", 1);
  app.disable("x-powered-by");

  app.use(requestIdMiddleware);
  app.use(securityHeaders());
  app.use(corsMiddleware());
  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => req.id,
      autoLogging: { ignore: (req) => req.url.startsWith("/health") },
      customLogLevel: (req, res, error) => (error || res.statusCode >= 500 ? "error" : res.statusCode >= 400 ? "warn" : "info"),
      serializers: {
        req: (req) => ({ method: req.method, url: req.url }),
        res: (res) => ({ statusCode: res.statusCode }),
      },
    })
  );

  // Health checks answer before the body parsers and the limiter so a probe
  // still works when the API is under load.
  app.use("/health", healthRouter);

  /**
   * The API root. This is not a website — opening the API port in a browser used to return a bare
   * "no route matches GET /", which reads like a broken deployment rather than the API answering
   * correctly. This says what the service is and where the site actually lives.
   */
  app.get("/", (req, res) =>
    res.json({
      data: {
        service: "livfinder-api",
        status: "ok",
        message: "This is the LivFinder API. The website runs separately and calls this service.",
        website: env.FRONTEND_URL,
        endpoints: {
          health: "/health",
          publicListings: "/v1/public/listings",
          media: "/media",
          auth: "/v1/auth/session",
        },
      },
    })
  );

  app.use(express.json({ limit: env.BODY_LIMIT }));
  app.use(express.urlencoded({ extended: false, limit: env.BODY_LIMIT }));
  app.use(cookieParser());
  app.use(generalLimiter);
  app.use(attachSession);

  app.get("/v1/csrf-token", csrfTokenRoute);

  // Media reads are public GETs and are mounted before CSRF; the router applies
  // its own protection to the write paths.
  app.use("/media", mediaPublicRouter);

  // Seeded image URLs point at a CDN host that only exists in a deployed environment; this
  // rewrites them on the way out. See middleware/legacyMedia.js.
  app.use(legacyMediaRewrite);

  app.use(csrfProtection);

  // Projects owns /v1/public/projects and /v1/public/developers. Mounted first
  // because the general public router ends in a `/:category/…` catch-all that
  // would otherwise answer /projects/facets as a category named "projects".
  app.use("/v1/public", projectsPublicRouter);
  app.use("/v1/public", publicRouter);
  app.use("/v1/auth", authRouter);
  app.use("/v1/accounts", accountsRouter);
  app.use("/v1/media", mediaRouter);
  app.use("/v1/portal", portalRouter);
  app.use("/v1/admin", adminRouter);
  app.use("/v1", engagementRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

export default createApp;
