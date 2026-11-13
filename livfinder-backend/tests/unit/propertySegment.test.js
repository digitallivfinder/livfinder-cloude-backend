import { describe, expect, it } from "vitest";
import { decideSegment } from "../../src/modules/listings/propertySegment.js";
import { normalizeSegment, typeFitsSegment } from "../../src/modules/search/propertySegments.js";

const fields = (fn) => {
  try {
    fn();
  } catch (error) {
    return error.fields;
  }
  throw new Error("expected a validation error");
};

describe("the segment a listing is saved with", () => {
  it("uses the segment given when the type belongs to it", () => {
    expect(decideSegment({ requested: "commercial", typeSegment: "commercial", typeName: "Office" })).toBe("commercial");
    expect(decideSegment({ requested: "commercial", typeSegment: "both", typeName: "Plot" })).toBe("commercial");
    expect(decideSegment({ requested: "residential", typeSegment: "both", typeName: "Whole Building" })).toBe("residential");
  });

  it("refuses a type from the other segment", () => {
    const errors = fields(() => decideSegment({ requested: "commercial", typeSegment: "residential", typeName: "Villa" }));
    expect(errors.categorySlug).toMatch(/Villa is Residential/);
  });

  it("takes the segment from a type that belongs to one", () => {
    expect(decideSegment({ typeSegment: "residential", typeName: "Villa" })).toBe("residential");
    expect(decideSegment({ typeSegment: "commercial", typeName: "Warehouse" })).toBe("commercial");
  });

  it("refuses a plot or whole building without one", () => {
    expect(fields(() => decideSegment({ typeSegment: "both", typeName: "Plot" })).propertySegment).toMatch(/Plot can be residential or commercial/);
    expect(fields(() => decideSegment({ typeSegment: null })).propertySegment).toMatch(/Choose Residential or Commercial/);
  });

  it("keeps an edit's stored segment when the type allows it", () => {
    expect(decideSegment({ typeSegment: "both", typeName: "Plot", stored: "commercial" })).toBe("commercial");
    // A new single-segment type wins over what was stored.
    expect(decideSegment({ typeSegment: "residential", typeName: "Villa", stored: "commercial" })).toBe("residential");
  });

  it("reads the ways feeds spell it", () => {
    expect(decideSegment({ requested: "Commercial", typeSegment: "both" })).toBe("commercial");
    expect(normalizeSegment("R")).toBe("residential");
    expect(normalizeSegment(" residential ")).toBe("residential");
    expect(normalizeSegment("C")).toBe("commercial");
    expect(normalizeSegment("")).toBeNull();
    expect(fields(() => decideSegment({ requested: "industrial", typeSegment: "both" })).propertySegment).toMatch(/Residential or Commercial/);
  });

  it("knows which types fit which segment", () => {
    expect(typeFitsSegment("both", "commercial")).toBe(true);
    expect(typeFitsSegment("residential", "commercial")).toBe(false);
    expect(typeFitsSegment(null, "commercial")).toBe(true);
  });
});
