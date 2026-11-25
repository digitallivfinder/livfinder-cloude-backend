-- =============================================================================
-- 0085_staff_user_details.sql
--
-- Admin users are not all admins (owner, 2026-11-24): support agents, moderators and editors
-- are users with a role. Each now carries the details the Users screen asks for.
--
--   users.job_title     e.g. "Senior Support Agent".
--   users.department    e.g. "Customer Support".
--   user_languages      languages the person speaks (to route live chats, among others).
--
-- The photo is users.avatar_url, which already exists. Removing a user is a soft delete
-- (users.deleted_at) done by the API, so past actions, chats and the audit log keep their name.
--
-- Safe to run more than once.
-- =============================================================================

SET @has_title := (SELECT COUNT(*) FROM information_schema.columns
                    WHERE table_schema = DATABASE() AND table_name = 'users' AND column_name = 'job_title');
SET @ddl := IF(@has_title = 0,
  'ALTER TABLE users
     ADD COLUMN job_title VARCHAR(120) NULL AFTER display_name,
     ADD COLUMN department VARCHAR(120) NULL AFTER job_title',
  'SELECT 1');
PREPARE stmt FROM @ddl; EXECUTE stmt; DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS user_languages (
  user_id BIGINT UNSIGNED NOT NULL,
  language_id SMALLINT UNSIGNED NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (user_id, language_id),
  KEY idx_user_languages_language (language_id),
  CONSTRAINT fk_user_languages_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
  CONSTRAINT fk_user_languages_language FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0085', 'staff_user_details')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
