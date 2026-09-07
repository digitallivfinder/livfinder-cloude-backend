-- =============================================================================
-- 070_media_extensions.sql
--
-- The parts of the media layer that are their own subject rather than a column
-- on an asset: video, virtual tours, floor plans with their rooms, the
-- resumable upload machinery, per-language captions and alt text, and the
-- gated-document flow that turns a brochure download into a lead.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

SET @now = NOW(3);
SET @today = CAST(CURDATE() AS CHAR) COLLATE utf8mb4_unicode_ci;

DROP TABLE IF EXISTS tmp_n;
CREATE TABLE tmp_n (n INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO tmp_n (n)
SELECT a.d + b.d * 10
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b;

-- -----------------------------------------------------------------------------
-- Video
--
-- A video asset is the same row in media_assets as an image, extended here with
-- everything that only applies to moving pictures. Held as a one-to-one
-- extension rather than as thirty nullable columns on every photograph.
-- -----------------------------------------------------------------------------
INSERT INTO media_assets
  (public_id, folder_id, account_id, uploaded_by_user_id, media_type,
   storage_disk, storage_location_id, storage_path, url, cdn_url, file_name,
   original_file_name, mime_type, extension, file_size_bytes, width, height,
   aspect_ratio, duration_seconds, checksum, source, blur_hash, dominant_color,
   alt_text, caption, credit, license_id, scan_status, processing_status,
   reference_count, tier, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('video:', l.id)), 26)),
  NULL, l.account_id, l.created_by_user_id, 'video',
  's3', sl.id,
  CONCAT('videos/', DATE_FORMAT(l.created_at, '%Y/%m'), '/',
         LEFT(MD5(CONCAT('video:', l.id)), 16), '/master.mp4'),
  CONCAT('https://media.livfinder.com/videos/', LEFT(MD5(CONCAT('video:', l.id)), 16), '/master.mp4'),
  CONCAT('https://cdn.livfinder.com/videos/', LEFT(MD5(CONCAT('video:', l.id)), 16), '/master.mp4'),
  'master.mp4', CONCAT(l.slug, '-tour.mp4'), 'video/mp4', 'mp4',
  40000000 + MOD(CONV(SUBSTRING(MD5(CONCAT('vsize:', l.id)), 1, 6), 16, 10), 900000000),
  3840, 2160, 1.77778,
  45 + MOD(CONV(SUBSTRING(MD5(CONCAT('vdur:', l.id)), 1, 4), 16, 10), 220),
  SHA2(CONCAT('video-content:', l.id), 256),
  'upload', NULL, '#1B2A3A',
  CONCAT('Video tour of ', l.title),
  CONCAT('Cinematic walkthrough — ', l.title),
  'Liv Finder Studios',
  (SELECT id FROM media_licenses WHERE code = 'agency-supplied' LIMIT 1),
  -- See 050_media.sql: 'skipped' is the truthful value for a file no scanner has looked at.
  'skipped', 'ready', 1, 'hot', l.created_at, @now
FROM listings l
JOIN (SELECT id FROM storage_locations WHERE code = 's3-primary-me' LIMIT 1) sl
WHERE l.status = 'active' AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasvideo:', l.id)), 1, 4), 16, 10), 4) = 0;

INSERT INTO video_assets
  (media_asset_id, duration_seconds, frame_rate, bitrate_kbps, video_codec,
   audio_codec, audio_channels, has_audio, hls_manifest_url, dash_manifest_url,
   poster_asset_id, thumbnail_sprite_url, thumbnail_vtt_url, provider,
   provider_asset_id, playback_id, is_downloadable, view_count, created_at, updated_at)
SELECT
  m.id, m.duration_seconds, 25.000,
  9000 + MOD(CONV(SUBSTRING(MD5(CONCAT('bitrate:', m.id)), 1, 4), 16, 10), 18000),
  'h264', 'aac', 2, 1,
  REPLACE(m.cdn_url, 'master.mp4', 'index.m3u8'),
  REPLACE(m.cdn_url, 'master.mp4', 'manifest.mpd'),
  poster.id,
  REPLACE(m.cdn_url, 'master.mp4', 'sprite.jpg'),
  REPLACE(m.cdn_url, 'master.mp4', 'thumbs.vtt'),
  'mux',
  LEFT(MD5(CONCAT('muxasset:', m.id)), 24),
  LEFT(MD5(CONCAT('muxplay:', m.id)), 22),
  0,
  MOD(CONV(SUBSTRING(MD5(CONCAT('vviews:', m.id)), 1, 5), 16, 10), 9000),
  m.created_at, @now
FROM media_assets m
LEFT JOIN media_assets poster
  ON poster.media_type = 'image'
 AND poster.account_id = m.account_id
 AND poster.id = (SELECT MIN(p2.id) FROM media_assets p2
                   WHERE p2.media_type = 'image' AND p2.account_id = m.account_id)
WHERE m.media_type = 'video';

-- Transcode ladder. One job per rendition, which is how a stuck 1080p run is
-- visible without inspecting the provider's console.
INSERT INTO video_transcode_jobs
  (media_asset_id, profile, target_resolution, target_bitrate_kbps, status,
   progress_percent, provider_job_id, error_message, attempts, compute_seconds,
   queued_at, started_at, finished_at)
SELECT
  m.id, p.profile, p.resolution, p.bitrate,
  CASE
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('tjob:', m.id, p.profile)), 1, 4), 16, 10), 40) = 0 THEN 'failed'
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('tjob:', m.id, p.profile)), 1, 4), 16, 10), 37) = 0 THEN 'processing'
    ELSE 'completed'
  END,
  CASE
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('tjob:', m.id, p.profile)), 1, 4), 16, 10), 40) = 0 THEN 0
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('tjob:', m.id, p.profile)), 1, 4), 16, 10), 37) = 0
      THEN 10 + MOD(CONV(SUBSTRING(MD5(CONCAT('prog:', m.id, p.profile)), 1, 4), 16, 10), 80)
    ELSE 100
  END,
  LEFT(MD5(CONCAT('provjob:', m.id, p.profile)), 20),
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('tjob:', m.id, p.profile)), 1, 4), 16, 10), 40) = 0
       THEN 'Source stream has a variable frame rate the encoder could not lock to. Re-ingest with a constant frame rate requested from the supplier.' END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('tjob:', m.id, p.profile)), 1, 4), 16, 10), 40) = 0 THEN 3 ELSE 1 END,
  ROUND(m.duration_seconds * p.compute_factor),
  m.created_at,
  DATE_ADD(m.created_at, INTERVAL 30 SECOND),
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('tjob:', m.id, p.profile)), 1, 4), 16, 10), 37) <> 0
       THEN DATE_ADD(m.created_at, INTERVAL 30 + ROUND(m.duration_seconds * p.compute_factor) SECOND) END
FROM media_assets m
JOIN (
  SELECT 'hls_240p'  AS profile, '426x240'   AS resolution,   400 AS bitrate, 0.4 AS compute_factor
  UNION ALL SELECT 'hls_480p',  '854x480',    1200, 0.6
  UNION ALL SELECT 'hls_720p',  '1280x720',   2800, 0.9
  UNION ALL SELECT 'hls_1080p', '1920x1080',  5500, 1.4
  UNION ALL SELECT 'hls_2160p', '3840x2160', 16000, 3.2
) AS p
WHERE m.media_type = 'video';

-- -----------------------------------------------------------------------------
-- Virtual tours
-- -----------------------------------------------------------------------------
INSERT INTO virtual_tours
  (public_id, listing_id, title, tour_type, provider, provider_tour_id,
   embed_url, thumbnail_asset_id, scene_count, scanned_area_sqm, captured_at,
   captured_by, status, is_public, view_count, median_duration_seconds,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('tour:', l.id)), 26)),
  l.id,
  CONCAT(l.title, ' — 3D tour'),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('ttype:', l.id)), 1, 4), 16, 10), 4),
      'matterport', '360_photo', 'walkthrough_video', 'floor_plan_3d'),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('tprov:', l.id)), 1, 4), 16, 10), 4),
      'matterport', 'kuula', 'giraffe360', 'cupix'),
  LEFT(MD5(CONCAT('tourid:', l.id)), 16),
  CONCAT('https://tours.livfinder.com/embed/', LEFT(MD5(CONCAT('tourid:', l.id)), 16)),
  cover.id,
  4 + MOD(CONV(SUBSTRING(MD5(CONCAT('scenes:', l.id)), 1, 4), 16, 10), 9),
  ROUND(COALESCE(re.built_area_sqm, 180) * 1.05, 2),
  DATE(DATE_SUB(l.created_at, INTERVAL 4 DAY)),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('capt:', l.id)), 1, 4), 16, 10), 3),
      'Liv Finder Capture Team', 'Giraffe360 Partner Network', 'Agency in-house photographer'),
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('tstat:', l.id)), 1, 4), 16, 10), 25) = 0
       THEN 'processing' ELSE 'ready' END,
  1,
  MOD(CONV(SUBSTRING(MD5(CONCAT('tviews:', l.id)), 1, 5), 16, 10), 4000),
  60 + MOD(CONV(SUBSTRING(MD5(CONCAT('tdur:', l.id)), 1, 4), 16, 10), 300),
  l.created_at, @now
FROM listings l
LEFT JOIN listing_real_estate re ON re.listing_id = l.id
LEFT JOIN media_attachments ma
  ON ma.attachable_type = 'listing' AND ma.attachable_id = l.id AND ma.is_primary = 1
LEFT JOIN media_assets cover ON cover.id = ma.media_asset_id
WHERE l.has_virtual_tour = 1;

INSERT INTO tour_scenes
  (virtual_tour_id, name, room_type, panorama_asset_id, initial_yaw,
   initial_pitch, initial_fov, position_x, position_y, position_z, floor_level,
   sort_order, created_at)
SELECT
  t.id,
  ELT(1 + n.n, 'Entrance hall', 'Living room', 'Kitchen', 'Dining room',
      'Principal bedroom', 'Principal ensuite', 'Second bedroom', 'Study',
      'Terrace', 'Roof terrace', 'Pool deck', 'Garage'),
  ELT(1 + n.n, 'entrance', 'living', 'kitchen', 'dining', 'bedroom', 'ensuite',
      'bedroom', 'study', 'terrace', 'terrace', 'pool', 'garage'),
  NULL,
  ROUND(MOD(CONV(SUBSTRING(MD5(CONCAT('yaw:', t.id, n.n)), 1, 4), 16, 10), 360), 3),
  0.000, 75.00,
  ROUND(MOD(CONV(SUBSTRING(MD5(CONCAT('px:', t.id, n.n)), 1, 4), 16, 10), 2000) / 100, 4),
  ROUND(MOD(CONV(SUBSTRING(MD5(CONCAT('py:', t.id, n.n)), 1, 4), 16, 10), 2000) / 100, 4),
  CASE WHEN n.n >= 9 THEN 3.2000 ELSE 1.6000 END,
  CASE WHEN n.n >= 9 THEN 1 ELSE 0 END,
  n.n + 1, @now
FROM virtual_tours t
JOIN tmp_n n ON n.n < t.scene_count;

-- Navigation hotspots stitch the scenes into a walkable path; information
-- hotspots are where the agent sells.
INSERT INTO tour_hotspots
  (scene_id, hotspot_type, label, description, yaw, pitch, target_scene_id,
   icon, sort_order)
SELECT
  s.id, 'navigation',
  CONCAT('Go to ', nxt.name), NULL,
  ROUND(MOD(CONV(SUBSTRING(MD5(CONCAT('hyaw:', s.id)), 1, 4), 16, 10), 360), 3),
  -8.000, nxt.id, 'arrow', 1
FROM tour_scenes s
JOIN tour_scenes nxt
  ON nxt.virtual_tour_id = s.virtual_tour_id AND nxt.sort_order = s.sort_order + 1;

INSERT INTO tour_hotspots
  (scene_id, hotspot_type, label, description, yaw, pitch, icon, sort_order)
SELECT
  s.id, 'info',
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('info:', s.id)), 1, 4), 16, 10), 5),
      'Gaggenau appliances', 'Full-height glazing', 'Marble throughout',
      'Smart home controls', 'Bespoke joinery'),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('info:', s.id)), 1, 4), 16, 10), 5),
      'Fully integrated Gaggenau appliance suite with a wine cabinet and a steam oven.',
      'Floor to ceiling glazing on two elevations, with motorised shading on a scene controller.',
      'Book-matched Calacatta marble to the floors and the principal bathroom walls.',
      'Lutron lighting, Sonos throughout and a Crestron panel at the entrance.',
      'Joinery by an Italian workshop, specified and installed for this unit.'),
  ROUND(MOD(CONV(SUBSTRING(MD5(CONCAT('iyaw:', s.id)), 1, 4), 16, 10), 360), 3),
  2.000, 'info', 2
FROM tour_scenes s
WHERE s.room_type IN ('living', 'kitchen', 'ensuite')
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasinfo:', s.id)), 1, 4), 16, 10), 2) = 0;

UPDATE virtual_tours t
JOIN (SELECT virtual_tour_id, COUNT(*) n FROM tour_scenes GROUP BY virtual_tour_id) s
  ON s.virtual_tour_id = t.id
SET t.scene_count = s.n;

-- -----------------------------------------------------------------------------
-- Floor plans
--
-- The rooms are rows because a buyer filtering on "study" needs the schedule of
-- accommodation to be queryable, not an image somebody has to open and read.
-- -----------------------------------------------------------------------------
INSERT INTO floor_plans
  (listing_id, name, floor_level, media_asset_id, interactive_svg_url,
   total_area_sqm, total_area_sqft, ceiling_height_m, scale_factor, is_public,
   requires_lead, sort_order, created_at, updated_at)
SELECT
  l.id,
  CASE WHEN n.n = 0 THEN 'Ground floor' ELSE CONCAT('Floor ', n.n) END,
  n.n, fp.id,
  CONCAT('https://cdn.livfinder.com/floorplans/', LEFT(MD5(CONCAT('fp:', l.id, n.n)), 16), '.svg'),
  ROUND(COALESCE(re.built_area_sqm, 160) / GREATEST(1, lv.levels), 2),
  ROUND(COALESCE(re.built_area_sqm, 160) / GREATEST(1, lv.levels) * 10.7639, 2),
  CASE WHEN n.n = 0 THEN 3.20 ELSE 2.95 END,
  0.020000,
  1,
  -- The dimensioned plan is gated; the marketing plan is not. Gating the
  -- detailed one is where a large share of the enquiry volume comes from.
  CASE WHEN n.n = 0 THEN 0 ELSE 1 END,
  n.n + 1, l.created_at, @now
FROM listings l
JOIN listing_real_estate re ON re.listing_id = l.id
JOIN (
  SELECT l2.id AS listing_id,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('levels:', l2.id)), 1, 4), 16, 10), 3) AS levels
  FROM listings l2
) AS lv ON lv.listing_id = l.id
JOIN tmp_n n ON n.n < lv.levels
LEFT JOIN media_assets fp
  ON fp.media_type = 'floor_plan'
 AND fp.id = (SELECT MIN(f2.id) FROM media_assets f2
               WHERE f2.media_type = 'floor_plan' AND f2.account_id = l.account_id)
WHERE l.has_floor_plan = 1;

INSERT INTO floor_plan_rooms
  (floor_plan_id, name, room_type, area_sqm, length_m, width_m, has_window,
   is_ensuite, sort_order)
SELECT
  fp.id, r.name, r.room_type,
  ROUND(fp.total_area_sqm * r.area_share, 2),
  ROUND(SQRT(fp.total_area_sqm * r.area_share) * 1.25, 2),
  ROUND(SQRT(fp.total_area_sqm * r.area_share) * 0.80, 2),
  r.has_window, r.is_ensuite, r.sort_order
FROM floor_plans fp
JOIN (
  SELECT 'Entrance hall' AS name, 'entrance' AS room_type, 0.06 AS area_share, 0 AS has_window, 0 AS is_ensuite, 1 AS sort_order, 0 AS ground_only
  UNION ALL SELECT 'Living room',      'living',    0.24, 1, 0, 2, 1
  UNION ALL SELECT 'Dining room',      'dining',    0.13, 1, 0, 3, 1
  UNION ALL SELECT 'Kitchen',          'kitchen',   0.12, 1, 0, 4, 1
  UNION ALL SELECT 'Guest cloakroom',  'powder_room', 0.03, 0, 0, 5, 1
  UNION ALL SELECT 'Principal bedroom','bedroom',   0.18, 1, 0, 6, 0
  UNION ALL SELECT 'Principal ensuite','ensuite',   0.08, 1, 1, 7, 0
  UNION ALL SELECT 'Second bedroom',   'bedroom',   0.12, 1, 0, 8, 0
  UNION ALL SELECT 'Family bathroom',  'bathroom',  0.05, 1, 0, 9, 0
  UNION ALL SELECT 'Study',            'study',     0.07, 1, 0, 10, 0
  UNION ALL SELECT 'Utility',          'laundry',   0.04, 0, 0, 11, 0
  UNION ALL SELECT 'Terrace',          'terrace',   0.10, 1, 0, 12, 0
) AS r
  ON (fp.floor_level = 0 AND r.ground_only = 1)
  OR (fp.floor_level > 0 AND r.ground_only = 0);

-- -----------------------------------------------------------------------------
-- Crops, captions, tags and translations
--
-- One asset, several aspect ratios: the same photograph has to work as a 16:9
-- hero, a 4:3 card and a 1:1 social tile without three separate uploads. Storing
-- the crop rather than a cropped file means a re-crop is a metadata change.
-- -----------------------------------------------------------------------------
INSERT INTO media_crops
  (media_asset_id, aspect_ratio, crop_x, crop_y, crop_width, crop_height,
   rotation_degrees, is_manual, created_by_user_id, created_at, updated_at)
SELECT
  m.id, r.ratio,
  -- The offset is expressed as a fraction of the slack left over, so the crop
  -- can never run past the edge of the frame whatever the ratio.
  ROUND((1 - r.width)  * MOD(CONV(SUBSTRING(MD5(CONCAT('cx:', m.id, r.ratio)), 1, 4), 16, 10), 101) / 100, 5),
  ROUND((1 - r.height) * MOD(CONV(SUBSTRING(MD5(CONCAT('cy:', m.id, r.ratio)), 1, 4), 16, 10), 101) / 100, 5),
  r.width, r.height, 0,
  CASE WHEN r.ratio = '16:9' THEN 1 ELSE 0 END,
  m.uploaded_by_user_id, m.created_at, @now
FROM media_assets m
JOIN (
  SELECT '16:9' AS ratio, 0.88000 AS width, 0.72000 AS height
  UNION ALL SELECT '4:3',  0.86000, 0.82000
  UNION ALL SELECT '1:1',  0.72000, 0.72000
  UNION ALL SELECT '3:2',  0.90000, 0.78000
) AS r
WHERE m.media_type = 'image'
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hascrop:', m.id)), 1, 4), 16, 10), 6) = 0;

INSERT INTO media_captions
  (media_asset_id, language_id, kind, format, url, is_default,
   is_auto_generated, transcript, created_at)
SELECT
  m.id, lg.language_id, 'subtitles', 'vtt',
  REPLACE(m.cdn_url, 'master.mp4', CONCAT('subs-', lg.code, '.vtt')),
  lg.is_default, lg.is_auto,
  CASE WHEN lg.is_default = 1
       THEN 'WEBVTT\n\n00:00:00.000 --> 00:00:06.000\nWelcome to this tour.\n\n00:00:06.000 --> 00:00:14.000\nThe entrance opens onto a double-height reception hall.' END,
  m.created_at
FROM media_assets m
JOIN (
  SELECT 1 AS language_id, 'en' AS code, 1 AS is_default, 0 AS is_auto
  UNION ALL SELECT 2, 'ar', 0, 1
  UNION ALL SELECT 8, 'ru', 0, 1
  UNION ALL SELECT 9, 'zh', 0, 1
) AS lg
WHERE m.media_type = 'video';

INSERT INTO media_tags (media_asset_id, tag, source, confidence, created_at)
SELECT
  m.id, t.tag, t.source,
  ROUND(0.62 + MOD(CONV(SUBSTRING(MD5(CONCAT('conf:', m.id, t.tag)), 1, 4), 16, 10), 37) / 100, 4),
  m.created_at
FROM media_assets m
JOIN (
  SELECT 'interior' AS tag, 'ai' AS source, 0 AS slot
  UNION ALL SELECT 'living-room',  'ai', 1
  UNION ALL SELECT 'kitchen',      'ai', 2
  UNION ALL SELECT 'bathroom',     'ai', 3
  UNION ALL SELECT 'bedroom',      'ai', 4
  UNION ALL SELECT 'exterior',     'ai', 5
  UNION ALL SELECT 'pool',         'ai', 6
  UNION ALL SELECT 'sea-view',     'ai', 7
  UNION ALL SELECT 'skyline-view', 'ai', 8
  UNION ALL SELECT 'garden',       'ai', 9
  UNION ALL SELECT 'twilight',     'manual', 10
  UNION ALL SELECT 'hero',         'manual', 11
) AS t
  ON t.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('tag:', m.id)), 1, 4), 16, 10), 12)
   OR t.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('tag2:', m.id)), 1, 4), 16, 10), 12)
WHERE m.media_type IN ('image', 'video');

INSERT INTO media_translations
  (media_asset_id, language_id, alt_text, caption, is_machine_generated,
   created_at, updated_at)
SELECT
  m.id, lg.language_id,
  CONCAT(lg.prefix, ' — ', COALESCE(m.alt_text, m.file_name)),
  CONCAT(lg.prefix, ': ', COALESCE(m.caption, m.file_name)),
  1, m.created_at, @now
FROM media_assets m
JOIN (
  SELECT 2 AS language_id, 'صورة' AS prefix
  UNION ALL SELECT 3, 'Photo'
  UNION ALL SELECT 8, 'Фото'
) AS lg
WHERE m.media_type = 'image'
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hastrans:', m.id)), 1, 4), 16, 10), 8) = 0;

-- -----------------------------------------------------------------------------
-- Resumable uploads
--
-- An agency uploading forty photographs over hotel wifi will lose the
-- connection. The session and its parts are what let the upload resume rather
-- than restart, and the abandoned sessions are what the orphan-cleanup
-- retention policy prunes.
-- -----------------------------------------------------------------------------
INSERT INTO upload_sessions
  (public_id, account_id, user_id, file_name, mime_type, total_bytes,
   uploaded_bytes, chunk_size_bytes, total_chunks, received_chunks,
   expected_checksum, storage_location_id, storage_path, provider_upload_id,
   status, media_asset_id, error_message, target_type, target_id, expires_at,
   created_at, updated_at, completed_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('upload:', m.id)), 26)),
  m.account_id, m.uploaded_by_user_id,
  COALESCE(m.original_file_name, m.file_name), m.mime_type, m.file_size_bytes,
  CASE WHEN u.status = 'completed' THEN m.file_size_bytes
       ELSE ROUND(m.file_size_bytes * u.progress) END,
  8388608,
  GREATEST(1, CEIL(m.file_size_bytes / 8388608)),
  CASE WHEN u.status = 'completed' THEN GREATEST(1, CEIL(m.file_size_bytes / 8388608))
       ELSE FLOOR(GREATEST(1, CEIL(m.file_size_bytes / 8388608)) * u.progress) END,
  m.checksum, m.storage_location_id, m.storage_path,
  LEFT(MD5(CONCAT('provupload:', m.id)), 32),
  u.status,
  CASE WHEN u.status = 'completed' THEN m.id END,
  CASE WHEN u.status = 'failed'
       THEN 'Checksum mismatch on assembly. The client reassembled and retried under a new session.' END,
  'listing', NULL,
  DATE_ADD(m.created_at, INTERVAL 24 HOUR),
  m.created_at, @now,
  CASE WHEN u.status = 'completed' THEN DATE_ADD(m.created_at, INTERVAL 90 SECOND) END
FROM media_assets m
JOIN (
  SELECT m2.id AS asset_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('ustat:', m2.id)), 1, 4), 16, 10), 12),
             'completed','completed','completed','completed','completed','completed',
             'completed','completed','completed','uploading','aborted','failed') AS status,
         (20 + MOD(CONV(SUBSTRING(MD5(CONCAT('uprog:', m2.id)), 1, 4), 16, 10), 70)) / 100 AS progress
  FROM media_assets m2
) AS u ON u.asset_id = m.id
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasupload:', m.id)), 1, 4), 16, 10), 9) = 0;

INSERT INTO upload_parts
  (upload_session_id, part_number, byte_offset, byte_length, checksum,
   provider_etag, status, received_at)
SELECT
  s.id, n.n + 1, n.n * s.chunk_size_bytes,
  LEAST(s.chunk_size_bytes, s.total_bytes - n.n * s.chunk_size_bytes),
  SHA2(CONCAT('part:', s.id, ':', n.n), 256),
  LEFT(MD5(CONCAT('etag:', s.id, ':', n.n)), 32),
  CASE
    WHEN n.n < s.received_chunks THEN 'verified'
    WHEN n.n = s.received_chunks AND s.status = 'failed' THEN 'failed'
    WHEN n.n = s.received_chunks THEN 'received'
    ELSE 'pending'
  END,
  CASE WHEN n.n <= s.received_chunks
       THEN DATE_ADD(s.created_at, INTERVAL n.n * 3 SECOND) END
FROM upload_sessions s
JOIN tmp_n n ON n.n < LEAST(s.total_chunks, 12);

-- -----------------------------------------------------------------------------
-- CDN purges
--
-- Every purge is recorded, because "why is the old photograph still showing"
-- is answered by finding the purge that failed, not by guessing at cache times.
-- -----------------------------------------------------------------------------
INSERT INTO cdn_purge_requests
  (provider, purge_type, target, reason, requested_by_user_id, status,
   provider_request_id, attempts, error_message, created_at, completed_at)
SELECT
  'cloudflare', p.purge_type, p.target, p.reason, NULL,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('purge:', p.target)), 1, 4), 16, 10), 14) = 0
       THEN 'failed' ELSE 'completed' END,
  LEFT(MD5(CONCAT('purgeid:', p.target)), 24),
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('purge:', p.target)), 1, 4), 16, 10), 14) = 0 THEN 3 ELSE 1 END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('purge:', p.target)), 1, 4), 16, 10), 14) = 0
       THEN 'Provider returned 429 after the daily purge quota was reached. Queued behind the nightly window.' END,
  DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('pdate:', p.target)), 1, 4), 16, 10), 400) HOUR),
  DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('pdate:', p.target)), 1, 4), 16, 10), 400) HOUR)
FROM (
  SELECT 'url' AS purge_type,
         CONCAT('https://cdn.livfinder.com/listings/', l.id, '/cover.jpg') AS target,
         'Cover image replaced by the agency.' AS reason
  FROM listings l WHERE MOD(l.id, 17) = 0
  UNION ALL
  SELECT 'prefix', CONCAT('https://cdn.livfinder.com/listings/', l.id, '/'),
         'Listing withdrawn; all renditions invalidated.'
  FROM listings l WHERE l.status = 'withdrawn'
  UNION ALL
  SELECT 'tag', CONCAT('tenant:', t.code), 'Brand theme changed; cached CSS invalidated.'
  FROM tenants t WHERE t.tenant_type IN ('white_label', 'partner')
) AS p;

-- -----------------------------------------------------------------------------
-- Documents
--
-- Brochures, price lists, title deeds and payment plans. Visibility is the
-- interesting column: a gated document is a lead-generation instrument, and the
-- grant and download tables are what make the gate auditable rather than
-- decorative.
-- -----------------------------------------------------------------------------
INSERT INTO documents
  (public_id, media_asset_id, owner_type, owner_id, document_type, title,
   description, language_id, version, page_count, file_size_bytes, visibility,
   watermark_on_download, expires_at, download_count, status,
   uploaded_by_user_id, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('document:', d.owner_type, ':', d.owner_id, ':', d.document_type)), 26)),
  NULL, d.owner_type, d.owner_id, d.document_type, d.title, d.description,
  1, 'v1.0',
  4 + MOD(CONV(SUBSTRING(MD5(CONCAT('pages:', d.owner_id, d.document_type)), 1, 4), 16, 10), 60),
  400000 + MOD(CONV(SUBSTRING(MD5(CONCAT('dsize:', d.owner_id, d.document_type)), 1, 6), 16, 10), 20000000),
  d.visibility, d.watermark, NULL, 0, 'active', NULL, d.created_at, @now
FROM (
  SELECT 'project' AS owner_type, p.id AS owner_id, 'brochure' AS document_type,
         CONCAT(p.name, ' — Brochure') AS title,
         CONCAT('Full sales brochure for ', p.name, ', including specification, amenities and the masterplan.') AS description,
         'gated' AS visibility, 1 AS watermark, p.created_at AS created_at
  FROM projects p
  UNION ALL
  SELECT 'project', p.id, 'price_list', CONCAT(p.name, ' — Price list'),
         'Current availability and pricing by unit type. Superseded on each release.',
         'gated', 1, p.created_at FROM projects p
  UNION ALL
  SELECT 'project', p.id, 'payment_plan', CONCAT(p.name, ' — Payment plan'),
         'Milestone schedule with the construction-linked drawdown percentages.',
         'public', 0, p.created_at FROM projects p
  UNION ALL
  SELECT 'listing', l.id, 'floor_plan', CONCAT(l.title, ' — Dimensioned floor plan'),
         'Measured plan with the schedule of accommodation.',
         'gated', 1, l.created_at
  FROM listings l WHERE l.has_floor_plan = 1 AND MOD(l.id, 3) = 0
  UNION ALL
  SELECT 'listing', l.id, 'title_deed', CONCAT(l.title, ' — Title deed'),
         'Registry extract evidencing title. Restricted to verified parties to a transaction.',
         'restricted', 1, l.created_at
  FROM listings l WHERE l.root_category_id = 1 AND MOD(l.id, 11) = 0
  UNION ALL
  SELECT 'building', b.id, 'service_charge', CONCAT(b.name, ' — Service charge schedule'),
         'Owners association budget and the per-square-foot charge for the current year.',
         'public', 0, b.created_at
  FROM buildings b WHERE MOD(b.id, 4) = 0
  UNION ALL
  SELECT 'organization', o.id, 'registration', CONCAT(o.name, ' — Trade licence'),
         'Trade licence and brokerage registration held for compliance purposes.',
         'internal', 0, o.created_at
  FROM organizations o
) AS d;

INSERT INTO document_access_grants
  (document_id, user_id, email, inquiry_id, granted_by_user_id, access_token,
   max_downloads, download_count, expires_at, created_at)
SELECT
  d.id, i.user_id, i.email, i.id, NULL,
  SHA2(CONCAT('grant:', d.id, ':', i.id), 256),
  3,
  MOD(CONV(SUBSTRING(MD5(CONCAT('dl:', d.id, i.id)), 1, 4), 16, 10), 4),
  DATE_ADD(i.created_at, INTERVAL 30 DAY),
  i.created_at
FROM documents d
JOIN inquiries i
  ON i.listing_id IS NOT NULL
 AND MOD(CONV(SUBSTRING(MD5(CONCAT('grantpick:', d.id, ':', i.id)), 1, 5), 16, 10), 700) = 0
WHERE d.visibility = 'gated';

INSERT INTO document_downloads
  (document_id, grant_id, user_id, email, ip_address, user_agent,
   watermark_reference, downloaded_at)
SELECT
  g.document_id, g.id, g.user_id, g.email,
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('dlip:', g.id, n.n)), 1, 8), 16, 10)), 8, '0')),
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0 Safari/537.36',
  CONCAT('WM-', UPPER(LEFT(MD5(CONCAT('wm:', g.id, n.n)), 12))),
  DATE_ADD(g.created_at, INTERVAL n.n * 3 + 1 HOUR)
FROM document_access_grants g
JOIN tmp_n n ON n.n < g.download_count;

UPDATE documents d
JOIN (SELECT document_id, COUNT(*) n FROM document_downloads GROUP BY document_id) x
  ON x.document_id = d.id
SET d.download_count = x.n;

DROP TABLE IF EXISTS tmp_n;
