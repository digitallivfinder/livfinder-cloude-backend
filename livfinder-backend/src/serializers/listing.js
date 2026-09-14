import { bool, int, isoDate, isoDay, jsonField, money, num } from "./primitives.js";
import { categoryByRootId } from "../utils/categories.js";
import { descriptionToHtml, descriptionToText } from "../utils/richText.js";

/**
 * Card projection.
 *
 * Field names mirror the fixtures the public components already read
 * (`media[0]`, `price.amount`, `city`, `country`, `category`, `canonicalUrl`,
 * `sponsored`) so no component had to change when the data became real.
 *
 * Deliberately carries only the cover image — the gallery belongs to the detail
 * response, not to twenty cards on a results page.
 */
export function serializeListingCard(row) {
  const definition = categoryByRootId(row.root_category_id);
  const specs = jsonField(row.spec_labels, {}) || {};
  return {
    id: row.public_id,
    listingId: int(row.listing_id ?? row.id),
    publicId: row.reference,
    reference: row.reference,
    category: definition?.frontendId ?? null,
    listingType: definition?.listingType ?? null,
    categorySlug: row.category_slug ?? null,
    purpose: row.purpose_slug === "for-rent" ? "rent" : row.purpose_slug === "for-charter" ? "charter" : "sale",
    purposeSlug: row.purpose_slug ?? null,
    title: row.title,
    slug: row.slug,
    canonicalUrl: row.canonical_path,
    canonicalPath: row.canonical_path,
    price: money(row.price, row.currency_code),
    priceBase: num(row.price_base),
    pricePeriod: row.price_period || null,
    isPriceHidden: bool(row.is_price_hidden),
    coverImage: row.cover_image_url
      ? { url: row.cover_image_url, alt: row.cover_image_alt || row.title }
      : null,
    // The public components index `media[0]`; keep that working with exactly
    // one entry rather than shipping a gallery to every card.
    media: row.cover_image_url ? [row.cover_image_url] : [],
    imageCount: int(row.image_count) ?? 0,
    locationLabel: row.location_label || null,
    country: row.country_slug || null,
    state: row.state_slug || null,
    city: row.city_slug || null,
    area: row.community_slug || null,
    countryName: row.country_name || null,
    cityName: row.city_name || null,
    latitude: num(row.latitude),
    longitude: num(row.longitude),
    organizationId: row.organization_id ? String(row.organization_id) : null,
    organizationSlug: row.organization_slug || null,
    organizationName: row.organization_name || null,
    organizationLogo: row.organization_logo_url || null,
    agentId: row.agent_id ? String(row.agent_id) : null,
    agentSlug: row.agent_slug || null,
    agentName: row.agent_name || null,
    agentPhoto: row.agent_photo_url || null,
    featured: bool(row.is_featured),
    sponsored: bool(row.is_premium),
    verified: bool(row.is_verified),
    exclusive: bool(row.is_exclusive),
    hasVirtualTour: bool(row.has_virtual_tour),
    specs,
    specValues: {
      a: int(row.spec_a),
      b: int(row.spec_b),
      c: int(row.spec_c),
      d: int(row.spec_d),
      e: int(row.spec_e),
      f: int(row.spec_f),
    },
    // Real-estate cards read these directly.
    bedrooms: int(specs.beds),
    bathrooms: int(specs.baths),
    builtArea: specs.area_sqft ? `${Math.round(num(specs.area_sqft)).toLocaleString("en")} sq ft` : null,
    propertyType: specs.type || null,
    make: row.brand_slug || null,
    model: row.brand_model_slug || null,
    year: specs.year ? String(specs.year) : null,
    brandName: row.brand_name || null,
    modelName: row.brand_model_name || null,
    qualityScore: int(row.quality_score),
    publishedAt: isoDay(row.published_at),
    updatedAt: isoDay(row.source_updated_at ?? row.updated_at),
    status: "published",
    legalRestriction: false,
    explicitDenyFlags: [],
  };
}

const DETAIL_BUILDERS = {
  "real-estate": (detail) => ({
    propertyType: detail.category_name || null,
    transactionType: detail.purpose_slug === "for-rent" ? "rent" : "sale",
    bedrooms: int(detail.bedrooms),
    bathrooms: int(detail.bathrooms),
    halfBathrooms: int(detail.half_bathrooms),
    receptionRooms: int(detail.reception_rooms),
    maidRooms: int(detail.maid_rooms),
    parkingSpaces: int(detail.parking_spaces),
    builtAreaSqft: num(detail.built_area_sqft),
    builtAreaSqm: num(detail.built_area_sqm),
    plotAreaSqft: num(detail.plot_area_sqft),
    plotAreaSqm: num(detail.plot_area_sqm),
    builtArea: detail.built_area_sqft ? `${Math.round(num(detail.built_area_sqft)).toLocaleString("en")} sq ft` : null,
    plotArea: detail.plot_area_sqft ? `${Math.round(num(detail.plot_area_sqft)).toLocaleString("en")} sq ft` : null,
    floorNumber: int(detail.floor_number),
    totalFloors: int(detail.total_floors),
    unitNumber: detail.unit_number || null,
    buildingName: detail.building_name || null,
    yearBuilt: int(detail.year_built),
    completionStatus: detail.completion_status || null,
    handoverDate: isoDay(detail.handover_date),
    furnishing: detail.furnishing || null,
    ownershipType: detail.ownership_type || null,
    viewType: detail.view_type || null,
    orientation: detail.orientation || null,
    rentPeriod: detail.rent_period || null,
    chequesAccepted: int(detail.cheques_accepted),
    availableFrom: isoDay(detail.available_from),
    serviceChargePerSqft: num(detail.service_charge_per_sqft),
    rentalYieldPercentage: num(detail.rental_yield_percentage),
    permitNumber: detail.permit_number || detail.dld_permit_number || null,
    isNewBuild: bool(detail.is_new_build),
    isTenanted: bool(detail.is_tenanted),
  }),
  cars: (detail) => ({
    year: detail.model_year ? String(detail.model_year) : null,
    modelYear: int(detail.model_year),
    mileageKm: int(detail.mileage_km),
    mileage: detail.mileage_km ? `${int(detail.mileage_km).toLocaleString("en")} km` : null,
    bodyType: detail.body_type || null,
    transmission: detail.transmission || null,
    fuelType: detail.fuel_type || null,
    drivetrain: detail.drivetrain || null,
    engineSizeCc: int(detail.engine_size_cc),
    cylinders: int(detail.cylinders),
    horsepower: int(detail.horsepower),
    torqueNm: int(detail.torque_nm),
    topSpeedKmh: int(detail.top_speed_kmh),
    acceleration: num(detail.acceleration_0_100),
    exteriorColor: detail.exterior_color || null,
    interiorColor: detail.interior_color || null,
    doors: int(detail.doors),
    seats: int(detail.seats),
    condition: detail.condition_type || null,
    steeringSide: detail.steering_side || null,
    regionalSpec: detail.regional_spec || null,
    ownersCount: int(detail.owners_count),
    serviceHistory: detail.service_history || null,
    isAccidentFree: bool(detail.is_accident_free),
    isLimitedEdition: bool(detail.is_limited_edition),
    // VIN is never published in full.
    vinDisclosure: detail.vin ? "masked" : "not-supplied",
  }),
  yachts: (detail) => ({
    year: detail.build_year ? String(detail.build_year) : null,
    buildYear: int(detail.build_year),
    refitYear: int(detail.refit_year),
    lengthOverallFt: num(detail.length_overall_ft),
    lengthOverallM: num(detail.length_overall_m),
    beamM: num(detail.beam_m),
    draftM: num(detail.draft_m),
    grossTonnage: num(detail.gross_tonnage),
    vesselType: detail.vessel_type || null,
    hullMaterial: detail.hull_material || null,
    cabins: int(detail.cabins),
    berths: int(detail.berths),
    heads: int(detail.heads),
    guestsSleeping: int(detail.guests_sleeping),
    guestsCruising: int(detail.guests_cruising),
    crewCapacity: int(detail.crew_capacity),
    engineMake: detail.engine_make || null,
    engineModel: detail.engine_model || null,
    engineHours: int(detail.engine_hours),
    cruisingSpeedKnots: num(detail.cruising_speed_knots),
    maxSpeedKnots: num(detail.max_speed_knots),
    rangeNm: int(detail.range_nm),
    homePort: detail.home_port || null,
    isCharterAvailable: bool(detail.is_charter_available),
    isVatPaid: bool(detail.is_vat_paid),
  }),
  jets: aviationDetail,
  helicopters: aviationDetail,
  watches: (detail) => ({
    referenceNumber: detail.reference_number || null,
    year: detail.year_of_production ? String(detail.year_of_production) : null,
    yearOfProduction: int(detail.year_of_production),
    caseMaterial: detail.case_material || null,
    caseDiameterMm: num(detail.case_diameter_mm),
    caseThicknessMm: num(detail.case_thickness_mm),
    bezelMaterial: detail.bezel_material || null,
    crystal: detail.crystal || null,
    dialColor: detail.dial_color || null,
    dialType: detail.dial_type || null,
    braceletMaterial: detail.bracelet_material || null,
    movement: detail.movement_type || null,
    caliber: detail.caliber || null,
    powerReserveHours: int(detail.power_reserve_hours),
    jewels: int(detail.jewels),
    waterResistanceM: int(detail.water_resistance_m),
    complications: jsonField(detail.complications, []),
    condition: detail.condition_grade || null,
    hasOriginalBox: bool(detail.has_original_box),
    hasOriginalPapers: bool(detail.has_original_papers),
    isFullSet: bool(detail.is_full_set),
    isLimitedEdition: bool(detail.is_limited_edition),
    gender: detail.gender || null,
  }),
};

function aviationDetail(detail) {
  return {
    aircraftType: detail.aircraft_type || null,
    year: detail.year_built ? String(detail.year_built) : null,
    yearBuilt: int(detail.year_built),
    yearRefurbished: int(detail.year_refurbished),
    totalTimeHours: int(detail.total_time_hours),
    totalLandings: int(detail.total_landings),
    cycles: int(detail.cycles),
    passengerCapacity: int(detail.passenger_capacity),
    crewCapacity: int(detail.crew_capacity),
    berths: int(detail.berths),
    rangeNm: int(detail.range_nm),
    maxCruiseSpeedKts: int(detail.max_cruise_speed_kts),
    maxAltitudeFt: int(detail.max_altitude_ft),
    engineCount: int(detail.engine_count),
    engineMake: detail.engine_make || null,
    engineModel: detail.engine_model || null,
    engineProgram: detail.engine_program || null,
    avionicsSuite: detail.avionics_suite || null,
    interiorConfiguration: detail.interior_configuration || null,
    baseAirportCode: detail.base_airport_code || null,
    nextInspectionDue: isoDay(detail.next_inspection_due),
    isCharterAvailable: bool(detail.is_charter_available),
    charterHourlyRate: num(detail.charter_hourly_rate),
    // Serial and registration are controlled disclosures, not public fields.
    serialDisclosure: detail.serial_number ? "on-request" : "not-supplied",
  };
}

/**
 * Full detail projection: the listing, its category-specific fields, the
 * ordered gallery, features, attributes, and the contact channels the listing
 * actually allows.
 */
export function serializeListingDetail({ listing, detail, media = [], features = [], attributes = [], organization, agent, project }) {
  const definition = categoryByRootId(listing.root_category_id);
  const listingType = definition?.listingType;
  const buildDetail = DETAIL_BUILDERS[listingType];
  const gallery = media
    .filter((item) => item.media_type === "image")
    .map((item) => ({
      id: item.public_id || String(item.id),
      mediaId: String(item.id),
      url: item.url,
      thumbnailUrl: item.thumbnail_url || item.url,
      alt: item.alt_text || listing.title,
      caption: item.caption || null,
      tag: item.tag || null,
      sortOrder: int(item.sort_order) ?? 0,
      isCover: bool(item.is_cover),
      width: int(item.width),
      height: int(item.height),
    }));

  return {
    id: listing.public_id,
    listingId: int(listing.id),
    publicId: listing.reference,
    reference: listing.reference,
    category: definition?.frontendId ?? null,
    listingType,
    categoryId: int(listing.category_id),
    categorySlug: listing.category_slug,
    categoryName: listing.category_name,
    rootCategoryId: int(listing.root_category_id),
    purpose: listing.purpose_slug === "for-rent" ? "rent" : listing.purpose_slug === "for-charter" ? "charter" : "sale",
    purposeSlug: listing.purpose_slug,
    title: listing.title,
    subtitle: listing.subtitle || null,
    slug: listing.slug,
    propertyUrl: listing.slug,
    description: listing.description || "",
    // What a page renders — sanitised rich text, or plain text as escaped paragraphs — and
    // the words alone for meta descriptions and structured data.
    descriptionHtml: descriptionToHtml(listing.description),
    descriptionText: descriptionToText(listing.description),
    canonicalUrl: listing.canonical_path,
    canonicalPath: listing.canonical_path,
    price: money(listing.price, listing.currency_code),
    priceType: listing.price_type,
    pricePeriod: listing.price_period || null,
    priceMin: num(listing.price_min),
    priceMax: num(listing.price_max),
    pricePerArea: num(listing.price_per_area),
    serviceCharge: num(listing.service_charge),
    isPriceHidden: bool(listing.is_price_hidden),
    country: listing.country_slug || null,
    state: listing.state_slug || null,
    city: listing.city_slug || null,
    area: listing.community_slug || null,
    subCommunity: listing.sub_community_slug || null,
    hierarchy: {
      country: listing.country_slug || null,
      state: listing.state_slug || null,
      city: listing.city_slug || null,
      community: listing.community_slug || null,
      subcommunity: listing.sub_community_slug || null,
    },
    locationLabel: [listing.sub_community_name, listing.community_name, listing.city_name, listing.country_name]
      .filter(Boolean)
      .join(", "),
    locationNames: {
      country: listing.country_name || null,
      state: listing.state_name || null,
      city: listing.city_name || null,
      community: listing.community_name || null,
      subCommunity: listing.sub_community_name || null,
    },
    // The ids behind `locationNames`, so an edit form reopens the same selection
    // rather than guessing a place back from its name.
    locationIds: {
      country: int(listing.country_id),
      state: int(listing.state_id),
      city: int(listing.city_id),
      community: int(listing.community_id),
      subCommunity: int(listing.sub_community_id),
    },
    address: bool(listing.hide_exact_location) ? null : listing.address || null,
    addressDisplayPrecision: bool(listing.hide_exact_location) ? "locality" : "exact",
    latitude: bool(listing.hide_exact_location) ? null : num(listing.latitude),
    longitude: bool(listing.hide_exact_location) ? null : num(listing.longitude),
    media: gallery.map((item) => item.url),
    gallery,
    coverImage: listing.cover_image_url
      ? { url: listing.cover_image_url, alt: listing.cover_image_alt || listing.title }
      : gallery[0] || null,
    documents: media
      .filter((item) => ["document", "floor_plan", "virtual_tour", "video"].includes(item.media_type))
      .map((item) => ({
        id: item.public_id || String(item.id),
        // The `listing_media` row id — what the edit, retype and remove calls address.
        mediaId: String(item.id),
        type: item.media_type,
        documentType: item.tag || null,
        url: item.url,
        label: item.caption || item.alt_text || item.media_type,
      })),
    features: features.map((feature) => ({
      id: int(feature.id),
      slug: feature.slug,
      name: feature.name,
      group: feature.group_name || null,
      isHighlighted: bool(feature.is_highlighted),
    })),
    amenities: features.map((feature) => feature.name),
    attributes: attributes.map((attribute) => ({
      key: attribute.code,
      label: attribute.name,
      value:
        attribute.value_text ??
        attribute.option_label ??
        (attribute.value_number !== null && attribute.value_number !== undefined ? num(attribute.value_number) : null) ??
        (attribute.value_boolean !== null && attribute.value_boolean !== undefined ? bool(attribute.value_boolean) : null) ??
        isoDay(attribute.value_date),
      unit: attribute.unit || null,
    })),
    make: listing.brand_slug || null,
    model: listing.brand_model_slug || null,
    brand: listing.brand_slug || null,
    collection: listing.brand_model_slug || null,
    manufacturer: listing.brand_slug || null,
    brandName: listing.brand_name || null,
    modelName: listing.brand_model_name || null,
    project: project
      ? {
          id: project.public_id,
          name: project.name,
          slug: project.slug,
          status: project.status,
          completionDate: isoDay(project.expected_completion_date),
        }
      : null,
    organizationId: listing.organization_id ? String(listing.organization_id) : null,
    organization: organization || null,
    agentId: listing.agent_id ? String(listing.agent_id) : null,
    agent: agent || null,
    contact: {
      name: listing.contact_name || null,
      phone: bool(listing.allow_call) ? listing.contact_phone || null : null,
      whatsapp: bool(listing.allow_whatsapp) ? listing.contact_whatsapp || null : null,
      email: bool(listing.allow_email) ? listing.contact_email || null : null,
      allowCall: bool(listing.allow_call),
      allowWhatsapp: bool(listing.allow_whatsapp),
      allowEmail: bool(listing.allow_email),
    },
    inquiryEnabled: true,
    featured: bool(listing.is_featured),
    sponsored: bool(listing.is_premium),
    verified: bool(listing.is_verified),
    exclusive: bool(listing.is_exclusive),
    isNewListing: bool(listing.is_new_listing),
    badges: jsonField(listing.badge_labels, []),
    hasVirtualTour: bool(listing.has_virtual_tour),
    hasFloorPlan: bool(listing.has_floor_plan),
    hasBrochure: bool(listing.has_brochure),
    viewCount: int(listing.view_count),
    inquiryCount: int(listing.inquiry_count),
    favouriteCount: int(listing.favourite_count),
    seo: {
      title: listing.seo_title || listing.title,
      description: listing.seo_description || (listing.description || "").slice(0, 300),
      indexable: bool(listing.is_indexable),
    },
    status: "published",
    source: listing.source,
    publishedAt: isoDay(listing.published_at),
    createdAt: isoDay(listing.created_at),
    updatedAt: isoDay(listing.updated_at),
    revision: int(listing.quality_score) ?? 0,
    etag: `W/"${listing.public_id}-${new Date(listing.updated_at).getTime()}"`,
    legalRestriction: false,
    explicitDenyFlags: [],
    ...(buildDetail && detail ? buildDetail({ ...detail, purpose_slug: listing.purpose_slug, category_name: listing.category_name }) : {}),
  };
}

export { isoDate };
