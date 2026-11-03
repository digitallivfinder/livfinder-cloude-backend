import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { adminEmail, cleanupUsers, client, createDisposablePortalOwner, ensureTestPassword, execute, query, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { applyDuePlanChanges } from "../../src/modules/accounts/accounts.service.js";

/**
 * "Next Billing Cycle" in Change Package: the account keeps its plan and quotas until renewal.
 * Everything runs on a disposable company and two real plans; the suite only reads the plans.
 */
const suffix = Date.now();
const admin = client();
let ownerEmail;
let accountId;
let organizationId;
let organizationPublicId;
let subscriptionId;
let ownerPublicId;
let startPlan;
let nextPlan;

const change = (packageId, effective) =>
  admin.send("patch", `/v1/admin/companies/${organizationPublicId}/package`, { packageId, effective });
const account = () => queryOne("SELECT listing_quota FROM accounts WHERE id = ?", [accountId]);
const subscription = () =>
  queryOne("SELECT plan_id, current_period_start, current_period_end FROM subscriptions WHERE id = ?", [subscriptionId]);
const changes = () =>
  query("SELECT status, effective_timing, to_plan_id FROM subscription_changes WHERE subscription_id = ? ORDER BY id", [subscriptionId]);
const detail = async () => (await admin.get(`/v1/admin/companies/${organizationPublicId}`)).body.data;

async function reset({ periodEnd = "DATE_ADD(NOW(3), INTERVAL 20 DAY)" } = {}) {
  await execute("DELETE FROM subscription_changes WHERE subscription_id = ?", [subscriptionId]);
  await execute(
    `UPDATE subscriptions SET plan_id = ?, billing_interval = ?, current_period_start = DATE_SUB(NOW(3), INTERVAL 10 DAY), current_period_end = ${periodEnd} WHERE id = ?`,
    [startPlan.id, startPlan.billing_interval, subscriptionId]
  );
  await execute("UPDATE accounts SET listing_quota = ? WHERE id = ?", [startPlan.listing_quota, accountId]);
}

beforeAll(async () => {
  await ensureTestPassword();
  const owner = await createDisposablePortalOwner({ prefix: "package-schedule" });
  ownerEmail = owner.email;
  ownerPublicId = owner.publicId;
  ({ id: accountId } = await queryOne("SELECT id FROM accounts WHERE owner_user_id = ?", [owner.id]));
  await execute("UPDATE accounts a JOIN account_types t ON t.code = 'company' SET a.account_type_id = t.id WHERE a.id = ?", [accountId]);
  organizationPublicId = `sched${suffix}`;
  ({ insertId: organizationId } = await execute(
    `INSERT INTO organizations (public_id, account_id, kind, name, legal_name, slug, status, verification_status, is_publicly_visible, created_at)
     VALUES (?, ?, 'agency', 'Schedule Test', 'Schedule Test LLC', ?, 'active', 'verified', 0, NOW(3))`,
    [organizationPublicId, accountId, `schedule-test-${suffix}`]
  ));
  const plans = await query(
    `SELECT id, public_id, listing_quota, billing_interval FROM plans
      WHERE is_active = 1 AND billing_interval IN ('monthly', 'yearly') AND listing_quota IS NOT NULL ORDER BY listing_quota DESC LIMIT 2`
  );
  [startPlan, nextPlan] = [plans[1], plans[0]];
  ({ insertId: subscriptionId } = await execute(
    `INSERT INTO subscriptions (public_id, account_id, plan_id, status, amount, currency_code, billing_interval, created_at)
     VALUES (?, ?, ?, 'active', 0, 'AED', ?, NOW(3))`,
    [`sched${suffix}`, accountId, startPlan.id, startPlan.billing_interval]
  ));
  await admin.login(await adminEmail("super_admin"));
  await admin.stepUp();
});

afterAll(async () => {
  await execute("DELETE FROM subscription_changes WHERE subscription_id = ?", [subscriptionId]);
  await execute("DELETE FROM subscriptions WHERE account_id = ?", [accountId]);
  await execute("DELETE FROM organizations WHERE id = ?", [organizationId]);
  await cleanupUsers([ownerEmail]);
  await closePool();
});

describe("Changing a package for the next billing cycle", () => {
  it("leaves the plan and quotas alone until the renewal date", async () => {
    await reset();
    const response = await change(nextPlan.public_id, "next");
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(response.body.data).toMatchObject({ scheduled: true, chargeRaised: false });
    expect(response.body.data.effectiveAt).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(Number((await subscription()).plan_id)).toBe(Number(startPlan.id));
    expect((await account()).listing_quota).toBe(startPlan.listing_quota);
    expect((await changes())[0]).toMatchObject({ status: "scheduled", effective_timing: "period_end" });
    expect((await detail()).scheduledPackage).toMatchObject({ packageId: nextPlan.public_id, effectiveAt: response.body.data.effectiveAt });
  });

  it("does nothing before the date", async () => {
    await applyDuePlanChanges();
    expect(Number((await subscription()).plan_id)).toBe(Number(startPlan.id));
    expect((await changes())[0].status).toBe("scheduled");
  });

  it("applies the plan and quotas once due, and starts the next period", async () => {
    await execute("UPDATE subscription_changes SET effective_at = DATE_SUB(NOW(3), INTERVAL 1 HOUR) WHERE subscription_id = ?", [subscriptionId]);
    await execute("UPDATE subscriptions SET current_period_end = DATE_SUB(NOW(3), INTERVAL 1 HOUR) WHERE id = ?", [subscriptionId]);
    const lapsed = await subscription();
    await applyDuePlanChanges();
    const after = await subscription();
    expect(Number(after.plan_id)).toBe(Number(nextPlan.id));
    expect((await account()).listing_quota).toBe(nextPlan.listing_quota);
    expect((await changes())[0].status).toBe("applied");
    expect(new Date(after.current_period_start).getTime()).toBe(new Date(lapsed.current_period_end).getTime());
    expect(new Date(after.current_period_end).getTime()).toBeGreaterThan(Date.now());
    expect((await detail()).scheduledPackage).toBeNull();
  });

  it("applies straight away when the period has already lapsed", async () => {
    await reset({ periodEnd: "DATE_SUB(NOW(3), INTERVAL 1 DAY)" });
    const response = await change(nextPlan.public_id, "next");
    expect(response.body.data.scheduled).toBe(false);
    expect(Number((await subscription()).plan_id)).toBe(Number(nextPlan.id));
    expect(await changes()).toHaveLength(0);
  });

  it("replaces an earlier schedule, and an immediate change cancels it", async () => {
    await reset();
    await change(nextPlan.public_id, "next");
    await change(nextPlan.public_id, "next");
    expect((await changes()).map((row) => row.status)).toEqual(["cancelled", "scheduled"]);
    const now = await change(nextPlan.public_id, "now");
    expect(now.body.data.scheduled).toBe(false);
    expect(Number((await subscription()).plan_id)).toBe(Number(nextPlan.id));
    expect((await changes()).map((row) => row.status)).toEqual(["cancelled", "cancelled"]);
  });

  it("can be cancelled, and then never applies", async () => {
    await reset();
    await change(nextPlan.public_id, "next");
    const path = `/v1/admin/companies/${organizationPublicId}/package/scheduled`;
    expect((await admin.send("delete", path)).status).toBe(200);
    expect((await changes())[0].status).toBe("cancelled");
    expect((await detail()).scheduledPackage).toBeNull();
    await execute("UPDATE subscription_changes SET effective_at = DATE_SUB(NOW(3), INTERVAL 1 HOUR) WHERE subscription_id = ?", [subscriptionId]);
    await applyDuePlanChanges();
    expect(Number((await subscription()).plan_id)).toBe(Number(startPlan.id));
    expect((await admin.send("delete", path)).status).toBe(404);
  });

  it("marks a change it cannot apply as failed and leaves the account alone", async () => {
    await reset();
    await change(nextPlan.public_id, "next");
    await execute("UPDATE subscription_changes SET effective_at = DATE_SUB(NOW(3), INTERVAL 1 HOUR), to_plan_id = NULL WHERE subscription_id = ?", [subscriptionId]);
    await applyDuePlanChanges();
    expect((await changes())[0].status).toBe("failed");
    expect(Number((await subscription()).plan_id)).toBe(Number(startPlan.id));
  });

  it("finds an individual by the id the Individuals screen uses", async () => {
    await reset();
    const response = await admin.send("patch", `/v1/admin/companies/${ownerPublicId}/package`, { packageId: nextPlan.public_id, effective: "now" });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(Number((await subscription()).plan_id)).toBe(Number(nextPlan.id));
  });

  it("leaves old demo rows alone: they are not requests from this flow", async () => {
    await reset();
    await execute(
      `INSERT INTO subscription_changes (subscription_id, change_type, from_plan_id, to_plan_id, effective_timing, effective_at, reason, status)
       VALUES (?, 'upgrade', ?, ?, 'period_end', '2026-01-01', 'Demo upgrade', 'scheduled')`,
      [subscriptionId, startPlan.id, nextPlan.id]
    );
    await applyDuePlanChanges();
    expect((await changes())[0].status).toBe("scheduled");
    expect(Number((await subscription()).plan_id)).toBe(Number(startPlan.id));
    expect((await detail()).scheduledPackage).toBeNull();
  });

  it("will not schedule the plan the account is already on", async () => {
    await reset();
    expect((await change(startPlan.public_id, "next")).status).toBe(422);
  });
});
