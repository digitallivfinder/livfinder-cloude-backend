import { describe, expect, it } from "vitest";
import { parseFeed } from "../../src/modules/feeds/feedParser.js";
import { readForeignXml } from "../../src/modules/feeds/foreignFormats.js";

const property = (n) =>
  `<property><reference_number>R${n}</reference_number><offering_type>RS</offering_type><property_type>AP</property_type>` +
  `<description_en>${"&lt;p&gt;Line &amp;amp; more&lt;/p&gt;".repeat(50)}</description_en></property>`;

describe("feed XML entities", () => {
  it("reads a file with many thousands of ordinary escapes (HTML descriptions)", () => {
    const file = `<?xml version="1.0"?><list>${Array.from({ length: 200 }, (_, i) => property(i)).join("")}</list>`;
    const { entries } = readForeignXml(file);
    expect(entries).toHaveLength(200);
    expect(entries[0].description).toContain("<p>Line &amp; more</p>");
    expect(parseFeed({ category: "real-estate", format: "xml", content: file }).items).toHaveLength(200);
  });

  it("still refuses a file whose own declared entities blow up its size", () => {
    const lol = `<!DOCTYPE list [<!ENTITY a "${"x".repeat(5000)}"><!ENTITY b "y">]>`;
    const bomb = `<?xml version="1.0"?>${lol}<list><property><reference_number>R1</reference_number><description_en>${"&a;".repeat(50)}</description_en></property></list>`;
    expect(() => parseFeed({ category: "real-estate", format: "xml", content: bomb })).toThrow();
  });
});
