-- =============================================================================
-- Liv Finder — 0016 · Digital asset management
-- =============================================================================
-- Migration 0006 gave media a working minimum: an asset row, a folder, and an
-- ordered join to listings. That is enough to render a gallery and nothing else.
--
-- A marketplace at this price point needs considerably more from its images,
-- because for a luxury asset the photography IS the product page:
--
--   · RENDITIONS. One upload becomes a dozen derivatives — AVIF/WebP/JPEG at
--     five widths for srcset, a low-quality placeholder, an OG card at exactly
--     1200x630, a square thumbnail. Each is a real file with its own bytes,
--     dimensions and CDN URL, so it is a row, not a JSON blob.
--
--   · CROPS WITH FOCAL POINTS. The same photograph is shown 16:9 on the detail
--     hero, 4:3 on the result card and 1:1 in the agent's avatar strip. Centre-
--     cropping decapitates people and cuts buildings in half. A stored focal
--     point plus per-aspect crop rectangles is the difference between a gallery
--     that looks art-directed and one that looks automated.
--
--   · PERCEPTUAL HASHING. Photo theft between agencies is endemic in this
--     industry — the same villa shoot appears on four portals under four
--     brokers. A perceptual hash makes "have we seen this image before, even
--     resized and re-compressed" answerable, which is the only practical way to
--     catch it.
--
--   · PROVENANCE. EXIF capture date and GPS answer "was this photographed where
--     and when the listing claims", which is a fraud signal and a
--     licence-compliance record at once.
--
--   · RIGHTS. Photographers licence their work with terms and expiry. A portal
--     that cannot say who shot an image and until when may not use it is one
--     lawsuit from a very bad afternoon.
--
-- Everything here is additive. Nothing in 0006 changes shape.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- storage_locations — where bytes physically live
--
-- Multi-region and multi-tier from the start. A listing sold three years ago
-- still needs its photographs for the audit trail, but it does not need them on
-- hot storage at hot-storage prices.
-- -----------------------------------------------------------------------------
CREATE TABLE storage_locations (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(40)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  provider       ENUM('s3','gcs','azure_blob','cloudflare_r2','local','other') NOT NULL DEFAULT 's3',
  bucket         VARCHAR(160)    NULL,
  region         VARCHAR(60)     NULL,
  base_url       VARCHAR(500)    NULL,
  cdn_base_url   VARCHAR(500)    NULL,
  -- Hot is served directly; warm sits behind the CDN with a long TTL; cold and
  -- archive need a restore before they can be read, which the application must
  -- surface rather than hanging on.
  tier           ENUM('hot','warm','cold','archive') NOT NULL DEFAULT 'hot',
  restore_hours  SMALLINT UNSIGNED NULL,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  is_writable    TINYINT(1)      NOT NULL DEFAULT 1,
  -- Where uploads from this region should land, so a Dubai agency's photographs
  -- are not round-tripping through Virginia.
  preferred_for_country_id BIGINT UNSIGNED NULL,
  monthly_cost_per_gb DECIMAL(10,4) NULL,
  status         ENUM('active','draining','retired') NOT NULL DEFAULT 'active',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_storage_locations_code (code),
  KEY ix_storage_locations_tier (tier, status),
  CONSTRAINT fk_storage_locations_country FOREIGN KEY (preferred_for_country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Extend media_assets
--
-- The 0006 table stayed deliberately small. These columns are what turn it from
-- "a file we uploaded" into a managed asset with provenance, rights and a
-- lifecycle.
-- -----------------------------------------------------------------------------
ALTER TABLE media_assets
  ADD COLUMN storage_location_id SMALLINT UNSIGNED NULL AFTER storage_disk,
  -- Original filename as the user knew it, kept separate from the sanitised
  -- storage path. Users search their own library by the name they gave it.
  ADD COLUMN original_file_name VARCHAR(255) NULL AFTER file_name,
  ADD COLUMN extension VARCHAR(16) NULL AFTER mime_type,
  -- Colour handling matters for print-sourced photography: a CMYK JPEG from a
  -- brochure renders wrong in browsers unless converted.
  ADD COLUMN color_space ENUM('srgb','adobe_rgb','display_p3','cmyk','gray','unknown') NOT NULL DEFAULT 'unknown' AFTER height,
  ADD COLUMN has_alpha TINYINT(1) NOT NULL DEFAULT 0 AFTER color_space,
  ADD COLUMN orientation TINYINT UNSIGNED NULL AFTER has_alpha,
  ADD COLUMN is_animated TINYINT(1) NOT NULL DEFAULT 0 AFTER orientation,
  -- Aspect ratio stored, not computed, so galleries can reserve layout space
  -- before the image loads and avoid cumulative layout shift.
  ADD COLUMN aspect_ratio DECIMAL(8,5) NULL AFTER is_animated,
  -- Normalised focal point in 0..1 space. Every crop derives from this.
  ADD COLUMN focal_x DECIMAL(5,4) NULL AFTER aspect_ratio,
  ADD COLUMN focal_y DECIMAL(5,4) NULL AFTER focal_x,
  -- Dominant colour, for placeholder backgrounds and theme extraction.
  ADD COLUMN dominant_color CHAR(7) NULL AFTER blur_hash,
  ADD COLUMN palette JSON NULL AFTER dominant_color,
  -- Rights and attribution.
  ADD COLUMN photographer VARCHAR(200) NULL AFTER credit,
  ADD COLUMN license_id INT UNSIGNED NULL AFTER photographer,
  ADD COLUMN license_expires_at DATE NULL AFTER license_id,
  ADD COLUMN copyright_holder VARCHAR(200) NULL AFTER license_expires_at,
  -- Whether a recognisable person appears and a release is on file. Relevant
  -- wherever lifestyle photography is used in marketing.
  ADD COLUMN has_model_release TINYINT(1) NOT NULL DEFAULT 0 AFTER copyright_holder,
  ADD COLUMN has_property_release TINYINT(1) NOT NULL DEFAULT 0 AFTER has_model_release,
  -- Lifecycle and cost control.
  ADD COLUMN reference_count INT UNSIGNED NOT NULL DEFAULT 0 AFTER processing_status,
  ADD COLUMN last_referenced_at DATETIME(3) NULL AFTER reference_count,
  ADD COLUMN bytes_served BIGINT UNSIGNED NOT NULL DEFAULT 0 AFTER last_referenced_at,
  ADD COLUMN tier ENUM('hot','warm','cold','archive') NOT NULL DEFAULT 'hot' AFTER bytes_served,
  ADD COLUMN tiered_at DATETIME(3) NULL AFTER tier,
  -- Set when the asset is the canonical original that renditions derive from.
  -- A re-upload of the same bytes points at the existing original instead of
  -- storing them twice.
  ADD COLUMN duplicate_of_id BIGINT UNSIGNED NULL AFTER checksum,
  ADD COLUMN source ENUM('upload','import','feed','api','stock','generated','migration') NOT NULL DEFAULT 'upload' AFTER duplicate_of_id,
  ADD COLUMN source_url VARCHAR(700) NULL AFTER source,
  ADD KEY ix_media_assets_tier (tier, last_referenced_at),
  ADD KEY ix_media_assets_license_expiry (license_expires_at),
  ADD KEY ix_media_assets_duplicate (duplicate_of_id),
  ADD KEY ix_media_assets_refcount (reference_count),
  ADD CONSTRAINT fk_media_assets_storage FOREIGN KEY (storage_location_id) REFERENCES storage_locations (id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_media_assets_duplicate FOREIGN KEY (duplicate_of_id) REFERENCES media_assets (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- media_licenses — the terms an asset may be used under
-- -----------------------------------------------------------------------------
CREATE TABLE media_licenses (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  license_type   ENUM('owned','exclusive','royalty_free','rights_managed','creative_commons','editorial_only','client_supplied','unknown') NOT NULL DEFAULT 'unknown',
  -- What the licence actually permits. Checked before an asset is used in a
  -- paid campaign or syndicated to a third-party portal, which are the two
  -- places an editorial-only image causes trouble.
  allows_commercial_use TINYINT(1) NOT NULL DEFAULT 1,
  allows_modification TINYINT(1) NOT NULL DEFAULT 1,
  allows_syndication TINYINT(1) NOT NULL DEFAULT 0,
  requires_attribution TINYINT(1) NOT NULL DEFAULT 0,
  attribution_text VARCHAR(500) NULL,
  license_url    VARCHAR(500)    NULL,
  default_duration_months SMALLINT UNSIGNED NULL,
  notes          VARCHAR(1000)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_licenses_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE media_assets
  ADD CONSTRAINT fk_media_assets_license FOREIGN KEY (license_id) REFERENCES media_licenses (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- image_presets — the named derivative recipes
--
-- Declarative rather than hardcoded, so adding an AVIF variant or changing the
-- card width is a data change and a reprocess, not a deploy.
-- -----------------------------------------------------------------------------
CREATE TABLE image_presets (
  id             SMALLINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  -- What this preset is for. `srcset_member` presets are generated as a family
  -- and emitted together in one <img srcset>.
  usage_type     ENUM('thumbnail','card','gallery','hero','og_share','placeholder','print','avatar','srcset_member','watermarked') NOT NULL DEFAULT 'gallery',
  target_width   INT UNSIGNED    NULL,
  target_height  INT UNSIGNED    NULL,
  -- 'contain' never crops; 'cover' crops to fill using the focal point;
  -- 'crop' uses an explicit rectangle from media_crops.
  resize_mode    ENUM('contain','cover','crop','fill','inside','outside') NOT NULL DEFAULT 'cover',
  aspect_ratio   VARCHAR(12)     NULL,
  format         ENUM('jpeg','webp','avif','png','gif','original') NOT NULL DEFAULT 'webp',
  quality        TINYINT UNSIGNED NOT NULL DEFAULT 82,
  -- Never enlarge a small original: upscaling looks worse than serving the
  -- native size and costs more bytes.
  allow_upscale  TINYINT(1)      NOT NULL DEFAULT 0,
  strip_metadata TINYINT(1)      NOT NULL DEFAULT 1,
  apply_watermark TINYINT(1)     NOT NULL DEFAULT 0,
  watermark_profile_id INT UNSIGNED NULL,
  -- DPR multiplier for retina variants (1, 2, 3).
  pixel_density  TINYINT UNSIGNED NOT NULL DEFAULT 1,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  -- Generated eagerly on upload, or lazily on first request.
  generate_eagerly TINYINT(1)    NOT NULL DEFAULT 1,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_image_presets_code (code),
  KEY ix_image_presets_usage (usage_type, is_active, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- watermark_profiles
--
-- Agencies watermark to deter the photo theft that perceptual hashing detects
-- after the fact. Per-brand and per-organisation profiles, because a
-- white-label deployment watermarks with the partner's mark, not ours.
-- -----------------------------------------------------------------------------
CREATE TABLE watermark_profiles (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  organization_id BIGINT UNSIGNED NULL,
  watermark_asset_id BIGINT UNSIGNED NULL,
  text_content   VARCHAR(160)    NULL,
  position       ENUM('top_left','top_center','top_right','center','bottom_left','bottom_center','bottom_right','tiled') NOT NULL DEFAULT 'bottom_right',
  opacity        DECIMAL(4,3)    NOT NULL DEFAULT 0.400,
  -- Scale relative to the target image's shorter edge, so the mark stays
  -- proportionate across a thumbnail and a 4K hero.
  scale_percent  TINYINT UNSIGNED NOT NULL DEFAULT 12,
  margin_percent TINYINT UNSIGNED NOT NULL DEFAULT 3,
  rotation_degrees SMALLINT      NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_watermark_profiles_code (code),
  KEY ix_watermark_profiles_org (organization_id, is_active),
  CONSTRAINT fk_watermark_profiles_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_watermark_profiles_asset FOREIGN KEY (watermark_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

ALTER TABLE image_presets
  ADD CONSTRAINT fk_image_presets_watermark FOREIGN KEY (watermark_profile_id) REFERENCES watermark_profiles (id) ON DELETE SET NULL;

-- -----------------------------------------------------------------------------
-- media_renditions — one row per generated derivative
--
-- Rows, not a JSON column, because the application needs to query them: build a
-- srcset ordered by width, find every rendition on cold storage, total the bytes
-- an account is being charged for, or re-generate only the AVIF family after a
-- codec upgrade. None of that is reasonable against JSON.
-- -----------------------------------------------------------------------------
CREATE TABLE media_renditions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  preset_id      SMALLINT UNSIGNED NULL,
  -- Denormalised from the preset so a srcset can be built from this table
  -- alone, and so a rendition survives its preset being retired.
  preset_code    VARCHAR(60)     NOT NULL,
  format         ENUM('jpeg','webp','avif','png','gif','mp4','webm','hls','pdf') NOT NULL,
  width          INT UNSIGNED    NULL,
  height         INT UNSIGNED    NULL,
  pixel_density  TINYINT UNSIGNED NOT NULL DEFAULT 1,
  file_size_bytes BIGINT UNSIGNED NULL,
  storage_location_id SMALLINT UNSIGNED NULL,
  storage_path   VARCHAR(700)    NOT NULL,
  url            VARCHAR(700)    NOT NULL,
  cdn_url        VARCHAR(700)    NULL,
  checksum       CHAR(64)        NULL,
  is_watermarked TINYINT(1)      NOT NULL DEFAULT 0,
  status         ENUM('pending','processing','ready','failed','stale') NOT NULL DEFAULT 'pending',
  error_message  VARCHAR(500)    NULL,
  -- Marked stale when the source asset or the preset changes, so the
  -- regeneration job can find exactly what needs redoing.
  generated_at   DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_renditions (media_asset_id, preset_code, format, pixel_density),
  -- Ordered by width: exactly the shape a srcset is built in.
  KEY ix_media_renditions_srcset (media_asset_id, format, width),
  KEY ix_media_renditions_status (status, created_at),
  KEY ix_media_renditions_preset (preset_id, status),
  KEY ix_media_renditions_storage (storage_location_id),
  CONSTRAINT fk_media_renditions_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE,
  CONSTRAINT fk_media_renditions_preset FOREIGN KEY (preset_id) REFERENCES image_presets (id) ON DELETE SET NULL,
  CONSTRAINT fk_media_renditions_storage FOREIGN KEY (storage_location_id) REFERENCES storage_locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- media_crops — explicit crop rectangles per aspect ratio
--
-- The focal point on media_assets handles the automatic case. This table is the
-- override: an editor drags the crop box for the hero and the card
-- independently, and those decisions must survive re-processing.
-- -----------------------------------------------------------------------------
CREATE TABLE media_crops (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  aspect_ratio   VARCHAR(12)     NOT NULL,
  -- Normalised 0..1 rectangle, so the crop is resolution-independent and stays
  -- correct if the original is later replaced with a higher-resolution scan.
  crop_x         DECIMAL(6,5)    NOT NULL,
  crop_y         DECIMAL(6,5)    NOT NULL,
  crop_width     DECIMAL(6,5)    NOT NULL,
  crop_height    DECIMAL(6,5)    NOT NULL,
  rotation_degrees SMALLINT      NOT NULL DEFAULT 0,
  -- Distinguishes a human decision from an automatic one: automatic crops are
  -- recomputed when the focal point moves, manual ones never are.
  is_manual      TINYINT(1)      NOT NULL DEFAULT 1,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_crops (media_asset_id, aspect_ratio),
  CONSTRAINT fk_media_crops_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE,
  CONSTRAINT fk_media_crops_user FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT ck_media_crops_bounds CHECK (
    crop_x >= 0 AND crop_y >= 0 AND crop_width > 0 AND crop_height > 0
    AND crop_x + crop_width <= 1.00001 AND crop_y + crop_height <= 1.00001
  )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- media_exif — capture metadata, extracted on ingest
--
-- Kept in its own table because it applies only to camera-originated images and
-- is read rarely — on the provenance panel and by the fraud checks — but is
-- wide when present.
-- -----------------------------------------------------------------------------
CREATE TABLE media_exif (
  media_asset_id BIGINT UNSIGNED NOT NULL,
  camera_make    VARCHAR(80)     NULL,
  camera_model   VARCHAR(120)    NULL,
  lens_model     VARCHAR(120)    NULL,
  captured_at    DATETIME        NULL,
  exposure_time  VARCHAR(24)     NULL,
  aperture       VARCHAR(16)     NULL,
  iso            INT UNSIGNED    NULL,
  focal_length_mm DECIMAL(7,2)   NULL,
  flash_fired    TINYINT(1)      NULL,
  -- GPS from the camera. Compared against the listing's stated location: a
  -- "Palm Jumeirah villa" whose photographs were taken in another country is a
  -- strong fraud signal, and one of the few automatic ones available.
  gps_latitude   DECIMAL(10,7)   NULL,
  gps_longitude  DECIMAL(10,7)   NULL,
  gps_altitude_m DECIMAL(8,2)    NULL,
  -- Distance in metres between the EXIF GPS and the listing's coordinates,
  -- computed on ingest so the moderation queue can sort by it.
  location_mismatch_metres INT UNSIGNED NULL,
  software       VARCHAR(120)    NULL,
  -- Editing software in the EXIF is not itself suspicious, but combined with a
  -- stripped capture date it is worth a look.
  is_edited      TINYINT(1)      NULL,
  copyright_tag  VARCHAR(255)    NULL,
  artist_tag     VARCHAR(255)    NULL,
  raw_exif       JSON            NULL,
  extracted_at   DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (media_asset_id),
  KEY ix_media_exif_captured (captured_at),
  KEY ix_media_exif_mismatch (location_mismatch_metres),
  CONSTRAINT fk_media_exif_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- media_hashes — perceptual fingerprints
--
-- SHA-256 on media_assets catches byte-identical re-uploads. It does not catch
-- the same photograph resized, re-compressed, slightly cropped or watermarked —
-- which is exactly what image theft looks like in practice.
--
-- Several algorithms are stored per asset because they fail differently: aHash
-- is fast and crude, dHash survives gamma changes, pHash survives scaling, and
-- a CNN embedding catches the same room shot from a slightly different angle.
-- Hamming distance between two hashes of the same algorithm gives similarity.
-- -----------------------------------------------------------------------------
CREATE TABLE media_hashes (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  algorithm      ENUM('ahash','dhash','phash','whash','blockhash','cnn_embedding') NOT NULL,
  -- Hex for the classic hashes; the first bytes of a quantised vector for the
  -- embedding. BINARY so Hamming distance is computable with BIT_COUNT.
  hash_value     BINARY(32)      NOT NULL,
  -- Leading 16 bits, indexed, as a cheap bucket for candidate lookup before
  -- computing exact distance. Full nearest-neighbour search belongs in a vector
  -- index, not MySQL; this makes the common case tractable here.
  hash_prefix    SMALLINT UNSIGNED NOT NULL,
  bit_length     SMALLINT UNSIGNED NOT NULL DEFAULT 64,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_hashes (media_asset_id, algorithm),
  KEY ix_media_hashes_lookup (algorithm, hash_prefix),
  CONSTRAINT fk_media_hashes_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Clusters of visually near-identical assets. A cluster is opened when a new
-- upload matches an existing one within threshold; a moderator then decides
-- whether it is a legitimate re-use (same agency, new listing) or theft.
CREATE TABLE media_duplicate_clusters (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  representative_asset_id BIGINT UNSIGNED NOT NULL,
  algorithm      ENUM('ahash','dhash','phash','whash','blockhash','cnn_embedding','exact') NOT NULL DEFAULT 'phash',
  member_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Set when members belong to different organisations, which is the case worth
  -- a human looking at.
  spans_organizations TINYINT(1) NOT NULL DEFAULT 0,
  status         ENUM('open','reviewing','legitimate','infringing','resolved','ignored') NOT NULL DEFAULT 'open',
  resolution_note VARCHAR(1000)  NULL,
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at    DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_media_dupe_clusters_status (status, spans_organizations, created_at),
  KEY ix_media_dupe_clusters_rep (representative_asset_id),
  CONSTRAINT fk_media_dupe_clusters_asset FOREIGN KEY (representative_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE,
  CONSTRAINT fk_media_dupe_clusters_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE media_duplicate_members (
  cluster_id     BIGINT UNSIGNED NOT NULL,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  -- Hamming distance to the cluster representative. 0 is identical; under ~10
  -- on a 64-bit pHash is the same image.
  distance       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  similarity_score DECIMAL(5,4)  NULL,
  organization_id BIGINT UNSIGNED NULL,
  first_seen_at  DATETIME(3)     NULL,
  added_at       DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (cluster_id, media_asset_id),
  KEY ix_media_dupe_members_asset (media_asset_id),
  KEY ix_media_dupe_members_org (organization_id),
  CONSTRAINT fk_media_dupe_members_cluster FOREIGN KEY (cluster_id) REFERENCES media_duplicate_clusters (id) ON DELETE CASCADE,
  CONSTRAINT fk_media_dupe_members_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE,
  CONSTRAINT fk_media_dupe_members_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- media_moderation_results — automated content checks
--
-- Every uploaded image is scored before it is publishable. Beyond the obvious
-- safety checks, this catches the things that specifically degrade a property
-- portal: another agency's watermark or phone number burned into the image,
-- screenshots of a competitor's listing, and stock photography passed off as
-- the actual property.
-- -----------------------------------------------------------------------------
CREATE TABLE media_moderation_results (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  provider       VARCHAR(60)     NOT NULL,
  check_type     ENUM('nsfw','violence','text_detection','logo_detection','watermark_detection','face_detection','quality','stock_photo','screenshot','ai_generated','duplicate') NOT NULL,
  -- 0..1. The threshold that turns a score into a decision lives in settings,
  -- not here, so it can be tuned without a migration.
  score          DECIMAL(5,4)    NULL,
  decision       ENUM('pass','review','reject','error') NOT NULL DEFAULT 'pass',
  -- Text found in the image. A phone number or a rival's brand burned into a
  -- photograph is both a policy breach and a lead leak.
  detected_text  TEXT            NULL,
  detected_labels JSON           NULL,
  -- Face bounding boxes, so faces can be blurred where privacy law or the
  -- listing's own settings require it.
  face_regions   JSON            NULL,
  raw_response   JSON            NULL,
  checked_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_moderation (media_asset_id, provider, check_type),
  KEY ix_media_moderation_decision (decision, checked_at),
  KEY ix_media_moderation_type_score (check_type, score),
  CONSTRAINT fk_media_moderation_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- Resumable uploads
--
-- Agencies upload forty 25 MB photographs at once, frequently over hotel or
-- mobile connections. Without chunked, resumable uploads a dropped connection
-- at 90% means starting again, and the practical consequence is listings
-- published with four photographs instead of forty.
-- -----------------------------------------------------------------------------
CREATE TABLE upload_sessions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  account_id     BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  file_name      VARCHAR(255)    NOT NULL,
  mime_type      VARCHAR(120)    NULL,
  total_bytes    BIGINT UNSIGNED NOT NULL,
  uploaded_bytes BIGINT UNSIGNED NOT NULL DEFAULT 0,
  chunk_size_bytes INT UNSIGNED  NOT NULL DEFAULT 5242880,
  total_chunks   INT UNSIGNED    NULL,
  received_chunks INT UNSIGNED   NOT NULL DEFAULT 0,
  -- Client-computed digest of the whole file, verified on assembly. Catches
  -- silent corruption, which chunked uploads over flaky links do produce.
  expected_checksum CHAR(64)     NULL,
  storage_location_id SMALLINT UNSIGNED NULL,
  storage_path   VARCHAR(700)    NULL,
  -- The multipart id at the storage provider, so an abandoned upload can be
  -- aborted there and stop accruing storage cost.
  provider_upload_id VARCHAR(255) NULL,
  status         ENUM('initiated','uploading','assembling','completed','failed','aborted','expired') NOT NULL DEFAULT 'initiated',
  media_asset_id BIGINT UNSIGNED NULL,
  error_message  VARCHAR(500)    NULL,
  -- Where the file is destined, captured up front so the asset can be attached
  -- automatically on completion.
  target_type    VARCHAR(60)     NULL,
  target_id      BIGINT UNSIGNED NULL,
  expires_at     DATETIME(3)     NOT NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  completed_at   DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_upload_sessions_public_id (public_id),
  KEY ix_upload_sessions_account (account_id, status),
  KEY ix_upload_sessions_expiry (status, expires_at),
  KEY ix_upload_sessions_asset (media_asset_id),
  CONSTRAINT fk_upload_sessions_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_upload_sessions_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_upload_sessions_storage FOREIGN KEY (storage_location_id) REFERENCES storage_locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_upload_sessions_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE upload_parts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  upload_session_id BIGINT UNSIGNED NOT NULL,
  part_number    INT UNSIGNED    NOT NULL,
  byte_offset    BIGINT UNSIGNED NOT NULL,
  byte_length    INT UNSIGNED    NOT NULL,
  checksum       CHAR(64)        NULL,
  -- The provider's per-part ETag, required to complete a multipart upload.
  provider_etag  VARCHAR(255)    NULL,
  status         ENUM('pending','received','verified','failed') NOT NULL DEFAULT 'pending',
  received_at    DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_upload_parts (upload_session_id, part_number),
  KEY ix_upload_parts_status (upload_session_id, status),
  CONSTRAINT fk_upload_parts_session FOREIGN KEY (upload_session_id) REFERENCES upload_sessions (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- media_attachments — polymorphic use of an asset, with reference counting
--
-- `listing_media` in 0006 handles listings specifically and stays as it is. This
-- is the general case: the same asset attached to an organisation's cover, an
-- article, a project brochure, a user avatar, a report's evidence.
--
-- `media_assets.reference_count` is maintained from this table plus
-- `listing_media`. Without it, deleting an asset means scanning a dozen tables
-- to find out whether anything still points at it, and orphaned files
-- accumulate storage cost forever.
-- -----------------------------------------------------------------------------
CREATE TABLE media_attachments (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  attachable_type VARCHAR(60)    NOT NULL,
  attachable_id  BIGINT UNSIGNED NOT NULL,
  -- Which slot on the parent this fills: 'cover', 'logo', 'gallery',
  -- 'brochure', 'avatar', 'evidence'.
  role           VARCHAR(60)     NOT NULL DEFAULT 'gallery',
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  caption        VARCHAR(500)    NULL,
  attached_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_attachments (attachable_type, attachable_id, media_asset_id, role),
  KEY ix_media_attachments_target (attachable_type, attachable_id, role, sort_order),
  KEY ix_media_attachments_asset (media_asset_id),
  CONSTRAINT fk_media_attachments_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE,
  CONSTRAINT fk_media_attachments_user FOREIGN KEY (attached_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- media_translations — per-locale alt text and captions
--
-- Alt text is both an accessibility requirement and a genuine ranking signal for
-- image search, which for a luxury portal is a real acquisition channel. It has
-- to be translatable like any other content.
-- -----------------------------------------------------------------------------
CREATE TABLE media_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  alt_text       VARCHAR(255)    NULL,
  caption        VARCHAR(500)    NULL,
  description    TEXT            NULL,
  is_machine_generated TINYINT(1) NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_translations (media_asset_id, language_id),
  CONSTRAINT fk_media_translations_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE,
  CONSTRAINT fk_media_translations_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE media_tags (
  media_asset_id BIGINT UNSIGNED NOT NULL,
  tag            VARCHAR(80)     NOT NULL,
  -- AI-suggested tags carry a confidence and are shown for confirmation rather
  -- than applied silently.
  source         ENUM('manual','ai','import') NOT NULL DEFAULT 'manual',
  confidence     DECIMAL(5,4)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (media_asset_id, tag),
  KEY ix_media_tags_tag (tag),
  CONSTRAINT fk_media_tags_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Video
-- -----------------------------------------------------------------------------
CREATE TABLE video_assets (
  media_asset_id BIGINT UNSIGNED NOT NULL,
  duration_seconds DECIMAL(10,3) NULL,
  frame_rate     DECIMAL(7,3)    NULL,
  bitrate_kbps   INT UNSIGNED    NULL,
  video_codec    VARCHAR(40)     NULL,
  audio_codec    VARCHAR(40)     NULL,
  audio_channels TINYINT UNSIGNED NULL,
  has_audio      TINYINT(1)      NOT NULL DEFAULT 1,
  -- Adaptive-bitrate manifests. Serving a 4K property tour as a single MP4 to a
  -- phone on 4G is how you get a 12-second first frame.
  hls_manifest_url VARCHAR(700)  NULL,
  dash_manifest_url VARCHAR(700) NULL,
  poster_asset_id BIGINT UNSIGNED NULL,
  -- Sprite sheet for scrubbing previews.
  thumbnail_sprite_url VARCHAR(700) NULL,
  thumbnail_vtt_url VARCHAR(700) NULL,
  provider       ENUM('self_hosted','mux','cloudflare_stream','vimeo','youtube','jwplayer','other') NOT NULL DEFAULT 'self_hosted',
  provider_asset_id VARCHAR(191) NULL,
  playback_id    VARCHAR(191)    NULL,
  is_downloadable TINYINT(1)     NOT NULL DEFAULT 0,
  view_count     BIGINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (media_asset_id),
  KEY ix_video_assets_provider (provider, provider_asset_id),
  CONSTRAINT fk_video_assets_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE,
  CONSTRAINT fk_video_assets_poster FOREIGN KEY (poster_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE video_transcode_jobs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  profile        VARCHAR(60)     NOT NULL,
  target_resolution VARCHAR(16)  NULL,
  target_bitrate_kbps INT UNSIGNED NULL,
  status         ENUM('queued','processing','completed','failed','cancelled') NOT NULL DEFAULT 'queued',
  progress_percent TINYINT UNSIGNED NOT NULL DEFAULT 0,
  provider_job_id VARCHAR(191)   NULL,
  output_rendition_id BIGINT UNSIGNED NULL,
  error_message  VARCHAR(1000)   NULL,
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  -- Transcoding is billed by the minute; recording it makes the cost
  -- attributable to the account that caused it.
  compute_seconds INT UNSIGNED   NULL,
  queued_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  started_at     DATETIME(3)     NULL,
  finished_at    DATETIME(3)     NULL,
  PRIMARY KEY (id),
  KEY ix_video_transcode_asset (media_asset_id, status),
  KEY ix_video_transcode_queue (status, queued_at),
  CONSTRAINT fk_video_transcode_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE,
  CONSTRAINT fk_video_transcode_rendition FOREIGN KEY (output_rendition_id) REFERENCES media_renditions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE media_captions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  kind           ENUM('subtitles','captions','descriptions','chapters') NOT NULL DEFAULT 'subtitles',
  format         ENUM('vtt','srt','ttml') NOT NULL DEFAULT 'vtt',
  url            VARCHAR(700)    NOT NULL,
  is_default     TINYINT(1)      NOT NULL DEFAULT 0,
  is_auto_generated TINYINT(1)   NOT NULL DEFAULT 0,
  -- The transcript, stored so it can be indexed for search: a tour narration
  -- mentioning "sea view" should make the listing findable by that term.
  transcript     MEDIUMTEXT      NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_captions (media_asset_id, language_id, kind),
  CONSTRAINT fk_media_captions_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE,
  CONSTRAINT fk_media_captions_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- Virtual tours
--
-- Modelled as a scene graph rather than an embed URL, because tours are a
-- primary conversion surface for remote buyers — which is most buyers at this
-- price point — and the platform needs to measure and deep-link into them.
-- -----------------------------------------------------------------------------
CREATE TABLE virtual_tours (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  listing_id     BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  title          VARCHAR(200)    NULL,
  tour_type      ENUM('matterport','360_photo','360_video','walkthrough_video','cgi_render','floor_plan_3d','drone') NOT NULL DEFAULT '360_photo',
  provider       ENUM('matterport','kuula','cupix','giraffe360','asteroom','self_hosted','other') NOT NULL DEFAULT 'self_hosted',
  provider_tour_id VARCHAR(191)  NULL,
  embed_url      VARCHAR(700)    NULL,
  thumbnail_asset_id BIGINT UNSIGNED NULL,
  scene_count    SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  -- Captured floor area from the scan, which is an independent check on the
  -- area the agent typed into the listing.
  scanned_area_sqm DECIMAL(12,2) NULL,
  captured_at    DATE            NULL,
  captured_by    VARCHAR(200)    NULL,
  status         ENUM('processing','ready','failed','archived') NOT NULL DEFAULT 'processing',
  is_public      TINYINT(1)      NOT NULL DEFAULT 1,
  view_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  -- Median seconds spent in the tour. The strongest single engagement signal
  -- available for a listing.
  median_duration_seconds INT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_virtual_tours_public_id (public_id),
  KEY ix_virtual_tours_listing (listing_id, status),
  KEY ix_virtual_tours_project (project_id, status),
  KEY ix_virtual_tours_provider (provider, provider_tour_id),
  CONSTRAINT fk_virtual_tours_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_virtual_tours_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
  CONSTRAINT fk_virtual_tours_thumb FOREIGN KEY (thumbnail_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tour_scenes (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  virtual_tour_id BIGINT UNSIGNED NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  room_type      VARCHAR(60)     NULL,
  panorama_asset_id BIGINT UNSIGNED NULL,
  -- Initial camera orientation, so a deep link opens facing the sea rather than
  -- at a wall.
  initial_yaw    DECIMAL(7,3)    NULL,
  initial_pitch  DECIMAL(7,3)    NULL,
  initial_fov    DECIMAL(6,2)    NULL,
  -- Position within the scan, for the dollhouse and floor-plan views.
  position_x     DECIMAL(10,4)   NULL,
  position_y     DECIMAL(10,4)   NULL,
  position_z     DECIMAL(10,4)   NULL,
  floor_level    SMALLINT        NULL,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_tour_scenes_tour (virtual_tour_id, sort_order),
  CONSTRAINT fk_tour_scenes_tour FOREIGN KEY (virtual_tour_id) REFERENCES virtual_tours (id) ON DELETE CASCADE,
  CONSTRAINT fk_tour_scenes_panorama FOREIGN KEY (panorama_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE tour_hotspots (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  scene_id       BIGINT UNSIGNED NOT NULL,
  hotspot_type   ENUM('navigation','info','media','link','measurement','product') NOT NULL DEFAULT 'navigation',
  label          VARCHAR(200)    NULL,
  description    VARCHAR(1000)   NULL,
  yaw            DECIMAL(7,3)    NOT NULL,
  pitch          DECIMAL(7,3)    NOT NULL,
  target_scene_id BIGINT UNSIGNED NULL,
  target_url     VARCHAR(700)    NULL,
  media_asset_id BIGINT UNSIGNED NULL,
  icon           VARCHAR(60)     NULL,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY ix_tour_hotspots_scene (scene_id, sort_order),
  CONSTRAINT fk_tour_hotspots_scene FOREIGN KEY (scene_id) REFERENCES tour_scenes (id) ON DELETE CASCADE,
  CONSTRAINT fk_tour_hotspots_target FOREIGN KEY (target_scene_id) REFERENCES tour_scenes (id) ON DELETE SET NULL,
  CONSTRAINT fk_tour_hotspots_media FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- Floor plans
--
-- Structured rather than "a PDF we uploaded", because room dimensions are
-- filterable data ("bedroom at least 4m wide"), a cross-check on the stated
-- built area, and what an interactive floor plan needs to highlight rooms.
-- -----------------------------------------------------------------------------
CREATE TABLE floor_plans (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  listing_id     BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  unit_type_id   BIGINT UNSIGNED NULL,
  name           VARCHAR(160)    NOT NULL,
  floor_level    SMALLINT        NULL,
  media_asset_id BIGINT UNSIGNED NULL,
  interactive_svg_url VARCHAR(700) NULL,
  total_area_sqm DECIMAL(12,2)   NULL,
  total_area_sqft DECIMAL(12,2)  NULL,
  ceiling_height_m DECIMAL(6,2)  NULL,
  -- Scale factor from drawing units to metres, so measurements taken on the
  -- image are real.
  scale_factor   DECIMAL(12,6)   NULL,
  is_public      TINYINT(1)      NOT NULL DEFAULT 1,
  -- Floor plans are commonly gated behind a lead form; that is a per-plan
  -- decision, not a global one.
  requires_lead  TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_floor_plans_listing (listing_id, sort_order),
  KEY ix_floor_plans_project (project_id, sort_order),
  KEY ix_floor_plans_unit_type (unit_type_id),
  CONSTRAINT fk_floor_plans_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_floor_plans_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
  CONSTRAINT fk_floor_plans_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE floor_plan_rooms (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  floor_plan_id  BIGINT UNSIGNED NOT NULL,
  name           VARCHAR(120)    NOT NULL,
  room_type      ENUM('bedroom','bathroom','ensuite','powder_room','living','dining','kitchen','study','maid_room','driver_room','laundry','storage','balcony','terrace','garden','garage','pool','gym','cinema','wine_cellar','entrance','corridor','other') NOT NULL DEFAULT 'other',
  area_sqm       DECIMAL(10,2)   NULL,
  length_m       DECIMAL(8,2)    NULL,
  width_m        DECIMAL(8,2)    NULL,
  -- Polygon on the plan image in normalised coordinates, for hover highlighting.
  outline_points JSON            NULL,
  has_window     TINYINT(1)      NULL,
  is_ensuite     TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY ix_floor_plan_rooms_plan (floor_plan_id, sort_order),
  KEY ix_floor_plan_rooms_type (room_type, area_sqm),
  CONSTRAINT fk_floor_plan_rooms_plan FOREIGN KEY (floor_plan_id) REFERENCES floor_plans (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- documents — gated files with an access trail
--
-- Brochures, title deeds, surveys, service-charge statements, spec sheets. Two
-- things separate these from ordinary media: they are frequently gated behind a
-- lead form, and for the legal ones every download must be attributable.
-- -----------------------------------------------------------------------------
CREATE TABLE documents (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  media_asset_id BIGINT UNSIGNED NULL,
  owner_type     VARCHAR(60)     NOT NULL,
  owner_id       BIGINT UNSIGNED NOT NULL,
  document_type  ENUM('brochure','floor_plan','price_list','payment_plan','title_deed','survey','inspection_report','service_charge','spec_sheet','maintenance_log','registration','insurance','contract','noc','valuation','other') NOT NULL DEFAULT 'other',
  title          VARCHAR(255)    NOT NULL,
  description    VARCHAR(1000)   NULL,
  language_id    SMALLINT UNSIGNED NULL,
  version        VARCHAR(40)     NULL,
  page_count     SMALLINT UNSIGNED NULL,
  file_size_bytes BIGINT UNSIGNED NULL,
  -- Access model. `gated` requires an enquiry first; `restricted` requires an
  -- explicit grant, which is how a title deed should behave.
  visibility     ENUM('public','gated','restricted','internal') NOT NULL DEFAULT 'gated',
  -- Personalised watermarking on download, so a leaked document is traceable to
  -- the person who downloaded it.
  watermark_on_download TINYINT(1) NOT NULL DEFAULT 0,
  expires_at     DATETIME(3)     NULL,
  download_count INT UNSIGNED    NOT NULL DEFAULT 0,
  status         ENUM('draft','active','superseded','archived') NOT NULL DEFAULT 'active',
  superseded_by_id BIGINT UNSIGNED NULL,
  uploaded_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_documents_public_id (public_id),
  KEY ix_documents_owner (owner_type, owner_id, document_type, status),
  KEY ix_documents_visibility (visibility, status),
  KEY ix_documents_expiry (expires_at),
  CONSTRAINT fk_documents_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE SET NULL,
  CONSTRAINT fk_documents_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL,
  CONSTRAINT fk_documents_superseded FOREIGN KEY (superseded_by_id) REFERENCES documents (id) ON DELETE SET NULL,
  CONSTRAINT fk_documents_uploader FOREIGN KEY (uploaded_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE document_access_grants (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  document_id    BIGINT UNSIGNED NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  -- Grants to an unregistered enquirer are keyed by email, since gating exists
  -- precisely to capture people who have not signed up.
  email          VARCHAR(255)    NULL,
  inquiry_id     BIGINT UNSIGNED NULL,
  granted_by_user_id BIGINT UNSIGNED NULL,
  -- Single-use signed URL token; the file itself is never publicly addressable.
  access_token   CHAR(64)        CHARACTER SET ascii NULL,
  max_downloads  SMALLINT UNSIGNED NULL,
  download_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  expires_at     DATETIME(3)     NULL,
  revoked_at     DATETIME(3)     NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_document_grants_token (access_token),
  KEY ix_document_grants_doc (document_id, expires_at),
  KEY ix_document_grants_user (user_id),
  KEY ix_document_grants_email (email),
  CONSTRAINT fk_document_grants_doc FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
  CONSTRAINT fk_document_grants_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_document_grants_inquiry FOREIGN KEY (inquiry_id) REFERENCES inquiries (id) ON DELETE SET NULL,
  CONSTRAINT fk_document_grants_granter FOREIGN KEY (granted_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE document_downloads (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  document_id    BIGINT UNSIGNED NOT NULL,
  grant_id       BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  email          VARCHAR(255)    NULL,
  ip_address     VARBINARY(16)   NULL,
  user_agent     VARCHAR(500)    NULL,
  -- The identifier burned into the watermark of this specific copy.
  watermark_reference VARCHAR(80) NULL,
  downloaded_at  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_document_downloads_doc (document_id, downloaded_at),
  KEY ix_document_downloads_user (user_id, downloaded_at),
  KEY ix_document_downloads_watermark (watermark_reference),
  CONSTRAINT fk_document_downloads_doc FOREIGN KEY (document_id) REFERENCES documents (id) ON DELETE CASCADE,
  CONSTRAINT fk_document_downloads_grant FOREIGN KEY (grant_id) REFERENCES document_access_grants (id) ON DELETE SET NULL,
  CONSTRAINT fk_document_downloads_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- media_processing_jobs — the ingest pipeline
--
-- One row per stage per asset, so a stuck upload can be diagnosed to the exact
-- step rather than being "still processing".
-- -----------------------------------------------------------------------------
CREATE TABLE media_processing_jobs (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  media_asset_id BIGINT UNSIGNED NOT NULL,
  stage          ENUM('virus_scan','metadata_extract','hash_compute','rendition_generate','moderation','transcode','thumbnail','ocr','ai_tagging','watermark','cdn_warm','tier_move') NOT NULL,
  status         ENUM('queued','processing','completed','failed','skipped','cancelled') NOT NULL DEFAULT 'queued',
  priority       TINYINT UNSIGNED NOT NULL DEFAULT 5,
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  max_attempts   TINYINT UNSIGNED NOT NULL DEFAULT 3,
  worker_id      VARCHAR(80)     NULL,
  error_message  VARCHAR(1000)   NULL,
  -- Backoff target for the retry worker.
  next_attempt_at DATETIME(3)    NULL,
  duration_ms    INT UNSIGNED    NULL,
  payload        JSON            NULL,
  queued_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  started_at     DATETIME(3)     NULL,
  finished_at    DATETIME(3)     NULL,
  PRIMARY KEY (id),
  KEY ix_media_jobs_queue (status, priority, next_attempt_at),
  KEY ix_media_jobs_asset (media_asset_id, stage),
  KEY ix_media_jobs_stuck (status, started_at),
  CONSTRAINT fk_media_jobs_asset FOREIGN KEY (media_asset_id) REFERENCES media_assets (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- cdn_purge_requests
--
-- Replacing an image at the same URL without a purge means users see the old one
-- for as long as the TTL. Tracked because purges are rate-limited by every CDN
-- and need batching and retry.
-- -----------------------------------------------------------------------------
CREATE TABLE cdn_purge_requests (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  provider       VARCHAR(60)     NOT NULL,
  purge_type     ENUM('url','prefix','tag','everything') NOT NULL DEFAULT 'url',
  target         VARCHAR(700)    NOT NULL,
  reason         VARCHAR(255)    NULL,
  requested_by_user_id BIGINT UNSIGNED NULL,
  status         ENUM('queued','submitted','completed','failed') NOT NULL DEFAULT 'queued',
  provider_request_id VARCHAR(191) NULL,
  attempts       TINYINT UNSIGNED NOT NULL DEFAULT 0,
  error_message  VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  completed_at   DATETIME(3)     NULL,
  PRIMARY KEY (id),
  KEY ix_cdn_purge_status (status, created_at),
  CONSTRAINT fk_cdn_purge_user FOREIGN KEY (requested_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- media_usage_daily — bandwidth and storage, per account, per day
--
-- Media is usually the largest infrastructure line item for a portal, and on
-- larger plans it is rebilled. Neither is possible without measuring it.
-- -----------------------------------------------------------------------------
CREATE TABLE media_usage_daily (
  account_id     BIGINT UNSIGNED NOT NULL,
  stat_date      DATE            NOT NULL,
  storage_bytes  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  bandwidth_bytes BIGINT UNSIGNED NOT NULL DEFAULT 0,
  request_count  BIGINT UNSIGNED NOT NULL DEFAULT 0,
  transform_count INT UNSIGNED   NOT NULL DEFAULT 0,
  transcode_seconds INT UNSIGNED NOT NULL DEFAULT 0,
  asset_count    INT UNSIGNED    NOT NULL DEFAULT 0,
  estimated_cost DECIMAL(12,4)   NULL,
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (account_id, stat_date),
  KEY ix_media_usage_date (stat_date),
  CONSTRAINT fk_media_usage_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0016', 'media_asset_management');
