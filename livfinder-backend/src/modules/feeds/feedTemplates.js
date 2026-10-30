import { FEED_CATEGORIES, LIST_SEPARATOR, feedFormat } from "./feedFormats.js";

/**
 * Everything a client downloads to build a feed, generated from the format registry so it can
 * never disagree with what the import accepts: a CSV template, an XML schema (XSD) and a sample
 * XML file, one of each per category.
 */

// Plural list element → the element each item sits in.
export const LIST_ITEM = { images: "image", features: "feature", highlights: "highlight", amenities: "amenity" };

// Readable example values; anything else is derived from the field's type.
const EXAMPLES = {
  externalId: "ABC-1001",
  title: "Example title written by the company",
  subtitle: "A short line under the title",
  description: "A full description of the listing.",
  name: "Example Residences",
  tagline: "A short line about the development",
  purpose: "sale",
  propertyType: "apartments",
  price: 2500000,
  minPrice: 1200000,
  maxPrice: 4500000,
  startingPrice: 1200000,
  currency: "AED",
  country: "AE",
  state: "Dubai",
  city: "Dubai",
  community: "Dubai Marina",
  subCommunity: "Bay Central",
  handoverDate: "2027-06-30",
  availableFrom: "2027-01-01",
  agentEmail: "agent@example.com",
  contactEmail: "sales@example.com",
  contactPhone: "+971500000000",
  images: ["https://example.com/photos/1.jpg", "https://example.com/photos/2.jpg", "https://example.com/photos/3.jpg"],
  features: ["Private pool", "Sea view"],
  highlights: ["Beachfront", "Branded residences"],
  amenities: ["Gym", "Infinity pool"],
  brochureUrl: "https://example.com/brochure.pdf",
};

const CATEGORY_EXAMPLES = {
  cars: {
    propertyType: "supercars", brand: "Porsche", model: "911 Turbo S", title: "2022 Porsche 911 Turbo S", price: 850000,
    modelYear: 2022, mileageKm: 8000, transmission: "dual_clutch", fuelType: "petrol", drivetrain: "awd",
    engineSizeCc: 3745, cylinders: 6,
    features: ["Sport Chrono package", "Carbon ceramic brakes"],
  },
  yachts: {
    propertyType: "motor-yachts", brand: "Sunseeker", model: "Predator 74", title: "2021 Sunseeker Predator 74", price: 14000000,
    buildYear: 2021, lengthOverallM: 22.6, vesselType: "motor_yacht", hullMaterial: "grp", cabins: 4,
    features: ["Stabilisers", "Jet ski"],
  },
  jets: {
    propertyType: "light-jets", brand: "Embraer", model: "Phenom 300E", title: "2019 Embraer Phenom 300E", price: 38000000,
    aircraftType: "light_jet", yearBuilt: 2019, totalTimeHours: 1200, passengerCapacity: 8,
    features: ["Wi-Fi", "Enrolled on engine program"],
  },
  helicopters: {
    propertyType: "light-helicopter", brand: "Airbus Helicopters", model: "ACH130", title: "2020 Airbus H125", price: 11000000,
    aircraftType: "light_helicopter", yearBuilt: 2020, totalTimeHours: 450, passengerCapacity: 5,
    features: ["Air conditioning", "Cargo hook"],
  },
  watches: {
    propertyType: "dive-watches", brand: "Rolex", model: "Daytona", title: "Rolex Submariner Date 126610LN", price: 14500,
    currency: "USD", referenceNumber: "126610LN", yearOfProduction: 2022, caseMaterial: "Oystersteel", caseDiameterMm: 41,
    movementType: "automatic", hasOriginalBox: true, hasOriginalPapers: true,
    features: ["Box and papers", "Unworn"],
  },
  "real-estate": {
    title: "3 bedroom apartment with sea view in Dubai Marina", bedrooms: 3, bathrooms: 3, builtAreaSqft: 2100,
    completionStatus: "ready", furnishing: "unfurnished",
  },
};

function example(field, category) {
  const own = CATEGORY_EXAMPLES[category]?.[field.key] ?? EXAMPLES[field.key];
  if (own !== undefined) return own;
  switch (field.type) {
    case "enum":
      return field.values[0];
    case "boolean":
      return false;
    case "integer":
      return Math.max(field.min ?? 0, 1);
    case "number":
      return Math.max(field.min ?? 0, 1);
    case "date":
      return "2027-06-30";
    default:
      return field.list ? ["Example"] : "Example";
  }
}

const SAMPLE_KEYS = new Set([
  "externalId", "title", "name", "tagline", "purpose", "propertyType", "price", "currency", "country", "city",
  "community", "subCommunity", "agentEmail", "images", "features", "brand", "model", "minPrice", "status", "launchStatus",
  "handoverDate", "totalUnits", "availableUnits", "highlights", "amenities",
]);

/** The fields a sample fills in: everything required, the common ones, and the category's own examples. */
function sampleFields(fields, category) {
  return fields.filter(
    (field) => field.required || SAMPLE_KEYS.has(field.key) || CATEGORY_EXAMPLES[category]?.[field.key] !== undefined
  );
}

/* -------------------------------------------------------------------------- */
/* CSV                                                                         */
/* -------------------------------------------------------------------------- */

function csvCell(value) {
  if (value === undefined || value === null) return "";
  const text = Array.isArray(value) ? value.join(LIST_SEPARATOR) : String(value);
  return /[",\n\r]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
}

/**
 * The CSV columns of a category. A development file has one row per unit type and payment plan:
 * the development's own columns, then `unit.*` and `plan.*` (rows of one development share its
 * externalId; its own columns need filling only once).
 */
export function csvColumns(category) {
  const format = feedFormat(category);
  if (!format) return null;
  if (format.entity === "development") {
    return [
      ...format.fields.map((field) => field.key),
      ...format.unitTypeFields.map((field) => `unit.${field.key}`),
      ...format.paymentPlanFields.map((field) => `plan.${field.key}`),
    ];
  }
  return format.fields.map((field) => field.key);
}

export function csvTemplate(category) {
  const format = feedFormat(category);
  if (!format) return null;
  const columns = csvColumns(category);
  const sample = new Set(sampleFields(format.fields, category));
  if (format.entity === "development") {
    const own = Object.fromEntries(format.fields.map((field) => [field.key, sample.has(field) ? example(field, category) : ""]));
    const unit = (unitType, bedrooms, price) => ({ "unit.unitType": unitType, "unit.bedrooms": bedrooms, "unit.startingPrice": price, "unit.currency": "AED", "unit.availability": "available" });
    const plan = { "plan.name": "60/40", "plan.planType": "construction_linked", "plan.downPaymentPercent": 20, "plan.duringConstructionPercent": 40, "plan.onHandoverPercent": 40 };
    const rows = [
      { ...own, ...unit("apartment", 1, 1200000), ...plan },
      { externalId: own.externalId, ...unit("apartment", 2, 1900000) },
      { externalId: own.externalId, ...unit("penthouse", 4, 4500000) },
    ];
    return [columns.join(","), ...rows.map((row) => columns.map((column) => csvCell(row[column])).join(","))].join("\r\n") + "\r\n";
  }
  const row = format.fields.map((field) => csvCell(sample.has(field) ? example(field, category) : ""));
  return `${columns.join(",")}\r\n${row.join(",")}\r\n`;
}

/* -------------------------------------------------------------------------- */
/* XML                                                                         */
/* -------------------------------------------------------------------------- */

const escapeXml = (value) =>
  String(value).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

function xmlFields(fields, values, indent) {
  const pad = " ".repeat(indent);
  const lines = [];
  for (const field of fields) {
    const value = values[field.key];
    if (value === undefined || value === null || value === "" || (Array.isArray(value) && !value.length)) continue;
    if (field.list) {
      const item = LIST_ITEM[field.key] || "item";
      lines.push(`${pad}<${field.key}>`);
      for (const entry of value) lines.push(`${pad}  <${item}>${escapeXml(entry)}</${item}>`);
      lines.push(`${pad}</${field.key}>`);
    } else {
      lines.push(`${pad}<${field.key}>${escapeXml(value)}</${field.key}>`);
    }
  }
  return lines;
}

function grouped(fields, values, indent) {
  const pad = " ".repeat(indent);
  const top = fields.filter((field) => !["location", "details"].includes(field.group));
  const location = fields.filter((field) => field.group === "location");
  const details = fields.filter((field) => field.group === "details");
  const lines = xmlFields(top, values, indent);
  const where = xmlFields(location, values, indent + 2);
  if (where.length) lines.push(`${pad}<location>`, ...where, `${pad}</location>`);
  const own = xmlFields(details, values, indent + 2);
  if (own.length) lines.push(`${pad}<details>`, ...own, `${pad}</details>`);
  return lines;
}

export function sampleXml(category) {
  const format = feedFormat(category);
  if (!format) return null;
  const sample = sampleFields(format.fields, category);
  const values = Object.fromEntries(sample.map((field) => [field.key, example(field, category)]));
  const lines = ['<?xml version="1.0" encoding="UTF-8"?>', `<livfinder-feed category="${category}" version="${format.version}">`];
  if (format.entity === "development") {
    lines.push("  <development>", ...grouped(sample, values, 4));
    lines.push("    <unitTypes>");
    for (const [unitType, bedrooms, price] of [["apartment", 1, 1200000], ["apartment", 2, 1900000], ["penthouse", 4, 4500000]]) {
      lines.push("      <unitType>", ...xmlFields(format.unitTypeFields, { unitType, bedrooms, startingPrice: price, currency: "AED", availability: "available" }, 8), "      </unitType>");
    }
    lines.push("    </unitTypes>", "    <paymentPlans>", "      <paymentPlan>");
    lines.push(...xmlFields(format.paymentPlanFields, { name: "60/40", planType: "construction_linked", downPaymentPercent: 20, duringConstructionPercent: 40, onHandoverPercent: 40 }, 8));
    lines.push("        <milestones>");
    for (const [name, triggerType, percentage] of [["Booking", "booking", 20], ["During construction", "construction_percent", 40], ["Handover", "handover", 40]]) {
      lines.push("          <milestone>", ...xmlFields(format.milestoneFields, { name, triggerType, percentage }, 12), "          </milestone>");
    }
    lines.push("        </milestones>", "      </paymentPlan>", "    </paymentPlans>", "  </development>");
  } else {
    lines.push("  <listing>", ...grouped(sample, values, 4), "  </listing>");
  }
  lines.push("</livfinder-feed>");
  return `${lines.join("\n")}\n`;
}

/** A sample of the file that holds every category, each in its own section. */
export function sampleAllXml() {
  const sections = FEED_CATEGORIES.flatMap((category) => {
    const entry = sampleXml(category).trimEnd().split("\n").slice(2, -1);
    return [`  <category name="${category}" version="${feedFormat(category).version}">`, ...entry.map((line) => `  ${line}`), "  </category>"];
  });
  return ['<?xml version="1.0" encoding="UTF-8"?>', '<livfinder-feed version="1">', ...sections, "</livfinder-feed>", ""].join("\n");
}

/* -------------------------------------------------------------------------- */
/* What a client pushed, written back out                                      */
/* -------------------------------------------------------------------------- */

const pathValue = (record, path) => String(path).split(".").reduce((node, key) => node?.[key], record);

const fieldValues = (fields, record) => Object.fromEntries(fields.map((field) => [field.key, pathValue(record, field.path ?? field.key)]));

function entryXml(format, record, status, indent) {
  const pad = " ".repeat(indent);
  const lines = [`${pad}<${format.entity} livfinderStatus="${escapeXml(status)}">`, ...grouped(format.fields, fieldValues(format.fields, record), indent + 2)];
  if (format.entity === "development") {
    const inner = " ".repeat(indent + 2);
    lines.push(`${inner}<unitTypes>`);
    for (const unit of record.unitTypes || []) {
      lines.push(`${inner}  <unitType>`, ...xmlFields(format.unitTypeFields, fieldValues(format.unitTypeFields, unit), indent + 6), `${inner}  </unitType>`);
    }
    lines.push(`${inner}</unitTypes>`, `${inner}<paymentPlans>`);
    for (const plan of record.paymentPlans || []) {
      lines.push(`${inner}  <paymentPlan>`, ...xmlFields(format.paymentPlanFields, fieldValues(format.paymentPlanFields, plan), indent + 6));
      lines.push(`${inner}    <milestones>`);
      for (const step of plan.milestones || []) {
        lines.push(`${inner}      <milestone>`, ...xmlFields(format.milestoneFields, fieldValues(format.milestoneFields, step), indent + 10), `${inner}      </milestone>`);
      }
      lines.push(`${inner}    </milestones>`, `${inner}  </paymentPlan>`);
    }
    lines.push(`${inner}</paymentPlans>`);
  }
  lines.push(`${pad}</${format.entity}>`);
  return lines;
}

/**
 * The all-categories file for one client: `sections` is `[{ category, entries }]`, an entry being
 * `{ record, status }`. It can be pushed straight back: `livfinderStatus` is ignored on the way in.
 */
export function listingsXml(sections, baseUrl = "") {
  const lines = ['<?xml version="1.0" encoding="UTF-8"?>', '<livfinder-feed version="1">'];
  for (const { category, entries } of sections) {
    const format = feedFormat(category);
    const open = `  <category name="${category}" version="${format.version}" label="${escapeXml(format.label)}" count="${entries.length}" format="${escapeXml(`${baseUrl}/v1/public/feed-formats/${category}`)}"`;
    if (!entries.length) {
      lines.push(`${open}/>`);
      continue;
    }
    lines.push(`${open}>`, ...entries.flatMap((entry) => entryXml(format, entry.record, entry.status, 4)), "  </category>");
  }
  lines.push("</livfinder-feed>", "");
  return lines.join("\n");
}

const csvValue = (field, value) => csvCell(field.list && Array.isArray(value) ? value.join(LIST_SEPARATOR) : value);

/** One category's pushed entries as a CSV file, with `livfinderStatus` as its last column. */
export function listingsCsv(category, entries) {
  const format = feedFormat(category);
  const columns = [...csvColumns(category), "livfinderStatus"];
  const line = (cells) => columns.map((column) => cells[column] ?? "").join(",");
  const rows = entries.flatMap(({ record, status }) => {
    const own = Object.fromEntries(format.fields.map((field) => [field.key, csvValue(field, pathValue(record, field.path ?? field.key))]));
    if (format.entity !== "development") return [line({ ...own, livfinderStatus: csvCell(status) })];
    // A development is one row per unit type and payment plan; rows after the first repeat only its id.
    const units = record.unitTypes || [];
    const plans = record.paymentPlans || [];
    return Array.from({ length: Math.max(units.length, plans.length, 1) }, (_, index) => {
      const cells = index ? { externalId: own.externalId } : { ...own, livfinderStatus: csvCell(status) };
      for (const field of format.unitTypeFields) cells[`unit.${field.key}`] = units[index] ? csvCell(pathValue(units[index], field.path ?? field.key)) : "";
      for (const field of format.paymentPlanFields) cells[`plan.${field.key}`] = plans[index] ? csvCell(pathValue(plans[index], field.path ?? field.key)) : "";
      return line(cells);
    });
  });
  return [columns.join(","), ...rows].join("\r\n") + "\r\n";
}

/* -------------------------------------------------------------------------- */
/* XSD                                                                         */
/* -------------------------------------------------------------------------- */

function xsdSimpleType(field) {
  const facets = [];
  let base = "xs:string";
  if (field.type === "integer") base = "xs:integer";
  else if (field.type === "number") base = "xs:decimal";
  else if (field.type === "boolean") return 'type="xs:boolean"';
  else if (field.type === "date") return 'type="xs:date"';
  if (field.type === "enum") for (const value of field.values) facets.push(`<xs:enumeration value="${escapeXml(value)}"/>`);
  if ((field.type === "integer" || field.type === "number") && field.min !== undefined) facets.push(`<xs:minInclusive value="${field.min}"/>`);
  if ((field.type === "integer" || field.type === "number") && field.max !== undefined) facets.push(`<xs:maxInclusive value="${field.max}"/>`);
  if (field.type === "string" && field.maxLength) facets.push(`<xs:maxLength value="${field.maxLength}"/>`);
  if (!facets.length) return `type="${base}"`;
  return { base, facets };
}

function xsdElement(field, indent) {
  const pad = " ".repeat(indent);
  const occurs = field.required ? "" : ' minOccurs="0"';
  const type = xsdSimpleType(field);
  const simple = (name, extra = "") =>
    typeof type === "string"
      ? [`${pad}<xs:element name="${name}" ${type}${extra}/>`]
      : [
          `${pad}<xs:element name="${name}"${extra}>`,
          `${pad}  <xs:simpleType><xs:restriction base="${type.base}">${type.facets.join("")}</xs:restriction></xs:simpleType>`,
          `${pad}</xs:element>`,
        ];
  if (!field.list) return simple(field.key, occurs);
  return [
    `${pad}<xs:element name="${field.key}"${occurs}>`,
    `${pad}  <xs:complexType><xs:sequence>`,
    ...simple(LIST_ITEM[field.key] || "item", ' maxOccurs="unbounded"').map((line) => `    ${line}`),
    `${pad}  </xs:sequence></xs:complexType>`,
    `${pad}</xs:element>`,
  ];
}

function xsdGroup(name, fields, indent, { all = true, many = false, extra = [] } = {}) {
  const pad = " ".repeat(indent);
  return [
    `${pad}<xs:element name="${name}"${many ? ' maxOccurs="unbounded"' : ' minOccurs="0"'}>`,
    `${pad}  <xs:complexType>`,
    `${pad}    <xs:${all ? "all" : "sequence"}>`,
    ...fields.flatMap((field) => xsdElement(field, indent + 6)),
    ...extra,
    `${pad}    </xs:${all ? "all" : "sequence"}>`,
    `${pad}  </xs:complexType>`,
    `${pad}</xs:element>`,
  ];
}

export function xmlSchema(category) {
  const format = feedFormat(category);
  if (!format) return null;
  const top = format.fields.filter((field) => !["location", "details"].includes(field.group));
  const location = format.fields.filter((field) => field.group === "location");
  const details = format.fields.filter((field) => field.group === "details");
  const children = [
    ...top.flatMap((field) => xsdElement(field, 12)),
    ...xsdGroup("location", location, 12),
    ...(details.length ? xsdGroup("details", details, 12) : []),
  ];
  if (format.entity === "development") {
    children.push(
      "            <xs:element name=\"unitTypes\" minOccurs=\"0\"><xs:complexType><xs:sequence>",
      ...xsdGroup("unitType", format.unitTypeFields, 16, { many: true }),
      "            </xs:sequence></xs:complexType></xs:element>",
      "            <xs:element name=\"paymentPlans\" minOccurs=\"0\"><xs:complexType><xs:sequence>",
      ...xsdGroup("paymentPlan", format.paymentPlanFields, 16, {
        many: true,
        extra: [
          "                      <xs:element name=\"milestones\" minOccurs=\"0\"><xs:complexType><xs:sequence>",
          ...xsdGroup("milestone", format.milestoneFields, 24, { many: true }),
          "                      </xs:sequence></xs:complexType></xs:element>",
        ],
      }),
      "            </xs:sequence></xs:complexType></xs:element>"
    );
  }
  const entity = format.entity === "development" ? "development" : "listing";
  return [
    '<?xml version="1.0" encoding="UTF-8"?>',
    `<!-- LivFinder ${format.label} feed, version ${format.version}. Generated from the import's own rules. -->`,
    '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" elementFormDefault="qualified">',
    '  <xs:element name="livfinder-feed">',
    "    <xs:complexType>",
    "      <xs:sequence>",
    `        <xs:element name="${entity}" minOccurs="0" maxOccurs="unbounded">`,
    "          <xs:complexType>",
    "            <xs:all>",
    ...children.map((line) => `  ${line}`),
    "            </xs:all>",
    "          </xs:complexType>",
    "        </xs:element>",
    "      </xs:sequence>",
    `      <xs:attribute name="category" type="xs:string" fixed="${category}" use="required"/>`,
    `      <xs:attribute name="version" type="xs:integer" use="required"/>`,
    "    </xs:complexType>",
    "  </xs:element>",
    "</xs:schema>",
    "",
  ].join("\n");
}
