-- =============================================================================
-- Liv Finder — 0011 · Editorial and CMS
-- =============================================================================
-- The public site's magazine (archive, article, category, author, tag, topic and
-- destination routes), static pages, navigation, redirects and location landing
-- pages.
--
-- Editorial is not decoration on a marketplace like this — it is the top of the
-- funnel and the main organic-search surface. So it gets the same treatment as
-- listings: real taxonomy, real translations, real SEO fields, and a `redirects`
-- table so URLs can be changed without losing the rankings that took years to
-- earn.
-- =============================================================================

SET NAMES utf8mb4;

-- -----------------------------------------------------------------------------
-- authors
--
-- Distinct from `users`: a byline may belong to a guest contributor with no
-- login, and an author profile must outlive the staff account behind it.
-- -----------------------------------------------------------------------------
CREATE TABLE authors (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  name           VARCHAR(200)    NOT NULL,
  slug           VARCHAR(220)    NOT NULL,
  title          VARCHAR(160)    NULL,
  bio            TEXT            NULL,
  avatar_url     VARCHAR(500)    NULL,
  email          VARCHAR(255)    NULL,
  social_links   JSON            NULL,
  post_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_authors_public_id (public_id),
  UNIQUE KEY uq_authors_slug (slug),
  KEY ix_authors_user (user_id),
  CONSTRAINT fk_authors_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- Editorial taxonomy
--
-- The public site has separate category, tag, topic and destination routes.
-- One table with a `taxonomy` discriminator rather than four near-identical
-- ones — same reasoning as the location tree: shared behaviour, shared indexes,
-- shared translation table, and adding a fifth taxonomy is an INSERT.
-- -----------------------------------------------------------------------------
CREATE TABLE editorial_terms (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  taxonomy       ENUM('category','tag','topic','destination','series') NOT NULL,
  parent_id      INT UNSIGNED    NULL,
  name           VARCHAR(160)    NOT NULL,
  slug           VARCHAR(180)    NOT NULL,
  description    TEXT            NULL,
  cover_image_url VARCHAR(500)   NULL,
  -- 'destination' terms map onto the geography tree, so a destination article
  -- can be surfaced on that location's landing page and vice versa.
  location_id    BIGINT UNSIGNED NULL,
  post_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  -- Slugs are unique per taxonomy, so /tags/dubai and /destinations/dubai can
  -- coexist.
  UNIQUE KEY uq_editorial_terms (taxonomy, slug),
  KEY ix_editorial_terms_parent (parent_id),
  KEY ix_editorial_terms_location (location_id),
  KEY ix_editorial_terms_featured (taxonomy, is_featured, sort_order),
  CONSTRAINT fk_editorial_terms_parent   FOREIGN KEY (parent_id)   REFERENCES editorial_terms (id) ON DELETE SET NULL,
  CONSTRAINT fk_editorial_terms_location FOREIGN KEY (location_id) REFERENCES locations (id)       ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE editorial_term_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  term_id        INT UNSIGNED    NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  name           VARCHAR(160)    NOT NULL,
  slug           VARCHAR(180)    NULL,
  description    TEXT            NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_editorial_term_translations (term_id, language_id),
  CONSTRAINT fk_ett_term FOREIGN KEY (term_id)     REFERENCES editorial_terms (id) ON DELETE CASCADE,
  CONSTRAINT fk_ett_lang FOREIGN KEY (language_id) REFERENCES languages (id)       ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- posts — articles, guides, market reports, press
-- -----------------------------------------------------------------------------
CREATE TABLE posts (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  author_id      INT UNSIGNED    NULL,
  primary_term_id INT UNSIGNED   NULL,

  post_type      ENUM('article','guide','news','market_report','press_release','interview','video','case_study') NOT NULL DEFAULT 'article',
  title          VARCHAR(255)    NOT NULL,
  slug           VARCHAR(280)    NOT NULL,
  excerpt        VARCHAR(600)    NULL,
  body           LONGTEXT        NULL,
  body_format    ENUM('html','markdown','blocks') NOT NULL DEFAULT 'html',

  cover_image_url VARCHAR(500)   NULL,
  cover_image_alt VARCHAR(255)   NULL,
  -- Denormalised so an article index page can render entirely from this table.
  reading_time_minutes SMALLINT UNSIGNED NULL,

  status         ENUM('draft','in_review','scheduled','published','archived') NOT NULL DEFAULT 'draft',
  visibility     ENUM('public','members','private') NOT NULL DEFAULT 'public',
  published_at   DATETIME(3)     NULL,
  scheduled_for  DATETIME(3)     NULL,

  is_featured    TINYINT(1)      NOT NULL DEFAULT 0,
  is_pinned      TINYINT(1)      NOT NULL DEFAULT 0,
  allow_comments TINYINT(1)      NOT NULL DEFAULT 0,

  view_count     INT UNSIGNED    NOT NULL DEFAULT 0,
  share_count    INT UNSIGNED    NOT NULL DEFAULT 0,

  -- Editorial cross-links: an article about Palm Jumeirah surfaces on that
  -- location's landing page and in the real-estate category feed.
  related_location_id BIGINT UNSIGNED NULL,
  related_category_id INT UNSIGNED NULL,

  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  canonical_url  VARCHAR(700)    NULL,
  is_indexable   TINYINT(1)      NOT NULL DEFAULT 1,
  og_image_url   VARCHAR(700)    NULL,
  structured_data JSON           NULL,

  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,

  PRIMARY KEY (id),
  UNIQUE KEY uq_posts_public_id (public_id),
  UNIQUE KEY uq_posts_slug (slug),
  -- The archive: published posts, newest first.
  KEY ix_posts_published (status, published_at),
  KEY ix_posts_type (post_type, status, published_at),
  KEY ix_posts_author (author_id, status, published_at),
  KEY ix_posts_term (primary_term_id, status, published_at),
  KEY ix_posts_featured (is_featured, status, published_at),
  -- Drives the scheduled-publish job.
  KEY ix_posts_scheduled (status, scheduled_for),
  KEY ix_posts_location (related_location_id, status),
  KEY ix_posts_category (related_category_id, status),
  KEY ix_posts_deleted (deleted_at),
  CONSTRAINT fk_posts_author   FOREIGN KEY (author_id)           REFERENCES authors (id)         ON DELETE SET NULL,
  CONSTRAINT fk_posts_term     FOREIGN KEY (primary_term_id)     REFERENCES editorial_terms (id) ON DELETE SET NULL,
  CONSTRAINT fk_posts_location FOREIGN KEY (related_location_id) REFERENCES locations (id)       ON DELETE SET NULL,
  CONSTRAINT fk_posts_category FOREIGN KEY (related_category_id) REFERENCES categories (id)      ON DELETE SET NULL,
  CONSTRAINT fk_posts_creator  FOREIGN KEY (created_by_user_id)  REFERENCES users (id)           ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

ALTER TABLE posts ADD FULLTEXT KEY ft_posts (title, excerpt, body);

CREATE TABLE post_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  post_id        BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  title          VARCHAR(255)    NOT NULL,
  slug           VARCHAR(280)    NULL,
  excerpt        VARCHAR(600)    NULL,
  body           LONGTEXT        NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  is_machine_translated TINYINT(1) NOT NULL DEFAULT 0,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_post_translations (post_id, language_id),
  CONSTRAINT fk_post_translations_post FOREIGN KEY (post_id)     REFERENCES posts (id)     ON DELETE CASCADE,
  CONSTRAINT fk_post_translations_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE post_terms (
  post_id        BIGINT UNSIGNED NOT NULL,
  term_id        INT UNSIGNED    NOT NULL,
  PRIMARY KEY (post_id, term_id),
  -- Reverse direction serves /tags/{slug} and /topics/{slug}.
  KEY ix_post_terms_term (term_id, post_id),
  CONSTRAINT fk_post_terms_post FOREIGN KEY (post_id) REFERENCES posts (id)           ON DELETE CASCADE,
  CONSTRAINT fk_post_terms_term FOREIGN KEY (term_id) REFERENCES editorial_terms (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Listings explicitly referenced by an article ("The 10 finest Palm villas"),
-- which is both an editorial device and a measurable referral path.
CREATE TABLE post_listings (
  post_id        BIGINT UNSIGNED NOT NULL,
  listing_id     BIGINT UNSIGNED NOT NULL,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  PRIMARY KEY (post_id, listing_id),
  KEY ix_post_listings_listing (listing_id),
  CONSTRAINT fk_post_listings_post    FOREIGN KEY (post_id)    REFERENCES posts (id)    ON DELETE CASCADE,
  CONSTRAINT fk_post_listings_listing FOREIGN KEY (listing_id) REFERENCES listings (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- pages — static/marketing CMS pages
-- -----------------------------------------------------------------------------
CREATE TABLE pages (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  parent_id      BIGINT UNSIGNED NULL,
  title          VARCHAR(255)    NOT NULL,
  slug           VARCHAR(280)    NOT NULL,
  -- Full URL path including ancestors, so routing is one indexed lookup.
  path           VARCHAR(500)    NOT NULL,
  page_type      ENUM('standard','landing','legal','help','about','contact','custom') NOT NULL DEFAULT 'standard',
  body           LONGTEXT        NULL,
  -- Structured page-builder content, when the page is composed of blocks rather
  -- than a single body.
  blocks         JSON            NULL,
  template       VARCHAR(80)     NULL,
  status         ENUM('draft','published','archived') NOT NULL DEFAULT 'draft',
  published_at   DATETIME(3)     NULL,
  -- Legal pages are versioned so `user_consents.policy_version` means something.
  version        VARCHAR(40)     NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  is_indexable   TINYINT(1)      NOT NULL DEFAULT 1,
  sort_order     INT             NOT NULL DEFAULT 0,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  deleted_at     DATETIME(3)     NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_pages_public_id (public_id),
  UNIQUE KEY uq_pages_path (path),
  KEY ix_pages_status (status, published_at),
  KEY ix_pages_parent (parent_id, sort_order),
  KEY ix_pages_type (page_type, status),
  CONSTRAINT fk_pages_parent  FOREIGN KEY (parent_id)          REFERENCES pages (id) ON DELETE SET NULL,
  CONSTRAINT fk_pages_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

CREATE TABLE page_translations (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  page_id        BIGINT UNSIGNED NOT NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  title          VARCHAR(255)    NOT NULL,
  slug           VARCHAR(280)    NULL,
  body           LONGTEXT        NULL,
  blocks         JSON            NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_page_translations (page_id, language_id),
  CONSTRAINT fk_page_translations_page FOREIGN KEY (page_id)     REFERENCES pages (id)     ON DELETE CASCADE,
  CONSTRAINT fk_page_translations_lang FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- location_landing_pages — editorial copy for country/city/community pages
--
-- Separate from `pages` because these are generated per location and joined to
-- live listing data, not hand-authored one-offs. This is the schema's answer to
-- ranking for "villas for sale in Palm Jumeirah" — a real page with real copy
-- rather than a bare filtered list.
-- -----------------------------------------------------------------------------
CREATE TABLE location_landing_pages (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  location_id    BIGINT UNSIGNED NOT NULL,
  category_id    INT UNSIGNED    NULL,
  purpose_id     SMALLINT UNSIGNED NULL,
  language_id    SMALLINT UNSIGNED NOT NULL,
  heading        VARCHAR(255)    NOT NULL,
  intro          TEXT            NULL,
  body           LONGTEXT        NULL,
  -- Structured Q&A rendered as FAQPage structured data.
  faq            JSON            NULL,
  highlights     JSON            NULL,
  hero_image_url VARCHAR(500)    NULL,
  seo_title      VARCHAR(255)    NULL,
  seo_description VARCHAR(500)   NULL,
  is_indexable   TINYINT(1)      NOT NULL DEFAULT 1,
  status         ENUM('draft','published','archived') NOT NULL DEFAULT 'draft',
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_location_landing (location_id, category_id, purpose_id, language_id),
  KEY ix_location_landing_status (status, location_id),
  CONSTRAINT fk_llp_location FOREIGN KEY (location_id) REFERENCES locations (id)  ON DELETE CASCADE,
  CONSTRAINT fk_llp_category FOREIGN KEY (category_id) REFERENCES categories (id) ON DELETE CASCADE,
  CONSTRAINT fk_llp_purpose  FOREIGN KEY (purpose_id)  REFERENCES purposes (id)   ON DELETE CASCADE,
  CONSTRAINT fk_llp_language FOREIGN KEY (language_id) REFERENCES languages (id)  ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- navigation_menus / menu_items
-- -----------------------------------------------------------------------------
CREATE TABLE navigation_menus (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  code           VARCHAR(60)     NOT NULL,
  name           VARCHAR(140)    NOT NULL,
  location       ENUM('header','footer','mobile','sidebar','portal','admin','legal') NOT NULL DEFAULT 'header',
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_navigation_menus_code (code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE menu_items (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  menu_id        INT UNSIGNED    NOT NULL,
  parent_id      INT UNSIGNED    NULL,
  label          VARCHAR(160)    NOT NULL,
  url            VARCHAR(700)    NULL,
  -- When the item points at a managed entity, the URL is derived from it so a
  -- slug change cannot leave a dead menu link behind.
  target_type    ENUM('url','page','post','category','location','term','external') NOT NULL DEFAULT 'url',
  target_id      BIGINT UNSIGNED NULL,
  icon           VARCHAR(80)     NULL,
  opens_new_tab  TINYINT(1)      NOT NULL DEFAULT 0,
  -- Gate items by audience without duplicating whole menus.
  visible_to     ENUM('everyone','guests','members','admins') NOT NULL DEFAULT 'everyone',
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  KEY ix_menu_items_menu (menu_id, parent_id, sort_order),
  CONSTRAINT fk_menu_items_menu   FOREIGN KEY (menu_id)   REFERENCES navigation_menus (id) ON DELETE CASCADE,
  CONSTRAINT fk_menu_items_parent FOREIGN KEY (parent_id) REFERENCES menu_items (id)       ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- redirects
--
-- The audit found published URLs that 404. Any URL this platform has ever
-- emitted must resolve forever — either to content or to a 301. `hit_count`
-- shows which legacy paths still matter; zero-hit rules can be retired.
-- -----------------------------------------------------------------------------
CREATE TABLE redirects (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  from_path      VARCHAR(500)    NOT NULL,
  to_path        VARCHAR(700)    NOT NULL,
  status_code    SMALLINT UNSIGNED NOT NULL DEFAULT 301,
  -- Prefix rules rewrite whole subtrees after a taxonomy change.
  is_prefix_match TINYINT(1)     NOT NULL DEFAULT 0,
  is_active      TINYINT(1)      NOT NULL DEFAULT 1,
  hit_count      INT UNSIGNED    NOT NULL DEFAULT 0,
  last_hit_at    DATETIME(3)     NULL,
  reason         VARCHAR(255)    NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_redirects_from (from_path),
  KEY ix_redirects_active (is_active, is_prefix_match),
  CONSTRAINT fk_redirects_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT ck_redirects_status CHECK (status_code IN (301,302,307,308,410))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- faqs
-- -----------------------------------------------------------------------------
CREATE TABLE faqs (
  id             INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  question       VARCHAR(500)    NOT NULL,
  answer         TEXT            NOT NULL,
  -- Scoping lets the same table serve the help centre, a category page and a
  -- location landing page.
  scope_type     ENUM('global','category','location','page','plan') NOT NULL DEFAULT 'global',
  scope_id       BIGINT UNSIGNED NULL,
  language_id    SMALLINT UNSIGNED NULL,
  sort_order     SMALLINT        NOT NULL DEFAULT 0,
  is_published   TINYINT(1)      NOT NULL DEFAULT 1,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  KEY ix_faqs_scope (scope_type, scope_id, is_published, sort_order),
  CONSTRAINT fk_faqs_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

-- -----------------------------------------------------------------------------
-- newsletter_subscribers
-- -----------------------------------------------------------------------------
CREATE TABLE newsletter_subscribers (
  id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id      CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  email          VARCHAR(255)    NOT NULL,
  user_id        BIGINT UNSIGNED NULL,
  first_name     VARCHAR(120)    NULL,
  language_id    SMALLINT UNSIGNED NULL,
  country_id     BIGINT UNSIGNED NULL,
  -- Which lists they are on: ['market-report','new-listings','editorial'].
  interests      JSON            NULL,
  status         ENUM('pending','subscribed','unsubscribed','bounced','complained') NOT NULL DEFAULT 'pending',
  -- Double opt-in is required in most of the markets this platform targets.
  confirmed_at   DATETIME(3)     NULL,
  unsubscribed_at DATETIME(3)    NULL,
  unsubscribe_token CHAR(32)     CHARACTER SET ascii NULL,
  source         VARCHAR(80)     NULL,
  ip_address     VARBINARY(16)   NULL,
  created_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at     DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_newsletter_public_id (public_id),
  UNIQUE KEY uq_newsletter_email (email),
  UNIQUE KEY uq_newsletter_token (unsubscribe_token),
  KEY ix_newsletter_status (status, created_at),
  CONSTRAINT fk_newsletter_user     FOREIGN KEY (user_id)     REFERENCES users (id)     ON DELETE SET NULL,
  CONSTRAINT fk_newsletter_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE SET NULL,
  CONSTRAINT fk_newsletter_country  FOREIGN KEY (country_id)  REFERENCES locations (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC;

INSERT INTO schema_migrations (version, name) VALUES ('0011', 'editorial');
