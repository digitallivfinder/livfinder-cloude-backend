import pino from "pino";
import env from "./env.js";

// Anything whose value must never reach a log line, in any casing the source
// might use. Matches the admin System Logs redaction contract.
const REDACT_PATHS = [
  "req.headers.authorization",
  "req.headers.cookie",
  "req.headers['x-csrf-token']",
  "res.headers['set-cookie']",
  "password",
  "*.password",
  "passwordHash",
  "*.passwordHash",
  "password_hash",
  "*.password_hash",
  "currentPassword",
  "newPassword",
  "token",
  "*.token",
  "refreshToken",
  "sessionToken",
  "secret",
  "*.secret",
  "secretKey",
  "apiKey",
  "*.apiKey",
  "cardNumber",
  "cvc",
  "STRIPE_SECRET_KEY",
  "STORAGE_SECRET_KEY",
  "AWS_SECRET_ACCESS_KEY",
];

export const logger = pino({
  level: env.LOG_LEVEL,
  redact: { paths: REDACT_PATHS, censor: "[redacted]" },
  base: { service: "livfinder-api" },
  transport:
    env.isProduction || env.isTest
      ? undefined
      : { target: "pino/file", options: { destination: 1 } },
});

export default logger;
