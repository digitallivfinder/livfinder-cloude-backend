import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, query, queryOne, execute } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

/**
 * Public marketplace API, against the real database.
 *
 * The point of these is the SQL: that the visibility view is what decides who
 * is published, that a filter reaches the right indexed column, and that an
 * unpublished row cannot be reached by guessing an identifier.
 */
const api = client();
let sampleListing = null;

beforeAll(async () => {
  const response = await api.get("/v1/public/listings", { category: "real-estate", pageSize: 5 });
  sampleListing = response.body.data[0];
});

afterAll(async () => {
  await closePool();
});

describe("health", () => {
  it("reports liveness without touching the database", async () => {
    const response = await api.get("/health");
    expect(response.status).toBe(200);
    expect(response.body.data.status).toBe("ok");
  });

  it("reports database readiness separately", async () => {
    const response = await api.get("/health/database");
    expect(response.status).toBe(200);
    expect(response.body.data.database).toBe("livfinder");
  });

  it("returns a trace id on every response", async () => {
    const response = await api.get("/health");
    expect(response.headers["x-request-id"]).toBeTruthy();
  });
});

describe("listing search", () => {
  it("returns published listings with a page total", async () => {
    const response = await api.get("/v1/public/listings", { category: "real-estate", pageSize: 5 });
    expect(response.status).toBe(200);
    expect(response.body.data.length).toBeGreaterThan(0);
    expect(response.body.pageInfo.total).toBeGreaterThan(response.body.data.length);
  });

  it("returns only rows the visibility view admits", async () => {
    const response = await api.get("/v1/public/listings", { pageSize: 100 });
    const references = response.body.data.map((row) => row.reference);
    const rows = await query(
      `SELECT reference FROM listings
        WHERE reference IN (${references.map(() => "?").join(", ")})
          AND (status <> 'active' OR moderation_status <> 'approved' OR published_at IS NULL)`,
      references
    );
    expect(rows).toHaveLength(0);
  });

  it("filters by price against the base-currency column", async () => {
    const floor = 5_000_000;
    const response = await api.get("/v1/public/listings", { category: "real-estate", minPrice: floor, pageSize: 20 });
    const below = response.body.data.filter((row) => row.priceBase !== null && row.priceBase < floor);
    expect(below).toHaveLength(0);
  });

  it("filters by bedrooms through the projection's spec column", async () => {
    const response = await api.get("/v1/public/listings", { category: "real-estate", beds: 5, pageSize: 20 });
    expect(response.body.data.every((row) => row.bedrooms === 5)).toBe(true);
  });

  it("filters by location and only returns that country", async () => {
    const response = await api.get("/v1/public/listings", { country: "united-arab-emirates", pageSize: 20 });
    expect(response.body.data.length).toBeGreaterThan(0);
    expect(response.body.data.every((row) => row.country === "united-arab-emirates")).toBe(true);
  });

  it("returns nothing for a location that does not exist rather than everything", async () => {
    const response = await api.get("/v1/public/listings", { country: "atlantis", pageSize: 20 });
    expect(response.status).toBe(200);
    expect(response.body.data).toHaveLength(0);
    expect(response.body.pageInfo.total).toBe(0);
  });

  it("sorts by price in both directions", async () => {
    const ascending = await api.get("/v1/public/listings", { category: "cars", sort: "priceAsc", pageSize: 10 });
    const prices = ascending.body.data.map((row) => row.priceBase).filter((value) => value !== null);
    expect([...prices].sort((a, b) => a - b)).toEqual(prices);

    const descending = await api.get("/v1/public/listings", { category: "cars", sort: "priceDesc", pageSize: 10 });
    const reversed = descending.body.data.map((row) => row.priceBase).filter((value) => value !== null);
    expect([...reversed].sort((a, b) => b - a)).toEqual(reversed);
  });

  it("pages without repeating a row", async () => {
    const first = await api.get("/v1/public/listings", { category: "real-estate", page: 1, pageSize: 5 });
    const second = await api.get("/v1/public/listings", { category: "real-estate", page: 2, pageSize: 5 });
    const overlap = first.body.data.filter((row) => second.body.data.some((other) => other.id === row.id));
    expect(overlap).toHaveLength(0);
  });

  it("caps the page size", async () => {
    const response = await api.get("/v1/public/listings", { pageSize: 5000 });
    expect(response.status).toBe(422);
  });

  it("searches by reference", async () => {
    const response = await api.get("/v1/public/listings", { keyword: sampleListing.reference });
    expect(response.body.data.some((row) => row.reference === sampleListing.reference)).toBe(true);
  });
});

describe("listing detail", () => {
  it("resolves a listing by its canonical path", async () => {
    const response = await api.get("/v1/public/listings/by-path", { path: sampleListing.canonicalUrl });
    expect(response.status).toBe(200);
    expect(response.body.data.reference).toBe(sampleListing.reference);
  });

  it("returns the ordered gallery, features and contact channels", async () => {
    const response = await api.get(`/v1/public/listings/${sampleListing.reference}`);
    const detail = response.body.data;
    expect(Array.isArray(detail.gallery)).toBe(true);
    expect(Array.isArray(detail.features)).toBe(true);
    expect(detail.contact).toHaveProperty("allowCall");
  });

  it("404s for an unknown reference", async () => {
    const response = await api.get("/v1/public/listings/LF-000000000");
    expect(response.status).toBe(404);
    expect(response.body.error.traceId).toBeTruthy();
  });

  it("does not expose a draft listing by reference", async () => {
    const draft = await queryOne("SELECT reference FROM listings WHERE status = 'draft' AND deleted_at IS NULL LIMIT 1");
    if (!draft) return;
    const response = await api.get(`/v1/public/listings/${draft.reference}`);
    expect(response.status).toBe(404);
  });
});

describe("companies and agents", () => {
  it("lists only publicly visible organizations", async () => {
    const response = await api.get("/v1/public/companies", { pageSize: 50 });
    const slugs = response.body.data.map((row) => row.companySlug);
    const hidden = await query(
      `SELECT slug FROM organizations
        WHERE slug IN (${slugs.map(() => "?").join(", ")})
          AND (is_publicly_visible = 0 OR status <> 'active' OR deleted_at IS NOT NULL)`,
      slugs
    );
    expect(hidden).toHaveLength(0);
  });

  it("returns a company profile with its listings and agents", async () => {
    const list = await api.get("/v1/public/companies", { pageSize: 1 });
    const slug = list.body.data[0].companySlug;
    const response = await api.get(`/v1/public/companies/${slug}/profile`);
    expect(response.status).toBe(200);
    expect(response.body.data.agency.companySlug).toBe(slug);
    expect(Array.isArray(response.body.data.listings)).toBe(true);
  });

  it("hides an agent whose organization is not publicly visible", async () => {
    const hidden = await queryOne(
      `SELECT a.slug FROM agents a JOIN organizations o ON o.id = a.organization_id
        WHERE o.is_publicly_visible = 0 AND a.is_publicly_visible = 1 AND a.deleted_at IS NULL LIMIT 1`
    );
    if (!hidden) return;
    const response = await api.get(`/v1/public/agents/${hidden.slug}`);
    expect(response.status).toBe(404);
  });
});

describe("locations", () => {
  it("finds a city by prefix", async () => {
    const response = await api.get("/v1/public/locations", { q: "Dub", type: "city" });
    expect(response.status).toBe(200);
    expect(response.body.options.some((option) => option.label === "Dubai")).toBe(true);
  });

  it("never returns the whole tree", async () => {
    const response = await api.get("/v1/public/locations");
    expect(response.body.options.length).toBeLessThanOrEqual(50);
  });

  it("resolves a hierarchy path and rejects a child under the wrong parent", async () => {
    const valid = await api.get("/v1/public/locations", { pathname: "/real-estate/united-arab-emirates/dubai" });
    expect(valid.body.status).toBe("resolved");
    const invalid = await api.get("/v1/public/locations", { pathname: "/real-estate/france/dubai" });
    expect(invalid.body.status).toBe("not-found");
  });

  it("returns countries that actually have listings", async () => {
    const response = await api.get("/v1/public/countries");
    expect(response.body.data.length).toBeGreaterThan(0);
    expect(response.body.data.every((row) => row.listingCount > 0)).toBe(true);
  });
});

describe("editorial and seo", () => {
  it("lists only published articles", async () => {
    const response = await api.get("/v1/public/blogs", { pageSize: 20 });
    const slugs = response.body.data.map((row) => row.slug);
    const unpublished = await query(
      `SELECT slug FROM posts WHERE slug IN (${slugs.map(() => "?").join(", ")}) AND status <> 'published'`,
      slugs
    );
    expect(unpublished).toHaveLength(0);
  });

  it("returns an article body as renderable blocks", async () => {
    const list = await api.get("/v1/public/blogs", { pageSize: 1 });
    const response = await api.get(`/v1/public/blogs/${list.body.data[0].slug}`);
    expect(Array.isArray(response.body.data.body)).toBe(true);
    expect(response.body.data.body.length).toBeGreaterThan(0);
  });

  it("builds a sitemap from published rows only", async () => {
    const response = await api.get("/v1/public/sitemap", { kind: "properties" });
    expect(response.body.data.length).toBeGreaterThan(0);
    const paths = response.body.data.slice(0, 20).map((entry) => entry.url);
    const rows = await query(
      `SELECT canonical_path FROM listing_search WHERE canonical_path IN (${paths.map(() => "?").join(", ")})`,
      paths
    );
    expect(rows).toHaveLength(paths.length);
  });
});

describe("error contract", () => {
  it("returns a stable envelope with a trace id", async () => {
    const response = await api.get("/v1/public/listings/by-path", { path: "not-a-path" });
    expect(response.status).toBe(400);
    expect(response.body.error).toMatchObject({ code: "BAD_REQUEST" });
    expect(response.body.error.traceId).toBeTruthy();
  });

  it("reports field errors on a validation failure", async () => {
    const response = await api.get("/v1/public/listings", { page: "-3" });
    expect(response.status).toBe(422);
    expect(response.body.error.fields).toBeTruthy();
  });

  it("never returns SQL or a stack trace", async () => {
    const response = await api.get("/v1/public/listings/by-path", { path: "/real-estate/'; DROP TABLE listings; --" });
    expect(response.status).toBe(200);
    expect(response.text).not.toMatch(/SELECT|FROM listings|at Object/);
    // The table is still there.
    const [{ total }] = await query("SELECT COUNT(*) AS total FROM listings");
    expect(Number(total)).toBeGreaterThan(0);
  });
});

describe("seeded CDN imagery", () => {
  it("never serves a URL for the CDN host that only exists in a deployed environment", async () => {
    // ~2,500 seeded rows carry https://cdn.livfinder.com/... URLs. Unrewritten, every avatar,
    // logo and cover on the site renders broken.
    for (const path of [
      "/v1/public/home",
      "/v1/public/listings?pageSize=30",
      "/v1/public/agents?pageSize=20",
      "/v1/public/companies?pageSize=20",
      "/v1/public/blogs?pageSize=10",
      "/v1/public/directory",
    ]) {
      const response = await api.get(path);
      expect(response.status).toBe(200);
      expect(JSON.stringify(response.body)).not.toContain("cdn.livfinder.com");
    }
  });

  it("serves a placeholder image for a rewritten path", async () => {
    const listings = await api.get("/v1/public/agents", { pageSize: 5 });
    const photo = (listings.body.data || []).map((agent) => agent.photo).find(Boolean);
    expect(photo).toBeTruthy();

    const url = new URL(photo);
    const image = await api.get(url.pathname);
    expect(image.status).toBe(200);
    expect(String(image.headers["content-type"])).toContain("image/svg+xml");
  });
});
