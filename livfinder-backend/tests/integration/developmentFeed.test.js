import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupProjects, createTestApiKey, execute, pushFile, query, queryOne } from "../helpers/testApp.js";
import { sampleXml } from "../../src/modules/feeds/feedTemplates.js";
import { closePool } from "../../src/db/pool.js";
import { useFakeImages } from "../helpers/completeListing.js";

/**
 * A developer's development file: projects with unit types and payment plans arrive as drafts;
 * a change to a published one waits for approval (0061).
 *
 * Uses a seeded developer company approved for developments. Its add-on row is restored, and
 * every project the run created is removed.
 */

let company = null;
let key = null;
let addonBefore = null;
const created = [];
const externalId = `QA-DEV-${Date.now()}`;

// The sample file, with this run's own id.
const file = (tagline) =>
  sampleXml("developments")
    .replace("<externalId>ABC-1001</externalId>", `<externalId>${externalId}</externalId>`)
    .replace(/<tagline>[^<]*<\/tagline>/, `<tagline>${tagline}</tagline>`);
const project = () =>
  queryOne(
    `SELECT p.id, p.public_id, p.tagline, p.moderation_status, p.organization_id, p.pending_revision_id
       FROM external_references er JOIN projects p ON p.id = er.entity_id
      WHERE er.entity_type = 'project' AND er.external_id = ? LIMIT 1`,
    [externalId]
  );

beforeAll(async () => {
  company = await queryOne(
    `SELECT o.id AS organization_id, o.account_id
       FROM organizations o
       JOIN accounts a ON a.id = o.account_id AND a.status = 'active'
       JOIN account_category_access aca ON aca.account_id = a.id AND aca.category_id = 7 AND aca.status = 'approved'
      WHERE o.deleted_at IS NULL AND o.status = 'active'
      ORDER BY o.id LIMIT 1`
  );
  expect(company, "a developer company approved for developments").toBeTruthy();
  addonBefore = await queryOne("SELECT * FROM account_addons WHERE account_id = ? AND addon_code = 'integrations'", [company.account_id]);
  await execute(
    `INSERT INTO account_addons (public_id, account_id, addon_code, status, started_at)
     VALUES (?, ?, 'integrations', 'active', NOW(3)) ON DUPLICATE KEY UPDATE status = 'active', ends_at = NULL`,
    [`01QADEVFEED${String(Date.now()).slice(-8)}${company.account_id}`.slice(0, 26).padEnd(26, "0"), company.account_id]
  );
  key = await createTestApiKey({ accountId: company.account_id, organizationId: company.organization_id });
  useFakeImages();
});

afterAll(async () => {
  const row = await project();
  if (row) created.push(row.public_id);
  await execute("DELETE FROM external_references WHERE entity_type = 'project' AND external_id = ?", [externalId]);
  await cleanupProjects(created);
  if (key) {
    await execute("DELETE FROM feed_import_items WHERE import_id IN (SELECT fi.id FROM feed_imports fi JOIN api_clients ac ON ac.id = fi.api_client_id WHERE ac.public_id = ?)", [key.id]);
    await execute("DELETE FROM feed_imports WHERE api_client_id = (SELECT id FROM api_clients WHERE public_id = ?)", [key.id]);
    await execute("DELETE FROM api_clients WHERE public_id = ?", [key.id]);
  }
  if (!addonBefore) {
    await execute("DELETE FROM account_addons WHERE account_id = ? AND addon_code = 'integrations'", [company.account_id]);
  } else {
    await execute("UPDATE account_addons SET status = ?, ends_at = ?, cancelled_at = ? WHERE id = ?", [
      addonBefore.status, addonBefore.ends_at, addonBefore.cancelled_at, addonBefore.id,
    ]);
  }
  await closePool();
});

describe("a development made in LivFinder", () => {
  it("updates when sent back under its own id, and never becomes a copy", async () => {
    const own = await queryOne("SELECT id, public_id, tagline FROM projects WHERE organization_id = ? AND deleted_at IS NULL AND moderation_status = 'draft' ORDER BY id DESC LIMIT 1", [company.organization_id]);
    if (!own) return;
    const before = await queryOne("SELECT COUNT(*) AS n FROM projects WHERE organization_id = ? AND deleted_at IS NULL", [company.organization_id]);
    const body = sampleXml("developments").replace("<externalId>ABC-1001</externalId>", `<externalId>${own.public_id}</externalId>`);
    const { imports: [result] } = await pushFile(key, "/listings.xml", body);
    expect(result, JSON.stringify(result)).toMatchObject({ accepted: 1 });
    const after = await queryOne("SELECT COUNT(*) AS n FROM projects WHERE organization_id = ? AND deleted_at IS NULL", [company.organization_id]);
    expect(after.n).toBe(before.n);
    await execute("UPDATE projects SET tagline = ? WHERE id = ?", [own.tagline, own.id]);
    await execute("DELETE FROM external_references WHERE entity_type = 'project' AND external_id = ?", [own.public_id]);
  });
});

describe("a pushed development file", () => {
  it("creates the development as a draft of the company, with its unit types and payment plan", async () => {
    const { imports: [result] } = await pushFile(key, "/listings.xml", file("First tagline"));
    expect(result, JSON.stringify(result)).toMatchObject({ accepted: 1 });
    const items = await query("SELECT fi.status, fi.errors FROM feed_import_items fi JOIN feed_imports r ON r.id = fi.import_id WHERE r.public_id = ?", [result.id]);
    expect(items.map((item) => item.status), JSON.stringify(items)).toEqual(["success"]);

    const row = await project();
    expect(row).toMatchObject({ tagline: "First tagline", moderation_status: "draft", organization_id: company.organization_id });
    const units = await query("SELECT unit_type FROM project_unit_types WHERE project_id = ? ORDER BY id", [row.id]);
    expect(units.map((unit) => unit.unit_type)).toEqual(["apartment", "apartment", "penthouse"]);
    const plans = await query("SELECT id FROM project_payment_plans WHERE project_id = ?", [row.id]);
    expect(plans).toHaveLength(1);
  });

  it("holds a change to a published development for approval", async () => {
    const row = await project();
    await execute("UPDATE projects SET moderation_status = 'published', is_publicly_visible = 1, published_at = NOW(3) WHERE id = ?", [row.id]);
    // As publishing does: the development appears in the public projection.
    await execute("CALL sp_rebuild_project_canonical_path(?)", [row.id]);
    await execute("CALL sp_refresh_project_search(?)", [row.id]);
    expect(await queryOne("SELECT 1 AS ok FROM project_search WHERE project_id = ?", [row.id])).toBeTruthy();
    const { imports: [result] } = await pushFile(key, "/listings.xml", file("Second tagline"));
    expect(result.accepted).toBe(1);
    const after = await project();
    expect(after).toMatchObject({ tagline: "Second tagline", moderation_status: "published" });
    expect(after.pending_revision_id).toBeTruthy();
  });
});
