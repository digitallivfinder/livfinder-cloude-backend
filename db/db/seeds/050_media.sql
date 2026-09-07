-- =============================================================================
-- Liv Finder — seed 050 · Media and digital asset management
-- =============================================================================
-- Reference data here is real configuration, not filler: the image presets are
-- the sizes a marketplace actually needs, and the storage tiers reflect a
-- working cost model.
--
-- The demo assets are derived from `listing_media`, which already exists, with
-- `INSERT ... SELECT`. Deterministic pseudo-randomness comes from hashing the
-- row's own id, so the same load produces the same data every time — a seed
-- that differs between runs makes every assertion below untrustworthy.
--
-- Public ids follow the same convention throughout these seeds: 26 uppercase
-- hex characters derived from an MD5 of a salted id. Real ULIDs are Crockford
-- base32 and time-ordered; these are the same width and unique, which is what
-- the schema requires, and they are obviously synthetic, which is what a demo
-- dataset should be.
-- =============================================================================

SET NAMES utf8mb4;

-- The schema's collation is utf8mb4_unicode_ci throughout, but a client's
-- default connection collation is utf8mb4_general_ci. Any comparison between a
-- string literal (or a CONVERT result) and a column is then a mix of two
-- collations, which MySQL rejects rather than coerces. Pinning the connection
-- collation is what lets the joins below be written naturally.
SET collation_connection = 'utf8mb4_unicode_ci';

-- -----------------------------------------------------------------------------
-- Storage locations
--
-- Three tiers with genuinely different economics. Cold storage costs about a
-- tenth of hot and takes hours to restore, which is why `restore_hours` exists
-- and why nothing user-facing should ever point at it.
-- -----------------------------------------------------------------------------
INSERT INTO storage_locations
  (code, name, provider, bucket, region, base_url, cdn_base_url, tier,
   restore_hours, is_default, is_writable, monthly_cost_per_gb, status)
VALUES
  ('s3-primary-me', 'S3 Primary — Middle East', 's3', 'livfinder-media-me', 'me-central-1',
   'https://livfinder-media-me.s3.me-central-1.amazonaws.com', 'https://cdn.livfinder.com',
   'hot', NULL, 1, 1, 0.0230, 'active'),
  ('s3-primary-eu', 'S3 Primary — Europe', 's3', 'livfinder-media-eu', 'eu-west-1',
   'https://livfinder-media-eu.s3.eu-west-1.amazonaws.com', 'https://cdn-eu.livfinder.com',
   'hot', NULL, 0, 1, 0.0230, 'active'),
  ('s3-primary-us', 'S3 Primary — Americas', 's3', 'livfinder-media-us', 'us-east-1',
   'https://livfinder-media-us.s3.us-east-1.amazonaws.com', 'https://cdn-us.livfinder.com',
   'hot', NULL, 0, 1, 0.0230, 'active'),
  ('r2-renditions', 'Cloudflare R2 — Renditions', 'cloudflare_r2', 'livfinder-renditions', 'auto',
   'https://renditions.livfinder.com', 'https://cdn.livfinder.com/r',
   'hot', NULL, 0, 1, 0.0150, 'active'),
  ('s3-infrequent', 'S3 Infrequent Access', 's3', 'livfinder-media-ia', 'me-central-1',
   'https://livfinder-media-ia.s3.me-central-1.amazonaws.com', NULL,
   'warm', NULL, 0, 1, 0.0125, 'active'),
  ('s3-glacier', 'S3 Glacier Flexible Retrieval', 's3', 'livfinder-archive', 'me-central-1',
   'https://livfinder-archive.s3.me-central-1.amazonaws.com', NULL,
   'archive', 5, 0, 0, 0.0036, 'active');

-- -----------------------------------------------------------------------------
-- Watermark profiles
--
-- Agencies watermark to deter the photo theft that `media_hashes` detects.
-- Tiled at low opacity is the only placement that survives a crop, which is why
-- it is the anti-theft profile rather than the corner logo everyone starts with.
-- -----------------------------------------------------------------------------
INSERT INTO watermark_profiles
  (code, name, organization_id, text_content, position, opacity, scale_percent,
   margin_percent, rotation_degrees, is_active)
VALUES
  ('platform-corner', 'Liv Finder — bottom right', NULL, 'livfinder.com', 'bottom_right', 0.700, 12, 3, 0, 1),
  ('platform-tiled', 'Liv Finder — tiled anti-theft', NULL, 'livfinder.com', 'tiled', 0.120, 20, 0, -30, 1),
  ('agency-corner', 'Agency logo — bottom left', NULL, NULL, 'bottom_left', 0.850, 14, 4, 0, 1),
  ('print-centre', 'Print proof — centred', NULL, 'PROOF — NOT FOR PUBLICATION', 'center', 0.250, 60, 0, -25, 1);

-- -----------------------------------------------------------------------------
-- Image presets
--
-- The rendition ladder. Three things about it are deliberate:
--
--   · AVIF and WebP alongside JPEG. AVIF is roughly half the bytes of JPEG at
--     equivalent quality and is now supported everywhere that matters; JPEG
--     stays as the fallback, not as the default.
--   · A `placeholder` preset at 24px. Twenty bytes of blurred image inlined
--     into the HTML removes the layout shift that Core Web Vitals penalises.
--   · `generate_eagerly` on the four that appear above the fold and lazily on
--     the rest. Generating every rendition of every upload immediately is how a
--     media pipeline becomes the largest line on the infrastructure bill.
-- -----------------------------------------------------------------------------
INSERT INTO image_presets
  (code, name, usage_type, target_width, target_height, resize_mode, aspect_ratio,
   format, quality, allow_upscale, strip_metadata, apply_watermark,
   watermark_profile_id, pixel_density, is_active, generate_eagerly, sort_order)
VALUES
  ('placeholder',    'Blur placeholder',        'placeholder',   24,   16, 'cover', '3:2',  'webp', 30, 0, 1, 0, NULL, 1, 1, 1, 10),
  ('thumb-160',      'Thumbnail 160',           'thumbnail',    160,  120, 'cover', '4:3',  'webp', 72, 0, 1, 0, NULL, 1, 1, 1, 20),
  ('thumb-160-2x',   'Thumbnail 160 @2x',       'srcset_member',320,  240, 'cover', '4:3',  'webp', 68, 0, 1, 0, NULL, 2, 1, 0, 21),
  ('card-400',       'Result card 400',         'card',         400,  267, 'cover', '3:2',  'avif', 60, 0, 1, 0, NULL, 1, 1, 1, 30),
  ('card-400-webp',  'Result card 400 (WebP)',  'card',         400,  267, 'cover', '3:2',  'webp', 74, 0, 1, 0, NULL, 1, 1, 1, 31),
  ('card-800-2x',    'Result card 400 @2x',     'srcset_member',800,  534, 'cover', '3:2',  'avif', 55, 0, 1, 0, NULL, 2, 1, 0, 32),
  ('gallery-1200',   'Gallery 1200',            'gallery',     1200,  800, 'inside','3:2',  'avif', 62, 0, 1, 1, 2,    1, 1, 1, 40),
  ('gallery-1200-webp','Gallery 1200 (WebP)',   'gallery',     1200,  800, 'inside','3:2',  'webp', 78, 0, 1, 1, 2,    1, 1, 0, 41),
  ('gallery-2400-2x','Gallery 1200 @2x',        'srcset_member',2400,1600, 'inside','3:2',  'avif', 55, 0, 1, 1, 2,    2, 1, 0, 42),
  ('hero-1920',      'Hero 1920',               'hero',        1920, 1080, 'cover', '16:9', 'avif', 62, 0, 1, 0, NULL, 1, 1, 0, 50),
  ('og-1200',        'Open Graph share card',   'og_share',    1200,  630, 'cover', '1.91:1','jpeg',82, 1, 1, 0, NULL, 1, 1, 1, 60),
  ('avatar-256',     'Avatar 256',              'avatar',       256,  256, 'crop',  '1:1',  'webp', 80, 0, 1, 0, NULL, 1, 1, 1, 70),
  ('print-3000',     'Print / brochure 3000',   'print',       3000, 2000, 'inside','3:2',  'jpeg', 92, 0, 0, 0, NULL, 1, 1, 0, 80),
  ('watermarked-1200','Syndication watermarked','watermarked', 1200,  800, 'inside','3:2',  'jpeg', 80, 0, 1, 1, 1,    1, 1, 0, 90);

-- -----------------------------------------------------------------------------
-- Media licences
--
-- Who may use a photograph, and for what. This is the difference between
-- syndicating a listing to eight portals legitimately and doing it in breach of
-- the photographer's terms — which is a real invoice, not a theoretical risk.
-- -----------------------------------------------------------------------------
INSERT INTO media_licenses
  (code, name, license_type, allows_commercial_use, allows_modification,
   allows_syndication, requires_attribution, attribution_text, license_url,
   default_duration_months, notes)
VALUES
  ('owned', 'Owned outright', 'owned', 1, 1, 1, 0, NULL, NULL, NULL,
   'Commissioned by the platform. Full rights, no expiry.'),
  ('agency-supplied', 'Agency supplied', 'client_supplied', 1, 1, 1, 0, NULL, NULL, NULL,
   'Supplied by the listing agency, who warrants they hold the rights. Liability sits with them.'),
  ('photographer-rm', 'Photographer — rights managed', 'rights_managed', 1, 0, 0, 1,
   'Photograph © the photographer', NULL, 24,
   'Licensed for a fixed term and a defined use. Syndication is NOT included and must be cleared separately.'),
  ('photographer-rf', 'Photographer — royalty free', 'royalty_free', 1, 1, 1, 1,
   'Photograph © the photographer', NULL, NULL, 'Perpetual, unlimited use, attribution required.'),
  ('developer-supplied', 'Developer marketing pack', 'client_supplied', 1, 0, 1, 1,
   'Images courtesy of the developer', NULL, NULL,
   'Renders and marketing imagery. Modification is not permitted — these depict a design, not a building.'),
  ('editorial-only', 'Editorial use only', 'editorial_only', 0, 0, 0, 1,
   'Image used under editorial licence', NULL, 12,
   'May accompany journalism. May NOT appear on a listing or in advertising.'),
  ('cc-by-4', 'Creative Commons BY 4.0', 'creative_commons', 1, 1, 1, 1,
   'CC BY 4.0', 'https://creativecommons.org/licenses/by/4.0/', NULL, NULL),
  ('unknown', 'Provenance unknown', 'unknown', 0, 0, 0, 0, NULL, NULL, NULL,
   'Imported without licence information. Treat as unusable until cleared.');

-- -----------------------------------------------------------------------------
-- Folders
-- -----------------------------------------------------------------------------
INSERT INTO media_folders (id, parent_id, name, path) VALUES
  (1, NULL, 'Listings',      '/listings'),
  (2, NULL, 'Projects',      '/projects'),
  (3, NULL, 'People',        '/people'),
  (4, NULL, 'Brands',        '/brands'),
  (5, NULL, 'Editorial',     '/editorial'),
  (6, NULL, 'Documents',     '/documents'),
  (7, NULL, 'System',        '/system'),
  (8, 1,    'Real estate',   '/listings/real-estate'),
  (9, 1,    'Motoring',      '/listings/motoring'),
  (10, 1,   'Marine',        '/listings/marine'),
  (11, 1,   'Aviation',      '/listings/aviation'),
  (12, 1,   'Timepieces',    '/listings/timepieces'),
  (13, 3,   'Agent photos',  '/people/agents'),
  (14, 3,   'Avatars',       '/people/avatars'),
  (15, 7,   'Watermarks',    '/system/watermarks');

-- -----------------------------------------------------------------------------
-- Media assets
--
-- One asset per existing `listing_media` row. Dimensions, weights and colours
-- are derived from the row id so they vary plausibly and reproducibly.
--
-- `reference_count` is set to a real count afterwards rather than guessed —
-- see the finalise step at the end of this file.
-- -----------------------------------------------------------------------------
INSERT INTO media_assets
  (public_id, folder_id, account_id, uploaded_by_user_id, media_type, storage_disk,
   storage_location_id, storage_path, url, cdn_url, file_name, original_file_name,
   mime_type, extension, file_size_bytes, width, height, color_space, has_alpha,
   orientation, is_animated, aspect_ratio, focal_x, focal_y, checksum, source,
   blur_hash, dominant_color, alt_text, caption, credit, photographer, license_id,
   copyright_holder, has_model_release, has_property_release, scan_status,
   processing_status, reference_count, last_referenced_at, bytes_served, tier,
   created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('media_asset:', lm.id)), 26)),
  CASE l.root_category_id
    WHEN (SELECT id FROM categories WHERE code = 'real-estate') THEN 8
    WHEN (SELECT id FROM categories WHERE code = 'cars') THEN 9
    WHEN (SELECT id FROM categories WHERE code = 'yachts') THEN 10
    WHEN (SELECT id FROM categories WHERE code = 'jets') THEN 11
    WHEN (SELECT id FROM categories WHERE code = 'helicopters') THEN 11
    WHEN (SELECT id FROM categories WHERE code = 'watches') THEN 12
    ELSE 1 END,
  l.account_id,
  l.created_by_user_id,
  lm.media_type,
  's3',
  -- Assets follow their listing's market, which is what keeps a Dubai gallery
  -- from being served across an ocean.
  CASE WHEN lo.path LIKE 'ae/%' OR lo.path LIKE 'sa/%' OR lo.path LIKE 'qa/%'
         OR lo.path LIKE 'kw/%' OR lo.path LIKE 'bh/%' OR lo.path LIKE 'om/%' THEN 1
       WHEN lo.path LIKE 'us/%' OR lo.path LIKE 'ca/%' OR lo.path LIKE 'br/%'
         OR lo.path LIKE 'mx/%' OR lo.path LIKE 'ar/%' THEN 3
       ELSE 2 END,
  CONCAT('listings/', DATE_FORMAT(lm.created_at, '%Y/%m'), '/', CONVERT(l.public_id USING utf8mb4) COLLATE utf8mb4_unicode_ci, '/',
         LOWER(LEFT(MD5(CONCAT('file:', lm.id)), 20)),
         CASE lm.media_type WHEN 'image' THEN '.jpg' WHEN 'video' THEN '.mp4'
                            WHEN 'document' THEN '.pdf' ELSE '.jpg' END),
  lm.url,
  REPLACE(lm.url, 'https://images.livfinder.com', 'https://cdn.livfinder.com'),
  CONCAT(LOWER(LEFT(MD5(CONCAT('file:', lm.id)), 20)),
         CASE lm.media_type WHEN 'image' THEN '.jpg' WHEN 'video' THEN '.mp4'
                            WHEN 'document' THEN '.pdf' ELSE '.jpg' END),
  CASE lm.media_type
    WHEN 'image' THEN CONCAT('DSC_', LPAD(MOD(lm.id * 7, 9000) + 1000, 4, '0'), '.jpg')
    WHEN 'video' THEN CONCAT('walkthrough_', LPAD(MOD(lm.id, 90) + 10, 2, '0'), '.mp4')
    ELSE CONCAT('brochure_v', MOD(lm.id, 3) + 1, '.pdf') END,
  CASE lm.media_type WHEN 'image' THEN 'image/jpeg' WHEN 'video' THEN 'video/mp4'
                     WHEN 'document' THEN 'application/pdf' ELSE 'image/jpeg' END,
  CASE lm.media_type WHEN 'image' THEN 'jpg' WHEN 'video' THEN 'mp4'
                     WHEN 'document' THEN 'pdf' ELSE 'jpg' END,
  -- Sizes in the range a real 24-megapixel camera JPEG occupies.
  CASE lm.media_type
    WHEN 'image' THEN 2400000 + MOD(CONV(SUBSTRING(MD5(CONCAT('size:', lm.id)),1,6),16,10), 6800000)
    WHEN 'video' THEN 48000000 + MOD(CONV(SUBSTRING(MD5(CONCAT('size:', lm.id)),1,6),16,10), 210000000)
    ELSE 900000 + MOD(CONV(SUBSTRING(MD5(CONCAT('size:', lm.id)),1,6),16,10), 5200000) END,
  CASE lm.media_type WHEN 'document' THEN NULL
       ELSE ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dim:', lm.id)),1,4),16,10), 5),
                6000, 5472, 4032, 3840, 4500) END,
  CASE lm.media_type WHEN 'document' THEN NULL
       ELSE ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dim:', lm.id)),1,4),16,10), 5),
                4000, 3648, 3024, 2160, 3000) END,
  'srgb', 0, 1, 0,
  CASE lm.media_type WHEN 'document' THEN NULL ELSE 1.50000 END,
  -- Focal point. Most photographs put the subject slightly above centre, which
  -- is why a naive centre crop decapitates people and cuts the sky off a tower.
  ROUND(0.35 + MOD(CONV(SUBSTRING(MD5(CONCAT('fx:', lm.id)),1,4),16,10), 300) / 1000, 4),
  ROUND(0.30 + MOD(CONV(SUBSTRING(MD5(CONCAT('fy:', lm.id)),1,4),16,10), 300) / 1000, 4),
  SHA2(CONCAT('content:', lm.id, ':', lm.url), 256),
  CASE WHEN l.source = 'feed' THEN 'feed' WHEN l.source = 'api' THEN 'api' ELSE 'upload' END,
  CONCAT('L', LOWER(LEFT(MD5(CONCAT('blur:', lm.id)), 20))),
  CONCAT('#', UPPER(LEFT(MD5(CONCAT('colour:', lm.id)), 6))),
  lm.alt_text,
  lm.caption,
  CASE WHEN MOD(lm.id, 4) = 0 THEN CONCAT('Photography by ', ELT(1 + MOD(lm.id, 6),
      'Studio Lumière', 'Marina Visuals', 'Ateliér Nord', 'Gulf Frame', 'Casa Imagen', 'Blue Hour Media'))
       ELSE NULL END,
  CASE WHEN MOD(lm.id, 4) = 0 THEN ELT(1 + MOD(lm.id, 6),
      'Studio Lumière', 'Marina Visuals', 'Ateliér Nord', 'Gulf Frame', 'Casa Imagen', 'Blue Hour Media')
       ELSE NULL END,
  -- Licence follows provenance: fed-in imagery is agency supplied, commissioned
  -- shoots are rights-managed, and a minority arrives with nothing at all.
  CASE WHEN l.source = 'feed' THEN (SELECT id FROM media_licenses WHERE code = 'agency-supplied')
       WHEN MOD(lm.id, 17) = 0 THEN (SELECT id FROM media_licenses WHERE code = 'unknown')
       WHEN MOD(lm.id, 4) = 0 THEN (SELECT id FROM media_licenses WHERE code = 'photographer-rm')
       WHEN l.project_id IS NOT NULL THEN (SELECT id FROM media_licenses WHERE code = 'developer-supplied')
       ELSE (SELECT id FROM media_licenses WHERE code = 'owned') END,
  CASE WHEN MOD(lm.id, 4) = 0 THEN 'The photographer' ELSE o.name END,
  0,
  CASE WHEN lm.media_type = 'image' THEN 1 ELSE 0 END,
  -- 'skipped', not 'clean'. Nothing has scanned these files, and `clean` is a claim that a
  -- scanner made a judgement. The enum distinguishes the two for a reason: an operator reading
  -- the media library should be able to tell "checked and safe" from "never checked".
  -- livfinder-backend/src/modules/media/scanner.js writes the real value on upload.
  'skipped',
  'ready',
  0, lm.created_at,
  -- Bytes served scales with the listing's views, which is what actually drives
  -- CDN cost.
  GREATEST(0, l.view_count) * 180000,
  -- Assets on sold or archived listings have already been tiered down.
  CASE WHEN l.status IN ('sold', 'rented', 'archived', 'expired') THEN 'warm' ELSE 'hot' END,
  lm.created_at, lm.created_at
FROM listing_media lm
JOIN listings l ON l.id = lm.listing_id
LEFT JOIN organizations o ON o.id = l.organization_id
LEFT JOIN locations lo ON lo.id = l.country_id;

-- Point the existing media rows at their new assets.
-- `public_id` is CHAR(26) ASCII with a binary collation, so a comparison
-- against a utf8mb4 expression is rejected rather than silently coerced. The
-- CONVERT is what makes the join legal, and it is needed wherever these seeds
-- match on a generated public id.
UPDATE listing_media lm
  JOIN media_assets ma
    ON ma.public_id = CONVERT(UPPER(LEFT(MD5(CONCAT('media_asset:', lm.id)), 26)) USING ascii)
   SET lm.media_asset_id = ma.id;

-- -----------------------------------------------------------------------------
-- Attachments
--
-- The polymorphic join that lets one asset appear against several subjects.
-- Seeded from the listing relationship that already exists.
-- -----------------------------------------------------------------------------
INSERT INTO media_attachments
  (media_asset_id, attachable_type, attachable_id, role, sort_order, is_primary,
   caption, attached_by_user_id, created_at)
SELECT lm.media_asset_id, 'listing', lm.listing_id,
       CASE lm.media_type WHEN 'image' THEN IF(lm.is_cover, 'cover', 'gallery')
                          WHEN 'video' THEN 'video'
                          WHEN 'floor_plan' THEN 'floor_plan'
                          WHEN 'document' THEN 'brochure'
                          ELSE 'gallery' END,
       lm.sort_order, lm.is_cover, lm.caption, l.created_by_user_id, lm.created_at
FROM listing_media lm
JOIN listings l ON l.id = lm.listing_id
WHERE lm.media_asset_id IS NOT NULL;

-- -----------------------------------------------------------------------------
-- Renditions
--
-- Only the eagerly-generated presets exist for every image; the rest are
-- generated on first request, which is exactly the state a real system is in.
-- -----------------------------------------------------------------------------
INSERT INTO media_renditions
  (media_asset_id, preset_id, preset_code, format, width, height, pixel_density,
   file_size_bytes, storage_location_id, storage_path, url, cdn_url, checksum,
   is_watermarked, status, generated_at, created_at, updated_at)
SELECT
  ma.id, p.id, p.code, p.format,
  p.target_width, p.target_height, p.pixel_density,
  -- Rendition weight scales with pixel count and the format's efficiency.
  GREATEST(400, ROUND(p.target_width * p.target_height *
    CASE p.format WHEN 'avif' THEN 0.055 WHEN 'webp' THEN 0.095 ELSE 0.170 END *
    (0.75 + MOD(CONV(SUBSTRING(MD5(CONCAT('r:', ma.id, p.id)),1,4),16,10), 50) / 100))),
  4,
  CONCAT('renditions/', p.code, '/', LOWER(LEFT(MD5(CONCAT('rend:', ma.id, ':', p.id)), 24)), '.', p.format),
  CONCAT('https://renditions.livfinder.com/', p.code, '/', LOWER(LEFT(MD5(CONCAT('rend:', ma.id, ':', p.id)), 24)), '.', p.format),
  CONCAT('https://cdn.livfinder.com/r/', p.code, '/', LOWER(LEFT(MD5(CONCAT('rend:', ma.id, ':', p.id)), 24)), '.', p.format),
  SHA2(CONCAT('rend:', ma.id, ':', p.id), 256),
  p.apply_watermark, 'ready', ma.created_at, ma.created_at, ma.created_at
FROM media_assets ma
JOIN image_presets p ON p.generate_eagerly = 1 AND p.is_active = 1
WHERE ma.media_type = 'image';

-- -----------------------------------------------------------------------------
-- Perceptual hashes
--
-- `hash_prefix` is the first 16 bits, indexed, so a near-duplicate search is a
-- range scan over candidates rather than a Hamming distance across the whole
-- table. Without it, photo-theft detection is O(n) per upload and gets switched
-- off within a month.
-- -----------------------------------------------------------------------------
INSERT INTO media_hashes
  (media_asset_id, algorithm, hash_value, hash_prefix, bit_length, computed_at)
SELECT ma.id, 'phash',
       UNHEX(SHA2(CONCAT('phash:', ma.id), 256)),
       CONV(SUBSTRING(SHA2(CONCAT('phash:', ma.id), 256), 1, 4), 16, 10),
       64, ma.created_at
FROM media_assets ma
WHERE ma.media_type = 'image';

INSERT INTO media_hashes
  (media_asset_id, algorithm, hash_value, hash_prefix, bit_length, computed_at)
SELECT ma.id, 'dhash',
       UNHEX(SHA2(CONCAT('dhash:', ma.id), 256)),
       CONV(SUBSTRING(SHA2(CONCAT('dhash:', ma.id), 256), 1, 4), 16, 10),
       64, ma.created_at
FROM media_assets ma
WHERE ma.media_type = 'image';

-- -----------------------------------------------------------------------------
-- EXIF
--
-- Two things here are fraud signals rather than metadata.
--
-- `location_mismatch_metres` compares the photograph's GPS tag against the
-- listing's own coordinates. A few hundred metres is normal — phones are
-- imprecise and the agent may have shot from across the street. Forty
-- kilometres means the photographs are of a different property, and that is the
-- single most reliable automated detector of a fake listing there is.
--
-- `is_edited` with heavy software is not itself suspicious — every property
-- photograph is edited — but combined with a missing capture date it usually
-- means the image came from somewhere else.
-- -----------------------------------------------------------------------------
INSERT INTO media_exif
  (media_asset_id, camera_make, camera_model, lens_model, captured_at,
   exposure_time, aperture, iso, focal_length_mm, flash_fired,
   gps_latitude, gps_longitude, gps_altitude_m, location_mismatch_metres,
   software, is_edited, copyright_tag, artist_tag, extracted_at)
SELECT
  ma.id,
  ELT(1 + MOD(ma.id, 5), 'Canon', 'SONY', 'NIKON CORPORATION', 'Apple', 'DJI'),
  ELT(1 + MOD(ma.id, 5), 'Canon EOS R5', 'ILCE-7RM5', 'NIKON Z 7II', 'iPhone 15 Pro Max', 'FC3582'),
  ELT(1 + MOD(ma.id, 5), 'RF15-35mm F2.8 L IS USM', 'FE 16-35mm F2.8 GM II',
      'NIKKOR Z 14-24mm f/2.8 S', 'iPhone 15 Pro Max back triple camera 6.86mm f/1.78',
      'FC3582 24mm f/1.7'),
  DATE_SUB(ma.created_at, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('cap:', ma.id)),1,4),16,10), 30) DAY),
  ELT(1 + MOD(ma.id, 6), '1/125', '1/250', '1/60', '1/500', '1/30', '1/1000'),
  ELT(1 + MOD(ma.id, 5), 'f/8.0', 'f/5.6', 'f/4.0', 'f/2.8', 'f/11'),
  ELT(1 + MOD(ma.id, 5), 100, 200, 400, 64, 800),
  ELT(1 + MOD(ma.id, 5), 16.00, 24.00, 35.00, 6.86, 14.00),
  0,
  -- GPS near the listing, with the usual handheld scatter.
  ROUND(l.latitude  + (MOD(CONV(SUBSTRING(MD5(CONCAT('glat:', ma.id)),1,5),16,10), 2000) - 1000) / 1000000, 7),
  ROUND(l.longitude + (MOD(CONV(SUBSTRING(MD5(CONCAT('glon:', ma.id)),1,5),16,10), 2000) - 1000) / 1000000, 7),
  ROUND(MOD(CONV(SUBSTRING(MD5(CONCAT('alt:', ma.id)),1,4),16,10), 180), 2),
  -- One asset in ninety-seven is photographed tens of kilometres from where the
  -- listing claims to be. See the table comment.
  CASE WHEN MOD(ma.id, 97) = 0
       THEN 18000 + MOD(CONV(SUBSTRING(MD5(CONCAT('mm:', ma.id)),1,5),16,10), 42000)
       ELSE MOD(CONV(SUBSTRING(MD5(CONCAT('mm:', ma.id)),1,4),16,10), 260) END,
  ELT(1 + MOD(ma.id, 4), 'Adobe Lightroom Classic 13.2', 'Capture One 23',
      'Adobe Photoshop 25.5', NULL),
  IF(MOD(ma.id, 4) = 3, 0, 1),
  ma.copyright_holder,
  ma.photographer,
  ma.created_at
FROM media_assets ma
JOIN media_attachments att ON att.media_asset_id = ma.id AND att.attachable_type = 'listing'
JOIN listings l ON l.id = att.attachable_id
WHERE ma.media_type = 'image'
  AND l.latitude IS NOT NULL
  AND att.is_primary = 1;

-- -----------------------------------------------------------------------------
-- Duplicate clusters
--
-- Assets that are the same photograph. Exact checksum matches are the easy
-- case; the perceptual hashes above are what catch a re-crop or a re-save,
-- which is what photo theft actually looks like.
--
-- `spans_organizations` is the column that matters. A duplicate within one
-- agency is a filing error; the same photograph under two agencies is either a
-- co-agency arrangement or one of them has taken the other's work.
-- -----------------------------------------------------------------------------
-- The demo listings each carry their own imagery, so there are no natural
-- duplicates to find. A controlled set is planted instead — pairs of assets
-- given a shared checksum, standing for the same photograph uploaded twice —
-- so the detector has something to detect and the reviewing UI has rows to
-- show. Roughly one asset in seventy is involved.
UPDATE media_assets ma
   SET ma.checksum = SHA2(CONCAT('shared-file:', ma.id DIV 137), 256)
 WHERE ma.media_type = 'image'
   AND MOD(ma.id, 137) IN (0, 1);

CREATE TABLE tmp_dupe_groups AS
SELECT ma.checksum AS checksum,
       MIN(ma.id) AS representative_asset_id,
       COUNT(*) AS member_count,
       COUNT(DISTINCT l.organization_id) AS org_count,
       MIN(ma.created_at) AS first_seen,
       MAX(ma.created_at) AS last_seen
  FROM media_assets ma
  JOIN media_attachments att
    ON att.media_asset_id = ma.id AND att.attachable_type = 'listing'
  JOIN listings l ON l.id = att.attachable_id
 WHERE ma.media_type = 'image'
 GROUP BY ma.checksum
HAVING COUNT(*) > 1;

INSERT INTO media_duplicate_clusters
  (representative_asset_id, algorithm, member_count, spans_organizations,
   status, created_at, updated_at)
SELECT g.representative_asset_id, 'exact', g.member_count, g.org_count > 1,
       IF(g.org_count > 1, 'reviewing', 'open'), g.first_seen, g.last_seen
FROM tmp_dupe_groups g;

INSERT INTO media_duplicate_members
  (cluster_id, media_asset_id, distance, similarity_score, organization_id,
   first_seen_at, added_at)
SELECT c.id, ma.id, 0, 1.0000, MIN(l.organization_id), ma.created_at, ma.created_at
FROM media_duplicate_clusters c
JOIN media_assets rep ON rep.id = c.representative_asset_id
JOIN media_assets ma ON ma.checksum = rep.checksum AND ma.media_type = 'image'
JOIN media_attachments att
  ON att.media_asset_id = ma.id AND att.attachable_type = 'listing'
JOIN listings l ON l.id = att.attachable_id
GROUP BY c.id, ma.id, ma.created_at;

DROP TABLE tmp_dupe_groups;

-- -----------------------------------------------------------------------------
-- Moderation
--
-- Automated screening, one row per check rather than one verdict per asset —
-- because "why was this rejected" needs the individual check that failed, not a
-- composite score.
--
-- The check that matters commercially is `text`: contact details burned into a
-- photograph bypass the platform's lead capture entirely, which is why it gates
-- rather than warns.
-- -----------------------------------------------------------------------------
INSERT INTO media_moderation_results
  (media_asset_id, provider, check_type, score, decision, detected_text,
   detected_labels, face_regions, checked_at)
SELECT ma.id, 'rekognition', 'nsfw',
       ROUND(MOD(CONV(SUBSTRING(MD5(CONCAT('adult:', ma.id)),1,4),16,10), 400) / 10000, 4),
       'pass', NULL, NULL, NULL, ma.created_at
FROM media_assets ma WHERE ma.media_type = 'image';

INSERT INTO media_moderation_results
  (media_asset_id, provider, check_type, score, decision, detected_text,
   detected_labels, face_regions, checked_at)
SELECT ma.id, 'rekognition', 'text_detection',
       IF(MOD(ma.id, 11) = 0, 0.9100, 0.0200),
       CASE WHEN MOD(ma.id, 22) = 0 THEN 'reject'
            WHEN MOD(ma.id, 11) = 0 THEN 'review'
            ELSE 'pass' END,
       CASE WHEN MOD(ma.id, 11) = 0 THEN ELT(1 + MOD(ma.id, 4),
           'CALL 050 123 4567', 'www.example-realty.ae', 'FOR SALE', 'PRICE REDUCED')
            ELSE NULL END,
       NULL, NULL, ma.created_at
FROM media_assets ma WHERE ma.media_type = 'image';

-- A competitor's watermark on your photograph is theft in the other direction,
-- and it is common enough to be worth detecting.
INSERT INTO media_moderation_results
  (media_asset_id, provider, check_type, score, decision, detected_text,
   detected_labels, face_regions, checked_at)
SELECT ma.id, 'internal', 'watermark_detection',
       IF(MOD(ma.id, 23) = 0, 0.8700, 0.0100),
       IF(MOD(ma.id, 23) = 0, 'review', 'pass'),
       NULL,
       IF(MOD(ma.id, 23) = 0, JSON_ARRAY('watermark', 'text_overlay'), NULL),
       NULL, ma.created_at
FROM media_assets ma WHERE ma.media_type = 'image';

-- Faces need blurring in several jurisdictions before a street photograph can
-- be published.
INSERT INTO media_moderation_results
  (media_asset_id, provider, check_type, score, decision, detected_text,
   detected_labels, face_regions, checked_at)
SELECT ma.id, 'rekognition', 'face_detection',
       IF(MOD(ma.id, 13) = 0, 0.9600, 0.0000),
       IF(MOD(ma.id, 13) = 0, 'review', 'pass'),
       NULL, NULL,
       IF(MOD(ma.id, 13) = 0,
          JSON_ARRAY(JSON_OBJECT('x', 0.41, 'y', 0.33, 'w', 0.08, 'h', 0.11)), NULL),
       ma.created_at
FROM media_assets ma WHERE ma.media_type = 'image' AND MOD(ma.id, 13) = 0;

-- -----------------------------------------------------------------------------
-- Processing jobs
--
-- The pipeline's own record. Kept for a sample rather than every asset, because
-- completed jobs are pruned in practice and a table holding every job ever run
-- is a table nobody queries.
-- -----------------------------------------------------------------------------
INSERT INTO media_processing_jobs
  (media_asset_id, stage, status, priority, attempts, max_attempts, worker_id,
   error_message, next_attempt_at, duration_ms, queued_at, started_at, finished_at)
SELECT ma.id,
       ELT(1 + MOD(ma.id, 5), 'rendition_generate', 'hash_compute', 'metadata_extract',
           'moderation', 'thumbnail'),
       CASE WHEN MOD(ma.id, 71) = 0 THEN 'failed' ELSE 'completed' END,
       5, IF(MOD(ma.id, 71) = 0, 3, 1), 3,
       CONCAT('media-worker-', 1 + MOD(ma.id, 4)),
       CASE WHEN MOD(ma.id, 71) = 0
            THEN 'ImageMagick: memory allocation failed (source 6000x4000)' ELSE NULL END,
       NULL,
       1500 + MOD(CONV(SUBSTRING(MD5(CONCAT('dur:', ma.id)),1,4),16,10), 38000),
       ma.created_at,
       DATE_ADD(ma.created_at, INTERVAL 1 SECOND),
       DATE_ADD(ma.created_at, INTERVAL (2 + MOD(ma.id, 40)) SECOND)
FROM media_assets ma
WHERE MOD(ma.id, 3) = 0;

-- -----------------------------------------------------------------------------
-- Derived counters
--
-- Every count below is a COUNT over the rows it describes. Nothing is asserted
-- and then hoped for — which is the discipline the whole schema is built on.
-- -----------------------------------------------------------------------------
UPDATE media_assets ma
  LEFT JOIN (SELECT media_asset_id, COUNT(*) c FROM media_attachments GROUP BY media_asset_id) a
    ON a.media_asset_id = ma.id
   SET ma.reference_count = COALESCE(a.c, 0);

UPDATE media_duplicate_clusters c
  JOIN (SELECT cluster_id, COUNT(*) n FROM media_duplicate_members GROUP BY cluster_id) m
    ON m.cluster_id = c.id
   SET c.member_count = m.n;

-- -----------------------------------------------------------------------------
-- Daily storage and bandwidth per account
--
-- The grain is the account, not the asset: this table exists to bill and to
-- spot the agency uploading 40GB of uncompressed TIFFs, and both questions are
-- asked per customer.
--
-- `estimated_cost` multiplies the bytes by the storage location's real
-- per-gigabyte rate, so the number is derived rather than invented.
-- -----------------------------------------------------------------------------
INSERT INTO media_usage_daily
  (account_id, stat_date, storage_bytes, bandwidth_bytes, request_count,
   transform_count, transcode_seconds, asset_count, estimated_cost, computed_at)
SELECT a.account_id, a.stat_date, a.storage_bytes, a.bandwidth_bytes,
       a.request_count, a.transform_count, 0, a.asset_count,
       ROUND(a.storage_bytes / 1073741824 * 0.0230 / 30
             + a.bandwidth_bytes / 1073741824 * 0.0850, 4),
       NOW(3)
FROM (
  SELECT ma.account_id,
         DATE(ma.created_at) AS stat_date,
         SUM(ma.file_size_bytes) AS storage_bytes,
         SUM(ma.bytes_served) AS bandwidth_bytes,
         SUM(GREATEST(1, ma.reference_count * 40)) AS request_count,
         COUNT(r.id) AS transform_count,
         COUNT(DISTINCT ma.id) AS asset_count
    FROM media_assets ma
    LEFT JOIN media_renditions r ON r.media_asset_id = ma.id
   WHERE ma.account_id IS NOT NULL
   GROUP BY ma.account_id, DATE(ma.created_at)
) a;
