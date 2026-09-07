import {
  query, queryOne, queryValue, adminPagination, adminList, int, bool, isoDate,
} from "./admin.shared.js";
import * as options from "./admin.options.js";
import { execute } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { encryptSecret, secretStatus } from "../../utils/secrets.js";
import { toAdminPermissions, adminPermissionUniverse } from "../auth/adminPermissions.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";
import { CATEGORY_DEFINITIONS } from "../../utils/categories.js";

/**
 * Settings, access management and system logs.
 *
 * Secret-valued settings never leave the server. A read returns
 * `{ configured, hint }`; a write encrypts before storing. There is no endpoint
 * that returns a provider secret key.
 */
function coerceSetting(row) {
  const raw = row.value;
  switch (row.value_type) {
    case "integer":
      return raw === null ? null : Number.parseInt(raw, 10);
    case "decimal":
      return raw === null ? null : Number.parseFloat(raw);
    case "boolean":
      return raw === "1" || raw === "true" || raw === true;
    case "json":
      try {
        return JSON.parse(raw ?? "null");
      } catch {
        return null;
      }
    default:
      return raw;
  }
}

export async function getSettings(groupKey) {
  const rows = await query(
    `SELECT setting_key, value, value_type, label, description, is_public, is_secret, updated_at
       FROM settings WHERE group_key = ? ORDER BY setting_key`,
    [groupKey]
  );
  const values = {};
  const meta = {};
  for (const row of rows) {
    meta[row.setting_key] = {
      label: row.label,
      description: row.description,
      isPublic: bool(row.is_public),
      isSecret: bool(row.is_secret),
      updatedAt: isoDate(row.updated_at),
    };
    // A secret's value is replaced by its status. Nothing else is filtered.
    values[row.setting_key] = bool(row.is_secret) ? secretStatus(row.value) : coerceSetting(row);
  }
  return { values, meta };
}

export async function updateSettings({ groupKey, patch, userId }) {
  const existing = await query(
    "SELECT setting_key, value_type, is_secret FROM settings WHERE group_key = ?",
    [groupKey]
  );
  const known = new Map(existing.map((row) => [row.setting_key, row]));

  const applied = {};
  await withTransaction(async (connection) => {
    for (const [settingKey, value] of Object.entries(patch)) {
      const definition = known.get(settingKey);
      // Only settings that already exist can be written: the settings table is
      // a schema, not a free-form key/value bucket a client can extend.
      if (!definition) continue;
      if (value === undefined) continue;

      let stored;
      if (bool(definition.is_secret)) {
        // An empty string means "leave the stored secret alone".
        if (value === "" || value === null) continue;
        stored = encryptSecret(String(value));
        applied[settingKey] = "[updated]";
      } else if (definition.value_type === "json") {
        stored = JSON.stringify(value);
        applied[settingKey] = value;
      } else if (definition.value_type === "boolean") {
        stored = value ? "1" : "0";
        applied[settingKey] = Boolean(value);
      } else {
        stored = value === null ? null : String(value);
        applied[settingKey] = value;
      }

      await execute(
        "UPDATE settings SET value = ?, updated_by = ?, updated_at = NOW(3) WHERE group_key = ? AND setting_key = ?",
        [stored, userId, groupKey, settingKey],
        connection
      );
    }
  });
  return { applied, settings: await getSettings(groupKey) };
}

export async function generalSettingsOptions() {
  const [currencies, languages, countries, timezones] = await Promise.all([
    query("SELECT code, name, symbol FROM currencies WHERE is_active = 1 ORDER BY sort_order, code"),
    query("SELECT code, name FROM languages WHERE is_active = 1 ORDER BY sort_order, name"),
    query("SELECT slug, name FROM locations WHERE level = 'country' AND status = 'active' ORDER BY name LIMIT 250"),
    query("SELECT DISTINCT timezone FROM locations WHERE timezone IS NOT NULL ORDER BY timezone LIMIT 200").catch(() => []),
  ]);
  return {
    currencyOptions: currencies.map((row) => ({ value: row.code, label: `${row.code} — ${row.name}`, symbol: row.symbol })),
    languageOptions: languages.map((row) => ({ value: row.code, label: row.name })),
    countryOptions: countries.map((row) => ({ value: row.slug, label: row.name })),
    timezoneOptions: timezones.map((row) => ({ value: row.timezone, label: row.timezone })),
    dateFormatOptions: [
      { value: "DD/MM/YYYY", label: "31/12/2026" },
      { value: "MM/DD/YYYY", label: "12/31/2026" },
      { value: "YYYY-MM-DD", label: "2026-12-31" },
    ],
    numberFormatOptions: [
      { value: "1,234.56", label: "1,234.56" },
      { value: "1.234,56", label: "1.234,56" },
      { value: "1 234,56", label: "1 234,56" },
    ],
    pageSizeOptions: [10, 20, 30, 50, 100].map((value) => ({ value, label: String(value) })),
    listingApprovalModeOptions: [
      { value: "manual", label: "Manual review" },
      { value: "auto", label: "Publish immediately" },
      { value: "trusted", label: "Auto for verified accounts" },
    ],
    reviewApprovalModeOptions: [
      { value: "manual", label: "Manual review" },
      { value: "auto", label: "Publish immediately" },
    ],
    verificationExpiryOptions: [30, 90, 180, 365].map((value) => ({ value, label: `${value} days` })),
    sortOptions: [
      { value: "featured", label: "Featured" },
      { value: "newest", label: "Newest" },
      { value: "priceDesc", label: "Price: high to low" },
      { value: "priceAsc", label: "Price: low to high" },
    ],
    notificationChannelMeta: [
      { value: "email", label: "Email" },
      { value: "sms", label: "SMS" },
      { value: "push", label: "Push" },
      { value: "in_app", label: "In app" },
    ],
  };
}

export async function paymentSettingsOptions() {
  const [gateways, currencies] = await Promise.all([
    query("SELECT code, name, provider, status FROM payment_gateways ORDER BY name").catch(() => []),
    query("SELECT code, name FROM currencies WHERE is_active = 1 ORDER BY sort_order"),
  ]);
  return {
    providerMeta: gateways.map((row) => ({ value: row.provider || row.code, label: row.name, status: row.status })),
    currencyOptions: currencies.map((row) => ({ value: row.code, label: row.code })),
    environmentOptions: [
      { value: "test", label: "Test" },
      { value: "live", label: "Live" },
    ],
    billingCycleOptions: [
      { value: "monthly", label: "Monthly" },
      { value: "quarterly", label: "Quarterly" },
      { value: "yearly", label: "Yearly" },
    ],
    taxModeOptions: [
      { value: "inclusive", label: "Prices include tax" },
      { value: "exclusive", label: "Tax added at checkout" },
    ],
    prorationOptions: [
      { value: "immediate", label: "Prorate immediately" },
      { value: "next_cycle", label: "Apply at next cycle" },
      { value: "none", label: "No proration" },
    ],
    upgradeEffectiveOptions: [
      { value: "immediate", label: "Immediately" },
      { value: "next_cycle", label: "Next billing cycle" },
    ],
    downgradeEffectiveOptions: [
      { value: "immediate", label: "Immediately" },
      { value: "next_cycle", label: "Next billing cycle" },
    ],
    refundWindowOptions: [7, 14, 30, 60].map((value) => ({ value, label: `${value} days` })),
    refundReasonOptions: ["Duplicate charge", "Service not delivered", "Customer request", "Fraudulent"].map((value) => ({ value, label: value })),
    gracePeriodOptions: [0, 3, 7, 14].map((value) => ({ value, label: value ? `${value} days` : "None" })),
    renewalReminderDayOptions: [1, 3, 7, 14, 30].map((value) => ({ value, label: `${value} days before` })),
    paymentMethodMeta: ["card", "bank_transfer", "sepa_debit", "paypal", "apple_pay", "google_pay"].map((value) => ({ value, label: value })),
    paymentEventMeta: ["payment.succeeded", "payment.failed", "subscription.renewed", "subscription.cancelled", "refund.issued"].map((value) => ({ value, label: value })),
  };
}

/* -------------------------------------------------------------------------- */
/* Roles and access management                                                 */
/* -------------------------------------------------------------------------- */

export async function listAdminRoles({ page = 1, pageSize = 50 } = {}) {
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });
  const [rows, total] = await Promise.all([
    query(
      `SELECT r.id, r.code, r.name, r.description, r.scope, r.is_system, r.created_at,
              (SELECT COUNT(*) FROM user_roles ur WHERE ur.role_id = r.id) AS user_count
         FROM roles r WHERE r.scope = 'platform'
        ORDER BY r.sort_order ASC LIMIT ${safeSize} OFFSET ${offset}`
    ),
    queryValue("SELECT COUNT(*) FROM roles WHERE scope = 'platform'"),
  ]);

  const [permissions, scopes] = await Promise.all([
    query(`SELECT rp.role_id, p.code FROM role_permissions rp JOIN permissions p ON p.id = rp.permission_id`),
    query(`SELECT role_id, scope_type, scope_value FROM role_scopes ORDER BY scope_value`),
  ]);
  const byRole = permissions.reduce((map, row) => {
    const list = map.get(String(row.role_id)) || [];
    list.push(row.code);
    map.set(String(row.role_id), list);
    return map;
  }, new Map());
  const scopesByRole = scopes.reduce((map, row) => {
    const entry = map.get(String(row.role_id)) || { categories: [] };
    if (row.scope_type === "category") entry.categories.push(row.scope_value);
    map.set(String(row.role_id), entry);
    return map;
  }, new Map());

  // The Roles screen leads with four metric tiles. Computed here rather than derived from the
  // page's own rows, so the numbers describe every role rather than the current page of them.
  const totals = await queryOne(
    `SELECT COUNT(*) AS total,
            SUM(r.is_system = 0) AS custom,
            (SELECT COUNT(DISTINCT ur.user_id) FROM user_roles ur
               JOIN roles r2 ON r2.id = ur.role_id AND r2.scope = 'platform') AS assigned_users
       FROM roles r WHERE r.scope = 'platform'`
  );

  return adminList({
    summary: {
      total: int(totals?.total) ?? 0,
      // Every platform role is usable; there is no disabled state on the table, so "active"
      // is the count rather than a filter that would always be the same number.
      active: int(totals?.total) ?? 0,
      custom: int(totals?.custom) ?? 0,
      assignedUsers: int(totals?.assigned_users) ?? 0,
    },
    items: rows.map((row) => {
      const dbCodes = byRole.get(String(row.id)) || [];
      return {
        id: String(row.id),
        slug: row.code,
        name: row.name,
        description: row.description,
        status: "active",
        // The table draws a System/Custom tag and a permission count from these two.
        type: bool(row.is_system) ? "system" : "custom",
        permissionCount: dbCodes.length,
        protectedFromDelete: bool(row.is_system),
        userCount: int(row.user_count) ?? 0,
        databasePermissions: dbCodes.sort(),
        permissions: toAdminPermissions(dbCodes, { isSuperAdmin: row.code === "super_admin" }),
        // No category rows means the role is unrestricted, which is a different statement from
        // "restricted to nothing" — the UI needs to tell those apart.
        categoryScope: scopesByRole.get(String(row.id))?.categories ?? [],
        allCategories: (scopesByRole.get(String(row.id))?.categories ?? []).length === 0,
        createdAt: isoDate(row.created_at),
        updatedAt: isoDate(row.created_at),
      };
    }),
    total,
    page: safePage,
    pageSize: safeSize,
  });
}

export async function getAdminRole(identifier) {
  const result = await listAdminRoles({ pageSize: 100 });
  const role = result.items.find((item) => item.id === String(identifier) || item.slug === identifier);
  if (!role) return null;
  const activity = await query(
    `SELECT a.occurred_at, a.action, a.subject_label, u.display_name AS actor_name
       FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_user_id
      WHERE a.subject_type = 'role' AND a.subject_id = ? ORDER BY a.occurred_at DESC LIMIT 25`,
    [Number(role.id)]
  );
  return {
    ...role,
    activity: activity.map((entry) => ({
      action: entry.action,
      actor: entry.actor_name,
      details: entry.subject_label,
      timestamp: isoDate(entry.occurred_at),
    })),
  };
}

/**
 * Everything the Role editor needs to draw itself, from the database rather than a hardcoded
 * frontend catalogue.
 *
 * The matrix is two axes — domain down the side, action across the top — so a new permission
 * appears in the UI the moment its row exists, and a category added to the marketplace needs no
 * frontend change at all. That is the whole reason the codes carry no category: the grid is
 * `domain x action`, and the category is a separate selector beside it.
 */
export async function adminRoleOptions() {
  const [roles, permissions] = await Promise.all([
    query("SELECT id, code, name FROM roles WHERE scope = 'platform' ORDER BY sort_order"),
    query(
      `SELECT code, name, domain, action, is_scopable, sort_order, description
         FROM permissions ORDER BY sort_order, domain, action`
    ),
  ]);

  const actions = [...new Set(permissions.map((row) => row.action))];
  const domains = [];
  for (const row of permissions) {
    let domain = domains.find((entry) => entry.id === row.domain);
    if (!domain) {
      domain = {
        id: row.domain,
        label: DOMAIN_LABELS[row.domain] ?? row.domain,
        scopable: false,
        sortOrder: Number(row.sort_order) || 0,
        actions: {},
      };
      domains.push(domain);
    }
    if (bool(row.is_scopable)) domain.scopable = true;
    domain.actions[row.action] = { code: row.code, label: row.name, description: row.description };
  }
  domains.sort((a, b) => a.sortOrder - b.sortOrder);

  return {
    roles: roles.map((row) => ({ value: String(row.id), label: row.name, slug: row.code })),
    databasePermissions: permissions.map((row) => ({ value: row.code, label: row.name, domain: row.domain })),
    // The matrix: every domain, every action it supports, and whether a category scope applies.
    permissionMatrix: { actions, actionLabels: ACTION_LABELS, domains },
    // The categories a role can be narrowed to. Empty selection = every category.
    categoryScopeOptions: CATEGORY_DEFINITIONS.map((definition) => ({
      value: definition.listingType,
      label: definition.label,
    })),
    permissionUniverse: adminPermissionUniverse(),
    statuses: ["active", "inactive"],
  };
}

/** Presentation only — the grammar itself carries no display text. */
const ACTION_LABELS = Object.freeze({
  view: "View",
  create: "Create",
  edit: "Edit",
  delete: "Delete",
  moderate: "Moderate",
  publish: "Publish",
  verify: "Verify",
  suspend: "Suspend",
  assign: "Assign",
  resolve: "Resolve",
  decide: "Decide",
  export: "Export",
  feature: "Feature",
  refund: "Refund",
  payout: "Payout",
  plans: "Plans",
  manage: "Manage",
  impersonate: "Impersonate",
});

const DOMAIN_LABELS = Object.freeze({
  dashboard: "Dashboard",
  listings: "Listings",
  developments: "Developments",
  leads: "Leads",
  inquiries: "Inquiries",
  bookings: "Bookings",
  offers: "Offers",
  reviews: "Reviews",
  reports: "Reports",
  moderation: "Moderation",
  companies: "Companies",
  individuals: "Individuals",
  agents: "Agents",
  categoryAccess: "Category access",
  users: "Users",
  roles: "Roles",
  content: "Blog & pages",
  media: "Media library",
  emails: "Email templates",
  collections: "Collections",
  seo: "SEO",
  locations: "Locations",
  taxonomy: "Categories & brands",
  finance: "Finance",
  analytics: "Analytics",
  settings: "Settings",
  system: "System",
  api: "API & webhooks",
});

export async function listAdminAccessUsers({ status = "all", search = "", roleId = "", page = 1, pageSize = 20 } = {}) {
  const conditions = ["u.deleted_at IS NULL", "EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id)"];
  const params = [];
  if (status !== "all") {
    conditions.push("u.status = ?");
    params.push(status);
  }
  if (search) {
    conditions.push("(u.display_name LIKE ? OR u.email LIKE ?)");
    params.push(`%${search}%`, `%${search}%`);
  }
  if (roleId) {
    conditions.push("EXISTS (SELECT 1 FROM user_roles ur2 WHERE ur2.user_id = u.id AND ur2.role_id = ?)");
    params.push(Number(roleId));
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT u.id, u.public_id, u.first_name, u.last_name, u.display_name, u.email, u.phone_e164,
              u.status, u.avatar_url, u.last_login_at, u.created_at, u.updated_at,
              GROUP_CONCAT(r.id) AS role_ids, GROUP_CONCAT(r.name) AS role_names
         FROM users u
         LEFT JOIN user_roles ur ON ur.user_id = u.id
         LEFT JOIN roles r ON r.id = ur.role_id
         ${where}
        GROUP BY u.id
        ORDER BY u.created_at ASC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM users u ${where}`, params),
    // The Admin Users screen shows four counters and read them from a `summary` this
    // endpoint never sent, so the page threw on `summary.total`. These count every
    // administrator, not just the current page — that is what the screen claims.
    queryOne(
      `SELECT COUNT(*) AS total,
              SUM(u.status = 'active') AS active,
              SUM(u.status <> 'active') AS inactive,
              SUM(u.last_login_at IS NULL) AS neverLoggedIn
         FROM users u
        WHERE u.deleted_at IS NULL
          AND EXISTS (SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id)`
    ),
  ]);

  return adminList({
    items: rows.map((row) => ({
      id: row.public_id,
      userId: String(row.id),
      firstName: row.first_name,
      lastName: row.last_name,
      displayName: row.display_name,
      email: row.email,
      phone: row.phone_e164,
      avatar: row.avatar_url,
      jobTitle: (row.role_names || "").split(",")[0] || null,
      department: null,
      status: row.status,
      roleId: (row.role_ids || "").split(",")[0] || null,
      roleIds: (row.role_ids || "").split(",").filter(Boolean),
      roleNames: (row.role_names || "").split(",").filter(Boolean),
      lastLoginAt: isoDate(row.last_login_at),
      createdAt: isoDate(row.created_at),
      updatedAt: isoDate(row.updated_at),
    })),
    total,
    page: safePage,
    pageSize: safeSize,
    summary: {
      total: int(summary?.total) ?? 0,
      active: int(summary?.active) ?? 0,
      inactive: int(summary?.inactive) ?? 0,
      neverLoggedIn: int(summary?.neverLoggedIn) ?? 0,
    },
    options: await accessUserOptions(),
  });
}

export async function getAdminAccessUser(identifier) {
  const result = await listAdminAccessUsers({ pageSize: 200 });
  const user = result.items.find((item) => item.id === identifier || item.userId === identifier);
  if (!user) return null;
  const activity = await query(
    `SELECT occurred_at, action, subject_type, subject_label FROM audit_logs
      WHERE actor_user_id = ? ORDER BY occurred_at DESC LIMIT 50`,
    [Number(user.userId)]
  );
  return {
    ...user,
    activity: activity.map((entry) => ({
      action: entry.action,
      details: entry.subject_label || entry.subject_type,
      timestamp: isoDate(entry.occurred_at),
    })),
  };
}

/* -------------------------------------------------------------------------- */
/* System logs                                                                 */
/* -------------------------------------------------------------------------- */

// Anything matching these keys is masked before a log line leaves the server.
const SENSITIVE_KEYS = /^(authorization|cookie|password|secret|secretkey|signingsecret|token|apikey|api_key|set-cookie|x-api-key)$/i;

function redactContext(value, depth = 0) {
  if (value === null || value === undefined || depth > 4) return value;
  if (Array.isArray(value)) return value.slice(0, 30).map((entry) => redactContext(entry, depth + 1));
  if (typeof value !== "object") return value;
  const result = {};
  for (const [key, entry] of Object.entries(value)) {
    result[key] = SENSITIVE_KEYS.test(key) ? "[redacted]" : redactContext(entry, depth + 1);
  }
  return result;
}

export async function listAdminSystemLogs({ severity = "all", search = "", source = "", from, to, page = 1, pageSize = 20 } = {}) {
  const conditions = [];
  const params = [];
  if (severity !== "all") {
    conditions.push("s.level = ?");
    params.push(severity);
  }
  if (source) {
    conditions.push("s.channel = ?");
    params.push(source);
  }
  if (from) {
    conditions.push("s.occurred_at >= ?");
    params.push(new Date(from));
  }
  if (to) {
    conditions.push("s.occurred_at <= ?");
    params.push(new Date(`${to}T23:59:59`));
  }
  if (search) {
    conditions.push("(s.message LIKE ? OR s.exception_class LIKE ? OR s.request_id = ?)");
    params.push(`%${search}%`, `%${search}%`, search);
  }

  const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, summary] = await Promise.all([
    query(
      `SELECT s.id, s.occurred_at, s.level, s.channel, s.message, s.context, s.exception_class,
              s.request_id, s.user_id, s.url, s.http_method, s.http_status, s.duration_ms,
              u.display_name AS user_name
         FROM system_logs s LEFT JOIN users u ON u.id = s.user_id
         ${where} ORDER BY s.occurred_at DESC LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(`SELECT COUNT(*) FROM system_logs s ${where}`, params),
    queryOne(
      `SELECT COUNT(*) AS total,
              SUM(level IN ('critical','alert','emergency')) AS critical,
              SUM(level = 'error') AS error,
              SUM(level = 'warning') AS warning,
              SUM(level IN ('info','notice')) AS info,
              SUM(level = 'debug') AS debug
         FROM system_logs`
    ),
  ]);

  return adminList({
    items: rows.map(serializeSystemLog),
    total,
    page: safePage,
    pageSize: safeSize,
    summary: {
      total: int(summary?.total) ?? 0,
      critical: int(summary?.critical) ?? 0,
      error: int(summary?.error) ?? 0,
      warning: int(summary?.warning) ?? 0,
      info: int(summary?.info) ?? 0,
      debug: int(summary?.debug) ?? 0,
    },
    options: await systemLogFilterOptions(),
  });
}

function serializeSystemLog(row) {
  const context = typeof row.context === "string" ? safeParse(row.context) : row.context;
  return {
    id: String(row.id),
    createdAt: isoDate(row.occurred_at),
    severity: row.level,
    source: row.channel,
    message: row.message,
    error: row.exception_class,
    type: row.exception_class,
    requestId: row.request_id,
    correlationId: row.request_id,
    userId: row.user_id ? String(row.user_id) : null,
    userName: row.user_name,
    url: row.url,
    method: row.http_method,
    httpStatus: int(row.http_status),
    durationMs: int(row.duration_ms),
    // The stack trace is not returned in a list; it is on the detail read only.
    context: redactContext(context),
    metadata: redactContext(context),
  };
}

function safeParse(value) {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
}

export async function getAdminSystemLog(id) {
  const row = await queryOne(
    `SELECT s.*, u.display_name AS user_name FROM system_logs s
       LEFT JOIN users u ON u.id = s.user_id WHERE s.id = ? LIMIT 1`,
    [Number(id)]
  );
  if (!row) return null;
  return {
    ...serializeSystemLog(row),
    stack: row.stack_trace,
    technical: { exceptionClass: row.exception_class, stack: row.stack_trace },
  };
}

export async function getRelatedSystemLogs(id) {
  const row = await queryOne("SELECT request_id, occurred_at FROM system_logs WHERE id = ?", [Number(id)]);
  if (!row?.request_id) return [];
  const rows = await query(
    `SELECT s.id, s.occurred_at, s.level, s.channel, s.message, s.request_id, s.http_status
       FROM system_logs s WHERE s.request_id = ? AND s.id <> ? ORDER BY s.occurred_at ASC LIMIT 50`,
    [row.request_id, Number(id)]
  );
  return rows.map(serializeSystemLog);
}

export async function adminSystemLogOptions() {
  const [sources, environments] = await Promise.all([
    query("SELECT DISTINCT channel FROM system_logs WHERE channel IS NOT NULL ORDER BY channel LIMIT 100"),
    Promise.resolve([{ value: "production", label: "Production" }, { value: "staging", label: "Staging" }]),
  ]);
  return {
    severities: ["debug", "info", "notice", "warning", "error", "critical", "alert", "emergency"],
    sources: sources.map((row) => ({ value: row.channel, label: row.channel })),
    statuses: ["open", "acknowledged", "resolved"],
    types: [],
    environments,
    resolutionOptions: ["fixed", "wont_fix", "duplicate", "not_reproducible"],
  };
}

/* -------------------------------------------------------------------------- */
/* Admin settings documents                                                    */
/* -------------------------------------------------------------------------- */

/**
 * The admin General/Payment Settings screens own a nested document. Each
 * top-level section is one JSON row in `settings`, and the defaults the screen
 * ships with are used until an operator saves over them.
 */
export async function getSettingsDocument(groupKey, defaults = {}) {
  const { values, meta } = await getSettings(groupKey);
  const document = {};
  for (const [section, fallback] of Object.entries(defaults)) {
    const stored = values[section];
    document[section] = stored && typeof stored === "object" ? { ...fallback, ...stored } : fallback;
  }
  // Any stored section the defaults do not know about is still returned.
  for (const [section, stored] of Object.entries(values)) {
    if (!(section in document)) document[section] = stored;
  }
  return { document, meta };
}

/**
 * Saves a settings document and mirrors the values the public site reads into
 * the flat rows, so the marketplace and the admin screen cannot disagree about
 * the platform currency or language.
 */
const GENERAL_MIRROR = {
  "general.platformName": ["general", "site_name"],
  "general.currency": ["general", "default_currency"],
  "general.language": ["general", "default_language"],
  "general.defaultCountry": ["general", "default_country"],
};
const PAYMENT_MIRROR = {
  "general.defaultCurrency": ["payment", "currency"],
  "tax.rate": ["payment", "tax_rate"],
  "tax.label": ["payment", "tax_label"],
  "providers.environment": ["payment", "environment"],
  "invoices.prefix": ["payment", "invoice_prefix"],
};

export async function updateSettingsDocument({ groupKey, patch, userId }) {
  const sections = {};
  for (const [section, value] of Object.entries(patch)) {
    if (value === undefined) continue;
    sections[section] = value;
  }
  const result = await updateSettings({ groupKey, patch: sections, userId });

  const mirror = groupKey === "admin_general" ? GENERAL_MIRROR : groupKey === "admin_payment" ? PAYMENT_MIRROR : null;
  if (mirror) {
    for (const [path, [targetGroup, targetKey]] of Object.entries(mirror)) {
      const [section, key] = path.split(".");
      const value = sections[section]?.[key];
      if (value === undefined) continue;
      await updateSettings({ groupKey: targetGroup, patch: { [targetKey]: value }, userId });
    }
  }
  return result;
}

/** Selects above the User Accesses table. */
async function accessUserOptions() {
  return {
    roles: await options.roleOptions(),
    statuses: options.staticOptions(["active", "suspended", "pending_verification", "banned"]),
  };
}

/**
 * Selects above the System Logs table. Severity, channel and status come from
 * the rows actually present rather than a fixed list, so the filter can never
 * offer a value that matches nothing.
 */
async function systemLogFilterOptions() {
  const [severities, sources] = await Promise.all([
    options.distinct("system_logs", "level", { limit: 20 }),
    options.distinct("system_logs", "channel", { limit: 60 }),
  ]);
  return {
    severities,
    sources,
    statuses: options.staticOptions(["open", "acknowledged", "resolved"]),
    types: options.staticOptions(["request", "job", "webhook", "integration", "security", "database"]),
    environments: options.staticOptions(["development", "staging", "production"]),
  };
}

/* -------------------------------------------------------------------------- */
/* Audit search                                                                */
/* -------------------------------------------------------------------------- */
/**
 * Queries the audit trail.
 *
 * `audit_logs` is written faithfully by every mutation — 1,967 rows and growing — and had no
 * read API at all, so the record existed and no one could look at it. That is the difference
 * between an audit trail and a write-only log: an administrator asking "who suspended this
 * account, and when" had to open a database client.
 *
 * `changes` and `metadata` are already scrubbed of credentials at write time by
 * `system/audit.service.js`; they are returned as parsed JSON so the screen can render a diff.
 */
export async function searchAuditEvents({
  actor = "",
  action = "",
  subjectType = "",
  subjectId = "",
  from = "",
  to = "",
  search = "",
  page = 1,
  pageSize = 25,
} = {}) {
  const conditions = ["1 = 1"];
  const params = [];

  if (actor) {
    conditions.push("(u.email LIKE ? OR u.display_name LIKE ? OR a.actor_label LIKE ?)");
    params.push(`%${actor}%`, `%${actor}%`, `%${actor}%`);
  }
  if (action) {
    // Prefix match, so "listing." finds every listing action without listing them all.
    conditions.push("a.action LIKE ?");
    params.push(`${action}%`);
  }
  if (subjectType) {
    conditions.push("a.subject_type = ?");
    params.push(subjectType);
  }
  if (subjectId) {
    conditions.push("(a.subject_id = ? OR a.subject_label = ?)");
    params.push(Number(subjectId) || 0, String(subjectId));
  }
  if (from) {
    conditions.push("a.occurred_at >= ?");
    params.push(from);
  }
  if (to) {
    conditions.push("a.occurred_at <= ?");
    params.push(to);
  }
  if (search) {
    conditions.push("(a.action LIKE ? OR a.subject_label LIKE ? OR a.actor_label LIKE ? OR a.request_id = ?)");
    params.push(`%${search}%`, `%${search}%`, `%${search}%`, search);
  }

  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });

  const [rows, total, actions] = await Promise.all([
    query(
      `SELECT a.id, a.occurred_at, a.action, a.actor_type, a.actor_label, a.subject_type,
              a.subject_id, a.subject_label, a.changes, a.metadata, a.ip_address, a.request_id,
              u.email AS actor_email, u.display_name AS actor_name,
              imp.display_name AS impersonator_name
         FROM audit_logs a
         LEFT JOIN users u ON u.id = a.actor_user_id
         LEFT JOIN users imp ON imp.id = a.impersonator_user_id
         ${where}
        ORDER BY a.occurred_at DESC, a.id DESC
        LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryValue(
      `SELECT COUNT(*) FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_user_id ${where}`,
      params
    ),
    // The distinct action prefixes, so the filter offers what actually exists rather than a
    // hardcoded list that drifts as endpoints are added.
    query(
      `SELECT SUBSTRING_INDEX(action, '.', 1) AS domain, COUNT(*) AS total
         FROM audit_logs GROUP BY domain ORDER BY total DESC LIMIT 40`
    ),
  ]);

  const parse = (value) => {
    if (!value) return null;
    if (typeof value === "object") return value;
    try {
      return JSON.parse(value);
    } catch {
      return null;
    }
  };

  return adminList({
    items: rows.map((row) => ({
      id: String(row.id),
      occurredAt: isoDate(row.occurred_at),
      action: row.action,
      actor: {
        type: row.actor_type,
        name: row.actor_name ?? row.actor_label ?? "System",
        email: row.actor_email ?? null,
        impersonatedBy: row.impersonator_name ?? null,
      },
      subject: { type: row.subject_type, id: row.subject_id ? String(row.subject_id) : null, label: row.subject_label },
      changes: parse(row.changes),
      metadata: parse(row.metadata),
      ipAddress: row.ip_address,
      requestId: row.request_id,
    })),
    total,
    page: safePage,
    pageSize: safeSize,
    options: {
      domains: actions.map((row) => ({ value: row.domain, label: row.domain, count: int(row.total) ?? 0 })),
      subjectTypes: [...new Set(rows.map((row) => row.subject_type).filter(Boolean))],
    },
  });
}
