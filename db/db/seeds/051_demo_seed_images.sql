-- =============================================================================
-- Liv Finder — demo seed · photographs for the demo catalogue
-- =============================================================================
-- Image URLs in the base seeds point at `https://cdn.livfinder.com/...`, a host that exists in a
-- deployed environment and nowhere else. `src/middleware/legacyMedia.js` rewrites those on the
-- way out to a generated grey SVG placeholder, so without this file a freshly seeded database
-- renders a catalogue of empty boxes.
--
-- The photographs themselves travel with the repository, in `db/seeds/media/` (listed with their
-- Unsplash sources in `media/SOURCES.tsv`). `tools/install-seed-media.sh` copies them into the
-- API's public storage; the seeds write the paths that name them.
--
--   049_demo_gallery.sql   every listing's 4–8 photographs, chosen from its own subcategory.
--                          Runs before 050_media.sql so the media library is derived from them.
--   this file              the media library's view of those photographs, every development's
--                          gallery, and agent portraits and company logos.
--
-- The paths are ROOT-RELATIVE — `/media/seed/developments/tower-03.jpg`, never an absolute URL.
-- `publicMediaUrl` resolves a stored `/media/...` path against `STORAGE_PUBLIC_BASE_URL` on the
-- way out, so the same seeded row serves correctly from localhost, from the test server and from
-- a CDN without anything in the database naming a host.
--
-- Nothing uploaded through the admin or the portal is ever overwritten. IDEMPOTENT: a second run
-- matches nothing.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;

-- The seed photographs: every file under db/seeds/media/ with its size on disk, and the
-- development gallery sets. Written by tools/generate-seed-gallery.mjs from media/SOURCES.tsv.
DROP TABLE IF EXISTS _seed_project_pick, _seed_project_plan, _seed_project_slot, _seed_project_photo, _seed_file;

CREATE TABLE _seed_file (
  path  VARCHAR(120) NOT NULL PRIMARY KEY,
  bytes INT UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE _seed_project_photo (
  pool  VARCHAR(40)       NOT NULL,
  idx   SMALLINT UNSIGNED NOT NULL,
  path  VARCHAR(120)      NOT NULL PRIMARY KEY,
  label VARCHAR(60)       NOT NULL,
  KEY idx_seed_project_photo_pool (pool)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE _seed_project_slot (
  slot TINYINT UNSIGNED NOT NULL PRIMARY KEY,
  pool VARCHAR(40)      NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- @generated:start — tools/generate-seed-gallery.mjs writes this block; do not edit by hand.
INSERT INTO _seed_file (path, bytes) VALUES
  ('/media/seed/real-estate/villa-01.jpg', 195643),
  ('/media/seed/real-estate/villa-02.jpg', 184212),
  ('/media/seed/real-estate/villa-03.jpg', 219717),
  ('/media/seed/real-estate/villa-04.jpg', 150263),
  ('/media/seed/real-estate/villa-05.jpg', 237788),
  ('/media/seed/real-estate/villa-06.jpg', 140261),
  ('/media/seed/real-estate/villa-07.jpg', 176711),
  ('/media/seed/real-estate/villa-08.jpg', 164153),
  ('/media/seed/real-estate/villa-09.jpg', 265409),
  ('/media/seed/real-estate/villa-10.jpg', 194451),
  ('/media/seed/real-estate/villa-11.jpg', 142092),
  ('/media/seed/real-estate/villa-12.jpg', 257533),
  ('/media/seed/real-estate/villa-13.jpg', 164863),
  ('/media/seed/real-estate/villa-14.jpg', 221710),
  ('/media/seed/real-estate/villa-15.jpg', 135052),
  ('/media/seed/real-estate/villa-16.jpg', 248562),
  ('/media/seed/real-estate/house-01.jpg', 242856),
  ('/media/seed/real-estate/house-02.jpg', 361964),
  ('/media/seed/real-estate/house-03.jpg', 159834),
  ('/media/seed/real-estate/house-04.jpg', 181627),
  ('/media/seed/real-estate/house-05.jpg', 243985),
  ('/media/seed/real-estate/house-06.jpg', 290977),
  ('/media/seed/real-estate/house-07.jpg', 167239),
  ('/media/seed/real-estate/house-08.jpg', 197878),
  ('/media/seed/real-estate/tower-01.jpg', 133727),
  ('/media/seed/real-estate/tower-02.jpg', 103509),
  ('/media/seed/real-estate/tower-03.jpg', 164880),
  ('/media/seed/real-estate/tower-04.jpg', 142639),
  ('/media/seed/real-estate/tower-05.jpg', 111054),
  ('/media/seed/real-estate/tower-06.jpg', 154484),
  ('/media/seed/real-estate/tower-07.jpg', 178190),
  ('/media/seed/real-estate/tower-08.jpg', 173900),
  ('/media/seed/real-estate/tower-09.jpg', 163063),
  ('/media/seed/real-estate/tower-10.jpg', 212735),
  ('/media/seed/real-estate/living-01.jpg', 174131),
  ('/media/seed/real-estate/living-02.jpg', 131954),
  ('/media/seed/real-estate/living-03.jpg', 156015),
  ('/media/seed/real-estate/living-04.jpg', 211656),
  ('/media/seed/real-estate/living-05.jpg', 137883),
  ('/media/seed/real-estate/living-06.jpg', 204961),
  ('/media/seed/real-estate/living-07.jpg', 167104),
  ('/media/seed/real-estate/living-08.jpg', 126768),
  ('/media/seed/real-estate/living-09.jpg', 139403),
  ('/media/seed/real-estate/living-10.jpg', 155658),
  ('/media/seed/real-estate/bedroom-01.jpg', 191945),
  ('/media/seed/real-estate/bedroom-02.jpg', 207199),
  ('/media/seed/real-estate/bedroom-03.jpg', 294395),
  ('/media/seed/real-estate/bedroom-04.jpg', 195348),
  ('/media/seed/real-estate/bedroom-05.jpg', 173575),
  ('/media/seed/real-estate/bedroom-06.jpg', 135223),
  ('/media/seed/real-estate/bedroom-07.jpg', 214384),
  ('/media/seed/real-estate/bedroom-08.jpg', 163774),
  ('/media/seed/real-estate/kitchen-01.jpg', 140213),
  ('/media/seed/real-estate/kitchen-02.jpg', 197060),
  ('/media/seed/real-estate/kitchen-03.jpg', 116904),
  ('/media/seed/real-estate/kitchen-04.jpg', 106908),
  ('/media/seed/real-estate/kitchen-05.jpg', 127977),
  ('/media/seed/real-estate/kitchen-06.jpg', 112081),
  ('/media/seed/real-estate/kitchen-07.jpg', 117931),
  ('/media/seed/real-estate/kitchen-08.jpg', 147208),
  ('/media/seed/real-estate/bathroom-01.jpg', 138145),
  ('/media/seed/real-estate/bathroom-02.jpg', 221035),
  ('/media/seed/real-estate/bathroom-03.jpg', 139510),
  ('/media/seed/real-estate/bathroom-04.jpg', 176077),
  ('/media/seed/real-estate/bathroom-05.jpg', 101990),
  ('/media/seed/real-estate/bathroom-06.jpg', 176762),
  ('/media/seed/real-estate/bathroom-07.jpg', 137432),
  ('/media/seed/real-estate/office-01.jpg', 157259),
  ('/media/seed/real-estate/office-02.jpg', 143778),
  ('/media/seed/real-estate/office-03.jpg', 211008),
  ('/media/seed/real-estate/office-04.jpg', 190673),
  ('/media/seed/real-estate/office-05.jpg', 164828),
  ('/media/seed/real-estate/office-06.jpg', 116667),
  ('/media/seed/real-estate/office-07.jpg', 156515),
  ('/media/seed/real-estate/office-08.jpg', 216830),
  ('/media/seed/real-estate/office-09.jpg', 103290),
  ('/media/seed/real-estate/retail-01.jpg', 113489),
  ('/media/seed/real-estate/retail-02.jpg', 235405),
  ('/media/seed/real-estate/retail-03.jpg', 94190),
  ('/media/seed/real-estate/retail-04.jpg', 195286),
  ('/media/seed/real-estate/retail-05.jpg', 224798),
  ('/media/seed/real-estate/retail-06.jpg', 178889),
  ('/media/seed/real-estate/retail-07.jpg', 119053),
  ('/media/seed/real-estate/retail-08.jpg', 272133),
  ('/media/seed/real-estate/plot-01.jpg', 392482),
  ('/media/seed/real-estate/plot-02.jpg', 161946),
  ('/media/seed/real-estate/plot-03.jpg', 272731),
  ('/media/seed/real-estate/plot-04.jpg', 332524),
  ('/media/seed/real-estate/plot-05.jpg', 488842),
  ('/media/seed/real-estate/plot-06.jpg', 355138),
  ('/media/seed/real-estate/plot-07.jpg', 364692),
  ('/media/seed/real-estate/plot-08.jpg', 345595),
  ('/media/seed/real-estate/vineyard-01.jpg', 185262),
  ('/media/seed/real-estate/vineyard-02.jpg', 327292),
  ('/media/seed/real-estate/vineyard-03.jpg', 159246),
  ('/media/seed/real-estate/vineyard-04.jpg', 160268),
  ('/media/seed/real-estate/vineyard-05.jpg', 203558),
  ('/media/seed/real-estate/vineyard-06.jpg', 271079),
  ('/media/seed/real-estate/vineyard-07.jpg', 285148),
  ('/media/seed/real-estate/vineyard-08.jpg', 222373),
  ('/media/seed/real-estate/island-01.jpg', 130081),
  ('/media/seed/real-estate/island-02.jpg', 181087),
  ('/media/seed/real-estate/island-03.jpg', 297883),
  ('/media/seed/real-estate/island-04.jpg', 154506),
  ('/media/seed/real-estate/island-05.jpg', 216605),
  ('/media/seed/real-estate/island-06.jpg', 229350),
  ('/media/seed/real-estate/island-07.jpg', 359849),
  ('/media/seed/real-estate/island-08.jpg', 171126),
  ('/media/seed/real-estate/chalet-01.jpg', 357318),
  ('/media/seed/real-estate/chalet-02.jpg', 182636),
  ('/media/seed/real-estate/chalet-03.jpg', 175961),
  ('/media/seed/real-estate/chalet-04.jpg', 138702),
  ('/media/seed/real-estate/chalet-05.jpg', 351981),
  ('/media/seed/real-estate/chalet-06.jpg', 215452),
  ('/media/seed/real-estate/chalet-07.jpg', 255806),
  ('/media/seed/real-estate/chalet-08.jpg', 226161),
  ('/media/seed/cars/sports-01.jpg', 237768),
  ('/media/seed/cars/sports-02.jpg', 114245),
  ('/media/seed/cars/sports-03.jpg', 246453),
  ('/media/seed/cars/sports-04.jpg', 181790),
  ('/media/seed/cars/sports-05.jpg', 199468),
  ('/media/seed/cars/sports-06.jpg', 161017),
  ('/media/seed/cars/sports-07.jpg', 218583),
  ('/media/seed/cars/sports-08.jpg', 184270),
  ('/media/seed/cars/sports-09.jpg', 296209),
  ('/media/seed/cars/sports-10.jpg', 135081),
  ('/media/seed/cars/sports-11.jpg', 125423),
  ('/media/seed/cars/sports-12.jpg', 190922),
  ('/media/seed/cars/classic-01.jpg', 145855),
  ('/media/seed/cars/classic-02.jpg', 127718),
  ('/media/seed/cars/classic-03.jpg', 291494),
  ('/media/seed/cars/classic-04.jpg', 192247),
  ('/media/seed/cars/classic-05.jpg', 233982),
  ('/media/seed/cars/classic-06.jpg', 184311),
  ('/media/seed/cars/classic-07.jpg', 225459),
  ('/media/seed/cars/classic-08.jpg', 247904),
  ('/media/seed/cars/classic-interior-01.jpg', 124769),
  ('/media/seed/cars/classic-interior-02.jpg', 142493),
  ('/media/seed/cars/classic-interior-03.jpg', 140039),
  ('/media/seed/cars/suv-01.jpg', 206057),
  ('/media/seed/cars/suv-02.jpg', 194470),
  ('/media/seed/cars/suv-03.jpg', 181932),
  ('/media/seed/cars/suv-04.jpg', 114130),
  ('/media/seed/cars/suv-05.jpg', 321844),
  ('/media/seed/cars/suv-06.jpg', 189515),
  ('/media/seed/cars/suv-07.jpg', 180670),
  ('/media/seed/cars/suv-08.jpg', 166594),
  ('/media/seed/cars/sedan-01.jpg', 211158),
  ('/media/seed/cars/sedan-02.jpg', 202755),
  ('/media/seed/cars/sedan-03.jpg', 127780),
  ('/media/seed/cars/sedan-04.jpg', 193801),
  ('/media/seed/cars/sedan-05.jpg', 167766),
  ('/media/seed/cars/sedan-06.jpg', 162167),
  ('/media/seed/cars/sedan-07.jpg', 257368),
  ('/media/seed/cars/sedan-08.jpg', 295525),
  ('/media/seed/cars/convertible-01.jpg', 206488),
  ('/media/seed/cars/convertible-02.jpg', 153300),
  ('/media/seed/cars/convertible-03.jpg', 129679),
  ('/media/seed/cars/convertible-04.jpg', 142992),
  ('/media/seed/cars/convertible-05.jpg', 220931),
  ('/media/seed/cars/convertible-06.jpg', 22895),
  ('/media/seed/cars/interior-01.jpg', 96252),
  ('/media/seed/cars/interior-02.jpg', 129943),
  ('/media/seed/cars/interior-03.jpg', 143743),
  ('/media/seed/cars/interior-04.jpg', 158125),
  ('/media/seed/cars/interior-05.jpg', 125047),
  ('/media/seed/cars/interior-06.jpg', 132675),
  ('/media/seed/cars/interior-07.jpg', 91673),
  ('/media/seed/cars/interior-08.jpg', 223122),
  ('/media/seed/yachts/motor-01.jpg', 203264),
  ('/media/seed/yachts/motor-02.jpg', 266921),
  ('/media/seed/yachts/motor-03.jpg', 159292),
  ('/media/seed/yachts/motor-04.jpg', 139401),
  ('/media/seed/yachts/motor-05.jpg', 360519),
  ('/media/seed/yachts/motor-06.jpg', 142581),
  ('/media/seed/yachts/motor-07.jpg', 264836),
  ('/media/seed/yachts/motor-08.jpg', 123545),
  ('/media/seed/yachts/motor-09.jpg', 129944),
  ('/media/seed/yachts/motor-10.jpg', 138545),
  ('/media/seed/yachts/motor-11.jpg', 201468),
  ('/media/seed/yachts/sail-01.jpg', 161951),
  ('/media/seed/yachts/sail-02.jpg', 64606),
  ('/media/seed/yachts/sail-03.jpg', 224060),
  ('/media/seed/yachts/sail-04.jpg', 123385),
  ('/media/seed/yachts/sail-05.jpg', 84485),
  ('/media/seed/yachts/sail-06.jpg', 113094),
  ('/media/seed/yachts/sail-07.jpg', 232148),
  ('/media/seed/yachts/sail-08.jpg', 139712),
  ('/media/seed/yachts/catamaran-01.jpg', 279485),
  ('/media/seed/yachts/catamaran-02.jpg', 168344),
  ('/media/seed/yachts/catamaran-03.jpg', 142583),
  ('/media/seed/yachts/catamaran-04.jpg', 176935),
  ('/media/seed/yachts/catamaran-05.jpg', 320047),
  ('/media/seed/yachts/catamaran-06.jpg', 256016),
  ('/media/seed/yachts/sportfish-01.jpg', 147153),
  ('/media/seed/yachts/sportfish-02.jpg', 198838),
  ('/media/seed/yachts/sportfish-03.jpg', 178547),
  ('/media/seed/yachts/sportfish-04.jpg', 164150),
  ('/media/seed/yachts/sportfish-05.jpg', 230758),
  ('/media/seed/yachts/sportfish-06.jpg', 152066),
  ('/media/seed/yachts/interior-01.jpg', 140876),
  ('/media/seed/yachts/interior-02.jpg', 217959),
  ('/media/seed/yachts/interior-03.jpg', 168700),
  ('/media/seed/yachts/interior-04.jpg', 147924),
  ('/media/seed/yachts/interior-05.jpg', 83520),
  ('/media/seed/yachts/interior-06.jpg', 92671),
  ('/media/seed/yachts/interior-07.jpg', 195047),
  ('/media/seed/yachts/deck-01.jpg', 178228),
  ('/media/seed/yachts/deck-02.jpg', 169324),
  ('/media/seed/yachts/deck-03.jpg', 225634),
  ('/media/seed/yachts/deck-04.jpg', 119794),
  ('/media/seed/yachts/deck-05.jpg', 252817),
  ('/media/seed/yachts/deck-06.jpg', 281441),
  ('/media/seed/jets/exterior-01.jpg', 95661),
  ('/media/seed/jets/exterior-02.jpg', 120996),
  ('/media/seed/jets/exterior-03.jpg', 125813),
  ('/media/seed/jets/exterior-04.jpg', 125912),
  ('/media/seed/jets/exterior-05.jpg', 142611),
  ('/media/seed/jets/exterior-06.jpg', 85902),
  ('/media/seed/jets/exterior-07.jpg', 99189),
  ('/media/seed/jets/exterior-08.jpg', 87157),
  ('/media/seed/jets/exterior-09.jpg', 124803),
  ('/media/seed/jets/exterior-10.jpg', 144411),
  ('/media/seed/jets/exterior-11.jpg', 77217),
  ('/media/seed/jets/cabin-01.jpg', 202863),
  ('/media/seed/jets/cabin-02.jpg', 166901),
  ('/media/seed/jets/cabin-03.jpg', 151328),
  ('/media/seed/jets/cabin-04.jpg', 160240),
  ('/media/seed/jets/cabin-05.jpg', 151855),
  ('/media/seed/jets/cabin-06.jpg', 115904),
  ('/media/seed/jets/cabin-07.jpg', 175678),
  ('/media/seed/jets/cabin-08.jpg', 154152),
  ('/media/seed/jets/cabin-09.jpg', 123682),
  ('/media/seed/jets/cockpit-01.jpg', 128648),
  ('/media/seed/jets/cockpit-02.jpg', 134443),
  ('/media/seed/jets/cockpit-03.jpg', 161853),
  ('/media/seed/jets/cockpit-04.jpg', 124966),
  ('/media/seed/jets/cockpit-05.jpg', 163189),
  ('/media/seed/jets/turboprop-01.jpg', 155758),
  ('/media/seed/jets/turboprop-02.jpg', 194073),
  ('/media/seed/jets/turboprop-03.jpg', 164867),
  ('/media/seed/jets/turboprop-04.jpg', 165263),
  ('/media/seed/jets/turboprop-05.jpg', 81508),
  ('/media/seed/jets/airliner-01.jpg', 177024),
  ('/media/seed/jets/airliner-02.jpg', 120062),
  ('/media/seed/jets/airliner-03.jpg', 267302),
  ('/media/seed/jets/airliner-04.jpg', 200129),
  ('/media/seed/jets/airliner-05.jpg', 162378),
  ('/media/seed/jets/airliner-06.jpg', 51757),
  ('/media/seed/helicopters/helicopter-01.jpg', 125645),
  ('/media/seed/helicopters/helicopter-02.jpg', 45673),
  ('/media/seed/helicopters/helicopter-03.jpg', 46487),
  ('/media/seed/helicopters/helicopter-04.jpg', 110105),
  ('/media/seed/helicopters/helicopter-05.jpg', 109346),
  ('/media/seed/helicopters/helicopter-06.jpg', 70460),
  ('/media/seed/helicopters/helicopter-07.jpg', 158313),
  ('/media/seed/helicopters/helicopter-08.jpg', 134751),
  ('/media/seed/helicopters/helicopter-09.jpg', 111651),
  ('/media/seed/helicopters/helicopter-10.jpg', 86524),
  ('/media/seed/helicopters/helicopter-11.jpg', 109839),
  ('/media/seed/helicopters/helicopter-12.jpg', 197699),
  ('/media/seed/helicopters/helicopter-13.jpg', 170958),
  ('/media/seed/helicopters/helicopter-14.jpg', 141224),
  ('/media/seed/helicopters/helicopter-15.jpg', 125629),
  ('/media/seed/helicopters/helicopter-16.jpg', 151535),
  ('/media/seed/helicopters/helicopter-17.jpg', 105211),
  ('/media/seed/helicopters/helicopter-18.jpg', 196915),
  ('/media/seed/helicopters/helicopter-19.jpg', 161653),
  ('/media/seed/watches/steel-01.jpg', 113258),
  ('/media/seed/watches/steel-02.jpg', 84786),
  ('/media/seed/watches/steel-03.jpg', 151750),
  ('/media/seed/watches/steel-04.jpg', 143651),
  ('/media/seed/watches/steel-05.jpg', 222120),
  ('/media/seed/watches/steel-06.jpg', 45245),
  ('/media/seed/watches/steel-07.jpg', 101361),
  ('/media/seed/watches/steel-08.jpg', 120616),
  ('/media/seed/watches/steel-09.jpg', 111977),
  ('/media/seed/watches/steel-10.jpg', 122596),
  ('/media/seed/watches/steel-11.jpg', 88087),
  ('/media/seed/watches/steel-12.jpg', 112771),
  ('/media/seed/watches/steel-13.jpg', 127995),
  ('/media/seed/watches/steel-14.jpg', 85787),
  ('/media/seed/watches/classic-01.jpg', 145759),
  ('/media/seed/watches/classic-02.jpg', 95182),
  ('/media/seed/watches/classic-03.jpg', 98772),
  ('/media/seed/watches/classic-04.jpg', 121572),
  ('/media/seed/watches/classic-05.jpg', 125577),
  ('/media/seed/watches/classic-06.jpg', 183181),
  ('/media/seed/watches/classic-07.jpg', 178548),
  ('/media/seed/watches/classic-08.jpg', 62296),
  ('/media/seed/watches/classic-09.jpg', 189776),
  ('/media/seed/watches/classic-10.jpg', 46996),
  ('/media/seed/watches/classic-11.jpg', 115302),
  ('/media/seed/developments/tower-01.jpg', 280140),
  ('/media/seed/developments/tower-02.jpg', 205619),
  ('/media/seed/developments/tower-03.jpg', 212636),
  ('/media/seed/developments/tower-04.jpg', 385873),
  ('/media/seed/developments/tower-05.jpg', 265417),
  ('/media/seed/developments/tower-06.jpg', 245544),
  ('/media/seed/developments/tower-07.jpg', 180932),
  ('/media/seed/developments/tower-08.jpg', 68743),
  ('/media/seed/developments/tower-09.jpg', 134809),
  ('/media/seed/developments/tower-10.jpg', 276870),
  ('/media/seed/developments/tower-11.jpg', 167223),
  ('/media/seed/developments/tower-12.jpg', 179681),
  ('/media/seed/developments/tower-13.jpg', 156071),
  ('/media/seed/developments/tower-14.jpg', 253747),
  ('/media/seed/developments/amenity-01.jpg', 239568),
  ('/media/seed/developments/amenity-02.jpg', 214640),
  ('/media/seed/developments/amenity-03.jpg', 212036),
  ('/media/seed/developments/amenity-04.jpg', 208803),
  ('/media/seed/developments/amenity-05.jpg', 183963),
  ('/media/seed/developments/amenity-06.jpg', 159822),
  ('/media/seed/developments/amenity-07.jpg', 265699),
  ('/media/seed/developments/amenity-08.jpg', 287610);

INSERT INTO _seed_project_photo (pool, idx, path, label) VALUES
  ('developments/tower', 0, '/media/seed/developments/tower-01.jpg', 'tower'),
  ('developments/tower', 1, '/media/seed/developments/tower-02.jpg', 'tower'),
  ('developments/tower', 2, '/media/seed/developments/tower-03.jpg', 'tower'),
  ('developments/tower', 3, '/media/seed/developments/tower-04.jpg', 'tower'),
  ('developments/tower', 4, '/media/seed/developments/tower-05.jpg', 'tower'),
  ('developments/tower', 5, '/media/seed/developments/tower-06.jpg', 'tower'),
  ('developments/tower', 6, '/media/seed/developments/tower-07.jpg', 'tower'),
  ('developments/tower', 7, '/media/seed/developments/tower-08.jpg', 'tower'),
  ('developments/tower', 8, '/media/seed/developments/tower-09.jpg', 'tower'),
  ('developments/tower', 9, '/media/seed/developments/tower-10.jpg', 'tower'),
  ('developments/tower', 10, '/media/seed/developments/tower-11.jpg', 'tower'),
  ('developments/tower', 11, '/media/seed/developments/tower-12.jpg', 'tower'),
  ('developments/tower', 12, '/media/seed/developments/tower-13.jpg', 'tower'),
  ('developments/tower', 13, '/media/seed/developments/tower-14.jpg', 'tower'),
  ('developments/amenity', 0, '/media/seed/developments/amenity-01.jpg', 'amenities'),
  ('developments/amenity', 1, '/media/seed/developments/amenity-02.jpg', 'amenities'),
  ('developments/amenity', 2, '/media/seed/developments/amenity-03.jpg', 'amenities'),
  ('developments/amenity', 3, '/media/seed/developments/amenity-04.jpg', 'amenities'),
  ('developments/amenity', 4, '/media/seed/developments/amenity-05.jpg', 'amenities'),
  ('developments/amenity', 5, '/media/seed/developments/amenity-06.jpg', 'amenities'),
  ('developments/amenity', 6, '/media/seed/developments/amenity-07.jpg', 'amenities'),
  ('developments/amenity', 7, '/media/seed/developments/amenity-08.jpg', 'amenities'),
  ('real-estate/living', 0, '/media/seed/real-estate/living-01.jpg', 'living room'),
  ('real-estate/living', 1, '/media/seed/real-estate/living-02.jpg', 'living room'),
  ('real-estate/living', 2, '/media/seed/real-estate/living-03.jpg', 'living room'),
  ('real-estate/living', 3, '/media/seed/real-estate/living-04.jpg', 'living room'),
  ('real-estate/living', 4, '/media/seed/real-estate/living-05.jpg', 'living room'),
  ('real-estate/living', 5, '/media/seed/real-estate/living-06.jpg', 'living room'),
  ('real-estate/living', 6, '/media/seed/real-estate/living-07.jpg', 'living room'),
  ('real-estate/living', 7, '/media/seed/real-estate/living-08.jpg', 'living room'),
  ('real-estate/living', 8, '/media/seed/real-estate/living-09.jpg', 'living room'),
  ('real-estate/living', 9, '/media/seed/real-estate/living-10.jpg', 'living room'),
  ('real-estate/bedroom', 0, '/media/seed/real-estate/bedroom-01.jpg', 'bedroom'),
  ('real-estate/bedroom', 1, '/media/seed/real-estate/bedroom-02.jpg', 'bedroom'),
  ('real-estate/bedroom', 2, '/media/seed/real-estate/bedroom-03.jpg', 'bedroom'),
  ('real-estate/bedroom', 3, '/media/seed/real-estate/bedroom-04.jpg', 'bedroom'),
  ('real-estate/bedroom', 4, '/media/seed/real-estate/bedroom-05.jpg', 'bedroom'),
  ('real-estate/bedroom', 5, '/media/seed/real-estate/bedroom-06.jpg', 'bedroom'),
  ('real-estate/bedroom', 6, '/media/seed/real-estate/bedroom-07.jpg', 'bedroom'),
  ('real-estate/bedroom', 7, '/media/seed/real-estate/bedroom-08.jpg', 'bedroom'),
  ('real-estate/kitchen', 0, '/media/seed/real-estate/kitchen-01.jpg', 'kitchen'),
  ('real-estate/kitchen', 1, '/media/seed/real-estate/kitchen-02.jpg', 'kitchen'),
  ('real-estate/kitchen', 2, '/media/seed/real-estate/kitchen-03.jpg', 'kitchen'),
  ('real-estate/kitchen', 3, '/media/seed/real-estate/kitchen-04.jpg', 'kitchen'),
  ('real-estate/kitchen', 4, '/media/seed/real-estate/kitchen-05.jpg', 'kitchen'),
  ('real-estate/kitchen', 5, '/media/seed/real-estate/kitchen-06.jpg', 'kitchen'),
  ('real-estate/kitchen', 6, '/media/seed/real-estate/kitchen-07.jpg', 'kitchen'),
  ('real-estate/kitchen', 7, '/media/seed/real-estate/kitchen-08.jpg', 'kitchen');

INSERT INTO _seed_project_slot (slot, pool) VALUES
  (1, 'developments/tower'),
  (2, 'developments/amenity'),
  (3, 'real-estate/living'),
  (4, 'developments/tower'),
  (5, 'real-estate/bedroom'),
  (6, 'real-estate/kitchen'),
  (7, 'developments/amenity'),
  (8, 'developments/tower');
-- @generated:end

-- -----------------------------------------------------------------------------
-- 1 · The media library's record of the listing photographs
-- -----------------------------------------------------------------------------
-- 050_media.sql derived one `media_assets` row per gallery photograph, and gave it the shape of
-- an agency upload: an S3 path, a camera-sized file, an invented photographer and licence. For
-- these files that is untrue — they are Unsplash stock photographs stored locally — and the admin
-- media library shows those fields, so they are set to what the files actually are.
UPDATE media_assets a
  JOIN _seed_file f ON f.path = a.url
   SET a.storage_disk     = 'local',
       a.storage_path     = SUBSTRING(a.url, 8),
       a.cdn_url          = NULL,
       a.file_size_bytes  = f.bytes,
       a.width            = 1280,
       a.height           = 853,
       a.aspect_ratio     = 1.50000,
       a.source           = 'stock',
       a.credit           = 'Photo: Unsplash',
       a.photographer     = NULL,
       a.copyright_holder = 'Unsplash contributor',
       a.license_id       = (SELECT id FROM media_licenses WHERE code = 'photographer-rf')
 WHERE a.source <> 'stock';

-- The renditions 050 generated name files on `renditions.livfinder.com`, which does not exist.
-- The upload flow hands a rendition out as an asset's thumbnail, so point them at the original.
UPDATE media_renditions r
  JOIN media_assets a ON a.id = r.media_asset_id
   SET r.url = a.url
 WHERE a.url LIKE '/media/seed/%'
   AND r.url NOT LIKE '/media/seed/%';

-- -----------------------------------------------------------------------------
-- 2 · Development galleries
-- -----------------------------------------------------------------------------
-- A development's gallery is the tower, its amenities and the homes inside it: 4–8 photographs
-- (4 + project id mod 5), cover first. Each project walks every set from its own starting point
-- (5 × project id, which shares no factor with the set sizes), so no gallery repeats a photograph
-- and neighbouring developments open on different towers. Development photographs come from
-- `media/developments/`; the interiors share the real-estate living-room, bedroom and kitchen sets.
--
-- A project that already has a gallery or cover attachment is left alone.
CREATE TABLE _seed_project_plan ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AS
SELECT p.id AS project_id, s.slot, s.pool,
       ROW_NUMBER() OVER (PARTITION BY p.id, s.pool ORDER BY s.slot) AS pool_rank
  FROM projects p
  JOIN _seed_project_slot s ON s.slot <= 4 + (p.id % 5)
 WHERE p.deleted_at IS NULL
   AND NOT EXISTS (
         SELECT 1 FROM media_attachments ma
          WHERE ma.attachable_type = 'project' AND ma.attachable_id = p.id
            AND ma.role IN ('gallery', 'cover')
       );

CREATE TABLE _seed_project_pick ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AS
SELECT pl.project_id, pl.slot, ranked.path, ranked.label,
       CONVERT(UPPER(LEFT(MD5(CONCAT('project_media:', pl.project_id, ':', pl.slot)), 26)) USING ascii) AS asset_public_id
  FROM _seed_project_plan pl
  JOIN (
        SELECT x.project_id, ph.pool, ph.path, ph.label,
               ROW_NUMBER() OVER (PARTITION BY x.project_id, ph.pool
                                  ORDER BY MOD(ph.idx + x.project_id * 5, sz.size)) AS pick_rank
          FROM (SELECT DISTINCT project_id, pool FROM _seed_project_plan) x
          JOIN _seed_project_photo ph ON ph.pool = x.pool
          JOIN (SELECT pool, COUNT(*) AS size FROM _seed_project_photo GROUP BY pool) sz ON sz.pool = ph.pool
       ) ranked
    ON ranked.project_id = pl.project_id AND ranked.pool = pl.pool AND ranked.pick_rank = pl.pool_rank;

INSERT INTO media_assets
  (public_id, folder_id, media_type, storage_disk, storage_path, url, cdn_url, file_name,
   original_file_name, mime_type, extension, file_size_bytes, width, height, color_space, has_alpha,
   orientation, is_animated, aspect_ratio, source, alt_text, credit, copyright_holder, license_id,
   scan_status, processing_status, reference_count, last_referenced_at, tier, created_at, updated_at)
SELECT k.asset_public_id,
       (SELECT id FROM media_folders WHERE path = '/projects'),
       'image', 'local', SUBSTRING(k.path, 8), k.path, NULL,
       SUBSTRING_INDEX(k.path, '/', -1), SUBSTRING_INDEX(k.path, '/', -1),
       'image/jpeg', 'jpg', f.bytes, 1280, 853, 'srgb', 0, 1, 0, 1.50000, 'stock',
       LEFT(CONCAT(p.name, ' — ', k.label), 255),
       'Photo: Unsplash', 'Unsplash contributor',
       (SELECT id FROM media_licenses WHERE code = 'photographer-rf'),
       'skipped', 'ready', 1, p.created_at, 'hot', p.created_at, p.created_at
  FROM _seed_project_pick k
  JOIN projects p ON p.id = k.project_id
  JOIN _seed_file f ON f.path = k.path;

INSERT INTO media_attachments
  (media_asset_id, attachable_type, attachable_id, role, sort_order, is_primary, created_at)
SELECT a.id, 'project', k.project_id, 'gallery', k.slot - 1, k.slot = 1, p.created_at
  FROM _seed_project_pick k
  JOIN projects p ON p.id = k.project_id
  JOIN media_assets a ON a.public_id = k.asset_public_id;

-- The card reads `cover_image_url`; keeping it the primary gallery image is what stops a card and
-- its detail page showing different photographs.
UPDATE projects p
  JOIN _seed_project_pick k ON k.project_id = p.id AND k.slot = 1
   SET p.cover_image_url = k.path,
       p.updated_at      = p.updated_at;

DROP TABLE IF EXISTS _seed_project_pick, _seed_project_plan, _seed_project_slot, _seed_project_photo, _seed_file;

-- -----------------------------------------------------------------------------
-- 3 · Developer logos
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
-- 4 · Agent portraits and company logos
-- -----------------------------------------------------------------------------
-- `users.avatar_url` and `organizations.logo_url` point at the same dead CDN, so every agent
-- renders as a generated initials circle and every company as a lettered box. A portrait has to
-- be of someone who agreed to it, and a logo belongs to the company it names, so only what the
-- project owns ships here:
--
--   db/seeds/media/avatars/01.jpg …   →  @avatar_count
--   db/seeds/media/logos/01.svg …     →  @logo_count
--
-- Two portraits ship today — the AI-generated headshots the project already used as agent
-- avatars, so nobody's likeness is being published. Two is thin for 127 agents: the same faces
-- repeat. Adding files to `db/seeds/media/avatars/` and raising the count is the whole fix.
SET @avatar_count = 2;
-- One logo, worn by every agency and developer. These companies are demo records: most are
-- invented, and the few with real-sounding names are not the real firms, so one designed emblem
-- used everywhere is honest about that — it says "an agency" rather than pretending to identify
-- one. Add more files and raise the count to give companies distinct marks.
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

-- Both projections carry their own copy of the cover (and the project one the first gallery
-- URLs), so neither shows the photographs until it is rebuilt. NULL rebuilds every row.
-- `gallery_urls` is a GROUP_CONCAT, which the default 1024-byte limit would cut mid-URL.
SET SESSION group_concat_max_len = 8192;
CALL sp_refresh_listing_search(NULL);
CALL sp_refresh_project_search(NULL);
