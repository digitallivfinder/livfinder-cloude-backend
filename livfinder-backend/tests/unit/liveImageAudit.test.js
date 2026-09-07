import { describe, expect, it } from "vitest";
import { imageIssue } from "../../scripts/audit-live-images.mjs";

describe("live image validation", () => {
  it("does not confuse a 200 placeholder with a real photo", () => {
    expect(imageIssue("https://api.example/media/placeholder/a.svg", 200, "image/svg+xml"))
      .toBe("generated-placeholder");
  });
  it("detects an HTML catch-all served as 200", () => {
    expect(imageIssue("https://site.example/media/a.jpg", 200, "text/html"))
      .toBe("not-an-image");
  });
  it("reports missing files even when the 404 body is an image", () => {
    expect(imageIssue("https://api.example/media/a.jpg", 404, "image/svg+xml")).toBe("http-404");
  });
  it("does not pass a known demo import as a verified listing photo", () => {
    expect(imageIssue("https://api.example/media/listings/imported/a.jpg", 200, "image/jpeg"))
      .toBe("demo-import-not-verified-listing-photo");
  });
  it("accepts image responses including partial-content requests", () => {
    expect(imageIssue("https://api.example/media/listings/a.jpg", 206, "image/jpeg")).toBeNull();
  });
});
