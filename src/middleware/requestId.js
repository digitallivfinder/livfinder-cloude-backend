import { requestId as makeRequestId } from "../utils/ids.js";

const SAFE_ID = /^[A-Za-z0-9._:-]{1,128}$/;

/**
 * Every request carries a trace id. It goes out on X-Request-ID, into every log
 * line, and into the error envelope so a user-reported failure can be found in
 * the admin System Logs screen.
 */
export function requestIdMiddleware(req, res, next) {
  const inbound = req.get("x-request-id");
  req.id = inbound && SAFE_ID.test(inbound) ? inbound : makeRequestId();
  res.setHeader("X-Request-ID", req.id);
  next();
}

export default requestIdMiddleware;
