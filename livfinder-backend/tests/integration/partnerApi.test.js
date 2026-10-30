import { afterAll, beforeAll, describe, expect, it } from "vitest";
import request from "supertest";
import {
  app, client, cleanupListings, cleanupUsers, createDisposableStaffUser, execute, query, queryOne,
} from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { completeRecord, useFakeImages } from "../helpers/completeListing.js";
import { createApiClient } from "../../src/modules/portal/organization.service.js";
import { IMPORT_PROVIDER_CODE } from "../../src/modules/imports/importConnection.js";

/**
 * The partner listing API, end to end against the real database.
 *
 * Uses a real seeded company that is approved for Real Estate, with throwaway API keys, a
 * throwaway portal member and a throwaway admin. Everything the run creates — listings, keys,
 * imports, connection, request logs, notifications, idempotency keys — is removed afterwards.
 * The shared `cleanupUsers` deletes every account a user belongs to, so the member is detached
 * from the real company before it is called.
 */

const PASSWORD = "LivFinder!2026";
const suffix = `${Date.now()}`;
const ext = (name) => `QA-${suffix}-${name}`;

let company = null;
let otherCompany = null;
let writeKey = null;
let readKey = null;
let ipLockedKey = null;
let revokedKey = null;
let otherKey = null;
let location = null;
let agent = null;
let unapprovedCategory = null;
let member = null;
let staff = null;
const portal = client();
const admin = client();
const keyIds = [];
const createdListingIds = new Set();
// The add-on rows as they were before the run, so afterAll puts them back exactly.
const addonBefore = new Map();

const basic = (key) => `Basic ${Buffer.from(`${key.clientId}:${key.secret}`).toString("base64")}`;
const as = (key) => ({
  get: (path) => request(app).get(path).set("Authorization", basic(key)),
  put: (path, body) => request(app).put(path).set("Authorization", basic(key)).send(body),
  post: (path, body) => request(app).post(path).set("Authorization", basic(key)).send(body),
  delete: (path) => request(app).delete(path).set("Authorization", basic(key)),
});

function listing(externalId, overrides = {}) {
  return completeRecord("real-estate", externalId, {
    title: `QA import ${externalId}`,
    agentEmail: agent?.email,
    ...overrides,
  });
}

async function makeKey(organizationId, scopes, extra = {}) {
  const { account_id: accountId } = await queryOne("SELECT account_id FROM organizations WHERE id = ?", [organizationId]);
  const key = await createApiClient({ accountId, organizationId, name: `QA key ${suffix}`, scopes, userId: null, ...extra });
  const row = await queryOne("SELECT id FROM api_clients WHERE public_id = ?", [key.id]);
  keyIds.push(row.id);
  return { ...key, rowId: row.id };
}

async function waitForImport(key, importId) {
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const response = await as(key).get(`/v1/partner/imports/${importId}`);
    if (!["queued", "running"].includes(response.body.data.status)) return response.body.data;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  throw new Error("bulk import did not finish");
}

beforeAll(async () => {
  const provider = await queryOne("SELECT id FROM integration_providers WHERE code = ?", [IMPORT_PROVIDER_CODE]);
  if (!provider) throw new Error("migration 0058 has not been applied to this database");

  const companies = await query(
    `SELECT o.id AS organization_id, o.account_id, o.public_id, o.name
       FROM organizations o
       JOIN accounts a ON a.id = o.account_id AND a.status = 'active'
       JOIN account_category_access aca ON aca.account_id = a.id AND aca.status = 'approved'
       JOIN categories c ON c.id = aca.category_id AND COALESCE(c.root_category_id, c.id) = 1
      WHERE o.status = 'active' AND o.deleted_at IS NULL
        AND (a.listing_quota IS NULL OR a.listing_used + 10 < a.listing_quota)
        AND (a.storage_quota IS NULL OR a.storage_used + 10 < a.storage_quota)
      GROUP BY o.id ORDER BY o.id LIMIT 2`
  );
  [company, otherCompany] = companies;
  if (!company || !otherCompany) throw new Error("need two active companies approved for Real Estate with free listing slots");

  // The listing API is part of the Integrations add-on (0059).
  for (const accountId of [company.account_id, otherCompany.account_id]) {
    addonBefore.set(accountId, await queryOne("SELECT * FROM account_addons WHERE account_id = ? AND addon_code = 'integrations'", [accountId]));
    await execute(
      `INSERT INTO account_addons (public_id, account_id, addon_code, status, started_at)
       VALUES (?, ?, 'integrations', 'active', NOW(3))
       ON DUPLICATE KEY UPDATE status = 'active', ends_at = NULL, cancelled_at = NULL`,
      [`01QAADDON${suffix}${accountId}`.slice(0, 26).padEnd(26, "0"), accountId]
    );
  }

  unapprovedCategory = await queryOne(
    `SELECT c.code FROM categories c
      WHERE c.id IN (2, 3, 4, 5, 6) AND NOT EXISTS (
        SELECT 1 FROM account_category_access aca JOIN categories cc ON cc.id = aca.category_id
         WHERE aca.account_id = ? AND aca.status = 'approved' AND COALESCE(cc.root_category_id, cc.id) = c.id)
      LIMIT 1`,
    [company.account_id]
  );

  location = await queryOne(
    `SELECT ci.id AS city_id, ci.name AS city_name, co.name AS country_name
       FROM locations ci JOIN locations co ON co.id = ci.country_id
      WHERE ci.level = 'city' AND ci.status = 'active' AND ci.deleted_at IS NULL AND co.slug = 'united-arab-emirates'
      ORDER BY ci.active_listing_count DESC LIMIT 1`
  );

  agent = await queryOne("SELECT email FROM agents WHERE organization_id = ? AND deleted_at IS NULL AND email IS NOT NULL LIMIT 1", [company.organization_id]);
  useFakeImages();

  writeKey = await makeKey(company.organization_id, ["listings:write"]);
  readKey = await makeKey(company.organization_id, ["listings:read"]);
  ipLockedKey = await makeKey(company.organization_id, ["listings:write"], { allowedIps: ["203.0.113.10"] });
  revokedKey = await makeKey(company.organization_id, ["listings:write"]);
  await execute("UPDATE api_clients SET status = 'revoked', revoked_at = NOW(3) WHERE id = ?", [revokedKey.rowId]);
  otherKey = await makeKey(otherCompany.organization_id, ["listings:write"]);

  member = await createDisposableStaffUser({ prefix: "partner-api-member", password: PASSWORD });
  await execute(
    `INSERT INTO account_members (account_id, user_id, role, status, can_view_integrations, can_manage_listings, joined_at)
     VALUES (?, ?, 'manager', 'active', 1, 1, NOW(3))`,
    [company.account_id, member.id]
  );
  await portal.login(member.email, PASSWORD);

  staff = await createDisposableStaffUser({ prefix: "partner-api-admin", password: PASSWORD, roleCode: "super_admin" });
  await admin.login(staff.email, PASSWORD);
});

afterAll(async () => {
  const listingRows = createdListingIds.size
    ? await query(`SELECT public_id FROM listings WHERE id IN (${[...createdListingIds].map(() => "?").join(",")})`, [...createdListingIds])
    : [];
  await cleanupListings(listingRows.map((row) => row.public_id));

  const imports = keyIds.length
    ? await query(`SELECT id, public_id FROM feed_imports WHERE api_client_id IN (${keyIds.map(() => "?").join(",")})`, keyIds)
    : [];
  for (const run of imports) {
    await execute("DELETE FROM notifications WHERE type = 'listing_import.failed_items' AND subject_id = ?", [run.id]);
  }
  const provider = await queryOne("SELECT id FROM integration_providers WHERE code = ?", [IMPORT_PROVIDER_CODE]);
  for (const organizationId of [company?.organization_id, otherCompany?.organization_id].filter(Boolean)) {
    // Imports, items and external references cascade with the connection this run created.
    await execute("DELETE FROM integration_connections WHERE provider_id = ? AND organization_id = ? AND direction = 'inbound'", [
      provider?.id ?? 0,
      organizationId,
    ]);
  }
  for (const id of keyIds) {
    await execute("DELETE FROM idempotency_keys WHERE scope = ?", [`partner:${id}`]);
    await execute("DELETE FROM api_request_logs WHERE api_client_id = ?", [id]);
    await execute("DELETE FROM api_clients WHERE id = ?", [id]);
  }
  if (member) {
    await execute("DELETE FROM account_members WHERE user_id = ?", [member.id]);
    await cleanupUsers([member.email]);
  }
  if (staff) await cleanupUsers([staff.email]);
  // The unknown values this run sends on purpose join the admin's mapping queue (Phase 5).
  await execute("DELETE FROM feed_value_mappings WHERE connection_id IS NULL AND external_value IN ('spaceship', 'atlantis-under-the-sea')");
  for (const [accountId, before] of addonBefore) {
    if (!before) {
      await execute("DELETE FROM account_addons WHERE account_id = ? AND addon_code = 'integrations'", [accountId]);
    } else {
      await execute("UPDATE account_addons SET status = ?, ends_at = ?, cancelled_at = ? WHERE id = ?", [
        before.status, before.ends_at, before.cancelled_at, before.id,
      ]);
    }
  }
  await closePool();
});

describe("authentication and authorization", () => {
  it("asks for credentials when none are sent", async () => {
    const response = await request(app).get("/v1/partner/me");
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe("API_KEY_REQUIRED");
  });

  it("refuses a wrong secret, an unknown key and a revoked key with the same answer", async () => {
    for (const key of [{ clientId: writeKey.clientId, secret: "wrong" }, { clientId: "lf_unknown", secret: "x" }, revokedKey]) {
      const response = await as(key).get("/v1/partner/me");
      expect(response.status).toBe(401);
      expect(response.body.error.code).toBe("API_KEY_INVALID");
    }
  });

  it("refuses a key used from an address outside its allow-list", async () => {
    const response = await as(ipLockedKey).get("/v1/partner/me");
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe("IP_NOT_ALLOWED");
  });

  it("refuses a write with a read-only key", async () => {
    const response = await as(readKey).put(`/v1/partner/listings/${ext("readonly")}`, listing(ext("readonly")));
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe("SCOPE_MISSING");
  });

  it("stops every key while the company's Integrations add-on is off", async () => {
    await execute("UPDATE account_addons SET status = 'cancelled' WHERE account_id = ? AND addon_code = 'integrations'", [company.account_id]);
    try {
      const response = await as(writeKey).get("/v1/partner/me");
      expect(response.status).toBe(403);
      expect(response.body.error.code).toBe("ADDON_INACTIVE");
    } finally {
      await execute("UPDATE account_addons SET status = 'active' WHERE account_id = ? AND addon_code = 'integrations'", [company.account_id]);
    }
  });

  it("reads the company's lead feed with a leads:read key, and refuses a key without it", async () => {
    const leadsKey = await makeKey(company.organization_id, ["leads:read"]);
    const response = await as(leadsKey).get("/v1/partner/leads?limit=5");
    expect(response.status, JSON.stringify(response.body)).toBe(200);
    expect(response.body).toMatchObject({ version: 1, hasMore: expect.any(Boolean) });
    expect(Array.isArray(response.body.data)).toBe(true);
    const xml = await as(leadsKey).get("/v1/partner/leads?limit=2&format=xml");
    expect(xml.text).toContain("<livfinder-leads");
    expect((await as(writeKey).get("/v1/partner/leads")).status).toBe(403);
  });

  it("tells a key which company it belongs to", async () => {
    const response = await as(writeKey).get("/v1/partner/me");
    expect(response.status).toBe(200);
    expect(response.body.data.company.id).toBe(company.public_id);
    expect(response.body.data.apiKey.clientId).toBe(writeKey.clientId);
  });

  it("logs every partner request against its key", async () => {
    await new Promise((resolve) => setTimeout(resolve, 200));
    const row = await queryOne("SELECT COUNT(*) AS n FROM api_request_logs WHERE api_client_id = ?", [writeKey.rowId]);
    expect(Number(row.n)).toBeGreaterThan(0);
  });
});

describe("single push", () => {
  const id = ext("single");
  let listingPublicId = null;

  it("creates the listing in the key's company, unpublished until the company submits it, with its source recorded", async () => {
    const response = await as(writeKey).put(`/v1/partner/listings/${id}`, listing(id));
    expect(response.status).toBe(201);
    expect(response.headers["x-import-id"]).toBeTruthy();
    expect(response.body.data.operation).toBe("create");
    expect(response.body.data.status).toBe("draft");
    listingPublicId = response.body.data.listingId;

    const row = await queryOne(
      "SELECT id, organization_id, account_id, source, source_reference, source_api_client_id, moderation_status FROM listings WHERE public_id = ?",
      [listingPublicId]
    );
    createdListingIds.add(row.id);
    expect(row.organization_id).toBe(company.organization_id);
    expect(row.source).toBe("api");
    expect(row.source_reference).toBe(id);
    expect(row.source_api_client_id).toBe(writeKey.rowId);
    expect(row.moderation_status).toBe("not_submitted");
  });

  it("submits a pushed listing for review when the push asks for it", async () => {
    const submitted = ext("submitted");
    const response = await as(writeKey).put(`/v1/partner/listings/${submitted}`, listing(submitted, { status: "pending_review" }));
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect(response.body.data.status).toBe("pending_review");
    const row = await queryOne("SELECT id, moderation_status FROM listings WHERE public_id = ?", [response.body.data.listingId]);
    createdListingIds.add(row.id);
    expect(row.moderation_status).toBe("pending");
  });

  it("answers unchanged when the same listing is pushed again", async () => {
    const response = await as(writeKey).put(`/v1/partner/listings/${id}`, listing(id));
    expect(response.status).toBe(200);
    expect(response.body.data.operation).toBe("unchanged");
    expect(response.body.data.listingId).toBe(listingPublicId);
  });

  it("updates in place; on a live listing the change waits for approval while it stays live", async () => {
    await execute("UPDATE listings SET status = 'active', moderation_status = 'approved' WHERE public_id = ?", [listingPublicId]);
    const response = await as(writeKey).put(`/v1/partner/listings/${id}`, listing(id, { price: 2600000 }));
    expect(response.status).toBe(200);
    expect(response.body.data.operation).toBe("update");
    expect(response.body.data.status).toBe("active");
    const row = await queryOne(
      `SELECT l.price, r.status AS revision FROM listings l LEFT JOIN listing_revisions r ON r.id = l.pending_revision_id
        WHERE l.public_id = ?`,
      [listingPublicId]
    );
    expect(Number(row.price)).toBe(2600000);
    expect(row.revision).toBe("pending");
  });

  it("reports an image it could not fetch as a warning, when enough others arrived", async () => {
    const withImage = ext("image");
    const images = [...listing(withImage).images, "https://images.example/broken/1.jpg"];
    const response = await as(writeKey).put(`/v1/partner/listings/${withImage}`, listing(withImage, { images }));
    expect(response.status).toBe(201);
    const row = await queryOne("SELECT id FROM listings WHERE public_id = ?", [response.body.data.listingId]);
    createdListingIds.add(row.id);
    expect(response.body.data.images.failed).toHaveLength(1);
    expect(response.body.data.warnings.join(" ")).toMatch(/Image not added/);
  });

  it("refuses a listing that ends up with fewer than 3 images, and says why", async () => {
    const bad = ext("few-images");
    const images = ["https://images.example/ok/1.jpg", "https://images.example/ok/2.jpg", "https://images.example/broken/2.jpg"];
    const response = await as(writeKey).put(`/v1/partner/listings/${bad}`, listing(bad, { images }));
    expect(response.status).toBe(422);
    expect(response.body.error.fields.images).toMatch(/At least 3 different images must load; 2 did/);
  });

  it("refuses an incomplete listing, naming everything it lacks", async () => {
    const bad = ext("thin");
    const response = await as(writeKey).put(`/v1/partner/listings/${bad}`, {
      externalId: bad,
      category: "real-estate",
      title: "QA thin listing",
      location: { country: location.country_name, city: location.city_name },
    });
    expect(response.status).toBe(422);
    expect(Object.keys(response.body.error.fields)).toEqual(expect.arrayContaining(["purpose", "description", "bedrooms", "features", "images"]));
  });

  it("refuses a company's listing with no agent", async () => {
    const bad = ext("no-agent");
    const response = await as(writeKey).put(`/v1/partner/listings/${bad}`, listing(bad, { agentEmail: undefined }));
    expect(response.status).toBe(422);
    expect(response.body.error.fields.agentEmail).toBeTruthy();
  });

  it("asks for the sub-community where the community has them", async () => {
    const bad = ext("no-sub");
    const whole = listing(bad);
    const response = await as(writeKey).put(`/v1/partner/listings/${bad}`, { ...whole, location: { country: "AE", city: "Dubai", community: "Dubai Marina" } });
    expect(response.status).toBe(422);
    expect(response.body.error.fields.subCommunity).toMatch(/sub-community in Dubai Marina/);
  });

  describe("a location goes as deep as LivFinder's list, and no deeper", () => {
    const push = (name, place) => {
      const id = ext(name);
      return as(writeKey).put(`/v1/partner/listings/${id}`, listing(id, { location: place }));
    };
    const saved = async (response) => {
      expect(response.status, JSON.stringify(response.body.error)).toBe(201);
      const row = await queryOne("SELECT id FROM listings WHERE public_id = ?", [response.body.data.listingId]);
      createdListingIds.add(row.id);
    };
    const place = (sql) => queryOne(sql);
    const live = "deleted_at IS NULL AND status = 'active'";

    it("saves a country that has no cities or states on LivFinder", async () => {
      const country = await place(
        `SELECT c.id, c.name FROM locations c WHERE c.level = 'country' AND c.${live}
           AND NOT EXISTS (SELECT 1 FROM locations x WHERE x.country_id = c.id AND x.level IN ('city', 'state') AND x.deleted_at IS NULL) LIMIT 1`
      );
      await saved(await push("country-only", { country: country.name }));
    });

    it("saves a state that has no cities, by its id", async () => {
      const state = await place(
        `SELECT s.id FROM locations s WHERE s.level = 'state' AND s.${live}
           AND NOT EXISTS (SELECT 1 FROM locations x WHERE x.state_id = s.id AND x.level = 'city' AND x.deleted_at IS NULL) LIMIT 1`
      );
      await saved(await push("state-only", { id: String(state.id) }));
    });

    it("saves a city that has no communities", async () => {
      const city = await place(
        `SELECT c.id FROM locations c WHERE c.level = 'city' AND c.${live}
           AND NOT EXISTS (SELECT 1 FROM locations x WHERE x.city_id = c.id AND x.level IN ('community', 'district') AND x.deleted_at IS NULL) LIMIT 1`
      );
      await saved(await push("city-only", { id: String(city.id) }));
    });

    it("saves a community that has no sub-communities", async () => {
      const community = await place(
        `SELECT c.id FROM locations c WHERE c.level = 'community' AND c.${live}
           AND NOT EXISTS (SELECT 1 FROM locations x WHERE x.community_id = c.id AND x.level = 'sub_community' AND x.deleted_at IS NULL) LIMIT 1`
      );
      await saved(await push("community-only", { id: String(community.id) }));
    });

    it("holds an id to the same rule as names", async () => {
      const uae = await place(`SELECT id FROM locations WHERE level = 'country' AND slug = 'united-arab-emirates' LIMIT 1`);
      const country = await push("country-id", { id: String(uae.id) });
      expect(country.status).toBe(422);
      expect(country.body.error.fields.city).toMatch(/Give the city/);

      const dubai = await place(`SELECT id FROM locations WHERE level = 'city' AND slug = 'dubai' AND country_id = ${uae.id} LIMIT 1`);
      const city = await push("city-id", { id: String(dubai.id) });
      expect(city.status).toBe(422);
      expect(city.body.error.fields.community).toMatch(/Give the community/);
    });
  });

  describe("each level of a location must belong to the one above it", () => {
    const push = (name, place) => {
      const id = ext(name);
      return as(writeKey).put(`/v1/partner/listings/${id}`, listing(id, { location: place }));
    };

    it("refuses a state from another country, and says where it really is", async () => {
      const state = await queryOne(
        `SELECT s.name, c.name AS country FROM locations s JOIN locations c ON c.id = s.country_id
          WHERE s.level = 'state' AND s.deleted_at IS NULL AND c.slug = 'india' ORDER BY s.id LIMIT 1`
      );
      const before = await queryOne("SELECT COUNT(*) AS n FROM feed_value_mappings WHERE external_value = ?", [state.name.toLowerCase()]);
      const response = await push("wrong-state", { country: "AE", state: state.name, city: "Dubai" });
      expect(response.status).toBe(422);
      const message = response.body.error.fields["location.state"];
      expect(message).toContain(`"${state.name}" is not in United Arab Emirates`);
      expect(message).toContain(state.country);
      const after = await queryOne("SELECT COUNT(*) AS n FROM feed_value_mappings WHERE external_value = ?", [state.name.toLowerCase()]);
      expect(after.n).toBe(before.n);
    });

    it("refuses a city from another state", async () => {
      const response = await push("wrong-city", { country: "AE", state: "Sharjah", city: "Dubai" });
      expect(response.status).toBe(422);
      expect(response.body.error.fields["location.city"]).toMatch(/"Dubai" is not in Sharjah.*United Arab Emirates/);
    });

    it("refuses a community from another city", async () => {
      const response = await push("wrong-community", { country: "AE", city: "Abu Dhabi", community: "Dubai Marina" });
      expect(response.status).toBe(422);
      expect(response.body.error.fields["location.community"]).toMatch(/"Dubai Marina" is not in Abu Dhabi/);
    });

    it("holds names sent with an id to that id", async () => {
      const place = await queryOne("SELECT id FROM locations WHERE level = 'sub_community' AND name = 'Bay Central' LIMIT 1");
      const response = await push("id-mismatch", { id: String(place.id), country: "IN", city: "Abu Dhabi" });
      expect(response.status).toBe(422);
      expect(response.body.error.fields["location.country"]).toMatch(/does not match location id/);
      expect(response.body.error.fields["location.city"]).toMatch(/Bay Central/);
    });

    it("accepts names that do fit their id", async () => {
      const place = await queryOne("SELECT id FROM locations WHERE level = 'sub_community' AND name = 'Bay Central' LIMIT 1");
      const id = ext("id-match");
      const response = await as(writeKey).put(`/v1/partner/listings/${id}`, listing(id, { location: { id: String(place.id), country: "AE", city: "Dubai", community: "Dubai Marina" } }));
      expect(response.status, JSON.stringify(response.body.error)).toBe(201);
      const row = await queryOne("SELECT id FROM listings WHERE public_id = ?", [response.body.data.listingId]);
      createdListingIds.add(row.id);
    });
  });

  it("adds an amenity LivFinder does not have, and the listing shows it", async () => {
    const id = ext("amenity");
    const amenity = `QA rooftop cinema ${suffix}`;
    const response = await as(writeKey).put(`/v1/partner/listings/${id}`, listing(id, { features: ["Private pool", amenity] }));
    expect(response.status).toBe(201);
    const row = await queryOne("SELECT id FROM listings WHERE public_id = ?", [response.body.data.listingId]);
    createdListingIds.add(row.id);
    const feature = await queryOne(
      `SELECT f.id, f.name FROM features f JOIN listing_features lf ON lf.feature_id = f.id WHERE lf.listing_id = ? AND f.name = ?`,
      [row.id, amenity]
    );
    expect(feature).toBeTruthy();
    expect(await queryOne("SELECT 1 AS ok FROM category_features WHERE category_id = 1 AND feature_id = ?", [feature.id])).toBeTruthy();
    await execute("DELETE FROM listing_features WHERE feature_id = ?", [feature.id]);
    await execute("DELETE FROM category_features WHERE feature_id = ?", [feature.id]);
    await execute("DELETE FROM features WHERE id = ?", [feature.id]);
  });

  it("explains what to fix, with the partner's field names, and records the failure", async () => {
    const bad = ext("bad");
    const response = await as(writeKey).put(`/v1/partner/listings/${bad}`, listing(bad, { propertyType: "spaceship" }));
    expect(response.status).toBe(422);
    expect(response.body.error.code).toBe("UNMAPPED_VALUE");
    expect(response.body.error.fields.propertyType).toMatch(/spaceship/);
    const importId = response.headers["x-import-id"];
    const items = await as(writeKey).get(`/v1/partner/imports/${importId}/items`);
    expect(items.body.data[0].status).toBe("failed");
    expect(items.body.data[0].error.fields.propertyType).toBeTruthy();
  });

  it("refuses a location it cannot find, naming the level", async () => {
    const bad = ext("nowhere");
    const response = await as(writeKey).put(
      `/v1/partner/listings/${bad}`,
      listing(bad, { location: { country: location.country_name, city: "Atlantis-Under-The-Sea" } })
    );
    expect(response.status).toBe(422);
    expect(response.body.error.fields["location.city"]).toMatch(/Atlantis/);
  });

  it("refuses a category the company is not approved for", async () => {
    if (!unapprovedCategory) return;
    const bad = ext("category");
    const response = await as(writeKey).put(`/v1/partner/listings/${bad}`, {
      category: unapprovedCategory.code,
      title: "QA category check",
      location: { country: location.country_name, city: location.city_name },
    });
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe("CATEGORY_NOT_APPROVED");
  });

  it("keeps another company out of this company's listings and imports", async () => {
    const own = await as(writeKey).get(`/v1/partner/listings/${id}`);
    expect(own.status).toBe(200);
    const foreign = await as(otherKey).get(`/v1/partner/listings/${id}`);
    expect(foreign.status).toBe(404);
    const foreignImport = await as(otherKey).get(`/v1/partner/imports/${own.headers["x-import-id"] || "none"}`);
    expect(foreignImport.status).toBe(404);
  });

  it("withdraws the listing and records where every change came from", async () => {
    const response = await as(writeKey).delete(`/v1/partner/listings/${id}`);
    expect(response.status).toBe(200);
    expect(response.body.data.operation).toBe("withdraw");
    expect(response.body.data.status).toBe("withdrawn");

    const source = await admin.get(`/v1/admin/listing-sources/${listingPublicId}`);
    expect(source.status).toBe(200);
    expect(source.body.data.channel).toBe("api");
    expect(source.body.data.externalId).toBe(id);
    expect(source.body.data.apiKey.clientId).toBe(writeKey.clientId);
    expect(source.body.data.company.id).toBe(company.public_id);
    expect(source.body.data.history.map((entry) => entry.operation)).toEqual(expect.arrayContaining(["create", "update", "withdraw"]));
    expect(source.body.data.history[0].sourceIp).toBeTruthy();
  });
});

describe("bulk push", () => {
  it("accepts a batch, rejects bad rows at once, and reports every listing", async () => {
    const good = [ext("bulk-1"), ext("bulk-2")];
    const response = await as(writeKey).post("/v1/partner/imports", {
      listings: [
        { externalId: good[0], ...listing(good[0]) },
        { externalId: good[1], ...listing(good[1]) },
        { externalId: ext("bulk-bad"), ...listing(ext("bulk-bad")), title: "x" },
        { externalId: good[0], ...listing(good[0]) },
      ],
    });
    expect(response.status).toBe(202);
    expect(response.body.data.accepted).toBe(2);
    expect(response.body.data.rejected.map((item) => item.row)).toEqual([3, 4]);
    expect(response.body.data.rejected[0].error.fields.title).toBeTruthy();

    const done = await waitForImport(writeKey, response.body.data.id);
    expect(done.status).toBe("partial");
    expect(done.counts).toMatchObject({ total: 4, created: 2, failed: 2 });

    const items = await as(writeKey).get(`/v1/partner/imports/${response.body.data.id}/items?status=succeeded`);
    for (const item of items.body.data) {
      const row = await queryOne("SELECT id FROM listings WHERE public_id = ?", [item.listing.id]);
      createdListingIds.add(row.id);
    }
    expect(items.body.data).toHaveLength(2);
  });

  it("refuses more than 100 listings in one request", async () => {
    const response = await as(writeKey).post("/v1/partner/imports", { listings: Array.from({ length: 101 }, () => ({})) });
    expect(response.status).toBe(422);
  });
});

describe("company and admin views", () => {
  it("shows the company its own imports with per-listing results", async () => {
    const response = await portal.get("/v1/portal/integrations/imports");
    expect(response.status).toBe(200);
    expect(response.body.data.length).toBeGreaterThan(0);
    expect(response.body.data.every((run) => run.company.id === company.public_id)).toBe(true);
    const failed = response.body.data.find((run) => run.counts.failed > 0);
    const items = await portal.get(`/v1/portal/integrations/imports/${failed.id}/items?status=failed`);
    expect(items.status).toBe(200);
    expect(items.body.data[0].error).toBeTruthy();
  });

  it("never shows a company another company's import", async () => {
    const foreign = await as(otherKey).post("/v1/partner/imports", { listings: [{ externalId: ext("foreign"), title: "x" }] });
    const response = await portal.get(`/v1/portal/integrations/imports/${foreign.body.data.id}`);
    expect(response.status).toBe(404);
  });

  it("returns each key's client id and IP allow-list to the company", async () => {
    const response = await portal.get("/v1/portal/integrations");
    const locked = response.body.data.find((key) => key.id === ipLockedKey.id);
    expect(locked.clientId).toBe(ipLockedKey.clientId);
    expect(locked.allowedIps).toEqual(["203.0.113.10"]);
    expect(locked.secret).toBeNull();
  });

  it("lets admins see imports for any company and suspend a key", async () => {
    const imports = await admin.get(`/v1/admin/listing-imports?company=${company.public_id}`);
    expect(imports.status).toBe(200);
    expect(imports.body.data.length).toBeGreaterThan(0);

    const suspended = await admin.send("patch", `/v1/admin/api-clients/${writeKey.id}`, { status: "suspended" });
    expect(suspended.status).toBe(200);
    expect(suspended.body.data.status).toBe("suspended");
    const refused = await as(writeKey).get("/v1/partner/me");
    expect(refused.status).toBe(401);
    await admin.send("patch", `/v1/admin/api-clients/${writeKey.id}`, { status: "active" });
  });
});
