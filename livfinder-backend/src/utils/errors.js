/**
 * The single error type the API surfaces. Everything else is caught by the
 * error middleware and reported as an opaque INTERNAL_ERROR with a trace id.
 */
export class AppError extends Error {
  constructor(message, { status = 500, code = "INTERNAL_ERROR", fields, expose = true, cause } = {}) {
    super(message, cause ? { cause } : undefined);
    this.name = "AppError";
    this.status = status;
    this.code = code;
    this.fields = fields;
    // `expose` false means the message is for the log, not the browser.
    this.expose = expose;
  }

  static badRequest(message = "The request could not be understood.", fields) {
    return new AppError(message, { status: 400, code: "BAD_REQUEST", fields });
  }

  static validation(message = "Some information is invalid.", fields) {
    return new AppError(message, { status: 422, code: "VALIDATION_ERROR", fields });
  }

  static unauthorized(message = "You need to sign in to continue.") {
    return new AppError(message, { status: 401, code: "UNAUTHENTICATED" });
  }

  static forbidden(message = "You do not have access to this resource.") {
    return new AppError(message, { status: 403, code: "FORBIDDEN" });
  }

  static notFound(message = "The requested resource was not found.") {
    return new AppError(message, { status: 404, code: "NOT_FOUND" });
  }

  static conflict(message = "That change conflicts with the current state.", fields) {
    return new AppError(message, { status: 409, code: "CONFLICT", fields });
  }

  static payloadTooLarge(message = "The uploaded file is too large.") {
    return new AppError(message, { status: 413, code: "PAYLOAD_TOO_LARGE" });
  }

  static unsupportedMedia(message = "That file type is not supported.") {
    return new AppError(message, { status: 415, code: "UNSUPPORTED_MEDIA_TYPE" });
  }

  static tooManyRequests(message = "Too many requests. Try again shortly.") {
    return new AppError(message, { status: 429, code: "RATE_LIMITED" });
  }

  static notImplemented(message = "That capability is not configured on this server.") {
    return new AppError(message, { status: 501, code: "NOT_IMPLEMENTED" });
  }

  static serviceUnavailable(message = "A dependency is unavailable. Try again shortly.") {
    return new AppError(message, { status: 503, code: "SERVICE_UNAVAILABLE" });
  }

  static internal(message = "Something went wrong on our side.", { cause } = {}) {
    return new AppError(message, { status: 500, code: "INTERNAL_ERROR", expose: false, cause });
  }
}

export default AppError;
