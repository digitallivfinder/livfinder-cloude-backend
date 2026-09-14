import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, ensureTestPassword, adminEmail, findPortalOwner, createDisposablePortalOwner, cleanupUsers, queryOne, query, execute } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { decryptSecret } from "../../src/utils/secrets.js";

/**
 * Admin portal, against the real database.
 *
 * The two things that matter here are that every endpoint is gated by a real
 * permission — not by a hidden nav entry — and that a decision writes the
 * history the audit screens later read.
 */
const PASSWORD = "LivFinder!2026";
const superAdmin = client();
const moderator = client();
const support = client();
let portalOwner = null;

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  portalOwner = await findPortalOwner();
  await superAdmin.login(await adminEmail("super_admin"), PASSWORD);
  // Role, staff-user, suspension and payment-credential changes require step-up (SEC-IAM-011).
  // Doing it here is what a real administrator's client does after the first 403.
  await superAdmin.stepUp();
  await moderator.login(await adminEmail("moderator"), PASSWORD);
  await support.login(await adminEmail("support"), PASSWORD);
});

afterAll(async () => {
  await closePool();
});

describe("admin reads", () => {
  it("answers every list endpoint for a super admin", async () => {
    const paths = [
      "/v1/admin/dashboard", "/v1/admin/listings", "/v1/admin/developments", "/v1/admin/developers",
      "/v1/admin/companies", "/v1/admin/individuals", "/v1/admin/agents", "/v1/admin/leads",
      "/v1/admin/contacts", "/v1/admin/articles", "/v1/admin/articles/options", "/v1/admin/media",
      "/v1/admin/media/options", "/v1/admin/reviews", "/v1/admin/reports", "/v1/admin/roles",
      "/v1/admin/roles/options", "/v1/admin/access-users", "/v1/admin/system-logs",
      "/v1/admin/system-logs/options", "/v1/admin/packages", "/v1/admin/categories",
      "/v1/admin/locations/countries", "/v1/admin/locations/states", "/v1/admin/locations/cities",
      "/v1/admin/locations/communities", "/v1/admin/locations/sub-communities",
      "/v1/admin/locations/hierarchy-options", "/v1/admin/settings/general",
      "/v1/admin/settings/general/options", "/v1/admin/settings/payment",
      "/v1/admin/settings/payment/options", "/v1/admin/permission-catalog", "/v1/admin/me/permissions",
      "/v1/admin/business-activity",
    ];
    for (const path of paths) {
      const response = await superAdmin.get(path);
      expect(response.status, path).toBe(200);
    }
  });

  it("counts listings the same way the listings table does", async () => {
    const response = await superAdmin.get("/v1/admin/listings", { category: "cars", pageSize: 1 });
    const actual = await queryOne(
      "SELECT COUNT(*) AS total FROM listings WHERE root_category_id = 2 AND deleted_at IS NULL"
    );
    expect(response.body.total).toBe(Number(actual.total));
  });

  it("shows unpublished listings, which the public API does not", async () => {
    const response = await superAdmin.get("/v1/admin/listings", { status: "pending", pageSize: 5 });
    expect(response.body.items.length).toBeGreaterThan(0);
    const reference = response.body.items[0].reference;
    expect((await client().get(`/v1/public/listings/${reference}`)).status).toBe(404);
  });

  it("returns a listing detail with the leads and activity engagement blocks", async () => {
    const list = await superAdmin.get("/v1/admin/listings", { category: "real-estate", pageSize: 1 });
    const id = list.body.items[0].id;
    const response = await superAdmin.get(`/v1/admin/listings/${id}`);
    expect(response.status).toBe(200);
    const { engagement, gallery, documents } = response.body.data;
    expect(Array.isArray(gallery)).toBe(true);
    expect(Array.isArray(documents)).toBe(true);
    expect(Array.isArray(engagement.leads.records)).toBe(true);
    expect(engagement.leads.summary).toMatchObject({
      total: expect.any(Number),
      new: expect.any(Number),
      qualified: expect.any(Number),
      followUp: expect.any(Number),
      closed: expect.any(Number),
    });
    expect(Array.isArray(engagement.activity.events)).toBe(true);
    expect(engagement.activity.summary).toHaveProperty("total");
    const listingRow = await queryOne("SELECT id FROM listings WHERE public_id = ?", [id]);
    const leadCount = await queryOne(
      "SELECT COUNT(*) AS total FROM leads WHERE primary_listing_id = ? AND deleted_at IS NULL",
      [listingRow.id]
    );
    expect(engagement.leads.summary.total).toBe(Number(leadCount.total));
  });

  it("redacts credentials in a system log entry", async () => {
    const log = await queryOne(
      "SELECT id FROM system_logs WHERE context IS NOT NULL AND JSON_EXTRACT(context, '$.authorization') IS NOT NULL LIMIT 1"
    );
    if (!log) return;
    const response = await superAdmin.get(`/v1/admin/system-logs/${log.id}`);
    expect(response.body.data.context.authorization).toBe("[redacted]");
  });
});

describe("permission gating", () => {
  it("lets a moderator moderate but not read finance or settings", async () => {
    expect((await moderator.get("/v1/admin/listings")).status).toBe(200);
    expect((await moderator.get("/v1/admin/reviews")).status).toBe(200);
    expect((await moderator.get("/v1/admin/packages")).status).toBe(403);
    expect((await moderator.get("/v1/admin/settings/general")).status).toBe(403);
    expect((await moderator.get("/v1/admin/system-logs")).status).toBe(403);
  });

  it("lets support read users but not moderate a listing", async () => {
    expect((await support.get("/v1/admin/companies")).status).toBe(200);
    const listing = await queryOne("SELECT public_id FROM listings WHERE status = 'pending_review' LIMIT 1");
    const response = await support.send("patch", `/v1/admin/listings/${listing.public_id}/moderation`, {
      decision: "approve",
    });
    expect(response.status).toBe(403);
  });

  it("refuses an unauthenticated caller before it refuses an unauthorised one", async () => {
    const response = await client().get("/v1/admin/dashboard");
    expect(response.status).toBe(401);
  });

  it("reports the caller's own resolved permissions", async () => {
    const response = await moderator.get("/v1/admin/me/permissions");
    expect(response.body.data.databasePermissions).toContain("listings.moderate");
    expect(response.body.data.databasePermissions).not.toContain("finance.view");
  });
});

describe("moderation writes history", () => {
  let listingId = null;
  let previous = null;

  beforeAll(async () => {
    const row = await queryOne(
      "SELECT public_id, status, moderation_status FROM listings WHERE status = 'pending_review' AND deleted_at IS NULL LIMIT 1"
    );
    listingId = row.public_id;
    previous = row;
  });

  afterAll(async () => {
    if (!listingId) return;
    const row = await queryOne("SELECT id FROM listings WHERE public_id = ?", [listingId]);
    await execute(
      "UPDATE listings SET status = ?, moderation_status = ?, rejection_reason = NULL WHERE id = ?",
      [previous.status, previous.moderation_status, row.id]
    );
    await execute("DELETE FROM listing_status_history WHERE listing_id = ? AND reason IN ('integration approve', 'integration reject')", [row.id]);
    await execute("CALL sp_refresh_listing_search(?)", [row.id]);
  });

  it("records the transition and refreshes the projection on approval", async () => {
    const response = await moderator.send("patch", `/v1/admin/listings/${listingId}/moderation`, {
      decision: "approve",
      note: "integration approve",
    });
    expect(response.status).toBe(200);

    const row = await queryOne("SELECT id, status FROM listings WHERE public_id = ?", [listingId]);
    expect(row.status).toBe("active");

    const history = await queryOne(
      "SELECT to_status, reason FROM listing_status_history WHERE listing_id = ? ORDER BY id DESC LIMIT 1",
      [row.id]
    );
    expect(history).toMatchObject({ to_status: "active", reason: "integration approve" });

    const projection = await queryOne("SELECT listing_id FROM listing_search WHERE listing_id = ?", [row.id]);
    expect(projection).toBeTruthy();
  });

  it("requires a reason to reject and removes it from the projection", async () => {
    const missing = await moderator.send("patch", `/v1/admin/listings/${listingId}/moderation`, { decision: "reject" });
    expect(missing.status).toBe(422);

    const response = await moderator.send("patch", `/v1/admin/listings/${listingId}/moderation`, {
      decision: "reject",
      reason: "integration reject",
    });
    expect(response.status).toBe(200);

    const row = await queryOne("SELECT id, status, rejection_reason FROM listings WHERE public_id = ?", [listingId]);
    expect(row).toMatchObject({ status: "rejected", rejection_reason: "integration reject" });
    const projection = await queryOne("SELECT listing_id FROM listing_search WHERE listing_id = ?", [row.id]);
    expect(projection).toBeNull();
  });

  it("writes an audit row for the decision", async () => {
    const audit = await queryOne(
      `SELECT action, actor_user_id FROM audit_logs
        WHERE subject_type = 'listing' AND action LIKE 'listing.%' ORDER BY occurred_at DESC LIMIT 1`
    );
    expect(audit.action).toMatch(/^listing\./);
    expect(audit.actor_user_id).toBeTruthy();
  });
});

describe("verification decisions", () => {
  let organizationId = null;
  let before = null;

  beforeAll(async () => {
    const row = await queryOne(
      `SELECT public_id, status, verification_status, is_publicly_visible
         FROM organizations WHERE deleted_at IS NULL AND verification_status <> 'verified' LIMIT 1`
    );
    organizationId = row?.public_id ?? null;
    before = row;
  });

  afterAll(async () => {
    if (!organizationId) return;
    await execute(
      "UPDATE organizations SET status = ?, verification_status = ?, is_publicly_visible = ?, verified_at = NULL WHERE public_id = ?",
      [before.status, before.verification_status, before.is_publicly_visible, organizationId]
    );
  });

  it("verifying an organization makes it publicly visible and moves its account", async () => {
    if (!organizationId) return;
    const response = await superAdmin.send("patch", `/v1/admin/companies/${organizationId}/verification`, {
      decision: "approve",
      note: "integration",
    });
    expect(response.status).toBe(200);

    const row = await queryOne(
      "SELECT id, status, verification_status, is_publicly_visible, account_id FROM organizations WHERE public_id = ?",
      [organizationId]
    );
    expect(row).toMatchObject({ status: "active", verification_status: "verified", is_publicly_visible: 1 });

    const account = await queryOne("SELECT verification_status FROM accounts WHERE id = ?", [row.account_id]);
    expect(account.verification_status).toBe("verified");
  });

  it("suspending a company takes its live listings off the marketplace", async () => {
    if (!organizationId) return;
    const row = await queryOne("SELECT id FROM organizations WHERE public_id = ?", [organizationId]);
    const activeBefore = await query(
      "SELECT id FROM listings WHERE organization_id = ? AND status = 'active'",
      [row.id]
    );
    if (activeBefore.length === 0) return;

    await superAdmin.send("patch", `/v1/admin/companies/${organizationId}/status`, {
      status: "suspended",
      reason: "integration",
    });
    const activeAfter = await queryOne(
      "SELECT COUNT(*) AS total FROM listings WHERE organization_id = ? AND status = 'active'",
      [row.id]
    );
    expect(Number(activeAfter.total)).toBe(0);

    // Restore exactly what the test changed: only the listings it took down. The old restore set
    // every withdrawn listing of the company active, including ones withdrawn before the test.
    await execute(
      `UPDATE listings SET status = 'active' WHERE id IN (${activeBefore.map(() => "?").join(",")}) AND status = 'withdrawn'`,
      activeBefore.map((listing) => listing.id)
    );
    await execute("CALL sp_refresh_listing_search(NULL)", []);
  });

  it("grants a company access to another category, in the slug the admin screens use", async () => {
    const org = await queryOne(
      "SELECT o.id, o.public_id, o.account_id FROM organizations o WHERE o.deleted_at IS NULL LIMIT 1"
    );
    // Pick a category the account does not already have.
    const existing = await query(
      "SELECT c.code FROM account_category_access aca JOIN categories c ON c.id = aca.category_id WHERE aca.account_id = ?",
      [org.account_id]
    );
    const have = new Set(existing.map((entry) => entry.code));
    const target = ["yachts", "cars", "jets", "helicopters", "watches"].find((slug) => !have.has(slug));
    // Only a category the company does not already hold. The old `|| "yachts"` fallback
    // "granted" yachts to a company that already had it, then deleted that real grant below.
    if (!target) return;

    const response = await superAdmin.send("patch", `/v1/admin/companies/${org.public_id}/category-access`, {
      categoryId: target,
      decision: "approve",
    });
    expect(response.status).toBe(200);

    const rootId = { yachts: 3, cars: 2, jets: 4, helicopters: 5, watches: 6 }[target];
    const granted = await queryOne(
      "SELECT status FROM account_category_access WHERE account_id = ? AND category_id = ?",
      [org.account_id, rootId]
    );
    expect(granted.status).toBe("approved");

    // The company detail reads it back with the `listingType` slug the admin panels key on.
    const detail = (await superAdmin.get(`/v1/admin/companies/${org.public_id}`)).body.data;
    expect(detail.enabledCategories).toContain(target);
    expect(detail.enabledCategories).not.toContain("realEstate");

    await execute("DELETE FROM account_category_access WHERE account_id = ? AND category_id = ?", [org.account_id, rootId]);
  });

  it("grants Real Estate Developments as its own seventh category", async () => {
    const org = await queryOne(
      "SELECT o.id, o.public_id, o.account_id FROM organizations o WHERE o.deleted_at IS NULL LIMIT 1"
    );
    const before = await queryOne(
      "SELECT status FROM account_category_access WHERE account_id = ? AND category_id = 7",
      [org.account_id]
    );

    const on = await superAdmin.send("patch", `/v1/admin/companies/${org.public_id}/category-access`, {
      categoryId: "real-estate-developments",
      decision: "approve",
    });
    expect(on.status).toBe(200);
    expect(on.body.data.categoryId).toBe("realEstateDevelopment");

    const row = await queryOne(
      "SELECT status FROM account_category_access WHERE account_id = ? AND category_id = 7",
      [org.account_id]
    );
    expect(row.status).toBe("approved");

    const detail = (await superAdmin.get(`/v1/admin/companies/${org.public_id}`)).body.data;
    expect(detail.enabledCategories).toContain("real-estate-developments");

    // Cleanup.
    if (before) {
      await execute("UPDATE account_category_access SET status = ? WHERE account_id = ? AND category_id = 7", [before.status, org.account_id]);
    } else {
      await execute("DELETE FROM account_category_access WHERE account_id = ? AND category_id = 7", [org.account_id]);
    }
  });

  it("grants a category to an individual, independent of their account type", async () => {
    const individual = (await superAdmin.get("/v1/admin/individuals", { pageSize: 1 })).body.items[0];
    expect(individual).toBeTruthy();
    const account = await queryOne(
      `SELECT am.account_id FROM users u
         JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
        WHERE u.public_id = ? LIMIT 1`,
      [individual.id]
    );

    const response = await superAdmin.send("patch", `/v1/admin/individuals/${individual.id}/category-access`, {
      categoryId: "yachts",
      decision: "approve",
    });
    expect(response.status).toBe(200);

    const granted = await queryOne(
      "SELECT status FROM account_category_access WHERE account_id = ? AND category_id = 3",
      [account.account_id]
    );
    expect(granted.status).toBe("approved");

    const detail = (await superAdmin.get(`/v1/admin/individuals/${individual.id}`)).body.data;
    expect(detail.enabledCategories).toContain("yachts");

    await execute("DELETE FROM account_category_access WHERE account_id = ? AND category_id = 3", [account.account_id]);
  });
});

describe("settings", () => {
  it("stores a provider secret encrypted and never returns it", async () => {
    const write = await superAdmin.send("patch", "/v1/admin/settings/payment", {
      credentials: { stripe_secret_key: "sk_test_integration_9876" },
    });
    expect(write.status).toBe(200);
    expect(write.text).not.toContain("sk_test_integration_9876");

    const stored = await queryOne(
      "SELECT value, is_secret FROM settings WHERE group_key = 'payment' AND setting_key = 'stripe_secret_key'"
    );
    expect(stored.is_secret).toBe(1);
    expect(stored.value.startsWith("enc:v1:")).toBe(true);
    expect(decryptSecret(stored.value)).toBe("sk_test_integration_9876");

    const read = await superAdmin.get("/v1/admin/settings/payment");
    expect(read.text).not.toContain("sk_test_integration_9876");
    expect(read.body.data._flat.stripe_secret_key).toMatchObject({ configured: true });
  });

  it("never writes a secret value into the audit log", async () => {
    const audit = await queryOne(
      `SELECT changes FROM audit_logs WHERE action = 'settings.updated' ORDER BY occurred_at DESC LIMIT 1`
    );
    expect(JSON.stringify(audit.changes ?? {})).not.toContain("sk_test_integration_9876");
  });

  it("persists a settings section and mirrors it into the public flat row", async () => {
    const write = await superAdmin.send("patch", "/v1/admin/settings/general", {
      general: { platformName: "LivFinder Integration" },
    });
    expect(write.status).toBe(200);

    const read = await superAdmin.get("/v1/admin/settings/general");
    expect(read.body.data.general.platformName).toBe("LivFinder Integration");

    const flat = await queryOne("SELECT value FROM settings WHERE group_key = 'general' AND setting_key = 'site_name'");
    expect(flat.value).toBe("LivFinder Integration");

    await superAdmin.send("patch", "/v1/admin/settings/general", { general: { platformName: "Liv Finder" } });
  });

  it("ignores a settings key that is not part of the schema", async () => {
    const before = await queryOne("SELECT COUNT(*) AS total FROM settings WHERE group_key = 'admin_general'");
    await superAdmin.send("patch", "/v1/admin/settings/general", { notASection: { anything: true } });
    const after = await queryOne("SELECT COUNT(*) AS total FROM settings WHERE group_key = 'admin_general'");
    expect(Number(after.total)).toBe(Number(before.total));
  });
});

describe("access management", () => {
  it("creates a role, grants permissions, and refuses to delete a system role", async () => {
    const name = `Integration Role ${Date.now()}`;
    const created = await superAdmin.send("post", "/v1/admin/roles", {
      name,
      description: "Created by the integration suite.",
      databasePermissions: ["listings.view", "reports.view"],
    });
    expect(created.status).toBe(201);
    const roleId = created.body.data.id;

    const read = await superAdmin.get(`/v1/admin/roles/${roleId}`);
    expect(read.body.data.databasePermissions).toEqual(["listings.view", "reports.view"]);
    // The frontend vocabulary is derived, not stored twice.
    expect(read.body.data.permissions).toContain("listings.view");

    const systemRole = await queryOne("SELECT id FROM roles WHERE code = 'super_admin'");
    expect((await superAdmin.send("delete", `/v1/admin/roles/${systemRole.id}`)).status).toBe(409);

    expect((await superAdmin.send("delete", `/v1/admin/roles/${roleId}`)).status).toBe(200);
  });

  it("suspending a user ends their live sessions", async () => {
    // A throwaway user: suspending bumps the session epoch, and doing it to the real seeded
    // portal owner signed that person out of their own browser on every run.
    const disposable = await createDisposablePortalOwner({ prefix: "suspend-target", password: PASSWORD });
    try {
      const target = client();
      await target.login(disposable.email, PASSWORD);
      expect((await target.get("/v1/auth/session")).body.data.authenticated).toBe(true);

      const response = await superAdmin.send("patch", `/v1/admin/users/${disposable.publicId}/status`, {
        status: "suspended",
        reason: "integration",
      });
      expect(response.status).toBe(200);

      expect((await target.get("/v1/auth/session")).body.data).toBeNull();
    } finally {
      // Audit rows may keep a suspended throwaway user alive; an example.test account is harmless.
      await cleanupUsers([disposable.email]).catch(() => {});
    }
  });

  it("refuses a self-lockout and refuses to strip the last active Super Administrator", async () => {
    // The admin UI disables both of these menu items. That is presentation; the rules have to
    // hold when the request is crafted by hand, so they are asserted against the API directly.
    const me = await queryOne(
      "SELECT u.id, u.public_id FROM users u WHERE u.email = ? AND u.deleted_at IS NULL",
      [await adminEmail("super_admin")]
    );

    const selfSuspend = await superAdmin.send(`patch`, `/v1/admin/users/${me.public_id}/status`, {
      status: "suspended",
      reason: "integration",
    });
    expect(selfSuspend.status).toBe(403);
    const unchanged = await queryOne("SELECT status FROM users WHERE id = ?", [me.id]);
    expect(unchanged.status).toBe("active");

    // Another admin cannot deactivate them either, while they are the only active super admin.
    const otherSupers = await query(
      `SELECT u.id FROM user_roles ur JOIN users u ON u.id = ur.user_id
        WHERE ur.role_id = 1 AND ur.user_id <> ? AND u.status = 'active' AND u.deleted_at IS NULL`,
      [me.id]
    );
    if (otherSupers.length === 0) {
      const stripRole = await superAdmin.send("patch", `/v1/admin/access-users/${me.public_id}`, {
        firstName: "Super",
        lastName: "Admin",
        email: await adminEmail("super_admin"),
        roleIds: ["3"],
      });
      expect(stripRole.status).toBe(409);
      const stillSuper = await queryOne(
        "SELECT 1 AS ok FROM user_roles WHERE user_id = ? AND role_id = 1",
        [me.id]
      );
      expect(stillSuper?.ok).toBe(1);
    }
  });
});

describe("editorial", () => {
  let articleId = null;

  afterAll(async () => {
    if (articleId) await execute("DELETE FROM post_terms WHERE post_id = (SELECT id FROM posts WHERE public_id = ?)", [articleId]);
    if (articleId) await execute("DELETE FROM posts WHERE public_id = ?", [articleId]);
  });

  it("creates a draft and publishes it into the public feed", async () => {
    const created = await superAdmin.send("post", "/v1/admin/articles", {
      title: `Integration Article ${Date.now()}`,
      contentHtml: "<p>First paragraph.</p><h2>Section</h2><p>Second paragraph.</p>",
      status: "draft",
      categories: ["market-insight"],
    });
    expect(created.status).toBe(201);
    articleId = created.body.data.id;

    const row = await queryOne("SELECT slug, status, reading_time_minutes FROM posts WHERE public_id = ?", [articleId]);
    expect(row.status).toBe("draft");
    expect(row.reading_time_minutes).toBeGreaterThan(0);

    // A draft is not in the public feed.
    expect((await client().get(`/v1/public/blogs/${row.slug}`)).status).toBe(404);

    const published = await superAdmin.send("patch", `/v1/admin/articles/${articleId}/status`, { status: "published" });
    expect(published.status).toBe(200);

    const publicRead = await client().get(`/v1/public/blogs/${row.slug}`);
    expect(publicRead.status).toBe(200);
    expect(publicRead.body.data.body[0]).toMatchObject({ type: "paragraph", text: "First paragraph." });
  });

  it("refuses to publish for an editor without the publish permission", async () => {
    const editor = client();
    await editor.login(await adminEmail("editor"), PASSWORD);
    const hasPublish = await queryOne(
      `SELECT p.code FROM roles r JOIN role_permissions rp ON rp.role_id = r.id
         JOIN permissions p ON p.id = rp.permission_id
        WHERE r.code = 'editor' AND p.code = 'content.publish'`
    );
    if (hasPublish) return;
    const response = await editor.send("post", "/v1/admin/articles", { title: "Should not publish", status: "published" });
    expect(response.status).toBe(403);
  });
});
