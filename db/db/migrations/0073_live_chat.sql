-- =============================================================================
-- 0073_live_chat.sql
--
-- Live chat (owner decision 2026-11-03: our own WebSocket chat on the existing tables).
--
-- Three kinds of conversation share conversations/messages:
--   enquiry  visitor <-> the seller of a listing, development, agent or company
--   support  visitor or client <-> LivFinder staff
--   (a staff member opening a support thread with a company is a support conversation too)
--
-- Visitors may chat without an account. A guest is a row in chat_guests, recognised by a
-- random token in an httpOnly cookie (only its hash is stored); an emailed link brings them back
-- on another device. A guest who signs up later keeps the threads (claimed by email).
--
-- Attachments are uploaded before the message that carries them, so message_id becomes
-- nullable; an upload never sent is swept after a day. Files live in private storage and are
-- read through an authorised route only.
--
-- Safe to run more than once.
-- =============================================================================

CREATE TABLE IF NOT EXISTS chat_guests (
  id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id       CHAR(26)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name            VARCHAR(160)    NOT NULL,
  email           VARCHAR(255)    NOT NULL,
  phone           VARCHAR(40)     NULL,
  -- sha256 of the cookie token. Rotated by every emailed resume link.
  token_hash      CHAR(64)        CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  email_verified_at DATETIME(3)   NULL,
  claimed_by_user_id BIGINT UNSIGNED NULL,
  ip_address      VARBINARY(16)   NULL,
  user_agent      VARCHAR(500)    NULL,
  last_seen_at    DATETIME(3)     NULL,
  created_at      DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (id),
  UNIQUE KEY uq_chat_guests_public_id (public_id),
  UNIQUE KEY uq_chat_guests_token (token_hash),
  KEY ix_chat_guests_email (email),
  CONSTRAINT fk_chat_guests_user FOREIGN KEY (claimed_by_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

DROP PROCEDURE IF EXISTS lf_0073_add_column;
DELIMITER //
CREATE PROCEDURE lf_0073_add_column(IN tbl VARCHAR(64), IN col VARCHAR(64), IN ddl TEXT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                  WHERE table_schema = DATABASE() AND table_name = tbl AND column_name = col) THEN
    SET @sql = CONCAT('ALTER TABLE `', tbl, '` ADD COLUMN ', ddl);
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END //
DELIMITER ;

-- conversations
CALL lf_0073_add_column('conversations', 'kind',
  "kind ENUM('enquiry','support') NOT NULL DEFAULT 'enquiry' AFTER public_id");
CALL lf_0073_add_column('conversations', 'project_id', 'project_id BIGINT UNSIGNED NULL AFTER listing_id');
CALL lf_0073_add_column('conversations', 'agent_id', 'agent_id BIGINT UNSIGNED NULL AFTER project_id');
CALL lf_0073_add_column('conversations', 'account_id', 'account_id BIGINT UNSIGNED NULL AFTER organization_id');
CALL lf_0073_add_column('conversations', 'created_by_user_id', 'created_by_user_id BIGINT UNSIGNED NULL');
CALL lf_0073_add_column('conversations', 'created_by_guest_id', 'created_by_guest_id BIGINT UNSIGNED NULL');
-- Support threads: the staff member handling it, and when it was closed.
CALL lf_0073_add_column('conversations', 'assigned_user_id', 'assigned_user_id BIGINT UNSIGNED NULL');
CALL lf_0073_add_column('conversations', 'closed_at', 'closed_at DATETIME(3) NULL');
CALL lf_0073_add_column('conversations', 'blocked_by_user_id', 'blocked_by_user_id BIGINT UNSIGNED NULL');
CALL lf_0073_add_column('conversations', 'blocked_at', 'blocked_at DATETIME(3) NULL');

-- conversation_participants: a guest takes the place of a user.
CALL lf_0073_add_column('conversation_participants', 'guest_id', 'guest_id BIGINT UNSIGNED NULL AFTER user_id');
-- Delivery receipts (two grey ticks). Read receipts already use last_read_at.
CALL lf_0073_add_column('conversation_participants', 'last_delivered_at', 'last_delivered_at DATETIME(3) NULL AFTER last_read_at');
CALL lf_0073_add_column('conversation_participants', 'last_emailed_at', 'last_emailed_at DATETIME(3) NULL');

-- messages
CALL lf_0073_add_column('messages', 'sender_guest_id', 'sender_guest_id BIGINT UNSIGNED NULL AFTER sender_user_id');
-- The client's own id for a message, so a resend after a dropped connection is not stored twice.
CALL lf_0073_add_column('messages', 'client_ref', 'client_ref VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NULL');

-- message_attachments
CALL lf_0073_add_column('message_attachments', 'public_id', 'public_id CHAR(26) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER id');
CALL lf_0073_add_column('message_attachments', 'conversation_id', 'conversation_id BIGINT UNSIGNED NULL AFTER message_id');
CALL lf_0073_add_column('message_attachments', 'storage_key', 'storage_key VARCHAR(500) NULL');
CALL lf_0073_add_column('message_attachments', 'preview_key', 'preview_key VARCHAR(500) NULL');
CALL lf_0073_add_column('message_attachments', 'width', 'width INT UNSIGNED NULL');
CALL lf_0073_add_column('message_attachments', 'height', 'height INT UNSIGNED NULL');
CALL lf_0073_add_column('message_attachments', 'scan_status', "scan_status VARCHAR(20) NULL");
CALL lf_0073_add_column('message_attachments', 'uploaded_by_user_id', 'uploaded_by_user_id BIGINT UNSIGNED NULL');
CALL lf_0073_add_column('message_attachments', 'uploaded_by_guest_id', 'uploaded_by_guest_id BIGINT UNSIGNED NULL');

DROP PROCEDURE lf_0073_add_column;

ALTER TABLE message_attachments MODIFY message_id BIGINT UNSIGNED NULL;
ALTER TABLE conversations MODIFY status ENUM('open','archived','closed','blocked') NOT NULL DEFAULT 'open';

DROP PROCEDURE IF EXISTS lf_0073_add_index;
DELIMITER //
CREATE PROCEDURE lf_0073_add_index(IN tbl VARCHAR(64), IN idx VARCHAR(64), IN ddl TEXT)
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.statistics
                  WHERE table_schema = DATABASE() AND table_name = tbl AND index_name = idx) THEN
    SET @sql = CONCAT('ALTER TABLE `', tbl, '` ADD ', ddl);
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
  END IF;
END //
DELIMITER ;

CALL lf_0073_add_index('conversations', 'ix_conversations_kind', 'KEY ix_conversations_kind (kind, status, last_message_at)');
CALL lf_0073_add_index('conversations', 'ix_conversations_project', 'KEY ix_conversations_project (project_id)');
CALL lf_0073_add_index('conversations', 'ix_conversations_account', 'KEY ix_conversations_account (account_id, last_message_at)');
CALL lf_0073_add_index('conversation_participants', 'uq_conversation_participants_guest',
  'UNIQUE KEY uq_conversation_participants_guest (conversation_id, guest_id)');
CALL lf_0073_add_index('conversation_participants', 'ix_conversation_participants_guest',
  'KEY ix_conversation_participants_guest (guest_id)');
CALL lf_0073_add_index('messages', 'uq_messages_client_ref', 'UNIQUE KEY uq_messages_client_ref (conversation_id, client_ref)');
CALL lf_0073_add_index('message_attachments', 'uq_message_attachments_public_id',
  'UNIQUE KEY uq_message_attachments_public_id (public_id)');
CALL lf_0073_add_index('message_attachments', 'ix_message_attachments_pending',
  'KEY ix_message_attachments_pending (conversation_id, message_id, created_at)');

DROP PROCEDURE lf_0073_add_index;

-- Existing attachments are seeded links, not stored files; they keep working as links.
UPDATE message_attachments SET public_id = CONCAT('01SEED', LPAD(id, 20, '0')) WHERE public_id IS NULL;

-- Staff permissions for the support inbox.
INSERT INTO permissions (code, name, domain, action, is_scopable, sort_order, description) VALUES
  ('supportChat.view',  'View support chats',  'supportChat', 'view',  0, 170, 'See the live support inbox.'),
  ('supportChat.reply', 'Reply to support chats', 'supportChat', 'edit', 0, 171, 'Answer, assign, close and start support chats.')
ON DUPLICATE KEY UPDATE name = VALUES(name), description = VALUES(description);

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  JOIN permissions p ON p.code IN ('supportChat.view', 'supportChat.reply')
 WHERE r.scope = 'platform' AND r.code IN ('super_admin', 'admin', 'support');

INSERT IGNORE INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
  FROM roles r
  JOIN permissions p ON p.code = 'supportChat.view'
 WHERE r.scope = 'platform' AND r.code = 'moderator';

INSERT INTO schema_migrations (version, name) VALUES ('0073', 'live_chat')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
