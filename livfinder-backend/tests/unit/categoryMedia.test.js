import { describe, expect, it } from "vitest";
import {
  categoryAllowsMedia,
  categoryDocumentTypes,
  resolveCategoryMediaPolicy,
} from "../../src/utils/categoryMedia.js";
import { CATEGORY_DEFINITIONS } from "../../src/utils/categories.js";

describe("category media policy", () => {
  it("allows floor plans and virtual tours only for real estate and developments", () => {
    for (const value of ["real-estate", "real-estate-developments", 1, 7]) {
      expect(categoryAllowsMedia(value, "floor_plan")).toBe(true);
      expect(categoryAllowsMedia(value, "virtual_tour")).toBe(true);
    }
    for (const value of ["cars", "yachts", "jets", "helicopters", "watches"]) {
      expect(categoryAllowsMedia(value, "floor_plan")).toBe(false);
      expect(categoryAllowsMedia(value, "virtual_tour")).toBe(false);
      expect(categoryAllowsMedia(value, "video")).toBe(true);
    }
  });

  it("gives every category a non-empty, valid document type list", () => {
    for (const definition of CATEGORY_DEFINITIONS) {
      const types = categoryDocumentTypes(definition.listingType);
      expect(types.length).toBeGreaterThan(0);
      expect(types).toContain("other");
    }
  });

  it("uses category-specific document types", () => {
    expect(categoryDocumentTypes("real-estate")).toContain("title_deed");
    expect(categoryDocumentTypes("real-estate")).not.toContain("registration");
    expect(categoryDocumentTypes("cars")).toContain("registration");
    expect(categoryDocumentTypes("cars")).not.toContain("title_deed");
    expect(categoryDocumentTypes("real-estate-developments")).toContain("payment_plan");
  });

  it("falls back to the real-estate policy for an unknown category", () => {
    expect(resolveCategoryMediaPolicy("teleporters")).toBe(resolveCategoryMediaPolicy("real-estate"));
  });
});
