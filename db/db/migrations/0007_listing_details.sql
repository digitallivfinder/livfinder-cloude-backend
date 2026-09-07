-- =============================================================================
-- Liv Finder — 0007 · Per-category listing detail tables
-- =============================================================================
-- Class-table inheritance: one detail table per asset class, each keyed 1:1 on
-- `listings.id`, holding that class's filterable specifications as real typed,
-- indexed columns.
--
-- WHY NOT JUST USE THE JSON COLUMN?
-- ---------------------------------
-- Because "3+ bedrooms, 2,000–4,000 sqft, in Dubai Marina, under AED 5m" has to
-- be answerable from indexes. A predicate over JSON_EXTRACT cannot use an
-- ordinary B-tree, so it degrades to a full scan of every candidate row. MySQL
-- 8.0.17+ multi-valued indexes help with array membership but not with the range
-- comparisons that dominate real filtering. Typed columns are the only thing
-- that makes a range filter an index seek.
--
-- WHY NOT PUT THEM ALL ON `listings`?
-- -----------------------------------
-- Roughly 70 columns across six classes, of which any given row uses ~12. That
-- is a permanently sparse, permanently wide clustered index on the busiest table
-- in the system — every scan drags dead weight through the buffer pool.
--
-- Five tables, not six: helicopters and jets share `listing_aviation` because
-- their specifications are genuinely the same shape (airframe hours, cycles,
-- seats, range, engines, registration). Splitting them would duplicate a schema
-- to express a distinction `root_category_id` already makes.
--
-- Each table is INSERTed only for listings of its class, so a query against one
-- touches only its own rows. `categories.detail_table` records the mapping so
-- the application dispatches from data rather than a hardcoded switch.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- listing_real_estate
-- -----------------------------------------------------------------------------
CREATE TABLE listing_real_estate (
  listing_id     BIGINT UNSIGNED NOT NULL,

  -- `bedrooms` is a SMALLINT with 0 meaning studio, which is how the market
  -- talks about it and how the filter chip renders ("Studio, 1, 2, 3…").
  bedrooms       SMALLINT UNSIGNED NULL,
  bathrooms      SMALLINT UNSIGNED NULL,
  -- Half-baths are common in US and European listings and users do filter on
  -- the combined figure, so it is stored rather than derived.
  half_bathrooms SMALLINT UNSIGNED NULL,
  reception_rooms SMALLINT UNSIGNED NULL,
  maid_rooms     SMALLINT UNSIGNED NULL,
  parking_spaces SMALLINT UNSIGNED NULL,

  -- Areas are stored canonically in square metres and mirrored to square feet.
  -- Both are indexed because the two halves of the market genuinely filter in
  -- different units, and converting inside a WHERE clause would defeat the index.
  built_area_sqm DECIMAL(12,2)   NULL,
  built_area_sqft DECIMAL(12,2)  NULL,
  plot_area_sqm  DECIMAL(12,2)   NULL,
  plot_area_sqft DECIMAL(12,2)   NULL,
  terrace_area_sqm DECIMAL(12,2) NULL,

  floor_number   SMALLINT        NULL,
  total_floors   SMALLINT UNSIGNED NULL,
  unit_number    VARCHAR(40)     NULL,
  building_name  VARCHAR(200)    NULL,

  year_built     SMALLINT UNSIGNED NULL,
  completion_status ENUM('ready','off_plan','under_construction','shell_and_core') NOT NULL DEFAULT 'ready',
  handover_date  DATE            NULL,

  furnishing     ENUM('unfurnished','semi_furnished','furnished','fully_fitted') NULL,
  ownership_type ENUM('freehold','leasehold','usufruct','musataha','commonhold','share_of_freehold') NULL,
  -- Years remaining on a leasehold; decisive in London and Bangkok, irrelevant
  -- in a freehold market, hence nullable.
  lease_years_remaining SMALLINT UNSIGNED NULL,
  tenure_note    VARCHAR(255)    NULL,

  view_type      VARCHAR(120)    NULL,
  orientation    ENUM('north','north_east','east','south_east','south','south_west','west','north_west') NULL,

  -- Rental specifics; NULL for sale listings.
  rent_period    ENUM('yearly','monthly','weekly','daily') NULL,
  cheques_accepted TINYINT UNSIGNED NULL,
  deposit_amount DECIMAL(18,2)   NULL,
  available_from DATE            NULL,
  minimum_stay_days SMALLINT UNSIGNED NULL,

  service_charge_per_sqft DECIMAL(12,2) NULL,
  -- Gross yield percentage, computed at write time for investor-oriented sorts.
  rental_yield_percentage DECIMAL(5,2) NULL,

  -- Regulator-issued advertising permit. Legally required on every Dubai
  -- property advert; other markets have equivalents.
  permit_number  VARCHAR(80)     NULL,
  dld_permit_number VARCHAR(80)  NULL,
  title_deed_number VARCHAR(80)  NULL,

  is_new_build   TINYINT(1)      NOT NULL DEFAULT 0,
  is_distressed  TINYINT(1)      NOT NULL DEFAULT 0,
  is_tenanted    TINYINT(1)      NOT NULL DEFAULT 0,
  developer_brand_id INT UNSIGNED NULL,

  PRIMARY KEY (listing_id),
  -- Composite leading with the filters users combine most: beds, then size,
  -- then price. Column order follows real filter-panel usage, not schema order.
  KEY ix_lre_beds_area (bedrooms, built_area_sqft, bathrooms),
  KEY ix_lre_area_sqm (built_area_sqm),
  KEY ix_lre_plot (plot_area_sqft),
  KEY ix_lre_completion (completion_status, handover_date),
  KEY ix_lre_furnishing (furnishing),
  KEY ix_lre_ownership (ownership_type),
  KEY ix_lre_year (year_built),
  KEY ix_lre_developer (developer_brand_id),
  KEY ix_lre_permit (permit_number),
  CONSTRAINT fk_lre_listing   FOREIGN KEY (listing_id)         REFERENCES listings (id) ON DELETE CASCADE,
  CONSTRAINT fk_lre_developer FOREIGN KEY (developer_brand_id) REFERENCES brands (id)   ON DELETE SET NULL,
  CONSTRAINT ck_lre_areas CHECK (built_area_sqm IS NULL OR built_area_sqm >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_vehicle — cars
-- -----------------------------------------------------------------------------
CREATE TABLE listing_vehicle (
  listing_id     BIGINT UNSIGNED NOT NULL,

  model_year     SMALLINT UNSIGNED NULL,
  -- Mileage is stored in kilometres canonically and mirrored to miles, for the
  -- same reason areas are stored twice: both halves of the market filter in
  -- their own unit and conversion in a predicate kills the index.
  mileage_km     INT UNSIGNED    NULL,
  mileage_miles  INT UNSIGNED    NULL,

  body_type      VARCHAR(60)     NULL,
  transmission   ENUM('automatic','manual','semi_automatic','cvt','dual_clutch') NULL,
  fuel_type      ENUM('petrol','diesel','hybrid','plug_in_hybrid','electric','hydrogen') NULL,
  drivetrain     ENUM('fwd','rwd','awd','4wd') NULL,

  engine_size_cc INT UNSIGNED    NULL,
  cylinders      TINYINT UNSIGNED NULL,
  horsepower     INT UNSIGNED    NULL,
  torque_nm      INT UNSIGNED    NULL,
  top_speed_kmh  SMALLINT UNSIGNED NULL,
  acceleration_0_100 DECIMAL(4,2) NULL,
  -- EV/PHEV only.
  battery_capacity_kwh DECIMAL(6,2) NULL,
  electric_range_km SMALLINT UNSIGNED NULL,

  exterior_color VARCHAR(60)     NULL,
  interior_color VARCHAR(60)     NULL,
  doors          TINYINT UNSIGNED NULL,
  seats          TINYINT UNSIGNED NULL,

  condition_type ENUM('new','used','certified_pre_owned','classic','salvage') NOT NULL DEFAULT 'used',
  -- LHD vs RHD is a genuine buying constraint in the Gulf and Asia, where cars
  -- cross borders routinely.
  steering_side  ENUM('left','right') NULL,
  vin            VARCHAR(40)     NULL,
  registration_number VARCHAR(40) NULL,
  -- Where the car was originally sold. A "GCC spec" or "Japan import" label
  -- materially changes value and is a standard filter in this market.
  regional_spec  VARCHAR(60)     NULL,

  owners_count   TINYINT UNSIGNED NULL,
  service_history ENUM('none','partial','full','full_dealer') NULL,
  warranty_until DATE            NULL,
  is_accident_free TINYINT(1)    NULL,
  has_service_contract TINYINT(1) NOT NULL DEFAULT 0,
  -- Limited-run/collector cars, which drive their own browse surface.
  production_number VARCHAR(40)  NULL,
  is_limited_edition TINYINT(1)  NOT NULL DEFAULT 0,

  PRIMARY KEY (listing_id),
  KEY ix_lv_year_mileage (model_year, mileage_km),
  KEY ix_lv_mileage_miles (mileage_miles),
  KEY ix_lv_body (body_type, model_year),
  KEY ix_lv_transmission (transmission),
  KEY ix_lv_fuel (fuel_type),
  KEY ix_lv_condition (condition_type, model_year),
  KEY ix_lv_power (horsepower),
  KEY ix_lv_vin (vin),
  CONSTRAINT fk_lv_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_marine — yachts and boats
-- -----------------------------------------------------------------------------
CREATE TABLE listing_marine (
  listing_id     BIGINT UNSIGNED NOT NULL,

  build_year     SMALLINT UNSIGNED NULL,
  refit_year     SMALLINT UNSIGNED NULL,
  -- Length overall. The defining specification of a yacht — every search starts
  -- here — so both metric and imperial are stored and indexed.
  length_overall_m DECIMAL(8,2)  NULL,
  length_overall_ft DECIMAL(8,2) NULL,
  beam_m         DECIMAL(7,2)    NULL,
  draft_m        DECIMAL(7,2)    NULL,
  gross_tonnage  DECIMAL(10,2)   NULL,

  vessel_type    ENUM('motor_yacht','sailing_yacht','superyacht','mega_yacht','catamaran','trimaran','explorer','sport_fisher','gulet','classic','tender','houseboat') NULL,
  hull_material  ENUM('grp','steel','aluminium','wood','composite','ferrocement') NULL,
  hull_type      VARCHAR(60)     NULL,

  cabins         TINYINT UNSIGNED NULL,
  berths         TINYINT UNSIGNED NULL,
  heads          TINYINT UNSIGNED NULL,
  -- Guests sleeping aboard vs. day guests: charter listings are searched on both
  -- and they are different numbers.
  guests_sleeping TINYINT UNSIGNED NULL,
  guests_cruising TINYINT UNSIGNED NULL,
  crew_capacity  TINYINT UNSIGNED NULL,

  engine_count   TINYINT UNSIGNED NULL,
  engine_make    VARCHAR(80)     NULL,
  engine_model   VARCHAR(120)    NULL,
  total_power_hp INT UNSIGNED    NULL,
  engine_hours   INT UNSIGNED    NULL,
  cruising_speed_knots DECIMAL(5,2) NULL,
  max_speed_knots DECIMAL(5,2)   NULL,
  range_nm       INT UNSIGNED    NULL,
  fuel_capacity_l INT UNSIGNED   NULL,
  water_capacity_l INT UNSIGNED  NULL,

  -- Registration and berth. `flag_country_id` matters for tax and charter
  -- legality; `current_location_id` is where she actually lies.
  flag_country_id BIGINT UNSIGNED NULL,
  home_port      VARCHAR(160)    NULL,
  current_location_id BIGINT UNSIGNED NULL,
  hull_identification_number VARCHAR(60) NULL,
  mmsi           VARCHAR(20)     NULL,

  -- Charter economics, NULL for sale-only vessels.
  charter_rate_low_season DECIMAL(18,2) NULL,
  charter_rate_high_season DECIMAL(18,2) NULL,
  charter_currency_code CHAR(3)  NULL,
  is_charter_available TINYINT(1) NOT NULL DEFAULT 0,
  -- Yachts are commonly held in a company; buyers search for it because it
  -- changes the transaction structure.
  is_vat_paid    TINYINT(1)      NULL,
  ownership_structure VARCHAR(80) NULL,

  PRIMARY KEY (listing_id),
  KEY ix_lm_length_ft (length_overall_ft, build_year),
  KEY ix_lm_length_m (length_overall_m),
  KEY ix_lm_type_year (vessel_type, build_year),
  KEY ix_lm_cabins (cabins, guests_sleeping),
  KEY ix_lm_charter (is_charter_available, charter_rate_high_season),
  KEY ix_lm_flag (flag_country_id),
  KEY ix_lm_location (current_location_id),
  CONSTRAINT fk_lm_listing  FOREIGN KEY (listing_id)          REFERENCES listings (id)  ON DELETE CASCADE,
  CONSTRAINT fk_lm_flag     FOREIGN KEY (flag_country_id)     REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_lm_location FOREIGN KEY (current_location_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_aviation — jets and helicopters
--
-- One table for both: airframe hours, cycles, seats, range and engine
-- programmes are the same specification set. `listings.root_category_id`
-- separates them.
-- -----------------------------------------------------------------------------
CREATE TABLE listing_aviation (
  listing_id     BIGINT UNSIGNED NOT NULL,

  aircraft_type  ENUM('very_light_jet','light_jet','midsize_jet','super_midsize_jet','heavy_jet','ultra_long_range','vip_airliner','turboprop','light_helicopter','medium_helicopter','heavy_helicopter') NULL,
  year_built     SMALLINT UNSIGNED NULL,
  year_refurbished SMALLINT UNSIGNED NULL,
  serial_number  VARCHAR(60)     NULL,
  registration   VARCHAR(20)     NULL,

  -- The two numbers that determine an airframe's value and maintenance state.
  -- Every serious buyer filters on them, so both are indexed.
  total_time_hours INT UNSIGNED  NULL,
  total_landings INT UNSIGNED    NULL,
  cycles         INT UNSIGNED    NULL,

  passenger_capacity SMALLINT UNSIGNED NULL,
  crew_capacity  TINYINT UNSIGNED NULL,
  -- Whether it can be slept in — the dividing line between a long-range jet and
  -- a very long flight.
  berths         TINYINT UNSIGNED NULL,

  range_nm       INT UNSIGNED    NULL,
  max_cruise_speed_kts SMALLINT UNSIGNED NULL,
  max_altitude_ft INT UNSIGNED   NULL,
  takeoff_distance_ft INT UNSIGNED NULL,

  engine_count   TINYINT UNSIGNED NULL,
  engine_make    VARCHAR(80)     NULL,
  engine_model   VARCHAR(120)    NULL,
  -- Enrolment in a manufacturer maintenance programme (JSSI, MSP, ESP) can move
  -- an aircraft's value by seven figures. It is a headline filter, not a note.
  engine_program VARCHAR(120)    NULL,
  apu_hours      INT UNSIGNED    NULL,

  avionics_suite VARCHAR(160)    NULL,
  interior_configuration VARCHAR(255) NULL,
  exterior_paint_year SMALLINT UNSIGNED NULL,
  interior_refurb_year SMALLINT UNSIGNED NULL,

  -- Airworthiness and regulatory state.
  base_location_id BIGINT UNSIGNED NULL,
  -- ICAO code of the home base (OMDB, EGGW, KTEB).
  base_airport_code VARCHAR(8)   NULL,
  registration_country_id BIGINT UNSIGNED NULL,
  -- Commercial (Part 135 / AOC) vs private (Part 91) determines whether it may
  -- be chartered out.
  operating_certificate VARCHAR(80) NULL,
  next_inspection_due DATE       NULL,
  is_charter_available TINYINT(1) NOT NULL DEFAULT 0,
  charter_hourly_rate DECIMAL(18,2) NULL,
  charter_currency_code CHAR(3)  NULL,

  PRIMARY KEY (listing_id),
  KEY ix_la_type_year (aircraft_type, year_built),
  KEY ix_la_hours (total_time_hours),
  KEY ix_la_range (range_nm),
  KEY ix_la_capacity (passenger_capacity),
  KEY ix_la_registration (registration),
  KEY ix_la_base (base_location_id),
  KEY ix_la_charter (is_charter_available, charter_hourly_rate),
  CONSTRAINT fk_la_listing  FOREIGN KEY (listing_id)              REFERENCES listings (id)  ON DELETE CASCADE,
  CONSTRAINT fk_la_base     FOREIGN KEY (base_location_id)        REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_la_regcount FOREIGN KEY (registration_country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- listing_timepiece — watches
-- -----------------------------------------------------------------------------
CREATE TABLE listing_timepiece (
  listing_id     BIGINT UNSIGNED NOT NULL,

  -- The reference number is the watch's real identity — buyers search "5711/1A"
  -- far more than "Nautilus". Indexed and treated as a first-class search key.
  reference_number VARCHAR(80)   NULL,
  serial_number  VARCHAR(80)     NULL,
  year_of_production SMALLINT UNSIGNED NULL,
  -- Vintage pieces are often only datable to a decade; stored alongside the
  -- exact year rather than instead of it.
  production_decade VARCHAR(20)  NULL,

  case_material  VARCHAR(80)     NULL,
  case_diameter_mm DECIMAL(5,2)  NULL,
  case_thickness_mm DECIMAL(5,2) NULL,
  lug_width_mm   DECIMAL(5,2)    NULL,
  bezel_material VARCHAR(80)     NULL,
  crystal        VARCHAR(60)     NULL,

  dial_color     VARCHAR(60)     NULL,
  dial_type      VARCHAR(80)     NULL,
  bracelet_material VARCHAR(80)  NULL,
  clasp_type     VARCHAR(80)     NULL,

  movement_type  ENUM('automatic','manual','quartz','spring_drive','solar','mechanical_digital') NULL,
  caliber        VARCHAR(80)     NULL,
  power_reserve_hours SMALLINT UNSIGNED NULL,
  jewels         SMALLINT UNSIGNED NULL,
  frequency_vph  INT UNSIGNED    NULL,
  water_resistance_m SMALLINT UNSIGNED NULL,
  complications  JSON            NULL,

  condition_grade ENUM('new','unworn','excellent','very_good','good','fair','restored') NULL,
  -- "Full set" — original box, papers and warranty card — is the single biggest
  -- non-condition price determinant in the secondary market, and the filter
  -- every serious collector applies first.
  has_original_box TINYINT(1)    NOT NULL DEFAULT 0,
  has_original_papers TINYINT(1) NOT NULL DEFAULT 0,
  has_warranty_card TINYINT(1)   NOT NULL DEFAULT 0,
  is_full_set    TINYINT(1)      GENERATED ALWAYS AS (
                   has_original_box AND has_original_papers AND has_warranty_card
                 ) STORED,
  warranty_expires_at DATE       NULL,
  last_service_year SMALLINT UNSIGNED NULL,

  is_limited_edition TINYINT(1)  NOT NULL DEFAULT 0,
  limited_edition_number VARCHAR(40) NULL,
  limited_edition_total INT UNSIGNED NULL,
  gender         ENUM('mens','ladies','unisex') NULL,

  PRIMARY KEY (listing_id),
  KEY ix_lt_reference (reference_number),
  KEY ix_lt_year (year_of_production),
  KEY ix_lt_case (case_material, case_diameter_mm),
  KEY ix_lt_movement (movement_type),
  KEY ix_lt_condition (condition_grade, year_of_production),
  KEY ix_lt_full_set (is_full_set),
  KEY ix_lt_diameter (case_diameter_mm),
  CONSTRAINT fk_lt_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0007', 'listing_details');
