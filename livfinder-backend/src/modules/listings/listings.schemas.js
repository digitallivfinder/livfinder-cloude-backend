import { z } from "zod";
import { CATEGORY_PURPOSES } from "../../utils/categories.js";

const optionalText = (max) => z.string().trim().max(max).optional().or(z.literal("").transform(() => undefined));
const optionalNumber = (min = 0, max = 1e12) => z.coerce.number().min(min).max(max).optional().nullable();
const optionalInt = (min = 0, max = 1e9) => z.coerce.number().int().min(min).max(max).optional().nullable();

/** Fields any listing carries, whatever its category. */
const commonListing = {
  category: z.string().trim().min(1, "Choose a category.").max(40),
  categorySlug: optionalText(80),
  purpose: z.string().trim().max(20).optional(),
  title: z.string().trim().min(4, "Enter a title.").max(255),
  subtitle: optionalText(255),
  description: z.string().trim().max(50_000).optional().or(z.literal("")),
  price: optionalNumber(0, 1e15),
  currency: z.string().trim().length(3).toUpperCase().optional(),
  priceType: z.enum(["fixed", "from", "on_request", "auction", "negotiable"]).optional(),
  pricePeriod: z.enum(["total", "year", "month", "week", "day", "hour", "nautical_day", "flight_hour"]).optional().nullable(),
  isPriceHidden: z.boolean().optional(),
  locationId: z.union([z.string(), z.number()]).optional().nullable(),
  address: optionalText(500),
  postalCode: optionalText(30),
  latitude: z.coerce.number().min(-90).max(90).optional().nullable(),
  longitude: z.coerce.number().min(-180).max(180).optional().nullable(),
  hideExactLocation: z.boolean().optional(),
  contactName: optionalText(200),
  contactPhone: optionalText(40),
  contactWhatsapp: optionalText(40),
  contactEmail: optionalText(255),
  allowCall: z.boolean().optional(),
  allowWhatsapp: z.boolean().optional(),
  allowEmail: z.boolean().optional(),
  agentId: z.union([z.string(), z.number()]).optional().nullable(),
  projectId: z.union([z.string(), z.number()]).optional().nullable(),
  brand: optionalText(160),
  model: optionalText(180),
  featureIds: z.array(z.union([z.string(), z.number()])).max(200).optional(),
  features: z.array(z.string().max(120)).max(200).optional(),
  attributes: z.record(z.string().max(60), z.union([z.string().max(500), z.number(), z.boolean(), z.null()])).optional(),
  mediaAssetIds: z.array(z.string().max(40)).max(60).optional(),
  seoTitle: optionalText(255),
  seoDescription: optionalText(500),
};

/**
 * Per-category detail payloads. Each maps to exactly one detail table; nothing
 * here is shared between categories, which is what stops a car's mileage from
 * being written to a yacht.
 */
export const realEstateDetail = z.object({
  bedrooms: optionalInt(0, 200),
  bathrooms: optionalInt(0, 200),
  halfBathrooms: optionalInt(0, 100),
  receptionRooms: optionalInt(0, 100),
  maidRooms: optionalInt(0, 50),
  parkingSpaces: optionalInt(0, 500),
  builtAreaSqft: optionalNumber(0, 10_000_000),
  builtAreaSqm: optionalNumber(0, 1_000_000),
  plotAreaSqft: optionalNumber(0, 100_000_000),
  plotAreaSqm: optionalNumber(0, 10_000_000),
  floorNumber: optionalInt(-20, 250),
  totalFloors: optionalInt(0, 250),
  unitNumber: optionalText(40),
  buildingName: optionalText(180),
  yearBuilt: optionalInt(1500, 2200),
  completionStatus: z.enum(["ready", "off_plan", "under_construction", "shell_and_core"]).optional().nullable(),
  handoverDate: z.string().max(20).optional().nullable(),
  furnishing: z.enum(["unfurnished", "semi_furnished", "furnished", "fully_fitted"]).optional().nullable(),
  ownershipType: z.enum(["freehold", "leasehold", "usufruct", "musataha", "commonhold", "share_of_freehold"]).optional().nullable(),
  viewType: optionalText(120),
  rentPeriod: z.enum(["yearly", "monthly", "weekly", "daily"]).optional().nullable(),
  chequesAccepted: optionalInt(0, 12),
  availableFrom: z.string().max(20).optional().nullable(),
  permitNumber: optionalText(80),
  isNewBuild: z.boolean().optional(),
  isTenanted: z.boolean().optional(),
});

export const vehicleDetail = z.object({
  modelYear: optionalInt(1900, 2200),
  mileageKm: optionalInt(0, 5_000_000),
  bodyType: optionalText(60),
  transmission: z.enum(["manual", "automatic", "semi_automatic", "cvt", "dual_clutch", "single_speed"]).optional().nullable(),
  fuelType: z.enum(["petrol", "diesel", "hybrid", "plug_in_hybrid", "electric", "hydrogen", "other"]).optional().nullable(),
  drivetrain: z.enum(["fwd", "rwd", "awd", "4wd"]).optional().nullable(),
  serviceHistory: z.enum(["none", "partial", "full", "full_dealer"]).optional().nullable(),
  engineSizeCc: optionalInt(0, 100_000),
  cylinders: optionalInt(0, 24),
  horsepower: optionalInt(0, 5000),
  torqueNm: optionalInt(0, 10_000),
  topSpeedKmh: optionalInt(0, 1000),
  exteriorColor: optionalText(60),
  interiorColor: optionalText(60),
  doors: optionalInt(0, 10),
  seats: optionalInt(0, 30),
  conditionType: z.enum(["new", "used", "certified_pre_owned", "classic", "salvage", "restored", "project"]).optional().nullable(),
  steeringSide: z.enum(["left", "right"]).optional().nullable(),
  vin: optionalText(40),
  regionalSpec: optionalText(60),
  ownersCount: optionalInt(0, 100),
  isAccidentFree: z.boolean().optional(),
  isLimitedEdition: z.boolean().optional(),
});

export const marineDetail = z.object({
  buildYear: optionalInt(1800, 2200),
  refitYear: optionalInt(1800, 2200),
  lengthOverallM: optionalNumber(0, 1000),
  lengthOverallFt: optionalNumber(0, 3300),
  beamM: optionalNumber(0, 200),
  draftM: optionalNumber(0, 100),
  grossTonnage: optionalNumber(0, 1_000_000),
  vesselType: z
    .enum([
      "motor_yacht", "sailing_yacht", "superyacht", "mega_yacht", "catamaran", "trimaran",
      "explorer", "sport_fisher", "gulet", "classic", "tender", "houseboat",
    ])
    .optional()
    .nullable(),
  hullMaterial: z
    .enum(["grp", "steel", "aluminium", "wood", "composite", "ferrocement"])
    .optional()
    .nullable(),
  cabins: optionalInt(0, 100),
  berths: optionalInt(0, 200),
  heads: optionalInt(0, 100),
  guestsSleeping: optionalInt(0, 200),
  guestsCruising: optionalInt(0, 500),
  crewCapacity: optionalInt(0, 200),
  engineMake: optionalText(120),
  engineModel: optionalText(120),
  engineHours: optionalInt(0, 500_000),
  cruisingSpeedKnots: optionalNumber(0, 200),
  maxSpeedKnots: optionalNumber(0, 300),
  rangeNm: optionalInt(0, 100_000),
  homePort: optionalText(120),
  isCharterAvailable: z.boolean().optional(),
  isVatPaid: z.boolean().optional(),
});

export const aviationDetail = z.object({
  aircraftType: z
    .enum([
      "very_light_jet", "light_jet", "midsize_jet", "super_midsize_jet", "heavy_jet",
      "ultra_long_range", "vip_airliner", "turboprop",
      "light_helicopter", "medium_helicopter", "heavy_helicopter",
    ])
    .optional()
    .nullable(),
  yearBuilt: optionalInt(1900, 2200),
  yearRefurbished: optionalInt(1900, 2200),
  totalTimeHours: optionalInt(0, 500_000),
  totalLandings: optionalInt(0, 1_000_000),
  cycles: optionalInt(0, 1_000_000),
  passengerCapacity: optionalInt(0, 900),
  crewCapacity: optionalInt(0, 100),
  rangeNm: optionalInt(0, 100_000),
  maxCruiseSpeedKts: optionalInt(0, 2000),
  maxAltitudeFt: optionalInt(0, 100_000),
  engineCount: optionalInt(0, 12),
  engineMake: optionalText(120),
  engineModel: optionalText(120),
  engineProgram: optionalText(80),
  avionicsSuite: optionalText(160),
  interiorConfiguration: optionalText(200),
  baseAirportCode: optionalText(10),
  isCharterAvailable: z.boolean().optional(),
  charterHourlyRate: optionalNumber(0, 1e9),
});

export const timepieceDetail = z.object({
  referenceNumber: optionalText(80),
  yearOfProduction: optionalInt(1500, 2200),
  caseMaterial: optionalText(60),
  caseDiameterMm: optionalNumber(0, 200),
  caseThicknessMm: optionalNumber(0, 100),
  bezelMaterial: optionalText(60),
  crystal: optionalText(60),
  dialColor: optionalText(60),
  dialType: optionalText(60),
  braceletMaterial: optionalText(60),
  movementType: z.enum(["automatic", "manual", "quartz", "spring_drive", "solar", "mechanical_digital"]).optional().nullable(),
  caliber: optionalText(60),
  powerReserveHours: optionalInt(0, 10_000),
  jewels: optionalInt(0, 200),
  waterResistanceM: optionalInt(0, 20_000),
  conditionGrade: z.enum(["new", "unworn", "excellent", "very_good", "good", "fair", "restored"]).optional().nullable(),
  hasOriginalBox: z.boolean().optional(),
  hasOriginalPapers: z.boolean().optional(),
  isFullSet: z.boolean().optional(),
  isLimitedEdition: z.boolean().optional(),
  gender: z.enum(["mens", "ladies", "unisex"]).optional().nullable(),
});

export const DETAIL_SCHEMAS = {
  "real-estate": realEstateDetail,
  cars: vehicleDetail,
  yachts: marineDetail,
  jets: aviationDetail,
  helicopters: aviationDetail,
  watches: timepieceDetail,
};

export const createListingSchema = z
  .object({
    ...commonListing,
    detail: z.record(z.string(), z.unknown()).optional(),
    status: z.enum(["draft", "pending_review"]).optional(),
  })
  .superRefine((value, ctx) => {
    const allowed = CATEGORY_PURPOSES[value.category] || CATEGORY_PURPOSES[String(value.category).toLowerCase()];
    if (value.purpose && allowed && !allowed.includes(value.purpose)) {
      ctx.addIssue({ code: "custom", path: ["purpose"], message: `That purpose is not available for this category.` });
    }
  });

export const updateListingSchema = z.object({
  ...Object.fromEntries(Object.entries(commonListing).map(([key, schema]) => [key, schema.optional()])),
  detail: z.record(z.string(), z.unknown()).optional(),
  // The edit form's "Save draft" / "Submit for review". Without it here, zod stripped it and
  // "Submit for review" on an edited rejected listing never resubmitted it. Publishing stays a
  // moderator action; a live listing an owner edits goes back to review regardless.
  status: z.enum(["draft", "pending_review"]).optional(),
});

export const listingStatusSchema = z.object({
  status: z.enum(["draft", "pending_review", "active", "sold", "rented", "withdrawn", "archived", "expired"]),
  reason: z.string().trim().max(500).optional(),
});
