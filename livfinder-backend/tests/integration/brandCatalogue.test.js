import { afterAll, describe, expect, it } from "vitest";
import { adminEmail, client, cleanupListings, ensureTestPassword, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { query } from "../../src/db/query.js";

const PASSWORD = "LivFinder!2026";

/** An active portal owner whose account is approved for `categoryId`. */
async function ownerForCategory(categoryId) {
  return queryOne(
    `SELECT u.email
       FROM users u
       JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
       JOIN accounts a ON a.id = am.account_id AND a.status = 'active'
       JOIN account_category_access aca ON aca.account_id = a.id AND aca.status = 'approved' AND aca.category_id = ?
      WHERE u.status = 'active' AND u.deleted_at IS NULL
      ORDER BY u.id LIMIT 1`,
    [categoryId]
  );
}

/**
 * The make/model catalogue that the portal and admin add-listing forms cascade
 * through. `?all=true` returns the whole catalogue (not just makes that already
 * have live listings) so a lister can pick a make no one has listed yet; the
 * model list is scoped to the chosen make.
 */
const api = client();
const createdListings = [];

afterAll(async () => {
  await cleanupListings(createdListings);
  await closePool();
});

const CATEGORIES = ["cars", "yachts", "jets", "helicopters", "watches"];

describe("brand / model filter-options catalogue", () => {
  it.each(CATEGORIES)("%s: ?all=true returns the full make catalogue as slugs", async (category) => {
    const withListings = await api.get(`/v1/public/filter-options/${category}/make`);
    const all = await api.get(`/v1/public/filter-options/${category}/make?all=true`);

    const allOptions = all.body.options || all.body.data || [];
    expect(allOptions.length).toBeGreaterThan(0);
    for (const option of allOptions) {
      expect(option.slug, "every option carries a slug").toBeTruthy();
      expect(option.slug).toMatch(/^[a-z0-9-]+$/);
    }
    // `all` is a superset of "makes that have listings".
    const listed = withListings.body.options || withListings.body.data || [];
    expect(allOptions.length).toBeGreaterThanOrEqual(listed.length);
  });

  it.each(CATEGORIES)("%s: models are scoped to their make", async (category) => {
    const makes = (await api.get(`/v1/public/filter-options/${category}/make?all=true`)).body.options || [];
    // Pick a make that actually has models.
    let picked = null;
    let models = [];
    for (const make of makes.slice(0, 8)) {
      const response = await api.get(
        `/v1/public/filter-options/${category}/carModel?all=true&parent=${encodeURIComponent(make.slug)}`
      );
      const list = response.body.options || response.body.data || [];
      if (list.length) {
        picked = make;
        models = list;
        break;
      }
    }
    expect(picked, `${category} has at least one make with models`).toBeTruthy();
    for (const model of models) {
      expect(model.slug).toBeTruthy();
      // Its parent make is the one we asked for.
      expect(model.parentId ?? `make:${picked.slug}`).toContain(picked.slug);
    }

    // A different make does not return this make's models.
    const other = makes.find((make) => make.slug !== picked.slug);
    if (other) {
      const otherModels =
        (await api.get(`/v1/public/filter-options/${category}/carModel?all=true&parent=${other.slug}`)).body.options || [];
      const overlap = otherModels.filter((model) => models.some((mine) => mine.slug === model.slug && mine.id === model.id));
      expect(overlap).toHaveLength(0);
    }
  });

  it("each catalogue category maps to a distinct brand kind", async () => {
    const rows = await query(
      `SELECT kind, COUNT(*) AS n FROM brands WHERE deleted_at IS NULL GROUP BY kind`
    );
    const kinds = Object.fromEntries(rows.map((row) => [row.kind, Number(row.n)]));
    for (const kind of ["car_make", "yacht_builder", "aircraft_manufacturer", "watch_brand"]) {
      expect(kinds[kind], `${kind} catalogue is populated`).toBeGreaterThan(0);
    }
  });

  /**
   * Jets and helicopters share `brands.kind = 'aircraft_manufacturer'` by design
   * (a search filter needs only `kind` to disambiguate a slug collision), but the
   * `?all=true` make/model catalogue has no listing-count join to fall back on, so
   * without `aircraft_segment` (migration 0046) it offered every aircraft brand to
   * both categories — a jet listing could pick "Airbus Helicopters".
   */
  describe("jets and helicopters do not cross-list each other's manufacturers", () => {
    const HELICOPTER_MAKES = ["airbus-helicopters", "bell", "leonardo-helicopters", "robinson-helicopter", "sikorsky"];
    const JET_MAKES = ["gulfstream", "bombardier", "dassault-falcon", "cessna", "pilatus"];

    it("jets: ?all=true offers only fixed-wing manufacturers", async () => {
      const slugs = ((await api.get("/v1/public/filter-options/jets/make?all=true")).body.options || []).map((o) => o.slug);
      expect(slugs.length).toBeGreaterThan(0);
      for (const heli of HELICOPTER_MAKES) expect(slugs).not.toContain(heli);
      for (const jet of JET_MAKES) expect(slugs).toContain(jet);
    });

    it("helicopters: ?all=true offers only rotorcraft manufacturers", async () => {
      const slugs = ((await api.get("/v1/public/filter-options/helicopters/make?all=true")).body.options || []).map((o) => o.slug);
      expect(slugs.length).toBeGreaterThan(0);
      for (const jet of JET_MAKES) expect(slugs).not.toContain(jet);
      for (const heli of HELICOPTER_MAKES) expect(slugs).toContain(heli);
    });

    it("a jet's model list is empty for a helicopter-only manufacturer, and vice versa", async () => {
      const jetModelsForHeliMake = (await api.get("/v1/public/filter-options/jets/carModel?all=true&parent=bell")).body.options || [];
      expect(jetModelsForHeliMake).toHaveLength(0);
      const heliModelsForJetMake = (await api.get("/v1/public/filter-options/helicopters/carModel?all=true&parent=gulfstream")).body.options || [];
      expect(heliModelsForJetMake).toHaveLength(0);
    });

    it("create rejects a jet listing whose brand is a helicopter-only manufacturer", async () => {
      await ensureTestPassword(PASSWORD);
      const owner = await ownerForCategory(4); // jets
      expect(owner, "a seeded owner with jets access").toBeTruthy();
      const portal = client();
      await portal.login(owner.email, PASSWORD);
      const city = await queryOne("SELECT id FROM locations WHERE level = 'city' AND status = 'active' LIMIT 1");

      const response = await portal.send("post", "/v1/portal/listings", {
        category: "jets",
        purpose: "sale",
        title: `Segment mismatch ${Date.now()}`,
        description: "<p>Should be rejected</p>",
        price: 1000000,
        currency: "USD",
        locationId: `city:${city.id}`,
        brand: "bell", // a helicopter-only manufacturer
        detail: { yearBuilt: 2020 },
      });
      expect(response.status).toBe(422);
      if (response.status === 201) createdListings.push(response.body.data.id);
    });

    it("the admin listings-table filter (GET /v1/admin/listings) scopes manufacturers the same way", async () => {
      await ensureTestPassword(PASSWORD);
      const admin = client();
      await admin.login(await adminEmail("super_admin"), PASSWORD);

      // `brandsOfKind` returns `{value,label}` pairs (id-keyed), so match by label.
      const jetsResponse = await admin.get("/v1/admin/listings", { category: "jets" });
      const jetLabels = (jetsResponse.body.options?.brands || []).map((b) => b.label);
      expect(jetLabels).toEqual(expect.arrayContaining(["Gulfstream"]));
      expect(jetLabels).not.toEqual(expect.arrayContaining(["Bell", "Sikorsky", "Airbus Helicopters"]));

      const heliResponse = await admin.get("/v1/admin/listings", { category: "helicopters" });
      const heliLabels = (heliResponse.body.options?.brands || []).map((b) => b.label);
      expect(heliLabels).toEqual(expect.arrayContaining(["Bell"]));
      expect(heliLabels).not.toEqual(expect.arrayContaining(["Gulfstream", "Bombardier", "Cessna"]));
    });
  });
});
