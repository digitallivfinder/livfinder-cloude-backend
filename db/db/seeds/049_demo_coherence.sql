-- =============================================================================
-- Liv Finder — demo seed · make each listing agree with itself
-- =============================================================================
-- 042_demo_listings.sql picked a listing's subcategory, its make and model, and its copy
-- independently of each other, so the demo catalogue was full of listings that contradicted
-- themselves: a Ferrari LaFerrari filed under Off-road, a Pilatus PC-12 turboprop under Heavy
-- jets, a "7 Bedroom Office with Private Pool", a "176ft Sunseeker Manhattan 68". With galleries
-- now chosen by subcategory (049_demo_gallery.sql) the mismatch would show in the photographs
-- too, so this runs first and puts each listing in the subcategory its model actually belongs to.
--
--   1. Cars, yachts, jets, helicopters and watches are filed by make and model.
--      The detail rows follow: aircraft type, vessel type, body style.
--   2. A yacht whose model names its length (Manhattan 68, Grande 35M) is given that length.
--   3. Titles that repeat the maker ("Bell Bell 505") lose the repeat.
--   4. Offices, retail units and plots get titles, descriptions and features of their own kind
--      instead of a villa's bedrooms, kitchen and private pool.
--   5. Every copy of a changed title follows it (translations, enquiry subjects, SEO fields).
--   6. Canonical paths are rewritten to the marketplace URL contract the website routes on.
--   7. Live listings' end dates are measured from the day of the load.
--   8. Live listings a development plausibly contains are filed inside it.
--
-- Slugs are left alone: a title change does not move a listing's address.
--
-- Runs after 043–048, so the rows those files copied a listing's subcategory or title into
-- (enquiries, daily statistics, featured placements, translations) are brought along here.
-- =============================================================================

SET NAMES utf8mb4;

DROP TABLE IF EXISTS _seed_retitle, _seed_recategorised, _seed_model_category;

CREATE TABLE _seed_model_category (
  root_category_id INT UNSIGNED     NOT NULL,
  brand_slug       VARCHAR(160)     NOT NULL,
  model_slug       VARCHAR(180)     NOT NULL,   -- '-' for a listing with a make but no model
  category_code    VARCHAR(60)      NOT NULL,
  length_ft        SMALLINT UNSIGNED NULL,      -- yachts whose model names its length
  PRIMARY KEY (root_category_id, brand_slug, model_slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO _seed_model_category (root_category_id, brand_slug, model_slug, category_code, length_ft) VALUES
  -- Cars
  (2, 'aston-martin', 'dbs', 'grand-tourer', NULL),
  (2, 'aston-martin', 'dbx707', 'luxury-suv', NULL),
  (2, 'aston-martin', 'valkyrie', 'hypercar', NULL),
  (2, 'aston-martin', 'vantage', 'coupe', NULL),
  (2, 'audi', 'rs-e-tron-gt', 'electric-car', NULL),
  (2, 'audi', 'rs6-avant', 'luxury-sedan', NULL),
  (2, 'bentley', 'continental-gt', 'grand-tourer', NULL),
  (2, 'bentley', 'flying-spur', 'luxury-sedan', NULL),
  (2, 'bmw', 'i7', 'electric-car', NULL),
  (2, 'bmw', 'm8-competition', 'coupe', NULL),
  (2, 'bmw', 'xm', 'luxury-suv', NULL),
  (2, 'bugatti', 'chiron', 'hypercar', NULL),
  (2, 'bugatti', 'tourbillon', 'hypercar', NULL),
  (2, 'bugatti', 'veyron', 'hypercar', NULL),
  (2, 'cadillac', '-', 'luxury-suv', NULL),
  (2, 'ferrari', '12cilindri', 'grand-tourer', NULL),
  (2, 'ferrari', 'f8-tributo', 'supercar', NULL),
  (2, 'ferrari', 'laferrari', 'hypercar', NULL),
  (2, 'jaguar', '-', 'convertible', NULL),
  (2, 'koenigsegg', 'gemera', 'hypercar', NULL),
  (2, 'lamborghini', 'aventador', 'supercar', NULL),
  (2, 'lamborghini', 'urus', 'luxury-suv', NULL),
  (2, 'land-rover', '-', 'off-road', NULL),
  (2, 'lexus', '-', 'luxury-sedan', NULL),
  (2, 'lotus', 'emira', 'coupe', NULL),
  (2, 'lucid', 'air-sapphire', 'electric-car', NULL),
  (2, 'maserati', 'grecale', 'luxury-suv', NULL),
  (2, 'maserati', 'mc20', 'supercar', NULL),
  (2, 'mclaren', 'artura', 'supercar', NULL),
  (2, 'mclaren', 'senna', 'hypercar', NULL),
  (2, 'mercedes-amg', 'gt-63-s-e-performance', 'grand-tourer', NULL),
  (2, 'mercedes-benz', 'maybach-s680', 'luxury-sedan', NULL),
  (2, 'mercedes-benz', 's-class', 'luxury-sedan', NULL),
  (2, 'mercedes-benz', 'sl-63', 'convertible', NULL),
  (2, 'pagani', 'huayra', 'hypercar', NULL),
  (2, 'pagani', 'utopia', 'hypercar', NULL),
  (2, 'porsche', '911-gt3-rs', 'supercar', NULL),
  (2, 'porsche', '911-turbo-s', 'supercar', NULL),
  (2, 'porsche', '918-spyder', 'hypercar', NULL),
  (2, 'range-rover', 'range-rover-sv', 'off-road', NULL),
  (2, 'rimac', 'nevera', 'electric-car', NULL),
  (2, 'rolls-royce', 'phantom', 'luxury-sedan', NULL),
  (2, 'tesla', '-', 'electric-car', NULL),
  -- Yachts
  (3, 'amels', '-', 'superyacht', NULL),
  (3, 'azimut', 'grande-27m', 'motor-yacht', 89),
  (3, 'azimut', 'grande-35m', 'motor-yacht', 115),
  (3, 'baglietto', '-', 'superyacht', NULL),
  (3, 'benetti', 'b-yond-37m', 'explorer', 121),
  (3, 'crn', '-', 'mega-yacht', NULL),
  (3, 'damen-yachting', '-', 'explorer', NULL),
  (3, 'feadship', '-', 'mega-yacht', NULL),
  (3, 'ferretti-yachts', '860', 'motor-yacht', 86),
  (3, 'ferretti-yachts', 'infynito-90', 'motor-yacht', 90),
  (3, 'gulf-craft', '-', 'superyacht', NULL),
  (3, 'heesen-yachts', 'project-aquamarine', 'superyacht', 164),
  (3, 'lagoon', 'lagoon-65', 'catamaran', 65),
  (3, 'lagoon', 'seventy-8', 'catamaran', 78),
  (3, 'lurssen', '-', 'mega-yacht', NULL),
  (3, 'majesty-yachts', 'majesty-120', 'motor-yacht', 120),
  (3, 'nautor-swan', '-', 'sailing-yacht', NULL),
  (3, 'perini-navi', '-', 'sailing-yacht', NULL),
  (3, 'pershing', '140', 'motor-yacht', 140),
  (3, 'pershing', '9x', 'motor-yacht', 92),
  (3, 'princess-yachts', 'y85', 'motor-yacht', 85),
  (3, 'riva', 'argo-90', 'motor-yacht', 90),
  (3, 'sanlorenzo', 'sd118', 'motor-yacht', 118),
  (3, 'sanlorenzo', 'sl120a', 'motor-yacht', 120),
  (3, 'sunreef-yachts', '100-power', 'catamaran', 100),
  (3, 'sunreef-yachts', '80-eco', 'catamaran', 80),
  (3, 'sunseeker', '95-yacht', 'motor-yacht', 95),
  (3, 'sunseeker', 'manhattan-68', 'motor-yacht', 68),
  (3, 'sunseeker', 'ocean-182', 'superyacht', 182),
  (3, 'sunseeker', 'predator-74', 'motor-yacht', 74),
  (3, 'wally', '-', 'sailing-yacht', NULL),
  -- Jets
  (4, 'airbus-corporate-jets', 'acj320neo', 'vip-airliner', NULL),
  (4, 'boeing-business-jets', 'bbj-737-max', 'vip-airliner', NULL),
  (4, 'bombardier', 'challenger-350', 'super-midsize-jet', NULL),
  (4, 'cessna', 'citation-longitude', 'super-midsize-jet', NULL),
  (4, 'cessna', 'citation-xls-plus', 'midsize-jet', NULL),
  (4, 'dassault-falcon', 'falcon-6x', 'heavy-jet', NULL),
  (4, 'dassault-falcon', 'falcon-7x', 'heavy-jet', NULL),
  (4, 'dassault-falcon', 'falcon-8x', 'ultra-long-range', NULL),
  (4, 'embraer', 'legacy-500', 'midsize-jet', NULL),
  (4, 'embraer', 'praetor-600', 'super-midsize-jet', NULL),
  (4, 'gulfstream', 'g280', 'super-midsize-jet', NULL),
  (4, 'gulfstream', 'g600', 'heavy-jet', NULL),
  (4, 'gulfstream', 'g800', 'ultra-long-range', NULL),
  (4, 'honda-aircraft', 'hondajet-elite-ii', 'light-jet', NULL),
  (4, 'pilatus', 'pc-12-ngx', 'turboprop', NULL),
  (4, 'pilatus', 'pc-24', 'light-jet', NULL),
  -- Helicopters
  (5, 'airbus-helicopters', 'ach145', 'vip-helicopter', NULL),
  (5, 'airbus-helicopters', 'ach160', 'vip-helicopter', NULL),
  (5, 'airbus-helicopters', 'h175', 'heavy-helicopter', NULL),
  (5, 'bell', 'bell-429', 'light-helicopter', NULL),
  (5, 'bell', 'bell-505', 'light-helicopter', NULL),
  (5, 'leonardo-helicopters', 'aw109-grandnew', 'light-helicopter', NULL),
  (5, 'leonardo-helicopters', 'aw139', 'medium-helicopter', NULL),
  (5, 'leonardo-helicopters', 'aw169', 'medium-helicopter', NULL),
  (5, 'robinson-helicopter', 'r66-turbine', 'light-helicopter', NULL),
  (5, 'sikorsky', 's-76d', 'medium-helicopter', NULL),
  -- Watches
  (6, 'a-lange-sohne', 'lange-1', 'dress-watch', NULL),
  (6, 'blancpain', '-', 'dive-watch', NULL),
  (6, 'breguet', '-', 'complication', NULL),
  (6, 'bvlgari', 'octo-finissimo', 'dress-watch', NULL),
  (6, 'chopard', '-', 'ladies-watch', NULL),
  (6, 'fp-journe', 'chronometre-bleu', 'dress-watch', NULL),
  (6, 'grand-seiko', 'snowflake', 'dress-watch', NULL),
  (6, 'greubel-forsey', '-', 'complication', NULL),
  (6, 'h-moser-cie', '-', 'dress-watch', NULL),
  (6, 'hublot', 'big-bang', 'chronograph', NULL),
  (6, 'hublot', 'classic-fusion', 'sports-watch', NULL),
  (6, 'iwc-schaffhausen', 'big-pilot', 'sports-watch', NULL),
  (6, 'iwc-schaffhausen', 'portugieser', 'chronograph', NULL),
  (6, 'mb-and-f', 'legacy-machine', 'complication', NULL),
  (6, 'omega', 'seamaster-300', 'dive-watch', NULL),
  (6, 'omega', 'speedmaster', 'chronograph', NULL),
  (6, 'panerai', 'luminor', 'sports-watch', NULL),
  (6, 'panerai', 'submersible', 'dive-watch', NULL),
  (6, 'parmigiani-fleurier', '-', 'sports-watch', NULL),
  (6, 'piaget', '-', 'ladies-watch', NULL),
  (6, 'richard-mille', 'rm-011', 'chronograph', NULL),
  (6, 'richard-mille', 'rm-035', 'sports-watch', NULL),
  (6, 'richard-mille', 'rm-67-02', 'sports-watch', NULL),
  (6, 'roger-dubuis', '-', 'complication', NULL),
  (6, 'rolex', 'gmt-master-ii', 'gmt-worldtimer', NULL),
  (6, 'tag-heuer', '-', 'chronograph', NULL),
  (6, 'vacheron-constantin', 'overseas', 'sports-watch', NULL),
  (6, 'vacheron-constantin', 'patrimony', 'dress-watch', NULL),
  (6, 'zenith', '-', 'vintage-watch', NULL);

-- -----------------------------------------------------------------------------
-- 1 · Subcategory from make and model
-- -----------------------------------------------------------------------------
-- A make-only car whose title says "Convertible" is a convertible whatever the make's default.
CREATE TABLE _seed_recategorised ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AS
SELECT l.id AS listing_id, l.category_id AS old_category_id, target.id AS new_category_id,
       m.length_ft
  FROM listings l
  JOIN brands b ON b.id = l.brand_id
  LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
  JOIN _seed_model_category m
    ON m.root_category_id = l.root_category_id
   AND m.brand_slug = CONVERT(b.slug USING utf8mb4) COLLATE utf8mb4_unicode_ci
   AND m.model_slug = COALESCE(CONVERT(bm.slug USING utf8mb4) COLLATE utf8mb4_unicode_ci, '-')
  JOIN categories target
    ON target.code = CASE WHEN l.root_category_id = 2 AND l.brand_model_id IS NULL
                               AND l.title LIKE '%Convertible%' THEN 'convertible'
                          ELSE m.category_code END
   AND target.root_category_id = l.root_category_id;

ALTER TABLE _seed_recategorised ADD PRIMARY KEY (listing_id);

UPDATE listings l
  JOIN _seed_recategorised r ON r.listing_id = l.id
   SET l.category_id = r.new_category_id,
       l.updated_at  = l.updated_at
 WHERE l.category_id <> r.new_category_id;

-- Rows 043–046 wrote with the listing's subcategory in them.
UPDATE inquiries i
  JOIN _seed_recategorised r ON r.listing_id = i.listing_id
   SET i.category_id = r.new_category_id
 WHERE i.category_id = r.old_category_id;

UPDATE listing_daily_stats s
  JOIN _seed_recategorised r ON r.listing_id = s.listing_id
   SET s.category_id = r.new_category_id
 WHERE s.category_id = r.old_category_id;

UPDATE featured_placements f
  JOIN _seed_recategorised r ON r.listing_id = f.listing_id
   SET f.category_id = r.new_category_id
 WHERE f.category_id = r.old_category_id;

-- The detail rows describe the same thing the subcategory does.
UPDATE listing_aviation a
  JOIN listings l ON l.id = a.listing_id
  JOIN categories c ON c.id = l.category_id
   SET a.aircraft_type = CASE c.code
         WHEN 'light-jet'         THEN 'light_jet'
         WHEN 'midsize-jet'       THEN 'midsize_jet'
         WHEN 'super-midsize-jet' THEN 'super_midsize_jet'
         WHEN 'heavy-jet'         THEN 'heavy_jet'
         WHEN 'ultra-long-range'  THEN 'ultra_long_range'
         WHEN 'vip-airliner'      THEN 'vip_airliner'
         WHEN 'turboprop'         THEN 'turboprop'
         WHEN 'light-helicopter'  THEN 'light_helicopter'
         WHEN 'medium-helicopter' THEN 'medium_helicopter'
         WHEN 'vip-helicopter'    THEN 'medium_helicopter'
         WHEN 'heavy-helicopter'  THEN 'heavy_helicopter'
         ELSE a.aircraft_type END;

UPDATE listing_marine m
  JOIN listings l ON l.id = m.listing_id
  JOIN categories c ON c.id = l.category_id
   SET m.vessel_type = CASE c.code
         WHEN 'motor-yacht'   THEN 'motor_yacht'
         WHEN 'superyacht'    THEN 'superyacht'
         WHEN 'mega-yacht'    THEN 'mega_yacht'
         WHEN 'explorer'      THEN 'explorer'
         WHEN 'sailing-yacht' THEN 'sailing_yacht'
         WHEN 'catamaran'     THEN 'catamaran'
         WHEN 'sport-fisher'  THEN 'sport_fisher'
         WHEN 'classic-yacht' THEN 'classic'
         ELSE m.vessel_type END;

UPDATE listing_vehicle v
  JOIN listings l ON l.id = v.listing_id
  JOIN categories c ON c.id = l.category_id
  LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
   SET v.body_type = CASE
         WHEN c.code = 'convertible'                 THEN 'Convertible'
         WHEN c.code IN ('luxury-suv', 'off-road')   THEN 'SUV'
         WHEN bm.body_type IS NOT NULL               THEN bm.body_type
         ELSE v.body_type END;

-- -----------------------------------------------------------------------------
-- 2 · Yacht length from the model
-- -----------------------------------------------------------------------------
UPDATE listing_marine m
  JOIN _seed_recategorised r ON r.listing_id = m.listing_id
   SET m.length_overall_ft = r.length_ft,
       m.length_overall_m  = ROUND(r.length_ft * 0.3048, 2)
 WHERE r.length_ft IS NOT NULL;

-- -----------------------------------------------------------------------------
-- 3 · New titles, collected so every copy of the old one can follow
-- -----------------------------------------------------------------------------
CREATE TABLE _seed_retitle (
  listing_id      BIGINT UNSIGNED NOT NULL PRIMARY KEY,
  old_title       VARCHAR(255)    NOT NULL,
  new_title       VARCHAR(255)    NOT NULL,
  new_description TEXT            NULL      -- NULL: keep the description, swapping the title in it
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO _seed_retitle (listing_id, old_title, new_title)
SELECT l.id, l.title, REGEXP_REPLACE(l.title, '[0-9]+ft', CONCAT(r.length_ft, 'ft'))
  FROM listings l
  JOIN _seed_recategorised r ON r.listing_id = l.id
 WHERE r.length_ft IS NOT NULL
   AND l.title REGEXP '[0-9]+ft';

-- A model named after its maker ("Bell 505", "Range Rover SV", "Falcon 8X" by Dassault Falcon)
-- was printed after the maker's name as well. Say the maker once.
INSERT INTO _seed_retitle (listing_id, old_title, new_title)
SELECT l.id, l.title,
       REPLACE(l.title, CONCAT(b.name, ' ', bm.name),
               CASE WHEN bm.name LIKE CONCAT(b.name, ' %') THEN bm.name
                    ELSE CONCAT(b.name, SUBSTRING(bm.name, CHAR_LENGTH(SUBSTRING_INDEX(b.name, ' ', -1)) + 1)) END)
  FROM listings l
  JOIN brands b ON b.id = l.brand_id
  JOIN brand_models bm ON bm.id = l.brand_model_id
 WHERE l.title LIKE CONCAT('%', b.name, ' ', bm.name, '%')
   AND (bm.name LIKE CONCAT(b.name, ' %')
        OR bm.name LIKE CONCAT(SUBSTRING_INDEX(b.name, ' ', -1), ' %'))
   AND NOT EXISTS (SELECT 1 FROM _seed_retitle t WHERE t.listing_id = l.id);

-- A yacht retitled for its length above may also repeat its builder; fold that in too.
UPDATE _seed_retitle t
  JOIN listings l ON l.id = t.listing_id
  JOIN brands b ON b.id = l.brand_id
  JOIN brand_models bm ON bm.id = l.brand_model_id
   SET t.new_title = REPLACE(t.new_title, CONCAT(b.name, ' ', bm.name), bm.name)
 WHERE bm.name LIKE CONCAT(b.name, ' %');

-- -----------------------------------------------------------------------------
-- 4 · Offices, retail units and plots
-- -----------------------------------------------------------------------------
-- The subtitle is "<community>, <city>".
INSERT INTO _seed_retitle (listing_id, old_title, new_title, new_description)
SELECT l.id, l.title,
       CASE c.code
         WHEN 'office' THEN CONCAT(
           ELT(1 + l.id % 5, 'Grade A', 'Prime', 'Fitted', 'Full-Floor', 'Corner'),
           ' Office in ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', 1)),
           ELT(1 + (l.id DIV 5) % 5, ' with Skyline Views', ' with Sea Views', ' with Private Parking', '', ' with Terrace'))
         WHEN 'retail' THEN CONCAT(
           ELT(1 + l.id % 5, 'Prime', 'High-Street', 'Corner', 'Double-Height', 'Flagship'),
           ' Retail Unit in ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', 1)),
           ELT(1 + (l.id DIV 5) % 5, ' with Street Frontage', '', ' Near the Waterfront', ' with Terrace', ' with Parking'))
         ELSE CONCAT(
           ELT(1 + l.id % 5, 'Freehold', 'Residential', 'Waterfront', 'Villa', 'Hillside'),
           ' Plot in ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', 1)),
           ELT(1 + (l.id DIV 5) % 5, ' with Sea Views', '', ' with Approved Plans', ' Ready to Build', ' with Golf Views'))
       END,
       CASE c.code
         WHEN 'office' THEN CONCAT(
           'This ', COALESCE(CONCAT(FORMAT(re.built_area_sqft, 0), ' sq ft '), ''),
           'office in ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', 1)), ', ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', -1)),
           ' offers an open, column-free floor plate with full-height glazing, raised floors and a fitted reception. ',
           'The building has 24-hour access, a staffed lobby and allocated parking.  ',
           TRIM(SUBSTRING_INDEX(l.subtitle, ',', 1)), ' is one of the most established business addresses in ',
           TRIM(SUBSTRING_INDEX(l.subtitle, ',', -1)), ', with transport links, hotels and restaurants close at hand. ',
           'Viewing is strictly by appointment.')
         WHEN 'retail' THEN CONCAT(
           'This ', COALESCE(CONCAT(FORMAT(re.built_area_sqft, 0), ' sq ft '), ''),
           'retail unit in ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', 1)), ', ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', -1)),
           ' has a glazed frontage onto a busy pedestrian route, generous ceiling heights and a rear service entrance. ',
           'It suits a boutique, gallery, showroom or flagship concept, fitted out to the tenant''s own design.  ',
           'Footfall in ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', 1)), ' is among the strongest in ',
           TRIM(SUBSTRING_INDEX(l.subtitle, ',', -1)), '. Viewing is strictly by appointment.')
         ELSE CONCAT(
           'This ', COALESCE(CONCAT(FORMAT(re.plot_area_sqft, 0), ' sq ft '), ''),
           'plot in ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', 1)), ', ', TRIM(SUBSTRING_INDEX(l.subtitle, ',', -1)),
           ' is level and serviced, with utilities at the boundary, and is zoned for residential development — ',
           'a rare chance to build a private residence to your own design.  ',
           TRIM(SUBSTRING_INDEX(l.subtitle, ',', 1)), ' is one of the most sought-after addresses in ',
           TRIM(SUBSTRING_INDEX(l.subtitle, ',', -1)), '. Site plans and planning guidance are available on request, ',
           'and viewing is strictly by appointment.')
       END
  FROM listings l
  JOIN categories c ON c.id = l.category_id AND c.code IN ('office', 'retail', 'plot')
  LEFT JOIN listing_real_estate re ON re.listing_id = l.id
 WHERE l.subtitle LIKE '%,%';

-- Nobody sleeps in an office, a shop or a field.
UPDATE listing_real_estate re
  JOIN listings l ON l.id = re.listing_id
  JOIN categories c ON c.id = l.category_id
   SET re.bedrooms = NULL
 WHERE c.code IN ('office', 'retail', 'plot');

UPDATE listing_real_estate re
  JOIN listings l ON l.id = re.listing_id
  JOIN categories c ON c.id = l.category_id AND c.code = 'plot'
   SET re.bathrooms = NULL, re.floor_number = NULL, re.total_floors = NULL,
       re.parking_spaces = NULL, re.furnishing = NULL;

UPDATE listings l
  JOIN categories c ON c.id = l.category_id
   SET l.attributes = CASE c.code
         WHEN 'plot' THEN JSON_REMOVE(l.attributes, '$.kitchen', '$.flooring', '$.balcony_count', '$.chiller')
         ELSE JSON_REMOVE(l.attributes, '$.kitchen', '$.balcony_count') END,
       l.updated_at = l.updated_at
 WHERE c.code IN ('office', 'retail', 'plot')
   AND l.attributes IS NOT NULL;

-- Features: keep only what can be true of the land or the building — views, location,
-- building services. A maid's room, a home cinema or a private pool cannot.
DELETE lf
  FROM listing_features lf
  JOIN listings l ON l.id = lf.listing_id
  JOIN categories c ON c.id = l.category_id AND c.code IN ('office', 'retail', 'plot')
  JOIN features f ON f.id = lf.feature_id
 WHERE f.name NOT IN ('Sea view', 'Marina view', 'Park view', 'City view', 'Vineyard view',
                      'Mountain view', 'Golf course view', 'Burj Khalifa view', 'Beachfront',
                      'Golf course access', 'Gated community')
   AND (c.code = 'plot'
        OR f.name NOT IN ('Concierge', 'Valet parking', 'CCTV', 'Retail on site', 'Shared gym',
                          'Solar panels', 'Greywater recycling', 'Private lift'));

-- Car titles carry a body style chosen for the subcategory 042 picked at random: a "Lucid Air
-- Sapphire Convertible", a "Maserati Grecale Coupé". A title keeps "Convertible" only when the
-- car is filed as a convertible, and "Coupé" only when the model is one.
UPDATE _seed_retitle t
  JOIN listings l ON l.id = t.listing_id AND l.root_category_id = 2
  JOIN categories c ON c.id = l.category_id
  LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
   SET t.new_title = REPLACE(REPLACE(t.new_title,
         IF(c.code <> 'convertible', ' Convertible', CHAR(0)), ''),
         IF(COALESCE(bm.body_type, '') <> 'Coupé', ' Coupé', CHAR(0)), '');

INSERT INTO _seed_retitle (listing_id, old_title, new_title)
SELECT l.id, l.title,
       REPLACE(REPLACE(l.title,
         IF(c.code <> 'convertible', ' Convertible', CHAR(0)), ''),
         IF(COALESCE(bm.body_type, '') <> 'Coupé', ' Coupé', CHAR(0)), '')
  FROM listings l
  JOIN categories c ON c.id = l.category_id
  LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
 WHERE l.root_category_id = 2
   AND ((l.title LIKE '% Convertible%' AND c.code <> 'convertible')
        OR (l.title LIKE '% Coupé%' AND COALESCE(bm.body_type, '') <> 'Coupé'))
   AND NOT EXISTS (SELECT 1 FROM _seed_retitle t WHERE t.listing_id = l.id);

-- -----------------------------------------------------------------------------
-- 5 · Apply the new titles everywhere the old one was copied
-- -----------------------------------------------------------------------------
UPDATE listings l
  JOIN _seed_retitle t ON t.listing_id = l.id
   SET l.title           = t.new_title,
       l.description     = COALESCE(t.new_description, REPLACE(l.description, t.old_title, t.new_title)),
       l.seo_title       = LEFT(CONCAT(t.new_title, ' | Liv Finder'), 255),
       l.seo_description = REPLACE(l.seo_description, t.old_title, t.new_title),
       l.cover_image_alt = REPLACE(l.cover_image_alt, t.old_title, t.new_title),
       l.updated_at      = l.updated_at;

UPDATE listing_translations lt
  JOIN _seed_retitle t ON t.listing_id = lt.listing_id
   SET lt.title = t.new_title
 WHERE lt.title = t.old_title;

UPDATE inquiries i
  JOIN _seed_retitle t ON t.listing_id = i.listing_id
   SET i.subject = REPLACE(i.subject, t.old_title, t.new_title)
 WHERE i.subject LIKE CONCAT('%', t.old_title, '%');

-- -----------------------------------------------------------------------------
-- 6 · Addresses in the marketplace URL contract
-- -----------------------------------------------------------------------------
-- 042 writes `/{category}/{purpose}/{iso}/{city}/…/{slug}`. The website routes — and
-- `src/utils/canonicalPath.js`, which writes this column for every listing created through the
-- API — use the marketplace contract instead, so a seeded listing opened from its own card was
-- "unavailable" until `scripts/backfill-canonical-paths.js` had been run by hand:
--
--   real-estate  /real-estate/{country}/{state}/{city}/{community}/{subcommunity}/{slug}
--   cars, yachts, jets, helicopters   /{category}/{make}/{model}/{year}/{slug}
--   watches      /watches/{brand}/{collection}/{slug}
--
-- Segments stop at the first level a listing does not have. Done here, before 051_seo.sql and
-- the search seeds copy the path into url_inventory, sitemaps and the projection.
CREATE TABLE _seed_path ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci AS
SELECT id AS listing_id, canonical_path AS old_path FROM listings;

ALTER TABLE _seed_path ADD PRIMARY KEY (listing_id);

UPDATE listings l
  LEFT JOIN locations co ON co.id = l.country_id
  LEFT JOIN locations st ON st.id = l.state_id
  LEFT JOIN locations ct ON ct.id = l.city_id
  LEFT JOIN locations cm ON cm.id = l.community_id
  LEFT JOIN locations sc ON sc.id = l.sub_community_id
  LEFT JOIN brands br ON br.id = l.brand_id
  LEFT JOIN brand_models bm ON bm.id = l.brand_model_id
  LEFT JOIN listing_vehicle veh ON veh.listing_id = l.id
  LEFT JOIN listing_marine mar ON mar.listing_id = l.id
  LEFT JOIN listing_aviation av ON av.listing_id = l.id
   SET l.canonical_path = CASE l.root_category_id
         WHEN 1 THEN CONCAT('/real-estate',
                IF(co.slug IS NULL, '', CONCAT('/', co.slug,
                IF(st.slug IS NULL, '', CONCAT('/', st.slug,
                IF(ct.slug IS NULL, '', CONCAT('/', ct.slug,
                IF(cm.slug IS NULL, '', CONCAT('/', cm.slug,
                IF(sc.slug IS NULL, '', CONCAT('/', sc.slug)))))))))),
                '/', l.slug)
         WHEN 6 THEN CONCAT('/watches',
                IF(br.slug IS NULL, '', CONCAT('/', br.slug,
                IF(bm.slug IS NULL, '', CONCAT('/', bm.slug)))),
                '/', l.slug)
         ELSE CONCAT('/', ELT(l.root_category_id - 1, 'cars', 'yachts', 'jets', 'helicopters'),
                IF(br.slug IS NULL, '', CONCAT('/', br.slug,
                IF(bm.slug IS NULL, '', CONCAT('/', bm.slug,
                IF(COALESCE(veh.model_year, mar.build_year, av.year_built) IS NULL, '',
                   CONCAT('/', COALESCE(veh.model_year, mar.build_year, av.year_built))))))),
                '/', l.slug)
       END,
       l.updated_at = l.updated_at
 WHERE l.root_category_id BETWEEN 1 AND 6;

-- An enquiry records the page it was sent from.
UPDATE inquiries i
  JOIN _seed_path p ON p.listing_id = i.listing_id
  JOIN listings l ON l.id = i.listing_id
   SET i.source_url = REPLACE(i.source_url, p.old_path, l.canonical_path)
 WHERE i.source_url LIKE CONCAT('%', p.old_path, '%');

-- -----------------------------------------------------------------------------
-- 7 · End dates measured from the day of the load
-- -----------------------------------------------------------------------------
-- 042 fixed every live listing's end date between September and November 2026. Loaded any later,
-- the in-process expiry sweep (listings.jobs.js) takes a large share of the catalogue off the
-- website within days — on the test server the demo would empty itself. A live listing now runs
-- three to nine months from the load, except one in twenty, which ends within a fortnight so the
-- "expiring soon" views in the portal and admin still have something to show.
UPDATE listings
   SET expires_at = TIMESTAMP(
         DATE_ADD(CURDATE(), INTERVAL IF(id % 20 = 0, 3 + id % 12, 90 + id % 180) DAY), '09:00:00'),
       updated_at = updated_at
 WHERE status = 'active'
   AND deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- 8 · Listings inside a development
-- -----------------------------------------------------------------------------
-- A development page lists the units for sale in it. The demo listings name none, so every
-- page said "no units". A listing is filed inside a development only where that is plausible:
-- the same community, and a unit a tower actually contains — an apartment, penthouse, duplex,
-- hotel apartment, or the office and retail space on its podium. Its building is then the
-- development and its developer the development's. Runs after the unit-type seeds, so each
-- development's price list stays its own.
UPDATE listings l
  JOIN categories c ON c.id = l.category_id
   AND c.code IN ('apartment', 'penthouse', 'duplex', 'hotel-apartment', 'office', 'retail')
  JOIN projects p ON p.community_id = l.community_id
   AND p.deleted_at IS NULL AND p.moderation_status = 'published'
   SET l.project_id = p.id,
       l.updated_at = l.updated_at
 WHERE l.root_category_id = 1
   AND l.project_id IS NULL
   AND l.deleted_at IS NULL
   AND l.community_id IS NOT NULL
   -- Only units actually on the market: an expired or sold listing would sit on the development
   -- page as a unit nobody can enquire about.
   AND l.status = 'active'
   AND (l.expires_at IS NULL OR l.expires_at > NOW());

UPDATE listing_real_estate re
  JOIN listings l ON l.id = re.listing_id
  JOIN projects p ON p.id = l.project_id
   SET re.building_name      = p.name,
       re.developer_brand_id = COALESCE(re.developer_brand_id, p.developer_brand_id);

DROP TABLE IF EXISTS _seed_path, _seed_retitle, _seed_recategorised, _seed_model_category;
