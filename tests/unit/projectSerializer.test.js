import { describe, expect, it } from "vitest";
import {
  displayStatus,
  handoverQuarter,
  serializeProjectCard,
  serializeProjectDetail,
  serializeDeveloper,
} from "../../src/serializers/project.js";

/**
 * The public project DTO.
 *
 * A card is only as complete as the record behind it. These assertions are
 * mostly about absence: a project with no price, no bedrooms and no handover
 * must produce nulls rather than zeroes, empty objects or placeholder text —
 * a card that fills a slot with an invented number is worse than a shorter card.
 */

const row = {
  project_id: 42,
  public_id: "01PROJECT",
  name: "Creek Waters",
  slug: "creek-waters-2",
  canonical_path: "/projects/united-arab-emirates/abu-dhabi/abu-dhabi/corniche-area/creek-waters-2",
  tagline: "Waterfront living",
  developer_brand_id: 410,
  developer_slug: "omniyat",
  developer_name: "Omniyat",
  developer_logo_url: null,
  country_id: 1231,
  state_id: 5,
  city_id: 9,
  community_id: 12,
  sub_community_id: null,
  country_slug: "united-arab-emirates",
  country_name: "United Arab Emirates",
  state_slug: "abu-dhabi",
  state_name: "Abu Dhabi",
  city_slug: "abu-dhabi",
  city_name: "Abu Dhabi",
  community_slug: "corniche-area",
  community_name: "Corniche Area",
  location_label: "Corniche Area, Abu Dhabi, United Arab Emirates",
  latitude: "24.4136100",
  longitude: "54.4329500",
  project_type: "residential",
  status: "under_construction",
  launch_status: "launched",
  ownership_type: "freehold",
  launch_date: new Date("2023-02-04T00:00:00Z"),
  handover_date: new Date("2027-11-05T00:00:00Z"),
  handover_year: 2027,
  completion_percentage: 73,
  total_units: 122,
  available_units: 80,
  building_count: 2,
  min_price: "4100000.00",
  max_price: "22038456.44",
  min_price_base: "4100000.00",
  currency_code: "AED",
  bedrooms_min: 1,
  bedrooms_max: 4,
  area_min: "720.00",
  area_max: "4600.00",
  unit_types: "apartment,penthouse",
  bedroom_values: "1,2,4",
  availability: "available",
  payment_plan_count: 2,
  min_down_payment_percent: "10.000",
  has_post_handover: 1,
  payment_plan_types: "construction_linked,post_handover",
  cover_image_url: "https://cdn.example/creek.jpg",
  image_count: 6,
  is_featured: 1,
  accepts_inquiries: 1,
  active_listing_count: 3,
  published_at: new Date("2023-02-04T09:00:00Z"),
  source_updated_at: new Date("2026-09-04T20:04:11Z"),
};

const bare = {
  project_id: 43,
  public_id: "01BARE",
  name: "Announced Tower",
  slug: "announced-tower-43",
  canonical_path: "/projects/spain/announced-tower-43",
  status: "announced",
  launch_status: "upcoming",
  ownership_type: "unknown",
  project_type: "residential",
  payment_plan_count: 0,
  image_count: 0,
  is_featured: 0,
  accepts_inquiries: 1,
  active_listing_count: 0,
  source_updated_at: new Date("2026-09-04T20:04:11Z"),
};

describe("handoverQuarter", () => {
  it("turns a handover date into the quarter the market quotes", () => {
    expect(handoverQuarter("2027-11-05")).toEqual({ quarter: "Q4", year: 2027 });
    expect(handoverQuarter("2027-01-01")).toEqual({ quarter: "Q1", year: 2027 });
  });

  it("returns null rather than guessing when there is no date", () => {
    expect(handoverQuarter(null)).toBeNull();
    expect(handoverQuarter("")).toBeNull();
  });
});

describe("displayStatus", () => {
  it("derives nearing completion from construction plus a percentage", () => {
    expect(displayStatus({ status: "under_construction", completion_percentage: 86 })).toBe("nearing_completion");
  });

  it("leaves construction alone below the threshold", () => {
    expect(displayStatus({ status: "under_construction", completion_percentage: 73 })).toBe("under_construction");
  });

  it("never labels an unknown completion as nearing anything", () => {
    expect(displayStatus({ status: "under_construction", completion_percentage: null })).toBe("under_construction");
  });

  it("does not touch any other lifecycle value", () => {
    expect(displayStatus({ status: "completed", completion_percentage: 100 })).toBe("completed");
    expect(displayStatus({ status: "announced", completion_percentage: null })).toBe("announced");
  });
});

describe("serializeProjectCard", () => {
  const card = serializeProjectCard(row);

  it("carries the canonical URL the database wrote", () => {
    expect(card.canonicalUrl).toBe(row.canonical_path);
    expect(card.canonicalPath).toBe(row.canonical_path);
  });

  it("returns the developer as an object, not a name", () => {
    expect(card.developer).toEqual({ id: "410", slug: "omniyat", name: "Omniyat", logoUrl: null });
  });

  it("exposes the whole location hierarchy plus the deepest level", () => {
    expect(card.location.hierarchy.country.slug).toBe("united-arab-emirates");
    expect(card.location.hierarchy.community.name).toBe("Corniche Area");
    expect(card.location.deepest.name).toBe("Corniche Area");
  });

  it("converts driver decimals to numbers", () => {
    expect(card.priceRange).toEqual({ min: 4100000, max: 22038456.44, currency: "AED", baseMin: 4100000 });
    expect(card.location.latitude).toBeCloseTo(24.41361);
  });

  it("splits the aggregate columns into arrays and ranges", () => {
    expect(card.unitTypes).toEqual(["apartment", "penthouse"]);
    expect(card.bedrooms).toEqual({ min: 1, max: 4, values: [1, 2, 4] });
    expect(card.area).toEqual({ min: 720, max: 4600 });
  });

  it("summarises the payment plans without asserting one that does not exist", () => {
    expect(card.paymentPlan).toEqual({
      planCount: 2,
      minDownPaymentPercent: 10,
      hasPostHandover: true,
      types: ["construction_linked", "post_handover"],
    });
    expect(serializeProjectCard(bare).paymentPlan).toBeNull();
  });

  it("omits every unpublished field rather than defaulting it", () => {
    const empty = serializeProjectCard(bare);
    expect(empty.priceRange).toBeNull();
    expect(empty.startingPrice).toBeNull();
    expect(empty.bedrooms).toBeNull();
    expect(empty.area).toBeNull();
    expect(empty.handover).toBeNull();
    expect(empty.handoverDate).toBeNull();
    expect(empty.coverImage).toBeNull();
    expect(empty.completionPercentage).toBeNull();
    expect(empty.availability).toBeNull();
    expect(empty.tagline).toBeNull();
    expect(empty.unitTypes).toEqual([]);
  });

  it("reports an unknown ownership type as absent rather than as 'unknown'", () => {
    expect(serializeProjectCard(bare).ownershipType).toBeNull();
    expect(serializeProjectCard(row).ownershipType).toBe("freehold");
  });

  it("keeps the stored lifecycle alongside the displayed one", () => {
    const nearing = serializeProjectCard({ ...row, completion_percentage: 92 });
    expect(nearing.status).toBe("nearing_completion");
    expect(nearing.lifecycleStatus).toBe("under_construction");
  });

  it("returns null for no row at all", () => {
    expect(serializeProjectCard(null)).toBeNull();
  });
});

describe("serializeProjectDetail", () => {
  const detail = serializeProjectDetail({
    row,
    record: {
      description: "A development in Abu Dhabi.",
      marketing_heading: "Live on the Corniche",
      highlights: '["Private beach","Sky lounge"]',
      address_line1: "Plot 4, Corniche Road",
      seo_title: "Creek Waters",
      seo_description: "Prices and plans.",
      construction_start_date: new Date("2023-06-01T00:00:00Z"),
      developer_public_id: "01DEV",
      developer_description: "An Abu Dhabi developer.",
      developer_website: "https://example.com",
      developer_founded_year: 2005,
      developer_country: "United Arab Emirates",
    },
    unitTypes: [
      {
        public_id: "01UNIT",
        unit_type: "apartment",
        name: null,
        bedrooms: 2,
        bathrooms: "2.0",
        min_size: "1150.00",
        max_size: "1340.00",
        starting_price: "2650000.00",
        max_price: null,
        currency_code: "AED",
        availability: "limited",
        available_units: 22,
        total_units: 140,
        area_unit: "sqft",
      },
    ],
    paymentPlans: [
      { id: 7, name: "60/40", description: null, plan_type: "construction_linked", down_payment_percent: "20.000",
        during_construction_percent: "40.000", on_handover_percent: "40.000", post_handover_percent: null,
        post_handover_months: null, waives_registration_fee: 1, service_charge_waiver_years: null,
        guaranteed_return_percent: null, guaranteed_return_years: null },
    ],
    milestones: [
      { plan_id: 7, sequence_number: 1, name: "On booking", trigger_type: "booking", construction_percent: null,
        months_offset: null, fixed_date: null, amount_percent: "20.000", fixed_amount: null, currency_code: null, notes: null },
      // A milestone on another plan must not leak into this one.
      { plan_id: 8, sequence_number: 1, name: "Elsewhere", trigger_type: "booking", amount_percent: "100.000" },
    ],
    amenities: [{ slug: "infinity-pool", label: "Infinity pool", category: null }],
    media: [
      { role: "gallery", sort_order: 0, is_primary: 1, caption: null, public_id: "01IMG", url: "https://cdn/1.jpg", width: 1200, height: 800, mime_type: "image/jpeg", alt_text: "Tower" },
      { role: "masterplan", sort_order: 0, is_primary: 0, caption: null, public_id: "01MAP", url: "https://cdn/map.jpg", width: null, height: null, mime_type: "image/jpeg", alt_text: null },
    ],
    documents: [
      { public_id: "01PUB", document_type: "brochure", title: "Brochure", description: null, visibility: "public", page_count: 45, file_size_bytes: 100, version: "v1", url: "https://cdn/b.pdf" },
      { public_id: "01GATE", document_type: "price_list", title: "Price list", description: null, visibility: "gated", page_count: 14, file_size_bytes: 200, version: "v1", url: null },
    ],
    floorPlans: [
      { name: "Type A", floor_level: 12, total_area_sqm: "110.00", total_area_sqft: "1184.00", requires_lead: 1, url: "https://cdn/plan.pdf" },
    ],
    tours: [{ public_id: "01TOUR", title: "Tour", tour_type: "matterport", provider: "matterport", embed_url: "https://tour", thumbnail_url: null }],
    buildings: [{ public_id: "01BLD", name: "Tower A", slug: "tower-a", building_type: "residential_tower", floors_above_ground: 40, total_units: 122, status: "under_construction", completion_year: 2027, handover_date: null }],
    listings: [{ id: "01LST" }],
    related: { similar: [bare], byDeveloper: [], recent: [] },
  });

  it("keeps everything the card had", () => {
    expect(detail.name).toBe("Creek Waters");
    expect(detail.canonicalUrl).toBe(row.canonical_path);
  });

  it("parses highlights whether the driver hydrated the JSON or not", () => {
    expect(detail.highlights).toEqual(["Private beach", "Sky lounge"]);
  });

  it("enriches the developer without losing the card's fields", () => {
    expect(detail.developer).toMatchObject({ slug: "omniyat", publicId: "01DEV", foundedYear: 2005, country: "United Arab Emirates" });
  });

  it("attaches each milestone to its own plan only", () => {
    expect(detail.paymentPlans).toHaveLength(1);
    expect(detail.paymentPlans[0].milestones.map((milestone) => milestone.name)).toEqual(["On booking"]);
  });

  it("keeps a gated document listed but unlinked", () => {
    const gated = detail.documents.find((document) => document.visibility === "gated");
    expect(gated.title).toBe("Price list");
    expect(gated.url).toBeNull();
    expect(detail.documents.find((document) => document.visibility === "public").url).toBe("https://cdn/b.pdf");
  });

  it("withholds a lead-gated floor plan's file while still naming the plan", () => {
    expect(detail.floorPlans[0]).toMatchObject({ name: "Type A", requiresLead: true, url: null });
  });

  it("separates gallery from masterplan and picks a cover", () => {
    expect(detail.media.gallery).toHaveLength(1);
    expect(detail.media.masterplan).toHaveLength(1);
    expect(detail.media.cover.url).toBe("https://cdn/1.jpg");
  });

  it("serialises unit types with a real size range and price", () => {
    expect(detail.unitTypeDetails[0]).toMatchObject({
      unitType: "apartment",
      bedrooms: 2,
      size: { min: 1150, max: 1340, unit: "sqft" },
      startingPrice: { amount: 2650000, currency: "AED" },
      availability: "limited",
    });
  });

  it("builds a map only from real coordinates", () => {
    expect(detail.map).toMatchObject({ latitude: 24.41361, longitude: 54.43295 });
    const noCoordinates = serializeProjectDetail({ row: { ...row, latitude: null, longitude: null }, record: {} });
    expect(noCoordinates.map).toBeNull();
  });

  it("serialises the related collections as cards", () => {
    expect(detail.related.similar[0].name).toBe("Announced Tower");
    expect(detail.related.byDeveloper).toEqual([]);
  });
});

describe("serializeDeveloper", () => {
  it("returns the fields a profile card needs", () => {
    expect(
      serializeDeveloper({
        public_id: "01DEV",
        slug: "omniyat",
        name: "Omniyat",
        logo_url: null,
        website_url: null,
        description: null,
        founded_year: 2005,
        country_name: "United Arab Emirates",
        country_slug: "united-arab-emirates",
        project_count: 2,
      })
    ).toEqual({
      id: "01DEV",
      slug: "omniyat",
      name: "Omniyat",
      logoUrl: null,
      website: null,
      description: null,
      foundedYear: 2005,
      country: { name: "United Arab Emirates", slug: "united-arab-emirates" },
      projectCount: 2,
    });
  });

  it("returns null for no row", () => {
    expect(serializeDeveloper(null)).toBeNull();
  });
});
