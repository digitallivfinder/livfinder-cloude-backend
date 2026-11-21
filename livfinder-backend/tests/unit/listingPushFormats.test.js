import { describe, expect, it } from "vitest";
import { parseFeed, parsePushedXml } from "../../src/modules/feeds/feedParser.js";
import { listingsCsv, listingsXml, sampleAllXml } from "../../src/modules/feeds/feedTemplates.js";
import { FEED_CATEGORIES } from "../../src/modules/feeds/feedFormats.js";

describe("the all-categories file", () => {
  it("reads every section of its own sample, each as its category", () => {
    const results = parsePushedXml(sampleAllXml());
    expect(results.map((result) => result.category)).toEqual([...FEED_CATEGORIES]);
    for (const result of results) {
      expect(result.items.length, result.category).toBe(1);
      expect(result.items[0].errors, `${result.category}: ${JSON.stringify(result.items[0].errors)}`).toBeNull();
    }
  });

  it("still reads a one-category file", () => {
    const results = parsePushedXml('<livfinder-feed category="cars" version="1"><listing><externalId>A</externalId><status>withdrawn</status></listing></livfinder-feed>');
    expect(results.map((result) => result.category)).toEqual(["cars"]);
  });

  it("needs only the id to withdraw a listing", () => {
    const [cars] = parsePushedXml('<livfinder-feed version="1"><category name="cars"><listing><externalId>A</externalId><status>Withdrawn</status></listing></category></livfinder-feed>');
    expect(cars.items[0]).toMatchObject({ externalId: "A", errors: null, record: { externalId: "A", category: "cars", withdraw: true } });
  });

  it("does not warn about <status> on a withdrawal", () => {
    const [cars] = parsePushedXml('<livfinder-feed category="cars" version="1"><listing><externalId>A</externalId><status>withdrawn</status></listing></livfinder-feed>');
    expect(cars.items[0].record.withdraw).toBe(true);
    expect(cars.warnings).toEqual([]);
  });

  it("still warns about an element it does not know", () => {
    const [cars] = parsePushedXml('<livfinder-feed category="cars" version="1"><listing><externalId>A</externalId><status>withdrawn</status><colour>red</colour></listing></livfinder-feed>');
    expect(cars.warnings).toEqual(["Unknown element <colour> was ignored."]);
  });

  it("refuses an unknown category, a repeated one, and a file with no sections", () => {
    expect(() => parsePushedXml('<livfinder-feed version="1"><category name="boats"/></livfinder-feed>')).toThrow(/no feed format/);
    expect(() => parsePushedXml('<livfinder-feed version="1"><category name="cars"/><category name="cars"/></livfinder-feed>')).toThrow(/twice/);
    expect(() => parsePushedXml('<livfinder-feed version="1"></livfinder-feed>')).toThrow(/no <category/);
  });

  it("marks a repeated id within a category", () => {
    const entry = "<listing><externalId>A</externalId><status>withdrawn</status></listing>";
    const [cars] = parsePushedXml(`<livfinder-feed version="1"><category name="cars">${entry}${entry}</category></livfinder-feed>`);
    expect(cars.items[1].errors.externalId).toContain("row 1");
  });

  it("writes what a client pushed so it reads back the same", () => {
    const [before] = parsePushedXml(sampleAllXml());
    const record = before.items[0].record;
    const written = listingsXml([{ category: before.category, entries: [{ record, status: "draft" }] }], "https://api.test");
    expect(written).toContain('livfinderStatus="draft"');
    expect(written).toContain('format="https://api.test/v1/public/feed-formats/real-estate"');
    const [after] = parsePushedXml(written);
    expect(after.items[0].errors).toBeNull();
    expect(after.items[0].record).toEqual(record);
  });

  it("writes a development with its units and plans, and reads it back the same", () => {
    const developments = parsePushedXml(sampleAllXml()).find((result) => result.category === "developments");
    const record = developments.items[0].record;
    const written = listingsXml([{ category: "developments", entries: [{ record, status: "draft" }] }]);
    const [after] = parsePushedXml(written);
    expect(after.items[0].record).toEqual(record);
  });
});

describe("the CSV a client reads back", () => {
  it("escapes values and adds the status column", () => {
    const record = { externalId: "A", title: 'Villa, "sea view"', images: ["https://a/1.jpg", "https://a/2.jpg"] };
    const lines = listingsCsv("real-estate", [{ record, status: "active" }]).split("\r\n");
    expect(lines[0].endsWith(",livfinderStatus")).toBe(true);
    expect(lines[1]).toContain('"Villa, ""sea view"""');
    expect(lines[1]).toContain("https://a/1.jpg|https://a/2.jpg");
    expect(lines[1].endsWith(",active")).toBe(true);
  });

  it("can be pushed straight back without a warning about livfinderStatus", () => {
    const realEstate = parsePushedXml(sampleAllXml()).find((result) => result.category === "real-estate");
    const csv = listingsCsv("real-estate", [{ record: realEstate.items[0].record, status: "draft" }]);
    const parsed = parseFeed({ category: "real-estate", format: "csv", content: csv });
    expect(parsed.warnings).toEqual([]);
    expect(parsed.items[0].errors).toBeNull();
  });

  it("withdraws by a status column without a warning, and still names an unknown column", () => {
    const parsed = parseFeed({ category: "cars", format: "csv", content: "externalId,status,colour\r\nA,withdrawn,red\r\n" });
    expect(parsed.items[0].record).toMatchObject({ externalId: "A", withdraw: true });
    expect(parsed.warnings).toEqual(['Unknown column "colour" was ignored.']);
  });
});

describe("a very large read-back file", () => {
  it("is written without overflowing the call stack (16,000+ listings)", async () => {
    const { listingsXml } = await import("../../src/modules/feeds/feedTemplates.js");
    const record = { externalId: "X", title: "A listing", description: "Text", features: ["Pool"], images: ["https://e.x/1.jpg"], detail: { bedrooms: 1 } };
    const entries = Array.from({ length: 20_000 }, (_, i) => ({ record: { ...record, externalId: `X-${i}` }, status: "draft" }));
    const xml = listingsXml([{ category: "real-estate", entries }]);
    expect(xml.match(/<listing[ >]/g)).toHaveLength(20_000);
  });
});
