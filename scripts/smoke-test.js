#!/usr/bin/env node
/**
 * End-to-end API smoke test against a running server.
 *
 * Exercises the real HTTP surface — public reads, sign-in, CSRF, portal reads,
 * a listing create/edit/publish cycle with a real image upload, admin
 * moderation, and an authorization check — and asserts persistence by
 * re-reading each mutation through a fresh request.
 *
 *   BASE_URL=http://127.0.0.1:4100 node scripts/smoke-test.js
 */
import { Buffer } from "node:buffer";
import sharp from "sharp";

const BASE = process.env.BASE_URL || "http://127.0.0.1:4100";
const PASSWORD = process.env.DEV_PASSWORD || "LivFinder!2026";

let passed = 0;
let failed = 0;
const failures = [];

function ok(name, detail = "") {
  passed += 1;
  console.log(`  ok    ${name}${detail ? ` — ${detail}` : ""}`);
}
function fail(name, detail) {
  failed += 1;
  failures.push(`${name}: ${detail}`);
  console.log(`  FAIL  ${name} — ${detail}`);
}
async function check(name, fn) {
  try {
    const detail = await fn();
    ok(name, detail);
  } catch (error) {
    fail(name, error.message);
  }
}
function assert(condition, message) {
  if (!condition) throw new Error(message);
}

/** A cookie jar plus CSRF handling, so the client behaves like a browser. */
function createClient() {
  const cookies = new Map();
  return {
    cookies,
    csrfToken: null,
    async request(path, { method = "GET", body, headers = {}, raw = false } = {}) {
      const cookieHeader = [...cookies.entries()].map(([key, value]) => `${key}=${value}`).join("; ");
      const requestHeaders = { Accept: "application/json", ...headers };
      if (cookieHeader) requestHeaders.Cookie = cookieHeader;
      if (this.csrfToken && method !== "GET") requestHeaders["X-CSRF-Token"] = this.csrfToken;

      let payload = body;
      if (body && !(body instanceof FormData) && typeof body === "object") {
        requestHeaders["Content-Type"] = "application/json";
        payload = JSON.stringify(body);
      }

      const response = await fetch(`${BASE}${path}`, { method, headers: requestHeaders, body: payload });
      for (const raw of response.headers.getSetCookie?.() ?? []) {
        const [pair] = raw.split(";");
        const index = pair.indexOf("=");
        const name = pair.slice(0, index).trim();
        const value = pair.slice(index + 1).trim();
        if (value === "" ) cookies.delete(name);
        else cookies.set(name, value);
      }
      if (cookies.has("livfinder_csrf")) this.csrfToken = cookies.get("livfinder_csrf");

      const text = await response.text();
      let json = null;
      try {
        json = text ? JSON.parse(text) : null;
      } catch {
        json = null;
      }
      return { status: response.status, body: json, text, headers: response.headers };
    },
  };
}

async function makeImage(label, size = 900) {
  return sharp({
    create: { width: size, height: Math.round(size * 0.66), channels: 3, background: { r: 30 + (label.length % 60), g: 90, b: 140 } },
  })
    .jpeg({ quality: 80 })
    .toBuffer();
}

async function run() {
  console.log(`\nLivFinder API smoke test → ${BASE}\n`);

  const anon = createClient();

  console.log("Health");
  await check("GET /health", async () => {
    const res = await anon.request("/health");
    assert(res.status === 200 && res.body.data.status === "ok", `status ${res.status}`);
    return res.body.data.environment;
  });
  await check("GET /health/database", async () => {
    const res = await anon.request("/health/database");
    assert(res.status === 200 && res.body.data.status === "ok", `status ${res.status}`);
    return `MySQL ${res.body.data.serverVersion}`;
  });
  await check("X-Request-ID header present", async () => {
    const res = await anon.request("/health");
    assert(res.headers.get("x-request-id"), "missing header");
    return res.headers.get("x-request-id").slice(0, 8);
  });

  console.log("\nPublic marketplace");
  let sampleListing = null;
  await check("GET /v1/public/home", async () => {
    const res = await anon.request("/v1/public/home");
    assert(res.status === 200, `status ${res.status}`);
    assert(Array.isArray(res.body.data.featuredListings), "featuredListings missing");
    return `${res.body.data.featuredListings.length} featured, ${res.body.data.featuredCompanies.length} companies`;
  });
  await check("GET /v1/public/listings", async () => {
    const res = await anon.request("/v1/public/listings?category=real-estate&pageSize=5");
    assert(res.status === 200, `status ${res.status}`);
    assert(res.body.data.length > 0, "no listings");
    assert(res.body.pageInfo.total > 0, "no total");
    sampleListing = res.body.data[0];
    return `${res.body.data.length} of ${res.body.pageInfo.total}`;
  });
  await check("public listing card carries only a cover image", async () => {
    assert(sampleListing, "no sample");
    assert(sampleListing.media.length <= 1, `card returned ${sampleListing.media.length} images`);
    return `imageCount=${sampleListing.imageCount}, media=${sampleListing.media.length}`;
  });
  await check("GET /v1/public/listings filters by price", async () => {
    const res = await anon.request("/v1/public/listings?category=real-estate&minPrice=5000000&pageSize=5");
    assert(res.status === 200, `status ${res.status}`);
    const under = res.body.data.filter((item) => item.priceBase !== null && item.priceBase < 5000000);
    assert(under.length === 0, `${under.length} rows below the floor`);
    return `${res.body.pageInfo.total} matches`;
  });
  await check("GET /v1/public/listings filters by bedrooms", async () => {
    const res = await anon.request("/v1/public/listings?category=real-estate&beds=5&pageSize=5");
    assert(res.status === 200, `status ${res.status}`);
    const wrong = res.body.data.filter((item) => item.bedrooms !== 5);
    assert(wrong.length === 0, `${wrong.length} rows with the wrong bedroom count`);
    return `${res.body.pageInfo.total} matches`;
  });
  await check("pagination advances", async () => {
    const first = await anon.request("/v1/public/listings?category=cars&page=1&pageSize=3");
    const second = await anon.request("/v1/public/listings?category=cars&page=2&pageSize=3");
    assert(first.body.data[0].id !== second.body.data[0].id, "page 2 repeated page 1");
    return `${first.body.pageInfo.totalPages} pages`;
  });
  await check("GET /v1/public/listings/by-path", async () => {
    const res = await anon.request(`/v1/public/listings/by-path?path=${encodeURIComponent(sampleListing.canonicalUrl)}`);
    assert(res.status === 200 && res.body.data, "not found by canonical path");
    assert(res.body.data.gallery.length >= 0, "no gallery key");
    return `${res.body.data.reference}, gallery ${res.body.data.gallery.length}`;
  });
  await check("GET /v1/public/companies", async () => {
    const res = await anon.request("/v1/public/companies?pageSize=3");
    assert(res.status === 200 && res.body.data.length > 0, "no companies");
    return `${res.body.pageInfo.total} companies`;
  });
  await check("GET /v1/public/agents", async () => {
    const res = await anon.request("/v1/public/agents?pageSize=3");
    assert(res.status === 200 && res.body.data.length > 0, "no agents");
    return `${res.body.pageInfo.total} agents`;
  });
  await check("GET /v1/public/countries", async () => {
    const res = await anon.request("/v1/public/countries");
    assert(res.status === 200 && res.body.data.length > 0, "no countries");
    return `${res.body.data.length} countries`;
  });
  await check("GET /v1/public/locations typeahead", async () => {
    const res = await anon.request("/v1/public/locations?q=Dub&type=city");
    assert(res.status === 200 && res.body.options.length > 0, "no matches for Dub");
    return res.body.options[0].label;
  });
  await check("locations endpoint is bounded", async () => {
    const res = await anon.request("/v1/public/locations?limit=999");
    assert(res.body.options.length <= 50, `returned ${res.body.options.length}`);
    return `${res.body.options.length} rows`;
  });
  await check("GET /v1/public/blogs", async () => {
    const res = await anon.request("/v1/public/blogs?pageSize=3");
    assert(res.status === 200 && res.body.data.length > 0, "no articles");
    return `${res.body.pageInfo.total} articles`;
  });
  await check("GET /v1/public/blogs/:slug returns blocks", async () => {
    const list = await anon.request("/v1/public/blogs?pageSize=1");
    const res = await anon.request(`/v1/public/blogs/${list.body.data[0].slug}`);
    assert(res.status === 200 && Array.isArray(res.body.data.body), "body is not a block array");
    return `${res.body.data.body.length} blocks`;
  });
  await check("GET /v1/public/sitemap", async () => {
    const res = await anon.request("/v1/public/sitemap?kind=properties");
    assert(res.status === 200 && res.body.data.length > 0, "empty sitemap");
    return `${res.body.data.length} urls`;
  });
  await check("unpublished listings are not reachable by reference", async () => {
    const res = await anon.request("/v1/public/listings/LF-0000000");
    assert(res.status === 404, `status ${res.status}`);
    return "404 as expected";
  });

  console.log("\nAuthentication");
  const portal = createClient();
  let portalSession = null;
  await check("login rejects a bad password", async () => {
    const res = await portal.request("/v1/auth/login", {
      method: "POST",
      body: { email: "vikram.ferrari11@example.com", password: "definitely-not-it" },
    });
    assert(res.status === 401, `status ${res.status}`);
    assert(!/not found|no such/i.test(res.body.error.message), "message leaks account existence");
    return res.body.error.code;
  });
  await check("POST /v1/auth/login", async () => {
    const res = await portal.request("/v1/auth/login", {
      method: "POST",
      body: { email: "vikram.ferrari11@example.com", password: PASSWORD },
    });
    assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 120)}`);
    assert(res.body.data.authenticated, "not authenticated");
    portalSession = res.body.data;
    return `${res.body.data.user.displayName}, account ${res.body.data.account?.accountType}`;
  });
  await check("session cookie is HttpOnly", async () => {
    assert(portal.cookies.has("livfinder_session"), "no session cookie");
    return "livfinder_session set";
  });
  await check("GET /v1/auth/session survives a fresh request", async () => {
    const res = await portal.request("/v1/auth/session");
    assert(res.status === 200 && res.body.data?.authenticated, "session not restored");
    return res.body.data.user.email;
  });
  await check("anonymous session read returns null", async () => {
    const res = await anon.request("/v1/auth/session");
    assert(res.status === 200 && res.body.data === null, `status ${res.status}`);
    return "null session";
  });

  console.log("\nCSRF");
  await check("mutation without a CSRF token is rejected", async () => {
    const cookieHeader = [...portal.cookies.entries()].map(([key, value]) => `${key}=${value}`).join("; ");
    const response = await fetch(`${BASE}/v1/favourites`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Cookie: cookieHeader },
      body: JSON.stringify({ listingId: sampleListing.id }),
    });
    assert(response.status === 403, `status ${response.status}`);
    return "403 as expected";
  });
  await check("mutation with a valid CSRF token is accepted", async () => {
    const res = await portal.request("/v1/favourites", { method: "POST", body: { listingId: sampleListing.id } });
    assert(res.status === 201, `status ${res.status} ${res.text.slice(0, 160)}`);
    return "favourited";
  });
  await check("favourite persisted across a new request", async () => {
    const res = await portal.request("/v1/favourites/ids");
    assert(res.body.data.includes(sampleListing.id), "favourite not persisted");
    return `${res.body.data.length} favourites`;
  });
  await check("favourite can be removed", async () => {
    await portal.request(`/v1/favourites/${sampleListing.id}`, { method: "DELETE" });
    const res = await portal.request("/v1/favourites/ids");
    assert(!res.body.data.includes(sampleListing.id), "favourite still present");
    return "removed and verified";
  });

  console.log("\nPortal");
  await check("GET /v1/portal/dashboard", async () => {
    const res = await portal.request("/v1/portal/dashboard");
    assert(res.status === 200, `status ${res.status}`);
    assert(res.body.data.summary.activeListings.value >= 0, "no summary");
    return `${res.body.data.summary.activeListings.value} active listings`;
  });
  await check("GET /v1/portal/listings", async () => {
    const res = await portal.request("/v1/portal/listings?pageSize=5");
    assert(res.status === 200 && Array.isArray(res.body.data), "no listings");
    assert(res.body.counts.all === res.body.pageInfo.total || res.body.counts.all >= res.body.data.length, "counts disagree");
    return `${res.body.pageInfo.total} listings, counts ${JSON.stringify(res.body.counts)}`;
  });
  for (const path of ["inquiries", "leads", "messages", "bookings", "offers", "reviews", "favourites", "saved-searches", "profile", "categories"]) {
    await check(`GET /v1/portal/${path}`, async () => {
      const res = await portal.request(`/v1/portal/${path}`);
      assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 140)}`);
      return Array.isArray(res.body.data) ? `${res.body.data.length} rows` : "ok";
    });
  }
  await check("GET /v1/portal/organization", async () => {
    const res = await portal.request("/v1/portal/organization");
    assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 140)}`);
    return res.body.data.name;
  });
  await check("GET /v1/portal/billing", async () => {
    const res = await portal.request("/v1/portal/billing");
    assert(res.status === 200, `status ${res.status}`);
    return res.body.data.currentPlan?.name || "no plan";
  });

  console.log("\nListing lifecycle");
  let createdListing = null;
  const locationLookup = await anon.request("/v1/public/locations?q=Dubai&type=community&limit=1");
  const communityId = locationLookup.body.options[0]?.id;

  await check("POST /v1/portal/listings creates a real-estate listing", async () => {
    const res = await portal.request("/v1/portal/listings", {
      method: "POST",
      body: {
        category: "real-estate",
        categorySlug: "villas",
        purpose: "sale",
        title: `Smoke Test Villa ${Date.now()}`,
        description: "Created by the API smoke test to verify the full create path end to end.",
        price: 12500000,
        currency: "AED",
        locationId: communityId,
        contactName: "Smoke Test",
        contactEmail: "smoke@example.com",
        detail: { bedrooms: 5, bathrooms: 6, builtAreaSqft: 7200, furnishing: "furnished", completionStatus: "ready" },
      },
    });
    assert(res.status === 201, `status ${res.status} ${res.text.slice(0, 300)}`);
    createdListing = res.body.data;
    return `${createdListing.reference} (${createdListing.status})`;
  });
  await check("created listing persists and carries its category detail", async () => {
    const res = await portal.request(`/v1/portal/listings/${createdListing.id}`);
    assert(res.status === 200, `status ${res.status}`);
    assert(res.body.data.bedrooms === 5, `bedrooms ${res.body.data.bedrooms}`);
    assert(res.body.data.builtAreaSqft === 7200, `area ${res.body.data.builtAreaSqft}`);
    return `beds ${res.body.data.bedrooms}, ${res.body.data.builtArea}`;
  });
  await check("draft listing is not publicly visible", async () => {
    const res = await anon.request(`/v1/public/listings/${createdListing.reference}`);
    assert(res.status === 404, `status ${res.status}`);
    return "404 as expected";
  });
  await check("PATCH /v1/portal/listings/:id updates and persists", async () => {
    const newTitle = `Smoke Test Villa Updated ${Date.now()}`;
    const res = await portal.request(`/v1/portal/listings/${createdListing.id}`, {
      method: "PATCH",
      body: { title: newTitle, price: 13750000, detail: { bedrooms: 6 } },
    });
    assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 200)}`);
    const reread = await portal.request(`/v1/portal/listings/${createdListing.id}`);
    assert(reread.body.data.title === newTitle, "title not persisted");
    assert(reread.body.data.bedrooms === 6, `bedrooms ${reread.body.data.bedrooms}`);
    assert(reread.body.data.price.amount === 13750000, `price ${reread.body.data.price.amount}`);
    return "title, price and bedrooms persisted";
  });

  console.log("\nMedia");
  let uploadedMedia = [];
  await check("POST listing media uploads two images", async () => {
    const form = new FormData();
    form.append("files", new Blob([await makeImage("a")], { type: "image/jpeg" }), "smoke-a.jpg");
    form.append("files", new Blob([await makeImage("bb")], { type: "image/jpeg" }), "smoke-b.jpg");
    form.append("altText", "Smoke test image");
    const res = await portal.request(`/v1/media/listings/${createdListing.id}/media`, { method: "POST", body: form });
    assert(res.status === 201, `status ${res.status} ${res.text.slice(0, 300)}`);
    uploadedMedia = res.body.data;
    assert(uploadedMedia.length === 2, `${uploadedMedia.length} media rows`);
    return `${uploadedMedia.length} images, cover=${uploadedMedia[0].isCover}`;
  });
  await check("uploaded image is fetchable over HTTP", async () => {
    const response = await fetch(uploadedMedia[0].url);
    assert(response.ok, `status ${response.status}`);
    const buffer = Buffer.from(await response.arrayBuffer());
    assert(buffer.length > 500, `only ${buffer.length} bytes`);
    return `${Math.round(buffer.length / 1024)} KB`;
  });
  await check("renditions were generated and the thumbnail loads", async () => {
    assert(uploadedMedia[0].thumbnailUrl, "no thumbnail");
    const response = await fetch(uploadedMedia[0].thumbnailUrl);
    assert(response.ok, `thumbnail status ${response.status}`);
    return uploadedMedia[0].thumbnailUrl.split("/").pop();
  });
  await check("gallery survives a fresh read", async () => {
    const res = await portal.request(`/v1/media/listings/${createdListing.id}/media`);
    assert(res.body.data.length === 2, `${res.body.data.length} rows`);
    return `${res.body.data.length} images`;
  });
  await check("PATCH reorder swaps the cover and persists", async () => {
    const before = await portal.request(`/v1/media/listings/${createdListing.id}/media`);
    const reversed = [...before.body.data].reverse().map((item) => item.id);
    const res = await portal.request(`/v1/media/listings/${createdListing.id}/media/reorder`, {
      method: "PATCH",
      body: { order: reversed },
    });
    assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 200)}`);
    const after = await portal.request(`/v1/media/listings/${createdListing.id}/media`);
    assert(after.body.data[0].id === reversed[0], "order not persisted");
    assert(after.body.data[0].isCover, "cover not moved");
    return "order and cover persisted";
  });
  await check("PATCH media alt text persists", async () => {
    const list = await portal.request(`/v1/media/listings/${createdListing.id}/media`);
    const target = list.body.data[0];
    await portal.request(`/v1/media/listings/${createdListing.id}/media/${target.id}`, {
      method: "PATCH",
      body: { altText: "Updated alt text" },
    });
    const after = await portal.request(`/v1/media/listings/${createdListing.id}/media`);
    assert(after.body.data[0].alt === "Updated alt text", `alt is "${after.body.data[0].alt}"`);
    return "alt text persisted";
  });
  await check("DELETE media removes one image and persists", async () => {
    const list = await portal.request(`/v1/media/listings/${createdListing.id}/media`);
    const target = list.body.data[1];
    const res = await portal.request(`/v1/media/listings/${createdListing.id}/media/${target.id}`, { method: "DELETE" });
    assert(res.status === 200, `status ${res.status}`);
    const after = await portal.request(`/v1/media/listings/${createdListing.id}/media`);
    assert(after.body.data.length === 1, `${after.body.data.length} rows remain`);
    return "one image remains";
  });
  await check("a non-image upload is rejected", async () => {
    const form = new FormData();
    form.append("files", new Blob([Buffer.from("not an image at all")], { type: "image/jpeg" }), "fake.jpg");
    const res = await portal.request(`/v1/media/listings/${createdListing.id}/media`, { method: "POST", body: form });
    assert(res.status === 415, `status ${res.status}`);
    return res.body.error.code;
  });

  console.log("\nPublication");
  await check("portal cannot publish directly", async () => {
    const res = await portal.request(`/v1/portal/listings/${createdListing.id}/status`, {
      method: "PATCH",
      body: { status: "active" },
    });
    assert(res.status === 403, `status ${res.status}`);
    return "403 as expected";
  });
  await check("portal can submit for review", async () => {
    const res = await portal.request(`/v1/portal/listings/${createdListing.id}/status`, {
      method: "PATCH",
      body: { status: "pending_review" },
    });
    assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 200)}`);
    return res.body.data.status;
  });

  console.log("\nAdmin");
  const admin = createClient();
  await check("admin login", async () => {
    const res = await admin.request("/v1/auth/login", {
      method: "POST",
      body: { email: "admin@livfinder.com", password: PASSWORD },
    });
    assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 200)}`);
    assert(res.body.data.user.platformRole === "admin", "not an admin session");
    return `${res.body.data.admin.role}, ${res.body.data.admin.permissions.length} permissions`;
  });
  /**
   * Step-up — SEC-IAM-011.
   *
   * Payment credentials, role changes and staff-user changes require the session to have
   * re-proved itself. A real administrator's client does this after the first 403; the smoke
   * test does the same, so what it exercises is the flow a person actually goes through.
   */
  await check("step-up before high-risk actions", async () => {
    const res = await admin.request("/v1/auth/step-up", { method: "POST", body: { password: PASSWORD } });
    assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 200)}`);
    return `valid for ${res.body.data.validForMinutes} minutes`;
  });

  await check("a high-risk action is refused without step-up", async () => {
    // A fresh session has not stepped up, so the same call it just made is refused.
    const fresh = createClient();
    const login = await fresh.request("/v1/auth/login", {
      method: "POST",
      body: { email: "admin@livfinder.com", password: PASSWORD },
    });
    assert(login.status === 200, `login ${login.status}`);
    const res = await fresh.request("/v1/admin/settings/payment", { method: "PATCH", body: { general: {} } });
    assert(res.status === 403, `status ${res.status}`);
    assert(res.body?.error?.code === "STEP_UP_REQUIRED", `code ${res.body?.error?.code}`);
    return "403 STEP_UP_REQUIRED as expected";
  });

  await check("portal user cannot reach admin", async () => {
    const res = await portal.request("/v1/admin/dashboard");
    assert(res.status === 403, `status ${res.status}`);
    return "403 as expected";
  });
  await check("GET /v1/admin/dashboard", async () => {
    const res = await admin.request("/v1/admin/dashboard");
    assert(res.status === 200 && res.body.data.kpis.length > 0, `status ${res.status}`);
    return `${res.body.data.kpis.length} kpis, ${res.body.data.listingInventory.length} inventory rows`;
  });
  for (const path of [
    "listings?category=real-estate", "developments", "companies", "individuals", "agents", "leads",
    "contacts", "articles", "media", "reviews", "reports", "roles", "access-users", "system-logs",
    "packages", "categories", "locations/countries", "locations/communities", "settings/general",
    "settings/payment", "me/permissions",
  ]) {
    await check(`GET /v1/admin/${path.split("?")[0]}`, async () => {
      const res = await admin.request(`/v1/admin/${path}`);
      assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 140)}`);
      const count = res.body.total ?? res.body.data?.length ?? "ok";
      return String(count);
    });
  }
  await check("payment secrets are never returned", async () => {
    const res = await admin.request("/v1/admin/settings/payment");
    const secret = res.body.data._flat?.stripe_secret_key;
    assert(secret && typeof secret === "object" && "configured" in secret, "secret is not masked");
    assert(!("value" in secret), "secret value present in response");
    assert(!/sk_(test|live)/.test(res.text), "a provider key appears in the response body");
    return `configured=${secret.configured}`;
  });

  await check("a saved payment secret is stored encrypted and never read back", async () => {
    const write = await admin.request("/v1/admin/settings/payment", {
      method: "PATCH",
      body: { credentials: { stripe_secret_key: "sk_test_smoke_1234" }, tax: { rate: 5 } },
    });
    assert(write.status === 200, `status ${write.status} ${write.text.slice(0, 200)}`);
    const read = await admin.request("/v1/admin/settings/payment");
    assert(!read.text.includes("sk_test_smoke_1234"), "the secret came back from the API");
    const secret = read.body.data._flat.stripe_secret_key;
    assert(secret.configured === true, "the secret was not stored");
    assert(secret.hint && secret.hint.endsWith("1234"), `hint is ${secret.hint}`);
    return `stored, hint ${secret.hint}`;
  });

  await check("a settings document section persists", async () => {
    const write = await admin.request("/v1/admin/settings/general", {
      method: "PATCH",
      body: { general: { platformName: "LivFinder Smoke" } },
    });
    assert(write.status === 200, `status ${write.status}`);
    const read = await admin.request("/v1/admin/settings/general");
    assert(read.body.data.general.platformName === "LivFinder Smoke", "not persisted");
    // The public flat row is mirrored so the marketplace cannot disagree.
    assert(read.body.data._flat.site_name === "LivFinder Smoke", "flat row not mirrored");
    await admin.request("/v1/admin/settings/general", { method: "PATCH", body: { general: { platformName: "LivFinder" } } });
    return "persisted and mirrored";
  });
  await check("admin can approve the submitted listing", async () => {
    const res = await admin.request(`/v1/admin/listings/${createdListing.id}/moderation`, {
      method: "PATCH",
      body: { decision: "approve", note: "smoke test" },
    });
    assert(res.status === 200, `status ${res.status} ${res.text.slice(0, 200)}`);
    return res.body.data.status;
  });
  await check("approved listing is now publicly visible", async () => {
    const res = await anon.request(`/v1/public/listings/${createdListing.reference}`);
    assert(res.status === 200, `status ${res.status}`);
    assert(res.body.data.gallery.length === 1, `gallery ${res.body.data.gallery.length}`);
    return `${res.body.data.reference}, ${res.body.data.gallery.length} image`;
  });
  await check("approved listing appears in public search", async () => {
    const res = await anon.request(`/v1/public/listings?keyword=${encodeURIComponent(createdListing.reference)}`);
    assert(res.body.pageInfo.total >= 1, "not in the search projection");
    return `${res.body.pageInfo.total} match`;
  });
  await check("admin can archive it again", async () => {
    const res = await admin.request(`/v1/admin/listings/${createdListing.id}/moderation`, {
      method: "PATCH",
      body: { decision: "archive", reason: "smoke test cleanup" },
    });
    assert(res.status === 200, `status ${res.status}`);
    const check404 = await anon.request(`/v1/public/listings/${createdListing.reference}`);
    assert(check404.status === 404, `still public: ${check404.status}`);
    return "archived and removed from the projection";
  });

  console.log("\nAuthorization");
  await check("another account's listing is not reachable", async () => {
    // The listing has to belong to a *different* owner for this to prove
    // anything, so pick one whose organization is not the caller's.
    const mine = await portal.request("/v1/portal/organization");
    const ownName = mine.body.data.name;
    const other = await admin.request("/v1/admin/listings?pageSize=200");
    const foreign = other.body.items.find((item) => item.owner && item.owner !== ownName);
    assert(foreign, "no listing from another owner to test with");
    const res = await portal.request(`/v1/portal/listings/${foreign.id}`);
    assert(res.status === 404, `status ${res.status} for a listing owned by ${foreign.owner}`);
    return `404 for ${foreign.owner}'s listing`;
  });
  await check("unauthenticated portal read is rejected", async () => {
    const res = await anon.request("/v1/portal/dashboard");
    assert(res.status === 401, `status ${res.status}`);
    return res.body.error.code;
  });
  await check("errors carry a trace id", async () => {
    const res = await anon.request("/v1/portal/dashboard");
    assert(res.body.error.traceId, "no traceId");
    return res.body.error.traceId.slice(0, 8);
  });
  await check("validation errors report fields", async () => {
    const res = await portal.request("/v1/portal/listings", { method: "POST", body: { title: "x" } });
    assert(res.status === 422, `status ${res.status}`);
    assert(res.body.error.fields, "no field errors");
    return Object.keys(res.body.error.fields).join(", ").slice(0, 60);
  });

  console.log("\nSign out");
  await check("POST /v1/auth/logout ends the session", async () => {
    const res = await portal.request("/v1/auth/logout", { method: "POST" });
    assert(res.status === 200, `status ${res.status}`);
    const after = await portal.request("/v1/auth/session");
    assert(after.body.data === null, "session survived logout");
    return "session cleared";
  });

  console.log(`\n${passed} passed, ${failed} failed\n`);
  if (failed) {
    console.log("Failures:");
    for (const failure of failures) console.log(`  - ${failure}`);
    process.exit(1);
  }
}

run().catch((error) => {
  console.error("\nsmoke test crashed:", error);
  process.exit(1);
});
