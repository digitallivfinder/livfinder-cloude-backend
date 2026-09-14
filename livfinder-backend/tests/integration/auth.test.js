import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, ensureTestPassword, createDisposablePortalOwner, adminEmail, cleanupUsers, queryOne, query, execute } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { sentMessages, clearSentMessages } from "../../src/modules/system/mail.service.js";

/**
 * Authentication and account creation, against the real database.
 *
 * Sessions are rows in `user_sessions` holding only a hash of the cookie token;
 * signup is a multi-table transaction. Both are asserted against the database,
 * not just the response.
 */
const PASSWORD = "LivFinder!2026";
const suffix = Date.now();
const createdEmails = [];
let owner = null;

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  // A throwaway owner. These tests sign out, bump the session epoch and rewrite the password
  // hash; run against the real lowest-id seeded owner, that signed the person using that account
  // out of their own browser on every run.
  owner = await createDisposablePortalOwner({ prefix: "auth-owner", password: PASSWORD });
  createdEmails.push(owner.email);
});

afterAll(async () => {
  await cleanupUsers(createdEmails);
  await closePool();
});

describe("sign in", () => {
  it("rejects a wrong password without revealing whether the account exists", async () => {
    const api = client();
    const known = await api.send("post", "/v1/auth/login", { email: owner.email, password: "definitely-wrong" });
    const unknown = await api.send("post", "/v1/auth/login", { email: `nobody-${suffix}@example.test`, password: "definitely-wrong" });
    expect(known.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(known.body.error.message).toBe(unknown.body.error.message);
  });

  it("signs in and stores only a hash of the session token", async () => {
    const api = client();
    const response = await api.login(owner.email, PASSWORD);
    expect(response.status).toBe(200);
    expect(response.body.data.authenticated).toBe(true);

    const cookie = response.headers["set-cookie"].find((entry) => entry.startsWith("livfinder_session="));
    expect(cookie).toContain("HttpOnly");
    const token = cookie.split(";")[0].split("=")[1];

    const stored = await queryOne(
      "SELECT token_hash FROM user_sessions WHERE user_id = ? ORDER BY id DESC LIMIT 1",
      [owner.id]
    );
    expect(stored.token_hash.toString("hex")).not.toContain(token);
    const { createHash } = await import("node:crypto");
    expect(stored.token_hash.toString("hex")).toBe(createHash("sha256").update(token).digest("hex"));
  });

  it("restores the session on a later request", async () => {
    const api = client();
    await api.login(owner.email, PASSWORD);
    const session = await api.get("/v1/auth/session");
    expect(session.body.data.authenticated).toBe(true);
    expect(session.body.data.user.email).toBe(owner.email);
  });

  it("returns a null session for an anonymous caller", async () => {
    const response = await client().get("/v1/auth/session");
    expect(response.status).toBe(200);
    expect(response.body.data).toBeNull();
  });

  it("upgrades a legacy bcrypt hash to Argon2id on a successful sign-in", async () => {
    const bcrypt = await import("bcryptjs");
    const legacy = await bcrypt.default.hash(PASSWORD, 4);
    await execute("UPDATE users SET password_hash = ? WHERE id = ?", [legacy.replace("$2b$", "$2y$"), owner.id]);

    const api = client();
    expect((await api.login(owner.email, PASSWORD)).status).toBe(200);

    const after = await queryOne("SELECT password_hash FROM users WHERE id = ?", [owner.id]);
    expect(after.password_hash.startsWith("$argon2id$")).toBe(true);
  });

  it("ends the session on sign-out and revokes the row", async () => {
    const api = client();
    await api.login(owner.email, PASSWORD);
    const before = await queryOne("SELECT id FROM user_sessions WHERE user_id = ? ORDER BY id DESC LIMIT 1", [owner.id]);

    const response = await api.send("post", "/v1/auth/logout", {});
    expect(response.status).toBe(200);

    const after = await queryOne("SELECT revoked_at FROM user_sessions WHERE id = ?", [before.id]);
    expect(after.revoked_at).not.toBeNull();
    expect((await api.get("/v1/auth/session")).body.data).toBeNull();
  });

  it("kills every session when the epoch is bumped", async () => {
    const api = client();
    await api.login(owner.email, PASSWORD);
    expect((await api.get("/v1/auth/session")).body.data.authenticated).toBe(true);

    await execute("UPDATE users SET session_epoch = session_epoch + 1 WHERE id = ?", [owner.id]);
    expect((await api.get("/v1/auth/session")).body.data).toBeNull();
  });
});

describe("CSRF", () => {
  it("refuses a cookie-authenticated mutation with no token", async () => {
    const api = client();
    await api.login(owner.email, PASSWORD);
    const token = api.csrfToken;
    api.csrfToken = null;
    const response = await api.send("post", "/v1/favourites", { listingId: "anything" });
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe("CSRF_TOKEN_INVALID");
    api.csrfToken = token;
  });

  it("accepts the same mutation with a valid token", async () => {
    const api = client();
    await api.login(owner.email, PASSWORD);
    const listing = await queryOne("SELECT public_id FROM v_public_listings LIMIT 1");
    const response = await api.send("post", "/v1/favourites", { listingId: listing.public_id });
    expect(response.status).toBe(201);
    await api.send("delete", `/v1/favourites/${listing.public_id}`);
  });

  it("refuses a token that was issued for a different session", async () => {
    const first = client();
    await first.login(owner.email, PASSWORD);
    const second = client();
    await second.login(owner.email, PASSWORD);
    second.csrfToken = first.csrfToken;
    const response = await second.send("post", "/v1/favourites", { listingId: "anything" });
    expect(response.status).toBe(403);
  });
});

describe("password recovery", () => {
  it("answers identically for a known and an unknown address", async () => {
    const api = client();
    const known = await api.send("post", "/v1/auth/forgot-password", { email: owner.email });
    const unknown = await api.send("post", "/v1/auth/forgot-password", { email: `nobody-${suffix}@example.test` });
    expect(known.status).toBe(200);
    expect(unknown.status).toBe(200);
    expect(known.body).toEqual(unknown.body);
  });

  it("stores only a hash of the reset token", async () => {
    await execute("UPDATE user_tokens SET consumed_at = NOW(3) WHERE user_id = ? AND purpose = 'password_reset'", [owner.id]);
    await client().send("post", "/v1/auth/forgot-password", { email: owner.email });
    const token = await queryOne(
      "SELECT token_hash FROM user_tokens WHERE user_id = ? AND purpose = 'password_reset' AND consumed_at IS NULL ORDER BY id DESC LIMIT 1",
      [owner.id]
    );
    expect(token).toBeTruthy();
    expect(token.token_hash).toHaveLength(32);
  });

  it("rejects an invalid reset token", async () => {
    const response = await client().send("post", "/v1/auth/reset-password", {
      token: "not-a-real-token-value",
      password: "Replacement42",
    });
    expect(response.status).toBe(400);
  });

  it("enforces the password policy on reset", async () => {
    const response = await client().send("post", "/v1/auth/reset-password", { token: "x".repeat(20), password: "short" });
    expect(response.status).toBe(422);
    expect(response.body.error.fields.password).toBeTruthy();
  });
});

describe("signup", () => {
  it("creates a user, an account and an owner membership in one transaction", async () => {
    const email = `personal-${suffix}@example.test`;
    createdEmails.push(email);
    clearSentMessages();

    const response = await client().send("post", "/v1/accounts/personal/signup", {
      firstName: "Test",
      lastName: "Person",
      email,
      password: "Reasonable42",
      confirmPassword: "Reasonable42",
      agreements: true,
      country: "United Arab Emirates",
      city: "Dubai",
      displayName: "Test Person",
      categoryId: "realEstate",
    });
    expect(response.status).toBe(201);

    const user = await queryOne("SELECT id, status, default_account_id FROM users WHERE email_normalized = ?", [email]);
    expect(user).toBeTruthy();
    expect(user.status).toBe("pending_verification");
    expect(user.default_account_id).toBeTruthy();

    const membership = await queryOne(
      "SELECT role, status FROM account_members WHERE user_id = ? AND account_id = ?",
      [user.id, user.default_account_id]
    );
    expect(membership).toMatchObject({ role: "owner", status: "active" });

    const verification = await queryOne(
      "SELECT status FROM verification_requests WHERE requested_by_user_id = ? ORDER BY id DESC LIMIT 1",
      [user.id]
    );
    expect(verification.status).toBe("pending");
    expect(sentMessages().some((message) => message.to === email)).toBe(true);
  });

  it("creates the organization, licence and category request together", async () => {
    const email = `org-${suffix}@example.test`;
    createdEmails.push(email);

    const response = await client().send("post", "/v1/accounts/organization/signup", {
      firstName: "Owner",
      lastName: "Person",
      email,
      password: "Reasonable42",
      confirmPassword: "Reasonable42",
      agreements: true,
      legalName: `Test Agency ${suffix} LLC`,
      publicName: `Test Agency ${suffix}`,
      organizationType: "agency",
      registrationNumber: `REG-${suffix}`,
      organizationEmail: email,
      categoryId: "realEstate",
      country: "United Arab Emirates",
    });
    expect(response.status).toBe(201);

    const user = await queryOne("SELECT id, default_account_id FROM users WHERE email_normalized = ?", [email]);
    const organization = await queryOne("SELECT id, status, is_publicly_visible FROM organizations WHERE account_id = ?", [
      user.default_account_id,
    ]);
    expect(organization.status).toBe("pending");
    // A new organization is not on the marketplace until it is verified.
    expect(organization.is_publicly_visible).toBe(0);

    const licence = await queryOne("SELECT license_number FROM organization_licenses WHERE organization_id = ?", [organization.id]);
    expect(licence.license_number).toBe(`REG-${suffix}`);

    const access = await queryOne(
      "SELECT status FROM account_category_access WHERE account_id = ? LIMIT 1",
      [user.default_account_id]
    );
    expect(access.status).toBe("requested");
  });

  it("refuses a duplicate email and creates nothing", async () => {
    const email = `personal-${suffix}@example.test`;
    const before = await queryOne("SELECT COUNT(*) AS total FROM users");
    const response = await client().send("post", "/v1/accounts/personal/signup", {
      firstName: "Another",
      lastName: "Person",
      email,
      password: "Reasonable42",
      confirmPassword: "Reasonable42",
      agreements: true,
    });
    expect(response.status).toBe(409);
    const after = await queryOne("SELECT COUNT(*) AS total FROM users");
    expect(Number(after.total)).toBe(Number(before.total));
  });

  it("rejects a weak password and a missing agreement", async () => {
    const weak = await client().send("post", "/v1/accounts/personal/signup", {
      firstName: "A", lastName: "B", email: `weak-${suffix}@example.test`,
      password: "short", confirmPassword: "short", agreements: true,
    });
    expect(weak.status).toBe(422);

    const noAgreement = await client().send("post", "/v1/accounts/personal/signup", {
      firstName: "A", lastName: "B", email: `noagree-${suffix}@example.test`,
      password: "Reasonable42", confirmPassword: "Reasonable42", agreements: false,
    });
    expect(noAgreement.status).toBe(422);
    expect(noAgreement.body.error.fields.agreements).toBeTruthy();
  });
});

describe("session payload", () => {
  it("gives a platform user their resolved admin permissions", async () => {
    const email = await adminEmail("moderator");
    const api = client();
    await api.login(email, PASSWORD);
    const session = await api.get("/v1/auth/session");
    expect(session.body.data.user.platformRole).toBe("admin");
    expect(session.body.data.admin.permissions).toContain("listings.moderate");
    expect(session.body.data.admin.permissions).not.toContain("billing.manage");
  });

  it("gives an account owner their category access, not the admin block", async () => {
    const api = client();
    await api.login(owner.email, PASSWORD);
    const session = await api.get("/v1/auth/session");
    expect(session.body.data.user.platformRole).toBe("client");
    expect(session.body.data.admin).toBeNull();
    expect(Array.isArray(session.body.data.accountCategories)).toBe(true);
  });
});
