import { describe, expect, it } from "vitest";
import { s3MediaUrl, s3MediaUrlDeep } from "../../src/utils/s3MediaUrl.js";

const options = {
  publicBaseUrl: "https://livfinder.s3.eu-north-1.amazonaws.com/public/",
  legacyBaseUrls: ["https://api-test.livfinder.com/media/"],
};
const s3 = "https://livfinder.s3.eu-north-1.amazonaws.com/public";

describe("local media URL → S3 public base", () => {
  it.each([
    "http://localhost:4100",
    "http://localhost:4000",
    "http://127.0.0.1:4100",
    "http://[::1]:4100",
    "",
  ])("rewrites %s/media/<key> keeping the key verbatim", (origin) => {
    expect(s3MediaUrl(`${origin}/media/listings/800/my%20photo.card.webp`, options))
      .toBe(`${s3}/listings/800/my%20photo.card.webp`);
  });

  it("rewrites an old non-loopback STORAGE_PUBLIC_BASE_URL", () => {
    expect(s3MediaUrl("https://api-test.livfinder.com/media/profiles/a.png", options))
      .toBe(`${s3}/profiles/a.png`);
  });

  it("rewrites the seed's relative paths", () => {
    expect(s3MediaUrl("/media/seed/logos/01.svg", options)).toBe(`${s3}/seed/logos/01.svg`);
  });

  it.each([
    "private://verification/accounts/1/a.pdf",
    "https://cdn.livfinder.com/media/seed/a.jpg",
    "http://cdn.livfinder.com/listings/a.jpg",
    `${s3}/listings/a.jpg`,
    "http://localhost:4100/media/a.jpg?X-Amz-Signature=abc",
    "/media/a.jpg?signature=abc",
    "http://localhost:4100/media/a.jpg#x",
    "http://localhost:4100/v1/media/signed?key=a",
    "http://localhost:3000/real-estate/dubai/listing-1",
    "http://user:pass@localhost:4100/media/a.jpg",
    "https://localhost.evil.example/media/a.jpg",
    "https://api-test.livfinder.com/v1/media/a.jpg",
    "//example.com/media/a.jpg",
    "/media/",
    "/images/brand.jpg",
    "",
    null,
    undefined,
  ])("leaves %s unchanged", (value) => {
    expect(s3MediaUrl(value, options)).toBe(value);
  });

  it("is idempotent", () => {
    const once = s3MediaUrl("http://localhost:4100/media/listings/a.jpg", options);
    expect(s3MediaUrl(once, options)).toBe(once);
  });

  it("requires a target base", () => {
    expect(() => s3MediaUrl("/media/a.jpg", { publicBaseUrl: "" })).toThrow(TypeError);
  });
});

describe("JSON values", () => {
  it("rewrites nested strings and keeps untouched values by reference", () => {
    const snapshot = {
      title: "Villa",
      coverImageUrl: "http://localhost:4100/media/listings/a.jpg",
      documents: [{ url: "private://leads/b.pdf" }],
      gallery: ["/media/listings/c.jpg", "https://cdn.livfinder.com/d.jpg"],
    };
    const rewritten = s3MediaUrlDeep(snapshot, options);
    expect(rewritten).toEqual({
      title: "Villa",
      coverImageUrl: `${s3}/listings/a.jpg`,
      documents: [{ url: "private://leads/b.pdf" }],
      gallery: [`${s3}/listings/c.jpg`, "https://cdn.livfinder.com/d.jpg"],
    });
    expect(rewritten.documents).toBe(snapshot.documents);
    const untouched = { a: 1, b: ["private://x"] };
    expect(s3MediaUrlDeep(untouched, options)).toBe(untouched);
  });
});
