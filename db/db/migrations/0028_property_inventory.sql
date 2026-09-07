-- =============================================================================
-- Liv Finder — 0028 · Property inventory, tenancy, valuation and finance
-- =============================================================================
-- Everything up to here treats a listing as the unit of interest. That is
-- correct for a marketplace and insufficient for a platform, because a listing
-- is an *advertisement* and the thing being advertised outlives it.
--
-- Apartment 3204 in Marina Gate 2 has been listed eleven times over six years
-- by four agencies at prices between 2.1M and 3.4M, rented twice, sold once,
-- valued three times and mortgaged. Model that as eleven unrelated listings and
-- you lose every question worth asking: what has this unit actually
-- transacted at, is this "exclusive" mandate really exclusive, is the same
-- property being advertised twice at different prices right now.
--
-- So this migration introduces the physical hierarchy that sits underneath the
-- marketplace:
--
--   buildings → floors → units → listings
--
-- and, hanging off units, the things that happen to real property over its
-- life: ownership, tenancy, rent, maintenance, valuation and finance.
--
-- Two consequences are worth stating plainly.
--
-- DUPLICATE DETECTION BECOMES POSSIBLE. Two live listings pointing at the same
-- `unit_id` is either a co-agency arrangement or a duplicate — and today, on
-- every portal in the world, that is guessed at by comparing photographs.
--
-- PRICE HISTORY BECOMES REAL. `unit_transactions` records what actually
-- changed hands, not what was asked. Asking prices are marketing; transaction
-- prices are the market, and the gap between them is the single most valuable
-- statistic a property portal can hold.
--
-- Not every listing has a unit. A yacht does not, a watch does not, and a villa
-- in a market where we have no building data does not. `listings.unit_id` is
-- therefore optional and everything here degrades gracefully to NULL.
-- =============================================================================

SET NAMES utf8mb4;

-- =============================================================================
-- SECTION 1 · PHYSICAL HIERARCHY
-- =============================================================================

-- -----------------------------------------------------------------------------
-- buildings
--
-- A physical structure. Sits below the location tree from 0002 — a building
-- belongs to a sub-community, which belongs to a community, and so on — and it
-- is deliberately a separate table rather than a seventh location tier.
--
-- The reason: a location is a place people search for and navigate to, with
-- URLs, SEO and translations. A building is an asset with a completion date, a
-- developer, a service charge and a lift count. Overloading `locations` with
-- those would put a hundred mostly-NULL columns on the most-read table in the
-- schema.
--
-- Where a building genuinely is a searchable place — "Burj Khalifa",
-- "One Palm" — it also has a `locations` row at `building` level, and
-- `location_id` binds the two.
-- -----------------------------------------------------------------------------
CREATE TABLE buildings (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  slug           VARCHAR(220)    NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  alternate_names JSON           NULL,
  -- Where it is. Full denormalised ancestry, same discipline as `listings`.
  location_id    BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,
  sub_community_id BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  developer_brand_id INT UNSIGNED NULL,
  address_line1  VARCHAR(255)    NULL,
  postal_code    VARCHAR(24)     NULL,
  latitude       DECIMAL(10,7)   NULL,
  longitude      DECIMAL(10,7)   NULL,
  -- Physical description.
  building_type  ENUM('residential_tower','villa_compound','townhouse_cluster','mixed_use','commercial_tower','hotel_apartment','warehouse','retail','marina','hangar','other') NOT NULL DEFAULT 'residential_tower',
  floors_above_ground SMALLINT UNSIGNED NULL,
  floors_below_ground TINYINT UNSIGNED NULL,
  total_units    SMALLINT UNSIGNED NULL,
  height_metres  DECIMAL(8,2)    NULL,
  lift_count     TINYINT UNSIGNED NULL,
  parking_levels TINYINT UNSIGNED NULL,
  -- Status and dates. `handover_date` is what off-plan buyers actually care
  -- about and what every "ready in 2027" filter reads.
  status         ENUM('planned','under_construction','completed','operational','renovating','demolished') NOT NULL DEFAULT 'completed',
  completion_year SMALLINT UNSIGNED NULL,
  handover_date  DATE            NULL,
  -- Tenure, which is a hard filter in several markets and a legal question in
  -- all of them.
  tenure         ENUM('freehold','leasehold','commonhold','usufruct','musataha','unknown') NOT NULL DEFAULT 'unknown',
  leasehold_years SMALLINT UNSIGNED NULL,
  -- Running costs. Service charge per unit area is one of the most requested
  -- and least available numbers in Gulf property.
  service_charge_per_area DECIMAL(12,4) NULL,
  service_charge_currency CHAR(3) NULL,
  service_charge_unit_id SMALLINT UNSIGNED NULL,
  service_charge_year SMALLINT UNSIGNED NULL,
  management_company VARCHAR(200) NULL,
  -- Marketplace rollups, derived.
  listing_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  active_listing_count SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  unit_count     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  avg_price_base DECIMAL(18,2)   NULL,
  avg_price_per_area DECIMAL(14,4) NULL,
  avg_rent_base  DECIMAL(18,2)   NULL,
  gross_yield_percent DECIMAL(6,3) NULL,
  cover_image_url VARCHAR(500)   NULL,
  description    MEDIUMTEXT      NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  is_publicly_visible TINYINT(1) NOT NULL DEFAULT 1,
  data_source    ENUM('manual','import','registry','agency','developer','derived') NOT NULL DEFAULT 'manual',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_buildings_public (public_id),
  UNIQUE KEY uq_buildings_slug (slug),
  -- "All buildings in this community" — the building directory page.
  KEY ix_buildings_community (community_id, is_publicly_visible, name),
  KEY ix_buildings_location (location_id),
  KEY ix_buildings_project (project_id),
  KEY ix_buildings_city (city_id, building_type, status),
  KEY ix_buildings_geo (latitude, longitude),
  CONSTRAINT fk_buildings_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_buildings_community FOREIGN KEY (community_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_buildings_city FOREIGN KEY (city_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_buildings_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL,
  CONSTRAINT fk_buildings_developer FOREIGN KEY (developer_brand_id) REFERENCES brands (id) ON DELETE SET NULL,
  CONSTRAINT fk_buildings_charge_unit FOREIGN KEY (service_charge_unit_id) REFERENCES measurement_units (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- building_floors
--
-- Floors exist as rows because floor is a real filter ("above the 40th"), a
-- real price driver, and — in most of Asia and the Gulf — not a number you can
-- compute. Buildings routinely skip 13, and skip 4, 14, 24, 34 and 40–49
-- entirely where those are unlucky, so the 30th floor plate may be labelled
-- "56". `floor_number` is the physical level and `floor_label` is what the lift
-- button says; conflating them produces listings on floors that do not exist.
-- -----------------------------------------------------------------------------
CREATE TABLE building_floors (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  building_id    BIGINT UNSIGNED NOT NULL,
  floor_number   SMALLINT        NOT NULL,
  floor_label    VARCHAR(20)     NOT NULL,
  floor_type     ENUM('residential','retail','office','amenity','parking','mechanical','lobby','penthouse','basement','roof') NOT NULL DEFAULT 'residential',
  unit_count     SMALLINT UNSIGNED NULL,
  floor_plate_area DECIMAL(12,2) NULL,
  area_unit_id   SMALLINT UNSIGNED NULL,
  ceiling_height_metres DECIMAL(5,2) NULL,
  has_balconies  TINYINT(1)      NULL,
  notes          VARCHAR(300)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_building_floor (building_id, floor_number),
  KEY ix_building_floors_type (building_id, floor_type),
  CONSTRAINT fk_building_floors_building FOREIGN KEY (building_id) REFERENCES buildings (id) ON DELETE CASCADE,
  CONSTRAINT fk_building_floors_unit FOREIGN KEY (area_unit_id) REFERENCES measurement_units (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- property_units
--
-- The physical asset. This is the row that persists while listings come and go.
--
-- `unit_number` is unique within a building, which is what makes matching an
-- incoming feed to an existing unit possible — and matching is the whole point.
-- Where the market has an official identifier (a Dubai Land Department title
-- number, a UK UPRN), `registry_reference` holds it and matching becomes exact
-- rather than heuristic.
-- -----------------------------------------------------------------------------
CREATE TABLE property_units (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  building_id    BIGINT UNSIGNED NULL,
  floor_id       BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  -- Identity within the building.
  unit_number    VARCHAR(40)     NOT NULL,
  floor_number   SMALLINT        NULL,
  -- Official identifier where the market has one. See the table comment.
  registry_reference VARCHAR(120) NULL,
  registry_authority_id INT UNSIGNED NULL,
  plot_number    VARCHAR(60)     NULL,
  -- Where, for units with no building (villas, plots, standalone houses).
  location_id    BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  address_line1  VARCHAR(255)    NULL,
  latitude       DECIMAL(10,7)   NULL,
  longitude      DECIMAL(10,7)   NULL,
  -- Physical characteristics. These belong to the unit, not to the advert, and
  -- a listing that disagrees with them is a data-quality signal.
  category_id    INT UNSIGNED    NULL,
  unit_type      ENUM('apartment','penthouse','duplex','villa','townhouse','studio','loft','office','retail','warehouse','plot','floor','whole_building','other') NOT NULL DEFAULT 'apartment',
  bedrooms       TINYINT UNSIGNED NULL,
  bathrooms      DECIMAL(4,1)    NULL,
  built_up_area  DECIMAL(12,2)   NULL,
  plot_area      DECIMAL(12,2)   NULL,
  balcony_area   DECIMAL(12,2)   NULL,
  area_unit_id   SMALLINT UNSIGNED NULL,
  parking_spaces TINYINT UNSIGNED NULL,
  parking_numbers VARCHAR(120)   NULL,
  storage_room   TINYINT(1)      NULL,
  maid_room      TINYINT(1)      NULL,
  view_type      VARCHAR(120)    NULL,
  orientation    ENUM('north','north_east','east','south_east','south','south_west','west','north_west') NULL,
  floor_plan_id  BIGINT UNSIGNED NULL,
  -- Tenure and current state.
  tenure         ENUM('freehold','leasehold','commonhold','usufruct','musataha','unknown') NOT NULL DEFAULT 'unknown',
  occupancy_status ENUM('vacant','owner_occupied','tenanted','under_renovation','off_plan','unknown') NOT NULL DEFAULT 'unknown',
  is_off_plan    TINYINT(1)      NOT NULL DEFAULT 0,
  handover_date  DATE            NULL,
  -- Marketplace state. `active_listing_count` above 1 is a duplicate or a
  -- multi-agency mandate, and either way it is worth surfacing.
  listing_count  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  active_listing_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
  last_listed_at DATETIME(3)     NULL,
  -- Money, derived from transactions and valuations rather than from asking
  -- prices.
  last_sale_price DECIMAL(18,2)  NULL,
  last_sale_date DATE            NULL,
  last_rent_amount DECIMAL(18,2) NULL,
  last_rent_date DATE            NULL,
  currency_code  CHAR(3)         NULL,
  estimated_value DECIMAL(18,2)  NULL,
  estimated_value_at DATE        NULL,
  data_source    ENUM('manual','import','registry','agency','developer','derived') NOT NULL DEFAULT 'manual',
  verification_status ENUM('unverified','agency_verified','registry_verified','disputed') NOT NULL DEFAULT 'unverified',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_property_units_public (public_id),
  -- The matching key. Feed imports resolve against this before creating.
  UNIQUE KEY uq_property_unit_number (building_id, unit_number),
  UNIQUE KEY uq_property_unit_registry (registry_authority_id, registry_reference),
  KEY ix_property_units_building (building_id, floor_number, unit_number),
  KEY ix_property_units_project (project_id, unit_type, bedrooms),
  KEY ix_property_units_location (community_id, unit_type, bedrooms),
  -- The duplicate-listing detector.
  KEY ix_property_units_active (active_listing_count, building_id),
  KEY ix_property_units_occupancy (occupancy_status, community_id),
  CONSTRAINT fk_property_units_building FOREIGN KEY (building_id) REFERENCES buildings (id) ON DELETE SET NULL,
  CONSTRAINT fk_property_units_floor FOREIGN KEY (floor_id) REFERENCES building_floors (id) ON DELETE SET NULL,
  CONSTRAINT fk_property_units_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL,
  CONSTRAINT fk_property_units_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE SET NULL,
  CONSTRAINT fk_property_units_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE SET NULL,
  CONSTRAINT fk_property_units_area_unit FOREIGN KEY (area_unit_id) REFERENCES measurement_units (id) ON DELETE SET NULL,
  CONSTRAINT fk_property_units_floor_plan FOREIGN KEY (floor_plan_id) REFERENCES floor_plans (id) ON DELETE SET NULL,
  CONSTRAINT fk_property_units_registry FOREIGN KEY (registry_authority_id) REFERENCES regulatory_authorities (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- Bind the marketplace to the physical asset. Nullable because most categories
-- have no unit, and because a listing in an uncovered market has none either.
ALTER TABLE listings
  ADD COLUMN unit_id BIGINT UNSIGNED NULL AFTER project_id,
  ADD COLUMN building_id BIGINT UNSIGNED NULL AFTER unit_id,
  ADD KEY ix_listings_unit (unit_id, status),
  ADD KEY ix_listings_building (building_id, status),
  ADD CONSTRAINT fk_listings_unit FOREIGN KEY (unit_id) REFERENCES property_units (id) ON DELETE SET NULL,
  ADD CONSTRAINT fk_listings_building FOREIGN KEY (building_id) REFERENCES buildings (id) ON DELETE SET NULL;

-- =============================================================================
-- SECTION 2 · OWNERSHIP AND TRANSACTIONS
-- =============================================================================

-- -----------------------------------------------------------------------------
-- unit_ownerships
--
-- Who owns what, and what share. Joint ownership is normal, so this is rows
-- rather than an owner column, and `share_percent` is expected to sum to 100
-- across concurrent rows — an invariant the integrity suite checks.
--
-- `is_current` plus dated ranges means the ownership history is preserved,
-- which is what makes "how long do people hold in this building" answerable.
-- -----------------------------------------------------------------------------
CREATE TABLE unit_ownerships (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  unit_id        BIGINT UNSIGNED NOT NULL,
  owner_type     ENUM('individual','company','trust','fund','government','developer','joint','unknown') NOT NULL DEFAULT 'individual',
  contact_id     BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  owner_name     VARCHAR(255)    NULL,
  owner_country_id BIGINT UNSIGNED NULL,
  share_percent  DECIMAL(6,3)    NOT NULL DEFAULT 100.000,
  -- How they hold it, which matters for tax and for who must sign.
  ownership_type ENUM('sole','joint_tenants','tenants_in_common','company_shares','beneficial','leasehold') NOT NULL DEFAULT 'sole',
  acquired_on    DATE            NULL,
  acquired_price DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  disposed_on    DATE            NULL,
  is_current     TINYINT(1)      NOT NULL DEFAULT 1,
  title_deed_reference VARCHAR(120) NULL,
  title_document_id BIGINT UNSIGNED NULL,
  -- Whether we may market it. An agency listing a property without the owner's
  -- instruction is the oldest problem in the industry.
  is_verified    TINYINT(1)      NOT NULL DEFAULT 0,
  verified_at    DATETIME(3)     NULL,
  verification_method ENUM('title_deed','registry_api','notarised','declaration','none') NOT NULL DEFAULT 'none',
  source         ENUM('manual','import','registry','agency','declared') NOT NULL DEFAULT 'manual',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_unit_ownerships_unit (unit_id, is_current, acquired_on),
  KEY ix_unit_ownerships_contact (contact_id, is_current),
  KEY ix_unit_ownerships_owner (organization_id, is_current),
  CONSTRAINT fk_unit_ownerships_unit FOREIGN KEY (unit_id) REFERENCES property_units (id) ON DELETE CASCADE,
  CONSTRAINT fk_unit_ownerships_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_unit_ownerships_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_unit_ownerships_document FOREIGN KEY (title_document_id) REFERENCES documents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- unit_transactions
--
-- What actually happened, at what price. The counterweight to asking prices.
--
-- `source` is load-bearing: a price from a land registry is fact, a price
-- reported by the selling agent is a claim, and presenting them identically is
-- how portals end up publishing market statistics that nobody trusts. The
-- `confidence` column makes the difference explicit in every aggregate built
-- from this table.
-- -----------------------------------------------------------------------------
CREATE TABLE unit_transactions (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  unit_id        BIGINT UNSIGNED NULL,
  building_id    BIGINT UNSIGNED NULL,
  project_id     BIGINT UNSIGNED NULL,
  location_id    BIGINT UNSIGNED NULL,
  community_id   BIGINT UNSIGNED NULL,
  city_id        BIGINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  transaction_type ENUM('sale','resale','off_plan_sale','rent','rent_renewal','transfer','gift','inheritance','auction','repossession') NOT NULL DEFAULT 'sale',
  transaction_date DATE          NOT NULL,
  registration_date DATE         NULL,
  registry_reference VARCHAR(120) NULL,
  -- Money.
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  amount_base    DECIMAL(18,2)   NULL,
  -- Per-area price, stored because every market statistic is built on it and
  -- recomputing it across millions of rows per query is waste.
  price_per_area DECIMAL(14,4)   NULL,
  area           DECIMAL(12,2)   NULL,
  area_unit_id   SMALLINT UNSIGNED NULL,
  -- Rental specifics.
  rent_period    ENUM('yearly','monthly','weekly','daily','nightly') NULL,
  contract_months SMALLINT UNSIGNED NULL,
  -- Characteristics captured at the time, because the unit's own record may
  -- change afterwards (a renovation adds a bedroom) and the transaction must
  -- remain interpretable against what was sold.
  unit_type      VARCHAR(40)     NULL,
  bedrooms       TINYINT UNSIGNED NULL,
  -- Provenance. See the table comment.
  source         ENUM('land_registry','government_open_data','agency_reported','platform_deal','portal_feed','estimated','manual') NOT NULL DEFAULT 'manual',
  confidence     ENUM('verified','high','medium','low') NOT NULL DEFAULT 'medium',
  is_public      TINYINT(1)      NOT NULL DEFAULT 1,
  -- Linked platform records where the transaction happened here.
  deal_id        BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  -- Off-plan sales at a discount, distressed sales and inter-family transfers
  -- are not comparable evidence and must be excludable from indices.
  is_arms_length TINYINT(1)      NOT NULL DEFAULT 1,
  exclusion_reason VARCHAR(200)  NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_unit_transactions_public (public_id),
  UNIQUE KEY uq_unit_transaction_registry (registry_reference, transaction_type),
  -- The unit's own transaction history.
  KEY ix_unit_transactions_unit (unit_id, transaction_date),
  -- The market-statistics query: everything comparable in this area, by date.
  KEY ix_unit_transactions_market (community_id, transaction_type, transaction_date, is_arms_length),
  KEY ix_unit_transactions_building (building_id, transaction_type, transaction_date),
  KEY ix_unit_transactions_city (city_id, transaction_type, transaction_date),
  KEY ix_unit_transactions_deal (deal_id),
  CONSTRAINT fk_unit_transactions_unit FOREIGN KEY (unit_id) REFERENCES property_units (id) ON DELETE SET NULL,
  CONSTRAINT fk_unit_transactions_building FOREIGN KEY (building_id) REFERENCES buildings (id) ON DELETE SET NULL,
  CONSTRAINT fk_unit_transactions_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE SET NULL,
  CONSTRAINT fk_unit_transactions_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_unit_transactions_area_unit FOREIGN KEY (area_unit_id) REFERENCES measurement_units (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 3 · TENANCY AND MANAGEMENT
-- =============================================================================

-- -----------------------------------------------------------------------------
-- tenancies
--
-- A live lease. The property-management side of the business, and the reason an
-- agency stays in contact with a client for years rather than months.
--
-- `renewal_notice_due` is the operationally critical column: most jurisdictions
-- require notice of a rent increase a set period before expiry — ninety days in
-- Dubai — and missing it means the rent cannot be raised for another year. That
-- is a direct, recurring financial loss caused entirely by a missing reminder.
-- -----------------------------------------------------------------------------
CREATE TABLE tenancies (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(40)     NOT NULL,
  unit_id        BIGINT UNSIGNED NULL,
  building_id    BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  deal_id        BIGINT UNSIGNED NULL,
  contract_id    BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  managing_agent_id BIGINT UNSIGNED NULL,
  -- Registration with the authority, which is mandatory in several markets
  -- (Ejari in Dubai) and without which the contract is unenforceable.
  registration_reference VARCHAR(120) NULL,
  registration_authority_id INT UNSIGNED NULL,
  registered_at  DATE            NULL,
  tenancy_type   ENUM('residential','commercial','short_term','holiday_home','corporate','sublease') NOT NULL DEFAULT 'residential',
  status         ENUM('draft','pending_signature','active','expiring','renewed','ended','terminated','breached','vacated') NOT NULL DEFAULT 'draft',
  -- Term.
  starts_on      DATE            NOT NULL,
  ends_on        DATE            NOT NULL,
  term_months    SMALLINT UNSIGNED NULL,
  -- Notice. See the table comment.
  notice_period_days SMALLINT UNSIGNED NULL,
  renewal_notice_due DATE        NULL,
  renewal_notice_sent_at DATETIME(3) NULL,
  auto_renews    TINYINT(1)      NOT NULL DEFAULT 0,
  -- Money.
  annual_rent    DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  annual_rent_base DECIMAL(18,2) NULL,
  -- Gulf convention: rent paid in a small number of post-dated cheques.
  payment_frequency ENUM('annual','biannual','quarterly','monthly','cheques') NOT NULL DEFAULT 'annual',
  cheque_count   TINYINT UNSIGNED NULL,
  security_deposit DECIMAL(18,2) NULL,
  deposit_held_by ENUM('landlord','agency','scheme','escrow') NULL,
  deposit_returned_at DATE       NULL,
  deposit_deductions DECIMAL(18,2) NULL,
  agency_commission DECIMAL(18,2) NULL,
  -- Terms that decide most disputes.
  furnished      ENUM('furnished','unfurnished','part_furnished') NULL,
  utilities_included SET('water','electricity','gas','internet','cooling','maintenance') NULL,
  pets_allowed   TINYINT(1)      NULL,
  subletting_allowed TINYINT(1)  NULL,
  max_occupants  TINYINT UNSIGNED NULL,
  -- Exit.
  ended_on       DATE            NULL,
  termination_reason ENUM('expiry','mutual','tenant_notice','landlord_notice','breach','sale','eviction','other') NULL,
  vacated_at     DATE            NULL,
  renewed_into_tenancy_id BIGINT UNSIGNED NULL,
  previous_tenancy_id BIGINT UNSIGNED NULL,
  notes          TEXT            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tenancies_public (public_id),
  UNIQUE KEY uq_tenancies_reference (reference),
  KEY ix_tenancies_unit (unit_id, status, ends_on),
  -- The two operational sweeps: leases expiring, and notice becoming due.
  KEY ix_tenancies_expiry (status, ends_on),
  KEY ix_tenancies_notice (status, renewal_notice_due, renewal_notice_sent_at),
  KEY ix_tenancies_org (organization_id, status, ends_on),
  KEY ix_tenancies_agent (managing_agent_id, status),
  CONSTRAINT fk_tenancies_unit FOREIGN KEY (unit_id) REFERENCES property_units (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenancies_building FOREIGN KEY (building_id) REFERENCES buildings (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenancies_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenancies_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenancies_contract FOREIGN KEY (contract_id) REFERENCES contracts (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenancies_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenancies_agent FOREIGN KEY (managing_agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_tenancies_previous FOREIGN KEY (previous_tenancy_id) REFERENCES tenancies (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE tenancy_parties (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tenancy_id     BIGINT UNSIGNED NOT NULL,
  party_role     ENUM('landlord','tenant','co_tenant','guarantor','occupant','managing_agent','company') NOT NULL,
  contact_id     BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  legal_name     VARCHAR(255)    NOT NULL,
  email          VARCHAR(255)    NULL,
  phone_e164     VARCHAR(20)     NULL,
  identity_reference VARCHAR(80) NULL,
  is_primary     TINYINT(1)      NOT NULL DEFAULT 0,
  liability_percent DECIMAL(6,3) NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_tenancy_parties_tenancy (tenancy_id, party_role),
  KEY ix_tenancy_parties_contact (contact_id),
  CONSTRAINT fk_tenancy_parties_tenancy FOREIGN KEY (tenancy_id) REFERENCES tenancies (id) ON DELETE CASCADE,
  CONSTRAINT fk_tenancy_parties_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- rent_schedules
--
-- Every rent instalment, generated when the tenancy is created.
--
-- Materialised rather than computed because each instalment has its own state —
-- a cheque can bounce, an instalment can be part-paid, a date can be varied by
-- agreement — and because the arrears query ("what is overdue right now") must
-- be an index range scan, not a calculation over every live tenancy.
-- -----------------------------------------------------------------------------
CREATE TABLE rent_schedules (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  tenancy_id     BIGINT UNSIGNED NOT NULL,
  unit_id        BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  instalment_number SMALLINT UNSIGNED NOT NULL,
  period_start   DATE            NULL,
  period_end     DATE            NULL,
  due_on         DATE            NOT NULL,
  amount         DECIMAL(18,2)   NOT NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  amount_base    DECIMAL(18,2)   NULL,
  paid_amount    DECIMAL(18,2)   NOT NULL DEFAULT 0,
  status         ENUM('scheduled','due','partially_paid','paid','overdue','bounced','waived','cancelled') NOT NULL DEFAULT 'scheduled',
  -- Post-dated cheques, which is how most Gulf rent is paid and which fail in
  -- their own particular way.
  payment_method ENUM('cheque','bank_transfer','card','cash','standing_order','online') NULL,
  cheque_number  VARCHAR(40)     NULL,
  cheque_bank    VARCHAR(120)    NULL,
  cheque_status  ENUM('held','presented','cleared','bounced','returned','replaced') NULL,
  bounced_at     DATE            NULL,
  bounce_reason  VARCHAR(200)    NULL,
  paid_at        DATE            NULL,
  payment_id     BIGINT UNSIGNED NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  late_fee       DECIMAL(12,2)   NOT NULL DEFAULT 0,
  reminder_sent_at DATETIME(3)   NULL,
  reminder_count TINYINT UNSIGNED NOT NULL DEFAULT 0,
  notes          VARCHAR(500)    NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_rent_instalment (tenancy_id, instalment_number),
  -- The arrears report and the reminder sweep.
  KEY ix_rent_schedules_due (status, due_on),
  KEY ix_rent_schedules_tenancy (tenancy_id, due_on),
  KEY ix_rent_schedules_org (organization_id, status, due_on),
  CONSTRAINT fk_rent_schedules_tenancy FOREIGN KEY (tenancy_id) REFERENCES tenancies (id) ON DELETE CASCADE,
  CONSTRAINT fk_rent_schedules_unit FOREIGN KEY (unit_id) REFERENCES property_units (id) ON DELETE SET NULL,
  CONSTRAINT fk_rent_schedules_payment FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL,
  CONSTRAINT fk_rent_schedules_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- maintenance_requests
--
-- Repairs and issues, from the tenant's report through to the invoice.
--
-- `is_emergency` and `is_habitability_issue` are separated because they carry
-- different legal weight: a broken air conditioner in a Gulf summer is not a
-- convenience issue, and in most jurisdictions failing to act on a habitability
-- fault within a statutory window entitles the tenant to remedies.
-- -----------------------------------------------------------------------------
CREATE TABLE maintenance_requests (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(40)     NOT NULL,
  unit_id        BIGINT UNSIGNED NULL,
  building_id    BIGINT UNSIGNED NULL,
  tenancy_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  reported_by_contact_id BIGINT UNSIGNED NULL,
  reported_by_user_id BIGINT UNSIGNED NULL,
  category       ENUM('plumbing','electrical','hvac','appliance','structural','pest','cleaning','security','lift','common_area','landscaping','other') NOT NULL DEFAULT 'other',
  title          VARCHAR(255)    NOT NULL,
  description    TEXT            NULL,
  priority       ENUM('low','normal','high','emergency') NOT NULL DEFAULT 'normal',
  is_emergency   TINYINT(1)      NOT NULL DEFAULT 0,
  is_habitability_issue TINYINT(1) NOT NULL DEFAULT 0,
  status         ENUM('reported','triaged','quoted','approved','scheduled','in_progress','completed','verified','rejected','cancelled') NOT NULL DEFAULT 'reported',
  -- Who pays. The most contested question in property management, and one that
  -- should be decided and recorded rather than argued at invoice time.
  liable_party   ENUM('landlord','tenant','building','warranty','insurance','undetermined') NOT NULL DEFAULT 'undetermined',
  liability_note VARCHAR(500)    NULL,
  -- Money.
  quoted_amount  DECIMAL(12,2)   NULL,
  approved_amount DECIMAL(12,2)  NULL,
  final_amount   DECIMAL(12,2)   NULL,
  currency_code  CHAR(3)         NULL,
  invoice_id     BIGINT UNSIGNED NULL,
  -- Execution.
  vendor_name    VARCHAR(200)    NULL,
  vendor_contact_id BIGINT UNSIGNED NULL,
  assigned_to_user_id BIGINT UNSIGNED NULL,
  scheduled_at   DATETIME(3)     NULL,
  access_arranged TINYINT(1)     NOT NULL DEFAULT 0,
  -- Timing, for the SLA and for the habitability clock.
  reported_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  acknowledged_at DATETIME(3)    NULL,
  response_due_at DATETIME(3)    NULL,
  started_at     DATETIME(3)     NULL,
  completed_at   DATETIME(3)     NULL,
  verified_at    DATETIME(3)     NULL,
  resolution_note TEXT           NULL,
  tenant_satisfaction TINYINT UNSIGNED NULL,
  media_asset_ids JSON           NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_maintenance_public (public_id),
  UNIQUE KEY uq_maintenance_reference (reference),
  KEY ix_maintenance_unit (unit_id, status, reported_at),
  KEY ix_maintenance_org (organization_id, status, priority, reported_at),
  KEY ix_maintenance_due (status, response_due_at),
  KEY ix_maintenance_building (building_id, category, reported_at),
  CONSTRAINT fk_maintenance_unit FOREIGN KEY (unit_id) REFERENCES property_units (id) ON DELETE SET NULL,
  CONSTRAINT fk_maintenance_building FOREIGN KEY (building_id) REFERENCES buildings (id) ON DELETE SET NULL,
  CONSTRAINT fk_maintenance_tenancy FOREIGN KEY (tenancy_id) REFERENCES tenancies (id) ON DELETE SET NULL,
  CONSTRAINT fk_maintenance_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_maintenance_contact FOREIGN KEY (reported_by_contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_maintenance_invoice FOREIGN KEY (invoice_id) REFERENCES invoices (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- =============================================================================
-- SECTION 4 · VALUATION
-- =============================================================================

-- -----------------------------------------------------------------------------
-- valuations
--
-- What a property is worth, and who says so.
--
-- `valuation_type` separates three very different things that get conflated: an
-- automated estimate (cheap, instant, approximate), a broker's opinion (free,
-- optimistic, useful for winning an instruction) and a formal surveyor's
-- valuation (expensive, slow, and the only one a bank will lend against).
-- Showing an automated estimate where a formal valuation is expected is a
-- liability; the column is what keeps them apart.
-- -----------------------------------------------------------------------------
CREATE TABLE valuations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  unit_id        BIGINT UNSIGNED NULL,
  building_id    BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  lead_id        BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  agent_id       BIGINT UNSIGNED NULL,
  valuation_type ENUM('automated','broker_opinion','desktop','formal_survey','mortgage','insurance','probate','tax') NOT NULL DEFAULT 'automated',
  purpose        ENUM('sale','rent','mortgage','insurance','accounting','probate','dispute','curiosity','listing_appraisal') NOT NULL DEFAULT 'sale',
  -- The figure, with a range because a point estimate implies a precision that
  -- does not exist.
  valued_amount  DECIMAL(18,2)   NOT NULL,
  value_low      DECIMAL(18,2)   NULL,
  value_high     DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  valued_amount_base DECIMAL(18,2) NULL,
  price_per_area DECIMAL(14,4)   NULL,
  -- Rental valuation, which is a separate question with a separate answer.
  rental_value   DECIMAL(18,2)   NULL,
  rental_period  ENUM('yearly','monthly') NULL,
  gross_yield_percent DECIMAL(6,3) NULL,
  confidence     ENUM('very_low','low','medium','high','very_high') NOT NULL DEFAULT 'medium',
  confidence_score DECIMAL(5,2)  NULL,
  -- Method and evidence.
  method         ENUM('comparable','income','cost','residual','hedonic_model','index_adjusted','manual') NULL,
  comparable_count SMALLINT UNSIGNED NULL,
  model_version  VARCHAR(40)     NULL,
  adjustments    JSON            NULL,
  -- Who performed it. A formal valuation needs a named, qualified valuer.
  valuer_name    VARCHAR(200)    NULL,
  valuer_firm    VARCHAR(200)    NULL,
  valuer_licence VARCHAR(80)     NULL,
  report_document_id BIGINT UNSIGNED NULL,
  valued_on      DATE            NOT NULL,
  valid_until    DATE            NULL,
  status         ENUM('draft','issued','superseded','expired','disputed','withdrawn') NOT NULL DEFAULT 'issued',
  notes          TEXT            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_valuations_public (public_id),
  KEY ix_valuations_unit (unit_id, valued_on),
  KEY ix_valuations_type (valuation_type, valued_on),
  KEY ix_valuations_org (organization_id, valued_on),
  KEY ix_valuations_expiry (status, valid_until),
  CONSTRAINT fk_valuations_unit FOREIGN KEY (unit_id) REFERENCES property_units (id) ON DELETE SET NULL,
  CONSTRAINT fk_valuations_building FOREIGN KEY (building_id) REFERENCES buildings (id) ON DELETE SET NULL,
  CONSTRAINT fk_valuations_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE SET NULL,
  CONSTRAINT fk_valuations_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE SET NULL,
  CONSTRAINT fk_valuations_org FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE SET NULL,
  CONSTRAINT fk_valuations_document FOREIGN KEY (report_document_id) REFERENCES documents (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- The evidence behind a valuation. Stored per valuation rather than
-- re-derived, because a comparable that was valid in March may have been
-- withdrawn by June and the valuation must remain defensible as issued.
CREATE TABLE valuation_comparables (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  valuation_id   BIGINT UNSIGNED NOT NULL,
  transaction_id BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  unit_id        BIGINT UNSIGNED NULL,
  comparable_type ENUM('transaction','active_listing','withdrawn_listing','rental','index') NOT NULL DEFAULT 'transaction',
  amount         DECIMAL(18,2)   NULL,
  price_per_area DECIMAL(14,4)   NULL,
  area           DECIMAL(12,2)   NULL,
  bedrooms       TINYINT UNSIGNED NULL,
  transaction_date DATE          NULL,
  distance_metres INT UNSIGNED   NULL,
  -- The adjustments made and their net effect, which is what a surveyor's
  -- report actually shows.
  similarity_score DECIMAL(5,2)  NULL,
  adjustments    JSON            NULL,
  adjusted_price_per_area DECIMAL(14,4) NULL,
  weight         DECIMAL(5,4)    NULL,
  is_excluded    TINYINT(1)      NOT NULL DEFAULT 0,
  exclusion_reason VARCHAR(200)  NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_valuation_comparables_valuation (valuation_id, weight),
  KEY ix_valuation_comparables_transaction (transaction_id),
  CONSTRAINT fk_valuation_comparables_valuation FOREIGN KEY (valuation_id) REFERENCES valuations (id) ON DELETE CASCADE,
  CONSTRAINT fk_valuation_comparables_transaction FOREIGN KEY (transaction_id) REFERENCES unit_transactions (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================================
-- SECTION 5 · FINANCE
-- =============================================================================

-- -----------------------------------------------------------------------------
-- lenders / mortgage_products
--
-- Mortgage comparison is a revenue line and a conversion aid: a buyer who can
-- see what they can borrow enquires more.
--
-- Rates are effective-dated for the same reason tax rates are — the rate a
-- customer was quoted on the day is the one that must be reproducible when they
-- complain three months later that the quote was wrong.
-- -----------------------------------------------------------------------------
CREATE TABLE lenders (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  lender_type    ENUM('bank','islamic_bank','building_society','specialist','broker','developer_finance','private') NOT NULL DEFAULT 'bank',
  country_id     BIGINT UNSIGNED NULL,
  logo_url       VARCHAR(500)    NULL,
  website_url    VARCHAR(500)    NULL,
  -- Commercial relationship with us.
  is_partner     TINYINT(1)      NOT NULL DEFAULT 0,
  referral_fee   DECIMAL(12,2)   NULL,
  referral_fee_percent DECIMAL(6,3) NULL,
  currency_code  CHAR(3)         NULL,
  contact_email  VARCHAR(255)    NULL,
  processing_days SMALLINT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_lenders_code (code),
  KEY ix_lenders_country (country_id, is_active),
  CONSTRAINT fk_lenders_country FOREIGN KEY (country_id) REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE mortgage_products (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  lender_id      INT UNSIGNED    NOT NULL,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  product_type   ENUM('fixed','variable','tracker','discounted','offset','interest_only','islamic_ijara','islamic_murabaha','islamic_musharaka','bridge','buy_to_let') NOT NULL DEFAULT 'fixed',
  -- Sharia-compliant products are structurally different — there is no
  -- interest, there is a profit rate — and presenting them under an APR label
  -- is both wrong and, to the customers who need them, offensive.
  is_sharia_compliant TINYINT(1) NOT NULL DEFAULT 0,
  rate_percent   DECIMAL(7,4)    NULL,
  profit_rate_percent DECIMAL(7,4) NULL,
  apr_percent    DECIMAL(7,4)    NULL,
  rate_type      ENUM('fixed','variable','tracker','stepped') NOT NULL DEFAULT 'fixed',
  fixed_period_months SMALLINT UNSIGNED NULL,
  reversion_rate_percent DECIMAL(7,4) NULL,
  -- Eligibility.
  min_amount     DECIMAL(18,2)   NULL,
  max_amount     DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  max_ltv_percent DECIMAL(5,2)   NULL,
  min_term_years TINYINT UNSIGNED NULL,
  max_term_years TINYINT UNSIGNED NULL,
  max_age_at_maturity TINYINT UNSIGNED NULL,
  min_income     DECIMAL(14,2)   NULL,
  -- Who it is for. Expatriate and non-resident terms differ sharply from
  -- national ones in Gulf markets.
  residency_requirement ENUM('national','resident','non_resident','any') NOT NULL DEFAULT 'any',
  employment_type SET('salaried','self_employed','business_owner','retired') NULL,
  property_types SET('ready','off_plan','land','commercial','buy_to_let') NULL,
  -- Costs.
  arrangement_fee DECIMAL(12,2)  NULL,
  arrangement_fee_percent DECIMAL(6,3) NULL,
  valuation_fee  DECIMAL(12,2)   NULL,
  early_settlement_fee_percent DECIMAL(6,3) NULL,
  effective_from DATE            NOT NULL,
  effective_to   DATE            NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mortgage_products (lender_id, code, effective_from),
  KEY ix_mortgage_products_search (is_active, currency_code, max_ltv_percent, rate_percent),
  CONSTRAINT fk_mortgage_products_lender FOREIGN KEY (lender_id) REFERENCES lenders (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- mortgage_applications
--
-- A buyer's finance journey, from enquiry to drawdown. Tracked because a deal
-- that collapses at the finance stage collapses late and expensively, and
-- because the lead is not really qualified until this has a pre-approval on it.
-- -----------------------------------------------------------------------------
CREATE TABLE mortgage_applications (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        NOT NULL,
  reference      VARCHAR(40)     NOT NULL,
  lead_id        BIGINT UNSIGNED NULL,
  contact_id     BIGINT UNSIGNED NULL,
  user_id        BIGINT UNSIGNED NULL,
  deal_id        BIGINT UNSIGNED NULL,
  unit_id        BIGINT UNSIGNED NULL,
  listing_id     BIGINT UNSIGNED NULL,
  organization_id BIGINT UNSIGNED NULL,
  lender_id      INT UNSIGNED    NULL,
  product_id     INT UNSIGNED    NULL,
  broker_agent_id BIGINT UNSIGNED NULL,
  -- What is being asked for.
  requested_amount DECIMAL(18,2) NULL,
  property_value DECIMAL(18,2)   NULL,
  deposit_amount DECIMAL(18,2)   NULL,
  ltv_percent    DECIMAL(5,2)    NULL,
  term_years     TINYINT UNSIGNED NULL,
  currency_code  CHAR(3)         NOT NULL DEFAULT 'AED',
  -- Applicant circumstances, which is what the decision turns on.
  applicant_income DECIMAL(14,2) NULL,
  income_period  ENUM('annual','monthly') NULL,
  existing_liabilities DECIMAL(14,2) NULL,
  employment_type ENUM('salaried','self_employed','business_owner','retired','other') NULL,
  residency_status ENUM('national','resident','non_resident') NULL,
  credit_score   SMALLINT UNSIGNED NULL,
  -- Progress.
  status         ENUM('enquiry','documents_pending','submitted','pre_approved','valuation_ordered','underwriting','approved','offer_issued','declined','withdrawn','completed','expired') NOT NULL DEFAULT 'enquiry',
  stage_updated_at DATETIME(3)   NULL,
  pre_approval_amount DECIMAL(18,2) NULL,
  pre_approved_at DATE           NULL,
  pre_approval_expires_on DATE   NULL,
  offer_amount   DECIMAL(18,2)   NULL,
  offer_rate_percent DECIMAL(7,4) NULL,
  offered_at     DATE            NULL,
  offer_expires_on DATE          NULL,
  declined_reason VARCHAR(500)   NULL,
  completed_at   DATE            NULL,
  -- Our commercial interest.
  referral_fee_earned DECIMAL(12,2) NULL,
  referral_fee_status ENUM('none','pending','invoiced','paid','cancelled') NOT NULL DEFAULT 'none',
  valuation_id   BIGINT UNSIGNED NULL,
  notes          TEXT            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_mortgage_applications_public (public_id),
  UNIQUE KEY uq_mortgage_applications_reference (reference),
  KEY ix_mortgage_applications_status (status, updated_at),
  KEY ix_mortgage_applications_lead (lead_id),
  KEY ix_mortgage_applications_deal (deal_id),
  KEY ix_mortgage_applications_lender (lender_id, status),
  -- Pre-approvals and offers expire, and an expired one silently kills a deal.
  KEY ix_mortgage_applications_expiry (status, offer_expires_on),
  CONSTRAINT fk_mortgage_applications_lead FOREIGN KEY (lead_id) REFERENCES leads (id) ON DELETE SET NULL,
  CONSTRAINT fk_mortgage_applications_contact FOREIGN KEY (contact_id) REFERENCES crm_contacts (id) ON DELETE SET NULL,
  CONSTRAINT fk_mortgage_applications_deal FOREIGN KEY (deal_id) REFERENCES deals (id) ON DELETE SET NULL,
  CONSTRAINT fk_mortgage_applications_unit FOREIGN KEY (unit_id) REFERENCES property_units (id) ON DELETE SET NULL,
  CONSTRAINT fk_mortgage_applications_lender FOREIGN KEY (lender_id) REFERENCES lenders (id) ON DELETE SET NULL,
  CONSTRAINT fk_mortgage_applications_product FOREIGN KEY (product_id) REFERENCES mortgage_products (id) ON DELETE SET NULL,
  CONSTRAINT fk_mortgage_applications_valuation FOREIGN KEY (valuation_id) REFERENCES valuations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- project_payment_plans / payment_plan_milestones
--
-- Off-plan is sold on the payment plan as much as on the price: "20% down,
-- 40% during construction, 40% on handover" is the product. Modelling
-- milestones as rows lets the platform show a real schedule, compare plans
-- across developers, and — for units actually sold — track which instalments
-- are due.
-- -----------------------------------------------------------------------------
CREATE TABLE project_payment_plans (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  project_id     BIGINT UNSIGNED NULL,
  building_id    BIGINT UNSIGNED NULL,
  developer_brand_id INT UNSIGNED NULL,
  name           VARCHAR(200)    NOT NULL,
  description    VARCHAR(1000)   NULL,
  plan_type      ENUM('construction_linked','time_linked','post_handover','cash','custom') NOT NULL DEFAULT 'construction_linked',
  down_payment_percent DECIMAL(6,3) NULL,
  during_construction_percent DECIMAL(6,3) NULL,
  on_handover_percent DECIMAL(6,3) NULL,
  post_handover_percent DECIMAL(6,3) NULL,
  post_handover_months SMALLINT UNSIGNED NULL,
  -- Sweeteners that are effectively price, and should be comparable as such.
  waives_registration_fee TINYINT(1) NOT NULL DEFAULT 0,
  service_charge_waiver_years TINYINT UNSIGNED NULL,
  guaranteed_return_percent DECIMAL(6,3) NULL,
  guaranteed_return_years TINYINT UNSIGNED NULL,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  effective_from DATE            NULL,
  effective_to   DATE            NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_payment_plans_project (project_id, is_active),
  KEY ix_payment_plans_developer (developer_brand_id, is_active),
  CONSTRAINT fk_payment_plans_project FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
  CONSTRAINT fk_payment_plans_building FOREIGN KEY (building_id) REFERENCES buildings (id) ON DELETE CASCADE,
  CONSTRAINT fk_payment_plans_developer FOREIGN KEY (developer_brand_id) REFERENCES brands (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE payment_plan_milestones (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  plan_id        INT UNSIGNED    NOT NULL,
  sequence_number SMALLINT UNSIGNED NOT NULL,
  name           VARCHAR(200)    NOT NULL,
  -- Either a construction event or a date offset. Construction-linked plans
  -- slip when the building does, which is exactly why the two are distinct.
  trigger_type   ENUM('booking','contract','construction_percent','months_from_booking','months_from_handover','handover','date') NOT NULL DEFAULT 'months_from_booking',
  construction_percent DECIMAL(5,2) NULL,
  months_offset  SMALLINT UNSIGNED NULL,
  fixed_date     DATE            NULL,
  amount_percent DECIMAL(6,3)    NULL,
  fixed_amount   DECIMAL(18,2)   NULL,
  currency_code  CHAR(3)         NULL,
  notes          VARCHAR(300)    NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_plan_milestone (plan_id, sequence_number),
  CONSTRAINT fk_plan_milestones_plan FOREIGN KEY (plan_id) REFERENCES project_payment_plans (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- market_statistics_monthly
--
-- The area-level market report: median price per area, transaction volume,
-- rental yield, days on market, by month by area by property type.
--
-- Built from `unit_transactions` (facts) rather than from listings (asking
-- prices), with `sample_size` published alongside every figure. A median drawn
-- from four transactions is not a market statistic, and publishing it without
-- the count is how portals end up reporting a 30% crash that was three villas.
-- -----------------------------------------------------------------------------
CREATE TABLE market_statistics_monthly (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  stat_month     DATE            NOT NULL,
  location_id    BIGINT UNSIGNED NOT NULL,
  location_level ENUM('country','state','city','community','sub_community','building') NOT NULL DEFAULT 'community',
  category_id    INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  unit_type      VARCHAR(40)     NULL,
  bedrooms       TINYINT UNSIGNED NULL,
  -- Transactions.
  transaction_count INT UNSIGNED NOT NULL DEFAULT 0,
  transaction_volume DECIMAL(20,2) NOT NULL DEFAULT 0,
  median_price   DECIMAL(18,2)   NULL,
  mean_price     DECIMAL(18,2)   NULL,
  median_price_per_area DECIMAL(14,4) NULL,
  price_per_area_p25 DECIMAL(14,4) NULL,
  price_per_area_p75 DECIMAL(14,4) NULL,
  currency_code  CHAR(3)         NULL,
  -- Rental.
  rental_count   INT UNSIGNED    NOT NULL DEFAULT 0,
  median_rent    DECIMAL(18,2)   NULL,
  median_rent_per_area DECIMAL(14,4) NULL,
  gross_yield_percent DECIMAL(6,3) NULL,
  -- Supply and liquidity, from the marketplace rather than the registry.
  active_listings INT UNSIGNED   NOT NULL DEFAULT 0,
  new_listings   INT UNSIGNED    NOT NULL DEFAULT 0,
  median_days_on_market SMALLINT UNSIGNED NULL,
  median_asking_price DECIMAL(18,2) NULL,
  -- The gap between asking and achieved: the most honest single indicator of
  -- which way a market is moving.
  asking_to_achieved_percent DECIMAL(6,2) NULL,
  price_reduction_count INT UNSIGNED NOT NULL DEFAULT 0,
  -- Change against the prior period.
  mom_change_percent DECIMAL(8,3) NULL,
  yoy_change_percent DECIMAL(8,3) NULL,
  -- Honesty about the sample. See the table comment.
  sample_size    INT UNSIGNED    NOT NULL DEFAULT 0,
  is_publishable TINYINT(1)      NOT NULL DEFAULT 0,
  confidence     ENUM('very_low','low','medium','high') NOT NULL DEFAULT 'low',
  computed_at    DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_market_stats (stat_month, location_id, category_id, purpose_id, unit_type, bedrooms),
  KEY ix_market_stats_location (location_id, stat_month),
  KEY ix_market_stats_publishable (is_publishable, location_level, stat_month),
  CONSTRAINT fk_market_stats_location FOREIGN KEY (location_id) REFERENCES locations (id) ON DELETE CASCADE,
  CONSTRAINT fk_market_stats_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0028', 'property_inventory');
