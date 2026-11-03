import { describe, expect, it } from "vitest";
import { hasPhoneLength, optionalPhone } from "../../src/utils/phone.js";

describe("phone length", () => {
  it.each([
    ["+6834001", "the shortest numbers in use (Niue)"],
    ["+97143334444", "a landline"],
    ["+971501234567", "a mobile or WhatsApp number"],
    ["+491761234567890", "the 15-digit maximum"],
    ["04 123 4567", "an older number with no country code"],
  ])("accepts %s, %s", (value) => {
    expect(hasPhoneLength(value)).toBe(true);
  });

  it.each(["+12345", "+4917612345678901", "sdf", ""])("refuses %j", (value) => {
    expect(hasPhoneLength(value)).toBe(false);
  });

  it("refuses letters and stores digits only", () => {
    expect(optionalPhone.safeParse("sdf1234567").success).toBe(false);
    expect(optionalPhone.safeParse("+971-50-abc-4567").success).toBe(false);
    expect(optionalPhone.parse("+971 50 123-4567")).toBe("+971501234567");
    expect(optionalPhone.parse("(04) 123 4567")).toBe("041234567");
  });

  it("leaves an optional field optional", () => {
    for (const value of ["", null, undefined, "+971501234567"]) expect(optionalPhone.safeParse(value).success).toBe(true);
    const refused = optionalPhone.safeParse("+123");
    expect(refused.success).toBe(false);
    expect(refused.error.issues[0].message).toContain("7 to 15");
  });
});
