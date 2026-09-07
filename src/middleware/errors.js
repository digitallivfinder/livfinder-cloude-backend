import { ZodError } from "zod";
import { AppError } from "../utils/errors.js";
import logger from "../config/logger.js";
import env from "../config/env.js";

export function notFoundHandler(req, res, next) {
  next(AppError.notFound(`No route matches ${req.method} ${req.path}.`));
}

function fieldsFromZod(error) {
  const fields = {};
  for (const issue of error.issues) {
    const path = issue.path.join(".") || "_";
    if (!fields[path]) fields[path] = issue.message;
  }
  return fields;
}

// eslint-disable-next-line no-unused-vars -- Express identifies error handlers by arity.
export function errorHandler(error, req, res, next) {
  let appError = error;

  if (error instanceof ZodError) {
    appError = AppError.validation("Some information is invalid.", fieldsFromZod(error));
  } else if (error?.type === "entity.too.large") {
    appError = AppError.payloadTooLarge("The request body is too large.");
  } else if (error?.type === "entity.parse.failed") {
    appError = AppError.badRequest("The request body is not valid JSON.");
  } else if (error?.code === "LIMIT_FILE_SIZE") {
    appError = AppError.payloadTooLarge("The uploaded file is too large.");
  } else if (error?.code === "LIMIT_UNEXPECTED_FILE") {
    appError = AppError.badRequest("Unexpected file field in the upload.");
  } else if (!(error instanceof AppError)) {
    appError = AppError.internal(undefined, { cause: error });
  }

  const status = appError.status || 500;
  const logPayload = {
    traceId: req.id,
    status,
    code: appError.code,
    method: req.method,
    path: req.originalUrl,
    userId: req.auth?.user?.id ?? null,
    err: {
      message: appError.message,
      cause: appError.cause?.message,
      stack: env.isProduction ? undefined : (appError.cause?.stack || appError.stack),
    },
  };
  if (status >= 500) logger.error(logPayload, "request failed");
  else logger.warn(logPayload, "request rejected");

  const body = {
    error: {
      code: appError.code,
      // A 5xx never leaks the underlying message; a 4xx is written for a user.
      message: appError.expose && status < 500 ? appError.message : defaultMessage(status),
      traceId: req.id,
    },
  };
  if (appError.fields && Object.keys(appError.fields).length) {
    body.error.fields = appError.fields;
  }

  if (res.headersSent) return next(error);
  return res.status(status).json(body);
}

function defaultMessage(status) {
  if (status === 401) return "You need to sign in to continue.";
  if (status === 403) return "You do not have access to this resource.";
  if (status === 404) return "The requested resource was not found.";
  if (status === 429) return "Too many requests. Try again shortly.";
  if (status === 503) return "A dependency is unavailable. Try again shortly.";
  return "Something went wrong on our side.";
}

/** Wraps an async handler so a rejected promise reaches the error middleware. */
export function asyncHandler(handler) {
  return (req, res, next) => Promise.resolve(handler(req, res, next)).catch(next);
}
