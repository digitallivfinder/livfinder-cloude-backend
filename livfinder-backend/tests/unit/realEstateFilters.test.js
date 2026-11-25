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

  it("applies no Market outside real estate, and Listed by only where the marketplace offers it", async () => {
    const cars = await buildSearchQuery({ category: "cars", market: "resale", listedBy: "company,developer" });
    expect(cars.where).not.toContain("is_new_build");
    // Cars: Dealer and Private seller only; a Developer is real estate's alone.
    expect(cars.where).toContain("a_seller.seller_type IN (?)");
    expect(cars.params).toContain("company");
    expect(cars.params).not.toContain("developer");
    // Every marketplace has Listed by since 2026-11-25; an unknown seller type is never searched.
    const watches = await buildSearchQuery({ category: "watches", listedBy: "developer" });
    expect(watches.where).not.toContain("seller_type");
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

describe("cars: listed by and condition", () => {
  it("names Dealer and Private seller, with no Developer", async () => {
    const { sellerTypeOptions } = await import("../../src/modules/search/marketAndSeller.js");
    const options = sellerTypeOptions(["individual", "company", "developer", "family_office"], "cars");
    expect(options.map((option) => [option.value, option.label])).toEqual([
      ["company", "Dealer"],
      ["individual", "Private seller"],
    ]);
    expect(sellerTypeOptions(["company"], "real-estate-developments")).toEqual([]);
  });

  it("offers New, Used and Certified pre-owned, in that order", async () => {
    const { CAR_CONDITION_OPTIONS } = await import("../../src/modules/search/marketAndSeller.js");
    expect(CAR_CONDITION_OPTIONS.map((option) => option.value)).toEqual(["new", "used", "certified_pre_owned"]);
  });
});

describe("only real estate rents", () => {
  it("accepts only sale outside real estate; real estate keeps rent", async () => {
    const { CATEGORY_PURPOSES } = await import("../../src/utils/categories.js");
    for (const category of ["cars", "yachts", "jets", "helicopters", "watches"]) expect(CATEGORY_PURPOSES[category]).toEqual(["sale"]);
    expect(CATEGORY_PURPOSES["real-estate"]).toEqual(["sale", "rent"]);
  });

  it("drops the retired charter fields instead of refusing them", async () => {
    const { withoutRetiredDetails } = await import("../../src/modules/listings/listings.schemas.js");
    expect(withoutRetiredDetails("jets", { yearBuilt: 2020, isCharterAvailable: true, charterHourlyRate: 9000 })).toEqual({ yearBuilt: 2020 });
    expect(withoutRetiredDetails("yachts", { cabins: 4, isCharterAvailable: false })).toEqual({ cabins: 4 });
    const car = { mileageKm: 10 };
    expect(withoutRetiredDetails("cars", car)).toBe(car);
  });
});

describe("yachts: type and listed by", () => {
  it("offers Motor, Sailing, Catamaran, Superyacht; Superyacht also finds mega yachts", async () => {
    const { YACHT_TYPE_OPTIONS, yachtTypeValues } = await import("../../src/modules/search/marketAndSeller.js");
    expect(YACHT_TYPE_OPTIONS.map((option) => option.label)).toEqual(["Motor", "Sailing", "Catamaran", "Superyacht"]);
    expect(yachtTypeValues("superyacht")).toEqual(["superyacht", "mega_yacht"]);
    expect(yachtTypeValues("catamaran")).toEqual(["catamaran"]);
  });

  it("names the sellers Broker and Private owner, never Developer", async () => {
    const { sellerTypeOptions, sellerTypesFor } = await import("../../src/modules/search/marketAndSeller.js");
    expect(sellerTypeOptions(["developer", "company", "individual"], "yachts").map((option) => option.label)).toEqual(["Broker", "Private owner"]);
    expect(sellerTypesFor("yachts", ["developer", "company"])).toEqual(["company"]);
  });
});

describe("jets: size and listed by", () => {
  it("groups aircraft types into Light, Midsize, Heavy, Ultra long range", async () => {
    const { aircraftSizeOptions, aircraftSizeTypes } = await import("../../src/modules/search/marketAndSeller.js");
    expect(aircraftSizeOptions("jets").map((option) => option.label)).toEqual(["Light", "Midsize", "Heavy", "Ultra long range"]);
    expect(aircraftSizeTypes("jets", "light")).toEqual(["very_light_jet", "light_jet"]);
    expect(aircraftSizeTypes("jets", "heavy")).toEqual(["heavy_jet", "vip_airliner"]);
    expect(aircraftSizeTypes("jets", "nonsense")).toEqual([]);
    expect(aircraftSizeOptions("watches")).toEqual([]);
  });

  it("names the sellers Broker and Private owner", async () => {
    const { sellerTypeOptions } = await import("../../src/modules/search/marketAndSeller.js");
    expect(sellerTypeOptions(["developer", "company", "individual"], "jets").map((option) => option.label)).toEqual(["Broker", "Private owner"]);
  });
});

describe("helicopters: size and listed by", () => {
  it("offers Light, Medium, Heavy from the helicopter types, and Broker / Private owner", async () => {
    const { aircraftSizeOptions, aircraftSizeTypes, sellerTypeOptions } = await import("../../src/modules/search/marketAndSeller.js");
    expect(aircraftSizeOptions("helicopters").map((option) => option.label)).toEqual(["Light", "Medium", "Heavy"]);
    expect(aircraftSizeTypes("helicopters", "medium")).toEqual(["medium_helicopter"]);
    expect(sellerTypeOptions(["developer", "company", "individual"], "helicopters").map((option) => option.label)).toEqual(["Broker", "Private owner"]);
  });
});

describe("watches: condition, full set, gender, case material, listed by", () => {
  it("groups the condition grades into Unworn and Pre-owned", async () => {
    const { WATCH_CONDITION_OPTIONS, watchConditionGrades } = await import("../../src/modules/search/marketAndSeller.js");
    expect(WATCH_CONDITION_OPTIONS.map((option) => option.label)).toEqual(["Unworn", "Pre-owned"]);
    expect(watchConditionGrades("unworn")).toEqual(["new", "unworn"]);
    expect(watchConditionGrades("pre_owned")).toContain("restored");
    expect(watchConditionGrades("excellent")).toEqual(["excellent"]);
  });

  it("matches a case material by the words sellers write", async () => {
    const { caseMaterialWords } = await import("../../src/modules/search/marketAndSeller.js");
    expect(caseMaterialWords("rose_gold")).toContain("everose");
    expect(caseMaterialWords("bronze")).toEqual(["bronze"]);
  });

  it("names the sellers Dealer and Private seller, and the genders as buyers say them", async () => {
    const { sellerTypeOptions, watchGenderOptions } = await import("../../src/modules/search/marketAndSeller.js");
    expect(sellerTypeOptions(["developer", "company", "individual"], "watches").map((option) => option.label)).toEqual(["Dealer", "Private seller"]);
    expect(watchGenderOptions(["mens", "ladies", "unisex"]).map((option) => option.label)).toEqual(["Men's", "Women's", "Unisex"]);
  });

  it("searches rose gold on the watch's own case material", async () => {
    const { buildSearchQuery } = await import("../../src/modules/search/search.repository.js");
    const query = await buildSearchQuery({ category: "watches", caseMaterial: "rose_gold", condition: "unworn" });
    expect(query.where).toContain("case_material LIKE ?");
    expect(query.params).toEqual(expect.arrayContaining(["%everose%", "new", "unworn"]));
  });
});
