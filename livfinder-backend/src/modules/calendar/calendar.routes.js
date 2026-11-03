import { Router } from "express";
import crypto from "node:crypto";
import env from "../../config/env.js";
import { asyncHandler } from "../../middleware/errors.js";
import { writeLimiter } from "../../middleware/rateLimit.js";
import { AppError } from "../../utils/errors.js";
import { detailResponse } from "../../utils/http.js";
import { auditFromRequest } from "../system/audit.service.js";
import * as calendar from "./calendar.service.js";

export const portalCalendarRouter = Router();

const STATE_COOKIE = "livfinder_calendar_state";
const redirectUri = (req) => `${req.protocol}://${req.get("host")}/v1/portal/calendar/google/callback`;
const backToPortal = (res, result) => res.redirect(`${env.FRONTEND_URL}/portal/bookings?calendar=${result}`);

portalCalendarRouter.get(
  "/calendar",
  asyncHandler(async (req, res) => res.json(detailResponse(await calendar.connectionStatus(req.auth.user.id))))
);

portalCalendarRouter.get(
  "/calendar/google/connect",
  asyncHandler(async (req, res) => {
    if (!calendar.googleCalendarConfigured()) throw AppError.notImplemented("Google Calendar is not configured on this server.");
    const state = crypto.randomBytes(24).toString("base64url");
    res.cookie(STATE_COOKIE, state, {
      httpOnly: true,
      secure: env.isProduction,
      sameSite: "lax",
      path: "/",
      maxAge: 10 * 60 * 1000,
    });
    return res.redirect(calendar.authorizeUrl({ redirectUri: redirectUri(req), state }));
  })
);

portalCalendarRouter.get(
  "/calendar/google/callback",
  asyncHandler(async (req, res) => {
    const expected = req.cookies?.[STATE_COOKIE];
    res.clearCookie(STATE_COOKIE, { path: "/" });
    if (!expected || expected !== req.query.state) return backToPortal(res, "failed");
    // Pressing Cancel on Google's screen comes back here as `error=access_denied`.
    if (req.query.error || !req.query.code) return backToPortal(res, "declined");
    try {
      await calendar.completeConnection({ userId: req.auth.user.id, code: String(req.query.code), redirectUri: redirectUri(req) });
    } catch {
      return backToPortal(res, "failed");
    }
    await auditFromRequest(req, { action: "calendar.connected", subjectType: "user", subjectId: req.auth.user.id });
    return backToPortal(res, "connected");
  })
);

portalCalendarRouter.delete(
  "/calendar/google",
  writeLimiter,
  asyncHandler(async (req, res) => {
    await calendar.disconnect(req.auth.user.id);
    await auditFromRequest(req, { action: "calendar.disconnected", subjectType: "user", subjectId: req.auth.user.id });
    return res.json(detailResponse({ connected: false }));
  })
);
