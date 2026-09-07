import { bool, int, isoDate, isoDay, jsonField, money, num } from "./primitives.js";
import { NEARING_COMPLETION_THRESHOLD } from "../modules/projects/projects.filters.js";

/**
 * Public project DTOs.
 *
 * Projects are not listings and are deliberately not passed through the listing
 * serializer: they have a developer rather than an agency, a handover rather
 * than a price period, unit types rather than a bedroom count, and payment plans
 * rather than a single price. Sharing the shape would mean either lying about
 * half the fields or filling both objects with nulls.
 *
 * Every field is nullable and absent-when-unknown. A card renders what the
 * record actually holds; it never fabricates a bedroom count, a handover date,
 * a price or a payment plan to fill a slot in the layout.
 */

const csv = (value) =>
  String(value ?? "")
    .split(",")
    .map((entry) => entry.trim())
    .filter(Boolean);

/** `2027-06-14` → `Q2 2027`, which is how off-plan handover is quoted. */
export function handoverQuarter(date) {
  const day = isoDay(date);
  if (!day) return null;
  const month = Number(day.slice(5, 7));
  return { quarter: `Q${Math.floor((month - 1) / 3) + 1}`, year: Number(day.slice(0, 4)) };
}

/**
 * The status a visitor is shown.
 *
 * `nearing_completion` is derived here and only here, from the stored lifecycle
 * plus the completion percentage, so the badge and the filter agree by
 * construction. An unfiltered project is never labelled "Ready" — that word
 * belongs to `completed`/`handed_over` and nothing else.
 */
export function displayStatus(row) {
  if (row.status === "under_construction" && num(row.completion_percentage) >= NEARING_COMPLETION_THRESHOLD) {
    return "nearing_completion";
  }
  return row.status;
}

function locationObject(row) {
  const level = (slug, name, id, type) => (slug ? { slug, name, id: id ? `${type}:${id}` : null, type } : null);
  const hierarchy = {
    country: level(row.country_slug, row.country_name, row.country_id, "country"),
    state: level(row.state_slug, row.state_name, row.state_id, "state"),
    city: level(row.city_slug, row.city_name, row.city_id, "city"),
    community: level(row.community_slug, row.community_name, row.community_id, "community"),
  };
  return {
    label: row.location_label || null,
    hierarchy,
    // The deepest level the project is actually placed at — what a card prints
    // and what "Back to Projects" falls back to.
    deepest: hierarchy.community || hierarchy.city || hierarchy.state || hierarchy.country || null,
    latitude: num(row.latitude),
    longitude: num(row.longitude),
  };
}

function priceRange(row) {
  const min = num(row.min_price);
  const max = num(row.max_price);
  if (min === null && max === null) return null;
  return { min, max, currency: row.currency_code || null, baseMin: num(row.min_price_base) };
}

function paymentPlanSummary(row) {
  const count = int(row.payment_plan_count) || 0;
  if (!count) return null;
  return {
    planCount: count,
    minDownPaymentPercent: num(row.min_down_payment_percent),
    hasPostHandover: bool(row.has_post_handover),
    types: csv(row.payment_plan_types),
  };
}

/**
 * The card DTO. Everything the search grid, the homepage rail and the related
 * rails render comes from exactly this shape.
 */
export function serializeProjectCard(row) {
  if (!row) return null;
  const bedroomValues = csv(row.bedroom_values).map(Number).filter(Number.isFinite);
  return {
    id: row.public_id,
    publicId: row.public_id,
    name: row.name,
    slug: row.slug,
    tagline: row.tagline || null,
    canonicalUrl: row.canonical_path,
    canonicalPath: row.canonical_path,

    developer: row.developer_slug
      ? {
          id: row.developer_brand_id ? String(row.developer_brand_id) : null,
          slug: row.developer_slug,
          name: row.developer_name,
          logoUrl: row.developer_logo_url || null,
        }
      : null,

    location: locationObject(row),

    projectType: row.project_type,
    status: displayStatus(row),
    lifecycleStatus: row.status,
    launchStatus: row.launch_status,
    ownershipType: row.ownership_type === "unknown" ? null : row.ownership_type,

    launchDate: isoDay(row.launch_date),
    handoverDate: isoDay(row.handover_date),
    handover: handoverQuarter(row.handover_date),
    completionPercentage: int(row.completion_percentage),

    totalUnits: int(row.total_units),
    availableUnits: int(row.available_units),
    buildingCount: int(row.building_count),
    availability: row.availability || null,

    priceRange: priceRange(row),
    startingPrice: money(row.min_price, row.currency_code),

    unitTypes: csv(row.unit_types),
    bedrooms: bedroomValues.length
      ? { min: Math.min(...bedroomValues), max: Math.max(...bedroomValues), values: bedroomValues }
      : null,
    area: num(row.area_min) === null && num(row.area_max) === null ? null : { min: num(row.area_min), max: num(row.area_max) },

    paymentPlan: paymentPlanSummary(row),

    coverImage: row.cover_image_url ? { url: row.cover_image_url } : null,
    /**
     * The first few gallery images, so a card's slider is real.
     *
     * Newline-separated in the projection because a URL cannot contain one.
     * Empty when the project has published no gallery — the card then shows its
     * cover, or its lettered mark, rather than paging through nothing.
     */
    galleryImages: String(row.gallery_urls ?? "")
      .split("\n")
      .map((url) => url.trim())
      .filter(Boolean),
    imageCount: int(row.image_count) || 0,
    featured: bool(row.is_featured),
    acceptsInquiries: bool(row.accepts_inquiries),
    // Drives the "View available properties" link, and its absence hides it.
    activeListingCount: int(row.active_listing_count) || 0,

    publishedAt: isoDate(row.published_at),
    updatedAt: isoDate(row.source_updated_at),
  };
}

function serializeUnitType(row) {
  return {
    id: row.public_id,
    unitType: row.unit_type,
    name: row.name || null,
    bedrooms: int(row.bedrooms),
    bathrooms: num(row.bathrooms),
    size: num(row.min_size) === null && num(row.max_size) === null
      ? null
      : { min: num(row.min_size), max: num(row.max_size), unit: row.area_unit || null },
    startingPrice: money(row.starting_price, row.currency_code),
    maxPrice: money(row.max_price, row.currency_code),
    availability: row.availability,
    availableUnits: int(row.available_units),
    totalUnits: int(row.total_units),
  };
}

function serializeMilestone(row) {
  return {
    sequence: int(row.sequence_number),
    name: row.name,
    triggerType: row.trigger_type,
    constructionPercent: num(row.construction_percent),
    monthsOffset: int(row.months_offset),
    date: isoDay(row.fixed_date),
    percentage: num(row.amount_percent),
    amount: money(row.fixed_amount, row.currency_code),
    notes: row.notes || null,
  };
}

function serializePaymentPlan(plan, milestones) {
  return {
    id: String(plan.id),
    name: plan.name,
    description: plan.description || null,
    type: plan.plan_type,
    downPaymentPercent: num(plan.down_payment_percent),
    duringConstructionPercent: num(plan.during_construction_percent),
    onHandoverPercent: num(plan.on_handover_percent),
    postHandoverPercent: num(plan.post_handover_percent),
    postHandoverMonths: int(plan.post_handover_months),
    waivesRegistrationFee: bool(plan.waives_registration_fee),
    serviceChargeWaiverYears: int(plan.service_charge_waiver_years),
    guaranteedReturnPercent: num(plan.guaranteed_return_percent),
    guaranteedReturnYears: int(plan.guaranteed_return_years),
    milestones: milestones.filter((row) => String(row.plan_id) === String(plan.id)).map(serializeMilestone),
  };
}

function serializeMedia(media) {
  const byRole = (role) => media.filter((row) => row.role === role);
  const asImage = (row) => ({
    id: row.public_id,
    url: row.url,
    alt: row.alt_text || row.caption || null,
    caption: row.caption || null,
    width: int(row.width),
    height: int(row.height),
    primary: bool(row.is_primary),
  });
  const gallery = byRole("gallery").map(asImage);
  const cover = byRole("cover").map(asImage)[0] || gallery.find((image) => image.primary) || gallery[0] || null;
  return {
    cover,
    gallery,
    masterplan: byRole("masterplan").map(asImage),
    video: byRole("video").map((row) => ({ id: row.public_id, url: row.url, mimeType: row.mime_type })),
  };
}

/**
 * The detail DTO.
 *
 * `documents` carries `gated` entries without a URL on purpose: the page has to
 * be able to say a brochure exists and offer the enquiry that unlocks it.
 * `restricted` and `internal` documents never reach this function at all — the
 * repository excludes them in SQL.
 */
export function serializeProjectDetail({
  row,
  record,
  unitTypes = [],
  paymentPlans = [],
  milestones = [],
  amenities = [],
  media = [],
  documents = [],
  floorPlans = [],
  tours = [],
  buildings = [],
  listings = [],
  related = {},
}) {
  const card = serializeProjectCard(row);
  const highlights = jsonField(record?.highlights, []) || [];

  return {
    ...card,
    description: record?.description || null,
    marketingHeading: record?.marketing_heading || null,
    highlights: Array.isArray(highlights) ? highlights.filter(Boolean) : [],
    address: record?.address_line1 || null,
    constructionStartDate: isoDay(record?.construction_start_date),

    developer: card.developer
      ? {
          ...card.developer,
          publicId: record?.developer_public_id || null,
          description: record?.developer_description || null,
          website: record?.developer_website || null,
          foundedYear: int(record?.developer_founded_year),
          country: record?.developer_country || null,
        }
      : null,

    amenities: amenities.map((row) => ({ slug: row.slug, label: row.label, category: row.category || null })),
    unitTypeDetails: unitTypes.map(serializeUnitType),
    paymentPlans: paymentPlans.map((plan) => serializePaymentPlan(plan, milestones)),
    media: serializeMedia(media),
    virtualTours: tours.map((row) => ({
      id: row.public_id,
      title: row.title || null,
      type: row.tour_type,
      provider: row.provider,
      embedUrl: row.embed_url,
      thumbnailUrl: row.thumbnail_url || null,
    })),
    floorPlans: floorPlans.map((row) => ({
      name: row.name,
      floorLevel: int(row.floor_level),
      areaSqm: num(row.total_area_sqm),
      areaSqft: num(row.total_area_sqft),
      requiresLead: bool(row.requires_lead),
      url: bool(row.requires_lead) ? null : row.url || null,
    })),
    documents: documents.map((row) => ({
      id: row.public_id,
      type: row.document_type,
      title: row.title,
      description: row.description || null,
      visibility: row.visibility,
      pageCount: int(row.page_count),
      fileSizeBytes: int(row.file_size_bytes),
      version: row.version || null,
      // Null for a gated document the caller has not unlocked. The page shows
      // the title and an enquiry prompt; it never links to a file it cannot serve.
      url: row.url || null,
    })),
    buildings: buildings.map((row) => ({
      id: row.public_id,
      name: row.name,
      slug: row.slug,
      buildingType: row.building_type,
      floors: int(row.floors_above_ground),
      totalUnits: int(row.total_units),
      status: row.status,
      completionYear: int(row.completion_year),
      handoverDate: isoDay(row.handover_date),
    })),
    listings,
    map:
      card.location.latitude === null || card.location.longitude === null
        ? null
        : { latitude: card.location.latitude, longitude: card.location.longitude, address: record?.address_line1 || card.location.label },
    seo: {
      title: record?.seo_title || null,
      description: record?.seo_description || null,
    },
    related: {
      similar: (related.similar || []).map(serializeProjectCard),
      byDeveloper: (related.byDeveloper || []).map(serializeProjectCard),
      recent: (related.recent || []).map(serializeProjectCard),
    },
  };
}

export function serializeDeveloper(row) {
  if (!row) return null;
  return {
    id: row.public_id,
    slug: row.slug,
    name: row.name,
    logoUrl: row.logo_url || null,
    website: row.website_url || null,
    description: row.description || null,
    foundedYear: int(row.founded_year),
    country: row.country_name ? { name: row.country_name, slug: row.country_slug } : null,
    projectCount: int(row.project_count) || 0,
  };
}
