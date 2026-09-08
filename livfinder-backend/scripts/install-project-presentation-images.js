#!/usr/bin/env node
/**
 * Installs the five bundled presentation renders on projects that currently
 * have no gallery. The images are intentionally reused in rotation: this is a
 * test/demo presentation aid, not a claim that a render is official developer
 * photography.
 *
 * Existing project media is never replaced. Re-running is safe.
 *
 *   npm run media:project-presentation
 *   npm run media:project-presentation -- --dry-run
 */
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { query, execute, callProcedure } from "../src/db/query.js";
import { withTransaction } from "../src/db/transaction.js";
import { closePool } from "../src/db/pool.js";
import { storeImage } from "../src/modules/media/media.service.js";
import logger from "../src/config/logger.js";

const ASSET_DIRECTORY = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../assets/project-presentation"
);

const PRESENTATION_IMAGES = [
  { file: "marina-waterfront.webp", alt: "Luxury residences overlooking a Mediterranean marina" },
  { file: "gulf-waterfront-towers.webp", alt: "Contemporary waterfront residential towers" },
  { file: "tropical-resort-towers.webp", alt: "Tropical beachfront residential resort" },
  { file: "oasis-villas.webp", alt: "Landscaped luxury villa community" },
  { file: "urban-stone-residences.webp", alt: "Contemporary stone city residences" },
];

async function projectsWithoutMedia() {
  return query(
    `SELECT p.id, p.public_id, p.name, p.slug
       FROM projects p
      WHERE p.deleted_at IS NULL
        AND NOT EXISTS (
          SELECT 1
            FROM media_attachments ma
           WHERE ma.attachable_type = 'project'
             AND ma.attachable_id = p.id
             AND ma.role IN ('gallery', 'cover')
        )
      ORDER BY p.id ASC`
  );
}

async function storePresentationImages() {
  const assets = [];
  for (const image of PRESENTATION_IMAGES) {
    const buffer = await fs.readFile(path.join(ASSET_DIRECTORY, image.file));
    assets.push(
      await storeImage({
        buffer,
        originalFileName: image.file,
        scope: "projects/presentation",
        altText: image.alt,
        caption: "AI-generated presentation render",
        source: "generated",
      })
    );
  }
  return assets;
}

export async function installProjectPresentationImages({ dryRun = false } = {}) {
  const projects = await projectsWithoutMedia();
  if (dryRun) {
    return {
      dryRun: true,
      bundledImages: PRESENTATION_IMAGES.length,
      projectsToUpdate: projects.length,
      projects: projects.map((project) => project.name),
    };
  }
  if (!projects.length) {
    return { bundledImages: PRESENTATION_IMAGES.length, projectsUpdated: 0, note: "every project already has media" };
  }

  const assets = await storePresentationImages();
  for (const [index, project] of projects.entries()) {
    const asset = assets[index % assets.length];
    await withTransaction(async (connection) => {
      await execute(
        `INSERT INTO media_attachments
           (media_asset_id, attachable_type, attachable_id, role, sort_order, is_primary, caption, created_at)
         VALUES (?, 'project', ?, 'gallery', 0, 1, 'AI-generated presentation render', NOW(3))
         ON DUPLICATE KEY UPDATE sort_order = 0, is_primary = 1,
                                 caption = 'AI-generated presentation render'`,
        [asset.id, project.id],
        connection
      );
      await execute(
        "UPDATE projects SET cover_image_url = ?, updated_at = NOW(3) WHERE id = ?",
        [asset.url, project.id],
        connection
      );
    });
  }

  await callProcedure("sp_refresh_project_search", [null]);
  return {
    bundledImages: assets.length,
    projectsUpdated: projects.length,
    assignment: projects.map((project, index) => ({
      project: project.name,
      image: PRESENTATION_IMAGES[index % PRESENTATION_IMAGES.length].file,
    })),
  };
}

const invokedDirectly = process.argv[1] && process.argv[1].endsWith("install-project-presentation-images.js");
if (invokedDirectly) {
  installProjectPresentationImages({ dryRun: process.argv.includes("--dry-run") })
    .then((summary) => {
      logger.info(summary, "project presentation images installed");
      console.log(JSON.stringify(summary, null, 2));
    })
    .catch((error) => {
      console.error(error);
      process.exitCode = 1;
    })
    .finally(() => closePool());
}
