import request from "supertest";
import { createApp } from "../../src/app.js";
import { query, queryOne, execute } from "../../src/db/query.js";
import { hashPassword } from "../../src/modules/auth/passwords.js";

/**
 * Integration test harness.
 *
 * The tests run against the real database, because the point of them is the SQL
 * — the visibility view, the transactions, the projection refresh. Fixtures are
 * created with a unique suffix per run and removed afterwards, so a run leaves
 * the seed exactly as it found it.
 */
export const app = createApp();

export function client() {
  const agent = request.agent(app);
  return {
    agent,
    csrfToken: null,
    async get(path, query) {
      const req = agent.get(path);
      if (query) req.query(query);
      return req;
    },
    async send(method, path, body) {
      const req = agent[method](path).set("Accept", "application/json");
      if (this.csrfToken) req.set("X-CSRF-Token", this.csrfToken);
      return body === undefined ? req : req.send(body);
    },
    async login(email, password = "LivFinder!2026") {
      const response = await agent.post("/v1/auth/login").send({ email, password });
      if (response.status === 200) {
        this.csrfToken = response.body.data.csrfToken;
        this.email = email;
        this.password = password;
      }
      return response;
    },
    /**
     * Re-proves the session before a high-risk action — SEC-IAM-011.
     *
     * Real clients do this after a 403 with `STEP_UP_REQUIRED`, so a test that skips it is not
     * testing the flow a person goes through. Password-based, because these accounts have no
     * MFA factor enrolled; `mfa.test.js` covers the code-based path.
     */
    async stepUp() {
      return this.send("post", "/v1/auth/step-up", { password: this.password ?? "LivFinder!2026" });
    },
  };
}

/** A demo account owner who can use the portal. */
export async function findPortalOwner() {
  return queryOne(
    `SELECT u.id, u.email, am.account_id, a.public_id AS account_public_id, o.id AS organization_id
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
       JOIN organizations o ON o.account_id = a.id
      WHERE u.status = 'active' AND u.deleted_at IS NULL
        AND EXISTS (SELECT 1 FROM account_category_access aca
                     JOIN categories c ON c.id = aca.category_id
                    WHERE aca.account_id = a.id AND aca.status = 'approved' AND c.id = 1)
      ORDER BY u.id LIMIT 1`
  );
}

export async function findSecondPortalOwner(excludeAccountId) {
  return queryOne(
    `SELECT u.id, u.email, am.account_id
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
      WHERE u.status = 'active' AND u.deleted_at IS NULL AND am.account_id <> ?
      ORDER BY u.id LIMIT 1`,
    [excludeAccountId]
  );
}

export async function adminEmail(role = "super_admin") {
  const row = await queryOne(
    `SELECT u.email FROM users u JOIN user_roles ur ON ur.user_id = u.id
       JOIN roles r ON r.id = ur.role_id AND r.code = ?
      WHERE u.status = 'active' ORDER BY u.id LIMIT 1`,
    [role]
  );
  return row?.email ?? null;
}

/** Guarantees the demo users have a password these tests can use. */
export async function ensureTestPassword(password = "LivFinder!2026") {
  const hash = await hashPassword(password);
  await execute(
    `UPDATE users SET password_hash = ?, failed_login_count = 0, locked_until = NULL
      WHERE deleted_at IS NULL AND password_hash NOT LIKE '$argon2%'`,
    [hash]
  );
}

/** Removes rows created by a test run, newest first so foreign keys hold. */
export async function cleanupListings(publicIds) {
  for (const publicId of publicIds) {
    const listing = await queryOne("SELECT id, account_id, unit_id FROM listings WHERE public_id = ?", [publicId]);
    if (!listing) continue;
    const ownerAccountId = listing.account_id;
    await execute("DELETE FROM listing_search WHERE listing_id = ?", [listing.id]);
    await execute("DELETE FROM listing_media WHERE listing_id = ?", [listing.id]);
    await execute("DELETE FROM listing_features WHERE listing_id = ?", [listing.id]);
    await execute("DELETE FROM listing_attribute_values WHERE listing_id = ?", [listing.id]);
    await execute("DELETE FROM listing_status_history WHERE listing_id = ?", [listing.id]);
    await execute("DELETE FROM listing_price_history WHERE listing_id = ?", [listing.id]).catch(() => {});
    for (const table of ["listing_real_estate", "listing_vehicle", "listing_marine", "listing_aviation", "listing_timepiece"]) {
      await execute(`DELETE FROM ${table} WHERE listing_id = ?`, [listing.id]);
    }
    await execute("DELETE FROM inquiries WHERE listing_id = ?", [listing.id]);
    // A public enquiry now creates a real admin lead (engagement.routes.js
    // linkInquiryToLead). `leads.primary_listing_id` is ON DELETE SET NULL, so
    // deleting the listing alone left each of those leads behind with no
    // property — nine runs of the lifecycle suite left 54 of them in the dev
    // database, and the admin Leads page crashed on every one. Delete the
    // leads first; their activities, stage history and assignments cascade.
    await execute("DELETE FROM leads WHERE primary_listing_id = ?", [listing.id]);
    await execute("DELETE FROM favourites WHERE listing_id = ?", [listing.id]);
    await execute("DELETE FROM listings WHERE id = ?", [listing.id]);
    // A hard delete bypasses the service, so the owner's allowance usage is recomputed here.
    // It used to be left counting the deleted listing, and because the suite shares the dev
    // database, repeated runs pushed the seeded portal owner to 500/500 "allowance used".
    if (ownerAccountId) {
      const { syncAccountListingUsage } = await import("../../src/modules/listings/listings.service.js");
      await syncAccountListingUsage(ownerAccountId);
    }
    // Likewise the property unit a real-estate listing registered: its counters kept counting
    // the deleted listing ("unit listing count disagrees with listings" in the integrity suite).
    if (listing.unit_id) {
      await execute(
        `UPDATE property_units u
            SET u.listing_count = (SELECT COUNT(*) FROM listings l WHERE l.unit_id = u.id AND l.deleted_at IS NULL),
                u.active_listing_count = (SELECT COUNT(*) FROM listings l WHERE l.unit_id = u.id AND l.deleted_at IS NULL AND l.status = 'active')
          WHERE u.id = ?`,
        [listing.unit_id]
      );
    }
  }
}

export async function cleanupUsers(emails) {
  for (const email of emails) {
    const user = await queryOne("SELECT id, default_account_id FROM users WHERE email_normalized = ?", [email.toLowerCase()]);
    if (!user) continue;
    const accounts = await query("SELECT account_id FROM account_members WHERE user_id = ?", [user.id]);
    await execute("DELETE FROM user_sessions WHERE user_id = ?", [user.id]);
    await execute("DELETE FROM user_tokens WHERE user_id = ?", [user.id]);
    // Disposable staff users hold a role and may have enrolled MFA; owners may have favourited.
    await execute("DELETE FROM user_roles WHERE user_id = ?", [user.id]);
    await execute("DELETE FROM user_mfa_factors WHERE user_id = ?", [user.id]).catch(() => {});
    await execute("DELETE FROM favourites WHERE user_id = ?", [user.id]).catch(() => {});
    await execute("DELETE FROM verification_documents WHERE verification_request_id IN (SELECT id FROM verification_requests WHERE requested_by_user_id = ?)", [user.id]);
    await execute("DELETE FROM verification_requests WHERE requested_by_user_id = ?", [user.id]);
    await execute("DELETE FROM agents WHERE user_id = ?", [user.id]);
    await execute("DELETE FROM account_members WHERE user_id = ?", [user.id]);
    await execute("UPDATE users SET default_account_id = NULL WHERE id = ?", [user.id]);
    for (const row of accounts) {
      await execute("DELETE FROM account_category_access WHERE account_id = ?", [row.account_id]);
      await execute("DELETE FROM organization_category_access WHERE organization_id IN (SELECT id FROM organizations WHERE account_id = ?)", [row.account_id]);
      await execute("DELETE FROM organization_licenses WHERE organization_id IN (SELECT id FROM organizations WHERE account_id = ?)", [row.account_id]);
      await execute("DELETE FROM organizations WHERE account_id = ?", [row.account_id]);
      await execute("DELETE FROM accounts WHERE id = ?", [row.account_id]);
    }
    await execute("DELETE FROM users WHERE id = ?", [user.id]);
  }
}

/**
 * Removes projects created by a test run.
 *
 * Ordered so foreign keys hold, and it clears the search projection first — a
 * project deleted out from under `project_search` would leave a row pointing at
 * nothing, which is exactly the inconsistency the integrity suite checks for.
 */
export async function cleanupProjects(publicIds) {
  for (const publicId of publicIds) {
    const project = await queryOne("SELECT id FROM projects WHERE public_id = ?", [publicId]);
    if (!project) continue;
    await execute("DELETE FROM project_search WHERE project_id = ?", [project.id]);
    await execute("DELETE FROM analytics_events WHERE subject_type = 'project' AND subject_id = ?", [project.id]);
    await execute(
      `DELETE FROM document_access_grants
        WHERE document_id IN (SELECT id FROM documents WHERE owner_type = 'project' AND owner_id = ?)`,
      [project.id]
    );
    await execute("DELETE FROM documents WHERE owner_type = 'project' AND owner_id = ?", [project.id]);
    await execute("DELETE FROM floor_plans WHERE project_id = ?", [project.id]);
    await execute("DELETE FROM media_attachments WHERE attachable_type = 'project' AND attachable_id = ?", [project.id]);
    await execute("DELETE FROM project_unit_types WHERE project_id = ?", [project.id]);
    await execute("DELETE FROM project_amenities WHERE project_id = ?", [project.id]);
    await execute("DELETE FROM project_payment_plans WHERE project_id = ?", [project.id]);
    // Development enquiries now create admin leads; `leads.project_id` is ON DELETE SET NULL,
    // so the leads go first or they are orphaned (and crash the admin Leads page).
    await execute("DELETE FROM leads WHERE project_id = ?", [project.id]);
    await execute("DELETE FROM inquiries WHERE project_id = ?", [project.id]);
    await execute("DELETE FROM projects WHERE id = ?", [project.id]);
  }
}

/**
 * Throwaway accounts for tests that sign a user out, suspend them, rewrite their password or
 * enrol MFA. Those tests used to act on real seeded accounts (the lowest-id portal owner, the
 * super admin), and because the suite shares the dev database, every run signed the real people
 * using those accounts out of their browsers (session-epoch bumps, suspensions) and stripped the
 * real admin's MFA. Remove what these create with `cleanupUsers([email])`.
 */
const disposableEmail = (prefix) => `${prefix}-${Date.now()}-${Math.floor(Math.random() * 1e6)}@example.test`;

/** A real portal owner — user, personal account and owner membership — through the signup endpoint. */
export async function createDisposablePortalOwner({ prefix = "disposable-owner", password = "LivFinder!2026" } = {}) {
  const email = disposableEmail(prefix);
  const response = await client().send("post", "/v1/accounts/personal/signup", {
    firstName: "Disposable", lastName: "Owner", email, password, confirmPassword: password,
    agreements: true, country: "United Arab Emirates", city: "Dubai", displayName: "Disposable Owner",
    categoryId: "realEstate",
  });
  if (response.status !== 201) throw new Error(`disposable signup failed: ${response.status} ${JSON.stringify(response.body)}`);
  await execute("UPDATE users SET status = 'active', email_verified_at = NOW(3) WHERE email_normalized = ?", [email]);
  const user = await queryOne("SELECT id, public_id, email FROM users WHERE email_normalized = ?", [email]);
  return { id: user.id, publicId: user.public_id, email: user.email };
}

/** A staff user holding `roleCode` (e.g. "moderator") and nothing else. */
export async function createDisposableStaffUser({ prefix = "disposable-staff", password = "LivFinder!2026", roleCode } = {}) {
  const email = disposableEmail(prefix);
  const { hashPassword } = await import("../../src/modules/auth/passwords.js");
  const { ulid } = await import("../../src/utils/ids.js");
  const insert = await execute(
    `INSERT INTO users (public_id, email, email_normalized, password_hash, password_updated_at,
                        status, first_name, last_name, display_name, email_verified_at, created_at)
     VALUES (?, ?, ?, ?, NOW(3), 'active', 'Disposable', 'Staff', 'Disposable Staff', NOW(3), NOW(3))`,
    [ulid(), email, email, await hashPassword(password)]
  );
  if (roleCode) {
    await execute(
      "INSERT INTO user_roles (user_id, role_id, granted_at) SELECT ?, id, NOW(3) FROM roles WHERE code = ?",
      [insert.insertId, roleCode]
    );
  }
  return { id: insert.insertId, email };
}

export { query, queryOne, execute };
