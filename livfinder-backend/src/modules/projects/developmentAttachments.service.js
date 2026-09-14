import { callProcedure, execute, query, queryOne, queryValue } from "../../db/query.js";
import { AppError } from "../../utils/errors.js";
import { ulid } from "../../utils/ids.js";

/**
 * A development's files and links, managed by its developer from the portal.
 *
 * Floor plans (`floor_plans`), the brochure (a `brochure` media attachment), other documents
 * (`documents`, gated by default), the video (`projects.video_url`) and virtual tours
 * (`virtual_tours`). Before this, only LivFinder's admin wizard could add any of them; the
 * portal form had no way to attach a floor plan or a brochure to a development at all.
 *
 * Every change an owner makes to a published development sends it back for review, the same
 * rule as a listing: the public page would otherwise show material no moderator has seen.
 */

/** The portal's document types for developments (frontend documentTypes.js DEVELOPMENT_DOCS). */
export const DEVELOPMENT_DOCUMENT_TYPES = ["brochure", "price_list", "payment_plan", "noc", "spec_sheet", "contract", "other"];

/** One development owned by the caller's account, or a 404 that confirms nothing. */
export async function ownedDevelopment(accountId, identifier) {
  const project = await queryOne(
    `SELECT p.id, p.public_id, p.name, p.moderation_status
       FROM projects p
       JOIN organizations o ON o.id = p.organization_id AND o.deleted_at IS NULL
      WHERE (p.public_id = ? OR p.slug = ?) AND p.deleted_at IS NULL AND o.account_id = ?
      LIMIT 1`,
    [String(identifier), String(identifier), accountId]
  );
  if (!project) throw AppError.notFound("That development was not found.");
  if (project.moderation_status === "archived") throw AppError.conflict("An archived development cannot be edited.");
  return project;
}

/** Every attachment, in the shape the portal's media manager lists (`toAttachment`). */
export async function developmentAttachments(projectId) {
  const [plans, brochures, documents, project, tours] = await Promise.all([
    query(
      `SELECT fp.id, fp.name, COALESCE(a.cdn_url, a.url) AS url
         FROM floor_plans fp LEFT JOIN media_assets a ON a.id = fp.media_asset_id
        WHERE fp.project_id = ? ORDER BY fp.sort_order, fp.id`,
      [projectId]
    ),
    query(
      `SELECT a.public_id, ma.caption, COALESCE(a.cdn_url, a.url) AS url
         FROM media_attachments ma JOIN media_assets a ON a.id = ma.media_asset_id
        WHERE ma.attachable_type = 'project' AND ma.attachable_id = ? AND ma.role = 'brochure'
        ORDER BY ma.sort_order, ma.id`,
      [projectId]
    ),
    query(
      `SELECT d.public_id, d.document_type, d.title, COALESCE(a.cdn_url, a.url) AS url
         FROM documents d LEFT JOIN media_assets a ON a.id = d.media_asset_id
        WHERE d.owner_type = 'project' AND d.owner_id = ? AND d.deleted_at IS NULL
        ORDER BY d.id`,
      [projectId]
    ),
    queryOne("SELECT video_url FROM projects WHERE id = ?", [projectId]),
    query(
      "SELECT public_id, title, embed_url FROM virtual_tours WHERE project_id = ? AND status <> 'archived' ORDER BY id",
      [projectId]
    ),
  ]);
  return [
    ...plans.map((plan) => ({ id: `floor_plan-${plan.id}`, type: "floor_plan", url: plan.url, label: plan.name })),
    ...brochures.map((item) => ({
      id: `brochure-${item.public_id}`,
      type: "document",
      documentType: "brochure",
      url: item.url,
      label: item.caption || "Brochure",
    })),
    ...documents.map((item) => ({
      id: `document-${item.public_id}`,
      type: "document",
      documentType: item.document_type,
      url: item.url,
      label: item.title,
    })),
    ...(project?.video_url ? [{ id: "video", type: "video", url: project.video_url, label: "Video" }] : []),
    ...tours.map((tour) => ({ id: `tour-${tour.public_id}`, type: "virtual_tour", url: tour.embed_url, label: tour.title || "Virtual tour" })),
  ];
}

/** A stored asset attached as a floor plan, the brochure, or a typed document. */
export async function attachDevelopmentFile({ projectId, assetId, mediaType, documentType, caption, userId }) {
  if (mediaType === "floor_plan") {
    const next = Number(await queryValue("SELECT COALESCE(MAX(sort_order), -1) + 1 FROM floor_plans WHERE project_id = ?", [projectId]));
    await execute(
      `INSERT INTO floor_plans (project_id, name, media_asset_id, is_public, requires_lead, sort_order, created_at, updated_at)
       VALUES (?, ?, ?, 1, 0, ?, NOW(3), NOW(3))`,
      [projectId, caption || "Floor plan", assetId, next]
    );
    return;
  }
  if (!DEVELOPMENT_DOCUMENT_TYPES.includes(documentType)) {
    throw AppError.validation("Some information is invalid.", { tag: "Choose a document type for this development." });
  }
  if (documentType === "brochure") {
    await execute(
      `INSERT INTO media_attachments (media_asset_id, attachable_type, attachable_id, role, sort_order, is_primary, caption, attached_by_user_id, created_at)
       VALUES (?, 'project', ?, 'brochure', 0, 0, ?, ?, NOW(3))`,
      [assetId, projectId, caption || "Brochure", userId]
    );
    return;
  }
  await execute(
    `INSERT INTO documents (public_id, media_asset_id, owner_type, owner_id, document_type, title, visibility, status, uploaded_by_user_id, created_at, updated_at)
     VALUES (?, ?, 'project', ?, ?, ?, 'gated', 'active', ?, NOW(3), NOW(3))`,
    [ulid(), assetId, projectId, documentType, caption || documentType.replace("_", " "), userId]
  );
}

/** A hosted video (the project's one `video_url`) or a virtual tour. */
export async function addDevelopmentLink({ projectId, mediaType, url, caption }) {
  if (mediaType === "video") {
    await execute("UPDATE projects SET video_url = ?, updated_at = NOW(3) WHERE id = ?", [url, projectId]);
    return;
  }
  await execute(
    `INSERT INTO virtual_tours (public_id, project_id, title, tour_type, provider, embed_url, status, is_public, created_at, updated_at)
     VALUES (?, ?, ?, '360_photo', 'other', ?, 'ready', 1, NOW(3), NOW(3))`,
    [ulid(), projectId, caption || "Virtual tour", url]
  );
}

/** Removes one attachment by the id `developmentAttachments` gave it. */
export async function removeDevelopmentAttachment({ projectId, attachmentId }) {
  const [kind, ...rest] = String(attachmentId).split("-");
  const ref = rest.join("-");
  let affected = 0;
  if (kind === "floor_plan") {
    affected = (await execute("DELETE FROM floor_plans WHERE id = ? AND project_id = ?", [Number(ref) || 0, projectId])).affectedRows;
  } else if (kind === "brochure") {
    affected = (
      await execute(
        `DELETE ma FROM media_attachments ma JOIN media_assets a ON a.id = ma.media_asset_id
          WHERE ma.attachable_type = 'project' AND ma.attachable_id = ? AND ma.role = 'brochure' AND a.public_id = ?`,
        [projectId, ref]
      )
    ).affectedRows;
  } else if (kind === "document") {
    affected = (
      await execute(
        "UPDATE documents SET deleted_at = NOW(3) WHERE owner_type = 'project' AND owner_id = ? AND public_id = ? AND deleted_at IS NULL",
        [projectId, ref]
      )
    ).affectedRows;
  } else if (kind === "video") {
    affected = (await execute("UPDATE projects SET video_url = NULL, updated_at = NOW(3) WHERE id = ? AND video_url IS NOT NULL", [projectId])).affectedRows;
  } else if (kind === "tour") {
    affected = (await execute("UPDATE virtual_tours SET status = 'archived' WHERE project_id = ? AND public_id = ?", [projectId, ref])).affectedRows;
  }
  if (!affected) throw AppError.notFound("That attachment was not found.");
}

/** A published development its developer changed goes back to review, off the public site. */
export async function sendDevelopmentBackForReview(project) {
  if (project.moderation_status !== "published") return false;
  await execute(
    "UPDATE projects SET moderation_status = 'pending', rejection_reason = NULL, is_publicly_visible = 0, updated_at = NOW(3) WHERE id = ?",
    [project.id]
  );
  await callProcedure("sp_refresh_project_search", [project.id]);
  return true;
}
