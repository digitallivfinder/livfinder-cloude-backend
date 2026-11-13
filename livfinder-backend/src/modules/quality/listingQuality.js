import logger from "../../config/logger.js";
import { execute, query, queryOne } from "../../db/query.js";
import { categoryByRootId } from "../../utils/categories.js";
import { descriptionToText } from "../../utils/richText.js";

/**
 * Listing quality score, 0–100 (owner's rubric, 2026-11-13).
 *
 * The score is the share of points a listing earns across the parts below. A part that does not
 * apply to a listing (a permit where the country asks for none, rooms on a plot of land) is left
 * out of both sides, so every listing can reach 100 with what its own form offers.
 *
 * The score is stored on `listings.quality_score` and copied to `listing_search.quality_score`,
 * which ranks the website (featured and boosted listings still come first). It is recomputed
 * whenever the listing's search row is refreshed (every write path calls that) and by the
 * maintenance sweep for anything that slipped past (`quality_scored_at < updated_at`).
 *
 * `photoReview` is where an AI photo check will plug in later: when a listing has a review, a
 * "Photo quality" part joins the score. Until then that part does not apply and nothing changes.
 */

export const QUALITY_BANDS = [
  { id: "low", min: 0, label: "Needs work", tone: "red" },
  { id: "fair", min: 50, label: "Fair", tone: "yellow" },
  { id: "good", min: 80, label: "Good", tone: "green" },
];

export function qualityBand(score) {
  const value = Number(score) || 0;
  return [...QUALITY_BANDS].reverse().find((band) => value >= band.min) ?? QUALITY_BANDS[0];
}

/** Where in the listing form each kind of fix is made — the form's own step ids. */
const STEP = {
  basic: { id: "basics", label: "Basic Details" },
  pricing: { id: "pricing", label: "Pricing" },
  location: { id: "location", label: "Location" },
  specs: { id: "specifications", label: "Specifications" },
  features: { id: "features", label: "Features and Amenities" },
  description: { id: "description", label: "Description" },
  media: { id: "media", label: "Images and Media" },
};

const PARTS = {
  photos: { label: "Photos", max: 25 },
  description: { label: "Description", max: 15 },
  title: { label: "Title", max: 5 },
  required: { label: "Key details", max: 15 },
  extra: { label: "Extra details", max: 10 },
  amenities: { label: "Amenities and features", max: 10 },
  location: { label: "Location", max: 10 },
  media: { label: "Floor plan, video or tour", max: 5 },
  permit: { label: "Permit", max: 5 },
  photoQuality: { label: "Photo quality", max: 10 },
};

export const FULL_PHOTOS = 10;
export const FULL_DESCRIPTION = 750;
const FAIR_DESCRIPTION = 300;
export const FULL_AMENITIES = 5;

const LABELS = {
  price: "Price",
  bedrooms: "Bedrooms",
  bathrooms: "Bathrooms",
  builtArea: "Built area",
  plotArea: "Plot area",
  completionStatus: "Completion status",
  handoverDate: "Handover date",
  furnishing: "Furnishing",
  rentPeriod: "Rent period",
  viewType: "View",
  yearBuilt: "Year built",
  ownershipType: "Ownership type",
  parkingSpaces: "Parking spaces",
  halfBathrooms: "Half bathrooms",
  receptionRooms: "Reception rooms",
  maidRooms: "Maid's room",
  availableFrom: "Available from",
  chequesAccepted: "Cheques accepted",
  brand: "Make / brand",
  model: "Model",
  modelYear: "Model year",
  mileageKm: "Mileage",
  bodyType: "Body type",
  transmission: "Transmission",
  fuelType: "Fuel type",
  exteriorColor: "Exterior colour",
  conditionType: "Condition",
  regionalSpec: "Regional spec",
  drivetrain: "Drivetrain",
  engineSizeCc: "Engine size",
  cylinders: "Cylinders",
  horsepower: "Horsepower",
  torqueNm: "Torque",
  topSpeedKmh: "Top speed",
  interiorColor: "Interior colour",
  doors: "Doors",
  seats: "Seats",
  steeringSide: "Steering side",
  ownersCount: "Previous owners",
  buildYear: "Build year",
  lengthOverall: "Length overall",
  vesselType: "Vessel type",
  cabins: "Cabins",
  guestsSleeping: "Guests sleeping",
  engineMake: "Engine make",
  beamM: "Beam",
  draftM: "Draft",
  grossTonnage: "Gross tonnage",
  hullMaterial: "Hull material",
  berths: "Berths",
  heads: "Heads",
  guestsCruising: "Guests cruising",
  crewCapacity: "Crew capacity",
  engineModel: "Engine model",
  engineHours: "Engine hours",
  cruisingSpeedKnots: "Cruising speed",
  maxSpeedKnots: "Max speed",
  rangeNm: "Range",
  homePort: "Home port",
  aircraftType: "Aircraft type",
  totalTimeHours: "Total flight hours",
  passengerCapacity: "Passenger capacity",
  totalLandings: "Total landings",
  maxCruiseSpeedKts: "Max cruise speed",
  maxAltitudeFt: "Max altitude",
  engineCount: "Engine count",
  avionicsSuite: "Avionics suite",
  interiorConfiguration: "Interior configuration",
  baseAirportCode: "Base airport",
  referenceNumber: "Reference number",
  yearOfProduction: "Year of production",
  caseMaterial: "Case material",
  caseDiameterMm: "Case diameter",
  movementType: "Movement",
  conditionGrade: "Condition grade",
  caseThicknessMm: "Case thickness",
  bezelMaterial: "Bezel material",
  crystal: "Crystal",
  dialColor: "Dial colour",
  dialType: "Dial type",
  braceletMaterial: "Bracelet material",
  caliber: "Calibre",
  powerReserveHours: "Power reserve",
  jewels: "Jewels",
  waterResistanceM: "Water resistance",
  gender: "Gender",
};

const blank = (value) => value === undefined || value === null || value === "" || (typeof value === "string" && !value.trim());

/** Fields that are one measurement in two units: either counts. */
const EITHER = {
  builtArea: ["builtAreaSqft", "builtAreaSqm"],
  plotArea: ["plotAreaSqft", "plotAreaSqm"],
  lengthOverall: ["lengthOverallM", "lengthOverallFt"],
};
const filled = (input, key) => {
  if (key === "price") return input.priceOnRequest || !blank(input.price);
  if (key === "brand") return !blank(input.brandId);
  if (key === "model") return !blank(input.modelId);
  if (EITHER[key]) return EITHER[key].some((one) => !blank(input.detail?.[one]));
  return !blank(input.detail?.[key]);
};

const notElectric = (input) => input.detail?.fuelType !== "electric";

/** The details a buyer needs before anything else, per category, and the ones that round it out. */
function detailFields(input) {
  const d = input.detail || {};
  switch (input.category) {
    case "real-estate": {
      const land = input.isLand;
      const home = input.segment !== "commercial" && !land;
      const rent = input.purpose === "rent";
      const required = ["price", land ? "plotArea" : "builtArea", "completionStatus"];
      if (home) required.push("bedrooms");
      if (!land) required.push("bathrooms", "furnishing");
      if (rent) required.push("rentPeriod");
      if (d.completionStatus && d.completionStatus !== "ready") required.push("handoverDate");
      const extra = ["viewType", "ownershipType"];
      if (!land) extra.push("yearBuilt", "parkingSpaces", "halfBathrooms");
      if (home) extra.push("receptionRooms", "maidRooms");
      if (rent) extra.push("availableFrom", "chequesAccepted");
      return { required, extra };
    }
    case "cars": {
      const extra = ["drivetrain", "horsepower", "torqueNm", "topSpeedKmh", "interiorColor", "doors", "seats", "steeringSide", "ownersCount"];
      if (notElectric(input)) extra.push("engineSizeCc", "cylinders");
      return {
        required: ["price", "brand", "model", "modelYear", "mileageKm", "bodyType", "transmission", "fuelType", "exteriorColor", "conditionType", "regionalSpec"],
        extra,
      };
    }
    case "yachts":
      return {
        required: ["price", "brand", "buildYear", "lengthOverall", "vesselType", "cabins", "guestsSleeping"],
        extra: ["model", "beamM", "draftM", "grossTonnage", "hullMaterial", "berths", "heads", "guestsCruising", "crewCapacity", "engineMake", "engineModel", "engineHours", "cruisingSpeedKnots", "maxSpeedKnots", "rangeNm", "homePort"],
      };
    case "jets":
    case "helicopters":
      return {
        required: ["price", "brand", "model", "yearBuilt", "totalTimeHours", "passengerCapacity", "rangeNm"],
        extra: ["aircraftType", "totalLandings", "crewCapacity", "maxCruiseSpeedKts", "maxAltitudeFt", "engineCount", "engineMake", "engineModel", "avionicsSuite", "interiorConfiguration", "baseAirportCode"],
      };
    case "watches":
      return {
        required: ["price", "brand", "model", "referenceNumber", "yearOfProduction", "caseMaterial", "caseDiameterMm", "movementType", "conditionGrade"],
        extra: ["caseThicknessMm", "bezelMaterial", "crystal", "dialColor", "dialType", "braceletMaterial", "caliber", "powerReserveHours", "jewels", "waterResistanceM", "gender"],
      };
    default:
      return { required: ["price"], extra: [] };
  }
}

const listOf = (keys) => {
  const names = keys.map((key) => LABELS[key] || key);
  if (names.length <= 3) return names.join(", ");
  return `${names.slice(0, 3).join(", ")} and ${names.length - 3} more`;
};

function photosPart(input) {
  const n = Number(input.imageCount) || 0;
  const max = PARTS.photos.max;
  const earned = n >= FULL_PHOTOS ? max : n >= 5 ? 15 + (n - 5) * 2 : n * 3;
  const issues = [];
  if (n < FULL_PHOTOS) {
    issues.push({
      id: "photos.count",
      message: n === 0 ? "This listing has no photos." : `This listing has ${n} photo${n === 1 ? "" : "s"}.`,
      suggestion: `Add ${FULL_PHOTOS - n} more to reach ${FULL_PHOTOS}. Bright, landscape photos of every room or angle get the most enquiries; put the best one first as the cover.`,
      step: STEP.media,
      points: max - earned,
    });
  }
  return { earned, issues };
}

function descriptionPart(input) {
  const length = (input.descriptionText || "").trim().length;
  const max = PARTS.description.max;
  const earned =
    length >= FULL_DESCRIPTION
      ? max
      : length >= FAIR_DESCRIPTION
        ? Math.round(8 + ((length - FAIR_DESCRIPTION) / (FULL_DESCRIPTION - FAIR_DESCRIPTION)) * 7)
        : Math.round((length / FAIR_DESCRIPTION) * 8);
  const issues = [];
  if (length < FULL_DESCRIPTION) {
    issues.push({
      id: "description.length",
      message: length === 0 ? "There is no description." : `The description is ${length} characters long.`,
      suggestion: `Write at least ${FULL_DESCRIPTION} characters: what makes it special, the condition, what is included, and what is nearby. Short paragraphs read best.`,
      step: STEP.description,
      points: max - earned,
    });
  }
  return { earned, issues };
}

function titlePart(input) {
  const title = String(input.title || "").trim();
  const max = PARTS.title.max;
  const letters = title.replace(/[^A-Za-z]/g, "");
  const shouting = letters.length >= 10 && letters.replace(/[^A-Z]/g, "").length / letters.length > 0.6;
  let earned = title.length >= 30 && title.length <= 70 ? max : title.length >= 15 && title.length <= 90 ? 3 : title ? 1 : 0;
  const issues = [];
  if (title.length < 30) {
    issues.push({ id: "title.short", message: `The title is ${title.length} characters long.`, suggestion: "Use 30 to 70 characters, for example the type, size and the best feature or location.", step: STEP.basic, points: 0 });
  } else if (title.length > 70) {
    issues.push({ id: "title.long", message: `The title is ${title.length} characters long.`, suggestion: "Keep it to 70 characters so it shows in full on search results; move the rest into the description.", step: STEP.basic, points: 0 });
  }
  if (shouting) {
    earned = Math.max(0, earned - 2);
    issues.push({ id: "title.caps", message: "The title is mostly in capital letters.", suggestion: "Write it in normal sentence case; all capitals reads as shouting and looks like spam.", step: STEP.basic, points: 0 });
  }
  // The points a fix wins are shared out over the title's issues.
  if (issues.length) issues[0].points = max - earned;
  return { earned, issues };
}

function detailsPart(input, keys, part, { full = 1 } = {}) {
  if (!keys.length) return null;
  const missing = keys.filter((key) => !filled(input, key));
  const ratio = (keys.length - missing.length) / keys.length;
  const max = PARTS[part].max;
  const earned = Math.round(max * Math.min(1, ratio / full));
  const issues = [];
  if (earned < max) {
    issues.push({
      id: `${part}.missing`,
      message: `Missing: ${listOf(missing)}.`,
      suggestion:
        part === "required"
          ? "Buyers filter on these first; a listing without them drops out of their searches."
          : `Fill in ${full < 1 ? "most" : "all"} of these; extra detail answers questions before a buyer has to ask.`,
      step: missing.includes("price") && missing.length === 1 ? STEP.pricing : STEP.specs,
      fields: missing,
      points: max - earned,
    });
  }
  return { earned, issues };
}

function amenitiesPart(input) {
  const n = Number(input.featureCount) || 0;
  const max = PARTS.amenities.max;
  const earned = Math.min(max, n * (max / FULL_AMENITIES));
  const issues = [];
  if (n < FULL_AMENITIES) {
    issues.push({
      id: "amenities.count",
      message: n === 0 ? "No amenities or features are selected." : `${n} amenit${n === 1 ? "y is" : "ies are"} selected.`,
      suggestion: `Select at least ${FULL_AMENITIES} that this listing really has; buyers filter on them.`,
      step: STEP.features,
      points: max - earned,
    });
  }
  return { earned, issues };
}

function locationPart(input) {
  const loc = input.location || {};
  const max = PARTS.location.max;
  let earned = 0;
  const issues = [];
  if (loc.cityId || !loc.countryHasCities) earned += 4;
  else issues.push({ id: "location.city", message: "No city is set.", suggestion: "Choose the city.", step: STEP.location, points: 4 });
  if (loc.communityId || !loc.cityHasCommunities) earned += 3;
  else issues.push({ id: "location.community", message: "No community or area is set.", suggestion: "Choose the community so the listing shows in area searches.", step: STEP.location, points: 3 });
  if (loc.hasPin) earned += 3;
  else issues.push({ id: "location.pin", message: "There is no map pin.", suggestion: "Place the pin on the map; listings with a pin show on the map view.", step: STEP.location, points: 3 });
  return { earned, issues };
}

function mediaPart(input) {
  const max = PARTS.media.max;
  const realEstate = input.category === "real-estate";
  const has = input.videoCount > 0 || (realEstate && (input.hasFloorPlan || input.hasVirtualTour));
  if (has) return { earned: max, issues: [] };
  return {
    earned: 0,
    issues: [
      {
        id: "media.extra",
        message: realEstate ? "There is no floor plan, video or virtual tour." : "There is no video.",
        suggestion: realEstate ? "Add a floor plan, a video or a virtual tour link; any one of them earns these points." : "Add a short walk-around video or a video link.",
        step: STEP.media,
        points: max,
      },
    ],
  };
}

function permitPart(input) {
  if (!input.permit?.required) return null;
  const max = PARTS.permit.max;
  if (input.permit.has) return { earned: max, issues: [] };
  return {
    earned: 0,
    issues: [
      {
        id: "permit.missing",
        message: `No ${input.permit.label || "advertising permit"} number is given.`,
        suggestion: "This country requires a permit to advertise. Add the permit number from the authority.",
        step: STEP.specs,
        points: max,
      },
    ],
  };
}

function photoQualityPart(input) {
  const review = input.photoReview;
  if (!review || review.score === null || review.score === undefined) return null;
  const max = PARTS.photoQuality.max;
  const earned = Math.round((Math.max(0, Math.min(100, Number(review.score))) / 100) * max);
  return {
    earned,
    issues: (review.notes || []).map((note, index) => ({
      id: `photoQuality.${index}`,
      message: note.message,
      suggestion: note.suggestion,
      step: STEP.media,
      points: index === 0 ? max - earned : 0,
    })),
  };
}

/**
 * The score and its breakdown for one listing, from plain data (no database) — see
 * `loadQualityInput` for the shape. Every part says what it earned, its maximum, and the fixes
 * that would win the missing points, biggest first.
 */
export function scoreListing(input) {
  const { required, extra } = detailFields(input);
  const computed = {
    photos: photosPart(input),
    description: descriptionPart(input),
    title: titlePart(input),
    required: detailsPart(input, required, "required"),
    extra: detailsPart(input, extra, "extra", { full: 0.8 }),
    amenities: amenitiesPart(input),
    location: locationPart(input),
    media: mediaPart(input),
    permit: permitPart(input),
    photoQuality: photoQualityPart(input),
  };
  const parts = Object.entries(computed)
    .filter(([, result]) => result)
    .map(([key, result]) => ({
      key,
      label: PARTS[key].label,
      max: PARTS[key].max,
      earned: Math.round(result.earned * 10) / 10,
      issues: result.issues,
    }));
  const max = parts.reduce((sum, part) => sum + part.max, 0);
  const earned = parts.reduce((sum, part) => sum + part.earned, 0);
  const score = max ? Math.round((earned / max) * 100) : 0;
  // Points on the 0–100 scale each fix would add, so the list reads in the score's own units.
  const scale = max ? 100 / max : 0;
  const suggestions = parts
    .flatMap((part) => part.issues.map((issue) => ({ ...issue, part: part.key, gain: Math.round(issue.points * scale) })))
    .sort((a, b) => b.gain - a.gain);
  return {
    score,
    band: qualityBand(score),
    parts: parts.map((part) => ({ ...part, percent: part.max ? Math.round((part.earned / part.max) * 100) : 0 })),
    suggestions,
    photoCheck: input.photoReview ? "reviewed" : "not_available",
  };
}

/* -------------------------------------------------------------------------- */
/* Reading a listing                                                           */
/* -------------------------------------------------------------------------- */

const DETAIL_SOURCES = {
  "real-estate": {
    table: "listing_real_estate",
    columns: {
      bedrooms: "bedrooms", bathrooms: "bathrooms", halfBathrooms: "half_bathrooms", receptionRooms: "reception_rooms",
      maidRooms: "maid_rooms", parkingSpaces: "parking_spaces", builtAreaSqft: "built_area_sqft", builtAreaSqm: "built_area_sqm",
      plotAreaSqft: "plot_area_sqft", plotAreaSqm: "plot_area_sqm", yearBuilt: "year_built", completionStatus: "completion_status",
      handoverDate: "handover_date", furnishing: "furnishing", ownershipType: "ownership_type", viewType: "view_type",
      rentPeriod: "rent_period", chequesAccepted: "cheques_accepted", availableFrom: "available_from", permitNumber: "permit_number",
    },
  },
  cars: {
    table: "listing_vehicle",
    columns: {
      modelYear: "model_year", mileageKm: "mileage_km", bodyType: "body_type", transmission: "transmission", fuelType: "fuel_type",
      drivetrain: "drivetrain", engineSizeCc: "engine_size_cc", cylinders: "cylinders", horsepower: "horsepower", torqueNm: "torque_nm",
      topSpeedKmh: "top_speed_kmh", exteriorColor: "exterior_color", interiorColor: "interior_color", doors: "doors", seats: "seats",
      conditionType: "condition_type", steeringSide: "steering_side", regionalSpec: "regional_spec", ownersCount: "owners_count",
    },
  },
  yachts: {
    table: "listing_marine",
    columns: {
      buildYear: "build_year", lengthOverallM: "length_overall_m", lengthOverallFt: "length_overall_ft", beamM: "beam_m", draftM: "draft_m",
      grossTonnage: "gross_tonnage", vesselType: "vessel_type", hullMaterial: "hull_material", cabins: "cabins", berths: "berths",
      heads: "heads", guestsSleeping: "guests_sleeping", guestsCruising: "guests_cruising", crewCapacity: "crew_capacity",
      engineMake: "engine_make", engineModel: "engine_model", engineHours: "engine_hours", cruisingSpeedKnots: "cruising_speed_knots",
      maxSpeedKnots: "max_speed_knots", rangeNm: "range_nm", homePort: "home_port",
    },
  },
  jets: {
    table: "listing_aviation",
    columns: {
      aircraftType: "aircraft_type", yearBuilt: "year_built", totalTimeHours: "total_time_hours", totalLandings: "total_landings",
      passengerCapacity: "passenger_capacity", crewCapacity: "crew_capacity", rangeNm: "range_nm", maxCruiseSpeedKts: "max_cruise_speed_kts",
      maxAltitudeFt: "max_altitude_ft", engineCount: "engine_count", engineMake: "engine_make", engineModel: "engine_model",
      avionicsSuite: "avionics_suite", interiorConfiguration: "interior_configuration", baseAirportCode: "base_airport_code",
    },
  },
  watches: {
    table: "listing_timepiece",
    columns: {
      referenceNumber: "reference_number", yearOfProduction: "year_of_production", caseMaterial: "case_material",
      caseDiameterMm: "case_diameter_mm", caseThicknessMm: "case_thickness_mm", bezelMaterial: "bezel_material", crystal: "crystal",
      dialColor: "dial_color", dialType: "dial_type", braceletMaterial: "bracelet_material", movementType: "movement_type",
      caliber: "caliber", powerReserveHours: "power_reserve_hours", jewels: "jewels", waterResistanceM: "water_resistance_m",
      conditionGrade: "condition_grade", gender: "gender",
    },
  },
};
DETAIL_SOURCES.helicopters = DETAIL_SOURCES.jets;

const LAND_TYPES = new Set(["plot", "plots", "industrial-land", "land"]);

/** Everything `scoreListing` reads, for one listing id. `null` when there is no such listing. */
export async function loadQualityInput(listingId) {
  const row = await queryOne(
    `SELECT l.id, l.root_category_id, l.title, l.description, l.price, l.price_type, l.is_price_hidden,
            l.country_id, l.city_id, l.community_id, l.latitude, l.longitude, l.brand_id, l.brand_model_id,
            l.property_segment, l.image_count, l.video_count, l.has_floor_plan, l.has_virtual_tour,
            c.code AS type_code, c.slug AS type_slug, p.code AS purpose_code
       FROM listings l
       JOIN categories c ON c.id = l.category_id
       JOIN purposes p ON p.id = l.purpose_id
      WHERE l.id = ?`,
    [Number(listingId)]
  );
  if (!row) return null;
  const definition = categoryByRootId(row.root_category_id);
  const category = definition?.listingType ?? null;
  const source = DETAIL_SOURCES[category];

  const [detailRow, features, cityChildren, countryCities, permitRule, permitRow] = await Promise.all([
    source ? queryOne(`SELECT * FROM ${source.table} WHERE listing_id = ?`, [row.id]) : null,
    queryOne("SELECT COUNT(*) AS n FROM listing_features WHERE listing_id = ?", [row.id]),
    row.city_id ? queryOne("SELECT COUNT(*) AS n FROM locations WHERE parent_id = ? AND status = 'active'", [row.city_id]) : null,
    row.country_id
      ? // Every city carries its country_id, under a state or not: one indexed count (0.2 ms) instead
        // of a scan of all 150,000 cities by parent (170 ms), which slowed every listing save.
        queryOne("SELECT COUNT(*) AS n FROM locations WHERE country_id = ? AND level = 'city' AND status = 'active'", [row.country_id])
      : null,
    row.country_id
      ? queryOne(
          `SELECT pt.display_label, pt.name FROM permit_types pt
            WHERE pt.applies_to = 'listing' AND pt.is_active = 1 AND pt.is_mandatory = 1
              AND pt.country_id = ? AND (pt.root_category_id IS NULL OR pt.root_category_id = ?)
            LIMIT 1`,
          [row.country_id, row.root_category_id]
        )
      : null,
    queryOne(
      "SELECT 1 AS ok FROM listing_permits WHERE listing_id = ? AND status IN ('submitted','active','expiring') LIMIT 1",
      [row.id]
    ),
  ]);

  const detail = {};
  for (const [key, column] of Object.entries(source?.columns ?? {})) {
    const value = detailRow?.[column];
    if (value !== null && value !== undefined) detail[key] = value;
  }

  return {
    category,
    purpose: row.purpose_code,
    title: row.title,
    descriptionText: descriptionToText(row.description || ""),
    price: row.price,
    priceOnRequest: row.price_type === "on_request" || Boolean(row.is_price_hidden),
    brandId: row.brand_id,
    modelId: row.brand_model_id,
    segment: row.property_segment,
    isLand: LAND_TYPES.has(row.type_code) || LAND_TYPES.has(row.type_slug),
    detail,
    imageCount: Number(row.image_count) || 0,
    videoCount: Number(row.video_count) || 0,
    hasFloorPlan: Boolean(row.has_floor_plan),
    hasVirtualTour: Boolean(row.has_virtual_tour),
    featureCount: Number(features?.n) || 0,
    location: {
      cityId: row.city_id,
      communityId: row.community_id,
      countryHasCities: Number(countryCities?.n) > 0,
      cityHasCommunities: Number(cityChildren?.n) > 0,
      hasPin: row.latitude !== null && row.longitude !== null,
    },
    permit: {
      required: Boolean(permitRule),
      label: permitRule?.display_label || permitRule?.name || null,
      has: Boolean(permitRow) || !blank(detail.permitNumber),
    },
    // The AI photo check's result, once there is one (not built yet).
    photoReview: null,
  };
}

export async function computeListingQuality(listingId) {
  const input = await loadQualityInput(listingId);
  return input ? scoreListing(input) : null;
}

/**
 * Recomputes and stores one listing's score. `updated_at` is kept as it was: a score is not an
 * edit, and the projection and revision checks compare against that column.
 */
export async function saveListingQuality(listingId) {
  const quality = await computeListingQuality(listingId);
  if (!quality) return null;
  await execute(
    "UPDATE listings SET quality_score = ?, quality_scored_at = NOW(3), updated_at = updated_at WHERE id = ?",
    [quality.score, Number(listingId)]
  );
  // A live listing with changes waiting for approval keeps ranking on its approved version (0060);
  // the projection takes the new score when the change is approved and the row is refreshed.
  await execute(
    `UPDATE listing_search ls JOIN listings l ON l.id = ls.listing_id
        SET ls.quality_score = ?
      WHERE ls.listing_id = ? AND l.pending_revision_id IS NULL AND ls.quality_score <> ?`,
    [quality.score, Number(listingId), quality.score]
  );
  return quality;
}

/** The sweep: listings never scored, or changed since they were. */
export async function refreshDueQualityScores({ limit = 2000 } = {}) {
  const due = await query(
    `SELECT id FROM listings
      WHERE deleted_at IS NULL AND (quality_scored_at IS NULL OR quality_scored_at < updated_at)
      ORDER BY id
      LIMIT ${Number(limit)}`
  );
  for (const row of due) {
    try {
      await saveListingQuality(row.id);
    } catch (error) {
      logger.warn({ err: error, listingId: row.id }, "listing quality score failed");
    }
  }
  return due.length;
}
