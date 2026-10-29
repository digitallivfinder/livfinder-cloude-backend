import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, createDisposablePortalOwner, cleanupUsers, queryOne, execute } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { ulid } from "../../src/utils/ids.js";

/**
 * Individual accounts cannot reach each other's records (Findings 1 and 2).
 *
 * Ownership checks were written `account_id = ? OR organization_id <=> ?`. An individual has no
 * organization, and `<=>` treats NULL as equal to NULL, so every individual matched every other
 * individual's rows. Two throwaway individuals: one owns an inquiry, the other must not see or
 * change it.
 */
const PASSWORD = "LivFinder!2026";
const owner = client();
const stranger = client();
let ownerUser;
let strangerUser;
let inquiry;

beforeAll(async () => {
  ownerUser = await createDisposablePortalOwner({ prefix: "tenant-owner", password: PASSWORD });
  strangerUser = await createDisposablePortalOwner({ prefix: "tenant-stranger", password: PASSWORD });
  const account = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [ownerUser.id]);
  const publicId = ulid();
  await execute(
    `INSERT INTO inquiries (public_id, reference, account_id, organization_id, name, email, message, status, created_at)
     VALUES (?, ?, ?, NULL, 'Tenant test buyer', 'tenant-test-buyer@example.test', 'Tenant isolation test', 'new', NOW(3))`,
    [publicId, `TT-${Date.now()}`, account.account_id]
  );
  inquiry = await queryOne("SELECT id, public_id, status FROM inquiries WHERE public_id = ?", [publicId]);
  expect((await owner.login(ownerUser.email, PASSWORD)).status).toBe(200);
  expect((await stranger.login(strangerUser.email, PASSWORD)).status).toBe(200);
});

afterAll(async () => {
  if (inquiry) await execute("DELETE FROM inquiries WHERE id = ?", [inquiry.id]);
  await cleanupUsers([ownerUser?.email, strangerUser?.email].filter(Boolean)).catch(() => {});
  await closePool();
});

describe("individual accounts", () => {
  it("cannot change another individual's inquiry", async () => {
    const response = await stranger.send("patch", `/v1/portal/inquiries/${inquiry.public_id}`, { status: "contacted" });
    expect([403, 404]).toContain(response.status);
    expect((await queryOne("SELECT status FROM inquiries WHERE id = ?", [inquiry.id])).status).toBe("new");
  });

  it("do not see another individual's inquiries on their dashboard", async () => {
    const dashboard = await stranger.get("/v1/portal/dashboard");
    expect(dashboard.status).toBe(200);
    expect(JSON.stringify(dashboard.body)).not.toContain(inquiry.public_id);
  });

  it("still reach their own", async () => {
    const dashboard = await owner.get("/v1/portal/dashboard");
    expect(dashboard.status).toBe(200);
    expect(JSON.stringify(dashboard.body)).toContain("Tenant test buyer");
  });
});
