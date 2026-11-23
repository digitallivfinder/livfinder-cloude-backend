import { describe, expect, it } from "vitest";
import { slugify } from "../../src/utils/slug.js";
import {
  amenityLookupSlug,
  currentTypeCode,
  offeredForCondition,
  typeOfferedFor,
} from "../../src/modules/search/realEstateCatalogue.js";

describe("Property Finder types (0083)", () => {
  it("resolves LivFinder's earlier codes to the type that replaced them", () => {
    expect(currentTypeCode("plot")).toBe("land");
    expect(currentTypeCode("Mansion")).toBe("villa");
    expect(currentTypeCode("offices")).toBe("office-space");
    expect(currentTypeCode("labour_camp")).toBe("labor-camp");
    expect(currentTypeCode("commercial-floor")).toBe("full-floor");
  });

  it("picks the sale or rent version of a bulk unit from the purpose", () => {
    expect(currentTypeCode("bulk-unit", "sale")).toBe("bulk-sale-unit");
    expect(currentTypeCode("bulk-unit", "rent")).toBe("bulk-rent-unit");
    expect(currentTypeCode("BU", "rent")).toBe("bulk-rent-unit");
  });

  it("reads Property Finder's two-letter codes and passes other words through", () => {
    expect(currentTypeCode("AP")).toBe("apartment");
    expect(currentTypeCode("CD")).toBe("compound");
    expect(currentTypeCode("Penthouse")).toBe("Penthouse");
  });

  it("knows which purposes a type is offered for in each segment", () => {
    const land = { residential: ["sale"], commercial: ["sale", "rent"] };
    expect(typeOfferedFor(land, "residential", "sale")).toBe(true);
    expect(typeOfferedFor(land, "residential", "rent")).toBe(false);
    expect(typeOfferedFor(JSON.stringify(land), "commercial", "rent")).toBe(true);
    expect(typeOfferedFor(null, "commercial", "rent")).toBe(true);
    expect(typeOfferedFor({ residential: ["rent"], commercial: ["rent"] }, null, "sale")).toBe(false);
  });

  it("builds the SQL that narrows types by purpose", () => {
    expect(offeredForCondition({})).toBeNull();
    expect(offeredForCondition({ segment: "residential", purpose: "rent" }).params).toEqual(["$.residential", "rent"]);
  });
});

describe("Property Finder amenities (0083)", () => {
  it("matches PF codes, earlier names and common spellings", () => {
    expect(amenityLookupSlug("BA", slugify)).toBe("balcony");
    expect(amenityLookupSlug("Terrace", slugify)).toBe("balcony");
    expect(amenityLookupSlug("Sea view", slugify)).toBe("view-of-water");
    expect(amenityLookupSlug("Kids play area", slugify)).toBe("childrens-play-area");
    expect(amenityLookupSlug("Shared Pool", slugify)).toBe("shared-pool");
  });

  it("leaves an unknown amenity as its own slug, for the push to report", () => {
    expect(amenityLookupSlug("Wine cellar", slugify)).toBe("wine-cellar");
    expect(amenityLookupSlug("", slugify)).toBeNull();
  });
});
