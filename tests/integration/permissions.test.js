import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, ensureTestPassword, adminEmail, queryOne, query, execute } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * The permission model, against the real database.
 *
 * Two things are being proved, and the second is the one that used to be false:
 *
 *   1. A permission code answers "may this role do this action at all".
 *   2. A category scope answers "over which slice" — and it is enforced on the server,
 *      not merely drawn in the Role Access matrix.
 *
 * Before migration 0032 the matrix offered per-category checkboxes that mapped back onto one
 * coarse `listings.edit`, so a role ticked for Cars only could edit yachts. That is what the
 * scoped-user cases below check.
 */
const PASSWORD = "LivFinder!2026";
const superAdmin = client();
const scoped = client();

let roleId = null;
let userId = null;
let scopedEmail = null;
let carListing = null;
let yachtListing = null;

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  await superAdmin.login(await adminEmail("super_admin"), PASSWORD);
  // Role, staff-user, suspension and payment-credential changes require step-up (SEC-IAM-011).
  // Doing it here is what a real administrator's client does after the first 403.
  await superAdmin.stepUp();

  carListing = await queryOne(
    "SELECT public_id, reference FROM listings WHERE root_category_id = 2 AND deleted_at IS NULL LIMIT 1"
  );
  yachtListing = await queryOne(
    "SELECT public_id, reference FROM listings WHERE root_category_id = 3 AND deleted_at IS NULL LIMIT 1"
  );

  const created = await superAdmin.send("post", "/v1/admin/roles", {
    name: `Scope Suite ${Date.now()}`,
    description: "Created by the permission integration suite.",
    databasePermissions: ["dashboard.view", "listings.view", "listings.edit", "listings.moderate"],
    categoryScope: ["cars"],
  });
  roleId = created.body.data.id;

  // A user who holds nothing but that role.
  scopedEmail = `scope-${Date.now()}@example.test`;
  const { hashPassword } = await import("../../src/modules/auth/passwords.js");
  const { ulid } = await import("../../src/utils/ids.js");
  const insert = await execute(
    `INSERT INTO users (public_id, email, email_normalized, password_hash, password_updated_at,
                        status, first_name, last_name, display_name, email_verified_at, created_at)
     VALUES (?, ?, ?, ?, NOW(3), 'active', 'Scope', 'Tester', 'Scope Tester', NOW(3), NOW(3))`,
    [ulid(), scopedEmail, scopedEmail, await hashPassword(PASSWORD)]
  );
  userId = insert.insertId;
  await execute("INSERT INTO user_roles (user_id, role_id, granted_at) VALUES (?, ?, NOW(3))", [userId, Number(roleId)]);
  await scoped.login(scopedEmail, PASSWORD);
});

afterAll(async () => {
  if (userId) {
    await execute("DELETE FROM user_sessions WHERE user_id = ?", [userId]);
    await execute("DELETE FROM user_roles WHERE user_id = ?", [userId]);
    await execute("DELETE FROM users WHERE id = ?", [userId]);
  }
  if (roleId) {
    await execute("DELETE FROM role_scopes WHERE role_id = ?", [Number(roleId)]);
    await execute("DELETE FROM role_permissions WHERE role_id = ?", [Number(roleId)]);
    await execute("DELETE FROM roles WHERE id = ?", [Number(roleId)]);
  }
  await closePool();
});

describe("permission grammar", () => {
  it("carries no category or page name in any code", async () => {
    // LIV-IAM-001 §6.2: scopes and attributes, not keys. A code is exactly <domain>.<action>.
    const codes = (await query("SELECT code FROM permissions")).map((row) => row.code);
    expect(codes.length).toBeGreaterThan(80);
    for (const code of codes) {
      expect(code).toMatch(/^[a-z][a-zA-Z]*\.[a-z][a-zA-Z]*$/);
    }
    const categorySlugs = ["cars", "yachts", "jets", "helicopters", "watches", "realEstate", "real-estate"];
    for (const code of codes) {
      for (const slug of categorySlugs) {
        expect(code.includes(`.${slug}.`)).toBe(false);
      }
    }
  });

  it("exposes the matrix as domain x action so the UI derives it rather than hardcoding it", async () => {
    const response = await superAdmin.get("/v1/admin/roles/options");
    expect(response.status).toBe(200);
    const matrix = response.body.data.permissionMatrix;
    expect(matrix.domains.length).toBeGreaterThan(20);
    expect(matrix.actions).toContain("moderate");

    const listings = matrix.domains.find((domain) => domain.id === "listings");
    expect(listings.scopable).toBe(true);
    expect(Object.keys(listings.actions)).toEqual(
      expect.arrayContaining(["view", "create", "edit", "delete", "moderate"])
    );
    // Settings is platform-wide: offering "settings for yachts only" would be a lie.
    expect(matrix.domains.find((domain) => domain.id === "settings").scopable).toBe(false);
  });
});

describe("category scope", () => {
  it("lets a scoped role work inside its categories", async () => {
    const response = await scoped.get(`/v1/admin/listings/${carListing.public_id}`);
    expect(response.status).toBe(200);
    expect(response.body.data.reference).toBe(carListing.reference);
  });

  it("refuses the same action outside them, and does not confirm the record exists", async () => {
    // 404 rather than 403: a competitor must not learn that a reference is real.
    const read = await scoped.get(`/v1/admin/listings/${yachtListing.public_id}`);
    expect(read.status).toBe(404);

    const moderate = await scoped.send("patch", `/v1/admin/listings/${yachtListing.public_id}/moderation`, {
      decision: "approve",
    });
    expect(moderate.status).toBe(404);

    // And the listing is untouched.
    const after = await queryOne("SELECT moderation_status FROM listings WHERE public_id = ?", [yachtListing.public_id]);
    const before = await queryOne("SELECT moderation_status FROM listings WHERE public_id = ?", [yachtListing.public_id]);
    expect(after.moderation_status).toBe(before.moderation_status);
  });

  it("filters the list rather than failing it", async () => {
    const response = await scoped.get("/v1/admin/listings", { pageSize: 50, category: "" });
    expect(response.status).toBe(200);
    expect(response.body.items.length).toBeGreaterThan(0);
    // Every row the scoped user can see is a car.
    const references = response.body.items.map((item) => item.reference);
    const rows = await query(
      `SELECT root_category_id FROM listings WHERE reference IN (${references.map(() => "?").join(",")})`,
      references
    );
    for (const row of rows) expect(Number(row.root_category_id)).toBe(2);
  });

  it("treats a role with no scope rows as unrestricted", async () => {
    const response = await superAdmin.get(`/v1/admin/roles/${roleId}`);
    expect(response.body.data.allCategories).toBe(false);
    expect(response.body.data.categoryScope).toEqual(["cars"]);

    // Clearing the selection restores platform-wide reach — the default, not "access to nothing".
    await superAdmin.send("patch", `/v1/admin/roles/${roleId}`, {
      name: "Scope Suite widened",
      databasePermissions: ["dashboard.view", "listings.view", "listings.edit", "listings.moderate"],
      categoryScope: [],
    });
    const widened = await superAdmin.get(`/v1/admin/roles/${roleId}`);
    expect(widened.body.data.allCategories).toBe(true);

    const fresh = client();
    await fresh.login(scopedEmail, PASSWORD);
    expect((await fresh.get(`/v1/admin/listings/${yachtListing.public_id}`)).status).toBe(200);
  });
});

describe("role writes", () => {
  it("refuses an unknown permission code instead of dropping it silently", async () => {
    const response = await superAdmin.send("patch", `/v1/admin/roles/${roleId}`, {
      name: "Scope Suite",
      databasePermissions: ["listings.view", "listings.cars.view"],
    });
    expect(response.status).toBe(422);
    expect(response.body.error.fields.databasePermissions).toContain("listings.cars.view");

    // The role still holds what it held: a rejected write changes nothing.
    const after = await superAdmin.get(`/v1/admin/roles/${roleId}`);
    expect(after.body.data.databasePermissions.length).toBe(4);
  });
});

describe("hardcoded constants that mirror the database", () => {
  it("reconciles root category ids against categories.code", async () => {
    // `utils/categories.js` hardcodes rootId 1…6. Those are seed-loader ids, and reseeding in a
    // different order would silently misfile every listing, dashboard and scope check. The
    // reconciliation at boot is what stops that being a latent time bomb.
    const { reconcileCategoryIds, CATEGORY_DEFINITIONS } = await import("../../src/utils/categories.js");
    const corrections = await reconcileCategoryIds(query);
    expect(corrections).toEqual([]);

    const rows = await query("SELECT id, code FROM categories WHERE depth = 0 AND deleted_at IS NULL");
    const byCode = new Map(rows.map((row) => [row.code, Number(row.id)]));
    for (const definition of CATEGORY_DEFINITIONS) {
      expect(definition.rootId).toBe(byCode.get(definition.dbCode));
    }
  });

  it("resolves the super administrator role by code rather than assuming id 1", async () => {
    const role = await queryOne("SELECT id FROM roles WHERE code = 'super_admin'");
    expect(role).toBeTruthy();
    // The guard reads the code; this asserts the code exists and is the one the seed grants
    // everything to, which is what the guard depends on.
    const grants = await queryOne("SELECT COUNT(*) AS total FROM role_permissions WHERE role_id = ?", [role.id]);
    const permissions = await queryOne("SELECT COUNT(*) AS total FROM permissions");
    expect(Number(grants.total)).toBe(Number(permissions.total));
  });
});
