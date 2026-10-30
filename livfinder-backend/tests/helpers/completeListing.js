import crypto from "node:crypto";
import sharp from "sharp";
import { parseFeed } from "../../src/modules/feeds/feedParser.js";
import { listingsCsv, listingsXml, sampleXml } from "../../src/modules/feeds/feedTemplates.js";
import { setImageFetcher } from "../../src/modules/imports/listingImport.service.js";

/** A listing that meets every requirement, from the published sample, with its own id. */
export function completeRecord(category, externalId, overrides = {}) {
  const [item] = parseFeed({ category, format: "xml", content: sampleXml(category) }).items;
  const images = [1, 2, 3].map((index) => `https://images.example/${externalId}/${index}.jpg`);
  return { ...structuredClone(item.record), externalId, images, ...overrides };
}

export const completeXml = (category, records) =>
  listingsXml([{ category, entries: records.map((record) => ({ record, status: "draft" })) }]);

export const completeCsv = (category, records) =>
  listingsCsv(category, records.map((record) => ({ record, status: "draft" })));

/** No network in tests: every URL answers with its own small picture, unless it says `broken`. */
export function useFakeImages() {
  setImageFetcher(async (url) => {
    if (url.includes("broken")) throw new Error("the image host answered 404");
    const [r, g, b] = crypto.createHash("sha256").update(url).digest();
    return sharp({ create: { width: 1200, height: 800, channels: 3, background: { r, g, b } } }).jpeg().toBuffer();
  });
}

export const useRealImages = () => setImageFetcher(null);
