import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute, query, queryOne } from "../../db/query.js";
import { ulid } from "../../utils/ids.js";
import { TEMPLATES } from "./templates/index.js";
import { normalizeEmail } from "./preferences.js";

/**
 * Queueing an email. This is the only way the app sends mail.
 *
 *   await queueEmail({ template: "auth.password_reset", to: user.email, userId: user.id, data: { url } });
 *
 * The row is written to `email_messages` and the worker (worker.js) renders and sends it, with
 * retries. Writing never throws into the caller: an email must not undo or fail the thing it
 * announces. `dedupeKey` makes a send happen once however often it is queued (reminders).
 *
 * Under NODE_ENV=test the email is delivered before this returns, so tests can read it.
 */
export async function queueEmail(
  { template, to, toName = null, userId = null, accountId = null, campaignId = null, data = {}, dedupeKey = null, sendAfter = null, replyTo = null, priority = null, attachments = null, sendNow = true },
  connection
) {
  const definition = TEMPLATES[template];
  if (!definition) {
    logger.error({ template }, "email not queued: unknown template");
    return null;
  }
  if (!to || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(to))) return null;
  try {
    const payload = attachments?.length ? { ...data, _attachments: attachments } : data;
    const result = await execute(
      `INSERT IGNORE INTO email_messages
         (public_id, template_key, category, to_email, to_name, user_id, account_id, campaign_id, data, reply_to,
          status, priority, send_after, dedupe_key, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'queued', ?, COALESCE(?, NOW(3)), ?, NOW(3))`,
      [
        ulid(),
        template,
        definition.category,
        normalizeEmail(to),
        toName ? String(toName).slice(0, 200) : null,
        userId,
        accountId,
        campaignId,
        JSON.stringify(payload),
        replyTo,
        priority ?? definition.priority ?? 5,
        sendAfter ? new Date(sendAfter) : null,
        dedupeKey ? String(dedupeKey).slice(0, 191) : null,
      ],
      connection
    );
    if (!result.affectedRows) return null; // already queued under this dedupe key
    const id = result.insertId;
    // Inside a caller's transaction the row is not visible yet; the worker picks it up after commit.
    if (!connection && sendNow) await kick(id);
    return id;
  } catch (error) {
    // Before migration 0081 there is no queue table: send straight away so nothing is lost.
    if (missingEmailTables(error)) return sendWithoutQueue({ template, to, toName, userId, data, replyTo, attachments });
    logger.error({ err: error, template }, "email could not be queued");
    return null;
  }
}


/** True when migration 0081 has not been applied (the DB layer keeps the MySQL error in `cause`). */
export function missingEmailTables(error) {
  const text = `${error?.message ?? ""} ${error?.cause?.message ?? ""} ${error?.cause?.sqlMessage ?? ""}`;
  return /email_messages|email_suppressions|email_events|email_campaigns|email_frequency/.test(text) && /doesn.t exist|Unknown column/.test(text);
}

let warnedNoQueue = false;
async function sendWithoutQueue({ template, to, toName, userId, data, replyTo, attachments }) {
  if (!warnedNoQueue) {
    logger.warn("email_messages is missing (run migration 0081_email_programme.sql); emails are sent directly without retries");
    warnedNoQueue = true;
  }
  try {
    const { composeMessage } = await import("./worker.js");
    const { sendMail } = await import("../system/mail.service.js");
    const message = await composeMessage({
      template_key: template,
      data: attachments?.length ? { ...data, _attachments: attachments } : data,
      to_email: normalizeEmail(to),
      to_name: toName,
      user_id: userId,
      reply_to: replyTo,
      public_id: ulid(),
    });
    await sendMail(message);
    return -1;
  } catch (error) {
    logger.error({ err: error, template }, "email could not be sent");
    return null;
  }
}

/** Starts sending at once instead of waiting for the next worker tick. */
async function kick(id) {
  const { deliverDue } = await import("./worker.js");
  if (env.isTest) {
    await deliverDue({ ids: [id] }).catch((error) => logger.error({ err: error }, "email delivery failed"));
    return;
  }
  setImmediate(() => deliverDue({ ids: [id] }).catch((error) => logger.error({ err: error }, "email delivery failed")));
}

/* -------------------------------------------------------------------------- */
/* Recipients                                                                  */
/* -------------------------------------------------------------------------- */

const USER_COLUMNS = "u.id, u.email, u.first_name, u.display_name";

export async function usersByIds(ids) {
  const unique = [...new Set((ids ?? []).filter(Boolean).map(Number))];
  if (!unique.length) return [];
  return query(
    `SELECT ${USER_COLUMNS} FROM users u WHERE u.id IN (${unique.map(() => "?").join(",")}) AND u.deleted_at IS NULL AND u.email IS NOT NULL AND u.status <> 'banned'`,
    unique
  );
}

/**
 * The people on an account who should hear about something.
 * `roles` picks members by role; the assigned agent (if they have a login) is always included.
 * An organization with no member rows falls back to its agents, as notifications do.
 */
export async function accountUsers({ accountId, organizationId = null, agentId = null, roles = ["owner", "manager"] }) {
  const ids = [];
  if (agentId) {
    const agent = await queryOne("SELECT user_id FROM agents WHERE id = ? AND user_id IS NOT NULL AND deleted_at IS NULL", [agentId]);
    if (agent) ids.push(agent.user_id);
  }
  if (accountId) {
    const members = await query(
      `SELECT user_id FROM account_members WHERE account_id = ? AND status = 'active' AND user_id IS NOT NULL AND role IN (${roles.map(() => "?").join(",")})`,
      [accountId, ...roles]
    );
    ids.push(...members.map((row) => row.user_id));
    if (!members.length) {
      const owner = await queryOne("SELECT owner_user_id FROM accounts WHERE id = ?", [accountId]);
      if (owner?.owner_user_id) ids.push(owner.owner_user_id);
    }
  }
  if (!ids.length && organizationId) {
    const agents = await query("SELECT DISTINCT user_id FROM agents WHERE organization_id = ? AND user_id IS NOT NULL AND deleted_at IS NULL LIMIT 20", [organizationId]);
    ids.push(...agents.map((row) => row.user_id));
  }
  return usersByIds(ids);
}

export async function emailUsers(users, template, data, { accountId = null, dedupeKey = null, replyTo = null, perUserData = null } = {}) {
  let queued = 0;
  for (const user of users) {
    const id = await queueEmail({
      template,
      to: user.email,
      toName: user.display_name || user.first_name,
      userId: user.id,
      accountId,
      data: perUserData ? { ...data, ...perUserData(user) } : data,
      dedupeKey: dedupeKey ? `${dedupeKey}:u${user.id}` : null,
      replyTo,
    });
    if (id) queued += 1;
  }
  return queued;
}

export async function emailUser(userId, template, data, options = {}) {
  return emailUsers(await usersByIds([userId]), template, data, options);
}

/** Every member of an account in `roles` (plus the agent): one email each. */
export async function emailAccount(scope, template, data, options = {}) {
  const users = await accountUsers(scope);
  return emailUsers(users, template, data, { accountId: scope.accountId ?? null, ...options });
}

/** LivFinder staff holding `permissionCode` (super administrators always do). */
export async function emailStaff(permissionCode, data, { dedupeKey = null, template = "staff.alert" } = {}) {
  const rows = await query(
    `SELECT DISTINCT u.id, u.email, u.first_name, u.display_name
       FROM user_roles ur
       JOIN roles r ON r.id = ur.role_id AND r.scope = 'platform'
       JOIN users u ON u.id = ur.user_id AND u.status = 'active' AND u.deleted_at IS NULL AND u.email IS NOT NULL
      WHERE r.code = 'super_admin'
         OR EXISTS (SELECT 1 FROM role_permissions rp JOIN permissions p ON p.id = rp.permission_id
                     WHERE rp.role_id = ur.role_id AND p.code = ?)`,
    [permissionCode]
  );
  return emailUsers(rows, template, data, { dedupeKey });
}

/**
 * A listing or development as the email card needs it. Accepts a listings row (or a projects row
 * with `kind: "development"`) and reads what the row does not carry.
 */
export async function listingSummary(listingOrId) {
  const row =
    typeof listingOrId === "object" && listingOrId?.title !== undefined && listingOrId?.public_id
      ? listingOrId
      : await queryOne(
          "SELECT id, public_id, reference, title, canonical_path, price, currency_code, price_base, cover_image_url, is_price_hidden FROM listings WHERE id = ?",
          [typeof listingOrId === "object" ? listingOrId.id : listingOrId]
        );
  if (!row) return null;
  const search = await queryOne("SELECT spec_labels, cover_image_url, canonical_path FROM listing_search WHERE listing_id = ?", [row.id]).catch(() => null);
  // spec_labels holds the category's headline specs: {"beds": 6, "baths": 7, "area_sqft": 7636, "type": "Villa"}.
  let specs = {};
  try {
    specs = (typeof search?.spec_labels === "string" ? JSON.parse(search.spec_labels) : search?.spec_labels) || {};
  } catch {
    specs = {};
  }
  const facts = [];
  for (const [key, value] of Object.entries(specs)) {
    if (value === null || value === undefined || value === "" || key === "area_sqft") continue;
    if (key === "beds") facts.push(Number(value) === 0 ? "Studio" : `${value} bed${Number(value) === 1 ? "" : "s"}`);
    else if (key === "baths") facts.push(`${value} bath${Number(value) === 1 ? "" : "s"}`);
    else if (typeof value === "string" || typeof value === "number") facts.push(key === "type" ? String(value) : `${String(key).replace(/_/g, " ")}: ${value}`);
    if (facts.length >= 4) break;
  }
  const { siteUrl, imageUrl } = await import("./format.js");
  const path = row.canonical_path || search?.canonical_path;
  return {
    title: row.title || row.reference,
    reference: row.reference,
    url: path ? siteUrl(path) : siteUrl("/"),
    portalUrl: siteUrl(`/portal/listings/${row.public_id}`),
    image: imageUrl(row.cover_image_url || search?.cover_image_url),
    price: row.is_price_hidden ? null : row.price,
    currency: row.currency_code,
    priceBase: row.price_base,
    facts,
    areaSqft: specs.area_sqft ?? null,
  };
}

export async function developmentSummary(projectOrId) {
  const id = typeof projectOrId === "object" ? projectOrId.id : projectOrId;
  const row = await queryOne("SELECT * FROM projects WHERE id = ?", [id]);
  if (!row) return null;
  const { siteUrl, imageUrl } = await import("./format.js");
  return {
    title: row.name,
    reference: row.slug,
    url: siteUrl(row.canonical_path || `/projects/${row.slug}`),
    portalUrl: siteUrl(`/portal/developments/${row.public_id}`),
    image: imageUrl(row.cover_image_url),
    price: row.min_price ?? null,
    currency: row.currency_code ?? "AED",
    priceBase: row.min_price_base ?? null,
    facts: [row.launch_status ? String(row.launch_status).replace(/_/g, " ") : null, row.handover_date ? `Handover ${new Date(row.handover_date).getFullYear()}` : null].filter(Boolean),
  };
}
