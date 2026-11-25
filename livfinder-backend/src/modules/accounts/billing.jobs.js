import logger from "../../config/logger.js";
import { execute, query } from "../../db/query.js";
import { notifyInvoiceOverdue, notifySubscriptionPastDue } from "../system/notifications.service.js";
import { holdsReady, paymentRules, syncPackageHolds } from "./entitlement.js";

/**
 * Accounts that do not pay right now: everyone while "Clients must pay" is off, and accounts an
 * admin gave free access (0084). They get no overdue marks and no billing warnings, and their
 * renewal date simply moves on.
 */
async function waivedAccountCondition(column) {
  const { paymentsRequired } = await paymentRules();
  if (!paymentsRequired) return "1 = 1";
  if (!(await holdsReady())) return "1 = 0";
  return `${column} IN (SELECT id FROM accounts WHERE free_access = 1)`;
}

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
  const waived = await waivedAccountCondition("account_id");
  const due = await query(
    `SELECT id, public_id, invoice_number, account_id, total, currency_code, due_at
       FROM invoices
      WHERE status = 'open' AND due_at IS NOT NULL AND due_at < NOW(3) AND NOT (${waived})
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
  const waived = await waivedAccountCondition("account_id");
  // A subscription nobody pays for renews on its own: past due would only be a false alarm.
  // Selected first, so a quiet sweep writes nothing (every write clears part of the public cache).
  const renewOnTheirOwn = await query(
    `SELECT id FROM subscriptions
      WHERE status IN ('active', 'past_due') AND current_period_end IS NOT NULL
        AND (current_period_end < NOW(3) OR status = 'past_due') AND ${waived}
      LIMIT ${Number(limit)}`
  );
  if (renewOnTheirOwn.length) {
    await execute(
      `UPDATE subscriptions
          SET status = 'active',
              current_period_start = IF(current_period_end < NOW(3), NOW(3), current_period_start),
              current_period_end = IF(current_period_end < NOW(3),
                DATE_ADD(NOW(3), INTERVAL (CASE billing_interval WHEN 'quarterly' THEN 3 WHEN 'yearly' THEN 12 ELSE 1 END) MONTH),
                current_period_end),
              updated_at = NOW(3)
        WHERE id IN (${renewOnTheirOwn.map(() => "?").join(", ")})`,
      renewOnTheirOwn.map((row) => row.id)
    );
  }
  const renewalsDue = await query(
    `SELECT id, account_id FROM subscriptions
      WHERE status = 'active' AND current_period_end IS NOT NULL AND current_period_end < NOW(3) AND NOT (${waived})
      ORDER BY current_period_end
      LIMIT ${Number(limit)}`
  );
  for (const sub of renewalsDue) {
    await execute("UPDATE subscriptions SET status = 'past_due', updated_at = NOW(3) WHERE id = ?", [sub.id]);
    await notifySubscriptionPastDue({ accountId: sub.account_id, subscriptionId: sub.id });
  }

  const unnotified = await query(
    `SELECT s.id, s.account_id FROM subscriptions s
      WHERE s.status = 'past_due' AND NOT (${waived.replaceAll("account_id", "s.account_id")})
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
  // Renewals and payments above change who has a working package; search and the automations
  // read the holds, so they follow within one sweep.
  const holds = await syncPackageHolds();
  return { invoicesMarkedPastDue: invoices, subscriptionsMarkedPastDue: subscriptions, ...holds };
}

export function startBillingMaintenance({ intervalMs = 10 * 60 * 1000 } = {}) {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const result = await runBillingMaintenance();
      if (result.invoicesMarkedPastDue || result.subscriptionsMarkedPastDue || result.held || result.released) logger.info(result, "billing maintenance");
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
