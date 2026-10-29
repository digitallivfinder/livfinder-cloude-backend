import crypto from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import request from "supertest";
import { app, cleanupListings, cleanupUsers, client, createDisposablePortalOwner, execute, query, queryOne } from "../helpers/testApp.js";
import { createListingSchema } from "../../src/modules/listings/listings.schemas.js";
import { changeListingStatus, createListing } from "../../src/modules/listings/listings.service.js";
import { listLeadsSince } from "../../src/modules/leads/leadExport.service.js";
import { createWebhook, deliverDue, setWebhookTransport, signPayload } from "../../src/modules/leads/webhooks.service.js";
import { createFeedToken, revokeFeedToken } from "../../src/modules/leads/leadFeedTokens.service.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Leads out (Phase 6, 0064), on a throwaway account: an enquiry reaches the company's endpoint,
 * signed, and is retried when the endpoint fails; the lead feed gives the history and then only
 * what changed, as JSON, XML or CSV, behind an API key or a read-only address; leads that arrive
 * after a category is taken away are not sent. The network is stood in for.
 */

const PASSWORD = "LivFinder!2026";
const visitor = `qa-lead-out-${Date.now()}@example.com`;
let owner = null;
let accountId = null;
let listing = null;
let webhook = null;
const sent = [];
let answer = 200;

setWebhookTransport(async (url, options) => {
  sent.push({ url, headers: options.headers, body: options.body });
  return new Response(answer === 200 ? "ok" : "nope", { status: answer });
});

async function enquire(message = "Is this car still available to view?") {
  const response = await client().send("post", "/v1/inquiries", {
    listingId: listing.public_id,
    name: "QA Lead Visitor",
    email: visitor,
    message,
    inquiryType: "viewing",
  });
  expect(response.status, JSON.stringify(response.body)).toBe(201);
  return response.body.data;
}

beforeAll(async () => {
  owner = await createDisposablePortalOwner({ prefix: "lead-out", password: PASSWORD });
  ({ account_id: accountId } = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [owner.id]));
  await execute("UPDATE accounts SET listing_quota = NULL, storage_quota = NULL WHERE id = ?", [accountId]);
  await execute(
    `INSERT INTO account_category_access (account_id, category_id, status, listing_used, requested_at, created_at)
     VALUES (?, 2, 'approved', 0, NOW(3), NOW(3)) ON DUPLICATE KEY UPDATE status = 'approved', reviewed_at = NULL`,
    [accountId]
  );
  await execute(
    `INSERT INTO account_addons (public_id, account_id, addon_code, status, started_at)
     VALUES (?, ?, 'integrations', 'active', NOW(3)) ON DUPLICATE KEY UPDATE status = 'active'`,
    [`01QALEAD${String(Date.now()).slice(-10)}${accountId}`.slice(0, 26).padEnd(26, "0"), accountId]
  );
  const city = await queryOne("SELECT id FROM locations WHERE level = 'city' AND status = 'active' LIMIT 1");
  const payload = createListingSchema.parse({
    category: "cars", categorySlug: "supercars", purpose: "sale", title: `QA lead out car ${Date.now()}`,
    price: 500000, currency: "AED", locationId: `city:${city.id}`, detail: { modelYear: 2023 }, status: "pending_review",
  });
  const created = await createListing({ payload, accountId, userId: owner.id, organizationId: null, agentId: null, ip: null });
  await changeListingStatus({ listing: await queryOne("SELECT * FROM listings WHERE public_id = ?", [created.publicId]), toStatus: "active", userId: null, byPlatform: true });
  listing = await queryOne("SELECT * FROM listings WHERE public_id = ?", [created.publicId]);
  webhook = await createWebhook({ accountId, name: "QA CRM", url: "https://example.com/livfinder-webhook", events: ["lead.created", "lead.updated"], userId: owner.id });
});

afterAll(async () => {
  setWebhookTransport(null);
  await execute("DELETE FROM webhooks WHERE account_id = ?", [accountId]);
  await execute("DELETE FROM crm_contacts WHERE primary_email_normalized = ?", [visitor]);
  if (listing) await cleanupListings([listing.public_id]);
  if (owner) await cleanupUsers([owner.email]);
  await closePool();
});

describe("webhooks", () => {
  it("sends a new enquiry to the company's endpoint, signed with its secret", async () => {
    const inquiry = await enquire();
    const delivery = await queryOne("SELECT d.id, d.event_type, d.payload FROM webhook_deliveries d JOIN webhooks w ON w.id = d.webhook_id WHERE w.public_id = ? ORDER BY d.id DESC LIMIT 1", [webhook.id]);
    expect(delivery.event_type).toBe("lead.created");

    const [result] = await deliverDue({ deliveryIds: [delivery.id] });
    expect(result).toMatchObject({ delivered: true, status: 200 });
    const request_ = sent.at(-1);
    const body = JSON.parse(request_.body);
    expect(body).toMatchObject({ type: "lead.created", data: { lead: { type: "enquiry", contact: { email: visitor }, listing: { id: listing.public_id }, spam: false } } });
    expect(body.data.lead.reference).toBe(inquiry.reference);

    // The receiver's check: recompute the signature from the raw body and the secret.
    const [, t, v1] = /^t=(\d+),v1=([0-9a-f]{64})$/.exec(request_.headers["LivFinder-Signature"]);
    expect(signPayload(webhook.secret, request_.body, Number(t))).toBe(`t=${t},v1=${v1}`);
    expect(request_.headers["LivFinder-Event-Id"]).toBe(body.id);
  });

  it("retries a delivery the endpoint refused, and marks the endpoint failing", async () => {
    answer = 500;
    await enquire("Second question about this car, please.");
    const delivery = await queryOne("SELECT d.id FROM webhook_deliveries d JOIN webhooks w ON w.id = d.webhook_id WHERE w.public_id = ? ORDER BY d.id DESC LIMIT 1", [webhook.id]);
    const [result] = await deliverDue({ deliveryIds: [delivery.id] });
    expect(result).toMatchObject({ delivered: false, status: 500, willRetry: true });
    const after = await queryOne("SELECT status, attempts, next_retry_at FROM webhook_deliveries WHERE id = ?", [delivery.id]);
    expect(after).toMatchObject({ status: "pending", attempts: 1 });
    expect(new Date(after.next_retry_at).getTime()).toBeGreaterThan(Date.now() + 30_000);
    expect((await queryOne("SELECT status FROM webhooks WHERE public_id = ?", [webhook.id])).status).toBe("failing");
    answer = 200;
  });

  it("sends nothing while the Integrations add-on is off", async () => {
    await execute("UPDATE account_addons SET status = 'cancelled' WHERE account_id = ?", [accountId]);
    try {
      const before = await queryOne("SELECT COUNT(*) AS n FROM webhook_deliveries d JOIN webhooks w ON w.id = d.webhook_id WHERE w.public_id = ?", [webhook.id]);
      await enquire("A question while the add-on is off.");
      const after = await queryOne("SELECT COUNT(*) AS n FROM webhook_deliveries d JOIN webhooks w ON w.id = d.webhook_id WHERE w.public_id = ?", [webhook.id]);
      expect(Number(after.n)).toBe(Number(before.n));
    } finally {
      await execute("UPDATE account_addons SET status = 'active' WHERE account_id = ?", [accountId]);
    }
  });
});

describe("the lead feed", () => {
  let cursor = null;

  it("gives the full history, then only what changed", async () => {
    const first = await listLeadsSince({ accountId });
    expect(first.leads.length).toBe(3);
    expect(first.hasMore).toBe(false);
    cursor = first.nextCursor;
    expect((await listLeadsSince({ accountId, cursor })).leads).toEqual([]);

    const [one] = await query("SELECT id FROM inquiries WHERE account_id = ? ORDER BY id LIMIT 1", [accountId]);
    await execute("UPDATE inquiries SET status = 'contacted' WHERE id = ?", [one.id]);
    const changed = await listLeadsSince({ accountId, cursor });
    expect(changed.leads.map((lead) => lead.status)).toEqual(["contacted"]);
  });

  it("is readable at a read-only address as XML and CSV, until the address is revoked", async () => {
    const token = await createFeedToken({ accountId, name: "QA CRM import" });
    const xml = await request(app).get(`/v1/lead-feeds/${token.token}.xml`);
    expect(xml.status).toBe(200);
    expect(xml.text).toContain("<livfinder-leads");
    expect(xml.text).toContain(visitor);
    const csv = await request(app).get(`/v1/lead-feeds/${token.token}.csv`);
    expect(csv.status).toBe(200);
    expect(csv.text.split("\r\n")[0]).toMatch(/^id,type,reference,status,spam/);
    expect(csv.headers["x-next-cursor"]).toBeTruthy();

    await revokeFeedToken({ accountId, publicId: token.id });
    expect((await request(app).get(`/v1/lead-feeds/${token.token}.xml`)).status).toBe(404);
    expect((await request(app).get("/v1/lead-feeds/lft_not-a-real-token-at-all-000000.xml")).status).toBe(404);
  });

  it("downloads as CSV from the portal", async () => {
    const portal = client();
    await portal.login(owner.email, PASSWORD);
    const response = await portal.get("/v1/portal/leads/export.csv");
    expect(response.status, response.text).toBe(200);
    expect(response.headers["content-disposition"]).toMatch(/livfinder-leads/);
    expect(response.text.trim().split("\r\n")).toHaveLength(4);
  });

  it("keeps old leads after a category is taken away, but does not send new ones", async () => {
    await execute(
      `UPDATE account_category_access SET status = 'revoked', reviewed_at = NOW(3) WHERE account_id = ? AND category_id = 2`,
      [accountId]
    );
    await new Promise((resolve) => setTimeout(resolve, 20));
    const deliveriesBefore = await queryOne("SELECT COUNT(*) AS n FROM webhook_deliveries d JOIN webhooks w ON w.id = d.webhook_id WHERE w.public_id = ?", [webhook.id]);
    await enquire("A question after the category was removed.");
    const deliveriesAfter = await queryOne("SELECT COUNT(*) AS n FROM webhook_deliveries d JOIN webhooks w ON w.id = d.webhook_id WHERE w.public_id = ?", [webhook.id]);
    expect(Number(deliveriesAfter.n)).toBe(Number(deliveriesBefore.n));
    const all = await listLeadsSince({ accountId });
    expect(all.leads.length).toBe(3);
  });
});
