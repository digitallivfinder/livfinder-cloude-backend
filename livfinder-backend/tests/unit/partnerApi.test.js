import { describe, expect, it } from "vitest";
import express from "express";
import request from "supertest";
import { ipAllowed, normalizeIp, requireApiClient, scopesGrant } from "../../src/middleware/apiClient.js";
import { errorHandler } from "../../src/middleware/errors.js";
import { normalizeAllowedIps } from "../../src/modules/portal/organization.service.js";
import { mergeListingPatch, parseListingRecord, payloadHash } from "../../src/modules/imports/listingImport.service.js";
import { AppError } from "../../src/utils/errors.js";

const validRecord = {
  externalId: "PF-10293",
  category: "real-estate",
  purpose: "sale",
  title: "Five-bedroom villa on Palm Jumeirah",
  price: 32500000,
  currency: "aed",
  location: { country: "AE", city: "Dubai" },
  images: ["https://cdn.example.com/1.jpg"],
  detail: { bedrooms: 5 },
};

describe("API key IP allow-list", () => {
  it("allows any address when the list is empty", () => {
    expect(ipAllowed("203.0.113.9", [])).toBe(true);
    expect(ipAllowed("203.0.113.9", null)).toBe(true);
  });

  it("matches exact addresses and CIDR ranges, including JSON stored as text", () => {
    expect(ipAllowed("203.0.113.9", ["203.0.113.9"])).toBe(true);
    expect(ipAllowed("203.0.113.77", ["203.0.113.0/24"])).toBe(true);
    expect(ipAllowed("198.51.100.1", '["203.0.113.0/24"]')).toBe(false);
    expect(ipAllowed("2001:db8::5", ["2001:db8::/32"])).toBe(true);
  });

  it("treats an IPv4-mapped IPv6 address as the IPv4 address", () => {
    expect(normalizeIp("::ffff:203.0.113.9")).toBe("203.0.113.9");
    expect(ipAllowed("::ffff:203.0.113.9", ["203.0.113.9"])).toBe(true);
  });

  it("refuses a caller with no readable address when a list is set", () => {
    expect(ipAllowed("", ["203.0.113.9"])).toBe(false);
  });

  it("validates what a company saves", () => {
    expect(normalizeAllowedIps(["203.0.113.9", " 203.0.113.0/24 ", "203.0.113.9", ""])).toEqual(["203.0.113.9", "203.0.113.0/24"]);
    expect(() => normalizeAllowedIps(["not-an-ip"])).toThrow(AppError);
    expect(() => normalizeAllowedIps(["10.0.0.0/33"])).toThrow(AppError);
    expect(() => normalizeAllowedIps(["10.0.0.0/8/1"])).toThrow(AppError);
  });
});

describe("API key scopes", () => {
  it("grants only what the key holds; write implies read", () => {
    expect(scopesGrant(["listings:read"], "listings:read")).toBe(true);
    expect(scopesGrant(["listings:read"], "listings:write")).toBe(false);
    expect(scopesGrant(["listings:write"], "listings:read")).toBe(true);
    expect(scopesGrant('["listings:write"]', "listings:write")).toBe(true);
    expect(scopesGrant([], "listings:read")).toBe(false);
  });
});

describe("requireApiClient without valid credentials", () => {
  const app = express();
  app.get("/probe", requireApiClient("listings:read"), (req, res) => res.json({ ok: true }));
  app.use(errorHandler);

  it("asks for credentials when none are sent", async () => {
    const response = await request(app).get("/probe");
    expect(response.status).toBe(401);
    expect(response.body.error.code).toBe("API_KEY_REQUIRED");
  });

  it("refuses a header that is not Basic client_id:secret, before any lookup", async () => {
    for (const header of ["Bearer abc", "Basic", `Basic ${Buffer.from("no-separator").toString("base64")}`]) {
      const response = await request(app).get("/probe").set("Authorization", header);
      expect(response.status).toBe(401);
      expect(response.body.error.code).toBe("API_KEY_INVALID");
    }
  });
});

describe("listing records", () => {
  it("accepts a valid record and normalises it", () => {
    const record = parseListingRecord(validRecord);
    expect(record.currency).toBe("AED");
    expect(record.externalId).toBe("PF-10293");
  });

  it("reports problems under the partner's own field names", () => {
    try {
      parseListingRecord({ ...validRecord, externalId: "has space", title: "ab", category: "boats", images: ["not a url"], colour: "red" });
      throw new Error("expected a validation error");
    } catch (error) {
      expect(error).toBeInstanceOf(AppError);
      expect(error.status).toBe(422);
      expect(error.fields.externalId).toMatch(/spaces/);
      expect(error.fields.title).toBeTruthy();
      expect(error.fields.category).toMatch(/real-estate/);
      expect(error.fields["images.0"]).toMatch(/URL/);
      expect(error.fields._).toMatch(/colour/);
    }
  });

  it("refuses unknown location keys rather than dropping them", () => {
    expect(() => parseListingRecord({ ...validRecord, location: { country: "AE", town: "Dubai" } })).toThrow(AppError);
  });

  it("hashes the same content the same way whatever the key order", () => {
    const reordered = Object.fromEntries(Object.entries(validRecord).reverse());
    expect(payloadHash(validRecord)).toBe(payloadHash(reordered));
    expect(payloadHash(validRecord)).not.toBe(payloadHash({ ...validRecord, price: 1 }));
    expect(payloadHash(validRecord)).toHaveLength(32);
  });
});

describe("mergeListingPatch", () => {
  const base = {
    ...validRecord,
    status: "pending_review",
    features: ["Pool", "Gym"],
    detail: { bedrooms: 5, bathrooms: 6, parking: 2 },
  };

  it("changes only the fields sent and keeps the rest", () => {
    const merged = mergeListingPatch(base, { price: 31000000 }, "PF-10293");
    expect(merged).toEqual({ ...base, price: 31000000 });
  });

  it("merges detail key by key, a null removing a key", () => {
    const merged = mergeListingPatch(base, { detail: { bathrooms: 7, parking: null } }, "PF-10293");
    expect(merged.detail).toEqual({ bedrooms: 5, bathrooms: 7 });
  });

  it("replaces location, images and features whole", () => {
    const merged = mergeListingPatch(
      base,
      { location: { id: "123" }, images: ["https://cdn.example.com/9.jpg"], features: ["Sea view"] },
      "PF-10293"
    );
    expect(merged.location).toEqual({ id: "123" });
    expect(merged.images).toEqual(["https://cdn.example.com/9.jpg"]);
    expect(merged.features).toEqual(["Sea view"]);
  });

  it("clears a top-level field sent as null", () => {
    const merged = mergeListingPatch({ ...base, subtitle: "Old" }, { subtitle: null }, "PF-10293");
    expect("subtitle" in merged).toBe(false);
  });

  it("always takes externalId from the URL, and does not change the base", () => {
    const copy = structuredClone(base);
    const merged = mergeListingPatch(base, { externalId: "OTHER", detail: { bedrooms: 4 } }, "PF-10293");
    expect(merged.externalId).toBe("PF-10293");
    expect(base).toEqual(copy);
  });

  it("gives the same hash as the equivalent full push, so a no-op patch is unchanged", () => {
    const merged = parseListingRecord(mergeListingPatch(parseListingRecord(base), { price: base.price }, "PF-10293"));
    expect(payloadHash(merged)).toBe(payloadHash(parseListingRecord(base)));
  });
});
