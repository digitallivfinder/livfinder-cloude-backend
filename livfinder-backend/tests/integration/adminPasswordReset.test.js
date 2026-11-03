import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { adminEmail, cleanupUsers, client, createDisposablePortalOwner, ensureTestPassword, execute, query, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { clearSentMessages, sentMessages } from "../../src/modules/system/mail.service.js";

/** An admin helping a company owner back in, on a company created here. */
const ORIGINAL = "LivFinder!2026";
const suffix = Date.now();
const companyEmail = `company-${suffix}@example.test`;
const admin = client();
let owner;
let publicId;

const reset = (person, body) => person.send("post", `/v1/admin/companies/${publicId}/password-reset`, body);
const linkToken = () => decodeURIComponent(sentMessages().at(-1).text.match(/token=([^\s]+)/)[1]);

beforeAll(async () => {
  await ensureTestPassword();
  await admin.login(await adminEmail("super_admin"));
  owner = await createDisposablePortalOwner({ prefix: "password-reset" });
  const account = await queryOne("SELECT id FROM accounts WHERE owner_user_id = ?", [owner.id]);
  publicId = `pwd${suffix}`;
  await execute(
    `INSERT INTO organizations (public_id, account_id, kind, name, legal_name, slug, email, status, verification_status, is_publicly_visible, created_at)
     VALUES (?, ?, 'agency', 'Reset Co', 'Reset Co LLC', ?, ?, 'active', 'verified', 1, NOW(3))`,
    [publicId, account.id, publicId, companyEmail]
  );
});

afterAll(async () => {
  await execute("DELETE FROM organizations WHERE public_id = ?", [publicId]);
  await cleanupUsers([owner.email]);
  await closePool();
});

describe("Resetting a company owner's password", () => {
  it("asks the admin to confirm first, and refuses anyone without the permission", async () => {
    const refused = await reset(admin, { method: "temporary" });
    expect(refused.status).toBe(403);
    expect(refused.body.error.code).toBe("STEP_UP_REQUIRED");
    const seller = await createDisposablePortalOwner({ prefix: "password-reset-other" });
    const other = client();
    await other.login(seller.email, ORIGINAL);
    expect((await reset(other, { method: "temporary" })).status).toBe(403);
    await cleanupUsers([seller.email]);
    expect((await client().login(owner.email, ORIGINAL)).status).toBe(200);
  });

  it("emails a link to the owner, and the old password works until it is used", async () => {
    await admin.stepUp();
    clearSentMessages();
    const sent = await reset(admin, { method: "link" });
    expect(sent.status, JSON.stringify(sent.body)).toBe(200);
    expect(sent.body.data).toMatchObject({ method: "link", sentTo: owner.email });
    expect(sentMessages().at(-1).to).toBe(owner.email);
    expect((await client().login(owner.email, ORIGINAL)).status).toBe(200);
    const used = await client().send("post", "/v1/auth/reset-password", { token: linkToken(), password: "Harbour-view-2049" });
    expect(used.status, JSON.stringify(used.body)).toBe(200);
    expect((await client().login(owner.email, "Harbour-view-2049")).status).toBe(200);
  });

  it("can send the link to the company email instead", async () => {
    clearSentMessages();
    const sent = await reset(admin, { method: "link", recipient: "company" });
    expect(sent.body.data.sentTo).toBe(companyEmail);
    expect(sentMessages().at(-1).to).toBe(companyEmail);
  });

  it("creates a temporary password that is shown once, never stored, and tells the owner", async () => {
    const person = client();
    await person.login(owner.email, "Harbour-view-2049");
    clearSentMessages();
    const created = await reset(admin, { method: "temporary" });
    expect(created.status).toBe(200);
    expect(created.headers["cache-control"]).toContain("no-store");
    const { temporaryPassword } = created.body.data;
    expect(temporaryPassword.length).toBeGreaterThanOrEqual(10);
    expect(sentMessages().at(-1).to).toBe(owner.email);
    expect(sentMessages().at(-1).text).not.toContain(temporaryPassword);
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(401);
    expect((await client().login(owner.email, "Harbour-view-2049")).status).toBe(401);
    expect((await client().login(owner.email, temporaryPassword)).status).toBe(200);
    const audit = await query("SELECT changes FROM audit_logs WHERE action = 'company.password_reset' AND subject_label = ? ORDER BY id DESC", [publicId]);
    expect(audit.length).toBeGreaterThan(1);
    expect(JSON.stringify(audit)).not.toContain(temporaryPassword);
  });

  it("will not touch a staff login, or a company that does not exist", async () => {
    expect((await admin.send("post", "/v1/admin/companies/nothing-here/password-reset", { method: "link" })).status).toBe(404);
    const staff = await queryOne("SELECT user_id FROM user_roles LIMIT 1");
    await execute("UPDATE accounts SET owner_user_id = ? WHERE id = (SELECT account_id FROM organizations WHERE public_id = ?)", [staff.user_id, publicId]);
    const refused = await reset(admin, { method: "temporary" });
    await execute("UPDATE accounts SET owner_user_id = ? WHERE id = (SELECT account_id FROM organizations WHERE public_id = ?)", [owner.id, publicId]);
    expect(refused.status).toBe(403);
  });
});
