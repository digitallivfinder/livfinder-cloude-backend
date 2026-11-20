import { describe, expect, it } from "vitest";
import { DESCRIPTION_MIN, TITLE_MAX, effectiveDescription, effectiveTitle, seoChecks } from "../../src/modules/admin/admin.seo.js";

const words = (n) => Array.from({ length: n }, (_, i) => `word${i}`).join(" ");
const listing = (overrides = {}) => ({
  listing_id: overrides.listing_id ?? 1,
  public_id: `L${overrides.listing_id ?? 1}`,
  reference: "LF-1",
  root_category_id: 1,
  canonical_path: "/real-estate/x",
  organization_name: "Acme",
  image_count: 8,
  cover_image_url: "/media/a.jpg",
  title: `Five Bedroom Villa with Sea Views, Plot ${overrides.listing_id ?? 1}`,
  seo_title: null,
  seo_description: "A five bedroom villa on the Palm with a private beach, pool and uninterrupted views of the Gulf.",
  description: words(120),
  ...overrides,
});
const count = (result, key) => result.checks.find((check) => check.key === key).count;

describe("SEO checks on public listings", () => {
  it("reads the title and description the public page actually renders", () => {
    expect(effectiveTitle({ title: "Villa | Liv Finder" })).toBe("Villa");
    expect(effectiveTitle({ title: "Villa", seo_title: "Sea-view villa" })).toBe("Sea-view villa");
    expect(effectiveDescription({ seo_description: "", description: "<p>Lovely&nbsp; home</p>" })).toBe("Lovely home");
  });

  it("passes a complete listing on every check", () => {
    const result = seoChecks([listing()]);
    expect(result.listingsWithIssues).toBe(0);
    expect(result.checks.every((check) => check.count === 0)).toBe(true);
  });

  it("flags each problem once, against the right listing", () => {
    const result = seoChecks([
      listing({ listing_id: 1, title: "Same title for two different villas" }),
      listing({ listing_id: 2, title: "Same title for two different villas" }),
      listing({ listing_id: 3, title: "x".repeat(TITLE_MAX + 1) }),
      listing({ listing_id: 4, title: "Villa" }),
      listing({ listing_id: 5, seo_description: "", description: "" }),
      listing({ listing_id: 6, seo_description: "s".repeat(DESCRIPTION_MIN - 1) }),
      listing({ listing_id: 7, description: words(10) }),
      listing({ listing_id: 8, cover_image_url: null, image_count: 0 }),
      listing({ listing_id: 9, image_count: 2 }),
    ]);
    expect(count(result, "duplicate-title")).toBe(2);
    expect(count(result, "long-title")).toBe(1);
    expect(count(result, "short-title")).toBe(1);
    expect(count(result, "missing-description")).toBe(1);
    expect(count(result, "short-description")).toBe(1);
    // Listing 5 has no description at all, so it is thin as well as missing one.
    expect(count(result, "thin-content")).toBe(2);
    expect(count(result, "no-image")).toBe(1);
    // A listing with no cover is reported as "no image", not also as "few photos".
    expect(count(result, "few-photos")).toBe(1);
    expect(result.listingsWithIssues).toBe(9);
    const duplicate = result.checks.find((check) => check.key === "duplicate-title");
    expect(duplicate.listings.map((row) => row.id)).toEqual(["L1", "L2"]);
    expect(duplicate.listings[0]).toMatchObject({ categorySlug: "real-estate", detail: "Shared by 2 listings" });
  });
});
