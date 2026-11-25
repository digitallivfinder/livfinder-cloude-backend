import { query, queryOne } from "../../db/query.js";
import { adminPagination, adminList } from "./admin.shared.js";
import { categoryByRootId } from "../../utils/categories.js";

/**
 * System Logs → Activity: the audit trail as sentences an operator can read, each linked to the
 * admin page of the thing it was about ("Alice Agentone updated listing LF-2001 · 2 bedroom…").
 *
 * Audit rows name their subject inconsistently — sometimes by internal id, sometimes by public
 * id in `subject_label` — so each subject is resolved by either before a link is built.
 */

const ADMIN_LISTING_CATEGORIES = new Set(["real-estate", "cars", "yachts", "jets", "helicopters", "watches"]);

const ACTIONS = {
  "auth.login": "signed in",
  "auth.logout": "signed out",
  "auth.email_verified": "verified their email",
  "auth.password_reset": "reset their password",
  "account.signup_organization": "signed up the company",
  "account.signup_personal": "signed up as an individual seller",
  "account.package_changed": "changed the package of",
  "account.free_access_granted": (row) => (row.changes?.enabled === false ? "removed free access from" : "gave free access to"),
  "account.addon_enabled": (row) => `${row.changes?.enabled === false ? "switched off" : "switched on"} the ${humanise(row.metadata?.addon || "add-on")} add-on for`,
  "account.verification_approve": "approved the account of",
  "account.verification_reject": "rejected the account of",
  "organization.verification_approve": "approved the verification of",
  "organization.verification_reject": "rejected the verification of",
  "category_access.decided": (row) =>
    `${row.changes?.decision === "approve" ? "approved" : row.changes?.decision === "reject" ? "rejected" : "decided"} ${humanise(row.changes?.categoryId || "category")} access for`,
  "api_client.created": "created an API key",
  "api_client.revoked": "revoked an API key",
  "inquiry.created": (row) => `received enquiry ${row.metadata?.reference || ""} on`.replace("  ", " "),
  "listing.created": "created the listing",
  "listing.updated": "updated the listing",
  "listing.approve": "approved the listing",
  "listing.reject": "rejected the listing",
  "listing.bulk_approve": "approved listings in bulk",
  "listing.bulk_reject": "rejected listings in bulk",
  "listing.imported": "imported the listing",
  "listing.import_updated": "updated the listing",
  "listing.import_withdrawn": "withdrew the listing",
  "listing.archived": "archived the listing",
  "development.imported": "imported the development",
  "development.import_updated": "updated the development",
  "development.import_withdrawn": "withdrew the development",
  "development.updated": "updated the development",
  "development.resubmitted": "resubmitted the development",
  "location.created": "added the location",
  "location.updated": "updated the location",
  "category.created": "added the category",
  "category.updated": "updated the category",
  "feed_mapping.set": "mapped a feed value",
  "feed_mapping.dismissed": "dismissed a feed value",
  "settings.updated": (row) => `updated the ${Array.isArray(row.changes) ? row.changes.slice(0, 3).map(humanise).join(", ") : "general"} settings`,
  "team.invited": (row) => `invited ${row.subject_label || "a member"} to`,
  "verification.document_read": "opened a verification document of",
  "internal_user.created": "added the user",
  "internal_user.updated": "updated the user",
  "internal_user.deleted": "deleted the user",
  "user.access_reset": "reset the access of",
};

// Actions whose subject is the actor themself, or that name no single subject.
const NO_SUBJECT = new Set(["account.signup_personal", "auth.login", "auth.logout", "auth.email_verified", "auth.password_reset", "api_client.created", "api_client.revoked", "feed_mapping.set", "feed_mapping.dismissed", "listing.bulk_approve", "listing.bulk_reject", "settings.updated"]);

const AREA_BY_TYPE = {
  listing: "Listing", project: "Development", organization: "Company", account: "Account", user: "User",
  location: "Location", category: "Category", settings: "Settings", api_client: "API", feed_value_mapping: "Feed mapping",
  verification_document: "Verification", inquiry: "Lead", lead: "Lead",
};

function humanise(value) {
  return String(value ?? "").replace(/[._-]+/g, " ").replace(/\s+/g, " ").trim().replace(/^\w/, (letter) => letter.toUpperCase());
}

function parse(value) {
  if (value === null || value === undefined) return null;
  if (typeof value !== "string") return value;
  try { return JSON.parse(value); } catch { return null; }
}

const isPublicId = (value) => typeof value === "string" && /^[0-9A-HJKMNP-TV-Z]{26}$/.test(value);

/** Finds the subject row by internal id or by the public id kept in the label. */
async function findBy(table, columns, row) {
  if (row.subject_id) {
    const found = await queryOne(`SELECT ${columns} FROM ${table} WHERE id = ? LIMIT 1`, [row.subject_id]);
    if (found) return found;
  }
  if (isPublicId(row.subject_label)) {
    return queryOne(`SELECT ${columns} FROM ${table} WHERE public_id = ? LIMIT 1`, [row.subject_label]);
  }
  return null;
}

async function companyOrIndividualForAccount(accountId) {
  const org = await queryOne("SELECT public_id, name FROM organizations WHERE account_id = ? AND deleted_at IS NULL LIMIT 1", [accountId]);
  if (org) return { name: org.name, href: `/admin/companies/${org.public_id}` };
  const owner = await queryOne(
    `SELECT u.public_id, u.display_name FROM account_members am JOIN users u ON u.id = am.user_id
      WHERE am.account_id = ? ORDER BY am.id LIMIT 1`,
    [accountId]
  ).catch(() => null);
  return owner ? { name: owner.display_name, href: `/admin/individuals/${owner.public_id}` } : null;
}

/** What the row was about, and the admin page for it. */
async function resolveSubject(row) {
  switch (row.subject_type) {
    case "listing": {
      if (row.action.startsWith("listing.bulk_")) return { name: null, href: "/admin/listings" };
      const listing = await findBy("listings", "id, public_id, reference, title, root_category_id", row);
      if (!listing) return null;
      const slug = categoryByRootId(listing.root_category_id)?.routeBase;
      if (row.action === "inquiry.created" && row.metadata?.reference) {
        const lead = await queryOne(
          `SELECT l.public_id FROM inquiries i JOIN leads l ON l.id = i.lead_id WHERE i.reference = ? LIMIT 1`,
          [row.metadata.reference]
        ).catch(() => null);
        if (lead && ADMIN_LISTING_CATEGORIES.has(slug)) {
          return { name: `${listing.reference} · ${listing.title}`, href: `/admin/listings/${slug}/leads/${lead.public_id}`, area: "Lead" };
        }
      }
      return {
        name: `${listing.reference} · ${listing.title}`,
        href: ADMIN_LISTING_CATEGORIES.has(slug) ? `/admin/listings/${slug}/${listing.public_id}` : null,
      };
    }
    case "project": {
      const project = await findBy("projects", "id, public_id, name", row);
      if (!project) return null;
      if (row.action === "inquiry.created" && row.metadata?.reference) {
        const lead = await queryOne(
          `SELECT l.public_id FROM inquiries i JOIN leads l ON l.id = i.lead_id WHERE i.reference = ? LIMIT 1`,
          [row.metadata.reference]
        ).catch(() => null);
        if (lead) return { name: project.name, href: `/admin/listings/real-estate-developments/leads/${lead.public_id}`, area: "Lead" };
      }
      return { name: project.name, href: `/admin/listings/real-estate-developments/${project.public_id}` };
    }
    case "organization": {
      const org = await findBy("organizations", "id, public_id, name", row);
      return org ? { name: org.name, href: `/admin/companies/${org.public_id}` } : null;
    }
    case "account": {
      // Some account actions store the company's or the person's public id, or the account number.
      const account = (await findBy("accounts", "id, public_id, name", row))
        || (/^\d+$/.test(String(row.subject_label ?? "")) ? await queryOne("SELECT id, public_id, name FROM accounts WHERE id = ?", [Number(row.subject_label)]) : null);
      if (account) return (await companyOrIndividualForAccount(account.id)) || { name: account.name, href: null };
      if (isPublicId(row.subject_label)) {
        const org = await queryOne("SELECT public_id, name FROM organizations WHERE public_id = ?", [row.subject_label]);
        if (org) return { name: org.name, href: `/admin/companies/${org.public_id}` };
        return resolveSubject({ ...row, subject_type: "user", subject_id: null });
      }
      return null;
    }
    case "user": {
      const user = await findBy("users", "id, public_id, display_name, email, default_account_id", row);
      if (!user) return null;
      const staff = await queryOne(
        "SELECT 1 AS yes FROM user_roles ur JOIN roles r ON r.id = ur.role_id AND r.scope = 'platform' WHERE ur.user_id = ? LIMIT 1",
        [user.id]
      );
      if (staff) return { name: user.display_name || user.email, href: `/admin/access-management/users/${user.public_id}` };
      const target = user.default_account_id ? await companyOrIndividualForAccount(user.default_account_id) : null;
      return { name: user.display_name || user.email, href: target?.href ?? null };
    }
    case "location":
      return { name: row.subject_label || "a location", href: "/admin/locations" };
    case "category":
      return { name: row.subject_label || "a category", href: "/admin/categories" };
    case "feed_value_mapping":
      return { name: null, href: "/admin/feed-mappings?tab=mapped" };
    case "settings":
      return { name: null, href: "/admin/general-settings" };
    case "api_client":
      // The key belongs to the company (or individual) of whoever created it.
      return row.actor_user_id ? resolveSubject({ ...row, subject_type: "user", subject_id: row.actor_user_id, subject_label: null }) : null;
    case "verification_document": {
      // A document belongs to a verification request about a company, an account or a user.
      const request = await queryOne(
        `SELECT vr.subject_type, vr.subject_id FROM verification_documents vd
           JOIN verification_requests vr ON vr.id = vd.verification_request_id
          WHERE vd.id = ? LIMIT 1`,
        [row.subject_id]
      ).catch(() => null);
      if (!request) return null;
      if (request.subject_type === "organization") {
        const org = await queryOne("SELECT public_id, name FROM organizations WHERE id = ?", [request.subject_id]);
        return org ? { name: org.name, href: `/admin/companies/${org.public_id}` } : null;
      }
      if (request.subject_type === "account") return companyOrIndividualForAccount(request.subject_id);
      return resolveSubject({ ...row, subject_type: "user", subject_id: request.subject_id, subject_label: null });
    }
    default:
      return null;
  }
}

function actorName(row) {
  if (row.actor_name) return row.actor_name;
  if (row.actor_type === "api") return row.actor_label ? row.actor_label.replace(/\s*\(lf_[^)]*\)/, "") : "An API key";
  if (row.actor_type === "system" || row.actor_type === "job") return "LivFinder";
  if (row.actor_type === "anonymous") return "A visitor";
  return row.actor_label || "Someone";
}

async function describe(row) {
  const subject = await resolveSubject(row).catch(() => null);
  const verb = ACTIONS[row.action];
  const phrase = typeof verb === "function" ? verb(row) : verb || humanise(row.action).toLowerCase();
  const actor = row.action === "inquiry.created" ? "LivFinder" : actorName(row);
  const subjectName = NO_SUBJECT.has(row.action) ? null : subject?.name || (isPublicId(row.subject_label) ? null : row.subject_label);
  const bulkCount = row.action.startsWith("listing.bulk_") && Array.isArray(row.metadata?.ids) ? ` (${row.metadata.ids.length})` : "";
  return {
    id: String(row.id),
    at: row.occurred_at instanceof Date ? row.occurred_at.toISOString() : row.occurred_at,
    actor,
    actorEmail: row.actor_email || null,
    actorType: row.actor_type,
    action: row.action,
    area: subject?.area || AREA_BY_TYPE[row.subject_type] || humanise(row.subject_type || "other"),
    // Imports name the method after the subject: "… withdrew the listing LF-2005 · Ferrari by import".
    summary: `${actor} ${phrase}${subjectName ? ` ${subjectName}` : ""}${bulkCount}${/\.import_/.test(row.action) ? " by import" : ""}`,
    href: subject?.href ?? null,
    requestId: row.request_id || null,
  };
}

export async function listActivity({ search = "", area = "", from = "", to = "", page = 1, pageSize = 20 } = {}) {
  const conditions = ["1 = 1"];
  const params = [];
  if (search) {
    conditions.push("(a.action LIKE ? OR a.subject_label LIKE ? OR a.actor_label LIKE ? OR u.display_name LIKE ? OR u.email LIKE ?)");
    params.push(...Array(5).fill(`%${search}%`));
  }
  if (area) {
    const types = Object.entries(AREA_BY_TYPE).filter(([, label]) => label === area).map(([type]) => type);
    if (types.length) {
      conditions.push(`a.subject_type IN (${types.map(() => "?").join(", ")})`);
      params.push(...types);
    }
  }
  if (from) { conditions.push("a.occurred_at >= ?"); params.push(from); }
  if (to) { conditions.push("a.occurred_at < DATE_ADD(?, INTERVAL 1 DAY)"); params.push(to); }
  const where = `WHERE ${conditions.join(" AND ")}`;
  const { page: safePage, pageSize: safeSize, offset } = adminPagination({ page, pageSize });
  const [rows, totalRow] = await Promise.all([
    query(
      `SELECT a.id, a.occurred_at, a.action, a.actor_type, a.actor_label, a.actor_user_id, a.subject_type, a.subject_id,
              a.subject_label, a.changes, a.metadata, a.request_id,
              u.display_name AS actor_name, u.email AS actor_email
         FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_user_id
         ${where}
        ORDER BY a.occurred_at DESC, a.id DESC
        LIMIT ${safeSize} OFFSET ${offset}`,
      params
    ),
    queryOne(`SELECT COUNT(*) AS total FROM audit_logs a LEFT JOIN users u ON u.id = a.actor_user_id ${where}`, params),
  ]);
  const items = await Promise.all(
    rows.map((row) => describe({ ...row, changes: parse(row.changes), metadata: parse(row.metadata) }))
  );
  return adminList({
    items,
    total: Number(totalRow?.total ?? 0),
    page: safePage,
    pageSize: safeSize,
    options: { areas: [...new Set(Object.values(AREA_BY_TYPE))].sort().map((label) => ({ value: label, label })) },
  });
}
