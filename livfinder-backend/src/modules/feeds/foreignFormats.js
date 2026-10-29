import { XMLParser } from "fast-xml-parser";

/**
 * Property Finder and Bayut XML, read into LivFinder's real-estate fields (Phase 5).
 *
 * A company that already exports one of these for the portals can point its LivFinder Real Estate
 * feed at the same file. Each entry becomes the same flat values a LivFinder CSV row has
 * (`externalId`, `title`, `price`, `city`, `bedrooms`…), and from there it is read and checked
 * exactly like a LivFinder file.
 *
 * Neither portal publishes one fixed schema (field names vary between versions and accounts), so
 * every field is looked up under the names in use, in any case. Nothing is guessed: a value that
 * cannot be placed is left out and the row reports what is missing. A place name or property type
 * that does not match LivFinder's goes to the admin's mapping queue on import (valueMappings.js).
 * Both portals' feeds are UAE files; a listing without a country is taken to be in the UAE.
 */

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  parseTagValue: false,
  trimValues: true,
  processEntities: true,
  isArray: (name) => ["property", "listing", "url", "image", "photo", "feature", "amenity", "facility"].includes(String(name).toLowerCase()),
});

// Property Finder's two-letter property type codes, to LivFinder's real-estate types.
const PF_TYPES = {
  AP: "apartment",
  VH: "villa",
  TH: "townhouse",
  PH: "penthouse",
  DX: "duplex",
  LP: "plot",
  OF: "office",
  RE: "retail",
  WB: "whole-building",
  HA: "hotel-apartment",
  BU: "villa",
};

const lowerKeys = (node) =>
  node && typeof node === "object" && !Array.isArray(node)
    ? Object.fromEntries(Object.entries(node).map(([key, value]) => [key.toLowerCase(), value]))
    : {};

/** The first non-empty text under any of `names` (case-insensitive). */
function pick(node, ...names) {
  const keys = lowerKeys(node);
  for (const name of names) {
    let value = keys[name.toLowerCase()];
    if (Array.isArray(value)) value = value[0];
    if (value && typeof value === "object") value = value["#text"] ?? null;
    if (value !== undefined && value !== null && String(value).trim() !== "") return String(value).trim();
  }
  return undefined;
}

function list(value) {
  if (value === undefined || value === null || value === "") return [];
  return (Array.isArray(value) ? value : [value]).flatMap((item) => (item && typeof item === "object" ? [item["#text"] ?? item.url ?? item.URL] : [item]));
}

const yesNo = (value) => {
  const text = String(value ?? "").trim().toLowerCase();
  if (["yes", "y", "true", "1"].includes(text)) return "yes";
  if (["no", "n", "false", "0"].includes(text)) return "no";
  return undefined;
};

function furnishing(value) {
  const text = String(value ?? "").trim().toLowerCase();
  if (!text) return undefined;
  if (text.startsWith("partl") || text.startsWith("semi")) return "semi_furnished";
  if (["yes", "furnished", "fully furnished"].includes(text)) return "furnished";
  if (["no", "unfurnished", "not furnished"].includes(text)) return "unfurnished";
  return undefined;
}

const bedrooms = (value) => (/^studio$/i.test(String(value ?? "").trim()) ? "0" : value);

/** "lat,lng" (a value outside ±90 is taken to be the longitude, whichever side it is on). */
function geopoints(value) {
  const parts = String(value ?? "").split(",").map((part) => Number(part.trim()));
  if (parts.length !== 2 || parts.some((part) => !Number.isFinite(part))) return {};
  const [a, b] = parts;
  return Math.abs(a) > 90 ? { latitude: String(b), longitude: String(a) } : { latitude: String(a), longitude: String(b) };
}

function compact(values) {
  return Object.fromEntries(Object.entries(values).filter(([, value]) => value !== undefined && value !== null && value !== "" && !(Array.isArray(value) && !value.length)));
}

/* -------------------------------------------------------------------------- */
/* Property Finder                                                             */
/* -------------------------------------------------------------------------- */

function propertyFinderEntry(node) {
  const offering = String(pick(node, "offering_type") || "").toUpperCase();
  const isRent = /R$/.test(offering) || /rent/i.test(offering);
  const priceNode = lowerKeys(node).price;
  let price = pick(node, "price");
  let pricePeriod;
  if (priceNode && typeof priceNode === "object" && !Array.isArray(priceNode)) {
    for (const [period, key] of [["year", "yearly"], ["month", "monthly"], ["week", "weekly"], ["day", "daily"]]) {
      const value = pick(priceNode, key);
      if (value) {
        price = value;
        pricePeriod = period;
        break;
      }
    }
  }
  const typeCode = String(pick(node, "property_type") || "").toUpperCase();
  const agent = lowerKeys(node).agent;
  const photoNode = lowerKeys(node).photo;
  const photos = (Array.isArray(photoNode) ? photoNode : photoNode ? [photoNode] : []).flatMap((photo) => list(lowerKeys(photo).url ?? photo));
  const amenities = String(pick(node, "private_amenities", "commercial_amenities", "amenities") || "")
    .split(",")
    .map((item) => item.trim())
    .filter(Boolean);
  const onRequest = yesNo(pick(node, "price_on_application")) === "yes";
  return compact({
    externalId: pick(node, "reference_number", "reference"),
    purpose: isRent ? "rent" : "sale",
    propertyType: PF_TYPES[typeCode] || typeCode || undefined,
    title: pick(node, "title_en", "title"),
    description: pick(node, "description_en", "description"),
    price: onRequest ? undefined : price,
    pricePeriod: isRent ? pricePeriod || "year" : undefined,
    isPriceHidden: onRequest ? "yes" : undefined,
    currency: pick(node, "currency") || "AED",
    country: pick(node, "country") || "AE",
    city: pick(node, "city"),
    community: pick(node, "community"),
    subCommunity: pick(node, "sub_community"),
    ...geopoints(pick(node, "geopoints")),
    agentEmail: agent ? pick(agent, "email") : undefined,
    images: photos.filter(Boolean),
    features: amenities,
    bedrooms: bedrooms(pick(node, "bedroom", "bedrooms")),
    bathrooms: pick(node, "bathroom", "bathrooms"),
    builtAreaSqft: pick(node, "size"),
    plotAreaSqft: pick(node, "plot_size"),
    parkingSpaces: pick(node, "parking"),
    buildingName: pick(node, "property_name"),
    permitNumber: pick(node, "permit_number"),
    furnishing: furnishing(pick(node, "furnished")),
    completionStatus: /off/i.test(pick(node, "completion_status") || "") ? "off_plan" : pick(node, "completion_status") ? "ready" : undefined,
  });
}

/* -------------------------------------------------------------------------- */
/* Bayut                                                                       */
/* -------------------------------------------------------------------------- */

function bayutEntry(node) {
  const purpose = String(pick(node, "Property_purpose", "Purpose") || "").toLowerCase();
  const isRent = purpose.includes("rent");
  const frequency = String(pick(node, "Rent_Frequency") || "").toLowerCase();
  const sizeUnit = String(pick(node, "Property_Size_Unit") || "sqft").toLowerCase();
  const size = pick(node, "Property_Size");
  const imagesNode = lowerKeys(node).images;
  const featuresNode = lowerKeys(node).features;
  return compact({
    externalId: pick(node, "Property_Ref_No", "Reference"),
    purpose: isRent ? "rent" : "sale",
    propertyType: pick(node, "Property_Type"),
    title: pick(node, "Property_Title", "Title"),
    description: pick(node, "Property_Description", "Description"),
    price: pick(node, "Price"),
    pricePeriod: isRent ? ({ yearly: "year", monthly: "month", weekly: "week", daily: "day" }[frequency] || "year") : undefined,
    currency: pick(node, "Currency") || "AED",
    country: pick(node, "Country") || "AE",
    city: pick(node, "City"),
    community: pick(node, "Locality"),
    subCommunity: pick(node, "Sub_Locality"),
    latitude: pick(node, "Latitude"),
    longitude: pick(node, "Longitude"),
    agentEmail: pick(node, "Listing_Agent_Email", "Agent_Email"),
    images: list(imagesNode && typeof imagesNode === "object" ? lowerKeys(imagesNode).image : imagesNode).filter(Boolean),
    features: list(featuresNode && typeof featuresNode === "object" ? lowerKeys(featuresNode).feature : featuresNode).filter(Boolean),
    bedrooms: bedrooms(pick(node, "Bedrooms")),
    bathrooms: pick(node, "Bathroom", "Bathrooms"),
    ...(size ? (sizeUnit.includes("m") && !sizeUnit.includes("ft") ? { builtAreaSqm: size } : { builtAreaSqft: size }) : {}),
    buildingName: pick(node, "Tower_Name", "Building_Name"),
    permitNumber: pick(node, "Permit_Number"),
    furnishing: furnishing(pick(node, "Furnished")),
    completionStatus: yesNo(pick(node, "Off_plan", "Off_Plan")) === "yes" ? "off_plan" : pick(node, "Off_plan", "Off_Plan") ? "ready" : undefined,
  });
}

/* -------------------------------------------------------------------------- */

/**
 * Recognises a Property Finder or Bayut file and returns its entries as LivFinder field values:
 * `{ source: "property_finder" | "bayut", entries: [values] }`, or null for anything else.
 */
export function readForeignXml(text) {
  let doc;
  try {
    doc = parser.parse(text);
  } catch {
    return null;
  }
  const root = lowerKeys(doc);
  for (const container of Object.values(root)) {
    const keys = lowerKeys(container);
    if (Array.isArray(keys.property) && keys.property.some((item) => pick(item, "reference_number") !== undefined)) {
      return { source: "property_finder", entries: keys.property.map(propertyFinderEntry) };
    }
    const listings = keys.listing || keys.property;
    if (Array.isArray(listings) && listings.some((item) => pick(item, "Property_Ref_No") !== undefined)) {
      return { source: "bayut", entries: listings.map(bayutEntry) };
    }
  }
  return null;
}
