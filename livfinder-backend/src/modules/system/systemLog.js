import { execute } from "../../db/query.js";
import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { withoutSecret } from "../../utils/redactUrl.js";

/**
 * Writes a failed request to `system_logs`, which the admin's System Logs → Errors screen reads.
 *
 * Fire-and-forget: logging must never turn one failure into two, so a write that fails (the
 * database being the thing that is down, say) is only written to the process log.
 */
export function recordSystemError({ req, status, appError }) {
  if (env.isTest) return;
  const cause = appError.cause instanceof Error ? appError.cause : null;
  const message = String(cause?.message || appError.message || "Request failed").slice(0, 1000);
  const context = {
    code: appError.code ?? null,
    path: withoutSecret(req.originalUrl),
    userAgent: String(req.get?.("user-agent") ?? "").slice(0, 300) || null,
  };
  execute(
    `INSERT INTO system_logs
       (occurred_at, level, channel, message, context, exception_class, stack_trace, request_id,
        user_id, url, http_method, http_status)
     VALUES (NOW(3), ?, 'api', ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      status >= 500 ? "error" : "warning",
      message,
      JSON.stringify(context),
      String(cause?.name || appError.code || "Error").slice(0, 191),
      String(cause?.stack || appError.stack || "").slice(0, 60000) || null,
      typeof req.id === "string" && req.id.length === 26 ? req.id : null,
      req.auth?.user?.id ?? null,
      withoutSecret(req.originalUrl).slice(0, 700),
      req.method,
      status,
    ]
  ).catch((error) => logger.warn({ err: error?.message }, "could not write system_logs"));
}
