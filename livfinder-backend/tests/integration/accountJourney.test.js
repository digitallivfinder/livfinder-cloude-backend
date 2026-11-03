import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { adminEmail, cleanupListings, cleanupUsers, client, ensureTestPassword, execute, query, queryOne } from "../helpers/testApp.js";
import { getStorage } from "../../src/config/storage.js";

/**
 * One person, start to finish: visitor, Member, individual seller, organization. Each stage
 * checks what that account may do and what it must be refused, and that nothing earned at one
 * stage is lost at the next.
 */
const suffix = `${Date.now()}`;
const email = `journey-${suffix}@example.test`;
const password = "Reasonable42";
const phone = () => `+9715${String(Math.floor(Math.random() * 1e8)).padStart(8, "0")}`;
let person = client();
const admin = client();
const listings = [];
let seeded;
let place;
let communityId;
let accountPublicId;
let accountId;
let userId;
let ownListing;

async function upload(documentType) {
  const presigned = await person.send("post", "/v1/accounts/verification/uploads/presign", {
    fileName: `${documentType}.pdf`, mimeType: "application/pdf", fileSizeBytes: 3, documentType,
  });
  expect(presigned.status, JSON.stringify(presigned.body)).toBe(200);
  const { uploadId } = presigned.body.data;
  await getStorage().put(uploadId, Buffer.from("pdf"), { contentType: "application/pdf", visibility: "private" });
  return { uploadId, documentType, fileName: `${documentType}.pdf` };
}

// The session read reissues the CSRF token, as it does for the website.
const memberType = async () => {
  const { data } = (await person.send("get", "/v1/auth/session")).body;
  person.csrfToken = data.csrfToken;
  return data.account.memberType;
};
const statusOf = async (path) => (await person.send("get", path)).status;
const newListing = (title) =>
  person.send("post", "/v1/portal/listings", {
    category: "real-estate", categorySlug: "villas", purpose: "sale", title, description: "Created by the account journey.",
    price: 9500000, currency: "AED", locationId: communityId, detail: { bedrooms: 4, bathrooms: 5, builtAreaSqft: 5400, furnishing: "furnished" },
  });

beforeAll(async () => {
  await ensureTestPassword();
  await admin.login(await adminEmail("super_admin"));
  await admin.stepUp();
  seeded = await queryOne("SELECT public_id, slug FROM listings WHERE status = 'active' AND deleted_at IS NULL LIMIT 1");
  const city = await queryOne("SELECT id, country_id FROM locations WHERE level = 'city' AND slug = 'dubai' LIMIT 1");
  place = { countryId: `country:${city.country_id}`, cityId: `city:${city.id}` };
  const community = await queryOne("SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1");
  communityId = `community:${community.id}`;
});

afterAll(async () => {
  await cleanupListings(listings);
  const user = await queryOne("SELECT id FROM users WHERE email_normalized = ?", [email]);
  if (user) {
    await execute("DELETE FROM reports WHERE reporter_user_id = ?", [user.id]);
    await execute("DELETE FROM saved_searches WHERE user_id = ?", [user.id]);
    await execute("DELETE FROM bookings WHERE user_id = ?", [user.id]);
    await execute("DELETE FROM organization_licenses WHERE organization_id IN (SELECT o.id FROM organizations o JOIN accounts a ON a.id = o.account_id WHERE a.owner_user_id = ?)", [user.id]);
  }
  await execute("DELETE FROM leads WHERE email = ?", [email]);
  await execute("DELETE FROM inquiries WHERE email = ?", [email]);
  await execute("DELETE FROM crm_contacts WHERE primary_email_normalized = ?", [email]);
  await cleanupUsers([email]);
});

describe("Visitor", () => {
  const visitor = client();

  it("browses without an account", async () => {
    expect((await visitor.get("/v1/public/listings", { limit: 1 })).status).toBe(200);
    expect((await visitor.get("/v1/public/country-codes")).status).toBe(200);
  });

  it("can send an enquiry with an email, which is kept for later", async () => {
    const response = await visitor.send("post", "/v1/inquiries", {
      listingId: seeded.public_id, name: "Journey Visitor", email, message: "Is this still available?",
    });
    expect(response.status).toBeLessThan(300);
  });

  it("is sent to sign in for everything that needs an account", async () => {
    expect((await visitor.send("post", "/v1/favourites", { listingId: seeded.public_id })).status).toBe(401);
    expect((await visitor.send("post", "/v1/reports", { listingId: seeded.public_id, reasons: ["spam"], details: "Looks wrong." })).status).toBe(401);
    expect((await visitor.send("post", "/v1/bookings", { listingId: seeded.public_id, scheduledStart: "2031-01-01T10:00:00Z" })).status).toBe(401);
    expect((await visitor.get("/v1/portal/dashboard")).status).toBe(401);
    expect((await visitor.get("/v1/accounts/seller-application")).status).toBe(401);
  });
});

describe("Member", () => {
  it("joins with the short signup", async () => {
    const response = await person.send("post", "/v1/accounts/member/signup", { name: "Journey Person", email, password, agreements: true });
    expect(response.status).toBe(201);
    person.csrfToken = response.body.data.csrfToken;
    expect(await memberType()).toBe("member");
    const user = await queryOne("SELECT id, default_account_id FROM users WHERE email_normalized = ?", [email]);
    userId = user.id;
    accountId = user.default_account_id;
    accountPublicId = (await queryOne("SELECT public_id FROM accounts WHERE id = ?", [accountId])).public_id;
  });

  it("does not see the earlier enquiry until the email is confirmed", async () => {
    expect((await person.send("get", "/v1/portal/my-enquiries")).body.data.items).toHaveLength(0);
    await execute("UPDATE users SET email_verified_at = NOW(3) WHERE id = ?", [userId]);
    person = client();
    await person.login(email, password);
    const items = (await person.send("get", "/v1/portal/my-enquiries")).body.data.items;
    expect(items).toHaveLength(1);
    expect(items[0].message).toBe("Is this still available?");
  });

  it("saves, searches, reports and asks for a viewing", async () => {
    expect((await person.send("post", "/v1/favourites", { listingId: seeded.public_id })).status).toBeLessThan(300);
    expect((await person.send("post", "/v1/saved-searches", { name: "Villas", category: "real-estate", purpose: "sale", filters: {} })).status).toBeLessThan(300);
    const reason = await queryOne("SELECT code FROM report_reasons WHERE is_active = 1 AND FIND_IN_SET('listing', applies_to) LIMIT 1");
    const report = await person.send("post", "/v1/reports", { listingId: seeded.public_id, reasons: [reason.code], details: "The price looks wrong here." });
    expect(report.status).toBeLessThan(300);
    expect((await person.send("post", "/v1/bookings", { listingId: seeded.public_id, scheduledStart: "2031-01-01T10:00:00Z" })).status).toBe(201);
    const viewings = (await person.send("get", "/v1/portal/my-viewings")).body.data;
    expect(viewings).toHaveLength(1);
    expect(viewings[0].status).toBe("requested");
  });

  it("uses its own pages", async () => {
    for (const path of ["/v1/portal/profile", "/v1/portal/settings/account", "/v1/portal/settings/notifications", "/v1/portal/settings/privacy", "/v1/portal/messages", "/v1/portal/calendar", "/v1/portal/saved-searches", "/v1/portal/favourites", "/v1/notifications"]) {
      expect(await statusOf(path), path).toBe(200);
    }
  });

  it("has no seller tools", async () => {
    for (const path of ["/v1/portal/listings", "/v1/portal/leads", "/v1/portal/bookings", "/v1/portal/inquiries", "/v1/portal/offers", "/v1/portal/reviews", "/v1/portal/categories", "/v1/portal/billing", "/v1/portal/payments", "/v1/portal/payouts", "/v1/portal/organization", "/v1/portal/agents", "/v1/portal/integrations", "/v1/portal/webhooks"]) {
      expect(await statusOf(path), path).toBe(403);
    }
    expect((await newListing("Member listing")).status).toBe(403);
  });
});

describe("Individual seller", () => {
  it("applies as a Member and keeps working while waiting", async () => {
    const response = await person.send("post", "/v1/accounts/seller-application", {
      accountType: "personal", phone: phone(), ...place, displayName: "Journey Person",
      bio: "<p>Ten years in <strong>waterfront</strong> homes.</p><ul><li>Dubai Marina</li></ul>", categoryId: "real-estate", documents: [await upload("identity")],
    });
    expect(response.status).toBe(201);
    expect(await memberType()).toBe("member");
    expect(await statusOf("/v1/portal/favourites")).toBe(200);
    expect(await statusOf("/v1/portal/listings")).toBe(403);
  });

  it("becomes an individual seller on approval", async () => {
    const detail = (await admin.get(`/v1/admin/individuals/${(await queryOne("SELECT public_id FROM users WHERE id = ?", [userId])).public_id}`)).body.data;
    expect(detail.verification.documents).toHaveLength(1);
    const decided = await admin.send("patch", `/v1/admin/individuals/${accountPublicId}/verification`, { decision: "approve" });
    expect(decided.status).toBe(200);
    expect(await memberType()).toBe("personal_seller");
  });

  it("is public from approval, with the bio as it was formatted", async () => {
    const agent = await queryOne("SELECT slug, status, verification_status, is_publicly_visible FROM agents WHERE user_id = ?", [userId]);
    expect(agent).toMatchObject({ status: "active", verification_status: "verified", is_publicly_visible: 1 });
    const response = await client().send("get", `/v1/public/agents/${agent.slug}`);
    expect(response.status).toBe(200);
    const profile = response.body.data.agent ?? response.body.data;
    expect(profile.biographyHtml).toContain("<strong>waterfront</strong>");
    expect(profile.biographyHtml).toContain("<li>Dubai Marina</li>");
    expect(profile.biography).toContain("Ten years in waterfront homes.");
  });

  it("has its seller tools and keeps what it had", async () => {
    for (const path of ["/v1/portal/listings", "/v1/portal/leads", "/v1/portal/bookings", "/v1/portal/inquiries", "/v1/portal/categories", "/v1/portal/billing", "/v1/portal/favourites", "/v1/portal/my-enquiries", "/v1/portal/my-viewings"]) {
      expect(await statusOf(path), path).toBe(200);
    }
    expect((await person.send("get", "/v1/portal/my-enquiries")).body.data.items).toHaveLength(1);
    expect(await queryOne("SELECT listing_id FROM favourites WHERE user_id = ?", [userId])).toBeTruthy();
  });

  it("creates a listing in its approved category, and only there", async () => {
    const response = await newListing(`Journey Villa ${suffix}`);
    expect(response.status, JSON.stringify(response.body)).toBe(201);
    ownListing = response.body.data.id;
    listings.push(ownListing);
    const row = await queryOne("SELECT organization_id, account_id FROM listings WHERE public_id = ?", [ownListing]);
    expect(row.organization_id).toBeNull();
    const hidden = await queryOne("SELECT slug, canonical_path FROM listings WHERE public_id = ?", [ownListing]);
    expect((await client().send("get", `/v1/public/listings/${ownListing}`)).status).toBe(404);
    const submitted = await person.send("patch", `/v1/portal/listings/${ownListing}/status`, { status: "pending_review" });
    expect(submitted.status, JSON.stringify(submitted.body)).toBe(200);
    expect((await person.send("patch", `/v1/portal/listings/${ownListing}/status`, { status: "active" })).status).toBe(403);
    expect((await client().send("get", `/v1/public/listings/${ownListing}`)).status).toBe(404);
    const approved = await admin.send("patch", `/v1/admin/listings/${ownListing}/moderation`, { decision: "approve" });
    expect(approved.status, JSON.stringify(approved.body)).toBe(200);
    const live = await client().send("get", `/v1/public/listings/${ownListing}`);
    expect(live.status, JSON.stringify(hidden)).toBe(200);
    const refused = await person.send("post", "/v1/portal/listings", { category: "yachts", purpose: "sale", title: "Wrong category", description: "x", price: 1, currency: "AED", locationId: communityId, detail: {} });
    expect(refused.status).toBe(403);
  });

  it("has no company tools", async () => {
    expect(await statusOf("/v1/portal/organization")).toBe(403);
    const status = (await person.send("get", "/v1/accounts/seller-application")).body.data;
    expect(status.isMember).toBe(false);
    expect(status.canUpgrade).toBe(true);
    expect(status.application).toBeNull();
  });

  it("cannot apply to be an individual again", async () => {
    const response = await person.send("post", "/v1/accounts/seller-application", {
      accountType: "personal", phone: phone(), ...place, displayName: "Twice", bio: "<p>Applying a second time.</p>", categoryId: "real-estate", documents: [await upload("identity")],
    });
    expect(response.status).toBe(409);
  });
});

describe("Individual to organization", () => {
  let organizationPublicId;
  const body = async () => ({
    accountType: "organization", phone: phone(), ...place, legalName: `Journey Homes ${suffix} LLC`, publicName: `Journey Homes ${suffix}`,
    organizationType: "agency", registrationNumber: `REG-J-${suffix}`, organizationEmail: "hello@example.test", organizationPhone: phone(),
    address: "Office 12, Marina Plaza, Dubai", description: "<p>A boutique agency.</p>", categoryId: "yachts",
    documents: [await upload("identity"), await upload("organization_registration")],
  });

  it("applies and keeps selling while waiting", async () => {
    expect((await person.send("post", "/v1/accounts/seller-application", await body())).status).toBe(201);
    expect(await memberType()).toBe("personal_seller");
    expect(await statusOf("/v1/portal/listings")).toBe(200);
    const edit = await person.send("patch", `/v1/portal/listings/${ownListing}`, { title: `Journey Villa ${suffix} updated` });
    expect(edit.status).toBeLessThan(300);
    expect((await person.send("get", "/v1/accounts/seller-application")).body.data.application.status).toBe("pending");
    expect((await person.send("post", "/v1/accounts/seller-application", await body())).status).toBe(409);
    const waiting = await newListing(`Journey Waiting Villa ${suffix}`);
    expect(waiting.status).toBe(201);
    listings.push(waiting.body.data.id);
    const row = await queryOne("SELECT organization_id FROM listings WHERE public_id = ?", [waiting.body.data.id]);
    expect(row.organization_id).toBeNull();
  });

  it("stays an individual when rejected, and can apply again", async () => {
    const organization = await queryOne("SELECT public_id, is_publicly_visible FROM organizations WHERE account_id = ?", [accountId]);
    organizationPublicId = organization.public_id;
    expect(organization.is_publicly_visible).toBe(0);
    const rejected = await admin.send("patch", `/v1/admin/companies/${organizationPublicId}/verification`, { decision: "reject", reason: "Licence expired" });
    expect(rejected.status).toBe(200);
    expect(await memberType()).toBe("personal_seller");
    expect(await statusOf("/v1/portal/listings")).toBe(200);
    const account = await queryOne("SELECT status FROM accounts WHERE id = ?", [accountId]);
    expect(account.status).toBe("active");
    expect((await person.send("get", "/v1/accounts/seller-application")).body.data.application.rejectionReason).toBe("Licence expired");
    expect((await person.send("post", "/v1/accounts/seller-application", await body())).status).toBe(201);
  });

  it("becomes an organization and brings everything with it", async () => {
    const decided = await admin.send("patch", `/v1/admin/companies/${organizationPublicId}/verification`, { decision: "approve" });
    expect(decided.status).toBe(200);
    expect(await memberType()).toBe("organization");

    const organization = await queryOne("SELECT id, status, verification_status, is_publicly_visible, listing_count, agent_count FROM organizations WHERE public_id = ?", [organizationPublicId]);
    expect(organization).toMatchObject({ status: "active", verification_status: "verified", is_publicly_visible: 1 });
    expect(Number(organization.listing_count)).toBe(2);
    expect(Number(organization.agent_count)).toBe(1);

    const listing = await queryOne("SELECT organization_id, account_id FROM listings WHERE public_id = ?", [ownListing]);
    expect(String(listing.organization_id)).toBe(String(organization.id));
    expect(String(listing.account_id)).toBe(String(accountId));
    const agent = await queryOne("SELECT organization_id FROM agents WHERE user_id = ?", [userId]);
    expect(String(agent.organization_id)).toBe(String(organization.id));

    const grants = await query(
      "SELECT c.slug FROM account_category_access aca JOIN categories c ON c.id = aca.category_id WHERE aca.account_id = ? AND aca.status = 'approved'",
      [accountId]
    );
    expect(grants.length).toBe(2);
  });

  it("has company tools and keeps its history", async () => {
    for (const path of ["/v1/portal/organization", "/v1/portal/listings", "/v1/portal/leads", "/v1/portal/bookings", "/v1/portal/favourites", "/v1/portal/my-enquiries", "/v1/portal/my-viewings"]) {
      expect(await statusOf(path), path).toBe(200);
    }
    const mine = (await person.send("get", "/v1/portal/listings", { pageSize: 50 })).body.data;
    expect(mine.map((row) => row.id)).toContain(ownListing);
    expect((await person.send("get", "/v1/portal/my-enquiries")).body.data.items).toHaveLength(1);
    const second = await newListing(`Journey Company Villa ${suffix}`);
    expect(second.status).toBe(201);
    listings.push(second.body.data.id);
    const row = await queryOne("SELECT organization_id FROM listings WHERE public_id = ?", [second.body.data.id]);
    expect(row.organization_id).not.toBeNull();
  });

  it("moves in admin from Individuals to Companies", async () => {
    const company = (await admin.get(`/v1/admin/companies/${organizationPublicId}`)).body.data;
    expect(company.owner.email).toBe(email);
    expect(company.status).toBe("active");
    const user = await queryOne("SELECT public_id FROM users WHERE id = ?", [userId]);
    expect((await admin.get(`/v1/admin/individuals/${user.public_id}`)).status).toBe(404);
  });

  it("is told it cannot apply any more", async () => {
    const status = (await person.send("get", "/v1/accounts/seller-application")).body.data;
    expect(status.isMember).toBe(false);
    expect(status.canUpgrade).toBe(false);
    expect((await person.send("post", "/v1/accounts/seller-application", await body())).status).toBe(409);
  });

  it("is still the same login", async () => {
    const again = client();
    expect((await again.login(email, password)).status).toBe(200);
    expect((await again.send("get", "/v1/auth/session")).body.data.account.memberType).toBe("organization");
  });
});
