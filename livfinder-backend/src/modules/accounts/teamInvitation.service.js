import { z } from "zod";
import env from "../../config/env.js";
import logger from "../../config/logger.js";
import { execute, query, queryOne, queryValue } from "../../db/query.js";
import { withTransaction } from "../../db/transaction.js";
import { AppError } from "../../utils/errors.js";
import { randomToken, sha256Hex, ulid } from "../../utils/ids.js";
import { PHONE_LENGTH_MESSAGE, splitPhone } from "../../utils/phone.js";
import { normalizeEmail } from "../auth/auth.service.js";
import { hashPassword, passwordPolicyError } from "../auth/passwords.js";
import { createSession } from "../auth/sessions.js";
import { sendMail } from "../system/mail.service.js";
import { uniqueAgentSlug } from "../portal/organization.service.js";

/**
 * A company inviting a person onto its team.
 *
 * The link in the email is the only proof of that mailbox, so it stands in for email
 * confirmation. A new person sets a password on it; someone who already has a Member account
 * signs in first, and that login has to match the invited address. A seller keeps their own
 * business, so an individual or company account cannot join another company.
 */
const LIFETIME_DAYS = 7;
const OPEN = "status = 'pending' AND expires_at > NOW(3)";

const ROLE_CAPABILITIES = {
  manager: { members: 1, listings: 1, publish: 1, leads: 1, integrations: 1 },
  agent: { members: 0, listings: 1, publish: 0, leads: 1, integrations: 0 },
  viewer: { members: 0, listings: 0, publish: 0, leads: 0, integrations: 0 },
};
const ROLE_LABELS = { manager: "Manager", agent: "Agent", viewer: "Viewer" };

const personName = z.string().trim().max(120).regex(/^[^<>]*\p{L}[^<>]*$/u, "Enter a name.");

export const invitationCreateSchema = z.object({
  email: z.string().trim().toLowerCase().email("Enter a valid email address.").max(255),
  firstName: personName.optional().or(z.literal("")),
  lastName: personName.optional().or(z.literal("")),
  role: z.enum(["manager", "agent", "viewer"]).default("agent"),
  title: z.string().trim().max(120).optional().or(z.literal("")),
  agentId: z.string().max(40).optional().nullable(),
});

export const invitationAcceptSchema = z.object({
  token: z.string().min(20).max(200),
  firstName: personName.optional(),
  lastName: personName.optional(),
  password: z.string().max(200).optional(),
  phone: z.string().trim().regex(/^\+[1-9]\d{6,14}$/, PHONE_LENGTH_MESSAGE).optional().or(z.literal("")),
  agreements: z.boolean().optional(),
});

function serialize(row) {
  const expired = row.status === "pending" && new Date(row.expires_at).getTime() <= Date.now();
  return {
    id: row.public_id,
    email: row.email,
    firstName: row.first_name,
    lastName: row.last_name,
    role: row.role,
    title: row.title,
    status: expired ? "expired" : row.status,
    invitedAt: row.created_at,
    expiresAt: row.expires_at,
    acceptedAt: row.accepted_at,
  };
}

async function sendInvitation({ invitation, token, companyName, inviterName }) {
  const url = `${env.FRONTEND_URL}/accept-invite?token=${encodeURIComponent(token)}`;
  try {
    const result = await sendMail({
      to: invitation.email,
      subject: `${companyName} invited you to LivFinder`,
      text: [
        `${inviterName} invited you to join ${companyName} on LivFinder as ${ROLE_LABELS[invitation.role]}.`,
        `Accept the invitation: ${url}`,
        `The link works for ${LIFETIME_DAYS} days. If you were not expecting this, you can ignore it.`,
      ].join("\n\n"),
    });
    return result?.delivered !== false;
  } catch (error) {
    logger.error({ err: error, invitationId: invitation.public_id }, "team invitation could not be sent");
    return false;
  }
}

async function inviteContext(organizationId, userId) {
  const [company, inviter] = await Promise.all([
    queryOne("SELECT id, name, account_id FROM organizations WHERE id = ?", [organizationId]),
    queryOne("SELECT display_name, first_name, email FROM users WHERE id = ?", [userId]),
  ]);
  return { company, inviterName: inviter?.display_name || inviter?.first_name || inviter?.email };
}

/** NULL on the plan means unlimited. An invitation waiting to be accepted holds a seat too. */
async function assertSeatAvailable(accountId) {
  const quota = await queryValue(
    `SELECT p.agent_seat_quota FROM subscriptions s JOIN plans p ON p.id = s.plan_id
      WHERE s.account_id = ? AND s.status IN ('active', 'trialing') ORDER BY s.id DESC LIMIT 1`,
    [accountId]
  );
  if (quota === null || quota === undefined) return;
  const members = await queryValue("SELECT COUNT(*) FROM account_members WHERE account_id = ? AND status = 'active'", [accountId]);
  const waiting = await queryValue(`SELECT COUNT(*) FROM team_invitations WHERE account_id = ? AND ${OPEN}`, [accountId]);
  if (Number(members) + Number(waiting) >= Number(quota)) {
    throw AppError.conflict("Your plan has no free team seats. Upgrade it or cancel a waiting invitation.");
  }
}

export async function listInvitations(organizationId) {
  const rows = await query(
    `SELECT * FROM team_invitations WHERE organization_id = ? AND status IN ('pending', 'accepted') ORDER BY id DESC LIMIT 100`,
    [organizationId]
  );
  return rows.map(serialize);
}

/** `inviterLabel` names the sender in the email when it is not a member of the company (admin). */
export async function createInvitation({ organizationId, payload, userId, inviterLabel = null }) {
  const context = await inviteContext(organizationId, userId);
  const { company } = context;
  const inviterName = inviterLabel ?? context.inviterName;
  const emailNormalized = normalizeEmail(payload.email);

  let agentId = null;
  if (payload.agentId) {
    const agent = await queryOne(
      "SELECT id, user_id FROM agents WHERE public_id = ? AND organization_id = ? AND deleted_at IS NULL",
      [payload.agentId, organizationId]
    );
    if (!agent) throw AppError.notFound("That agent was not found.");
    if (agent.user_id) throw AppError.conflict("That agent already has a login.");
    agentId = agent.id;
  }

  const member = await queryValue(
    `SELECT am.id FROM account_members am JOIN users u ON u.id = am.user_id
      WHERE am.account_id = ? AND am.status = 'active' AND u.email_normalized = ?`,
    [company.account_id, emailNormalized]
  );
  if (member) throw AppError.conflict("That person is already on your team.", { email: "That person is already on your team." });
  const waiting = await queryValue(
    `SELECT id FROM team_invitations WHERE account_id = ? AND email_normalized = ? AND ${OPEN}`,
    [company.account_id, emailNormalized]
  );
  if (waiting) throw AppError.conflict("That person already has an invitation.", { email: "That person already has an invitation. Resend it instead." });
  await assertSeatAvailable(company.account_id);

  const token = randomToken(32);
  const invitation = {
    public_id: ulid(),
    email: payload.email,
    role: payload.role,
  };
  await execute(
    `INSERT INTO team_invitations
       (public_id, account_id, organization_id, agent_id, email, email_normalized, first_name, last_name, role, title,
        token_hash, invited_by_user_id, expires_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(3), INTERVAL ? DAY), NOW(3))`,
    [invitation.public_id, company.account_id, organizationId, agentId, payload.email, emailNormalized,
      payload.firstName || null, payload.lastName || null, payload.role, payload.title || null,
      sha256Hex(token), userId, LIFETIME_DAYS]
  );
  const delivered = await sendInvitation({ invitation, token, companyName: company.name, inviterName });
  const row = await queryOne("SELECT * FROM team_invitations WHERE public_id = ?", [invitation.public_id]);
  return { ...serialize(row), delivered };
}

async function managedInvitation(organizationId, publicId) {
  const row = await queryOne("SELECT * FROM team_invitations WHERE public_id = ? AND organization_id = ?", [publicId, organizationId]);
  if (!row) throw AppError.notFound("That invitation was not found.");
  if (row.status !== "pending") throw AppError.conflict("That invitation has already been closed.");
  return row;
}

/** A new link replaces the old one, which stops working. */
export async function resendInvitation({ organizationId, publicId, userId, inviterLabel = null }) {
  const row = await managedInvitation(organizationId, publicId);
  const token = randomToken(32);
  await execute(
    "UPDATE team_invitations SET token_hash = ?, expires_at = DATE_ADD(NOW(3), INTERVAL ? DAY) WHERE id = ?",
    [sha256Hex(token), LIFETIME_DAYS, row.id]
  );
  const context = await inviteContext(organizationId, userId);
  const delivered = await sendInvitation({ invitation: row, token, companyName: context.company.name, inviterName: inviterLabel ?? context.inviterName });
  return { ...serialize(await queryOne("SELECT * FROM team_invitations WHERE id = ?", [row.id])), delivered };
}

export async function revokeInvitation({ organizationId, publicId }) {
  const row = await managedInvitation(organizationId, publicId);
  await execute("UPDATE team_invitations SET status = 'revoked', revoked_at = NOW(3) WHERE id = ?", [row.id]);
  return { id: row.public_id, status: "revoked" };
}

async function openInvitation(token, connection) {
  const row = await queryOne(
    `SELECT ti.*, o.name AS company_name, o.status AS company_status
       FROM team_invitations ti JOIN organizations o ON o.id = ti.organization_id
      WHERE ti.token_hash = ? ${connection ? "FOR UPDATE" : ""}`,
    [sha256Hex(token)],
    connection
  );
  if (!row || row.status !== "pending" || new Date(row.expires_at).getTime() <= Date.now()) {
    throw new AppError("This invitation is no longer valid. Ask the company to send a new one.", {
      status: 410,
      code: "INVITATION_INVALID",
    });
  }
  return row;
}

/** Seller accounts the person owns. A Member's `personal` account does not count. */
async function ownsSellerAccount(userId, connection) {
  return Boolean(
    await queryValue(
      `SELECT a.id FROM account_members am
         JOIN accounts a ON a.id = am.account_id JOIN account_types t ON t.id = a.account_type_id
        WHERE am.user_id = ? AND am.role = 'owner' AND am.status = 'active' AND t.code <> 'personal' LIMIT 1`,
      [userId],
      connection
    )
  );
}

export async function previewInvitation(token) {
  const row = await openInvitation(token);
  const user = await queryOne("SELECT id FROM users WHERE email_normalized = ? AND deleted_at IS NULL", [row.email_normalized]);
  return {
    company: row.company_name,
    email: row.email,
    role: row.role,
    roleLabel: ROLE_LABELS[row.role],
    firstName: row.first_name,
    lastName: row.last_name,
    hasAccount: Boolean(user),
    isSeller: user ? await ownsSellerAccount(user.id) : false,
  };
}

async function joinTeam({ invitation, userId, connection }) {
  const can = ROLE_CAPABILITIES[invitation.role];
  await execute(
    `INSERT INTO account_members
       (account_id, user_id, role, status, title, can_manage_members, can_manage_listings, can_publish_listings,
        can_manage_leads, can_view_integrations, invited_by_user_id, invited_at, joined_at, created_at)
     VALUES (?, ?, ?, 'active', ?, ?, ?, ?, ?, ?, ?, ?, NOW(3), NOW(3))
     ON DUPLICATE KEY UPDATE status = 'active', role = VALUES(role), title = VALUES(title),
       can_manage_members = VALUES(can_manage_members), can_manage_listings = VALUES(can_manage_listings),
       can_publish_listings = VALUES(can_publish_listings), can_manage_leads = VALUES(can_manage_leads),
       can_view_integrations = VALUES(can_view_integrations), joined_at = NOW(3), removed_at = NULL`,
    [invitation.account_id, userId, invitation.role, invitation.title, can.members, can.listings, can.publish,
      can.leads, can.integrations, invitation.invited_by_user_id, invitation.created_at],
    connection
  );
  await execute("UPDATE users SET default_account_id = ? WHERE id = ?", [invitation.account_id, userId], connection);

  // Only a person who works listings has a public profile; a viewer has none unless one was named.
  const user = await queryOne("SELECT first_name, last_name, display_name, email, phone_e164 FROM users WHERE id = ?", [userId], connection);
  const own = await queryValue("SELECT id FROM agents WHERE user_id = ? AND deleted_at IS NULL LIMIT 1", [userId], connection);
  const agentId = invitation.agent_id ?? own;
  if (agentId) {
    await execute(
      `UPDATE agents SET user_id = ?, organization_id = ?, status = 'active', joined_at = COALESCE(joined_at, CURDATE()),
              title = COALESCE(?, title), email = COALESCE(email, ?), phone = COALESCE(phone, ?) WHERE id = ?`,
      [userId, invitation.organization_id, invitation.title, user.email, user.phone_e164, agentId],
      connection
    );
  } else if (invitation.role !== "viewer") {
    const name = user.display_name || `${user.first_name} ${user.last_name}`.trim();
    await execute(
      `INSERT INTO agents
         (public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, email, phone,
          status, verification_status, is_publicly_visible, joined_at, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', 'unverified', 1, CURDATE(), NOW(3))`,
      [ulid(), userId, invitation.organization_id, user.first_name, user.last_name, name,
        await uniqueAgentSlug(name, connection), invitation.title, user.email, user.phone_e164],
      connection
    );
  }
  await execute(
    "UPDATE organizations SET agent_count = (SELECT COUNT(*) FROM agents WHERE organization_id = ? AND deleted_at IS NULL) WHERE id = ?",
    [invitation.organization_id, invitation.organization_id],
    connection
  );
  await execute(
    "UPDATE team_invitations SET status = 'accepted', accepted_at = NOW(3), accepted_user_id = ? WHERE id = ?",
    [userId, invitation.id],
    connection
  );
}

async function createInvitedUser({ invitation, input, connection }) {
  const fields = {};
  const firstName = input.firstName || invitation.first_name;
  const lastName = input.lastName || invitation.last_name;
  if (!firstName) fields.firstName = "Enter your first name.";
  if (!lastName) fields.lastName = "Enter your last name.";
  const policyError = input.password ? passwordPolicyError(input.password, { email: invitation.email }) : "Choose a password.";
  if (policyError) fields.password = policyError;
  if (!input.agreements) fields.agreements = "Accept the terms to continue.";
  const phone = input.phone ? splitPhone(input.phone) : null;
  if (phone) {
    const owner = await queryValue(
      "SELECT id FROM users WHERE phone_country_code = ? AND phone_number = ? LIMIT 1",
      [phone.countryCode, phone.number],
      connection
    );
    if (owner) fields.phone = "An account with that phone number already exists.";
  }
  if (Object.keys(fields).length) throw AppError.validation("Some information is invalid.", fields);

  const result = await execute(
    `INSERT INTO users
       (public_id, email, email_normalized, email_verified_at, password_hash, password_updated_at, status, first_name,
        last_name, display_name, phone_country_code, phone_number, terms_accepted_at, created_at)
     VALUES (?, ?, ?, NOW(3), ?, NOW(3), 'active', ?, ?, ?, ?, ?, NOW(3), NOW(3))`,
    [ulid(), invitation.email, invitation.email_normalized, await hashPassword(input.password), firstName, lastName,
      `${firstName} ${lastName}`.trim(), phone?.countryCode ?? null, phone?.number ?? null],
    connection
  );
  return result.insertId;
}

/**
 * Accepting. A new person gets a user and a session; an existing one must already be signed in
 * as the invited address, and carries on in their session on the company's account.
 */
export async function acceptInvitation({ input, auth, ip, userAgent }) {
  return withTransaction(async (connection) => {
    const invitation = await openInvitation(input.token, connection);
    if (invitation.company_status !== "active") {
      throw AppError.conflict("This company cannot add people at the moment.");
    }
    const existing = await queryOne(
      "SELECT id, session_epoch FROM users WHERE email_normalized = ? AND deleted_at IS NULL",
      [invitation.email_normalized],
      connection
    );

    if (!existing) {
      const userId = await createInvitedUser({ invitation, input, connection });
      await joinTeam({ invitation, userId, connection });
      const user = await queryOne("SELECT session_epoch FROM users WHERE id = ?", [userId], connection);
      const session = await createSession(
        { userId, sessionEpoch: user.session_epoch, activeAccountId: invitation.account_id, ip, userAgent },
        connection
      );
      return { userId, session, accountId: invitation.account_id };
    }

    if (!auth?.user) {
      throw new AppError("Sign in with this email address to accept.", { status: 401, code: "SIGN_IN_REQUIRED" });
    }
    if (String(auth.user.id) !== String(existing.id)) {
      throw AppError.forbidden("This invitation was sent to a different email address.");
    }
    if (await ownsSellerAccount(existing.id, connection)) {
      throw AppError.conflict("This login already has a seller account, so it cannot join another company.");
    }
    await execute("UPDATE users SET email_verified_at = COALESCE(email_verified_at, NOW(3)) WHERE id = ?", [existing.id], connection);
    await joinTeam({ invitation, userId: existing.id, connection });
    return { userId: existing.id, session: null, accountId: invitation.account_id };
  });
}

/** Someone taken off the team stops being able to act for the company; putting them back restores it. */
export async function syncMembershipWithAgent({ agentId, status, connection }) {
  const agent = await queryOne(
    `SELECT a.user_id, o.account_id FROM agents a JOIN organizations o ON o.id = a.organization_id WHERE a.id = ?`,
    [agentId],
    connection
  );
  if (!agent?.user_id) return;
  await execute(
    "UPDATE account_members SET status = ? WHERE account_id = ? AND user_id = ? AND role <> 'owner'",
    [status === "active" ? "active" : "suspended", agent.account_id, agent.user_id],
    connection
  );
}
