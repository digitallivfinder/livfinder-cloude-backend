import { beforeEach, describe, expect, it, vi } from "vitest";

const query = vi.fn();
const queryValue = vi.fn();
vi.mock("../../src/db/query.js", () => ({ query, queryValue }));

const { buildSearchQuery } = await import("../../src/modules/search/search.repository.js");
const { normalizeSearchInput, parseCountChips, parseAmenities } = await import("../../src/modules/search/searchFilters.js");
const { segmentCondition } = await import("../../src/modules/search/propertySegments.js");

beforeEach(() => {
  query.mockReset();
  queryValue.mockReset();
});

describe("bedroom and bathroom chips", () => {
  it("reads exact counts and an 8+ minimum", () => {
    expect(parseCountChips(["0", "1", "8+"])).toEqual({ exact: [0, 1], atLeast: 8 });
    expect(parseCountChips("8+")).toEqual({ exact: [], atLeast: 8 });
    expect(parseCountChips(["6+", "8+"])).toEqual({ exact: [], atLeast: 6 });
    expect(parseCountChips(["x", "-1"])).toEqual({ exact: [], atLeast: null });
  });

  it("matches the exact counts or eight-plus in one condition", async () => {
    const built = await buildSearchQuery({ category: "real-estate", bedrooms: ["0", "1", "8+"] });
    expect(built.where).toContain("(ls.spec_a IN (?, ?) OR ls.spec_a >= ?)");
    expect(built.params).toEqual(expect.arrayContaining([0, 1, 8]));
  });

  it("uses a bare minimum for 8+ alone", async () => {
    const built = await buildSearchQuery({ category: "real-estate", bathrooms: "8+" });
    expect(built.where).toContain("ls.spec_b >= ?");
    expect(built.where).not.toContain("ls.spec_b IN");
  });
});

describe("rent duration", () => {
  it("maps the filter's words onto the projection's price period", async () => {
    expect(normalizeSearchInput({ category: "real-estate", rentPeriod: "monthly" }).rentPeriod).toBe("month");
    expect(normalizeSearchInput({ category: "real-estate", rentPeriod: "hourly" }).rentPeriod).toBeNull();
    const built = await buildSearchQuery({ category: "real-estate", transactionType: "rent", rentPeriod: "yearly" });
    expect(built.where).toContain("ls.price_period = ?");
    expect(built.params).toContain("year");
  });
});

describe("residential / commercial", () => {
  it("searches the segment each listing stores", () => {
    expect(segmentCondition("commercial")).toEqual({ sql: "ls.property_segment = ?", params: ["commercial"] });
    expect(segmentCondition("residential")).toEqual({ sql: "ls.property_segment = ?", params: ["residential"] });
    expect(segmentCondition("industrial")).toBeNull();
  });

  it("filters the search on the segment, from either spelling", async () => {
    const built = await buildSearchQuery({ category: "real-estate", segment: "commercial" });
    expect(built.where).toContain("ls.property_segment = ?");
    expect(built.params).toContain("commercial");
    expect(normalizeSearchInput({ category: "real-estate", propertySegment: "nope" }).propertySegment).toBeNull();
  });
});

describe("amenities", () => {
  it("keeps clean slugs only, de-duplicated and capped", () => {
    expect(parseAmenities(["Private-Pool", "private-pool", "bad slug", "'; DROP"])).toEqual(["private-pool"]);
    expect(parseAmenities(Array.from({ length: 30 }, (_, i) => `a${i}`))).toHaveLength(20);
  });

  it("requires every chosen amenity", async () => {
    const built = await buildSearchQuery({ category: "real-estate", amenities: ["private-pool", "private-gym"] });
    expect(built.where).toContain("HAVING COUNT(DISTINCT f.id) = ?");
    expect(built.params.slice(-3)).toEqual(["private-pool", "private-gym", 2]);
  });

  it("is ignored outside real estate", async () => {
    const built = await buildSearchQuery({ category: "watches", amenities: ["private-pool"] });
    expect(built.where).not.toContain("listing_features");
  });
});

describe("off plan", () => {
  it("also finds listings still stored as under construction", async () => {
    for (const value of ["off_plan", "under_construction"]) {
      const built = await buildSearchQuery({ category: "real-estate", completionStatus: value });
      expect(built.where).toContain("ls.facet_b IN ('off_plan', 'under_construction')");
    }
  });
});

describe("ready", () => {
  it("includes shell and core, which is never a status of its own", async () => {
    for (const value of ["ready", "shell_and_core"]) {
      const built = await buildSearchQuery({ category: "real-estate", completionStatus: value });
      expect(built.where).toContain("ls.facet_b IN ('ready', 'shell_and_core')");
    }
  });
});

describe("market and listed by", () => {
  it("reads market and seller types from the query, ignoring anything unknown", () => {
    expect(normalizeSearchInput({ category: "real-estate", market: "New_Launch" }).market).toBe("new_launch");
    expect(normalizeSearchInput({ category: "real-estate", market: "secondhand" }).market).toBeNull();
    expect(normalizeSearchInput({ category: "real-estate", listedBy: "developer,company" }).sellerTypes).toEqual(["developer", "company"]);
    expect(normalizeSearchInput({ category: "real-estate", listedBy: ["owner; DROP", "individual"] }).sellerTypes).toEqual(["individual"]);
  });

  it("filters New Launch and Resale on the new-build flag", async () => {
    const launch = await buildSearchQuery({ category: "real-estate", market: "new_launch" });
    expect(launch.where).toContain("d_mkt.is_new_build = ?");
    expect(launch.params).toContain(1);
    const resale = await buildSearchQuery({ category: "real-estate", market: "resale" });
    expect(resale.params).toContain(0);
  });

  it("filters on the seller account's type", async () => {
    const built = await buildSearchQuery({ category: "real-estate", listedBy: "developer,individual" });
    expect(built.where).toContain("a_seller.seller_type IN (?, ?)");
    expect(built.params).toEqual(expect.arrayContaining(["developer", "individual"]));
  });

  it("applies neither outside real estate", async () => {
    const built = await buildSearchQuery({ category: "cars", market: "resale", listedBy: "company" });
    expect(built.where).not.toContain("is_new_build");
    expect(built.where).not.toContain("seller_type");
  });
});

describe("listed by options", () => {
  it("names the seller types as buyers do, in the menu's order, keeping newer values", async () => {
    const { sellerTypeOptions } = await import("../../src/modules/search/marketAndSeller.js");
    const options = sellerTypeOptions(["individual", "company", "developer", "family_office"]);
    expect(options.map((option) => [option.value, option.label])).toEqual([
      ["developer", "Developer"],
      ["company", "Agency"],
      ["individual", "Owner"],
      ["family_office", "Family Office"],
    ]);
    expect(options[0].hint).toBe("New launches");
  });
});
