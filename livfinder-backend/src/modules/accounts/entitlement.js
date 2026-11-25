import logger from "../../config/logger.js";
import { execute, query, queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";

/**
 * Whether a seller's package is working (owner, 2026-11-24; migration 0084).
 *
 * A seller account has a working package when it holds a current subscription on a seller plan
 * (any plan not meant for Members) and either nobody has to pay yet (the admin switch "Clients
 * must pay" is off), an admin gave it free access, or the subscription is paid up: active,
 * trialing, or past due by less than the grace period.
 *
 * Without one, the portal keeps only the basics (`PACKAGE_FREE_PORTAL_PATHS`), the API and
 * integrations stop (the Integrations add-on reads `isEntitled`), the seller automations skip it,
 * and its listings and developments leave search and the listing pages. Their own pages, the
 * sitemap and llms.txt keep them. Those last two read `seller_package_holds`, which
 * `syncPackageHolds` keeps in step.
 *
 * Package limits (live and stored listings, seats, add-ons) still come from the package itself.
 */

const LIVE_STATUSES = ["active", "trialing", "past_due"];
const PAID_STATUSES = new Set(["active", "trialing"]);
const SETTINGS_TTL_MS = 15 * 1000;

let settingsCache = null;

/** `{ paymentsRequired, graceDays }`, read at most every 15 s. Before 0084 nobody has to pay. */
export async function paymentRules() {
  if (settingsCache && settingsCache.expires > Date.now()) return settingsCache.value;
  const rows = await query(
    "SELECT setting_key, value FROM settings WHERE group_key = 'payment' AND setting_key IN ('payments_required', 'grace_period_days')"
  ).catch(() => []);
  const read = (key) => rows.find((row) => row.setting_key === key)?.value;
  const value = {
    paymentsRequired: ["1", "true"].includes(String(read("payments_required") ?? "0").toLowerCase()),
    graceDays: Math.max(0, Number.parseInt(read("grace_period_days") ?? "0", 10) || 0),
  };
  settingsCache = { value, expires: Date.now() + SETTINGS_TTL_MS };
  return value;
}

export function clearPaymentRulesCache() {
  settingsCache = null;
}

/** Turns "Clients must pay" on or off, then brings every seller's holds in line. */
export async function setPaymentsRequired(required, userId = null) {
  await execute(
    `INSERT INTO settings (group_key, setting_key, value, value_type, label, is_public, is_secret, updated_by)
     VALUES ('payment', 'payments_required', ?, 'boolean', 'Clients must pay', 0, 0, ?)
     ON DUPLICATE KEY UPDATE value = VALUES(value), updated_by = VALUES(updated_by), updated_at = NOW(3)`,
    [required ? "1" : "0", userId]
  );
  clearPaymentRulesCache();
  await syncPackageHolds();
  return paymentRules();
}

/**
 * The package state of one account row (see `packageRows`), as a plain object:
 * `{ chosen, active, reason, paymentNeeded, ... }`. `reason` is why it is not active:
 * `no_package` or `unpaid`; null when it is.
 */
export function decidePackage(row, rules, now = Date.now()) {
  const chosen = Boolean(row?.subscription_id) && row.plan_audience !== "personal";
  const freeAccess = Number(row?.free_access) === 1;
  const paymentNeeded = rules.paymentsRequired && !freeAccess;
  let paid = PAID_STATUSES.has(row?.subscription_status);
  if (!paid && row?.subscription_status === "past_due" && row.current_period_end) {
    paid = new Date(row.current_period_end).getTime() + rules.graceDays * 864e5 > now;
  }
  const reason = !chosen ? "no_package" : paymentNeeded && !paid ? "unpaid" : null;
  return {
    chosen,
    active: reason === null,
    reason,
    paymentsRequired: rules.paymentsRequired,
    freeAccess,
    paymentNeeded,
    planId: chosen ? row.plan_public_id : null,
    planName: chosen ? row.plan_name : null,
    status: chosen ? row.subscription_status : null,
    promptDismissed: Boolean(row?.package_prompt_dismissed_at),
  };
}

async function packageRows(accountId = null) {
  return query(
    `SELECT a.id AS account_id, a.free_access, a.package_prompt_dismissed_at,
            s.id AS subscription_id, s.status AS subscription_status, s.current_period_end,
            p.public_id AS plan_public_id, p.name AS plan_name, p.audience AS plan_audience
       FROM accounts a
       JOIN account_types at ON at.id = a.account_type_id
       LEFT JOIN subscriptions s ON s.id = (
            SELECT s2.id FROM subscriptions s2
             WHERE s2.account_id = a.id AND s2.status IN (${LIVE_STATUSES.map(() => "?").join(", ")})
             ORDER BY s2.created_at DESC, s2.id DESC LIMIT 1)
       LEFT JOIN plans p ON p.id = s.plan_id
      WHERE at.code <> 'personal' AND a.deleted_at IS NULL ${accountId ? "AND a.id = ?" : ""}`,
    [...LIVE_STATUSES, ...(accountId ? [accountId] : [])]
  );
}

const MISSING_SCHEMA = new Set(["ER_BAD_FIELD_ERROR", "ER_NO_SUCH_TABLE"]);

/**
 * The package state of a seller account, or null for a Member (who has no package) or an
 * unknown account. Before migration 0084 every seller counts as active.
 */
export async function accountPackage(accountId) {
  if (!accountId) return null;
  try {
    const [row] = await packageRows(accountId);
    if (!row) return null;
    return decidePackage(row, await paymentRules());
  } catch (error) {
    if (MISSING_SCHEMA.has(error?.code)) return { chosen: true, active: true, reason: null, paymentsRequired: false, freeAccess: false, paymentNeeded: false, planId: null, planName: null, status: null, promptDismissed: true };
    throw error;
  }
}

/** True for a Member (not a seller) and for a seller whose package works. */
export async function isEntitled(accountId) {
  const state = await accountPackage(accountId);
  return state === null || state.active;
}

/**
 * The plan audiences a seller may pick from: individuals the lister plans, companies and
 * developers the company and organization plans; `any` suits both. Members keep theirs.
 */
export function packageAudiences(accountTypeCode) {
  if (accountTypeCode === "personal") return ["personal", "any"];
  if (accountTypeCode === "lister") return ["lister", "any"];
  return ["company", "organization", "any"];
}

/* -------------------------------------------------------------------------- */
/* Holds: what search and the automations read                                 */
/* -------------------------------------------------------------------------- */

let holdsTable = null;

/** Whether `seller_package_holds` exists (0084), checked once. */
export function holdsReady() {
  if (!holdsTable) {
    holdsTable = (async () => {
      try {
        const row = await queryOne(
          "SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema = DATABASE() AND table_name = 'seller_package_holds'"
        );
        return Number(row?.n) > 0;
      } catch {
        return false;
      }
    })();
  }
  return holdsTable;
}

/** Brings `seller_package_holds` in line for one account, or for every seller. Writes only what changed. */
export async function syncPackageHolds(accountId = null) {
  if (!(await holdsReady())) return { held: 0, released: 0 };
  const rules = await paymentRules();
  const rows = await packageRows(accountId);
  const current = await query(
    `SELECT account_id, reason FROM seller_package_holds ${accountId ? "WHERE account_id = ?" : ""}`,
    accountId ? [accountId] : []
  );
  const before = new Map(current.map((row) => [String(row.account_id), row.reason]));
  const seen = new Set();
  let held = 0;
  let released = 0;
  for (const row of rows) {
    const key = String(row.account_id);
    seen.add(key);
    const { reason } = decidePackage(row, rules);
    if (reason && before.get(key) !== reason) {
      await execute(
        `INSERT INTO seller_package_holds (account_id, reason) VALUES (?, ?)
         ON DUPLICATE KEY UPDATE reason = VALUES(reason)`,
        [row.account_id, reason]
      );
      held += 1;
    } else if (!reason && before.has(key)) {
      await execute("DELETE FROM seller_package_holds WHERE account_id = ?", [row.account_id]);
      released += 1;
    }
  }
  // Accounts that are gone, or became Members, hold nothing.
  for (const key of before.keys()) {
    if (!seen.has(key)) {
      await execute("DELETE FROM seller_package_holds WHERE account_id = ?", [key]);
      released += 1;
    }
  }
  if (held || released) logger.info({ held, released, accountId }, "seller package holds updated");
  return { held, released };
}

/** Syncs one account's holds and never throws: a hold that lags is fixed by the next sweep. */
export async function refreshPackageHold(accountId) {
  try {
    await syncPackageHolds(accountId);
  } catch (error) {
    logger.error({ err: error, accountId }, "seller package hold refresh failed");
  }
}

/**
 * Search conditions that leave out held sellers. Each returns "" until 0084 exists, so search
 * works the same on a database that has not been migrated yet.
 */
export async function heldListingsCondition(alias = "ls") {
  if (!(await holdsReady())) return "";
  return `${alias}.listing_id NOT IN (SELECT hl.id FROM listings hl JOIN seller_package_holds hh ON hh.account_id = hl.account_id)`;
}

export async function heldProjectsCondition(alias = "ps") {
  if (!(await holdsReady())) return "";
  return `${alias}.project_id NOT IN (SELECT hp.id FROM projects hp JOIN organizations ho ON ho.id = hp.organization_id
                                       JOIN seller_package_holds hh ON hh.account_id = ho.account_id)`;
}

/** For the automations: `<column> NOT IN (held accounts)`, or "1 = 1" before 0084. */
export async function notHeldAccount(column) {
  if (!(await holdsReady())) return "1 = 1";
  return `${column} NOT IN (SELECT account_id FROM seller_package_holds)`;
}

/* -------------------------------------------------------------------------- */
/* Portal gate                                                                 */
/* -------------------------------------------------------------------------- */

/**
 * What a seller without a working package can still use under /v1/portal: the dashboard, their
 * profile and settings, messages, their own buying side, Billing & Plans and payment history, and
 * the company profile itself (not its team). Everything else is a seller tool.
 */
export const PACKAGE_FREE_PORTAL_PATHS = [
  "/dashboard",
  "/profile",
  "/settings",
  "/messages",
  "/my-enquiries",
  "/my-viewings",
  "/favourites",
  "/saved-searches",
  "/calendar",
  "/options",
  "/lookup",
  "/categories",
  "/billing",
  "/payments",
];
const PACKAGE_FREE_EXACT = new Set(["/organization"]);

export function isPackageFreePortalPath(path) {
  const clean = String(path || "").split("?")[0];
  return PACKAGE_FREE_EXACT.has(clean) || PACKAGE_FREE_PORTAL_PATHS.some((base) => clean === base || clean.startsWith(`${base}/`));
}

export function packageRequiredError(reason) {
  return new AppError(
    reason === "unpaid"
      ? "Your package needs payment before you can use this. Go to Billing & Plans."
      : "Choose a package under Billing & Plans to use this.",
    { status: 403, code: "PACKAGE_REQUIRED", fields: { reason } }
  );
}

/** Mounted after `requireSellerTools` on /v1/portal. Members pass straight through. */
export async function requirePackage(req, res, next) {
  try {
    const membership = req.auth?.activeMembership;
    if (!membership || membership.account_type_code === "personal" || isPackageFreePortalPath(req.path)) return next();
    const state = await accountPackage(membership.account_id);
    if (!state || state.active) return next();
    return next(packageRequiredError(state.reason));
  } catch (error) {
    return next(error);
  }
}

/** The seller pressed "Later" on the first-login package screen. */
export async function dismissPackagePrompt(accountId) {
  await execute("UPDATE accounts SET package_prompt_dismissed_at = COALESCE(package_prompt_dismissed_at, NOW(3)) WHERE id = ?", [accountId]);
  return accountPackage(accountId);
}

/** Admin: lets one account use its package without paying, or takes that away. */
export async function setFreeAccess(accountId, enabled, userId = null) {
  await execute(
    "UPDATE accounts SET free_access = ?, free_access_at = IF(? = 1, NOW(3), NULL), free_access_by = IF(? = 1, ?, NULL) WHERE id = ?",
    [enabled ? 1 : 0, enabled ? 1 : 0, enabled ? 1 : 0, userId, accountId]
  );
  await syncPackageHolds(accountId);
  return accountPackage(accountId);
}

/** For the admin Payment Settings switch: the rule, and how many sellers it currently affects. */
export async function packageAccessSummary() {
  const rules = await paymentRules();
  const counts = await queryOne(
    `SELECT (SELECT COUNT(*) FROM seller_package_holds WHERE reason = 'no_package') AS no_package,
            (SELECT COUNT(*) FROM seller_package_holds WHERE reason = 'unpaid') AS unpaid,
            (SELECT COUNT(*) FROM accounts WHERE free_access = 1 AND deleted_at IS NULL) AS free_access`
  ).catch(() => null);
  return {
    paymentsRequired: rules.paymentsRequired,
    graceDays: rules.graceDays,
    sellersWithoutPackage: Number(counts?.no_package ?? 0),
    sellersUnpaid: Number(counts?.unpaid ?? 0),
    accountsWithFreeAccess: Number(counts?.free_access ?? 0),
  };
}
