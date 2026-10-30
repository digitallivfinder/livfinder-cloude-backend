import request from "supertest";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  adminEmail,
  app,
  cleanupListings,
  cleanupUsers,
  client,
  createDisposablePortalOwner,
  createTestApiKey,
  ensureTestPassword,
  execute,
  pushFile,
  query,
  queryOne,
} from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { clearSentMessages, sentMessages } from "../../src/modules/system/mail.service.js";
import { sampleAllXml } from "../../src/modules/feeds/feedTemplates.js";
import { completeCsv, completeRecord, completeXml, useFakeImages } from "../helpers/completeListing.js";

/**
 * Every way a client can send a listing, right and wrong, on a throwaway individual account
 * approved for the six listing categories (and a second one approved for real estate only).
 */

const suffix = Date.now();
const CATEGORIES = ["real-estate", "cars", "yachts", "jets", "helicopters", "watches"];
const ROOTS = { "real-estate": 1, cars: 2, yachts: 3, jets: 4, helicopters: 5, watches: 6 };
const owners = [];
const accounts = [];
let key;
let narrowKey;
let n = 0;
const id = (label) => `M${(n += 1)}-${label}-${suffix}`;

const put = (externalId, record, usingKey = key) =>
  request(app).put(`/v1/partner/listings/${externalId}`).auth(usingKey.clientId, usingKey.secret).send({ ...record, externalId });
const get = (path, usingKey = key) => request(app).get(`/v1/partner${path}`).auth(usingKey.clientId, usingKey.secret);
const house = (externalId, overrides = {}) => completeRecord("real-estate", externalId, overrides);
const car = (externalId, overrides = {}) => completeRecord("cars", externalId, overrides);

async function makeAccount(prefix, roots) {
  const owner = await createDisposablePortalOwner({ prefix });
  const { account_id: accountId } = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [owner.id]);
  await execute("UPDATE accounts SET listing_quota = NULL, storage_quota = NULL WHERE id = ?", [accountId]);
  for (const root of roots) {
    await execute(
      `INSERT INTO account_category_access (account_id, category_id, status, listing_used, requested_at, created_at)
       VALUES (?, ?, 'approved', 0, NOW(3), NOW(3)) ON DUPLICATE KEY UPDATE status = 'approved'`,
      [accountId, root]
    );
  }
  await execute(
    `INSERT INTO account_addons (public_id, account_id, addon_code, status, started_at)
     VALUES (?, ?, 'integrations', 'active', NOW(3)) ON DUPLICATE KEY UPDATE status = 'active'`,
    [`01QAMTX${String(suffix).slice(-9)}${accountId}`.slice(0, 26).padEnd(26, "0"), accountId]
  );
  owners.push(owner);
  accounts.push(accountId);
  return { accountId, owner, key: await createTestApiKey({ accountId, userId: owner.id, scopes: ["listings:write", "leads:read"] }) };
}

beforeAll(async () => {
  useFakeImages();
  await ensureTestPassword();
  ({ key } = await makeAccount("push-matrix", Object.values(ROOTS)));
  ({ key: narrowKey } = await makeAccount("push-narrow", [1]));
});

afterAll(async () => {
  for (const accountId of accounts) {
    const listings = await query("SELECT public_id FROM listings WHERE account_id = ?", [accountId]);
    await cleanupListings(listings.map((row) => row.public_id));
    await execute("DELETE FROM integration_connections WHERE account_id = ? AND organization_id IS NULL", [accountId]);
    await execute("DELETE FROM api_clients WHERE account_id = ?", [accountId]);
  }
  await execute("DELETE FROM category_features WHERE feature_id IN (SELECT id FROM features WHERE name LIKE ?)", [`%QA%${suffix}%`]);
  await execute("DELETE FROM features WHERE name LIKE ?", [`%QA%${suffix}%`]);
  await execute("DELETE FROM notifications WHERE type = 'listing_import.failed_items' AND user_id IN (?, ?)", owners.map((owner) => owner.id));
  await cleanupUsers(owners.map((owner) => owner.email));
  await closePool();
});

describe("a complete listing in every category", () => {
  it.each(CATEGORIES)("%s comes in by JSON", async (category) => {
    const externalId = id(category);
    const response = await put(externalId, completeRecord(category, externalId));
    expect(response.status, JSON.stringify(response.body.error)).toBe(201);
  });

  it.each(CATEGORIES)("%s comes in by CSV and shows on its link", async (category) => {
    const externalId = id(`csv-${category}`);
    const pushed = await pushFile(key, `/listings/${category}.csv`, completeCsv(category, [completeRecord(category, externalId)]), "text/csv");
    expect(pushed.imports[0], JSON.stringify(pushed.imports[0].rejected)).toMatchObject({ accepted: 1, status: "completed" });
    expect((await get(`/listings/${category}.csv`)).text).toContain(externalId);
  });

  it("all six come in together in one XML file, each in its section", async () => {
    const ids = {};
    const sections = CATEGORIES.map((category) => {
      ids[category] = id(`xml-${category}`);
      return completeXml(category, [completeRecord(category, ids[category])]).split("\n").slice(2, -2).join("\n");
    }).join("\n");
    const pushed = await pushFile(key, "/listings.xml", `<livfinder-feed version="1">\n${sections}\n</livfinder-feed>`);
    expect(pushed.imports.map((entry) => [entry.category, entry.status])).toEqual(CATEGORIES.map((category) => [category, "completed"]));
    const xml = (await get("/listings.xml")).text;
    for (const category of CATEGORIES) expect(xml).toContain(ids[category]);
  });

  it("reads back the same, and pushing it again changes nothing", async () => {
    const file = (await get("/listings.xml")).text;
    const pushed = await pushFile(key, "/listings.xml", file);
    expect(pushed.imports.every((entry) => entry.status === "completed" && !entry.rejected.length)).toBe(true);
    const ids = pushed.imports.map((entry) => entry.id);
    const counts = await query(
      `SELECT i.operation FROM feed_import_items i JOIN feed_imports r ON r.id = i.import_id
        WHERE r.public_id IN (${ids.map(() => "?").join(", ")}) GROUP BY i.operation`,
      ids
    );
    expect(counts.map((row) => row.operation)).toEqual(["unchanged"]);
  });

  it("the published all-categories sample is valid, apart from developments on an individual", async () => {
    const pushed = await pushFile(key, "/listings.xml", sampleAllXml().replaceAll("ABC-1001", id("sample")));
    const listings = pushed.imports.filter((entry) => entry.category !== "developments");
    expect(listings.map((entry) => entry.rejected)).toEqual(listings.map(() => []));
    expect(listings.every((entry) => entry.status === "partial" || entry.status === "completed" || entry.status === "failed")).toBe(true);
  });
});

describe("what applies only sometimes", () => {
  const ok = async (externalId, record) => {
    const response = await put(externalId, record);
    expect(response.status, JSON.stringify(response.body.error)).toBe(201);
  };
  const refused = async (externalId, record, field, pattern = /./) => {
    const response = await put(externalId, record);
    expect(response.status).toBe(422);
    expect(response.body.error.fields[field], JSON.stringify(response.body.error.fields)).toMatch(pattern);
  };

  it("price on request needs no price or currency", async () => {
    const externalId = id("on-request");
    const { price, ...rest } = house(externalId);
    await ok(externalId, { ...rest, priceType: "on_request", currency: undefined });
  });

  it("a rental needs its rent terms", async () => {
    const externalId = id("rent");
    await refused(externalId, house(externalId, { purpose: "rent" }), "rentPeriod");
  });

  it("a property not ready needs a handover date, and a bad date is a clear refusal", async () => {
    const externalId = id("handover");
    const base = house(externalId);
    await refused(externalId, { ...base, detail: { ...base.detail, completionStatus: "under_construction", handoverDate: undefined } }, "handoverDate");
    await refused(externalId, { ...base, detail: { ...base.detail, completionStatus: "under_construction", handoverDate: "next year" } }, "handoverDate", /date/);
  });

  it("an electric car needs no engine size or cylinders", async () => {
    const externalId = id("electric");
    const base = car(externalId);
    const { engineSizeCc, cylinders, ...detail } = base.detail;
    await ok(externalId, { ...base, detail: { ...detail, fuelType: "electric" } });
  });

  it("a petrol car does", async () => {
    const externalId = id("petrol");
    const base = car(externalId);
    const { engineSizeCc, ...detail } = base.detail;
    await refused(externalId, { ...base, detail }, "engineSizeCc");
  });

  it("built area is fine in either unit, but not in neither", async () => {
    const externalId = id("area");
    const base = house(externalId);
    const { builtAreaSqft, ...detail } = base.detail;
    await refused(externalId, { ...base, detail }, "builtAreaSqft", /builtAreaSqm/);
    await ok(externalId, { ...base, detail: { ...detail, builtAreaSqm: 200 } });
  });

  it("latitude and longitude: both, neither, but not one or out of range", async () => {
    const one = id("lat");
    await refused(one, house(one, { latitude: 25.1 }), "longitude", /both/);
    const range = id("range");
    expect((await put(range, house(range, { latitude: 125.1, longitude: 55.1 }))).status).toBe(422);
    const both = id("both");
    await ok(both, house(both, { latitude: 25.1, longitude: 55.1 }));
  });
});

describe("images", () => {
  const urls = (externalId, count) => Array.from({ length: count }, (_, index) => `https://images.example/${externalId}/${index}.jpg`);

  it("two are not enough", async () => {
    const externalId = id("two");
    const response = await put(externalId, house(externalId, { images: urls(externalId, 2) }));
    expect(response.body.error.fields.images).toMatch(/this has 2/);
  });

  it("the same picture three times counts once", async () => {
    const externalId = id("same");
    const link = "https://images.example/one.jpg";
    const response = await put(externalId, house(externalId, { images: [link, link, link] }));
    expect(response.body.error.fields.images).toMatch(/this has 1/);
  });

  it("more than the limit is refused", async () => {
    const externalId = id("many");
    expect((await put(externalId, house(externalId, { images: urls(externalId, 31) }))).status).toBe(422);
  });
});

describe("amenities", () => {
  it("none is refused", async () => {
    const externalId = id("no-amenity");
    const response = await put(externalId, house(externalId, { features: [] }));
    expect(response.body.error.fields.features).toBeTruthy();
  });

  it("a new one is added once, whatever its case", async () => {
    const name = `QA sky deck ${suffix}`;
    for (const [label, value] of [["a", name], ["b", name.toUpperCase()]]) {
      const externalId = id(`amenity-${label}`);
      expect((await put(externalId, house(externalId, { features: [value] }))).status).toBe(201);
    }
    const rows = await query("SELECT id FROM features WHERE name = ?", [name]);
    expect(rows).toHaveLength(1);
  });

  it("is not added when the listing is rejected", async () => {
    const name = `QA rejected deck ${suffix}`;
    const externalId = id("amenity-rejected");
    await put(externalId, house(externalId, { features: [name], images: ["https://images.example/broken/1.jpg", "https://images.example/broken/2.jpg", "https://images.example/broken/3.jpg"] }));
    expect(await query("SELECT id FROM features WHERE name = ?", [name])).toHaveLength(0);
  });
});

describe("updating", () => {
  it("an incomplete update is refused and leaves the listing as it was", async () => {
    const externalId = id("update");
    await put(externalId, house(externalId, { title: "Original complete title" }));
    const response = await put(externalId, { category: "real-estate", title: "Thin new title" });
    expect(response.status).toBe(422);
    const row = await queryOne("SELECT title FROM listings WHERE source_reference = ?", [externalId]);
    expect(row.title).toBe("Original complete title");
  });

  it("a listing cannot move category", async () => {
    const externalId = id("move");
    await put(externalId, house(externalId));
    const response = await put(externalId, car(externalId));
    expect(response.status).toBe(422);
    expect(response.body.error.fields.category).toBeTruthy();
  });

  it("withdrawing an id nobody sent is reported, not ignored", async () => {
    const pushed = await pushFile(key, "/listings.xml", `<livfinder-feed version="1"><category name="cars"><listing><externalId>${id("ghost")}</externalId><status>withdrawn</status></listing></category></livfinder-feed>`);
    expect(pushed.imports[0].status).toBe("failed");
  });

  it("a withdrawn listing can be sent again", async () => {
    const externalId = id("back");
    await put(externalId, house(externalId, { status: "pending_review" }));
    await pushFile(key, "/listings.xml", `<livfinder-feed version="1"><category name="real-estate"><listing><externalId>${externalId}</externalId><status>withdrawn</status></listing></category></livfinder-feed>`);
    expect((await queryOne("SELECT status FROM listings WHERE source_reference = ?", [externalId])).status).toBe("withdrawn");
    const response = await put(externalId, house(externalId, { title: "Back again after a withdrawal" }));
    expect(response.status, JSON.stringify(response.body.error)).toBe(200);
  });
});

describe("files", () => {
  const push = (body, path = "/listings.xml", type = "application/xml") => pushFile(key, path, body, type);

  it("refuses an empty body", async () => {
    expect((await push("")).status).toBe(400);
  });

  it("refuses JSON sent to the XML link", async () => {
    const response = await request(app).post("/v1/partner/listings.xml").auth(key.clientId, key.secret).send({ hello: "world" });
    expect(response.status).toBe(400);
  });

  it("refuses an unknown category, a repeated one and a wrong version", async () => {
    expect((await push('<livfinder-feed version="1"><category name="boats"><listing/></category></livfinder-feed>')).status).toBe(422);
    expect((await push('<livfinder-feed version="1"><category name="cars"/><category name="cars"/></livfinder-feed>')).status).toBe(422);
    expect((await push('<livfinder-feed version="1"><category name="cars" version="9"/></livfinder-feed>')).status).toBe(422);
  });

  it("refuses a CSV with no id column", async () => {
    expect((await push("title,price\nA car title,100\n", "/listings/cars.csv", "text/csv")).status).toBe(422);
  });

  it("has no link for an unknown category", async () => {
    expect((await request(app).post("/v1/partner/listings/boats.csv").auth(key.clientId, key.secret).set("Content-Type", "text/csv").send("x")).status).toBeGreaterThanOrEqual(400);
  });

  it("rejects the second of two entries with the same id, by row", async () => {
    const externalId = id("twice");
    const pushed = await push(completeXml("cars", [car(externalId), car(externalId)]));
    expect(pushed.imports[0]).toMatchObject({ total: 2, accepted: 1 });
    expect(pushed.imports[0].rejected[0].errors.externalId).toMatch(/also on row 1/);
  });

  it("keeps Arabic text and characters XML has to escape", async () => {
    const externalId = id("text");
    const title = 'شقة & "sea view" <penthouse> at Bay';
    const pushed = await push(completeXml("cars", [car(externalId, { title })]));
    expect(pushed.imports[0], JSON.stringify(pushed.imports[0].rejected)).toMatchObject({ status: "completed" });
    expect((await queryOne("SELECT title FROM listings WHERE source_reference = ?", [externalId])).title).toBe(title);
    expect((await get("/listings.xml")).text).toContain("&amp; &quot;sea view&quot; &lt;penthouse&gt;");
  });

  it("reads a CSV with a byte order mark, commas and quotes in a value", async () => {
    const externalId = id("bom");
    const csv = `﻿${completeCsv("cars", [car(externalId, { title: 'Coupe, "rare" edition' })])}`;
    const pushed = await push(csv, "/listings/cars.csv", "text/csv");
    expect(pushed.imports[0], JSON.stringify(pushed.imports[0].rejected)).toMatchObject({ status: "completed" });
    expect((await queryOne("SELECT title FROM listings WHERE source_reference = ?", [externalId])).title).toBe('Coupe, "rare" edition');
  });

  it("sends a CSV of another category to its rejection, not into the wrong category", async () => {
    const externalId = id("wrong-file");
    const pushed = await push(completeCsv("real-estate", [house(externalId)]), "/listings/cars.csv", "text/csv");
    expect(pushed.imports[0].accepted).toBe(0);
    expect(await queryOne("SELECT id FROM listings WHERE source_reference = ?", [externalId])).toBeNull();
  });
});

describe("access", () => {
  it("refuses a category the account is not approved for, per entry", async () => {
    const externalId = id("unapproved");
    const pushed = await pushFile(narrowKey, "/listings.xml", completeXml("cars", [car(externalId)]));
    expect(pushed.imports[0].status).toBe("failed");
    const item = await queryOne("SELECT error_message FROM feed_import_items WHERE external_id = ?", [externalId]);
    expect(item.error_message).toMatch(/not approved/);
  });

  it("a development needs a company", async () => {
    const pushed = await pushFile(key, "/listings.xml", sampleAllXml().replaceAll("ABC-1001", id("dev")));
    const developments = pushed.imports.find((entry) => entry.category === "developments");
    expect(developments.status).toBe("failed");
  });

  it("a key without listing scopes cannot read the link", async () => {
    const leadsOnly = await createTestApiKey({ accountId: accounts[0], userId: owners[0].id, scopes: ["leads:read"] });
    expect((await get("/listings.xml", leadsOnly)).status).toBe(403);
  });

  it("a revoked key stops working", async () => {
    const short = await createTestApiKey({ accountId: accounts[0], userId: owners[0].id });
    await execute("UPDATE api_clients SET status = 'revoked' WHERE client_id = ?", [short.clientId]);
    expect((await get("/listings.xml", short)).status).toBe(401);
  });

  it("with the add-on off the link is closed", async () => {
    await execute("UPDATE account_addons SET status = 'cancelled' WHERE account_id = ? AND addon_code = 'integrations'", [accounts[1]]);
    const response = await get("/listings.xml", narrowKey);
    await execute("UPDATE account_addons SET status = 'active' WHERE account_id = ? AND addon_code = 'integrations'", [accounts[1]]);
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe("ADDON_INACTIVE");
  });
});

describe("rejection notices", () => {
  it("a JSON batch tells the client too, naming the listing and its reasons", async () => {
    clearSentMessages();
    const externalId = id("batch");
    const response = await request(app)
      .post("/v1/partner/imports")
      .auth(key.clientId, key.secret)
      .send({ listings: [{ externalId, category: "cars", title: "Thin batch car" }] });
    expect(response.status).toBe(202);
    let mail;
    for (let attempt = 0; attempt < 100 && !mail; attempt += 1) {
      mail = sentMessages().find((message) => message.text?.includes(externalId));
      if (!mail) await new Promise((resolve) => setTimeout(resolve, 50));
    }
    expect(mail.to).toBe(owners[0].email);
    expect(mail.html).toContain(externalId);
  });

  it("escapes what a client sent, in the email's HTML", async () => {
    clearSentMessages();
    const externalId = id("html");
    await pushFile(key, "/listings/cars.csv", `externalId,title\r\n${externalId},<script>alert(1)</script> car\r\n`, "text/csv");
    let mail;
    for (let attempt = 0; attempt < 100 && !mail; attempt += 1) {
      mail = sentMessages().find((message) => message.text?.includes(externalId));
      if (!mail) await new Promise((resolve) => setTimeout(resolve, 50));
    }
    expect(mail.html).not.toContain("<script>");
  });
});

describe("a shallow location, once approved", () => {
  let admin;

  beforeAll(async () => {
    admin = client();
    await admin.login(await adminEmail());
  });

  const approveAndOpen = async (externalId, location) => {
    const pushed = await put(externalId, house(externalId, { location, status: "pending_review" }));
    expect(pushed.status, JSON.stringify(pushed.body.error)).toBe(201);
    const listing = await queryOne("SELECT public_id FROM listings WHERE source_reference = ?", [externalId]);
    const approve = await admin.send("patch", `/v1/admin/listings/${listing.public_id}/moderation`, { decision: "approve" });
    expect(approve.status, JSON.stringify(approve.body)).toBe(200);
    return client().get(`/v1/public/listings/${listing.public_id}`);
  };

  it("a country with no cities has a public page", async () => {
    const country = await queryOne(
      `SELECT c.name FROM locations c WHERE c.level = 'country' AND c.deleted_at IS NULL AND c.status = 'active'
         AND NOT EXISTS (SELECT 1 FROM locations x WHERE x.country_id = c.id AND x.level IN ('city', 'state') AND x.deleted_at IS NULL) LIMIT 1`
    );
    const page = await approveAndOpen(id("public-country"), { country: country.name });
    expect(page.status, JSON.stringify(page.body)).toBe(200);
    expect(page.body.data.canonicalUrl ?? page.body.data.url ?? page.body.data.canonicalPath, JSON.stringify(Object.keys(page.body.data))).toBeTruthy();
  });

  it("a state with no cities has a public page", async () => {
    const state = await queryOne(
      `SELECT s.id FROM locations s WHERE s.level = 'state' AND s.deleted_at IS NULL AND s.status = 'active'
         AND NOT EXISTS (SELECT 1 FROM locations x WHERE x.state_id = s.id AND x.level = 'city' AND x.deleted_at IS NULL) LIMIT 1`
    );
    const page = await approveAndOpen(id("public-state"), { id: String(state.id) });
    expect(page.status, JSON.stringify(page.body)).toBe(200);
  });
});
