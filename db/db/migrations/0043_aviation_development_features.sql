-- =============================================================================
-- Liv Finder — 0043 · features & amenities for Jets, Helicopters and Developments
-- =============================================================================
-- After 0041, Jets and Helicopters still had only the 7 shared "Cabin &
-- equipment" rows, and Real Estate Developments (root category 7, added in 0040)
-- had none at all — so the add-listing Features step was almost empty for aircraft
-- and completely empty for a development. This adds a proper catalogue for each,
-- grouped the way the form renders it.
--
-- IDEMPOTENT. feature `code`/`slug` are unique; `category_features` is keyed on
-- (category_id, feature_id). Safe to re-run.
-- =============================================================================

SET NAMES utf8mb4;

INSERT INTO feature_groups (id, code, name, icon, sort_order) VALUES
  (16, 'aviation_avionics', 'Avionics & navigation',    'radar',  16),
  (17, 'aviation_cabin',    'Cabin comfort',            'sofa',   17),
  (18, 'aviation_jet_ops',  'Operations & pedigree',    'wrench', 18),
  (19, 'heli_ops',          'Rotorcraft equipment',     'wind',   19),
  (20, 'dev_amenity',       'Community amenities',      'trees',  20),
  (21, 'dev_spec',          'Finishes & specification', 'ruler',  21),
  (22, 'dev_payment',       'Payment & ownership',      'wallet', 22)
ON DUPLICATE KEY UPDATE name = VALUES(name), icon = VALUES(icon), sort_order = VALUES(sort_order);

INSERT INTO features (id, feature_group_id, code, slug, name, is_premium, sort_order) VALUES
  -- Aviation · avionics & navigation (jets + helicopters)
  (300, 16, 'ads_b_out',          'ads-b-out',          'ADS-B Out',                     0, 1),
  (301, 16, 'synthetic_vision',   'synthetic-vision',   'Synthetic vision',              1, 2),
  (302, 16, 'weather_radar',      'weather-radar',      'Weather radar',                 0, 3),
  (303, 16, 'tcas_ii',            'tcas-ii',            'TCAS II',                       0, 4),
  (304, 16, 'egpws',              'egpws',              'EGPWS / TAWS',                  0, 5),
  (305, 16, 'fms',                'fms',                'Flight management system',      0, 6),
  (306, 16, 'avionics_hud',       'avionics-hud',       'Head-up display',               1, 7),
  (307, 16, 'autoland',           'autoland',           'Emergency autoland',            1, 8),
  (308, 16, 'cpdlc_fans',         'cpdlc-fans',         'CPDLC / FANS 1/A',              0, 9),
  (309, 16, 'rvsm',               'rvsm',               'RVSM approved',                 0, 10),
  -- Aviation · cabin comfort (jets + helicopters)
  (310, 17, 'full_galley',        'full-galley',        'Full galley',                   0, 1),
  (311, 17, 'enclosed_lav',       'enclosed-lav',       'Enclosed lavatory',             0, 2),
  (312, 17, 'lie_flat_seats',     'lie-flat-seats',     'Lie-flat seats',                1, 3),
  (313, 17, 'berthable_divan',    'berthable-divan',    'Berthable divan',               1, 4),
  (314, 17, 'cabin_entertainment','cabin-entertainment','Cabin entertainment system',    0, 5),
  (315, 17, 'cabin_mgmt_system',  'cabin-mgmt-system',  'Cabin management system',       0, 6),
  (316, 17, 'cabin_wifi',         'cabin-wifi',         'In-flight Wi-Fi',               0, 7),
  (317, 17, 'ka_band',            'ka-band',            'Ka-band high-speed internet',   1, 8),
  (318, 17, 'sound_proofed',      'sound-proofed',      'Sound-proofed cabin',           0, 9),
  (319, 17, 'crew_rest',          'crew-rest',          'Crew rest area',                1, 10),
  -- Aviation · operations & pedigree (jets)
  (322, 18, 'engine_program',     'engine-program',     'Engine maintenance programme',  0, 1),
  (323, 18, 'apu_program',        'apu-program',        'APU on programme',              0, 2),
  (324, 18, 'fresh_paint',        'fresh-paint',        'Fresh exterior paint (<2 yrs)', 0, 3),
  (325, 18, 'fresh_interior',     'fresh-interior',     'Refurbished interior (<2 yrs)', 0, 4),
  (326, 18, 'no_damage_history',  'no-damage-history',  'No damage history',             0, 5),
  (327, 18, 'single_owner',       'single-owner',       'Single owner since new',        1, 6),
  (328, 18, 'part_135_ready',     'part-135-ready',     'Part 135 / AOC ready',          0, 7),
  (329, 18, 'us_eu_registered',   'us-eu-registered',   'US / EU registered',            0, 8),
  -- Rotorcraft · equipment (helicopters)
  (332, 19, 'wire_strike',        'wire-strike',        'Wire strike protection',        0, 1),
  (333, 19, 'emergency_floats',   'emergency-floats',   'Emergency / pop-out floats',    0, 2),
  (334, 19, 'cargo_hook',         'cargo-hook',         'Cargo hook',                    0, 3),
  (335, 19, 'rescue_hoist',       'rescue-hoist',       'Rescue hoist',                  1, 4),
  (336, 19, 'nvg_compatible',     'nvg-compatible',     'NVG compatible',                1, 5),
  (337, 19, 'heli_air_con',       'heli-air-con',       'Air conditioning',              0, 6),
  (338, 19, 'dual_controls',      'dual-controls',      'Dual controls',                 0, 7),
  (339, 19, 'ifr_equipped',       'ifr-equipped',       'IFR equipped',                  0, 8),
  -- Developments · community amenities
  (350, 20, 'dev_pool',           'dev-pool',           'Swimming pool',                 0, 1),
  (351, 20, 'dev_gym',            'dev-gym',            'Gymnasium',                     0, 2),
  (352, 20, 'dev_kids_play',      'dev-kids-play',      'Kids play area',                0, 3),
  (353, 20, 'dev_gardens',        'dev-gardens',        'Landscaped gardens',            0, 4),
  (354, 20, 'dev_jogging',        'dev-jogging',        'Jogging & cycling track',       0, 5),
  (355, 20, 'dev_clubhouse',      'dev-clubhouse',      'Residents clubhouse',           0, 6),
  (356, 20, 'dev_retail',         'dev-retail',         'Retail promenade',              0, 7),
  (357, 20, 'dev_concierge',      'dev-concierge',      'Concierge service',             1, 8),
  (358, 20, 'dev_security_247',   'dev-security-247',   '24/7 security',                 0, 9),
  (359, 20, 'dev_covered_parking','dev-covered-parking','Covered parking',               0, 10),
  (360, 20, 'dev_bbq',            'dev-bbq',            'BBQ & picnic areas',            0, 11),
  (361, 20, 'dev_coworking',      'dev-coworking',      'Co-working spaces',             0, 12),
  (362, 20, 'dev_courts',         'dev-courts',         'Padel / tennis courts',         0, 13),
  (363, 20, 'dev_beach_access',   'dev-beach-access',   'Private beach access',          1, 14),
  -- Developments · finishes & specification
  (364, 21, 'dev_branded',        'dev-branded',        'Branded residences',            1, 1),
  (365, 21, 'dev_smart_home',     'dev-smart-home',     'Smart-home wiring',             0, 2),
  (366, 21, 'dev_floor_ceiling',  'dev-floor-ceiling',  'Floor-to-ceiling windows',      0, 3),
  (367, 21, 'dev_private_lift',   'dev-private-lift',    'Private lift lobby',            1, 4),
  (368, 21, 'dev_appliances',     'dev-appliances',     'Fitted kitchen appliances',     0, 5),
  (369, 21, 'dev_central_ac',     'dev-central-ac',      'Central air conditioning',      0, 6),
  (370, 21, 'dev_maid_room',      'dev-maid-room',       'Maid / staff room',             0, 7),
  (371, 21, 'dev_storage',        'dev-storage',         'Storage room',                  0, 8),
  (372, 21, 'dev_balcony',        'dev-balcony',         'Balcony / terrace',             0, 9),
  -- Developments · payment & ownership
  (373, 22, 'dev_post_handover',  'dev-post-handover',   'Post-handover payment plan',    0, 1),
  (374, 22, 'dev_interest_free',  'dev-interest-free',   'Interest-free instalments',     0, 2),
  (375, 22, 'dev_zero_commission','dev-zero-commission', '0% commission',                 0, 3),
  (376, 22, 'dev_fee_waiver',     'dev-fee-waiver',      'Registration fee waiver',       0, 4),
  (377, 22, 'dev_rental_guarantee','dev-rental-guarantee','Guaranteed rental return',     1, 5),
  (378, 22, 'dev_golden_visa',    'dev-golden-visa',     'Golden Visa eligible',          1, 6),
  (379, 22, 'dev_freehold',       'dev-freehold',        'Freehold ownership',            0, 7)
ON DUPLICATE KEY UPDATE feature_group_id = VALUES(feature_group_id), name = VALUES(name),
                        is_premium = VALUES(is_premium), sort_order = VALUES(sort_order);

-- Jets = category 4, Helicopters = 5, Real Estate Developments = 7 (root ids).
-- Jets: shared avionics + cabin + jet ops.
INSERT INTO category_features (category_id, feature_id, sort_order)
SELECT 4, id, sort_order FROM features WHERE feature_group_id IN (16, 17, 18)
ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order);

-- Helicopters: shared avionics + cabin + rotorcraft equipment.
INSERT INTO category_features (category_id, feature_id, sort_order)
SELECT 5, id, sort_order FROM features WHERE feature_group_id IN (16, 17, 19)
ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order);

-- Developments: community amenities + finishes + payment.
INSERT INTO category_features (category_id, feature_id, sort_order)
SELECT 7, id, sort_order FROM features WHERE feature_group_id IN (20, 21, 22)
ON DUPLICATE KEY UPDATE sort_order = VALUES(sort_order);

INSERT INTO schema_migrations (version, name) VALUES ('0043', 'aviation_development_features')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
