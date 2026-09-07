#!/usr/bin/env node
/**
 * Gives every publishable project a real gallery.
 *
 * The demo seed ships `cdn.livfinder.com` cover URLs that resolve to nothing in
 * development, and no `media_attachments` at all — so a project card fell back
 * to its lettered mark and the detail gallery had one placeholder in it. This
 * attaches photographs that are already in the media store (the ones
 * `import-frontend-media.js` imported from the frontend's `public/images`) to
 * each project, and points `projects.cover_image_url` at the primary.
 *
 * Nothing is invented and nothing new is uploaded: these are the same
 * photographs the listing catalogue already uses. A development's gallery is
 * assigned deterministically from the project's own id, so two runs produce the
 * same result and a project keeps the same imagery between them.
 *
 * Existing data is preserved: a project that already has gallery attachments is
 * skipped, so real imagery uploaded through the admin wizard is never replaced.
 *
 *   node scripts/attach-project-media.js [--per-project 5] [--dry-run]
 */
import { query, execute, callProcedure } from "../src/db/query.js";
import { withTransaction } from "../src/db/transaction.js";
import { closePool } from "../src/db/pool.js";
import logger from "../src/config/logger.js";

function parseArgs(argv) {
  const args = { perProject: 5, dryRun: false };
  for (let index = 0; index < argv.length; index += 1) {
    if (argv[index] === "--per-project") args.perProject = Number(argv[++index]);
    else if (argv[index] === "--dry-run") args.dryRun = true;
  }
  return args;
}

/** Photographs this deployment can actually serve. */
async function servableAssets() {
  return query(
    `SELECT id, COALESCE(cdn_url, url) AS url
       FROM media_assets
      WHERE deleted_at IS NULL
        AND media_type = 'image'
        AND COALESCE(cdn_url, url) NOT LIKE 'https://cdn.livfinder.com/%'
      ORDER BY id ASC`
  );
}

async function projectsNeedingMedia() {
  return query(
    `SELECT p.id, p.name,
            (SELECT COUNT(*) FROM media_attachments ma
              WHERE ma.attachable_type = 'project' AND ma.attachable_id = p.id
                AND ma.role IN ('gallery', 'cover')) AS attachment_count
       FROM projects p
      WHERE p.deleted_at IS NULL
      ORDER BY p.id ASC`
  );
}

export async function attachProjectMedia({ perProject = 5, dryRun = false } = {}) {
  const assets = await servableAssets();
  if (!assets.length) {
    return { assets: 0, projects: 0, attached: 0, note: "no servable images in the media store" };
  }

  const projects = await projectsNeedingMedia();
  const pending = projects.filter((project) => Number(project.attachment_count) === 0);
  const summary = { assets: assets.length, projects: projects.length, pending: pending.length, attached: 0, skipped: projects.length - pending.length };

  if (dryRun) return { ...summary, dryRun: true };

  const count = Math.max(1, Math.min(assets.length, Number(perProject) || 5));

  for (const [index, project] of pending.entries()) {
    // Deterministic and distinct: each project starts at a different offset in
    // the pool, so neighbouring cards in a rail do not repeat the same picture.
    const offset = (index * count) % assets.length;
    const gallery = Array.from({ length: count }, (_, position) => assets[(offset + position) % assets.length]);

    await withTransaction(async (connection) => {
      for (const [position, asset] of gallery.entries()) {
        await execute(
          `INSERT INTO media_attachments
             (media_asset_id, attachable_type, attachable_id, role, sort_order, is_primary, created_at)
           VALUES (?, 'project', ?, 'gallery', ?, ?, NOW(3))
           ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order), is_primary = VALUES(is_primary)`,
          [asset.id, project.id, position, position === 0 ? 1 : 0],
          connection
        );
      }
      // The card reads `cover_image_url`; keeping it as the primary gallery
      // image is what stops a card and its detail page showing different photos.
      await execute("UPDATE projects SET cover_image_url = ? WHERE id = ?", [gallery[0].url, project.id], connection);
    });
    summary.attached += gallery.length;
  }

  // `image_count` and `cover_image_url` live in the projection.
  await callProcedure("sp_refresh_project_search", [null]);
  return summary;
}

const invokedDirectly = process.argv[1] && process.argv[1].endsWith("attach-project-media.js");
if (invokedDirectly) {
  const args = parseArgs(process.argv.slice(2));
  attachProjectMedia(args)
    .then((summary) => {
      logger.info(summary, "project media attached");
      console.log(JSON.stringify(summary, null, 2));
    })
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    })
    .finally(() => closePool());
}
