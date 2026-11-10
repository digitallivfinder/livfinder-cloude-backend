/**
 * Table header filters for admin list endpoints: a declarative spec per table, turned into bound
 * SQL conditions. See `applyColumnFilters`.
 */
/** Ids from a location dropdown, matched at any tier of the row's location chain. */
export function locationAtAnyTier(key, alias, tiers = ["country_id", "state_id", "city_id", "community_id", "sub_community_id"]) {
  return {
    type: "custom", key,
    build: (value) => {
      const ids = csvList(value).filter((id) => /^\d+$/.test(id));
      if (!ids.length) return { sql: "1 = 0" };
      const marks = ids.map(() => "?").join(", ");
      return { sql: tiers.map((tier) => `${alias}.${tier} IN (${marks})`).join(" OR "), params: tiers.flatMap(() => ids) };
    },
  };
}

/** Agent dropdown public ids (plus "none" for rows with no agent) against an agent id column. */
export function agentIn(key, column) {
  return {
    type: "custom", key,
    build: (value) => {
      const values = csvList(value);
      const ids = values.filter((id) => id !== "none");
      const parts = [];
      if (values.includes("none")) parts.push(`${column} IS NULL`);
      if (ids.length) parts.push(`${column} IN (SELECT fa.id FROM agents fa WHERE fa.public_id IN (${ids.map(() => "?").join(", ")}))`);
      return parts.length ? { sql: parts.join(" OR "), params: ids } : { sql: "1 = 0" };
    },
  };
}

/** A comma-separated query value as a clean, de-duplicated list (column filters send several). */
/**
 * A "prefix + number" header filter (Lead "LD-", Report "RPT-"…). The box takes the number, so the
 * number is compared rather than the text: "786" finds LD-786 and LD-00786 but not LD-7860, and a
 * pasted "LD-786" works too. `partial` matches any part of the number instead, for long ones such
 * as LF-INV-2026000299. `column` may be an expression, e.g. a reference built from an id.
 */
export function referenceNumber(key, column, prefix, { partial = false } = {}) {
  const strip = new RegExp(`^\\s*${prefix.replace(/[-]/g, "\\-")}?`, "i");
  return {
    type: "custom", key,
    build: (value) => {
      const digits = String(value).replace(strip, "").trim();
      if (!/^\d{1,12}$/.test(digits)) return { sql: "1 = 0" };
      if (partial) return { sql: `${column} LIKE ?`, params: [`${prefix}%${digits}%`] };
      return { sql: `(${column} LIKE ? AND CAST(SUBSTRING(${column}, ?) AS UNSIGNED) = ?)`, params: [`${prefix}%`, prefix.length + 1, Number(digits)] };
    },
  };
}

export const csvList = (value, max = 60) =>
  [...new Set(String(value ?? "").split(",").map((part) => part.trim()).filter(Boolean))].slice(0, max);

const WHOLE = /^-?\d{1,12}$/;
const DECIMAL = /^-?\d{1,12}(\.\d{1,4})?$/;
const DAY = /^\d{4}-\d{2}-\d{2}$/;
const placeholders = (list) => list.map(() => "?").join(", ");

/**
 * Adds the admin table header filters to a list query. `spec` names every filter a table offers,
 * the query keys it reads and the SQL it adds — only keys named here ever reach SQL, and every
 * value is bound as a parameter. Conditions are pushed onto `conditions`/`params` in place.
 *
 *   { type: "text",  key, columns: ["o.name", …] }           any column contains the text
 *   { type: "in",    key, column, cases?, map? }               "a,b,c": column IN (…)
 *        cases: { value: "raw SQL" } for values that are derived states rather than column values;
 *        map(value) translates an offered value (a slug → an id, or → several stored values);
 *        returning null drops it.
 *   { type: "range", keys: [min, max], column, decimal? }      inclusive number range
 *   { type: "date",  keys: [from, to], column }                inclusive YYYY-MM-DD range
 *   { type: "bool",  key, when: { value: "raw SQL", … } }      one of a fixed set of states
 *   { type: "custom", key, build: (value) => ({ sql, params }) | null }
 */
export function applyColumnFilters(spec, input = {}, conditions = [], params = []) {
  for (const filter of spec) {
    switch (filter.type) {
      case "text": {
        const value = String(input[filter.key] ?? "").trim().slice(0, 200);
        if (!value) break;
        conditions.push(`(${filter.columns.map((column) => `${column} LIKE ?`).join(" OR ")})`);
        params.push(...filter.columns.map(() => `%${value}%`));
        break;
      }
      case "in": {
        const values = csvList(input[filter.key]).filter((value) => value !== "all");
        if (!values.length) break;
        const parts = [];
        const cases = filter.cases ?? {};
        values.filter((value) => cases[value]).forEach((value) => parts.push(cases[value]));
        // `map` may turn one offered value into several stored ones ("sold" → sold, rented).
        const plain = [...new Set(values.filter((value) => !cases[value]).flatMap((value) => {
          const mapped = filter.map ? filter.map(value) : value;
          return Array.isArray(mapped) ? mapped : [mapped];
        }))].filter((value) => value !== null && value !== undefined && value !== "");
        if (plain.length && filter.column) {
          parts.push(`${filter.column} IN (${placeholders(plain)})`);
          params.push(...plain);
        }
        // Every value was unrecognised: match nothing rather than silently ignoring the filter.
        conditions.push(parts.length ? `(${parts.join(" OR ")})` : "1 = 0");
        break;
      }
      case "range":
      case "date": {
        const valid = filter.type === "date" ? DAY : filter.decimal ? DECIMAL : WHOLE;
        const [low, high] = filter.keys.map((key) => {
          const value = String(input[key] ?? "").trim();
          return valid.test(value) ? value : null;
        });
        if (low !== null) {
          conditions.push(`${filter.column} >= ?`);
          params.push(filter.type === "date" ? low : Number(low));
        }
        if (high !== null) {
          // A date's upper bound covers that whole day.
          conditions.push(filter.type === "date" ? `${filter.column} < DATE_ADD(?, INTERVAL 1 DAY)` : `${filter.column} <= ?`);
          params.push(filter.type === "date" ? high : Number(high));
        }
        break;
      }
      case "bool": {
        const sql = filter.when[String(input[filter.key] ?? "")];
        if (sql) conditions.push(`(${sql})`);
        break;
      }
      case "custom": {
        const value = input[filter.key];
        if (value === undefined || value === null || value === "") break;
        const built = filter.build(value);
        if (built?.sql) {
          conditions.push(`(${built.sql})`);
          params.push(...(built.params ?? []));
        }
        break;
      }
      default:
        throw new Error(`Unknown column filter type: ${filter.type}`);
    }
  }
  return { conditions, params };
}
