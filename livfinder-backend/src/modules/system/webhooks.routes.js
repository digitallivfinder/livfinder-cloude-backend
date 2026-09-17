import { Router } from "express";
import express from "express";
import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { handleStripeCheckoutCompleted } from "./payments.service.js";

/**
 * Provider webhooks. Mounted in app.js *before* the global `express.json()` — Stripe's
 * signature check needs the exact raw request bytes, and a body already parsed to an object
 * cannot be re-serialized back to what was actually signed. `express.raw()` here is scoped to
 * this one route, so every other route downstream still gets its normal JSON body.
 */
const router = Router();

router.post("/stripe", express.raw({ type: "application/json" }), async (req, res) => {
  if (!env.STRIPE_WEBHOOK_SECRET || !env.STRIPE_SECRET_KEY) {
    logger.warn("Stripe webhook received but STRIPE_WEBHOOK_SECRET/STRIPE_SECRET_KEY are not configured");
    return res.status(503).json({ error: { code: "NOT_CONFIGURED", message: "Payments are not configured." } });
  }
  const signature = req.headers["stripe-signature"];
  let event;
  try {
    const { default: Stripe } = await import("stripe");
    const stripe = new Stripe(env.STRIPE_SECRET_KEY);
    event = stripe.webhooks.constructEvent(req.body, signature, env.STRIPE_WEBHOOK_SECRET);
  } catch (error) {
    logger.warn({ err: error }, "stripe webhook signature verification failed");
    return res.status(400).json({ error: { code: "INVALID_SIGNATURE", message: "Webhook signature verification failed." } });
  }

  try {
    if (event.type === "checkout.session.completed") {
      await handleStripeCheckoutCompleted(event.data.object);
    }
  } catch (error) {
    // Acknowledge receipt regardless: Stripe retries a non-2xx response for up to three days,
    // and a payment that already failed to settle once needs an operator, not a retry storm.
    logger.error({ err: error, eventType: event.type }, "stripe webhook handler failed");
  }
  return res.json({ received: true });
});

export default router;
