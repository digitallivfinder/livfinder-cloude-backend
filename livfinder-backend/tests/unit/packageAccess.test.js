import { describe, expect, it } from "vitest";
import { decidePackage, isPackageFreePortalPath, packageAudiences, packageRequiredError } from "../../src/modules/accounts/entitlement.js";

const FREE = { paymentsRequired: false, graceDays: 7 };
const PAY = { paymentsRequired: true, graceDays: 7 };
const NOW = Date.parse("2026-11-24T12:00:00Z");
const row = (overrides = {}) => ({
  subscription_id: 10,
  subscription_status: "active",
  current_period_end: "2026-12-24T00:00:00Z",
  plan_public_id: "plan_1",
  plan_name: "Agency Essential",
  plan_audience: "company",
  free_access: 0,
  package_prompt_dismissed_at: null,
  ...overrides,
});

describe("decidePackage", () => {
  it("has no package without a subscription, whatever the payment rule", () => {
    for (const rules of [FREE, PAY]) {
      const state = decidePackage(row({ subscription_id: null, subscription_status: null }), rules, NOW);
      expect(state).toMatchObject({ chosen: false, active: false, reason: "no_package", planId: null });
    }
  });

  it("does not count the Members' Free plan as a seller package", () => {
    expect(decidePackage(row({ plan_audience: "personal" }), FREE, NOW)).toMatchObject({ chosen: false, reason: "no_package" });
  });

  it("works without payment while clients need not pay, even when past due", () => {
    const state = decidePackage(row({ subscription_status: "past_due", current_period_end: "2026-01-01T00:00:00Z" }), FREE, NOW);
    expect(state).toMatchObject({ chosen: true, active: true, reason: null, paymentNeeded: false });
  });

  it("needs payment once clients must pay: active and trialing work", () => {
    expect(decidePackage(row(), PAY, NOW)).toMatchObject({ active: true, paymentNeeded: true });
    expect(decidePackage(row({ subscription_status: "trialing" }), PAY, NOW).active).toBe(true);
  });

  it("keeps a past-due package working through the grace period, then pauses it", () => {
    const inGrace = row({ subscription_status: "past_due", current_period_end: "2026-11-20T00:00:00Z" });
    const pastGrace = row({ subscription_status: "past_due", current_period_end: "2026-11-01T00:00:00Z" });
    expect(decidePackage(inGrace, PAY, NOW).active).toBe(true);
    expect(decidePackage(pastGrace, PAY, NOW)).toMatchObject({ active: false, reason: "unpaid" });
  });

  it("lets free access skip payment, but still needs a package", () => {
    const pastGrace = row({ subscription_status: "past_due", current_period_end: "2026-11-01T00:00:00Z", free_access: 1 });
    expect(decidePackage(pastGrace, PAY, NOW)).toMatchObject({ active: true, freeAccess: true, paymentNeeded: false });
    expect(decidePackage(row({ subscription_id: null, free_access: 1 }), PAY, NOW).reason).toBe("no_package");
  });

  it("remembers that the seller pressed Later", () => {
    expect(decidePackage(row({ package_prompt_dismissed_at: "2026-11-24T10:00:00Z" }), FREE, NOW).promptDismissed).toBe(true);
  });
});

describe("portal paths a seller without a package keeps", () => {
  it("keeps the basics", () => {
    for (const path of ["/dashboard", "/profile", "/settings/account", "/messages/abc", "/billing", "/billing/plan", "/payments", "/organization", "/my-enquiries"]) {
      expect(isPackageFreePortalPath(path)).toBe(true);
    }
  });

  it("closes the seller tools, including the company's team", () => {
    for (const path of ["/listings", "/leads/1", "/inquiries", "/bookings", "/offers", "/reviews", "/integrations", "/webhooks", "/organization/agents", "/organization/invitations", "/developments", "/category-requests", "/payouts"]) {
      expect(isPackageFreePortalPath(path)).toBe(false);
    }
  });

  it("says what to do in the error", () => {
    expect(packageRequiredError("no_package")).toMatchObject({ status: 403, code: "PACKAGE_REQUIRED" });
    expect(packageRequiredError("unpaid").message).toMatch(/payment/);
  });
});

describe("packageAudiences", () => {
  it("offers individuals the lister plans and companies the company plans", () => {
    expect(packageAudiences("lister")).toEqual(["lister", "any"]);
    expect(packageAudiences("company")).toEqual(["company", "organization", "any"]);
    expect(packageAudiences("personal")).toEqual(["personal", "any"]);
  });
});
