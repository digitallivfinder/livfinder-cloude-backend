-- =============================================================================
-- 0083_property_finder_types_amenities.sql
--
-- Real estate property types and amenities follow Property Finder's lists exactly, for Buy,
-- Rent and New Launch (developments). Owner decision, 2026-11-23.
--
-- 1. categories.offered_for  JSON, NULL = every purpose in every segment the type belongs to.
--      Set only where PF narrows a type: {"residential": ["sale"], "commercial": ["sale","rent"]}.
-- 2. The 25 PF types. One-to-one renames keep their id (Plot → Land, Office → Office Space,
--    Showroom → Show Room, Labour Camp → Labor Camp, Bulk Units → Bulk Sale Unit, Commercial
--    Floor → Full Floor, Hotel Apartment → Hotel & Hotel Apartment); Villa also becomes
--    commercial. New: Compound, Half Floor, Bulk Rent Unit, Bungalow, Staff Accommodation,
--    Business Centre, Co-working space, Farm.
-- 3. Types PF does not have are retired after their listings move:
--      Mansion, Estate, Chalet → Villa; Private Island, Vineyard → Land (for sale) or Villa
--      (for rent: PF offers no residential Land to rent); Industrial Land → Land.
--      Residential Land listed for rent → Commercial (PF offers Land to rent only there).
-- 4. Amenities: PF's 23, in one "Amenities" group, for real estate and developments. Close
--    matches are merged first (Terrace → Balcony, Spa/Sauna/Steam → Shared Spa, sea / marina /
--    lake / beachfront views → View of Water, Burj Khalifa view → View of Landmark …); every other
--    real-estate amenity is removed from the catalogue and from listings. The views are shared
--    with yachts, so those stay in the catalogue for yachts. Commercial listings keep none (PF has
--    no amenities for commercial property).
-- 5. Developments: unit types are PF's five (Studio and the rest → Apartment); project amenities
--    are renamed to PF's names, the rest dropped; the 30 development-only features are removed.
-- 6. The search projections and counters follow.
--
-- Runs after the seeds on a fresh load (tools/load.sh). Safe to run more than once.
-- =============================================================================

SET NAMES utf8mb4;

SET @lf_re  = (SELECT id FROM categories WHERE code = 'real-estate' AND parent_id IS NULL LIMIT 1);
SET @lf_dev = (SELECT id FROM categories WHERE code = 'real-estate-developments' AND parent_id IS NULL LIMIT 1);
SET @lf_sale = (SELECT id FROM purposes WHERE code = 'sale' LIMIT 1);
SET @lf_rent = (SELECT id FROM purposes WHERE code = 'rent' LIMIT 1);

-- -----------------------------------------------------------------------------
-- 1. categories.offered_for
-- -----------------------------------------------------------------------------
SET @lf_has_col = (
  SELECT COUNT(*) FROM information_schema.columns
   WHERE table_schema = DATABASE() AND table_name = 'categories' AND column_name = 'offered_for'
);
SET @lf_sql = IF(@lf_has_col = 0,
  'ALTER TABLE categories ADD COLUMN offered_for JSON NULL DEFAULT NULL AFTER property_segment', 'DO 0');
PREPARE lf_stmt FROM @lf_sql; EXECUTE lf_stmt; DEALLOCATE PREPARE lf_stmt;

-- -----------------------------------------------------------------------------
-- 2. The 25 Property Finder types
-- -----------------------------------------------------------------------------
-- Renames in place, matched on the old or the new code so a re-run finds them.
UPDATE categories SET code = 'apartment', slug = 'apartments', name = 'Apartment', name_plural = 'Apartments',
       path = 'real-estate/apartments', property_segment = 'residential', offered_for = NULL, sort_order = 1
 WHERE root_category_id = @lf_re AND code = 'apartment';
UPDATE categories SET name = 'Villa', name_plural = 'Villas', property_segment = 'both', offered_for = NULL, sort_order = 2
 WHERE root_category_id = @lf_re AND code = 'villa';
UPDATE categories SET name = 'Townhouse', name_plural = 'Townhouses', property_segment = 'residential', offered_for = NULL, sort_order = 3
 WHERE root_category_id = @lf_re AND code = 'townhouse';
UPDATE categories SET name = 'Penthouse', name_plural = 'Penthouses', property_segment = 'residential', offered_for = NULL, sort_order = 4
 WHERE root_category_id = @lf_re AND code = 'penthouse';
UPDATE categories SET name = 'Duplex', name_plural = 'Duplexes', property_segment = 'residential', offered_for = NULL, sort_order = 6
 WHERE root_category_id = @lf_re AND code = 'duplex';
UPDATE categories SET code = 'full-floor', slug = 'full-floors', name = 'Full Floor', name_plural = 'Full Floors',
       path = 'real-estate/full-floors', property_segment = 'both', offered_for = NULL, sort_order = 7
 WHERE root_category_id = @lf_re AND code IN ('commercial-floor', 'full-floor');
UPDATE categories SET name = 'Whole Building', name_plural = 'Whole Buildings', property_segment = 'both', offered_for = NULL, sort_order = 9
 WHERE root_category_id = @lf_re AND code = 'whole-building';
UPDATE categories SET code = 'land', slug = 'land', name = 'Land', name_plural = 'Land', path = 'real-estate/land',
       property_segment = 'both', offered_for = JSON_OBJECT('residential', JSON_ARRAY('sale'), 'commercial', JSON_ARRAY('sale', 'rent')),
       sort_order = 10
 WHERE root_category_id = @lf_re AND code IN ('plot', 'land');
UPDATE categories SET code = 'bulk-sale-unit', slug = 'bulk-sale-units', name = 'Bulk Sale Unit', name_plural = 'Bulk Sale Units',
       path = 'real-estate/bulk-sale-units', property_segment = 'both',
       offered_for = JSON_OBJECT('residential', JSON_ARRAY('sale'), 'commercial', JSON_ARRAY('sale')), sort_order = 11
 WHERE root_category_id = @lf_re AND code IN ('bulk-unit', 'bulk-sale-unit');
UPDATE categories SET name = 'Hotel & Hotel Apartment', name_plural = 'Hotels & Hotel Apartments', property_segment = 'both',
       offered_for = JSON_OBJECT('residential', JSON_ARRAY('sale', 'rent'), 'commercial', JSON_ARRAY('sale')), sort_order = 13
 WHERE root_category_id = @lf_re AND code = 'hotel-apartment';
UPDATE categories SET code = 'office-space', slug = 'office-spaces', name = 'Office Space', name_plural = 'Office Spaces',
       path = 'real-estate/office-spaces', property_segment = 'commercial', offered_for = NULL, sort_order = 15
 WHERE root_category_id = @lf_re AND code IN ('office', 'office-space');
UPDATE categories SET name = 'Retail', name_plural = 'Retail', property_segment = 'commercial', offered_for = NULL, sort_order = 16
 WHERE root_category_id = @lf_re AND code = 'retail';
UPDATE categories SET name = 'Warehouse', name_plural = 'Warehouses', property_segment = 'commercial', offered_for = NULL, sort_order = 17
 WHERE root_category_id = @lf_re AND code = 'warehouse';
UPDATE categories SET name = 'Shop', name_plural = 'Shops', property_segment = 'commercial', offered_for = NULL, sort_order = 18
 WHERE root_category_id = @lf_re AND code = 'shop';
UPDATE categories SET code = 'show-room', slug = 'show-rooms', name = 'Show Room', name_plural = 'Show Rooms',
       path = 'real-estate/show-rooms', property_segment = 'commercial', offered_for = NULL, sort_order = 19
 WHERE root_category_id = @lf_re AND code IN ('showroom', 'show-room');
UPDATE categories SET name = 'Factory', name_plural = 'Factories', property_segment = 'commercial', offered_for = NULL, sort_order = 20
 WHERE root_category_id = @lf_re AND code = 'factory';
UPDATE categories SET code = 'labor-camp', slug = 'labor-camps', name = 'Labor Camp', name_plural = 'Labor Camps',
       path = 'real-estate/labor-camps', property_segment = 'commercial', offered_for = NULL, sort_order = 21
 WHERE root_category_id = @lf_re AND code IN ('labour-camp', 'labor-camp');

-- New types. Matched on `code`, so a re-run updates in place.
INSERT INTO categories (public_id, parent_id, root_category_id, code, slug, name, name_plural,
                        depth, path, detail_table, status, is_visible, sort_order, property_segment, offered_for)
VALUES
  ('01K2F3A00000000000000PF005', @lf_re, @lf_re, 'compound',            'compounds',            'Compound',            'Compounds',            1, 'real-estate/compounds',            'real_estate', 'active', 1,  5, 'residential', NULL),
  ('01K2F3A00000000000000PF008', @lf_re, @lf_re, 'half-floor',          'half-floors',          'Half Floor',          'Half Floors',          1, 'real-estate/half-floors',          'real_estate', 'active', 1,  8, 'both',        NULL),
  ('01K2F3A00000000000000PF012', @lf_re, @lf_re, 'bungalow',            'bungalows',            'Bungalow',            'Bungalows',            1, 'real-estate/bungalows',            'real_estate', 'active', 1, 12, 'residential', NULL),
  ('01K2F3A00000000000000PF014', @lf_re, @lf_re, 'bulk-rent-unit',      'bulk-rent-units',      'Bulk Rent Unit',      'Bulk Rent Units',      1, 'real-estate/bulk-rent-units',      'real_estate', 'active', 1, 14, 'both',
     JSON_OBJECT('residential', JSON_ARRAY('rent'), 'commercial', JSON_ARRAY('rent'))),
  ('01K2F3A00000000000000PF022', @lf_re, @lf_re, 'staff-accommodation', 'staff-accommodation',  'Staff Accommodation', 'Staff Accommodation',  1, 'real-estate/staff-accommodation',  'real_estate', 'active', 1, 22, 'commercial',  NULL),
  ('01K2F3A00000000000000PF023', @lf_re, @lf_re, 'business-centre',     'business-centres',     'Business Centre',     'Business Centres',     1, 'real-estate/business-centres',     'real_estate', 'active', 1, 23, 'commercial',  NULL),
  ('01K2F3A00000000000000PF024', @lf_re, @lf_re, 'co-working-space',    'co-working-spaces',    'Co-working space',    'Co-working spaces',    1, 'real-estate/co-working-spaces',    'real_estate', 'active', 1, 24, 'commercial',  NULL),
  ('01K2F3A00000000000000PF025', @lf_re, @lf_re, 'farm',                'farms',                'Farm',                'Farms',                1, 'real-estate/farms',                'real_estate', 'active', 1, 25, 'commercial',  NULL)
ON DUPLICATE KEY UPDATE name = VALUES(name), name_plural = VALUES(name_plural), slug = VALUES(slug), path = VALUES(path),
                        sort_order = VALUES(sort_order), property_segment = VALUES(property_segment),
                        offered_for = VALUES(offered_for), status = 'active', is_visible = 1, deleted_at = NULL;

-- Every new type is offered for sale and rent at the category level, like the others.
INSERT IGNORE INTO category_purposes (category_id, purpose_id, is_default, sort_order)
SELECT c.id, cp.purpose_id, cp.is_default, cp.sort_order
  FROM categories c JOIN category_purposes cp ON cp.category_id = @lf_re
 WHERE c.root_category_id = @lf_re AND c.id <> @lf_re;

SET @lf_villa = (SELECT id FROM categories WHERE root_category_id = @lf_re AND code = 'villa' LIMIT 1);
SET @lf_land  = (SELECT id FROM categories WHERE root_category_id = @lf_re AND code = 'land' LIMIT 1);

-- -----------------------------------------------------------------------------
-- 3. Retired types: move what points at them, then retire them
-- -----------------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS lf_retired;
CREATE TEMPORARY TABLE lf_retired (id INT UNSIGNED PRIMARY KEY, sale_to INT UNSIGNED, rent_to INT UNSIGNED);
INSERT INTO lf_retired (id, sale_to, rent_to)
SELECT id,
       CASE WHEN code IN ('mansion', 'estate', 'chalet') THEN @lf_villa ELSE @lf_land END,
       CASE WHEN code IN ('industrial-land') THEN @lf_land ELSE @lf_villa END
  FROM categories
 WHERE root_category_id = @lf_re AND id <> @lf_re
   AND code IN ('mansion', 'estate', 'chalet', 'island', 'vineyard', 'industrial-land');

UPDATE listings l
  JOIN lf_retired r ON r.id = l.category_id
   SET l.category_id = IF(l.purpose_id = @lf_rent, r.rent_to, r.sale_to);

UPDATE property_units pu
  JOIN lf_retired r ON r.id = pu.category_id
   SET pu.category_id = r.sale_to;

UPDATE project_unit_types put
  JOIN lf_retired r ON r.id = put.category_id
   SET put.category_id = r.sale_to;

DELETE ui FROM url_inventory ui JOIN lf_retired r ON r.id = ui.category_id;

-- Land to rent is commercial only on PF.
UPDATE listings
   SET property_segment = 'commercial'
 WHERE category_id = @lf_land AND purpose_id = @lf_rent AND property_segment = 'residential';

-- Retire: hidden from every menu, kept so history (leads, stats) still resolves.
UPDATE categories c
  JOIN lf_retired r ON r.id = c.id
   SET c.status = 'inactive', c.is_visible = 0, c.deleted_at = COALESCE(c.deleted_at, NOW(3));

-- An end-to-end test's leftover type (2026-11-23 audit).
UPDATE categories
   SET status = 'inactive', is_visible = 0, deleted_at = COALESCE(deleted_at, NOW(3))
 WHERE root_category_id = @lf_re AND code LIKE 'e2e-%';

DROP TEMPORARY TABLE IF EXISTS lf_retired;

-- -----------------------------------------------------------------------------
-- 4. Amenities: Property Finder's 23
-- -----------------------------------------------------------------------------
INSERT INTO feature_groups (code, name, icon, sort_order)
SELECT 'amenities', 'Amenities', 'sparkles', 0
  FROM DUAL WHERE NOT EXISTS (SELECT 1 FROM feature_groups WHERE code = 'amenities');
SET @lf_group = (SELECT id FROM feature_groups WHERE code = 'amenities' LIMIT 1);

-- Renames in place (keeps every listing that already has them).
UPDATE features SET code = 'maids_room',          slug = 'maids-room',          name = 'Maids Room',           feature_group_id = @lf_group, sort_order = 2,  is_filterable = 1 WHERE code = 'maids_room';
UPDATE features SET code = 'balcony',             slug = 'balcony',             name = 'Balcony',              feature_group_id = @lf_group, sort_order = 3,  is_filterable = 1 WHERE code = 'balcony';
UPDATE features SET code = 'shared_pool',         slug = 'shared-pool',         name = 'Shared Pool',          feature_group_id = @lf_group, sort_order = 4,  is_filterable = 1 WHERE code = 'shared_pool';
UPDATE features SET code = 'shared_spa',          slug = 'shared-spa',          name = 'Shared Spa',           feature_group_id = @lf_group, sort_order = 5,  is_filterable = 1 WHERE code IN ('spa', 'shared_spa');
UPDATE features SET code = 'shared_gym',          slug = 'shared-gym',          name = 'Shared Gym',           feature_group_id = @lf_group, sort_order = 6,  is_filterable = 1 WHERE code = 'shared_gym';
UPDATE features SET code = 'concierge_service',   slug = 'concierge-service',   name = 'Concierge Service',    feature_group_id = @lf_group, sort_order = 7,  is_filterable = 1 WHERE code IN ('concierge', 'concierge_service');
UPDATE features SET code = 'covered_parking',     slug = 'covered-parking',     name = 'Covered Parking',      feature_group_id = @lf_group, sort_order = 8,  is_filterable = 1 WHERE code = 'covered_parking';
UPDATE features SET code = 'pets_allowed',        slug = 'pets-allowed',        name = 'Pets Allowed',         feature_group_id = @lf_group, sort_order = 11, is_filterable = 1 WHERE code IN ('pet_friendly', 'pets_allowed');
UPDATE features SET code = 'study',               slug = 'study',               name = 'Study',                feature_group_id = @lf_group, sort_order = 12, is_filterable = 1 WHERE code = 'study';
UPDATE features SET code = 'private_garden',      slug = 'private-garden',      name = 'Private Garden',       feature_group_id = @lf_group, sort_order = 13, is_filterable = 1 WHERE code = 'private_garden';
UPDATE features SET code = 'private_pool',        slug = 'private-pool',        name = 'Private Pool',         feature_group_id = @lf_group, sort_order = 14, is_filterable = 1 WHERE code = 'private_pool';
UPDATE features SET code = 'private_gym',         slug = 'private-gym',         name = 'Private Gym',          feature_group_id = @lf_group, sort_order = 15, is_filterable = 1 WHERE code = 'private_gym';
UPDATE features SET code = 'walk_in_closet',      slug = 'walk-in-closet',      name = 'Walk-in Closet',       feature_group_id = @lf_group, sort_order = 18, is_filterable = 1 WHERE code = 'walk_in_closet';
UPDATE features SET code = 'maid_service',        slug = 'maid-service',        name = 'Maid Service',         feature_group_id = @lf_group, sort_order = 20, is_filterable = 1 WHERE code IN ('housekeeping', 'maid_service');
UPDATE features SET code = 'childrens_play_area', slug = 'childrens-play-area', name = 'Children''s Play Area', feature_group_id = @lf_group, sort_order = 21, is_filterable = 1 WHERE code IN ('kids_play_area', 'childrens_play_area');
UPDATE features SET code = 'barbecue_area',       slug = 'barbecue-area',       name = 'Barbecue Area',        feature_group_id = @lf_group, sort_order = 23, is_filterable = 1 WHERE code IN ('bbq_area', 'barbecue_area');

-- New ones. The views stay separate rows because yachts keep their own view features.
INSERT INTO features (feature_group_id, code, slug, name, is_premium, is_filterable, sort_order, created_at) VALUES
  (@lf_group, 'central_ac',                  'central-a-c',                 'Central A/C',                 0, 1,  1, NOW(3)),
  (@lf_group, 'view_of_water',               'view-of-water',               'View of Water',               0, 1,  9, NOW(3)),
  (@lf_group, 'view_of_landmark',            'view-of-landmark',            'View of Landmark',            0, 1, 10, NOW(3)),
  (@lf_group, 'private_jacuzzi',             'private-jacuzzi',             'Private Jacuzzi',             0, 1, 16, NOW(3)),
  (@lf_group, 'built_in_wardrobes',          'built-in-wardrobes',          'Built in Wardrobes',          0, 1, 17, NOW(3)),
  (@lf_group, 'built_in_kitchen_appliances', 'built-in-kitchen-appliances', 'Built in Kitchen Appliances', 0, 1, 19, NOW(3)),
  (@lf_group, 'childrens_pool',              'childrens-pool',              'Children''s Pool',            0, 1, 22, NOW(3))
ON DUPLICATE KEY UPDATE feature_group_id = VALUES(feature_group_id), name = VALUES(name),
                        sort_order = VALUES(sort_order), is_filterable = 1;

DROP TEMPORARY TABLE IF EXISTS lf_pf_amenity;
CREATE TEMPORARY TABLE lf_pf_amenity (id INT UNSIGNED PRIMARY KEY);
INSERT INTO lf_pf_amenity (id)
SELECT id FROM features WHERE code IN (
  'central_ac', 'maids_room', 'balcony', 'shared_pool', 'shared_spa', 'shared_gym', 'concierge_service',
  'covered_parking', 'view_of_water', 'view_of_landmark', 'pets_allowed', 'study', 'private_garden',
  'private_pool', 'private_gym', 'private_jacuzzi', 'built_in_wardrobes', 'walk_in_closet',
  'built_in_kitchen_appliances', 'maid_service', 'childrens_play_area', 'childrens_pool', 'barbecue_area');

-- Close matches carried onto the PF amenity before the old ones go (real-estate listings only).
DROP TEMPORARY TABLE IF EXISTS lf_amenity_merge;
CREATE TEMPORARY TABLE lf_amenity_merge (old_code VARCHAR(80) PRIMARY KEY, new_code VARCHAR(80) NOT NULL);
INSERT INTO lf_amenity_merge (old_code, new_code) VALUES
  ('terrace', 'balcony'), ('infinity_pool', 'shared_pool'), ('sauna', 'shared_spa'), ('steam_room', 'shared_spa'),
  ('concierge_security', 'concierge_service'), ('basement_parking', 'covered_parking'),
  ('sea_view', 'view_of_water'), ('beachfront', 'view_of_water'), ('marina_view', 'view_of_water'), ('lake_view', 'view_of_water'),
  ('burj_khalifa_view', 'view_of_landmark');

INSERT IGNORE INTO listing_features (listing_id, feature_id)
SELECT lf.listing_id, nf.id
  FROM listing_features lf
  JOIN listings l ON l.id = lf.listing_id AND l.root_category_id = @lf_re
  JOIN features oldf ON oldf.id = lf.feature_id
  JOIN lf_amenity_merge m ON m.old_code = oldf.code
  JOIN features nf ON nf.code = m.new_code;

-- Real-estate listings keep only the 23.
DELETE lf FROM listing_features lf
  JOIN listings l ON l.id = lf.listing_id AND l.root_category_id = @lf_re
 WHERE lf.feature_id NOT IN (SELECT id FROM lf_pf_amenity);

-- Property Finder has no amenities for commercial property, so commercial listings carry none.
DELETE lf FROM listing_features lf
  JOIN listings l ON l.id = lf.listing_id AND l.root_category_id = @lf_re
 WHERE l.property_segment = 'commercial';

-- The catalogue links: real estate and developments offer exactly the 23.
DELETE cf FROM category_features cf
  JOIN categories c ON c.id = cf.category_id
 WHERE (c.id IN (@lf_re, @lf_dev) OR c.root_category_id IN (@lf_re, @lf_dev))
   AND cf.feature_id NOT IN (SELECT id FROM lf_pf_amenity);
INSERT INTO category_features (category_id, feature_id, sort_order)
SELECT root.id, f.id, f.sort_order
  FROM features f JOIN lf_pf_amenity a ON a.id = f.id
  JOIN categories root ON root.id IN (@lf_re, @lf_dev)
ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order);

-- Features no category offers any more and no listing carries are deleted.
DROP TEMPORARY TABLE IF EXISTS lf_orphan_feature;
CREATE TEMPORARY TABLE lf_orphan_feature (id INT UNSIGNED PRIMARY KEY);
INSERT INTO lf_orphan_feature (id)
SELECT f.id FROM features f
 WHERE NOT EXISTS (SELECT 1 FROM category_features cf WHERE cf.feature_id = f.id)
   AND NOT EXISTS (SELECT 1 FROM listing_features lf WHERE lf.feature_id = f.id);
DELETE ft FROM feature_translations ft JOIN lf_orphan_feature o ON o.id = ft.feature_id;
UPDATE search_synonym_sets s JOIN lf_orphan_feature o ON o.id = s.feature_id SET s.feature_id = NULL;
DELETE f FROM features f JOIN lf_orphan_feature o ON o.id = f.id;
DELETE fg FROM feature_groups fg
 WHERE NOT EXISTS (SELECT 1 FROM features f WHERE f.feature_group_id = fg.id);

DROP TEMPORARY TABLE IF EXISTS lf_orphan_feature;
DROP TEMPORARY TABLE IF EXISTS lf_amenity_merge;

-- -----------------------------------------------------------------------------
-- 5. Developments
-- -----------------------------------------------------------------------------
-- Unit types: PF's five. Studio is a bedroom count (0) on PF, so a Studio unit is an Apartment.
UPDATE project_unit_types
   SET bedrooms = COALESCE(bedrooms, 0)
 WHERE unit_type = 'studio';
UPDATE project_unit_types
   SET unit_type = 'apartment'
 WHERE unit_type NOT IN ('apartment', 'villa', 'townhouse', 'penthouse', 'duplex');
ALTER TABLE project_unit_types
  MODIFY COLUMN unit_type ENUM('apartment','villa','townhouse','penthouse','duplex') NOT NULL DEFAULT 'apartment';

-- Amenities: PF's names (the slugs match the listing amenities'), the rest dropped.
DROP TEMPORARY TABLE IF EXISTS lf_dev_amenity;
CREATE TEMPORARY TABLE lf_dev_amenity (old_slug VARCHAR(120) PRIMARY KEY, new_slug VARCHAR(120) NOT NULL, new_label VARCHAR(160) NOT NULL);
INSERT INTO lf_dev_amenity (old_slug, new_slug, new_label)
SELECT slug, slug, name FROM features WHERE id IN (SELECT id FROM lf_pf_amenity);
INSERT IGNORE INTO lf_dev_amenity (old_slug, new_slug, new_label) VALUES
  ('swimming-pool', 'shared-pool', 'Shared Pool'), ('infinity-pool', 'shared-pool', 'Shared Pool'),
  ('gymnasium', 'shared-gym', 'Shared Gym'), ('residents-gym', 'shared-gym', 'Shared Gym'), ('gym', 'shared-gym', 'Shared Gym'),
  ('kids-play-area', 'childrens-play-area', 'Children''s Play Area'),
  ('concierge', 'concierge-service', 'Concierge Service'),
  ('bbq-picnic-areas', 'barbecue-area', 'Barbecue Area'), ('bbq-area', 'barbecue-area', 'Barbecue Area'),
  ('fitted-kitchen-appliances', 'built-in-kitchen-appliances', 'Built in Kitchen Appliances'),
  ('central-air-conditioning', 'central-a-c', 'Central A/C'),
  ('maid-staff-room', 'maids-room', 'Maids Room'), ('maid-s-room', 'maids-room', 'Maids Room'),
  ('balcony-terrace', 'balcony', 'Balcony'), ('terrace', 'balcony', 'Balcony'),
  ('spa', 'shared-spa', 'Shared Spa');

INSERT IGNORE INTO project_amenities (project_id, slug, label, category, sort_order, created_at)
SELECT pa.project_id, m.new_slug, m.new_label, NULL, pa.sort_order, pa.created_at
  FROM project_amenities pa JOIN lf_dev_amenity m ON m.old_slug = pa.slug
 WHERE m.old_slug <> m.new_slug;
DELETE pa FROM project_amenities pa
 WHERE pa.slug NOT IN (SELECT slug FROM features WHERE id IN (SELECT id FROM lf_pf_amenity));
UPDATE project_amenities pa
  JOIN features f ON f.slug = pa.slug AND f.id IN (SELECT id FROM lf_pf_amenity)
   SET pa.label = f.name, pa.category = NULL, pa.sort_order = f.sort_order;

-- The names list the detail page reads, rebuilt from the rows.
UPDATE projects p
   SET p.amenities = COALESCE(
         (SELECT JSON_ARRAYAGG(x.label) FROM (
            SELECT pa.project_id, pa.label FROM project_amenities pa ORDER BY pa.project_id, pa.sort_order
          ) x WHERE x.project_id = p.id),
         JSON_ARRAY());

DROP TEMPORARY TABLE IF EXISTS lf_dev_amenity;
DROP TEMPORARY TABLE IF EXISTS lf_pf_amenity;

CALL sp_refresh_project_search(NULL);

-- -----------------------------------------------------------------------------
-- 6. The listing projection and counters
-- -----------------------------------------------------------------------------
-- Updated in place rather than rebuilt, so a live listing with an unapproved edit (0060) keeps
-- its approved row and only the renamed type / amenity ids change under it.
UPDATE listing_search ls
  JOIN listings l ON l.id = ls.listing_id
  JOIN categories c ON c.id = l.category_id
   SET ls.category_id = l.category_id,
       ls.category_slug = c.slug,
       ls.property_segment = l.property_segment,
       ls.spec_labels = IF(ls.spec_labels IS NULL, NULL, JSON_SET(ls.spec_labels, '$.type', c.name)),
       ls.feature_ids = (SELECT JSON_ARRAYAGG(lf.feature_id) FROM listing_features lf WHERE lf.listing_id = l.id)
 WHERE ls.root_category_id = @lf_re;

UPDATE categories c
   SET c.listing_count = (SELECT COUNT(*) FROM listings l WHERE l.category_id = c.id AND l.deleted_at IS NULL),
       c.active_listing_count = (SELECT COUNT(*) FROM listing_search ls WHERE ls.category_id = c.id)
 WHERE c.root_category_id = @lf_re AND c.id <> @lf_re;

INSERT INTO schema_migrations (version, name) VALUES ('0083', 'property_finder_types_amenities')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
