import { describe, expect, it } from "vitest";
import { applyColumnFilters, csvList } from "../../src/modules/admin/admin.shared.js";

const run = (spec, input) => applyColumnFilters(spec, input, [], []);

describe("csvList", () => {
  it("trims, drops blanks and de-duplicates", () => {
    expect(csvList(" a, b,,a ,c")).toEqual(["a", "b", "c"]);
    expect(csvList(undefined)).toEqual([]);
  });
});

describe("applyColumnFilters", () => {
  it("ignores keys that are absent or empty", () => {
    const spec = [{ type: "text", key: "name", columns: ["x.name"] }, { type: "in", key: "status", column: "x.status" }];
    expect(run(spec, {})).toEqual({ conditions: [], params: [] });
    expect(run(spec, { name: "  ", status: "" })).toEqual({ conditions: [], params: [] });
  });

  it("text matches any listed column, bound as parameters", () => {
    expect(run([{ type: "text", key: "q", columns: ["a.x", "a.y"] }], { q: " foo " })).toEqual({
      conditions: ["(a.x LIKE ? OR a.y LIKE ?)"],
      params: ["%foo%", "%foo%"],
    });
  });

  it("in combines plain values with derived cases and mapped values", () => {
    const spec = [{ type: "in", key: "s", column: "t.s", cases: { pending: "t.p = 1" }, map: (v) => (v === "bad" ? null : v.toUpperCase()) }];
    expect(run(spec, { s: "active,pending,bad,all" })).toEqual({ conditions: ["(t.p = 1 OR t.s IN (?))"], params: ["ACTIVE"] });
  });

  it("in lets map expand one value into several", () => {
    const spec = [{ type: "in", key: "s", column: "t.s", map: (v) => ({ sold: ["sold", "rented"], live: ["active"] })[v] ?? null }];
    expect(run(spec, { s: "sold,live" })).toEqual({ conditions: ["(t.s IN (?, ?, ?))"], params: ["sold", "rented", "active"] });
  });

  it("in with only unknown values matches nothing", () => {
    expect(run([{ type: "in", key: "s", column: "t.s", map: () => null }], { s: "x" }).conditions).toEqual(["1 = 0"]);
  });

  it("range accepts either bound and rejects junk", () => {
    const spec = [{ type: "range", keys: ["min", "max"], column: "t.n" }];
    expect(run(spec, { min: "2", max: "9" })).toEqual({ conditions: ["t.n >= ?", "t.n <= ?"], params: [2, 9] });
    expect(run(spec, { min: "abc", max: "1; DROP" })).toEqual({ conditions: [], params: [] });
    expect(run([{ ...spec[0], decimal: true }], { max: "12.5" }).params).toEqual([12.5]);
  });

  it("date upper bound is inclusive of the whole day", () => {
    expect(run([{ type: "date", keys: ["f", "t"], column: "x.at" }], { f: "2026-01-01", t: "2026-01-31" })).toEqual({
      conditions: ["x.at >= ?", "x.at < DATE_ADD(?, INTERVAL 1 DAY)"],
      params: ["2026-01-01", "2026-01-31"],
    });
    expect(run([{ type: "date", keys: ["f", "t"], column: "x.at" }], { f: "01/01/2026" }).conditions).toEqual([]);
  });

  it("bool only adds SQL for a known state", () => {
    const spec = [{ type: "bool", key: "api", when: { enabled: "a = 1", disabled: "a = 0" } }];
    expect(run(spec, { api: "enabled" }).conditions).toEqual(["(a = 1)"]);
    expect(run(spec, { api: "maybe" }).conditions).toEqual([]);
  });

  it("custom builds its own SQL", () => {
    const spec = [{ type: "custom", key: "k", build: (v) => ({ sql: "f(?)", params: [v] }) }];
    expect(run(spec, { k: "z" })).toEqual({ conditions: ["(f(?))"], params: ["z"] });
  });
});
