import { describe, expect, it } from "vitest";
import { OFF_PLAN_RENT_MESSAGE, alignCompletionStatus, assertOffPlanForSale } from "../../src/modules/listings/completionStatus.js";

describe("shell and core belongs to a commercial listing", () => {
  it("is kept for a commercial listing, whatever its type", () => {
    const detail = { completionStatus: "shell_and_core" };
    expect(alignCompletionStatus("real-estate", detail, "commercial")).toBe(detail);
  });

  it("is stored as ready for a residential listing", () => {
    expect(alignCompletionStatus("real-estate", { completionStatus: "shell_and_core", bedrooms: 4 }, "residential"))
      .toEqual({ completionStatus: "ready", bedrooms: 4 });
    expect(alignCompletionStatus("real-estate", { completionStatus: "shell_and_core" }, null).completionStatus).toBe("ready");
  });

  it("leaves every other status, an absent detail and other marketplaces alone", () => {
    const offPlan = { completionStatus: "off_plan" };
    expect(alignCompletionStatus("real-estate", offPlan, "residential")).toBe(offPlan);
    expect(alignCompletionStatus("real-estate", undefined, "residential")).toBeUndefined();
    const car = { completionStatus: "shell_and_core" };
    expect(alignCompletionStatus("cars", car, null)).toBe(car);
  });
});

describe("off plan is for sale only", () => {
  it("refuses an off-plan or under-construction rental", () => {
    for (const completionStatus of ["off_plan", "under_construction"]) {
      expect(() => assertOffPlanForSale("real-estate", { purpose: "rent", completionStatus })).toThrow(
        expect.objectContaining({ fields: { "detail.completionStatus": OFF_PLAN_RENT_MESSAGE } })
      );
    }
  });

  it("accepts an off-plan sale, a ready rental, and every other marketplace", () => {
    expect(() => assertOffPlanForSale("real-estate", { purpose: "sale", completionStatus: "off_plan" })).not.toThrow();
    expect(() => assertOffPlanForSale("real-estate", { purpose: "rent", completionStatus: "ready" })).not.toThrow();
    expect(() => assertOffPlanForSale("real-estate", { purpose: "rent", completionStatus: undefined })).not.toThrow();
    expect(() => assertOffPlanForSale("cars", { purpose: "rent", completionStatus: "off_plan" })).not.toThrow();
  });
});
