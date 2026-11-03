import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { adminEmail, cleanupUsers, client, createDisposablePortalOwner, ensureTestPassword, execute, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { disableAddon } from "../../src/modules/accounts/addons.service.js";

/** A package that includes Integrations turns them on. Two throwaway plans and one company. */
const suffix = Date.now();
const admin = client();
const plans = {};
let ownerEmail;
let accountId;
let publicId;

const makePlan = async (name, addons) => {
  const created = await admin.send("post", "/v1/admin/plans", {
    name: `${name} ${suffix}`, code: `${name}_${suffix}`.toLowerCase(), billingInterval: "monthly", isActive: true, isPublic: false,
    listingQuota: 5, storageQuota: 10, featuredQuota: 0, agentSeatQuota: 2, leadQuota: 10, addons,
  });
  expect(created.status, JSON.stringify(created.body)).toBeLessThan(300);
  return created.body.data.id;
};
const change = (packageId) => admin.send("patch", `/v1/admin/companies/${publicId}/package`, { packageId, effective: "now" });
const addon = () => queryOne("SELECT status, enabled_by_user_id FROM account_addons WHERE account_id = ? AND addon_code = 'integrations'", [accountId]);
const integration = async () => (await admin.send("get", `/v1/admin/companies/${publicId}/integration`)).body.data;

beforeAll(async () => {
  await ensureTestPassword();
  await admin.login(await adminEmail("super_admin"));
  await admin.stepUp();
  const owner = await createDisposablePortalOwner({ prefix: "plan-addons" });
  ownerEmail = owner.email;
  ({ id: accountId } = await queryOne("SELECT id FROM accounts WHERE owner_user_id = ?", [owner.id]));
  await execute("UPDATE accounts a JOIN account_types t ON t.code = 'company' SET a.account_type_id = t.id WHERE a.id = ?", [accountId]);
  publicId = `addon${suffix}`;
  await execute(
    `INSERT INTO organizations (public_id, account_id, kind, name, legal_name, slug, status, verification_status, is_publicly_visible, created_at)
     VALUES (?, ?, 'agency', 'Addon Co', 'Addon Co LLC', ?, 'active', 'verified', 0, NOW(3))`,
    [publicId, accountId, publicId]
  );
  plans.with = await makePlan("With", [{ code: "integrations", isAvailable: true, amount: 100 }]);
  plans.without = await makePlan("Without", [{ code: "integrations", isAvailable: false, amount: 0 }]);
});

afterAll(async () => {
  await execute("DELETE FROM api_clients WHERE account_id = ?", [accountId]);
  await execute("DELETE FROM lead_feed_tokens WHERE account_id = ?", [accountId]);
  await execute("DELETE FROM account_addons WHERE account_id = ?", [accountId]);
  await execute("DELETE FROM subscription_changes WHERE subscription_id IN (SELECT id FROM subscriptions WHERE account_id = ?)", [accountId]);
  await execute("DELETE FROM subscriptions WHERE account_id = ?", [accountId]);
  await execute("DELETE FROM organizations WHERE public_id = ?", [publicId]);
  await cleanupUsers([ownerEmail]);
  await execute("DELETE FROM plans WHERE public_id IN (?, ?)", [plans.with, plans.without]);
  await closePool();
});

describe("Managing a company's integration from admin", () => {
  const path = () => `/v1/admin/companies/${publicId}/integration`;

  it("does what the portal does, with secrets shown once and never listed", async () => {
    await change(plans.with);
    const key = await admin.send("post", `${path()}/keys`, { name: "CRM", scopes: ["listings:write"], allowedIps: ["203.0.113.10"] });
    expect(key.status, JSON.stringify(key.body)).toBe(201);
    expect(key.body.data.secret).toBeTruthy();
    expect((await admin.send("patch", `${path()}/keys/${key.body.data.id}`, { name: "CRM 2", allowedIps: [] })).status).toBe(200);

    const hook = await admin.send("post", `${path()}/webhooks`, { name: "Leads", url: "https://example.com/hook", events: ["lead.created"] });
    expect(hook.status, JSON.stringify(hook.body)).toBe(201);
    const hookId = hook.body.data.id;
    expect((await admin.send("patch", `${path()}/webhooks/${hookId}`, { status: "paused" })).status).toBe(200);
    const rotated = await admin.send("post", `${path()}/webhooks/${hookId}/rotate-secret`);
    expect(rotated.body.data.secret).not.toBe(hook.body.data.secret);
    expect((await admin.send("get", `${path()}/webhooks/${hookId}/deliveries`)).status).toBe(200);

    const feed = await admin.send("post", `${path()}/lead-feeds`, { name: "Sheet" });
    expect(feed.body.data.token).toBeTruthy();

    const state = await integration();
    expect(state.keys[0]).toMatchObject({ name: "CRM 2", status: "active", allowedIps: [] });
    expect(state.webhooks[0]).toMatchObject({ name: "Leads", status: "paused" });
    expect(state.leadFeeds[0].name).toBe("Sheet");
    const listed = JSON.stringify(state);
    for (const value of [key.body.data.secret, rotated.body.data.secret, feed.body.data.token]) expect(listed).not.toContain(value);

    expect((await admin.send("delete", `${path()}/lead-feeds/${feed.body.data.id}`)).status).toBe(200);
    expect((await admin.send("delete", `${path()}/webhooks/${hookId}`)).status).toBe(200);
    expect((await admin.send("delete", `${path()}/keys/${key.body.data.id}`)).status).toBe(200);
    expect((await integration()).keys[0].status).toBe("revoked");
  });

  it("asks the admin to confirm, refuses other people, and needs the add-on on", async () => {
    const fresh = client();
    await fresh.login(await adminEmail("super_admin"));
    const stopped = await fresh.send("post", `${path()}/lead-feeds`, { name: "Nope" });
    expect(stopped.body.error.code).toBe("STEP_UP_REQUIRED");
    expect((await client().send("post", `${path()}/lead-feeds`, { name: "Nope" })).status).toBeGreaterThanOrEqual(401);
    await change(plans.without);
    expect((await admin.send("post", `${path()}/lead-feeds`, { name: "Nope" })).status).toBe(403);
    await change(plans.with);
  });

  it("cannot reach another company's key", async () => {
    const other = await queryOne("SELECT public_id FROM api_clients WHERE account_id <> ? LIMIT 1", [accountId]);
    if (other) expect((await admin.send("delete", `${path()}/keys/${other.public_id}`)).status).toBe(404);
  });
});

describe("A package that includes Integrations", () => {
  it("switches them on, and the admin screens agree", async () => {
    expect((await change(plans.with)).status).toBe(200);
    expect(await addon()).toMatchObject({ status: "active", enabled_by_user_id: null });
    const state = await integration();
    expect(state).toMatchObject({ enabled: true, availableOnPlan: true, imports: [] });
    expect(state.price).toMatchObject({ amount: 100, currency: "AED" });
    const detail = (await admin.send("get", `/v1/admin/companies/${publicId}`)).body.data;
    expect(detail.api.enabled).toBe(true);
    const list = (await admin.send("get", `/v1/admin/companies?search=Addon%20Co&pageSize=50`)).body;
    expect((list.items ?? list.data?.items ?? list.data).find((row) => row.id === publicId).api.enabled).toBe(true);
  });

  it("goes off with a package that does not include them", async () => {
    expect((await change(plans.without)).status).toBe(200);
    expect((await addon()).status).toBe("cancelled");
    expect((await integration()).enabled).toBe(false);
  });

  it("keeps a grant an admin made by hand", async () => {
    const grant = await admin.send("put", `/v1/admin/companies/${publicId}/addons/integrations`, { enabled: true });
    expect(grant.status, JSON.stringify(grant.body)).toBe(200);
    expect((await addon()).enabled_by_user_id).not.toBeNull();
    await change(plans.without);
    expect((await addon()).status).toBe("active");
    await disableAddon({ accountId, code: "integrations" });
  });

  it("reaches accounts already on a plan when it starts including them", async () => {
    await change(plans.without);
    await execute("DELETE FROM account_addons WHERE account_id = ?", [accountId]);
    const edited = await admin.send("patch", `/v1/admin/plans/${plans.without}`, {
      name: `Without ${suffix}`, addons: [{ code: "integrations", isAvailable: true, amount: 50 }],
    });
    expect(edited.status, JSON.stringify(edited.body)).toBeLessThan(300);
    expect((await addon()).status).toBe("active");
  });

  it("leaves it off when the account switched it off and the plan is only edited", async () => {
    await disableAddon({ accountId, code: "integrations" });
    await admin.send("patch", `/v1/admin/plans/${plans.without}`, { name: `Without ${suffix}`, addons: [{ code: "integrations", isAvailable: true, amount: 60 }] });
    expect((await addon()).status).toBe("cancelled");
  });
});
