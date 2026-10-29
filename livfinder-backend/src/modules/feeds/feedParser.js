import { parse as parseCsv } from "csv-parse/sync";
import { XMLParser } from "fast-xml-parser";
import { AppError } from "../../utils/errors.js";
import { DETAIL_SCHEMAS } from "../listings/listings.schemas.js";
import { parseListingRecord } from "../imports/listingImport.service.js";
import { FORMAT_VERSIONS, LIST_SEPARATOR, feedFormat } from "./feedFormats.js";
import { LIST_ITEM, csvColumns } from "./feedTemplates.js";
import { readForeignXml } from "./foreignFormats.js";

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

export const MAX_FEED_BYTES = 50 * 1024 * 1024;
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
  const { out, errors } = readFields(format.fields, values);
  const externalId = typeof out.externalId === "string" ? out.externalId : null;
  if (Object.keys(errors).length) return { row, externalId, record: null, errors };
  const record = { ...out, category };
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
  if (!out.location?.country) errors.country ??= "Give the country.";
  if (!out.location?.city) errors.city ??= "Give the city.";
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

const ARRAY_PATHS = new Set([
  "livfinder-feed.listing",
  "livfinder-feed.development",
  "livfinder-feed.development.unitTypes.unitType",
  "livfinder-feed.development.paymentPlans.paymentPlan",
  "livfinder-feed.development.paymentPlans.paymentPlan.milestones.milestone",
]);

const xml = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: "@_",
  parseTagValue: false,
  parseAttributeValue: false,
  trimValues: true,
  processEntities: true,
  isArray: (name, jpath) => ARRAY_PATHS.has(jpath) || Object.values(LIST_ITEM).includes(name),
});

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

function readXml(category, format, text) {
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
  const version = Number(root["@_version"] ?? FORMAT_VERSIONS[category]);
  const entity = format.entity;
  const nodes = root[entity] || [];
  if (nodes.length > MAX_FEED_ROWS) throw fileError(`A feed file can hold at most ${MAX_FEED_ROWS} entries.`);
  const warnings = new Set();
  const items = nodes.map((node, index) => {
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
  });
  return { version, items, warnings: [...warnings] };
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

/** Parses one feed file. Throws a 422 `FEED_INVALID` for a file that cannot be read at all. */
export function parseFeed({ category, format, content }) {
  const spec = feedFormat(category);
  if (!spec) throw fileError(`There is no feed format for "${category}".`, { category: "Unknown category." });
  const bytes = Buffer.isBuffer(content) ? content.length : Buffer.byteLength(String(content ?? ""));
  if (!bytes) throw fileError("The feed file is empty.");
  if (bytes > MAX_FEED_BYTES) throw fileError(`A feed file can be at most ${MAX_FEED_BYTES / 1024 / 1024} MB.`);
  const text = Buffer.isBuffer(content) ? content.toString("utf8") : String(content);
  const kind = format || (text.trimStart().startsWith("<") ? "xml" : "csv");
  const result = kind === "xml" ? readXml(category, spec, text) : readCsv(category, spec, text);
  if (result.version !== FORMAT_VERSIONS[category]) {
    throw fileError(`Version ${result.version} of the ${category} format is not supported; use version ${FORMAT_VERSIONS[category]}.`, {
      version: `Use version ${FORMAT_VERSIONS[category]}.`,
    });
  }
  return { category, entity: spec.entity, format: kind, source: result.source ?? "livfinder", ...result, items: markDuplicates(result.items) };
}
