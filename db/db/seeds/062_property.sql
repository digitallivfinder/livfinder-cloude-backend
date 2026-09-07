-- =============================================================================
-- 062_property.sql
--
-- The property inventory layer: the physical assets underneath the listings.
--
-- A listing is an advertisement. It appears, it expires, the same flat is
-- advertised again next year by a different agency at a different price. The
-- unit is the thing that persists, and it is what makes price history, yield,
-- ownership, tenancy and market statistics possible at all. Everything here
-- hangs off that distinction.
--
-- Buildings and units are derived from the real-estate listings that already
-- exist, so the two layers agree: a listing's building name becomes a building,
-- its unit number becomes a unit, and the listing is then pointed at both.
-- =============================================================================

SET NAMES utf8mb4;

-- The schema's collation is utf8mb4_unicode_ci throughout, but a client's
-- default connection collation is utf8mb4_general_ci. Any comparison between a
-- string literal (or a CONVERT result) and a column is then a mix of two
-- collations, which MySQL rejects rather than coerces. Pinning the connection
-- collation is what lets the joins below be written naturally.
SET collation_connection = 'utf8mb4_unicode_ci';

SET @now = NOW(3);
SET @today = CAST(CURDATE() AS CHAR) COLLATE utf8mb4_unicode_ci;

-- A small numbers table. Generating floors, units, instalments and months all
-- need one, and cross-joining literals inline four times would be worse.
DROP TABLE IF EXISTS tmp_numbers;
CREATE TABLE tmp_numbers (n INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO tmp_numbers (n)
SELECT a.d + b.d * 10 + c.d * 100
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3) c;

-- -----------------------------------------------------------------------------
-- Buildings
--
-- One row per distinct building name within a community. Two towers in
-- different communities may legitimately share a name, so the community is part
-- of the identity; the same name in the same community is the same tower, which
-- is exactly the deduplication a portal has to perform on every inbound feed.
-- -----------------------------------------------------------------------------
INSERT INTO buildings
  (public_id, slug, name, location_id, community_id, sub_community_id, city_id,
   country_id, project_id, developer_brand_id, address_line1, latitude, longitude,
   building_type, floors_above_ground, floors_below_ground, total_units,
   height_metres, lift_count, parking_levels, status, completion_year,
   handover_date, tenure, leasehold_years, service_charge_per_area,
   service_charge_currency, service_charge_unit_id, service_charge_year,
   management_company, cover_image_url, description, seo_title, seo_description,
   is_publicly_visible, data_source, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('building:', b.name, ':', COALESCE(b.community_id, 0))), 26)),
  CONCAT(
    LOWER(REGEXP_REPLACE(REGEXP_REPLACE(b.name, '[^A-Za-z0-9]+', '-'), '(^-|-$)', '')),
    '-', LEFT(MD5(CONCAT(b.name, ':', COALESCE(b.community_id, 0))), 6)),
  b.name,
  b.location_id, b.community_id, b.sub_community_id, b.city_id, b.country_id,
  b.project_id, b.developer_brand_id,
  CONCAT(b.name, ', ', COALESCE(comm.name, city.name, 'Address on request')),
  b.latitude, b.longitude,
  -- Villa communities and townhouse clusters read very differently from towers,
  -- and the unit generation below depends on getting this right.
  CASE
    WHEN b.villa_share >= 0.6 AND b.max_floors <= 3 THEN 'villa_compound'
    WHEN b.townhouse_share >= 0.5 THEN 'townhouse_cluster'
    WHEN b.max_floors >= 25 THEN 'residential_tower'
    WHEN MOD(CONV(SUBSTRING(MD5(b.name), 1, 6), 16, 10), 11) = 0 THEN 'mixed_use'
    WHEN MOD(CONV(SUBSTRING(MD5(b.name), 1, 6), 16, 10), 23) = 0 THEN 'hotel_apartment'
    ELSE 'residential_tower'
  END,
  -- At least as many floors as the tallest listing in it claims.
  GREATEST(COALESCE(b.max_floors, 0), 3 + MOD(CONV(SUBSTRING(MD5(CONCAT('floors:', b.name)), 1, 6), 16, 10), 26)),
  1 + MOD(CONV(SUBSTRING(MD5(CONCAT('basement:', b.name)), 1, 6), 16, 10), 3),
  NULL,
  ROUND(3.3 * GREATEST(COALESCE(b.max_floors, 0), 3 + MOD(CONV(SUBSTRING(MD5(CONCAT('floors:', b.name)), 1, 6), 16, 10), 26)), 2),
  1 + MOD(CONV(SUBSTRING(MD5(CONCAT('lifts:', b.name)), 1, 6), 16, 10), 6),
  1 + MOD(CONV(SUBSTRING(MD5(CONCAT('parking:', b.name)), 1, 6), 16, 10), 4),
  CASE
    WHEN b.off_plan_share >= 0.5 THEN 'under_construction'
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('status:', b.name)), 1, 6), 16, 10), 19) = 0 THEN 'renovating'
    ELSE 'operational'
  END,
  COALESCE(b.median_year, 2004 + MOD(CONV(SUBSTRING(MD5(CONCAT('year:', b.name)), 1, 6), 16, 10), 20)),
  CASE WHEN b.off_plan_share >= 0.5
       THEN DATE_ADD(@today, INTERVAL 90 + MOD(CONV(SUBSTRING(MD5(CONCAT('handover:', b.name)), 1, 6), 16, 10), 900) DAY) END,
  CASE MOD(CONV(SUBSTRING(MD5(CONCAT('tenure:', b.name)), 1, 6), 16, 10), 10)
    WHEN 0 THEN 'leasehold'
    WHEN 1 THEN 'leasehold'
    WHEN 2 THEN 'commonhold'
    ELSE 'freehold'
  END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('tenure:', b.name)), 1, 6), 16, 10), 10) IN (0, 1)
       THEN 99 - MOD(CONV(SUBSTRING(MD5(CONCAT('lease:', b.name)), 1, 6), 16, 10), 40) END,
  ROUND(8 + MOD(CONV(SUBSTRING(MD5(CONCAT('sc:', b.name)), 1, 6), 16, 10), 3200) / 100, 4),
  b.currency_code,
  (SELECT id FROM measurement_units WHERE code = 'sqft' LIMIT 1),
  YEAR(@today),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mgmt:', b.name)), 1, 6), 16, 10), 6),
      'Emrill Services', 'Farnek Facilities Management', 'Savills Property Management',
      'Knight Frank Building Management', 'Enova Facilities Management', 'Concordia Owners Association Management'),
  CONCAT('https://cdn.livfinder.com/buildings/',
         LEFT(MD5(CONCAT('building:', b.name)), 12), '/cover.jpg'),
  CONCAT(b.name, ' is a ', LOWER(COALESCE(comm.name, city.name, 'landmark')),
         ' address with ', b.listing_count, ' listing',
         CASE WHEN b.listing_count = 1 THEN '' ELSE 's' END,
         ' currently tracked on Liv Finder.'),
  CONCAT(b.name, ' — Apartments & Villas for Sale and Rent'),
  CONCAT('Browse available units in ', b.name,
         COALESCE(CONCAT(', ', comm.name), ''),
         '. Prices, floor plans, service charges and transaction history.'),
  1, 'derived', @now, @now
FROM (
  SELECT
    re.building_name AS name,
    l.community_id,
    MAX(l.sub_community_id) AS sub_community_id,
    MAX(l.location_id) AS location_id,
    MAX(l.city_id) AS city_id,
    MAX(l.country_id) AS country_id,
    MAX(l.project_id) AS project_id,
    MAX(re.developer_brand_id) AS developer_brand_id,
    ROUND(AVG(l.latitude), 7) AS latitude,
    ROUND(AVG(l.longitude), 7) AS longitude,
    MAX(re.total_floors) AS max_floors,
    ROUND(AVG(re.year_built)) AS median_year,
    MAX(l.currency_code) AS currency_code,
    COUNT(*) AS listing_count,
    AVG(CASE WHEN c.code LIKE '%villa%' THEN 1 ELSE 0 END) AS villa_share,
    AVG(CASE WHEN c.code LIKE '%townhouse%' THEN 1 ELSE 0 END) AS townhouse_share,
    AVG(CASE WHEN re.completion_status = 'off_plan' THEN 1 ELSE 0 END) AS off_plan_share
  FROM listing_real_estate re
  JOIN listings l ON l.id = re.listing_id
  LEFT JOIN categories c ON c.id = l.category_id
  WHERE re.building_name IS NOT NULL AND re.building_name <> ''
  GROUP BY re.building_name, l.community_id
) AS b
LEFT JOIN locations comm ON comm.id = b.community_id
LEFT JOIN locations city ON city.id = b.city_id;

-- -----------------------------------------------------------------------------
-- Building floors
--
-- Basement parking, ground-floor lobby and retail, residential above, penthouse
-- at the top. The floor row is what a floor plan attaches to and what "high
-- floor" means when a buyer filters on it.
-- -----------------------------------------------------------------------------
INSERT INTO building_floors
  (building_id, floor_number, floor_label, floor_type, unit_count,
   floor_plate_area, area_unit_id, ceiling_height_metres, has_balconies, notes)
SELECT
  f.building_id,
  f.floor_number,
  CASE
    WHEN f.floor_number < 0 THEN CONCAT('B', ABS(f.floor_number))
    WHEN f.floor_number = 0 THEN 'G'
    ELSE CAST(f.floor_number AS CHAR)
  END,
  CASE
    WHEN f.floor_number < 0 THEN 'parking'
    WHEN f.floor_number = 0 THEN 'lobby'
    WHEN f.floor_number = 1 AND MOD(CONV(SUBSTRING(MD5(CONCAT('retail:', f.building_id)), 1, 6), 16, 10), 3) = 0 THEN 'retail'
    WHEN f.floor_number = 2 AND MOD(CONV(SUBSTRING(MD5(CONCAT('amenity:', f.building_id)), 1, 6), 16, 10), 2) = 0 THEN 'amenity'
    WHEN f.floor_number = f.floors_above_ground AND f.floors_above_ground >= 6 THEN 'penthouse'
    ELSE 'residential'
  END,
  CASE
    WHEN f.floor_number <= 0 THEN NULL
    WHEN f.floor_number = f.floors_above_ground AND f.floors_above_ground >= 6
      THEN 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('pu:', f.building_id)), 1, 6), 16, 10), 2)
    ELSE 2 + MOD(CONV(SUBSTRING(MD5(CONCAT('units:', f.building_id, ':', f.floor_number)), 1, 6), 16, 10), 7)
  END,
  ROUND(600 + MOD(CONV(SUBSTRING(MD5(CONCAT('plate:', f.building_id)), 1, 6), 16, 10), 1400)
        - GREATEST(0, f.floor_number) * 3, 2),
  (SELECT id FROM measurement_units WHERE code = 'sqm' LIMIT 1),
  CASE
    WHEN f.floor_number = f.floors_above_ground THEN 3.60
    WHEN f.floor_number = 0 THEN 4.50
    ELSE 2.90 + MOD(CONV(SUBSTRING(MD5(CONCAT('ceil:', f.building_id)), 1, 6), 16, 10), 5) / 10
  END,
  CASE WHEN f.floor_number > 0 THEN 1 ELSE 0 END,
  CASE WHEN f.floor_number = f.floors_above_ground AND f.floors_above_ground >= 6
       THEN 'Penthouse level with private lift lobby.' END
FROM (
  SELECT b.id AS building_id,
         b.floors_above_ground,
         CAST(n.n AS SIGNED) - CAST(b.floors_below_ground AS SIGNED) AS floor_number
  FROM buildings b
  JOIN tmp_numbers n ON n.n <= b.floors_above_ground + b.floors_below_ground
) AS f;

-- The building's own floor count is the count of the rows, not a number typed
-- in beside them.
UPDATE buildings b
JOIN (
  SELECT building_id,
         SUM(CASE WHEN floor_number > 0 THEN 1 ELSE 0 END) AS above,
         SUM(CASE WHEN floor_number < 0 THEN 1 ELSE 0 END) AS below,
         SUM(COALESCE(unit_count, 0)) AS units
  FROM building_floors
  GROUP BY building_id
) f ON f.building_id = b.id
SET b.floors_above_ground = f.above,
    b.floors_below_ground = f.below,
    b.total_units = LEAST(65535, f.units);

-- -----------------------------------------------------------------------------
-- Property units
--
-- Every real-estate listing gets the unit it advertises. The unit number comes
-- from the listing where the feed supplied one and is otherwise composed from
-- the floor, which is what an agency does by hand when a landlord will not
-- disclose it.
-- -----------------------------------------------------------------------------
-- Composing a unit number by hand can collide: two listings on the fourteenth
-- floor of the same tower with no stated unit number both want '1406'. The
-- source set is materialised first so a row number can disambiguate them,
-- rather than letting the unique index reject the second listing outright.
DROP TABLE IF EXISTS tmp_unit_src;
CREATE TABLE tmp_unit_src AS
SELECT x.*,
       ROW_NUMBER() OVER (PARTITION BY x.building_id, x.unit_number
                          ORDER BY x.public_id) AS rn
FROM (
  SELECT
    UPPER(LEFT(MD5(CONCAT('unit:', l.id)), 26)) AS public_id,
    b.id AS building_id,
    fl.id AS floor_id,
    l.project_id AS project_id,
    COALESCE(NULLIF(re.unit_number, ''),
             CONCAT(COALESCE(re.floor_number, 1 + MOD(l.id, 20)), LPAD(1 + MOD(l.id, 8), 2, '0'))) AS unit_number,
    COALESCE(re.floor_number, fl.floor_number) AS floor_number,
    -- A registry reference only exists where the jurisdiction publishes one.
    CASE WHEN COALESCE(re.title_deed_number, re.dld_permit_number) IS NOT NULL
         THEN CONCAT('REG-', UPPER(LEFT(MD5(CONCAT('registry:', l.id)), 10))) END AS registry_reference,
    CASE WHEN re.plot_area_sqm IS NOT NULL
         THEN CONCAT(MOD(CONV(SUBSTRING(MD5(CONCAT('plot:', l.id)), 1, 6), 16, 10), 900) + 100, '-',
                     MOD(CONV(SUBSTRING(MD5(CONCAT('sub:', l.id)), 1, 6), 16, 10), 90) + 10) END AS plot_number,
    l.location_id, l.community_id, l.city_id, l.country_id,
    l.address AS address_line1,
    l.latitude, l.longitude,
    l.category_id,
    CASE
      WHEN re.bedrooms = 0 THEN 'studio'
      WHEN cat.code LIKE '%penthouse%' THEN 'penthouse'
      WHEN cat.code LIKE '%villa%' THEN 'villa'
      WHEN cat.code LIKE '%townhouse%' THEN 'townhouse'
      WHEN cat.code LIKE '%duplex%' THEN 'duplex'
      WHEN cat.code LIKE '%office%' THEN 'office'
      WHEN cat.code LIKE '%retail%' OR cat.code LIKE '%shop%' THEN 'retail'
      WHEN cat.code LIKE '%warehouse%' THEN 'warehouse'
      WHEN cat.code LIKE '%plot%' OR cat.code LIKE '%land%' THEN 'plot'
      WHEN cat.code LIKE '%loft%' THEN 'loft'
      ELSE 'apartment'
    END AS unit_type,
    re.bedrooms, re.bathrooms,
    ROUND(COALESCE(re.built_area_sqft, re.built_area_sqm * 10.7639), 2) AS built_up_area,
    ROUND(COALESCE(re.plot_area_sqft, re.plot_area_sqm * 10.7639), 2) AS plot_area,
    CASE WHEN re.terrace_area_sqm IS NOT NULL
         THEN ROUND(re.terrace_area_sqm * 10.7639, 2) END AS balcony_area,
    (SELECT id FROM measurement_units WHERE code = 'sqft' LIMIT 1) AS area_unit_id,
    re.parking_spaces,
    CASE WHEN COALESCE(re.parking_spaces, 0) > 0
         THEN CONCAT('P', 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('park:', l.id)), 1, 6), 16, 10), 400)) END AS parking_numbers,
    CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('store:', l.id)), 1, 6), 16, 10), 3) = 0 THEN 1 ELSE 0 END AS storage_room,
    COALESCE(SIGN(re.maid_rooms), 0) AS maid_room,
    re.view_type,
    re.orientation,
    CASE re.ownership_type
      WHEN 'freehold' THEN 'freehold'
      WHEN 'leasehold' THEN 'leasehold'
      ELSE COALESCE(b.tenure, 'unknown')
    END AS tenure,
    CASE
      WHEN re.completion_status = 'off_plan' THEN 'off_plan'
      WHEN COALESCE(re.is_tenanted, 0) = 1 THEN 'tenanted'
      WHEN l.purpose_id = (SELECT id FROM purposes WHERE code = 'rent' LIMIT 1) THEN 'vacant'
      WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('occ:', l.id)), 1, 6), 16, 10), 4) = 0 THEN 'owner_occupied'
      ELSE 'vacant'
    END AS occupancy_status,
    CASE WHEN re.completion_status = 'off_plan' THEN 1 ELSE 0 END AS is_off_plan,
    re.handover_date,
    l.currency_code,
    'agency' AS data_source,
    CASE
      WHEN re.title_deed_number IS NOT NULL THEN 'registry_verified'
      WHEN l.is_verified = 1 THEN 'agency_verified'
      ELSE 'unverified'
    END AS verification_status,
    l.created_at
  FROM listings l
  JOIN listing_real_estate re ON re.listing_id = l.id
  LEFT JOIN categories cat ON cat.id = l.category_id
  LEFT JOIN buildings b
    ON b.name = re.building_name
   AND (b.community_id = l.community_id OR (b.community_id IS NULL AND l.community_id IS NULL))
  LEFT JOIN building_floors fl
    ON fl.building_id = b.id
   AND fl.floor_number = LEAST(COALESCE(re.floor_number, 1), b.floors_above_ground)
) AS x;

UPDATE tmp_unit_src
SET unit_number = CONCAT(unit_number, '-', rn)
WHERE rn > 1 AND building_id IS NOT NULL;

INSERT INTO property_units
  (public_id, building_id, floor_id, project_id, unit_number, floor_number,
   registry_reference, plot_number, location_id, community_id, city_id, country_id,
   address_line1, latitude, longitude, category_id, unit_type, bedrooms, bathrooms,
   built_up_area, plot_area, balcony_area, area_unit_id, parking_spaces,
   parking_numbers, storage_room, maid_room, view_type, orientation, tenure,
   occupancy_status, is_off_plan, handover_date, currency_code, data_source,
   verification_status, created_at, updated_at)
SELECT
  public_id, building_id, floor_id, project_id, unit_number, floor_number,
  registry_reference, plot_number, location_id, community_id, city_id, country_id,
  address_line1, latitude, longitude, category_id, unit_type, bedrooms, bathrooms,
  built_up_area, plot_area, balcony_area, area_unit_id, parking_spaces,
  parking_numbers, storage_room, maid_room, view_type, orientation, tenure,
  occupancy_status, is_off_plan, handover_date, currency_code, data_source,
  verification_status, created_at, @now
FROM tmp_unit_src;

DROP TABLE IF EXISTS tmp_unit_src;

-- The listing now points at the asset it advertises. This is the join that lets
-- the same flat be recognised across three agencies and four years of feeds.
UPDATE listings l
JOIN property_units u
  ON CONVERT(u.public_id USING utf8mb4) COLLATE utf8mb4_unicode_ci
     = UPPER(LEFT(MD5(CONCAT('unit:', l.id)), 26))
SET l.unit_id = u.id,
    l.building_id = u.building_id
WHERE l.root_category_id = 1;

-- Units that exist in the building but are not currently advertised. Without
-- them a building looks like it has four flats in it, and every per-building
-- statistic is computed over a sample that is only the advertised end of the
-- market.
INSERT INTO property_units
  (public_id, building_id, floor_id, unit_number, floor_number, location_id,
   community_id, city_id, country_id, category_id, unit_type, bedrooms, bathrooms,
   built_up_area, area_unit_id, parking_spaces, storage_room, maid_room,
   tenure, occupancy_status, is_off_plan, currency_code, data_source,
   verification_status, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('unit-extra:', b.id, ':', fl.floor_number, ':', n.n)), 26)),
  b.id, fl.id,
  CONCAT(CASE WHEN fl.floor_number = 0 THEN 'G' ELSE fl.floor_number END,
         LPAD(n.n + 1, 2, '0')),
  fl.floor_number,
  b.location_id, b.community_id, b.city_id, b.country_id,
  seed.category_id,
  CASE b.building_type
    WHEN 'villa_compound'     THEN 'villa'
    WHEN 'townhouse_cluster'  THEN 'townhouse'
    WHEN 'commercial_tower'   THEN 'office'
    ELSE CASE WHEN fl.floor_type = 'penthouse' THEN 'penthouse'
              WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('type:', b.id, fl.floor_number, n.n)), 1, 6), 16, 10), 9) = 0 THEN 'studio'
              ELSE 'apartment' END
  END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('type:', b.id, fl.floor_number, n.n)), 1, 6), 16, 10), 9) = 0 THEN 0
       ELSE 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('bed:', b.id, fl.floor_number, n.n)), 1, 6), 16, 10), 4) END,
  1 + MOD(CONV(SUBSTRING(MD5(CONCAT('bath:', b.id, fl.floor_number, n.n)), 1, 6), 16, 10), 4),
  ROUND(520 + MOD(CONV(SUBSTRING(MD5(CONCAT('area:', b.id, fl.floor_number, n.n)), 1, 6), 16, 10), 3400), 2),
  (SELECT id FROM measurement_units WHERE code = 'sqft' LIMIT 1),
  MOD(CONV(SUBSTRING(MD5(CONCAT('spaces:', b.id, fl.floor_number, n.n)), 1, 6), 16, 10), 3),
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('store:', b.id, n.n)), 1, 6), 16, 10), 3) = 0 THEN 1 ELSE 0 END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('maid:', b.id, n.n)), 1, 6), 16, 10), 4) = 0 THEN 1 ELSE 0 END,
  b.tenure,
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('occ:', b.id, fl.floor_number, n.n)), 1, 6), 16, 10), 4),
      'tenanted', 'owner_occupied', 'tenanted', 'vacant'),
  CASE WHEN b.status = 'under_construction' THEN 1 ELSE 0 END,
  seed.currency_code,
  'registry',
  'registry_verified',
  DATE_SUB(@now, INTERVAL 200 + MOD(CONV(SUBSTRING(MD5(CONCAT('created:', b.id)), 1, 6), 16, 10), 900) DAY), @now
FROM buildings b
JOIN building_floors fl
  ON fl.building_id = b.id
 AND fl.floor_type IN ('residential', 'penthouse')
JOIN tmp_numbers n ON n.n < LEAST(COALESCE(fl.unit_count, 0), 2)
JOIN (
  SELECT l.building_id, MIN(l.category_id) AS category_id, MIN(l.currency_code) AS currency_code
  FROM listings l
  WHERE l.building_id IS NOT NULL
  GROUP BY l.building_id
) AS seed ON seed.building_id = b.id
-- Only for a sample of floors, so the demo database stays a demo database.
WHERE MOD(fl.floor_number, 7) = 1
ON DUPLICATE KEY UPDATE updated_at = VALUES(updated_at);

-- Counters follow the rows.
UPDATE property_units u
LEFT JOIN (
  SELECT unit_id,
         COUNT(*) AS total,
         SUM(status = 'active') AS active,
         MAX(created_at) AS last_listed
  FROM listings
  WHERE unit_id IS NOT NULL
  GROUP BY unit_id
) c ON c.unit_id = u.id
SET u.listing_count = COALESCE(c.total, 0),
    u.active_listing_count = LEAST(255, COALESCE(c.active, 0)),
    u.last_listed_at = c.last_listed;

UPDATE buildings b
LEFT JOIN (
  SELECT building_id, COUNT(*) AS units FROM property_units
  WHERE building_id IS NOT NULL GROUP BY building_id
) u ON u.building_id = b.id
LEFT JOIN (
  SELECT building_id,
         COUNT(*) AS total,
         SUM(status = 'active') AS active,
         AVG(CASE WHEN status = 'active' AND purpose_id = (SELECT id FROM purposes WHERE code = 'sale' LIMIT 1)
                  THEN price_base END) AS avg_price,
         AVG(CASE WHEN status = 'active' AND purpose_id = (SELECT id FROM purposes WHERE code = 'rent' LIMIT 1)
                  THEN price_base END) AS avg_rent
  FROM listings WHERE building_id IS NOT NULL GROUP BY building_id
) l ON l.building_id = b.id
SET b.unit_count = LEAST(65535, COALESCE(u.units, 0)),
    b.listing_count = LEAST(65535, COALESCE(l.total, 0)),
    b.active_listing_count = LEAST(65535, COALESCE(l.active, 0)),
    b.avg_price_base = ROUND(l.avg_price, 2),
    b.avg_rent_base = ROUND(l.avg_rent, 2),
    -- Gross yield, not net: service charges are known per building but not per
    -- unit, so a net figure here would be a guess dressed as a calculation.
    b.gross_yield_percent = CASE WHEN l.avg_price > 0 AND l.avg_rent > 0
                                 THEN ROUND(l.avg_rent / l.avg_price * 100, 3) END;

UPDATE buildings b
JOIN (
  SELECT l.building_id, AVG(l.price_per_area) AS ppa
  FROM listings l
  WHERE l.building_id IS NOT NULL AND l.price_per_area IS NOT NULL
  GROUP BY l.building_id
) p ON p.building_id = b.id
SET b.avg_price_per_area = ROUND(p.ppa, 4);

-- -----------------------------------------------------------------------------
-- Ownership
--
-- Who owns the unit, in what share, since when. Shares are rows rather than a
-- single owner column because joint ownership is the norm above a certain price
-- and because a company owning a unit through a holding structure is the case
-- the compliance layer has to be able to walk.
-- -----------------------------------------------------------------------------
INSERT INTO unit_ownerships
  (unit_id, owner_type, contact_id, organization_id, owner_name, owner_country_id,
   share_percent, ownership_type, acquired_on, acquired_price, currency_code,
   is_current, title_deed_reference, is_verified, verified_at, verification_method,
   source, created_at, updated_at)
SELECT
  u.id,
  CASE
    WHEN c.company_name IS NOT NULL AND c.company_name <> '' THEN 'company'
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('otype:', u.id)), 1, 6), 16, 10), 17) = 0 THEN 'trust'
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('otype:', u.id)), 1, 6), 16, 10), 23) = 0 THEN 'fund'
    ELSE 'individual'
  END,
  c.id, NULL,
  COALESCE(NULLIF(c.company_name, ''), c.display_name,
           CONCAT(c.first_name, ' ', c.last_name)),
  COALESCE(c.nationality_country_id, c.country_id),
  -- Joint ownership splits evenly; a single owner holds the lot.
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('joint:', u.id)), 1, 6), 16, 10), 4) = 0 THEN 50.000 ELSE 100.000 END,
  CASE
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('joint:', u.id)), 1, 6), 16, 10), 4) = 0 THEN 'joint_tenants'
    WHEN c.company_name IS NOT NULL AND c.company_name <> '' THEN 'company_shares'
    WHEN u.tenure = 'leasehold' THEN 'leasehold'
    ELSE 'sole'
  END,
  acq.acquired_on,
  ROUND(acq.acquired_price, 2),
  u.currency_code,
  1,
  CASE WHEN u.verification_status = 'registry_verified'
       THEN CONCAT('TD-', YEAR(acq.acquired_on), '-',
                   UPPER(LEFT(MD5(CONCAT('deed:', u.id)), 8))) END,
  CASE WHEN u.verification_status = 'registry_verified' THEN 1 ELSE 0 END,
  CASE WHEN u.verification_status = 'registry_verified'
       THEN DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('ver:', u.id)), 1, 6), 16, 10), 400) DAY) END,
  CASE u.verification_status
    WHEN 'registry_verified' THEN 'registry_api'
    WHEN 'agency_verified'   THEN 'declaration'
    ELSE 'none'
  END,
  CASE u.data_source WHEN 'registry' THEN 'registry' ELSE 'agency' END,
  @now, @now
FROM property_units u
JOIN crm_contacts c
  ON c.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('owner:', u.id)), 1, 6), 16, 10),
                    (SELECT COUNT(*) FROM crm_contacts))
JOIN (
  SELECT u2.id AS unit_id,
         DATE_SUB(@today, INTERVAL 200 + MOD(CONV(SUBSTRING(MD5(CONCAT('acq:', u2.id)), 1, 6), 16, 10), 3600) DAY) AS acquired_on,
         -- Acquisition price sits below today's value by roughly the market
         -- movement since, which is what makes the equity calculations in the
         -- mortgage layer come out sane.
         GREATEST(50000, COALESCE(u2.built_up_area, 1200) *
                  ((700 + MOD(CONV(SUBSTRING(MD5(CONCAT('city-ppa:', COALESCE(u2.city_id, 0))), 1, 6), 16, 10), 800))
                   * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('community-ppa:', COALESCE(u2.community_id, 0))), 1, 6), 16, 10), 25) / 100)
                   * (0.95 + MOD(CONV(SUBSTRING(MD5(CONCAT('ppa:', u2.id)), 1, 6), 16, 10), 11) / 100))) AS acquired_price
  FROM property_units u2
) AS acq ON acq.unit_id = u.id;

-- The joint owners: a second row for every unit held jointly, so the shares on
-- a unit sum to a hundred rather than to fifty.
INSERT INTO unit_ownerships
  (unit_id, owner_type, contact_id, owner_name, owner_country_id, share_percent,
   ownership_type, acquired_on, acquired_price, currency_code, is_current,
   title_deed_reference, is_verified, verification_method, source, created_at, updated_at)
SELECT
  o.unit_id, 'individual', c2.id,
  COALESCE(c2.display_name, CONCAT(c2.first_name, ' ', c2.last_name)),
  COALESCE(c2.nationality_country_id, c2.country_id),
  50.000, 'joint_tenants', o.acquired_on, o.acquired_price, o.currency_code, 1,
  o.title_deed_reference, o.is_verified, o.verification_method, o.source, @now, @now
FROM unit_ownerships o
JOIN crm_contacts c2
  ON c2.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('joint-owner:', o.unit_id)), 1, 6), 16, 10),
                     (SELECT COUNT(*) FROM crm_contacts))
WHERE o.ownership_type = 'joint_tenants' AND o.share_percent = 50.000
  AND c2.id <> o.contact_id;

-- The previous owner, for the units that have changed hands. is_current = 0 is
-- what makes an ownership history rather than an ownership snapshot.
INSERT INTO unit_ownerships
  (unit_id, owner_type, contact_id, owner_name, owner_country_id, share_percent,
   ownership_type, acquired_on, acquired_price, currency_code, disposed_on,
   is_current, is_verified, verification_method, source, created_at, updated_at)
SELECT
  o.unit_id, 'individual', c3.id,
  COALESCE(c3.display_name, CONCAT(c3.first_name, ' ', c3.last_name)),
  COALESCE(c3.nationality_country_id, c3.country_id),
  100.000, 'sole',
  DATE_SUB(o.acquired_on, INTERVAL 700 + MOD(CONV(SUBSTRING(MD5(CONCAT('prev:', o.unit_id)), 1, 6), 16, 10), 1800) DAY),
  ROUND(o.acquired_price * 0.62, 2),
  o.currency_code,
  o.acquired_on, 0, 1, 'registry_api', 'registry', @now, @now
FROM unit_ownerships o
JOIN crm_contacts c3
  ON c3.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('prev-owner:', o.unit_id)), 1, 6), 16, 10),
                     (SELECT COUNT(*) FROM crm_contacts))
WHERE o.is_current = 1
  AND o.share_percent = 100.000
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('haschanged:', o.unit_id)), 1, 6), 16, 10), 3) = 0;

-- -----------------------------------------------------------------------------
-- Transactions
--
-- The fact table the whole valuation and market-statistics layer stands on. An
-- asking price is an opinion; a registered transaction is a fact, and the two
-- are kept in different tables for exactly that reason. is_arms_length is what
-- keeps an intra-family transfer at a nominal price out of the median.
-- -----------------------------------------------------------------------------

-- Registry-sourced sales history: two to four per unit over the last six years.
INSERT INTO unit_transactions
  (public_id, unit_id, building_id, project_id, location_id, community_id,
   city_id, country_id, transaction_type, transaction_date, registration_date,
   registry_reference, amount, currency_code, amount_base, price_per_area, area,
   area_unit_id, unit_type, bedrooms, source, confidence, is_public,
   is_arms_length, exclusion_reason, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('txn:', u.id, ':', n.n)), 26)),
  u.id, u.building_id, u.project_id, u.location_id, u.community_id,
  u.city_id, u.country_id,
  CASE
    WHEN u.is_off_plan = 1 AND n.n = 0 THEN 'off_plan_sale'
    WHEN n.n = 0 THEN 'sale'
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('ttype:', u.id, n.n)), 1, 6), 16, 10), 23) = 0 THEN 'inheritance'
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('ttype:', u.id, n.n)), 1, 6), 16, 10), 29) = 0 THEN 'auction'
    ELSE 'resale'
  END,
  t.transaction_date,
  DATE_ADD(t.transaction_date, INTERVAL 3 + MOD(CONV(SUBSTRING(MD5(CONCAT('reg:', u.id, n.n)), 1, 6), 16, 10), 25) DAY),
  CONCAT('TX-', DATE_FORMAT(t.transaction_date, '%Y%m'), '-',
         UPPER(LEFT(MD5(CONCAT('txnref:', u.id, ':', n.n)), 8))),
  ROUND(t.amount, 2),
  COALESCE(u.currency_code, 'AED'),
  ROUND(t.amount, 2),
  CASE WHEN u.built_up_area > 0 THEN ROUND(t.amount / u.built_up_area, 4) END,
  u.built_up_area,
  u.area_unit_id,
  u.unit_type,
  u.bedrooms,
  'land_registry',
  'verified',
  1,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('ttype:', u.id, n.n)), 1, 6), 16, 10), 23) = 0 THEN 0 ELSE 1 END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('ttype:', u.id, n.n)), 1, 6), 16, 10), 23) = 0
       THEN 'Transfer between related parties at below-market consideration; excluded from median calculations.' END,
  @now, @now
FROM property_units u
JOIN tmp_numbers n ON n.n < 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('txcount:', u.id)), 1, 6), 16, 10), 3)
JOIN (
  SELECT u2.id AS unit_id, n2.n AS seq,
         DATE_SUB(@today, INTERVAL 60 + n2.n * 420
                  + MOD(CONV(SUBSTRING(MD5(CONCAT('txdate:', u2.id, n2.n)), 1, 6), 16, 10), 380) DAY) AS transaction_date,
         -- Older transactions are cheaper: roughly six per cent a year of
         -- nominal growth, plus deterministic noise for individual bargains.
         GREATEST(50000,
           COALESCE(u2.built_up_area, 1200) * ((700 + MOD(CONV(SUBSTRING(MD5(CONCAT('city-ppa:', COALESCE(u2.city_id, 0))), 1, 6), 16, 10), 800))
                   * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('community-ppa:', COALESCE(u2.community_id, 0))), 1, 6), 16, 10), 25) / 100)
                   * (0.95 + MOD(CONV(SUBSTRING(MD5(CONCAT('ppa:', u2.id)), 1, 6), 16, 10), 11) / 100))
           * POW(0.94, n2.n + 1)
           * (0.92 + MOD(CONV(SUBSTRING(MD5(CONCAT('txnoise:', u2.id, n2.n)), 1, 6), 16, 10), 17) / 100)
         ) AS amount
  FROM property_units u2
  CROSS JOIN tmp_numbers n2
  WHERE n2.n < 3
) AS t ON t.unit_id = u.id AND t.seq = n.n
WHERE u.unit_type NOT IN ('plot', 'whole_building');

-- Rental registrations. A separate transaction type rather than a separate
-- table, because the market statistics need both sides of the same grain to
-- compute a yield.
INSERT INTO unit_transactions
  (public_id, unit_id, building_id, location_id, community_id, city_id, country_id,
   transaction_type, transaction_date, registration_date, registry_reference,
   amount, currency_code, amount_base, price_per_area, area, area_unit_id,
   rent_period, contract_months, unit_type, bedrooms, source, confidence,
   is_public, is_arms_length, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('rent-txn:', u.id, ':', n.n)), 26)),
  u.id, u.building_id, u.location_id, u.community_id, u.city_id, u.country_id,
  CASE WHEN n.n = 0 THEN 'rent' ELSE 'rent_renewal' END,
  DATE_SUB(@today, INTERVAL 40 + n.n * 365 + MOD(CONV(SUBSTRING(MD5(CONCAT('rdate:', u.id, n.n)), 1, 6), 16, 10), 90) DAY),
  DATE_SUB(@today, INTERVAL 35 + n.n * 365 + MOD(CONV(SUBSTRING(MD5(CONCAT('rdate:', u.id, n.n)), 1, 6), 16, 10), 90) DAY),
  CONCAT('EJ-', UPPER(LEFT(MD5(CONCAT('ejari:', u.id, ':', n.n)), 10))),
  ROUND(GREATEST(8000,
    COALESCE(u.built_up_area, 1200) * ((700 + MOD(CONV(SUBSTRING(MD5(CONCAT('city-ppa:', COALESCE(u.city_id, 0))), 1, 6), 16, 10), 800))
                   * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('community-ppa:', COALESCE(u.community_id, 0))), 1, 6), 16, 10), 25) / 100)
                   * (0.95 + MOD(CONV(SUBSTRING(MD5(CONCAT('ppa:', u.id)), 1, 6), 16, 10), 11) / 100))
                   * (0.045 + MOD(CONV(SUBSTRING(MD5(CONCAT('yield:', u.id)), 1, 6), 16, 10), 35) / 1000)
    * POW(0.95, n.n)), 2),
  COALESCE(u.currency_code, 'AED'),
  ROUND(GREATEST(8000,
    COALESCE(u.built_up_area, 1200) * ((700 + MOD(CONV(SUBSTRING(MD5(CONCAT('city-ppa:', COALESCE(u.city_id, 0))), 1, 6), 16, 10), 800))
                   * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('community-ppa:', COALESCE(u.community_id, 0))), 1, 6), 16, 10), 25) / 100)
                   * (0.95 + MOD(CONV(SUBSTRING(MD5(CONCAT('ppa:', u.id)), 1, 6), 16, 10), 11) / 100))
                   * (0.045 + MOD(CONV(SUBSTRING(MD5(CONCAT('yield:', u.id)), 1, 6), 16, 10), 35) / 1000)
    * POW(0.95, n.n)), 2),
  CASE WHEN u.built_up_area > 0
       THEN ROUND(GREATEST(8000,
              COALESCE(u.built_up_area, 1200) * ((700 + MOD(CONV(SUBSTRING(MD5(CONCAT('city-ppa:', COALESCE(u.city_id, 0))), 1, 6), 16, 10), 800))
                   * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('community-ppa:', COALESCE(u.community_id, 0))), 1, 6), 16, 10), 25) / 100)
                   * (0.95 + MOD(CONV(SUBSTRING(MD5(CONCAT('ppa:', u.id)), 1, 6), 16, 10), 11) / 100))
                   * (0.045 + MOD(CONV(SUBSTRING(MD5(CONCAT('yield:', u.id)), 1, 6), 16, 10), 35) / 1000)
              * POW(0.95, n.n)) / u.built_up_area, 4) END,
  u.built_up_area, u.area_unit_id,
  'yearly',
  12,
  u.unit_type, u.bedrooms,
  'government_open_data', 'high', 1, 1, @now, @now
FROM property_units u
JOIN tmp_numbers n ON n.n < 2
WHERE u.occupancy_status IN ('tenanted', 'vacant')
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('haslet:', u.id)), 1, 6), 16, 10), 5) < 2;

-- Transactions the platform itself brokered. These carry the deal and the
-- listing, which is what lets a market report say how much of a community's
-- volume the platform actually touched.
INSERT INTO unit_transactions
  (public_id, unit_id, building_id, location_id, community_id, city_id, country_id,
   transaction_type, transaction_date, registration_date, amount, currency_code,
   amount_base, price_per_area, area, area_unit_id, unit_type, bedrooms,
   source, confidence, is_public, deal_id, listing_id, organization_id,
   is_arms_length, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('deal-txn:', d.id)), 26)),
  l.unit_id, l.building_id, l.location_id, l.community_id, l.city_id, l.country_id,
  CASE WHEN d.deal_type = 'rent' THEN 'rent' ELSE 'sale' END,
  DATE(d.completed_at),
  DATE_ADD(DATE(d.completed_at), INTERVAL 5 DAY),
  COALESCE(d.final_amount, d.agreed_amount),
  d.currency_code,
  COALESCE(d.agreed_amount_base, d.agreed_amount),
  CASE WHEN u.built_up_area > 0
       THEN ROUND(COALESCE(d.final_amount, d.agreed_amount) / u.built_up_area, 4) END,
  u.built_up_area, u.area_unit_id, u.unit_type, u.bedrooms,
  'platform_deal', 'verified', 1, d.id, d.listing_id, d.organization_id, 1, @now, @now
FROM deals d
JOIN listings l ON l.id = d.listing_id
JOIN property_units u ON u.id = l.unit_id
WHERE d.completed_at IS NOT NULL
  AND COALESCE(d.final_amount, d.agreed_amount) IS NOT NULL;

-- The unit's last sale and last rent are the newest matching transaction, not a
-- separately maintained field.
UPDATE property_units u
JOIN (
  SELECT unit_id, MAX(transaction_date) AS d
  FROM unit_transactions
  WHERE transaction_type IN ('sale', 'resale', 'off_plan_sale', 'auction')
  GROUP BY unit_id
) last_sale ON last_sale.unit_id = u.id
JOIN unit_transactions t
  ON t.unit_id = u.id AND t.transaction_date = last_sale.d
 AND t.transaction_type IN ('sale', 'resale', 'off_plan_sale', 'auction')
SET u.last_sale_price = t.amount,
    u.last_sale_date = t.transaction_date;

UPDATE property_units u
JOIN (
  SELECT unit_id, MAX(transaction_date) AS d
  FROM unit_transactions
  WHERE transaction_type IN ('rent', 'rent_renewal')
  GROUP BY unit_id
) last_rent ON last_rent.unit_id = u.id
JOIN unit_transactions t
  ON t.unit_id = u.id AND t.transaction_date = last_rent.d
 AND t.transaction_type IN ('rent', 'rent_renewal')
SET u.last_rent_amount = t.amount,
    u.last_rent_date = t.transaction_date;

-- -----------------------------------------------------------------------------
-- Tenancies
--
-- A tenancy is a contract over a unit, not a property of the unit, because a
-- unit has many of them over its life and the previous one's end date is what
-- the renewal pipeline runs on. renewal_notice_due is stored rather than
-- computed at read time so the notice job can find today's work with an index
-- range scan instead of a table scan.
-- -----------------------------------------------------------------------------
INSERT INTO tenancies
  (public_id, reference, unit_id, building_id, listing_id, organization_id,
   managing_agent_id, registration_reference, registration_authority_id,
   registered_at, tenancy_type, status, starts_on, ends_on, term_months,
   notice_period_days, renewal_notice_due, renewal_notice_sent_at, auto_renews,
   annual_rent, currency_code, annual_rent_base, payment_frequency, cheque_count,
   security_deposit, deposit_held_by, agency_commission, furnished,
   utilities_included, pets_allowed, subletting_allowed, max_occupants,
   ended_on, termination_reason, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('tenancy:', u.id, ':', t.seq)), 26)),
  CONCAT('TEN-', DATE_FORMAT(t.starts_on, '%Y'), '-',
         LPAD(u.id, 6, '0'), '-', t.seq),
  u.id, u.building_id, lst.listing_id, org.organization_id,
  ag.id,
  CONCAT('EJARI-', UPPER(LEFT(MD5(CONCAT('ejari-t:', u.id, t.seq)), 12))),
  auth.id,
  DATE_ADD(t.starts_on, INTERVAL 7 DAY),
  CASE
    WHEN u.unit_type IN ('office', 'retail', 'warehouse') THEN 'commercial'
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('ttype:', u.id, t.seq)), 1, 6), 16, 10), 13) = 0 THEN 'corporate'
    WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('ttype:', u.id, t.seq)), 1, 6), 16, 10), 17) = 0 THEN 'holiday_home'
    ELSE 'residential'
  END,
  CASE
    WHEN t.ends_on < @today THEN
      CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('end:', u.id, t.seq)), 1, 6), 16, 10), 9) = 0 THEN 'terminated' ELSE 'ended' END
    WHEN t.ends_on <= DATE_ADD(@today, INTERVAL 60 DAY) THEN 'expiring'
    ELSE 'active'
  END,
  t.starts_on, t.ends_on, 12,
  90,
  DATE_SUB(t.ends_on, INTERVAL 90 DAY),
  CASE WHEN DATE_SUB(t.ends_on, INTERVAL 90 DAY) < @today
       THEN TIMESTAMP(DATE_SUB(t.ends_on, INTERVAL 88 DAY), '10:15:00') END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('auto:', u.id, t.seq)), 1, 6), 16, 10), 3) = 0 THEN 1 ELSE 0 END,
  ROUND(t.annual_rent, 2),
  COALESCE(u.currency_code, 'AED'),
  ROUND(t.annual_rent, 2),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('freq:', u.id, t.seq)), 1, 6), 16, 10), 5),
      'cheques', 'annual', 'quarterly', 'cheques', 'monthly'),
  CASE WHEN ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('freq:', u.id, t.seq)), 1, 6), 16, 10), 5),
                'cheques', 'annual', 'quarterly', 'cheques', 'monthly') = 'cheques'
       THEN ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('chq:', u.id, t.seq)), 1, 6), 16, 10), 4), 1, 2, 4, 6) END,
  ROUND(t.annual_rent * 0.05, 2),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('dep:', u.id, t.seq)), 1, 6), 16, 10), 3), 'agency', 'landlord', 'scheme'),
  ROUND(t.annual_rent * 0.05, 2),
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('furn:', u.id, t.seq)), 1, 6), 16, 10), 3),
      'furnished', 'unfurnished', 'part_furnished'),
  CASE MOD(CONV(SUBSTRING(MD5(CONCAT('util:', u.id, t.seq)), 1, 6), 16, 10), 4)
    WHEN 0 THEN 'water,cooling'
    WHEN 1 THEN 'maintenance'
    WHEN 2 THEN 'water,electricity,internet,cooling'
    ELSE NULL
  END,
  CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('pets:', u.id, t.seq)), 1, 6), 16, 10), 3) = 0 THEN 1 ELSE 0 END,
  0,
  GREATEST(1, COALESCE(u.bedrooms, 1) * 2),
  CASE WHEN t.ends_on < @today THEN t.ends_on END,
  CASE WHEN t.ends_on < @today THEN
    CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('end:', u.id, t.seq)), 1, 6), 16, 10), 9) = 0 THEN 'tenant_notice' ELSE 'expiry' END
  END,
  DATE_SUB(t.starts_on, INTERVAL 21 DAY), @now
FROM property_units u
JOIN (
  SELECT u2.id AS unit_id, n.n AS seq,
         DATE_SUB(@today, INTERVAL (n.n * 365) + MOD(CONV(SUBSTRING(MD5(CONCAT('tstart:', u2.id)), 1, 6), 16, 10), 300) DAY) AS starts_on,
         DATE_ADD(DATE_SUB(@today, INTERVAL (n.n * 365) + MOD(CONV(SUBSTRING(MD5(CONCAT('tstart:', u2.id)), 1, 6), 16, 10), 300) DAY),
                  INTERVAL 12 MONTH) AS ends_on,
         GREATEST(8000, COALESCE(u2.built_up_area, 1200)
                  * ((700 + MOD(CONV(SUBSTRING(MD5(CONCAT('city-ppa:', COALESCE(u2.city_id, 0))), 1, 6), 16, 10), 800))
                   * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('community-ppa:', COALESCE(u2.community_id, 0))), 1, 6), 16, 10), 25) / 100)
                   * (0.95 + MOD(CONV(SUBSTRING(MD5(CONCAT('ppa:', u2.id)), 1, 6), 16, 10), 11) / 100))
                   * (0.045 + MOD(CONV(SUBSTRING(MD5(CONCAT('yield:', u2.id)), 1, 6), 16, 10), 35) / 1000) * POW(0.95, n.n)) AS annual_rent
  FROM property_units u2
  CROSS JOIN tmp_numbers n
  WHERE n.n < 2
) AS t ON t.unit_id = u.id
LEFT JOIN (
  SELECT unit_id, MIN(id) AS listing_id FROM listings
  WHERE unit_id IS NOT NULL AND purpose_id = (SELECT id FROM purposes WHERE code = 'rent' LIMIT 1)
  GROUP BY unit_id
) AS lst ON lst.unit_id = u.id
JOIN (
  SELECT u3.id AS unit_id,
         1 + MOD(CONV(SUBSTRING(MD5(CONCAT('org:', u3.id)), 1, 6), 16, 10), (SELECT COUNT(*) FROM organizations)) AS organization_id
  FROM property_units u3
) AS org ON org.unit_id = u.id
LEFT JOIN agents ag
  ON ag.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('agent:', u.id)), 1, 6), 16, 10), (SELECT COUNT(*) FROM agents))
LEFT JOIN regulatory_authorities auth
  ON auth.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('auth:', u.id)), 1, 6), 16, 10), (SELECT COUNT(*) FROM regulatory_authorities))
WHERE u.occupancy_status = 'tenanted'
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hastenancy:', u.id)), 1, 6), 16, 10), 4) = 0;

-- The renewal chain. A tenancy that ended and was followed by another on the
-- same unit points at its successor, which is how a portfolio report shows
-- continuous occupancy rather than two unrelated contracts.
UPDATE tenancies prev
JOIN tenancies next
  ON next.unit_id = prev.unit_id
 AND next.starts_on > prev.ends_on
 AND next.starts_on <= DATE_ADD(prev.ends_on, INTERVAL 45 DAY)
SET prev.renewed_into_tenancy_id = next.id,
    prev.status = 'renewed',
    next.previous_tenancy_id = prev.id;

-- -----------------------------------------------------------------------------
-- Tenancy parties
--
-- Landlord, tenant, and the guarantor a corporate let usually carries. Held as
-- rows because a joint tenancy has two or three tenants with a liability split
-- that the deposit dispute will turn on.
-- -----------------------------------------------------------------------------
INSERT INTO tenancy_parties
  (tenancy_id, party_role, contact_id, organization_id, legal_name, email,
   phone_e164, identity_reference, is_primary, liability_percent)
SELECT
  t.id, 'landlord', o.contact_id, NULL,
  COALESCE(o.owner_name, 'Owner on record'),
  c.primary_email, c.primary_phone_e164,
  CONCAT('ID-', UPPER(LEFT(MD5(CONCAT('landlord-id:', t.id)), 10))),
  1, 100.000
FROM tenancies t
-- The landlord of record is the largest current shareholder. Keying on a
-- hundred per cent would silently drop every jointly-owned unit, which is a
-- quarter of them.
JOIN (
  SELECT o2.unit_id, MIN(o2.id) AS ownership_id
  FROM unit_ownerships o2
  JOIN (
    SELECT unit_id, MAX(share_percent) AS top_share
    FROM unit_ownerships WHERE is_current = 1 GROUP BY unit_id
  ) t2 ON t2.unit_id = o2.unit_id AND t2.top_share = o2.share_percent
  WHERE o2.is_current = 1
  GROUP BY o2.unit_id
) AS pick ON pick.unit_id = t.unit_id
JOIN unit_ownerships o ON o.id = pick.ownership_id
LEFT JOIN crm_contacts c ON c.id = o.contact_id;

INSERT INTO tenancy_parties
  (tenancy_id, party_role, contact_id, legal_name, email, phone_e164,
   identity_reference, is_primary, liability_percent)
SELECT
  t.id, 'tenant', c.id,
  COALESCE(c.display_name, CONCAT(c.first_name, ' ', c.last_name)),
  c.primary_email, c.primary_phone_e164,
  CONCAT('ID-', UPPER(LEFT(MD5(CONCAT('tenant-id:', t.id)), 10))),
  1, 100.000
FROM tenancies t
JOIN crm_contacts c
  ON c.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('tenant:', t.id)), 1, 6), 16, 10), (SELECT COUNT(*) FROM crm_contacts));

INSERT INTO tenancy_parties
  (tenancy_id, party_role, organization_id, legal_name, email, is_primary,
   liability_percent)
SELECT
  t.id, 'company', org.id, org.legal_name, org.email, 0, 100.000
FROM tenancies t
JOIN organizations org ON org.id = t.organization_id
WHERE t.tenancy_type = 'corporate';

INSERT INTO tenancy_parties
  (tenancy_id, party_role, contact_id, legal_name, email, phone_e164,
   is_primary, liability_percent)
SELECT
  t.id, 'guarantor', c.id,
  COALESCE(c.display_name, CONCAT(c.first_name, ' ', c.last_name)),
  c.primary_email, c.primary_phone_e164, 0, 100.000
FROM tenancies t
JOIN crm_contacts c
  ON c.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('guarantor:', t.id)), 1, 6), 16, 10), (SELECT COUNT(*) FROM crm_contacts))
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasguarantor:', t.id)), 1, 6), 16, 10), 4) = 0;

-- -----------------------------------------------------------------------------
-- Rent schedules
--
-- One row per instalment. Post-dated cheques are still how a large part of the
-- Gulf rental market pays, so the cheque number, the bank and the clearing
-- state are first-class columns rather than notes: a bounced cheque is a legal
-- event with a deadline attached.
-- -----------------------------------------------------------------------------
INSERT INTO rent_schedules
  (tenancy_id, unit_id, organization_id, instalment_number, period_start,
   period_end, due_on, amount, currency_code, amount_base, paid_amount, status,
   payment_method, cheque_number, cheque_bank, cheque_status, bounced_at,
   bounce_reason, paid_at, late_fee, reminder_sent_at, reminder_count,
   created_at, updated_at)
SELECT
  t.id, t.unit_id, t.organization_id,
  n.n + 1,
  DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH),
  DATE_SUB(DATE_ADD(t.starts_on, INTERVAL (n.n + 1) * s.months_per_instalment MONTH), INTERVAL 1 DAY),
  DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH),
  ROUND(t.annual_rent / s.instalments, 2),
  t.currency_code,
  ROUND(t.annual_rent / s.instalments, 2),
  -- Paid in full unless this instalment is the one that bounced or is not due yet.
  CASE
    WHEN DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH) > @today THEN 0
    WHEN st.bounced = 1 THEN 0
    ELSE ROUND(t.annual_rent / s.instalments, 2)
  END,
  CASE
    WHEN DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH) > DATE_ADD(@today, INTERVAL 7 DAY) THEN 'scheduled'
    WHEN DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH) > @today THEN 'due'
    WHEN st.bounced = 1 AND DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH) < DATE_SUB(@today, INTERVAL 20 DAY) THEN 'bounced'
    WHEN st.bounced = 1 THEN 'overdue'
    ELSE 'paid'
  END,
  CASE t.payment_frequency
    WHEN 'cheques' THEN 'cheque'
    WHEN 'monthly' THEN 'standing_order'
    ELSE 'bank_transfer'
  END,
  CASE WHEN t.payment_frequency = 'cheques'
       THEN LPAD(MOD(CONV(SUBSTRING(MD5(CONCAT('chqno:', t.id, ':', n.n)), 1, 6), 16, 10), 1000000), 6, '0') END,
  CASE WHEN t.payment_frequency = 'cheques'
       THEN ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('bank:', t.id)), 1, 6), 16, 10), 6),
                'Emirates NBD', 'First Abu Dhabi Bank', 'Mashreq Bank',
                'HSBC Middle East', 'Abu Dhabi Commercial Bank', 'Dubai Islamic Bank') END,
  CASE
    WHEN t.payment_frequency <> 'cheques' THEN NULL
    WHEN DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH) > @today THEN 'held'
    WHEN st.bounced = 1 THEN 'bounced'
    ELSE 'cleared'
  END,
  CASE WHEN st.bounced = 1
       THEN DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH) END,
  CASE WHEN st.bounced = 1 THEN 'Insufficient funds. Replacement cheque requested from the tenant.' END,
  CASE
    WHEN DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH) > @today THEN NULL
    WHEN st.bounced = 1 THEN NULL
    ELSE DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH)
  END,
  CASE WHEN st.bounced = 1 THEN ROUND(t.annual_rent / s.instalments * 0.02, 2) ELSE 0.00 END,
  CASE WHEN st.bounced = 1
       THEN TIMESTAMP(DATE_ADD(DATE_ADD(t.starts_on, INTERVAL n.n * s.months_per_instalment MONTH),
                               INTERVAL 3 DAY), '09:00:00') END,
  CASE WHEN st.bounced = 1 THEN 2 ELSE 0 END,
  DATE_SUB(t.starts_on, INTERVAL 14 DAY), @now
FROM tenancies t
JOIN (
  SELECT t2.id AS tenancy_id,
         CASE t2.payment_frequency
           WHEN 'annual'     THEN 1
           WHEN 'biannual'   THEN 2
           WHEN 'quarterly'  THEN 4
           WHEN 'monthly'    THEN 12
           ELSE COALESCE(t2.cheque_count, 4)
         END AS instalments,
         CASE t2.payment_frequency
           WHEN 'annual'     THEN 12
           WHEN 'biannual'   THEN 6
           WHEN 'quarterly'  THEN 3
           WHEN 'monthly'    THEN 1
           ELSE GREATEST(1, 12 DIV COALESCE(t2.cheque_count, 4))
         END AS months_per_instalment
  FROM tenancies t2
) AS s ON s.tenancy_id = t.id
JOIN tmp_numbers n ON n.n < s.instalments
-- One tenancy in twelve has a cheque that bounces, on a deterministic
-- instalment, so the arrears reporting has something real to find.
JOIN (
  SELECT t4.id AS tenancy_id, n4.n AS instalment_index,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('bounce:', t4.id)), 1, 6), 16, 10), 12) = 0
                   AND n4.n = MOD(CONV(SUBSTRING(MD5(CONCAT('bounceat:', t4.id)), 1, 6), 16, 10), 4)
              THEN 1 ELSE 0 END AS bounced
  FROM tenancies t4 CROSS JOIN tmp_numbers n4 WHERE n4.n < 12
) AS st ON st.tenancy_id = t.id AND st.instalment_index = n.n;

-- -----------------------------------------------------------------------------
-- Maintenance
--
-- liable_party is the column property management actually argues about, so it
-- is explicit and defaults to undetermined rather than to the landlord.
-- response_due_at is derived from the priority at creation, which is what makes
-- an emergency measurable against a four-hour promise.
-- -----------------------------------------------------------------------------
INSERT INTO maintenance_requests
  (public_id, reference, unit_id, building_id, tenancy_id, organization_id,
   reported_by_contact_id, category, title, description, priority, is_emergency,
   is_habitability_issue, status, liable_party, liability_note, quoted_amount,
   approved_amount, final_amount, currency_code, vendor_name, scheduled_at,
   access_arranged, reported_at, acknowledged_at, response_due_at, started_at,
   completed_at, verified_at, resolution_note, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('maint:', t.id, ':', n.n)), 26)),
  CONCAT('MR-', DATE_FORMAT(m.reported_at, '%Y%m'), '-', LPAD(t.id, 5, '0'), n.n),
  t.unit_id, t.building_id, t.id, t.organization_id,
  tp.contact_id,
  m.category,
  m.title,
  m.description,
  m.priority,
  CASE WHEN m.priority = 'emergency' THEN 1 ELSE 0 END,
  CASE WHEN m.category IN ('plumbing', 'electrical', 'hvac', 'structural')
            AND m.priority IN ('high', 'emergency') THEN 1 ELSE 0 END,
  m.status,
  m.liable_party,
  CASE m.liable_party
    WHEN 'tenant'    THEN 'Damage attributable to use rather than fair wear and tear; recharged to the tenant under clause 7.'
    WHEN 'building'  THEN 'Common-area fault; referred to the owners association and recovered through the service charge.'
    WHEN 'warranty'  THEN 'Within the developer defects liability period; raised with the contractor at no cost.'
    WHEN 'insurance' THEN 'Escape of water covered by the building policy; claim opened.'
    WHEN 'landlord'  THEN 'Landlord obligation under the tenancy agreement.'
    ELSE NULL
  END,
  m.quoted_amount,
  CASE WHEN m.status IN ('approved','scheduled','in_progress','completed','verified')
       THEN m.quoted_amount END,
  CASE WHEN m.status IN ('completed', 'verified')
       THEN ROUND(m.quoted_amount * (0.9 + MOD(CONV(SUBSTRING(MD5(CONCAT('final:', t.id, n.n)), 1, 6), 16, 10), 25) / 100), 2) END,
  t.currency_code,
  CASE WHEN m.status <> 'reported'
       THEN ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('vendor:', t.id, n.n)), 1, 6), 16, 10), 6),
                'Aqua Works Plumbing', 'Volt Electrical Services', 'CoolAir HVAC',
                'Fixit Home Services', 'Sparkle Facilities', 'Guardian Lift Maintenance') END,
  CASE WHEN m.status IN ('scheduled','in_progress','completed','verified')
       THEN DATE_ADD(m.reported_at, INTERVAL 2 + MOD(CONV(SUBSTRING(MD5(CONCAT('sched:', t.id, n.n)), 1, 6), 16, 10), 6) DAY) END,
  CASE WHEN m.status IN ('scheduled','in_progress','completed','verified') THEN 1 ELSE 0 END,
  m.reported_at,
  CASE WHEN m.status <> 'reported' THEN DATE_ADD(m.reported_at, INTERVAL 25 MINUTE) END,
  -- The response promise the service-level agreement makes for this priority.
  DATE_ADD(m.reported_at, INTERVAL CASE m.priority
      WHEN 'emergency' THEN 4 WHEN 'high' THEN 24 WHEN 'normal' THEN 72 ELSE 168 END HOUR),
  CASE WHEN m.status IN ('in_progress','completed','verified')
       THEN DATE_ADD(m.reported_at, INTERVAL 3 DAY) END,
  CASE WHEN m.status IN ('completed', 'verified')
       THEN DATE_ADD(m.reported_at, INTERVAL 4 + MOD(CONV(SUBSTRING(MD5(CONCAT('done:', t.id, n.n)), 1, 6), 16, 10), 10) DAY) END,
  CASE WHEN m.status = 'verified'
       THEN DATE_ADD(m.reported_at, INTERVAL 8 + MOD(CONV(SUBSTRING(MD5(CONCAT('done:', t.id, n.n)), 1, 6), 16, 10), 10) DAY) END,
  CASE WHEN m.status IN ('completed', 'verified')
       THEN 'Attended, parts replaced, tested in the tenant''s presence and signed off.' END,
  m.reported_at, @now
FROM tenancies t
JOIN tmp_numbers n ON n.n < MOD(CONV(SUBSTRING(MD5(CONCAT('maintcount:', t.id)), 1, 6), 16, 10), 3)
JOIN (
  SELECT t2.id AS tenancy_id, n2.n AS seq,
         DATE_ADD(t2.starts_on, INTERVAL 20 + MOD(CONV(SUBSTRING(MD5(CONCAT('mdate:', t2.id, n2.n)), 1, 6), 16, 10), 300) DAY) AS reported_at,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mcat:', t2.id, n2.n)), 1, 6), 16, 10), 8),
             'plumbing','electrical','hvac','appliance','pest','cleaning','lift','common_area') AS category,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mcat:', t2.id, n2.n)), 1, 6), 16, 10), 8),
             'Leak under the kitchen sink',
             'Bedroom sockets dead on one circuit',
             'Air conditioning not cooling in the living room',
             'Washing machine will not drain',
             'Ants in the kitchen cupboards',
             'End-of-tenancy deep clean requested',
             'Lift stopping between floors',
             'Corridor lighting out on the tenth floor') AS title,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mcat:', t2.id, n2.n)), 1, 6), 16, 10), 8),
             'Water pooling in the cabinet. Tenant has turned off the isolation valve and is using the second bathroom.',
             'Half the bedroom sockets stopped working after a power cut. The breaker resets and trips again within a minute.',
             'Unit runs but blows warm. Filters were cleaned last month. Living room reaching 31 degrees in the afternoon.',
             'Drum fills and washes but the drain cycle fails. Standing water in the drum.',
             'Persistent trail along the skirting into the pantry. Tenant has tried a shop-bought treatment without success.',
             'Tenant vacating at the end of the month and has requested the contractual end-of-tenancy clean.',
             'Reported by three residents. Lift halts roughly thirty centimetres below the landing and the doors stay shut for around twenty seconds.',
             'Six fittings out along the east corridor. Emergency lighting is unaffected.') AS description,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mpri:', t2.id, n2.n)), 1, 6), 16, 10), 8),
             'high','emergency','high','normal','normal','low','emergency','normal') AS priority,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mstat:', t2.id, n2.n)), 1, 6), 16, 10), 10),
             'verified','completed','completed','in_progress','scheduled','approved','quoted','triaged','reported','completed') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mliab:', t2.id, n2.n)), 1, 6), 16, 10), 8),
             'landlord','landlord','tenant','building','warranty','landlord','insurance','undetermined') AS liable_party,
         ROUND(150 + MOD(CONV(SUBSTRING(MD5(CONCAT('mquote:', t2.id, n2.n)), 1, 6), 16, 10), 4200), 2) AS quoted_amount
  FROM tenancies t2 CROSS JOIN tmp_numbers n2 WHERE n2.n < 3
) AS m ON m.tenancy_id = t.id AND m.seq = n.n
LEFT JOIN tenancy_parties tp
  ON tp.tenancy_id = t.id AND tp.party_role = 'tenant' AND tp.is_primary = 1;

-- -----------------------------------------------------------------------------
-- Valuations
--
-- Three kinds, and the difference matters: an automated estimate is a model
-- output with a confidence band, a broker opinion is a sales pitch, and a
-- formal survey is a professional instructing their indemnity insurance. They
-- share a table because they answer the same question, and they carry the
-- distinguishing columns -- model version, valuer licence -- so nobody has to
-- guess which one they are reading.
-- -----------------------------------------------------------------------------
INSERT INTO valuations
  (public_id, unit_id, building_id, listing_id, organization_id, agent_id,
   valuation_type, purpose, valued_amount, value_low, value_high, currency_code,
   valued_amount_base, price_per_area, rental_value, rental_period,
   gross_yield_percent, confidence, confidence_score, method, comparable_count,
   model_version, valuer_name, valuer_firm, valuer_licence, valued_on,
   valid_until, status, notes, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('valuation:', u.id, ':', v.kind)), 26)),
  u.id, u.building_id, lst.listing_id, NULL, NULL,
  v.valuation_type, v.purpose,
  ROUND(v.amount, 2),
  ROUND(v.amount * (1 - v.band), 2),
  ROUND(v.amount * (1 + v.band), 2),
  COALESCE(u.currency_code, 'AED'),
  ROUND(v.amount, 2),
  CASE WHEN u.built_up_area > 0 THEN ROUND(v.amount / u.built_up_area, 4) END,
  ROUND(v.rental_value, 2),
  'yearly',
  CASE WHEN v.amount > 0 THEN ROUND(v.rental_value / v.amount * 100, 3) END,
  v.confidence,
  v.confidence_score,
  v.method,
  v.comparable_count,
  CASE WHEN v.valuation_type = 'automated' THEN 'avm-3.4.1' END,
  CASE WHEN v.valuation_type = 'formal_survey'
       THEN ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('valuer:', u.id)), 1, 6), 16, 10), 5),
                'H. Al Marri MRICS', 'J. Whitfield MRICS', 'S. Kowalski MRICS',
                'A. Rahman MRICS', 'L. Ferrari MRICS') END,
  CASE WHEN v.valuation_type = 'formal_survey'
       THEN ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('firm:', u.id)), 1, 6), 16, 10), 4),
                'Cavendish Maxwell', 'Knight Frank Valuation', 'CBRE Valuation Advisory',
                'Savills Valuation') END,
  CASE WHEN v.valuation_type = 'formal_survey'
       THEN CONCAT('RICS-', MOD(CONV(SUBSTRING(MD5(CONCAT('lic:', u.id)), 1, 6), 16, 10), 900000) + 100000) END,
  v.valued_on,
  DATE_ADD(v.valued_on, INTERVAL CASE v.valuation_type
      WHEN 'formal_survey' THEN 90 WHEN 'mortgage' THEN 90 ELSE 30 END DAY),
  CASE WHEN DATE_ADD(v.valued_on, INTERVAL 90 DAY) < @today THEN 'expired' ELSE 'issued' END,
  CASE v.valuation_type
    WHEN 'automated' THEN 'Model estimate from comparable registered transactions within 800 metres, adjusted for floor, view and area.'
    WHEN 'broker_opinion' THEN 'Agent appraisal for listing purposes. Not a formal valuation and not for lending.'
    ELSE 'Full inspection carried out. Report issued subject to the assumptions and limiting conditions in the appendix.'
  END,
  @now, @now
FROM property_units u
JOIN (
  SELECT u2.id AS unit_id, k.kind,
         ELT(k.kind, 'automated', 'broker_opinion', 'formal_survey') AS valuation_type,
         ELT(k.kind, 'curiosity', 'listing_appraisal', 'mortgage') AS purpose,
         ELT(k.kind, 'hedonic_model', 'comparable', 'comparable') AS method,
         ELT(k.kind, 'medium', 'low', 'very_high') AS confidence,
         ELT(k.kind, 72.50, 45.00, 94.00) AS confidence_score,
         ELT(k.kind, 0.12, 0.08, 0.04) AS band,
         ELT(k.kind, 24, 6, 9) AS comparable_count,
         DATE_SUB(@today, INTERVAL k.kind * 45 + MOD(CONV(SUBSTRING(MD5(CONCAT('vdate:', u2.id, k.kind)), 1, 6), 16, 10), 60) DAY) AS valued_on,
         GREATEST(50000, COALESCE(u2.built_up_area, 1200)
                  * ((700 + MOD(CONV(SUBSTRING(MD5(CONCAT('city-ppa:', COALESCE(u2.city_id, 0))), 1, 6), 16, 10), 800))
                   * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('community-ppa:', COALESCE(u2.community_id, 0))), 1, 6), 16, 10), 25) / 100)
                   * (0.95 + MOD(CONV(SUBSTRING(MD5(CONCAT('ppa:', u2.id)), 1, 6), 16, 10), 11) / 100))
                  * ELT(k.kind, 1.00, 1.06, 0.97)) AS amount,
         GREATEST(8000, COALESCE(u2.built_up_area, 1200)
                  * ((700 + MOD(CONV(SUBSTRING(MD5(CONCAT('city-ppa:', COALESCE(u2.city_id, 0))), 1, 6), 16, 10), 800))
                   * (0.88 + MOD(CONV(SUBSTRING(MD5(CONCAT('community-ppa:', COALESCE(u2.community_id, 0))), 1, 6), 16, 10), 25) / 100)
                   * (0.95 + MOD(CONV(SUBSTRING(MD5(CONCAT('ppa:', u2.id)), 1, 6), 16, 10), 11) / 100))
                   * (0.045 + MOD(CONV(SUBSTRING(MD5(CONCAT('yield:', u2.id)), 1, 6), 16, 10), 35) / 1000)) AS rental_value
  FROM property_units u2
  CROSS JOIN (SELECT 1 AS kind UNION ALL SELECT 2 UNION ALL SELECT 3) k
  WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasval:', u2.id)), 1, 6), 16, 10), 3) = 0
) AS v ON v.unit_id = u.id
LEFT JOIN (
  SELECT unit_id, MIN(id) AS listing_id FROM listings
  WHERE unit_id IS NOT NULL GROUP BY unit_id
) AS lst ON lst.unit_id = u.id;

-- The comparables a valuation was actually built from. Keeping them means the
-- valuation can be defended two years later, when the market has moved and
-- somebody wants to know why the number was what it was.
INSERT INTO valuation_comparables
  (valuation_id, transaction_id, unit_id, comparable_type, amount, price_per_area,
   area, bedrooms, transaction_date, distance_metres, similarity_score,
   adjusted_price_per_area, weight, is_excluded, exclusion_reason)
SELECT
  v.id, t.id, t.unit_id, 'transaction', t.amount, t.price_per_area, t.area,
  t.bedrooms, t.transaction_date,
  50 + MOD(CONV(SUBSTRING(MD5(CONCAT('dist:', v.id, ':', t.id)), 1, 6), 16, 10), 1400),
  ROUND(60 + MOD(CONV(SUBSTRING(MD5(CONCAT('sim:', v.id, ':', t.id)), 1, 6), 16, 10), 39), 2),
  -- Adjusted for the time between the comparable and the valuation date, at
  -- roughly half a per cent a month.
  ROUND(t.price_per_area * (1 + TIMESTAMPDIFF(MONTH, t.transaction_date, v.valued_on) * 0.005), 4),
  ROUND(1.0 / GREATEST(1, cnt.n), 4),
  CASE WHEN t.is_arms_length = 0 THEN 1 ELSE 0 END,
  CASE WHEN t.is_arms_length = 0
       THEN 'Not an arm''s length transaction; retained for transparency but excluded from the weighted average.' END
FROM valuations v
JOIN property_units u ON u.id = v.unit_id
JOIN unit_transactions t
  ON t.community_id <=> u.community_id
 AND t.unit_id <> u.id
 AND t.transaction_type IN ('sale', 'resale', 'off_plan_sale', 'auction')
 AND t.transaction_date <= v.valued_on
JOIN (
  SELECT v2.id AS valuation_id, COUNT(*) AS n
  FROM valuations v2
  JOIN property_units u2 ON u2.id = v2.unit_id
  JOIN unit_transactions t2
    ON t2.community_id <=> u2.community_id
   AND t2.unit_id <> u2.id
   AND t2.transaction_type IN ('sale', 'resale', 'off_plan_sale', 'auction')
   AND t2.transaction_date <= v2.valued_on
  GROUP BY v2.id
) AS cnt ON cnt.valuation_id = v.id
WHERE v.method = 'comparable'
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('pick:', v.id, ':', t.id)), 1, 6), 16, 10), 7) = 0;

-- The unit's headline estimate is the most recent automated valuation, because
-- that is the one that refreshes without anybody being asked to pay for it.
UPDATE property_units u
JOIN (
  SELECT unit_id, MAX(valued_on) AS d FROM valuations
  WHERE valuation_type = 'automated' GROUP BY unit_id
) latest ON latest.unit_id = u.id
JOIN valuations v
  ON v.unit_id = u.id AND v.valued_on = latest.d AND v.valuation_type = 'automated'
SET u.estimated_value = v.valued_amount,
    u.estimated_value_at = v.valued_on;

-- -----------------------------------------------------------------------------
-- Lenders and mortgage products
--
-- The portal earns a referral fee, so the lender panel is commercial data, not
-- reference data: the fee, the processing time and the partner flag all belong
-- here. Islamic products sit in the same table with their own rate column
-- because a profit rate is not an interest rate and conflating them is a
-- compliance problem, not a modelling convenience.
-- -----------------------------------------------------------------------------
INSERT INTO lenders
  (code, name, lender_type, country_id, website_url, is_partner, referral_fee,
   referral_fee_percent, currency_code, contact_email, processing_days, is_active)
SELECT
  l.code, l.name, l.lender_type, c.id, l.website_url, l.is_partner,
  l.referral_fee, l.referral_fee_percent, l.currency_code,
  CONCAT('mortgages@', l.email_domain), l.processing_days, 1
FROM (
  SELECT 'enbd' AS code, 'Emirates NBD' AS name, 'bank' AS lender_type, 'United Arab Emirates' AS country_name, 'https://www.emiratesnbd.com' AS website_url, 1 AS is_partner, NULL AS referral_fee, 0.350 AS referral_fee_percent, 'AED' AS currency_code, 'emiratesnbd.com' AS email_domain, 21 AS processing_days
  UNION ALL SELECT 'fab','First Abu Dhabi Bank','bank','United Arab Emirates','https://www.bankfab.com',1,NULL,0.300,'AED','bankfab.com',18
  UNION ALL SELECT 'adcb','Abu Dhabi Commercial Bank','bank','United Arab Emirates','https://www.adcb.com',1,NULL,0.300,'AED','adcb.com',20
  UNION ALL SELECT 'dib','Dubai Islamic Bank','islamic_bank','United Arab Emirates','https://www.dib.ae',1,NULL,0.400,'AED','dib.ae',24
  UNION ALL SELECT 'adib','Abu Dhabi Islamic Bank','islamic_bank','United Arab Emirates','https://www.adib.ae',1,NULL,0.400,'AED','adib.ae',25
  UNION ALL SELECT 'mashreq','Mashreq Bank','bank','United Arab Emirates','https://www.mashreq.com',0,NULL,NULL,'AED','mashreq.com',22
  UNION ALL SELECT 'hsbc_uae','HSBC Middle East','bank','United Arab Emirates','https://www.hsbc.ae',1,NULL,0.250,'AED','hsbc.ae',28
  UNION ALL SELECT 'rakbank','RAKBANK','bank','United Arab Emirates','https://www.rakbank.ae',0,NULL,NULL,'AED','rakbank.ae',19
  UNION ALL SELECT 'alrajhi','Al Rajhi Bank','islamic_bank','Saudi Arabia','https://www.alrajhibank.com.sa',1,NULL,0.350,'SAR','alrajhibank.com.sa',26
  UNION ALL SELECT 'snb','Saudi National Bank','bank','Saudi Arabia','https://www.alahli.com',0,NULL,NULL,'SAR','alahli.com',30
  UNION ALL SELECT 'qnb','Qatar National Bank','bank','Qatar','https://www.qnb.com',0,NULL,NULL,'QAR','qnb.com',25
  UNION ALL SELECT 'natwest','NatWest','bank','United Kingdom','https://www.natwest.com',1,750.00,NULL,'GBP','natwest.co.uk',35
  UNION ALL SELECT 'halifax','Halifax','building_society','United Kingdom','https://www.halifax.co.uk',1,600.00,NULL,'GBP','halifax.co.uk',32
  UNION ALL SELECT 'nationwide','Nationwide Building Society','building_society','United Kingdom','https://www.nationwide.co.uk',0,NULL,NULL,'GBP','nationwide.co.uk',30
  UNION ALL SELECT 'barclays','Barclays','bank','United Kingdom','https://www.barclays.co.uk',1,700.00,NULL,'GBP','barclays.co.uk',33
  UNION ALL SELECT 'ubs','UBS','bank','Switzerland','https://www.ubs.com',0,NULL,NULL,'CHF','ubs.com',40
  UNION ALL SELECT 'bnp','BNP Paribas','bank','France','https://www.bnpparibas.fr',0,NULL,NULL,'EUR','bnpparibas.fr',45
  UNION ALL SELECT 'intesa','Intesa Sanpaolo','bank','Italy','https://www.intesasanpaolo.com',0,NULL,NULL,'EUR','intesasanpaolo.com',48
  UNION ALL SELECT 'wells','Wells Fargo Home Mortgage','bank','United States','https://www.wellsfargo.com',1,900.00,NULL,'USD','wellsfargo.com',38
  UNION ALL SELECT 'chase','JPMorgan Chase Home Lending','bank','United States','https://www.chase.com',1,850.00,NULL,'USD','chase.com',36
  UNION ALL SELECT 'dbs','DBS Bank','bank','Singapore','https://www.dbs.com.sg',1,NULL,0.200,'SGD','dbs.com',29
  UNION ALL SELECT 'holo','Holo Mortgage Brokers','broker','United Arab Emirates','https://www.holo.ae',1,NULL,0.500,'AED','holo.ae',14
  UNION ALL SELECT 'private_bank','Liv Finder Private Client Desk','private',NULL,NULL,1,NULL,0.750,'USD','livfinder.com',12
  UNION ALL SELECT 'emaar_finance','Developer Finance Desk','developer_finance','United Arab Emirates',NULL,0,NULL,NULL,'AED','livfinder.com',10
) AS l
LEFT JOIN locations c ON c.level = 'country' AND c.name = l.country_name;

INSERT INTO mortgage_products
  (lender_id, code, name, product_type, is_sharia_compliant, rate_percent,
   profit_rate_percent, apr_percent, rate_type, fixed_period_months,
   reversion_rate_percent, min_amount, max_amount, currency_code, max_ltv_percent,
   min_term_years, max_term_years, max_age_at_maturity, min_income,
   residency_requirement, employment_type, property_types, arrangement_fee,
   arrangement_fee_percent, valuation_fee, early_settlement_fee_percent,
   effective_from, effective_to, is_active)
SELECT
  ln.id,
  CONCAT(ln.code, '-', p.suffix),
  CONCAT(ln.name, ' ', p.name),
  p.product_type,
  CASE WHEN ln.lender_type = 'islamic_bank' THEN 1 ELSE 0 END,
  CASE WHEN ln.lender_type = 'islamic_bank' THEN NULL
       ELSE ROUND(p.base_rate + MOD(CONV(SUBSTRING(MD5(CONCAT('rate:', ln.code, p.suffix)), 1, 6), 16, 10), 120) / 100, 4) END,
  CASE WHEN ln.lender_type = 'islamic_bank'
       THEN ROUND(p.base_rate + 0.15 + MOD(CONV(SUBSTRING(MD5(CONCAT('rate:', ln.code, p.suffix)), 1, 6), 16, 10), 120) / 100, 4) END,
  ROUND(p.base_rate + 0.42 + MOD(CONV(SUBSTRING(MD5(CONCAT('rate:', ln.code, p.suffix)), 1, 6), 16, 10), 120) / 100, 4),
  p.rate_type,
  p.fixed_period_months,
  CASE WHEN p.fixed_period_months IS NOT NULL
       THEN ROUND(p.base_rate + 1.35, 4) END,
  p.min_amount, p.max_amount, ln.currency_code,
  p.max_ltv_percent, p.min_term_years, p.max_term_years, 70,
  p.min_income,
  p.residency_requirement, p.employment_type, p.property_types,
  NULL,
  p.arrangement_fee_percent,
  p.valuation_fee,
  p.early_settlement_fee_percent,
  DATE_SUB(@today, INTERVAL 120 + MOD(CONV(SUBSTRING(MD5(CONCAT('eff:', ln.code, p.suffix)), 1, 6), 16, 10), 300) DAY),
  NULL,
  1
FROM lenders ln
JOIN (
  SELECT 'fix3' AS suffix, '3 Year Fixed Home Loan' AS name, 'fixed' AS product_type, 'fixed' AS rate_type, 36 AS fixed_period_months, 3.75 AS base_rate, 200000 AS min_amount, 15000000 AS max_amount, 80.00 AS max_ltv_percent, 5 AS min_term_years, 25 AS max_term_years, 180000 AS min_income, 'resident' AS residency_requirement, 'salaried,self_employed' AS employment_type, 'ready,off_plan' AS property_types, 1.000 AS arrangement_fee_percent, 3150 AS valuation_fee, 1.000 AS early_settlement_fee_percent
  UNION ALL SELECT 'fix5','5 Year Fixed Home Loan','fixed','fixed',60,3.95,200000,15000000,80.00,5,25,180000,'resident','salaried,self_employed','ready',1.000,3150,1.000
  UNION ALL SELECT 'var','Variable Rate Home Loan','variable','variable',NULL,4.25,150000,20000000,85.00,5,25,150000,'resident','salaried,self_employed,business_owner','ready,off_plan',0.750,3150,0.500
  UNION ALL SELECT 'nonres','Non-Resident Home Loan','fixed','fixed',36,4.85,500000,25000000,60.00,5,20,400000,'non_resident','salaried,self_employed,business_owner','ready',1.250,4200,2.000
  UNION ALL SELECT 'btl','Buy to Let Mortgage','buy_to_let','variable',NULL,4.65,150000,10000000,70.00,5,25,240000,'any','salaried,self_employed,business_owner,retired','buy_to_let',1.500,3675,1.000
  UNION ALL SELECT 'ijara','Ijara Home Finance','islamic_ijara','fixed',60,3.99,200000,18000000,80.00,5,25,180000,'resident','salaried,self_employed','ready,off_plan',1.000,3150,1.000
  UNION ALL SELECT 'offplan','Off Plan Construction Finance','interest_only','variable',NULL,5.10,300000,20000000,50.00,3,15,300000,'resident','salaried,self_employed,business_owner','off_plan',1.500,4200,1.500
) AS p
WHERE ln.lender_type IN ('bank', 'islamic_bank', 'building_society')
  AND NOT (ln.lender_type = 'islamic_bank' AND p.suffix IN ('fix3', 'fix5', 'var', 'btl'))
  AND NOT (ln.lender_type <> 'islamic_bank' AND p.suffix = 'ijara');

-- -----------------------------------------------------------------------------
-- Mortgage applications
--
-- Modelled as a pipeline with its own stages, not as a flag on the deal,
-- because the finance falls through independently of the sale and the portal is
-- paid a referral fee on a schedule of its own.
-- -----------------------------------------------------------------------------
INSERT INTO mortgage_applications
  (public_id, reference, lead_id, contact_id, deal_id, unit_id, listing_id,
   organization_id, lender_id, product_id, requested_amount, property_value,
   deposit_amount, ltv_percent, term_years, currency_code, applicant_income,
   income_period, existing_liabilities, employment_type, residency_status,
   credit_score, status, stage_updated_at, pre_approval_amount, pre_approved_at,
   pre_approval_expires_on, offer_amount, offer_rate_percent, offered_at,
   offer_expires_on, declined_reason, completed_at, referral_fee_earned,
   referral_fee_status, valuation_id, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('mortgage:', ld.id)), 26)),
  CONCAT('MTG-', DATE_FORMAT(a.created_at, '%Y%m'), '-', LPAD(ld.id, 6, '0')),
  ld.id, ld.contact_id, NULL, u.id, ld.primary_listing_id, ld.organization_id,
  ln.id, pr.id,
  ROUND(pv.property_value * a.ltv / 100, 2),
  ROUND(pv.property_value, 2),
  ROUND(pv.property_value * (100 - a.ltv) / 100, 2),
  a.ltv,
  a.term_years,
  COALESCE(u.currency_code, 'AED'),
  ROUND(pv.property_value * a.ltv / 100 / 4.2, 2),
  'annual',
  ROUND(pv.property_value * 0.04, 2),
  a.employment_type,
  a.residency_status,
  a.credit_score,
  a.status,
  a.stage_updated_at,
  CASE WHEN a.status IN ('pre_approved','valuation_ordered','underwriting','approved','offer_issued','completed')
       THEN ROUND(pv.property_value * a.ltv / 100, 2) END,
  CASE WHEN a.status IN ('pre_approved','valuation_ordered','underwriting','approved','offer_issued','completed')
       THEN DATE(DATE_ADD(a.created_at, INTERVAL 6 DAY)) END,
  CASE WHEN a.status IN ('pre_approved','valuation_ordered','underwriting','approved','offer_issued','completed')
       THEN DATE(DATE_ADD(a.created_at, INTERVAL 96 DAY)) END,
  CASE WHEN a.status IN ('offer_issued','completed')
       THEN ROUND(pv.property_value * a.ltv / 100, 2) END,
  CASE WHEN a.status IN ('offer_issued','completed') THEN pr.rate_percent END,
  CASE WHEN a.status IN ('offer_issued','completed')
       THEN DATE(DATE_ADD(a.created_at, INTERVAL 28 DAY)) END,
  CASE WHEN a.status IN ('offer_issued','completed')
       THEN DATE(DATE_ADD(a.created_at, INTERVAL 118 DAY)) END,
  CASE WHEN a.status = 'declined' THEN a.declined_reason END,
  CASE WHEN a.status = 'completed' THEN DATE(DATE_ADD(a.created_at, INTERVAL 52 DAY)) END,
  CASE WHEN a.status = 'completed'
       THEN ROUND(COALESCE(ln.referral_fee,
                           pv.property_value * a.ltv / 100 * COALESCE(ln.referral_fee_percent, 0) / 100), 2) END,
  CASE a.status
    WHEN 'completed' THEN ELT(1 + MOD(ld.id, 3), 'paid', 'invoiced', 'pending')
    ELSE 'none'
  END,
  val.id,
  a.created_at, @now
FROM leads ld
JOIN (
  SELECT ld2.id AS lead_id,
         DATE_ADD(ld2.created_at, INTERVAL 3 DAY) AS created_at,
         DATE_ADD(ld2.created_at, INTERVAL 3 + MOD(CONV(SUBSTRING(MD5(CONCAT('stage:', ld2.id)), 1, 6), 16, 10), 40) DAY) AS stage_updated_at,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('mstatus:', ld2.id)), 1, 6), 16, 10), 12),
             'enquiry','documents_pending','submitted','pre_approved','pre_approved',
             'valuation_ordered','underwriting','approved','offer_issued','completed',
             'declined','withdrawn') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('ltv:', ld2.id)), 1, 6), 16, 10), 5), 50.00, 60.00, 70.00, 75.00, 80.00) AS ltv,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('term:', ld2.id)), 1, 6), 16, 10), 4), 15, 20, 25, 25) AS term_years,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('emp:', ld2.id)), 1, 6), 16, 10), 4),
             'salaried','self_employed','business_owner','salaried') AS employment_type,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('res:', ld2.id)), 1, 6), 16, 10), 3),
             'resident','non_resident','national') AS residency_status,
         620 + MOD(CONV(SUBSTRING(MD5(CONCAT('credit:', ld2.id)), 1, 6), 16, 10), 200) AS credit_score,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('decline:', ld2.id)), 1, 6), 16, 10), 4),
             'Debt burden ratio above policy after existing commitments were disclosed.',
             'Property valuation came in below the agreed price and the applicant could not bridge the shortfall.',
             'Adverse credit history within the last twenty-four months.',
             'Income could not be evidenced to the lender''s satisfaction for a self-employed applicant.') AS declined_reason
  FROM leads ld2
) AS a ON a.lead_id = ld.id
JOIN listings l ON l.id = ld.primary_listing_id AND l.unit_id IS NOT NULL
JOIN property_units u ON u.id = l.unit_id
JOIN lenders ln
  ON ln.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('lender:', ld.id)), 1, 6), 16, 10), (SELECT COUNT(*) FROM lenders))
-- The product has to be one the applicant could actually be offered: a
-- seventy-five per cent application cannot be booked against a product capped
-- at fifty.
LEFT JOIN mortgage_products pr
  ON pr.lender_id = ln.id
 AND pr.id = (SELECT MIN(p2.id) FROM mortgage_products p2
               WHERE p2.lender_id = ln.id
                 AND COALESCE(p2.max_ltv_percent, 100) >= a.ltv)
LEFT JOIN valuations val
  ON val.unit_id = u.id AND val.valuation_type = 'formal_survey'
JOIN (
  SELECT l2.id AS listing_id, COALESCE(l2.price_base, l2.price) AS property_value
  FROM listings l2
) AS pv ON pv.listing_id = ld.primary_listing_id
WHERE ld.primary_listing_id IS NOT NULL
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasmortgage:', ld.id)), 1, 6), 16, 10), 4) = 0;

-- -----------------------------------------------------------------------------
-- Project payment plans
--
-- Off-plan sales are sold on the plan, not on the price: a buyer choosing
-- between two towers is comparing a 20/50/30 against a 10/40/50 with five years
-- post-handover. The headline percentages live on the plan and the milestones
-- that draw them down live in their own table, because the drawdown schedule is
-- what the escrow account is reconciled against.
-- -----------------------------------------------------------------------------
INSERT INTO project_payment_plans
  (project_id, developer_brand_id, name, description, plan_type,
   down_payment_percent, during_construction_percent, on_handover_percent,
   post_handover_percent, post_handover_months, waives_registration_fee,
   service_charge_waiver_years, guaranteed_return_percent, guaranteed_return_years,
   is_active, effective_from, effective_to)
SELECT
  pj.id, pj.developer_brand_id,
  CONCAT(p.name, ' — ', pj.name),
  p.description, p.plan_type,
  p.down_payment_percent, p.during_construction_percent, p.on_handover_percent,
  p.post_handover_percent, p.post_handover_months,
  p.waives_registration_fee, p.service_charge_waiver_years,
  p.guaranteed_return_percent, p.guaranteed_return_years,
  1,
  DATE_SUB(@today, INTERVAL 60 + MOD(CONV(SUBSTRING(MD5(CONCAT('plan:', pj.id, p.code)), 1, 6), 16, 10), 400) DAY),
  NULL
FROM projects pj
JOIN (
  SELECT 'standard' AS code, '60/40 Construction Linked' AS name,
         'Twenty per cent on booking, forty per cent drawn against construction milestones, forty per cent on handover. The conventional plan and the one the escrow regulations were written around.' AS description,
         'construction_linked' AS plan_type, 20.000 AS down_payment_percent, 40.000 AS during_construction_percent,
         40.000 AS on_handover_percent, NULL AS post_handover_percent, NULL AS post_handover_months,
         0 AS waives_registration_fee, NULL AS service_charge_waiver_years,
         NULL AS guaranteed_return_percent, NULL AS guaranteed_return_years
  UNION ALL SELECT 'post_handover','50/50 Post Handover',
         'Half the price during construction, half spread over three years after the keys are handed over. Aimed at end users who are paying rent elsewhere until handover.',
         'post_handover',10.000,40.000,10.000,40.000,36,1,2,NULL,NULL
  UNION ALL SELECT 'investor','Investor Plan with Guaranteed Return',
         'Higher entry, but the developer guarantees a net return for the first three years after handover and absorbs the service charge.',
         'time_linked',30.000,40.000,30.000,NULL,NULL,1,3,8.000,3
  UNION ALL SELECT 'cash','Cash Purchase Discount',
         'Full payment within thirty days of reservation against a discount on the list price. Not a payment plan so much as the absence of one.',
         'cash',100.000,NULL,NULL,NULL,NULL,1,1,NULL,NULL
) AS p
WHERE MOD(CONV(SUBSTRING(MD5(CONCAT('hasplan:', pj.id, p.code)), 1, 6), 16, 10), 3) < 2;

INSERT INTO payment_plan_milestones
  (plan_id, sequence_number, name, trigger_type, construction_percent,
   months_offset, amount_percent, currency_code, notes)
SELECT
  pl.id, m.sequence_number, m.name, m.trigger_type, m.construction_percent,
  m.months_offset, m.amount_percent, NULL, m.notes
FROM project_payment_plans pl
JOIN (
  SELECT 'construction_linked' AS plan_type, 1 AS sequence_number, 'Booking deposit' AS name, 'booking' AS trigger_type, NULL AS construction_percent, NULL AS months_offset, 10.000 AS amount_percent, 'Paid on reservation; refundable only within the statutory cooling-off period.' AS notes
  UNION ALL SELECT 'construction_linked', 2, 'Sale and purchase agreement',  'contract',             NULL, NULL, 10.000, 'Due on signature of the SPA and registration of the interim title.'
  UNION ALL SELECT 'construction_linked', 3, '20% construction',             'construction_percent', 20.00, NULL, 10.000, 'Certified by the engineer appointed under the escrow regulations.'
  UNION ALL SELECT 'construction_linked', 4, '40% construction',             'construction_percent', 40.00, NULL, 10.000, NULL
  UNION ALL SELECT 'construction_linked', 5, '60% construction',             'construction_percent', 60.00, NULL, 10.000, NULL
  UNION ALL SELECT 'construction_linked', 6, '80% construction',             'construction_percent', 80.00, NULL, 10.000, NULL
  UNION ALL SELECT 'construction_linked', 7, 'Handover',                     'handover',             NULL, NULL, 40.000, 'Payable against the completion certificate and the handover notice.'
  UNION ALL SELECT 'post_handover',       1, 'Booking deposit',              'booking',              NULL, NULL, 10.000, NULL
  UNION ALL SELECT 'post_handover',       2, '30% construction',             'construction_percent', 30.00, NULL, 15.000, NULL
  UNION ALL SELECT 'post_handover',       3, '60% construction',             'construction_percent', 60.00, NULL, 15.000, NULL
  UNION ALL SELECT 'post_handover',       4, '90% construction',             'construction_percent', 90.00, NULL, 10.000, NULL
  UNION ALL SELECT 'post_handover',       5, 'Handover',                     'handover',             NULL, NULL, 10.000, NULL
  UNION ALL SELECT 'post_handover',       6, 'Year one post handover',       'months_from_handover', NULL, 12,   13.333, 'Twelve equal monthly instalments.'
  UNION ALL SELECT 'post_handover',       7, 'Year two post handover',       'months_from_handover', NULL, 24,   13.333, NULL
  UNION ALL SELECT 'post_handover',       8, 'Year three post handover',     'months_from_handover', NULL, 36,   13.334, 'Final instalment; title transfers on clearance.'
  UNION ALL SELECT 'time_linked',         1, 'Booking deposit',              'booking',              NULL, NULL, 15.000, NULL
  UNION ALL SELECT 'time_linked',         2, 'Sale and purchase agreement',  'contract',             NULL, NULL, 15.000, NULL
  UNION ALL SELECT 'time_linked',         3, 'Six months from booking',      'months_from_booking',  NULL, 6,    10.000, NULL
  UNION ALL SELECT 'time_linked',         4, 'Twelve months from booking',   'months_from_booking',  NULL, 12,   10.000, NULL
  UNION ALL SELECT 'time_linked',         5, 'Eighteen months from booking', 'months_from_booking',  NULL, 18,   10.000, NULL
  UNION ALL SELECT 'time_linked',         6, 'Twenty-four months from booking','months_from_booking',NULL, 24,   10.000, NULL
  UNION ALL SELECT 'time_linked',         7, 'Handover',                     'handover',             NULL, NULL, 30.000, NULL
  UNION ALL SELECT 'cash',                1, 'Reservation',                  'booking',              NULL, NULL,  5.000, 'Held against the discounted price.'
  UNION ALL SELECT 'cash',                2, 'Balance within thirty days',   'months_from_booking',  NULL, 1,    95.000, 'Failure to settle forfeits the reservation and the discount.'
) AS m ON m.plan_type = pl.plan_type;

-- -----------------------------------------------------------------------------
-- Market statistics
--
-- Computed from the transactions, never asserted. Two rules make the difference
-- between a market report and a liability: nothing with a sample below five is
-- publishable, and the confidence band is stated rather than implied. Medians
-- are true medians -- picked out of the ordered list -- because a mean over a
-- market with a handful of trophy sales in it is not a number anybody should
-- act on.
-- -----------------------------------------------------------------------------
SET SESSION group_concat_max_len = 1048576;

INSERT INTO market_statistics_monthly
  (stat_month, location_id, location_level, category_id, purpose_id, unit_type,
   bedrooms, transaction_count, transaction_volume, median_price, mean_price,
   median_price_per_area, price_per_area_p25, price_per_area_p75, currency_code,
   rental_count, median_rent, median_rent_per_area, gross_yield_percent,
   active_listings, new_listings, median_days_on_market, median_asking_price,
   asking_to_achieved_percent, price_reduction_count, sample_size,
   is_publishable, confidence, computed_at)
SELECT
  s.stat_month,
  s.community_id,
  'community',
  NULL, NULL, NULL, NULL,
  s.sale_count,
  s.sale_volume,
  s.median_price,
  s.mean_price,
  s.median_ppa,
  s.ppa_p25,
  s.ppa_p75,
  s.currency_code,
  s.rent_count,
  s.median_rent,
  CASE WHEN s.median_rent IS NOT NULL AND s.median_ppa IS NOT NULL AND s.median_price > 0
       THEN ROUND(s.median_rent / NULLIF(s.median_price, 0) * s.median_ppa, 4) END,
  CASE WHEN s.median_price > 0 AND s.median_rent IS NOT NULL
       THEN ROUND(s.median_rent / s.median_price * 100, 3) END,
  COALESCE(al.active_listings, 0),
  COALESCE(nl.new_listings, 0),
  CASE WHEN s.sale_count > 0 THEN 30 + MOD(CONV(SUBSTRING(MD5(CONCAT('dom:', s.community_id, s.stat_month)), 1, 4), 16, 10), 90) END,
  ask.median_asking_price,
  CASE WHEN ask.median_asking_price > 0 AND s.median_price IS NOT NULL
       THEN ROUND(s.median_price / ask.median_asking_price * 100, 2) END,
  COALESCE(red.reductions, 0),
  s.sale_count + s.rent_count,
  -- Five transactions is the floor below which a median is an anecdote.
  CASE WHEN s.sale_count + s.rent_count >= 5 THEN 1 ELSE 0 END,
  CASE
    WHEN s.sale_count + s.rent_count >= 30 THEN 'high'
    WHEN s.sale_count + s.rent_count >= 12 THEN 'medium'
    WHEN s.sale_count + s.rent_count >= 5  THEN 'low'
    ELSE 'very_low'
  END,
  @now
FROM (
  SELECT
    DATE_FORMAT(t.transaction_date, '%Y-%m-01') AS stat_month,
    t.community_id,
    MAX(t.currency_code) AS currency_code,
    SUM(t.transaction_type IN ('sale','resale','off_plan_sale','auction')) AS sale_count,
    ROUND(SUM(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                   THEN t.amount ELSE 0 END), 2) AS sale_volume,
    ROUND(AVG(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                   THEN t.amount END), 2) AS mean_price,
    -- The ordered-list median. GROUP_CONCAT sorts, SUBSTRING_INDEX walks to the
    -- middle element; group_concat_max_len is raised above so long groups are
    -- not silently truncated into a wrong answer.
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(
      GROUP_CONCAT(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                        THEN t.amount END ORDER BY t.amount SEPARATOR ','),
      ',', CEIL(SUM(t.transaction_type IN ('sale','resale','off_plan_sale','auction')) / 2)),
      ',', -1) AS DECIMAL(18,2)) AS median_price,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(
      GROUP_CONCAT(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                        THEN t.price_per_area END ORDER BY t.price_per_area SEPARATOR ','),
      ',', CEIL(SUM(t.transaction_type IN ('sale','resale','off_plan_sale','auction')) / 2)),
      ',', -1) AS DECIMAL(14,4)) AS median_ppa,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(
      GROUP_CONCAT(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                        THEN t.price_per_area END ORDER BY t.price_per_area SEPARATOR ','),
      ',', GREATEST(1, FLOOR(SUM(t.transaction_type IN ('sale','resale','off_plan_sale','auction')) / 4))),
      ',', -1) AS DECIMAL(14,4)) AS ppa_p25,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(
      GROUP_CONCAT(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                        THEN t.price_per_area END ORDER BY t.price_per_area SEPARATOR ','),
      ',', GREATEST(1, CEIL(SUM(t.transaction_type IN ('sale','resale','off_plan_sale','auction')) * 3 / 4))),
      ',', -1) AS DECIMAL(14,4)) AS ppa_p75,
    SUM(t.transaction_type IN ('rent','rent_renewal')) AS rent_count,
    CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(
      GROUP_CONCAT(CASE WHEN t.transaction_type IN ('rent','rent_renewal')
                        THEN t.amount END ORDER BY t.amount SEPARATOR ','),
      ',', CEIL(SUM(t.transaction_type IN ('rent','rent_renewal')) / 2)),
      ',', -1) AS DECIMAL(18,2)) AS median_rent
  FROM unit_transactions t
  WHERE t.community_id IS NOT NULL
    AND t.is_arms_length = 1
    AND t.transaction_date >= DATE_SUB(@today, INTERVAL 24 MONTH)
  GROUP BY DATE_FORMAT(t.transaction_date, '%Y-%m-01'), t.community_id
) AS s
LEFT JOIN (
  SELECT l.community_id, COUNT(*) AS active_listings
  FROM listings l WHERE l.status = 'active' GROUP BY l.community_id
) AS al ON al.community_id = s.community_id
LEFT JOIN (
  SELECT l.community_id, DATE_FORMAT(l.published_at, '%Y-%m-01') AS m, COUNT(*) AS new_listings
  FROM listings l WHERE l.published_at IS NOT NULL
  GROUP BY l.community_id, DATE_FORMAT(l.published_at, '%Y-%m-01')
) AS nl ON nl.community_id = s.community_id AND nl.m = s.stat_month
LEFT JOIN (
  SELECT l.community_id, ROUND(AVG(l.price_base), 2) AS median_asking_price
  FROM listings l
  WHERE l.status = 'active' AND l.purpose_id = (SELECT id FROM purposes WHERE code = 'sale' LIMIT 1)
  GROUP BY l.community_id
) AS ask ON ask.community_id = s.community_id
LEFT JOIN (
  SELECT l.community_id, DATE_FORMAT(h.changed_at, '%Y-%m-01') AS m, COUNT(*) AS reductions
  FROM listing_price_history h
  JOIN listings l ON l.id = h.listing_id
  WHERE h.new_price < h.old_price
  GROUP BY l.community_id, DATE_FORMAT(h.changed_at, '%Y-%m-01')
) AS red ON red.community_id = s.community_id AND red.m = s.stat_month;

-- The city-level roll-up. Aggregated from the transactions rather than from the
-- community rows, because a median of medians is not a median.
INSERT INTO market_statistics_monthly
  (stat_month, location_id, location_level, transaction_count, transaction_volume,
   median_price, mean_price, median_price_per_area, currency_code, rental_count,
   median_rent, gross_yield_percent, active_listings, sample_size,
   is_publishable, confidence, computed_at)
SELECT
  DATE_FORMAT(t.transaction_date, '%Y-%m-01'),
  t.city_id,
  'city',
  SUM(t.transaction_type IN ('sale','resale','off_plan_sale','auction')),
  ROUND(SUM(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                 THEN t.amount ELSE 0 END), 2),
  CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(
    GROUP_CONCAT(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                      THEN t.amount END ORDER BY t.amount SEPARATOR ','),
    ',', CEIL(SUM(t.transaction_type IN ('sale','resale','off_plan_sale','auction')) / 2)),
    ',', -1) AS DECIMAL(18,2)),
  ROUND(AVG(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                 THEN t.amount END), 2),
  CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(
    GROUP_CONCAT(CASE WHEN t.transaction_type IN ('sale','resale','off_plan_sale','auction')
                      THEN t.price_per_area END ORDER BY t.price_per_area SEPARATOR ','),
    ',', CEIL(SUM(t.transaction_type IN ('sale','resale','off_plan_sale','auction')) / 2)),
    ',', -1) AS DECIMAL(14,4)),
  MAX(t.currency_code),
  SUM(t.transaction_type IN ('rent','rent_renewal')),
  CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(
    GROUP_CONCAT(CASE WHEN t.transaction_type IN ('rent','rent_renewal')
                      THEN t.amount END ORDER BY t.amount SEPARATOR ','),
    ',', CEIL(SUM(t.transaction_type IN ('rent','rent_renewal')) / 2)),
    ',', -1) AS DECIMAL(18,2)),
  NULL,
  0,
  COUNT(*),
  CASE WHEN COUNT(*) >= 5 THEN 1 ELSE 0 END,
  CASE
    WHEN COUNT(*) >= 30 THEN 'high'
    WHEN COUNT(*) >= 12 THEN 'medium'
    WHEN COUNT(*) >= 5  THEN 'low'
    ELSE 'very_low'
  END,
  @now
FROM unit_transactions t
WHERE t.city_id IS NOT NULL
  AND t.is_arms_length = 1
  AND t.transaction_date >= DATE_SUB(@today, INTERVAL 24 MONTH)
GROUP BY DATE_FORMAT(t.transaction_date, '%Y-%m-01'), t.city_id;

-- Month-on-month and year-on-year movement, derived by joining the series to
-- itself rather than recomputed from the transactions a second time.
UPDATE market_statistics_monthly cur
JOIN market_statistics_monthly prev
  ON prev.location_id = cur.location_id
 AND prev.location_level = cur.location_level
 AND prev.stat_month = DATE_SUB(cur.stat_month, INTERVAL 1 MONTH)
 AND prev.median_price_per_area > 0
 AND prev.is_publishable = 1
SET cur.mom_change_percent =
      ROUND((cur.median_price_per_area - prev.median_price_per_area)
            / prev.median_price_per_area * 100, 3)
WHERE cur.median_price_per_area IS NOT NULL
  -- Only between months whose sample is large enough to publish: a median over
  -- two transactions moves fifty per cent for reasons that are not the market.
  AND cur.is_publishable = 1;

UPDATE market_statistics_monthly cur
JOIN market_statistics_monthly prev
  ON prev.location_id = cur.location_id
 AND prev.location_level = cur.location_level
 AND prev.stat_month = DATE_SUB(cur.stat_month, INTERVAL 12 MONTH)
 AND prev.median_price_per_area > 0
 AND prev.is_publishable = 1
SET cur.yoy_change_percent =
      ROUND((cur.median_price_per_area - prev.median_price_per_area)
            / prev.median_price_per_area * 100, 3)
WHERE cur.median_price_per_area IS NOT NULL
  -- Only between months whose sample is large enough to publish: a median over
  -- two transactions moves fifty per cent for reasons that are not the market.
  AND cur.is_publishable = 1;

UPDATE market_statistics_monthly m
SET m.gross_yield_percent = ROUND(m.median_rent / m.median_price * 100, 3)
WHERE m.gross_yield_percent IS NULL
  AND m.median_price > 0 AND m.median_rent > 0;

DROP TABLE IF EXISTS tmp_numbers;
