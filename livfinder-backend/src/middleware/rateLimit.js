import rateLimit, { ipKeyGenerator } from "express-rate-limit";
import env from "../config/env.js";
import { AppError } from "../utils/errors.js";

function handler(req, res, next) {
  next(AppError.tooManyRequests());
}

const shared = {
  standardHeaders: "draft-7",
  legacyHeaders: false,
  handler,
  // Tests would otherwise trip the limiter across cases.
  skip: () => env.isTest,
};

/**
 * The general read budget.
 *
 * Session resolution is deliberately excluded: it is counted by `sessionLimiter`
 * instead. Sharing one budget meant a visitor's identity checks competed with their
 * page reads, and a burst spent the allowance on `/v1/auth/session` alone.
 */
export const generalLimiter = rateLimit({
  ...shared,
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  limit: env.RATE_LIMIT_MAX,
  skip: (req) => env.isTest || req.path === "/v1/auth/session",
});

/**
 * Session resolution. One call per server-rendered page, so the budget is sized for
 * navigation rather than for writes. Exceeding it still returns 429 — never a 500 —
 * and the frontend degrades to a retry state.
 */
export const sessionLimiter = rateLimit({
  ...shared,
  windowMs: env.RATE_LIMIT_WINDOW_MS,
  limit: env.SESSION_RATE_LIMIT_MAX,
});

/**
 * Login, signup, password reset. Keyed on the IP *and* the submitted email, so
 * one attacker cannot lock out an account for everyone by guessing at it, and
 * a distributed guess against one account is still counted together.
 */
export const authLimiter = rateLimit({
  ...shared,
  windowMs: 15 * 60 * 1000,
  limit: env.AUTH_RATE_LIMIT_MAX,
  keyGenerator: (req) => {
    const email = String(req.body?.email || "").toLowerCase().trim();
    return `${ipKeyGenerator(req.ip)}|${email}`;
  },
});

export const writeLimiter = rateLimit({
  ...shared,
  windowMs: 60 * 1000,
  limit: 60,
});

export const uploadLimiter = rateLimit({
  ...shared,
  windowMs: 60 * 1000,
  limit: 40,
});
