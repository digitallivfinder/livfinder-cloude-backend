import { describe, expect, it } from "vitest";
import { serializeListingCard, serializeListingDetail } from "../../src/serializers/listing.js";
import { serializeCompany, serializeAgent } from "../../src/serializers/organization.js";
import { htmlToBlocks, serializeArticle } from "../../src/serializers/editorial.js";
import { bool, int, isoDay, jsonField, money, num } from "../../src/serializers/primitives.js";

describe("primitives", () => {
  it("turns driver strings into numbers and leaves nulls alone", () => {
    expect(num("1234.50")).toBe(1234.5);
    expect(num(null)).toBeNull();
    expect(num("not a number")).toBeNull();
    expect(int("42.9")).toBe(42);
  });

  it("treats only 1/true/'1' as true", () => {
    expect([bool(1), bool(true), bool("1")]).toEqual([true, true, true]);
    expect([bool(0), bool(null), bool(undefined), bool("0")]).toEqual([false, false, false, false]);
  });

  it("formats a date as a day and rejects an unparseable one", () => {
    expect(isoDay(new Date("2026-05-02T10:00:00Z"))).toBe("2026-05-02");
    expect(isoDay("nonsense")).toBeNull();
  });

  it("parses a JSON column whether the driver hydrated it or not", () => {
    expect(jsonField('{"a":1}')).toEqual({ a: 1 });
    expect(jsonField({ a: 1 })).toEqual({ a: 1 });
    expect(jsonField("broken", [])).toEqual([]);
  });

  it("returns null money rather than a zero-priced object", () => {
    expect(money(null, "AED")).toBeNull();
    expect(money("500", "USD")).toEqual({ amount: 500, currency: "USD" });
  });
});

const cardRow = {
  listing_id: 81,
  public_id: "01K2F2DKG0YZKTJ4H3958YD3FC",
  reference: "LF-2480",
  root_category_id: 1,
  category_slug: "duplexes",
  purpose_slug: "for-sale",
  title: "Turnkey 7 Bedroom Duplex",
  slug: "turnkey-7-bedroom-duplex-81",
  canonical_path: "/real-estate/united-arab-emirates/dubai/dubai/downtown/turnkey-7-bedroom-duplex-81",
  cover_image_url: "http://example.test/cover.jpg",
  image_count: 27,
  price: "87000000.00",
  currency_code: "AED",
  price_base: "87000000.00",
  location_label: "Downtown, Dubai, United Arab Emirates",
  country_slug: "united-arab-emirates",
  city_slug: "dubai",
  community_slug: "downtown",
  organization_id: 14,
  organization_name: "Sovereign Estates",
  agent_id: 42,
  agent_slug: "emma-herrera-42",
  is_featured: 1,
  is_premium: 0,
  is_verified: 1,
  spec_a: 7,
  spec_b: 8,
  spec_labels: JSON.stringify({ beds: 7, baths: 8, area_sqft: 8900, type: "Duplex" }),
  quality_score: 91,
  published_at: new Date("2026-04-10T00:00:00Z"),
  source_updated_at: new Date("2026-05-02T00:00:00Z"),
};

describe("listing card", () => {
  it("maps the database row onto the marketplace card contract", () => {
    const card = serializeListingCard(cardRow);
    expect(card).toMatchObject({
      id: "01K2F2DKG0YZKTJ4H3958YD3FC",
      reference: "LF-2480",
      category: "realEstate",
      listingType: "real-estate",
      purpose: "sale",
      canonicalUrl: cardRow.canonical_path,
      country: "united-arab-emirates",
      city: "dubai",
      featured: true,
      verified: true,
      bedrooms: 7,
      bathrooms: 8,
    });
    expect(card.price).toEqual({ amount: 87000000, currency: "AED" });
    expect(card.builtArea).toBe("8,900 sq ft");
  });

  it("carries exactly one image so a results page does not ship a gallery", () => {
    const card = serializeListingCard(cardRow);
    expect(card.media).toHaveLength(1);
    expect(card.imageCount).toBe(27);
  });

  it("has no media entry when the listing has no cover", () => {
    const card = serializeListingCard({ ...cardRow, cover_image_url: null });
    expect(card.media).toEqual([]);
    expect(card.coverImage).toBeNull();
  });

  it("maps each root category to its frontend id", () => {
    const ids = [1, 2, 3, 4, 5, 6].map((rootId) => serializeListingCard({ ...cardRow, root_category_id: rootId }).category);
    expect(ids).toEqual(["realEstate", "car", "yacht", "jet", "helicopter", "watch"]);
  });

  it("reads rent and charter purposes", () => {
    expect(serializeListingCard({ ...cardRow, purpose_slug: "for-rent" }).purpose).toBe("rent");
    expect(serializeListingCard({ ...cardRow, purpose_slug: "for-charter" }).purpose).toBe("charter");
  });
});

const detailListing = {
  id: 81,
  public_id: "01K2F2DKG0YZKTJ4H3958YD3FC",
  reference: "LF-2480",
  root_category_id: 2,
  category_id: 201,
  category_slug: "supercars",
  category_name: "Supercar",
  purpose_slug: "for-sale",
  title: "2022 Bugatti Tourbillon",
  slug: "bugatti-tourbillon-304",
  canonical_path: "/cars/bugatti/tourbillon/2022/bugatti-tourbillon-304",
  description: "A collector car.\n\nWith provenance.",
  price: "4500000.00",
  currency_code: "EUR",
  price_type: "fixed",
  contact_phone: "+971 4 000 0000",
  contact_whatsapp: "+971 50 000 0000",
  contact_email: "sales@example.test",
  allow_call: 1,
  allow_whatsapp: 0,
  allow_email: 1,
  hide_exact_location: 1,
  address: "Somewhere precise",
  latitude: "25.1",
  longitude: "55.2",
  brand_slug: "bugatti",
  brand_model_slug: "tourbillon",
  is_verified: 1,
  created_at: new Date("2026-02-15T00:00:00Z"),
  updated_at: new Date("2026-04-20T00:00:00Z"),
  published_at: new Date("2026-02-20T00:00:00Z"),
  is_indexable: 1,
};

describe("listing detail", () => {
  it("suppresses a contact channel the listing does not allow", () => {
    const detail = serializeListingDetail({ listing: detailListing, detail: {}, media: [] });
    expect(detail.contact.phone).toBe("+971 4 000 0000");
    expect(detail.contact.whatsapp).toBeNull();
    expect(detail.contact.email).toBe("sales@example.test");
  });

  it("withholds the exact address and coordinates when the seller hid them", () => {
    const detail = serializeListingDetail({ listing: detailListing, detail: {}, media: [] });
    expect(detail.address).toBeNull();
    expect(detail.latitude).toBeNull();
    expect(detail.addressDisplayPrecision).toBe("locality");
  });

  it("never publishes a VIN, only that one is on file", () => {
    const detail = serializeListingDetail({
      listing: detailListing,
      detail: { vin: "WVWZZZ1JZXW000001", model_year: 2022 },
      media: [],
    });
    expect(detail.vinDisclosure).toBe("masked");
    expect(JSON.stringify(detail)).not.toContain("WVWZZZ1JZXW000001");
  });

  it("orders the gallery with the cover first", () => {
    const detail = serializeListingDetail({
      listing: detailListing,
      detail: {},
      media: [
        { id: 2, media_type: "image", url: "b.jpg", sort_order: 1, is_cover: 0, public_id: "B" },
        { id: 1, media_type: "image", url: "a.jpg", sort_order: 0, is_cover: 1, public_id: "A" },
      ],
    });
    expect(detail.gallery.map((item) => item.url)).toEqual(["b.jpg", "a.jpg"]);
    expect(detail.media).toHaveLength(2);
  });

  it("keeps documents out of the image gallery", () => {
    const detail = serializeListingDetail({
      listing: detailListing,
      detail: {},
      media: [
        { id: 1, media_type: "image", url: "a.jpg", sort_order: 0, is_cover: 1 },
        { id: 2, media_type: "floor_plan", url: "plan.pdf", sort_order: 1, is_cover: 0 },
      ],
    });
    expect(detail.gallery).toHaveLength(1);
    expect(detail.documents).toHaveLength(1);
    expect(detail.documents[0].type).toBe("floor_plan");
  });

  it("uses the right detail builder for each category", () => {
    const realEstate = serializeListingDetail({
      listing: { ...detailListing, root_category_id: 1 },
      detail: { bedrooms: 5, bathrooms: 6, built_area_sqft: "7200.00" },
      media: [],
    });
    expect(realEstate.bedrooms).toBe(5);
    expect(realEstate.builtArea).toBe("7,200 sq ft");

    const watch = serializeListingDetail({
      listing: { ...detailListing, root_category_id: 6 },
      detail: { case_diameter_mm: "40.50", movement_type: "automatic", year_of_production: 2023 },
      media: [],
    });
    expect(watch.caseDiameterMm).toBe(40.5);
    expect(watch.movement).toBe("automatic");
    expect(watch.year).toBe("2023");
    // A watch has no bedrooms, whatever the shared columns say.
    expect(watch.bedrooms).toBeUndefined();
  });
});

describe("organization and agent", () => {
  it("maps an organization onto the company card contract", () => {
    const company = serializeCompany(
      {
        id: 1,
        public_id: "ORG1",
        slug: "prime-properties",
        name: "Prime Properties",
        legal_name: "Prime Properties LLC",
        kind: "agency",
        status: "active",
        verification_status: "verified",
        is_publicly_visible: 1,
        email: "a@b.test",
        phone: "+1",
        active_listing_count: 12,
        country_name: "United States",
      },
      { categories: [{ root_category_id: 1 }, { root_category_id: 2 }], serviceAreas: ["Los Angeles"] }
    );
    expect(company).toMatchObject({
      companySlug: "prime-properties",
      displayName: "Prime Properties",
      membershipStatus: "active",
      verificationStatus: "approved",
      publicPageEnabled: true,
      verifiedBadgeEnabled: true,
      activeListingCount: 12,
    });
    expect(company.categoriesAllowed).toEqual(["realEstate", "car"]);
    expect(company.leadChannels).toEqual(["email", "phone"]);
  });

  it("maps an agent and keeps an empty photo an empty string", () => {
    const agent = serializeAgent(
      { id: 2, public_id: "AGT2", slug: "layla", display_name: "Layla Haddad", first_name: "Layla", last_name: "Haddad", status: "active", is_publicly_visible: 1, photo_url: null },
      { languages: ["English"], specialties: ["Real Estate"], serviceAreas: ["Dubai"] }
    );
    expect(agent).toMatchObject({ slug: "layla", fullName: "Layla Haddad", publicProfileEnabled: true, photo: "" });
    expect(agent.languages).toEqual(["English"]);
  });
});

describe("editorial", () => {
  it("turns stored HTML into the block array the renderer reads", () => {
    const blocks = htmlToBlocks(
      "<p>First &amp; foremost.</p><h2>A heading</h2><ul><li>One</li><li>Two</li></ul><blockquote>Quoted.</blockquote>"
    );
    expect(blocks).toEqual([
      { type: "paragraph", text: "First & foremost." },
      { type: "heading", level: 2, text: "A heading" },
      { type: "list", items: ["One", "Two"] },
      { type: "quote", text: "Quoted." },
    ]);
  });

  it("still produces a paragraph from an unstructured body", () => {
    expect(htmlToBlocks("Just some text")).toEqual([{ type: "paragraph", text: "Just some text" }]);
    expect(htmlToBlocks("")).toEqual([]);
  });

  it("groups post terms by taxonomy", () => {
    const article = serializeArticle(
      {
        id: 2,
        public_id: "POST2",
        slug: "a-guide",
        title: "A guide",
        status: "published",
        visibility: "public",
        post_type: "guide",
        primary_term_id: 10,
        reading_time_minutes: 11,
        published_at: new Date("2026-07-18T00:00:00Z"),
      },
      {
        terms: [
          { id: 10, slug: "real-estate", name: "Real Estate", taxonomy: "category" },
          { id: 11, slug: "buying-guides", name: "Buying Guides", taxonomy: "topic" },
          { id: 12, slug: "dubai", name: "Dubai", taxonomy: "tag" },
        ],
      }
    );
    expect(article.primaryCategory).toEqual({ slug: "real-estate", label: "Real Estate" });
    expect(article.topics).toEqual(["buying-guides"]);
    expect(article.tags).toEqual(["Dubai"]);
    expect(article.format).toBe("Guide");
    expect(article.publishedAt).toBe("2026-07-18T00:00:00.000Z");
  });
});
