import { describe, expect, it } from "vitest";
import { safeReturnPath } from "../../src/utils/returnPath.js";

describe("safeReturnPath", () => {
  it("keeps a path on this site with its query and hash", () => {
    expect(safeReturnPath("/yachts/amels/mirabella?tab=specs#gallery")).toBe("/yachts/amels/mirabella?tab=specs#gallery");
  });

  it.each([
    "//evil.example",
    "/\\evil.example",
    "/\t/evil.example",
    "https://evil.example/",
    "javascript:alert(1)",
    "yachts",
    "",
    undefined,
    null,
    ["/yachts"],
  ])("refuses %j", (value) => {
    expect(safeReturnPath(value)).toBeNull();
  });
});
