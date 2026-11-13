import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { cleanupUsers, createDisposablePortalOwner, execute, queryOne } from "../helpers/testApp.js";
import { closePool } from "../../src/db/pool.js";
import { ensureImportConnection, importProviderId } from "../../src/modules/imports/importConnection.js";
import { requeueStalledImports } from "../../src/modules/imports/importRunner.js";
import { ulid } from "../../src/utils/ids.js";

/**
 * A long import (the 16,529-listing LuxuryProperty.com file runs for half an hour) must not be
 * taken for stranded while it is still working: only an import with no listing processed for
 * five minutes is put back in the queue.
 */

let owner;
let providerId;
let ctx;
const runs = [];

async function runningImport({ lastProcessedMinutesAgo }) {
  const publicId = ulid();
  const { insertId } = await execute(
    `INSERT INTO feed_imports (public_id, connection_id, provider_id, account_id, import_type, entity_type, status, total_rows,
                               deletion_mode, max_deletion_percent, started_at, created_at)
     VALUES (?, ?, ?, ?, 'full', 'listing', 'running', 2, 'none', 20, DATE_SUB(NOW(3), INTERVAL 40 MINUTE), DATE_SUB(NOW(3), INTERVAL 40 MINUTE))`,
    [publicId, ctx.connectionId, providerId, ctx.accountId]
  );
  runs.push(insertId);
  await execute(
    `INSERT INTO feed_import_items (import_id, source_row, external_id, entity_type, operation, status, processed_at)
     VALUES (?, 1, 'A', 'listing', 'create', 'success', DATE_SUB(NOW(3), INTERVAL ? MINUTE)),
            (?, 2, 'B', 'listing', 'create', 'queued', NULL)`,
    [insertId, lastProcessedMinutesAgo, insertId]
  );
  return insertId;
}

const statusOf = async (id) => (await queryOne("SELECT status FROM feed_imports WHERE id = ?", [id])).status;

beforeAll(async () => {
  owner = await createDisposablePortalOwner({ prefix: "import-stall" });
  const { account_id: accountId } = await queryOne("SELECT account_id FROM account_members WHERE user_id = ? AND role = 'owner'", [owner.id]);
  providerId = await importProviderId();
  ctx = { ...(await ensureImportConnection({ organizationId: null, accountId, name: "Import stall test" })), accountId };
});

afterAll(async () => {
  for (const id of runs) {
    await execute("DELETE FROM feed_import_items WHERE import_id = ?", [id]);
    await execute("DELETE FROM feed_imports WHERE id = ?", [id]);
  }
  await execute("DELETE FROM integration_connections WHERE account_id = ? AND organization_id IS NULL", [ctx.accountId]);
  await cleanupUsers([owner.email]);
  await closePool();
});

describe("a long-running import", () => {
  it("is left alone while it is still processing listings, however long ago it started", async () => {
    const busy = await runningImport({ lastProcessedMinutesAgo: 1 });
    await requeueStalledImports(providerId);
    expect(await statusOf(busy)).toBe("running");
  });

  it("is put back in the queue once nothing has been processed for five minutes", async () => {
    const stalled = await runningImport({ lastProcessedMinutesAgo: 10 });
    await requeueStalledImports(providerId);
    expect(await statusOf(stalled)).toBe("queued");
  });
});
