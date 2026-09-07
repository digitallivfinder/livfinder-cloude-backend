import { AppError } from "../utils/errors.js";

function fieldsFromZod(error) {
  const fields = {};
  for (const issue of error.issues) {
    const path = issue.path.join(".") || "_";
    if (!fields[path]) fields[path] = issue.message;
  }
  return fields;
}

function run(schema, value, label) {
  const result = schema.safeParse(value);
  if (result.success) return result.data;
  throw AppError.validation(
    label === "body" ? "Some information is invalid." : "The request could not be understood.",
    fieldsFromZod(result.error)
  );
}

/**
 * Validates and *replaces* the request parts with the parsed values, so a
 * handler can never read an unvalidated field by accident.
 *
 * req.query is a getter on Express 5, so the parsed value goes on
 * `req.validatedQuery` and the original is left alone.
 */
export function validate({ params, query, body } = {}) {
  return (req, res, next) => {
    try {
      if (params) req.params = run(params, req.params, "params");
      if (query) req.validatedQuery = run(query, { ...req.query }, "query");
      if (body) req.body = run(body, req.body ?? {}, "body");
      next();
    } catch (error) {
      next(error);
    }
  };
}

/** The parsed query when a schema ran, the raw query otherwise. */
export function q(req) {
  return req.validatedQuery ?? req.query;
}
