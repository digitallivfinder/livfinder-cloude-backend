import { describe, expect, it } from "vitest";
import { parseFeed } from "../../src/modules/feeds/feedParser.js";
import { readForeignXml } from "../../src/modules/feeds/foreignFormats.js";
import { feedFormat } from "../../src/modules/feeds/feedFormats.js";
import { parseListingRecord } from "../../src/modules/imports/listingImport.service.js";

const pf = (offering, type) => `<?xml version="1.0" encoding="UTF-8"?>
<list><property>
  <reference_number>PF-1</reference_number>
  <offering_type>${offering}</offering_type>
  <property_type>${type}</property_type>
  <price>100</price>
</property></list>`;

const bayut = (type) => `<?xml version="1.0" encoding="UTF-8"?>
<Listings><Listing>
  <Property_Ref_No>BY-1</Property_Ref_No>
  <Property_purpose>Buy</Property_purpose>
  <Property_Type>${type}</Property_Type>
  <Price>100</Price>
</Listing></Listings>`;

describe("Residential / Commercial in feeds", () => {
  it("reads Property Finder's offering type as the segment", () => {
    expect(readForeignXml(pf("RS", "AP")).entries[0]).toMatchObject({ propertySegment: "residential", propertyType: "apartment", purpose: "sale" });
    expect(readForeignXml(pf("CR", "WH")).entries[0]).toMatchObject({ propertySegment: "commercial", propertyType: "warehouse", purpose: "rent" });
    expect(readForeignXml(pf("CS", "LP")).entries[0]).toMatchObject({ propertySegment: "commercial", propertyType: "plot" });
  });

  it("maps Property Finder's commercial type codes, bulk units included", () => {
    const type = (code) => readForeignXml(pf("CS", code)).entries[0].propertyType;
    expect(type("BU")).toBe("bulk-unit");
    expect(type("SH")).toBe("shop");
    expect(type("SR")).toBe("showroom");
    expect(type("FA")).toBe("factory");
    expect(type("LC")).toBe("labour-camp");
    expect(type("FF")).toBe("commercial-floor");
  });

  it("splits Bayut's segment-named types", () => {
    expect(readForeignXml(bayut("Commercial Plot")).entries[0]).toMatchObject({ propertySegment: "commercial", propertyType: "Plot" });
    expect(readForeignXml(bayut("Residential Building")).entries[0]).toMatchObject({ propertySegment: "residential", propertyType: "whole-building" });
    const plain = readForeignXml(bayut("Warehouse")).entries[0];
    expect(plain.propertyType).toBe("Warehouse");
    expect(plain.propertySegment).toBeUndefined();
  });

  it("takes the segment from a CSV column, however it is spelt", () => {
    const csv = `externalId,purpose,propertyType,propertySegment,title
X-1,sale,plots,Commercial,A commercial plot by the port`;
    const { items } = parseFeed({ category: "real-estate", format: "csv", content: csv });
    expect(items[0].record.propertySegment).toBe("commercial");
  });

  it("validates a pushed record's segment", () => {
    const base = { externalId: "X-2", category: "real-estate", title: "A record" };
    expect(parseListingRecord({ ...base, propertySegment: "C" }).propertySegment).toBe("commercial");
    expect(parseListingRecord({ ...base, propertySegment: "Residential" }).propertySegment).toBe("residential");
    expect(() => parseListingRecord({ ...base, propertySegment: "industrial" })).toThrow();
  });

  it("documents the field for real estate only", () => {
    const field = feedFormat("real-estate").fields.find((entry) => entry.key === "propertySegment");
    expect(field).toMatchObject({ type: "enum", values: ["residential", "commercial"] });
    expect(field.description).toMatch(/plot or a whole building/);
    expect(feedFormat("cars").fields.some((entry) => entry.key === "propertySegment")).toBe(false);
  });
});

describe("rooms an imported listing must give", async () => {
  const { roomFieldsRequired } = await import("../../src/modules/feeds/listingRequirements.js");
  it("asks a home for bedrooms, commercial space for bathrooms and parking, land for none", () => {
    expect(roomFieldsRequired({ segment: "residential", land: false })).toEqual(
      expect.arrayContaining(["bedrooms", "receptionRooms", "maidRooms", "bathrooms", "parkingSpaces"])
    );
    const commercial = roomFieldsRequired({ segment: "commercial", land: false });
    expect(commercial).toContain("parkingSpaces");
    expect(commercial).not.toContain("bedrooms");
    expect(roomFieldsRequired({ segment: "commercial", land: true })).toEqual([]);
  });
});
