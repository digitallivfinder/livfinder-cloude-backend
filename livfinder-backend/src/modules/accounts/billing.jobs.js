import logger from "../../config/logger.js";
import { execute, query } from "../../db/query.js";
import { notifyInvoiceOverdue, notifySubscriptionPastDue } from "../system/notifications.service.js";

/**
 * Billing maintenance that time, not a request, triggers.
 *
 * No payment provider is connected, so nothing ever tells the platform a renewal charge or an
 * invoice payment failed — invoices sat at `open` and subscriptions at `active` forever, no
 * matter how far past their due date they were, and nobody was ever told their billing needed
 * attention. This sweep applies the two transitions a real gateway's failed-payment webhook
 * would have applied by now, and notifies the account either way. Mirrors
 * `listings/listings.jobs.js`'s expiry sweep; runs at boot and on the same interval (server.js).
 */

/** An unpaid invoice whose due date has passed becomes `past_due`, once, and the account is told. */
export async function markOverdueInvoices({ limit = 200 } = {}) {
  const due = await query(
    `SELECT id, public_id, invoice_number, account_id, total, currency_code, due_at
       FROM invoices
      WHERE status = 'open' AND due_at IS NOT NULL AND due_at < NOW(3)
      ORDER BY due_at
      LIMIT ${Number(limit)}`
  );
  for (const invoice of due) {
    await execute("UPDATE invoices SET status = 'past_due', updated_at = NOW(3) WHERE id = ?", [invoice.id]);
    await notifyInvoiceOverdue({ accountId: invoice.account_id, invoice });
  }
  return due.length;
}

/**
 * A subscription still `active` after its own renewal date becomes `past_due` — the honest
 * outcome of there being no gateway to actually attempt that renewal charge — and the account is
 * told. Already-`past_due` subscriptions (seeded that way, or from before this job existed) are
 * notified once via the `NOT EXISTS` check, not re-notified on every run.
 */
export async function markPastDueSubscriptions({ limit = 200 } = {}) {
  const renewalsDue = await query(
    `SELECT id, account_id FROM subscriptions
      WHERE status = 'active' AND current_period_end IS NOT NULL AND current_period_end < NOW(3)
      ORDER BY current_period_end
      LIMIT ${Number(limit)}`
  );
  for (const sub of renewalsDue) {
    await execute("UPDATE subscriptions SET status = 'past_due', updated_at = NOW(3) WHERE id = ?", [sub.id]);
    await notifySubscriptionPastDue({ accountId: sub.account_id, subscriptionId: sub.id });
  }

  const unnotified = await query(
    `SELECT s.id, s.account_id FROM subscriptions s
      WHERE s.status = 'past_due'
        AND NOT EXISTS (
          SELECT 1 FROM notifications n
           WHERE n.type = 'billing.subscription_past_due' AND n.subject_type = 'subscription' AND n.subject_id = s.id
        )
      LIMIT ${Number(limit)}`
  );
  for (const sub of unnotified) {
    await notifySubscriptionPastDue({ accountId: sub.account_id, subscriptionId: sub.id });
  }

  return renewalsDue.length + unnotified.length;
}

export async function runBillingMaintenance() {
  const invoices = await markOverdueInvoices();
  const subscriptions = await markPastDueSubscriptions();
  return { invoicesMarkedPastDue: invoices, subscriptionsMarkedPastDue: subscriptions };
}

export function startBillingMaintenance({ intervalMs = 10 * 60 * 1000 } = {}) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const result = await runBillingMaintenance();
      if (result.invoicesMarkedPastDue || result.subscriptionsMarkedPastDue) logger.info(result, "billing maintenance");
    } catch (error) {
      logger.error({ err: error }, "billing maintenance failed");
    } finally {
      running = false;
    }
  };
  tick();
  const timer = setInterval(tick, intervalMs);
  timer.unref();
  return timer;
}
