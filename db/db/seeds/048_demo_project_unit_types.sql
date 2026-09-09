-- =============================================================================
-- Liv Finder — demo seed · project unit types
-- =============================================================================
-- `project_unit_types` shipped empty, and it is the only source of
-- `project_search.unit_types` and `project_search.bedroom_values`. With the
-- table empty both projection columns were NULL for every project, which broke
-- the two places that read them:
--
--   * `GET /v1/public/projects/facets?facet=propertyType` returned `[]`, so the
--     Real Estate category strip could only count listings. A chip read
--     "Apartments 9" over a mixed page that also holds developments.
--   * `?propertyType=` on projects is `FIND_IN_SET(?, ps.unit_types)`, and
--     FIND_IN_SET against NULL is NULL — so selecting any category dropped
--     *every* development from the mixed results.
--
-- Both are data, not code: the filter and the facet are correct against a
-- catalogue that says what its projects sell.
--
-- Every row below is DERIVED FROM THE PROJECT'S OWN LISTINGS. A project sells
-- the unit types that the listings pointing at it are filed under, at the sizes,
-- bathroom counts and prices those listings carry. Nothing is asserted that the
-- catalogue does not already hold, so a chip's count cannot contradict the page
-- it opens.
--
-- Two deliberate narrowings:
--
--   * Sizes are square feet, because that is the unit the listing projection filters on and
--     the projects API compares the request value to the column as-is.
--   * Bedrooms are carried across for residential types only. The demo listings
--     assign bedrooms regardless of category — there are offices with eight and
--     plots with five — and copying that into `bedroom_values` would make the
--     beds filter offer "8-bed office". Commercial rows are left bedroom-less,
--     which is also what a real price list looks like.
--   * A zero-bedroom apartment is a studio, and is filed as one. That is the
--     vocabulary's own distinction, not a reclassification.
--
-- Listing categories with no counterpart in the unit-type enum — `mansions`,
-- `estates`, `chalets`, `islands`, `vineyards` — are deliberately absent. They
-- are listing categories, not unit types; their chips keep their listing counts
-- and match no development, which is what the catalogue actually says.
--
-- IDEMPOTENT, and safe over edited data: a project that already has any unit
-- type is skipped entirely, so a price list entered through the admin wizard is
-- never added to or overwritten.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;

INSERT INTO project_unit_types
  (public_id, project_id, unit_type, category_id, name, bedrooms, bathrooms,
   min_size, max_size, area_unit_id, starting_price, max_price, currency_code,
   availability, sort_order)
SELECT
  -- Deterministic, so a reload of this file against a truncated table produces
  -- the same ids rather than a second set colliding on the unique key.
  CONCAT('01JZPTDEMNTYPE000',
         LPAD(ROW_NUMBER() OVER (ORDER BY d.project_id, d.unit_type, COALESCE(d.bedrooms, 99)), 9, '0')),
  d.project_id,
  d.unit_type,
  d.category_id,
  CONCAT(
    UPPER(LEFT(CONCAT_WS(' ',
      IF(d.bedrooms IS NULL, NULL, CONCAT(d.bedrooms, '-bedroom')),
      REPLACE(d.unit_type, '_', ' ')
    ), 1)),
    SUBSTRING(CONCAT_WS(' ',
      IF(d.bedrooms IS NULL, NULL, CONCAT(d.bedrooms, '-bedroom')),
      REPLACE(d.unit_type, '_', ' ')
    ), 2)
  ),
  d.bedrooms,
  d.bathrooms,
  d.min_size,
  d.max_size,
  -- Square feet, to match the listing side.
  --
  -- `listing_search.spec_c` — what `areaMin`/`areaMax` filter listings on — holds sqft, and
  -- `projects.repository` compares `ps.area_min` to the same request value with no unit
  -- conversion. Sizing these rows in square metres would have made one area range mean two
  -- different things across the shared Real Estate result stream, off by a factor of ten.
  (SELECT id FROM measurement_units WHERE code = 'sqft'),
  d.starting_price,
  d.max_price,
  d.currency_code,
  d.availability,
  ROW_NUMBER() OVER (PARTITION BY d.project_id ORDER BY d.unit_type, COALESCE(d.bedrooms, 99))
FROM (
  SELECT
    l.project_id AS project_id,
    CASE WHEN m.unit_type = 'apartment' AND re.bedrooms = 0 THEN 'studio' ELSE m.unit_type END AS unit_type,
    CASE WHEN m.is_residential = 1 AND re.bedrooms > 0 THEN re.bedrooms END AS bedrooms,
    MIN(l.category_id) AS category_id,
    ROUND(AVG(re.bathrooms), 1) AS bathrooms,
    MIN(re.built_area_sqft) AS min_size,
    MAX(re.built_area_sqft) AS max_size,
    MIN(l.price) AS starting_price,
    MAX(l.price) AS max_price,
    MIN(l.currency_code) AS currency_code,
    -- The project already publishes how much of itself is left; the unit type
    -- inherits it rather than claiming an availability of its own.
    CASE
      WHEN p.available_units = 0 THEN 'sold_out'
      WHEN p.total_units > 0 AND p.available_units * 10 < p.total_units THEN 'limited'
      ELSE 'available'
    END AS availability
  FROM listings l
  JOIN listing_real_estate re ON re.listing_id = l.id
  JOIN categories c ON c.id = l.category_id
  JOIN projects p ON p.id = l.project_id AND p.deleted_at IS NULL
  -- The two vocabularies, joined where they genuinely correspond.
  JOIN (
              SELECT 'apartments'       AS slug, 'apartment'      AS unit_type, 1 AS is_residential
    UNION ALL SELECT 'hotel-apartments',        'apartment',                    1
    UNION ALL SELECT 'penthouses',              'penthouse',                    1
    UNION ALL SELECT 'duplexes',                'duplex',                       1
    UNION ALL SELECT 'villas',                  'villa',                        1
    UNION ALL SELECT 'townhouses',              'townhouse',                    1
    UNION ALL SELECT 'offices',                 'office',                       0
    UNION ALL SELECT 'retail',                  'retail',                       0
    UNION ALL SELECT 'plots',                   'plot',                         0
    UNION ALL SELECT 'buildings',               'whole_building',               0
  ) m ON m.slug = c.slug
  WHERE l.deleted_at IS NULL
    AND NOT EXISTS (SELECT 1 FROM project_unit_types x WHERE x.project_id = l.project_id)
  GROUP BY
    l.project_id,
    CASE WHEN m.unit_type = 'apartment' AND re.bedrooms = 0 THEN 'studio' ELSE m.unit_type END,
    CASE WHEN m.is_residential = 1 AND re.bedrooms > 0 THEN re.bedrooms END,
    p.available_units,
    p.total_units
) d;

COMMIT;
SET autocommit = 1;

-- `unit_types` and `bedroom_values` are aggregates over the rows just inserted,
-- so the projection has to be rebuilt or the facet stays empty.
CALL sp_refresh_project_search(NULL);
