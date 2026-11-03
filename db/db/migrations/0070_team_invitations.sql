-- =============================================================================
-- 0070_team_invitations.sql
--
-- A company invites a person by email. The invitation holds the role until it is accepted;
-- only then does an account_members row exist. Only the hash of the link's token is stored.
-- An expired invitation stays 'pending' and is read as expired from expires_at.
-- Safe to run more than once.
-- =============================================================================

CREATE TABLE IF NOT EXISTS team_invitations (
  id                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  public_id          CHAR(26)        NOT NULL,
  account_id         BIGINT UNSIGNED NOT NULL,
  organization_id    BIGINT UNSIGNED NOT NULL,
  agent_id           BIGINT UNSIGNED NULL,
  email              VARCHAR(255)    NOT NULL,
  email_normalized   VARCHAR(255)    NOT NULL,
  first_name         VARCHAR(120)    NULL,
  last_name          VARCHAR(120)    NULL,
  role               ENUM('manager','agent','viewer') NOT NULL DEFAULT 'agent',
  title              VARCHAR(120)    NULL,
  token_hash         CHAR(64)        NOT NULL,
  status             ENUM('pending','accepted','revoked') NOT NULL DEFAULT 'pending',
  invited_by_user_id BIGINT UNSIGNED NULL,
  accepted_user_id   BIGINT UNSIGNED NULL,
  expires_at         DATETIME(3)     NOT NULL,
  accepted_at        DATETIME(3)     NULL,
  revoked_at         DATETIME(3)     NULL,
  created_at         DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updated_at         DATETIME(3)     NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),

  PRIMARY KEY (id),
  UNIQUE KEY uq_team_invitations_public (public_id),
  UNIQUE KEY uq_team_invitations_token (token_hash),
  KEY ix_team_invitations_account (account_id, status),
  KEY ix_team_invitations_email (email_normalized, status),
  CONSTRAINT fk_team_invitations_account FOREIGN KEY (account_id) REFERENCES accounts (id) ON DELETE CASCADE,
  CONSTRAINT fk_team_invitations_organization FOREIGN KEY (organization_id) REFERENCES organizations (id) ON DELETE CASCADE,
  CONSTRAINT fk_team_invitations_agent FOREIGN KEY (agent_id) REFERENCES agents (id) ON DELETE SET NULL,
  CONSTRAINT fk_team_invitations_inviter FOREIGN KEY (invited_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
  CONSTRAINT fk_team_invitations_accepted FOREIGN KEY (accepted_user_id) REFERENCES users (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO schema_migrations (version, name) VALUES ('0070', 'team_invitations')
  ON DUPLICATE KEY UPDATE applied_at = applied_at;
