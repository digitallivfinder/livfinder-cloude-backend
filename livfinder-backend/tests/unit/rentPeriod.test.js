import { describe, expect, it } from "vitest";
import { alignRentPeriod } from "../../src/modules/listings/rentPeriod.js";

describe("a rental's rent period and price period are one value", () => {
  it("lets the form's Rent period set the price period", () => {
    const out = alignRentPeriod("real-estate", { purpose: "rent", pricePeriod: "total", detail: { rentPeriod: "monthly" } });
    expect(out.pricePeriod).toBe("month");
    expect(out.detail.rentPeriod).toBe("monthly");
  });

  it("wins over a conflicting price period", () => {
    const out = alignRentPeriod("real-estate", { purpose: "rent", pricePeriod: "month", detail: { rentPeriod: "yearly" } });
    expect(out.pricePeriod).toBe("year");
  });

  it("fills the Rent period from a price period sent alone (API, imports)", () => {
    const out = alignRentPeriod("real-estate", { purpose: "rent", pricePeriod: "week" });
    expect(out.detail).toEqual({ rentPeriod: "weekly" });
  });

  it("uses the stored purpose when an edit does not resend it", () => {
    expect(alignRentPeriod("real-estate", { detail: { rentPeriod: "daily" } }, "rent").pricePeriod).toBe("day");
    expect(alignRentPeriod("real-estate", { detail: { rentPeriod: "daily" } }, "sale").pricePeriod).toBeUndefined();
  });

  it("leaves sales, other marketplaces and unrelated periods alone", () => {
    const sale = { purpose: "sale", pricePeriod: "total", detail: { rentPeriod: "monthly" } };
    expect(alignRentPeriod("real-estate", sale)).toBe(sale);
    const car = { purpose: "rent", pricePeriod: "day" };
    expect(alignRentPeriod("cars", car)).toBe(car);
    const hourly = { purpose: "rent", pricePeriod: "hour" };
    expect(alignRentPeriod("real-estate", hourly)).toBe(hourly);
  });
});
