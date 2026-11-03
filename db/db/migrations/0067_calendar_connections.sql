-- =============================================================================
-- 0067_calendar_connections.sql
--
-- A person's link to their own Google Calendar, made from the portal and separate
-- from signing in. Only a long-lived refresh token is kept, encrypted by the API
-- (utils/secrets.js). `booking_calendar_events` remembers which event belongs to
-- which booking, so a new time updates that event and a cancellation removes it.
-- =============================================================================

CREATE TABLE IF NOT EXISTS calendar_connections (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id            BIGINT UNSIGNED NOT NULL,
  provider           ENUM('google') NOT NULL DEFAULT 'google',
  provider_email     VARCHAR(255)   NULL,
  refresh_token_enc  TEXT           NOT NULL,
  scope              VARCHAR(500)   NULL,
  status             ENUM('active','revoked') NOT NULL DEFAULT 'active',
  last_error         VARCHAR(255)   NULL,
  connected_at       DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at         DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_calendar_connection (user_id, provider),
  CONSTRAINT fk_calendar_connection_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS booking_calendar_events (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  booking_id         BIGINT UNSIGNED NOT NULL,
  user_id            BIGINT UNSIGNED NOT NULL,
  provider           ENUM('google') NOT NULL DEFAULT 'google',
  external_event_id  VARCHAR(255)   NOT NULL,
  created_at         DATETIME(3)    NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_booking_calendar_event (booking_id, user_id, provider),
  CONSTRAINT fk_booking_event_booking FOREIGN KEY (booking_id) REFERENCES bookings (id) ON DELETE CASCADE,
  CONSTRAINT fk_booking_event_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0067', 'calendar_connections')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
