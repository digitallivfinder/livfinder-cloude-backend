import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, ensureTestPassword, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Client portal table header filters, through the real routes and the caller's account scope.
 *
 * Signs in as the owner of the company with the most bookings and offers, and checks each filter
 * returns exactly the rows a predicate picks out of the unfiltered list. Read-only.
 */
const PASSWORD = "LivFinder!2026";
const owner = client();

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  const row = await queryOne(
    `SELECT u.email FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN organizations o ON o.account_id = am.account_id
      ORDER BY (SELECT COUNT(*) FROM bookings b WHERE b.organization_id = o.id) + (SELECT COUNT(*) FROM offers f WHERE f.organization_id = o.id) DESC
      LIMIT 1`
  );
  const response = await owner.login(row.email, PASSWORD);
  expect(response.status, JSON.stringify(response.body).slice(0, 200)).toBe(200);
});

afterAll(async () => {
  await closePool();
});

const fold = (value) => String(value ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
const has = (needle) => (...values) => values.some((value) => fold(value).includes(fold(needle)));

/** Every row of a list (rows under `data`, or `history.data` / `billingHistory.data` for the money screens). */
async function all(path, params = {}) {
  const items = [];
  for (let page = 1; page < 50; page++) {
    const response = await owner.get(path, { ...params, page, pageSize: 100 });
    expect(response.status, `${path} ${JSON.stringify(params)} → ${JSON.stringify(response.body).slice(0, 300)}`).toBe(200);
    const body = response.body.data && !Array.isArray(response.body.data) ? response.body.data : response.body;
    const list = Array.isArray(body.data) ? body : body.history ?? body.billingHistory ?? body;
    const rows = list.data ?? [];
    items.push(...rows);
    const total = Number(list.pageInfo?.total ?? rows.length);
    if (!rows.length || items.length >= total) break;
  }
  return items;
}

async function expectFilter(path, base, filter, predicate) {
  const everything = await all(path, base);
  const filtered = await all(path, { ...base, ...filter });
  expect(filtered.filter((row) => !predicate(row)).map((row) => row.id), `${path} ${JSON.stringify(filter)}: rows that do not match`).toEqual([]);
  expect(filtered.map((row) => row.id).sort(), `${path} ${JSON.stringify(filter)}`).toEqual(everything.filter(predicate).map((row) => row.id).sort());
}

describe("portal header filters", () => {
  it("filters the listings table", async () => {
    const rows = await all("/v1/portal/listings");
    expect(rows.length).toBeGreaterThan(0);
    const agent = rows.find((row) => row.agentId)?.agentId;
    await expectFilter("/v1/portal/listings", {}, { title: "a" }, (row) => has("a")(row.title, row.reference, row.id));
    await expectFilter("/v1/portal/listings", {}, { statusIn: "active" }, (row) => row.status === "active");
    await expectFilter("/v1/portal/listings", {}, { inquiriesMin: "1" }, (row) => (row.metrics?.inquiries ?? 0) >= 1);
    if (agent) await expectFilter("/v1/portal/listings", {}, { agent }, (row) => row.agentId === agent);
  });

  it("filters enquiries, bookings and offers", async () => {
    const inquiries = await all("/v1/portal/inquiries");
    expect(inquiries.length).toBeGreaterThan(0);
    expect((await all("/v1/portal/bookings", { status: "all" })).length).toBeGreaterThan(0);
    expect((await all("/v1/portal/offers")).length).toBeGreaterThan(0);
    const statuses = [...new Set(inquiries.map((row) => row.status))].slice(0, 2);
    await expectFilter("/v1/portal/inquiries", {}, { statusIn: statuses.join(",") }, (row) => statuses.includes(row.status));
    await expectFilter("/v1/portal/inquiries", {}, { message: "the" }, (row) => has("the")(row.message));
    await expectFilter("/v1/portal/bookings", { status: "all" }, { client: "a" }, (row) => has("a")(row.client?.name, row.client?.email, row.client?.phone));
    await expectFilter("/v1/portal/offers", {}, { differenceMax: "-5" }, (row) => row.differencePercent <= -5);
  });

  it("filters the team, payments and invoices", async () => {
    for (const path of ["/v1/portal/organization/agents", "/v1/portal/payments", "/v1/portal/billing"]) expect((await all(path)).length, path).toBeGreaterThan(0);
    await expectFilter("/v1/portal/organization/agents", {}, { listingsMin: "1" }, (row) => row.listingCount >= 1);
    await expectFilter("/v1/portal/payments", {}, { statusIn: "succeeded" }, (row) => row.status === "succeeded");
    await expectFilter("/v1/portal/billing", {}, { statusIn: "paid" }, (row) => row.status === "paid");
    // Invoice # box: "LF-INV-" fixed, any part of the number matches.
    const invoices = await all("/v1/portal/billing");
    const tail = String(invoices[0].number).slice(-3);
    await expectFilter("/v1/portal/billing", {}, { invoiceNumber: tail }, (row) => String(row.number).slice(7).includes(tail));
  });

  it("serves the portal's option lists, and not admin-only ones", async () => {
    const response = await owner.get("/v1/portal/options", { sets: "offer.status,invoice.status,lead.funnelStep:jets,role,plan" });
    expect(response.status).toBe(200);
    const sets = response.body.data;
    expect(sets["offer.status"].some((option) => option.value === "draft")).toBe(false);
    expect(sets["invoice.status"].map((option) => option.value)).toContain("paid");
    expect(sets["lead.funnelStep:jets"].find((option) => option.value === "viewing").label).toBe("Inspection");
    expect(sets.role).toBeUndefined();
    expect(sets.plan).toBeUndefined();
    // Its own listings, searchable for the leads Related listing filter.
    const listings = (await owner.get("/v1/portal/lookup/listing", { types: "real-estate" })).body.data;
    expect(listings.length).toBeGreaterThan(0);
  });

  it("offers places and its own agents for the dropdowns", async () => {
    const places = (await owner.get("/v1/portal/lookup/location", { q: "marina" })).body.data;
    expect(places.find((option) => option.label === "Dubai Marina")?.description).toContain("United Arab Emirates");
    const agents = (await owner.get("/v1/portal/lookup/agent", {})).body.data;
    expect(agents.length).toBeGreaterThan(0);
    // Only this company's agents.
    const others = await queryOne(
      "SELECT COUNT(*) AS n FROM agents a WHERE a.public_id IN (?) AND a.organization_id <> (SELECT organization_id FROM agents WHERE public_id = ?)",
      [agents.map((option) => option.value), agents[0].value]
    );
    expect(Number(others.n)).toBe(0);
  });
});
