-- =============================================================================
-- Liv Finder — 0041 · features & amenities for Cars and Watches
-- =============================================================================
-- `category_features` had rows only for real estate, yachts, jets and
-- helicopters, so the add-listing form's Features step showed "no features
-- listed for this category yet" for a car or a watch and a lister had nothing to
-- pick. This adds a real catalogue for both, grouped the way the form renders
-- them.
--
-- IDEMPOTENT. Safe to re-run — feature `code`/`slug` are unique and
-- `category_features` is keyed on (category_id, feature_id).
-- =============================================================================

SET NAMES utf8mb4;

INSERT INTO feature_groups (id, code, name, icon, sort_order) VALUES
  (9,  'car_comfort',   'Comfort & interior',            'sofa',    9),
  (10, 'car_safety',    'Driver assistance & safety',    'shield',  10),
  (11, 'car_tech',      'Infotainment & connectivity',   'radio',   11),
  (12, 'car_exterior',  'Exterior & performance',        'gauge',   12),
  (13, 'watch_case',    'Case & dial',                   'circle',  13),
  (14, 'watch_movement','Movement & complications',      'cog',     14),
  (15, 'watch_strap',   'Strap & bracelet',              'link',    15)
ON DUPLICATE KEY UPDATE name = VALUES(name), icon = VALUES(icon), sort_order = VALUES(sort_order);

INSERT INTO features (id, feature_group_id, code, slug, name, is_premium, sort_order) VALUES
  -- Cars · comfort & interior
  (200, 9, 'leather_seats',       'leather-seats',        'Leather seats',              0, 1),
  (201, 9, 'ventilated_seats',    'ventilated-seats',     'Ventilated seats',           1, 2),
  (202, 9, 'heated_seats',        'heated-seats',         'Heated seats',               0, 3),
  (203, 9, 'memory_seats',        'memory-seats',         'Memory seats',               0, 4),
  (204, 9, 'massage_seats',       'massage-seats',        'Massage seats',              1, 5),
  (205, 9, 'panoramic_roof',      'panoramic-roof',       'Panoramic roof',             1, 6),
  (206, 9, 'sunroof',             'sunroof',              'Sunroof',                    0, 7),
  (207, 9, 'ambient_lighting',    'ambient-lighting',     'Ambient lighting',           0, 8),
  (208, 9, 'rear_entertainment',  'rear-entertainment',   'Rear-seat entertainment',    1, 9),
  (209, 9, 'quad_zone_climate',   'quad-zone-climate',    '4-zone climate control',     1, 10),
  (210, 9, 'power_tailgate',      'power-tailgate',       'Power tailgate',             0, 11),
  (211, 9, 'keyless_entry',       'keyless-entry',        'Keyless entry & start',      0, 12),
  -- Cars · driver assistance & safety
  (215, 10, 'adaptive_cruise',       'adaptive-cruise',       'Adaptive cruise control',        1, 1),
  (216, 10, 'lane_keep_assist',      'lane-keep-assist',      'Lane-keep assist',               0, 2),
  (217, 10, 'blind_spot_monitor',    'blind-spot-monitor',    'Blind-spot monitor',             0, 3),
  (218, 10, 'auto_emergency_brake',  'auto-emergency-brake',  'Autonomous emergency braking',   0, 4),
  (219, 10, 'parking_sensors',       'parking-sensors',       'Parking sensors',                0, 5),
  (220, 10, 'surround_camera',       'surround-camera',       '360° camera',                    1, 6),
  (221, 10, 'head_up_display',       'head-up-display',       'Head-up display',                1, 7),
  (222, 10, 'night_vision',          'night-vision',          'Night vision',                   1, 8),
  (223, 10, 'self_parking',          'self-parking',          'Self-parking',                   1, 9),
  (224, 10, 'adaptive_headlights',   'adaptive-headlights',   'Adaptive LED headlights',        0, 10),
  -- Cars · infotainment & connectivity
  (230, 11, 'apple_carplay',      'apple-carplay',        'Apple CarPlay',              0, 1),
  (231, 11, 'android_auto',       'android-auto',         'Android Auto',               0, 2),
  (232, 11, 'wireless_charging',  'wireless-charging',     'Wireless phone charging',    0, 3),
  (233, 11, 'premium_sound',      'premium-sound',        'Premium sound system',       1, 4),
  (234, 11, 'navigation_system',  'navigation-system',    'Built-in navigation',        0, 5),
  (235, 11, 'digital_cockpit',    'digital-cockpit',      'Digital instrument cluster', 0, 6),
  (236, 11, 'wifi_hotspot',       'wifi-hotspot',         'Wi-Fi hotspot',              1, 7),
  (237, 11, 'ota_updates',        'ota-updates',          'Over-the-air updates',       1, 8),
  -- Cars · exterior & performance
  (240, 12, 'alloy_wheels',       'alloy-wheels',         'Alloy wheels',               0, 1),
  (241, 12, 'carbon_package',     'carbon-package',       'Carbon-fibre package',       1, 2),
  (242, 12, 'sport_exhaust',      'sport-exhaust',        'Sport exhaust',              1, 3),
  (243, 12, 'air_suspension',     'air-suspension',       'Adaptive air suspension',    1, 4),
  (244, 12, 'ceramic_brakes',     'ceramic-brakes',       'Carbon-ceramic brakes',      1, 5),
  (245, 12, 'limited_slip_diff',  'limited-slip-diff',    'Limited-slip differential',  1, 6),
  (246, 12, 'launch_control',     'launch-control',       'Launch control',             1, 7),
  (247, 12, 'tow_package',        'tow-package',          'Tow package',                0, 8),
  (248, 12, 'roof_rails',         'roof-rails',           'Roof rails',                 0, 9),
  (249, 12, 'soft_close_doors',   'soft-close-doors',     'Soft-close doors',           1, 10),
  -- Watches · case & dial
  (260, 13, 'sapphire_crystal',     'sapphire-crystal',     'Sapphire crystal',           0, 1),
  (261, 13, 'ceramic_bezel',        'ceramic-bezel',        'Ceramic bezel',              1, 2),
  (262, 13, 'luminous_hands',       'luminous-hands',       'Luminous hands & markers',   0, 3),
  (263, 13, 'exhibition_caseback',  'exhibition-caseback',  'Exhibition caseback',        0, 4),
  (264, 13, 'diamond_set',          'diamond-set',          'Diamond-set',                1, 5),
  (265, 13, 'skeleton_dial',        'skeleton-dial',        'Skeleton dial',              1, 6),
  (266, 13, 'guilloche_dial',       'guilloche-dial',       'Guilloché dial',             1, 7),
  (267, 13, 'screw_down_crown',     'screw-down-crown',     'Screw-down crown',           0, 8),
  -- Watches · movement & complications
  (270, 14, 'automatic_movement',   'automatic-movement',   'Automatic movement',         0, 1),
  (271, 14, 'manual_wind',          'manual-wind',          'Manual-wind movement',       0, 2),
  (272, 14, 'chronograph',          'chronograph',          'Chronograph',                0, 3),
  (273, 14, 'gmt_function',         'gmt-function',         'GMT / dual time',            0, 4),
  (274, 14, 'perpetual_calendar',   'perpetual-calendar',   'Perpetual calendar',         1, 5),
  (275, 14, 'moonphase',            'moonphase',            'Moonphase',                  1, 6),
  (276, 14, 'tourbillon',           'tourbillon',           'Tourbillon',                 1, 7),
  (277, 14, 'power_reserve_ind',    'power-reserve-ind',    'Power reserve indicator',    0, 8),
  (278, 14, 'minute_repeater',      'minute-repeater',      'Minute repeater',            1, 9),
  -- Watches · strap & bracelet
  (285, 15, 'bracelet_steel',       'bracelet-steel',       'Steel bracelet',             0, 1),
  (286, 15, 'bracelet_gold',        'bracelet-gold',        'Gold bracelet',              1, 2),
  (287, 15, 'leather_strap',        'leather-strap',        'Leather strap',              0, 3),
  (288, 15, 'rubber_strap',         'rubber-strap',         'Rubber strap',               0, 4),
  (289, 15, 'deployant_clasp',      'deployant-clasp',      'Deployant clasp',            0, 5),
  (290, 15, 'quick_release_strap',  'quick-release-strap',  'Quick-release strap',        0, 6)
ON DUPLICATE KEY UPDATE feature_group_id = VALUES(feature_group_id), name = VALUES(name),
                        is_premium = VALUES(is_premium), sort_order = VALUES(sort_order);

-- Cars = category 2, Watches = category 6 (root ids; see utils/categories.js).
INSERT INTO category_features (category_id, feature_id, sort_order)
SELECT 2, id, sort_order FROM features WHERE feature_group_id IN (9, 10, 11, 12)
ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order);

INSERT INTO category_features (category_id, feature_id, sort_order)
SELECT 6, id, sort_order FROM features WHERE feature_group_id IN (13, 14, 15)
ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order);

INSERT INTO schema_migrations (version, name) VALUES ('0041', 'car_watch_features')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
