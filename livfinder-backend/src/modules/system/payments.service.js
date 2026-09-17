import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute, queryOne } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { ulid } from "../../utils/ids.js";
import { AppError } from "../../utils/errors.js";
import { notifyInvoicePaid } from "./notifications.service.js";

/**
 * Payment adapter for paying an outstanding invoice.
 *
 * Same shape as `mail.service.js`'s driver switch: the "mock" driver is a real, working payment
 * path — it records a genuine `payment_intents` row and a genuine `payments` row and marks the
 * invoice paid, all in this database — it just settles instantly instead of going anywhere.
 * That's what LivFinder runs on with no Stripe keys configured, and it's how this was verified
 * end to end without any. Point PAYMENTS_DRIVER at "stripe" and set STRIPE_SECRET_KEY /
 * STRIPE_WEBHOOK_SECRET to actually charge a card (in Stripe's test mode with test keys, or for
 * real with live ones) — `webhooks.routes.js` completes the invoice once Stripe confirms it.
 */

function isPayable(invoice) {
  return ["open", "past_due", "partially_paid"].includes(invoice.status);
}

async function loadPayableInvoice({ invoiceId, accountId }) {
  const invoice = await queryOne("SELECT * FROM invoices WHERE id = ? AND account_id = ?", [invoiceId, accountId]);
  if (!invoice) throw AppError.notFound("That invoice was not found.");
  if (!isPayable(invoice)) throw AppError.conflict("This invoice is not payable.", { status: invoice.status });
  return invoice;
}

/** Writes the `payment_intents` row every driver starts from. */
async function openPaymentIntent({ invoice, accountId, userId, providerIntentId = null }, connection) {
  const publicId = ulid();
  const result = await execute(
    `INSERT INTO payment_intents
       (public_id, reference, account_id, user_id, amount, currency_code, purpose, invoice_id,
        description, status, provider_intent_id, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, 'subscription', ?, ?, ?, ?, NOW(3), NOW(3))`,
    [
      publicId,
      `PI-${publicId.slice(-12)}`,
      accountId,
      userId ?? null,
      invoice.amount_due,
      invoice.currency_code,
      invoice.id,
      `Invoice ${invoice.invoice_number}`,
      providerIntentId ? "processing" : "created",
      providerIntentId,
    ],
    connection
  );
  return result.insertId;
}

/** Settles the intent, records the payment, and marks the invoice paid — the one place every driver ends up. */
async function settleInvoicePayment({ invoice, accountId, userId, intentId, provider, providerPaymentId = null }) {
  await withTransaction(async (connection) => {
    await execute(
      "UPDATE payment_intents SET status = 'succeeded', amount_captured = amount, succeeded_at = NOW(3), updated_at = NOW(3) WHERE id = ?",
      [intentId],
      connection
    );
    const paymentPublicId = ulid();
    await execute(
      `INSERT INTO payments
         (public_id, reference, account_id, payment_intent_id, invoice_id, subscription_id, user_id,
          amount, currency_code, net_amount, status, payment_type, provider, provider_payment_id, paid_at, captured_at, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'succeeded', 'subscription', ?, ?, NOW(3), NOW(3), NOW(3), NOW(3))`,
      [
        paymentPublicId,
        `PAY-${paymentPublicId.slice(-12)}`,
        accountId,
        intentId,
        invoice.id,
        invoice.subscription_id,
        userId ?? null,
        invoice.amount_due,
        invoice.currency_code,
        invoice.amount_due,
        provider,
        providerPaymentId,
      ],
      connection
    );
    await execute(
      "UPDATE invoices SET status = 'paid', amount_paid = total, amount_due = 0, paid_at = NOW(3), updated_at = NOW(3) WHERE id = ?",
      [invoice.id],
      connection
    );
  });
  await notifyInvoicePaid({ accountId, invoice });
}

async function mockCheckout({ invoice, accountId, userId }) {
  const intentId = await openPaymentIntent({ invoice, accountId, userId });
  await settleInvoicePayment({ invoice, accountId, userId, intentId, provider: "mock" });
  logger.info({ invoiceId: invoice.id, accountId }, "mock payment settled");
  // No external checkout page exists to send the browser to — the caller redirects
  // straight back to Billing & Plans, where the invoice already shows as paid.
  return { checkoutUrl: null, paid: true };
}

async function stripeCheckout({ invoice, accountId, userId, successUrl, cancelUrl }) {
  if (!env.STRIPE_SECRET_KEY) {
    logger.warn("PAYMENTS_DRIVER=stripe but STRIPE_SECRET_KEY is unset — falling back to the mock driver");
    return mockCheckout({ invoice, accountId, userId });
  }
  const { default: Stripe } = await import("stripe");
  const stripe = new Stripe(env.STRIPE_SECRET_KEY);
  const intentId = await openPaymentIntent({ invoice, accountId, userId });
  const session = await stripe.checkout.sessions.create({
    mode: "payment",
    payment_method_types: ["card"],
    line_items: [
      {
        price_data: {
          currency: invoice.currency_code.toLowerCase(),
          product_data: { name: `LivFinder invoice ${invoice.invoice_number}` },
          unit_amount: Math.round(Number(invoice.amount_due) * 100),
        },
        quantity: 1,
      },
    ],
    success_url: successUrl,
    cancel_url: cancelUrl,
    // The webhook is the only place a Stripe payment is ever marked settled — the browser
    // returning to `successUrl` proves nothing on its own, since that URL is just a redirect
    // the customer's browser was told to visit.
    metadata: { invoicePublicId: invoice.public_id, invoiceId: String(invoice.id), accountId: String(accountId), paymentIntentId: String(intentId) },
  });
  await execute("UPDATE payment_intents SET provider_intent_id = ?, status = 'processing', updated_at = NOW(3) WHERE id = ?", [session.id, intentId]);
  return { checkoutUrl: session.url, paid: false };
}

/** Starts (and, for the mock driver, finishes) paying an invoice. */
export async function createInvoiceCheckout({ invoiceId, accountId, userId, successUrl, cancelUrl }) {
  const invoice = await loadPayableInvoice({ invoiceId, accountId });
  if (env.PAYMENTS_DRIVER === "stripe") {
    return stripeCheckout({ invoice, accountId, userId, successUrl, cancelUrl });
  }
  return mockCheckout({ invoice, accountId, userId });
}

/** `checkout.session.completed` — the only Stripe event this integration acts on. */
export async function handleStripeCheckoutCompleted(session) {
  const invoiceId = Number(session.metadata?.invoiceId);
  const accountId = Number(session.metadata?.accountId);
  const intentId = Number(session.metadata?.paymentIntentId);
  if (!invoiceId || !accountId || !intentId) {
    logger.warn({ sessionId: session.id }, "stripe checkout completed with no invoice metadata — ignored");
    return;
  }
  const invoice = await queryOne("SELECT * FROM invoices WHERE id = ? AND account_id = ?", [invoiceId, accountId]);
  if (!invoice || !isPayable(invoice)) {
    // Already settled (a retried webhook delivery) or the invoice moved on since checkout
    // started — either way, applying it again would double-count the payment.
    logger.info({ invoiceId, accountId }, "stripe checkout completed for an invoice that is no longer payable — skipped");
    return;
  }
  await settleInvoicePayment({
    invoice,
    accountId,
    userId: null,
    intentId,
    provider: "stripe",
    providerPaymentId: session.payment_intent ?? session.id,
  });
}
