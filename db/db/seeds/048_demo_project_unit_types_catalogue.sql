-- =============================================================================
-- Liv Finder — demo seed · a price list for every development
-- =============================================================================
-- 048_demo_project_unit_types.sql derives a development's unit types from the listings filed
-- inside it. The demo listings are not filed inside any development — and linking unrelated
-- ones would be worse (a Miami mansion "inside" a Dubai tower) — so that file produces nothing,
-- and a development page had no price list, no bedroom range and no unit-size facet.
--
-- This gives each development without unit types a price list of its own kind:
--
--   towers (residential, branded, hotel, mixed use)   studio · 1–3-bedroom apartments · penthouse
--   master communities                                 townhouse · 4–6-bedroom villas
--   commercial                                         office suite · full floor · retail unit
--
-- Prices sit inside the development's own published range (min_price → max_price), sizes are in
-- square feet to match the listing side, and availability follows the development's inventory
-- exactly as 048_demo_project_unit_types.sql does. A development that already has any unit type
-- is left alone.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;

INSERT INTO project_unit_types
  (public_id, project_id, unit_type, category_id, name, bedrooms, bathrooms,
   min_size, max_size, area_unit_id, starting_price, max_price, currency_code,
   availability, sort_order)
SELECT
  CONCAT('01JZPTDEMNTYPF', LPAD(ROW_NUMBER() OVER (ORDER BY p.id, t.sort_order), 12, '0')),
  p.id, t.unit_type, c.id, t.name, t.bedrooms, t.bathrooms, t.min_size, t.max_size,
  (SELECT id FROM measurement_units WHERE code = 'sqft'),
  CASE WHEN p.min_price IS NULL OR p.max_price IS NULL THEN NULL
       ELSE ROUND(p.min_price + (p.max_price - p.min_price) * t.price_from, -3) END,
  CASE WHEN p.min_price IS NULL OR p.max_price IS NULL THEN NULL
       ELSE ROUND(p.min_price + (p.max_price - p.min_price) * t.price_to, -3) END,
  p.currency_code,
  CASE
    WHEN p.available_units = 0 THEN 'sold_out'
    WHEN p.total_units > 0 AND p.available_units * 10 < p.total_units THEN 'limited'
    ELSE 'available'
  END,
  t.sort_order
FROM projects p
JOIN (
            SELECT 'tower' AS layout, 1 AS sort_order, 'studio' AS unit_type, 'apartment' AS category_code,
                   'Studio' AS name, NULL AS bedrooms, 1.0 AS bathrooms, 420 AS min_size, 560 AS max_size,
                   0.00 AS price_from, 0.08 AS price_to
  UNION ALL SELECT 'tower', 2, 'apartment', 'apartment', '1-bedroom apartment', 1, 1.5, 720, 950, 0.06, 0.18
  UNION ALL SELECT 'tower', 3, 'apartment', 'apartment', '2-bedroom apartment', 2, 2.5, 1100, 1480, 0.16, 0.32
  UNION ALL SELECT 'tower', 4, 'apartment', 'apartment', '3-bedroom apartment', 3, 3.5, 1600, 2150, 0.30, 0.52
  UNION ALL SELECT 'tower', 5, 'penthouse', 'penthouse', '4-bedroom penthouse', 4, 5.0, 3800, 5400, 0.62, 1.00
  UNION ALL SELECT 'community', 1, 'townhouse', 'townhouse', '3-bedroom townhouse', 3, 3.5, 2100, 2600, 0.00, 0.22
  UNION ALL SELECT 'community', 2, 'villa', 'villa', '4-bedroom villa', 4, 4.5, 3600, 4400, 0.20, 0.48
  UNION ALL SELECT 'community', 3, 'villa', 'villa', '5-bedroom villa', 5, 5.5, 5000, 6400, 0.45, 0.75
  UNION ALL SELECT 'community', 4, 'villa', 'villa', '6-bedroom signature villa', 6, 7.0, 7200, 9800, 0.70, 1.00
  UNION ALL SELECT 'commercial', 1, 'office', 'office', 'Office suite', NULL, 1.0, 850, 2400, 0.00, 0.40
  UNION ALL SELECT 'commercial', 2, 'floor', 'office', 'Full-floor office', NULL, 4.0, 6500, 12000, 0.45, 1.00
  UNION ALL SELECT 'commercial', 3, 'retail', 'retail', 'Retail unit', NULL, 1.0, 600, 1900, 0.10, 0.55
) t ON t.layout = CASE p.project_type
                    WHEN 'master_community' THEN 'community'
                    WHEN 'commercial' THEN 'commercial'
                    ELSE 'tower' END
JOIN categories c ON c.code = t.category_code
WHERE p.deleted_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM project_unit_types x WHERE x.project_id = p.id);

COMMIT;
SET autocommit = 1;

-- Bedroom range, unit types and availability are aggregates in the projection.
CALL sp_refresh_project_search(NULL);
