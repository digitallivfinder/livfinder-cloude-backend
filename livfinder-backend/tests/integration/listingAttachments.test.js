import { afterAll, beforeAll, describe, expect, it } from "vitest";
import sharp from "sharp";
import { client, cleanupListings, ensureTestPassword, findPortalOwner, queryOne } from "../helpers/testApp.js";
import { query } from "../../src/db/query.js";
import { closePool } from "../../src/db/pool.js";

/**
 * What the portal listing form writes beyond the listing row itself: catalogue features,
 * loose uploads from a signed-in browser, floor plans, typed documents, video and tour
 * links, and the rich-text description — against the real database.
 */
const PASSWORD = "LivFinder!2026";
const portal = client();
const created = [];
let listingId = null;

const PDF = Buffer.from("%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n");

async function png(seed = 1) {
  return sharp({ create: { width: 320, height: 200, channels: 3, background: { r: 30 + seed * 30, g: 90, b: 150 } } })
    .png()
    .toBuffer();
}

const upload = (path) => portal.agent.post(path).set("X-CSRF-Token", portal.csrfToken).set("Accept", "application/json");
const media = async () => (await portal.get(`/v1/media/listings/${listingId}/media`)).body.data;

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  const owner = await findPortalOwner();
  await portal.login(owner.email, PASSWORD);
  const community = await queryOne(
    "SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1"
  );
  const response = await portal.send("post", "/v1/portal/listings", {
    category: "real-estate",
    categorySlug: "apartments",
    purpose: "sale",
    title: `Attachment suite ${Date.now()}`,
    description: '<p>Sea <strong>views</strong></p><script>alert(1)</script><img src="x" onerror="alert(1)">',
    price: 2500000,
    currency: "AED",
    locationId: `community:${community.id}`,
    detail: { bedrooms: 2, bathrooms: 2, builtAreaSqft: 1400 },
  });
  expect(response.status).toBe(201);
  listingId = response.body.data.id;
  created.push(listingId);
});

afterAll(async () => {
  await cleanupListings(created);
  await closePool();
});

describe("catalogue reads for the portal form", () => {
  it("lists the features a category's listings may carry", async () => {
    const response = await portal.get("/v1/public/features", { category: "real-estate" });
    expect(response.status).toBe(200);
    expect(response.body.data.length).toBeGreaterThan(0);
    expect(response.body.data[0]).toEqual(expect.objectContaining({ id: expect.any(Number), name: expect.any(String) }));
  });

  it("has a features catalogue for every marketplace category", async () => {
    for (const category of ["cars", "watches", "yachts", "jets", "helicopters", "real-estate-developments"]) {
      const response = await portal.get("/v1/public/features", { category });
      expect(response.status).toBe(200);
      expect(response.body.data.length, category).toBeGreaterThanOrEqual(10);
      // Grouped the way the form renders them.
      expect(new Set(response.body.data.map((row) => row.group)).size, category).toBeGreaterThan(1);
    }
  });

  it("gives each category its own feature vocabulary", async () => {
    const cars = (await portal.get("/v1/public/features", { category: "cars" })).body.data.map((row) => row.name);
    expect(cars).toContain("Adaptive cruise control");
    expect(cars).not.toContain("Private pool");

    const jets = (await portal.get("/v1/public/features", { category: "jets" })).body.data.map((row) => row.name);
    expect(jets).toContain("Weather radar");
    expect(jets).not.toContain("Wire strike protection"); // that is a helicopter feature

    const helis = (await portal.get("/v1/public/features", { category: "helicopters" })).body.data.map((row) => row.name);
    expect(helis).toContain("Wire strike protection");

    const devs = (await portal.get("/v1/public/features", { category: "real-estate-developments" })).body.data.map((row) => row.name);
    expect(devs).toContain("Post-handover payment plan");
    expect(devs).not.toContain("Adaptive cruise control");
  });

  it("refuses a category it does not know", async () => {
    const response = await portal.get("/v1/public/features", { category: "spaceships" });
    expect(response.status).toBe(422);
  });
});

describe("uploads from a signed-in session", () => {
  it("accepts a loose image, as the add-listing flow sends before the listing exists", async () => {
    const response = await upload("/v1/media/upload").attach("files", await png(), "front.png");
    expect(response.status).toBe(201);
    expect(response.body.data[0].url).toBeTruthy();
    // `id` and `assetId` are both the public id — the form sends `assetId` as
    // `mediaAssetIds`, and every attach path resolves media by public id.
    expect(response.body.data[0].assetId).toBe(response.body.data[0].id);
    expect(String(response.body.data[0].assetId)).toMatch(/[a-z]/i);
  });

  it("attaches every loose image the add-listing form carried into create", async () => {
    const uploaded = await upload("/v1/media/upload")
      .attach("files", await png(2), "a.png")
      .attach("files", await png(3), "b.png")
      .attach("files", await png(4), "c.png");
    expect(uploaded.status).toBe(201);
    const ids = uploaded.body.data.map((row) => row.assetId);
    expect(ids).toHaveLength(3);

    const community = await queryOne(
      "SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1"
    );
    const response = await portal.send("post", "/v1/portal/listings", {
      category: "real-estate",
      categorySlug: "apartments",
      purpose: "sale",
      title: `Gallery attach ${Date.now()}`,
      description: "<p>Gallery</p>",
      price: 1900000,
      currency: "AED",
      locationId: `community:${community.id}`,
      detail: { bedrooms: 1, bathrooms: 1, builtAreaSqft: 800 },
      mediaAssetIds: ids,
    });
    expect(response.status).toBe(201);
    created.push(response.body.data.id);
    const gallery = (await portal.get(`/v1/media/listings/${response.body.data.id}/media`)).body.data;
    expect(gallery.filter((row) => (row.mediaType ?? row.type) === "image")).toHaveLength(3);
  });

  it("still finds the session when the browser also sends a dead one first", async () => {
    const cookies = portal.agent.jar.getCookies({ domain: "127.0.0.1", path: "/", secure: false, script: false });
    const live = cookies.find((cookie) => cookie.name === "livfinder_session");
    const header = cookies.map((cookie) => `${cookie.name}=${cookie.value}`).join("; ");
    const response = await client()
      .agent.get("/v1/auth/session")
      .set("Cookie", `livfinder_session=not-a-real-session; ${header}`);
    expect(live).toBeTruthy();
    expect(response.body.data.authenticated).toBe(true);
  });
});

describe("floor plans, documents and links", () => {
  it("attaches a typed PDF document that never becomes the cover", async () => {
    const response = await upload(`/v1/media/listings/${listingId}/files`)
      .field("mediaType", "document")
      .field("tag", "title_deed")
      .field("caption", "Title deed")
      .attach("files", PDF, { filename: "deed.pdf", contentType: "application/pdf" });
    expect(response.status).toBe(201);
    const document = response.body.data.find((row) => row.mediaType === "document");
    expect(document).toEqual(expect.objectContaining({ tag: "title_deed", caption: "Title deed", isCover: false }));
    expect(document.mimeType).toBe("application/pdf");
  });

  it("refuses a document without a type", async () => {
    const response = await upload(`/v1/media/listings/${listingId}/files`)
      .field("mediaType", "document")
      .attach("files", PDF, { filename: "untyped.pdf", contentType: "application/pdf" });
    expect(response.status).toBe(422);
  });

  it("attaches an image floor plan", async () => {
    const response = await upload(`/v1/media/listings/${listingId}/files`)
      .field("mediaType", "floor_plan")
      .attach("files", await png(2), "ground-floor.png");
    expect(response.status).toBe(201);
    expect(response.body.data.some((row) => row.mediaType === "floor_plan" && row.caption === "ground-floor.png")).toBe(true);
  });

  it("refuses a file that is neither a PDF nor an image", async () => {
    const response = await upload(`/v1/media/listings/${listingId}/files`)
      .field("mediaType", "floor_plan")
      .attach("files", Buffer.from("just some text"), { filename: "notes.txt", contentType: "text/plain" });
    expect(response.status).toBe(415);
  });

  it("adds a video as a link, and lets its address be changed", async () => {
    const added = await portal.send("post", `/v1/media/listings/${listingId}/links`, {
      mediaType: "video",
      url: "https://www.youtube.com/watch?v=livfinder",
      caption: "Walkthrough",
    });
    expect(added.status).toBe(201);
    const video = added.body.data.find((row) => row.mediaType === "video");
    expect(video.url).toBe("https://www.youtube.com/watch?v=livfinder");

    const edited = await portal.send("patch", `/v1/media/listings/${listingId}/media/${video.mediaId}`, {
      url: "https://vimeo.com/livfinder",
    });
    expect(edited.status).toBe(200);
    expect(edited.body.data.find((row) => row.mediaId === video.mediaId).url).toBe("https://vimeo.com/livfinder");
  });

  it("refuses a link that is not https", async () => {
    const response = await portal.send("post", `/v1/media/listings/${listingId}/links`, {
      mediaType: "virtual_tour",
      url: "http://tour.example.com/1",
    });
    expect(response.status).toBe(422);
  });

  it("keeps attachments out of the gallery order and the cover", async () => {
    await upload(`/v1/media/listings/${listingId}/media`).attach("files", await png(3), "facade.png");
    await upload(`/v1/media/listings/${listingId}/media`).attach("files", await png(4), "garden.png");
    const images = (await media()).filter((row) => row.mediaType === "image");
    expect(images.length).toBeGreaterThanOrEqual(2);

    const reordered = await portal.send("patch", `/v1/media/listings/${listingId}/media/reorder`, {
      order: [...images].reverse().map((row) => row.mediaId),
    });
    expect(reordered.status).toBe(200);
    const cover = reordered.body.data.filter((row) => row.isCover);
    expect(cover).toHaveLength(1);
    expect(cover[0].mediaType).toBe("image");
  });
});

describe("category-appropriate media", () => {
  const cars = client();
  let carListingId = null;

  beforeAll(async () => {
    const owner = await queryOne(
      `SELECT u.email FROM users u
         JOIN account_members am ON am.user_id = u.id AND am.role = 'owner' AND am.status = 'active'
         JOIN account_category_access aca ON aca.account_id = am.account_id AND aca.status = 'approved' AND aca.category_id = 2
        WHERE u.status = 'active' AND u.deleted_at IS NULL
        ORDER BY u.id LIMIT 1`
    );
    await cars.login(owner.email, PASSWORD);
    const anyLocation = await queryOne("SELECT id FROM locations WHERE level = 'city' AND status = 'active' LIMIT 1");
    const created = await cars.send("post", "/v1/portal/listings", {
      category: "cars",
      categorySlug: "supercars",
      purpose: "sale",
      title: `Car media suite ${Date.now()}`,
      description: "<p>Fast</p>",
      price: 450000,
      currency: "AED",
      locationId: `city:${anyLocation.id}`,
      detail: { make: "Ferrari", model: "296 GTB", year: 2024 },
    });
    expect(created.status).toBe(201);
    carListingId = created.body.data.id;
  });

  afterAll(async () => {
    if (carListingId) await cleanupListings([carListingId]);
  });

  const carUpload = () =>
    cars.agent.post(`/v1/media/listings/${carListingId}/files`).set("X-CSRF-Token", cars.csrfToken).set("Accept", "application/json");

  it("refuses a floor plan on a car", async () => {
    const response = await carUpload().field("mediaType", "floor_plan").attach("files", await png(9), "plan.png");
    expect(response.status).toBe(422);
  });

  it("refuses a virtual tour on a car", async () => {
    const response = await cars.send("post", `/v1/media/listings/${carListingId}/links`, {
      mediaType: "virtual_tour",
      url: "https://tour.example.com/car",
    });
    expect(response.status).toBe(422);
  });

  it("refuses a real-estate document type on a car", async () => {
    const response = await carUpload()
      .field("mediaType", "document")
      .field("tag", "title_deed")
      .attach("files", PDF, { filename: "deed.pdf", contentType: "application/pdf" });
    expect(response.status).toBe(422);
  });

  it("accepts a car document type and a plain video", async () => {
    const doc = await carUpload()
      .field("mediaType", "document")
      .field("tag", "registration")
      .attach("files", PDF, { filename: "reg.pdf", contentType: "application/pdf" });
    expect(doc.status).toBe(201);

    const video = await cars.send("post", `/v1/media/listings/${carListingId}/links`, {
      mediaType: "video",
      url: "https://www.youtube.com/watch?v=car",
    });
    expect(video.status).toBe(201);
  });
});

describe("rich-text descriptions", () => {
  it("stores and serves only the allowlist", async () => {
    const response = await portal.get(`/v1/portal/listings/${listingId}`);
    expect(response.status).toBe(200);
    const { description, descriptionHtml, descriptionText } = response.body.data;
    expect(description).toContain("<strong>views</strong>");
    expect(description).not.toMatch(/<script|onerror|<img/i);
    expect(descriptionHtml).not.toMatch(/<script|onerror|<img/i);
    expect(descriptionText).toBe("Sea views");
  });
});
