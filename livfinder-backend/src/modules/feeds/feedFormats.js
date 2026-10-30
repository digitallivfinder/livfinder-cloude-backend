import { DETAIL_SCHEMAS } from "../listings/listings.schemas.js";
import { isAlwaysRequired, requirementNote, requirementOf } from "./listingRequirements.js";
import { IMPORT_CATEGORIES, listingRecordSchema } from "../imports/listingImport.service.js";
import {
  DEVELOPMENT_AVAILABILITY,
  DEVELOPMENT_LAUNCH,
  DEVELOPMENT_LIFECYCLE,
  DEVELOPMENT_OWNERSHIP,
  DEVELOPMENT_PROJECT_TYPES,
  DEVELOPMENT_UNIT_TYPES,
  MILESTONE_TRIGGERS,
  PAYMENT_PLAN_TYPES,
} from "../admin/admin.mutations.js";

/**
 * The LivFinder feed formats: one per category, each versioned on its own (owner's rule,
 * 2026-10-29). A company sends one file per category; each file holds only that category's
 * structure.
 *
 * A listing format is a shared envelope (the fields every category has) plus the category's own
 * block. Both are read off the schemas the import already validates against
 * (`listingRecordSchema` and `DETAIL_SCHEMAS`), so a field added to a category's schema appears
 * in its CSV template, XSD, sample and docs without touching this file. A change that would
 * break files already being sent bumps that category's version in `FORMAT_VERSIONS`.
 *
 * A field is `{ key, path, type, required, values?, min?, max?, maxLength?, list?, group }`:
 * `path` is where it lands in the record the import takes ("location.city", "detail.bedrooms"),
 * `key` is its CSV column and XML element name.
 */

export const FORMAT_VERSIONS = Object.freeze({
  "real-estate": 1,
  cars: 1,
  yachts: 1,
  jets: 1,
  helicopters: 1,
  watches: 1,
  developments: 1,
});

export const FEED_CATEGORIES = Object.freeze([...IMPORT_CATEGORIES, "developments"]);

export const LIST_SEPARATOR = "|";

const LABELS = {
  "real-estate": "Real Estate",
  cars: "Cars",
  yachts: "Yachts",
  jets: "Jets",
  helicopters: "Helicopters",
  watches: "Watches",
  developments: "Real Estate Developments",
};

/* -------------------------------------------------------------------------- */
/* Reading a field's shape off a zod (v4) schema                               */
/* -------------------------------------------------------------------------- */

function describe(schema) {
  let node = schema;
  let optional = false;
  for (let guard = 0; node && guard < 12; guard += 1) {
    const type = node.def?.type;
    if (type === "optional" || type === "nullable" || type === "default") {
      optional = true;
      node = node.def.innerType;
    } else if (type === "union") {
      // `optionalText`: a string, or "" turned into undefined.
      node = node.def.options.find((option) => option.def?.type !== "literal" && option.def?.type !== "pipe") || node.def.options[0];
    } else if (type === "pipe") {
      node = node.def.in;
    } else {
      break;
    }
  }
  const type = node?.def?.type;
  const field = { required: !optional };
  if (type === "string") Object.assign(field, { type: "string", maxLength: node.maxLength ?? undefined });
  else if (type === "number") {
    Object.assign(field, {
      type: node.isInt ? "integer" : "number",
      min: Number.isFinite(node.minValue) ? node.minValue : undefined,
      max: Number.isFinite(node.maxValue) ? node.maxValue : undefined,
    });
  } else if (type === "boolean") field.type = "boolean";
  else if (type === "enum") Object.assign(field, { type: "enum", values: [...node.options] });
  else if (type === "array") Object.assign(field, { ...describe(node.def.element), list: true, required: !optional });
  else field.type = "string";
  return field;
}

/* -------------------------------------------------------------------------- */
/* Listing formats                                                             */
/* -------------------------------------------------------------------------- */

// The envelope fields a feed file does not carry: the category is the file's own, and the
// listing's status is chosen in the portal (a feed only syncs).
const ENVELOPE_SKIP = new Set(["category", "detail", "status", "location"]);
// Real estate has no make and model.
const ENVELOPE_SKIP_BY_CATEGORY = { "real-estate": new Set(["brand", "model"]) };

const LOCATION_KEYS = { id: "locationId", country: "country", state: "state", city: "city", community: "community", subCommunity: "subCommunity" };

const DESCRIPTIONS = {
  externalId: "Your own id for the listing. It names the same listing on every run, so keep it stable.",
  title: "At least 4 characters.",
  description: "Plain text or simple HTML.",
  purpose: "sale, rent or charter, as the category allows.",
  propertyType: "The listing's type within the category, by its LivFinder code or name.",
  price: "A number without separators.",
  currency: "3-letter code, such as AED.",
  country: "2-letter code or the country's name.",
  locationId: "A LivFinder location id; use instead of the names when you have it.",
  images: `Full image URLs, separated by ${LIST_SEPARATOR}. LivFinder downloads and stores them.`,
  features: `Feature names, separated by ${LIST_SEPARATOR}.`,
  agentEmail: "The email of the agent on your LivFinder account who handles this listing.",
};

function envelopeFields(category) {
  const skip = ENVELOPE_SKIP_BY_CATEGORY[category] || new Set();
  const fields = [];
  for (const [key, schema] of Object.entries(listingRecordSchema.shape)) {
    if (key === "location") {
      for (const [sub, subSchema] of Object.entries(schema.unwrap().shape)) {
        fields.push({ ...describe(subSchema), required: false, key: LOCATION_KEYS[sub], path: `location.${sub}`, group: "location" });
      }
      continue;
    }
    if (ENVELOPE_SKIP.has(key) || skip.has(key)) continue;
    fields.push({ ...describe(schema), key, path: key, group: "listing" });
  }
  // The import asks for a country and a city when no location id is given.
  for (const field of fields) {
    if (field.key === "country" || field.key === "city") field.description = "Required unless locationId is given.";
  }
  return fields;
}

function detailFields(category) {
  return Object.entries(DETAIL_SCHEMAS[category].shape).map(([key, schema]) => ({
    ...describe(schema),
    required: false,
    key,
    path: `detail.${key}`,
    group: "details",
  }));
}

/* -------------------------------------------------------------------------- */
/* The development format                                                      */
/* -------------------------------------------------------------------------- */

const s = (key, extra = {}) => ({ key, path: key, type: "string", required: false, ...extra });
const i = (key, min, max, extra = {}) => ({ key, path: key, type: "integer", required: false, min, max, ...extra });
const n = (key, min, max, extra = {}) => ({ key, path: key, type: "number", required: false, min, max, ...extra });
const e = (key, values, extra = {}) => ({ key, path: key, type: "enum", values: [...values], required: false, ...extra });
const d = (key, extra = {}) => ({ key, path: key, type: "date", required: false, ...extra });
const b = (key, extra = {}) => ({ key, path: key, type: "boolean", required: false, ...extra });

const DEVELOPMENT_FIELDS = [
  s("externalId", { required: true, maxLength: 191, description: DESCRIPTIONS.externalId }),
  s("name", { required: true, maxLength: 200 }),
  s("tagline", { maxLength: 255 }),
  s("description", { maxLength: 8000 }),
  s("marketingHeading", { maxLength: 255 }),
  s("highlights", { list: true, maxLength: 300 }),
  e("projectType", DEVELOPMENT_PROJECT_TYPES),
  e("ownershipType", DEVELOPMENT_OWNERSHIP),
  e("status", DEVELOPMENT_LIFECYCLE, { description: "Construction stage." }),
  e("launchStatus", DEVELOPMENT_LAUNCH),
  d("launchDate"),
  d("constructionStartDate"),
  d("handoverDate"),
  n("completionPercentage", 0, 100),
  i("totalUnits", 0, 100000),
  i("availableUnits", 0, 100000),
  i("buildingCount", 0, 1000),
  n("minPrice", 0, 1e15),
  n("maxPrice", 0, 1e15),
  s("currency", { maxLength: 3, description: DESCRIPTIONS.currency }),
  ...["country", "state", "city", "community", "subCommunity"].map((key) =>
    s(key, { path: `location.${key}`, maxLength: 180, group: "location", ...(key === "country" || key === "city" ? { description: "Required." } : {}) })
  ),
  s("address", { maxLength: 255, group: "location" }),
  n("latitude", -90, 90, { group: "location" }),
  n("longitude", -180, 180, { group: "location" }),
  s("amenities", { list: true, maxLength: 160 }),
  s("images", { list: true, maxLength: 2000, description: DESCRIPTIONS.images }),
  s("brochureUrl", { maxLength: 500 }),
  s("videoUrl", { maxLength: 500 }),
  s("seoTitle", { maxLength: 255 }),
  s("seoDescription", { maxLength: 500 }),
].map((field) => ({ group: "development", ...field }));

const UNIT_FIELDS = [
  e("unitType", DEVELOPMENT_UNIT_TYPES, { required: true }),
  s("name", { maxLength: 160 }),
  i("bedrooms", 0, 60),
  n("bathrooms", 0, 60),
  n("minSize", 0, 1e9),
  n("maxSize", 0, 1e9),
  s("areaUnit", { maxLength: 20, description: "sqft or sqm." }),
  n("startingPrice", 0, 1e15),
  n("maxPrice", 0, 1e15),
  s("currency", { maxLength: 3 }),
  e("availability", DEVELOPMENT_AVAILABILITY),
  i("availableUnits", 0, 100000),
  i("totalUnits", 0, 100000),
].map((field) => ({ group: "unitType", ...field }));

const MILESTONE_FIELDS = [
  s("name", { required: true, maxLength: 200 }),
  e("triggerType", MILESTONE_TRIGGERS),
  n("constructionPercent", 0, 100),
  i("monthsOffset", 0, 600),
  d("date"),
  n("percentage", 0, 100),
  n("amount", 0, 1e15),
  s("notes", { maxLength: 300 }),
].map((field) => ({ group: "milestone", ...field }));

const PLAN_FIELDS = [
  s("name", { required: true, maxLength: 200 }),
  s("description", { maxLength: 1000 }),
  e("planType", PAYMENT_PLAN_TYPES),
  n("downPaymentPercent", 0, 100),
  n("duringConstructionPercent", 0, 100),
  n("onHandoverPercent", 0, 100),
  n("postHandoverPercent", 0, 100),
  i("postHandoverMonths", 0, 600),
  b("waivesRegistrationFee"),
  i("serviceChargeWaiverYears", 0, 30),
  n("guaranteedReturnPercent", 0, 100),
  i("guaranteedReturnYears", 0, 30),
].map((field) => ({ group: "paymentPlan", ...field }));

/* -------------------------------------------------------------------------- */
/* The registry                                                                */
/* -------------------------------------------------------------------------- */

/** Every field of one category's format, or null for a category without a feed. */
export function feedFormat(category) {
  if (!FEED_CATEGORIES.includes(category)) return null;
  const base = { category, label: LABELS[category], version: FORMAT_VERSIONS[category], listSeparator: LIST_SEPARATOR };
  const withRules = (field) => ({
    ...field,
    required: isAlwaysRequired(category, field),
    requirement: requirementOf(category, field),
    description: requirementNote(category, field) ?? field.description,
  });
  if (category === "developments") {
    return {
      ...base,
      entity: "development",
      fields: DEVELOPMENT_FIELDS.map(withRules),
      unitTypeFields: UNIT_FIELDS,
      paymentPlanFields: PLAN_FIELDS,
      milestoneFields: MILESTONE_FIELDS,
    };
  }
  const fields = [...envelopeFields(category), ...detailFields(category)]
    .map((field) => ({ ...field, description: field.description ?? DESCRIPTIONS[field.key] }))
    .map(withRules);
  return { ...base, entity: "listing", fields };
}

/** The list a client sees: every category, its version and where to download its files. */
export function feedFormatIndex(baseUrl = "") {
  return FEED_CATEGORIES.map((category) => ({
    category,
    label: LABELS[category],
    version: FORMAT_VERSIONS[category],
    downloads: {
      spec: `${baseUrl}/v1/public/feed-formats/${category}`,
      csvTemplate: `${baseUrl}/v1/public/feed-formats/${category}/template.csv`,
      xmlSchema: `${baseUrl}/v1/public/feed-formats/${category}/schema.xsd`,
      xmlSample: `${baseUrl}/v1/public/feed-formats/${category}/sample.xml`,
    },
  }));
}
