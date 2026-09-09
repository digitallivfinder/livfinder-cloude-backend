-- =============================================================================
-- Liv Finder — demo seed · photographs for the demo catalogue
-- =============================================================================
-- Every image URL in these seeds points at `https://cdn.livfinder.com/...`, a host that exists
-- in a deployed environment and nowhere else. `src/middleware/legacyMedia.js` rewrites those on
-- the way out to a generated grey SVG placeholder, so a freshly seeded database renders a
-- catalogue of empty boxes: no cover on a listing card, nothing in a gallery, nothing on a
-- development. That is the intended fallback, not a bug — but it is not a demo anyone can look
-- at, and it is what a fresh load on the test server shows today.
--
-- This points the demo rows at photographs that travel with the repository, in
-- `db/seeds/media/`. `tools/install-seed-media.sh` copies those files into the API's public
-- storage; this file writes the paths that name them.
--
-- The paths are ROOT-RELATIVE — `/media/seed/real-estate/03.jpg`, never an absolute URL.
-- `publicMediaUrl` resolves a stored `/media/...` path against `STORAGE_PUBLIC_BASE_URL` on the
-- way out, so the same seeded row serves correctly from localhost, from the test server and
-- from a CDN without anything in the database naming a host. Absolute URLs are what made the
-- original data environment-specific in the first place.
--
-- Each row picks its image from its own id, so the assignment is stable across loads and a
-- gallery's images differ from each other rather than repeating one picture four times. There
-- are more listings than photographs, so photographs recur across the catalogue — a demo
-- dataset showing a real building beats one showing a grey rectangle.
--
-- Only rows still carrying the untouched `cdn.livfinder.com` seed URLs are rewritten, so an
-- image uploaded through the admin or the portal is never overwritten. IDEMPOTENT: a second
-- run matches nothing.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;

-- How many photographs each category ships with, so the modulo below stays in range. Keep in
-- step with `db/seeds/media/<category>/`; a count larger than the folder points at a 404.
SET @re_count   = 14;
SET @cars_count = 1;
SET @yacht_count = 1;
SET @jet_count  = 1;

-- -----------------------------------------------------------------------------
-- 1 · Listing covers
-- -----------------------------------------------------------------------------
-- Categories with no photographs of their own — helicopters and watches — are deliberately
-- left alone: a watch is not illustrated by a photograph of a building, and the placeholder is
-- the more honest answer until the folder has images for them.
UPDATE listings l
   SET l.cover_image_url = CASE l.root_category_id
         WHEN 1 THEN CONCAT('/media/seed/real-estate/', LPAD(1 + (l.id % @re_count), 2, '0'), '.jpg')
         WHEN 2 THEN CONCAT('/media/seed/cars/',        LPAD(1 + (l.id % @cars_count), 2, '0'), '.jpg')
         WHEN 3 THEN CONCAT('/media/seed/yachts/',      LPAD(1 + (l.id % @yacht_count), 2, '0'), '.jpg')
         WHEN 4 THEN CONCAT('/media/seed/jets/',        LPAD(1 + (l.id % @jet_count), 2, '0'), '.jpg')
       END
 WHERE l.deleted_at IS NULL
   AND l.root_category_id IN (1, 2, 3, 4)
   AND (l.cover_image_url IS NULL OR l.cover_image_url LIKE 'https://cdn.livfinder.com/%');

-- -----------------------------------------------------------------------------
-- 2 · Listing galleries
-- -----------------------------------------------------------------------------
-- `sort_order` joins the modulo so the images within one gallery differ from each other.
UPDATE listing_media m
  JOIN listings l ON l.id = m.listing_id AND l.deleted_at IS NULL
   SET m.url = CASE l.root_category_id
         WHEN 1 THEN CONCAT('/media/seed/real-estate/', LPAD(1 + ((l.id + COALESCE(m.sort_order, 0)) % @re_count), 2, '0'), '.jpg')
         WHEN 2 THEN CONCAT('/media/seed/cars/',        LPAD(1 + (l.id % @cars_count), 2, '0'), '.jpg')
         WHEN 3 THEN CONCAT('/media/seed/yachts/',      LPAD(1 + (l.id % @yacht_count), 2, '0'), '.jpg')
         WHEN 4 THEN CONCAT('/media/seed/jets/',        LPAD(1 + (l.id % @jet_count), 2, '0'), '.jpg')
       END
 WHERE l.root_category_id IN (1, 2, 3, 4)
   AND m.url LIKE 'https://cdn.livfinder.com/%';

-- -----------------------------------------------------------------------------
-- 3 · Media assets behind those galleries
-- -----------------------------------------------------------------------------
-- `media_assets` is the DAM record for the same file; leaving it on the dead host would make
-- the admin's media library disagree with the site.
UPDATE media_assets a
  JOIN media_attachments ma ON ma.media_asset_id = a.id AND ma.attachable_type = 'listing'
  JOIN listings l ON l.id = ma.attachable_id AND l.deleted_at IS NULL
   SET a.url = CASE l.root_category_id
         WHEN 1 THEN CONCAT('/media/seed/real-estate/', LPAD(1 + ((l.id + COALESCE(ma.sort_order, 0)) % @re_count), 2, '0'), '.jpg')
         WHEN 2 THEN CONCAT('/media/seed/cars/',        LPAD(1 + (l.id % @cars_count), 2, '0'), '.jpg')
         WHEN 3 THEN CONCAT('/media/seed/yachts/',      LPAD(1 + (l.id % @yacht_count), 2, '0'), '.jpg')
         WHEN 4 THEN CONCAT('/media/seed/jets/',        LPAD(1 + (l.id % @jet_count), 2, '0'), '.jpg')
       END,
       a.cdn_url = NULL
 WHERE l.root_category_id IN (1, 2, 3, 4)
   AND (a.url LIKE 'https://cdn.livfinder.com/%' OR a.cdn_url LIKE 'https://cdn.livfinder.com/%');

-- -----------------------------------------------------------------------------
-- 4 · Development covers
-- -----------------------------------------------------------------------------
-- Developments draw from the same property photographs, offset so a development and a listing
-- next to each other in the mixed Real Estate results rarely show the same picture.
UPDATE projects p
   SET p.cover_image_url = CONCAT('/media/seed/real-estate/', LPAD(1 + ((p.id + 7) % @re_count), 2, '0'), '.jpg')
 WHERE p.deleted_at IS NULL
   AND (p.cover_image_url IS NULL OR p.cover_image_url LIKE 'https://cdn.livfinder.com/%');

UPDATE media_assets a
  JOIN media_attachments ma ON ma.media_asset_id = a.id AND ma.attachable_type = 'project'
  JOIN projects p ON p.id = ma.attachable_id AND p.deleted_at IS NULL
   SET a.url = CONCAT('/media/seed/real-estate/', LPAD(1 + ((p.id + 7 + COALESCE(ma.sort_order, 0)) % @re_count), 2, '0'), '.jpg'),
       a.cdn_url = NULL
 WHERE a.url LIKE 'https://cdn.livfinder.com/%' OR a.cdn_url LIKE 'https://cdn.livfinder.com/%';

-- -----------------------------------------------------------------------------
-- 5 · Developer logos
-- -----------------------------------------------------------------------------
-- `organizations.logo_url` follows the convention `.../logos/<slug>.png`, and every agency gets
-- a mark from it. `brands.logo_url` — the developers behind the projects — was NULL for all 118
-- rows, so a development card had nothing to show and fell back to a bare initial while the
-- listing beside it in the same mixed grid showed a logo. Same convention, so the two agree.
--
-- These resolve through `MEDIA_CDN_BASE_URL` when one is configured, and through the generated
-- brand mark when it is not, exactly as the organization logos already do.
UPDATE brands
   SET logo_url = CONCAT('https://cdn.livfinder.com/logos/', slug, '.png')
 WHERE deleted_at IS NULL
   AND (logo_url IS NULL OR logo_url = '')
   AND slug IS NOT NULL AND slug <> '';

-- -----------------------------------------------------------------------------
-- 6 · Agent portraits and company logos — off until the images exist
-- -----------------------------------------------------------------------------
-- `users.avatar_url` and `organizations.logo_url` point at the same dead CDN, so every agent
-- renders as a generated initials circle and every company as a lettered box. Fixing that needs
-- real photographs and real logos, and this repository has neither: a portrait has to be of
-- someone who agreed to it, and a logo belongs to the company it names.
--
-- The wiring is here and inert. Drop the files in, set the two counts to how many you added,
-- and reload this file:
--
--   db/seeds/media/avatars/01.jpg …   →  @avatar_count
--   db/seeds/media/logos/01.png …     →  @logo_count
--
-- `tools/install-seed-media.sh` copies any folder under `db/seeds/media/`, so nothing else
-- needs changing. At 0 both statements match no rows and the initials fallback stays.
-- Two portraits ship today. They are the AI-generated headshots the project already used as
-- agent avatars — no photograph of a real person, so nobody's likeness is being published — and
-- they are here so a seeded database shows faces rather than initials.
--
-- Two is thin for 127 agents: the same faces repeat, and both read as men, so an agent whose
-- name suggests otherwise will not match her portrait. Adding more files to
-- `db/seeds/media/avatars/` and raising this count is the whole fix; nothing else changes.
SET @avatar_count = 2;
-- One logo, shipped as `db/seeds/media/logos/01.svg` and worn by every agency and developer.
--
-- These companies are demo records: most are invented, and the few with real-sounding names are
-- not the real firms. So there is no logo of theirs to use, and inventing a different mark per
-- company only produces a hundred variations of the same non-fact. One designed emblem, used
-- everywhere, is honest about that — it says "an agency" rather than pretending to identify one.
-- Add more files and raise the count to give companies distinct marks.
SET @logo_count = 1;

UPDATE users u
   SET u.avatar_url = CONCAT('/media/seed/avatars/', LPAD(1 + (u.id % @avatar_count), 2, '0'), '.jpg')
 WHERE @avatar_count > 0
   AND u.deleted_at IS NULL
   AND (u.avatar_url IS NULL OR u.avatar_url LIKE 'https://cdn.livfinder.com/%');

-- `agents.photo_url` is what the listing cards and the agent directory read; `users.avatar_url`
-- is the account's own picture. Both point at the same dead host and both have to move.
UPDATE agents a
   SET a.photo_url = CONCAT('/media/seed/avatars/', LPAD(1 + (a.id % @avatar_count), 2, '0'), '.jpg')
 WHERE @avatar_count > 0
   AND (a.photo_url IS NULL OR a.photo_url LIKE 'https://cdn.livfinder.com/%');

UPDATE organizations o
   SET o.logo_url = CONCAT('/media/seed/logos/', LPAD(1 + (o.id % @logo_count), 2, '0'), '.svg')
 WHERE @logo_count > 0
   AND (o.logo_url IS NULL OR o.logo_url LIKE 'https://cdn.livfinder.com/%');

-- Developers wear the same mark, so a development card and a listing card in the same mixed
-- grid do not disagree about what a company logo looks like.
UPDATE brands b
   SET b.logo_url = CONCAT('/media/seed/logos/', LPAD(1 + (b.id % @logo_count), 2, '0'), '.svg')
 WHERE @logo_count > 0
   AND b.deleted_at IS NULL
   AND (b.logo_url IS NULL OR b.logo_url LIKE 'https://cdn.livfinder.com/%');

COMMIT;
SET autocommit = 1;

-- Both projections carry their own copy of the cover, so neither shows the old URL until it is
-- rebuilt. `sp_refresh_listing_search` takes a listing id; NULL rebuilds every row.
CALL sp_refresh_listing_search(NULL);
CALL sp_refresh_project_search(NULL);
