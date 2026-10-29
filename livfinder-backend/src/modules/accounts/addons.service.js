import { execute, query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { notifyAccount } from "../system/notifications.service.js";

/**
 * Paid add-ons on top of a plan (migration 0059).
 *
 * An admin decides per plan whether an add-on can be switched on and what it costs (0 is a
 * real price); an account switches it on and keeps the plan, price and currency it agreed to.
 * One row per add-on per account, reused when it is switched back on, so feeds, keys and the
 * lead history carry on where they stopped.
 *
 * An add-on is running while its row is active, not past `ends_at`, and the account's latest
 * subscription has not lapsed. When it lapses, feeds stop and leads stop going out; listings
 * already on the site stay. As with plan changes, no charge is raised here yet.
 */

export const ADDONS = Object.freeze({
  integrations: {
    code: "integrations",
    name: "Integrations",
    description: "XML/CSV listing feeds, the listing API, lead export to your CRM and webhooks.",
  },
});

export const ADDON_CODES = Object.keys(ADDONS);

const LAPSED_SUBSCRIPTION = new Set(["cancelled", "expired", "paused"]);

const num = (value) => (value === null || value === undefined ? null : Number(value));

function assertKnown(code) {
  if (!ADDONS[code]) throw AppError.notFound("That add-on does not exist.");
  return ADDONS[code];
}

/** `{ [planId]: { [code]: { isAvailable, amount, currency } } }` for the plans given. */
export async function planAddonsByPlan(planIds) {
  const ids = [...new Set(planIds.filter(Boolean).map(Number))];
  if (!ids.length) return new Map();
  const rows = await query(
    `SELECT plan_id, addon_code, is_available, amount, currency_code
       FROM plan_addons WHERE plan_id IN (${ids.map(() => "?").join(", ")})`,
    ids
  );
  const byPlan = new Map();
  for (const row of rows) {
    if (!byPlan.has(Number(row.plan_id))) byPlan.set(Number(row.plan_id), {});
    byPlan.get(Number(row.plan_id))[row.addon_code] = {
      isAvailable: Boolean(row.is_available),
      amount: num(row.amount) ?? 0,
      currency: row.currency_code,
    };
  }
  return byPlan;
}

/** Every known add-on for one plan, defaulting to "not available, free". */
export function serializePlanAddons(addons = {}) {
  return ADDON_CODES.map((code) => ({
    code,
    name: ADDONS[code].name,
    description: ADDONS[code].description,
    isAvailable: addons[code]?.isAvailable ?? false,
    amount: addons[code]?.amount ?? 0,
    currency: addons[code]?.currency ?? "AED",
  }));
}

/** Writes an admin's add-on settings for a plan. `addons` is `[{ code, isAvailable, amount }]`. */
export async function upsertPlanAddons(planId, addons, connection) {
  if (!addons) return;
  for (const addon of addons) {
    assertKnown(addon.code);
    // A field left out keeps its current value.
    const isAvailable = addon.isAvailable === undefined ? null : addon.isAvailable ? 1 : 0;
    const amount = addon.amount ?? null;
    await execute(
      `INSERT INTO plan_addons (plan_id, addon_code, is_available, amount, currency_code)
       VALUES (?, ?, COALESCE(?, 0), COALESCE(?, 0), 'AED')
       ON DUPLICATE KEY UPDATE is_available = COALESCE(?, is_available), amount = COALESCE(?, amount)`,
      [planId, addon.code, isAvailable, amount, isAvailable, amount],
      connection
    );
  }
}

async function currentSubscription(accountId, connection) {
  return queryOne(
    "SELECT id, plan_id, status FROM subscriptions WHERE account_id = ? ORDER BY created_at DESC, id DESC LIMIT 1",
    [accountId],
    connection
  );
}

function runningState(row, subscription) {
  if (!row || row.status !== "active") return false;
  if (row.ends_at && new Date(row.ends_at).getTime() <= Date.now()) return false;
  if (subscription && LAPSED_SUBSCRIPTION.has(subscription.status)) return false;
  return true;
}

/** Whether the account's add-on is running right now. */
export async function isAddonActive(accountId, code, connection) {
  if (!accountId) return false;
  const [row, subscription] = await Promise.all([
    queryOne(
      "SELECT status, ends_at FROM account_addons WHERE account_id = ? AND addon_code = ?",
      [accountId, code],
      connection
    ),
    currentSubscription(accountId, connection),
  ]);
  return runningState(row, subscription);
}

export async function assertAddonActive(accountId, code, connection) {
  if (await isAddonActive(accountId, code, connection)) return;
  const addon = assertKnown(code);
  throw new AppError(`The ${addon.name} add-on is not active on this account. Switch it on under Billing to use this.`, {
    status: 403,
    code: "ADDON_INACTIVE",
  });
}

/** The add-ons an account can see: what its plan offers, and what it has switched on. */
export async function listAccountAddons(accountId) {
  const subscription = await currentSubscription(accountId);
  const [planAddons, rows] = await Promise.all([
    planAddonsByPlan([subscription?.plan_id]),
    query(
      `SELECT public_id, addon_code, status, amount, currency_code, started_at, ends_at, cancelled_at
         FROM account_addons WHERE account_id = ?`,
      [accountId]
    ),
  ]);
  const offered = planAddons.get(Number(subscription?.plan_id)) || {};
  return ADDON_CODES.map((code) => {
    const row = rows.find((item) => item.addon_code === code);
    return {
      code,
      name: ADDONS[code].name,
      description: ADDONS[code].description,
      availableOnPlan: offered[code]?.isAvailable ?? false,
      planPrice: offered[code] ? { amount: offered[code].amount, currency: offered[code].currency } : null,
      status: row?.status ?? "off",
      isActive: runningState(row, subscription),
      price: row ? { amount: num(row.amount), currency: row.currency_code } : null,
      startedAt: row?.started_at ?? null,
      endsAt: row?.ends_at ?? null,
      cancelledAt: row?.cancelled_at ?? null,
    };
  });
}

/**
 * Switches an add-on on. An owner may only do it when the plan offers it; an admin
 * (`byPlatform`) may grant it regardless, at the plan's price or the one given.
 */
export async function enableAddon({ accountId, code, userId, byPlatform = false, amount = null, endsAt = null }) {
  const addon = assertKnown(code);
  const subscription = await currentSubscription(accountId);
  const offered = (await planAddonsByPlan([subscription?.plan_id])).get(Number(subscription?.plan_id))?.[code];
  if (!byPlatform && !offered?.isAvailable) {
    throw new AppError(`Your plan does not include the ${addon.name} add-on. Upgrade your plan to use it.`, {
      status: 403,
      code: "ADDON_NOT_ON_PLAN",
    });
  }
  const price = amount ?? offered?.amount ?? 0;
  await execute(
    `INSERT INTO account_addons
       (public_id, account_id, addon_code, plan_id, amount, currency_code, status, started_at, ends_at,
        cancelled_at, enabled_by_user_id)
     VALUES (?, ?, ?, ?, ?, ?, 'active', NOW(3), ?, NULL, ?)
     ON DUPLICATE KEY UPDATE
       plan_id = VALUES(plan_id), amount = VALUES(amount), currency_code = VALUES(currency_code),
       -- Before status: MySQL applies these left to right, so this still sees the old status.
       started_at = IF(status = 'active', started_at, NOW(3)), status = 'active',
       ends_at = VALUES(ends_at), cancelled_at = NULL, enabled_by_user_id = VALUES(enabled_by_user_id)`,
    [ulid(), accountId, code, subscription?.plan_id ?? null, price, offered?.currency ?? "AED", endsAt, userId ?? null]
  );
  await notifyAccount(
    { accountId },
    {
      type: "billing.addon_enabled",
      title: `${addon.name} switched on`,
      body: price > 0 ? `${addon.name} is active. It is billed with your plan.` : `${addon.name} is active.`,
      actionUrl: "/portal/integrations",
      icon: "credit-card",
      subjectType: "account",
      subjectId: accountId,
    }
  ).catch(() => {});
  return listAccountAddons(accountId);
}

/** Switches an add-on off. Feeds stop and leads stop going out; listings stay. */
export async function disableAddon({ accountId, code }) {
  const addon = assertKnown(code);
  const result = await execute(
    "UPDATE account_addons SET status = 'cancelled', cancelled_at = NOW(3) WHERE account_id = ? AND addon_code = ? AND status = 'active'",
    [accountId, code]
  );
  if (result.affectedRows) {
    await notifyAccount(
      { accountId },
      {
        type: "billing.addon_disabled",
        title: `${addon.name} switched off`,
        body: "Feeds have stopped and leads are no longer sent to your systems. Your listings stay as they are.",
        actionUrl: "/portal/billing",
        icon: "credit-card",
        subjectType: "account",
        subjectId: accountId,
      }
    ).catch(() => {});
  }
  return listAccountAddons(accountId);
}
