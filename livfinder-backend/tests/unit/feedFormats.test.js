import { describe, expect, it } from "vitest";
import { FEED_CATEGORIES, FORMAT_VERSIONS, feedFormat } from "../../src/modules/feeds/feedFormats.js";
import { csvColumns, csvTemplate, sampleXml, xmlSchema } from "../../src/modules/feeds/feedTemplates.js";
import { parseFeed } from "../../src/modules/feeds/feedParser.js";
import { DETAIL_SCHEMAS } from "../../src/modules/listings/listings.schemas.js";

/**
 * The per-category feed formats (Phase 3): generated from the import's own schemas, one
 * structure per category, and every download parses back cleanly.
 */

const LISTING_CATEGORIES = FEED_CATEGORIES.filter((category) => category !== "developments");

describe("the format registry", () => {
  it("has a versioned format for every listing category and for developments", () => {
    expect(FEED_CATEGORIES).toEqual(expect.arrayContaining(["real-estate", "cars", "yachts", "jets", "helicopters", "watches", "developments"]));
    for (const category of FEED_CATEGORIES) expect(feedFormat(category).version).toBe(FORMAT_VERSIONS[category]);
    expect(feedFormat("boats")).toBeNull();
  });

  it("carries every field of the category's own schema, and only that category's", () => {
    for (const category of LISTING_CATEGORIES) {
      const own = Object.keys(DETAIL_SCHEMAS[category].shape);
      const details = feedFormat(category).fields.filter((field) => field.group === "details").map((field) => field.key);
      expect(details).toEqual(own);
    }
    const carKeys = new Set(feedFormat("cars").fields.map((field) => field.key));
    expect(carKeys.has("mileageKm")).toBe(true);
    expect(carKeys.has("bedrooms")).toBe(false);
  });

  it("never gives two fields of one category the same column", () => {
    for (const category of FEED_CATEGORIES) {
      const columns = csvColumns(category);
      expect(new Set(columns).size, category).toBe(columns.length);
    }
  });

  it("reads limits and allowed values off the schema", () => {
    const transmission = feedFormat("cars").fields.find((field) => field.key === "transmission");
    expect(transmission).toMatchObject({ type: "enum", values: expect.arrayContaining(["automatic", "manual"]) });
    const bedrooms = feedFormat("real-estate").fields.find((field) => field.key === "bedrooms");
    expect(bedrooms).toMatchObject({ type: "integer", min: 0, max: 200 });
  });
});

describe.each(FEED_CATEGORIES)("the %s downloads", (category) => {
  it("parse back with no errors, as CSV and as XML", () => {
    for (const [format, content] of [["csv", csvTemplate(category)], ["xml", sampleXml(category)]]) {
      const result = parseFeed({ category, format, content });
      expect(result.items.length, format).toBeGreaterThan(0);
      expect(result.items.filter((item) => item.errors).map((item) => item.errors), format).toEqual([]);
      expect(result.warnings, format).toEqual([]);
    }
  });

  it("has a schema that names the category", () => {
    expect(xmlSchema(category)).toContain(`fixed="${category}"`);
  });
});

describe("reading a file", () => {
  const header = "externalId,title,price,currency,country,city,modelYear,transmission,isAccidentFree,images";

  it("reads values by type: numbers with separators, yes/no, list values in any case, lists", () => {
    const csv = `${header}\nCAR-1,2022 Porsche 911,"850,000",AED,AE,Dubai,2022,Dual Clutch,yes,https://a.example/1.jpg|https://a.example/2.jpg\n`;
    const [item] = parseFeed({ category: "cars", format: "csv", content: csv }).items;
    expect(item.record).toMatchObject({
      externalId: "CAR-1",
      category: "cars",
      price: 850000,
      location: { country: "AE", city: "Dubai" },
      images: ["https://a.example/1.jpg", "https://a.example/2.jpg"],
      detail: { modelYear: 2022, transmission: "dual_clutch", isAccidentFree: true },
    });
  });

  it("reports each bad row by number and field, and keeps the good ones", () => {
    const csv = [
      header,
      "CAR-1,Good car,100000,AED,AE,Dubai,2022,automatic,no,",
      "CAR-2,Bad year,100000,AED,AE,Dubai,1800,automatic,no,",
      "CAR-3,Bad gearbox,100000,AED,AE,Dubai,2022,steam,no,",
      ",No id,100000,AED,AE,Dubai,2022,automatic,no,",
      "CAR-1,Twice,100000,AED,AE,Dubai,2022,automatic,no,",
    ].join("\n");
    const { items } = parseFeed({ category: "cars", format: "csv", content: csv });
    expect(items.map((item) => item.row)).toEqual([2, 3, 4, 5, 6]);
    expect(items[0].errors.modelYear).toBeUndefined();
    expect(Object.keys(items[1].errors)).toContain("modelYear");
    expect(items[2].errors.transmission).toMatch(/Use one of/);
    expect(items[3].errors.externalId).toBe("This is required.");
    expect(items[4].errors.externalId).toMatch(/also on row 2/);
  });

  it("names everything a listing is missing, in one go", () => {
    const [item] = parseFeed({ category: "cars", format: "csv", content: `externalId,title\nCAR-5,A car title\n` }).items;
    expect(Object.keys(item.errors)).toEqual(expect.arrayContaining(["purpose", "description", "price", "currency", "country", "brand", "model", "mileageKm", "features", "images"]));
    expect(item.errors.images).toMatch(/at least 3/);
  });

  it("does not ask an electric car for its engine, or a sale for its rent terms", () => {
    const electric = parseFeed({ category: "cars", format: "csv", content: `externalId,title,fuelType\nCAR-6,An electric car,electric\n` }).items[0];
    expect(electric.errors.engineSizeCc).toBeUndefined();
    expect(electric.errors.mileageKm).toBeTruthy();
    const sale = parseFeed({ category: "real-estate", format: "csv", content: `externalId,title,purpose\nRE-1,A flat for sale,sale\n` }).items[0];
    expect(sale.errors.rentPeriod).toBeUndefined();
    const rent = parseFeed({ category: "real-estate", format: "csv", content: `externalId,title,purpose\nRE-2,A flat to rent,rent\n` }).items[0];
    expect(rent.errors.rentPeriod).toBeTruthy();
  });

  it("takes latitude and longitude together or not at all", () => {
    const one = parseFeed({ category: "cars", format: "csv", content: `externalId,title,latitude\nCAR-7,A car title,25.1\n` }).items[0];
    expect(one.errors.longitude).toMatch(/both/);
  });

  it("warns about a column it does not know instead of failing", () => {
    const result = parseFeed({ category: "cars", format: "csv", content: `externalId,title,bedrooms\nCAR-9,A car title,3\n` });
    expect(result.warnings).toEqual(['Unknown column "bedrooms" was ignored.']);
  });

  it("refuses a file for another category, an unsupported version, and an unreadable file", () => {
    const yacht = sampleXml("yachts");
    expect(() => parseFeed({ category: "cars", format: "xml", content: yacht })).toThrow(/set up for cars/);
    expect(() => parseFeed({ category: "cars", format: "xml", content: sampleXml("cars").replace('version="1"', 'version="7"') })).toThrow(
      /Version 7/
    );
    expect(() => parseFeed({ category: "cars", format: "xml", content: "<livfinder-feed><listing>" })).toThrow(/could not be read/);
    expect(() => parseFeed({ category: "cars", format: "csv", content: "" })).toThrow(/empty/);
  });

  it("groups development CSV rows into one development with its unit types and plan", () => {
    const [item] = parseFeed({ category: "developments", format: "csv", content: csvTemplate("developments") }).items;
    expect(item.errors).toBeNull();
    expect(item.record.unitTypes.map((unit) => unit.unitType)).toEqual(["apartment", "apartment", "penthouse"]);
    expect(item.record.paymentPlans).toHaveLength(1);
  });

  it("reads a development's payment plan milestones from XML", () => {
    const [item] = parseFeed({ category: "developments", format: "xml", content: sampleXml("developments") }).items;
    expect(item.errors).toBeNull();
    expect(item.record.paymentPlans[0].milestones.map((step) => step.name)).toEqual(["Booking", "During construction", "Handover"]);
  });
});
