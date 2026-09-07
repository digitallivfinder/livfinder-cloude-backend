import { queryOne } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { hasPlatformPermission } from "../auth/rbac.js";

/**
 * Resource-level authorization for listings.
 *
 * A portal caller reaches a listing through their *account*, never through a
 * guessed id: the listing's account_id must match the caller's active account.
 * Platform staff take the separate permission path. This is the only place the
 * check exists, so no route can forget it.
 */
export async function assertListingAccess(req, identifier, action = "view") {
  if (!req.auth?.user) throw AppError.unauthorized();

  const listing = await queryOne(
    `SELECT id, public_id, reference, account_id, organization_id, agent_id, created_by_user_id,
            status, moderation_status, root_category_id, category_id, purpose_id, slug,
            canonical_path, title
       FROM listings
      WHERE (public_id = ? OR reference = ? OR (id = ? AND ? > 0))
        AND deleted_at IS NULL
      LIMIT 1`,
    [
      String(identifier),
      String(identifier),
      /^\d+$/.test(String(identifier)) ? Number(identifier) : 0,
      /^\d+$/.test(String(identifier)) ? 1 : 0,
    ]
  );
  if (!listing) throw AppError.notFound("That listing was not found.");

  const platformCode = action === "view" ? "listings.view" : action === "moderate" ? "listings.moderate" : "listings.edit";
  if (hasPlatformPermission(req.auth.platform, platformCode)) return listing;

  const membership = req.auth.activeMembership;
  if (!membership || String(membership.account_id) !== String(listing.account_id)) {
    // Deliberately 404, not 403: confirming the listing exists would leak the
    // existence of another account's inventory.
    throw AppError.notFound("That listing was not found.");
  }

  if (action !== "view") {
    const canEdit = membership.role === "owner" || membership.can_manage_listings === 1;
    if (!canEdit) throw AppError.forbidden("You do not have permission to change listings on this account.");
    // An agent may only change the listings assigned to them.
    if (membership.role === "agent" && req.auth.agent && listing.agent_id && String(listing.agent_id) !== String(req.auth.agent.id)) {
      throw AppError.forbidden("That listing is assigned to another agent.");
    }
  }
  return listing;
}

/** The organization behind the caller's active account, or a 403. */
export function requireOrganizationId(req) {
  const organizationId = req.auth?.activeMembership?.organization_id;
  if (!organizationId) throw AppError.forbidden("This account is not linked to an organization.");
  return organizationId;
}

export function requireAccountId(req) {
  const accountId = req.auth?.activeAccountId;
  if (!accountId) throw AppError.forbidden("This account cannot use the client portal.");
  return accountId;
}

/** Ownership check for any table carrying an account_id. */
export async function assertAccountOwned(req, table, identifier, { column = "public_id" } = {}) {
  const allowedTables = new Set([
    "saved_searches", "collections", "inquiries", "bookings", "offers", "reviews",
    "conversations", "listings", "agents", "organizations",
  ]);
  if (!allowedTables.has(table)) throw new TypeError(`ownership check not defined for ${table}`);

  const row = await queryOne(`SELECT * FROM ${table} WHERE ${column} = ? LIMIT 1`, [identifier]);
  if (!row) throw AppError.notFound();

  const accountId = req.auth?.activeAccountId;
  const userId = req.auth?.user?.id;
  const organizationId = req.auth?.activeMembership?.organization_id;

  const owned =
    (row.account_id && String(row.account_id) === String(accountId)) ||
    (row.user_id && String(row.user_id) === String(userId)) ||
    (row.organization_id && String(row.organization_id) === String(organizationId));

  if (!owned) throw AppError.notFound();
  return row;
}
