import { callProcedure, execute, query, queryOne, queryValue } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { resolveCategory } from "../../utils/categories.js";
import { AppError } from "../../utils/errors.js";

/**
 * What a seller account is: an Individual, a Company or a Developer (owner decision, 2026-11-14).
 *
 * Stored on `accounts.seller_type` (migration 0079); NULL for a Member, who cannot sell. The
 * seller picks it when applying and an admin can change it. Every rule that depends on it lives
 * here:
 *
 * - Only a Developer may hold Real Estate Developments (category 7): proper projects with units
 *   and payment plans come from the builder, not from an agency or a reseller.
 * - A Developer is always a company (`organizations.kind = 'developer'`); an individual never is.
 * - Whether a Developer may also list in Real Estate is not decided yet. One switch,
 *   `DEVELOPERS_MAY_LIST_REAL_ESTATE`, holds that decision; today they may, where admin granted it.
 */
export const SELLER_TYPES = ["individual", "company", "developer"];
export const SELLER_TYPE_LABELS = { individual: "Individual", company: "Company", developer: "Developer" };

export const DEVELOPMENTS_ROOT_ID = 7;
export const REAL_ESTATE_ROOT_ID = 1;
export const DEVELOPERS_MAY_LIST_REAL_ESTATE = true;

const DEVELOPMENTS_ONLY_MESSAGE = "Real Estate Developments are for developer accounts only.";

/** The seller type an account would have from what it is made of. */
export function sellerTypeFor({ accountTypeCode, organizationKind } = {}) {
  if (organizationKind) return organizationKind === "developer" ? "developer" : "company";
  if (accountTypeCode === "lister") return "individual";
  if (["company", "organization", "partner"].includes(accountTypeCode)) return "company";
  return null;
}

/** Whether a seller of this type may hold the category (a root id, slug or frontend id). */
export function sellerTypeAllowsCategory(sellerType, category) {
  const rootId = typeof category === "number" ? category : resolveCategory(category)?.rootId;
  if (rootId === DEVELOPMENTS_ROOT_ID) return sellerType === "developer";
  if (rootId === REAL_ESTATE_ROOT_ID && sellerType === "developer") return DEVELOPERS_MAY_LIST_REAL_ESTATE;
  return true;
}

export function categoryRefusal(sellerType, category) {
  const rootId = typeof category === "number" ? category : resolveCategory(category)?.rootId;
  if (rootId === DEVELOPMENTS_ROOT_ID) return DEVELOPMENTS_ONLY_MESSAGE;
  if (rootId === REAL_ESTATE_ROOT_ID && sellerType === "developer") return "Developer accounts cannot list in Real Estate.";
  return "This account type cannot list in that category.";
}

export async function sellerTypeOf(accountId, connection) {
  if (!accountId) return null;
  return queryValue("SELECT seller_type FROM accounts WHERE id = ?", [accountId], connection);
}

/** Throws a 403 when the account's type may not hold the category. */
export async function assertSellerTypeAllowsCategory(accountId, category, connection) {
  const sellerType = await sellerTypeOf(accountId, connection);
  if (!sellerTypeAllowsCategory(sellerType, category)) {
    throw new AppError(categoryRefusal(sellerType, category), { status: 403, code: "SELLER_TYPE_NOT_ALLOWED" });
  }
}

/**
 * The seller type an application asks for, checked against the category it chose.
 * A Developer applies as a company with business type 'developer' and lists developments.
 */
export function applicationSellerType(input) {
  if (input.accountType !== "organization") return "individual";
  return input.organizationType === "developer" ? "developer" : "company";
}

export function assertApplicationCategory(input) {
  const sellerType = applicationSellerType(input);
  const category = resolveCategory(input.categoryId);
  if (category && !sellerTypeAllowsCategory(sellerType, category.rootId)) {
    throw AppError.validation("Some information is invalid.", { categoryId: categoryRefusal(sellerType, category.rootId) });
  }
  if (sellerType === "developer" && category && category.rootId !== DEVELOPMENTS_ROOT_ID) {
    throw AppError.validation("Some information is invalid.", { categoryId: "A developer lists Real Estate Developments." });
  }
}

/**
 * An admin changing what an account is. Developments access follows the type:
 * - becoming a Developer grants it;
 * - leaving Developer revokes it, and the account's projects go back to draft and off the
 *   website (nothing is deleted; open change requests close).
 * A Developer must be a company; an individual can only stay an Individual.
 *
 * @returns {{ sellerType, projectsHidden, changed }}
 */
export async function setSellerType({ accountId, sellerType, userId }) {
  if (!SELLER_TYPES.includes(sellerType)) {
    throw AppError.validation("Some information is invalid.", { sellerType: "Choose Individual, Company or Developer." });
  }
  const account = await queryOne(
    `SELECT a.id, a.seller_type, o.id AS organization_id, o.kind
       FROM accounts a
       LEFT JOIN organizations o ON o.account_id = a.id AND o.deleted_at IS NULL
      WHERE a.id = ? AND a.deleted_at IS NULL`,
    [accountId]
  );
  if (!account) throw AppError.notFound("That account was not found.");
  const isCompany = Boolean(account.organization_id);
  if (sellerType === "individual" && isCompany) {
    throw AppError.validation("Some information is invalid.", { sellerType: "A company account is a Company or a Developer." });
  }
  if (sellerType !== "individual" && !isCompany) {
    throw AppError.validation("Some information is invalid.", { sellerType: "Only a company can be a Company or a Developer." });
  }
  if (account.seller_type === sellerType) return { sellerType, projectsHidden: 0, changed: false };

  let projectsHidden = 0;
  const hiddenProjectIds = [];
  await withTransaction(async (connection) => {
    await execute("UPDATE accounts SET seller_type = ? WHERE id = ?", [sellerType, accountId], connection);
    if (isCompany) {
      // The business type keeps in step: a developer is kind 'developer'; a company leaving it is an agency.
      const kind = sellerType === "developer" ? "developer" : account.kind === "developer" ? "agency" : account.kind;
      await execute("UPDATE organizations SET kind = ? WHERE id = ?", [kind, account.organization_id], connection);
    }
    if (sellerType === "developer") {
      await execute(
        `INSERT INTO account_category_access (account_id, category_id, status, listing_used, requested_at, reviewed_at, reviewed_by_user_id, notes, created_at)
         VALUES (?, ?, 'approved', 0, NOW(3), NOW(3), ?, 'Developer account.', NOW(3))
         ON DUPLICATE KEY UPDATE status = 'approved', reviewed_at = NOW(3), reviewed_by_user_id = VALUES(reviewed_by_user_id), notes = VALUES(notes)`,
        [accountId, DEVELOPMENTS_ROOT_ID, userId ?? null],
        connection
      );
      return;
    }
    await execute(
      `UPDATE account_category_access
          SET status = 'revoked', reviewed_at = NOW(3), reviewed_by_user_id = ?, notes = ?
        WHERE account_id = ? AND category_id = ? AND status IN ('requested','approved','suspended')`,
      [userId ?? null, DEVELOPMENTS_ONLY_MESSAGE, accountId, DEVELOPMENTS_ROOT_ID],
      connection
    );
    if (!isCompany) return;
    const projects = await query(
      `SELECT id, pending_revision_id FROM projects
        WHERE organization_id = ? AND deleted_at IS NULL AND moderation_status <> 'archived'`,
      [account.organization_id],
      connection
    );
    for (const project of projects) {
      if (project.pending_revision_id) {
        await execute("UPDATE project_revisions SET status = 'superseded' WHERE id = ? AND status = 'pending'", [project.pending_revision_id], connection);
      }
      await execute(
        `UPDATE projects SET moderation_status = 'draft', is_publicly_visible = 0, pending_revision_id = NULL, updated_at = NOW(3)
          WHERE id = ?`,
        [project.id],
        connection
      );
      hiddenProjectIds.push(project.id);
    }
    projectsHidden = projects.length;
  });
  for (const projectId of hiddenProjectIds) {
    await callProcedure("sp_refresh_project_search", [projectId]);
  }
  return { sellerType, projectsHidden, changed: true };
}

/** What a change would do, for the admin's confirm dialog. */
export async function sellerTypeChangePreview(accountId) {
  const organizationId = await queryValue("SELECT id FROM organizations WHERE account_id = ? AND deleted_at IS NULL LIMIT 1", [accountId]);
  const projects = organizationId
    ? await queryValue(
        "SELECT COUNT(*) FROM projects WHERE organization_id = ? AND deleted_at IS NULL AND moderation_status <> 'archived'",
        [organizationId]
      )
    : 0;
  return { projects: Number(projects) || 0 };
}
