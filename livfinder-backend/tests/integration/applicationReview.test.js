import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { adminEmail, cleanupListings, cleanupUsers, client, createDisposablePortalOwner, ensureTestPassword, execute, organizationSignup, personalSignup, queryOne } from "../helpers/testApp.js";
import { getStorage } from "../../src/config/storage.js";
import { closePool } from "../../src/db/pool.js";
import { clearSentMessages, sentMessages } from "../../src/modules/system/mail.service.js";

/**
 * The admin's side of every way in: find the application, read it, decide it, and what the
 * applicant then has. Each kind of application is created through the real signup route.
 */
const suffix = Date.now();
const password = "Harbour-view-2049";
const emails = [];
const listings = [];
const admin = client();
const PNG = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==", "base64");
const phone = () => `+9715${String(Math.floor(Math.random() * 1e8)).padStart(8, "0")}`;
const address = (name) => {
  const email = `review-${name}-${suffix}@example.test`;
  emails.push(email);
  return email;
};

async function place() {
  const city = await queryOne("SELECT id, country_id FROM locations WHERE level = 'city' AND slug = 'dubai' LIMIT 1");
  return { countryId: `country:${city.country_id}`, cityId: `city:${city.id}` };
}

async function anonymousUpload(documentType, fileName = `${documentType}.png`) {
  const presigned = await client().send("post", "/v1/accounts/verification/uploads/signup-presign", {
    fileName, mimeType: "image/png", fileSizeBytes: PNG.length, documentType,
  });
  expect(presigned.status, JSON.stringify(presigned.body)).toBe(200);
  await getStorage().put(presigned.body.data.uploadId, PNG, { contentType: "image/png", visibility: "private" });
  return { uploadId: presigned.body.data.uploadId, documentType, fileName };
}

async function upload(person, documentType) {
  const presigned = await person.send("post", "/v1/accounts/verification/uploads/presign", {
    fileName: `${documentType}.png`, mimeType: "image/png", fileSizeBytes: PNG.length, documentType,
  });
  expect(presigned.status, JSON.stringify(presigned.body)).toBe(200);
  await getStorage().put(presigned.body.data.uploadId, PNG, { contentType: "image/png", visibility: "private" });
  return { uploadId: presigned.body.data.uploadId, documentType, fileName: `${documentType}.png` };
}

async function member(name) {
  const email = address(name);
  const person = client();
  const response = await person.send("post", "/v1/accounts/member/signup", { name: "Mia Member", email, password, agreements: true });
  expect(response.status).toBe(201);
  person.csrfToken = response.body.data.csrfToken;
  await execute("UPDATE users SET email_verified_at = NOW(3) WHERE email_normalized = ?", [email]);
  return { person, email };
}

async function directIndividual(name) {
  const email = address(name);
  const documents = [await anonymousUpload("identity"), await anonymousUpload("profile_photo")];
  const response = await client().send("post", "/v1/accounts/personal/signup", {
    ...personalSignup(), firstName: "Dana", lastName: "Direct", email, password, confirmPassword: password, agreements: true,
    ...(await place()), displayName: `Dana Direct ${name} ${suffix}`, bio: "<p>Ten years in <strong>waterfront</strong> homes.</p>", categoryId: "cars", documents,
  });
  expect(response.status, JSON.stringify(response.body)).toBe(201);
  return email;
}

async function directCompany(name) {
  const email = address(name);
  const documents = [await anonymousUpload("identity"), await anonymousUpload("organization_registration"), await anonymousUpload("organization_logo")];
  const response = await client().send("post", "/v1/accounts/organization/signup", {
    ...organizationSignup(), firstName: "Omar", lastName: "Owner", email, password, confirmPassword: password, agreements: true,
    ...(await place()), legalName: `Review ${name} ${suffix} LLC`, publicName: `Review ${name} ${suffix}`,
    registrationNumber: `RV-${name}-${suffix}`.slice(0, 40), organizationEmail: email, description: "<p>Selling <em>homes</em> across Dubai since 2010.</p>", categoryId: "realEstate", documents,
  });
  expect(response.status, JSON.stringify(response.body)).toBe(201);
  return email;
}

const accountOf = (email) =>
  queryOne(
    `SELECT a.id, a.public_id, a.status, a.verification_status, t.code, u.public_id AS user_public_id, u.id AS user_id
       FROM users u JOIN accounts a ON a.id = u.default_account_id JOIN account_types t ON t.id = a.account_type_id
      WHERE u.email_normalized = ?`,
    [email]
  );
const companyOf = (accountId) => queryOne("SELECT * FROM organizations WHERE account_id = ?", [accountId]);
const decide = (kind, id, body) => admin.send("patch", `/v1/admin/${kind}/${id}/verification`, body);
const listed = async (kind, query) => {
  const { body } = await admin.send("get", `/v1/admin/${kind}?${query}&pageSize=50`);
  return { data: body.items ?? body.data?.items ?? body.data, summary: body.summary ?? body.data?.summary };
};
const confirmEmail = (email) =>
  execute("UPDATE users SET email_verified_at = NOW(3), status = 'active' WHERE email_normalized = ?", [email]);
const signIn = async (email) => {
  const person = client();
  expect((await person.login(email, password)).status).toBe(200);
  return person;
};

beforeAll(async () => {
  await ensureTestPassword();
  await admin.login(await adminEmail("super_admin"));
  await admin.stepUp();
});

afterAll(async () => {
  await cleanupListings(listings);
  await cleanupUsers(emails);
  await closePool();
});

describe("Individual who signed up to sell", () => {
  let email;
  let account;

  it("is in the Individuals pending list with what was sent", async () => {
    email = await directIndividual("direct");
    account = await accountOf(email);
    const { data } = await listed("individuals", `status=pending&search=${encodeURIComponent(email)}`);
    expect(data.map((row) => row.email)).toContain(email);
    const detail = (await admin.send("get", `/v1/admin/individuals/${account.user_public_id}`)).body.data;
    expect(detail.verification.status).toBe("pending");
    expect(detail.verification.documents.map((row) => row.documentType).sort()).toEqual(["identity", "profile_photo"]);
    expect(detail.bio).toContain("<strong>waterfront</strong>");
  });

  it("opens a document for the reviewer, and for nobody else", async () => {
    const detail = (await admin.send("get", `/v1/admin/individuals/${account.user_public_id}`)).body.data;
    const id = detail.verification.documents[0].id;
    const read = await admin.send("get", `/v1/media/verification-documents/${id}`);
    expect(read.status).toBe(200);
    expect(read.headers["content-type"]).toContain("image/png");
    expect((await client().send("get", `/v1/media/verification-documents/${id}`)).status).toBe(401);
    const stranger = await createDisposablePortalOwner({ prefix: "review-stranger" });
    emails.push(stranger.email);
    const other = client();
    await other.login(stranger.email, "LivFinder!2026");
    expect((await other.send("get", `/v1/media/verification-documents/${id}`)).status).toBe(403);
  });

  it("approves into a working seller with a public profile, photo and category", async () => {
    await confirmEmail(email);
    clearSentMessages();
    expect((await decide("individuals", account.public_id, { decision: "approve" })).status).toBe(200);
    expect(sentMessages().some((mail) => mail.to === email && /verified/i.test(mail.subject))).toBe(true);
    expect(await accountOf(email)).toMatchObject({ status: "active", verification_status: "verified", code: "lister" });
    const person = await signIn(email);
    expect((await person.send("get", "/v1/auth/session")).body.data.account.memberType).toBe("personal_seller");
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(200);
    const grant = await queryOne("SELECT aca.status FROM account_category_access aca WHERE aca.account_id = ?", [account.id]);
    expect(grant.status).toBe("approved");
    const agent = await queryOne("SELECT slug, photo_url FROM agents WHERE user_id = ?", [account.user_id]);
    expect(agent.photo_url, "profile photo from signup").toBeTruthy();
    expect((await client().send("get", `/v1/public/agents/${agent.slug}`)).status).toBe(200);
    const { data } = await listed("individuals", `status=pending&search=${encodeURIComponent(email)}`);
    expect(data).toHaveLength(0);
  });

  it("refuses a second decision on the same application", async () => {
    expect((await decide("individuals", account.public_id, { decision: "reject", reason: "Too late" })).status).toBe(409);
    expect(await accountOf(email)).toMatchObject({ status: "active", verification_status: "verified" });
  });
});

describe("Company that signed up to sell", () => {
  let email;
  let account;
  let company;

  it("is in the Companies pending list and the dashboard count", async () => {
    email = await directCompany("company");
    account = await accountOf(email);
    company = await companyOf(account.id);
    const { data } = await listed("companies", `status=pending&search=${encodeURIComponent(company.name)}`);
    expect(data.map((row) => row.id)).toContain(company.public_id);
    const detail = (await admin.send("get", `/v1/admin/companies/${company.public_id}`)).body.data;
    expect(detail.verification.documents).toHaveLength(3);
    expect(detail.description).toContain("<em>homes</em>");
  });

  it("approves into a live company with its logo and category", async () => {
    await confirmEmail(email);
    expect((await decide("companies", company.public_id, { decision: "approve" })).status).toBe(200);
    const live = await companyOf(account.id);
    expect(live).toMatchObject({ status: "active", verification_status: "verified", is_publicly_visible: 1 });
    expect(live.logo_url, "logo from signup").toBeTruthy();
    expect((await client().send("get", `/v1/public/companies/${live.slug}`)).status).toBe(200);
    const person = await signIn(email);
    expect((await person.send("get", "/v1/auth/session")).body.data.account.memberType).toBe("organization");
    expect((await person.send("get", "/v1/portal/organization")).status).toBe(200);
    const grant = await queryOne("SELECT status FROM account_category_access WHERE account_id = ?", [account.id]);
    expect(grant.status).toBe("approved");
  });

  it("can list straight away, on no plan yet", async () => {
    const person = await signIn(email);
    const community = await queryOne("SELECT id FROM locations WHERE level = 'community' AND status = 'active' AND active_listing_count > 0 LIMIT 1");
    const created = await person.send("post", "/v1/portal/listings", {
      category: "real-estate", categorySlug: "villas", purpose: "sale", title: `Approved Villa ${suffix}`, description: "Created by a newly approved company in the review test suite, long enough to pass.",
      price: 9500000, currency: "AED", locationId: `community:${community.id}`, detail: { bedrooms: 4, bathrooms: 5, builtAreaSqft: 5400 },
    });
    expect(created.status, JSON.stringify(created.body)).toBe(201);
    listings.push(created.body.data.id);
  });
});

describe("Member applying as an individual", () => {
  it("shows as pending although the Member account is active", async () => {
    const { person, email } = await member("member-individual");
    const sent = await person.send("post", "/v1/accounts/seller-application", {
      accountType: "personal", phone: phone(), ...(await place()), displayName: "Mia Member", bio: "<p>Ten years in waterfront homes.</p>",
      categoryId: "cars", documents: [await upload(person, "identity"), await upload(person, "profile_photo")],
    });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    const account = await accountOf(email);
    const { data, summary } = await listed("individuals", `status=pending&search=${encodeURIComponent(email)}`);
    expect(data.map((row) => row.email), "in the pending list").toContain(email);
    expect(summary.pending).toBeGreaterThan(0);
    const detail = (await admin.send("get", `/v1/admin/individuals/${account.user_public_id}`)).body.data;
    expect(detail.verification.status).toBe("pending");
    expect((await decide("individuals", account.public_id, { decision: "approve" })).status).toBe(200);
    expect((await session(person)).account.memberType).toBe("personal_seller");
  });
});

const session = async (person) => (await person.send("get", "/v1/auth/session")).body.data;

describe("Member applying as a company", () => {
  it("approves into a company on the same login", async () => {
    const { person, email } = await member("member-company");
    const sent = await person.send("post", "/v1/accounts/seller-application", {
      accountType: "organization", phone: phone(), ...(await place()), legalName: `Member Co ${suffix} LLC`, publicName: `Member Co ${suffix}`,
      organizationType: "agency", registrationNumber: `RV-M-${suffix}`, organizationEmail: email, organizationPhone: phone(),
      address: "Office 12, Marina Plaza, Dubai", description: "<p>Selling homes across Dubai since 2010.</p>", categoryId: "real-estate",
      documents: [await upload(person, "identity"), await upload(person, "organization_registration")],
    });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    const account = await accountOf(email);
    const company = await companyOf(account.id);
    const { data } = await listed("companies", `status=pending&search=${encodeURIComponent(company.name)}`);
    expect(data.map((row) => row.id)).toContain(company.public_id);
    expect((await session(person)).account.memberType).toBe("member");
    expect((await decide("companies", company.public_id, { decision: "approve" })).status).toBe(200);
    const current = await session(person);
    expect(current.account).toMatchObject({ memberType: "organization", state: "active" });
    expect((await person.send("get", "/v1/portal/organization")).status).toBe(200);
  });
});

describe("Individual upgrading to a company", () => {
  it("keeps working until approval, then moves their profile to the company", async () => {
    const owner = await createDisposablePortalOwner({ prefix: "review-upgrade" });
    emails.push(owner.email);
    const person = client();
    await person.login(owner.email, "LivFinder!2026");
    await execute(
      "UPDATE accounts a JOIN account_types t ON t.code = 'lister' SET a.account_type_id = t.id WHERE a.owner_user_id = ?",
      [owner.id]
    );
    const sent = await person.send("post", "/v1/accounts/seller-application", {
      accountType: "organization", phone: phone(), ...(await place()), legalName: `Upgrade Co ${suffix} LLC`, publicName: `Upgrade Co ${suffix}`,
      organizationType: "agency", registrationNumber: `RV-U-${suffix}`, organizationEmail: owner.email, organizationPhone: phone(),
      address: "Office 12, Marina Plaza, Dubai", description: "<p>Selling homes across Dubai since 2010.</p>", categoryId: "real-estate",
      documents: [await upload(person, "identity"), await upload(person, "organization_registration")],
    });
    expect(sent.status, JSON.stringify(sent.body)).toBe(201);
    const account = await accountOf(owner.email);
    expect((await session(person)).account.memberType).toBe("personal_seller");
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(200);
    const company = await companyOf(account.id);
    expect((await decide("companies", company.public_id, { decision: "approve" })).status).toBe(200);
    expect((await session(person)).account.memberType).toBe("organization");
    const agent = await queryOne("SELECT organization_id FROM agents WHERE user_id = ?", [owner.id]);
    expect(Number(agent.organization_id)).toBe(Number(company.id));
  });
});

describe("Reviewer decisions", () => {
  it("needs a reason to reject and a note to ask for changes", async () => {
    const email = await directCompany("reasons");
    const account = await accountOf(email);
    const company = await companyOf(account.id);
    expect((await decide("companies", company.public_id, { decision: "reject" })).status).toBe(422);
    expect((await decide("companies", company.public_id, { decision: "request_changes" })).status).toBe(422);
    expect((await decide("companies", company.public_id, { decision: "request_changes", note: "   " })).status).toBe(422);
  });

  it("asks for changes, takes a corrected document, then approves", async () => {
    const email = await directCompany("changes");
    await confirmEmail(email);
    const account = await accountOf(email);
    const company = await companyOf(account.id);
    clearSentMessages();
    expect((await decide("companies", company.public_id, { decision: "request_changes", note: "The licence has expired." })).status).toBe(200);
    expect(sentMessages().at(-1).text).toContain("The licence has expired.");
    const { data } = await listed("companies", `status=pending&search=${encodeURIComponent(company.name)}`);
    expect(data.map((row) => row.id), "still waiting on someone").toContain(company.public_id);

    const person = await signIn(email);
    const status = (await person.send("get", "/v1/accounts/verification/status")).body.data;
    expect(status.notes ?? status.decisionNotes ?? JSON.stringify(status)).toContain("The licence has expired.");
    const document = await upload(person, "resubmission");
    const sent = await person.send("post", "/v1/accounts/verification/submit", { subjectType: "organization", documents: [document] });
    expect(sent.status, JSON.stringify(sent.body)).toBeLessThan(300);
    const detail = (await admin.send("get", `/v1/admin/companies/${company.public_id}`)).body.data;
    expect(detail.verification.status).toBe("pending");
    expect(detail.verification.documents.some((row) => row.documentType === "resubmission")).toBe(true);
    expect((await decide("companies", company.public_id, { decision: "approve" })).status).toBe(200);
    expect(await companyOf(account.id)).toMatchObject({ status: "active", verification_status: "verified" });
  });

  it("tells a rejected applicant why, keeps the company hidden, and off the waiting list", async () => {
    const email = await directCompany("reject");
    await confirmEmail(email);
    const account = await accountOf(email);
    const company = await companyOf(account.id);
    clearSentMessages();
    expect((await decide("companies", company.public_id, { decision: "reject", reason: "Not a real business." })).status).toBe(200);
    expect(sentMessages().at(-1).text).toContain("Not a real business.");
    expect(await companyOf(account.id)).toMatchObject({ verification_status: "rejected", is_publicly_visible: 0 });
    const { data } = await listed("companies", `status=pending&search=${encodeURIComponent(company.name)}`);
    expect(data, "nothing left to decide").toHaveLength(0);
    const person = await signIn(email);
    expect((await person.send("get", "/v1/portal/listings")).status).toBe(403);
    expect((await person.send("get", "/v1/accounts/verification/status")).status).toBe(200);
  });

  it("lets a rejected applicant send it again, back to the reviewer", async () => {
    const email = await directCompany("again");
    await confirmEmail(email);
    const account = await accountOf(email);
    const company = await companyOf(account.id);
    expect((await decide("companies", company.public_id, { decision: "reject", reason: "The proof is unreadable." })).status).toBe(200);
    const person = await signIn(email);
    const sent = await person.send("post", "/v1/accounts/verification/submit", { subjectType: "organization", documents: [await upload(person, "resubmission")] });
    expect(sent.status, JSON.stringify(sent.body)).toBeLessThan(300);
    const { data } = await listed("companies", `status=pending&search=${encodeURIComponent(company.name)}`);
    expect(data.map((row) => row.id)).toContain(company.public_id);
    expect((await decide("companies", company.public_id, { decision: "approve" })).status).toBe(200);
    expect(await companyOf(account.id)).toMatchObject({ status: "active", verification_status: "verified", is_publicly_visible: 1 });
    expect(await accountOf(email)).toMatchObject({ status: "active", verification_status: "verified" });
  });

  it("does not take a live company down over a later review", async () => {
    const email = await directCompany("live");
    await confirmEmail(email);
    const account = await accountOf(email);
    const company = await companyOf(account.id);
    expect((await decide("companies", company.public_id, { decision: "approve" })).status).toBe(200);
    await execute(
      `INSERT INTO verification_requests (public_id, subject_type, subject_id, status, submitted_at, created_at)
       VALUES (?, 'organization', ?, 'pending', NOW(3), NOW(3))`,
      [`rv${suffix}`, company.id]
    );
    expect((await decide("companies", company.public_id, { decision: "reject", reason: "Licence renewal failed." })).status).toBe(200);
    expect(await companyOf(account.id)).toMatchObject({ status: "active", verification_status: "verified", is_publicly_visible: 1 });
    expect(await accountOf(email)).toMatchObject({ status: "active", verification_status: "verified" });
  });

  it("is refused to staff without the permission", async () => {
    const email = await directCompany("permission");
    const account = await accountOf(email);
    const company = await companyOf(account.id);
    const outsider = await createDisposablePortalOwner({ prefix: "review-outsider" });
    emails.push(outsider.email);
    const person = client();
    await person.login(outsider.email, "LivFinder!2026");
    expect((await person.send("patch", `/v1/admin/companies/${company.public_id}/verification`, { decision: "approve" })).status).toBe(403);
    expect((await companyOf(account.id)).status).toBe("pending");
  });
});
