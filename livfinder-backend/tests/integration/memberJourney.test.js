import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from "vitest";

const google = vi.hoisted(() => ({ calls: [], refresh: { ok: true } }));
vi.mock("../../src/utils/safeFetch.js", async (original) => ({
  ...(await original()),
  safeFetch: async (url, options = {}) => {
    const method = options.method ?? "GET";
    google.calls.push({ url: String(url), method, body: options.body ? String(options.body) : null });
    const json = (status, body) => new Response(JSON.stringify(body), { status });
    if (String(url).includes("oauth2.googleapis.com/token")) {
      if (String(options.body).includes("grant_type=authorization_code")) {
        return json(200, {
          access_token: "at",
          refresh_token: "rt-secret",
          scope: "openid email https://www.googleapis.com/auth/calendar.events",
        });
      }
      return google.refresh.ok ? json(200, { access_token: "at" }) : json(400, { error: "invalid_grant" });
    }
    if (String(url).includes("/userinfo")) return json(200, google.profile ?? { email: "calendar@example.test" });
    if (String(url).includes("/revoke")) return json(200, {});
    if (method === "POST") return json(200, { id: "evt-1" });
    return json(200, {});
  },
}));

import { client, cleanupUsers, createDisposablePortalOwner, ensureTestPassword, adminEmail, execute, query, queryOne } from "../helpers/testApp.js";
import { clearSentMessages, sentMessages } from "../../src/modules/system/mail.service.js";
import { isEncrypted } from "../../src/utils/secrets.js";
import * as calendar from "../../src/modules/calendar/calendar.service.js";
import { upsertOAuthIdentity } from "../../src/modules/auth/auth.service.js";
import { getStorage } from "../../src/config/storage.js";

const suffix = `${Date.now()}`;
const created = [];
const email = (name) => {
  const value = `${name}-${suffix}@example.test`;
  created.push(value);
  return value;
};
const uniquePhone = () => `+9715${String(Math.floor(Math.random() * 1e8)).padStart(8, "0")}`;
const password = "Reasonable42";

async function member(name) {
  const address = email(name);
  const person = client();
  const response = await person.send("post", "/v1/accounts/member/signup", { name: "Mia Member", email: address, password, agreements: true });
  expect(response.status).toBe(201);
  // The session and token signup itself returns, which is what the website goes on to use.
  person.csrfToken = response.body.data.csrfToken;
  return { person, address };
}

async function confirm(address) {
  await execute("UPDATE users SET email_verified_at = NOW(3) WHERE email_normalized = ?", [address]);
}

async function uploadFor(person, documentType) {
  const presigned = await person.send("post", "/v1/accounts/verification/uploads/presign", {
    fileName: `${documentType}.pdf`, mimeType: "application/pdf", fileSizeBytes: 3, documentType,
  });
  expect(presigned.body.error, JSON.stringify(presigned.body)).toBeUndefined();
  const { uploadId } = presigned.body.data;
  await getStorage().put(uploadId, Buffer.from("pdf"), { contentType: "application/pdf", visibility: "private" });
  return { uploadId, documentType, fileName: `${documentType}.pdf` };
}

const location = async () => {
  const city = await queryOne("SELECT id, country_id FROM locations WHERE level = 'city' AND slug = 'dubai' LIMIT 1");
  return { countryId: `country:${city.country_id}`, cityId: `city:${city.id}` };
};

let admin;
beforeAll(async () => {
  await ensureTestPassword();
  admin = client();
  await admin.login(await adminEmail("super_admin"));
  await admin.stepUp();
});

afterAll(async () => {
  const rows = await query(`SELECT id FROM users WHERE email_normalized IN (${created.map(() => "?").join(",") || "''"})`, created);
  for (const row of rows) await execute("DELETE FROM organization_licenses WHERE organization_id IN (SELECT o.id FROM organizations o JOIN accounts a ON a.id = o.account_id WHERE a.owner_user_id = ?)", [row.id]);
  await cleanupUsers(created);
});

beforeEach(() => {
  google.calls.length = 0;
  google.refresh.ok = true;
  clearSentMessages();
});

describe("Member signup", () => {
  it("opens an account straight away with no review", async () => {
    const { person, address } = await member("instant");
    const session = (await person.send("get", "/v1/auth/session")).body.data;
    expect(session.account.memberType).toBe("member");
    expect(session.account.state).toBe("active");
    const user = await queryOne("SELECT status, email_verified_at FROM users WHERE email_normalized = ?", [address]);
    expect(user.status).toBe("active");
    expect(user.email_verified_at).toBeNull();
  });

  it("gives a Member their own things and no seller tools", async () => {
    const { person } = await member("scope");
    for (const path of ["/v1/portal/my-enquiries", "/v1/portal/my-viewings", "/v1/portal/calendar", "/v1/portal/profile"]) {
      expect((await person.send("get", path)).status, path).toBe(200);
    }
    for (const path of ["/v1/portal/listings", "/v1/portal/leads", "/v1/portal/bookings", "/v1/portal/inquiries", "/v1/portal/billing", "/v1/portal/payouts", "/v1/portal/integrations"]) {
      expect((await person.send("get", path)).status, path).toBe(403);
    }
  });

  it("refuses a used email and a weak password", async () => {
    const { address } = await member("taken");
    const again = await client().send("post", "/v1/accounts/member/signup", { name: "Someone", email: address, password, agreements: true });
    expect(again.status).toBe(409);
    const weak = await client().send("post", "/v1/accounts/member/signup", { name: "Someone", email: email("weak"), password: "password1234", agreements: true });
    expect(weak.status).toBe(422);
  });
});

describe("Enquiries by email", () => {
  it("links earlier enquiries only after the address is confirmed", async () => {
    const { person, address } = await member("claims");
    const listing = await queryOne("SELECT id FROM listings WHERE deleted_at IS NULL LIMIT 1");
    await execute(
      "INSERT INTO inquiries (public_id, reference, listing_id, name, email, message, created_at) VALUES (?, ?, ?, 'Mia', ?, 'Earlier', NOW(3))",
      [`Q${suffix}`.padEnd(26, "0").slice(0, 26), `QA-${suffix}`, listing.id, address]
    );
    expect((await person.send("get", "/v1/portal/my-enquiries")).body.data.items).toHaveLength(0);
    await confirm(address);
    const again = client();
    await again.login(address, password);
    const items = (await again.send("get", "/v1/portal/my-enquiries")).body.data.items;
    expect(items).toHaveLength(1);
    await execute("DELETE FROM inquiries WHERE reference = ?", [`QA-${suffix}`]);
  });
});

describe("Social sign-in", () => {
  it("creates a Member for a new verified address", async () => {
    const address = email("social");
    const { userId } = await upsertOAuthIdentity({ provider: "google", subject: `g-${suffix}`, email: address, emailVerified: true, displayName: "Sam Social" });
    const account = await queryOne(
      `SELECT t.code FROM accounts a JOIN account_types t ON t.id = a.account_type_id WHERE a.owner_user_id = ?`,
      [userId]
    );
    expect(account.code).toBe("personal");
    await execute("DELETE FROM user_identities WHERE user_id = ?", [userId]);
  });

  it("refuses an address the provider has not verified", async () => {
    await expect(
      upsertOAuthIdentity({ provider: "google", subject: `g2-${suffix}`, email: email("unverified"), emailVerified: false })
    ).rejects.toMatchObject({ code: "EMAIL_NOT_VERIFIED" });
  });

  it("locks out whoever set a password on an unconfirmed address", async () => {
    const { address } = await member("squat");
    const { userId } = await upsertOAuthIdentity({ provider: "google", subject: `g3-${suffix}`, email: address, emailVerified: true, displayName: "Owner" });
    expect((await client().login(address, password)).status).toBe(401);
    await execute("DELETE FROM user_identities WHERE user_id = ?", [userId]);
  });
});

describe("Selling through a social button", () => {
  const start = async (person, query) => {
    const response = await person.agent.get(`/v1/auth/oauth/google?returnTo=%2Fportal%2Fbecome-seller&${query}`);
    return { response, state: new URL(response.headers.location).searchParams.get("state") };
  };

  beforeEach(() => {
    process.env.OAUTH_GOOGLE_CLIENT_ID = "client";
    process.env.OAUTH_GOOGLE_CLIENT_SECRET = "secret";
  });

  it("creates the account, keeps the chosen type, and asks for the details until they are sent", async () => {
    const address = email("social-seller");
    google.profile = { sub: `seller-${suffix}`, email: address, email_verified: true, name: "Sana Malik" };
    const person = client();
    const { state } = await start(person, "sellerType=organization");
    const landed = await person.agent.get(`/v1/auth/oauth/google/callback?code=c&state=${state}`);
    expect(landed.headers.location).toMatch(/\/portal\/become-seller$/);

    const session = (await person.send("get", "/v1/auth/session")).body.data;
    person.csrfToken = session.csrfToken;
    expect(session.account).toMatchObject({ memberType: "member", state: "active", sellerProfileRequired: true });
    const status = (await person.send("get", "/v1/accounts/seller-application")).body.data;
    expect(status).toMatchObject({ emailConfirmed: true, sellerIntent: "organization" });
    expect(status.prefill.name).toBe("Sana Malik");

    // Skipping leaves a working Member.
    expect((await person.send("get", "/v1/portal/my-enquiries")).status).toBe(200);
    const sent = await person.send("post", "/v1/accounts/seller-application", {
      accountType: "personal", phone: uniquePhone(), ...(await location()), displayName: "Sana Malik",
      bio: "<p>Ten years in waterfront homes.</p>", categoryId: "cars", documents: [await uploadFor(person, "identity")],
    });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    expect((await person.send("get", "/v1/auth/session")).body.data.account.sellerProfileRequired).toBe(false);
    await execute("DELETE FROM user_identities WHERE provider_uid = ?", [`seller-${suffix}`]);
  });

  it("does not ask an ordinary Member for anything", async () => {
    const address = email("social-member");
    google.profile = { sub: `member-${suffix}`, email: address, email_verified: true, name: "Omar Member" };
    const person = client();
    const { state } = await start(person, "");
    await person.agent.get(`/v1/auth/oauth/google/callback?code=c&state=${state}`);
    const session = (await person.send("get", "/v1/auth/session")).body.data;
    expect(session.account).toMatchObject({ memberType: "member", sellerProfileRequired: false });
    await execute("DELETE FROM user_identities WHERE provider_uid = ?", [`member-${suffix}`]);
  });

  it("returns a cancelled seller to the seller signup", async () => {
    const person = client();
    await start(person, "sellerType=personal");
    const back = await person.agent.get("/v1/auth/oauth/google/callback?error=access_denied");
    expect(back.headers.location).toMatch(/\/signup\?oauth=cancelled$/);
  });

  afterAll(() => {
    delete process.env.OAUTH_GOOGLE_CLIENT_ID;
    delete process.env.OAUTH_GOOGLE_CLIENT_SECRET;
    google.profile = null;
  });

  it("leaves an existing seller's account alone", async () => {
    const owner = await createDisposablePortalOwner();
    created.push(owner.email);
    await upsertOAuthIdentity({ provider: "google", subject: `owner-${suffix}`, email: owner.email, emailVerified: true, sellerType: "organization" });
    const row = await queryOne("SELECT seller_intent FROM accounts WHERE owner_user_id = ?", [owner.id]);
    expect(row.seller_intent).toBeNull();
    await execute("DELETE FROM user_identities WHERE provider_uid = ?", [`owner-${suffix}`]);
  });
});

describe("Becoming a seller", () => {
  const application = async (person, overrides = {}) => ({
    accountType: "personal",
    phone: uniquePhone(),
    ...(await location()),
    displayName: "Mia Seller",
    bio: "<p>Ten years in waterfront homes.</p>",
    categoryId: "cars",
    documents: [await uploadFor(person, "identity")],
    ...overrides,
  });

  it("needs a confirmed email", async () => {
    const { person } = await member("unconfirmed-seller");
    const response = await person.send("post", "/v1/accounts/seller-application", await application(person));
    expect(response.status).toBe(403);
    expect(response.body.error.code).toBe("EMAIL_NOT_VERIFIED");
  });

  it("keeps the Member working, then upgrades the same account with the chosen category", async () => {
    const { person, address } = await member("personal-seller");
    await confirm(address);
    expect((await person.send("post", "/v1/accounts/seller-application", await application(person))).status).toBe(201);

    expect((await person.send("get", "/v1/portal/my-enquiries")).status).toBe(200);
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(403);
    expect((await person.send("post", "/v1/accounts/seller-application", await application(person))).status).toBe(409);

    const user = await queryOne("SELECT id, default_account_id FROM users WHERE email_normalized = ?", [address]);
    const account = await queryOne("SELECT public_id FROM accounts WHERE id = ?", [user.default_account_id]);
    const decided = await admin.send("patch", `/v1/admin/individuals/${account.public_id}/verification`, { decision: "approve" });
    expect(decided.status).toBe(200);

    const session = (await person.send("get", "/v1/auth/session")).body.data;
    expect(session.account.memberType).toBe("personal_seller");
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(200);
    const grant = await queryOne(
      "SELECT c.slug, aca.status FROM account_category_access aca JOIN categories c ON c.id = aca.category_id WHERE aca.account_id = ?",
      [user.default_account_id]
    );
    expect(grant.status).toBe("approved");
    expect(grant.slug).toMatch(/car/);
  });

  it("leaves a rejected applicant a working Member who can reapply", async () => {
    const { person, address } = await member("rejected-seller");
    await confirm(address);
    await person.send("post", "/v1/accounts/seller-application", await application(person));
    const user = await queryOne("SELECT default_account_id FROM users WHERE email_normalized = ?", [address]);
    const account = await queryOne("SELECT public_id, status FROM accounts WHERE id = ?", [user.default_account_id]);
    await admin.send("patch", `/v1/admin/individuals/${account.public_id}/verification`, { decision: "reject", reason: "Unclear document" });

    expect((await person.send("get", "/v1/portal/my-enquiries")).status).toBe(200);
    const status = (await person.send("get", "/v1/accounts/seller-application")).body.data;
    expect(status.application.status).toBe("rejected");
    expect(status.application.rejectionReason).toBe("Unclear document");
    expect((await person.send("post", "/v1/accounts/seller-application", await application(person))).status).toBe(201);
  });

  it("upgrades an organization and refuses its registration number elsewhere", async () => {
    const { person, address } = await member("org-seller");
    await confirm(address);
    const registrationNumber = `REG-${suffix}`;
    const body = await application(person, {
      accountType: "organization",
      displayName: undefined,
      bio: undefined,
      legalName: "Mia Holdings LLC",
      publicName: `Mia Holdings ${suffix}`,
      organizationType: "agency",
      registrationNumber,
      organizationEmail: "hello@example.test",
      organizationPhone: uniquePhone(),
      address: "Office 12, Marina Plaza, Dubai",
      description: "<p>A boutique agency.</p>",
      categoryId: "yachts",
      documents: [await uploadFor(person, "identity"), await uploadFor(person, "organization_registration")],
    });
    expect((await person.send("post", "/v1/accounts/seller-application", body)).status).toBe(201);

    const rival = await member("org-rival");
    await confirm(rival.address);
    const copy = { ...body, phone: uniquePhone(), documents: [await uploadFor(rival.person, "identity"), await uploadFor(rival.person, "organization_registration")] };
    const refused = await rival.person.send("post", "/v1/accounts/seller-application", copy);
    expect(refused.status).toBe(409);
    expect(refused.body.error.fields.registrationNumber).toBeTruthy();

    const organization = await queryOne(
      "SELECT o.public_id FROM organizations o JOIN accounts a ON a.id = o.account_id JOIN users u ON u.id = a.owner_user_id WHERE u.email_normalized = ?",
      [address]
    );
    expect((await admin.send("patch", `/v1/admin/companies/${organization.public_id}/verification`, { decision: "approve" })).status).toBe(200);
    const session = (await person.send("get", "/v1/auth/session")).body.data;
    expect(session.account.memberType).toBe("organization");
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(200);
  });
});

describe("Viewing calendars", () => {
  async function booking(owner, customerId) {
    const account = await queryOne("SELECT default_account_id FROM users WHERE id = ?", [owner.id]);
    const result = await execute(
      `INSERT INTO bookings (public_id, reference, user_id, account_id, booking_type, status, scheduled_start, scheduled_end, contact_name, contact_email, currency_code, created_at)
       VALUES (?, ?, ?, ?, 'viewing', 'requested', '2030-01-10 09:00:00', '2030-01-10 10:00:00', 'Cara Customer', 'cara@example.test', 'AED', NOW(3))`,
      [`B${Date.now()}`.padEnd(26, "0").slice(0, 26), `BK-Q${Date.now()}`, customerId, account.default_account_id]
    );
    return result.insertId;
  }
  const setStatus = (id, status) => execute("UPDATE bookings SET status = ? WHERE id = ?", [status, id]);

  it("emails both sides an invite when a viewing is confirmed, and takes it back on cancellation", async () => {
    const owner = await createDisposablePortalOwner();
    created.push(owner.email);
    clearSentMessages();
    const id = await booking(owner, null);
    await setStatus(id, "confirmed");
    await calendar.publishBookingChange(id, { previousStatus: "requested" });

    const invites = sentMessages();
    expect(invites.map((message) => message.to).sort()).toEqual(["cara@example.test", owner.email].sort());
    expect(invites[0].attachments[0].content).toContain("METHOD:REQUEST");
    const seller = invites.find((message) => message.to === owner.email);
    expect(seller.attachments[0].content).toContain("Cara Customer");
    const customer = invites.find((message) => message.to === "cara@example.test");
    expect(customer.attachments[0].content).not.toContain(owner.email);

    clearSentMessages();
    await setStatus(id, "cancelled");
    await calendar.publishBookingChange(id, { previousStatus: "confirmed" });
    expect(sentMessages()).toHaveLength(2);
    expect(sentMessages()[0].attachments[0].content).toContain("METHOD:CANCEL");
    await execute("DELETE FROM bookings WHERE id = ?", [id]);
  });

  it("sends nothing for a request that was never confirmed", async () => {
    const owner = await createDisposablePortalOwner();
    created.push(owner.email);
    clearSentMessages();
    const id = await booking(owner, null);
    await setStatus(id, "cancelled");
    await calendar.publishBookingChange(id, { previousStatus: "requested" });
    expect(sentMessages()).toHaveLength(0);
    await execute("DELETE FROM bookings WHERE id = ?", [id]);
  });

  it("stores only an encrypted token, syncs the event, and stops cleanly when access ends", async () => {
    const owner = await createDisposablePortalOwner();
    created.push(owner.email);
    process.env.OAUTH_GOOGLE_CLIENT_ID = "client";
    process.env.OAUTH_GOOGLE_CLIENT_SECRET = "secret";
    await calendar.completeConnection({ userId: owner.id, code: "code", redirectUri: "http://localhost/cb" });
    const row = await queryOne("SELECT refresh_token_enc FROM calendar_connections WHERE user_id = ?", [owner.id]);
    expect(isEncrypted(row.refresh_token_enc)).toBe(true);
    expect(row.refresh_token_enc).not.toContain("rt-secret");

    const id = await booking(owner, null);
    await setStatus(id, "confirmed");
    await calendar.publishBookingChange(id, { previousStatus: "requested" });
    expect(google.calls.some((call) => call.method === "POST" && call.url.endsWith("/events"))).toBe(true);
    expect(await queryOne("SELECT external_event_id FROM booking_calendar_events WHERE booking_id = ?", [id])).toMatchObject({ external_event_id: "evt-1" });

    google.calls.length = 0;
    await execute("UPDATE bookings SET scheduled_start = '2030-01-11 09:00:00' WHERE id = ?", [id]);
    await calendar.publishBookingChange(id, { previousStatus: "confirmed", previousStart: "2030-01-10T09:00:00Z" });
    expect(google.calls.some((call) => call.method === "PATCH" && call.url.includes("evt-1"))).toBe(true);

    google.calls.length = 0;
    await setStatus(id, "cancelled");
    await calendar.publishBookingChange(id, { previousStatus: "confirmed" });
    expect(google.calls.some((call) => call.method === "DELETE" && call.url.includes("evt-1"))).toBe(true);
    expect(await queryOne("SELECT id FROM booking_calendar_events WHERE booking_id = ?", [id])).toBeFalsy();

    google.refresh.ok = false;
    await setStatus(id, "confirmed");
    await calendar.publishBookingChange(id, { previousStatus: "requested" });
    expect((await calendar.connectionStatus(owner.id)).needsReconnect).toBe(true);

    await calendar.disconnect(owner.id);
    expect(await queryOne("SELECT id FROM calendar_connections WHERE user_id = ?", [owner.id])).toBeFalsy();
    await execute("DELETE FROM bookings WHERE id = ?", [id]);
    delete process.env.OAUTH_GOOGLE_CLIENT_ID;
    delete process.env.OAUTH_GOOGLE_CLIENT_SECRET;
  });

});
