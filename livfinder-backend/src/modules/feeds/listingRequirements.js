import { feedFormat } from "./feedFormats.js";

/**
 * What a listing must carry to come in by XML, CSV or the API, so it is a proper listing from the
 * start (owner's rule, 2026-10-30). The portal form stays looser: a person can save a draft and
 * finish it later, a pushed file cannot be asked anything.
 *
 * Every detail field of a category is required, except the ones below, which a listing can
 * honestly not have. `OPTIONAL_DETAILS` never apply to some listings at all; `REQUIRED_WHEN` apply
 * only in a given case; `ONE_OF` are the same measurement in two units.
 */

export const MIN_IMAGES = 3;

const OPTIONAL_DETAILS = {
  // A villa has no floor or unit number; an apartment has no plot of its own.
  "real-estate": ["floorNumber", "totalFloors", "unitNumber", "buildingName", "plotAreaSqft", "plotAreaSqm"],
  // Not every yacht or aircraft has been refitted.
  yachts: ["refitYear"],
  jets: ["yearRefurbished"],
  helicopters: ["yearRefurbished"],
  // The portal works this one out from the box and the papers.
  watches: ["isFullSet"],
};

const notElectric = (record) => record.detail?.fuelType !== "electric";

const REQUIRED_WHEN = {
  "real-estate": {
    handoverDate: (record) => record.detail?.completionStatus && record.detail.completionStatus !== "ready",
    rentPeriod: (record) => record.purpose === "rent",
    chequesAccepted: (record) => record.purpose === "rent",
  },
  cars: { engineSizeCc: notElectric, cylinders: notElectric },
  yachts: {},
  jets: { charterHourlyRate: (record) => Boolean(record.detail?.isCharterAvailable) },
  helicopters: { charterHourlyRate: (record) => Boolean(record.detail?.isCharterAvailable) },
};

const ONE_OF = {
  "real-estate": [["builtAreaSqft", "builtAreaSqm"]],
  yachts: [["lengthOverallM", "lengthOverallFt"]],
};

const blank = (value) => value === undefined || value === null || value === "" || (Array.isArray(value) && !value.length);

/** Which of a category's fields must always be there, for the published format and its schema. */
export function isAlwaysRequired(category, field) {
  if (["externalId", "title", "name", "description", "features", "amenities", "images"].includes(field.key)) return true;
  if (field.key === "purpose") return true;
  if (field.key === "propertyType") return category === "real-estate";
  if (category === "developments") return ["projectType", "status", "currency"].includes(field.key);
  if (field.group === "details") {
    if ((OPTIONAL_DETAILS[category] || []).includes(field.key)) return false;
    if (field.key in (REQUIRED_WHEN[category] || {})) return false;
    if ((ONE_OF[category] || []).some((pair) => pair.includes(field.key))) return false;
    return true;
  }
  return field.key === "brand" || field.key === "model";
}

/** The rule in words, for the field reference: `null` for a field that is simply required or free. */
export function requirementNote(category, field) {
  if ((ONE_OF[category] || []).some((pair) => pair.includes(field.key))) return "Required in one of its two units.";
  if (field.key in (REQUIRED_WHEN[category] || {})) return "Required when it applies to this listing.";
  if (field.key === "images") return `At least ${MIN_IMAGES} images.`;
  if (field.key === "country") return "Required unless locationId is given.";
  if (field.key === "state") return "Required only if the country has states but no cities on LivFinder.";
  if (field.key === "city") return "Required where the country has cities on LivFinder.";
  if (field.key === "community") return "Required where the city has communities on LivFinder.";
  if (field.key === "subCommunity") return "Required where the community has sub-communities on LivFinder.";
  if (field.key === "price" || field.key === "currency") return "Required unless priceType is on_request.";
  if (field.key === "latitude" || field.key === "longitude") return "Optional, but give both or neither.";
  if (field.key === "agentEmail") return "Required for a company with agents.";
  return null;
}

/** `required`, `conditional` (required in some cases, the note says which) or `optional`. */
export function requirementOf(category, field) {
  if (isAlwaysRequired(category, field)) return "required";
  if (field.key === "latitude" || field.key === "longitude") return "optional";
  return requirementNote(category, field) ? "conditional" : "optional";
}

/**
 * What is missing from a record, as `{ field: message }`, in the file's field names so a client
 * can find them. Checks what the record alone can show; where a place sits in LivFinder's list,
 * and whether images really arrived, are checked when the listing is imported.
 */
export function missingRequired(category, record) {
  const format = feedFormat(category);
  const missing = {};
  const say = (key, message = "This is required.") => {
    missing[key] ??= message;
  };
  const value = (field) => String(field.path ?? field.key).split(".").reduce((node, key) => node?.[key], record);

  if (format.entity === "development") {
    if (blank(record.name)) say("name");
    for (const key of ["description", "projectType", "status", "currency"]) if (blank(record[key])) say(key);
    if (!record.unitTypes?.length) say("unitTypes", "Give at least one unit type.");
    if (!record.amenities?.length) say("amenities", "Give at least one amenity.");
  } else {
    for (const field of format.fields) {
      if (blank(value(field)) && isAlwaysRequired(category, field) && !["images", "features"].includes(field.key)) say(field.key);
    }
    for (const [key, applies] of Object.entries(REQUIRED_WHEN[category] || {})) {
      if (blank(record.detail?.[key]) && applies(record)) say(key);
    }
    for (const pair of ONE_OF[category] || []) {
      if (pair.every((key) => blank(record.detail?.[key]))) say(pair[0], `Give ${pair.join(" or ")}.`);
    }
    if (record.allowCall === false && record.allowWhatsapp === false && record.allowEmail === false) {
      say("allowCall", "Leave at least one way for buyers to make contact.");
    }
    if (record.priceType !== "on_request") {
      if (blank(record.price)) say("price", "Give a price, or set priceType to on_request.");
      if (blank(record.currency)) say("currency");
    }
    if (!record.features?.length) say("features", "Give at least one amenity or feature.");
  }

  // How deep the place must go depends on LivFinder's list, so it is checked when the place is
  // looked up (`assertLocationComplete`). A record alone can only show that it names one.
  if (blank(record.location?.id) && blank(record.location?.country)) say("country");
  const latitude = record.latitude ?? record.location?.latitude;
  const longitude = record.longitude ?? record.location?.longitude;
  if (blank(latitude) !== blank(longitude)) say(blank(latitude) ? "latitude" : "longitude", "Give both latitude and longitude, or neither.");

  // These are free text in the schema but dates in the database: a bad one is a clear refusal, not a crash.
  for (const key of ["handoverDate", "availableFrom"]) {
    const date = record.detail?.[key];
    if (!blank(date) && !/^\d{4}-\d{2}-\d{2}$/.test(String(date))) say(key, "Use a date like 2027-06-30.");
  }

  const images = record.images ?? [];
  if (new Set(images).size < MIN_IMAGES) say("images", `Give at least ${MIN_IMAGES} different images; this has ${new Set(images).size}.`);
  return missing;
}
