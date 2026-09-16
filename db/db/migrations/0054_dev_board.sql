-- =============================================================================
-- Liv Finder — migration 0054 · Upcoming Developments task board
-- =============================================================================
-- A single internal Kanban board (columns -> cards -> labels/comments) for staff
-- to track the pipeline of upcoming developments — "Under Discussion" through
-- whatever funnels a board admin names. There is exactly one board, so there is
-- no `boards` table: columns are top-level.
--
-- Columns and cards are soft-deleted (`deleted_at`), matching this app's
-- archive-don't-destroy convention elsewhere (e.g. archiveLocation). Labels and
-- comments have no children and are hard-deleted.
-- =============================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS `dev_board_columns` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `public_id`  CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `name`       VARCHAR(120)    NOT NULL,
  `position`   INT UNSIGNED    NOT NULL DEFAULT 0,
  `created_at` DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at` DATETIME(3)     DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dev_board_columns_public_id` (`public_id`),
  KEY `ix_dev_board_columns_position` (`deleted_at`,`position`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Lists on the Upcoming Developments board (e.g. Under Discussion, Planned, Done).';

CREATE TABLE IF NOT EXISTS `dev_board_cards` (
  `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `public_id`   CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `column_id`   BIGINT UNSIGNED NOT NULL,
  `title`       VARCHAR(200)    NOT NULL,
  `description` TEXT            DEFAULT NULL,
  `position`    INT UNSIGNED    NOT NULL DEFAULT 0,
  `created_by`  BIGINT UNSIGNED DEFAULT NULL,
  `created_at`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`  DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  `deleted_at`  DATETIME(3)     DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dev_board_cards_public_id` (`public_id`),
  KEY `ix_dev_board_cards_column` (`column_id`,`deleted_at`,`position`),
  CONSTRAINT `fk_dev_board_cards_column` FOREIGN KEY (`column_id`) REFERENCES `dev_board_columns` (`id`),
  CONSTRAINT `fk_dev_board_cards_created_by` FOREIGN KEY (`created_by`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Task cards on the Upcoming Developments board.';

CREATE TABLE IF NOT EXISTS `dev_board_labels` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `public_id`  CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `name`       VARCHAR(60)     DEFAULT NULL,
  `color`      VARCHAR(20)     NOT NULL,
  `position`   INT UNSIGNED    NOT NULL DEFAULT 0,
  `created_at` DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dev_board_labels_public_id` (`public_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Reusable colored labels, applied to cards many-to-many.';

CREATE TABLE IF NOT EXISTS `dev_board_card_labels` (
  `card_id`  BIGINT UNSIGNED NOT NULL,
  `label_id` BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (`card_id`,`label_id`),
  KEY `ix_dev_board_card_labels_label` (`label_id`),
  CONSTRAINT `fk_dev_board_card_labels_card` FOREIGN KEY (`card_id`) REFERENCES `dev_board_cards` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_dev_board_card_labels_label` FOREIGN KEY (`label_id`) REFERENCES `dev_board_labels` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Which labels are on which card.';

CREATE TABLE IF NOT EXISTS `dev_board_comments` (
  `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `public_id`       CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  `card_id`         BIGINT UNSIGNED NOT NULL,
  `author_user_id`  BIGINT UNSIGNED DEFAULT NULL,
  `body`            TEXT            NOT NULL,
  `created_at`      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at`      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_dev_board_comments_public_id` (`public_id`),
  KEY `ix_dev_board_comments_card` (`card_id`,`created_at`),
  CONSTRAINT `fk_dev_board_comments_card` FOREIGN KEY (`card_id`) REFERENCES `dev_board_cards` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_dev_board_comments_author` FOREIGN KEY (`author_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Comment thread on a card.';

-- -----------------------------------------------------------------------------
-- Seed: a fresh board starts with the funnel the request described, and the
-- fixed Trello-style label palette (colors only — an admin names them later).
-- -----------------------------------------------------------------------------

INSERT INTO `dev_board_columns` (`public_id`, `name`, `position`) VALUES
  ('01M2N6CB9PZS7Q7ZWQWSG9MRE9', 'Under Discussion', 0),
  ('01M2N6CB9QDVWQNCKDCV4Y2301', 'Planned',           1),
  ('01M2N6CB9QWVQYDNAHCHA5X1SM', 'In Progress',       2),
  ('01M2N6CB9QEJVM5E3GV9D4EKKQ', 'Done',              3)
ON DUPLICATE KEY UPDATE `name` = `name`;

INSERT INTO `dev_board_labels` (`public_id`, `color`, `position`) VALUES
  ('01M2N6CB9QSE6BVJGGGR7AYRMB', 'green',  0),
  ('01M2N6CB9QGBKF9D66XZPNBWPC', 'yellow', 1),
  ('01M2N6CB9QR910Y2H3CY3CX8S2', 'orange', 2),
  ('01M2N6CB9QGHVP4T3P9ZVHYPFQ', 'red',    3),
  ('01M2N6CB9QQP63RYJMZYYEBFQN', 'purple', 4),
  ('01M2N6CB9QFEN9368M2NYF0PVP', 'blue',   5)
ON DUPLICATE KEY UPDATE `color` = `color`;

-- -----------------------------------------------------------------------------
-- Permission: one new domain, `devBoard`, two actions. Same idiom as 0032.
-- -----------------------------------------------------------------------------

INSERT INTO `permissions` (`code`, `name`, `domain`, `action`, `is_scopable`, `sort_order`, `description`) VALUES
  ('devBoard.view', 'View the dev board', 'devBoard', 'view', 0, 870, 'See the Upcoming Developments task board.'),
  ('devBoard.edit', 'Edit the dev board', 'devBoard', 'edit', 0, 871, 'Add, move, label, comment on and delete columns and cards.')
AS new
ON DUPLICATE KEY UPDATE
  `name`        = new.`name`,
  `domain`      = new.`domain`,
  `action`      = new.`action`,
  `is_scopable` = new.`is_scopable`,
  `sort_order`  = new.`sort_order`,
  `description` = new.`description`;

-- Super admin and Administrator get it immediately; other roles can be granted
-- it later from the Role Access matrix.
INSERT IGNORE INTO `role_permissions` (`role_id`,`permission_id`)
SELECT r.`id`, p.`id` FROM `roles` r JOIN `permissions` p
 WHERE r.`code` IN ('super_admin','admin') AND p.`code` IN ('devBoard.view','devBoard.edit');

INSERT INTO schema_migrations (version, name) VALUES ('0054', 'dev_board')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
