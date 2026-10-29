import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupListings, cleanupUsers, client, createDisposablePortalOwner, createDisposableStaffUser, execute, queryOne } from "../helpers/testApp.js";
import { createListingSchema } from "../../src/modules/listings/listings.schemas.js";
import { createListing } from "../../src/modules/listings/listings.service.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Bulk moderation (Phase 7): one decision on many listings, each decided and reported on its own,
 * so a company's first feed of hundreds is not approved one by one. Throwaway owner and admin.
 */

const PASSWORD = "LivFinder!2026";
const admin = client();
let owner = null;
let staff = null;
let accountId = null;
const ids = [];

const statusOf = (publicId) => queryOne("SELECT status, moderation_status, rejection_reason FROM listings WHERE public_id = ?", [publicId]);

beforeAll(async () => {
  owner = await createDisposablePortalOwner({ prefix: "bulk-moderation" });
  ({ account_id: accountId } = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [owner.id]));
  await execute("UPDATE accounts SET listing_quota = NULL, storage_quota = NULL WHERE id = ?", [accountId]);
  const city = await queryOne("SELECT id FROM locations WHERE level = 'city' AND status = 'active' LIMIT 1");
  for (let index = 0; index < 4; index += 1) {
    const payload = createListingSchema.parse({
      category: "cars", categorySlug: "supercars", purpose: "sale", title: `QA bulk car ${index} ${Date.now()}`,
      price: 200000, currency: "AED", locationId: `city:${city.id}`, detail: { modelYear: 2021 }, status: "pending_review",
    });
    const created = await createListing({ payload, accountId, userId: owner.id, organizationId: null, agentId: null, ip: null });
    ids.push(created.publicId);
  }
  staff = await createDisposableStaffUser({ prefix: "bulk-moderation-admin", password: PASSWORD, roleCode: "super_admin" });
  await admin.login(staff.email, PASSWORD);
  await admin.stepUp?.();
});

afterAll(async () => {
  await execute("DELETE n FROM notifications n JOIN listings l ON l.id = n.subject_id WHERE n.subject_type = 'listing' AND l.account_id = ?", [accountId]);
  await cleanupListings(ids);
  if (owner) await cleanupUsers([owner.email]);
  if (staff) await cleanupUsers([staff.email]);
  await closePool();
});

describe("bulk moderation", () => {
  it("approves many listings at once and reports each", async () => {
    const response = await admin.send("post", "/v1/admin/listings/moderation/bulk", { ids: ids.slice(0, 2), decision: "approve" });
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(response.body.data).toMatchObject({ decided: 2, failed: 0 });
    for (const id of ids.slice(0, 2)) expect(await statusOf(id)).toMatchObject({ status: "active", moderation_status: "approved" });
  });

  it("needs a reason to reject, then rejects each with it", async () => {
    const without = await admin.send("post", "/v1/admin/listings/moderation/bulk", { ids: ids.slice(2), decision: "reject" });
    expect(without.status).toBe(422);
    const response = await admin.send("post", "/v1/admin/listings/moderation/bulk", { ids: ids.slice(2), decision: "reject", reason: "Add the mileage." });
    expect(response.body.data).toMatchObject({ decided: 2, failed: 0 });
    for (const id of ids.slice(2)) expect(await statusOf(id)).toMatchObject({ moderation_status: "rejected", rejection_reason: "Add the mileage." });
  });

  it("keeps going past a listing it cannot find, and says which", async () => {
    const response = await admin.send("post", "/v1/admin/listings/moderation/bulk", { ids: ["LF-DOES-NOT-EXIST", ids[0]], decision: "approve" });
    expect(response.body.data.results).toEqual([
      expect.objectContaining({ id: "LF-DOES-NOT-EXIST", ok: false }),
      expect.objectContaining({ id: ids[0], ok: true }),
    ]);
  });
});
