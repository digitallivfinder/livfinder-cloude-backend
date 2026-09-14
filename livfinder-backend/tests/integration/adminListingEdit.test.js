import { afterAll, beforeAll, describe, expect, it } from "vitest";
import sharp from "sharp";
import { adminEmail, cleanupListings, client, ensureTestPassword, findPortalOwner, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";

const png = () =>
  sharp({ create: { width: 240, height: 160, channels: 3, background: { r: 40, g: 110, b: 170 } } }).png().toBuffer();

/**
 * The admin real-estate edit form and detail view, against the real database.
 *
 * The admin form posts the same shape the client portal does — category-shared
 * fields at the top level, `realEstateDetail` in `detail` — through
 * `PATCH /v1/admin/listings/:id`. This exercises a full round trip: create a
 * listing as its owner, edit every field group as an admin, and read it back to
 * confirm each value reached its column.
 */
const PASSWORD = "LivFinder!2026";
const portal = client();
const admin = client();
const created = [];
let publicId = null;

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  const owner = await findPortalOwner();
  await portal.login(owner.email, PASSWORD);
  await admin.login(await adminEmail("super_admin"), PASSWORD);

  const community = await queryOne(
    "SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1"
  );
  const city = await queryOne(
    "SELECT id FROM locations WHERE level = 'city' AND status = 'active' AND active_listing_count > 0 LIMIT 1"
  );
  const response = await portal.send("post", "/v1/portal/listings", {
    category: "real-estate",
    categorySlug: "apartments",
    purpose: "sale",
    title: `Admin edit suite ${Date.now()}`,
    description: "<p>Original</p>",
    price: 1000000,
    currency: "AED",
    locationId: `community:${community.id}`,
    detail: { bedrooms: 1, bathrooms: 1, builtAreaSqft: 900 },
  });
  expect(response.status).toBe(201);
  publicId = response.body.data.id;
  created.push(publicId);
  globalThis.__cityId = city.id;
});

afterAll(async () => {
  await cleanupListings(created);
  await closePool();
});

describe("admin real-estate listing edit round trip", () => {
  it("returns a detail the edit form can prefill from", async () => {
    const response = await admin.get(`/v1/admin/listings/${publicId}`);
    expect(response.status).toBe(200);
    const listing = response.body.data;
    expect(listing).toEqual(
      expect.objectContaining({
        title: expect.any(String),
        purpose: "sale",
        bedrooms: 1,
        bathrooms: 1,
        locationIds: expect.objectContaining({ city: expect.any(Number), community: expect.any(Number) }),
        contact: expect.any(Object),
        gallery: expect.any(Array),
        mediaItems: expect.any(Array),
        descriptionHtml: expect.any(String),
      })
    );
  });

  it("surfaces an image uploaded as a floor plan in mediaItems, so the gallery can show it", async () => {
    const upload = await admin.agent
      .post(`/v1/media/listings/${publicId}/files`)
      .set("X-CSRF-Token", admin.csrfToken)
      .set("Accept", "application/json")
      .field("mediaType", "floor_plan")
      .attach("files", await png(), "layout.png");
    expect(upload.status).toBe(201);

    const listing = (await admin.get(`/v1/admin/listings/${publicId}`)).body.data;
    // The serializer's `gallery` is filtered to media_type='image' and stays empty…
    expect(listing.gallery).toEqual([]);
    // …but `mediaItems` carries the row, typed and with its mime, so the admin UI
    // classifies it as an image and shows it — the same list the client portal gets.
    const row = listing.mediaItems.find((item) => item.mediaType === "floor_plan");
    expect(row).toEqual(
      expect.objectContaining({ mediaType: "floor_plan", mimeType: "image/png", url: expect.stringContaining("/media/") })
    );

    // The listings table shows a picture too: with no cover set, it falls back to
    // any image file on the listing.
    const list = await admin.get("/v1/admin/listings", { category: "real-estate", search: publicId, pageSize: 1 });
    expect(list.body.items[0].image).toEqual(expect.stringContaining("/media/"));
  });

  it("writes every field group through PATCH and reads them all back", async () => {
    const patch = {
      purpose: "rent",
      title: "Admin edited title",
      subtitle: "Top floor, sea view",
      description: "<p>Rewritten by admin</p>",
      price: 185000,
      currency: "AED",
      priceType: "negotiable",
      pricePeriod: "year",
      isPriceHidden: false,
      locationId: `city:${globalThis.__cityId}`,
      address: "12 Marina Walk",
      hideExactLocation: true,
      contactName: "Admin Contact",
      contactPhone: "+971500000000",
      contactEmail: "admin.contact@example.com",
      allowCall: true,
      allowWhatsapp: false,
      allowEmail: true,
      seoTitle: "Bespoke SEO title",
      seoDescription: "Bespoke SEO description",
      detail: {
        bedrooms: 3,
        bathrooms: 4,
        halfBathrooms: 1,
        receptionRooms: 1,
        maidRooms: 1,
        parkingSpaces: 2,
        builtAreaSqft: 2100,
        builtAreaSqm: 195.1,
        plotAreaSqft: 3000,
        floorNumber: 14,
        totalFloors: 40,
        unitNumber: "1404",
        buildingName: "Marina Heights",
        yearBuilt: 2019,
        completionStatus: "ready",
        furnishing: "furnished",
        ownershipType: "freehold",
        viewType: "Sea and marina",
        rentPeriod: "yearly",
        chequesAccepted: 4,
        permitNumber: "DLD-99887",
        isNewBuild: false,
        isTenanted: true,
      },
    };

    const patched = await admin.send("patch", `/v1/admin/listings/${publicId}`, patch);
    expect(patched.status).toBe(200);

    const listing = (await admin.get(`/v1/admin/listings/${publicId}`)).body.data;
    expect(listing).toEqual(
      expect.objectContaining({
        purpose: "rent",
        title: "Admin edited title",
        subtitle: "Top floor, sea view",
        priceType: "negotiable",
        pricePeriod: "year",
        addressDisplayPrecision: "locality",
        bedrooms: 3,
        bathrooms: 4,
        halfBathrooms: 1,
        receptionRooms: 1,
        maidRooms: 1,
        parkingSpaces: 2,
        builtAreaSqft: 2100,
        floorNumber: 14,
        totalFloors: 40,
        unitNumber: "1404",
        buildingName: "Marina Heights",
        yearBuilt: 2019,
        furnishing: "furnished",
        ownershipType: "freehold",
        viewType: "Sea and marina",
        rentPeriod: "yearly",
        chequesAccepted: 4,
        permitNumber: "DLD-99887",
        isTenanted: true,
      })
    );
    expect(Number(listing.price?.amount)).toBe(185000);
    expect(listing.descriptionText).toContain("Rewritten by admin");
    expect(listing.contact).toEqual(
      expect.objectContaining({ name: "Admin Contact", allowCall: true, allowWhatsapp: false, allowEmail: true })
    );
    expect(listing.locationNames.city).toBeTruthy();

    const row = await queryOne(
      `SELECT half_bathrooms, reception_rooms, maid_rooms, is_tenanted, permit_number
         FROM listing_real_estate re JOIN listings l ON l.id = re.listing_id WHERE l.public_id = ?`,
      [publicId]
    );
    expect(row).toEqual(
      expect.objectContaining({ half_bathrooms: 1, reception_rooms: 1, maid_rooms: 1, is_tenanted: 1, permit_number: "DLD-99887" })
    );
  });
});
