import { parse as parseCsv } from "csv-parse/sync";
import { XMLParser } from "fast-xml-parser";
import { FEED_XML_ENTITIES } from "./xmlEntities.js";
import { AppError } from "../../utils/errors.js";
import { DETAIL_SCHEMAS } from "../listings/listings.schemas.js";
import { parseListingRecord } from "../imports/listingImport.service.js";
import { FORMAT_VERSIONS, LIST_SEPARATOR, feedFormat } from "./feedFormats.js";
import { LIST_ITEM, csvColumns } from "./feedTemplates.js";
import { foreignEntries, readForeignXml } from "./foreignFormats.js";
import { XmlShapeError, childElements, contentEnd, entityDeclarations, rootElement, textOf, toBytes } from "./xmlChunks.js";
import { missingRequired } from "./listingRequirements.js";

/**
 * Reads one category's feed file (LivFinder XML or CSV) into the records the import takes.
 *
 * The file is checked as a whole (well-formed, the right category, a version this server reads,
 * within the size and row limits), then row by row: each value is read by its field's type
 * (numbers, yes/no, a value from the field's list, dates, lists separated by `|`), and the
 * record is held to the same rules as a listing pushed through the API. A bad row is reported
 * with its row number and field names and never stops the others.
 *
 * Returns `{ category, version, entity, items: [{ row, externalId, record, errors }], warnings }`.
 * Developments come out as `{ externalId, ...development, location, unitTypes, paymentPlans }`;
 * their own validation happens where they are saved.
 */

// A large agency's full portal export runs to 75 MB and more (LuxuryProperty.com: 16,529 listings).
export const MAX_FEED_BYTES = 150 * 1024 * 1024;
export const MAX_FEED_ROWS = 20_000;

function fileError(message, fields) {
  return new AppError(message, { status: 422, code: "FEED_INVALID", fields });
}

/* -------------------------------------------------------------------------- */
/* Reading one value by its field's type                                       */
/* -------------------------------------------------------------------------- */

const TRUE = new Set(["true", "yes", "y", "1"]);
const FALSE = new Set(["false", "no", "n", "0"]);

function readValue(field, raw) {
  if (raw === undefined || raw === null) return { skip: true };
  if (field.list) {
    const items = (Array.isArray(raw) ? raw : String(raw).split(LIST_SEPARATOR))
      .map((item) => String(item ?? "").trim())
      .filter(Boolean);
    if (!items.length) return { skip: true };
    const read = items.map((item) => readValue({ ...field, list: false }, item));
    const bad = read.find((item) => item.error);
    return bad ? { error: bad.error } : { value: read.map((item) => item.value) };
  }
  const text = String(raw).trim();
  if (text === "") return { skip: true };
  switch (field.type) {
    case "integer":
    case "number": {
      const value = Number(text.replace(/[\s,]/g, ""));
      if (!Number.isFinite(value)) return { error: "Give a number." };
      if (field.type === "integer" && !Number.isInteger(value)) return { error: "Give a whole number." };
      if (field.min !== undefined && value < field.min) return { error: `Give ${field.min} or more.` };
      if (field.max !== undefined && value > field.max) return { error: `Give ${field.max} or less.` };
      return { value };
    }
    case "boolean": {
      const lower = text.toLowerCase();
      if (TRUE.has(lower)) return { value: true };
      if (FALSE.has(lower)) return { value: false };
      return { error: "Give yes or no." };
    }
    case "enum": {
      const value = text.toLowerCase().replace(/[\s-]+/g, "_");
      if (!field.values.includes(value)) return { error: `Use one of: ${field.values.join(", ")}.` };
      return { value };
    }
    case "date":
      if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return { error: "Give a date as YYYY-MM-DD." };
      return { value: text };
    default:
      if (field.maxLength && text.length > field.maxLength) return { error: `Use at most ${field.maxLength} characters.` };
      return { value: text };
  }
}

function setPath(target, path, value) {
  const parts = path.split(".");
  let node = target;
  for (const part of parts.slice(0, -1)) node = node[part] ??= {};
  node[parts.at(-1)] = value;
}

/** Reads `values` (key → raw) against `fields`; returns the object and the errors by key. */
function readFields(fields, values, prefix = "") {
  const out = {};
  const errors = {};
  for (const field of fields) {
    const result = readValue(field, values[field.key]);
    if (result.error) errors[`${prefix}${field.key}`] = result.error;
    else if (!result.skip) setPath(out, field.path, result.value);
    else if (field.required) errors[`${prefix}${field.key}`] = "This is required.";
  }
  return { out, errors };
}

/* -------------------------------------------------------------------------- */
/* Turning read values into records                                            */
/* -------------------------------------------------------------------------- */

function listingItem(category, format, values, row) {
  // Withdrawing needs only the id: the listing is already on LivFinder.
  if (String(values.status ?? "").trim().toLowerCase() === "withdrawn") {
    const id = String(values.externalId ?? "").trim();
    if (!id) return { row, externalId: null, record: null, errors: { externalId: "This is required." } };
    return { row, externalId: id, record: { externalId: id, category, withdraw: true }, errors: null };
  }
  const { out, errors } = readFields(format.fields, values);
  const externalId = typeof out.externalId === "string" ? out.externalId : null;
  // Every missing field at once, so a client fixes a listing in one go.
  const REQUIRED = "This is required.";
  const unreadable = Object.values(errors).some((message) => message !== REQUIRED);
  for (const [key, message] of Object.entries(missingRequired(category, out))) {
    if (!errors[key] || errors[key] === REQUIRED) errors[key] = message;
  }
  const record = { ...out, category };
  // What was sent stays with a rejected entry, so the notice can name the listing.
  if (Object.keys(errors).length) return { row, externalId, record: unreadable ? null : record, errors };
  try {
    const parsed = parseListingRecord(record);
    if (parsed.detail) {
      const detail = DETAIL_SCHEMAS[category].strict().safeParse(parsed.detail);
      if (!detail.success) {
        return {
          row,
          externalId,
          record: null,
          errors: Object.fromEntries(detail.error.issues.map((issue) => [issue.path.join(".") || "details", issue.message])),
        };
      }
    }
    return { row, externalId, record: parsed, errors: null };
  } catch (error) {
    return { row, externalId, record: null, errors: error.fields || { _: error.message } };
  }
}

function developmentItem(format, entry, row) {
  const { out, errors } = readFields(format.fields, entry.values);
  const unitTypes = entry.unitTypes.map((unit, index) => {
    const read = readFields(format.unitTypeFields, unit, `unitTypes.${index + 1}.`);
    Object.assign(errors, read.errors);
    return read.out;
  });
  const paymentPlans = entry.paymentPlans.map((plan, index) => {
    const read = readFields(format.paymentPlanFields, plan.values, `paymentPlans.${index + 1}.`);
    Object.assign(errors, read.errors);
    const milestones = plan.milestones.map((milestone, position) => {
      const step = readFields(format.milestoneFields, milestone, `paymentPlans.${index + 1}.milestones.${position + 1}.`);
      Object.assign(errors, step.errors);
      return step.out;
    });
    return { ...read.out, ...(milestones.length ? { milestones } : {}) };
  });
  for (const [key, message] of Object.entries(missingRequired("developments", { ...out, unitTypes, paymentPlans }))) errors[key] ??= message;
  const externalId = typeof out.externalId === "string" ? out.externalId : null;
  if (Object.keys(errors).length) return { row, externalId, record: null, errors };
  return { row, externalId, record: { ...out, unitTypes, paymentPlans }, errors: null };
}

function markDuplicates(items) {
  const seen = new Map();
  for (const item of items) {
    if (!item.externalId) continue;
    if (seen.has(item.externalId)) {
      item.record = null;
      item.errors = { externalId: `This externalId is also on row ${seen.get(item.externalId)}. Send each one once per file.` };
    } else {
      seen.set(item.externalId, item.row);
    }
  }
  return items;
}

/* -------------------------------------------------------------------------- */
/* XML                                                                         */
/* -------------------------------------------------------------------------- */

// The same entries sit directly under the root in a one-category file, and under a <category>
// section in a file holding several.
const ENTRY_PATHS = [
  "listing",
  "development",
  "development.unitTypes.unitType",
  "development.paymentPlans.paymentPlan",
  "development.paymentPlans.paymentPlan.milestones.milestone",
];
const ARRAY_PATHS = new Set([
  "livfinder-feed.category",
  ...ENTRY_PATHS.flatMap((path) => [`livfinder-feed.${path}`, `livfinder-feed.category.${path}`]),
]);

const xml = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  parseTagValue: false,
  parseAttributeValue: false,
  trimValues: true,
  processEntities: FEED_XML_ENTITIES,
  isArray: (name, jpath) => ARRAY_PATHS.has(jpath) || Object.values(LIST_ITEM).includes(name),
});

// One entry parsed on its own (see xmlChunks.js): its paths start at the entry, not the root.
const ENTRY_ARRAYS = new Set(ENTRY_PATHS);
const entryXml = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  parseTagValue: false,
  parseAttributeValue: false,
  trimValues: true,
  processEntities: FEED_XML_ENTITIES,
  isArray: (name, jpath) => ENTRY_ARRAYS.has(jpath) || Object.values(LIST_ITEM).includes(name),
});

/** The file's root element. A tag that does not close, or closes the wrong element, refuses the file. */
function wellFormedRoot(bytes) {
  let root;
  try {
    root = rootElement(bytes);
  } catch (error) {
    if (error instanceof XmlShapeError) throw fileError("The XML file could not be read.", { file: error.message.slice(0, 300) });
    throw error;
  }
  if (!root) throw fileError("The XML file could not be read.", { file: "The file has no root element." });
  return root;
}

/** A start tag's attributes, as the whole-file parser gives them (`@_name`…). */
function startTagAttributes(bytes, element) {
  const tag = textOf(bytes, element.start, element.openEnd);
  let doc;
  try {
    doc = xml.parse(element.selfClosing ? tag : `${tag}</${element.name}>`, true);
  } catch (error) {
    throw fileError("The XML file could not be read.", { file: String(error.message || error).slice(0, 300) });
  }
  const node = doc?.[element.name];
  return node && typeof node === "object" && !Array.isArray(node) ? node : {};
}

/**
 * The `entity` entries directly inside an element, each decoded and parsed (and checked for
 * well-formedness) on its own as it is reached.
 */
function* entryNodes(bytes, parent, entity) {
  if (parent.selfClosing) return;
  let position = 0;
  for (const element of childElements(bytes, parent.openEnd, contentEnd(bytes, parent))) {
    if (element.name !== entity) continue;
    position++;
    let doc;
    try {
      doc = entryXml.parse(textOf(bytes, element.start, element.end), true);
    } catch (error) {
      throw fileError("The XML file could not be read.", { file: `Entry ${position}: ${String(error.message || error)}`.slice(0, 300) });
    }
    yield doc?.[entity]?.[0] ?? "";
  }
}

/** An entity element's values, with `<location>` and `<details>` flattened and lists unwrapped. */
function flattenNode(node, format) {
  const values = {};
  const listKeys = new Set(format.fields.filter((field) => field.list).map((field) => field.key));
  for (const [key, value] of Object.entries(node || {})) {
    if (key === "location" || key === "details") {
      Object.assign(values, typeof value === "object" && value ? value : {});
    } else if (listKeys.has(key)) {
      const items = value && typeof value === "object" ? value[LIST_ITEM[key] || "item"] : value;
      values[key] = Array.isArray(items) ? items.map(String) : items === undefined || items === "" ? undefined : [String(items)];
    } else if (!["unitTypes", "paymentPlans"].includes(key)) {
      values[key] = value;
    }
  }
  return values;
}

function unknownKeys(values, format) {
  const known = new Set(format.fields.map((field) => field.key));
  return Object.keys(values).filter((key) => !known.has(key) && !key.startsWith("@_"));
}

/**
 * A LivFinder, Property Finder or Bayut XML file for one category, read one entry at a time: the
 * text is checked for well-formedness, then scanned, and each entry parsed as it is reached.
 */
function readXml(category, format, bytes) {
  const root = wellFormedRoot(bytes);
  if (entityDeclarations(bytes, root.start)) return readXmlWhole(category, format, bytes.toString("utf8"));
  if (root.name !== "livfinder-feed") {
    // A Property Finder or Bayut export, read into LivFinder's real-estate fields (Phase 5).
    const foreign = category === "real-estate" ? foreignEntries(bytes) : null;
    if (foreign) {
      const items = [];
      for (const values of foreign.entries) {
        if (items.length >= MAX_FEED_ROWS) break;
        items.push(listingItem(category, format, values, items.length + 1));
      }
      return {
        version: FORMAT_VERSIONS[category],
        source: foreign.source,
        items,
        warnings: foreign.count > MAX_FEED_ROWS ? [`Only the first ${MAX_FEED_ROWS} entries were read.`] : [],
      };
    }
    throw fileError(
      category === "real-estate"
        ? "The XML file must be a LivFinder feed (<livfinder-feed>), or a Property Finder or Bayut export."
        : "The XML file must have a <livfinder-feed> root element."
    );
  }
  const attributes = startTagAttributes(bytes, root);
  if (attributes["@_category"] !== category) {
    throw fileError(`This feed is set up for ${category}; the file says category="${attributes["@_category"] ?? ""}".`, {
      category: `Send a ${category} file to this feed.`,
    });
  }
  return readEntries(category, format, { attributes, nodes: entryNodes(bytes, root, format.entity) });
}

/**
 * The whole-file reader, kept for a file whose DOCTYPE declares its own entities: those apply to
 * the whole document, so its entries cannot be parsed one by one. No portal export does this.
 */
function readXmlWhole(category, format, text) {
  let doc;
  try {
    doc = xml.parse(text, true);
  } catch (error) {
    throw fileError("The XML file could not be read.", { file: String(error.message || error).slice(0, 300) });
  }
  const root = doc?.["livfinder-feed"];
  if (!root || typeof root !== "object") {
    // A Property Finder or Bayut export, read into LivFinder's real-estate fields (Phase 5).
    const foreign = category === "real-estate" ? readForeignXml(text) : null;
    if (foreign) {
      return {
        version: FORMAT_VERSIONS[category],
        source: foreign.source,
        items: foreign.entries.slice(0, MAX_FEED_ROWS).map((values, index) => listingItem(category, format, values, index + 1)),
        warnings: foreign.entries.length > MAX_FEED_ROWS ? [`Only the first ${MAX_FEED_ROWS} entries were read.`] : [],
      };
    }
    throw fileError(
      category === "real-estate"
        ? "The XML file must be a LivFinder feed (<livfinder-feed>), or a Property Finder or Bayut export."
        : "The XML file must have a <livfinder-feed> root element."
    );
  }
  if (root["@_category"] !== category) {
    throw fileError(`This feed is set up for ${category}; the file says category="${root["@_category"] ?? ""}".`, {
      category: `Send a ${category} file to this feed.`,
    });
  }
  return readEntries(category, format, { attributes: root, nodes: root[format.entity] || [] });
}

/** The entries of one category, from the root of a one-category file or a <category> section. */
function readEntries(category, format, { attributes, nodes }) {
  const version = Number(attributes["@_version"] ?? FORMAT_VERSIONS[category]);
  const entity = format.entity;
  const warnings = new Set();
  const items = [];
  let index = -1;
  for (const node of nodes) {
    index++;
    if (index >= MAX_FEED_ROWS) throw fileError(`A feed file can hold at most ${MAX_FEED_ROWS} entries.`);
    items.push(readEntry(node, index));
  }
  return { version, items, warnings: [...warnings] };

  function readEntry(node, index) {
    const values = flattenNode(node, format);
    for (const key of unknownKeys(values, format)) warnings.add(`Unknown element <${key}> was ignored.`);
    if (entity === "development") {
      const unitTypes = (node.unitTypes?.unitType || []).map((unit) => unit || {});
      const paymentPlans = (node.paymentPlans?.paymentPlan || []).map((plan) => ({
        values: plan || {},
        milestones: (plan?.milestones?.milestone || []).map((step) => step || {}),
      }));
      return developmentItem(format, { values, unitTypes, paymentPlans }, index + 1);
    }
    return listingItem(category, format, values, index + 1);
  }
}

/* -------------------------------------------------------------------------- */
/* CSV                                                                         */
/* -------------------------------------------------------------------------- */

function readCsv(category, format, text) {
  let records;
  try {
    // Read as arrays, not objects, so a file with a header and no rows (a feed that is now
    // empty) still has a header to check.
    records = parseCsv(text, { bom: true, skip_empty_lines: true, trim: true, relax_quotes: false });
  } catch (error) {
    throw fileError("The CSV file could not be read.", { file: String(error.message || error).slice(0, 300) });
  }
  const [header = [], ...data] = records;
  if (data.length > MAX_FEED_ROWS) throw fileError(`A feed file can hold at most ${MAX_FEED_ROWS} rows.`);
  const rows = data.map((cells) => Object.fromEntries(header.map((column, index) => [column, cells[index] ?? ""])));
  const known = new Set(csvColumns(category));
  const warnings = header.filter((column) => !known.has(column)).map((column) => `Unknown column "${column}" was ignored.`);
  if (!header.includes("externalId")) throw fileError('The CSV file needs an "externalId" column.', { externalId: "Add the column." });

  // A data row is file row + 1: the header is row 1.
  if (format.entity !== "development") {
    return { version: FORMAT_VERSIONS[category], items: rows.map((values, index) => listingItem(category, format, values, index + 2)), warnings };
  }

  // Development rows that share an externalId are one development: its own columns from the first
  // row that fills them, one unit type and one payment plan per row.
  const groups = new Map();
  rows.forEach((values, index) => {
    const id = String(values.externalId || "").trim() || `row-${index + 2}`;
    if (!groups.has(id)) groups.set(id, { row: index + 2, values: {}, unitTypes: [], paymentPlans: [] });
    const group = groups.get(id);
    for (const field of format.fields) {
      if (group.values[field.key] === undefined && String(values[field.key] ?? "").trim() !== "") group.values[field.key] = values[field.key];
    }
    const pick = (prefix) =>
      Object.fromEntries(
        Object.entries(values)
          .filter(([column, value]) => column.startsWith(prefix) && String(value ?? "").trim() !== "")
          .map(([column, value]) => [column.slice(prefix.length), value])
      );
    const unit = pick("unit.");
    if (Object.keys(unit).length) group.unitTypes.push(unit);
    const plan = pick("plan.");
    if (Object.keys(plan).length && !group.paymentPlans.some((existing) => existing.values.name === plan.name)) {
      group.paymentPlans.push({ values: plan, milestones: [] });
    }
  });
  return {
    version: FORMAT_VERSIONS[category],
    items: [...groups.values()].map((group) => developmentItem(format, group, group.row)),
    warnings,
  };
}

/* -------------------------------------------------------------------------- */

/** The file's bytes, after the empty-file and size checks. A pushed body arrives as a Buffer. */
function fileBytes(content) {
  const bytes = toBytes(content);
  if (!bytes.length) throw fileError("The feed file is empty.");
  if (bytes.length > MAX_FEED_BYTES) throw fileError(`A feed file can be at most ${MAX_FEED_BYTES / 1024 / 1024} MB.`);
  return bytes;
}

/** Whether the first thing in the file, past a byte-order mark and white space, is a "<". */
function startsWithTag(bytes) {
  let i = bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf ? 3 : 0;
  while (i < bytes.length && (bytes[i] === 0x20 || bytes[i] === 0x09 || bytes[i] === 0x0a || bytes[i] === 0x0d)) i++;
  return bytes[i] === 0x3c;
}

/** Parses one feed file. Throws a 422 `FEED_INVALID` for a file that cannot be read at all. */
export function parseFeed({ category, format, content }) {
  const spec = feedFormat(category);
  if (!spec) throw fileError(`There is no feed format for "${category}".`, { category: "Unknown category." });
  const bytes = fileBytes(content);
  const kind = format || (startsWithTag(bytes) ? "xml" : "csv");
  // XML is read straight from the bytes, one entry at a time (xmlChunks.js); CSV as text.
  const result = kind === "xml" ? readXml(category, spec, bytes) : readCsv(category, spec, bytes.toString("utf8"));
  if (result.version !== FORMAT_VERSIONS[category]) {
    throw fileError(`Version ${result.version} of the ${category} format is not supported; use version ${FORMAT_VERSIONS[category]}.`, {
      version: `Use version ${FORMAT_VERSIONS[category]}.`,
    });
  }
  return { category, entity: spec.entity, format: kind, source: result.source ?? "livfinder", ...result, items: markDuplicates(result.items) };
}

/**
 * Parses a pushed XML file into one result per category: a `<category name="…">` section for each
 * in the file, or the single category of a one-category file or a Property Finder or Bayut export.
 */
export function parsePushedXml(content) {
  const bytes = fileBytes(content);
  const root = wellFormedRoot(bytes);
  if (entityDeclarations(bytes, root.start)) return parsePushedXmlWhole(bytes.toString("utf8"));
  if (root.name !== "livfinder-feed") return [parseFeed({ category: "real-estate", format: "xml", content: bytes })];
  const rootAttributes = startTagAttributes(bytes, root);
  if (rootAttributes["@_category"]) return [parseFeed({ category: rootAttributes["@_category"], format: "xml", content: bytes })];

  const sections = root.selfClosing ? [] : [...childElements(bytes, root.openEnd, root.contentEnd)].filter((element) => element.name === "category");
  if (!sections.length) throw fileError('The file has no <category name="…"> sections.');
  const seen = new Set();
  let total = 0;
  const results = sections.map((section) => {
    const attributes = startTagAttributes(bytes, section);
    const category = attributes["@_name"];
    const spec = feedFormat(category);
    if (!spec) throw fileError(`There is no feed format for "${category ?? ""}".`, { category: "Unknown category." });
    if (seen.has(category)) throw fileError(`The ${category} section appears twice. Put all its entries in one section.`);
    seen.add(category);
    const result = readEntries(category, spec, { attributes, nodes: entryNodes(bytes, section, spec.entity) });
    if (result.version !== FORMAT_VERSIONS[category]) {
      throw fileError(`Version ${result.version} of the ${category} format is not supported; use version ${FORMAT_VERSIONS[category]}.`, {
        version: `Use version ${FORMAT_VERSIONS[category]}.`,
      });
    }
    total += result.items.length;
    if (total > MAX_FEED_ROWS) throw fileError(`A feed file can hold at most ${MAX_FEED_ROWS} entries.`);
    return { category, entity: spec.entity, format: "xml", source: "livfinder", ...result, items: markDuplicates(result.items) };
  });
  return results;
}

/** The whole-file version of parsePushedXml, for a file whose DOCTYPE declares entities (see readXmlWhole). */
function parsePushedXmlWhole(text) {
  let doc;
  try {
    doc = xml.parse(text, true);
  } catch (error) {
    throw fileError("The XML file could not be read.", { file: String(error.message || error).slice(0, 300) });
  }
  const root = doc?.["livfinder-feed"];
  if (!root || typeof root !== "object") return [parseFeed({ category: "real-estate", format: "xml", content: text })];
  if (root["@_category"]) return [parseFeed({ category: root["@_category"], format: "xml", content: text })];

  const sections = root.category || [];
  if (!sections.length) throw fileError('The file has no <category name="…"> sections.');
  const seen = new Set();
  const results = sections.map((section) => {
    const category = section["@_name"];
    const spec = feedFormat(category);
    if (!spec) throw fileError(`There is no feed format for "${category ?? ""}".`, { category: "Unknown category." });
    if (seen.has(category)) throw fileError(`The ${category} section appears twice. Put all its entries in one section.`);
    seen.add(category);
    const result = readEntries(category, spec, { attributes: section, nodes: section[spec.entity] || [] });
    if (result.version !== FORMAT_VERSIONS[category]) {
      throw fileError(`Version ${result.version} of the ${category} format is not supported; use version ${FORMAT_VERSIONS[category]}.`, {
        version: `Use version ${FORMAT_VERSIONS[category]}.`,
      });
    }
    return { category, entity: spec.entity, format: "xml", source: "livfinder", ...result, items: markDuplicates(result.items) };
  });
  if (results.reduce((total, result) => total + result.items.length, 0) > MAX_FEED_ROWS) {
    throw fileError(`A feed file can hold at most ${MAX_FEED_ROWS} entries.`);
  }
  return results;
}
