import { afterAll, describe, expect, it } from "vitest";
import { query } from "../../src/db/query.js";
import { closePool } from "../../src/db/pool.js";
import { DETAIL_SCHEMAS } from "../../src/modules/listings/listings.schemas.js";

/**
 * The per-category detail Zod schemas must agree with the ENUM columns they are
 * written into. A value that passes Zod and is then rejected by the column is the
 * worst kind of failure — the form looked like it worked. Migration 0042
 * reconciled the two; this keeps them reconciled.
 */

/** Pull the members of a Zod enum for `field` out of a detail schema shape. */
function zodEnumMembers(schema, field) {
  let node = schema.shape?.[field];
  for (let i = 0; i < 6 && node; i += 1) {
    if (Array.isArray(node.options)) return node.options;
    node = typeof node.unwrap === "function" ? node.unwrap() : null;
  }
  return null;
}

async function columnEnumMembers(table, column) {
  const rows = await query(
    "SELECT COLUMN_TYPE FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?",
    [table, column]
  );
  if (!rows.length) return null;
  const match = String(rows[0].COLUMN_TYPE).match(/^enum\((.*)\)$/i);
  if (!match) return null;
  return [...match[1].matchAll(/'([^']+)'/g)].map((entry) => entry[1]);
}

const CASES = [
  ["real-estate", "listing_real_estate", "completionStatus", "completion_status"],
  ["real-estate", "listing_real_estate", "furnishing", "furnishing"],
  ["real-estate", "listing_real_estate", "ownershipType", "ownership_type"],
  ["real-estate", "listing_real_estate", "rentPeriod", "rent_period"],
  ["cars", "listing_vehicle", "transmission", "transmission"],
  ["cars", "listing_vehicle", "fuelType", "fuel_type"],
  ["cars", "listing_vehicle", "drivetrain", "drivetrain"],
  ["cars", "listing_vehicle", "conditionType", "condition_type"],
  ["cars", "listing_vehicle", "serviceHistory", "service_history"],
  ["cars", "listing_vehicle", "steeringSide", "steering_side"],
  ["yachts", "listing_marine", "vesselType", "vessel_type"],
  ["yachts", "listing_marine", "hullMaterial", "hull_material"],
  ["jets", "listing_aviation", "aircraftType", "aircraft_type"],
  ["watches", "listing_timepiece", "movementType", "movement_type"],
  ["watches", "listing_timepiece", "conditionGrade", "condition_grade"],
  ["watches", "listing_timepiece", "gender", "gender"],
];

afterAll(async () => {
  await closePool();
});

describe("detail schema enums match their ENUM columns", () => {
  it.each(CASES)("%s.%s == %s.%s", async (category, table, field, column) => {
    const schema = DETAIL_SCHEMAS[category];
    expect(schema, `no detail schema for ${category}`).toBeTruthy();

    const zodMembers = zodEnumMembers(schema, field);
    expect(zodMembers, `${category}.${field} is not a Zod enum`).toBeTruthy();

    const dbMembers = await columnEnumMembers(table, column);
    expect(dbMembers, `${table}.${column} is not an ENUM column`).toBeTruthy();

    expect([...zodMembers].sort()).toEqual([...dbMembers].sort());
  });

  it("jets and helicopters share the aviation detail schema", () => {
    expect(DETAIL_SCHEMAS.helicopters).toBe(DETAIL_SCHEMAS.jets);
  });
});
