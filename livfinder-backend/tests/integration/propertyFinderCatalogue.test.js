import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  client, ensureTestPassword, findPortalOwner, cleanupListings, queryOne, query,
} from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Real estate's types and amenities follow Property Finder's lists (migration 0083, owner decision
 * 2026-11-23), end to end through the API: the menus the website and forms read, the rules a
 * listing is saved under, the older codes that still resolve, and New Launch's developments lists.
 */
const PASSWORD = "LivFinder!2026";
const created = [];
const portal = client();
const pub = client();
let communityId = null;

const labels = (response) => (response.body.options || response.body.data || []).map((option) => option.label ?? option.name);

const RESIDENTIAL_SALE = [
  "Apartment", "Villa", "Townhouse", "Penthouse", "Compound", "Duplex", "Full Floor", "Half Floor",
  "Whole Building", "Land", "Bulk Sale Unit", "Bungalow", "Hotel & Hotel Apartment",
];
const RESIDENTIAL_RENT = [
  "Apartment", "Villa", "Townhouse", "Penthouse", "Compound", "Duplex", "Full Floor", "Half Floor",
  "Whole Building", "Bungalow", "Hotel & Hotel Apartment", "Bulk Rent Unit",
];
const COMMERCIAL_SALE = [
  "Villa", "Full Floor", "Half Floor", "Whole Building", "Land", "Bulk Sale Unit", "Hotel & Hotel Apartment",
  "Office Space", "Retail", "Warehouse", "Shop", "Show Room", "Factory", "Labor Camp", "Staff Accommodation",
  "Business Centre", "Co-working space", "Farm",
];
const COMMERCIAL_RENT = [
  "Villa", "Full Floor", "Half Floor", "Whole Building", "Land", "Bulk Rent Unit", "Office Space", "Retail",
  "Warehouse", "Shop", "Show Room", "Factory", "Labor Camp", "Staff Accommodation", "Business Centre",
  "Co-working space", "Farm",
];
const AMENITIES = [
  "Central A/C", "Maids Room", "Balcony", "Shared Pool", "Shared Spa", "Shared Gym", "Concierge Service",
  "Covered Parking", "View of Water", "View of Landmark", "Pets Allowed", "Study", "Private Garden",
  "Private Pool", "Private Gym", "Private Jacuzzi", "Built in Wardrobes", "Walk-in Closet",
  "Built in Kitchen Appliances", "Maid Service", "Children's Play Area", "Children's Pool", "Barbecue Area",
];

function listing(overrides = {}) {
  return {
    category: "real-estate",
    purpose: "sale",
    title: `PF catalogue check ${Date.now()} ${Math.random().toString(36).slice(2, 6)}`,
    description: "Created by the Property Finder catalogue suite.",
    price: 2500000,
    currency: "AED",
    locationId: communityId,
    detail: { bedrooms: 2, bathrooms: 2, builtAreaSqft: 1400 },
    ...overrides,
  };
}

async function create(overrides) {
  const response = await portal.send("post", "/v1/portal/listings", listing(overrides));
  if (response.status === 201) created.push(response.body.data.id);
  return response;
}

const typeOf = (publicId) =>
  queryOne(
    `SELECT c.code, l.property_segment FROM listings l JOIN categories c ON c.id = l.category_id WHERE l.public_id = ?`,
    [publicId]
  );

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  const owner = await findPortalOwner();
  await portal.login(owner.email, PASSWORD);
  const community = await queryOne(
    `SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1`
  );
  communityId = `community:${community.id}`;
});

afterAll(async () => {
  await cleanupListings(created);
  await closePool();
});

describe("the type menus", () => {
  const types = (query) => pub.get("/v1/public/filter-options/real-estate/propertyType", { all: "true", limit: 100, ...query });

  it("offer Property Finder's types for each Buy / Rent and Residential / Commercial", async () => {
    expect(labels(await types({ parent: "residential", purpose: "sale" }))).toEqual(RESIDENTIAL_SALE);
    expect(labels(await types({ parent: "residential", purpose: "rent" }))).toEqual(RESIDENTIAL_RENT);
    expect(labels(await types({ parent: "commercial", purpose: "sale" }))).toEqual(COMMERCIAL_SALE);
    expect(labels(await types({ parent: "commercial", purpose: "rent" }))).toEqual(COMMERCIAL_RENT);
  });

  it("offer all 25 with no narrowing, and none of the retired types", async () => {
    const all = labels(await types({}));
    expect(all).toHaveLength(25);
    for (const retired of ["Mansion", "Estate", "Chalet", "Private Island", "Vineyard", "Plot", "Industrial Land", "Commercial Floor"]) {
      expect(all).not.toContain(retired);
    }
  });
});

describe("the amenity menus", () => {
  it("offer Property Finder's 23 to real estate, in order", async () => {
    const response = await pub.get("/v1/public/filter-options/real-estate/amenities");
    expect(labels(response)).toEqual(AMENITIES);
    const form = await pub.get("/v1/public/features", { category: "real-estate" });
    expect(form.body.data.map((row) => row.name)).toEqual(AMENITIES);
  });

  it("offer none for commercial property", async () => {
    expect(labels(await pub.get("/v1/public/filter-options/real-estate/amenities", { segment: "commercial" }))).toEqual([]);
    expect((await pub.get("/v1/public/features", { category: "real-estate", segment: "commercial" })).body.data).toEqual([]);
  });

  it("give developments the same 23", async () => {
    const form = await pub.get("/v1/public/features", { category: "real-estate-developments" });
    expect(form.body.data.map((row) => row.name)).toEqual(AMENITIES);
    const newLaunch = await pub.get("/v1/public/projects/filter-options/amenities");
    expect(labels(newLaunch)).toEqual(AMENITIES);
  });

  it("leave yachts their own view features", async () => {
    const yachts = (await pub.get("/v1/public/features", { category: "yachts" })).body.data.map((row) => row.name);
    expect(yachts).toContain("Sea view");
    expect(yachts).not.toContain("View of Water");
  });
});

describe("New Launch (developments) menus", () => {
  it("offer all five Property Finder unit types, with counts", async () => {
    const response = await pub.get("/v1/public/projects/filter-options/propertyType");
    expect(labels(response)).toEqual(["Apartment", "Villa", "Townhouse", "Penthouse", "Duplex"]);
    expect(response.body.options.every((option) => Number.isInteger(option.count))).toBe(true);
  });

  it("offer no unit types or amenities for commercial", async () => {
    expect(labels(await pub.get("/v1/public/projects/filter-options/propertyType", { propertySegment: "commercial" }))).toEqual([]);
    expect(labels(await pub.get("/v1/public/projects/filter-options/amenities", { propertySegment: "commercial" }))).toEqual([]);
  });

  it("store only the five unit types", async () => {
    const rows = await query("SELECT DISTINCT unit_type FROM project_unit_types");
    for (const row of rows) expect(["apartment", "villa", "townhouse", "penthouse", "duplex"]).toContain(row.unit_type);
  });

  it("search developments by Ready / Off Plan, unit type and amenity", async () => {
    const ready = await pub.get("/v1/public/projects", { status: ["completed", "handed_over"], pageSize: 1 });
    const offPlan = await pub.get("/v1/public/projects", { status: ["announced", "presale", "under_construction"], pageSize: 1 });
    const all = await pub.get("/v1/public/projects", { pageSize: 1 });
    expect(ready.status).toBe(200);
    expect(ready.body.pageInfo.total + offPlan.body.pageInfo.total).toBeLessThanOrEqual(all.body.pageInfo.total);
    const typed = await pub.get("/v1/public/projects", { propertyType: "penthouse", amenities: "shared-pool", pageSize: 1 });
    expect(typed.status).toBe(200);
    // An older amenity slug still finds the developments that now carry its replacement.
    const legacy = await pub.get("/v1/public/projects", { propertyType: "penthouse", amenities: "infinity-pool", pageSize: 1 });
    expect(legacy.body.pageInfo.total).toBe(typed.body.pageInfo.total);
  });
});

describe("the listing search", () => {
  const total = async (query) => (await pub.get("/v1/public/listings", { category: "real-estate", pageSize: 1, ...query })).body.pageInfo.total;

  it("finds the renamed types by their new slugs, and by the old ones in saved links", async () => {
    expect(await total({ propertyType: "plots" })).toBe(await total({ propertyType: "land" }));
    expect(await total({ propertyType: "mansions" })).toBe(await total({ propertyType: "villas" }));
    expect(await total({ propertyType: "offices" })).toBe(await total({ propertyType: "office-spaces" }));
  });

  it("finds the merged amenities by their new slugs, and by the old ones", async () => {
    expect(await total({ amenities: "view-of-water" })).toBeGreaterThan(0);
    expect(await total({ amenities: "sea-view" })).toBe(await total({ amenities: "view-of-water" }));
  });

  it("holds no listing on a retired type", async () => {
    const row = await queryOne(
      `SELECT COUNT(*) AS n FROM listings l JOIN categories c ON c.id = l.category_id
        WHERE l.root_category_id = 1 AND l.deleted_at IS NULL AND c.deleted_at IS NOT NULL`
    );
    expect(Number(row.n)).toBe(0);
  });

  it("holds no amenity on a commercial listing", async () => {
    const row = await queryOne(
      `SELECT COUNT(*) AS n FROM listing_features lf JOIN listings l ON l.id = lf.listing_id
        WHERE l.root_category_id = 1 AND l.property_segment = 'commercial'`
    );
    expect(Number(row.n)).toBe(0);
  });

  it("says Residential or Commercial on a listing's public page", async () => {
    const row = await queryOne(
      `SELECT ls.listing_id, l.reference, l.property_segment FROM listing_search ls JOIN listings l ON l.id = ls.listing_id
        WHERE ls.root_category_id = 1 AND l.property_segment = 'commercial' LIMIT 1`
    );
    if (!row) return;
    const detail = await pub.get(`/v1/public/listings/${row.reference}`);
    expect(detail.status).toBe(200);
    expect(detail.body.data.propertySegment).toBe("commercial");
    expect(detail.body.data.features).toEqual([]);
  });

  it("holds no real-estate amenity outside the 23", async () => {
    const row = await queryOne(
      `SELECT COUNT(*) AS n FROM listing_features lf JOIN listings l ON l.id = lf.listing_id
        WHERE l.root_category_id = 1
          AND lf.feature_id NOT IN (SELECT feature_id FROM category_features WHERE category_id = 1)`
    );
    expect(Number(row.n)).toBe(0);
  });
});

describe("saving a listing", () => {
  it("accepts a Property Finder type and amenities", async () => {
    const response = await create({ categorySlug: "compounds", propertySegment: "residential", features: ["central-a-c", "Balcony"] });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect(await typeOf(response.body.data.id)).toMatchObject({ code: "compound", property_segment: "residential" });
    const names = (await query(
      `SELECT f.name FROM listing_features lf JOIN features f ON f.id = lf.feature_id
        WHERE lf.listing_id = (SELECT id FROM listings WHERE public_id = ?) ORDER BY f.sort_order`,
      [response.body.data.id]
    )).map((row) => row.name);
    expect(names).toEqual(["Central A/C", "Balcony"]);
  });

  it("resolves an older type code to its replacement", async () => {
    const response = await create({ categorySlug: "plot", propertySegment: "residential", detail: {} });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect((await typeOf(response.body.data.id)).code).toBe("land");
  });

  it("refuses a type Property Finder does not offer for that purpose", async () => {
    const response = await create({ purpose: "rent", categorySlug: "land", propertySegment: "residential", detail: {} });
    expect(response.status).toBe(422);
    expect(response.body.error.fields.categorySlug).toMatch(/not offered for rent/);
  });

  it("offers Land to rent as commercial", async () => {
    const response = await create({ purpose: "rent", categorySlug: "land", propertySegment: "commercial", detail: {} });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
  });

  it("picks the rent version of a bulk unit from the purpose", async () => {
    const response = await create({ purpose: "rent", categorySlug: "bulk-unit", propertySegment: "commercial", detail: { bathrooms: 4 } });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect((await typeOf(response.body.data.id)).code).toBe("bulk-rent-unit");
  });

  it("keeps a villa residential when no segment is sent, as before 0083", async () => {
    const response = await create({ categorySlug: "villas" });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect(await typeOf(response.body.data.id)).toMatchObject({ code: "villa", property_segment: "residential" });
  });

  it("lets a villa be commercial when asked", async () => {
    const response = await create({ categorySlug: "villas", propertySegment: "commercial", detail: { bathrooms: 3 } });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    expect((await typeOf(response.body.data.id)).property_segment).toBe("commercial");
  });

  it("drops amenities from a commercial listing", async () => {
    const response = await create({ categorySlug: "office-spaces", propertySegment: "commercial", features: ["balcony"], detail: { bathrooms: 2 } });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    const row = await queryOne(
      "SELECT COUNT(*) AS n FROM listing_features WHERE listing_id = (SELECT id FROM listings WHERE public_id = ?)",
      [response.body.data.id]
    );
    expect(Number(row.n)).toBe(0);
  });

  it("refuses an edit that moves a listing to a type not offered for its purpose", async () => {
    const response = await create({ purpose: "rent", categorySlug: "apartments" });
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    const edit = await portal.send("patch", `/v1/portal/listings/${response.body.data.id}`, { categorySlug: "bulk-sale-units" });
    expect(edit.status).toBe(422);
    expect((await typeOf(response.body.data.id)).code).toBe("apartment");
  });
});
