-- =============================================================================
-- Liv Finder — seed 030 · Taxonomy
-- =============================================================================
-- The six asset classes, their listing types, transaction purposes, the
-- attribute registry and the amenity/feature vocabulary.
--
-- Ids are assigned explicitly so that category and attribute ids are stable
-- across environments — they end up in saved searches, analytics and URLs, and
-- must mean the same thing in staging as in production.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- Purposes
-- -----------------------------------------------------------------------------
INSERT INTO purposes (id, code, slug, name, is_recurring, sort_order) VALUES
  (1, 'sale',    'for-sale',    'For Sale',    0, 1),
  (2, 'rent',    'for-rent',    'For Rent',    1, 2),
  (3, 'charter', 'for-charter', 'For Charter', 1, 3),
  (4, 'lease',   'for-lease',   'For Lease',   1, 4),
  (5, 'auction', 'auction',     'At Auction',  0, 5);

-- -----------------------------------------------------------------------------
-- Categories — six roots, then listing types beneath each
--
-- `code` is the stable machine key used in routes and application code.
-- `detail_table` tells the application which per-category table in migration
-- 0007 backs a listing, so dispatch is data-driven.
-- -----------------------------------------------------------------------------
INSERT INTO categories
  (id, public_id, parent_id, root_category_id, code, slug, name, name_plural, depth, path,
   icon, detail_table, primary_unit, status, is_visible, is_featured, sort_order) VALUES
  (1,  '01K2F3A0000000000000000001', NULL, 1, 'real-estate', 'real-estate', 'Real Estate', 'Properties',  0, 'real-estate', 'home',       'real_estate', 'sqft', 'active', 1, 1, 1),
  (2,  '01K2F3A0000000000000000002', NULL, 2, 'cars',        'cars',        'Car',         'Cars',        0, 'cars',        'car',        'vehicle',     'km',   'active', 1, 1, 2),
  (3,  '01K2F3A0000000000000000003', NULL, 3, 'yachts',      'yachts',      'Yacht',       'Yachts',      0, 'yachts',      'anchor',     'marine',      'ft',   'active', 1, 1, 3),
  (4,  '01K2F3A0000000000000000004', NULL, 4, 'jets',        'jets',        'Jet',         'Jets',        0, 'jets',        'plane',      'aviation',    'nm',   'active', 1, 1, 4),
  (5,  '01K2F3A0000000000000000005', NULL, 5, 'helicopters', 'helicopters', 'Helicopter',  'Helicopters', 0, 'helicopters', 'helicopter', 'aviation',    'nm',   'active', 1, 1, 5),
  (6,  '01K2F3A0000000000000000006', NULL, 6, 'watches',     'watches',     'Watch',       'Watches',     0, 'watches',     'watch',      'timepiece',   'mm',   'active', 1, 1, 6);

-- Real estate types
INSERT INTO categories (id, public_id, parent_id, root_category_id, code, slug, name, name_plural, depth, path, detail_table, status, sort_order) VALUES
  (101, '01K2F3A0000000000000000101', 1, 1, 'apartment',       'apartments',       'Apartment',        'Apartments',        1, 'real-estate/apartments',       'real_estate', 'active', 1),
  (102, '01K2F3A0000000000000000102', 1, 1, 'villa',           'villas',           'Villa',            'Villas',            1, 'real-estate/villas',           'real_estate', 'active', 2),
  (103, '01K2F3A0000000000000000103', 1, 1, 'penthouse',       'penthouses',       'Penthouse',        'Penthouses',        1, 'real-estate/penthouses',       'real_estate', 'active', 3),
  (104, '01K2F3A0000000000000000104', 1, 1, 'townhouse',       'townhouses',       'Townhouse',        'Townhouses',        1, 'real-estate/townhouses',       'real_estate', 'active', 4),
  (105, '01K2F3A0000000000000000105', 1, 1, 'mansion',         'mansions',         'Mansion',          'Mansions',          1, 'real-estate/mansions',         'real_estate', 'active', 5),
  (106, '01K2F3A0000000000000000106', 1, 1, 'duplex',          'duplexes',         'Duplex',           'Duplexes',          1, 'real-estate/duplexes',         'real_estate', 'active', 6),
  (107, '01K2F3A0000000000000000107', 1, 1, 'chalet',          'chalets',          'Chalet',           'Chalets',           1, 'real-estate/chalets',          'real_estate', 'active', 7),
  (108, '01K2F3A0000000000000000108', 1, 1, 'estate',          'estates',          'Estate',           'Estates',           1, 'real-estate/estates',          'real_estate', 'active', 8),
  (109, '01K2F3A0000000000000000109', 1, 1, 'plot',            'plots',            'Plot',             'Plots',             1, 'real-estate/plots',            'real_estate', 'active', 9),
  (110, '01K2F3A0000000000000000110', 1, 1, 'whole-building',  'buildings',        'Whole Building',   'Buildings',         1, 'real-estate/buildings',        'real_estate', 'active', 10),
  (111, '01K2F3A0000000000000000111', 1, 1, 'office',          'offices',          'Office',           'Offices',           1, 'real-estate/offices',          'real_estate', 'active', 11),
  (112, '01K2F3A0000000000000000112', 1, 1, 'retail',          'retail',           'Retail',           'Retail Units',      1, 'real-estate/retail',           'real_estate', 'active', 12),
  (113, '01K2F3A0000000000000000113', 1, 1, 'hotel-apartment', 'hotel-apartments', 'Hotel Apartment',  'Hotel Apartments',  1, 'real-estate/hotel-apartments', 'real_estate', 'active', 13),
  (114, '01K2F3A0000000000000000114', 1, 1, 'island',          'islands',          'Private Island',   'Private Islands',   1, 'real-estate/islands',          'real_estate', 'active', 14),
  (115, '01K2F3A0000000000000000115', 1, 1, 'vineyard',        'vineyards',        'Vineyard',         'Vineyards',         1, 'real-estate/vineyards',        'real_estate', 'active', 15);

-- Car types
INSERT INTO categories (id, public_id, parent_id, root_category_id, code, slug, name, name_plural, depth, path, detail_table, status, sort_order) VALUES
  (201, '01K2F3A0000000000000000201', 2, 2, 'supercar',      'supercars',      'Supercar',       'Supercars',       1, 'cars/supercars',      'vehicle', 'active', 1),
  (202, '01K2F3A0000000000000000202', 2, 2, 'hypercar',      'hypercars',      'Hypercar',       'Hypercars',       1, 'cars/hypercars',      'vehicle', 'active', 2),
  (203, '01K2F3A0000000000000000203', 2, 2, 'luxury-sedan',  'luxury-sedans',  'Luxury Sedan',   'Luxury Sedans',   1, 'cars/luxury-sedans',  'vehicle', 'active', 3),
  (204, '01K2F3A0000000000000000204', 2, 2, 'luxury-suv',    'luxury-suvs',    'Luxury SUV',     'Luxury SUVs',     1, 'cars/luxury-suvs',    'vehicle', 'active', 4),
  (205, '01K2F3A0000000000000000205', 2, 2, 'coupe',         'coupes',         'Coupé',          'Coupés',          1, 'cars/coupes',         'vehicle', 'active', 5),
  (206, '01K2F3A0000000000000000206', 2, 2, 'convertible',   'convertibles',   'Convertible',    'Convertibles',    1, 'cars/convertibles',   'vehicle', 'active', 6),
  (207, '01K2F3A0000000000000000207', 2, 2, 'classic-car',   'classic-cars',   'Classic Car',    'Classic Cars',    1, 'cars/classic-cars',   'vehicle', 'active', 7),
  (208, '01K2F3A0000000000000000208', 2, 2, 'electric-car',  'electric',       'Electric',       'Electric Cars',   1, 'cars/electric',       'vehicle', 'active', 8),
  (209, '01K2F3A0000000000000000209', 2, 2, 'grand-tourer',  'grand-tourers',  'Grand Tourer',   'Grand Tourers',   1, 'cars/grand-tourers',  'vehicle', 'active', 9),
  (210, '01K2F3A0000000000000000210', 2, 2, 'off-road',      'off-road',       'Off-Road',       'Off-Road',        1, 'cars/off-road',       'vehicle', 'active', 10);

-- Yacht types
INSERT INTO categories (id, public_id, parent_id, root_category_id, code, slug, name, name_plural, depth, path, detail_table, status, sort_order) VALUES
  (301, '01K2F3A0000000000000000301', 3, 3, 'motor-yacht',   'motor-yachts',   'Motor Yacht',   'Motor Yachts',   1, 'yachts/motor-yachts',   'marine', 'active', 1),
  (302, '01K2F3A0000000000000000302', 3, 3, 'sailing-yacht', 'sailing-yachts', 'Sailing Yacht', 'Sailing Yachts', 1, 'yachts/sailing-yachts', 'marine', 'active', 2),
  (303, '01K2F3A0000000000000000303', 3, 3, 'superyacht',    'superyachts',    'Superyacht',    'Superyachts',    1, 'yachts/superyachts',    'marine', 'active', 3),
  (304, '01K2F3A0000000000000000304', 3, 3, 'mega-yacht',    'mega-yachts',    'Mega Yacht',    'Mega Yachts',    1, 'yachts/mega-yachts',    'marine', 'active', 4),
  (305, '01K2F3A0000000000000000305', 3, 3, 'catamaran',     'catamarans',     'Catamaran',     'Catamarans',     1, 'yachts/catamarans',     'marine', 'active', 5),
  (306, '01K2F3A0000000000000000306', 3, 3, 'explorer',      'explorer-yachts','Explorer',      'Explorer Yachts',1, 'yachts/explorer-yachts','marine', 'active', 6),
  (307, '01K2F3A0000000000000000307', 3, 3, 'sport-fisher',  'sport-fishers',  'Sport Fisher',  'Sport Fishers',  1, 'yachts/sport-fishers',  'marine', 'active', 7),
  (308, '01K2F3A0000000000000000308', 3, 3, 'classic-yacht', 'classic-yachts', 'Classic Yacht', 'Classic Yachts', 1, 'yachts/classic-yachts', 'marine', 'active', 8);

-- Jet types
INSERT INTO categories (id, public_id, parent_id, root_category_id, code, slug, name, name_plural, depth, path, detail_table, status, sort_order) VALUES
  (401, '01K2F3A0000000000000000401', 4, 4, 'light-jet',        'light-jets',        'Light Jet',        'Light Jets',        1, 'jets/light-jets',        'aviation', 'active', 1),
  (402, '01K2F3A0000000000000000402', 4, 4, 'midsize-jet',      'midsize-jets',      'Midsize Jet',      'Midsize Jets',      1, 'jets/midsize-jets',      'aviation', 'active', 2),
  (403, '01K2F3A0000000000000000403', 4, 4, 'super-midsize-jet','super-midsize-jets','Super Midsize Jet','Super Midsize Jets',1, 'jets/super-midsize-jets','aviation', 'active', 3),
  (404, '01K2F3A0000000000000000404', 4, 4, 'heavy-jet',        'heavy-jets',        'Heavy Jet',        'Heavy Jets',        1, 'jets/heavy-jets',        'aviation', 'active', 4),
  (405, '01K2F3A0000000000000000405', 4, 4, 'ultra-long-range', 'ultra-long-range',  'Ultra Long Range', 'Ultra Long Range',  1, 'jets/ultra-long-range',  'aviation', 'active', 5),
  (406, '01K2F3A0000000000000000406', 4, 4, 'vip-airliner',     'vip-airliners',     'VIP Airliner',     'VIP Airliners',     1, 'jets/vip-airliners',     'aviation', 'active', 6),
  (407, '01K2F3A0000000000000000407', 4, 4, 'turboprop',        'turboprops',        'Turboprop',        'Turboprops',        1, 'jets/turboprops',        'aviation', 'active', 7);

-- Helicopter types
INSERT INTO categories (id, public_id, parent_id, root_category_id, code, slug, name, name_plural, depth, path, detail_table, status, sort_order) VALUES
  (501, '01K2F3A0000000000000000501', 5, 5, 'light-helicopter',  'light-helicopters',  'Light Helicopter',  'Light Helicopters',  1, 'helicopters/light-helicopters',  'aviation', 'active', 1),
  (502, '01K2F3A0000000000000000502', 5, 5, 'medium-helicopter', 'medium-helicopters', 'Medium Helicopter', 'Medium Helicopters', 1, 'helicopters/medium-helicopters', 'aviation', 'active', 2),
  (503, '01K2F3A0000000000000000503', 5, 5, 'heavy-helicopter',  'heavy-helicopters',  'Heavy Helicopter',  'Heavy Helicopters',  1, 'helicopters/heavy-helicopters',  'aviation', 'active', 3),
  (504, '01K2F3A0000000000000000504', 5, 5, 'vip-helicopter',    'vip-helicopters',    'VIP Helicopter',    'VIP Helicopters',    1, 'helicopters/vip-helicopters',    'aviation', 'active', 4);

-- Watch types
INSERT INTO categories (id, public_id, parent_id, root_category_id, code, slug, name, name_plural, depth, path, detail_table, status, sort_order) VALUES
  (601, '01K2F3A0000000000000000601', 6, 6, 'sports-watch',    'sports-watches',    'Sports Watch',    'Sports Watches',    1, 'watches/sports-watches',    'timepiece', 'active', 1),
  (602, '01K2F3A0000000000000000602', 6, 6, 'dress-watch',     'dress-watches',     'Dress Watch',     'Dress Watches',     1, 'watches/dress-watches',     'timepiece', 'active', 2),
  (603, '01K2F3A0000000000000000603', 6, 6, 'chronograph',     'chronographs',      'Chronograph',     'Chronographs',      1, 'watches/chronographs',      'timepiece', 'active', 3),
  (604, '01K2F3A0000000000000000604', 6, 6, 'dive-watch',      'dive-watches',      'Dive Watch',      'Dive Watches',      1, 'watches/dive-watches',      'timepiece', 'active', 4),
  (605, '01K2F3A0000000000000000605', 6, 6, 'complication',    'complications',     'Complication',    'Complications',     1, 'watches/complications',     'timepiece', 'active', 5),
  (606, '01K2F3A0000000000000000606', 6, 6, 'gmt-worldtimer',  'gmt-worldtimers',   'GMT / Worldtimer','GMT & Worldtimers', 1, 'watches/gmt-worldtimers',   'timepiece', 'active', 6),
  (607, '01K2F3A0000000000000000607', 6, 6, 'vintage-watch',   'vintage-watches',   'Vintage Watch',   'Vintage Watches',   1, 'watches/vintage-watches',   'timepiece', 'active', 7),
  (608, '01K2F3A0000000000000000608', 6, 6, 'ladies-watch',    'ladies-watches',    'Ladies Watch',    'Ladies Watches',    1, 'watches/ladies-watches',    'timepiece', 'active', 8);

-- -----------------------------------------------------------------------------
-- Which purposes apply to which asset class
--
-- Watches are sale-only. Yachts and aircraft charter rather than rent. Applied
-- to the root categories and inherited by their children in application code.
-- -----------------------------------------------------------------------------
INSERT INTO category_purposes (category_id, purpose_id, is_default, sort_order) VALUES
  (1, 1, 1, 1), (1, 2, 0, 2),                          -- real estate: sale, rent
  (2, 1, 1, 1), (2, 2, 0, 2), (2, 5, 0, 3),            -- cars: sale, rent, auction
  (3, 1, 1, 1), (3, 3, 0, 2),                          -- yachts: sale, charter
  (4, 1, 1, 1), (4, 3, 0, 2), (4, 4, 0, 3),            -- jets: sale, charter, lease
  (5, 1, 1, 1), (5, 3, 0, 2),                          -- helicopters: sale, charter
  (6, 1, 1, 1), (6, 5, 0, 2);                          -- watches: sale, auction

-- -----------------------------------------------------------------------------
-- Attribute registry
--
-- `backing_column` names the typed column in the per-category detail table where
-- this attribute is physically stored. NULL means it lives in the listing's JSON
-- document only. This is the single place the mapping is declared.
-- -----------------------------------------------------------------------------
INSERT INTO attributes
  (id, code, name, data_type, unit_code, backing_column, ui_control, is_filterable, is_facet, is_sortable, is_highlight, min_value, max_value) VALUES
  -- Real estate
  (1,  'bedrooms',          'Bedrooms',            'integer', NULL,   'bedrooms',           'select',       1, 1, 1, 1, 0, 50),
  (2,  'bathrooms',         'Bathrooms',           'integer', NULL,   'bathrooms',          'select',       1, 1, 1, 1, 0, 50),
  (3,  'built_area_sqft',   'Built-up area',       'decimal', 'sqft', 'built_area_sqft',    'range_slider', 1, 0, 1, 1, 0, 500000),
  (4,  'built_area_sqm',    'Built-up area',       'decimal', 'sqm',  'built_area_sqm',     'range_slider', 1, 0, 1, 0, 0, 50000),
  (5,  'plot_area_sqft',    'Plot area',           'decimal', 'sqft', 'plot_area_sqft',     'range_slider', 1, 0, 1, 0, 0, 5000000),
  (6,  'year_built',        'Year built',          'year',    NULL,   'year_built',         'year_select',  1, 0, 1, 0, 1800, 2035),
  (7,  'furnishing',        'Furnishing',          'enum',    NULL,   'furnishing',         'select',       1, 1, 0, 1, NULL, NULL),
  (8,  'completion_status', 'Completion status',   'enum',    NULL,   'completion_status',  'select',       1, 1, 0, 1, NULL, NULL),
  (9,  'ownership_type',    'Ownership',           'enum',    NULL,   'ownership_type',     'select',       1, 1, 0, 0, NULL, NULL),
  (10, 'parking_spaces',    'Parking spaces',      'integer', NULL,   'parking_spaces',     'select',       1, 0, 0, 0, 0, 100),
  (11, 'floor_number',      'Floor',               'integer', NULL,   'floor_number',       'number',       1, 0, 1, 0, -10, 200),
  (12, 'view_type',         'View',                'string',  NULL,   'view_type',          'select',       1, 1, 0, 1, NULL, NULL),
  (13, 'handover_date',     'Handover',            'date',    NULL,   'handover_date',      'date',         1, 0, 1, 0, NULL, NULL),
  (14, 'rental_yield',      'Gross yield',         'decimal', NULL,   'rental_yield_percentage', 'range_slider', 1, 0, 1, 0, 0, 100),
  (15, 'permit_number',     'Permit number',       'string',  NULL,   'permit_number',      'text',         0, 0, 0, 0, NULL, NULL),

  -- Cars
  (30, 'model_year',        'Year',                'year',    NULL,   'model_year',         'year_select',  1, 1, 1, 1, 1900, 2035),
  (31, 'mileage_km',        'Mileage',             'integer', 'km',   'mileage_km',         'range_slider', 1, 0, 1, 1, 0, 2000000),
  (32, 'mileage_miles',     'Mileage',             'integer', 'mi',   'mileage_miles',      'range_slider', 1, 0, 1, 0, 0, 1500000),
  (33, 'transmission',      'Transmission',        'enum',    NULL,   'transmission',       'select',       1, 1, 0, 1, NULL, NULL),
  (34, 'fuel_type',         'Fuel type',           'enum',    NULL,   'fuel_type',          'select',       1, 1, 0, 1, NULL, NULL),
  (35, 'body_type',         'Body type',           'string',  NULL,   'body_type',          'select',       1, 1, 0, 0, NULL, NULL),
  (36, 'horsepower',        'Power',               'integer', 'hp',   'horsepower',         'range_slider', 1, 0, 1, 1, 0, 3000),
  (37, 'engine_size_cc',    'Engine size',         'integer', NULL,   'engine_size_cc',     'range_slider', 1, 0, 0, 0, 0, 12000),
  (38, 'drivetrain',        'Drivetrain',          'enum',    NULL,   'drivetrain',         'select',       1, 1, 0, 0, NULL, NULL),
  (39, 'exterior_color',    'Exterior colour',     'string',  NULL,   'exterior_color',     'select',       1, 1, 0, 0, NULL, NULL),
  (40, 'condition_type',    'Condition',           'enum',    NULL,   'condition_type',     'select',       1, 1, 0, 1, NULL, NULL),
  (41, 'steering_side',     'Steering side',       'enum',    NULL,   'steering_side',      'select',       1, 1, 0, 0, NULL, NULL),
  (42, 'regional_spec',     'Regional spec',       'string',  NULL,   'regional_spec',      'select',       1, 1, 0, 0, NULL, NULL),
  (43, 'service_history',   'Service history',     'enum',    NULL,   'service_history',    'select',       1, 0, 0, 0, NULL, NULL),
  (44, 'seats',             'Seats',               'integer', NULL,   'seats',              'select',       1, 0, 0, 0, 1, 20),

  -- Yachts
  (60, 'length_overall_ft', 'Length overall',      'decimal', 'ft',   'length_overall_ft',  'range_slider', 1, 0, 1, 1, 0, 800),
  (61, 'length_overall_m',  'Length overall',      'decimal', 'm',    'length_overall_m',   'range_slider', 1, 0, 1, 0, 0, 250),
  (62, 'build_year',        'Year built',          'year',    NULL,   'build_year',         'year_select',  1, 1, 1, 1, 1900, 2035),
  (63, 'cabins',            'Cabins',              'integer', NULL,   'cabins',             'select',       1, 1, 1, 1, 0, 40),
  (64, 'guests_sleeping',   'Guests sleeping',     'integer', NULL,   'guests_sleeping',    'select',       1, 1, 1, 1, 0, 60),
  (65, 'crew_capacity',     'Crew',                'integer', NULL,   'crew_capacity',      'select',       1, 0, 0, 0, 0, 60),
  (66, 'vessel_type',       'Vessel type',         'enum',    NULL,   'vessel_type',        'select',       1, 1, 0, 1, NULL, NULL),
  (67, 'hull_material',     'Hull material',       'enum',    NULL,   'hull_material',      'select',       1, 1, 0, 0, NULL, NULL),
  (68, 'max_speed_knots',   'Max speed',           'decimal', 'knot', 'max_speed_knots',    'range_slider', 1, 0, 1, 0, 0, 80),
  (69, 'range_nm_marine',   'Range',               'integer', 'nm',   'range_nm',           'range_slider', 1, 0, 1, 0, 0, 20000),
  (70, 'engine_hours',      'Engine hours',        'integer', NULL,   'engine_hours',       'range_slider', 1, 0, 1, 0, 0, 60000),
  (71, 'refit_year',        'Refit year',          'year',    NULL,   'refit_year',         'year_select',  1, 0, 0, 0, 1900, 2035),
  (72, 'is_vat_paid',       'VAT paid',            'boolean', NULL,   'is_vat_paid',        'toggle',       1, 1, 0, 0, NULL, NULL),

  -- Aviation (jets and helicopters)
  (90,  'aircraft_type',      'Aircraft type',      'enum',    NULL,  'aircraft_type',      'select',       1, 1, 0, 1, NULL, NULL),
  (91,  'aircraft_year',      'Year built',         'year',    NULL,  'year_built',         'year_select',  1, 1, 1, 1, 1940, 2035),
  (92,  'total_time_hours',   'Total time',         'integer', NULL,  'total_time_hours',   'range_slider', 1, 0, 1, 1, 0, 100000),
  (93,  'cycles',             'Cycles',             'integer', NULL,  'cycles',             'range_slider', 1, 0, 1, 0, 0, 100000),
  (94,  'passenger_capacity', 'Passengers',         'integer', NULL,  'passenger_capacity', 'select',       1, 1, 1, 1, 1, 400),
  (95,  'range_nm_air',       'Range',              'integer', 'nm',  'range_nm',           'range_slider', 1, 0, 1, 1, 0, 12000),
  (96,  'max_cruise_speed',   'Cruise speed',       'integer', NULL,  'max_cruise_speed_kts','range_slider',1, 0, 1, 0, 0, 700),
  (97,  'engine_program',     'Engine programme',   'string',  NULL,  'engine_program',     'select',       1, 1, 0, 1, NULL, NULL),
  (98,  'avionics_suite',     'Avionics',           'string',  NULL,  'avionics_suite',     'select',       1, 0, 0, 0, NULL, NULL),
  (99,  'registration',       'Registration',       'string',  NULL,  'registration',       'text',         1, 0, 0, 0, NULL, NULL),

  -- Watches
  (120, 'reference_number',   'Reference',          'string',  NULL,  'reference_number',   'text',         1, 0, 0, 1, NULL, NULL),
  (121, 'year_of_production', 'Year',               'year',    NULL,  'year_of_production', 'year_select',  1, 1, 1, 1, 1850, 2035),
  (122, 'case_material',      'Case material',      'string',  NULL,  'case_material',      'select',       1, 1, 0, 1, NULL, NULL),
  (123, 'case_diameter_mm',   'Case diameter',      'decimal', 'mm',  'case_diameter_mm',   'range_slider', 1, 1, 1, 1, 15, 70),
  (124, 'movement_type',      'Movement',           'enum',    NULL,  'movement_type',      'select',       1, 1, 0, 1, NULL, NULL),
  (125, 'dial_color',         'Dial colour',        'string',  NULL,  'dial_color',         'select',       1, 1, 0, 0, NULL, NULL),
  (126, 'condition_grade',    'Condition',          'enum',    NULL,  'condition_grade',    'select',       1, 1, 0, 1, NULL, NULL),
  (127, 'is_full_set',        'Box & papers',       'boolean', NULL,  'is_full_set',        'toggle',       1, 1, 0, 1, NULL, NULL),
  (128, 'power_reserve_hours','Power reserve',      'integer', NULL,  'power_reserve_hours','range_slider', 1, 0, 1, 0, 0, 2000),
  (129, 'water_resistance_m', 'Water resistance',   'integer', 'm',   'water_resistance_m', 'select',       1, 0, 0, 0, 0, 12000),
  (130, 'complications',      'Complications',      'multi_enum', NULL, 'complications',    'multiselect',  1, 1, 0, 0, NULL, NULL),
  (131, 'gender',             'Gender',             'enum',    NULL,  'gender',             'select',       1, 1, 0, 0, NULL, NULL);

INSERT INTO attribute_options (attribute_id, value, label, sort_order) VALUES
  (7, 'unfurnished', 'Unfurnished', 1), (7, 'semi_furnished', 'Semi-furnished', 2), (7, 'furnished', 'Furnished', 3), (7, 'fully_fitted', 'Fully fitted', 4),
  (8, 'ready', 'Ready', 1), (8, 'off_plan', 'Off-plan', 2), (8, 'under_construction', 'Under construction', 3), (8, 'shell_and_core', 'Shell & core', 4),
  (9, 'freehold', 'Freehold', 1), (9, 'leasehold', 'Leasehold', 2), (9, 'usufruct', 'Usufruct', 3), (9, 'musataha', 'Musataha', 4), (9, 'commonhold', 'Commonhold', 5), (9, 'share_of_freehold', 'Share of freehold', 6),
  (33, 'automatic', 'Automatic', 1), (33, 'manual', 'Manual', 2), (33, 'semi_automatic', 'Semi-automatic', 3), (33, 'dual_clutch', 'Dual clutch', 4), (33, 'cvt', 'CVT', 5),
  (34, 'petrol', 'Petrol', 1), (34, 'diesel', 'Diesel', 2), (34, 'hybrid', 'Hybrid', 3), (34, 'plug_in_hybrid', 'Plug-in hybrid', 4), (34, 'electric', 'Electric', 5), (34, 'hydrogen', 'Hydrogen', 6),
  (38, 'rwd', 'Rear-wheel drive', 1), (38, 'awd', 'All-wheel drive', 2), (38, 'fwd', 'Front-wheel drive', 3), (38, '4wd', 'Four-wheel drive', 4),
  (40, 'new', 'New', 1), (40, 'used', 'Used', 2), (40, 'certified_pre_owned', 'Certified pre-owned', 3), (40, 'classic', 'Classic', 4),
  (41, 'left', 'Left-hand drive', 1), (41, 'right', 'Right-hand drive', 2),
  (42, 'GCC', 'GCC spec', 1), (42, 'European', 'European spec', 2), (42, 'American', 'American spec', 3), (42, 'Japanese', 'Japanese import', 4),
  (66, 'motor_yacht', 'Motor yacht', 1), (66, 'sailing_yacht', 'Sailing yacht', 2), (66, 'superyacht', 'Superyacht', 3), (66, 'catamaran', 'Catamaran', 4), (66, 'explorer', 'Explorer', 5), (66, 'sport_fisher', 'Sport fisher', 6),
  (67, 'grp', 'GRP / fibreglass', 1), (67, 'steel', 'Steel', 2), (67, 'aluminium', 'Aluminium', 3), (67, 'composite', 'Composite', 4), (67, 'wood', 'Wood', 5),
  (90, 'light_jet', 'Light jet', 1), (90, 'midsize_jet', 'Midsize jet', 2), (90, 'super_midsize_jet', 'Super midsize jet', 3), (90, 'heavy_jet', 'Heavy jet', 4), (90, 'ultra_long_range', 'Ultra long range', 5), (90, 'vip_airliner', 'VIP airliner', 6),
  (97, 'JSSI', 'JSSI', 1), (97, 'MSP Gold', 'MSP Gold', 2), (97, 'ESP Gold', 'ESP Gold', 3), (97, 'TAP Blue', 'TAP Blue', 4), (97, 'None', 'Not enrolled', 5),
  (122, 'Stainless Steel', 'Stainless steel', 1), (122, 'Yellow Gold', 'Yellow gold', 2), (122, 'White Gold', 'White gold', 3), (122, 'Rose Gold', 'Rose gold', 4), (122, 'Platinum', 'Platinum', 5), (122, 'Titanium', 'Titanium', 6), (122, 'Ceramic', 'Ceramic', 7), (122, 'Carbon', 'Carbon', 8),
  (124, 'automatic', 'Automatic', 1), (124, 'manual', 'Manual wind', 2), (124, 'quartz', 'Quartz', 3), (124, 'spring_drive', 'Spring Drive', 4),
  (126, 'new', 'New', 1), (126, 'unworn', 'Unworn', 2), (126, 'excellent', 'Excellent', 3), (126, 'very_good', 'Very good', 4), (126, 'good', 'Good', 5), (126, 'fair', 'Fair', 6),
  (131, 'mens', 'Men''s', 1), (131, 'ladies', 'Ladies', 2), (131, 'unisex', 'Unisex', 3);

-- Attribute-to-category bindings. Applied at the root so all listing types in a
-- class inherit them; overrides can be added per leaf category later.
INSERT INTO category_attributes (category_id, attribute_id, is_required, group_label, sort_order)
SELECT 1, id, IF(code IN ('bedrooms','bathrooms','built_area_sqft'), 1, 0),
       CASE WHEN code IN ('bedrooms','bathrooms','parking_spaces') THEN 'Layout'
            WHEN code LIKE '%area%' OR code = 'floor_number' THEN 'Dimensions'
            WHEN code IN ('completion_status','handover_date','year_built') THEN 'Completion'
            WHEN code IN ('ownership_type','permit_number','rental_yield') THEN 'Ownership'
            ELSE 'Details' END,
       id
  FROM attributes WHERE id BETWEEN 1 AND 15;

INSERT INTO category_attributes (category_id, attribute_id, is_required, group_label, sort_order)
SELECT 2, id, IF(code IN ('model_year','mileage_km'), 1, 0),
       CASE WHEN code IN ('horsepower','engine_size_cc','drivetrain','transmission','fuel_type') THEN 'Engine & performance'
            WHEN code IN ('condition_type','service_history','regional_spec','steering_side') THEN 'Provenance'
            ELSE 'Details' END,
       id
  FROM attributes WHERE id BETWEEN 30 AND 44;

INSERT INTO category_attributes (category_id, attribute_id, is_required, group_label, sort_order)
SELECT 3, id, IF(code IN ('length_overall_ft','build_year'), 1, 0),
       CASE WHEN code LIKE 'length%' OR code IN ('vessel_type','hull_material') THEN 'Dimensions'
            WHEN code IN ('cabins','guests_sleeping','crew_capacity') THEN 'Accommodation'
            WHEN code IN ('max_speed_knots','range_nm_marine','engine_hours') THEN 'Performance'
            ELSE 'Details' END,
       id
  FROM attributes WHERE id BETWEEN 60 AND 72;

INSERT INTO category_attributes (category_id, attribute_id, is_required, group_label, sort_order)
SELECT c.id, a.id, IF(a.code IN ('aircraft_year','total_time_hours'), 1, 0),
       CASE WHEN a.code IN ('total_time_hours','cycles','engine_program') THEN 'Airframe & engines'
            WHEN a.code IN ('range_nm_air','max_cruise_speed') THEN 'Performance'
            ELSE 'Details' END,
       a.id
  FROM categories c CROSS JOIN attributes a
 WHERE c.id IN (4, 5) AND a.id BETWEEN 90 AND 99;

INSERT INTO category_attributes (category_id, attribute_id, is_required, group_label, sort_order)
SELECT 6, id, IF(code IN ('reference_number','condition_grade'), 1, 0),
       CASE WHEN code IN ('case_material','case_diameter_mm','dial_color') THEN 'Case & dial'
            WHEN code IN ('movement_type','power_reserve_hours','complications') THEN 'Movement'
            WHEN code IN ('is_full_set','condition_grade') THEN 'Provenance'
            ELSE 'Details' END,
       id
  FROM attributes WHERE id BETWEEN 120 AND 131;

-- -----------------------------------------------------------------------------
-- Features / amenities
-- -----------------------------------------------------------------------------
INSERT INTO feature_groups (id, code, name, icon, sort_order) VALUES
  (1, 'outdoor',      'Outdoor & leisure', 'tree',     1),
  (2, 'indoor',       'Indoor amenities',  'sofa',     2),
  (3, 'building',     'Building & estate', 'building', 3),
  (4, 'security',     'Security & access', 'shield',   4),
  (5, 'views',        'Views & setting',   'eye',      5),
  (6, 'marine',       'Onboard',           'anchor',   6),
  (7, 'aviation',     'Cabin & equipment', 'plane',    7),
  (8, 'sustainable',  'Sustainability',    'leaf',     8);

INSERT INTO features (id, feature_group_id, code, slug, name, is_premium, sort_order) VALUES
  (1,  1, 'private_pool',      'private-pool',      'Private pool',              1, 1),
  (2,  1, 'shared_pool',       'shared-pool',       'Shared pool',               0, 2),
  (3,  1, 'infinity_pool',     'infinity-pool',     'Infinity pool',             1, 3),
  (4,  1, 'private_garden',    'private-garden',    'Private garden',            0, 4),
  (5,  1, 'terrace',           'terrace',           'Terrace',                   0, 5),
  (6,  1, 'balcony',           'balcony',           'Balcony',                   0, 6),
  (7,  1, 'private_beach',     'private-beach',     'Private beach access',      1, 7),
  (8,  1, 'tennis_court',      'tennis-court',      'Tennis court',              1, 8),
  (9,  1, 'padel_court',       'padel-court',       'Padel court',               1, 9),
  (10, 1, 'golf_access',       'golf-access',       'Golf course access',        1, 10),
  (11, 1, 'private_marina',    'private-marina',    'Private mooring',           1, 11),
  (12, 1, 'helipad',           'helipad',           'Helipad',                   1, 12),
  (13, 1, 'outdoor_kitchen',   'outdoor-kitchen',   'Outdoor kitchen',           0, 13),

  (20, 2, 'private_gym',       'private-gym',       'Private gym',               1, 1),
  (21, 2, 'shared_gym',        'shared-gym',        'Shared gym',                0, 2),
  (22, 2, 'home_cinema',       'home-cinema',       'Home cinema',               1, 3),
  (23, 2, 'wine_cellar',       'wine-cellar',       'Wine cellar',               1, 4),
  (24, 2, 'spa',               'spa',               'Spa',                       1, 5),
  (25, 2, 'sauna',             'sauna',             'Sauna',                     0, 6),
  (26, 2, 'steam_room',        'steam-room',        'Steam room',                0, 7),
  (27, 2, 'smart_home',        'smart-home',        'Smart home system',         0, 8),
  (28, 2, 'maids_room',        'maids-room',        'Maid''s room',              0, 9),
  (29, 2, 'drivers_room',      'drivers-room',      'Driver''s room',            0, 10),
  (30, 2, 'study',             'study',             'Study / home office',       0, 11),
  (31, 2, 'walk_in_closet',    'walk-in-closet',    'Walk-in closet',            0, 12),
  (32, 2, 'elevator',          'elevator',          'Private lift',              1, 13),
  (33, 2, 'fireplace',         'fireplace',         'Fireplace',                 0, 14),
  (34, 2, 'library',           'library',           'Library',                   1, 15),

  (40, 3, 'concierge',         'concierge',         'Concierge',                 1, 1),
  (41, 3, 'valet_parking',     'valet-parking',     'Valet parking',             1, 2),
  (42, 3, 'covered_parking',   'covered-parking',   'Covered parking',           0, 3),
  (43, 3, 'basement_parking',  'basement-parking',  'Basement parking',          0, 4),
  (44, 3, 'kids_play_area',    'kids-play-area',    'Children''s play area',     0, 5),
  (45, 3, 'bbq_area',          'bbq-area',          'Barbecue area',             0, 6),
  (46, 3, 'business_centre',   'business-centre',   'Business centre',           0, 7),
  (47, 3, 'retail_on_site',    'retail-on-site',    'Retail on site',            0, 8),
  (48, 3, 'pet_friendly',      'pet-friendly',      'Pet friendly',              0, 9),
  (49, 3, 'housekeeping',      'housekeeping',      'Housekeeping',              1, 10),

  (60, 4, 'gated_community',   'gated-community',   'Gated community',           1, 1),
  (61, 4, 'security_24_7',     'security-24-7',     '24/7 security',             0, 2),
  (62, 4, 'cctv',              'cctv',              'CCTV',                      0, 3),
  (63, 4, 'concierge_security','concierge-security','Manned reception',          0, 4),
  (64, 4, 'private_entrance',  'private-entrance',  'Private entrance',          1, 5),
  (65, 4, 'panic_room',        'panic-room',        'Panic room',                1, 6),

  (70, 5, 'sea_view',          'sea-view',          'Sea view',                  1, 1),
  (71, 5, 'beachfront',        'beachfront',        'Beachfront',                1, 2),
  (72, 5, 'marina_view',       'marina-view',       'Marina view',               1, 3),
  (73, 5, 'skyline_view',      'skyline-view',      'Skyline view',              1, 4),
  (74, 5, 'burj_khalifa_view', 'burj-khalifa-view', 'Burj Khalifa view',         1, 5),
  (75, 5, 'golf_view',         'golf-view',         'Golf course view',          1, 6),
  (76, 5, 'mountain_view',     'mountain-view',     'Mountain view',             1, 7),
  (77, 5, 'lake_view',         'lake-view',         'Lake view',                 1, 8),
  (78, 5, 'park_view',         'park-view',         'Park view',                 0, 9),
  (79, 5, 'city_view',         'city-view',         'City view',                 0, 10),
  (80, 5, 'vineyard_view',     'vineyard-view',     'Vineyard view',             1, 11),

  (90, 6, 'jacuzzi_deck',      'jacuzzi-deck',      'Deck jacuzzi',              1, 1),
  (91, 6, 'beach_club',        'beach-club',        'Beach club',                1, 2),
  (92, 6, 'stabilisers',       'stabilisers',       'Zero-speed stabilisers',    1, 3),
  (93, 6, 'tender_garage',     'tender-garage',     'Tender garage',             1, 4),
  (94, 6, 'jet_skis',          'jet-skis',          'Jet skis',                  0, 5),
  (95, 6, 'diving_equipment',  'diving-equipment',  'Diving equipment',          0, 6),
  (96, 6, 'gym_onboard',       'gym-onboard',       'Onboard gym',               1, 7),
  (97, 6, 'sun_deck',          'sun-deck',          'Sun deck',                  0, 8),
  (98, 6, 'crew_quarters',     'crew-quarters',     'Crew quarters',             0, 9),

  (110, 7, 'wifi_onboard',     'wifi-onboard',      'In-flight Wi-Fi',           1, 1),
  (111, 7, 'satellite_phone',  'satellite-phone',   'Satellite phone',           0, 2),
  (112, 7, 'full_galley',      'full-galley',       'Full galley',               0, 3),
  (113, 7, 'enclosed_lavatory','enclosed-lavatory', 'Enclosed lavatory',         0, 4),
  (114, 7, 'berthable_seats',  'berthable-seats',   'Berthable seats',           1, 5),
  (115, 7, 'shower_onboard',   'shower-onboard',    'Onboard shower',            1, 6),
  (116, 7, 'baggage_external', 'external-baggage',  'External baggage',          0, 7),

  (130, 8, 'solar_panels',     'solar-panels',      'Solar panels',              0, 1),
  (131, 8, 'ev_charging',      'ev-charging',       'EV charging',               0, 2),
  (132, 8, 'leed_certified',   'leed-certified',    'LEED certified',            1, 3),
  (133, 8, 'greywater_system', 'greywater-system',  'Greywater recycling',       0, 4);

-- Which features are offered for which asset class.
INSERT INTO category_features (category_id, feature_id, sort_order)
SELECT 1, id, sort_order FROM features WHERE feature_group_id IN (1, 2, 3, 4, 5, 8);
INSERT INTO category_features (category_id, feature_id, sort_order)
SELECT 3, id, sort_order FROM features WHERE feature_group_id IN (6, 5);
INSERT INTO category_features (category_id, feature_id, sort_order)
SELECT c.id, f.id, f.sort_order FROM categories c CROSS JOIN features f
 WHERE c.id IN (4, 5) AND f.feature_group_id = 7;

-- -----------------------------------------------------------------------------
-- Report reasons
-- -----------------------------------------------------------------------------
INSERT INTO report_reasons (id, code, name, description, applies_to, is_severe, auto_hide_threshold, sort_order) VALUES
  (1, 'sold_unavailable',  'Already sold or unavailable', 'The listing is no longer on the market.',                  'listing',                                        0, 5,    1),
  (2, 'wrong_price',       'Incorrect price',             'The advertised price is wrong or misleading.',             'listing',                                        0, NULL, 2),
  (3, 'wrong_location',    'Incorrect location',          'The listing is not where it says it is.',                  'listing',                                        0, NULL, 3),
  (4, 'duplicate',         'Duplicate listing',           'The same asset is listed more than once.',                 'listing',                                        0, NULL, 4),
  (5, 'fake_listing',      'Fake or fraudulent',          'The listing appears fabricated or is a scam.',             'listing,agent,organization',                     1, 2,    5),
  (6, 'wrong_photos',      'Photos do not match',         'The images are of a different property or are stolen.',    'listing',                                        0, NULL, 6),
  (7, 'offensive_content', 'Offensive content',           'Contains abusive, discriminatory or explicit material.',   'listing,review,message,user',                    1, 1,    7),
  (8, 'spam',              'Spam',                        'Unsolicited or repetitive promotional content.',           'listing,review,message,user',                    0, 3,    8),
  (9, 'impersonation',     'Impersonation',               'Pretends to be another person, agency or brand.',          'agent,organization,user',                        1, 1,    9),
  (10,'unlicensed',        'Unlicensed practice',         'Operating without the required licence or registration.',  'agent,organization',                             1, 2,   10),
  (11,'harassment',        'Harassment',                  'Targeted abuse or unwanted contact.',                      'message,user,review',                            1, 1,   11),
  (12,'misleading_review', 'Misleading review',           'Review is fabricated, incentivised, or not a real client.', 'review',                                        0, 3,   12),
  (13,'privacy',           'Privacy violation',           'Discloses personal information without consent.',          'listing,review,message',                         1, 1,   13),
  (14,'other',             'Something else',              'Anything not covered by the reasons above.',               'listing,agent,organization,review,message,user,project', 0, NULL, 14);
