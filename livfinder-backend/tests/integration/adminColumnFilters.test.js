import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { adminEmail, client, ensureTestPassword, execute, query } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { importProviderId } from "../../src/modules/imports/importConnection.js";

/**
 * Admin table header filters, through the real routes.
 *
 * Each case asks a list endpoint for one filter and checks the answer is exactly the rows a
 * predicate picks out of the unfiltered list — every row returned matches, and none is missing.
 * Filter values are taken from the data itself so the suite works on any seeded database; a
 * value with no matching rows still has to come back empty rather than erroring.
 *
 * Read-only, except Feed Mappings, which inserts three rows and deletes them again.
 */
const PASSWORD = "LivFinder!2026";
const admin = client();

beforeAll(async () => {
  await ensureTestPassword(PASSWORD);
  await admin.login(await adminEmail("super_admin"), PASSWORD);
});

afterAll(async () => {
  await closePool();
});

const rowsOf = (body) => body.items ?? body.data ?? [];
const totalOf = (body) => Number(body.total ?? body.pageInfo?.total ?? 0);
const fold = (value) => String(value ?? "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
const has = (needle) => (...values) => values.some((value) => fold(value).includes(fold(needle)));
const day = (value) => (value ? new Date(value).toISOString().slice(0, 10) : "");

/** Every row of a list, page by page. */
async function all(path, params = {}, pageSize = 200) {
  const items = [];
  for (let page = 1; page < 100; page++) {
    const response = await admin.get(path, { ...params, page, pageSize });
    expect(response.status, `${path} ${JSON.stringify(params)} → ${JSON.stringify(response.body).slice(0, 300)}`).toBe(200);
    const rows = rowsOf(response.body);
    items.push(...rows);
    if (!rows.length || items.length >= totalOf(response.body)) break;
  }
  return items;
}

/** One filter case: the filtered list is exactly the predicate's subset of the full list. */
async function expectFilter(path, base, filter, predicate, pageSize) {
  // One request at a time: parallel requests on one supertest agent reset each other.
  const everything = await all(path, base, pageSize);
  const filtered = await all(path, { ...base, ...filter }, pageSize);
  const expected = everything.filter(predicate).map((row) => row.id).sort();
  const got = filtered.map((row) => row.id).sort();
  const strays = filtered.filter((row) => !predicate(row)).map((row) => row.id);
  expect(strays, `${path} ${JSON.stringify(filter)}: rows that do not match`).toEqual([]);
  expect(got, `${path} ${JSON.stringify(filter)}`).toEqual(expected);
  return got.length;
}

const first = (values, count = 2) => [...new Set(values.filter((value) => value !== null && value !== undefined && value !== ""))].slice(0, count);

describe("Companies and Individuals", () => {
  it("filters companies by every column", async () => {
    const path = "/v1/admin/companies";
    const rows = await all(path);
    const page = (await admin.get(path, { pageSize: 1 })).body;
    const statuses = first(rows.map((row) => row.status));
    const packages = page.options.packages.filter((pkg) => rows.some((row) => row.package?.name === pkg.name)).slice(0, 2);
    const country = page.options.countries.find((item) => rows.some((row) => row.country === item.name));
    await expectFilter(path, {}, { company: "a" }, (row) => has("a")(row.businessName, row.legalName, row.reference));
    await expectFilter(path, {}, { status: statuses.join(",") }, (row) => statuses.includes(row.status) || (statuses.includes("pending") && row.applicationOpen));
    await expectFilter(path, {}, { primary: "real-estate" }, (row) => row.primaryCategory === "real-estate");
    await expectFilter(path, {}, { categories: "cars,yachts" }, (row) => row.enabledCategories.some((slug) => ["cars", "yachts"].includes(slug)));
    await expectFilter(path, {}, { package: packages.map((pkg) => pkg.id).join(",") }, (row) => packages.some((pkg) => pkg.name === row.package?.name));
    if (country) await expectFilter(path, {}, { country: country.id }, (row) => row.country === country.name);
    await expectFilter(path, {}, { agentsMin: "1", agentsMax: "5" }, (row) => row.agentCount >= 1 && row.agentCount <= 5);
    await expectFilter(path, {}, { listingsMin: "10" }, (row) => row.listingCount >= 10);
    await expectFilter(path, {}, { api: "enabled" }, (row) => row.api.enabled);
    await expectFilter(path, {}, { api: "disabled" }, (row) => !row.api.enabled);
    await expectFilter(path, {}, { from: "2026-01-01", to: "2026-12-31" }, (row) => day(row.dateAdded).startsWith("2026"));
  });

  it("filters individuals by every column", async () => {
    const path = "/v1/admin/individuals";
    await expectFilter(path, {}, { individual: "a" }, (row) => has("a")(row.displayName, row.firstName, row.lastName, row.reference));
    await expectFilter(path, {}, { contact: "@" }, (row) => has("@")(row.email, row.phone));
    await expectFilter(path, {}, { primary: "real-estate" }, (row) => row.primaryCategory === "real-estate");
    await expectFilter(path, {}, { categories: "cars,yachts" }, (row) => row.enabledCategories.some((slug) => ["cars", "yachts"].includes(slug)));
    await expectFilter(path, {}, { listingsMin: "1", listingsMax: "5" }, (row) => row.listingCount >= 1 && row.listingCount <= 5);
    await expectFilter(path, {}, { activeFrom: "2026-10-01" }, (row) => day(row.lastActivityAt) >= "2026-10-01");
  });
});

describe("Listings and Developments", () => {
  it("filters each category's listing columns", async () => {
    const path = "/v1/admin/listings";
    const re = (await admin.get(path, { category: "real-estate", pageSize: 1 })).body;
    const types = re.options.propertyTypes.slice(0, 2);
    await expectFilter(path, { category: "real-estate" }, { listing: "villa" }, (row) => has("villa")(row.title, row.reference, row.id));
    await expectFilter(path, { category: "real-estate" }, { owner: "a" }, (row) => has("a")(row.owner));
    await expectFilter(path, { category: "real-estate" }, { propertyType: types.map((type) => type.id).join(",") }, (row) => types.some((type) => type.name === row.propertyType));
    await expectFilter(path, { category: "real-estate" }, { priceMin: "1000000", priceMax: "5000000" }, (row) => row.priceValue >= 1e6 && row.priceValue <= 5e6);
    await expectFilter(path, { category: "real-estate" }, { bedsMin: "2", bedsMax: "3" }, (row) => row.beds >= 2 && row.beds <= 3);
    await expectFilter(path, { category: "real-estate" }, { bathsMin: "3" }, (row) => row.baths >= 3);
    await expectFilter(path, { category: "real-estate" }, { bedsMin: "2", bathsMax: "2" }, (row) => row.beds >= 2 && row.baths <= 2);
    await expectFilter(path, { category: "real-estate" }, { status: "approved,sold" }, (row) => ["approved", "sold", "rented"].includes(row.status));
    await expectFilter(path, { category: "cars" }, { yearMin: "2020", yearMax: "2023" }, (row) => row.year >= 2020 && row.year <= 2023);
    await expectFilter(path, { category: "cars" }, { mileageMax: "20000" }, (row) => row.mileage !== null && row.mileage <= 20000);
    await expectFilter(path, { category: "yachts" }, { lengthMin: "80", lengthMax: "150" }, (row) => row.length >= 80 && row.length <= 150);
    await expectFilter(path, { category: "jets" }, { passengersMin: "8", passengersMax: "14" }, (row) => row.passengers >= 8 && row.passengers <= 14);
    await expectFilter(path, { category: "jets" }, { rangeMin: "4000" }, (row) => row.range >= 4000);
    await expectFilter(path, { category: "helicopters" }, { hoursMax: "1000" }, (row) => row.flightHours !== null && row.flightHours <= 1000);
    await expectFilter(path, { category: "watches" }, { condition: "unworn,excellent" }, (row) => ["unworn", "excellent"].includes(row.conditionGrade));
    await expectFilter(path, { category: "watches" }, { reference: "1" }, (row) => has("1")(row.watchReference));
    const cars = await all(path, { category: "cars" });
    const makes = (await admin.get(path, { category: "cars", pageSize: 1 })).body.options.brands.filter((brand) => cars.some((row) => row.make === brand.name)).slice(0, 2);
    await expectFilter(path, { category: "cars" }, { brand: makes.map((brand) => brand.id).join(",") }, (row) => makes.some((brand) => brand.name === row.make));
  });

  it("filters developments by every column", async () => {
    const path = "/v1/admin/developments";
    const options = (await admin.get(path, { pageSize: 1 })).body.options;
    const developers = options.developers.slice(0, 2);
    await expectFilter(path, {}, { development: "the" }, (row) => has("the")(row.name, row.slug, row.id));
    await expectFilter(path, {}, { developer: developers.map((item) => item.value).join(",") }, (row) => developers.some((item) => item.value === row.developer?.slug));
    await expectFilter(path, {}, { priceMin: "1000000", priceMax: "3000000" }, (row) => row.startingPrice?.amount >= 1e6 && row.startingPrice?.amount <= 3e6);
    await expectFilter(path, {}, { unitsMin: "10", unitsMax: "200" }, (row) => row.availableUnits >= 10 && row.availableUnits <= 200);
    await expectFilter(path, {}, { handoverFrom: "2027-01-01", handoverTo: "2027-12-31" }, (row) => String(row.expectedCompletionDate ?? "").startsWith("2027"));
    await expectFilter(path, {}, { status: "published,draft" }, (row) => ["published", "draft"].includes(row.moderationStatus));
    await expectFilter(path, {}, { leadsMax: "0" }, (row) => row.leadsCount <= 0);
  });
});

describe("Leads and Contacts", () => {
  it("filters leads, with Status matching what each row shows", async () => {
    const path = "/v1/admin/leads";
    for (const category of ["real-estate", "cars"]) {
      const rows = await all(path, { category });
      for (const stage of first(rows.map((row) => row.status), 6)) {
        await expectFilter(path, { category }, { stage }, (row) => row.status === stage);
      }
      const sources = first(rows.map((row) => row.sourceCode));
      await expectFilter(path, { category }, { source: sources.join(",") }, (row) => sources.includes(row.sourceCode));
      await expectFilter(path, { category }, { agent: "unassigned" }, (row) => !row.agent);
      await expectFilter(path, { category }, { contact: "a" }, (row) => has("a")(row.contact.name, row.contact.firstName, row.contact.lastName, `${row.contact.firstName} ${row.contact.lastName}`, row.contact.primaryEmail, row.contact.primaryPhone, row.email));
      await expectFilter(path, { category }, { propertyName: "a" }, (row) => has("a")(row.property?.title, row.property?.reference));
      await expectFilter(path, { category }, { from: "2026-01-01", to: "2026-12-31" }, (row) => day(row.inquiryAt).startsWith("2026"));
    }
  });

  it("filters contacts by every column", async () => {
    const path = "/v1/admin/contacts";
    const options = (await admin.get(path, { pageSize: 1 })).body.options;
    const rows = await all(path);
    const sources = options.sources.filter((source) => rows.some((row) => row.source === source.name)).slice(0, 2);
    const open = (row) => row.leads.filter((lead) => lead.status === "open").length;
    const listings = (row) => new Set(row.leads.map((lead) => lead.listing?.id).filter(Boolean)).size;
    await expectFilter(path, {}, { contact: "ma" }, (row) => has("ma")(row.displayName, row.firstName, row.lastName, `${row.firstName} ${row.lastName}`, row.reference, row.id));
    await expectFilter(path, {}, { phone: "97" }, (row) => has("97")(row.primaryPhone));
    await expectFilter(path, {}, { contactInfo: "44" }, (row) => has("44")(row.primaryEmail, row.primaryPhone));
    await expectFilter(path, {}, { source: sources.map((source) => source.value).join(",") }, (row) => sources.some((source) => source.name === row.source));
    await expectFilter(path, {}, { stage: "lead,customer" }, (row) => ["lead", "customer"].includes(row.status));
    await expectFilter(path, {}, { leadsMin: "2", leadsMax: "5" }, (row) => row.leadStats.total >= 2 && row.leadStats.total <= 5);
    await expectFilter(path, {}, { activeLeadsMin: "1" }, (row) => open(row) >= 1);
    await expectFilter(path, {}, { listingsMin: "2" }, (row) => listings(row) >= 2);
    await expectFilter(path, {}, { activeFrom: "2026-01-01", activeTo: "2026-12-31" }, (row) => day(row.lastActivityAt).startsWith("2026"));
  });
});

describe("Locations and Categories", () => {
  it("filters location tiers", async () => {
    await expectFilter("/v1/admin/locations/countries", {}, { name: "united" }, (row) => has("united")(row.name));
    await expectFilter("/v1/admin/locations/countries", {}, { childrenMin: "5" }, (row) => row.childCount >= 5);
    await expectFilter("/v1/admin/locations/countries", {}, { listingsMin: "1" }, (row) => row.listings >= 1);
    const uae = { country: "1231" };
    await expectFilter("/v1/admin/locations/communities", uae, { city: "dubai" }, (row) => has("dubai")(row.city));
    await expectFilter("/v1/admin/locations/communities", uae, { listingsMin: "1", listingsMax: "10" }, (row) => row.listings >= 1 && row.listings <= 10);
    await expectFilter("/v1/admin/locations/sub-communities", uae, { community: "marina" }, (row) => has("marina")(row.community));
  });

  it("filters categories", async () => {
    const path = "/v1/admin/categories";
    await expectFilter(path, {}, { name: "a" }, (row) => has("a")(row.name));
    await expectFilter(path, {}, { slug: "car" }, (row) => has("car")(row.slug, row.code));
    await expectFilter(path, {}, { listingsMin: "1" }, (row) => row.listings >= 1);
    await expectFilter(path, {}, { status: "active,inactive" }, (row) => ["active", "inactive"].includes(row.status));
  });
});

describe("Content", () => {
  it("filters articles, media, reviews and reports", async () => {
    const articles = await all("/v1/admin/articles");
    const categories = first(articles.map((row) => row.primaryCategory?.slug));
    await expectFilter("/v1/admin/articles", {}, { category: categories.join(",") }, (row) => categories.includes(row.primaryCategory?.slug));
    await expectFilter("/v1/admin/articles", {}, { status: "published,draft" }, (row) => ["published", "draft"].includes(row.status));
    await expectFilter("/v1/admin/articles", {}, { dateFrom: "2026-01-01", dateTo: "2026-12-31" }, (row) => day(row.publishedAt).startsWith("2026"));

    await expectFilter("/v1/admin/media", {}, { type: "image,document" }, (row) => ["image", "document"].includes(row.mediaType));
    await expectFilter("/v1/admin/media", {}, { widthMin: "1000", widthMax: "3000" }, (row) => row.width >= 1000 && row.width <= 3000);
    await expectFilter("/v1/admin/media", {}, { sizeMinKb: "100", sizeMaxKb: "500" }, (row) => row.fileSize / 1024 >= 100 && row.fileSize / 1024 <= 500);
    await expectFilter("/v1/admin/media", {}, { media: "jpg" }, (row) => has("jpg")(row.title, row.originalFilename, row.reference));

    await expectFilter("/v1/admin/reviews", {}, { rating: "4,5" }, (row) => [4, 5].includes(Math.round(row.rating)));
    await expectFilter("/v1/admin/reviews", {}, { targetType: "organization,agent" }, (row) => ["organization", "agent"].includes(row.targetType));
    await expectFilter("/v1/admin/reviews", {}, { reviewFor: "a" }, (row) => has("a")(row.target?.title));

    await expectFilter("/v1/admin/reports", {}, { priority: "high,urgent" }, (row) => ["high", "urgent"].includes(row.priority));
    await expectFilter("/v1/admin/reports", {}, { assignee: "unassigned" }, (row) => !row.assignedTo);
    await expectFilter("/v1/admin/reports", {}, { item: "a" }, (row) => has("a")(row.entity?.title));
    await expectFilter("/v1/admin/reports", {}, { entityType: "listing,review" }, (row) => ["listing", "review"].includes(row.entityType));
    // Number boxes with the prefix fixed: the number is compared, and a pasted reference works too.
    const reports = await all("/v1/admin/reports");
    const report = reports[3];
    const reportNo = Number(report.reference.slice(4));
    await expectFilter("/v1/admin/reports", {}, { reportNumber: String(reportNo) }, (row) => row.reference === report.reference);
    await expectFilter("/v1/admin/reports", {}, { reportNumber: report.reference }, (row) => row.reference === report.reference);
    await expectFilter("/v1/admin/reports", {}, { reportNumber: String(reportNo).slice(0, 2) }, () => false);
    const reviews = await all("/v1/admin/reviews");
    const review = reviews[5];
    await expectFilter("/v1/admin/reviews", {}, { reviewNumber: String(Number(review.reference.slice(3))) }, (row) => row.reference === review.reference);
    // Every row carries a reported item with a link wherever an admin page exists, and a photo or logo where one is stored.
    expect(reports.filter((row) => row.entityType === "listing" && !row.entity?.removed).every((row) => row.entity.href?.startsWith("/admin/listings/"))).toBe(true);
    expect(reports.some((row) => row.entity?.image)).toBe(true);
  });
});

describe("Access management and system logs", () => {
  it("filters admin users and logs", async () => {
    const users = await all("/v1/admin/access-users");
    const roles = first(users.flatMap((row) => row.roleIds));
    await expectFilter("/v1/admin/access-users", {}, { roleId: roles.join(",") }, (row) => row.roleIds.some((id) => roles.includes(id)));
    await expectFilter("/v1/admin/access-users", {}, { user: "a" }, (row) => has("a")(row.displayName, row.firstName, row.lastName, row.email, row.id));
    await expectFilter("/v1/admin/access-users", {}, { loginFrom: "2026-10-01" }, (row) => day(row.lastLoginAt) >= "2026-10-01");

    const logs = await all("/v1/admin/system-logs");
    const severities = first(logs.map((row) => row.severity));
    const sources = first(logs.map((row) => row.source));
    await expectFilter("/v1/admin/system-logs", {}, { severity: severities.join(",") }, (row) => severities.includes(row.severity));
    await expectFilter("/v1/admin/system-logs", {}, { source: sources.join(",") }, (row) => sources.includes(row.source));
    await expectFilter("/v1/admin/system-logs", {}, { message: "a" }, (row) => has("a")(row.message));
  });
});

describe("API imports and keys", () => {
  it("filters imports and API keys", async () => {
    await expectFilter("/v1/admin/listing-imports", {}, { status: "completed,failed" }, (row) => ["completed", "failed"].includes(row.status), 100);
    await expectFilter("/v1/admin/listing-imports", {}, { type: "file" }, (row) => row.type === "file", 100);
    await expectFilter("/v1/admin/listing-imports", {}, { failedMin: "1" }, (row) => row.counts.failed >= 1, 100);
    await expectFilter("/v1/admin/api-clients", {}, { status: "active,revoked" }, (row) => ["active", "revoked"].includes(row.status), 100);
    await expectFilter("/v1/admin/api-clients", {}, { key: "lf" }, (row) => has("lf")(row.name, row.clientId), 100);
    await expectFilter("/v1/admin/api-clients", {}, { createdBy: "@" }, (row) => has("@")(row.createdBy?.email, row.createdBy?.name), 100);
  });
});

describe("Feed mappings", () => {
  it("filters mappings on temporary rows", async () => {
    const provider = await importProviderId();
    const tag = `zz-filter-test-${Date.now()}`;
    const ids = [];
    try {
      for (const row of [
        ["location", 1231, null, `${tag}-dubai`, "Dubai Marina (test)", null, 0, 7, "2026-10-05 10:00:00"],
        ["category", null, "apartment", `${tag}-apt`, "Flat (test)", "1", 0, 2, "2025-06-01 10:00:00"],
        ["location", null, null, `${tag}-unknown`, "Somewhere (test)", null, 1, 12, "2026-11-01 10:00:00"],
      ]) {
        const result = await execute(
          `INSERT INTO feed_value_mappings (provider_id, connection_id, mapping_type, internal_id, internal_value, external_value, external_label, scope_key, is_unmapped, seen_count, last_seen_at)
           VALUES (?, NULL, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [provider, ...row]
        );
        ids.push(result.insertId);
      }
      const ours = async (params) => (await all("/v1/admin/feed-mappings", { status: "all", ...params }, 100)).filter((row) => row.value.startsWith(tag));
      expect((await ours({ type: "location" })).length).toBe(2);
      expect((await ours({ sent: "flat" })).map((row) => row.label)).toEqual(["Flat (test)"]);
      expect((await ours({ seenMin: "5", seenMax: "20" })).length).toBe(2);
      expect((await ours({ target: "united" })).map((row) => row.label)).toEqual(["Dubai Marina (test)"]);
      expect((await ours({ seenFrom: "2026-01-01", seenTo: "2026-12-31" })).length).toBe(2);
    } finally {
      if (ids.length) await execute(`DELETE FROM feed_value_mappings WHERE id IN (${ids.map(() => "?").join(", ")})`, ids);
    }
    expect((await query("SELECT COUNT(*) AS n FROM feed_value_mappings WHERE external_value LIKE ?", [`${tag}%`]))[0].n).toBe(0);
  });
});

describe("search-as-you-type dropdowns", () => {
  const lookup = async (kind, query) => {
    const response = await admin.get(`/v1/admin/lookup/${kind}`, query);
    expect(response.status, JSON.stringify(response.body).slice(0, 200)).toBe(200);
    return response.body.data;
  };

  it("finds places by any part of the name, with their full path, and names chosen ids", async () => {
    const found = await lookup("location", { q: "marina" });
    const marina = found.find((option) => option.label === "Dubai Marina");
    expect(marina.description).toContain("Dubai › Dubai › United Arab Emirates");
    expect((await lookup("location", { ids: marina.value })).map((option) => option.label)).toEqual(["Dubai Marina"]);
    expect((await lookup("location", { q: "dub", types: "city" })).every((option) => option.description.startsWith("City"))).toBe(true);
  });

  it("offers owners, companies, agents, brands and developers with images", async () => {
    for (const [kind, query] of [["owner", {}], ["company", {}], ["agent", {}], ["brand", { kinds: "car_make" }], ["developer", {}], ["admin", {}], ["property", { types: "real-estate" }]]) {
      const options = await lookup(kind, query);
      expect(options.length, kind).toBeGreaterThan(0);
      expect(options.every((option) => option.value && option.label), kind).toBe(true);
    }
    expect((await admin.get("/v1/admin/lookup/nonsense")).status).toBe(422);
  });

  it("filters lists by the chosen ids", async () => {
    const [place] = await lookup("location", { q: "Dubai Marina" });
    await expectFilter("/v1/admin/listings", { category: "real-estate" }, { locationId: place.value }, (row) => has("Dubai Marina")(row.location));
    const [owner] = await lookup("owner", { q: "Prime Properties" });
    await expectFilter("/v1/admin/listings", { category: "real-estate" }, { ownerId: owner.value }, (row) => row.owner === "Prime Properties");
    const [city] = await lookup("location", { q: "Dubai", types: "city" });
    await expectFilter("/v1/admin/locations/communities", {}, { cityId: city.value }, (row) => row.city === "Dubai");
    await expectFilter("/v1/admin/companies", {}, { place: city.value }, (row) => row.city === "Dubai");
    const leads = await all("/v1/admin/leads", { category: "real-estate" });
    const lead = leads.find((row) => row.property);
    await expectFilter("/v1/admin/leads", { category: "real-estate" }, { propertyId: `listing:${lead.property.id}` }, (row) => row.property?.id === lead.property.id);
    const number = Number(lead.reference.slice(3));
    await expectFilter("/v1/admin/leads", { category: "real-estate" }, { leadNumber: String(number) }, (row) => Number(row.reference.slice(3)) === number);
    await expectFilter("/v1/admin/contacts", { category: "real-estate" }, { contactType: "buyer" }, (row) => row.accountType === "buyer");
  });

  it("narrows category dropdowns by category access and brand kind, never by listings", async () => {
    const SEGMENT = { jets: "fixed_wing", helicopters: "rotorcraft" };
    const KIND = { cars: "car_make", yachts: "yacht_builder", jets: "aircraft_manufacturer", helicopters: "aircraft_manufacturer", watches: "watch_brand" };
    for (const category of ["real-estate", "cars", "yachts", "jets", "helicopters", "watches"]) {
      const [{ id: rootId }] = await query("SELECT id FROM categories WHERE slug = ? AND parent_id IS NULL", [category]);
      // Companies: exactly those whose account has approved access to the category (first page).
      const owners = await lookup("owner", { category });
      const companies = owners.filter((option) => option.value.startsWith("org:")).map((option) => option.value.slice(4));
      expect(companies.length, `${category} companies`).toBeGreaterThan(0);
      const allowed = await query(
        `SELECT o.public_id FROM organizations o JOIN account_category_access ca ON ca.account_id = o.account_id
          WHERE ca.category_id = ? AND ca.status = 'approved' AND o.public_id IN (${companies.map(() => "?").join(", ")})`,
        [rootId, ...companies]
      );
      expect(allowed.map((row) => row.public_id).sort(), category).toEqual([...companies].sort());
      // Makes: the category's brand kind (and aircraft segment), whether or not anything is listed.
      if (KIND[category]) {
        const brands = await lookup("brand", { category });
        expect(brands.length).toBeGreaterThan(0);
        const rows = await query(`SELECT kind, aircraft_segment FROM brands WHERE id IN (${brands.map(() => "?").join(", ")})`, brands.map((brand) => brand.value));
        expect(rows.every((row) => row.kind === KIND[category] && (!SEGMENT[category] || row.aircraft_segment === SEGMENT[category])), category).toBe(true);
      }
    }
    // Places are the whole tree, whatever the category: a place with no listing is still offered.
    const [empty] = await query(
      "SELECT name FROM locations WHERE level = 'country' AND status = 'active' AND deleted_at IS NULL AND is_searchable = 1 AND active_listing_count = 0 LIMIT 1"
    );
    if (empty) expect((await lookup("location", { category: "jets", q: empty.name })).some((option) => option.label === empty.name)).toBe(true);
    // A chosen id always resolves, whatever the category.
    const [anyOwner] = await lookup("owner", { category: "real-estate" });
    expect((await lookup("owner", { category: "watches", ids: anyOwner.value })).map((option) => option.value)).toEqual([anyOwner.value]);
  });

  it("serves every option list from the database's own definitions", async () => {
    const response = await admin.get("/v1/admin/options", { sets: "review.status,report.status,listing.adminStatus,lead.adminStatus,lead.funnelStep:cars,nope" });
    expect(response.status).toBe(200);
    const sets = response.body.data;
    const enumOf = async (table, column) =>
      (await query("SELECT column_type AS t FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = ? AND column_name = ?", [table, column]))[0].t;
    expect(sets["review.status"].map((option) => option.value)).toEqual([...(await enumOf("reviews", "status")).matchAll(/'([^']+)'/g)].map((m) => m[1]));
    expect(sets["report.status"].map((option) => option.value)).toEqual([...(await enumOf("reports", "status")).matchAll(/'([^']+)'/g)].map((m) => m[1]));
    expect(sets["lead.adminStatus"].map((option) => option.value)).toContain("follow-up");
    expect(sets["lead.funnelStep:cars"].find((option) => option.value === "viewing").label).toBe("Test drive");
    expect(sets.nope).toBeUndefined();
    // Every listing status the filter offers filters without error.
    for (const option of sets["listing.adminStatus"]) expect((await admin.get("/v1/admin/listings", { category: "all", status: option.value, page: 1, pageSize: 1 })).status).toBe(200);
  });
});

describe("bad filter input", () => {
  it("ignores junk and unknown keys instead of failing", async () => {
    const companies = await all("/v1/admin/companies");
    // Junk ranges and dates are dropped; an unknown key is inert.
    const junk = await all("/v1/admin/companies", { agentsMin: "1; DROP TABLE users", from: "yesterday", notAFilter: "x" });
    expect(junk.length).toBe(companies.length);
    // SQL-looking text is only ever a bound LIKE value.
    expect((await all("/v1/admin/companies", { company: "' OR 1=1 --" })).length).toBe(0);
    // A list where nothing is recognised matches nothing rather than everything.
    expect((await all("/v1/admin/listings", { category: "cars", status: "nonsense" })).length).toBe(0);
  });
});
