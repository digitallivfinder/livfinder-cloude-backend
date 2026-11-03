import crypto from "node:crypto";
import logger from "../../config/logger.js";
import { execute, queryValue } from "../../db/query.js";
import { ulid } from "../../utils/ids.js";
import { slugify } from "../../utils/slug.js";

/**
 * A Member: a person with an account who is not a seller.
 *
 * The `personal` account type cannot list. It needs no review, so it opens straight away and
 * is shared by email signup and social sign-in. Becoming a seller changes this same account.
 */
export async function createMemberAccount({ userId, displayName, email }, connection) {
  const slugBase = slugify(displayName) || "member";
  const result = await execute(
    `INSERT INTO accounts
       (public_id, account_type_id, owner_user_id, name, slug, status, verification_status,
        listing_quota, listing_used, billing_email, created_at)
     VALUES (?, (SELECT id FROM account_types WHERE code = 'personal'), ?, ?, ?, 'active', 'unverified', 0, 0, ?, NOW(3))`,
    [ulid(), userId, displayName, `${slugBase}-${crypto.randomBytes(4).toString("hex")}`, email],
    connection
  );
  await execute(
    `INSERT INTO account_members
       (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings,
        can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at, created_at)
     VALUES (?, ?, 'owner', 'active', 1, 1, 1, 1, 1, 1, 1, NOW(3), NOW(3))`,
    [result.insertId, userId],
    connection
  );
  await execute("UPDATE users SET default_account_id = ? WHERE id = ?", [result.insertId, userId], connection);
  return result.insertId;
}

/**
 * Enquiries and viewings sent before an account existed, or while signed out.
 *
 * Only a confirmed address claims them: typing someone else's email must reveal nothing.
 */
export async function claimRecordsByEmail(userId) {
  try {
    const verified = await queryValue("SELECT email_normalized FROM users WHERE id = ? AND email_verified_at IS NOT NULL", [userId]);
    if (!verified) return;
    await execute("UPDATE inquiries SET user_id = ? WHERE user_id IS NULL AND LOWER(email) = ?", [userId, verified]);
    await execute("UPDATE bookings SET user_id = ? WHERE user_id IS NULL AND LOWER(contact_email) = ?", [userId, verified]);
  } catch (error) {
    logger.error({ err: error, userId }, "earlier enquiries could not be linked");
  }
}
