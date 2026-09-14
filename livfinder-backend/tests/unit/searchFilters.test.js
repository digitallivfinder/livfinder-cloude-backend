import { describe, expect, it } from "vitest";
import { normalizeSearchInput, SPEC_MAP, SORT_MAP, RANGE_FILTERS, FACET_FILTERS } from "../../src/modules/search/searchFilters.js";
import { CATEGORY_DEFINITIONS } from "../../src/utils/categories.js";
import { paginationFrom, listResponse, cursorResponse, asArray, toBool, cleanString, MAX_PAGE_SIZE } from "../../src/utils/http.js";

describe("search filter normalisation", () => {
  it("resolves the category from any vocabulary", () => {
    expect(normalizeSearchInput({ category: "real-estate" }).rootCategoryId).toBe(1);
    expect(normalizeSearchInput({ category: "car" }).listingType).toBe("cars");
    expect(normalizeSearchInput({ listingType: "watches" }).rootCategoryId).toBe(6);
  });

  it("maps the frontend transaction type onto a purpose slug", () => {
    expect(normalizeSearchInput({ transactionType: "buy" }).purposeSlug).toBe("for-sale");
    expect(normalizeSearchInput({ transactionType: "rent" }).purposeSlug).toBe("for-rent");
    expect(normalizeSearchInput({ purpose: "charter" }).purposeSlug).toBe("for-charter");
    expect(normalizeSearchInput({}).purposeSlug).toBeNull();
  });

  it("accepts both price spellings and coerces to numbers", () => {
    expect(normalizeSearchInput({ minPrice: "1000", maxPrice: "5000" })).toMatchObject({ minPrice: 1000, maxPrice: 5000 });
    expect(normalizeSearchInput({ priceMin: "250" }).minPrice).toBe(250);
    expect(normalizeSearchInput({ minPrice: "not a number" }).minPrice).toBeNull();
  });

  it("takes bedroom chips as a list, whatever the caller sent", () => {
    expect(normalizeSearchInput({ beds: "3,4,5" }).bedrooms).toEqual([3, 4, 5]);
    expect(normalizeSearchInput({ bedrooms: ["3", "4"] }).bedrooms).toEqual([3, 4]);
    expect(normalizeSearchInput({}).bedrooms).toEqual([]);
  });

  it("collects every supplied location level into one list", () => {
    const filters = normalizeSearchInput({ country: "uae", city: "dubai", location: ["community:3", "city:2"] });
    expect(filters.locations).toContain("community:3");
    expect(filters.locations).toContain("dubai");
    expect(filters.country).toBe("uae");
  });

  it("only accepts a sort key that has a prepared ORDER BY", () => {
    expect(normalizeSearchInput({ sort: "priceDesc" }).sort).toBe("priceDesc");
    // An unknown key falls back rather than reaching SQL.
    expect(normalizeSearchInput({ sort: "id; DROP TABLE listings" }).sort).toBe("featured");
  });

  it("reads only the range and facet keys defined for the category", () => {
    const cars = normalizeSearchInput({ category: "cars", yearMin: "2020", mileageMax: "50000", transmission: "automatic", furnishing: "furnished" });
    expect(cars.ranges.yearMin).toBe(2020);
    expect(cars.ranges.mileageMax).toBe(50000);
    expect(cars.facets.transmission).toBe("automatic");
    // A real-estate facet is not a car facet.
    expect(cars.facets.furnishing).toBeUndefined();
  });

  it("caps a keyword rather than passing an unbounded string", () => {
    const long = "x".repeat(500);
    expect(normalizeSearchInput({ keyword: long }).keyword).toHaveLength(120);
  });
});

describe("filter registry coverage", () => {
  it("defines a spec map for every marketplace category", () => {
    // Developments are projects, not listings — searched via `project_search`,
    // not the listing filter registry. Every category with a listing detail
    // table must be covered here.
    for (const definition of CATEGORY_DEFINITIONS.filter((entry) => entry.detailTable)) {
      expect(SPEC_MAP[definition.listingType], definition.listingType).toBeDefined();
      expect(RANGE_FILTERS[definition.listingType], definition.listingType).toBeDefined();
      expect(FACET_FILTERS[definition.listingType], definition.listingType).toBeDefined();
    }
  });

  it("only exposes sort keys that are fixed SQL fragments", () => {
    for (const fragment of Object.values(SORT_MAP)) {
      expect(fragment).toMatch(/^ls\./);
      expect(fragment).not.toContain(";");
    }
  });
});

describe("http helpers", () => {
  it("clamps pagination to sane bounds", () => {
    expect(paginationFrom({ page: 0, pageSize: 0 })).toMatchObject({ page: 1, pageSize: 20 });
    expect(paginationFrom({ page: 3, pageSize: 10 })).toMatchObject({ page: 3, pageSize: 10, offset: 20 });
    expect(paginationFrom({ pageSize: 5000 }).pageSize).toBe(MAX_PAGE_SIZE);
  });

  it("reports total pages and whether more remain", () => {
    const response = listResponse([1, 2], { page: 1, pageSize: 2, total: 5 });
    expect(response.pageInfo).toMatchObject({ totalPages: 3, hasMore: true });
    expect(listResponse([], { page: 3, pageSize: 2, total: 5 }).pageInfo.hasMore).toBe(false);
  });

  it("advances a cursor only while rows remain", () => {
    expect(cursorResponse([1, 2], { cursor: 0, pageSize: 2, total: 5 }).pageInfo.nextCursor).toBe("2");
    expect(cursorResponse([1], { cursor: 4, pageSize: 2, total: 5 }).pageInfo.nextCursor).toBeNull();
  });

  it("normalises list and boolean query values", () => {
    expect(asArray("a,b,c")).toEqual(["a", "b", "c"]);
    expect(asArray(["a", ""])).toEqual(["a"]);
    expect(asArray(undefined)).toEqual([]);
    expect([toBool("1"), toBool("true"), toBool("no"), toBool(undefined)]).toEqual([true, true, false, false]);
    expect(cleanString("  hello  ")).toBe("hello");
    expect(cleanString("   ")).toBeNull();
    expect(cleanString("x".repeat(50), 10)).toHaveLength(10);
  });
});
