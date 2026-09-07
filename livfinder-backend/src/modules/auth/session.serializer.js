import { query, queryOne } from "../../db/query.js";
import { loadPlatformAccess, loadAccountMemberships, loadAgentProfile } from "./rbac.js";
import { toAdminPermissions, loadPermissionUniverse } from "./adminPermissions.js";
import { frontendCategoryId } from "../../utils/categories.js";
import { isoDate } from "../../serializers/primitives.js";

/**
 * The session payload the frontend auth guards already read.
 *
 * Shape (unchanged from the fixture contract):
 *   { authenticated, user, account, accountCategories, personalProfile,
 *     organization, organizationMember, admin }
 */
const ACCOUNT_TYPE_MAP = {
  personal: "personal",
  lister: "personal",
  company: "organization",
  organization: "organization",
  partner: "organization",
};

function accountState(row) {
  if (!row) return null;
  if (row.account_status === "suspended" || row.account_status === "closed") return "suspended";
  if (row.account_status === "pending") return "pending_verification";
  if (row.verification_status === "pending" || row.verification_status === "unverified") {
    // A personal account never needs verification to be usable.
    return ACCOUNT_TYPE_MAP[row.account_type_code] === "organization" ? "pending_verification" : "active";
  }
  if (row.verification_status === "rejected" || row.verification_status === "expired") return "pending_verification";
  return "active";
}

export async function serializeSession(userId, { sessionId = null, activeAccountId = null } = {}) {
  const user = await queryOne(
    `SELECT id, public_id, email, phone_e164, first_name, last_name, display_name, avatar_url,
            status, email_verified_at, default_account_id, created_at, updated_at
       FROM users WHERE id = ? AND deleted_at IS NULL`,
    [userId]
  );
  if (!user) return null;

  const [platform, memberships, agent] = await Promise.all([
    loadPlatformAccess(userId),
    loadAccountMemberships(userId),
    loadAgentProfile(userId),
  ]);

  const membership =
    memberships.find((entry) => String(entry.account_id) === String(activeAccountId)) ||
    memberships.find((entry) => String(entry.account_id) === String(user.default_account_id)) ||
    memberships[0] ||
    null;

  const isPlatformStaff = platform.roles.length > 0;
  const accountType = membership ? ACCOUNT_TYPE_MAP[membership.account_type_code] || "personal" : null;

  let account = null;
  let organization = null;
  let organizationMember = null;
  let accountCategories = [];
  let personalProfile = null;

  if (membership) {
    const accountRow = await queryOne(
      `SELECT a.id, a.public_id, a.name, a.status, a.verification_status, a.created_at, a.updated_at,
              at.code AS account_type_code
         FROM accounts a JOIN account_types at ON at.id = a.account_type_id
        WHERE a.id = ?`,
      [membership.account_id]
    );

    if (accountType === "organization") {
      const organizationRow = await queryOne(
        `SELECT id, public_id, account_id, name, legal_name, slug, status, kind, logo_url,
                verification_status, is_publicly_visible, created_at, updated_at
           FROM organizations WHERE account_id = ? AND deleted_at IS NULL LIMIT 1`,
        [membership.account_id]
      );
      if (organizationRow) {
        organization = {
          id: organizationRow.public_id,
          organizationId: String(organizationRow.id),
          accountId: accountRow?.public_id ?? String(membership.account_id),
          legalName: organizationRow.legal_name || organizationRow.name,
          displayName: organizationRow.name,
          slug: organizationRow.slug,
          kind: organizationRow.kind,
          logoUrl: organizationRow.logo_url,
          status: organizationRow.status,
          verificationStatus: organizationRow.verification_status,
          isPubliclyVisible: organizationRow.is_publicly_visible === 1,
          createdAt: isoDate(organizationRow.created_at),
          updatedAt: isoDate(organizationRow.updated_at),
        };

        const categories = await query(
          `SELECT oca.id, oca.status, oca.requested_at, oca.reviewed_at, oca.reviewed_by_user_id,
                  oca.notes, oca.created_at, oca.updated_at,
                  COALESCE(c.root_category_id, c.id) AS root_category_id
             FROM organization_category_access oca
             JOIN categories c ON c.id = oca.category_id
            WHERE oca.organization_id = ?`,
          [organizationRow.id]
        );
        accountCategories = categories.map((row) => ({
          id: `ac_${row.id}`,
          categoryId: frontendCategoryId(row.root_category_id),
          // The frontend vocabulary is active/requested/rejected.
          status: row.status === "approved" ? "active" : row.status === "revoked" ? "rejected" : row.status,
          requestedAt: isoDate(row.requested_at),
          approvedAt: row.status === "approved" ? isoDate(row.reviewed_at) : null,
          approvedBy: row.reviewed_by_user_id ? String(row.reviewed_by_user_id) : null,
          rejectionReason: row.status === "rejected" ? row.notes || null : undefined,
          restrictions: [],
          createdAt: isoDate(row.created_at),
          updatedAt: isoDate(row.updated_at),
        }));
      }

      const memberRow = await queryOne(
        `SELECT id, account_id, user_id, role, status, title,
                can_manage_organization, can_manage_members, can_manage_listings,
                can_publish_listings, can_manage_leads, can_view_integrations,
                can_manage_billing, created_at, updated_at
           FROM account_members WHERE account_id = ? AND user_id = ? LIMIT 1`,
        [membership.account_id, userId]
      );
      if (memberRow) {
        /**
         * The capability flags `requireAccountCapability` actually enforces.
         *
         * They were never serialized, so the portal had to infer permission from the
         * role name — and a member whose per-membership flag restricts them was still
         * shown management UI that the server then refused. Hidden UI is not
         * authorization, but UI that disagrees with the boundary is its own defect.
         *
         * An owner holds every capability on their own account regardless of the
         * flags, which exist to restrict delegated members. That rule lives in
         * `requireAccountCapability`; it is mirrored here so the two cannot drift.
         */
        const isOwner = memberRow.role === "owner";
        const can = (column) => isOwner || memberRow[column] === 1;

        organizationMember = {
          id: `mem_${memberRow.id}`,
          organizationId: organization?.id ?? null,
          userId: user.public_id,
          // The real role. `accountant` used to be reported as `viewer`, so an
          // accountant's finance access was indistinguishable from read-only.
          role: memberRow.role,
          title: memberRow.title,
          status: memberRow.status,
          capabilities: {
            manageOrganization: can("can_manage_organization"),
            manageMembers: can("can_manage_members"),
            manageListings: can("can_manage_listings"),
            publishListings: can("can_publish_listings"),
            manageLeads: can("can_manage_leads"),
            viewIntegrations: can("can_view_integrations"),
            manageBilling: can("can_manage_billing"),
          },
          createdAt: isoDate(memberRow.created_at),
          updatedAt: isoDate(memberRow.updated_at),
        };
      }
    } else {
      // A private lister's category access is implied by their account type.
      accountCategories = membership.account_type_code === "lister"
        ? [
            {
              id: `ac_${membership.account_id}_realEstate`,
              categoryId: "realEstate",
              status: "active",
              requestedAt: isoDate(accountRow?.created_at),
              approvedAt: isoDate(accountRow?.created_at),
              approvedBy: null,
              restrictions: [],
              createdAt: isoDate(accountRow?.created_at),
              updatedAt: isoDate(accountRow?.updated_at),
            },
          ]
        : [];
    }

    if (agent) {
      personalProfile = {
        id: agent.public_id,
        accountId: accountRow?.public_id ?? String(membership.account_id),
        publicSlug: agent.slug,
        bio: null,
        photoUrl: agent.photo_url,
        createdAt: isoDate(accountRow?.created_at),
        updatedAt: isoDate(accountRow?.updated_at),
      };
    }

    account = {
      id: accountRow?.public_id ?? String(membership.account_id),
      accountId: String(membership.account_id),
      name: accountRow?.name ?? null,
      accountType,
      accountTypeCode: membership.account_type_code,
      state: accountState({
        account_status: accountRow?.status,
        verification_status: accountRow?.verification_status,
        account_type_code: membership.account_type_code,
      }),
      listingQuota: membership.listing_quota === null ? null : Number(membership.listing_quota),
      listingUsed: Number(membership.listing_used || 0),
      createdAt: isoDate(accountRow?.created_at),
      updatedAt: isoDate(accountRow?.updated_at),
    };
  } else if (isPlatformStaff) {
    // Platform staff hold no marketplace account. The admin guards still expect
    // an active account object, so the staff seat is represented as one.
    account = {
      id: `acct_platform_${user.public_id}`,
      accountId: null,
      name: "LivFinder Platform",
      accountType: "platform",
      accountTypeCode: "platform",
      state: "active",
      listingQuota: 0,
      listingUsed: 0,
      createdAt: isoDate(user.created_at),
      updatedAt: isoDate(user.updated_at),
    };
  }

  // A super admin resolves to the whole catalogue, so make sure it is loaded before asking.
  if (isPlatformStaff) await loadPermissionUniverse();

  const admin = isPlatformStaff
    ? {
        role: platform.roles[0],
        roles: platform.roles,
        // One vocabulary: these are the codes the server enforces, not a presentation
        // translation of them. See modules/auth/adminPermissions.js.
        permissions: toAdminPermissions([...platform.permissions], { isSuperAdmin: platform.isSuperAdmin }),
        databasePermissions: [...platform.permissions].sort(),
        // The category slice this user's roles cover. `allCategories` distinguishes
        // "unrestricted" from "restricted to nothing", which the UI has to show differently.
        categoryScope: [...(platform.scopes?.categories ?? [])].sort(),
        allCategories: platform.scopes?.allCategories ?? true,
      }
    : null;

  return {
    authenticated: true,
    sessionId,
    user: {
      id: user.public_id,
      userId: String(user.id),
      firstName: user.first_name,
      lastName: user.last_name,
      displayName: user.display_name,
      email: user.email,
      phone: user.phone_e164 || null,
      avatarUrl: user.avatar_url,
      platformRole: isPlatformStaff ? "admin" : "client",
      emailVerified: Boolean(user.email_verified_at),
      status: user.status,
      createdAt: isoDate(user.created_at),
      updatedAt: isoDate(user.updated_at),
    },
    account,
    accounts: memberships.map((entry) => ({
      id: entry.account_public_id,
      accountId: String(entry.account_id),
      name: entry.account_name,
      accountType: ACCOUNT_TYPE_MAP[entry.account_type_code] || "personal",
      role: entry.role,
      isActive: String(entry.account_id) === String(membership?.account_id),
    })),
    accountCategories,
    personalProfile,
    organization,
    organizationMember,
    admin,
  };
}

export const UNAUTHENTICATED_SESSION = Object.freeze({
  authenticated: false,
  user: null,
  account: null,
  accountCategories: [],
  personalProfile: null,
  organization: null,
  organizationMember: null,
  admin: null,
});
