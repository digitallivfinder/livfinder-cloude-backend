import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { query, queryOne } from "../../db/query.js";
import { dateOnly, localClock, siteUrl } from "./format.js";
import { accountUsers, emailStaff, emailUsers, listingSummary, queueEmail, usersByIds } from "./send.js";
import { sendDueDigests } from "./worker.js";
import { heldListingsCondition, notHeldAccount, paymentRules } from "../accounts/entitlement.js";

/**
 * Emails that time triggers, not a request: reminders, alerts, digests and reports.
 *
 * Every pass is idempotent. Each email carries a dedupe key built from what it is about and the
 * moment it is for (a listing and its expiry date, a booking and its start time), so running the
 * pass every five minutes, on two API instances, or again after a restart sends each one once.
 */

const day = (date) => new Date(date).toISOString().slice(0, 10);

/** Listings ending in about 7 days or within a day, and listings that ended in the last 3 days. */
export async function listingExpiryEmails() {
  let queued = 0;
  // Sellers without a working package get no automations (0084).
  const notHeld = await notHeldAccount("l.account_id");
  const windows = [
    { days: 7, sql: "l.expires_at BETWEEN DATE_ADD(NOW(3), INTERVAL 6 DAY) AND DATE_ADD(NOW(3), INTERVAL 7 DAY)" },
    { days: 1, sql: "l.expires_at BETWEEN NOW(3) AND DATE_ADD(NOW(3), INTERVAL 1 DAY)" },
  ];
  for (const window of windows) {
    const rows = await query(
      `SELECT l.id, l.account_id, l.organization_id, l.agent_id, l.expires_at FROM listings l
        WHERE l.status = 'active' AND l.deleted_at IS NULL AND l.expires_at IS NOT NULL AND ${window.sql} AND ${notHeld} LIMIT 500`
    );
    for (const row of rows) {
      const listing = await listingSummary(row.id);
      const users = await accountUsers({ accountId: row.account_id, organizationId: row.organization_id, agentId: row.agent_id, roles: ["owner", "manager"] });
      queued += await emailUsers(users, "listings.expiring", { listing, days: window.days, expiresAt: row.expires_at }, {
        accountId: row.account_id,
        dedupeKey: `listing.expiring${window.days}:${row.id}:${day(row.expires_at)}`,
      });
    }
  }
  const expired = await query(
    `SELECT l.id, l.account_id, l.organization_id, l.agent_id, l.expires_at FROM listings l
      WHERE l.status = 'expired' AND l.deleted_at IS NULL AND l.expires_at BETWEEN DATE_SUB(NOW(3), INTERVAL 3 DAY) AND NOW(3) AND ${notHeld} LIMIT 500`
  );
  for (const row of expired) {
    const listing = await listingSummary(row.id);
    const users = await accountUsers({ accountId: row.account_id, organizationId: row.organization_id, agentId: row.agent_id, roles: ["owner", "manager"] });
    queued += await emailUsers(users, "listings.expired", { listing }, { accountId: row.account_id, dedupeKey: `listing.expired:${row.id}:${day(row.expires_at)}` });
  }
  return queued;
}

/** 24 hours and 2 hours before a confirmed viewing, to both sides. */
export async function viewingReminders() {
  let queued = 0;
  const windows = [
    { hours: 24, sql: "b.scheduled_start BETWEEN DATE_ADD(NOW(3), INTERVAL 23 HOUR) AND DATE_ADD(NOW(3), INTERVAL 24 HOUR)" },
    { hours: 2, sql: "b.scheduled_start BETWEEN NOW(3) AND DATE_ADD(NOW(3), INTERVAL 2 HOUR)" },
  ];
  for (const window of windows) {
    const rows = await query(
      `SELECT b.id, b.public_id, b.reference, b.scheduled_start, b.meeting_location, b.contact_name, b.contact_email, b.contact_phone,
              b.user_id, b.account_id, b.organization_id, b.agent_id, l.title AS listing_title,
              COALESCE(o.name, ag.display_name, 'LivFinder') AS seller_name, ag.phone AS agent_phone
         FROM bookings b
         LEFT JOIN listings l ON l.id = b.listing_id
         LEFT JOIN organizations o ON o.id = b.organization_id
         LEFT JOIN agents ag ON ag.id = b.agent_id
        WHERE b.status IN ('confirmed', 'rescheduled') AND b.deleted_at IS NULL AND ${window.sql} LIMIT 500`
    ).catch(async () =>
      // Older schemas name the agent columns differently; the reminder still goes without them.
      query(
        `SELECT b.id, b.public_id, b.reference, b.scheduled_start, b.meeting_location, b.contact_name, b.contact_email, b.contact_phone,
                b.user_id, b.account_id, b.organization_id, b.agent_id, l.title AS listing_title, COALESCE(o.name, 'LivFinder') AS seller_name, NULL AS agent_phone
           FROM bookings b LEFT JOIN listings l ON l.id = b.listing_id LEFT JOIN organizations o ON o.id = b.organization_id
          WHERE b.status IN ('confirmed', 'rescheduled') AND b.deleted_at IS NULL AND ${window.sql} LIMIT 500`
      )
    );
    for (const row of rows) {
      const summary = `Viewing: ${row.listing_title ?? row.reference}`;
      const base = { summary, hours: window.hours, start: row.scheduled_start, location: row.meeting_location };
      const key = `viewing.reminder${window.hours}:${row.id}:${new Date(row.scheduled_start).toISOString()}`;
      if (row.contact_email) {
        const id = await queueEmail({
          template: "viewings.reminder",
          to: row.contact_email,
          toName: row.contact_name,
          userId: row.user_id,
          data: { ...base, lines: [`With: ${row.seller_name}`, row.agent_phone && `Phone: ${row.agent_phone}`, `Booking ${row.reference}`].filter(Boolean) },
          dedupeKey: `${key}:customer`,
        });
        if (id) queued += 1;
      }
      const sellers = await accountUsers({ accountId: row.account_id, organizationId: row.organization_id, agentId: row.agent_id, roles: row.agent_id ? [] : ["owner"] });
      queued += await emailUsers(
        sellers,
        "viewings.reminder",
        { ...base, url: siteUrl("/portal/bookings"), lines: [`Customer: ${row.contact_name ?? "Customer"}`, row.contact_phone && `Phone: ${row.contact_phone}`, `Booking ${row.reference}`].filter(Boolean) },
        { accountId: row.account_id, dedupeKey: `${key}:seller` }
      );
    }
  }
  return queued;
}

/** Enquiries with no reply after a day: one reminder per account per day. */
export async function unansweredLeadReminders() {
  const notHeld = await notHeldAccount("i.account_id");
  const rows = await query(
    `SELECT i.account_id, i.organization_id, i.name, i.created_at, COALESCE(l.title, p.name, 'your listing') AS about
       FROM inquiries i
       LEFT JOIN listings l ON l.id = i.listing_id
       LEFT JOIN projects p ON p.id = i.project_id
      WHERE i.status = 'new' AND i.first_response_at IS NULL AND i.deleted_at IS NULL AND COALESCE(i.is_spam, 0) = 0
        AND i.created_at BETWEEN DATE_SUB(NOW(3), INTERVAL 7 DAY) AND DATE_SUB(NOW(3), INTERVAL 24 HOUR)
        AND i.account_id IS NOT NULL AND ${notHeld}
      ORDER BY i.created_at ASC LIMIT 2000`
  );
  const byAccount = new Map();
  for (const row of rows) {
    if (!byAccount.has(row.account_id)) byAccount.set(row.account_id, { organizationId: row.organization_id, leads: [] });
    byAccount.get(row.account_id).leads.push(row);
  }
  let queued = 0;
  const today = day(new Date());
  for (const [accountId, { organizationId, leads }] of byAccount) {
    const users = await accountUsers({ accountId, organizationId, roles: ["owner", "manager"] });
    const days = (date) => Math.max(1, Math.round((Date.now() - new Date(date).getTime()) / 864e5));
    queued += await emailUsers(
      users,
      "leads.unanswered",
      { count: leads.length, leads: leads.map((lead) => ({ name: lead.name, about: lead.about, age: `${days(lead.created_at)} day${days(lead.created_at) === 1 ? "" : "s"} ago` })) },
      { accountId, dedupeKey: `leads.unanswered:${accountId}:${today}` }
    );
  }
  return queued;
}

/** At 09:00 platform time: what is waiting for staff review. */
export async function staffDailyQueue() {
  const clock = localClock(env.EMAIL_DEFAULT_TIMEZONE);
  if (clock.hour < 9) return 0;
  const count = async (sql) => Number((await queryOne(sql).catch(() => null))?.n ?? 0);
  const rows = [
    ["Seller applications", await count("SELECT COUNT(*) AS n FROM verification_requests WHERE status IN ('pending','in_review')")],
    ["Listings to review", await count("SELECT COUNT(*) AS n FROM listings WHERE moderation_status = 'pending' AND deleted_at IS NULL")],
    ["Listing changes to review", await count("SELECT COUNT(*) AS n FROM listings WHERE pending_revision_id IS NOT NULL AND deleted_at IS NULL")],
    ["Developments to review", await count("SELECT COUNT(*) AS n FROM projects WHERE (moderation_status = 'pending' OR pending_revision_id IS NOT NULL) AND deleted_at IS NULL")],
    ["Category access requests", await count("SELECT COUNT(*) AS n FROM account_category_access WHERE status = 'pending'")],
    ["Open reports", await count("SELECT COUNT(*) AS n FROM reports WHERE status IN ('new','triaged','in_review','escalated')")],
    ["Support tickets", await count("SELECT COUNT(*) AS n FROM support_tickets WHERE status IN ('new','open')")],
  ];
  const total = rows.reduce((sum, [, value]) => sum + value, 0);
  if (!total) return 0;
  const oldest = await queryOne("SELECT MIN(submitted_at) AS at FROM verification_requests WHERE status IN ('pending','in_review')").catch(() => null);
  const oldestDays = oldest?.at ? Math.round((Date.now() - new Date(oldest.at).getTime()) / 864e5) : null;
  return emailStaff(
    "moderation.view",
    { total, rows: rows.filter(([, value]) => value > 0).map(([label, value]) => [label, String(value)]), oldest: oldestDays >= 2 ? `${oldestDays} days (a seller application)` : null },
    { template: "staff.daily_queue", dedupeKey: `staff.queue:${clock.day}` }
  );
}

/** Invoices due within 3 days, once each. */
export async function invoiceDueReminders() {
  // Nobody pays while "Clients must pay" is off, and accounts with free access never do (0084).
  const { paymentsRequired } = await paymentRules();
  if (!paymentsRequired) return 0;
  const rows = await query(
    `SELECT i.id, i.invoice_number, i.account_id, i.total, i.currency_code, i.issued_at, i.due_at, p.name AS plan_name
       FROM invoices i LEFT JOIN subscriptions s ON s.id = i.subscription_id LEFT JOIN plans p ON p.id = s.plan_id
      WHERE i.status NOT IN ('paid', 'void', 'voided', 'draft') AND i.due_at BETWEEN NOW(3) AND DATE_ADD(NOW(3), INTERVAL 3 DAY)
        AND NOT EXISTS (SELECT 1 FROM accounts fa WHERE fa.id = i.account_id AND fa.free_access = 1) LIMIT 500`
  );
  let queued = 0;
  for (const row of rows) {
    const users = await accountUsers({ accountId: row.account_id, roles: ["owner"] });
    queued += await emailUsers(
      users,
      "billing.invoice_due_soon",
      { invoice: { number: row.invoice_number, total: row.total, currency: row.currency_code, issuedAt: row.issued_at, dueAt: row.due_at, planName: row.plan_name } },
      { accountId: row.account_id, dedupeKey: `invoice.due:${row.id}` }
    );
  }
  return queued;
}

/** A plan change chosen for the next billing cycle, 3 days before it applies. */
export async function scheduledPlanChangeReminders() {
  const rows = await query(
    `SELECT c.id, c.effective_at, s.account_id, p.name AS plan_name
       FROM subscription_changes c JOIN subscriptions s ON s.id = c.subscription_id JOIN plans p ON p.id = c.to_plan_id
      WHERE c.status = 'scheduled' AND c.applied_at IS NULL AND c.reason = 'Next billing cycle, chosen in Change Package'
        AND c.effective_at BETWEEN DATE_ADD(NOW(3), INTERVAL 2 DAY) AND DATE_ADD(NOW(3), INTERVAL 3 DAY) LIMIT 500`
  ).catch(() => []);
  let queued = 0;
  for (const row of rows) {
    const users = await accountUsers({ accountId: row.account_id, roles: ["owner"] });
    queued += await emailUsers(users, "billing.plan_change_scheduled", { planName: row.plan_name, effectiveAt: row.effective_at, reminder: true }, {
      accountId: row.account_id,
      dedupeKey: `plan.change.reminder:${row.id}`,
    });
  }
  return queued;
}

/** One more confirmation link for accounts still unconfirmed a day after signing up. */
export async function unconfirmedSignupReminders() {
  const rows = await query(
    `SELECT id FROM users WHERE email_verified_at IS NULL AND deleted_at IS NULL AND status IN ('pending_verification', 'active')
        AND created_at BETWEEN DATE_SUB(NOW(3), INTERVAL 48 HOUR) AND DATE_SUB(NOW(3), INTERVAL 24 HOUR) LIMIT 500`
  );
  if (!rows.length) return 0;
  const { sendEmailVerification } = await import("../auth/auth.service.js");
  let queued = 0;
  for (const row of rows) {
    const already = await queryOne("SELECT id FROM email_messages WHERE dedupe_key = ?", [`auth.confirm.reminder:${row.id}`]);
    if (already) continue;
    await sendEmailVerification({ userId: row.id, ip: null, dedupeKey: `auth.confirm.reminder:${row.id}` }).catch(() => null);
    queued += 1;
  }
  return queued;
}

/** Team invitations two days from expiring: a fresh link, once. */
export async function invitationReminders() {
  const { remindExpiringInvitations } = await import("../accounts/teamInvitation.service.js");
  return remindExpiringInvitations();
}

/* -------------------------------------------------------------------------- */
/* Member alerts                                                               */
/* -------------------------------------------------------------------------- */

/**
 * New listings for saved searches. Daily searches are sent from 08:00 in the person's timezone,
 * weekly ones on Mondays, instant ones every half hour. Matching uses the search's category,
 * purpose and location plus the price and bedroom criteria it stored.
 */
export async function savedSearchAlerts() {
  // Alerts match what search shows, so held sellers' listings are left out (0084).
  const held = await heldListingsCondition("ls");
  const searches = await query(
    `SELECT s.*, u.timezone FROM saved_searches s JOIN users u ON u.id = s.user_id AND u.deleted_at IS NULL
      WHERE s.alerts_enabled = 1 AND s.deleted_at IS NULL AND s.alert_frequency <> 'never' LIMIT 2000`
  );
  let queued = 0;
  for (const search of searches) {
    const clock = localClock(search.timezone);
    const since = search.last_alert_at ? Date.now() - new Date(search.last_alert_at).getTime() : Infinity;
    const due =
      search.alert_frequency === "instant" ? since > 30 * 60 * 1000 :
      search.alert_frequency === "weekly" ? clock.weekday === "Mon" && clock.hour >= 8 && since > 6 * 864e5 :
      clock.hour >= 8 && since > 20 * 3600 * 1000;
    if (!due) continue;

    let criteria = {};
    try {
      criteria = (typeof search.criteria === "string" ? JSON.parse(search.criteria) : search.criteria) || {};
    } catch {
      criteria = {};
    }
    const where = ["ls.listing_id > ?", ...(held ? [held] : [])];
    const params = [Number(search.last_result_max_listing_id) || 0];
    if (search.category_id) {
      where.push("(ls.category_id = ? OR ls.root_category_id = ?)");
      params.push(search.category_id, search.category_id);
    }
    if (search.purpose_id) {
      where.push("ls.purpose_id = ?");
      params.push(search.purpose_id);
    }
    if (search.location_id) {
      where.push("? IN (ls.country_id, ls.state_id, ls.city_id, ls.community_id, ls.sub_community_id)");
      params.push(search.location_id);
    }
    const minPrice = Number(criteria.minPrice ?? criteria.priceMin);
    const maxPrice = Number(criteria.maxPrice ?? criteria.priceMax);
    if (minPrice > 0) { where.push("ls.price_base >= ?"); params.push(minPrice); }
    if (maxPrice > 0) { where.push("ls.price_base <= ?"); params.push(maxPrice); }
    const beds = Number(criteria.bedrooms ?? criteria.beds);
    if (Number.isFinite(beds) && criteria.bedrooms !== undefined) { where.push("ls.spec_a = ?"); params.push(beds); }

    const matches = await query(
      `SELECT ls.listing_id FROM listing_search ls WHERE ${where.join(" AND ")} ORDER BY ls.listing_id DESC LIMIT 50`,
      params
    ).catch(() => []);
    const newest = matches[0]?.listing_id ?? null;
    // First run only records where the search stands, so nobody gets an email of old listings.
    if (!search.last_result_max_listing_id) {
      const top = await queryOne("SELECT MAX(listing_id) AS id FROM listing_search").catch(() => null);
      await query("UPDATE saved_searches SET last_result_max_listing_id = ?, last_alert_at = NOW(3) WHERE id = ?", [top?.id ?? 0, search.id]);
      continue;
    }
    await query("UPDATE saved_searches SET last_alert_at = NOW(3), new_result_count = ?, last_result_max_listing_id = GREATEST(COALESCE(last_result_max_listing_id, 0), ?) WHERE id = ?", [
      matches.length,
      newest ?? 0,
      search.id,
    ]);
    if (!matches.length) continue;
    const listings = [];
    for (const match of matches.slice(0, 6)) listings.push(await listingSummary(match.listing_id));
    const [user] = await usersByIds([search.user_id]);
    if (!user) continue;
    const id = await queueEmail({
      template: "alerts.saved_search",
      to: user.email,
      toName: user.display_name || user.first_name,
      userId: user.id,
      data: { searchName: search.name, count: matches.length, listings: listings.filter(Boolean), url: siteUrl(search.canonical_url || "/") },
      dedupeKey: `alerts.saved_search:${search.id}:${newest}`,
    });
    if (id) queued += 1;
  }
  return queued;
}

/** Price drops in the last day on listings people saved as favourites. */
export async function priceDropAlerts() {
  const notHeld = await notHeldAccount("l.account_id");
  const drops = await query(
    `SELECT h.id, h.listing_id, h.old_price, h.new_price, h.change_percentage
       FROM listing_price_history h JOIN listings l ON l.id = h.listing_id AND l.status = 'active' AND l.deleted_at IS NULL
      WHERE h.new_price < h.old_price AND h.changed_at >= DATE_SUB(NOW(3), INTERVAL 1 DAY) AND ${notHeld} LIMIT 500`
  );
  let queued = 0;
  for (const drop of drops) {
    const fans = await query("SELECT DISTINCT user_id FROM favourites WHERE listing_id = ?", [drop.listing_id]);
    if (!fans.length) continue;
    const listing = await listingSummary(drop.listing_id);
    const users = await usersByIds(fans.map((row) => row.user_id));
    const changePercent = drop.change_percentage ?? ((Number(drop.new_price) - Number(drop.old_price)) / Number(drop.old_price)) * 100;
    queued += await emailUsers(users, "alerts.price_drop", { listing, oldPrice: drop.old_price, newPrice: drop.new_price, changePercent }, { dedupeKey: `alerts.price_drop:${drop.id}` });
  }
  return queued;
}

/** Monday from 08:00 platform time: last week's views and enquiries for each selling account. */
export async function weeklyReports() {
  const clock = localClock(env.EMAIL_DEFAULT_TIMEZONE);
  if (clock.weekday !== "Mon" || clock.hour < 8) return 0;
  const notHeld = await notHeldAccount("l.account_id");
  const accounts = await query(
    `SELECT l.account_id, MAX(l.organization_id) AS organization_id,
            SUM(s.stat_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) AND s.stat_date < CURDATE()) AS days,
            SUM(IF(s.stat_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY), s.views, 0)) AS views,
            SUM(IF(s.stat_date < DATE_SUB(CURDATE(), INTERVAL 7 DAY), s.views, 0)) AS views_before,
            SUM(IF(s.stat_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY), s.inquiries, 0)) AS enquiries,
            SUM(IF(s.stat_date < DATE_SUB(CURDATE(), INTERVAL 7 DAY), s.inquiries, 0)) AS enquiries_before
       FROM listing_daily_stats s JOIN listings l ON l.id = s.listing_id
      WHERE s.stat_date >= DATE_SUB(CURDATE(), INTERVAL 14 DAY) AND s.stat_date < CURDATE() AND l.account_id IS NOT NULL AND ${notHeld}
      GROUP BY l.account_id HAVING views > 0 OR enquiries > 0 LIMIT 5000`
  );
  const change = (now, before) => (Number(before) > 0 ? `${now >= before ? "+" : ""}${Math.round(((now - before) / before) * 100)}%` : null);
  let queued = 0;
  for (const account of accounts) {
    const live = await queryOne("SELECT COUNT(*) AS n FROM listings WHERE account_id = ? AND status = 'active' AND deleted_at IS NULL", [account.account_id]);
    const top = await query(
      `SELECT s.listing_id, SUM(s.views) AS views FROM listing_daily_stats s JOIN listings l ON l.id = s.listing_id
        WHERE l.account_id = ? AND s.stat_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) GROUP BY s.listing_id ORDER BY views DESC LIMIT 3`,
      [account.account_id]
    );
    const topListings = [];
    for (const row of top) topListings.push({ ...(await listingSummary(row.listing_id)), views: Number(row.views) });
    const users = await accountUsers({ accountId: account.account_id, organizationId: account.organization_id, roles: ["owner", "manager"] });
    queued += await emailUsers(
      users,
      "reports.weekly",
      {
        views: Number(account.views),
        enquiries: Number(account.enquiries),
        live: Number(live?.n ?? 0),
        viewsChange: change(Number(account.views), Number(account.views_before)),
        enquiriesChange: change(Number(account.enquiries), Number(account.enquiries_before)),
        from: new Date(Date.now() - 7 * 864e5).toISOString(),
        to: new Date(Date.now() - 864e5).toISOString(),
        top: topListings,
      },
      { accountId: account.account_id, dedupeKey: `reports.weekly:${account.account_id}:${clock.day}` }
    );
  }
  return queued;
}

const PASSES = {
  digests: sendDueDigests,
  listingExpiry: listingExpiryEmails,
  viewingReminders,
  unansweredLeads: unansweredLeadReminders,
  staffQueue: staffDailyQueue,
  invoiceDue: invoiceDueReminders,
  planChanges: scheduledPlanChangeReminders,
  unconfirmedSignups: unconfirmedSignupReminders,
  invitations: invitationReminders,
  savedSearches: savedSearchAlerts,
  priceDrops: priceDropAlerts,
  weeklyReports,
};

export async function runEmailJobs() {
  const result = {};
  for (const [name, pass] of Object.entries(PASSES)) {
    try {
      result[name] = await pass();
    } catch (error) {
      if ((await import("./send.js")).missingEmailTables(error)) return { skipped: "migration 0081 not applied" };
      logger.error({ err: error, pass: name }, "email job failed");
      result[name] = "failed";
    }
  }
  return result;
}

export function startEmailJobs({ intervalMs = 5 * 60 * 1000 } = {}) {
  if (env.isTest || !env.EMAIL_WORKER_ENABLED) return null;
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      const result = await runEmailJobs();
      const busy = Object.entries(result).filter(([, value]) => value);
      if (busy.length) logger.info(Object.fromEntries(busy), "email jobs");
    } finally {
      running = false;
    }
  };
  setTimeout(tick, 20 * 1000).unref?.();
  const timer = setInterval(tick, intervalMs);
  timer.unref?.();
  return timer;
}

export { dateOnly };
