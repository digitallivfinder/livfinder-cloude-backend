import { describe, expect, it } from "vitest";
import {
  DEVELOPERS_MAY_LIST_REAL_ESTATE,
  applicationSellerType,
  assertApplicationCategory,
  sellerTypeAllowsCategory,
  sellerTypeFor,
} from "../../src/modules/accounts/sellerType.js";

/** Individual, Company or Developer (0079): only a Developer holds Real Estate Developments. */
describe("seller type", () => {
  it("is worked out from what the account is made of", () => {
    expect(sellerTypeFor({ accountTypeCode: "lister" })).toBe("individual");
    expect(sellerTypeFor({ accountTypeCode: "company", organizationKind: "agency" })).toBe("company");
    expect(sellerTypeFor({ accountTypeCode: "partner", organizationKind: "developer" })).toBe("developer");
    expect(sellerTypeFor({ accountTypeCode: "organization" })).toBe("company");
    expect(sellerTypeFor({ accountTypeCode: "personal" })).toBeNull();
  });

  it("lets only a Developer hold Real Estate Developments", () => {
    expect(sellerTypeAllowsCategory("developer", "real-estate-developments")).toBe(true);
    expect(sellerTypeAllowsCategory("developer", 7)).toBe(true);
    for (const type of ["company", "individual", null]) {
      expect(sellerTypeAllowsCategory(type, "real-estate-developments")).toBe(false);
    }
  });

  it("leaves every other category to the access grants", () => {
    expect(sellerTypeAllowsCategory("company", "real-estate")).toBe(true);
    expect(sellerTypeAllowsCategory("individual", "cars")).toBe(true);
    expect(sellerTypeAllowsCategory("developer", "real-estate")).toBe(DEVELOPERS_MAY_LIST_REAL_ESTATE);
  });

  it("reads an application as Individual, Company or Developer", () => {
    expect(applicationSellerType({ accountType: "personal" })).toBe("individual");
    expect(applicationSellerType({ accountType: "organization", organizationType: "brokerage" })).toBe("company");
    expect(applicationSellerType({ accountType: "organization", organizationType: "developer" })).toBe("developer");
  });

  it("refuses an application whose category its type cannot hold", () => {
    expect(() => assertApplicationCategory({ accountType: "personal", categoryId: "real-estate-developments" })).toThrow();
    expect(() => assertApplicationCategory({ accountType: "organization", organizationType: "agency", categoryId: "real-estate-developments" })).toThrow();
    expect(() => assertApplicationCategory({ accountType: "organization", organizationType: "developer", categoryId: "cars" })).toThrow();
    expect(() => assertApplicationCategory({ accountType: "organization", organizationType: "developer", categoryId: "real-estate-developments" })).not.toThrow();
    expect(() => assertApplicationCategory({ accountType: "organization", organizationType: "agency", categoryId: "real-estate" })).not.toThrow();
  });
});
