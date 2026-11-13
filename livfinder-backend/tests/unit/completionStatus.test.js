import { describe, expect, it } from "vitest";
import { alignCompletionStatus } from "../../src/modules/listings/completionStatus.js";

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
