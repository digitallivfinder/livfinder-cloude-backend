import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, ensureTestPassword, createDisposableStaffUser, cleanupUsers, queryOne, execute } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { totpCode, verifyTotp, base32Encode, base32Decode } from "../../src/modules/auth/mfa.service.js";

/**
 * Multi-factor authentication and step-up.
 *
 * SEC-IAM-002 and SEC-IAM-011 were both listed as unmet go-live gates: `user_mfa_factors` was an
 * empty table and `users.mfa_enabled` could be displayed but never become true.
 *
 * The TOTP arithmetic is checked against the RFC 6238 vectors rather than against itself — a
 * self-consistent implementation that disagrees with every authenticator app would pass any
 * round-trip test and fail every real user.
 */
const PASSWORD = "LivFinder!2026";
const admin = client();
let userId = null;
let staffEmail = null;
let secret = null;
let recoveryCodes = [];

const currentCode = () => totpCode(secret, Math.floor(Date.now() / 1000 / 30));

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  // A throwaway super admin, never the real one. This suite deletes the account's MFA factors,
  // enrols and disables MFA and clears step-up on every one of its sessions; run against
  // admin@livfinder.com it silently stripped the real administrator's MFA on every run.
  // Super admin because the step-up cases create roles.
  const staff = await createDisposableStaffUser({ prefix: "mfa-admin", password: PASSWORD, roleCode: "super_admin" });
  staffEmail = staff.email;
  userId = staff.id;
  await admin.login(staff.email, PASSWORD);
});

afterAll(async () => {
  // Removes the user with its sessions, role and MFA factors. Audit rows may pin it; a leftover
  // example.test account is harmless.
  if (staffEmail) await cleanupUsers([staffEmail]).catch(() => {});
  await closePool();
});

describe("TOTP arithmetic", () => {
  it("matches the RFC 6238 test vectors", () => {
    // Appendix B, SHA-1, 8-digit vectors truncated to the 6 digits this implementation emits.
    const rfcSecret = base32Encode(Buffer.from("12345678901234567890"));
    const at = (unixSeconds) => totpCode(rfcSecret, Math.floor(unixSeconds / 30));
    expect(at(59)).toBe("287082");
    expect(at(1111111109)).toBe("081804");
    expect(at(1234567890)).toBe("005924");
    expect(at(2000000000)).toBe("279037");
  });

  it("round-trips base32 and rejects anything that is not six digits", () => {
    const value = base32Encode(Buffer.from("livfinder-secret-abc"));
    expect(base32Decode(value).toString()).toBe("livfinder-secret-abc");
    for (const bad of ["", "12345", "1234567", "abcdef", null, undefined]) {
      expect(verifyTotp(value, bad)).toBe(false);
    }
  });

  it("accepts one step of clock drift either way and nothing beyond it", () => {
    const value = base32Encode(Buffer.from("12345678901234567890"));
    const now = 1_700_000_000_000;
    const counter = Math.floor(now / 1000 / 30);
    expect(verifyTotp(value, totpCode(value, counter), now)).toBe(true);
    expect(verifyTotp(value, totpCode(value, counter - 1), now)).toBe(true);
    expect(verifyTotp(value, totpCode(value, counter + 1), now)).toBe(true);
    // Two steps is a minute old; a code that lives that long is a code worth stealing.
    expect(verifyTotp(value, totpCode(value, counter - 2), now)).toBe(false);
    expect(verifyTotp(value, totpCode(value, counter + 2), now)).toBe(false);
  });
});

describe("enrolment", () => {
  it("hands back a provisioning URI and does not enable MFA until a code proves it", async () => {
    expect((await admin.get("/v1/auth/mfa")).body.data.enabled).toBe(false);

    const started = await admin.send("post", "/v1/auth/mfa/totp", { label: "Integration suite" });
    expect(started.status).toBe(201);
    secret = started.body.data.secret;
    expect(started.body.data.otpauthUrl).toContain("otpauth://totp/");
    expect(started.body.data.otpauthUrl).toContain(secret);

    // Still off: scanning a QR code is not proof that the user can produce a code from it.
    expect((await admin.get("/v1/auth/mfa")).body.data.enabled).toBe(false);
    const stored = await queryOne(
      "SELECT confirmed_at FROM user_mfa_factors WHERE user_id = ? AND factor_type = 'totp'",
      [userId]
    );
    expect(stored.confirmed_at).toBeNull();
  });

  it("refuses a wrong code and accepts the right one", async () => {
    expect((await admin.send("post", "/v1/auth/mfa/totp/confirm", { code: "000000" })).status).toBe(400);
    expect((await admin.get("/v1/auth/mfa")).body.data.enabled).toBe(false);

    const confirmed = await admin.send("post", "/v1/auth/mfa/totp/confirm", { code: currentCode() });
    expect(confirmed.status).toBe(200);
    recoveryCodes = confirmed.body.data.recoveryCodes;
    expect(recoveryCodes).toHaveLength(10);

    const status = await admin.get("/v1/auth/mfa");
    expect(status.body.data.enabled).toBe(true);
    expect(status.body.data.recoveryCodesRemaining).toBe(10);
  });

  it("stores the secret encrypted and never returns it again", async () => {
    const row = await queryOne(
      "SELECT secret_encrypted FROM user_mfa_factors WHERE user_id = ? AND factor_type = 'totp'",
      [userId]
    );
    const stored = row.secret_encrypted.toString("utf8");
    expect(stored).not.toContain(secret);
    expect(stored.startsWith("enc:")).toBe(true);
    // The status endpoint reports whether it is on, never what it is.
    expect(JSON.stringify((await admin.get("/v1/auth/mfa")).body)).not.toContain(secret);
  });
});

describe("step-up", () => {
  it("refuses a high-risk action until the session re-proves itself", async () => {
    await execute("UPDATE user_sessions SET stepped_up_at = NULL WHERE user_id = ?", [userId]);
    const blocked = await admin.send("post", "/v1/admin/roles", {
      name: `Step-up suite ${Date.now()}`,
      databasePermissions: ["dashboard.view"],
    });
    expect(blocked.status).toBe(403);
    // Distinguishable from a plain permission failure, so the client can prompt and retry.
    expect(blocked.body.error.code === "STEP_UP_REQUIRED" || /Confirm it is you/.test(blocked.body.error.message)).toBe(true);
  });

  it("refuses a wrong code", async () => {
    // `verifyPassword` returns `{ valid }`, and treating the object as truthy once made every
    // code succeed. This is the case that caught it.
    expect((await admin.send("post", "/v1/auth/step-up", { code: "000000" })).status).toBe(403);
  });

  it("accepts a valid code, and the action then goes through", async () => {
    expect((await admin.send("post", "/v1/auth/step-up", { code: currentCode() })).status).toBe(200);

    const created = await admin.send("post", "/v1/admin/roles", {
      name: `Step-up suite ${Date.now()}`,
      databasePermissions: ["dashboard.view"],
    });
    expect(created.status).toBe(201);
    await admin.send("delete", `/v1/admin/roles/${created.body.data.id}`);
  });

  it("burns a recovery code on use", async () => {
    expect((await admin.send("post", "/v1/auth/step-up", { code: recoveryCodes[0] })).status).toBe(200);
    expect((await admin.send("post", "/v1/auth/step-up", { code: recoveryCodes[0] })).status).toBe(403);
    expect((await admin.get("/v1/auth/mfa")).body.data.recoveryCodesRemaining).toBe(9);
  });
});

describe("disabling", () => {
  it("needs a current code, so a hijacked session cannot quietly turn it off", async () => {
    expect((await admin.send("delete", "/v1/auth/mfa", { code: "000000" })).status).toBe(400);
    expect((await admin.get("/v1/auth/mfa")).body.data.enabled).toBe(true);

    expect((await admin.send("delete", "/v1/auth/mfa", { code: currentCode() })).status).toBe(200);
    const status = await admin.get("/v1/auth/mfa");
    expect(status.body.data.enabled).toBe(false);
    expect(status.body.data.recoveryCodesRemaining).toBe(0);
  });
});
