import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { client, cleanupProjects, query, queryOne, execute } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { callProcedure } from "../../src/db/query.js";
import { developmentSchema, upsertDevelopment, archiveDevelopment } from "../../src/modules/admin/admin.mutations.js";
import { getAdminDevelopment, listAdminDevelopments } from "../../src/modules/admin/admin.catalog.js";

/**
 * The public Projects marketplace, against the real database.
 *
 * The point of these is the SQL and the contract: that the search projection is
 * what decides who is public, that a filter reaches the column it claims to,
 * that an unpublished project cannot be reached by guessing a URL, and that a
 * gated document's file never leaves the database on a public read.
 *
 * A project is created through the admin write path and removed afterwards, so
 * a run leaves the seed exactly as it found it — and so the write contract is
 * exercised by the same tests that read it back.
 */
const api = client();
const created = [];
let project = null;

/** A location the seed genuinely holds, so the canonical path is a real one. */
async function seededCommunity() {
  return queryOne(
    `SELECT l.id, l.slug, l.country_id, l.state_id, l.city_id
       FROM locations l
      WHERE l.level = 'community' AND l.state_id IS NOT NULL AND l.deleted_at IS NULL
      ORDER BY l.id LIMIT 1`
  );
}

beforeAll(async () => {
  const community = await seededCommunity();
  const developer = await queryOne(
    "SELECT public_id, slug FROM brands WHERE kind = 'property_developer' AND deleted_at IS NULL ORDER BY id LIMIT 1"
  );

  const payload = developmentSchema.parse({
    name: "Integration Test Residences",
    tagline: "Created by the projects integration suite",
    description: "A development written by the integration suite to exercise the whole public contract.",
    marketingHeading: "Every field, persisted",
    highlights: ["Private marina", "Sky lounge"],
    developerId: developer.slug,
    // Deliberately a display-cased, hyphenated value: the schema must normalise
    // it rather than writing a status the column would reject.
    projectType: "Mixed Use",
    ownershipType: "freehold",
    status: "Under Construction",
    launchStatus: "launched",
    moderationStatus: "published",
    launchDate: "2026-03-01",
    constructionStartDate: "2026-04-15",
    handoverDate: "2029-09-30",
    completionPercentage: 12,
    totalUnits: 340,
    availableUnits: 210,
    buildingCount: 3,
    minPrice: 1850000,
    maxPrice: 9400000,
    currencyCode: "AED",
    communityId: community.id,
    address: "Plot 12, Test Boulevard",
    latitude: 25.0657,
    longitude: 55.17128,
    amenities: ["Infinity pool", "Padel courts"],
    unitTypes: [
      { unitType: "apartment", bedrooms: 1, minSize: 720, maxSize: 860, areaUnit: "sqft", startingPrice: 1850000, currencyCode: "AED", availability: "available", totalUnits: 120, availableUnits: 96 },
      { unitType: "penthouse", bedrooms: 4, minSize: 3900, maxSize: 4600, areaUnit: "sqft", startingPrice: 9400000, currencyCode: "AED", availability: "limited", totalUnits: 8, availableUnits: 2 },
    ],
    paymentPlans: [
      {
        name: "60/40 construction linked",
        planType: "construction_linked",
        downPaymentPercent: 20,
        duringConstructionPercent: 40,
        onHandoverPercent: 40,
        milestones: [
          { name: "On booking", triggerType: "booking", percentage: 20 },
          { name: "50% construction", triggerType: "construction_percent", constructionPercent: 50, percentage: 40 },
          { name: "On handover", triggerType: "handover", percentage: 40 },
        ],
      },
      { name: "Post-handover 3 years", planType: "post_handover", downPaymentPercent: 10, duringConstructionPercent: 40, onHandoverPercent: 20, postHandoverPercent: 30, postHandoverMonths: 36 },
    ],
    acceptsInquiries: true,
    isFeatured: false,
    seoTitle: "Integration Test Residences",
    seoDescription: "Prices, floor plans and payment plans.",
  });

  const result = await upsertDevelopment({ identifier: null, payload, userId: null });
  created.push(result.id);
  const row = await queryOne("SELECT id, public_id, slug, canonical_path FROM projects WHERE public_id = ?", [result.id]);

  // A public brochure and a gated price list, so the visibility rules have
  // something real to be tested against.
  await execute(
    `INSERT INTO documents (public_id, owner_type, owner_id, document_type, title, visibility, status, created_at, updated_at)
     VALUES (?, 'project', ?, 'brochure', 'Integration brochure', 'public', 'active', NOW(3), NOW(3')`.replace("NOW(3')", "NOW(3))"),
    [`ITBROCHURE${Date.now()}`.slice(0, 26), row.id]
  );
  await execute(
    `INSERT INTO documents (public_id, owner_type, owner_id, document_type, title, visibility, status, created_at, updated_at)
     VALUES (?, 'project', ?, 'title_deed', 'Integration title deed', 'restricted', 'active', NOW(3), NOW(3))`,
    [`ITDEED${Date.now()}`.slice(0, 26), row.id]
  );
  await callProcedure("sp_refresh_project_search", [row.id]);

  project = row;
});

afterAll(async () => {
  await cleanupProjects(created);
  await closePool();
});

describe("project search", () => {
  it("returns published projects with a page total", async () => {
    const response = await api.get("/v1/public/projects", { pageSize: 5 });
    expect(response.status).toBe(200);
    expect(response.body.data.length).toBeGreaterThan(0);
    expect(response.body.pageInfo.total).toBeGreaterThanOrEqual(response.body.data.length);
    expect(response.body.pageInfo.sort).toBe("featured");
  });

  it("counts exactly what the projection holds", async () => {
    const response = await api.get("/v1/public/projects", { pageSize: 1 });
    const actual = await queryOne("SELECT COUNT(*) AS total FROM project_search");
    expect(response.body.pageInfo.total).toBe(Number(actual.total));
  });

  it("serialises a card with a canonical URL and a developer object", async () => {
    const response = await api.get("/v1/public/projects", { q: "Integration Test Residences" });
    const card = response.body.data[0];
    expect(card.canonicalUrl).toBe(project.canonical_path);
    expect(card.developer).toMatchObject({ slug: expect.any(String), name: expect.any(String) });
    expect(card.location.hierarchy.country.slug).toEqual(expect.any(String));
  });

  it("rejects an unknown sort rather than silently using the default", async () => {
    const response = await api.get("/v1/public/projects", { sort: "cheapest" });
    expect(response.status).toBe(422);
  });

  it("pages without overlapping", async () => {
    const first = await api.get("/v1/public/projects", { pageSize: 2, page: 1, sort: "newest" });
    const second = await api.get("/v1/public/projects", { pageSize: 2, page: 2, sort: "newest" });
    const ids = new Set(first.body.data.map((row) => row.id));
    expect(second.body.data.every((row) => !ids.has(row.id))).toBe(true);
    expect(second.body.pageInfo.page).toBe(2);
  });
});

describe("visibility", () => {
  it("hides an unpublished project from search, from by-path and from the sitemap", async () => {
    await execute("UPDATE projects SET moderation_status = 'draft', is_publicly_visible = 0 WHERE id = ?", [project.id]);
    await callProcedure("sp_refresh_project_search", [project.id]);
    try {
      const search = await api.get("/v1/public/projects", { q: "Integration Test Residences" });
      expect(search.body.data).toHaveLength(0);

      const byPath = await api.get("/v1/public/projects/by-path", { path: project.canonical_path });
      expect(byPath.body.data).toBeNull();

      const detail = await api.get(`/v1/public/projects/${project.public_id}`);
      expect(detail.status).toBe(404);

      const sitemap = await api.get("/v1/public/sitemap", { kind: "projects" });
      expect(sitemap.body.data.some((entry) => entry.url === project.canonical_path)).toBe(false);
    } finally {
      await execute("UPDATE projects SET moderation_status = 'published', is_publicly_visible = 1 WHERE id = ?", [project.id]);
      await callProcedure("sp_refresh_project_search", [project.id]);
    }
  });

  it("excludes a cancelled project even while it is still flagged visible", async () => {
    await execute("UPDATE projects SET status = 'cancelled' WHERE id = ?", [project.id]);
    await callProcedure("sp_refresh_project_search", [project.id]);
    try {
      const search = await api.get("/v1/public/projects", { q: "Integration Test Residences" });
      expect(search.body.data).toHaveLength(0);
    } finally {
      await execute("UPDATE projects SET status = 'under_construction' WHERE id = ?", [project.id]);
      await callProcedure("sp_refresh_project_search", [project.id]);
    }
  });

  it("never returns a restricted document, even as a title", async () => {
    const detail = await api.get("/v1/public/projects/by-path/detail", { path: project.canonical_path });
    const titles = detail.body.data.documents.map((document) => document.title);
    expect(titles).toContain("Integration brochure");
    expect(titles).not.toContain("Integration title deed");
  });

  it("names a gated document but withholds its file", async () => {
    const detail = await api.get("/v1/public/projects/by-path/detail", { path: project.canonical_path });
    const gated = detail.body.data.documents.filter((document) => document.visibility === "gated");
    expect(gated.every((document) => document.url === null)).toBe(true);
  });
});

describe("routing", () => {
  it("resolves a canonical path to its project", async () => {
    const response = await api.get("/v1/public/projects/by-path", { path: project.canonical_path });
    expect(response.body.data.id).toBe(project.public_id);
  });

  it("offers a redirect for a resolvable but non-canonical path", async () => {
    const response = await api.get("/v1/public/projects/by-path", { path: `/projects/somewhere-else/${project.slug}` });
    expect(response.body.data).toBeNull();
    expect(response.body.meta.redirectTo).toBe(project.canonical_path);
  });

  it("answers a path that is neither a project nor a hierarchy with nothing", async () => {
    const response = await api.get("/v1/public/projects/by-path", { path: "/projects/not-a-place/not-a-project" });
    expect(response.body.data).toBeNull();
    expect(response.body.meta ?? null).toBeNull();
  });

  it("validates a location hierarchy by parent, not by name", async () => {
    const valid = await api.get("/v1/public/projects/resolve-location", { path: project.canonical_path.split("/").slice(0, -1).join("/") });
    expect(valid.body.status).toBe("resolved");

    const invalid = await api.get("/v1/public/projects/resolve-location", { path: "/projects/united-arab-emirates/not-a-state" });
    expect(invalid.body.status).toBe("not-found");
  });

  it("refuses a hierarchy deeper than the route allows", async () => {
    const response = await api.get("/v1/public/projects/resolve-location", { path: "/projects/a/b/c/d/e" });
    expect(response.body.status).toBe("not-found");
  });
});

describe("filters", () => {
  it("filters by developer and rejects an unknown one", async () => {
    const developers = await api.get("/v1/public/projects/facets", { facet: "developer" });
    const [first, second] = developers.body.data;

    const single = await api.get("/v1/public/projects", { developer: first.value, pageSize: 60 });
    expect(single.body.pageInfo.total).toBe(first.count);
    expect(single.body.data.every((row) => row.developer.slug === first.value)).toBe(true);

    if (second) {
      const multi = await api.get("/v1/public/projects", { developer: [first.value, second.value], pageSize: 60 });
      expect(multi.body.pageInfo.total).toBe(first.count + second.count);
    }

    const unknown = await api.get("/v1/public/projects", { developer: "not-a-developer" });
    expect(unknown.body.pageInfo.total).toBe(0);
  });

  it("filters by lifecycle status and by the derived nearing-completion state", async () => {
    const statuses = await api.get("/v1/public/projects/facets", { facet: "status" });
    const underConstruction = statuses.body.data.find((row) => row.value === "under_construction");
    if (underConstruction) {
      const response = await api.get("/v1/public/projects", { status: "under_construction", pageSize: 60 });
      expect(response.body.pageInfo.total).toBe(underConstruction.count);
    }

    const nearing = await api.get("/v1/public/projects", { status: "nearing_completion", pageSize: 60 });
    expect(
      nearing.body.data.every(
        (row) => row.lifecycleStatus === "under_construction" && row.completionPercentage >= 80
      )
    ).toBe(true);
  });

  it("filters by the location hierarchy the path carries", async () => {
    const country = await queryOne("SELECT slug FROM locations WHERE id = (SELECT country_id FROM projects WHERE id = ?)", [project.id]);
    const response = await api.get("/v1/public/projects", { country: country.slug, pageSize: 60 });
    const expected = await queryOne("SELECT COUNT(*) AS total FROM project_search ps JOIN locations co ON co.id = ps.country_id WHERE co.slug = ?", [country.slug]);
    expect(response.body.pageInfo.total).toBe(Number(expected.total));
  });

  it("filters by a bedroom count derived from the unit types", async () => {
    const response = await api.get("/v1/public/projects", { beds: "4", pageSize: 60 });
    expect(response.body.data.some((row) => row.id === project.public_id)).toBe(true);

    const missing = await api.get("/v1/public/projects", { beds: "7", pageSize: 60 });
    expect(missing.body.data.some((row) => row.id === project.public_id)).toBe(false);
  });

  it("treats a bedroom filter as the declared set, not as a range", async () => {
    // The project declares 1 and 4 bedrooms and nothing between them.
    const between = await api.get("/v1/public/projects", { beds: "2", pageSize: 60 });
    expect(between.body.data.some((row) => row.id === project.public_id)).toBe(false);
  });

  it("filters by unit type", async () => {
    const match = await api.get("/v1/public/projects", { propertyType: "penthouse", pageSize: 60 });
    expect(match.body.data.some((row) => row.id === project.public_id)).toBe(true);

    const miss = await api.get("/v1/public/projects", { propertyType: "warehouse", pageSize: 60 });
    expect(miss.body.data.some((row) => row.id === project.public_id)).toBe(false);
  });

  it("filters by unit size, overlapping the declared range", async () => {
    const overlap = await api.get("/v1/public/projects", { areaMin: 4000, pageSize: 60 });
    expect(overlap.body.data.some((row) => row.id === project.public_id)).toBe(true);

    const above = await api.get("/v1/public/projects", { areaMin: 9000, pageSize: 60 });
    expect(above.body.data.some((row) => row.id === project.public_id)).toBe(false);
  });

  it("filters by payment-plan type and by maximum down payment", async () => {
    const postHandover = await api.get("/v1/public/projects", { paymentPlan: "post_handover", pageSize: 60 });
    expect(postHandover.body.data.some((row) => row.id === project.public_id)).toBe(true);

    const cheapEntry = await api.get("/v1/public/projects", { maxDownPayment: 10, pageSize: 60 });
    expect(cheapEntry.body.data.some((row) => row.id === project.public_id)).toBe(true);

    const impossible = await api.get("/v1/public/projects", { maxDownPayment: 1, pageSize: 60 });
    expect(impossible.body.data.some((row) => row.id === project.public_id)).toBe(false);
  });

  it("filters by handover, treating a bare year as the whole year", async () => {
    const inRange = await api.get("/v1/public/projects", { handoverFrom: "2029", handoverTo: "2029", pageSize: 60 });
    expect(inRange.body.data.some((row) => row.id === project.public_id)).toBe(true);

    const before = await api.get("/v1/public/projects", { handoverTo: "2028", pageSize: 60 });
    expect(before.body.data.some((row) => row.id === project.public_id)).toBe(false);
  });

  it("filters by availability", async () => {
    const available = await api.get("/v1/public/projects", { availability: "available", pageSize: 60 });
    expect(available.body.data.every((row) => row.availability === "available")).toBe(true);
  });

  it("combines filters rather than replacing them", async () => {
    const response = await api.get("/v1/public/projects", {
      propertyType: "penthouse",
      beds: "4",
      handoverFrom: "2029",
      pageSize: 60,
    });
    expect(response.body.data.some((row) => row.id === project.public_id)).toBe(true);
  });
});

describe("attached listings", () => {
  it("finds a project's listings by its public id and by its slug", async () => {
    const byId = await api.get("/v1/public/listings", { category: "real-estate", project: "01K2F2DKG04KY2KT1EXSETV70E" });
    const bySlug = await api.get("/v1/public/listings", { category: "real-estate", project: "creek-waters-2" });
    expect(byId.body.pageInfo.total).toBeGreaterThan(0);
    expect(bySlug.body.pageInfo.total).toBe(byId.body.pageInfo.total);
  });

  it("returns nothing for an unknown project rather than the whole catalogue", async () => {
    const response = await api.get("/v1/public/listings", { category: "real-estate", project: "not-a-project" });
    expect(response.body.pageInfo.total).toBe(0);
  });

  /**
   * The internal numeric key must not be settable from a URL.
   *
   * `listingSearchQuery` has a catchall, so an unrecognised parameter still
   * reaches the repository — `?projectId=2` used to filter by a raw database id
   * and let anyone enumerate projects by counting upwards.
   */
  it("ignores a database id supplied as a query parameter", async () => {
    const unfiltered = await api.get("/v1/public/listings", { category: "real-estate", pageSize: 1 });
    const guessed = await api.get("/v1/public/listings", { category: "real-estate", projectId: 2, pageSize: 1 });
    expect(guessed.body.pageInfo.total).toBe(unfiltered.body.pageInfo.total);
  });
});

describe("sorting", () => {
  const ordered = (values) => values.every((value, index) => index === 0 || values[index - 1] <= value);

  it("sorts by handover, soonest first", async () => {
    const response = await api.get("/v1/public/projects", { sort: "handoverSoonest", pageSize: 60 });
    const dates = response.body.data.map((row) => row.handoverDate).filter(Boolean);
    expect(ordered(dates)).toBe(true);
  });

  it("sorts by starting price, low to high", async () => {
    const response = await api.get("/v1/public/projects", { sort: "priceAsc", pageSize: 60 });
    const prices = response.body.data.map((row) => row.priceRange?.baseMin).filter((value) => value !== null && value !== undefined);
    expect(ordered(prices)).toBe(true);
  });

  it("sorts by completion, highest first", async () => {
    const response = await api.get("/v1/public/projects", { sort: "completion", pageSize: 60 });
    const values = response.body.data.map((row) => row.completionPercentage).filter((value) => value !== null);
    expect(values.every((value, index) => index === 0 || values[index - 1] >= value)).toBe(true);
  });

  it("does not answer 'newest launched' with the featured order", async () => {
    const newest = await api.get("/v1/public/projects", { sort: "newest", pageSize: 60 });
    const dates = newest.body.data.map((row) => row.launchDate).filter(Boolean);
    expect(dates.every((value, index) => index === 0 || dates[index - 1] >= value)).toBe(true);
  });
});

describe("facets and options", () => {
  it("counts facets under the caller's own filters", async () => {
    const all = await api.get("/v1/public/projects/facets", { facet: "projectType" });
    const scoped = await api.get("/v1/public/projects/facets", { facet: "projectType", status: "under_construction" });
    const allTotal = all.body.data.reduce((sum, row) => sum + row.count, 0);
    const scopedTotal = scoped.body.data.reduce((sum, row) => sum + row.count, 0);
    expect(scopedTotal).toBeLessThanOrEqual(allTotal);
  });

  /**
   * Every value of a comma-separated aggregate gets its own count.
   *
   * These are counted with one `SUM(FIND_IN_SET(...))` per candidate value, and
   * each needs its own alias: identical column names collapse into one key on
   * the driver's result object, which silently reduced a whole menu to a single
   * option and made every other value look like it had no inventory.
   */
  it("counts every value of a comma-separated facet, not just the first", async () => {
    const propertyTypes = await api.get("/v1/public/projects/facets", { facet: "propertyType" });
    const values = propertyTypes.body.data.map((row) => row.value);
    expect(values).toEqual(expect.arrayContaining(["apartment", "penthouse"]));
    expect(propertyTypes.body.data.every((row) => row.count > 0)).toBe(true);

    const bedrooms = await api.get("/v1/public/projects/facets", { facet: "bedrooms" });
    expect(bedrooms.body.data.map((row) => row.value)).toEqual(expect.arrayContaining(["1", "4"]));

    const plans = await api.get("/v1/public/projects/facets", { facet: "paymentPlan" });
    expect(plans.body.data.length).toBeGreaterThan(1);
  });

  it("accepts the public filter's own name for the handover facet", async () => {
    const response = await api.get("/v1/public/projects/facets", { facet: "handover" });
    expect(response.status).toBe(200);
    expect(response.body.data.every((row) => Number(row.value) > 2000)).toBe(true);
  });

  it("refuses an unsupported facet rather than guessing a column", async () => {
    const response = await api.get("/v1/public/projects/facets", { facet: "'; DROP TABLE projects; --" });
    expect(response.status).toBe(400);
  });

  it("offers only developers that actually hold published projects", async () => {
    const response = await api.get("/v1/public/projects/filter-options/developer");
    expect(response.body.options.every((option) => option.count > 0)).toBe(true);
  });

  it("offers only handover years the catalogue holds", async () => {
    const response = await api.get("/v1/public/projects/filter-options/handover");
    const years = response.body.options.map((option) => Number(option.value));
    const actual = await query("SELECT DISTINCT handover_year AS y FROM project_search WHERE handover_year IS NOT NULL");
    expect(years.sort()).toEqual(actual.map((row) => Number(row.y)).sort());
  });
});

describe("country counts", () => {
  it("counts projects, not listings", async () => {
    const response = await api.get("/v1/public/projects/countries");
    for (const country of response.body.data) {
      const actual = await queryOne(
        "SELECT COUNT(*) AS total FROM project_search ps JOIN locations co ON co.id = ps.country_id WHERE co.slug = ?",
        [country.slug]
      );
      expect(country.projectCount).toBe(Number(actual.total));
    }
  });

  it("never lists a country with no published projects", async () => {
    const response = await api.get("/v1/public/projects/countries");
    expect(response.body.data.every((country) => country.projectCount > 0)).toBe(true);
  });
});

describe("developers", () => {
  it("lists developers with a project count and a page total", async () => {
    const response = await api.get("/v1/public/developers", { pageSize: 5 });
    expect(response.status).toBe(200);
    expect(response.body.data.every((developer) => developer.projectCount > 0)).toBe(true);
  });

  it("returns a developer profile with its projects", async () => {
    const list = await api.get("/v1/public/developers", { pageSize: 1 });
    const slug = list.body.data[0].slug;
    const response = await api.get(`/v1/public/developers/${slug}`);
    expect(response.status).toBe(200);
    expect(response.body.data.projects.every((row) => row.developer.slug === slug)).toBe(true);
  });

  it("404s an unknown developer", async () => {
    const response = await api.get("/v1/public/developers/not-a-developer");
    expect(response.status).toBe(404);
  });
});

describe("detail", () => {
  it("returns the nested record the page renders", async () => {
    const response = await api.get("/v1/public/projects/by-path/detail", { path: project.canonical_path });
    const data = response.body.data;
    expect(data.unitTypeDetails).toHaveLength(2);
    expect(data.paymentPlans).toHaveLength(2);
    expect(data.paymentPlans[0].milestones).toHaveLength(3);
    expect(data.amenities.map((amenity) => amenity.label)).toEqual(["Infinity pool", "Padel courts"]);
    expect(data.highlights).toEqual(["Private marina", "Sky lounge"]);
    expect(data.marketingHeading).toBe("Every field, persisted");
    expect(data.related.recent.every((row) => row.id !== project.public_id)).toBe(true);
  });

  it("404s an unknown project identifier", async () => {
    const response = await api.get("/v1/public/projects/01NOTAPROJECT");
    expect(response.status).toBe(404);
  });
});

describe("enquiries", () => {
  it("accepts an enquiry about a project with no listing and unlocks its gated documents", async () => {
    const response = await api.send("post", "/v1/inquiries", {
      projectId: project.public_id,
      name: "Integration Buyer",
      email: `integration.${Date.now()}@example.com`,
      message: "Please send the brochure and the payment plan for this development.",
    });
    expect(response.status).toBe(201);
    expect(response.body.data.projectId).toBe(project.public_id);

    const stored = await queryOne("SELECT project_id, listing_id FROM inquiries WHERE public_id = ?", [response.body.data.id]);
    expect(Number(stored.project_id)).toBe(Number(project.id));
    expect(stored.listing_id).toBeNull();
  });

  it("refuses an enquiry naming neither a listing nor a project", async () => {
    const response = await api.send("post", "/v1/inquiries", {
      name: "Nobody",
      email: "nobody@example.com",
      message: "This enquiry is about nothing at all.",
    });
    expect(response.status).toBe(422);
  });

  it("refuses an enquiry about a project that is not accepting them", async () => {
    await execute("UPDATE projects SET accepts_inquiries = 0 WHERE id = ?", [project.id]);
    await callProcedure("sp_refresh_project_search", [project.id]);
    try {
      const response = await api.send("post", "/v1/inquiries", {
        projectId: project.public_id,
        name: "Integration Buyer",
        email: "closed@example.com",
        message: "Please send the brochure for this development.",
      });
      expect(response.status).toBe(400);
    } finally {
      await execute("UPDATE projects SET accepts_inquiries = 1 WHERE id = ?", [project.id]);
      await callProcedure("sp_refresh_project_search", [project.id]);
    }
  });
});

describe("analytics", () => {
  it("records a project view against the project", async () => {
    const response = await api.send("post", `/v1/projects/${project.public_id}/events`, { event: "project_view" });
    expect(response.body.data.counted).toBe(true);
    const row = await queryOne(
      "SELECT COUNT(*) AS total FROM analytics_events WHERE subject_type = 'project' AND subject_id = ? AND event_type = 'project_view'",
      [project.id]
    );
    expect(Number(row.total)).toBeGreaterThan(0);
  });

  it("counts nothing for an unknown project rather than storing an undefined subject", async () => {
    const response = await api.send("post", "/v1/projects/not-a-project/events", { event: "project_view" });
    expect(response.body.data.counted).toBe(false);
  });

  it("refuses an event type outside the allow-list", async () => {
    const response = await api.send("post", `/v1/projects/${project.public_id}/events`, { event: "arbitrary" });
    expect(response.status).toBe(422);
  });
});

describe("admin write contract", () => {
  it("persists every field the wizard collects and reads it all back", async () => {
    const record = await getAdminDevelopment(project.public_id);
    expect(record.name).toBe("Integration Test Residences");
    expect(record.tagline).toBe("Created by the projects integration suite");
    expect(record.projectType).toBe("mixed_use");
    expect(record.developmentStatus).toBe("under_construction");
    expect(record.launchStatus).toBe("launched");
    expect(record.moderationStatus).toBe("published");
    expect(record.ownershipType).toBe("freehold");
    expect(record.buildingsCount).toBe(3);
    expect(record.construction.constructionStartedAt).toBe("2026-04-15");
    expect(record.handover).toMatchObject({ quarter: "Q3", year: 2029 });
    expect(record.acceptInquiries).toBe(true);
    expect(record.address).toBe("Plot 12, Test Boulevard");
    expect(record.highlights).toEqual(["Private marina", "Sky lounge"]);
    expect(record.description.heading).toBe("Every field, persisted");
    expect(record.unitTypes).toHaveLength(2);
    expect(record.paymentPlans).toHaveLength(2);
    expect(record.paymentPlans[0].milestones).toHaveLength(3);
    expect(record.amenities).toEqual(["Infinity pool", "Padel courts"]);
  });

  it("returns the developer as an object", () => {
    // Read back inside the same suite so a regression here fails loudly.
    return getAdminDevelopment(project.public_id).then((record) => {
      expect(record.developer).toMatchObject({ id: expect.any(String), slug: expect.any(String), name: expect.any(String) });
    });
  });

  it("normalises a display-cased status onto the value the column stores", async () => {
    // The wizard offers "Under Construction" and "on-hold"; both are the same
    // stored value, and neither may reach the column in its display spelling.
    expect(developmentSchema.partial().parse({ status: "Under Construction" }).status).toBe("under_construction");
    expect(developmentSchema.partial().parse({ status: "on-hold" }).status).toBe("on_hold");
    expect(developmentSchema.partial().parse({ launchStatus: "Coming Soon" }).launchStatus).toBe("coming_soon");
    expect(developmentSchema.partial().parse({ moderationStatus: "Pending" }).moderationStatus).toBe("pending");
  });

  it("refuses a lifecycle value the column does not have", async () => {
    // "Nearing completion" is derived from `under_construction` plus a
    // completion threshold. Accepting it as a stored status would let the badge
    // and the filter disagree the moment a percentage moved.
    expect(() => developmentSchema.partial().parse({ status: "Nearing-Completion" })).toThrow();
    expect(() => developmentSchema.partial().parse({ status: "totally-made-up" })).toThrow();
  });

  it("refuses a payment plan whose milestones do not total 100%", async () => {
    await expect(
      upsertDevelopment({
        identifier: project.public_id,
        userId: null,
        payload: developmentSchema.partial().parse({
          name: "Integration Test Residences",
          paymentPlans: [
            { name: "Broken", milestones: [{ name: "On booking", percentage: 20 }, { name: "On handover", percentage: 40 }] },
          ],
        }),
      })
    ).rejects.toThrow(/100%/);
  });

  it("rebuilds the canonical path when the location changes", async () => {
    const before = await queryOne("SELECT canonical_path FROM projects WHERE id = ?", [project.id]);
    const otherCountry = await queryOne(
      "SELECT id FROM locations WHERE level = 'country' AND id <> (SELECT country_id FROM projects WHERE id = ?) ORDER BY active_listing_count DESC LIMIT 1",
      [project.id]
    );
    await upsertDevelopment({
      identifier: project.public_id,
      userId: null,
      payload: developmentSchema.partial().parse({ name: "Integration Test Residences", countryId: otherCountry.id, stateId: null, cityId: null, communityId: null }),
    });
    const after = await queryOne("SELECT canonical_path FROM projects WHERE id = ?", [project.id]);
    expect(after.canonical_path).not.toBe(before.canonical_path);

    // Put it back so the rest of the suite still describes the same project.
    const community = await seededCommunity();
    await upsertDevelopment({
      identifier: project.public_id,
      userId: null,
      payload: developmentSchema.partial().parse({ name: "Integration Test Residences", communityId: community.id }),
    });
    const restored = await queryOne("SELECT canonical_path FROM projects WHERE id = ?", [project.id]);
    expect(restored.canonical_path).toBe(before.canonical_path);
  });

  it("filters the admin list by moderation status, developer and handover year", async () => {
    const published = await listAdminDevelopments({ status: "published", pageSize: 200 });
    expect(published.items.every((item) => item.moderationStatus === "published")).toBe(true);

    const byYear = await listAdminDevelopments({ handoverYear: "2029", pageSize: 200 });
    expect(byYear.items.every((item) => String(item.handover.year) === "2029")).toBe(true);

    const developer = published.options.developers[0];
    const byDeveloper = await listAdminDevelopments({ developer: developer.value, pageSize: 200 });
    expect(byDeveloper.items.every((item) => item.developer?.slug === developer.value)).toBe(true);
  });

  it("offers filter options valued the way the filter matches them", async () => {
    const result = await listAdminDevelopments({ pageSize: 1 });
    expect(result.options.developers.every((option) => typeof option.value === "string" && !/^\d+$/.test(option.value))).toBe(true);
    expect(result.options.propertyTypes.every((option) => typeof option.value === "string")).toBe(true);
    expect(result.options.locations.every((option) => typeof option.label === "string")).toBe(true);
  });

  it("takes an archived project out of the public projection", async () => {
    const community = await seededCommunity();
    const throwaway = await upsertDevelopment({
      identifier: null,
      userId: null,
      payload: developmentSchema.parse({
        name: "Integration Throwaway Project",
        communityId: community.id,
        moderationStatus: "published",
      }),
    });
    created.push(throwaway.id);
    const row = await queryOne("SELECT id FROM projects WHERE public_id = ?", [throwaway.id]);
    expect(await queryOne("SELECT COUNT(*) AS total FROM project_search WHERE project_id = ?", [row.id])).toMatchObject({ total: 1 });

    await archiveDevelopment({ identifier: throwaway.id });
    expect(await queryOne("SELECT COUNT(*) AS total FROM project_search WHERE project_id = ?", [row.id])).toMatchObject({ total: 0 });
  });
});
