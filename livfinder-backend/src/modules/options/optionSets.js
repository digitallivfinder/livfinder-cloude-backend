import { query } from "../../db/query.js";

/**
 * Every option list the table header filters offer, in one place, served by
 * `GET /v1/admin/options?sets=…` and `GET /v1/portal/options?sets=…`.
 *
 * The frontend holds no option lists of its own. Each set is read from where the value is
 * defined, so a value added there appears in the filters without touching the frontend:
 *
 * - `enumSet`: a MySQL ENUM column's definition (information_schema). A migration that adds a
 *   status adds it to the filter.
 * - `tableSet`: a reference table (categories, plans, roles, lead sources, report reasons…).
 * - `fixedSet`: a grouping the API itself defines next to the SQL that applies it (the admin
 *   listing tabs, the lead screen statuses…), passed in by the module that owns the mapping.
 *
 * No set is ever derived from the records a table lists (which values happen to be in use):
 * an option list is the complete vocabulary, whether or not anything carries a value yet.
 */

const CACHE_MS = 5 * 60 * 1000;
const cache = new Map();

async function cached(key, load) {
  const hit = cache.get(key);
  if (hit && hit.expires > Date.now()) return hit.value;
  const value = await load();
  cache.set(key, { value, expires: Date.now() + CACHE_MS });
  return value;
}

/** Forget cached sets (tests, or after a migration in a long-running process). */
export function clearOptionSetCache() {
  cache.clear();
}

/** "viewing_scheduled" → "Viewing scheduled". */
export function sentenceLabel(value) {
  const text = String(value ?? "").replace(/[._-]+/g, " ").trim();
  return text ? text[0].toUpperCase() + text.slice(1) : text;
}

const IDENTIFIER = /^[a-z_][a-z0-9_]*$/;

/** The values of an ENUM column, in their declared order. */
export async function enumValues(table, column) {
  if (!IDENTIFIER.test(table) || !IDENTIFIER.test(column)) throw new TypeError(`unsafe identifier: ${table}.${column}`);
  return cached(`enum:${table}.${column}`, async () => {
    const [row] = await query(
      `SELECT column_type AS type FROM information_schema.columns
        WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?`,
      [table, column]
    );
    if (!row || !String(row.type).startsWith("enum(")) throw new Error(`${table}.${column} is not an ENUM column`);
    return [...String(row.type).matchAll(/'((?:[^']|'')*)'/g)].map((match) => match[1].replace(/''/g, "'"));
  });
}

/** An ENUM column as options. `labels` overrides a value's label; `exclude` hides values a screen never shows. */
export function enumSet(table, column, { labels = {}, exclude = [] } = {}) {
  return async () =>
    (await enumValues(table, column))
      .filter((value) => !exclude.includes(value))
      .map((value) => ({ value, label: labels[value] ?? sentenceLabel(value) }));
}

/** A reference table as options; `sql` selects `value`, `label` and optionally `description` / `image`. */
export function tableSet(sql, params = []) {
  return async () =>
    (await query(sql, params)).map((row) => ({
      value: String(row.value),
      label: row.label ?? sentenceLabel(row.value),
      ...(row.description ? { description: row.description } : {}),
      ...(row.image ? { image: row.image } : {}),
    }));
}

/** A vocabulary the API defines with the mapping that applies it: `[value, label]` pairs or values. */
export function fixedSet(entries) {
  const options = entries.map((entry) => (Array.isArray(entry) ? { value: entry[0], label: entry[1] } : { value: entry, label: sentenceLabel(entry) }));
  return async () => options;
}

const REGISTRY = new Map();

/**
 * Registers sets. `portal: true` also serves a set to the client portal; everything else is
 * admin-only (a portal account never sees, say, the list of platform roles). A set's loader may
 * take a parameter, asked for as "name:param" (e.g. "lead.funnelStep:jets").
 */
export function registerOptionSets(sets, { portal = false } = {}) {
  for (const [name, load] of Object.entries(sets)) REGISTRY.set(name, { load, portal });
}

export const optionSetNames = (audience) => [...REGISTRY.entries()].filter(([, set]) => audience === "admin" || set.portal).map(([name]) => name);

const splitName = (name) => {
  const at = name.indexOf(":");
  return at < 0 ? [name, ""] : [name.slice(0, at), name.slice(at + 1)];
};

/** The asked-for sets, by name. Unknown names (or admin-only ones asked by the portal) are left out. */
export async function loadOptionSets(names, audience) {
  const wanted = [...new Set(names)].filter((name) => {
    const set = REGISTRY.get(splitName(name)[0]);
    return set && (audience === "admin" || set.portal) && /^[a-z0-9._:-]{1,80}$/i.test(name);
  });
  const loaded = await Promise.all(
    wanted.map((name) => {
      const [base, param] = splitName(name);
      return cached(`set:${name}`, () => REGISTRY.get(base).load(param));
    })
  );
  return Object.fromEntries(wanted.map((name, index) => [name, loaded[index]]));
}
