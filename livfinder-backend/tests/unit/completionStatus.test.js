import { describe, expect, it } from "vitest";
import { alignCompletionStatus } from "../../src/modules/listings/completionStatus.js";

describe("shell and core is commercial only", () => {
  it("is kept for an office, a shop or a whole building", () => {
    for (const categorySlug of ["offices", "retail", "buildings"]) {
      const payload = { categorySlug, detail: { completionStatus: "shell_and_core" } };
      expect(alignCompletionStatus("real-estate", payload)).toBe(payload);
    }
  });

  it("is stored as ready for a residential type", () => {
    const out = alignCompletionStatus("real-estate", { categorySlug: "villas", detail: { completionStatus: "shell_and_core", bedrooms: 4 } });
    expect(out.detail).toEqual({ completionStatus: "ready", bedrooms: 4 });
  });

  it("uses the stored type when an edit does not resend it", () => {
    const edit = { detail: { completionStatus: "shell_and_core" } };
    expect(alignCompletionStatus("real-estate", edit, "offices")).toBe(edit);
    expect(alignCompletionStatus("real-estate", edit, "apartments").detail.completionStatus).toBe("ready");
  });

  it("leaves every other status and marketplace alone", () => {
    const offPlan = { categorySlug: "villas", detail: { completionStatus: "off_plan" } };
    expect(alignCompletionStatus("real-estate", offPlan)).toBe(offPlan);
    const car = { detail: { completionStatus: "shell_and_core" } };
    expect(alignCompletionStatus("cars", car)).toBe(car);
  });
});
