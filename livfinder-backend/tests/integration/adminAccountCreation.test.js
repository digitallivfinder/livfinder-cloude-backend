import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { adminEmail, cleanupUsers, client, ensureTestPassword, execute, query, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Admin Add Company / Add Individual / Add Admin User / Add Contact, through the real routes.
 *
 * Each of these used to change only the table in the browser. Now: the account is created and
 * approved, the owner is emailed a set-up link (and nothing else), the link sets a password,
 * confirms the address and lets them sign in; contacts are stored in the chosen company's CRM.
 * Everything created here is removed afterwards.
 */
const suffix = Date.now();
const companyEmail = `admin-made-company-${suffix}@example.test`;
const individualEmail = `admin-made-person-${suffix}@example.test`;
const staffEmail = `admin-made-staff-${suffix}@example.test`;
const contactEmail = `admin-made-contact-${suffix}@example.test`;
const phone = (n) => `+9715${String(suffix).slice(-7)}${n}`;
const admin = client();
const created = { contacts: [] };

const emailsTo = (to) =>
  query("SELECT template_key, data FROM email_messages WHERE to_email = ? ORDER BY id ASC", [to]);
const setupToken = async (to) => {
  const rows = await emailsTo(to);
  const setup = rows.filter((row) => row.template_key === "auth.account_setup").at(-1);
  const data = typeof setup.data === "string" ? JSON.parse(setup.data) : setup.data;
  return decodeURIComponent(new URL(data.url).searchParams.get("token"));
};
const firstCountry = () => queryOne("SELECT id FROM locations WHERE level = 'country' AND deleted_at IS NULL AND status = 'active' ORDER BY id LIMIT 1");

beforeAll(async () => {
  await ensureTestPassword();
  await admin.login(await adminEmail("super_admin"));
});

afterAll(async () => {
  if (created.contacts.length) {
    await execute(`DELETE FROM crm_contacts WHERE public_id IN (${created.contacts.map(() => "?").join(",")})`, created.contacts);
  }
  for (const email of [companyEmail, individualEmail, staffEmail]) {
    const user = await queryOne("SELECT id FROM users WHERE email_normalized = ?", [email]);
    if (!user) continue;
    const accounts = await query("SELECT account_id FROM account_members WHERE user_id = ?", [user.id]);
    for (const { account_id: accountId } of accounts) {
      await execute("DELETE FROM subscription_changes WHERE subscription_id IN (SELECT id FROM subscriptions WHERE account_id = ?)", [accountId]).catch(() => {});
      await execute("DELETE FROM subscriptions WHERE account_id = ?", [accountId]).catch(() => {});
      await execute("DELETE FROM account_addons WHERE account_id = ?", [accountId]).catch(() => {});
    }
  }
  await execute("DELETE FROM email_messages WHERE to_email IN (?, ?, ?)", [companyEmail, individualEmail, staffEmail]);
  await cleanupUsers([companyEmail, individualEmail, staffEmail]);
  await closePool();
});

describe("Add Company", () => {
  it("creates an approved company with the chosen categories, and emails the owner only a set-up link", async () => {
    const country = await firstCountry();
    const response = await admin.send("post", "/v1/admin/companies", {
      name: `Admin Made Realty ${suffix}`,
      organizationType: "agency",
      contactName: "Amal Testa",
      email: companyEmail,
      phone: phone(1),
      countryId: country.id,
      categoryId: "realEstate",
      categoryIds: ["realEstate", "cars"],
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    created.company = response.body.data.id;

    const org = await queryOne(
      `SELECT o.status, o.verification_status, o.is_publicly_visible, a.status AS account_status, a.id AS account_id,
              u.status AS user_status, u.email_verified_at, u.id AS user_id
         FROM organizations o JOIN accounts a ON a.id = o.account_id JOIN users u ON u.id = a.owner_user_id
        WHERE o.public_id = ?`,
      [created.company]
    );
    expect(org).toMatchObject({ status: "active", verification_status: "verified", is_publicly_visible: 1, account_status: "active", user_status: "pending_verification" });
    const categories = await query("SELECT category_id, status FROM account_category_access WHERE account_id = ? ORDER BY category_id", [org.account_id]);
    expect(categories.filter((row) => row.status === "approved").map((row) => Number(row.category_id))).toEqual([1, 2]);
    // No session was opened for someone who never signed in.
    expect((await queryOne("SELECT COUNT(*) AS n FROM user_sessions WHERE user_id = ?", [org.user_id])).n).toBe(0);
    expect((await emailsTo(companyEmail)).map((row) => row.template_key)).toEqual(["auth.account_setup"]);
  });

  it("lets the owner choose a password from the link, which confirms the email and allows sign-in", async () => {
    const token = await setupToken(companyEmail);
    const reset = await client().send("post", "/v1/auth/reset-password", { token, password: "Chosen-Pass-2026" });
    expect(reset.status, JSON.stringify(reset.body)).toBe(200);
    const user = await queryOne("SELECT status, email_verified_at FROM users WHERE email_normalized = ?", [companyEmail]);
    expect(user.status).toBe("active");
    expect(user.email_verified_at).not.toBeNull();
    const signIn = await client().login(companyEmail, "Chosen-Pass-2026");
    expect(signIn.status, JSON.stringify(signIn.body)).toBe(200);
    // A first password is not a "your password changed" event.
    expect((await emailsTo(companyEmail)).map((row) => row.template_key)).not.toContain("auth.password_changed");
    // The link works once.
    const again = await client().send("post", "/v1/auth/reset-password", { token, password: "Another-Pass-2026" });
    expect(again.status).toBe(400);
  });

  it("refuses a business type the API does not know, and an email already in use", async () => {
    const country = await firstCountry();
    const base = { name: "Nope Co", contactName: "No Body", phone: phone(2), countryId: country.id, categoryId: "realEstate" };
    const badType = await admin.send("post", "/v1/admin/companies", { ...base, email: `x-${suffix}@example.test`, organizationType: "bakery" });
    expect(badType.status).toBe(422);
    const taken = await admin.send("post", "/v1/admin/companies", { ...base, email: companyEmail, organizationType: "agency" });
    expect([409, 422]).toContain(taken.status);
  });
});

describe("Add Individual", () => {
  it("creates an approved individual and emails a set-up link", async () => {
    const country = await firstCountry();
    const response = await admin.send("post", "/v1/admin/individuals", {
      firstName: "Indy",
      lastName: `Vidual${suffix}`,
      email: individualEmail,
      phone: phone(3),
      countryId: country.id,
      categoryId: "cars",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    const row = await queryOne(
      `SELECT a.status, a.verification_status, a.seller_type FROM users u JOIN accounts a ON a.owner_user_id = u.id WHERE u.public_id = ?`,
      [response.body.data.id]
    );
    expect(row).toMatchObject({ status: "active", verification_status: "verified", seller_type: "individual" });
    expect((await emailsTo(individualEmail)).map((r) => r.template_key)).toEqual(["auth.account_setup"]);
    // The admin Individuals page can open it by the id returned.
    expect((await admin.get(`/v1/admin/individuals/${response.body.data.id}`)).status).toBe(200);
  });
});

describe("Add Admin User", () => {
  it("emails the new staff user a set-up link", async () => {
    await admin.stepUp();
    const response = await admin.send("post", "/v1/admin/access-users", { firstName: "Staff", lastName: `Member${suffix}`, email: staffEmail });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect((await emailsTo(staffEmail)).map((r) => r.template_key)).toEqual(["auth.account_setup"]);
  });

  it("offers only the statuses the API accepts", async () => {
    const sets = (await admin.get("/v1/admin/options", { sets: "internalUser.status,organization.kind" })).body.data;
    expect(sets["internalUser.status"].map((o) => o.value)).toEqual(["active", "pending_verification", "suspended"]);
    expect(sets["organization.kind"].map((o) => o.value)).toContain("developer");
  });
});

describe("Add / Edit Contact", () => {
  it("stores a contact in the chosen company's CRM and edits it", async () => {
    const response = await admin.send("post", "/v1/admin/contacts", {
      companyId: created.company,
      firstName: "Connie",
      lastName: "Tact",
      email: contactEmail,
      contactType: "investor",
      lifecycleStage: "lead",
      source: "website",
    });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    created.contacts.push(response.body.data.id);

    const edited = await admin.send("patch", `/v1/admin/contacts/${response.body.data.id}`, { lastName: "Edited", lifecycleStage: "customer", isVip: true });
    expect(edited.status, JSON.stringify(edited.body)).toBe(200);
    const row = await queryOne("SELECT display_name, lifecycle_stage, is_vip, contact_type FROM crm_contacts WHERE public_id = ?", [response.body.data.id]);
    expect(row).toEqual({ display_name: "Connie Edited", lifecycle_stage: "customer", is_vip: 1, contact_type: "investor" });

    const detail = await admin.get(`/v1/admin/contacts/${response.body.data.id}`);
    expect(detail.status).toBe(200);
  });

  it("archives a contact so it leaves the list", async () => {
    const extra = await admin.send("post", "/v1/admin/contacts", { companyId: created.company, firstName: "Archie", email: `archive-${suffix}@example.test` });
    expect(extra.status).toBe(201);
    created.contacts.push(extra.body.data.id);
    const archived = await admin.send("delete", `/v1/admin/contacts/${extra.body.data.id}`);
    expect(archived.status, JSON.stringify(archived.body)).toBe(200);
    expect((await admin.get(`/v1/admin/contacts/${extra.body.data.id}`)).status).toBe(404);
    expect((await admin.send("delete", `/v1/admin/contacts/${extra.body.data.id}`)).status).toBe(404);
  });

  it("refuses a contact without a company, a value outside the lists, and a duplicate email", async () => {
    expect((await admin.send("post", "/v1/admin/contacts", { firstName: "No", email: `n-${suffix}@example.test` })).status).toBe(422);
    expect((await admin.send("post", "/v1/admin/contacts", { companyId: created.company, firstName: "No", email: `n-${suffix}@example.test`, lifecycleStage: "nope" })).status).toBe(422);
    expect((await admin.send("post", "/v1/admin/contacts", { companyId: created.company, firstName: "Dup", email: contactEmail })).status).toBe(409);
  });
});
