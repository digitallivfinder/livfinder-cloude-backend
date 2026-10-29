import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupProjects, execute, query, queryOne } from "../helpers/testApp.js";
import { saveAccountFeed } from "../../src/modules/feeds/feedSources.repository.js";
import { runFeed } from "../../src/modules/feeds/feedRunner.js";
import { sampleXml } from "../../src/modules/feeds/feedTemplates.js";
import { closePool } from "../../src/db/pool.js";

/**
 * A developer's development feed (0063): projects with unit types and payment plans arrive as
 * drafts; a change to a published one waits for approval (0061).
 *
 * Uses a seeded developer company approved for developments. Its add-on row and any feed it had
 * are restored, and every project the run created is removed.
 */

let company = null;
let feed = null;
let addonBefore = null;
const created = [];
const externalId = `QA-DEV-${Date.now()}`;

// The sample file, with this run's own id and no image URLs (no network in tests).
const file = (tagline) =>
  sampleXml("developments")
    .replace("<externalId>ABC-1001</externalId>", `<externalId>${externalId}</externalId>`)
    .replace(/<tagline>[^<]*<\/tagline>/, `<tagline>${tagline}</tagline>`)
    .replace(/\s*<images>[\s\S]*?<\/images>/, "");
const serve = (body) => async (url) => ({ buffer: Buffer.from(body), etag: null, lastModified: null, contentType: "application/xml", finalUrl: url });
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
        AND NOT EXISTS (SELECT 1 FROM feed_sources fs WHERE fs.account_id = a.id AND fs.category = 'developments')
      ORDER BY o.id LIMIT 1`
  );
  expect(company, "a developer company approved for developments").toBeTruthy();
  addonBefore = await queryOne("SELECT * FROM account_addons WHERE account_id = ? AND addon_code = 'integrations'", [company.account_id]);
  await execute(
    `INSERT INTO account_addons (public_id, account_id, addon_code, status, started_at)
     VALUES (?, ?, 'integrations', 'active', NOW(3)) ON DUPLICATE KEY UPDATE status = 'active', ends_at = NULL`,
    [`01QADEVFEED${String(Date.now()).slice(-8)}${company.account_id}`.slice(0, 26).padEnd(26, "0"), company.account_id]
  );
  feed = await saveAccountFeed({
    accountId: company.account_id,
    organizationId: company.organization_id,
    category: "developments",
    url: "https://feeds.example.com/developments.xml",
  });
});

afterAll(async () => {
  const row = await project();
  if (row) created.push(row.public_id);
  await execute("DELETE FROM external_references WHERE entity_type = 'project' AND external_id = ?", [externalId]);
  await cleanupProjects(created);
  if (feed) await execute("DELETE FROM feed_sources WHERE id = ?", [feed.id]);
  if (!addonBefore) {
    await execute("DELETE FROM account_addons WHERE account_id = ? AND addon_code = 'integrations'", [company.account_id]);
  } else {
    await execute("UPDATE account_addons SET status = ?, ends_at = ?, cancelled_at = ? WHERE id = ?", [
      addonBefore.status, addonBefore.ends_at, addonBefore.cancelled_at, addonBefore.id,
    ]);
  }
  await closePool();
});

describe("a development feed", () => {
  it("creates the development as a draft of the company, with its unit types and payment plan", async () => {
    const result = await runFeed(feed.id, { fetchFile: serve(file("First tagline")) });
    expect(result, JSON.stringify(result)).toMatchObject({ outcome: "imported" });
    const items = await query("SELECT fi.status, fi.errors FROM feed_import_items fi JOIN feed_imports r ON r.id = fi.import_id WHERE r.public_id = ?", [result.importId]);
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
    const result = await runFeed(feed.id, { fetchFile: serve(file("Second tagline")) });
    expect(result.outcome).toBe("imported");
    const after = await project();
    expect(after).toMatchObject({ tagline: "Second tagline", moderation_status: "published" });
    expect(after.pending_revision_id).toBeTruthy();
  });
});
