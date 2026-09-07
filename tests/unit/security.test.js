import { describe, expect, it, vi } from "vitest";
import crypto from "node:crypto";
import { hashPassword, verifyPassword, passwordPolicyError } from "../../src/modules/auth/passwords.js";
import { encryptSecret, decryptSecret, secretStatus, isEncrypted } from "../../src/utils/secrets.js";
import { scrub } from "../../src/modules/system/audit.service.js";
import { AppError } from "../../src/utils/errors.js";
import { isOriginAllowed } from "../../src/middleware/security.js";
import { rewriteLegacyMediaUrls } from "../../src/middleware/legacyMedia.js";
import { renderPlaceholder } from "../../src/modules/media/placeholder.js";
import { inClause } from "../../src/db/query.js";
import { toAdminPermissions, adminPermissionUniverse } from "../../src/modules/auth/adminPermissions.js";
import { hasPlatformPermission, hasAnyPlatformPermission } from "../../src/modules/auth/rbac.js";
import { buildCanonicalPath, splitCanonicalPath } from "../../src/utils/canonicalPath.js";
import { resolveCategory, categoryByRootId } from "../../src/utils/categories.js";
import { slugify } from "../../src/utils/slug.js";
import { ulid, sha256Hex } from "../../src/utils/ids.js";

describe("passwords", () => {
  it("hashes with Argon2id and verifies", async () => {
    const hash = await hashPassword("Correct horse 42");
    expect(hash.startsWith("$argon2id$")).toBe(true);
    expect((await verifyPassword(hash, "Correct horse 42")).valid).toBe(true);
    expect((await verifyPassword(hash, "wrong")).valid).toBe(false);
  });

  it("never stores the plaintext", async () => {
    const hash = await hashPassword("Sup3rsecret!");
    expect(hash).not.toContain("Sup3rsecret!");
  });

  it("produces a different hash for the same password", async () => {
    const [a, b] = await Promise.all([hashPassword("Same value 11"), hashPassword("Same value 11")]);
    expect(a).not.toBe(b);
  });

  it("accepts a legacy bcrypt hash and asks for a rehash", async () => {
    const bcrypt = await import("bcryptjs");
    const legacy = await bcrypt.default.hash("Legacy pass 12", 4);
    const result = await verifyPassword(legacy.replace("$2b$", "$2y$"), "Legacy pass 12");
    expect(result.valid).toBe(true);
    expect(result.needsRehash).toBe(true);
  });

  it("rejects a malformed stored hash rather than throwing", async () => {
    expect((await verifyPassword("not-a-hash", "anything")).valid).toBe(false);
    expect((await verifyPassword(null, "anything")).valid).toBe(false);
  });

  it("enforces the password policy", () => {
    expect(passwordPolicyError("short1")).toMatch(/at least 10/);
    expect(passwordPolicyError("passwordpassword")).toMatch(/letter and one number/);
    expect(passwordPolicyError("password1")).toMatch(/at least 10/);
    expect(passwordPolicyError("livfinder123", { email: "livfinder@example.test" })).toMatch(/must not contain/);
    expect(passwordPolicyError("Reasonable42")).toBeNull();
  });
});

describe("secret storage", () => {
  it("round-trips a value and marks it encrypted", () => {
    const stored = encryptSecret("sk_live_abcd1234");
    expect(isEncrypted(stored)).toBe(true);
    expect(stored).not.toContain("sk_live_abcd1234");
    expect(decryptSecret(stored)).toBe("sk_live_abcd1234");
  });

  it("produces different ciphertext each time", () => {
    expect(encryptSecret("same")).not.toBe(encryptSecret("same"));
  });

  it("refuses to decrypt a tampered ciphertext", () => {
    const stored = encryptSecret("sk_live_abcd1234");
    const tampered = `${stored.slice(0, -4)}AAAA`;
    expect(decryptSecret(tampered)).toBeNull();
  });

  it("reports only presence and a short hint", () => {
    const status = secretStatus(encryptSecret("sk_live_abcd1234"));
    expect(status.configured).toBe(true);
    expect(status.hint).toBe("••••1234");
    expect(JSON.stringify(status)).not.toContain("sk_live");
    expect(secretStatus(null)).toEqual({ configured: false, hint: null });
  });
});

describe("audit scrubbing", () => {
  it("redacts credentials at any depth", () => {
    const scrubbed = scrub({
      email: "a@b.test",
      password: "hunter2",
      nested: { token: "abc", apiKey: "k", keep: 1 },
    });
    expect(scrubbed.email).toBe("a@b.test");
    expect(scrubbed.password).toBe("[redacted]");
    expect(scrubbed.nested.token).toBe("[redacted]");
    expect(scrubbed.nested.apiKey).toBe("[redacted]");
    expect(scrubbed.nested.keep).toBe(1);
  });

  it("caps array size and recursion depth", () => {
    expect(scrub(Array.from({ length: 200 }, (_, index) => index))).toHaveLength(50);
    const deep = { a: { b: { c: { d: { e: { password: "x" } } } } } };
    expect(() => scrub(deep)).not.toThrow();
  });
});

describe("errors", () => {
  it("keeps a 5xx message off the wire and a 4xx on it", () => {
    const internal = AppError.internal("stack details");
    expect(internal.expose).toBe(false);
    expect(internal.status).toBe(500);
    const validation = AppError.validation("Some information is invalid.", { email: "bad" });
    expect(validation.status).toBe(422);
    expect(validation.fields).toEqual({ email: "bad" });
  });
});

describe("query helpers", () => {
  it("builds a parameterised IN clause and dedupes", () => {
    expect(inClause([1, 2, 2, 3])).toEqual({ sql: "(?, ?, ?)", params: [1, 2, 3] });
  });

  it("returns null for an empty list rather than emitting IN ()", () => {
    expect(inClause([])).toBeNull();
    expect(inClause([null, undefined])).toBeNull();
  });
});

describe("permissions", () => {
  it("treats super_admin as holding everything", () => {
    const access = { roles: ["super_admin"], permissions: new Set(), isSuperAdmin: true };
    expect(hasPlatformPermission(access, "anything.at.all")).toBe(true);
  });

  it("checks a specific permission otherwise", () => {
    const access = { roles: ["moderator"], permissions: new Set(["listings.moderate"]), isSuperAdmin: false };
    expect(hasPlatformPermission(access, "listings.moderate")).toBe(true);
    expect(hasPlatformPermission(access, "finance.refund")).toBe(false);
    expect(hasAnyPlatformPermission(access, ["finance.refund", "listings.moderate"])).toBe(true);
  });

  it("hands the frontend exactly the codes the server enforces, and nothing else", () => {
    // There is one vocabulary now. This used to expand a coarse code into per-category ids such
    // as `listings.real-estate.view`, which made the Role Access matrix appear to control each
    // category while the server only ever checked `listings.edit`. The category is a scope now,
    // not part of the key — so an expansion here would be reintroducing the same lie.
    const mapped = toAdminPermissions(["listings.view", "listings.moderate"]);
    expect(mapped).toEqual(["listings.moderate", "listings.view"]);
    expect(mapped.some((code) => code.includes(".real-estate."))).toBe(false);
    expect(mapped).not.toContain("finance.refund");
  });

  it("gives a super admin the whole universe once it is loaded", async () => {
    const { loadPermissionUniverse } = await import("../../src/modules/auth/adminPermissions.js");
    const universe = await loadPermissionUniverse();
    expect(universe.length).toBeGreaterThan(80);
    expect(toAdminPermissions([], { isSuperAdmin: true })).toEqual(universe);
  });
});

describe("canonical paths", () => {
  it("builds the real-estate hierarchy and stops at the first gap", () => {
    expect(
      buildCanonicalPath({
        rootCategoryId: 1,
        slug: "a-villa-1",
        location: { country: "united-arab-emirates", state: "dubai", city: "dubai", community: "palm-jumeirah", subCommunity: "frond-n" },
      })
    ).toBe("/real-estate/united-arab-emirates/dubai/dubai/palm-jumeirah/frond-n/a-villa-1");

    expect(
      buildCanonicalPath({ rootCategoryId: 1, slug: "a-villa-2", location: { country: "monaco" } })
    ).toBe("/real-estate/monaco/a-villa-2");
  });

  it("builds make/model/year for vehicles and brand/collection for watches", () => {
    expect(
      buildCanonicalPath({ rootCategoryId: 2, slug: "db12-9", brandSlug: "aston-martin", modelSlug: "db12", year: 2024 })
    ).toBe("/cars/aston-martin/db12/2024/db12-9");
    expect(
      buildCanonicalPath({ rootCategoryId: 6, slug: "daytona-3", brandSlug: "rolex", modelSlug: "daytona", year: 2023 })
    ).toBe("/watches/rolex/daytona/daytona-3");
  });

  it("omits a model with no make, and a year with no model", () => {
    expect(buildCanonicalPath({ rootCategoryId: 3, slug: "x-1", modelSlug: "55m", year: 2019 })).toBe("/yachts/x-1");
    expect(buildCanonicalPath({ rootCategoryId: 3, slug: "x-2", brandSlug: "benetti", year: 2019 })).toBe("/yachts/benetti/x-2");
  });

  it("splits a path back to its category", () => {
    expect(splitCanonicalPath("/cars/aston-martin/db12").definition.listingType).toBe("cars");
    expect(splitCanonicalPath("/nonsense/x")).toBeNull();
  });
});

describe("category mapping", () => {
  it("resolves every alias the three vocabularies use", () => {
    for (const alias of ["real-estate", "realEstate", "property", "properties"]) {
      expect(resolveCategory(alias).rootId).toBe(1);
    }
    expect(resolveCategory("cars").frontendId).toBe("car");
    expect(resolveCategory("helpcopters").listingType).toBe("helicopters");
    expect(resolveCategory("not-a-category")).toBeNull();
    expect(categoryByRootId(6).listingType).toBe("watches");
  });
});

describe("ids and slugs", () => {
  it("makes 26-character Crockford ids that sort by time", () => {
    const early = ulid(1000);
    const later = ulid(2_000_000);
    expect(early).toHaveLength(26);
    expect(later > early).toBe(true);
    expect(/^[0-9A-HJKMNP-TV-Z]{26}$/.test(ulid())).toBe(true);
  });

  it("hashes deterministically", () => {
    expect(sha256Hex("a")).toBe(crypto.createHash("sha256").update("a").digest("hex"));
  });

  it("slugifies accents, punctuation and spacing", () => {
    expect(slugify("Côte d'Azur Villa!")).toBe("cote-dazur-villa");
    expect(slugify("  multiple   spaces  ")).toBe("multiple-spaces");
    expect(slugify("")).toBe("");
  });
});

describe("CORS origin policy", () => {
  const allowed = new Set(["https://livfinder.com", "http://localhost:3000"]);

  it("allows exactly what is configured, in production and out", () => {
    for (const isProduction of [true, false]) {
      expect(isOriginAllowed("https://livfinder.com", { allowed, isProduction })).toBe(true);
      expect(isOriginAllowed("http://localhost:3000", { allowed, isProduction })).toBe(true);
    }
  });

  it("accepts any loopback origin outside production", () => {
    // localhost and 127.0.0.1 are different origins to a browser. Rejecting the spelling the
    // developer happened to type blocks every request and leaves the site loading forever.
    for (const origin of ["http://127.0.0.1:3000", "http://127.0.0.1:5173", "http://[::1]:3000", "https://localhost:8443"]) {
      expect(isOriginAllowed(origin, { allowed, isProduction: false })).toBe(true);
      expect(isOriginAllowed(origin, { allowed, isProduction: true })).toBe(false);
    }
  });

  it("never treats a lookalike host as loopback", () => {
    for (const origin of ["http://localhost.evil.com", "https://127.0.0.1.evil.com", "http://notlocalhost", "https://evil.com"]) {
      expect(isOriginAllowed(origin, { allowed, isProduction: false })).toBe(false);
      expect(isOriginAllowed(origin, { allowed, isProduction: true })).toBe(false);
    }
  });
});

describe("legacy CDN image rewriting", () => {
  it("rewrites seeded CDN URLs anywhere in a payload and leaves everything else alone", () => {
    const payload = {
      data: [
        { id: "a", avatarUrl: "https://cdn.livfinder.com/agents/farah-khoury-119.jpg" },
        { id: "b", logoUrl: "http://cdn.livfinder.com/organizations/omniyat.png", website: "https://cdn.livfinder.com.evil/x.jpg" },
      ],
      cover: { url: "http://localhost:4100/media/listings/imported/yachts/real.jpg" },
      count: 2,
      nothing: null,
    };
    const out = rewriteLegacyMediaUrls(payload);

    expect(out.data[0].avatarUrl).toMatch(/\/media\/placeholder\/agents\/farah-khoury-119\.svg$/);
    expect(out.data[1].logoUrl).toMatch(/\/media\/placeholder\/organizations\/omniyat\.svg$/);
    // A lookalike host is not the CDN and must not be rewritten.
    expect(out.data[1].website).toBe("https://cdn.livfinder.com.evil/x.jpg");
    // Real stored media is untouched.
    expect(out.cover.url).toBe("http://localhost:4100/media/listings/imported/yachts/real.jpg");
    expect(out.count).toBe(2);
    expect(out.nothing).toBeNull();
  });
});

describe("placeholder imagery", () => {
  it("is deterministic and derives a readable label from the path", () => {
    const first = renderPlaceholder("agents/farah-khoury-119.jpg");
    expect(renderPlaceholder("agents/farah-khoury-119.jpg")).toBe(first);
    expect(first).toContain('aria-label="Farah Khoury"');
    expect(first).toContain(">FK<");
    // A different subject gets different output, so a gallery is not one flat colour.
    expect(renderPlaceholder("agents/omar-said-3.jpg")).not.toBe(first);
  });

  it("escapes anything taken from the path", () => {
    // The path comes off the URL, so it is attacker-controlled and lands inside SVG markup
    // that a browser will parse.
    const svg = renderPlaceholder('organizations/<script>alert(1)</script>.png');
    expect(svg).not.toContain("<script");
    expect(svg).not.toContain("alert(1)");
    expect(svg).toContain("&gt;");

    const quoted = renderPlaceholder('agents/a"onload="alert(1).jpg');
    expect(quoted).toContain("&quot;");
    expect(quoted).not.toMatch(/aria-label="[^"]*"onload=/);
  });
});
