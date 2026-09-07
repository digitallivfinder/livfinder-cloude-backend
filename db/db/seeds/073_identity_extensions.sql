-- =============================================================================
-- 073_identity_extensions.sql
--
-- The identity and access tables that sit around the user record: live sessions,
-- one-time tokens, federated logins, second factors, the consent log, blocks,
-- join requests, identity documents and approval delegation.
--
-- Two things drive the shapes here. A session is a revocable artefact rather
-- than a cookie the server has forgotten about, so a support agent can end one
-- and see that they did. And an identity document is a liability as much as an
-- asset -- it carries a purge date from the moment it arrives, because the
-- obligation to hold it expires and the risk of holding it does not.
-- =============================================================================

SET NAMES utf8mb4;
SET collation_connection = 'utf8mb4_unicode_ci';

SET @now = NOW(3);
SET @today = CAST(CURDATE() AS CHAR) COLLATE utf8mb4_unicode_ci;

DROP TABLE IF EXISTS tmp_n;
CREATE TABLE tmp_n (n INT UNSIGNED NOT NULL PRIMARY KEY) ENGINE=InnoDB;
INSERT INTO tmp_n (n)
SELECT a.d + b.d * 10
FROM (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
      UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 AS d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
            UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b;

-- -----------------------------------------------------------------------------
-- Sessions
--
-- The session_epoch on the user is what makes "sign out everywhere" a single
-- update rather than a fan-out delete; a session whose epoch is behind the
-- user's is dead without anyone having touched its row.
-- -----------------------------------------------------------------------------
INSERT INTO user_sessions
  (public_id, user_id, token_hash, session_epoch, active_account_id, ip_address,
   user_agent, device_type, impersonated_by_user_id, created_at, last_used_at,
   expires_at, revoked_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('usession:', u.id, ':', n.n)), 26)),
  u.id,
  UNHEX(SHA2(CONCAT('sessiontoken:', u.id, ':', n.n), 256)),
  u.session_epoch,
  u.default_account_id,
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('sip:', u.id, n.n)), 1, 8), 16, 10)), 8, '0')),
  d.user_agent, d.device_type,
  NULL,
  DATE_SUB(@now, INTERVAL s.age_hours HOUR),
  DATE_SUB(@now, INTERVAL GREATEST(0, s.age_hours - 3) HOUR),
  DATE_ADD(DATE_SUB(@now, INTERVAL s.age_hours HOUR), INTERVAL 30 DAY),
  CASE WHEN s.is_revoked = 1
       THEN DATE_SUB(@now, INTERVAL GREATEST(0, s.age_hours - 1) HOUR) END
FROM users u
JOIN tmp_n n ON n.n < 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('nsessions:', u.id)), 1, 4), 16, 10), 3)
JOIN (
  SELECT u2.id AS user_id, n2.n AS seq,
         MOD(CONV(SUBSTRING(MD5(CONCAT('sage:', u2.id, n2.n)), 1, 4), 16, 10), 600) AS age_hours,
         CASE WHEN MOD(CONV(SUBSTRING(MD5(CONCAT('srev:', u2.id, n2.n)), 1, 4), 16, 10), 11) = 0
              THEN 1 ELSE 0 END AS is_revoked
  FROM users u2 CROSS JOIN tmp_n n2 WHERE n2.n < 3
) AS s ON s.user_id = u.id AND s.seq = n.n
JOIN (
  SELECT 0 AS slot, 'desktop' AS device_type, 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/124.0 Safari/537.36' AS user_agent
  UNION ALL SELECT 1, 'mobile',  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 Version/17.4 Mobile Safari/604.1'
  UNION ALL SELECT 2, 'mobile',  'Mozilla/5.0 (Linux; Android 14; SM-S918B) AppleWebKit/537.36 Chrome/124.0 Mobile Safari/537.36'
  UNION ALL SELECT 3, 'desktop', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36'
  UNION ALL SELECT 4, 'tablet',  'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) AppleWebKit/605.1.15 Version/17.4 Safari/604.1'
) AS d ON d.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('sdev:', u.id, n.n)), 1, 4), 16, 10), 5)
WHERE u.deleted_at IS NULL AND u.status = 'active';

-- A handful of support impersonation sessions, which are the ones an auditor
-- looks for first.
INSERT INTO user_sessions
  (public_id, user_id, token_hash, session_epoch, active_account_id, ip_address,
   user_agent, device_type, impersonated_by_user_id, created_at, last_used_at,
   expires_at, revoked_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('impersonate:', u.id)), 26)),
  u.id,
  UNHEX(SHA2(CONCAT('imptoken:', u.id), 256)),
  u.session_epoch, u.default_account_id,
  UNHEX('0A000105'),
  'LivFinder-Support-Console/3.1', 'desktop',
  staff.id,
  DATE_SUB(@now, INTERVAL MOD(u.id, 400) HOUR),
  DATE_SUB(@now, INTERVAL MOD(u.id, 400) HOUR),
  DATE_ADD(DATE_SUB(@now, INTERVAL MOD(u.id, 400) HOUR), INTERVAL 1 HOUR),
  DATE_ADD(DATE_SUB(@now, INTERVAL MOD(u.id, 400) HOUR), INTERVAL 25 MINUTE)
FROM users u
JOIN users staff ON staff.id = 1 + MOD(u.id, 4)
WHERE u.deleted_at IS NULL
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasimp:', u.id)), 1, 4), 16, 10), 40) = 0;

-- -----------------------------------------------------------------------------
-- One-time tokens
--
-- Hashed, attempt-counted and consumed exactly once. The attempts column is
-- what makes a brute-force attempt on a six-digit phone code visible.
-- -----------------------------------------------------------------------------
INSERT INTO user_tokens
  (user_id, purpose, token_hash, target, attempts, ip_address, created_at,
   expires_at, consumed_at)
SELECT
  u.id, t.purpose,
  -- The same purpose appears twice with different outcomes -- a reset that
  -- was used and one that was abandoned after four attempts -- so the cadence
  -- is part of the key.
  UNHEX(SHA2(CONCAT('token:', u.id, ':', t.purpose, ':', t.every), 256)),
  CASE WHEN t.purpose IN ('phone_verification') THEN u.phone_e164 ELSE u.email END,
  t.attempts,
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('tip:', u.id)), 1, 8), 16, 10)), 8, '0')),
  DATE_SUB(@now, INTERVAL t.age_hours HOUR),
  DATE_ADD(DATE_SUB(@now, INTERVAL t.age_hours HOUR), INTERVAL t.ttl_hours HOUR),
  CASE WHEN t.consumed = 1
       THEN DATE_ADD(DATE_SUB(@now, INTERVAL t.age_hours HOUR), INTERVAL 4 MINUTE) END
FROM users u
JOIN (
  SELECT 'email_verification' AS purpose, 0 AS attempts, 720 AS age_hours, 48 AS ttl_hours, 1 AS consumed, 1 AS every
  UNION ALL SELECT 'password_reset',     1, 200, 1,   1, 9
  UNION ALL SELECT 'password_reset',     4, 30,  1,   0, 23
  UNION ALL SELECT 'magic_link',         0, 12,  1,   1, 7
  UNION ALL SELECT 'phone_verification', 2, 400, 1,   1, 5
  UNION ALL SELECT 'phone_verification', 9, 6,   1,   0, 37
  UNION ALL SELECT 'invitation',         0, 600, 336, 1, 11
  UNION ALL SELECT 'mfa_recovery',       0, 900, 8760,0, 29
) AS t ON MOD(u.id, t.every) = 0
WHERE u.deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Federated identity
--
-- The provider identifier is the join key, never the email: an email can change
-- hands, a provider subject cannot, and treating them as equivalent is how
-- account takeover happens.
-- -----------------------------------------------------------------------------
INSERT INTO user_identities
  (user_id, provider, provider_uid, email, raw_profile, created_at, last_used_at)
SELECT
  u.id, p.provider,
  CONCAT(p.uid_prefix, CONV(SUBSTRING(MD5(CONCAT('uid:', u.id, p.provider)), 1, 12), 16, 10)),
  u.email,
  JSON_OBJECT('sub', CONV(SUBSTRING(MD5(CONCAT('uid:', u.id, p.provider)), 1, 12), 16, 10),
              'email', u.email, 'email_verified', TRUE,
              'name', u.display_name, 'locale', 'en'),
  u.created_at,
  COALESCE(u.last_login_at, u.created_at)
FROM users u
JOIN (
  SELECT 'google' AS provider, '1' AS uid_prefix, 0 AS slot
  UNION ALL SELECT 'apple',    '00', 1
  UNION ALL SELECT 'facebook', '7',  2
  UNION ALL SELECT 'linkedin', '',   3
  UNION ALL SELECT 'microsoft','',   4
) AS p ON p.slot = MOD(CONV(SUBSTRING(MD5(CONCAT('idp:', u.id)), 1, 4), 16, 10), 5)
WHERE u.deleted_at IS NULL
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasidp:', u.id)), 1, 4), 16, 10), 3) = 0;

-- -----------------------------------------------------------------------------
-- Second factors
-- -----------------------------------------------------------------------------
INSERT INTO user_mfa_factors
  (user_id, factor_type, secret_encrypted, label, is_primary, confirmed_at,
   last_used_at, created_at)
SELECT
  u.id, f.factor_type,
  UNHEX(SHA2(CONCAT('mfasecret:', u.id, f.factor_type), 256)),
  f.label, f.is_primary,
  DATE_ADD(u.created_at, INTERVAL 1 DAY),
  COALESCE(u.last_login_at, u.created_at),
  DATE_ADD(u.created_at, INTERVAL 1 DAY)
FROM users u
JOIN (
  SELECT 'totp' AS factor_type, 'Authenticator app' AS label, 1 AS is_primary, 0 AS only_recovery
  UNION ALL SELECT 'recovery_code', 'Recovery codes', 0, 1
  UNION ALL SELECT 'webauthn', 'Passkey on this device', 0, 0
) AS f
WHERE u.mfa_enabled = 1 AND u.deleted_at IS NULL
  AND (f.factor_type <> 'webauthn'
       OR MOD(CONV(SUBSTRING(MD5(CONCAT('passkey:', u.id)), 1, 4), 16, 10), 3) = 0);

INSERT INTO user_mfa_factors
  (user_id, factor_type, secret_encrypted, label, is_primary, confirmed_at,
   last_used_at, created_at)
SELECT
  u.id, 'sms', NULL, CONCAT('SMS to ', RIGHT(COALESCE(u.phone_e164, '0000'), 4)), 1,
  DATE_ADD(u.created_at, INTERVAL 2 HOUR),
  COALESCE(u.last_login_at, u.created_at),
  DATE_ADD(u.created_at, INTERVAL 2 HOUR)
FROM users u
WHERE u.mfa_enabled = 0 AND u.phone_verified_at IS NOT NULL AND u.deleted_at IS NULL
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('smsmfa:', u.id)), 1, 4), 16, 10), 6) = 0;

-- -----------------------------------------------------------------------------
-- Consent log
--
-- The append-only history behind the current preference. The preference answers
-- "may we send this"; the log answers "prove it", which is a different question
-- and the one that gets asked in a complaint.
-- -----------------------------------------------------------------------------
INSERT INTO user_consents
  (user_id, consent_type, is_granted, policy_version, source, ip_address, created_at)
SELECT
  u.id, c.consent_type, c.is_granted, c.policy_version, c.source,
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('cip:', u.id)), 1, 8), 16, 10)), 8, '0')),
  CASE c.at_signup WHEN 1 THEN u.created_at
       ELSE DATE_ADD(u.created_at, INTERVAL 30 + MOD(u.id, 300) DAY) END
FROM users u
JOIN (
  SELECT 'terms' AS consent_type, 1 AS is_granted, 'v3.0' AS policy_version, 'registration_form' AS source, 1 AS at_signup, 1 AS every
  UNION ALL SELECT 'privacy_policy',    1, 'v4.0', 'registration_form',   1, 1
  UNION ALL SELECT 'cookies_analytics', 1, 'v2.0', 'cookie_banner',       1, 2
  UNION ALL SELECT 'cookies_analytics', 0, 'v2.0', 'cookie_banner',       1, 3
  UNION ALL SELECT 'cookies_marketing', 0, 'v2.0', 'cookie_banner',       1, 2
  UNION ALL SELECT 'data_sharing',      1, 'v1.0', 'enquiry_form',        0, 4
  UNION ALL SELECT 'marketing_sms',     0, 'v1.0', 'account_preferences', 0, 5
  UNION ALL SELECT 'marketing_whatsapp',1, 'v1.0', 'account_preferences', 0, 7
) AS c ON MOD(u.id, c.every) = 0
WHERE u.deleted_at IS NULL;

-- The marketing-email entries follow the stored preference, so the log and the
-- flag tell the same story.
INSERT INTO user_consents
  (user_id, consent_type, is_granted, policy_version, source, ip_address, created_at)
SELECT
  u.id, 'marketing_email', u.marketing_opt_in, 'v2.0',
  CASE WHEN u.marketing_opt_in = 1 THEN 'double_opt_in' ELSE 'unsubscribe_link' END,
  UNHEX(LPAD(HEX(CONV(SUBSTRING(MD5(CONCAT('cip:', u.id)), 1, 8), 16, 10)), 8, '0')),
  CASE WHEN u.marketing_opt_in = 1 THEN u.created_at
       ELSE DATE_ADD(u.created_at, INTERVAL 30 + MOD(u.id, 200) DAY) END
FROM users u
WHERE u.deleted_at IS NULL;

-- -----------------------------------------------------------------------------
-- Blocks
--
-- A user blocking another. Enforced on messaging and on enquiry routing, so a
-- landlord who has fallen out with a broker stops receiving their enquiries.
-- -----------------------------------------------------------------------------
INSERT INTO user_blocks (blocker_user_id, blocked_user_id, reason, created_at)
SELECT
  a.id, b.id,
  ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('blockr:', a.id, b.id)), 1, 4), 16, 10), 4),
      'Repeated unsolicited contact after being asked to stop.',
      'Listed a property without instruction.',
      'Abusive language in the message thread.',
      'Persistent enquiries on properties well outside the stated brief.'),
  DATE_SUB(@now, INTERVAL MOD(CONV(SUBSTRING(MD5(CONCAT('blockd:', a.id, b.id)), 1, 4), 16, 10), 400) DAY)
FROM users a
JOIN users b
  ON b.id <> a.id
 AND b.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('blocktarget:', a.id)), 1, 5), 16, 10),
                    (SELECT COUNT(*) FROM users))
WHERE a.deleted_at IS NULL AND b.deleted_at IS NULL
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasblock:', a.id)), 1, 4), 16, 10), 18) = 0;

-- -----------------------------------------------------------------------------
-- Access requests
--
-- An agent asking to join an agency. Approved by somebody who already holds the
-- agency, which is what keeps the platform out of a decision it cannot make.
-- -----------------------------------------------------------------------------
INSERT INTO access_requests
  (public_id, organization_id, user_id, requested_role, status, message,
   reviewed_by_user_id, reviewed_at, response_note, expires_at, created_at, updated_at)
SELECT
  UPPER(LEFT(MD5(CONCAT('accessreq:', u.id, ':', o.id)), 26)),
  o.id, u.id, r.requested_role, r.status,
  CONCAT('I am joining ', o.name,
         ' as a consultant and would like access to the agency workspace to manage my listings.'),
  CASE WHEN r.status <> 'pending' THEN owner.id END,
  CASE WHEN r.status <> 'pending' THEN DATE_ADD(r.created_at, INTERVAL 2 DAY) END,
  CASE r.status
    WHEN 'approved' THEN 'Confirmed with the sales director. Access granted at agent level.'
    WHEN 'rejected' THEN 'No record of this person at the agency. Declined pending confirmation from the principal.'
    WHEN 'expired'  THEN 'No response within fourteen days; the request lapsed.'
    ELSE NULL
  END,
  DATE_ADD(r.created_at, INTERVAL 14 DAY),
  r.created_at, @now
FROM users u
JOIN organizations o
  ON o.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('reqorg:', u.id)), 1, 5), 16, 10),
                    (SELECT COUNT(*) FROM organizations))
LEFT JOIN users owner ON owner.id = 1 + MOD(o.id, 5)
JOIN (
  SELECT u2.id AS user_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('reqstat:', u2.id)), 1, 4), 16, 10), 8),
             'approved','approved','approved','approved','approved',
             'rejected','pending','expired') AS status,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('reqrole:', u2.id)), 1, 4), 16, 10), 4),
             'agent','agent','manager','accountant') AS requested_role,
         DATE_SUB(NOW(3), INTERVAL 10 + MOD(CONV(SUBSTRING(MD5(CONCAT('reqage:', u2.id)), 1, 4), 16, 10), 500) DAY) AS created_at
  FROM users u2
) AS r ON r.user_id = u.id
WHERE u.deleted_at IS NULL
  AND MOD(CONV(SUBSTRING(MD5(CONCAT('hasreq:', u.id)), 1, 4), 16, 10), 5) = 0;

-- -----------------------------------------------------------------------------
-- Identity documents
--
-- Held only as a hash and the last four characters. purge_after is set on
-- arrival rather than decided later: five years from the end of the business
-- relationship for a verified document, ninety days for a rejected one that
-- never became evidence of anything.
-- -----------------------------------------------------------------------------
INSERT INTO identity_documents
  (profile_id, document_type, issuing_country_id, number_hash, number_last4,
   holder_name, issued_on, expires_on, mrz_valid, mrz_mismatch_fields,
   status, verified_at, verified_by_user_id, rejection_reason, purge_after,
   created_at, updated_at)
SELECT
  p.id, d.document_type, c.id,
  SHA2(CONCAT('docnum:', p.id, d.document_type), 256),
  UPPER(RIGHT(MD5(CONCAT('docnum:', p.id, d.document_type)), 4)),
  COALESCE(ct.display_name, CONCAT(ct.first_name, ' ', ct.last_name), 'Holder on record'),
  DATE_SUB(@today, INTERVAL 400 + MOD(CONV(SUBSTRING(MD5(CONCAT('issued:', p.id, d.document_type)), 1, 4), 16, 10), 2200) DAY),
  DATE_ADD(@today, INTERVAL d.validity_days - MOD(CONV(SUBSTRING(MD5(CONCAT('exp:', p.id, d.document_type)), 1, 4), 16, 10), 900) DAY),
  CASE WHEN d.has_mrz = 1 AND st.status <> 'rejected' THEN 1
       WHEN d.has_mrz = 1 THEN 0 END,
  CASE WHEN d.has_mrz = 1 AND st.status = 'rejected'
       THEN '["surname","date_of_birth"]' END,
  st.status,
  CASE WHEN st.status = 'verified' THEN DATE_SUB(@now, INTERVAL MOD(p.id, 300) DAY) END,
  CASE WHEN st.status IN ('verified', 'rejected') THEN 1 + MOD(p.id, 4) END,
  CASE WHEN st.status = 'rejected'
       THEN 'Machine-readable zone does not match the details supplied on the form. A fresh scan was requested.' END,
  -- Five years for anything that became evidence; ninety days for a document
  -- that was rejected and never did.
  CASE WHEN st.status = 'rejected'
       THEN DATE_ADD(@today, INTERVAL 90 DAY)
       ELSE DATE_ADD(@today, INTERVAL 1825 DAY) END,
  DATE_SUB(@now, INTERVAL MOD(p.id, 400) DAY), @now
FROM kyc_profiles p
LEFT JOIN crm_contacts ct
  ON ct.id = 1 + MOD(CONV(SUBSTRING(MD5(CONCAT('docholder:', p.id)), 1, 5), 16, 10),
                     (SELECT COUNT(*) FROM crm_contacts))
LEFT JOIN locations c
  ON c.level = 'country'
 AND c.id = (SELECT MIN(id) FROM locations WHERE level = 'country')
JOIN (
  SELECT 'passport' AS document_type, 3650 AS validity_days, 1 AS has_mrz, 1 AS every
  UNION ALL SELECT 'national_id',       3650, 1, 2
  UNION ALL SELECT 'residence_permit',  1095, 1, 3
  UNION ALL SELECT 'utility_bill',        90, 0, 2
  UNION ALL SELECT 'bank_statement',      90, 0, 4
  UNION ALL SELECT 'trade_licence',      365, 0, 5
  UNION ALL SELECT 'tax_certificate',    365, 0, 7
) AS d ON MOD(p.id, d.every) = 0
JOIN (
  SELECT p2.id AS profile_id,
         ELT(1 + MOD(CONV(SUBSTRING(MD5(CONCAT('docstat:', p2.id)), 1, 4), 16, 10), 10),
             'verified','verified','verified','verified','verified','verified','verified',
             'pending','rejected','expired') AS status
  FROM kyc_profiles p2
) AS st ON st.profile_id = p.id;

-- -----------------------------------------------------------------------------
-- Account type change evidence
--
-- Upgrading a personal account to a brokerage requires documents. They hang off
-- the request rather than off the account, so a rejected upgrade does not leave
-- an unverified trade licence attached to a live account.
-- -----------------------------------------------------------------------------
INSERT INTO account_type_change_documents
  (request_id, document_type, file_url, file_name, file_size_bytes, mime_type,
   status, notes, uploaded_at)
SELECT
  r.id, d.document_type,
  CONCAT('https://secure.livfinder.com/uploads/atc/',
         LEFT(MD5(CONCAT('atc:', r.id, d.document_type)), 20), '.pdf'),
  CONCAT(d.document_type, '.pdf'),
  180000 + MOD(CONV(SUBSTRING(MD5(CONCAT('atcsize:', r.id, d.document_type)), 1, 5), 16, 10), 4000000),
  'application/pdf',
  CASE r.status
    WHEN 'approved' THEN 'accepted'
    WHEN 'rejected' THEN CASE WHEN d.document_type = 'trade_licence' THEN 'rejected' ELSE 'accepted' END
    ELSE 'pending'
  END,
  CASE WHEN r.status = 'rejected' AND d.document_type = 'trade_licence'
       THEN 'Licence expired four months ago. A current copy is required before the upgrade can proceed.' END,
  DATE_ADD(r.created_at, INTERVAL 1 HOUR)
FROM account_type_change_requests r
JOIN (
  SELECT 'trade_licence' AS document_type
  UNION ALL SELECT 'certificate_of_incorporation'
  UNION ALL SELECT 'authorised_signatory_id'
  UNION ALL SELECT 'proof_of_address'
) AS d;

-- -----------------------------------------------------------------------------
-- Approval delegation
--
-- Somebody has to be able to approve while the approver is on leave, and the
-- delegation has to be bounded in time and in amount or it becomes a permanent
-- second signature nobody remembers granting.
-- -----------------------------------------------------------------------------
INSERT INTO approval_delegations
  (from_user_id, to_user_id, organization_id, workflow_id, max_amount,
   currency_code, reason, starts_at, ends_at, is_active, revoked_at,
   revoked_by_user_id, used_count, created_at)
SELECT
  f.id, t.id, o.id, w.id,
  d.max_amount, 'USD', d.reason,
  DATE_SUB(@now, INTERVAL d.starts_days_ago DAY),
  DATE_ADD(@now, INTERVAL d.ends_in_days DAY),
  CASE WHEN d.revoked = 1 THEN 0 ELSE 1 END,
  CASE WHEN d.revoked = 1 THEN DATE_SUB(@now, INTERVAL 4 DAY) END,
  CASE WHEN d.revoked = 1 THEN f.id END,
  d.used_count,
  DATE_SUB(@now, INTERVAL d.starts_days_ago + 2 DAY)
FROM (
  SELECT 1 AS from_slot, 2 AS to_slot, 1 AS org_slot, 1 AS wf_slot, 50000.00 AS max_amount,
         'Annual leave, two weeks. Listing approvals and refunds up to fifty thousand.' AS reason,
         6 AS starts_days_ago, 8 AS ends_in_days, 0 AS revoked, 14 AS used_count
  UNION ALL SELECT 2, 3, 2, 2, 25000.00, 'Parental leave cover for the commercial approvals queue.', 40, 90, 0, 61
  UNION ALL SELECT 3, 4, 3, 1, 10000.00, 'Regional handover during the Gulf sales conference.', 3, 4, 0, 5
  UNION ALL SELECT 4, 1, 1, 3, 250000.00, 'Finance director delegation for month-end journal approval.', 20, 40, 0, 28
  UNION ALL SELECT 1, 3, 2, 2, 5000.00, 'Temporary cover, revoked early when the approver returned ahead of schedule.', 30, 10, 1, 2
) AS d
JOIN users f ON f.id = d.from_slot
JOIN users t ON t.id = d.to_slot
JOIN organizations o ON o.id = d.org_slot
LEFT JOIN workflow_definitions w ON w.id = d.wf_slot;

DROP TABLE IF EXISTS tmp_n;
