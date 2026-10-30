import { existsSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { parseFeed, parsePushedXml } from "../../src/modules/feeds/feedParser.js";

/** The guide's examples, read as a client would send them. An example must never be invalid. */
const path = new URL("../../../frontend/src/app/portal/integrations/_components/IntegrationsGuide/guideExamples.js", import.meta.url);

describe.runIf(existsSync(path))("the integrations guide's examples", () => {
  const source = readFileSync(path, "utf8");
  const example = (name) => new RegExp("export const " + name + " = `([\\s\\S]*?)`;").exec(source)[1];

  it("has a complete XML file", () => {
    const results = parsePushedXml(example("fullXmlExample"));
    expect(results.map((result) => result.category)).toEqual(["real-estate", "cars"]);
    for (const result of results) expect(result.items.map((item) => item.errors)).toEqual([null]);
  });

  it("has a complete CSV file", () => {
    const { items } = parseFeed({ category: "real-estate", format: "csv", content: example("fullCsvExample") });
    expect(items.map((item) => item.errors)).toEqual([null]);
  });

  it("has a complete JSON listing", () => {
    const record = JSON.parse(example("fullJsonExample"));
    expect(record.images.length).toBeGreaterThanOrEqual(3);
    expect(record.category).toBe("real-estate");
  });
});
