import logger from "../../config/logger.js";
import { callProcedure, execute, query, queryOne, queryValue } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { recordAudit } from "../system/audit.service.js";
import * as importsRepo from "../imports/imports.repository.js";
import { assertLocationComplete, importImages, payloadHash, resolveImportLocation } from "../imports/listingImport.service.js";
import { developmentSchema, upsertDevelopment } from "../admin/admin.mutations.js";
import { beginDeveloperChange } from "../projects/projectRevisions.service.js";

/**
 * Developments from a feed (0063): each entry is a project with its unit types and payment plans.
 *
 * Held to the same rules as a development a developer saves in the portal. A new one arrives as
 * a draft (the company submits it), a change to a published one waits for approval while the
 * site keeps the approved version (0061), and the developer's id is matched to the project through
 * `external_references` under the account's own connection. Developments that leave the file are
 * not taken down automatically; the company does that in the portal.
 */

const DEVELOPMENTS_ROOT_ID = 7;

function fieldsFromIssues(issues) {
  const fields = {};
  for (const issue of issues) {
    const key = issue.path.join(".") || "_";
    if (!fields[key]) fields[key] = issue.message;
  }
  return fields;
}

/** Location names (or an id) to the per-level ids a project stores. */
async function locationIds(location) {
  const id = await resolveImportLocation(location);
  await assertLocationComplete(id);
  const row = await queryOne("SELECT id, level, country_id, state_id, city_id, community_id FROM locations WHERE id = ?", [id]);
  const own = (level) => (row.level === level ? row.id : null);
  return {
    countryId: own("country") ?? row.country_id ?? null,
    stateId: own("state") ?? row.state_id ?? null,
    cityId: own("city") ?? row.city_id ?? null,
    communityId: own("community") ?? own("district") ?? row.community_id ?? null,
    subCommunityId: own("sub_community"),
  };
}

async function developerBrandFor(organizationId) {
  return queryValue(
    `SELECT b.public_id FROM projects p JOIN brands b ON b.id = p.developer_brand_id AND b.deleted_at IS NULL
      WHERE p.organization_id = ? AND p.deleted_at IS NULL
      GROUP BY b.id, b.public_id ORDER BY COUNT(*) DESC, b.id ASC LIMIT 1`,
    [organizationId]
  );
}

async function buildPayload({ record, client, ctx }) {
  const warnings = [];
  const { externalId, currency, location, images, unitTypes = [], paymentPlans = [], ...own } = record;
  const ids = await locationIds(location);
  let gallery;
  if (images?.length) {
    const results = await importImages({ urls: [...new Set(images)].slice(0, 80), ctx, accountId: client.accountId, userId: client.createdByUserId });
    for (const failure of results.filter((result) => result.error)) warnings.push(`Image not added (${failure.error}): ${failure.url}`);
    gallery = results
      .filter((result) => result.publicId)
      .map((result, index) => ({ mediaAssetId: result.publicId, isPrimary: index === 0, sortOrder: index }));
  }
  const payload = {
    ...own,
    ...ids,
    ...(currency ? { currencyCode: currency } : {}),
    ...(location?.address ? { address: location.address } : {}),
    ...(location?.latitude !== undefined ? { latitude: location.latitude } : {}),
    ...(location?.longitude !== undefined ? { longitude: location.longitude } : {}),
    unitTypes: unitTypes.map(({ currency: unitCurrency, ...unit }) => ({ ...unit, ...(unitCurrency ? { currencyCode: unitCurrency } : {}) })),
    paymentPlans,
    ...(gallery ? { gallery } : {}),
  };
  const parsed = developmentSchema.safeParse(payload);
  if (!parsed.success) {
    throw new AppError("Some information in this development is invalid.", { status: 422, code: "VALIDATION_ERROR", fields: fieldsFromIssues(parsed.error.issues) });
  }
  return { payload: parsed.data, warnings, imagesAttached: gallery?.length ?? 0 };
}

async function findReference(ctx, externalId) {
  return queryOne(
    `SELECT er.id AS reference_id, er.payload_hash, er.entity_id AS project_id
       FROM external_references er
      WHERE er.provider_id = ? AND er.connection_id = ? AND er.entity_type = 'project' AND er.external_id = ?
      LIMIT 1`,
    [ctx.providerId, ctx.connectionId, externalId]
  );
}

/** One development in, created or updated; returns `{ operation, project, warnings }`. */
export async function importDevelopment({ client, ctx, record, importId = null }) {
  if (!client.organizationId) {
    throw new AppError("Developments belong to a developer company; this account has none.", { status: 403, code: "ORGANIZATION_REQUIRED" });
  }
  const approved = await queryValue(
    `SELECT aca.id FROM account_category_access aca JOIN categories c ON c.id = aca.category_id
      WHERE aca.account_id = ? AND COALESCE(c.root_category_id, c.id) = ? AND aca.status = 'approved' LIMIT 1`,
    [client.accountId, DEVELOPMENTS_ROOT_ID]
  );
  if (!approved) {
    throw new AppError("This account is not approved to list developments.", { status: 403, code: "CATEGORY_NOT_APPROVED" });
  }

  const hash = payloadHash(record);
  let reference = await findReference(ctx, record.externalId);
  // A development made in LivFinder shows on the link by its own id; sent back, it is the same one.
  if (!reference) {
    const own = await queryOne(
      "SELECT id AS project_id FROM projects WHERE public_id = ? AND organization_id = ? AND deleted_at IS NULL LIMIT 1",
      [record.externalId, client.organizationId]
    );
    if (own) reference = { reference_id: null, payload_hash: null, project_id: own.project_id };
  }
  let project = reference
    ? await queryOne("SELECT id, public_id, name, moderation_status FROM projects WHERE id = ? AND deleted_at IS NULL", [reference.project_id])
    : null;
  if (reference && !project) {
    await execute("DELETE FROM external_references WHERE id = ?", [reference.reference_id]);
    reference = null;
  }
  if (project && reference.payload_hash === hash) return { operation: "unchanged", project, warnings: [] };

  const { payload, warnings, imagesAttached } = await buildPayload({ record, client, ctx });
  let operation;
  if (!project) {
    const developerId = await developerBrandFor(client.organizationId);
    const created = await upsertDevelopment({
      identifier: null,
      payload: { ...payload, ...(developerId ? { developerId } : {}), acceptsInquiries: true },
      userId: client.createdByUserId,
    });
    // Arrives as a draft: the company submits it from the portal (owner's rule, 2026-10-29).
    await execute(
      `UPDATE projects SET organization_id = ?, moderation_status = 'draft', is_publicly_visible = 0, rejection_reason = NULL, updated_at = NOW(3)
        WHERE public_id = ?`,
      [client.organizationId, created.id]
    );
    project = await queryOne("SELECT id, public_id, name, moderation_status FROM projects WHERE public_id = ?", [created.id]);
    await callProcedure("sp_refresh_project_search", [project.id]);
    operation = "create";
  } else {
    // A change to a published development waits for approval; the site keeps the approved version.
    await beginDeveloperChange({ projectId: project.id, userId: client.createdByUserId, change: "Updated by the development feed" });
    await upsertDevelopment({ identifier: project.public_id, payload, userId: client.createdByUserId });
    operation = "update";
  }

  await execute(
    `INSERT INTO external_references
       (provider_id, connection_id, entity_type, entity_id, external_id, remote_status, payload_hash,
        first_synced_at, last_synced_at, last_success_at, sync_count, created_at)
     VALUES (?, ?, 'project', ?, ?, 'live', ?, NOW(3), NOW(3), NOW(3), 1, NOW(3))
     ON DUPLICATE KEY UPDATE entity_id = VALUES(entity_id), payload_hash = VALUES(payload_hash), remote_status = 'live',
                             last_synced_at = NOW(3), last_success_at = NOW(3), sync_count = sync_count + 1`,
    [ctx.providerId, ctx.connectionId, project.id, record.externalId, warnings.length ? null : hash]
  );
  await recordAudit({
    action: operation === "create" ? "development.imported" : "development.import_updated",
    subjectType: "project",
    subjectId: project.id,
    subjectLabel: project.name,
    userId: client.createdByUserId,
    actorType: "api",
    actorLabel: `Development feed "${client.name}"`,
    metadata: { externalId: record.externalId, importId, feedId: client.feedPublicId },
  });
  return { operation, project, warnings, media: { attached: imagesAttached, failed: [] } };
}

/** Processes a feed run's queued development entries, one at a time. */
export async function importDevelopmentsRun({ run, client, ctx }) {
  const items = await query(
    "SELECT id, raw_payload FROM feed_import_items WHERE import_id = ? AND status = 'queued' ORDER BY source_row ASC, id ASC",
    [run.id]
  );
  for (const item of items) {
    try {
      const record = typeof item.raw_payload === "string" ? JSON.parse(item.raw_payload) : item.raw_payload;
      const outcome = await importDevelopment({ client, ctx, record, importId: run.public_id });
      await importsRepo.recordItemSuccess(item.id, run.id, { ...outcome, listing: outcome.project });
    } catch (error) {
      if (!(error instanceof AppError) || error.status >= 500) logger.error({ err: error, itemId: item.id }, "development import item failed");
      await importsRepo.recordItemFailure(item.id, error).catch(() => {});
    }
  }
}
