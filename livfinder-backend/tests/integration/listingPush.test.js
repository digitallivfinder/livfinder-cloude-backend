import request from "supertest";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  app,
  cleanupListings,
  client,
  cleanupUsers,
  createDisposablePortalOwner,
  createTestApiKey,
  execute,
  pushFile,
  query,
  queryOne,
} from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { clearSentMessages, sentMessages } from "../../src/modules/system/mail.service.js";
import { completeCsv, completeRecord, completeXml, useFakeImages } from "../helpers/completeListing.js";

/**
 * Scenario 2: a client's own XML and CSV links. Pushes go to the link with the client's ID and
 * secret, and the same link reads back what that client pushed, each category in its own section.
 * Runs on two throwaway individual accounts, so it covers an individual's key too.
 */

const suffix = Date.now();
const owners = [];
const accounts = [];
const keys = [];

const car = (id, title) => completeRecord("cars", id, { title });
const carsFile = (...entries) => completeXml("cars", entries);
const withdrawn = (id) => `<livfinder-feed version="1"><category name="cars"><listing><externalId>${id}</externalId><status>withdrawn</status></listing></category></livfinder-feed>`;

/** A draft as the portal saves it: a row with no push behind it. */
async function importPortalListing(accountId, userId, title) {
  const owner = await queryOne("SELECT email FROM users WHERE id = ?", [userId]);
  await execute(
    `INSERT INTO account_category_access (account_id, category_id, status, listing_used, requested_at, created_at)
     VALUES (?, 1, 'approved', 0, NOW(3), NOW(3)) ON DUPLICATE KEY UPDATE status = 'approved'`,
    [accountId]
  );
  const portal = client();
  await portal.login(owner.email);
  const response = await portal.send("post", "/v1/portal/listings", { category: "real-estate", title, status: "draft", locationId: "1231", price: 100000, currency: "AED", purpose: "sale" });
  expect(response.status, JSON.stringify(response.body)).toBe(201);
  return queryOne("SELECT reference FROM listings WHERE account_id = ? AND title = ?", [accountId, title]);
}

const read = (key, path) => request(app).get(`/v1/partner${path}`).auth(key.clientId, key.secret);

async function makeClient(index) {
  const owner = await createDisposablePortalOwner({ prefix: `listing-push-${index}` });
  const { account_id: accountId } = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [owner.id]);
  await execute("UPDATE accounts SET listing_quota = NULL, storage_quota = NULL WHERE id = ?", [accountId]);
  await execute(
    `INSERT INTO account_category_access (account_id, category_id, status, listing_used, requested_at, created_at)
     VALUES (?, 2, 'approved', 0, NOW(3), NOW(3)) ON DUPLICATE KEY UPDATE status = 'approved'`,
    [accountId]
  );
  await execute(
    `INSERT INTO account_addons (public_id, account_id, addon_code, status, started_at)
     VALUES (?, ?, 'integrations', 'active', NOW(3)) ON DUPLICATE KEY UPDATE status = 'active'`,
    [`01QAPUSH${String(suffix).slice(-10)}${accountId}`.slice(0, 26).padEnd(26, "0"), accountId]
  );
  owners.push(owner);
  accounts.push(accountId);
  const key = await createTestApiKey({ accountId, userId: owner.id });
  keys.push(key);
  return key;
}

let first;
let second;

beforeAll(async () => {
  useFakeImages();
  first = await makeClient(1);
  second = await makeClient(2);
});

afterAll(async () => {
  for (const accountId of accounts) {
    const listings = await query("SELECT public_id FROM listings WHERE account_id = ?", [accountId]);
    await cleanupListings(listings.map((item) => item.public_id));
    await execute("DELETE FROM integration_connections WHERE account_id = ? AND organization_id IS NULL", [accountId]);
    await execute("DELETE FROM api_clients WHERE account_id = ?", [accountId]);
  }
  await execute("DELETE FROM notifications WHERE type = 'listing_import.failed_items' AND user_id IN (?, ?)", owners.map((owner) => owner.id));
  await cleanupUsers(owners.map((owner) => owner.email));
  await closePool();
});

describe("opening a link", () => {
  it("asks for the client ID and secret, which is what makes a browser show its login box", async () => {
    const response = await request(app).get("/v1/partner/listings.xml");
    expect(response.status).toBe(401);
    expect(response.headers["www-authenticate"]).toContain("Basic");
  });

  it("refuses a wrong secret", async () => {
    const response = await request(app).get("/v1/partner/listings.xml").auth(first.clientId, "wrong");
    expect(response.status).toBe(401);
  });

  it("shows an approved category as an empty section before anything is pushed", async () => {
    const response = await read(first, "/listings.xml");
    expect(response.status).toBe(200);
    expect(response.headers["content-type"]).toContain("application/xml");
    expect(response.text).toContain('name="cars"');
    expect(response.text).toContain('count="0"');
  });
});

describe("a link that carries its own credentials", () => {
  const withKey = (path, key) => `/v1/partner${path}?client_id=${key.clientId}&secret=${encodeURIComponent(key.secret)}`;

  it("opens with no login", async () => {
    const response = await request(app).get(withKey("/listings.xml", first));
    expect(response.status).toBe(200);
    expect(response.headers["content-type"]).toContain("application/xml");
    expect(response.headers["www-authenticate"]).toBeUndefined();
  });

  it("takes a push too, on XML and CSV", async () => {
    const csv = await request(app).post(withKey("/listings/cars.csv", first)).set("Content-Type", "text/csv").send("externalId,title\r\nL1,Thin\r\n");
    expect(csv.status).toBe(202);
    const xml = await request(app).post(withKey("/listings.xml", first)).set("Content-Type", "application/xml").send("<broken");
    expect(xml.status).toBe(422);
  });

  it("falls back to the login box when the link has none, or a wrong one", async () => {
    const wrong = await request(app).get(`/v1/partner/listings.xml?client_id=${first.clientId}&secret=wrong`);
    expect(wrong.status).toBe(401);
    expect(wrong.headers["www-authenticate"]).toContain("Basic");
    const half = await request(app).get(`/v1/partner/listings.xml?client_id=${first.clientId}`);
    expect(half.status).toBe(401);
  });

  it("works only on the XML and CSV links", async () => {
    expect((await request(app).get(withKey("/me", first))).status).toBe(401);
    expect((await request(app).get(withKey("/listings", first))).status).toBe(401);
  });

  it("never writes the secret to the request log", async () => {
    await request(app).get(withKey("/listings.xml", first));
    await new Promise((resolve) => setTimeout(resolve, 300));
    const rows = await query("SELECT full_path FROM api_request_logs WHERE full_path LIKE ? ORDER BY id DESC LIMIT 5", [`%client_id=${first.clientId}%`]);
    expect(rows.length).toBeGreaterThan(0);
    for (const row of rows) expect(row.full_path).not.toContain("secret");
  });
});

describe("pushing a file", () => {
  it("adds the listings, unpublished, under the client's own account", async () => {
    const pushed = await pushFile(first, "/listings.xml", carsFile(car(`P1-${suffix}`, "First pushed car"), car(`P2-${suffix}`, "Second pushed car")));
    expect(pushed.status).toBe(202);
    expect(pushed.imports).toHaveLength(1);
    expect(pushed.imports[0]).toMatchObject({ category: "cars", total: 2, accepted: 2, status: "completed" });
    const listings = await query("SELECT status, source FROM listings WHERE account_id = ? AND deleted_at IS NULL", [accounts[0]]);
    expect(listings).toEqual([
      { status: "draft", source: "feed" },
      { status: "draft", source: "feed" },
    ]);
  });

  it("shows them back on the link, in their category, with their LivFinder status", async () => {
    const response = await read(first, "/listings.xml");
    expect(response.text).toContain("First pushed car");
    expect(response.text).toContain('livfinderStatus="draft"');
    expect(response.text).toContain('count="2"');
  });

  it("shows nothing of it to another client", async () => {
    const response = await read(second, "/listings.xml");
    expect(response.text).not.toContain("First pushed car");
  });

  it("leaves alone a listing missing from a later file", async () => {
    const pushed = await pushFile(first, "/listings.xml", carsFile(car(`P1-${suffix}`, "First pushed car, edited")));
    expect(pushed.imports[0].status).toBe("completed");
    const listings = await query("SELECT title FROM listings WHERE account_id = ? AND deleted_at IS NULL ORDER BY title", [accounts[0]]);
    expect(listings.map((row) => row.title)).toEqual(["First pushed car, edited", "Second pushed car"]);
  });

  it("can be sent straight back as it was read", async () => {
    const file = (await read(first, "/listings.xml")).text;
    const pushed = await pushFile(first, "/listings.xml", file);
    expect(pushed.status).toBe(202);
    expect(pushed.imports).toHaveLength(1);
    expect(pushed.imports[0]).toMatchObject({ total: 2, accepted: 2, status: "completed" });
  });

  it("takes a listing down only when told to", async () => {
    const pushed = await pushFile(first, "/listings.xml", withdrawn(`P2-${suffix}`));
    expect(pushed.imports[0]).toMatchObject({ accepted: 1, status: "completed" });
    const row = await queryOne("SELECT status FROM listings WHERE account_id = ? AND title = 'Second pushed car'", [accounts[0]]);
    expect(row.status).toBe("archived");
  });

  it("rejects an incomplete entry, keeps the good one, and tells the client exactly why", async () => {
    clearSentMessages();
    const thin = `<listing><externalId>P4-${suffix}</externalId><title>Thin car</title></listing>`;
    const body = carsFile(car(`P3-${suffix}`, "Third pushed car")).replace("</category>", `${thin}</category>`);
    const pushed = await pushFile(first, "/listings.xml", body);
    expect(pushed.imports[0]).toMatchObject({ total: 2, accepted: 1, status: "partial" });
    expect(pushed.imports[0].rejected[0].externalId).toBe(`P4-${suffix}`);
    expect(pushed.imports[0].rejected[0].errors.images).toMatch(/at least 3/);

    // The notice follows the import's final status, so it can land a moment after it.
    let notice = null;
    for (let attempt = 0; attempt < 100 && !notice; attempt += 1) {
      notice = await queryOne(
        "SELECT title, body FROM notifications WHERE user_id = ? AND type = 'listing_import.failed_items' ORDER BY id DESC LIMIT 1",
        [owners[0].id]
      );
      if (!sentMessages().some((message) => message.to === owners[0].email)) notice = null;
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    expect(notice.title).toBe("1 of 2 listings were rejected");
    expect(notice.body).toContain(`P4-${suffix}`);
    const mail = sentMessages().find((message) => message.to === owners[0].email);
    expect(mail.subject).toContain("rejected");
    expect(mail.text).toContain(`P4-${suffix}`);
    expect(mail.text).toContain("Thin car");
    expect(mail.text).toMatch(/images: Give at least 3/);
  });

  it("refuses a file that cannot be read", async () => {
    const pushed = await pushFile(first, "/listings.xml", "<livfinder-feed><oops");
    expect(pushed.status).toBe(422);
    expect(pushed.body.error.code).toBe("FEED_INVALID");
  });

  it("needs the write scope", async () => {
    const readOnly = await createTestApiKey({ accountId: accounts[0], userId: owners[0].id, scopes: ["listings:read"] });
    const pushed = await pushFile(readOnly, "/listings.xml", carsFile(car(`P5-${suffix}`, "Refused car")));
    expect(pushed.status).toBe(403);
  });
});

describe("the CSV link", () => {
  it("takes one category and shows it back", async () => {
    const csv = completeCsv("cars", [car(`C1-${suffix}`, "CSV pushed car")]);
    const pushed = await pushFile(second, "/listings/cars.csv", csv, "text/csv");
    expect(pushed.imports[0]).toMatchObject({ category: "cars", accepted: 1, status: "completed" });

    const response = await read(second, "/listings/cars.csv");
    expect(response.status).toBe(200);
    expect(response.headers["content-type"]).toContain("text/csv");
    expect(response.text).toContain("CSV pushed car");
    expect(response.text.split("\r\n")[0]).toContain("livfinderStatus");
  });

  it("opens as text in a browser, instead of downloading", async () => {
    const response = await read(second, "/listings/cars.csv").set("Accept", "text/html,application/xhtml+xml");
    expect(response.headers["content-type"]).toContain("text/plain");
  });
});

describe("listings made in the portal", () => {
  let reference;

  beforeAll(async () => {
    const created = await importPortalListing(accounts[1], owners[1].id, "Made by hand in the portal");
    reference = created.reference;
  });

  it("show on the link with the pushed ones, under their reference", async () => {
    const xml = (await read(second, "/listings.xml")).text;
    expect(xml).toContain("Made by hand in the portal");
    expect(xml).toContain(`<externalId>${reference}</externalId>`);
  });

  it("show in the CSV too, and not to another client", async () => {
    expect((await read(second, "/listings/real-estate.csv")).text).toContain("Made by hand in the portal");
    expect((await read(first, "/listings.xml")).text).not.toContain("Made by hand in the portal");
  });

  it("update when sent back, and never become a second copy", async () => {
    const before = await queryOne("SELECT COUNT(*) AS n FROM listings WHERE account_id = ? AND deleted_at IS NULL", [accounts[1]]);
    const pushed = await pushFile(second, "/listings.xml", completeXml("real-estate", [completeRecord("real-estate", reference, { title: "Updated from the client system" })]));
    expect(pushed.imports[0], JSON.stringify(pushed.imports[0])).toMatchObject({ accepted: 1, status: "completed" });
    const after = await queryOne("SELECT COUNT(*) AS n FROM listings WHERE account_id = ? AND deleted_at IS NULL", [accounts[1]]);
    expect(after.n).toBe(before.n);
    expect((await queryOne("SELECT title FROM listings WHERE reference = ?", [reference])).title).toBe("Updated from the client system");
  });
});

describe("the location files", () => {
  const file = (name) => request(app).get(`/v1/public/feed-formats/locations/${name}.csv`);

  it("gives each level its own file, with an id a client can send", async () => {
    const countries = await file("countries");
    expect(countries.status).toBe(200);
    expect(countries.headers["content-type"]).toContain("text/csv");
    expect(countries.headers["content-disposition"]).toContain("livfinder-countries.csv");
    const lines = countries.text.split("\r\n");
    expect(lines[0]).toBe("locationId,name");
    expect(lines.some((line) => /^\d+,United Arab Emirates$/.test(line))).toBe(true);
    expect(countries.text).not.toContain("Dubai Marina");
  });

  it("says where a sub-community sits, level by level", async () => {
    const response = await file("sub-communities");
    const lines = response.text.split("\r\n");
    expect(lines[0]).toBe("locationId,name,countryId,country,stateId,state,cityId,city,communityId,community");
    expect(lines.find((line) => line.includes(",Bay Central,"))).toContain("Dubai Marina");
  });

  it("has no file for a level that does not exist, and no country filter", async () => {
    expect((await file("planets")).status).toBe(404);
    expect((await request(app).get("/v1/public/feed-formats/locations.csv")).status).toBe(422);
  });
});

describe("the import results", () => {
  it("are readable with an individual's key", async () => {
    const response = await read(first, "/imports");
    expect(response.status).toBe(200);
    expect(response.body.data.length).toBeGreaterThan(0);
  });
});
