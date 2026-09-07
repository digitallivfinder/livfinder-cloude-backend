import { query, queryOne } from "../../db/query.js";

/**
 * Platform (admin) permissions, resolved from user_roles → role_permissions.
 * super_admin is treated as holding every permission so a new permission code
 * does not silently lock the platform owner out.
 */
export async function loadPlatformAccess(userId) {
  const rows = await query(
    `SELECT r.code AS role_code, p.code AS permission_code
       FROM user_roles ur
       JOIN roles r ON r.id = ur.role_id AND r.scope = 'platform'
       LEFT JOIN role_permissions rp ON rp.role_id = r.id
       LEFT JOIN permissions p ON p.id = rp.permission_id
      WHERE ur.user_id = ?
        AND (ur.expires_at IS NULL OR ur.expires_at > NOW(3))`,
    [userId]
  );
  const roles = [...new Set(rows.map((row) => row.role_code))];
  const permissions = new Set(rows.map((row) => row.permission_code).filter(Boolean));
  const isSuperAdmin = roles.includes("super_admin");

  /**
   * Category scope — the second half of the permission model.
   *
   * A permission answers "may they do this at all". A scope answers "over which slice". They
   * are kept apart on purpose: encoding the slice into the permission key (`listings.cars.edit`)
   * is what LIV-IAM-001 §6.2 forbids, and it does not scale — a seventh category would mint a
   * fresh permission for every action.
   *
   * The rule is deliberately permissive by default: a role with no `category` scope rows is
   * unrestricted. Restriction is something an administrator opts into, so existing roles and
   * any role created without touching the category selector keep working.
   *
   * A user holding several roles gets the union. Holding one unrestricted role therefore makes
   * the user unrestricted, which is the correct reading of "these two roles both apply".
   */
  const scopeRows = isSuperAdmin
    ? []
    : await query(
        `SELECT DISTINCT rs.scope_type, rs.scope_value
           FROM user_roles ur
           JOIN roles r ON r.id = ur.role_id AND r.scope = 'platform'
           JOIN role_scopes rs ON rs.role_id = r.id
          WHERE ur.user_id = ?
            AND (ur.expires_at IS NULL OR ur.expires_at > NOW(3))
            AND EXISTS (
              SELECT 1 FROM role_scopes any_scope
               WHERE any_scope.role_id = r.id AND any_scope.scope_type = rs.scope_type
            )`,
        [userId]
      );

  // A role with no category rows at all makes the whole user unrestricted, so check for one
  // before assembling the union.
  const unrestricted = isSuperAdmin || (await hasUnrestrictedCategoryRole(userId));
  const categories = new Set(
    scopeRows.filter((row) => row.scope_type === "category").map((row) => row.scope_value)
  );

  return {
    roles,
    permissions,
    isSuperAdmin,
    scopes: { categories, allCategories: unrestricted || categories.size === 0 },
  };
}

/** True when the user holds at least one platform role that declares no category restriction. */
async function hasUnrestrictedCategoryRole(userId) {
  const row = await query(
    `SELECT 1 AS ok
       FROM user_roles ur
       JOIN roles r ON r.id = ur.role_id AND r.scope = 'platform'
      WHERE ur.user_id = ?
        AND (ur.expires_at IS NULL OR ur.expires_at > NOW(3))
        AND NOT EXISTS (
          SELECT 1 FROM role_scopes rs WHERE rs.role_id = r.id AND rs.scope_type = 'category'
        )
      LIMIT 1`,
    [userId]
  );
  return row.length > 0;
}

export async function allPermissionCodes() {
  const rows = await query("SELECT code FROM permissions ORDER BY code");
  return rows.map((row) => row.code);
}

/**
 * Account memberships for a user, already resolved to a permission set by
 * v_account_permissions. One indexed read, no role join at request time.
 */
export async function loadAccountMemberships(userId) {
  return query(
    `SELECT vp.account_id,
            vp.role,
            vp.membership_status,
            vp.account_type_code,
            vp.account_status,
            vp.verification_status,
            vp.organization_id,
            vp.can_manage_organization,
            vp.can_manage_members,
            vp.can_manage_listings,
            vp.can_publish_listings,
            vp.can_manage_leads,
            vp.can_view_integrations,
            vp.can_manage_billing,
            a.name  AS account_name,
            a.slug  AS account_slug,
            a.public_id AS account_public_id,
            a.listing_quota,
            a.listing_used
       FROM v_account_permissions vp
       JOIN accounts a ON a.id = vp.account_id
      WHERE vp.user_id = ?
      ORDER BY (vp.role = 'owner') DESC, a.id ASC`,
    [userId]
  );
}

export async function loadAgentProfile(userId) {
  return queryOne(
    `SELECT id, public_id, organization_id, display_name, slug, photo_url, status, is_publicly_visible
       FROM agents
      WHERE user_id = ? AND deleted_at IS NULL
      LIMIT 1`,
    [userId]
  );
}

export function hasPlatformPermission(access, code) {
  if (!access) return false;
  if (access.isSuperAdmin) return true;
  return access.permissions.has(code);
}

/** Any one of the listed codes is enough. */
export function hasAnyPlatformPermission(access, codes) {
  return codes.some((code) => hasPlatformPermission(access, code));
}

export const ACCOUNT_CAPABILITIES = Object.freeze([
  "can_manage_organization",
  "can_manage_members",
  "can_manage_listings",
  "can_publish_listings",
  "can_manage_leads",
  "can_view_integrations",
  "can_manage_billing",
]);
