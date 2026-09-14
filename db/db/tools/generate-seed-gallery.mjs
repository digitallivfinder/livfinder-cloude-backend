#!/usr/bin/env node
/**
 * Writes the photo lists the seeds use, from db/seeds/media/SOURCES.tsv.
 *
 *   node db/db/tools/generate-seed-gallery.mjs
 *
 * Two outputs:
 *   - seeds/049_demo_gallery.sql, which gives every demo listing 4–8 photographs from its own
 *     subcategory (a plot shows land, a classic car shows classic cars, a jet shows jets);
 *   - the photo list between the @generated markers in seeds/051_demo_seed_images.sql, which
 *     gives every development its gallery.
 *
 * Re-run it after adding rows to SOURCES.tsv (and tools/fetch-seed-media.sh to download them).
 * It refuses to write a plan that asks a pool for more photographs than it holds, because the
 * seed would then quietly give those listings fewer than they should have.
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DB_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MANIFEST = path.join(DB_DIR, "seeds/media/SOURCES.tsv");
const GALLERY_SEED = path.join(DB_DIR, "seeds/049_demo_gallery.sql");
const IMAGES_SEED = path.join(DB_DIR, "seeds/051_demo_seed_images.sql");

/** pool → [listing_media.tag, the words after the listing title in the alt text] */
const POOLS = {
  "real-estate/villa": ["exterior", "exterior"],
  "real-estate/house": ["exterior", "exterior"],
  "real-estate/tower": ["exterior", "building exterior"],
  "real-estate/living": ["living", "living room"],
  "real-estate/bedroom": ["bedroom", "bedroom"],
  "real-estate/kitchen": ["kitchen", "kitchen"],
  "real-estate/bathroom": ["bathroom", "bathroom"],
  "real-estate/office": ["interior", "office space"],
  "real-estate/retail": ["interior", "retail space"],
  "real-estate/plot": ["exterior", "the land"],
  "real-estate/vineyard": ["exterior", "vineyard"],
  "real-estate/island": ["view", "island view"],
  "real-estate/chalet": ["exterior", "chalet"],
  "cars/sports": ["exterior", "exterior"],
  "cars/classic": ["exterior", "exterior"],
  "cars/suv": ["exterior", "exterior"],
  "cars/sedan": ["exterior", "exterior"],
  "cars/convertible": ["exterior", "exterior"],
  "cars/interior": ["interior", "interior"],
  "cars/classic-interior": ["interior", "interior"],
  "yachts/motor": ["exterior", "on the water"],
  "yachts/sail": ["exterior", "under sail"],
  "yachts/catamaran": ["exterior", "on the water"],
  "yachts/sportfish": ["exterior", "on the water"],
  "yachts/interior": ["interior", "interior"],
  "yachts/deck": ["exterior", "deck"],
  "jets/exterior": ["exterior", "exterior"],
  "jets/turboprop": ["exterior", "exterior"],
  "jets/airliner": ["exterior", "exterior"],
  "jets/cabin": ["interior", "cabin"],
  "jets/cockpit": ["detail", "flight deck"],
  "helicopters/helicopter": ["exterior", "exterior"],
  "watches/steel": ["detail", "detail"],
  "watches/classic": ["detail", "detail"],
  "developments/tower": ["exterior", "tower"],
  "developments/amenity": ["amenity", "amenities"],
};

/** The eight gallery slots of each kind of listing, cover first. A listing uses the first 4–8. */
const PROFILES = {
  residence: ["real-estate/villa", "real-estate/living", "real-estate/villa", "real-estate/bedroom", "real-estate/kitchen", "real-estate/bathroom", "real-estate/villa", "real-estate/living"],
  house: ["real-estate/house", "real-estate/living", "real-estate/kitchen", "real-estate/bedroom", "real-estate/house", "real-estate/bathroom", "real-estate/living", "real-estate/bedroom"],
  apartment: ["real-estate/tower", "real-estate/living", "real-estate/bedroom", "real-estate/kitchen", "real-estate/bathroom", "real-estate/living", "real-estate/tower", "real-estate/bedroom"],
  building: ["real-estate/tower", "real-estate/tower", "real-estate/living", "real-estate/tower", "real-estate/kitchen", "real-estate/tower", "real-estate/bedroom", "real-estate/tower"],
  office: Array(8).fill("real-estate/office"),
  retail: Array(8).fill("real-estate/retail"),
  plot: Array(8).fill("real-estate/plot"),
  vineyard: ["real-estate/vineyard", "real-estate/vineyard", "real-estate/villa", "real-estate/vineyard", "real-estate/living", "real-estate/vineyard", "real-estate/kitchen", "real-estate/vineyard"],
  island: ["real-estate/island", "real-estate/island", "real-estate/villa", "real-estate/island", "real-estate/living", "real-estate/island", "real-estate/bedroom", "real-estate/island"],
  chalet: ["real-estate/chalet", "real-estate/chalet", "real-estate/living", "real-estate/chalet", "real-estate/bedroom", "real-estate/chalet", "real-estate/kitchen", "real-estate/chalet"],
  sports: ["cars/sports", "cars/sports", "cars/interior", "cars/sports", "cars/sports", "cars/interior", "cars/sports", "cars/interior"],
  convertible: ["cars/convertible", "cars/convertible", "cars/interior", "cars/convertible", "cars/convertible", "cars/interior", "cars/convertible", "cars/interior"],
  classic: ["cars/classic", "cars/classic", "cars/classic-interior", "cars/classic", "cars/classic", "cars/classic-interior", "cars/classic", "cars/classic-interior"],
  suv: ["cars/suv", "cars/suv", "cars/interior", "cars/suv", "cars/suv", "cars/interior", "cars/suv", "cars/interior"],
  sedan: ["cars/sedan", "cars/sedan", "cars/interior", "cars/sedan", "cars/sedan", "cars/interior", "cars/sedan", "cars/interior"],
  "motor-yacht": ["yachts/motor", "yachts/deck", "yachts/interior", "yachts/motor", "yachts/interior", "yachts/deck", "yachts/motor", "yachts/interior"],
  sail: ["yachts/sail", "yachts/deck", "yachts/interior", "yachts/sail", "yachts/interior", "yachts/deck", "yachts/sail", "yachts/interior"],
  catamaran: ["yachts/catamaran", "yachts/deck", "yachts/interior", "yachts/catamaran", "yachts/interior", "yachts/deck", "yachts/catamaran", "yachts/interior"],
  sportfish: ["yachts/sportfish", "yachts/sportfish", "yachts/interior", "yachts/sportfish", "yachts/deck", "yachts/sportfish", "yachts/interior", "yachts/deck"],
  bizjet: ["jets/exterior", "jets/cabin", "jets/exterior", "jets/cabin", "jets/cockpit", "jets/exterior", "jets/cabin", "jets/exterior"],
  turboprop: ["jets/turboprop", "jets/cabin", "jets/turboprop", "jets/cockpit", "jets/turboprop", "jets/cabin", "jets/turboprop", "jets/cabin"],
  airliner: ["jets/airliner", "jets/cabin", "jets/airliner", "jets/cabin", "jets/cockpit", "jets/airliner", "jets/cabin", "jets/airliner"],
  helicopter: Array(8).fill("helicopters/helicopter"),
  "watch-sport": ["watches/steel", "watches/steel", "watches/classic", "watches/steel", "watches/steel", "watches/classic", "watches/steel", "watches/classic"],
  "watch-dress": ["watches/classic", "watches/classic", "watches/steel", "watches/classic", "watches/classic", "watches/steel", "watches/classic", "watches/steel"],
};

/**
 * Category code → profile. Root codes are the fallback for a listing filed directly under its
 * root or under a subcategory added after this was written.
 */
const CATEGORY_PROFILE = {
  "real-estate": "residence", villa: "residence", mansion: "residence", estate: "residence",
  townhouse: "house", duplex: "house",
  apartment: "apartment", penthouse: "apartment", "hotel-apartment": "apartment",
  "whole-building": "building", office: "office", retail: "retail", plot: "plot",
  vineyard: "vineyard", island: "island", chalet: "chalet",
  cars: "sports", supercar: "sports", hypercar: "sports", coupe: "sports", "grand-tourer": "sports",
  convertible: "convertible", "classic-car": "classic",
  "luxury-suv": "suv", "off-road": "suv", "luxury-sedan": "sedan", "electric-car": "sedan",
  yachts: "motor-yacht", "motor-yacht": "motor-yacht", superyacht: "motor-yacht", "mega-yacht": "motor-yacht",
  explorer: "motor-yacht", "sailing-yacht": "sail", "classic-yacht": "sail", catamaran: "catamaran",
  "sport-fisher": "sportfish",
  jets: "bizjet", "light-jet": "bizjet", "midsize-jet": "bizjet", "super-midsize-jet": "bizjet",
  "heavy-jet": "bizjet", "ultra-long-range": "bizjet", turboprop: "turboprop", "vip-airliner": "airliner",
  helicopters: "helicopter", "light-helicopter": "helicopter", "medium-helicopter": "helicopter",
  "heavy-helicopter": "helicopter", "vip-helicopter": "helicopter",
  watches: "watch-sport", chronograph: "watch-sport", "sports-watch": "watch-sport", "dive-watch": "watch-sport",
  "gmt-worldtimer": "watch-sport", complication: "watch-sport",
  "dress-watch": "watch-dress", "vintage-watch": "watch-dress", "ladies-watch": "watch-dress",
};

/** A development's gallery: the tower, its amenities and the homes inside it. */
const DEVELOPMENT_SLOTS = [
  "developments/tower", "developments/amenity", "real-estate/living", "developments/tower",
  "real-estate/bedroom", "real-estate/kitchen", "developments/amenity", "developments/tower",
];

function readPools() {
  const pools = new Map();
  for (const line of fs.readFileSync(MANIFEST, "utf8").split("\n")) {
    if (!line.trim() || line.startsWith("#")) continue;
    const [category, pool, id] = line.split("\t");
    if (!id) continue;
    const key = `${category}/${pool}`;
    const list = pools.get(key) ?? [];
    const name = `${category}/${pool}-${String(list.length + 1).padStart(2, "0")}.jpg`;
    const file = path.join(DB_DIR, "seeds/media", name);
    if (!fs.existsSync(file)) throw new Error(`${name} is listed but not downloaded — run tools/fetch-seed-media.sh`);
    list.push({ path: `/media/seed/${name}`, bytes: fs.statSync(file).size });
    pools.set(key, list);
  }
  return pools;
}

function assertPlan(pools, name, slots) {
  const uses = {};
  for (const pool of slots) uses[pool] = (uses[pool] ?? 0) + 1;
  for (const [pool, count] of Object.entries(uses)) {
    const size = pools.get(pool)?.length ?? 0;
    if (!POOLS[pool]) throw new Error(`${name}: pool ${pool} has no tag/label`);
    if (size < count) throw new Error(`${name} uses ${pool} ${count}× but it holds ${size} photo(s)`);
  }
}

const quote = (value) => `'${String(value).replace(/'/g, "''")}'`;

function valuesBlock(rows) {
  return rows.map((row) => `  (${row.map((value) => (typeof value === "number" ? value : quote(value))).join(", ")})`).join(",\n");
}

const pools = readPools();
for (const [name, slots] of Object.entries(PROFILES)) assertPlan(pools, name, slots);
assertPlan(pools, "development", DEVELOPMENT_SLOTS);
for (const [code, profile] of Object.entries(CATEGORY_PROFILE)) {
  if (!PROFILES[profile]) throw new Error(`category ${code} maps to unknown profile ${profile}`);
}

const listingPools = [...pools.keys()].filter((pool) => !pool.startsWith("developments/"));
const photoRows = listingPools.flatMap((pool) => pools.get(pool).map((photo, index) => [pool, index, photo.path]));
const poolRows = listingPools.map((pool) => [pool, ...POOLS[pool]]);
const profileRows = Object.entries(PROFILES).flatMap(([name, slots]) => slots.map((pool, index) => [name, index + 1, pool]));
const categoryRows = Object.entries(CATEGORY_PROFILE).map(([code, profile]) => [code, profile]);

const TABLE_OPTIONS = "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";

const gallerySql = `-- =============================================================================
-- Liv Finder — demo seed · listing galleries
-- =============================================================================
-- GENERATED by tools/generate-seed-gallery.mjs from seeds/media/SOURCES.tsv. Edit those, not this.
--
-- 042_demo_listings.sql gives each listing a gallery of \`cdn.livfinder.com\` URLs — a host that
-- does not exist outside a deployment, so every image rendered as a grey placeholder. This
-- replaces those rows, before 050_media.sql derives the media library from them, with 4–8
-- photographs that travel with the repository under seeds/media/ (all Unsplash License).
--
-- Every listing draws from photographs of its own kind, chosen by its subcategory: a villa
-- opens on a villa and shows its living room, bedroom and kitchen; a plot shows land; a vineyard
-- shows vines; a classic car shows classic cars and a period interior; a sailing yacht shows
-- yachts under sail, its deck and its saloon; a turboprop shows turboprops, a cabin and a
-- flight deck. Nothing is ever illustrated by another category's pictures.
--
-- How many: 4 + (listing id mod 5), so the catalogue has a spread of 4, 5, 6, 7 and 8.
-- Which: the cover is dealt round the pool in the order the website lists a category (live first,
-- then featured, quality, newest), so cards next to each other never open on the same photograph.
-- The rest of the gallery ranks the pool by MD5(listing id, file) and takes from the top, so no
-- gallery repeats a picture and the choice is identical on every load — locally and on the test
-- server alike.
--
-- The paths are root-relative (\`/media/seed/cars/sports-03.jpg\`); tools/install-seed-media.sh
-- copies the files into the API's storage, which serves them from any host.
--
-- Only listings whose images are still the untouched \`cdn.livfinder.com\` rows are rebuilt; a
-- photograph uploaded through the portal or the admin is never replaced.
-- =============================================================================

SET NAMES utf8mb4;

DROP TABLE IF EXISTS _seed_pick, _seed_cover, _seed_plan, _seed_category_profile, _seed_profile, _seed_photo, _seed_pool;

CREATE TABLE _seed_pool (
  pool  VARCHAR(40) NOT NULL PRIMARY KEY,
  tag   VARCHAR(40) NOT NULL,
  label VARCHAR(60) NOT NULL
) ${TABLE_OPTIONS};

CREATE TABLE _seed_photo (
  pool VARCHAR(40)       NOT NULL,
  idx  SMALLINT UNSIGNED NOT NULL,
  path VARCHAR(120)      NOT NULL PRIMARY KEY,
  KEY idx_seed_photo_pool (pool)
) ${TABLE_OPTIONS};

CREATE TABLE _seed_profile (
  profile VARCHAR(40)      NOT NULL,
  slot    TINYINT UNSIGNED NOT NULL,
  pool    VARCHAR(40)      NOT NULL,
  PRIMARY KEY (profile, slot)
) ${TABLE_OPTIONS};

CREATE TABLE _seed_category_profile (
  category_code VARCHAR(80) NOT NULL PRIMARY KEY,
  profile       VARCHAR(40) NOT NULL
) ${TABLE_OPTIONS};

INSERT INTO _seed_pool (pool, tag, label) VALUES
${valuesBlock(poolRows)};

INSERT INTO _seed_photo (pool, idx, path) VALUES
${valuesBlock(photoRows)};

INSERT INTO _seed_profile (profile, slot, pool) VALUES
${valuesBlock(profileRows)};

INSERT INTO _seed_category_profile (category_code, profile) VALUES
${valuesBlock(categoryRows)};

-- Which pool each of a listing's slots draws from, and how many of that pool it has already used.
CREATE TABLE _seed_plan ${TABLE_OPTIONS} AS
SELECT l.id AS listing_id, s.slot, s.pool,
       ROW_NUMBER() OVER (PARTITION BY l.id, s.pool ORDER BY s.slot) AS pool_rank
  FROM listings l
  JOIN categories c ON c.id = l.category_id
  JOIN categories r ON r.id = l.root_category_id
  LEFT JOIN _seed_category_profile leaf ON leaf.category_code = c.code
  LEFT JOIN _seed_category_profile root ON root.category_code = r.code
  JOIN _seed_profile s ON s.profile = COALESCE(leaf.profile, root.profile)
                      AND s.slot <= 4 + (l.id % 5)
 WHERE NOT EXISTS (
         SELECT 1 FROM listing_media m
          WHERE m.listing_id = l.id AND m.media_type = 'image'
            AND m.url NOT LIKE 'https://cdn.livfinder.com/%'
       );

-- Where each listing sits among the listings that open on the same pool, in the order the
-- website lists them. Its cover is that position, dealt round the pool.
CREATE TABLE _seed_cover ${TABLE_OPTIONS} AS
SELECT p.listing_id, p.pool,
       ROW_NUMBER() OVER (PARTITION BY p.pool
                          ORDER BY l.status = 'active' DESC, l.is_featured DESC, l.quality_score DESC,
                                   l.published_at DESC, l.id) - 1 AS feed_rank
  FROM _seed_plan p
  JOIN listings l ON l.id = p.listing_id
 WHERE p.slot = 1;

-- The photograph for each slot: the listing's n-th pick from that pool — its dealt cover first
-- where the pool is its cover pool, then its own shuffled order.
CREATE TABLE _seed_pick ${TABLE_OPTIONS} AS
SELECT p.listing_id, p.slot, p.pool, ranked.path
  FROM _seed_plan p
  JOIN (
        SELECT x.listing_id, ph.pool, ph.path,
               ROW_NUMBER() OVER (PARTITION BY x.listing_id, ph.pool
                                  ORDER BY (cv.listing_id IS NOT NULL AND ph.idx = MOD(cv.feed_rank, sz.size)) DESC,
                                           MD5(CONCAT(x.listing_id, ':', ph.path))) AS pick_rank
          FROM (SELECT DISTINCT listing_id, pool FROM _seed_plan) x
          JOIN _seed_photo ph ON ph.pool = x.pool
          JOIN (SELECT pool, COUNT(*) AS size FROM _seed_photo GROUP BY pool) sz ON sz.pool = ph.pool
          LEFT JOIN _seed_cover cv ON cv.listing_id = x.listing_id AND cv.pool = x.pool
       ) ranked
    ON ranked.listing_id = p.listing_id AND ranked.pool = p.pool AND ranked.pick_rank = p.pool_rank;

ALTER TABLE _seed_pick ADD PRIMARY KEY (listing_id, slot);

DELETE m
  FROM listing_media m
  JOIN (SELECT DISTINCT listing_id FROM _seed_pick) k ON k.listing_id = m.listing_id
 WHERE m.media_type = 'image';

INSERT INTO listing_media
  (listing_id, media_type, url, thumbnail_url, alt_text, tag, sort_order, is_cover, is_public, created_at)
SELECT k.listing_id, 'image', k.path, NULL,
       LEFT(CONCAT(l.title, ' — ', pl.label), 255),
       pl.tag, k.slot - 1, k.slot = 1, 1, l.created_at
  FROM _seed_pick k
  JOIN listings l ON l.id = k.listing_id
  JOIN _seed_pool pl ON pl.pool = k.pool
 ORDER BY k.listing_id, k.slot;

-- The card reads the listing's own cover and count; keep them equal to the gallery.
UPDATE listings l
  JOIN (SELECT listing_id, COUNT(*) AS images, MAX(CASE WHEN slot = 1 THEN path END) AS cover
          FROM _seed_pick GROUP BY listing_id) g ON g.listing_id = l.id
   SET l.cover_image_url = g.cover,
       l.cover_image_alt = LEFT(CONCAT(l.title, ' — main image'), 255),
       l.image_count     = g.images,
       l.updated_at      = l.updated_at;

DROP TABLE IF EXISTS _seed_pick, _seed_cover, _seed_plan, _seed_category_profile, _seed_profile, _seed_photo, _seed_pool;
`;

fs.writeFileSync(GALLERY_SEED, gallerySql);

const developmentPools = [...new Set(DEVELOPMENT_SLOTS)];
const projectPhotoRows = developmentPools.flatMap((pool) =>
  pools.get(pool).map((photo, index) => [pool, index, photo.path, POOLS[pool][1]])
);
const fileRows = [...pools.values()].flat().map((photo) => [photo.path, photo.bytes]);
const projectSlotRows = DEVELOPMENT_SLOTS.map((pool, index) => [index + 1, pool]);
const generated = `-- @generated:start — tools/generate-seed-gallery.mjs writes this block; do not edit by hand.
INSERT INTO _seed_file (path, bytes) VALUES
${valuesBlock(fileRows)};

INSERT INTO _seed_project_photo (pool, idx, path, label) VALUES
${valuesBlock(projectPhotoRows)};

INSERT INTO _seed_project_slot (slot, pool) VALUES
${valuesBlock(projectSlotRows)};
-- @generated:end`;

const images = fs.readFileSync(IMAGES_SEED, "utf8");
const marker = /-- @generated:start[\s\S]*?-- @generated:end/;
if (!marker.test(images)) throw new Error(`${IMAGES_SEED} has no @generated block`);
fs.writeFileSync(IMAGES_SEED, images.replace(marker, generated));

const listingPhotos = photoRows.length;
console.log(`049_demo_gallery.sql: ${listingPhotos} listing photographs in ${listingPools.length} pools, ${Object.keys(PROFILES).length} profiles, ${categoryRows.length} category mappings`);
console.log(`051_demo_seed_images.sql: ${fileRows.length} file sizes, ${projectPhotoRows.length} development photographs`);
