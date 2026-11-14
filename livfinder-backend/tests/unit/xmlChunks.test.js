import { describe, expect, it } from "vitest";
import { XmlShapeError, childElements, entityDeclarations, rootElement, textOf, toBytes } from "../../src/modules/feeds/xmlChunks.js";
import { parsePushedXml } from "../../src/modules/feeds/feedParser.js";
import { foreignEntries } from "../../src/modules/feeds/foreignFormats.js";
import { listingsCsv, listingsCsvChunks, listingsXml, listingsXmlChunks } from "../../src/modules/feeds/feedTemplates.js";
import { completeRecord, completeXml } from "../helpers/completeListing.js";

const names = (xml, from, to) => {
  const bytes = toBytes(xml);
  return [...childElements(bytes, from, to)].map((element) => ({ name: element.name, text: textOf(bytes, element.start, element.end) }));
};

describe("xmlChunks: finding entries without parsing the whole file", () => {
  it("steps over comments, CDATA, processing instructions and quoted attributes", () => {
    const xml = `﻿<?xml version="1.0"?>
<!-- a <listing> in a comment is not an entry -->
<feed note="a > b">
  <listing id="1"><title><![CDATA[Villa </listing> with a view]]></title></listing>
  <!-- <listing>2</listing> -->
  <listing id="2"/>
  <other>x</other>
</feed>`;
    const root = rootElement(toBytes(xml));
    expect(root.name).toBe("feed");
    const inside = names(xml, root.openEnd, root.contentEnd);
    expect(inside.map((entry) => entry.name)).toEqual(["listing", "listing", "other"]);
    expect(inside[0].text).toContain("Villa </listing> with a view");
    expect(inside[1].text).toBe('<listing id="2"/>');
  });

  it("reads multi-byte text by byte position", () => {
    const xml = "<feed><listing><title>Résidence ‘Burj’ — برج</title></listing></feed>";
    const bytes = toBytes(xml);
    const root = rootElement(bytes);
    const [entry] = childElements(bytes, root.openEnd, root.contentEnd);
    expect(textOf(bytes, entry.start, entry.end)).toBe("<listing><title>Résidence ‘Burj’ — برج</title></listing>");
  });

  it("refuses a file whose tags do not match, are never closed, or that has two roots", () => {
    expect(() => rootElement(toBytes("<feed><listing></feed>"))).toThrow(XmlShapeError);
    expect(() => rootElement(toBytes("<feed><listing>"))).toThrow(/never closed/);
    expect(() => rootElement(toBytes("<a/><b/>"))).toThrow(/more than one root/);
    expect(() => rootElement(toBytes('<feed attr="unclosed>'))).toThrow(XmlShapeError);
  });

  it("finds a DOCTYPE that declares entities, and ignores one that does not", () => {
    const withEntity = toBytes('<!DOCTYPE feed [<!ENTITY x "y">]><feed/>');
    expect(entityDeclarations(withEntity, rootElement(withEntity).start)).toContain("<!ENTITY");
    const plain = toBytes("<!DOCTYPE feed><feed/>");
    expect(entityDeclarations(plain, rootElement(plain).start)).toBe("");
  });
});

describe("pushed files read entry by entry", () => {
  it("reads a LivFinder file the same from bytes as from text, entities included", () => {
    const record = completeRecord("real-estate", "CHUNK-1", { title: "Villa & garden — 5 bed, Résidence برج" });
    const xml = completeXml("real-estate", [record]);
    const fromText = parsePushedXml(xml);
    const fromBytes = parsePushedXml(Buffer.from(xml, "utf8"));
    expect(fromBytes).toEqual(fromText);
    expect(fromBytes[0].items[0].errors).toBeNull();
    expect(fromBytes[0].items[0].record.title).toBe("Villa & garden — 5 bed, Résidence برج");
  });

  it("names the entry when one entry's content is broken", () => {
    const record = completeRecord("real-estate", "CHUNK-2");
    const xml = completeXml("real-estate", [record]).replace("<title>", "<title>Bad & raw");
    expect(() => parsePushedXml(xml)).toThrow(expect.objectContaining({ fields: { file: expect.stringMatching(/^Entry 1:/) } }));
  });

  it("refuses a file whose tags do not match", () => {
    expect(() => parsePushedXml('<livfinder-feed version="1"><category name="real-estate"></livfinder-feed>')).toThrow(
      expect.objectContaining({ message: "The XML file could not be read." })
    );
  });

  it("recognises a Property Finder export from its first entries", () => {
    const pf = `<list><property><reference_number>PF-1</reference_number><offering_type>RS</offering_type><property_type>AP</property_type></property></list>`;
    const found = foreignEntries(pf);
    expect(found.source).toBe("property_finder");
    expect(found.count).toBe(1);
    expect([...found.entries][0]).toMatchObject({ externalId: "PF-1" });
    expect(foreignEntries("<catalog><item/></catalog>")).toBeNull();
  });
});

describe("read-back files written piece by piece", () => {
  it("adds up to exactly the whole file", () => {
    const records = [completeRecord("real-estate", "RB-1"), completeRecord("real-estate", "RB-2")];
    const entries = records.map((record) => ({ record, status: "draft" }));
    const sections = [{ category: "real-estate", entries }, { category: "cars", entries: [] }];
    expect([...listingsXmlChunks(sections, "https://api.test")].join("")).toBe(listingsXml(sections, "https://api.test"));
    expect([...listingsXmlChunks(sections)].length).toBe(2 + 1 + entries.length + 1 + 1);
    expect([...listingsCsvChunks("real-estate", entries)].join("")).toBe(listingsCsv("real-estate", entries));
  });
});
