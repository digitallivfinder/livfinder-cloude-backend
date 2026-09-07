-- =============================================================================
-- Liv Finder — demo seed · users, accounts, organisations and agents
-- =============================================================================
-- Plain SQL. Edit it directly; there is no generator behind it.
-- Regenerate with:  python3 db/tools/build_demo_seed.py
--
-- One `users` row per person and one `accounts` row per entity they act
-- as, joined by `account_members`. Two people deliberately hold more than
-- one membership, so the account-switching flow has something real to
-- switch between, and every organisation has an owner, managers, agents
-- and at least one viewer — the role model the audit found unenforced.
-- 
-- Password hashes are a bcrypt digest of 'livfinder-demo' for every demo
-- user. They are demo credentials for a local database and must never be
-- loaded into an internet-reachable environment.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;

INSERT INTO users (id, public_id, email, email_normalized, email_verified_at, phone_country_code, phone_number, password_hash, password_updated_at, status, first_name, last_name, display_name, avatar_url, preferred_language_id, preferred_currency_id, preferred_area_unit, timezone, country_id, city_id, last_login_at, last_seen_at, login_count, mfa_enabled, marketing_opt_in, terms_accepted_at, created_at) VALUES
(1, '01K2F2DKG0R2Y92GKAQV8CJTX9', 'admin@livfinder.com', 'admin@livfinder.com', '2024-03-11 11:00:00', '971', '553173780', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-03-11 09:00:00', 'active', 'Daniel', 'Mercer', 'Daniel Mercer', 'https://cdn.livfinder.com/avatars/staff-1.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-17 04:00:00', '2026-08-17 03:12:00', 143, 1, 0, '2024-03-11 09:00:00', '2024-03-11 09:00:00'),
(2, '01K2F2DKG0A2XTJEZY8N187G3S', 'layla.haddad@livfinder.com', 'layla.haddad@livfinder.com', '2024-07-27 11:00:00', '971', '513133461', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-07-27 09:00:00', 'active', 'Layla', 'Haddad', 'Layla Haddad', 'https://cdn.livfinder.com/avatars/staff-2.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-14 15:00:00', '2026-08-17 06:44:00', 643, 1, 0, '2024-07-27 09:00:00', '2024-07-27 09:00:00'),
(3, '01K2F2DKG0Y8S760Y1DM4791DY', 'omar.mansouri@livfinder.com', 'omar.mansouri@livfinder.com', '2025-04-04 11:00:00', '971', '556699165', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-04 09:00:00', 'active', 'Omar', 'Al Mansouri', 'Omar Al Mansouri', 'https://cdn.livfinder.com/avatars/staff-3.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-16 14:00:00', '2026-08-17 06:39:00', 247, 1, 0, '2025-04-04 09:00:00', '2025-04-04 09:00:00'),
(4, '01K2F2DKG0D05TNXHHYWPC6W93', 'sarah.johnson@livfinder.com', 'sarah.johnson@livfinder.com', '2025-04-29 11:00:00', '971', '544956566', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-29 09:00:00', 'active', 'Sarah', 'Johnson', 'Sarah Johnson', 'https://cdn.livfinder.com/avatars/staff-4.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-14 23:00:00', '2026-08-17 01:00:00', 159, 1, 0, '2025-04-29 09:00:00', '2025-04-29 09:00:00'),
(5, '01K2F2DKG0XAX95AP9XJWDT952', 'james.whitfield@livfinder.com', 'james.whitfield@livfinder.com', '2024-03-19 11:00:00', '971', '553089830', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-03-19 09:00:00', 'active', 'James', 'Whitfield', 'James Whitfield', 'https://cdn.livfinder.com/avatars/staff-5.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-15 20:00:00', '2026-08-17 00:47:00', 582, 1, 0, '2024-03-19 09:00:00', '2024-03-19 09:00:00'),
(6, '01K2F2DKG0HY20FWCVJFGBKD96', 'aisha.rahman@livfinder.com', 'aisha.rahman@livfinder.com', '2025-05-23 11:00:00', '971', '516753658', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-23 09:00:00', 'active', 'Aisha', 'Rahman', 'Aisha Rahman', 'https://cdn.livfinder.com/avatars/staff-6.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-15 19:00:00', '2026-08-17 07:50:00', 90, 1, 0, '2025-05-23 09:00:00', '2025-05-23 09:00:00'),
(7, '01K2F2DKG0X9E9R0BRXH7HWDDV', 'marco.rossi@livfinder.com', 'marco.rossi@livfinder.com', '2025-03-19 11:00:00', '971', '557036388', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-19 09:00:00', 'active', 'Marco', 'Rossi', 'Marco Rossi', 'https://cdn.livfinder.com/avatars/staff-7.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-16 21:00:00', '2026-08-17 07:40:00', 155, 1, 0, '2025-03-19 09:00:00', '2025-03-19 09:00:00'),
(8, '01K2F2DKG0TAGWS3ZGD0657B8P', 'sofia.marchetti@livfinder.com', 'sofia.marchetti@livfinder.com', '2024-10-13 11:00:00', '971', '515571756', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-13 09:00:00', 'active', 'Sofia', 'Marchetti', 'Sofia Marchetti', 'https://cdn.livfinder.com/avatars/staff-8.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-16 00:00:00', '2026-08-17 06:31:00', 148, 1, 0, '2024-10-13 09:00:00', '2024-10-13 09:00:00'),
(9, '01K2F2DKG0TB4Z7X97J2CEJCQV', 'rashid.suwaidi@livfinder.com', 'rashid.suwaidi@livfinder.com', '2025-06-14 11:00:00', '971', '548975968', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-14 09:00:00', 'active', 'Rashid', 'Al Suwaidi', 'Rashid Al Suwaidi', 'https://cdn.livfinder.com/avatars/staff-9.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-16 10:00:00', '2026-08-17 07:10:00', 120, 1, 0, '2025-06-14 09:00:00', '2025-06-14 09:00:00'),
(10, '01K2F2DKG0VXA0Z606ZH9H1601', 'elena.petrova@livfinder.com', 'elena.petrova@livfinder.com', '2024-10-24 11:00:00', '971', '545410805', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-24 09:00:00', 'active', 'Elena', 'Petrova', 'Elena Petrova', 'https://cdn.livfinder.com/avatars/staff-10.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-15 04:00:00', '2026-08-17 05:45:00', 540, 1, 0, '2024-10-24 09:00:00', '2024-10-24 09:00:00'),
(11, '01K2F2DKG0WA2DZPR7P55BFNDM', 'vikram.ferrari11@example.com', 'vikram.ferrari11@example.com', '2024-12-08 10:00:00', '44', '656452970', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-12-08 09:00:00', 'active', 'Vikram', 'Ferrari', 'Vikram Ferrari', 'https://cdn.livfinder.com/avatars/agent-11.jpg', 1, 7, 'sqft', 'Europe/London', 1179, 1089864, '2026-08-02 09:00:00', '2026-08-05 10:00:00', 394, 1, 0, '2024-12-08 09:00:00', '2024-12-08 09:00:00'),
(12, '01K2F2DKG07896XQ0243PK0GYF', 'antoine.hussein12@example.com', 'antoine.hussein12@example.com', '2025-09-26 10:00:00', '44', '780606126', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-09-26 09:00:00', 'active', 'Antoine', 'Hussein', 'Antoine Hussein', 'https://cdn.livfinder.com/avatars/agent-12.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089101, '2026-08-01 09:00:00', '2026-08-09 12:00:00', 243, 0, 1, '2025-09-26 09:00:00', '2025-09-26 09:00:00'),
(13, '01K2F2DKG0ZXJ44P9ASGXV3P86', 'layla.al-suwaidi13@example.com', 'layla.al-suwaidi13@example.com', '2024-04-21 10:00:00', '44', '676147332', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-04-21 09:00:00', 'active', 'Layla', 'Al Suwaidi', 'Layla Al Suwaidi', 'https://cdn.livfinder.com/avatars/agent-13.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-07-30 09:00:00', '2026-08-04 00:00:00', 339, 1, 0, '2024-04-21 09:00:00', '2024-04-21 09:00:00'),
(14, '01K2F2DKG0JY7HZFF4BYPJZ50S', 'ingrid.el-sayed14@example.com', 'ingrid.el-sayed14@example.com', '2024-06-01 10:00:00', '44', '534799921', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-06-01 09:00:00', 'active', 'Ingrid', 'El Sayed', 'Ingrid El Sayed', 'https://cdn.livfinder.com/avatars/agent-14.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1122795, '2026-08-13 09:00:00', '2026-08-05 03:00:00', 172, 0, 1, '2024-06-01 09:00:00', '2024-06-01 09:00:00'),
(15, '01K2F2DKG0QJZ62Z43PG32V7CK', 'lucas.petrova15@example.com', 'lucas.petrova15@example.com', '2023-10-14 10:00:00', '44', '767823447', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-10-14 09:00:00', 'active', 'Lucas', 'Petrova', 'Lucas Petrova', 'https://cdn.livfinder.com/avatars/agent-15.jpg', 1, 7, 'sqft', 'Europe/London', 1179, 1089864, '2026-08-05 09:00:00', '2026-08-05 19:00:00', 221, 0, 1, '2023-10-14 09:00:00', '2023-10-14 09:00:00'),
(16, '01K2F2DKG0NCRT1PMS1Q6GF2KX', 'rashid.sato16@example.com', 'rashid.sato16@example.com', '2025-03-07 10:00:00', '44', '545812016', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-07 09:00:00', 'active', 'Rashid', 'Sato', 'Rashid Sato', 'https://cdn.livfinder.com/avatars/agent-16.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1035186, '2026-07-29 09:00:00', '2026-08-03 02:00:00', 361, 0, 1, '2025-03-07 09:00:00', '2025-03-07 09:00:00'),
(17, '01K2F2DKG0HQ5DKPKTFVB32TS4', 'diego.ivanov17@example.com', 'diego.ivanov17@example.com', '2024-01-10 10:00:00', '44', '583068578', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-01-10 09:00:00', 'active', 'Diego', 'Ivanov', 'Diego Ivanov', 'https://cdn.livfinder.com/avatars/agent-17.jpg', 1, 6, 'sqft', 'Europe/London', 1194, 1102874, '2026-07-30 09:00:00', '2026-08-04 12:00:00', 258, 0, 0, '2024-01-10 09:00:00', '2024-01-10 09:00:00'),
(18, '01K2F2DKG0MVPVKGQVGHXBD049', 'fatima.khoury18@example.com', 'fatima.khoury18@example.com', '2025-08-09 10:00:00', '971', '678134316', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-08-09 09:00:00', 'active', 'Fatima', 'Khoury', 'Fatima Khoury', 'https://cdn.livfinder.com/avatars/agent-18.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-12 09:00:00', '2026-08-16 03:00:00', 216, 1, 1, '2025-08-09 09:00:00', '2025-08-09 09:00:00'),
(19, '01K2F2DKG0VPY7NWY7DF8C6K2S', 'lucas.ivanov19@example.com', 'lucas.ivanov19@example.com', '2026-04-10 10:00:00', '44', '728231576', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-10 09:00:00', 'active', 'Lucas', 'Ivanov', 'Lucas Ivanov', 'https://cdn.livfinder.com/avatars/agent-19.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1052515, '2026-08-02 09:00:00', '2026-08-13 21:00:00', 297, 0, 0, '2026-04-10 09:00:00', '2026-04-10 09:00:00'),
(20, '01K2F2DKG0XB2E15N5M76KW9K9', 'daniel.al-otaiba20@example.com', 'daniel.al-otaiba20@example.com', '2025-06-18 10:00:00', '44', '791846038', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-18 09:00:00', 'active', 'Daniel', 'Al Otaiba', 'Daniel Al Otaiba', 'https://cdn.livfinder.com/avatars/agent-20.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-08-07 09:00:00', '2026-08-11 14:00:00', 208, 0, 0, '2025-06-18 09:00:00', '2025-06-18 09:00:00'),
(21, '01K2F2DKG0W3NX6P06Z0NM31H9', 'olivia.karim21@example.com', 'olivia.karim21@example.com', '2025-03-01 10:00:00', '44', '595211297', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-01 09:00:00', 'active', 'Olivia', 'Karim', 'Olivia Karim', 'https://cdn.livfinder.com/avatars/agent-21.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1140142, '2026-08-04 09:00:00', '2026-08-14 03:00:00', 400, 0, 0, '2025-03-01 09:00:00', '2025-03-01 09:00:00'),
(22, '01K2F2DKG0Y1VJXF6FR4CW911C', 'karim.kapoor22@example.com', 'karim.kapoor22@example.com', '2025-09-27 10:00:00', '44', '530408017', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-09-27 09:00:00', 'active', 'Karim', 'Kapoor', 'Karim Kapoor', 'https://cdn.livfinder.com/avatars/agent-22.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1059582, '2026-08-12 09:00:00', '2026-08-16 03:00:00', 351, 0, 1, '2025-09-27 09:00:00', '2025-09-27 09:00:00'),
(23, '01K2F2DKG0A6ABRYXCZTS2JHZK', 'hassan.fairfax23@example.com', 'hassan.fairfax23@example.com', '2025-01-04 10:00:00', '44', '668902367', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-04 09:00:00', 'active', 'Hassan', 'Fairfax', 'Hassan Fairfax', 'https://cdn.livfinder.com/avatars/agent-23.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1052515, '2026-08-12 09:00:00', '2026-08-12 18:00:00', 247, 1, 1, '2025-01-04 09:00:00', '2025-01-04 09:00:00'),
(24, '01K2F2DKG05MT8QRV866JDNPAQ', 'theo.darwish24@example.com', 'theo.darwish24@example.com', '2024-02-11 10:00:00', '44', '774000349', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-02-11 09:00:00', 'active', 'Theo', 'Darwish', 'Theo Darwish', 'https://cdn.livfinder.com/avatars/agent-24.jpg', 1, 2, 'sqm', 'Europe/London', 1102, 1056263, '2026-08-07 09:00:00', '2026-08-11 17:00:00', 148, 0, 1, '2024-02-11 09:00:00', '2024-02-11 09:00:00'),
(25, '01K2F2DKG0NQ72QHZJMZ7AHCQD', 'anastasia.rossi25@example.com', 'anastasia.rossi25@example.com', '2024-01-03 10:00:00', '971', '714494359', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-01-03 09:00:00', 'active', 'Anastasia', 'Rossi', 'Anastasia Rossi', 'https://cdn.livfinder.com/avatars/agent-25.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-29 09:00:00', '2026-08-11 09:00:00', 313, 0, 0, '2024-01-03 09:00:00', '2024-01-03 09:00:00'),
(26, '01K2F2DKG0TC1TAZ3SSZ9RY5K6', 'emma.von-habsburg26@example.com', 'emma.von-habsburg26@example.com', '2023-11-13 10:00:00', '971', '532770353', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-11-13 09:00:00', 'active', 'Emma', 'Von Habsburg', 'Emma Von Habsburg', 'https://cdn.livfinder.com/avatars/agent-26.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-11 09:00:00', '2026-08-05 13:00:00', 207, 0, 1, '2023-11-13 09:00:00', '2023-11-13 09:00:00'),
(27, '01K2F2DKG03TQGSVC417367DCM', 'farah.herrera27@example.com', 'farah.herrera27@example.com', '2024-07-26 10:00:00', '971', '670064177', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-07-26 09:00:00', 'active', 'Farah', 'Herrera', 'Farah Herrera', 'https://cdn.livfinder.com/avatars/agent-27.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-01 09:00:00', '2026-08-09 19:00:00', 94, 0, 0, '2024-07-26 09:00:00', '2024-07-26 09:00:00'),
(28, '01K2F2DKG0069STM8EQ2SAS4QS', 'maximilian.moreau28@example.com', 'maximilian.moreau28@example.com', '2025-02-17 10:00:00', '44', '562754358', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-17 09:00:00', 'active', 'Maximilian', 'Moreau', 'Maximilian Moreau', 'https://cdn.livfinder.com/avatars/agent-28.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1900001, '2026-08-02 09:00:00', '2026-08-15 00:00:00', 24, 0, 1, '2025-02-17 09:00:00', '2025-02-17 09:00:00'),
(29, '01K2F2DKG0F832QJ17P5ZTSGM1', 'aisha.fairfax29@example.com', 'aisha.fairfax29@example.com', '2025-04-13 10:00:00', '44', '760475598', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-13 09:00:00', 'active', 'Aisha', 'Fairfax', 'Aisha Fairfax', 'https://cdn.livfinder.com/avatars/agent-29.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1044856, '2026-08-10 09:00:00', '2026-08-02 13:00:00', 221, 1, 1, '2025-04-13 09:00:00', '2025-04-13 09:00:00'),
(30, '01K2F2DKG09BTK4QD7T2TH89SZ', 'youssef.al-mansouri30@example.com', 'youssef.al-mansouri30@example.com', '2025-06-22 10:00:00', '44', '596091900', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-22 09:00:00', 'active', 'Youssef', 'Al Mansouri', 'Youssef Al Mansouri', 'https://cdn.livfinder.com/avatars/agent-30.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1059582, '2026-07-31 09:00:00', '2026-08-14 11:00:00', 330, 1, 0, '2025-06-22 09:00:00', '2025-06-22 09:00:00'),
(31, '01K2F2DKG0G7HMGTXFR71MP9RK', 'mohammed.rossellini31@example.com', 'mohammed.rossellini31@example.com', '2026-04-09 10:00:00', '44', '629414567', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-09 09:00:00', 'active', 'Mohammed', 'Rossellini', 'Mohammed Rossellini', 'https://cdn.livfinder.com/avatars/agent-31.jpg', 1, 2, 'sqm', 'Europe/London', 1227, 1900003, '2026-08-13 09:00:00', '2026-08-08 20:00:00', 96, 0, 0, '2026-04-09 09:00:00', '2026-04-09 09:00:00'),
(32, '01K2F2DKG0RHC2STZ82XHJVTE5', 'zainab.darwish32@example.com', 'zainab.darwish32@example.com', '2026-05-22 10:00:00', '971', '643860577', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-22 09:00:00', 'active', 'Zainab', 'Darwish', 'Zainab Darwish', 'https://cdn.livfinder.com/avatars/agent-32.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-14 09:00:00', '2026-08-04 15:00:00', 178, 0, 0, '2026-05-22 09:00:00', '2026-05-22 09:00:00'),
(33, '01K2F2DKG0ADMJM9A2PMVVD5V3', 'rafael.von-habsburg33@example.com', 'rafael.von-habsburg33@example.com', '2024-09-02 10:00:00', '971', '788082908', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-02 09:00:00', 'active', 'Rafael', 'Von Habsburg', 'Rafael Von Habsburg', 'https://cdn.livfinder.com/avatars/agent-33.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-15 09:00:00', '2026-08-13 15:00:00', 325, 0, 1, '2024-09-02 09:00:00', '2024-09-02 09:00:00'),
(34, '01K2F2DKG0P3GJMZN7DGKZ5800', 'james.bin-ahmed34@example.com', 'james.bin-ahmed34@example.com', '2024-05-28 10:00:00', '971', '792861783', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-05-28 09:00:00', 'active', 'James', 'Bin Ahmed', 'James Bin Ahmed', 'https://cdn.livfinder.com/avatars/agent-34.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-09 09:00:00', '2026-08-04 14:00:00', 45, 0, 0, '2024-05-28 09:00:00', '2024-05-28 09:00:00'),
(35, '01K2F2DKG0QKKWTDNQCNMVZG5P', 'karim.sharma35@example.com', 'karim.sharma35@example.com', '2025-06-19 10:00:00', '44', '583229099', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-19 09:00:00', 'active', 'Karim', 'Sharma', 'Karim Sharma', 'https://cdn.livfinder.com/avatars/agent-35.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1122795, '2026-07-30 09:00:00', '2026-08-09 02:00:00', 177, 0, 1, '2025-06-19 09:00:00', '2025-06-19 09:00:00'),
(36, '01K2F2DKG02QA63H6JDSXPCC0M', 'mohammed.meyer36@example.com', 'mohammed.meyer36@example.com', '2024-03-17 10:00:00', '44', '597370856', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-03-17 09:00:00', 'active', 'Mohammed', 'Meyer', 'Mohammed Meyer', 'https://cdn.livfinder.com/avatars/agent-36.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1035186, '2026-08-07 09:00:00', '2026-08-05 04:00:00', 6, 0, 1, '2024-03-17 09:00:00', '2024-03-17 09:00:00'),
(37, '01K2F2DKG0T1DWW1F44EG2PZ21', 'fatima.herrera37@example.com', 'fatima.herrera37@example.com', '2024-02-10 10:00:00', '971', '674823909', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-02-10 09:00:00', 'active', 'Fatima', 'Herrera', 'Fatima Herrera', 'https://cdn.livfinder.com/avatars/agent-37.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-04 09:00:00', '2026-08-07 11:00:00', 126, 0, 0, '2024-02-10 09:00:00', '2024-02-10 09:00:00'),
(38, '01K2F2DKG02HRX90Y98QN1C26V', 'james.tanaka38@example.com', 'james.tanaka38@example.com', '2024-07-05 10:00:00', '44', '621322413', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-07-05 09:00:00', 'active', 'James', 'Tanaka', 'James Tanaka', 'https://cdn.livfinder.com/avatars/agent-38.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-08-15 09:00:00', '2026-08-11 04:00:00', 358, 0, 0, '2024-07-05 09:00:00', '2024-07-05 09:00:00'),
(39, '01K2F2DKG0WE0RC0Y37TV8WA6M', 'alexander.moretti39@example.com', 'alexander.moretti39@example.com', '2024-10-05 10:00:00', '971', '568583681', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-05 09:00:00', 'active', 'Alexander', 'Moretti', 'Alexander Moretti', 'https://cdn.livfinder.com/avatars/agent-39.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-08-05 09:00:00', '2026-08-08 13:00:00', 165, 0, 1, '2024-10-05 09:00:00', '2024-10-05 09:00:00'),
(40, '01K2F2DKG0VH47PV9GGG18J4MF', 'vikram.nasser40@example.com', 'vikram.nasser40@example.com', '2025-08-10 10:00:00', '44', '565668568', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-08-10 09:00:00', 'active', 'Vikram', 'Nasser', 'Vikram Nasser', 'https://cdn.livfinder.com/avatars/agent-40.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-08-06 09:00:00', '2026-08-14 05:00:00', 302, 0, 0, '2025-08-10 09:00:00', '2025-08-10 09:00:00'),
(41, '01K2F2DKG0ZY3MCP9G33ZC3Q92', 'henry.wong41@example.com', 'henry.wong41@example.com', '2026-06-16 10:00:00', '971', '500829198', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-06-16 09:00:00', 'active', 'Henry', 'Wong', 'Henry Wong', 'https://cdn.livfinder.com/avatars/agent-41.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-14 09:00:00', '2026-08-14 21:00:00', 205, 0, 1, '2026-06-16 09:00:00', '2026-06-16 09:00:00'),
(42, '01K2F2DKG0NQRMT8YKSAGJJZYR', 'aisha.petrova42@example.com', 'aisha.petrova42@example.com', '2026-05-26 10:00:00', '44', '791939951', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-26 09:00:00', 'active', 'Aisha', 'Petrova', 'Aisha Petrova', 'https://cdn.livfinder.com/avatars/agent-42.jpg', 1, 5, 'sqm', 'Europe/London', 1214, 1017827, '2026-08-02 09:00:00', '2026-08-06 18:00:00', 147, 1, 1, '2026-05-26 09:00:00', '2026-05-26 09:00:00'),
(43, '01K2F2DKG0JG5FNYX4A1XKRGCW', 'rashid.nasser43@example.com', 'rashid.nasser43@example.com', '2025-02-12 10:00:00', '44', '635168730', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-12 09:00:00', 'active', 'Rashid', 'Nasser', 'Rashid Nasser', 'https://cdn.livfinder.com/avatars/agent-43.jpg', 1, 2, 'sqm', 'Europe/London', 1102, 1056263, '2026-08-04 09:00:00', '2026-08-01 22:00:00', 381, 0, 1, '2025-02-12 09:00:00', '2025-02-12 09:00:00'),
(44, '01K2F2DKG0VPTH1FCG0FPD6QKF', 'tariq.konigsberg44@example.com', 'tariq.konigsberg44@example.com', '2026-01-30 10:00:00', '44', '680545337', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-30 09:00:00', 'active', 'Tariq', 'Königsberg', 'Tariq Königsberg', 'https://cdn.livfinder.com/avatars/agent-44.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-08-15 09:00:00', '2026-08-03 20:00:00', 52, 0, 1, '2026-01-30 09:00:00', '2026-01-30 09:00:00'),
(45, '01K2F2DKG0E2P7XQ2KRVKDAE2Q', 'vikram.sato45@example.com', 'vikram.sato45@example.com', '2024-03-22 10:00:00', '971', '798173976', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-03-22 09:00:00', 'active', 'Vikram', 'Sato', 'Vikram Sato', 'https://cdn.livfinder.com/avatars/agent-45.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-08-06 09:00:00', '2026-08-07 16:00:00', 285, 0, 0, '2024-03-22 09:00:00', '2024-03-22 09:00:00'),
(46, '01K2F2DKG042MSK6M76JEKFBGM', 'farah.blackwood46@example.com', 'farah.blackwood46@example.com', '2024-04-22 10:00:00', '44', '508742265', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-04-22 09:00:00', 'active', 'Farah', 'Blackwood', 'Farah Blackwood', 'https://cdn.livfinder.com/avatars/agent-46.jpg', 1, 12, 'sqm', 'Europe/London', 1098, 1900005, '2026-08-15 09:00:00', '2026-08-15 06:00:00', 161, 0, 0, '2024-04-22 09:00:00', '2024-04-22 09:00:00'),
(47, '01K2F2DKG0RX69R87ZJN1DT20J', 'henry.tanaka47@example.com', 'henry.tanaka47@example.com', '2026-03-02 10:00:00', '44', '733157927', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-02 09:00:00', 'active', 'Henry', 'Tanaka', 'Henry Tanaka', 'https://cdn.livfinder.com/avatars/agent-47.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1900002, '2026-08-14 09:00:00', '2026-08-07 03:00:00', 175, 1, 1, '2026-03-02 09:00:00', '2026-03-02 09:00:00'),
(48, '01K2F2DKG0SBVZ0TYZQJT2DCJY', 'julien.ferrari48@example.com', 'julien.ferrari48@example.com', '2024-11-12 10:00:00', '44', '671143685', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-12 09:00:00', 'active', 'Julien', 'Ferrari', 'Julien Ferrari', 'https://cdn.livfinder.com/avatars/agent-48.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-07-31 09:00:00', '2026-08-13 20:00:00', 355, 1, 0, '2024-11-12 09:00:00', '2024-11-12 09:00:00'),
(49, '01K2F2DKG04ABR8BCVFN40K8AJ', 'hassan.haddad49@example.com', 'hassan.haddad49@example.com', '2025-08-11 10:00:00', '44', '780992829', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-08-11 09:00:00', 'active', 'Hassan', 'Haddad', 'Hassan Haddad', 'https://cdn.livfinder.com/avatars/agent-49.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-08-05 09:00:00', '2026-08-05 14:00:00', 122, 0, 0, '2025-08-11 09:00:00', '2025-08-11 09:00:00'),
(50, '01K2F2DKG0YX4Q6KH9H91R1JV2', 'sarah.herrera50@example.com', 'sarah.herrera50@example.com', '2025-01-20 10:00:00', '44', '548981825', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-20 09:00:00', 'active', 'Sarah', 'Herrera', 'Sarah Herrera', 'https://cdn.livfinder.com/avatars/agent-50.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-08-06 09:00:00', '2026-08-06 13:00:00', 66, 0, 0, '2025-01-20 09:00:00', '2025-01-20 09:00:00'),
(51, '01K2F2DKG0450CNVK12J18XZ93', 'leila.kapoor51@example.com', 'leila.kapoor51@example.com', '2024-02-15 10:00:00', '44', '580682617', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-02-15 09:00:00', 'active', 'Leila', 'Kapoor', 'Leila Kapoor', 'https://cdn.livfinder.com/avatars/agent-51.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1044856, '2026-08-12 09:00:00', '2026-08-16 06:00:00', 111, 0, 0, '2024-02-15 09:00:00', '2024-02-15 09:00:00'),
(52, '01K2F2DKG01Y7FXJJJ7EQVYY5Z', 'charlotte.laurent52@example.com', 'charlotte.laurent52@example.com', '2025-12-28 10:00:00', '44', '667302678', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-28 09:00:00', 'active', 'Charlotte', 'Laurent', 'Charlotte Laurent', 'https://cdn.livfinder.com/avatars/agent-52.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1032653, '2026-08-07 09:00:00', '2026-08-05 09:00:00', 146, 0, 1, '2025-12-28 09:00:00', '2025-12-28 09:00:00'),
(53, '01K2F2DKG0MX0RSHXJ0N47Y8BA', 'henry.whitfield53@example.com', 'henry.whitfield53@example.com', '2023-11-08 10:00:00', '44', '539874490', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-11-08 09:00:00', 'active', 'Henry', 'Whitfield', 'Henry Whitfield', 'https://cdn.livfinder.com/avatars/agent-53.jpg', 1, 2, 'sqm', 'Europe/London', 1011, 1900004, '2026-07-31 09:00:00', '2026-08-12 16:00:00', 327, 0, 1, '2023-11-08 09:00:00', '2023-11-08 09:00:00'),
(54, '01K2F2DKG0QPRPQ3T85FCT13KM', 'henry.bin-ahmed54@example.com', 'henry.bin-ahmed54@example.com', '2025-12-06 10:00:00', '44', '542928515', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-06 09:00:00', 'active', 'Henry', 'Bin Ahmed', 'Henry Bin Ahmed', 'https://cdn.livfinder.com/avatars/agent-54.jpg', 1, 22, 'sqm', 'Europe/London', 1219, 1106650, '2026-08-06 09:00:00', '2026-08-10 21:00:00', 226, 0, 1, '2025-12-06 09:00:00', '2025-12-06 09:00:00'),
(55, '01K2F2DKG0NWQK9PJG9ED1JKCT', 'hassan.moretti55@example.com', 'hassan.moretti55@example.com', '2025-11-02 10:00:00', '44', '703022688', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-02 09:00:00', 'active', 'Hassan', 'Moretti', 'Hassan Moretti', 'https://cdn.livfinder.com/avatars/agent-55.jpg', 1, 5, 'sqm', 'Europe/London', 1214, 1017827, '2026-08-15 09:00:00', '2026-08-06 01:00:00', 255, 0, 1, '2025-11-02 09:00:00', '2025-11-02 09:00:00'),
(56, '01K2F2DKG01VEBP8127QY936EX', 'tariq.moreau56@example.com', 'tariq.moreau56@example.com', '2025-03-27 10:00:00', '971', '696875076', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-27 09:00:00', 'active', 'Tariq', 'Moreau', 'Tariq Moreau', 'https://cdn.livfinder.com/avatars/agent-56.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-11 09:00:00', '2026-08-13 00:00:00', 39, 0, 1, '2025-03-27 09:00:00', '2025-03-27 09:00:00'),
(57, '01K2F2DKG08N38NF9QCPCPV6AT', 'antoine.rossellini57@example.com', 'antoine.rossellini57@example.com', '2024-10-16 10:00:00', '44', '570269845', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-16 09:00:00', 'active', 'Antoine', 'Rossellini', 'Antoine Rossellini', 'https://cdn.livfinder.com/avatars/agent-57.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1052515, '2026-08-14 09:00:00', '2026-08-08 10:00:00', 99, 0, 1, '2024-10-16 09:00:00', '2024-10-16 09:00:00'),
(58, '01K2F2DKG0AHBCZS2PJV15CYWQ', 'diego.rahman58@example.com', 'diego.rahman58@example.com', '2025-11-05 10:00:00', '44', '624047419', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-05 09:00:00', 'active', 'Diego', 'Rahman', 'Diego Rahman', 'https://cdn.livfinder.com/avatars/agent-58.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1034729, '2026-08-02 09:00:00', '2026-08-10 17:00:00', 184, 0, 1, '2025-11-05 09:00:00', '2025-11-05 09:00:00'),
(59, '01K2F2DKG0BJ8K77PQ0J4M6BR6', 'rashid.konigsberg59@example.com', 'rashid.konigsberg59@example.com', '2023-10-16 10:00:00', '44', '707771685', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-10-16 09:00:00', 'active', 'Rashid', 'Königsberg', 'Rashid Königsberg', 'https://cdn.livfinder.com/avatars/agent-59.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-08-02 09:00:00', '2026-08-16 14:00:00', 303, 0, 1, '2023-10-16 09:00:00', '2023-10-16 09:00:00'),
(60, '01K2F2DKG0CMHE11KHJ8ADCG47', 'henry.al-balushi60@example.com', 'henry.al-balushi60@example.com', '2024-10-26 10:00:00', '44', '548894787', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-26 09:00:00', 'active', 'Henry', 'Al Balushi', 'Henry Al Balushi', 'https://cdn.livfinder.com/avatars/agent-60.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1052515, '2026-08-04 09:00:00', '2026-08-10 13:00:00', 45, 1, 1, '2024-10-26 09:00:00', '2024-10-26 09:00:00'),
(61, '01K2F2DKG0A0WQSZC39EX30RWA', 'noor.petrova61@example.com', 'noor.petrova61@example.com', '2026-04-14 10:00:00', '44', '793472733', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-14 09:00:00', 'active', 'Noor', 'Petrova', 'Noor Petrova', 'https://cdn.livfinder.com/avatars/agent-61.jpg', 1, 3, 'sqm', 'Europe/London', 1145, 1900000, '2026-07-31 09:00:00', '2026-08-07 23:00:00', 308, 0, 1, '2026-04-14 09:00:00', '2026-04-14 09:00:00'),
(62, '01K2F2DKG0FN505CKDD59WAY4P', 'julien.khoury62@example.com', 'julien.khoury62@example.com', '2023-10-06 10:00:00', '44', '731303663', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-10-06 09:00:00', 'active', 'Julien', 'Khoury', 'Julien Khoury', 'https://cdn.livfinder.com/avatars/agent-62.jpg', 1, 12, 'sqm', 'Europe/London', 1098, 1900005, '2026-08-06 09:00:00', '2026-08-10 06:00:00', 74, 0, 1, '2023-10-06 09:00:00', '2023-10-06 09:00:00'),
(63, '01K2F2DKG089X1HRHDCW69V89V', 'vikram.johnson63@example.com', 'vikram.johnson63@example.com', '2023-12-11 10:00:00', '44', '704645255', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-12-11 09:00:00', 'active', 'Vikram', 'Johnson', 'Vikram Johnson', 'https://cdn.livfinder.com/avatars/agent-63.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089250, '2026-08-13 09:00:00', '2026-08-05 15:00:00', 171, 1, 0, '2023-12-11 09:00:00', '2023-12-11 09:00:00'),
(64, '01K2F2DKG0J6XB7DQ0XAXRAS1Q', 'leila.santos64@example.com', 'leila.santos64@example.com', '2026-03-04 10:00:00', '44', '724943633', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-04 09:00:00', 'active', 'Leila', 'Santos', 'Leila Santos', 'https://cdn.livfinder.com/avatars/agent-64.jpg', 1, 13, 'sqm', 'Europe/London', 1014, 1007408, '2026-07-28 09:00:00', '2026-08-13 12:00:00', 187, 0, 1, '2026-03-04 09:00:00', '2026-03-04 09:00:00'),
(65, '01K2F2DKG0BP4RJT351Q8KWQQ2', 'emma.herrera65@example.com', 'emma.herrera65@example.com', '2024-08-16 10:00:00', '44', '503997777', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-08-16 09:00:00', 'active', 'Emma', 'Herrera', 'Emma Herrera', 'https://cdn.livfinder.com/avatars/agent-65.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089250, '2026-07-29 09:00:00', '2026-08-11 02:00:00', 154, 0, 0, '2024-08-16 09:00:00', '2024-08-16 09:00:00'),
(66, '01K2F2DKG0GMNAJTK7ECVME5ZD', 'valentina.bakr66@example.com', 'valentina.bakr66@example.com', '2023-11-27 10:00:00', '44', '636573825', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-11-27 09:00:00', 'active', 'Valentina', 'Bakr', 'Valentina Bakr', 'https://cdn.livfinder.com/avatars/agent-66.jpg', 1, 22, 'sqm', 'Europe/London', 1219, 1106650, '2026-08-10 09:00:00', '2026-08-08 15:00:00', 87, 0, 0, '2023-11-27 09:00:00', '2023-11-27 09:00:00'),
(67, '01K2F2DKG03D4D9RGENJVGZNTD', 'sofia.mercer67@example.com', 'sofia.mercer67@example.com', '2025-12-04 10:00:00', '971', '647350176', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-04 09:00:00', 'active', 'Sofia', 'Mercer', 'Sofia Mercer', 'https://cdn.livfinder.com/avatars/agent-67.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-28 09:00:00', '2026-08-02 13:00:00', 15, 0, 0, '2025-12-04 09:00:00', '2025-12-04 09:00:00'),
(68, '01K2F2DKG05Y5N5V6B2888Y6S8', 'camille.al-mansouri68@example.com', 'camille.al-mansouri68@example.com', '2023-10-16 10:00:00', '971', '738494066', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-10-16 09:00:00', 'active', 'Camille', 'Al Mansouri', 'Camille Al Mansouri', 'https://cdn.livfinder.com/avatars/agent-68.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-17 09:00:00', '2026-08-16 10:00:00', 272, 0, 0, '2023-10-16 09:00:00', '2023-10-16 09:00:00'),
(69, '01K2F2DKG0A7PB25MST077DKSS', 'layla.ferrari69@example.com', 'layla.ferrari69@example.com', '2025-09-08 10:00:00', '44', '797431303', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-09-08 09:00:00', 'active', 'Layla', 'Ferrari', 'Layla Ferrari', 'https://cdn.livfinder.com/avatars/agent-69.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1900002, '2026-08-07 09:00:00', '2026-08-17 00:00:00', 74, 0, 0, '2025-09-08 09:00:00', '2025-09-08 09:00:00'),
(70, '01K2F2DKG0AFZM2A89YRYZP646', 'theo.mercer70@example.com', 'theo.mercer70@example.com', '2026-01-15 10:00:00', '44', '526367421', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-15 09:00:00', 'active', 'Theo', 'Mercer', 'Theo Mercer', 'https://cdn.livfinder.com/avatars/agent-70.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1900001, '2026-08-05 09:00:00', '2026-08-03 11:00:00', 265, 0, 0, '2026-01-15 09:00:00', '2026-01-15 09:00:00'),
(71, '01K2F2DKG0KA6X1KHRRXZ3QTHN', 'elena.al-balushi71@example.com', 'elena.al-balushi71@example.com', '2023-08-17 10:00:00', '44', '737338992', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-08-17 09:00:00', 'active', 'Elena', 'Al Balushi', 'Elena Al Balushi', 'https://cdn.livfinder.com/avatars/agent-71.jpg', 1, 13, 'sqm', 'Europe/London', 1014, 1007408, '2026-08-01 09:00:00', '2026-08-15 23:00:00', 239, 0, 1, '2023-08-17 09:00:00', '2023-08-17 09:00:00'),
(72, '01K2F2DKG08S8KGTX7FSJ7CWJZ', 'charlotte.al-suwaidi72@example.com', 'charlotte.al-suwaidi72@example.com', '2025-08-04 10:00:00', '44', '714636312', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-08-04 09:00:00', 'active', 'Charlotte', 'Al Suwaidi', 'Charlotte Al Suwaidi', 'https://cdn.livfinder.com/avatars/agent-72.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-08-05 09:00:00', '2026-08-16 18:00:00', 298, 0, 1, '2025-08-04 09:00:00', '2025-08-04 09:00:00'),
(73, '01K2F2DKG0SBA2B9GT7K571SW7', 'lucas.ferrari73@example.com', 'lucas.ferrari73@example.com', '2026-05-20 10:00:00', '44', '571557228', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-20 09:00:00', 'active', 'Lucas', 'Ferrari', 'Lucas Ferrari', 'https://cdn.livfinder.com/avatars/agent-73.jpg', 1, 11, 'sqm', 'Europe/London', 1199, 1104057, '2026-08-06 09:00:00', '2026-08-15 01:00:00', 21, 1, 0, '2026-05-20 09:00:00', '2026-05-20 09:00:00'),
(74, '01K2F2DKG0VR80TDPJDJD1BWWK', 'nadia.nasser74@example.com', 'nadia.nasser74@example.com', '2025-10-06 10:00:00', '971', '692893966', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-06 09:00:00', 'active', 'Nadia', 'Nasser', 'Nadia Nasser', 'https://cdn.livfinder.com/avatars/agent-74.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-10 09:00:00', '2026-08-09 12:00:00', 125, 0, 1, '2025-10-06 09:00:00', '2025-10-06 09:00:00'),
(75, '01K2F2DKG0XGE6TZ96FB4G056Y', 'zainab.nasser75@example.com', 'zainab.nasser75@example.com', '2025-12-24 10:00:00', '971', '743345132', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-24 09:00:00', 'active', 'Zainab', 'Nasser', 'Zainab Nasser', 'https://cdn.livfinder.com/avatars/agent-75.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-01 09:00:00', '2026-08-11 03:00:00', 283, 0, 1, '2025-12-24 09:00:00', '2025-12-24 09:00:00'),
(76, '01K2F2DKG01C9CRXFX2HTKBK5S', 'valentina.meyer76@example.com', 'valentina.meyer76@example.com', '2026-06-06 10:00:00', '971', '623335071', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-06-06 09:00:00', 'active', 'Valentina', 'Meyer', 'Valentina Meyer', 'https://cdn.livfinder.com/avatars/agent-76.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-08-01 09:00:00', '2026-07-31 19:00:00', 268, 0, 0, '2026-06-06 09:00:00', '2026-06-06 09:00:00'),
(77, '01K2F2DKG0NA4ZAE1ZZCVYX256', 'henry.johnson77@example.com', 'henry.johnson77@example.com', '2024-05-05 10:00:00', '44', '767073902', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-05-05 09:00:00', 'active', 'Henry', 'Johnson', 'Henry Johnson', 'https://cdn.livfinder.com/avatars/agent-77.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-07-29 09:00:00', '2026-08-11 00:00:00', 358, 0, 1, '2024-05-05 09:00:00', '2024-05-05 09:00:00'),
(78, '01K2F2DKG05B0C7DAZE08ZW080', 'theo.moretti78@example.com', 'theo.moretti78@example.com', '2026-02-18 10:00:00', '44', '701945749', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-02-18 09:00:00', 'active', 'Theo', 'Moretti', 'Theo Moretti', 'https://cdn.livfinder.com/avatars/agent-78.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1140142, '2026-08-16 09:00:00', '2026-08-05 09:00:00', 392, 0, 1, '2026-02-18 09:00:00', '2026-02-18 09:00:00'),
(79, '01K2F2DKG0F5FCAYZQVHPBCMQ9', 'hassan.ashworth79@example.com', 'hassan.ashworth79@example.com', '2026-03-16 10:00:00', '44', '698102392', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-16 09:00:00', 'active', 'Hassan', 'Ashworth', 'Hassan Ashworth', 'https://cdn.livfinder.com/avatars/agent-79.jpg', 1, 12, 'sqm', 'Europe/London', 1098, 1900005, '2026-08-10 09:00:00', '2026-08-08 12:00:00', 64, 0, 0, '2026-03-16 09:00:00', '2026-03-16 09:00:00'),
(80, '01K2F2DKG098WZRMA1A4SX2PSK', 'priya.von-habsburg80@example.com', 'priya.von-habsburg80@example.com', '2024-01-13 10:00:00', '44', '686209333', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-01-13 09:00:00', 'active', 'Priya', 'Von Habsburg', 'Priya Von Habsburg', 'https://cdn.livfinder.com/avatars/agent-80.jpg', 1, 22, 'sqm', 'Europe/London', 1219, 1106650, '2026-08-09 09:00:00', '2026-08-07 10:00:00', 36, 1, 0, '2024-01-13 09:00:00', '2024-01-13 09:00:00'),
(81, '01K2F2DKG0VXJ42F2TQN9R9G1Z', 'charlotte.beaumont81@example.com', 'charlotte.beaumont81@example.com', '2025-10-04 10:00:00', '971', '553898624', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-04 09:00:00', 'active', 'Charlotte', 'Beaumont', 'Charlotte Beaumont', 'https://cdn.livfinder.com/avatars/agent-81.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-15 09:00:00', '2026-08-12 20:00:00', 375, 0, 0, '2025-10-04 09:00:00', '2025-10-04 09:00:00'),
(82, '01K2F2DKG02DX989KZCGYWK4M2', 'farah.ashworth82@example.com', 'farah.ashworth82@example.com', '2023-10-01 10:00:00', '44', '512203325', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-10-01 09:00:00', 'active', 'Farah', 'Ashworth', 'Farah Ashworth', 'https://cdn.livfinder.com/avatars/agent-82.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089245, '2026-08-07 09:00:00', '2026-08-02 23:00:00', 259, 0, 1, '2023-10-01 09:00:00', '2023-10-01 09:00:00'),
(83, '01K2F2DKG0TYQJYDQJVHBPSD4W', 'hana.mercer83@example.com', 'hana.mercer83@example.com', '2025-11-14 10:00:00', '44', '766968350', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-14 09:00:00', 'active', 'Hana', 'Mercer', 'Hana Mercer', 'https://cdn.livfinder.com/avatars/agent-83.jpg', 1, 7, 'sqft', 'Europe/London', 1179, 1089864, '2026-07-31 09:00:00', '2026-08-11 12:00:00', 254, 0, 0, '2025-11-14 09:00:00', '2025-11-14 09:00:00'),
(84, '01K2F2DKG0YP0WSHTFMZC6X4H2', 'mariam.bin-ahmed84@example.com', 'mariam.bin-ahmed84@example.com', '2025-10-01 10:00:00', '44', '592364203', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-01 09:00:00', 'active', 'Mariam', 'Bin Ahmed', 'Mariam Bin Ahmed', 'https://cdn.livfinder.com/avatars/agent-84.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1040512, '2026-08-06 09:00:00', '2026-08-01 03:00:00', 362, 0, 0, '2025-10-01 09:00:00', '2025-10-01 09:00:00'),
(85, '01K2F2DKG0THDY9H8WXSCVH2RS', 'rashid.fairfax85@example.com', 'rashid.fairfax85@example.com', '2025-07-13 10:00:00', '44', '634709110', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-07-13 09:00:00', 'active', 'Rashid', 'Fairfax', 'Rashid Fairfax', 'https://cdn.livfinder.com/avatars/agent-85.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-08-02 09:00:00', '2026-08-09 15:00:00', 366, 0, 0, '2025-07-13 09:00:00', '2025-07-13 09:00:00'),
(86, '01K2F2DKG0ETAGKW08W4J9Z8WT', 'arjun.sharma86@example.com', 'arjun.sharma86@example.com', '2025-03-10 10:00:00', '44', '782848467', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-10 09:00:00', 'active', 'Arjun', 'Sharma', 'Arjun Sharma', 'https://cdn.livfinder.com/avatars/agent-86.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1900002, '2026-08-09 09:00:00', '2026-08-04 17:00:00', 76, 0, 1, '2025-03-10 09:00:00', '2025-03-10 09:00:00'),
(87, '01K2F2DKG0SN2FJP80RZDBEA8W', 'daniel.darwish87@example.com', 'daniel.darwish87@example.com', '2026-07-05 10:00:00', '44', '633295542', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-05 09:00:00', 'active', 'Daniel', 'Darwish', 'Daniel Darwish', 'https://cdn.livfinder.com/avatars/agent-87.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1059582, '2026-08-13 09:00:00', '2026-08-01 20:00:00', 5, 0, 1, '2026-07-05 09:00:00', '2026-07-05 09:00:00'),
(88, '01K2F2DKG0SZBKR5VK767B75D7', 'sarah.haddad88@example.com', 'sarah.haddad88@example.com', '2024-03-16 10:00:00', '44', '558865147', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-03-16 09:00:00', 'active', 'Sarah', 'Haddad', 'Sarah Haddad', 'https://cdn.livfinder.com/avatars/agent-88.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1046589, '2026-08-10 09:00:00', '2026-08-01 22:00:00', 124, 0, 1, '2024-03-16 09:00:00', '2024-03-16 09:00:00'),
(89, '01K2F2DKG04TH9746WKPEZJ3KE', 'olivia.blackwood89@example.com', 'olivia.blackwood89@example.com', '2024-11-20 10:00:00', '44', '694493218', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-20 09:00:00', 'active', 'Olivia', 'Blackwood', 'Olivia Blackwood', 'https://cdn.livfinder.com/avatars/agent-89.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-08-13 09:00:00', '2026-08-11 06:00:00', 332, 0, 0, '2024-11-20 09:00:00', '2024-11-20 09:00:00'),
(90, '01K2F2DKG015VX4VPKJMFQAAXW', 'zainab.mercer90@example.com', 'zainab.mercer90@example.com', '2025-10-24 10:00:00', '44', '687175922', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-24 09:00:00', 'active', 'Zainab', 'Mercer', 'Zainab Mercer', 'https://cdn.livfinder.com/avatars/agent-90.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089101, '2026-08-13 09:00:00', '2026-08-13 08:00:00', 338, 0, 0, '2025-10-24 09:00:00', '2025-10-24 09:00:00'),
(91, '01K2F2DKG03EX92MGSQWJF7P4A', 'james.mercer91@example.com', 'james.mercer91@example.com', '2025-06-15 10:00:00', '44', '571243564', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-15 09:00:00', 'active', 'James', 'Mercer', 'James Mercer', 'https://cdn.livfinder.com/avatars/agent-91.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1140142, '2026-08-11 09:00:00', '2026-08-06 01:00:00', 232, 1, 0, '2025-06-15 09:00:00', '2025-06-15 09:00:00'),
(92, '01K2F2DKG0ZKFXXT3QJ824TKWY', 'julien.beaumont92@example.com', 'julien.beaumont92@example.com', '2023-11-16 10:00:00', '44', '687682107', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-11-16 09:00:00', 'active', 'Julien', 'Beaumont', 'Julien Beaumont', 'https://cdn.livfinder.com/avatars/agent-92.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-08-04 09:00:00', '2026-08-02 12:00:00', 292, 0, 0, '2023-11-16 09:00:00', '2023-11-16 09:00:00'),
(93, '01K2F2DKG0QV15M0PQWYA5R9PN', 'chen.hussein93@example.com', 'chen.hussein93@example.com', '2026-05-25 10:00:00', '44', '533380160', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-25 09:00:00', 'active', 'Chen', 'Hussein', 'Chen Hussein', 'https://cdn.livfinder.com/avatars/agent-93.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1044856, '2026-08-01 09:00:00', '2026-08-06 10:00:00', 272, 0, 1, '2026-05-25 09:00:00', '2026-05-25 09:00:00'),
(94, '01K2F2DKG0YK1WC65YQYVM6NBN', 'lucas.halabi94@example.com', 'lucas.halabi94@example.com', '2024-02-02 10:00:00', '44', '680873640', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-02-02 09:00:00', 'active', 'Lucas', 'Halabi', 'Lucas Halabi', 'https://cdn.livfinder.com/avatars/agent-94.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1900001, '2026-07-28 09:00:00', '2026-08-05 17:00:00', 71, 0, 1, '2024-02-02 09:00:00', '2024-02-02 09:00:00'),
(95, '01K2F2DKG0JPMRKEEJ5MMYQ3FP', 'hassan.rossi95@example.com', 'hassan.rossi95@example.com', '2026-07-15 10:00:00', '44', '784240466', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-15 09:00:00', 'active', 'Hassan', 'Rossi', 'Hassan Rossi', 'https://cdn.livfinder.com/avatars/agent-95.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1122795, '2026-08-08 09:00:00', '2026-08-15 03:00:00', 313, 0, 0, '2026-07-15 09:00:00', '2026-07-15 09:00:00'),
(96, '01K2F2DKG0EW4FJD31JAFAP63Z', 'layla.haddad96@example.com', 'layla.haddad96@example.com', '2025-08-08 10:00:00', '971', '759705405', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-08-08 09:00:00', 'active', 'Layla', 'Haddad', 'Layla Haddad', 'https://cdn.livfinder.com/avatars/agent-96.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-08-11 09:00:00', '2026-08-12 23:00:00', 119, 1, 1, '2025-08-08 09:00:00', '2025-08-08 09:00:00'),
(97, '01K2F2DKG018VSVE47Y1SM02A7', 'tariq.nasser97@example.com', 'tariq.nasser97@example.com', '2026-07-18 10:00:00', '44', '734833007', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-18 09:00:00', 'active', 'Tariq', 'Nasser', 'Tariq Nasser', 'https://cdn.livfinder.com/avatars/agent-97.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-08-10 09:00:00', '2026-08-07 16:00:00', 106, 0, 0, '2026-07-18 09:00:00', '2026-07-18 09:00:00'),
(98, '01K2F2DKG0GPDVQ13CWR8PKQW6', 'diego.laurent98@example.com', 'diego.laurent98@example.com', '2025-03-14 10:00:00', '44', '557635880', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-14 09:00:00', 'active', 'Diego', 'Laurent', 'Diego Laurent', 'https://cdn.livfinder.com/avatars/agent-98.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1122795, '2026-07-28 09:00:00', '2026-08-16 22:00:00', 224, 0, 0, '2025-03-14 09:00:00', '2025-03-14 09:00:00'),
(99, '01K2F2DKG059QFDAEW9D4960GQ', 'rania.al-suwaidi99@example.com', 'rania.al-suwaidi99@example.com', '2023-11-30 10:00:00', '44', '526657230', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-11-30 09:00:00', 'active', 'Rania', 'Al Suwaidi', 'Rania Al Suwaidi', 'https://cdn.livfinder.com/avatars/agent-99.jpg', 1, 2, 'sqm', 'Europe/London', 1102, 1056263, '2026-07-28 09:00:00', '2026-08-17 00:00:00', 279, 1, 1, '2023-11-30 09:00:00', '2023-11-30 09:00:00'),
(100, '01K2F2DKG0D0XCS0SQKQBYWPT4', 'chen.bin-ahmed100@example.com', 'chen.bin-ahmed100@example.com', '2024-07-05 10:00:00', '44', '567927565', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-07-05 09:00:00', 'active', 'Chen', 'Bin Ahmed', 'Chen Bin Ahmed', 'https://cdn.livfinder.com/avatars/agent-100.jpg', 1, 19, 'sqm', 'Europe/London', 1204, 1131059, '2026-08-17 09:00:00', '2026-08-03 05:00:00', 251, 1, 1, '2024-07-05 09:00:00', '2024-07-05 09:00:00'),
(101, '01K2F2DKG0R250FV09371M395J', 'zainab.mercer101@example.com', 'zainab.mercer101@example.com', '2025-11-17 10:00:00', '44', '677380752', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-17 09:00:00', 'active', 'Zainab', 'Mercer', 'Zainab Mercer', 'https://cdn.livfinder.com/avatars/agent-101.jpg', 1, 13, 'sqm', 'Europe/London', 1014, 1007408, '2026-08-05 09:00:00', '2026-08-12 05:00:00', 205, 0, 0, '2025-11-17 09:00:00', '2025-11-17 09:00:00'),
(102, '01K2F2DKG0JAJ4YX7KF57G5WZN', 'marco.moreau102@example.com', 'marco.moreau102@example.com', '2024-01-10 10:00:00', '44', '741385220', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-01-10 09:00:00', 'active', 'Marco', 'Moreau', 'Marco Moreau', 'https://cdn.livfinder.com/avatars/agent-102.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-08-04 09:00:00', '2026-08-10 17:00:00', 51, 0, 0, '2024-01-10 09:00:00', '2024-01-10 09:00:00'),
(103, '01K2F2DKG0JJ9757B77YGTBA16', 'omar.herrera103@example.com', 'omar.herrera103@example.com', '2026-04-14 10:00:00', '44', '745449591', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-14 09:00:00', 'active', 'Omar', 'Herrera', 'Omar Herrera', 'https://cdn.livfinder.com/avatars/agent-103.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1059582, '2026-08-14 09:00:00', '2026-08-07 15:00:00', 223, 0, 1, '2026-04-14 09:00:00', '2026-04-14 09:00:00'),
(104, '01K2F2DKG0H42RVP5YTRA4GYNB', 'noor.darwish104@example.com', 'noor.darwish104@example.com', '2026-05-19 10:00:00', '971', '737428946', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-19 09:00:00', 'active', 'Noor', 'Darwish', 'Noor Darwish', 'https://cdn.livfinder.com/avatars/agent-104.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-08-16 09:00:00', '2026-08-10 15:00:00', 361, 0, 0, '2026-05-19 09:00:00', '2026-05-19 09:00:00'),
(105, '01K2F2DKG03J6DG5Q165SM6VQK', 'sarah.bakr105@example.com', 'sarah.bakr105@example.com', '2026-06-12 10:00:00', '44', '627541957', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-06-12 09:00:00', 'active', 'Sarah', 'Bakr', 'Sarah Bakr', 'https://cdn.livfinder.com/avatars/agent-105.jpg', 1, 6, 'sqft', 'Europe/London', 1194, 1102858, '2026-08-16 09:00:00', '2026-08-13 15:00:00', 300, 0, 1, '2026-06-12 09:00:00', '2026-06-12 09:00:00'),
(106, '01K2F2DKG0XT65BN6JW25QXVEX', 'mohammed.ivanov106@example.com', 'mohammed.ivanov106@example.com', '2024-06-19 10:00:00', '971', '761611777', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-06-19 09:00:00', 'active', 'Mohammed', 'Ivanov', 'Mohammed Ivanov', 'https://cdn.livfinder.com/avatars/agent-106.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-15 09:00:00', '2026-08-11 22:00:00', 296, 1, 0, '2024-06-19 09:00:00', '2024-06-19 09:00:00'),
(107, '01K2F2DKG0AQBD85PKRW81THNS', 'elena.kapoor107@example.com', 'elena.kapoor107@example.com', '2024-10-17 10:00:00', '44', '794424239', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-17 09:00:00', 'active', 'Elena', 'Kapoor', 'Elena Kapoor', 'https://cdn.livfinder.com/avatars/agent-107.jpg', 1, 22, 'sqm', 'Europe/London', 1219, 1106650, '2026-08-10 09:00:00', '2026-08-10 07:00:00', 361, 0, 1, '2024-10-17 09:00:00', '2024-10-17 09:00:00'),
(108, '01K2F2DKG0BPVB69KRSDV14PXM', 'karim.mercer108@example.com', 'karim.mercer108@example.com', '2025-11-29 10:00:00', '971', '505388127', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-29 09:00:00', 'active', 'Karim', 'Mercer', 'Karim Mercer', 'https://cdn.livfinder.com/avatars/agent-108.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-12 09:00:00', '2026-08-15 07:00:00', 354, 0, 1, '2025-11-29 09:00:00', '2025-11-29 09:00:00'),
(109, '01K2F2DKG06W684HX7B80YMTBD', 'layla.ferrari109@example.com', 'layla.ferrari109@example.com', '2024-08-27 10:00:00', '44', '566271103', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-08-27 09:00:00', 'active', 'Layla', 'Ferrari', 'Layla Ferrari', 'https://cdn.livfinder.com/avatars/agent-109.jpg', 1, 12, 'sqm', 'Europe/London', 1098, 1900005, '2026-08-04 09:00:00', '2026-08-11 04:00:00', 224, 0, 0, '2024-08-27 09:00:00', '2024-08-27 09:00:00'),
(110, '01K2F2DKG0M09DHK0A544H1C3X', 'camille.santos110@example.com', 'camille.santos110@example.com', '2024-10-26 10:00:00', '44', '679378974', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-26 09:00:00', 'active', 'Camille', 'Santos', 'Camille Santos', 'https://cdn.livfinder.com/avatars/agent-110.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-08-01 09:00:00', '2026-08-02 04:00:00', 56, 0, 1, '2024-10-26 09:00:00', '2024-10-26 09:00:00'),
(111, '01K2F2DKG0ZGC1H73RR2P709Y2', 'tariq.sato111@example.com', 'tariq.sato111@example.com', '2024-05-03 10:00:00', '44', '643581854', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-05-03 09:00:00', 'active', 'Tariq', 'Sato', 'Tariq Sato', 'https://cdn.livfinder.com/avatars/agent-111.jpg', 1, 7, 'sqft', 'Europe/London', 1179, 1089864, '2026-08-09 09:00:00', '2026-08-04 03:00:00', 382, 0, 0, '2024-05-03 09:00:00', '2024-05-03 09:00:00'),
(112, '01K2F2DKG0X604R57S73YRNZXQ', 'elena.al-zaabi112@example.com', 'elena.al-zaabi112@example.com', '2026-01-26 10:00:00', '44', '561357692', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-26 09:00:00', 'active', 'Elena', 'Al Zaabi', 'Elena Al Zaabi', 'https://cdn.livfinder.com/avatars/agent-112.jpg', 1, 2, 'sqm', 'Europe/London', 1227, 1900003, '2026-08-11 09:00:00', '2026-08-07 04:00:00', 71, 0, 0, '2026-01-26 09:00:00', '2026-01-26 09:00:00'),
(113, '01K2F2DKG0AH17D2SFN8K1WN8E', 'khalid.moretti113@example.com', 'khalid.moretti113@example.com', '2025-04-11 10:00:00', '44', '684793757', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-11 09:00:00', 'active', 'Khalid', 'Moretti', 'Khalid Moretti', 'https://cdn.livfinder.com/avatars/agent-113.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1046589, '2026-08-11 09:00:00', '2026-08-17 06:00:00', 14, 0, 1, '2025-04-11 09:00:00', '2025-04-11 09:00:00'),
(114, '01K2F2DKG01TPYZX0BW558BBHD', 'isabella.al-zaabi114@example.com', 'isabella.al-zaabi114@example.com', '2025-04-22 10:00:00', '44', '745651367', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-22 09:00:00', 'active', 'Isabella', 'Al Zaabi', 'Isabella Al Zaabi', 'https://cdn.livfinder.com/avatars/agent-114.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1900002, '2026-08-14 09:00:00', '2026-08-12 05:00:00', 369, 0, 0, '2025-04-22 09:00:00', '2025-04-22 09:00:00'),
(115, '01K2F2DKG0HC7V35YRCSS7YN5X', 'hassan.meyer115@example.com', 'hassan.meyer115@example.com', '2025-03-10 10:00:00', '971', '606316804', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-10 09:00:00', 'active', 'Hassan', 'Meyer', 'Hassan Meyer', 'https://cdn.livfinder.com/avatars/agent-115.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-09 09:00:00', '2026-08-01 10:00:00', 215, 0, 0, '2025-03-10 09:00:00', '2025-03-10 09:00:00'),
(116, '01K2F2DKG0XKADAKZMF3B9NZ5R', 'mohammed.volkov116@example.com', 'mohammed.volkov116@example.com', '2024-06-04 10:00:00', '44', '721746319', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-06-04 09:00:00', 'active', 'Mohammed', 'Volkov', 'Mohammed Volkov', 'https://cdn.livfinder.com/avatars/agent-116.jpg', 1, 13, 'sqm', 'Europe/London', 1014, 1007408, '2026-08-06 09:00:00', '2026-08-13 00:00:00', 349, 0, 1, '2024-06-04 09:00:00', '2024-06-04 09:00:00'),
(117, '01K2F2DKG033VBWZBY7SDC8D0N', 'fatima.whitfield117@example.com', 'fatima.whitfield117@example.com', '2024-12-15 10:00:00', '44', '696840041', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-12-15 09:00:00', 'active', 'Fatima', 'Whitfield', 'Fatima Whitfield', 'https://cdn.livfinder.com/avatars/agent-117.jpg', 1, 14, 'sqm', 'Europe/London', 1039, 1017121, '2026-08-17 09:00:00', '2026-07-31 20:00:00', 67, 0, 0, '2024-12-15 09:00:00', '2024-12-15 09:00:00'),
(118, '01K2F2DKG02SW4MY363WFKBNAK', 'chen.beaumont118@example.com', 'chen.beaumont118@example.com', '2026-04-26 10:00:00', '44', '663966531', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-26 09:00:00', 'active', 'Chen', 'Beaumont', 'Chen Beaumont', 'https://cdn.livfinder.com/avatars/agent-118.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-08-01 09:00:00', '2026-08-01 02:00:00', 312, 1, 1, '2026-04-26 09:00:00', '2026-04-26 09:00:00'),
(119, '01K2F2DKG083VHCRBCW87H09P2', 'nikolai.halabi119@example.com', 'nikolai.halabi119@example.com', '2024-07-13 10:00:00', '44', '793937992', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-07-13 09:00:00', 'active', 'Nikolai', 'Halabi', 'Nikolai Halabi', 'https://cdn.livfinder.com/avatars/agent-119.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089245, '2026-08-01 09:00:00', '2026-08-14 00:00:00', 331, 1, 0, '2024-07-13 09:00:00', '2024-07-13 09:00:00'),
(120, '01K2F2DKG0NGFRCGRCAP4N135F', 'sarah.al-zaabi120@example.com', 'sarah.al-zaabi120@example.com', '2024-05-24 10:00:00', '44', '647496919', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-05-24 09:00:00', 'active', 'Sarah', 'Al Zaabi', 'Sarah Al Zaabi', 'https://cdn.livfinder.com/avatars/agent-120.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1035281, '2026-08-04 09:00:00', '2026-08-05 03:00:00', 200, 0, 0, '2024-05-24 09:00:00', '2024-05-24 09:00:00'),
(121, '01K2F2DKG0F1E1YA5BG6HBN6JP', 'isabella.al-zaabi121@example.com', 'isabella.al-zaabi121@example.com', '2024-01-31 10:00:00', '44', '670071236', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-01-31 09:00:00', 'active', 'Isabella', 'Al Zaabi', 'Isabella Al Zaabi', 'https://cdn.livfinder.com/avatars/agent-121.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-07-30 09:00:00', '2026-08-14 01:00:00', 390, 0, 1, '2024-01-31 09:00:00', '2024-01-31 09:00:00'),
(122, '01K2F2DKG0ARA1VE5ZATB3BBG9', 'sofia.dubois122@example.com', 'sofia.dubois122@example.com', '2024-09-17 10:00:00', '44', '595799340', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-17 09:00:00', 'active', 'Sofia', 'Dubois', 'Sofia Dubois', 'https://cdn.livfinder.com/avatars/agent-122.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1140142, '2026-08-07 09:00:00', '2026-08-11 15:00:00', 346, 1, 1, '2024-09-17 09:00:00', '2024-09-17 09:00:00'),
(123, '01K2F2DKG0N057F62VY169CVC7', 'rashid.tanaka123@example.com', 'rashid.tanaka123@example.com', '2024-06-09 10:00:00', '44', '768977562', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-06-09 09:00:00', 'active', 'Rashid', 'Tanaka', 'Rashid Tanaka', 'https://cdn.livfinder.com/avatars/agent-123.jpg', 1, 14, 'sqm', 'Europe/London', 1039, 1017121, '2026-08-07 09:00:00', '2026-08-16 08:00:00', 165, 0, 1, '2024-06-09 09:00:00', '2024-06-09 09:00:00'),
(124, '01K2F2DKG0S7W7KVBSS8D1VV8H', 'isabella.rossellini124@example.com', 'isabella.rossellini124@example.com', '2024-10-16 10:00:00', '44', '654030847', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-16 09:00:00', 'active', 'Isabella', 'Rossellini', 'Isabella Rossellini', 'https://cdn.livfinder.com/avatars/agent-124.jpg', 1, 21, 'sqm', 'Europe/London', 1142, 1068704, '2026-08-06 09:00:00', '2026-08-15 20:00:00', 17, 1, 0, '2024-10-16 09:00:00', '2024-10-16 09:00:00'),
(125, '01K2F2DKG09RNNVVGQFMB6BK76', 'james.dubois125@example.com', 'james.dubois125@example.com', '2023-10-28 10:00:00', '971', '643380026', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-10-28 09:00:00', 'active', 'James', 'Dubois', 'James Dubois', 'https://cdn.livfinder.com/avatars/agent-125.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-31 09:00:00', '2026-08-07 09:00:00', 286, 0, 0, '2023-10-28 09:00:00', '2023-10-28 09:00:00'),
(126, '01K2F2DKG0S6JTC98NAJFZSGDW', 'daniel.rossi126@example.com', 'daniel.rossi126@example.com', '2025-06-08 10:00:00', '44', '538896553', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-08 09:00:00', 'active', 'Daniel', 'Rossi', 'Daniel Rossi', 'https://cdn.livfinder.com/avatars/agent-126.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-08-05 09:00:00', '2026-08-12 21:00:00', 356, 0, 0, '2025-06-08 09:00:00', '2025-06-08 09:00:00'),
(127, '01K2F2DKG071SYFC8PY32M9J9S', 'youssef.rahman127@example.com', 'youssef.rahman127@example.com', '2025-11-20 10:00:00', '44', '680897222', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-20 09:00:00', 'active', 'Youssef', 'Rahman', 'Youssef Rahman', 'https://cdn.livfinder.com/avatars/agent-127.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-07-29 09:00:00', '2026-08-16 22:00:00', 338, 0, 0, '2025-11-20 09:00:00', '2025-11-20 09:00:00'),
(128, '01K2F2DKG0G15BQZETS8G59AYG', 'chen.volkov128@example.com', 'chen.volkov128@example.com', '2023-11-19 10:00:00', '44', '678795971', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-11-19 09:00:00', 'active', 'Chen', 'Volkov', 'Chen Volkov', 'https://cdn.livfinder.com/avatars/agent-128.jpg', 1, 3, 'sqm', 'Europe/London', 1145, 1900000, '2026-07-29 09:00:00', '2026-08-04 03:00:00', 221, 0, 1, '2023-11-19 09:00:00', '2023-11-19 09:00:00'),
(129, '01K2F2DKG08AE84KHXWRCK13T5', 'sarah.whitfield129@example.com', 'sarah.whitfield129@example.com', '2025-10-30 10:00:00', '44', '675035573', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-30 09:00:00', 'active', 'Sarah', 'Whitfield', 'Sarah Whitfield', 'https://cdn.livfinder.com/avatars/agent-129.jpg', 1, 6, 'sqft', 'Europe/London', 1194, 1102874, '2026-08-05 09:00:00', '2026-08-15 02:00:00', 339, 0, 1, '2025-10-30 09:00:00', '2025-10-30 09:00:00'),
(130, '01K2F2DKG0XH29RZP2J109ZN5P', 'maximilian.moreau130@example.com', 'maximilian.moreau130@example.com', '2024-07-27 10:00:00', '971', '740274573', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-07-27 09:00:00', 'active', 'Maximilian', 'Moreau', 'Maximilian Moreau', 'https://cdn.livfinder.com/avatars/agent-130.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-31 09:00:00', '2026-08-13 05:00:00', 25, 0, 1, '2024-07-27 09:00:00', '2024-07-27 09:00:00'),
(131, '01K2F2DKG019F7QW6KNAJBZSZ3', 'rania.nasser131@example.com', 'rania.nasser131@example.com', '2026-05-08 10:00:00', '44', '557952909', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-08 09:00:00', 'active', 'Rania', 'Nasser', 'Rania Nasser', 'https://cdn.livfinder.com/avatars/agent-131.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1052950, '2026-08-04 09:00:00', '2026-08-17 02:00:00', 206, 0, 1, '2026-05-08 09:00:00', '2026-05-08 09:00:00'),
(132, '01K2F2DKG0KTR5504KYCSCTQBS', 'khalid.ivanov132@example.com', 'khalid.ivanov132@example.com', '2025-05-28 10:00:00', '44', '786669346', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-28 09:00:00', 'active', 'Khalid', 'Ivanov', 'Khalid Ivanov', 'https://cdn.livfinder.com/avatars/agent-132.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1044856, '2026-08-10 09:00:00', '2026-08-14 16:00:00', 196, 1, 0, '2025-05-28 09:00:00', '2025-05-28 09:00:00'),
(133, '01K2F2DKG0SNM51PQGCQ73KBSZ', 'zainab.nasser133@example.com', 'zainab.nasser133@example.com', '2025-04-02 10:00:00', '44', '674744235', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-02 09:00:00', 'active', 'Zainab', 'Nasser', 'Zainab Nasser', 'https://cdn.livfinder.com/avatars/agent-133.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089101, '2026-08-10 09:00:00', '2026-08-06 17:00:00', 31, 0, 1, '2025-04-02 09:00:00', '2025-04-02 09:00:00'),
(134, '01K2F2DKG0F1FVGKAT07PRE8RF', 'anastasia.al-balushi134@example.com', 'anastasia.al-balushi134@example.com', '2025-07-11 10:00:00', '44', '664341503', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-07-11 09:00:00', 'active', 'Anastasia', 'Al Balushi', 'Anastasia Al Balushi', 'https://cdn.livfinder.com/avatars/agent-134.jpg', 1, 6, 'sqft', 'Europe/London', 1194, 1102874, '2026-08-01 09:00:00', '2026-08-11 14:00:00', 122, 0, 0, '2025-07-11 09:00:00', '2025-07-11 09:00:00'),
(135, '01K2F2DKG0ZS548V23K5XNZGCC', 'theo.bin-ahmed135@example.com', 'theo.bin-ahmed135@example.com', '2025-09-17 10:00:00', '44', '631196995', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-09-17 09:00:00', 'active', 'Theo', 'Bin Ahmed', 'Theo Bin Ahmed', 'https://cdn.livfinder.com/avatars/agent-135.jpg', 1, 2, 'sqm', 'Europe/London', 1227, 1900003, '2026-08-14 09:00:00', '2026-08-13 23:00:00', 287, 1, 0, '2025-09-17 09:00:00', '2025-09-17 09:00:00'),
(136, '01K2F2DKG0M73K7S6R7KAX8P78', 'olivia.haddad136@example.com', 'olivia.haddad136@example.com', '2024-11-27 10:00:00', '44', '794615372', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-27 09:00:00', 'active', 'Olivia', 'Haddad', 'Olivia Haddad', 'https://cdn.livfinder.com/avatars/agent-136.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1040512, '2026-08-05 09:00:00', '2026-08-02 20:00:00', 8, 0, 1, '2024-11-27 09:00:00', '2024-11-27 09:00:00'),
(137, '01K2F2DKG0DJ2BCDMDSKCPNQFT', 'emma.laurent137@example.com', 'emma.laurent137@example.com', '2024-06-15 10:00:00', '44', '724835310', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-06-15 09:00:00', 'active', 'Emma', 'Laurent', 'Emma Laurent', 'https://cdn.livfinder.com/avatars/agent-137.jpg', 1, 13, 'sqm', 'Europe/London', 1014, 1007408, '2026-08-16 09:00:00', '2026-08-06 15:00:00', 40, 0, 1, '2024-06-15 09:00:00', '2024-06-15 09:00:00'),
(138, '01K2F2DKG09X7HRX60YH3FKJWA', 'camille.dubois138@example.com', 'camille.dubois138@example.com', '2023-09-30 10:00:00', '971', '741124218', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-09-30 09:00:00', 'active', 'Camille', 'Dubois', 'Camille Dubois', 'https://cdn.livfinder.com/avatars/agent-138.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-08 09:00:00', '2026-08-16 01:00:00', 249, 0, 1, '2023-09-30 09:00:00', '2023-09-30 09:00:00'),
(139, '01K2F2DKG0K6V38STP6KY30N7K', 'youssef.tanaka139@example.com', 'youssef.tanaka139@example.com', '2023-11-24 10:00:00', '44', '509309106', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-11-24 09:00:00', 'active', 'Youssef', 'Tanaka', 'Youssef Tanaka', 'https://cdn.livfinder.com/avatars/agent-139.jpg', 1, 6, 'sqft', 'Europe/London', 1194, 1102858, '2026-08-16 09:00:00', '2026-08-17 05:00:00', 132, 0, 0, '2023-11-24 09:00:00', '2023-11-24 09:00:00'),
(140, '01K2F2DKG0GHFWCKE6E44GAP24', 'julien.meyer140@example.com', 'julien.meyer140@example.com', '2024-09-06 10:00:00', '971', '631899577', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-06 09:00:00', 'active', 'Julien', 'Meyer', 'Julien Meyer', 'https://cdn.livfinder.com/avatars/agent-140.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-08-06 09:00:00', '2026-08-01 13:00:00', 38, 0, 1, '2024-09-06 09:00:00', '2024-09-06 09:00:00'),
(141, '01K2F2DKG0GNCWCR0P57QQF235', 'camille.haddad141@example.com', 'camille.haddad141@example.com', '2023-10-23 10:00:00', '44', '777190704', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-10-23 09:00:00', 'active', 'Camille', 'Haddad', 'Camille Haddad', 'https://cdn.livfinder.com/avatars/agent-141.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-08-12 09:00:00', '2026-08-05 23:00:00', 147, 0, 1, '2023-10-23 09:00:00', '2023-10-23 09:00:00'),
(142, '01K2F2DKG0JV8D041CFX08ACG7', 'ingrid.petrova142@example.com', 'ingrid.petrova142@example.com', '2025-01-27 10:00:00', '44', '599421239', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-27 09:00:00', 'active', 'Ingrid', 'Petrova', 'Ingrid Petrova', 'https://cdn.livfinder.com/avatars/agent-142.jpg', 1, 19, 'sqm', 'Europe/London', 1204, 1131059, '2026-08-10 09:00:00', '2026-08-08 18:00:00', 59, 0, 1, '2025-01-27 09:00:00', '2025-01-27 09:00:00'),
(143, '01K2F2DKG0FSTMH32EJ3C5R09X', 'daniel.lindqvist143@example.com', 'daniel.lindqvist143@example.com', '2025-04-09 10:00:00', '44', '739201979', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-09 09:00:00', 'active', 'Daniel', 'Lindqvist', 'Daniel Lindqvist', 'https://cdn.livfinder.com/avatars/agent-143.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-08-05 09:00:00', '2026-08-08 15:00:00', 241, 0, 1, '2025-04-09 09:00:00', '2025-04-09 09:00:00'),
(144, '01K2F2DKG0ARNFW3HVEMAKY6CV', 'rafael.sharma144@example.com', 'rafael.sharma144@example.com', '2024-01-18 10:00:00', '44', '709921859', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-01-18 09:00:00', 'active', 'Rafael', 'Sharma', 'Rafael Sharma', 'https://cdn.livfinder.com/avatars/agent-144.jpg', 1, 14, 'sqm', 'Europe/London', 1039, 1017121, '2026-08-10 09:00:00', '2026-08-04 11:00:00', 378, 0, 1, '2024-01-18 09:00:00', '2024-01-18 09:00:00'),
(145, '01K2F2DKG02Z7E6J985X76J83G', 'antoine.aziz145@example.com', 'antoine.aziz145@example.com', '2025-03-06 10:00:00', '44', '754711522', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-06 09:00:00', 'active', 'Antoine', 'Aziz', 'Antoine Aziz', 'https://cdn.livfinder.com/avatars/agent-145.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1046589, '2026-08-07 09:00:00', '2026-08-11 06:00:00', 382, 1, 0, '2025-03-06 09:00:00', '2025-03-06 09:00:00'),
(146, '01K2F2DKG0PW134BB8JANYW394', 'julien.petrova146@example.com', 'julien.petrova146@example.com', '2024-12-13 10:00:00', '44', '575676571', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-12-13 09:00:00', 'active', 'Julien', 'Petrova', 'Julien Petrova', 'https://cdn.livfinder.com/avatars/agent-146.jpg', 1, 6, 'sqft', 'Europe/London', 1194, 1102874, '2026-07-29 09:00:00', '2026-08-02 18:00:00', 144, 0, 1, '2024-12-13 09:00:00', '2024-12-13 09:00:00'),
(147, '01K2F2DKG0H4R3R3NZG1T1CNJ1', 'leila.al-suwaidi147@example.com', 'leila.al-suwaidi147@example.com', '2024-09-11 10:00:00', '44', '705667154', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-11 09:00:00', 'active', 'Leila', 'Al Suwaidi', 'Leila Al Suwaidi', 'https://cdn.livfinder.com/avatars/agent-147.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-08-01 09:00:00', '2026-08-01 07:00:00', 115, 0, 1, '2024-09-11 09:00:00', '2024-09-11 09:00:00'),
(148, '01K2F2DKG07SAWNGJ5X31FEY3Z', 'rania.rahman148@example.com', 'rania.rahman148@example.com', '2024-03-27 10:00:00', '44', '705618339', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-03-27 09:00:00', 'active', 'Rania', 'Rahman', 'Rania Rahman', 'https://cdn.livfinder.com/avatars/agent-148.jpg', 1, 12, 'sqm', 'Europe/London', 1098, 1900005, '2026-07-30 09:00:00', '2026-08-03 20:00:00', 117, 0, 0, '2024-03-27 09:00:00', '2024-03-27 09:00:00'),
(149, '01K2F2DKG0M9SGY9GSPWDZK6P3', 'sarah.khoury149@example.com', 'sarah.khoury149@example.com', '2025-10-22 10:00:00', '44', '640551027', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-22 09:00:00', 'active', 'Sarah', 'Khoury', 'Sarah Khoury', 'https://cdn.livfinder.com/avatars/agent-149.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1035186, '2026-08-12 09:00:00', '2026-08-11 07:00:00', 81, 0, 1, '2025-10-22 09:00:00', '2025-10-22 09:00:00'),
(150, '01K2F2DKG00DK8B5M3CEH7PNRS', 'theo.petrova150@example.com', 'theo.petrova150@example.com', '2024-09-21 10:00:00', '44', '799874254', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-21 09:00:00', 'active', 'Theo', 'Petrova', 'Theo Petrova', 'https://cdn.livfinder.com/avatars/agent-150.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1034729, '2026-08-07 09:00:00', '2026-08-05 20:00:00', 208, 1, 1, '2024-09-21 09:00:00', '2024-09-21 09:00:00'),
(151, '01K2F2DKG0VFX785X5YJG9WKGV', 'rania.karim151@example.com', 'rania.karim151@example.com', '2026-05-23 10:00:00', '971', '589401636', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-23 09:00:00', 'active', 'Rania', 'Karim', 'Rania Karim', 'https://cdn.livfinder.com/avatars/agent-151.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-07 09:00:00', '2026-08-17 00:00:00', 16, 0, 0, '2026-05-23 09:00:00', '2026-05-23 09:00:00'),
(152, '01K2F2DKG0Y3H8QG9BVTSYE5MV', 'priya.moreau152@example.com', 'priya.moreau152@example.com', '2025-05-26 10:00:00', '44', '504423083', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-26 09:00:00', 'active', 'Priya', 'Moreau', 'Priya Moreau', 'https://cdn.livfinder.com/avatars/agent-152.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-08-01 09:00:00', '2026-08-06 21:00:00', 34, 1, 0, '2025-05-26 09:00:00', '2025-05-26 09:00:00'),
(153, '01K2F2DKG0C1Q87C3SDD43MF8M', 'zainab.aziz153@example.com', 'zainab.aziz153@example.com', '2026-01-06 10:00:00', '44', '719055329', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-06 09:00:00', 'active', 'Zainab', 'Aziz', 'Zainab Aziz', 'https://cdn.livfinder.com/avatars/agent-153.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1044856, '2026-08-10 09:00:00', '2026-08-06 16:00:00', 214, 0, 1, '2026-01-06 09:00:00', '2026-01-06 09:00:00'),
(154, '01K2F2DKG0R6WE3DJ12VWN9CX0', 'valentina.al-balushi154@example.com', 'valentina.al-balushi154@example.com', '2025-04-10 10:00:00', '44', '527261946', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-10 09:00:00', 'active', 'Valentina', 'Al Balushi', 'Valentina Al Balushi', 'https://cdn.livfinder.com/avatars/agent-154.jpg', 1, 6, 'sqft', 'Europe/London', 1194, 1102858, '2026-08-08 09:00:00', '2026-08-14 04:00:00', 178, 0, 1, '2025-04-10 09:00:00', '2025-04-10 09:00:00'),
(155, '01K2F2DKG0BN40N9CYBXJ6QZQV', 'hana.volkov155@example.com', 'hana.volkov155@example.com', '2026-01-26 10:00:00', '44', '750745046', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-26 09:00:00', 'active', 'Hana', 'Volkov', 'Hana Volkov', 'https://cdn.livfinder.com/avatars/agent-155.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1059582, '2026-07-29 09:00:00', '2026-08-16 20:00:00', 244, 0, 0, '2026-01-26 09:00:00', '2026-01-26 09:00:00'),
(156, '01K2F2DKG03M91HJ2GD0E8T2AQ', 'julien.sato156@example.com', 'julien.sato156@example.com', '2025-06-27 10:00:00', '971', '613986840', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-27 09:00:00', 'active', 'Julien', 'Sato', 'Julien Sato', 'https://cdn.livfinder.com/avatars/agent-156.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-07 09:00:00', '2026-08-04 09:00:00', 41, 0, 0, '2025-06-27 09:00:00', '2025-06-27 09:00:00'),
(157, '01K2F2DKG09GTFSAST0ESQK97M', 'daniel.al-suwaidi157@example.com', 'daniel.al-suwaidi157@example.com', '2024-10-01 10:00:00', '44', '520113408', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-01 09:00:00', 'active', 'Daniel', 'Al Suwaidi', 'Daniel Al Suwaidi', 'https://cdn.livfinder.com/avatars/agent-157.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089245, '2026-08-14 09:00:00', '2026-08-12 13:00:00', 293, 1, 0, '2024-10-01 09:00:00', '2024-10-01 09:00:00'),
(158, '01K2F2DKG088J3NBRD36CY7WY7', 'antoine.hussein158@example.com', 'antoine.hussein158@example.com', '2023-12-04 10:00:00', '44', '677854327', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-12-04 09:00:00', 'active', 'Antoine', 'Hussein', 'Antoine Hussein', 'https://cdn.livfinder.com/avatars/agent-158.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-08-14 09:00:00', '2026-08-07 15:00:00', 286, 0, 0, '2023-12-04 09:00:00', '2023-12-04 09:00:00'),
(159, '01K2F2DKG0M4EAKP6QM347N42Y', 'charlotte.moretti159@example.com', 'charlotte.moretti159@example.com', '2026-05-04 10:00:00', '44', '532700582', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-04 09:00:00', 'active', 'Charlotte', 'Moretti', 'Charlotte Moretti', 'https://cdn.livfinder.com/avatars/agent-159.jpg', 1, 21, 'sqm', 'Europe/London', 1142, 1068704, '2026-08-01 09:00:00', '2026-08-02 16:00:00', 333, 1, 0, '2026-05-04 09:00:00', '2026-05-04 09:00:00'),
(160, '01K2F2DKG0AEJESZT23Y5K20BW', 'anastasia.ferrari160@example.com', 'anastasia.ferrari160@example.com', '2023-08-20 10:00:00', '44', '671990935', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-08-20 09:00:00', 'active', 'Anastasia', 'Ferrari', 'Anastasia Ferrari', 'https://cdn.livfinder.com/avatars/agent-160.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1044856, '2026-07-28 09:00:00', '2026-08-12 21:00:00', 313, 0, 1, '2023-08-20 09:00:00', '2023-08-20 09:00:00'),
(161, '01K2F2DKG0TQZEKW4HMG0ESM2C', 'mohammed.meyer161@example.com', 'mohammed.meyer161@example.com', '2024-06-15 10:00:00', '971', '563434785', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-06-15 09:00:00', 'active', 'Mohammed', 'Meyer', 'Mohammed Meyer', 'https://cdn.livfinder.com/avatars/agent-161.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-11 09:00:00', '2026-08-15 16:00:00', 56, 1, 0, '2024-06-15 09:00:00', '2024-06-15 09:00:00'),
(162, '01K2F2DKG08RRXG6G4ZCJHWN1F', 'nadia.dubois162@example.com', 'nadia.dubois162@example.com', '2024-11-14 10:00:00', '44', '688187839', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-14 09:00:00', 'active', 'Nadia', 'Dubois', 'Nadia Dubois', 'https://cdn.livfinder.com/avatars/agent-162.jpg', 1, 18, 'sqm', 'Europe/London', 1225, 1153786, '2026-08-10 09:00:00', '2026-08-16 17:00:00', 68, 0, 0, '2024-11-14 09:00:00', '2024-11-14 09:00:00'),
(163, '01K2F2DKG0HM6X51Y9ZF782N3S', 'diego.von-habsburg163@example.com', 'diego.von-habsburg163@example.com', '2025-08-22 10:00:00', '44', '713716231', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-08-22 09:00:00', 'active', 'Diego', 'Von Habsburg', 'Diego Von Habsburg', 'https://cdn.livfinder.com/avatars/agent-163.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1035186, '2026-08-09 09:00:00', '2026-08-07 23:00:00', 13, 1, 1, '2025-08-22 09:00:00', '2025-08-22 09:00:00'),
(164, '01K2F2DKG0ZR1WX664ZXQ90SEQ', 'valentina.dubois164@example.com', 'valentina.dubois164@example.com', '2024-06-11 10:00:00', '44', '558642602', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-06-11 09:00:00', 'active', 'Valentina', 'Dubois', 'Valentina Dubois', 'https://cdn.livfinder.com/avatars/agent-164.jpg', 1, 2, 'sqm', 'Europe/London', 1011, 1900004, '2026-08-04 09:00:00', '2026-08-07 10:00:00', 73, 0, 1, '2024-06-11 09:00:00', '2024-06-11 09:00:00'),
(165, '01K2F2DKG05TAZ3X38ZSFRG2FK', 'nikolai.laurent165@example.com', 'nikolai.laurent165@example.com', '2025-12-20 10:00:00', '44', '747947613', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-20 09:00:00', 'active', 'Nikolai', 'Laurent', 'Nikolai Laurent', 'https://cdn.livfinder.com/avatars/agent-165.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1034729, '2026-08-03 09:00:00', '2026-08-13 17:00:00', 285, 0, 1, '2025-12-20 09:00:00', '2025-12-20 09:00:00'),
(166, '01K2F2DKG07W5PKW5VAE3R9M0N', 'marco.el-sayed166@example.com', 'marco.el-sayed166@example.com', '2024-02-06 10:00:00', '44', '540759618', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-02-06 09:00:00', 'active', 'Marco', 'El Sayed', 'Marco El Sayed', 'https://cdn.livfinder.com/avatars/agent-166.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-08-07 09:00:00', '2026-08-10 23:00:00', 337, 0, 0, '2024-02-06 09:00:00', '2024-02-06 09:00:00'),
(167, '01K2F2DKG034V8WR9DDF8E6MR6', 'mohammed.al-balushi167@example.com', 'mohammed.al-balushi167@example.com', '2025-05-26 10:00:00', '971', '768432227', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-26 09:00:00', 'active', 'Mohammed', 'Al Balushi', 'Mohammed Al Balushi', 'https://cdn.livfinder.com/avatars/agent-167.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-08-13 09:00:00', '2026-08-13 15:00:00', 169, 0, 0, '2025-05-26 09:00:00', '2025-05-26 09:00:00'),
(168, '01K2F2DKG0GV3NEVTRXA5WNVES', 'farah.khoury168@example.com', 'farah.khoury168@example.com', '2026-07-06 10:00:00', '44', '730223576', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-06 09:00:00', 'active', 'Farah', 'Khoury', 'Farah Khoury', 'https://cdn.livfinder.com/avatars/agent-168.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1035186, '2026-08-15 09:00:00', '2026-08-05 21:00:00', 387, 0, 1, '2026-07-06 09:00:00', '2026-07-06 09:00:00'),
(169, '01K2F2DKG0QTDN7Q7VR66KGRYA', 'henry.fairfax169@example.com', 'henry.fairfax169@example.com', '2024-04-15 10:00:00', '44', '752699648', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-04-15 09:00:00', 'active', 'Henry', 'Fairfax', 'Henry Fairfax', 'https://cdn.livfinder.com/avatars/agent-169.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-08-12 09:00:00', '2026-08-02 02:00:00', 313, 0, 0, '2024-04-15 09:00:00', '2024-04-15 09:00:00'),
(170, '01K2F2DKG02TRZD8TJA9EX6TKF', 'aisha.rossellini170@example.com', 'aisha.rossellini170@example.com', '2023-09-29 10:00:00', '44', '662856540', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-09-29 09:00:00', 'active', 'Aisha', 'Rossellini', 'Aisha Rossellini', 'https://cdn.livfinder.com/avatars/agent-170.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-08-12 09:00:00', '2026-08-04 13:00:00', 230, 0, 1, '2023-09-29 09:00:00', '2023-09-29 09:00:00'),
(171, '01K2F2DKG0J12H3A6NKR91RKQQ', 'rafael.ferrari171@example.com', 'rafael.ferrari171@example.com', '2024-04-09 10:00:00', '971', '569165813', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-04-09 09:00:00', 'active', 'Rafael', 'Ferrari', 'Rafael Ferrari', 'https://cdn.livfinder.com/avatars/agent-171.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-04 09:00:00', '2026-08-04 20:00:00', 381, 0, 0, '2024-04-09 09:00:00', '2024-04-09 09:00:00'),
(172, '01K2F2DKG0VYQS72KVR4Y0NP9W', 'hana.mercer172@example.com', 'hana.mercer172@example.com', '2023-10-30 10:00:00', '44', '543031180', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2023-10-30 09:00:00', 'active', 'Hana', 'Mercer', 'Hana Mercer', 'https://cdn.livfinder.com/avatars/agent-172.jpg', 1, 7, 'sqft', 'Europe/London', 1179, 1089864, '2026-07-29 09:00:00', '2026-08-09 14:00:00', 130, 0, 0, '2023-10-30 09:00:00', '2023-10-30 09:00:00'),
(173, '01K2F2DKG09G3SVSADBDZYNXES', 'vikram.rossellini173@example.com', 'vikram.rossellini173@example.com', '2025-12-30 10:00:00', '44', '602358912', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-30 09:00:00', 'active', 'Vikram', 'Rossellini', 'Vikram Rossellini', 'https://cdn.livfinder.com/avatars/agent-173.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-08-09 09:00:00', '2026-08-05 13:00:00', 166, 0, 1, '2025-12-30 09:00:00', '2025-12-30 09:00:00'),
(174, '01K2F2DKG0SRXH1Y16ZT5FAQ6A', 'arjun.meyer174@example.com', 'arjun.meyer174@example.com', '2025-09-13 10:00:00', '44', '573943032', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-09-13 09:00:00', 'active', 'Arjun', 'Meyer', 'Arjun Meyer', 'https://cdn.livfinder.com/avatars/agent-174.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-08-12 09:00:00', '2026-08-11 23:00:00', 78, 0, 1, '2025-09-13 09:00:00', '2025-09-13 09:00:00'),
(175, '01K2F2DKG0GPREW31B1WW3DD8E', 'vikram.wong175@example.com', 'vikram.wong175@example.com', '2025-11-20 10:00:00', '44', '721200384', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-20 09:00:00', 'active', 'Vikram', 'Wong', 'Vikram Wong', 'https://cdn.livfinder.com/avatars/agent-175.jpg', 1, 14, 'sqm', 'Europe/London', 1039, 1017121, '2026-08-06 09:00:00', '2026-08-02 17:00:00', 304, 0, 1, '2025-11-20 09:00:00', '2025-11-20 09:00:00'),
(176, '01K2F2DKG00TBT54ZB8B4YW62X', 'julien.ivanov176@example.com', 'julien.ivanov176@example.com', '2025-10-30 10:00:00', '44', '676167094', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-30 09:00:00', 'active', 'Julien', 'Ivanov', 'Julien Ivanov', 'https://cdn.livfinder.com/avatars/agent-176.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-08-17 09:00:00', '2026-08-16 17:00:00', 82, 0, 0, '2025-10-30 09:00:00', '2025-10-30 09:00:00'),
(177, '01K2F2DKG03ZPWPYFRZSBQSTJ1', 'vikram.al-balushi177@example.com', 'vikram.al-balushi177@example.com', '2026-05-26 10:00:00', '44', '696263818', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-26 09:00:00', 'active', 'Vikram', 'Al Balushi', 'Vikram Al Balushi', 'https://cdn.livfinder.com/avatars/agent-177.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1035281, '2026-08-13 09:00:00', '2026-08-15 01:00:00', 222, 1, 0, '2026-05-26 09:00:00', '2026-05-26 09:00:00'),
(178, '01K2F2DKG0KPMMNW614ZDRTH1Y', 'omar.clarke178@example.com', 'omar.clarke178@example.com', '2026-06-09 10:00:00', '44', '629290208', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-06-09 09:00:00', 'active', 'Omar', 'Clarke', 'Omar Clarke', 'https://cdn.livfinder.com/avatars/agent-178.jpg', 1, 2, 'sqm', 'Europe/London', 1011, 1900004, '2026-08-07 09:00:00', '2026-08-16 00:00:00', 186, 0, 1, '2026-06-09 09:00:00', '2026-06-09 09:00:00'),
(179, '01K2F2DKG0SZYQ1C746G3F8QC3', 'chen.khoury179@example.com', 'chen.khoury179@example.com', '2024-07-08 12:00:00', '44', '710956561', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-07-08 09:00:00', 'active', 'Chen', 'Khoury', 'Chen Khoury', 'https://cdn.livfinder.com/avatars/user-179.jpg', 2, 2, 'sqm', 'Europe/London', 1102, 1056263, '2026-08-08 09:00:00', '2026-05-08 09:00:00', 50, 0, 0, '2024-07-08 09:00:00', '2024-07-08 09:00:00'),
(180, '01K2F2DKG0H9GE6500JCBTS8W5', 'julien.rahman180@example.com', 'julien.rahman180@example.com', '2025-02-12 12:00:00', '971', '587212292', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-12 09:00:00', 'active', 'Julien', 'Rahman', 'Julien Rahman', 'https://cdn.livfinder.com/avatars/user-180.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-05-16 09:00:00', '2026-06-14 09:00:00', 50, 0, 1, '2025-02-12 09:00:00', '2025-02-12 09:00:00'),
(181, '01K2F2DKG058RN7MX8P7E8HK01', 'mariam.bin-ahmed181@example.com', 'mariam.bin-ahmed181@example.com', '2025-10-17 12:00:00', '971', '795880593', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-17 09:00:00', 'suspended', 'Mariam', 'Bin Ahmed', 'Mariam Bin Ahmed', 'https://cdn.livfinder.com/avatars/user-181.jpg', 8, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, NULL, NULL, 32, 0, 1, '2025-10-17 09:00:00', '2025-10-17 09:00:00'),
(182, '01K2F2DKG064QC3332J4NS0YDR', 'mohammed.al-otaiba182@example.com', 'mohammed.al-otaiba182@example.com', '2026-03-07 12:00:00', '971', '500084485', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-07 09:00:00', 'active', 'Mohammed', 'Al Otaiba', 'Mohammed Al Otaiba', 'https://cdn.livfinder.com/avatars/user-182.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-05-31 09:00:00', '2026-05-04 09:00:00', 20, 0, 1, '2026-03-07 09:00:00', '2026-03-07 09:00:00'),
(183, '01K2F2DKG07ZA784S4WGQPS1Z6', 'daniel.al-mansouri183@example.com', 'daniel.al-mansouri183@example.com', '2026-04-28 12:00:00', '44', '686130065', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-28 09:00:00', 'active', 'Daniel', 'Al Mansouri', 'Daniel Al Mansouri', 'https://cdn.livfinder.com/avatars/user-183.jpg', 9, 3, 'sqm', 'Europe/London', 1177, 1089101, '2026-08-05 09:00:00', '2026-05-28 09:00:00', 43, 0, 1, '2026-04-28 09:00:00', '2026-04-28 09:00:00'),
(184, '01K2F2DKG0NBV8SCQTSZKSBK6R', 'khalid.whitfield184@example.com', 'khalid.whitfield184@example.com', '2025-04-15 12:00:00', '44', '624305947', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-15 09:00:00', 'active', 'Khalid', 'Whitfield', 'Khalid Whitfield', 'https://cdn.livfinder.com/avatars/user-184.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-08-11 09:00:00', '2026-08-07 09:00:00', 1, 0, 0, '2025-04-15 09:00:00', '2025-04-15 09:00:00'),
(185, '01K2F2DKG0HJTY9V4Z8NC7XGAH', 'youssef.al-farsi185@example.com', 'youssef.al-farsi185@example.com', '2026-03-22 12:00:00', '971', '721680437', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-22 09:00:00', 'active', 'Youssef', 'Al Farsi', 'Youssef Al Farsi', 'https://cdn.livfinder.com/avatars/user-185.jpg', 3, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-05-06 09:00:00', '2026-05-02 09:00:00', 15, 0, 1, '2026-03-22 09:00:00', '2026-03-22 09:00:00'),
(186, '01K2F2DKG0B4PRHSFTNHQZSD3D', 'youssef.al-mansouri186@example.com', 'youssef.al-mansouri186@example.com', '2026-02-18 12:00:00', '971', '723000340', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-02-18 09:00:00', 'active', 'Youssef', 'Al Mansouri', 'Youssef Al Mansouri', 'https://cdn.livfinder.com/avatars/user-186.jpg', 9, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-05-30 09:00:00', '2026-06-28 09:00:00', 8, 0, 1, '2026-02-18 09:00:00', '2026-02-18 09:00:00'),
(187, '01K2F2DKG0PER5AA0BYSPB5YCN', 'khalid.sharma187@example.com', 'khalid.sharma187@example.com', '2026-06-21 12:00:00', '44', '655453408', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-06-21 09:00:00', 'active', 'Khalid', 'Sharma', 'Khalid Sharma', 'https://cdn.livfinder.com/avatars/user-187.jpg', 3, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-05-03 09:00:00', '2026-04-23 09:00:00', 8, 0, 1, '2026-06-21 09:00:00', '2026-06-21 09:00:00'),
(188, '01K2F2DKG0H9M89QJ5WVHBFG7K', 'james.kapoor188@example.com', 'james.kapoor188@example.com', '2025-03-27 12:00:00', '971', '745297626', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-27 09:00:00', 'active', 'James', 'Kapoor', 'James Kapoor', 'https://cdn.livfinder.com/avatars/user-188.jpg', 2, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-05-13 09:00:00', '2026-05-03 09:00:00', 10, 0, 1, '2025-03-27 09:00:00', '2025-03-27 09:00:00'),
(189, '01K2F2DKG0EN2RHSSY71T13X2Z', 'lucas.meyer189@example.com', 'lucas.meyer189@example.com', '2026-07-23 12:00:00', '44', '540803305', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-23 09:00:00', 'active', 'Lucas', 'Meyer', 'Lucas Meyer', 'https://cdn.livfinder.com/avatars/user-189.jpg', 9, 3, 'sqm', 'Europe/London', 1085, 1052950, '2026-07-20 09:00:00', '2026-08-03 09:00:00', 37, 0, 1, '2026-07-23 09:00:00', '2026-07-23 09:00:00'),
(190, '01K2F2DKG0V9P6RV1GF6RF98H7', 'charlotte.marchetti190@example.com', 'charlotte.marchetti190@example.com', '2024-10-21 12:00:00', '44', '547033773', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-21 09:00:00', 'active', 'Charlotte', 'Marchetti', 'Charlotte Marchetti', 'https://cdn.livfinder.com/avatars/user-190.jpg', 3, 2, 'sqft', 'Europe/London', 1233, 1122795, '2026-07-21 09:00:00', '2026-07-29 09:00:00', 31, 0, 1, '2024-10-21 09:00:00', '2024-10-21 09:00:00'),
(191, '01K2F2DKG04TXRXGJPK1ZKXF4W', 'rashid.sato191@example.com', 'rashid.sato191@example.com', NULL, '971', '704381867', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-12-13 09:00:00', 'pending_verification', 'Rashid', 'Sato', 'Rashid Sato', 'https://cdn.livfinder.com/avatars/user-191.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, NULL, NULL, 10, 0, 1, NULL, '2024-12-13 09:00:00'),
(192, '01K2F2DKG0Z7CSNW0PDMBT2TRB', 'mariam.al-mansouri192@example.com', 'mariam.al-mansouri192@example.com', '2024-11-12 12:00:00', '44', '617760685', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-12 09:00:00', 'active', 'Mariam', 'Al Mansouri', 'Mariam Al Mansouri', 'https://cdn.livfinder.com/avatars/user-192.jpg', 2, 13, 'sqm', 'Europe/London', 1014, 1007408, '2026-05-21 09:00:00', '2026-07-07 09:00:00', 38, 0, 1, '2024-11-12 09:00:00', '2024-11-12 09:00:00'),
(193, '01K2F2DKG0X9DGRGMWE5CGFKWY', 'hassan.mercer193@example.com', 'hassan.mercer193@example.com', '2025-01-27 12:00:00', '44', '634698725', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-27 09:00:00', 'active', 'Hassan', 'Mercer', 'Hassan Mercer', 'https://cdn.livfinder.com/avatars/user-193.jpg', 9, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-06-02 09:00:00', '2026-05-24 09:00:00', 56, 0, 1, '2025-01-27 09:00:00', '2025-01-27 09:00:00'),
(194, '01K2F2DKG0YYMYWFGBH4Z41CB4', 'nadia.clarke194@example.com', 'nadia.clarke194@example.com', '2024-11-21 12:00:00', '971', '789282632', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-21 09:00:00', 'active', 'Nadia', 'Clarke', 'Nadia Clarke', 'https://cdn.livfinder.com/avatars/user-194.jpg', 2, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-28 09:00:00', '2026-04-28 09:00:00', 14, 0, 0, '2024-11-21 09:00:00', '2024-11-21 09:00:00'),
(195, '01K2F2DKG01507J0CEK67Q47HJ', 'ingrid.kapoor195@example.com', 'ingrid.kapoor195@example.com', '2024-06-29 12:00:00', '971', '722266373', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-06-29 09:00:00', 'active', 'Ingrid', 'Kapoor', 'Ingrid Kapoor', 'https://cdn.livfinder.com/avatars/user-195.jpg', 9, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-05-24 09:00:00', '2026-04-21 09:00:00', 36, 0, 0, '2024-06-29 09:00:00', '2024-06-29 09:00:00'),
(196, '01K2F2DKG03H9A0GXG03WEK2X6', 'leila.bakr196@example.com', 'leila.bakr196@example.com', '2025-05-18 12:00:00', '971', '740568624', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-18 09:00:00', 'active', 'Leila', 'Bakr', 'Leila Bakr', 'https://cdn.livfinder.com/avatars/user-196.jpg', 3, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-06-13 09:00:00', '2026-06-10 09:00:00', 40, 0, 1, '2025-05-18 09:00:00', '2025-05-18 09:00:00'),
(197, '01K2F2DKG0AY9C6RFG04WRCDX9', 'rania.al-mansouri197@example.com', 'rania.al-mansouri197@example.com', '2024-09-06 12:00:00', '44', '687634425', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-06 09:00:00', 'active', 'Rania', 'Al Mansouri', 'Rania Al Mansouri', 'https://cdn.livfinder.com/avatars/user-197.jpg', 8, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-05-15 09:00:00', '2026-05-20 09:00:00', 19, 0, 1, '2024-09-06 09:00:00', '2024-09-06 09:00:00'),
(198, '01K2F2DKG0WZYFNDEZSW5BHZG0', 'lucas.al-otaiba198@example.com', 'lucas.al-otaiba198@example.com', '2025-01-15 12:00:00', '44', '525536747', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-15 09:00:00', 'active', 'Lucas', 'Al Otaiba', 'Lucas Al Otaiba', 'https://cdn.livfinder.com/avatars/user-198.jpg', 8, 6, 'sqm', 'Europe/London', 1194, 1102858, '2026-08-17 09:00:00', '2026-05-13 09:00:00', 25, 0, 1, '2025-01-15 09:00:00', '2025-01-15 09:00:00'),
(199, '01K2F2DKG06W0P96SGMM4HMF03', 'fatima.al-balushi199@example.com', 'fatima.al-balushi199@example.com', '2025-12-21 12:00:00', '44', '520151721', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-21 09:00:00', 'active', 'Fatima', 'Al Balushi', 'Fatima Al Balushi', 'https://cdn.livfinder.com/avatars/user-199.jpg', 3, 19, 'sqm', 'Europe/London', 1204, 1131059, '2026-05-11 09:00:00', '2026-08-06 09:00:00', 20, 0, 0, '2025-12-21 09:00:00', '2025-12-21 09:00:00'),
(200, '01K2F2DKG0SS7BSKDH3JJPGNW2', 'emma.haddad200@example.com', 'emma.haddad200@example.com', '2025-06-06 12:00:00', '44', '735924189', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-06 09:00:00', 'active', 'Emma', 'Haddad', 'Emma Haddad', 'https://cdn.livfinder.com/avatars/user-200.jpg', 9, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-06-22 09:00:00', '2026-08-08 09:00:00', 29, 0, 1, '2025-06-06 09:00:00', '2025-06-06 09:00:00'),
(201, '01K2F2DKG05EDQYMJPJVSJEPDK', 'fatima.beaumont201@example.com', 'fatima.beaumont201@example.com', '2024-07-20 12:00:00', '44', '571716389', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-07-20 09:00:00', 'active', 'Fatima', 'Beaumont', 'Fatima Beaumont', 'https://cdn.livfinder.com/avatars/user-201.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1044856, '2026-05-25 09:00:00', '2026-06-14 09:00:00', 34, 0, 1, '2024-07-20 09:00:00', '2024-07-20 09:00:00'),
(202, '01K2F2DKG0SXA5NKTRXR5T1SH5', 'zainab.al-mansouri202@example.com', 'zainab.al-mansouri202@example.com', '2024-09-07 12:00:00', '971', '630962393', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-07 09:00:00', 'closed', 'Zainab', 'Al Mansouri', 'Zainab Al Mansouri', 'https://cdn.livfinder.com/avatars/user-202.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, NULL, NULL, 47, 0, 1, '2024-09-07 09:00:00', '2024-09-07 09:00:00'),
(203, '01K2F2DKG04Q9HRTCYAC960XMY', 'hana.laurent203@example.com', 'hana.laurent203@example.com', '2024-09-20 12:00:00', '44', '691130778', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-20 09:00:00', 'active', 'Hana', 'Laurent', 'Hana Laurent', 'https://cdn.livfinder.com/avatars/user-203.jpg', 2, 19, 'sqm', 'Europe/London', 1204, 1131059, '2026-05-01 09:00:00', '2026-06-12 09:00:00', 54, 0, 1, '2024-09-20 09:00:00', '2024-09-20 09:00:00'),
(204, '01K2F2DKG0ZWMX6NFAWND5TND8', 'hana.el-sayed204@example.com', 'hana.el-sayed204@example.com', '2026-08-03 12:00:00', '44', '714946316', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-08-03 09:00:00', 'active', 'Hana', 'El Sayed', 'Hana El Sayed', 'https://cdn.livfinder.com/avatars/user-204.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-05-21 09:00:00', '2026-05-08 09:00:00', 4, 0, 0, '2026-08-03 09:00:00', '2026-08-03 09:00:00'),
(205, '01K2F2DKG053JJEZFG7X72FARZ', 'aisha.moretti205@example.com', 'aisha.moretti205@example.com', '2025-07-27 12:00:00', '44', '759801230', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-07-27 09:00:00', 'active', 'Aisha', 'Moretti', 'Aisha Moretti', 'https://cdn.livfinder.com/avatars/user-205.jpg', 8, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-07-31 09:00:00', '2026-08-07 09:00:00', 46, 0, 0, '2025-07-27 09:00:00', '2025-07-27 09:00:00'),
(206, '01K2F2DKG0ZTR65PTN80EAK2DR', 'hassan.volkov206@example.com', 'hassan.volkov206@example.com', '2026-02-23 12:00:00', '44', '517315815', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-02-23 09:00:00', 'active', 'Hassan', 'Volkov', 'Hassan Volkov', 'https://cdn.livfinder.com/avatars/user-206.jpg', 1, 2, 'sqm', 'Europe/London', 1102, 1056263, '2026-08-08 09:00:00', '2026-07-08 09:00:00', 40, 0, 1, '2026-02-23 09:00:00', '2026-02-23 09:00:00'),
(207, '01K2F2DKG05TPHFK0PJQY9Y82R', 'arjun.clarke207@example.com', 'arjun.clarke207@example.com', '2026-05-16 12:00:00', '971', '705009184', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-16 09:00:00', 'active', 'Arjun', 'Clarke', 'Arjun Clarke', 'https://cdn.livfinder.com/avatars/user-207.jpg', 3, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-05-27 09:00:00', '2026-05-10 09:00:00', 41, 0, 0, '2026-05-16 09:00:00', '2026-05-16 09:00:00'),
(208, '01K2F2DKG0KHSZRZD5V4G9486B', 'isabella.volkov208@example.com', 'isabella.volkov208@example.com', '2025-11-27 12:00:00', '44', '760604765', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-27 09:00:00', 'suspended', 'Isabella', 'Volkov', 'Isabella Volkov', 'https://cdn.livfinder.com/avatars/user-208.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1900002, NULL, NULL, 30, 0, 0, '2025-11-27 09:00:00', '2025-11-27 09:00:00'),
(209, '01K2F2DKG0PX43PYD7N7BBZ2ET', 'farah.karim209@example.com', 'farah.karim209@example.com', '2024-10-15 12:00:00', '44', '716097636', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-15 09:00:00', 'active', 'Farah', 'Karim', 'Farah Karim', 'https://cdn.livfinder.com/avatars/user-209.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-08-15 09:00:00', '2026-08-07 09:00:00', 24, 0, 1, '2024-10-15 09:00:00', '2024-10-15 09:00:00'),
(210, '01K2F2DKG0JVNATB9Q2YT8A94N', 'mohammed.lindqvist210@example.com', 'mohammed.lindqvist210@example.com', '2026-03-17 12:00:00', '971', '653999122', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-17 09:00:00', 'active', 'Mohammed', 'Lindqvist', 'Mohammed Lindqvist', 'https://cdn.livfinder.com/avatars/user-210.jpg', 9, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-07-11 09:00:00', '2026-07-22 09:00:00', 3, 0, 1, '2026-03-17 09:00:00', '2026-03-17 09:00:00'),
(211, '01K2F2DKG0DD0EA1G1KBP1W5XQ', 'sebastian.ivanov211@example.com', 'sebastian.ivanov211@example.com', '2026-04-27 12:00:00', '44', '573647645', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-27 09:00:00', 'active', 'Sebastian', 'Ivanov', 'Sebastian Ivanov', 'https://cdn.livfinder.com/avatars/user-211.jpg', 3, 3, 'sqm', 'Europe/London', 1075, 1044856, '2026-06-14 09:00:00', '2026-04-27 09:00:00', 19, 0, 1, '2026-04-27 09:00:00', '2026-04-27 09:00:00'),
(212, '01K2F2DKG0A0M1M8R75VWADHHD', 'noor.al-balushi212@example.com', 'noor.al-balushi212@example.com', '2024-11-23 12:00:00', '44', '767181538', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-23 09:00:00', 'active', 'Noor', 'Al Balushi', 'Noor Al Balushi', 'https://cdn.livfinder.com/avatars/user-212.jpg', 9, 3, 'sqm', 'Europe/London', 1075, 1040512, '2026-05-01 09:00:00', '2026-05-15 09:00:00', 16, 0, 0, '2024-11-23 09:00:00', '2024-11-23 09:00:00'),
(213, '01K2F2DKG0A92BD203HD5M8S3W', 'youssef.rossellini213@example.com', 'youssef.rossellini213@example.com', '2024-09-03 12:00:00', '44', '774920377', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-03 09:00:00', 'active', 'Youssef', 'Rossellini', 'Youssef Rossellini', 'https://cdn.livfinder.com/avatars/user-213.jpg', 8, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-05-23 09:00:00', '2026-06-21 09:00:00', 14, 0, 0, '2024-09-03 09:00:00', '2024-09-03 09:00:00'),
(214, '01K2F2DKG0RKAKQFFNYDBX3BXJ', 'sarah.al-balushi214@example.com', 'sarah.al-balushi214@example.com', '2026-06-02 12:00:00', '44', '740134523', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-06-02 09:00:00', 'active', 'Sarah', 'Al Balushi', 'Sarah Al Balushi', 'https://cdn.livfinder.com/avatars/user-214.jpg', 2, 3, 'sqm', 'Europe/London', 1177, 1089245, '2026-04-25 09:00:00', '2026-07-28 09:00:00', 10, 0, 0, '2026-06-02 09:00:00', '2026-06-02 09:00:00'),
(215, '01K2F2DKG0F94W8XH2N4RYVKTZ', 'noor.al-balushi215@example.com', 'noor.al-balushi215@example.com', NULL, '44', '712835721', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-09-26 09:00:00', 'pending_verification', 'Noor', 'Al Balushi', 'Noor Al Balushi', 'https://cdn.livfinder.com/avatars/user-215.jpg', 1, 19, 'sqm', 'Europe/London', 1204, 1131059, NULL, NULL, 34, 0, 1, NULL, '2025-09-26 09:00:00'),
(216, '01K2F2DKG0EKWY00JGCJ1JXKC7', 'farah.konigsberg216@example.com', 'farah.konigsberg216@example.com', '2025-03-05 12:00:00', '971', '710438533', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-05 09:00:00', 'closed', 'Farah', 'Königsberg', 'Farah Königsberg', 'https://cdn.livfinder.com/avatars/user-216.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, NULL, NULL, 7, 0, 1, '2025-03-05 09:00:00', '2025-03-05 09:00:00'),
(217, '01K2F2DKG0P15NC7N9QF7Z2N5A', 'nadia.halabi217@example.com', 'nadia.halabi217@example.com', '2026-04-27 12:00:00', '44', '710854982', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-27 09:00:00', 'active', 'Nadia', 'Halabi', 'Nadia Halabi', 'https://cdn.livfinder.com/avatars/user-217.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-06-12 09:00:00', '2026-07-23 09:00:00', 13, 0, 1, '2026-04-27 09:00:00', '2026-04-27 09:00:00'),
(218, '01K2F2DKG0FD05W15EMYWPTQDT', 'hassan.ferrari218@example.com', 'hassan.ferrari218@example.com', '2026-03-26 12:00:00', '44', '788750111', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-26 09:00:00', 'suspended', 'Hassan', 'Ferrari', 'Hassan Ferrari', 'https://cdn.livfinder.com/avatars/user-218.jpg', 8, 6, 'sqm', 'Europe/London', 1194, 1102858, NULL, NULL, 6, 0, 0, '2026-03-26 09:00:00', '2026-03-26 09:00:00'),
(219, '01K2F2DKG0MXCHJBRHS042PAXN', 'camille.sharma219@example.com', 'camille.sharma219@example.com', '2026-01-20 12:00:00', '44', '629557958', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-20 09:00:00', 'active', 'Camille', 'Sharma', 'Camille Sharma', 'https://cdn.livfinder.com/avatars/user-219.jpg', 9, 3, 'sqm', 'Europe/London', 1075, 1046589, '2026-04-25 09:00:00', '2026-06-13 09:00:00', 31, 0, 1, '2026-01-20 09:00:00', '2026-01-20 09:00:00'),
(220, '01K2F2DKG0NK02XFDSMDVW4XSZ', 'priya.al-suwaidi220@example.com', 'priya.al-suwaidi220@example.com', '2025-04-29 12:00:00', '44', '582580545', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-29 09:00:00', 'active', 'Priya', 'Al Suwaidi', 'Priya Al Suwaidi', 'https://cdn.livfinder.com/avatars/user-220.jpg', 8, 6, 'sqm', 'Europe/London', 1194, 1102858, '2026-06-08 09:00:00', '2026-07-06 09:00:00', 1, 0, 0, '2025-04-29 09:00:00', '2025-04-29 09:00:00'),
(221, '01K2F2DKG0RPN13D7EZ76QACPZ', 'alexander.volkov221@example.com', 'alexander.volkov221@example.com', '2026-05-04 12:00:00', '44', '670556382', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-04 09:00:00', 'active', 'Alexander', 'Volkov', 'Alexander Volkov', 'https://cdn.livfinder.com/avatars/user-221.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1900001, '2026-07-11 09:00:00', '2026-05-15 09:00:00', 11, 0, 0, '2026-05-04 09:00:00', '2026-05-04 09:00:00'),
(222, '01K2F2DKG0979S7ZMBQNAW4PCS', 'vikram.rossellini222@example.com', 'vikram.rossellini222@example.com', '2025-01-11 12:00:00', '44', '621260217', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-11 09:00:00', 'active', 'Vikram', 'Rossellini', 'Vikram Rossellini', 'https://cdn.livfinder.com/avatars/user-222.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1040512, '2026-07-02 09:00:00', '2026-08-09 09:00:00', 9, 0, 1, '2025-01-11 09:00:00', '2025-01-11 09:00:00'),
(223, '01K2F2DKG0GRR9TMGE002AMF9M', 'sarah.al-mansouri223@example.com', 'sarah.al-mansouri223@example.com', NULL, '44', '705924310', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-19 09:00:00', 'pending_verification', 'Sarah', 'Al Mansouri', 'Sarah Al Mansouri', 'https://cdn.livfinder.com/avatars/user-223.jpg', 9, 2, 'sqft', 'Europe/London', 1233, 1121746, NULL, NULL, 35, 0, 1, NULL, '2025-11-19 09:00:00'),
(224, '01K2F2DKG0ZKHJK5MB6XFJS4QH', 'anastasia.laurent224@example.com', 'anastasia.laurent224@example.com', '2026-07-14 12:00:00', '44', '547806673', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-14 09:00:00', 'active', 'Anastasia', 'Laurent', 'Anastasia Laurent', 'https://cdn.livfinder.com/avatars/user-224.jpg', 8, 3, 'sqm', 'Europe/London', 1177, 1089101, '2026-05-22 09:00:00', '2026-08-07 09:00:00', 40, 0, 1, '2026-07-14 09:00:00', '2026-07-14 09:00:00'),
(225, '01K2F2DKG0JPG62T1JQ9M97ACW', 'marco.fairfax225@example.com', 'marco.fairfax225@example.com', '2025-03-25 12:00:00', '971', '734946522', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-25 09:00:00', 'active', 'Marco', 'Fairfax', 'Marco Fairfax', 'https://cdn.livfinder.com/avatars/user-225.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-06-16 09:00:00', '2026-08-17 09:00:00', 21, 0, 0, '2025-03-25 09:00:00', '2025-03-25 09:00:00'),
(226, '01K2F2DKG0A7R02B1TRR0CG2T6', 'henry.whitfield226@example.com', 'henry.whitfield226@example.com', '2026-06-10 12:00:00', '44', '772734227', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-06-10 09:00:00', 'active', 'Henry', 'Whitfield', 'Henry Whitfield', 'https://cdn.livfinder.com/avatars/user-226.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1034729, '2026-05-09 09:00:00', '2026-05-10 09:00:00', 7, 0, 0, '2026-06-10 09:00:00', '2026-06-10 09:00:00'),
(227, '01K2F2DKG0S8FPSHPQ2MG68ZF4', 'james.el-sayed227@example.com', 'james.el-sayed227@example.com', '2024-08-15 12:00:00', '44', '698599786', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-08-15 09:00:00', 'suspended', 'James', 'El Sayed', 'James El Sayed', 'https://cdn.livfinder.com/avatars/user-227.jpg', 8, 13, 'sqm', 'Europe/London', 1014, 1007408, NULL, NULL, 24, 0, 1, '2024-08-15 09:00:00', '2024-08-15 09:00:00'),
(228, '01K2F2DKG0P4VB5TAEJ044HS20', 'rafael.moreau228@example.com', 'rafael.moreau228@example.com', '2026-05-09 12:00:00', '44', '579598033', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-09 09:00:00', 'active', 'Rafael', 'Moreau', 'Rafael Moreau', 'https://cdn.livfinder.com/avatars/user-228.jpg', 2, 3, 'sqm', 'Europe/London', 1207, 1036027, '2026-07-10 09:00:00', '2026-06-07 09:00:00', 19, 0, 0, '2026-05-09 09:00:00', '2026-05-09 09:00:00'),
(229, '01K2F2DKG0BGZY240GA6WTD7R1', 'marco.santos229@example.com', 'marco.santos229@example.com', '2025-03-20 12:00:00', '971', '569557631', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-20 09:00:00', 'active', 'Marco', 'Santos', 'Marco Santos', 'https://cdn.livfinder.com/avatars/user-229.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-05-28 09:00:00', '2026-06-23 09:00:00', 23, 0, 0, '2025-03-20 09:00:00', '2025-03-20 09:00:00'),
(230, '01K2F2DKG0R05QNP5FR9PXPPC8', 'aisha.ivanov230@example.com', 'aisha.ivanov230@example.com', '2025-12-19 12:00:00', '44', '704085413', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-19 09:00:00', 'active', 'Aisha', 'Ivanov', 'Aisha Ivanov', 'https://cdn.livfinder.com/avatars/user-230.jpg', 1, 2, 'sqm', 'Europe/London', 1011, 1900004, '2026-07-24 09:00:00', '2026-05-17 09:00:00', 5, 0, 0, '2025-12-19 09:00:00', '2025-12-19 09:00:00'),
(231, '01K2F2DKG0BZW4X414C5WWWFQW', 'charlotte.volkov231@example.com', 'charlotte.volkov231@example.com', '2024-09-06 12:00:00', '44', '515680078', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-06 09:00:00', 'active', 'Charlotte', 'Volkov', 'Charlotte Volkov', 'https://cdn.livfinder.com/avatars/user-231.jpg', 8, 3, 'sqm', 'Europe/London', 1145, 1900000, '2026-08-12 09:00:00', '2026-05-22 09:00:00', 10, 0, 0, '2024-09-06 09:00:00', '2024-09-06 09:00:00'),
(232, '01K2F2DKG0YCTPD1M60BYT7FT8', 'mariam.rossi232@example.com', 'mariam.rossi232@example.com', '2025-12-23 12:00:00', '44', '583195241', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-23 09:00:00', 'active', 'Mariam', 'Rossi', 'Mariam Rossi', 'https://cdn.livfinder.com/avatars/user-232.jpg', 3, 3, 'sqm', 'Europe/London', 1207, 1900001, '2026-05-02 09:00:00', '2026-07-18 09:00:00', 4, 0, 1, '2025-12-23 09:00:00', '2025-12-23 09:00:00'),
(233, '01K2F2DKG0X5X3BEB11WMQMKRE', 'anastasia.el-sayed233@example.com', 'anastasia.el-sayed233@example.com', '2026-05-17 12:00:00', '44', '748234347', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-17 09:00:00', 'active', 'Anastasia', 'El Sayed', 'Anastasia El Sayed', 'https://cdn.livfinder.com/avatars/user-233.jpg', 9, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-07-03 09:00:00', '2026-08-04 09:00:00', 22, 0, 0, '2026-05-17 09:00:00', '2026-05-17 09:00:00'),
(234, '01K2F2DKG05PB125RFTW60CSW0', 'priya.al-suwaidi234@example.com', 'priya.al-suwaidi234@example.com', NULL, '44', '637789783', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-05 09:00:00', 'pending_verification', 'Priya', 'Al Suwaidi', 'Priya Al Suwaidi', 'https://cdn.livfinder.com/avatars/user-234.jpg', 9, 21, 'sqm', 'Europe/London', 1142, 1068704, NULL, NULL, 58, 0, 0, NULL, '2026-04-05 09:00:00'),
(235, '01K2F2DKG0JQMD3292HBY2YK5N', 'antoine.kapoor235@example.com', 'antoine.kapoor235@example.com', '2025-02-02 12:00:00', '44', '720767158', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-02 09:00:00', 'active', 'Antoine', 'Kapoor', 'Antoine Kapoor', 'https://cdn.livfinder.com/avatars/user-235.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089101, '2026-07-12 09:00:00', '2026-07-29 09:00:00', 13, 0, 1, '2025-02-02 09:00:00', '2025-02-02 09:00:00'),
(236, '01K2F2DKG025YJ22KY327PMPKV', 'sarah.marchetti236@example.com', 'sarah.marchetti236@example.com', '2025-12-30 12:00:00', '44', '573217354', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-30 09:00:00', 'suspended', 'Sarah', 'Marchetti', 'Sarah Marchetti', 'https://cdn.livfinder.com/avatars/user-236.jpg', 8, 22, 'sqm', 'Europe/London', 1219, 1106650, NULL, NULL, 41, 0, 0, '2025-12-30 09:00:00', '2025-12-30 09:00:00'),
(237, '01K2F2DKG0W1ZYYH5K4KCWBCFP', 'daniel.rahman237@example.com', 'daniel.rahman237@example.com', '2024-10-10 12:00:00', '971', '772051811', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-10 09:00:00', 'active', 'Daniel', 'Rahman', 'Daniel Rahman', 'https://cdn.livfinder.com/avatars/user-237.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-22 09:00:00', '2026-06-05 09:00:00', 57, 0, 1, '2024-10-10 09:00:00', '2024-10-10 09:00:00'),
(238, '01K2F2DKG0J4TKBMT6QN28A41T', 'omar.herrera238@example.com', 'omar.herrera238@example.com', '2025-10-22 12:00:00', '44', '666307337', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-22 09:00:00', 'active', 'Omar', 'Herrera', 'Omar Herrera', 'https://cdn.livfinder.com/avatars/user-238.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1122795, '2026-04-28 09:00:00', '2026-06-20 09:00:00', 7, 0, 1, '2025-10-22 09:00:00', '2025-10-22 09:00:00'),
(239, '01K2F2DKG0XBQTN276S6YCX8FH', 'karim.konigsberg239@example.com', 'karim.konigsberg239@example.com', '2025-10-01 12:00:00', '44', '610474453', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-01 09:00:00', 'active', 'Karim', 'Königsberg', 'Karim Königsberg', 'https://cdn.livfinder.com/avatars/user-239.jpg', 1, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-06-03 09:00:00', '2026-04-30 09:00:00', 25, 0, 0, '2025-10-01 09:00:00', '2025-10-01 09:00:00'),
(240, '01K2F2DKG0EBXTGP2YQAJ9CT0H', 'mohammed.ashworth240@example.com', 'mohammed.ashworth240@example.com', '2025-04-09 12:00:00', '44', '591246726', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-09 09:00:00', 'active', 'Mohammed', 'Ashworth', 'Mohammed Ashworth', 'https://cdn.livfinder.com/avatars/user-240.jpg', 2, 3, 'sqm', 'Europe/London', 1207, 1036027, '2026-05-15 09:00:00', '2026-07-02 09:00:00', 58, 0, 1, '2025-04-09 09:00:00', '2025-04-09 09:00:00'),
(241, '01K2F2DKG0AJW46HNTKN9TGWR9', 'rafael.clarke241@example.com', 'rafael.clarke241@example.com', '2024-09-22 12:00:00', '44', '637726634', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-22 09:00:00', 'active', 'Rafael', 'Clarke', 'Rafael Clarke', 'https://cdn.livfinder.com/avatars/user-241.jpg', 8, 3, 'sqm', 'Europe/London', 1207, 1032653, '2026-05-31 09:00:00', '2026-06-20 09:00:00', 57, 0, 0, '2024-09-22 09:00:00', '2024-09-22 09:00:00'),
(242, '01K2F2DKG0CKDWJ3XN39RHHSCT', 'nadia.bin-ahmed242@example.com', 'nadia.bin-ahmed242@example.com', '2024-08-14 12:00:00', '971', '716222080', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-08-14 09:00:00', 'active', 'Nadia', 'Bin Ahmed', 'Nadia Bin Ahmed', 'https://cdn.livfinder.com/avatars/user-242.jpg', 3, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-06 09:00:00', '2026-07-22 09:00:00', 39, 0, 0, '2024-08-14 09:00:00', '2024-08-14 09:00:00'),
(243, '01K2F2DKG0DPRS2GSEP8KS3KNG', 'diego.aziz243@example.com', 'diego.aziz243@example.com', '2026-01-09 12:00:00', '44', '522331165', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-09 09:00:00', 'active', 'Diego', 'Aziz', 'Diego Aziz', 'https://cdn.livfinder.com/avatars/user-243.jpg', 2, 19, 'sqm', 'Europe/London', 1204, 1131059, '2026-07-23 09:00:00', '2026-08-09 09:00:00', 19, 0, 0, '2026-01-09 09:00:00', '2026-01-09 09:00:00'),
(244, '01K2F2DKG0SCS0RM3A6822WPN9', 'fatima.wong244@example.com', 'fatima.wong244@example.com', '2026-03-14 12:00:00', '44', '517086116', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-14 09:00:00', 'active', 'Fatima', 'Wong', 'Fatima Wong', 'https://cdn.livfinder.com/avatars/user-244.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-06-12 09:00:00', '2026-08-15 09:00:00', 22, 0, 0, '2026-03-14 09:00:00', '2026-03-14 09:00:00'),
(245, '01K2F2DKG0KD7W94114K60PVZW', 'alexander.rossellini245@example.com', 'alexander.rossellini245@example.com', '2024-11-10 12:00:00', '44', '659023783', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-10 09:00:00', 'active', 'Alexander', 'Rossellini', 'Alexander Rossellini', 'https://cdn.livfinder.com/avatars/user-245.jpg', 8, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-05-14 09:00:00', '2026-07-21 09:00:00', 38, 0, 0, '2024-11-10 09:00:00', '2024-11-10 09:00:00'),
(246, '01K2F2DKG0CNKSBMDXJCEN97DG', 'nikolai.marchetti246@example.com', 'nikolai.marchetti246@example.com', '2025-11-08 12:00:00', '44', '701067937', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-08 09:00:00', 'active', 'Nikolai', 'Marchetti', 'Nikolai Marchetti', 'https://cdn.livfinder.com/avatars/user-246.jpg', 8, 19, 'sqm', 'Europe/London', 1204, 1131059, '2026-06-16 09:00:00', '2026-05-19 09:00:00', 44, 0, 1, '2025-11-08 09:00:00', '2025-11-08 09:00:00'),
(247, '01K2F2DKG06FHVTSV5AYJS2WGD', 'farah.khoury247@example.com', 'farah.khoury247@example.com', '2025-10-28 12:00:00', '971', '602243412', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-28 09:00:00', 'active', 'Farah', 'Khoury', 'Farah Khoury', 'https://cdn.livfinder.com/avatars/user-247.jpg', 8, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-24 09:00:00', '2026-06-17 09:00:00', 55, 0, 1, '2025-10-28 09:00:00', '2025-10-28 09:00:00'),
(248, '01K2F2DKG02EA2B6W2TQ6SBMK1', 'rashid.rahman248@example.com', 'rashid.rahman248@example.com', '2025-09-25 12:00:00', '44', '781077201', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-09-25 09:00:00', 'active', 'Rashid', 'Rahman', 'Rashid Rahman', 'https://cdn.livfinder.com/avatars/user-248.jpg', 1, 2, 'sqm', 'Europe/London', 1227, 1900003, '2026-06-22 09:00:00', '2026-07-27 09:00:00', 37, 0, 1, '2025-09-25 09:00:00', '2025-09-25 09:00:00'),
(249, '01K2F2DKG06CRX8F2TGWYAFJWH', 'james.marchetti249@example.com', 'james.marchetti249@example.com', '2026-01-19 12:00:00', '971', '723234309', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-19 09:00:00', 'active', 'James', 'Marchetti', 'James Marchetti', 'https://cdn.livfinder.com/avatars/user-249.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-06-14 09:00:00', '2026-06-26 09:00:00', 22, 0, 1, '2026-01-19 09:00:00', '2026-01-19 09:00:00'),
(250, '01K2F2DKG0KEXD0PZ991KBWVTY', 'isabella.nasser250@example.com', 'isabella.nasser250@example.com', '2024-09-27 12:00:00', '44', '531386772', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-27 09:00:00', 'suspended', 'Isabella', 'Nasser', 'Isabella Nasser', 'https://cdn.livfinder.com/avatars/user-250.jpg', 9, 12, 'sqm', 'Europe/London', 1098, 1900005, NULL, NULL, 48, 0, 0, '2024-09-27 09:00:00', '2024-09-27 09:00:00'),
(251, '01K2F2DKG0EVK67EZXFKVFSW4N', 'sarah.sterling251@example.com', 'sarah.sterling251@example.com', '2025-03-13 12:00:00', '44', '689737754', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-13 09:00:00', 'active', 'Sarah', 'Sterling', 'Sarah Sterling', 'https://cdn.livfinder.com/avatars/user-251.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1059582, '2026-04-27 09:00:00', '2026-04-28 09:00:00', 24, 0, 1, '2025-03-13 09:00:00', '2025-03-13 09:00:00'),
(252, '01K2F2DKG001DJCFT59T5K8ATV', 'chen.aziz252@example.com', 'chen.aziz252@example.com', '2026-07-02 12:00:00', '44', '566546057', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-02 09:00:00', 'active', 'Chen', 'Aziz', 'Chen Aziz', 'https://cdn.livfinder.com/avatars/user-252.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-08-16 09:00:00', '2026-06-18 09:00:00', 2, 0, 0, '2026-07-02 09:00:00', '2026-07-02 09:00:00'),
(253, '01K2F2DKG0V7TA3NGZWCT13J2V', 'diego.al-farsi253@example.com', 'diego.al-farsi253@example.com', '2026-03-07 12:00:00', '44', '513226281', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-07 09:00:00', 'active', 'Diego', 'Al Farsi', 'Diego Al Farsi', 'https://cdn.livfinder.com/avatars/user-253.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1052515, '2026-06-24 09:00:00', '2026-07-12 09:00:00', 26, 0, 0, '2026-03-07 09:00:00', '2026-03-07 09:00:00'),
(254, '01K2F2DKG0R4P102SAVP4MDM5M', 'camille.ferrari254@example.com', 'camille.ferrari254@example.com', '2024-07-03 12:00:00', '44', '632220430', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-07-03 09:00:00', 'active', 'Camille', 'Ferrari', 'Camille Ferrari', 'https://cdn.livfinder.com/avatars/user-254.jpg', 9, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-08-13 09:00:00', '2026-05-24 09:00:00', 46, 0, 0, '2024-07-03 09:00:00', '2024-07-03 09:00:00'),
(255, '01K2F2DKG0ED9Z7R246MNT5R81', 'rania.fairfax255@example.com', 'rania.fairfax255@example.com', '2026-02-04 12:00:00', '44', '740297071', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-02-04 09:00:00', 'active', 'Rania', 'Fairfax', 'Rania Fairfax', 'https://cdn.livfinder.com/avatars/user-255.jpg', 8, 18, 'sqm', 'Europe/London', 1225, 1153786, '2026-07-04 09:00:00', '2026-06-26 09:00:00', 25, 0, 0, '2026-02-04 09:00:00', '2026-02-04 09:00:00'),
(256, '01K2F2DKG0HFC1KFM2S608C67Q', 'chen.ashworth256@example.com', 'chen.ashworth256@example.com', '2026-05-05 12:00:00', '44', '780459082', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-05 09:00:00', 'active', 'Chen', 'Ashworth', 'Chen Ashworth', 'https://cdn.livfinder.com/avatars/user-256.jpg', 2, 4, 'sqft', 'Europe/London', 1232, 1050388, '2026-06-11 09:00:00', '2026-05-27 09:00:00', 43, 0, 1, '2026-05-05 09:00:00', '2026-05-05 09:00:00'),
(257, '01K2F2DKG0PPX3TYZ3BW2YE3HD', 'sebastian.al-mansouri257@example.com', 'sebastian.al-mansouri257@example.com', '2025-06-07 12:00:00', '44', '690475082', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-07 09:00:00', 'active', 'Sebastian', 'Al Mansouri', 'Sebastian Al Mansouri', 'https://cdn.livfinder.com/avatars/user-257.jpg', 8, 3, 'sqm', 'Europe/London', 1207, 1036027, '2026-05-25 09:00:00', '2026-07-06 09:00:00', 16, 0, 0, '2025-06-07 09:00:00', '2025-06-07 09:00:00'),
(258, '01K2F2DKG096YD9RY6N6YXJZVA', 'arjun.konigsberg258@example.com', 'arjun.konigsberg258@example.com', '2026-06-09 12:00:00', '44', '772792837', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-06-09 09:00:00', 'active', 'Arjun', 'Königsberg', 'Arjun Königsberg', 'https://cdn.livfinder.com/avatars/user-258.jpg', 9, 12, 'sqm', 'Europe/London', 1098, 1900005, '2026-08-10 09:00:00', '2026-08-13 09:00:00', 33, 0, 1, '2026-06-09 09:00:00', '2026-06-09 09:00:00'),
(259, '01K2F2DKG0AF5DHC8Y3SJB6E17', 'daniel.mercer259@example.com', 'daniel.mercer259@example.com', '2025-09-01 12:00:00', '971', '526699120', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-09-01 09:00:00', 'active', 'Daniel', 'Mercer', 'Daniel Mercer', 'https://cdn.livfinder.com/avatars/user-259.jpg', 2, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-05-12 09:00:00', '2026-04-25 09:00:00', 39, 0, 0, '2025-09-01 09:00:00', '2025-09-01 09:00:00'),
(260, '01K2F2DKG09WENF9Z878KZ2RVQ', 'sofia.marchetti260@example.com', 'sofia.marchetti260@example.com', '2024-08-31 12:00:00', '44', '534934064', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-08-31 09:00:00', 'active', 'Sofia', 'Marchetti', 'Sofia Marchetti', 'https://cdn.livfinder.com/avatars/user-260.jpg', 2, 22, 'sqm', 'Europe/London', 1219, 1106650, '2026-04-27 09:00:00', '2026-08-15 09:00:00', 22, 0, 1, '2024-08-31 09:00:00', '2024-08-31 09:00:00'),
(261, '01K2F2DKG0P2S8VNDJVECGJ14G', 'arjun.kapoor261@example.com', 'arjun.kapoor261@example.com', '2024-08-26 12:00:00', '44', '557580957', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-08-26 09:00:00', 'suspended', 'Arjun', 'Kapoor', 'Arjun Kapoor', 'https://cdn.livfinder.com/avatars/user-261.jpg', 1, 2, 'sqm', 'Europe/London', 1227, 1900003, NULL, NULL, 25, 0, 1, '2024-08-26 09:00:00', '2024-08-26 09:00:00'),
(262, '01K2F2DKG02BP5W9S8SEZSW50N', 'camille.darwish262@example.com', 'camille.darwish262@example.com', '2025-01-03 12:00:00', '971', '715840173', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-03 09:00:00', 'active', 'Camille', 'Darwish', 'Camille Darwish', 'https://cdn.livfinder.com/avatars/user-262.jpg', 9, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-06-17 09:00:00', '2026-04-23 09:00:00', 50, 0, 1, '2025-01-03 09:00:00', '2025-01-03 09:00:00'),
(263, '01K2F2DKG0XMKCCZ15HSKAQK7K', 'elena.halabi263@example.com', 'elena.halabi263@example.com', '2026-07-13 12:00:00', '971', '601404767', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-13 09:00:00', 'active', 'Elena', 'Halabi', 'Elena Halabi', 'https://cdn.livfinder.com/avatars/user-263.jpg', 2, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-22 09:00:00', '2026-05-14 09:00:00', 29, 0, 0, '2026-07-13 09:00:00', '2026-07-13 09:00:00'),
(264, '01K2F2DKG0763B5G5G7237H1WZ', 'yuki.dubois264@example.com', 'yuki.dubois264@example.com', '2026-05-11 12:00:00', '44', '644481995', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-11 09:00:00', 'active', 'Yuki', 'Dubois', 'Yuki Dubois', 'https://cdn.livfinder.com/avatars/user-264.jpg', 8, 2, 'sqm', 'Europe/London', 1011, 1900004, '2026-06-19 09:00:00', '2026-05-08 09:00:00', 54, 0, 0, '2026-05-11 09:00:00', '2026-05-11 09:00:00'),
(265, '01K2F2DKG07JKG02JN6KRCXZ8W', 'karim.hussein265@example.com', 'karim.hussein265@example.com', '2026-02-23 12:00:00', '44', '799147110', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-02-23 09:00:00', 'active', 'Karim', 'Hussein', 'Karim Hussein', 'https://cdn.livfinder.com/avatars/user-265.jpg', 3, 2, 'sqft', 'Europe/London', 1233, 1122795, '2026-08-14 09:00:00', '2026-07-12 09:00:00', 37, 0, 1, '2026-02-23 09:00:00', '2026-02-23 09:00:00'),
(266, '01K2F2DKG0YA2MET85KDCVNNTY', 'hassan.ashworth266@example.com', 'hassan.ashworth266@example.com', '2024-10-10 12:00:00', '44', '551100260', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-10 09:00:00', 'active', 'Hassan', 'Ashworth', 'Hassan Ashworth', 'https://cdn.livfinder.com/avatars/user-266.jpg', 8, 3, 'sqm', 'Europe/London', 1177, 1089250, '2026-07-24 09:00:00', '2026-06-21 09:00:00', 53, 0, 1, '2024-10-10 09:00:00', '2024-10-10 09:00:00'),
(267, '01K2F2DKG0QFQKQB3SEWCKTNE7', 'vikram.sterling267@example.com', 'vikram.sterling267@example.com', '2025-08-15 12:00:00', '44', '637373554', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-08-15 09:00:00', 'active', 'Vikram', 'Sterling', 'Vikram Sterling', 'https://cdn.livfinder.com/avatars/user-267.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1140142, '2026-06-04 09:00:00', '2026-06-18 09:00:00', 9, 0, 1, '2025-08-15 09:00:00', '2025-08-15 09:00:00'),
(268, '01K2F2DKG03ACDAH4ZQTKGMZCN', 'noor.halabi268@example.com', 'noor.halabi268@example.com', '2024-09-18 12:00:00', '44', '759007520', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-18 09:00:00', 'active', 'Noor', 'Halabi', 'Noor Halabi', 'https://cdn.livfinder.com/avatars/user-268.jpg', 3, 3, 'sqm', 'Europe/London', 1207, 1032653, '2026-07-22 09:00:00', '2026-06-03 09:00:00', 59, 0, 1, '2024-09-18 09:00:00', '2024-09-18 09:00:00'),
(269, '01K2F2DKG045KB5HRTG34BWGB3', 'julien.fairfax269@example.com', 'julien.fairfax269@example.com', NULL, '44', '514306231', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-04-22 09:00:00', 'pending_verification', 'Julien', 'Fairfax', 'Julien Fairfax', 'https://cdn.livfinder.com/avatars/user-269.jpg', 1, 18, 'sqm', 'Europe/London', 1225, 1153786, NULL, NULL, 36, 0, 0, NULL, '2026-04-22 09:00:00'),
(270, '01K2F2DKG02QAV9SWHSM7SAAC2', 'antoine.rossellini270@example.com', 'antoine.rossellini270@example.com', '2025-01-23 12:00:00', '971', '686729791', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-23 09:00:00', 'active', 'Antoine', 'Rossellini', 'Antoine Rossellini', 'https://cdn.livfinder.com/avatars/user-270.jpg', 9, 1, 'sqft', 'Asia/Dubai', 1231, 1000012, '2026-05-13 09:00:00', '2026-06-01 09:00:00', 44, 0, 0, '2025-01-23 09:00:00', '2025-01-23 09:00:00'),
(271, '01K2F2DKG0JMT6S5EE7AN3H164', 'mohammed.clarke271@example.com', 'mohammed.clarke271@example.com', '2025-08-13 12:00:00', '44', '751729380', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-08-13 09:00:00', 'closed', 'Mohammed', 'Clarke', 'Mohammed Clarke', 'https://cdn.livfinder.com/avatars/user-271.jpg', 8, 2, 'sqft', 'Europe/London', 1233, 1120784, NULL, NULL, 18, 0, 0, '2025-08-13 09:00:00', '2025-08-13 09:00:00'),
(272, '01K2F2DKG0GRG2ZX20GR1BPVHC', 'valentina.wong272@example.com', 'valentina.wong272@example.com', '2025-01-07 12:00:00', '44', '598274758', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-07 09:00:00', 'active', 'Valentina', 'Wong', 'Valentina Wong', 'https://cdn.livfinder.com/avatars/user-272.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1059582, '2026-05-28 09:00:00', '2026-06-13 09:00:00', 52, 0, 0, '2025-01-07 09:00:00', '2025-01-07 09:00:00'),
(273, '01K2F2DKG06MMRSNDBPCS7DQQ4', 'hassan.tanaka273@example.com', 'hassan.tanaka273@example.com', '2026-07-26 12:00:00', '44', '764270851', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-26 09:00:00', 'active', 'Hassan', 'Tanaka', 'Hassan Tanaka', 'https://cdn.livfinder.com/avatars/user-273.jpg', 2, 2, 'sqm', 'Europe/London', 1227, 1900003, '2026-05-13 09:00:00', '2026-06-07 09:00:00', 49, 0, 1, '2026-07-26 09:00:00', '2026-07-26 09:00:00'),
(274, '01K2F2DKG03PZG9588Q7ZWAN0E', 'yuki.al-otaiba274@example.com', 'yuki.al-otaiba274@example.com', '2025-05-23 12:00:00', '971', '635397086', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-23 09:00:00', 'active', 'Yuki', 'Al Otaiba', 'Yuki Al Otaiba', 'https://cdn.livfinder.com/avatars/user-274.jpg', 8, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-05-17 09:00:00', '2026-06-06 09:00:00', 28, 0, 0, '2025-05-23 09:00:00', '2025-05-23 09:00:00'),
(275, '01K2F2DKG0NSZH6SKZDXJCYAFN', 'karim.marchetti275@example.com', 'karim.marchetti275@example.com', '2025-06-24 12:00:00', '44', '699247216', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-24 09:00:00', 'active', 'Karim', 'Marchetti', 'Karim Marchetti', 'https://cdn.livfinder.com/avatars/user-275.jpg', 1, 19, 'sqm', 'Europe/London', 1204, 1131059, '2026-06-18 09:00:00', '2026-08-14 09:00:00', 38, 0, 1, '2025-06-24 09:00:00', '2025-06-24 09:00:00'),
(276, '01K2F2DKG0JCWVF1BTQDRJ4FR8', 'elena.bin-ahmed276@example.com', 'elena.bin-ahmed276@example.com', '2024-10-11 12:00:00', '44', '634395501', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-11 09:00:00', 'active', 'Elena', 'Bin Ahmed', 'Elena Bin Ahmed', 'https://cdn.livfinder.com/avatars/user-276.jpg', 9, 12, 'sqm', 'Europe/London', 1098, 1900005, '2026-06-20 09:00:00', '2026-08-12 09:00:00', 23, 0, 1, '2024-10-11 09:00:00', '2024-10-11 09:00:00'),
(277, '01K2F2DKG04JYPZMYY56TQSMRP', 'fatima.bakr277@example.com', 'fatima.bakr277@example.com', '2025-06-18 12:00:00', '971', '514844806', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-18 09:00:00', 'active', 'Fatima', 'Bakr', 'Fatima Bakr', 'https://cdn.livfinder.com/avatars/user-277.jpg', 8, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-09 09:00:00', '2026-08-02 09:00:00', 15, 0, 0, '2025-06-18 09:00:00', '2025-06-18 09:00:00'),
(278, '01K2F2DKG0D008J9SX2Y2ZZ9KF', 'theo.rahman278@example.com', 'theo.rahman278@example.com', '2024-10-21 12:00:00', '44', '682642165', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-21 09:00:00', 'active', 'Theo', 'Rahman', 'Theo Rahman', 'https://cdn.livfinder.com/avatars/user-278.jpg', 2, 2, 'sqm', 'Europe/London', 1227, 1900003, '2026-06-27 09:00:00', '2026-08-06 09:00:00', 41, 0, 0, '2024-10-21 09:00:00', '2024-10-21 09:00:00'),
(279, '01K2F2DKG0JMHCCXYKH74X2NQ0', 'maximilian.al-mansouri279@example.com', 'maximilian.al-mansouri279@example.com', '2025-05-03 12:00:00', '44', '795418827', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-03 09:00:00', 'active', 'Maximilian', 'Al Mansouri', 'Maximilian Al Mansouri', 'https://cdn.livfinder.com/avatars/user-279.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1032653, '2026-08-03 09:00:00', '2026-05-06 09:00:00', 52, 0, 1, '2025-05-03 09:00:00', '2025-05-03 09:00:00'),
(280, '01K2F2DKG03BAVGTJGMRYSR77F', 'hassan.dubois280@example.com', 'hassan.dubois280@example.com', '2026-03-13 12:00:00', '44', '798465971', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-13 09:00:00', 'active', 'Hassan', 'Dubois', 'Hassan Dubois', 'https://cdn.livfinder.com/avatars/user-280.jpg', 9, 2, 'sqft', 'Europe/London', 1233, 1121750, '2026-05-24 09:00:00', '2026-07-20 09:00:00', 28, 0, 0, '2026-03-13 09:00:00', '2026-03-13 09:00:00'),
(281, '01K2F2DKG0N723YS9EV76EVCCK', 'sarah.kapoor281@example.com', 'sarah.kapoor281@example.com', '2025-11-25 12:00:00', '44', '508886823', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-25 09:00:00', 'active', 'Sarah', 'Kapoor', 'Sarah Kapoor', 'https://cdn.livfinder.com/avatars/user-281.jpg', 8, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-04-28 09:00:00', '2026-07-16 09:00:00', 1, 0, 1, '2025-11-25 09:00:00', '2025-11-25 09:00:00'),
(282, '01K2F2DKG0W6DQPYY7HKAAYA8Q', 'priya.wong282@example.com', 'priya.wong282@example.com', '2024-10-13 12:00:00', '44', '577317934', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-13 09:00:00', 'active', 'Priya', 'Wong', 'Priya Wong', 'https://cdn.livfinder.com/avatars/user-282.jpg', 1, 3, 'sqm', 'Europe/London', 1145, 1900000, '2026-05-27 09:00:00', '2026-08-15 09:00:00', 24, 0, 0, '2024-10-13 09:00:00', '2024-10-13 09:00:00'),
(283, '01K2F2DKG0Q89PAX17BH378853', 'lucas.whitfield283@example.com', 'lucas.whitfield283@example.com', NULL, '44', '690103207', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-02 09:00:00', 'pending_verification', 'Lucas', 'Whitfield', 'Lucas Whitfield', 'https://cdn.livfinder.com/avatars/user-283.jpg', 1, 3, 'sqm', 'Europe/London', 1107, 1059582, NULL, NULL, 12, 0, 0, NULL, '2025-02-02 09:00:00'),
(284, '01K2F2DKG0Y3XJXTXFKB4YP89D', 'hana.rahman284@example.com', 'hana.rahman284@example.com', '2024-10-26 12:00:00', '44', '786469353', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-26 09:00:00', 'active', 'Hana', 'Rahman', 'Hana Rahman', 'https://cdn.livfinder.com/avatars/user-284.jpg', 2, 2, 'sqm', 'Europe/London', 1102, 1056263, '2026-08-03 09:00:00', '2026-07-21 09:00:00', 53, 0, 0, '2024-10-26 09:00:00', '2024-10-26 09:00:00'),
(285, '01K2F2DKG022KKMAZ91KVTXY77', 'henry.al-otaiba285@example.com', 'henry.al-otaiba285@example.com', '2025-06-26 12:00:00', '44', '634917325', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-06-26 09:00:00', 'active', 'Henry', 'Al Otaiba', 'Henry Al Otaiba', 'https://cdn.livfinder.com/avatars/user-285.jpg', 2, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-07-16 09:00:00', '2026-06-07 09:00:00', 55, 0, 1, '2025-06-26 09:00:00', '2025-06-26 09:00:00'),
(286, '01K2F2DKG0T7B0YW9QZV6S4KMD', 'youssef.kapoor286@example.com', 'youssef.kapoor286@example.com', '2024-10-07 12:00:00', '44', '737857290', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-10-07 09:00:00', 'active', 'Youssef', 'Kapoor', 'Youssef Kapoor', 'https://cdn.livfinder.com/avatars/user-286.jpg', 1, 2, 'sqm', 'Europe/London', 1102, 1056263, '2026-07-03 09:00:00', '2026-07-09 09:00:00', 20, 0, 0, '2024-10-07 09:00:00', '2024-10-07 09:00:00'),
(287, '01K2F2DKG095AWGK31VV71W75A', 'lucas.bakr287@example.com', 'lucas.bakr287@example.com', '2025-01-29 12:00:00', '44', '713233058', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-29 09:00:00', 'active', 'Lucas', 'Bakr', 'Lucas Bakr', 'https://cdn.livfinder.com/avatars/user-287.jpg', 1, 3, 'sqm', 'Europe/London', 1207, 1035281, '2026-07-21 09:00:00', '2026-06-29 09:00:00', 10, 0, 1, '2025-01-29 09:00:00', '2025-01-29 09:00:00'),
(288, '01K2F2DKG0XBT36427Y6FGS2TK', 'karim.herrera288@example.com', 'karim.herrera288@example.com', '2025-05-05 12:00:00', '44', '709948280', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-05 09:00:00', 'suspended', 'Karim', 'Herrera', 'Karim Herrera', 'https://cdn.livfinder.com/avatars/user-288.jpg', 1, 5, 'sqm', 'Europe/London', 1214, 1017827, NULL, NULL, 4, 0, 1, '2025-05-05 09:00:00', '2025-05-05 09:00:00'),
(289, '01K2F2DKG0T2J35ZGTMK4BSPD7', 'valentina.bakr289@example.com', 'valentina.bakr289@example.com', '2026-03-19 12:00:00', '44', '641732068', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-19 09:00:00', 'active', 'Valentina', 'Bakr', 'Valentina Bakr', 'https://cdn.livfinder.com/avatars/user-289.jpg', 2, 3, 'sqm', 'Europe/London', 1207, 1900001, '2026-05-08 09:00:00', '2026-07-30 09:00:00', 52, 0, 0, '2026-03-19 09:00:00', '2026-03-19 09:00:00'),
(290, '01K2F2DKG0CQAV9EAMM6EVYTD1', 'charlotte.ferrari290@example.com', 'charlotte.ferrari290@example.com', '2026-03-12 12:00:00', '44', '626962124', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-12 09:00:00', 'active', 'Charlotte', 'Ferrari', 'Charlotte Ferrari', 'https://cdn.livfinder.com/avatars/user-290.jpg', 3, 13, 'sqm', 'Europe/London', 1014, 1007408, '2026-07-23 09:00:00', '2026-05-18 09:00:00', 32, 0, 0, '2026-03-12 09:00:00', '2026-03-12 09:00:00'),
(291, '01K2F2DKG016RV2A6JJCAY17J2', 'layla.rahman291@example.com', 'layla.rahman291@example.com', '2024-06-13 12:00:00', '44', '656007970', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-06-13 09:00:00', 'active', 'Layla', 'Rahman', 'Layla Rahman', 'https://cdn.livfinder.com/avatars/user-291.jpg', 2, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-04-26 09:00:00', '2026-05-01 09:00:00', 9, 0, 0, '2024-06-13 09:00:00', '2024-06-13 09:00:00'),
(292, '01K2F2DKG0G19CG1P4VAAFN1JD', 'amelia.fairfax292@example.com', 'amelia.fairfax292@example.com', '2024-11-14 12:00:00', '971', '527264880', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-14 09:00:00', 'active', 'Amelia', 'Fairfax', 'Amelia Fairfax', 'https://cdn.livfinder.com/avatars/user-292.jpg', 2, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-04-30 09:00:00', '2026-05-03 09:00:00', 42, 0, 0, '2024-11-14 09:00:00', '2024-11-14 09:00:00'),
(293, '01K2F2DKG09HCZQPM267PNMX8M', 'camille.darwish293@example.com', 'camille.darwish293@example.com', '2025-02-26 12:00:00', '44', '690804571', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-26 09:00:00', 'active', 'Camille', 'Darwish', 'Camille Darwish', 'https://cdn.livfinder.com/avatars/user-293.jpg', 1, 11, 'sqm', 'Europe/London', 1199, 1104057, '2026-04-24 09:00:00', '2026-06-29 09:00:00', 33, 0, 1, '2025-02-26 09:00:00', '2025-02-26 09:00:00'),
(294, '01K2F2DKG0SEMT2FQ2AEJSDGTM', 'diego.volkov294@example.com', 'diego.volkov294@example.com', '2025-02-22 12:00:00', '44', '731366028', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-22 09:00:00', 'active', 'Diego', 'Volkov', 'Diego Volkov', 'https://cdn.livfinder.com/avatars/user-294.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1052950, '2026-07-14 09:00:00', '2026-06-27 09:00:00', 53, 0, 1, '2025-02-22 09:00:00', '2025-02-22 09:00:00'),
(295, '01K2F2DKG0FBJ0YNE9SRM4MQTE', 'marco.haddad295@example.com', 'marco.haddad295@example.com', '2025-12-15 12:00:00', '971', '778727479', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-15 09:00:00', 'active', 'Marco', 'Haddad', 'Marco Haddad', 'https://cdn.livfinder.com/avatars/user-295.jpg', 3, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-06-09 09:00:00', '2026-07-24 09:00:00', 47, 0, 1, '2025-12-15 09:00:00', '2025-12-15 09:00:00'),
(296, '01K2F2DKG0B868DCST6N9ER868', 'rafael.al-farsi296@example.com', 'rafael.al-farsi296@example.com', '2026-03-17 12:00:00', '44', '686981673', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-17 09:00:00', 'active', 'Rafael', 'Al Farsi', 'Rafael Al Farsi', 'https://cdn.livfinder.com/avatars/user-296.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089250, '2026-08-16 09:00:00', '2026-08-01 09:00:00', 49, 0, 0, '2026-03-17 09:00:00', '2026-03-17 09:00:00'),
(297, '01K2F2DKG0CSD9RACJYT65FPB0', 'chen.bin-ahmed297@example.com', 'chen.bin-ahmed297@example.com', '2024-12-29 12:00:00', '44', '602529833', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-12-29 09:00:00', 'active', 'Chen', 'Bin Ahmed', 'Chen Bin Ahmed', 'https://cdn.livfinder.com/avatars/user-297.jpg', 1, 7, 'sqm', 'Europe/London', 1179, 1089864, '2026-08-11 09:00:00', '2026-08-09 09:00:00', 1, 0, 1, '2024-12-29 09:00:00', '2024-12-29 09:00:00'),
(298, '01K2F2DKG0CB0HCAE7RCV4T2KV', 'youssef.fairfax298@example.com', 'youssef.fairfax298@example.com', '2026-01-29 12:00:00', '44', '585704424', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-29 09:00:00', 'active', 'Youssef', 'Fairfax', 'Youssef Fairfax', 'https://cdn.livfinder.com/avatars/user-298.jpg', 3, 12, 'sqm', 'Europe/London', 1098, 1900005, '2026-07-13 09:00:00', '2026-06-20 09:00:00', 30, 0, 0, '2026-01-29 09:00:00', '2026-01-29 09:00:00'),
(299, '01K2F2DKG0P2E46S2GBP9YYCTD', 'nadia.al-suwaidi299@example.com', 'nadia.al-suwaidi299@example.com', '2026-03-01 12:00:00', '971', '749934911', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-03-01 09:00:00', 'active', 'Nadia', 'Al Suwaidi', 'Nadia Al Suwaidi', 'https://cdn.livfinder.com/avatars/user-299.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-07-29 09:00:00', '2026-04-25 09:00:00', 11, 0, 1, '2026-03-01 09:00:00', '2026-03-01 09:00:00'),
(300, '01K2F2DKG0B23MHB8AE7125GVM', 'hana.haddad300@example.com', 'hana.haddad300@example.com', '2025-03-16 12:00:00', '44', '522795944', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-16 09:00:00', 'active', 'Hana', 'Haddad', 'Hana Haddad', 'https://cdn.livfinder.com/avatars/user-300.jpg', 3, 2, 'sqft', 'Europe/London', 1233, 1122795, '2026-08-07 09:00:00', '2026-07-05 09:00:00', 10, 0, 1, '2025-03-16 09:00:00', '2025-03-16 09:00:00'),
(301, '01K2F2DKG0RAYB9WDKMWW04D5P', 'mariam.beaumont301@example.com', 'mariam.beaumont301@example.com', '2025-03-28 12:00:00', '44', '682592762', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-28 09:00:00', 'active', 'Mariam', 'Beaumont', 'Mariam Beaumont', 'https://cdn.livfinder.com/avatars/user-301.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1046589, '2026-07-10 09:00:00', '2026-08-15 09:00:00', 28, 0, 1, '2025-03-28 09:00:00', '2025-03-28 09:00:00'),
(302, '01K2F2DKG01X1D92JFAG7J5P1A', 'amelia.whitfield302@example.com', 'amelia.whitfield302@example.com', '2026-02-07 12:00:00', '44', '572011696', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-02-07 09:00:00', 'active', 'Amelia', 'Whitfield', 'Amelia Whitfield', 'https://cdn.livfinder.com/avatars/user-302.jpg', 1, 22, 'sqm', 'Europe/London', 1219, 1106650, '2026-08-06 09:00:00', '2026-05-12 09:00:00', 50, 0, 0, '2026-02-07 09:00:00', '2026-02-07 09:00:00'),
(303, '01K2F2DKG03DJMR7BNNB5QYQNV', 'hassan.ferrari303@example.com', 'hassan.ferrari303@example.com', '2025-03-02 12:00:00', '44', '644616293', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-03-02 09:00:00', 'active', 'Hassan', 'Ferrari', 'Hassan Ferrari', 'https://cdn.livfinder.com/avatars/user-303.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1122795, '2026-04-25 09:00:00', '2026-04-29 09:00:00', 36, 0, 0, '2025-03-02 09:00:00', '2025-03-02 09:00:00'),
(304, '01K2F2DKG0FY8VVKSFF09Z5YWH', 'yuki.moreau304@example.com', 'yuki.moreau304@example.com', '2025-10-08 12:00:00', '44', '706719802', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-08 09:00:00', 'active', 'Yuki', 'Moreau', 'Yuki Moreau', 'https://cdn.livfinder.com/avatars/user-304.jpg', 1, 3, 'sqm', 'Europe/London', 1085, 1052515, '2026-06-24 09:00:00', '2026-08-11 09:00:00', 29, 0, 1, '2025-10-08 09:00:00', '2025-10-08 09:00:00'),
(305, '01K2F2DKG0ZR247AH424WG2HVH', 'noor.von-habsburg305@example.com', 'noor.von-habsburg305@example.com', '2025-02-07 12:00:00', '44', '674992690', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-07 09:00:00', 'active', 'Noor', 'Von Habsburg', 'Noor Von Habsburg', 'https://cdn.livfinder.com/avatars/user-305.jpg', 2, 7, 'sqm', 'Europe/London', 1179, 1089864, '2026-06-09 09:00:00', '2026-04-25 09:00:00', 52, 0, 1, '2025-02-07 09:00:00', '2025-02-07 09:00:00'),
(306, '01K2F2DKG0WPX5ZMMMR1J16CGN', 'nadia.blackwood306@example.com', 'nadia.blackwood306@example.com', '2025-05-06 12:00:00', '44', '605585582', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-06 09:00:00', 'active', 'Nadia', 'Blackwood', 'Nadia Blackwood', 'https://cdn.livfinder.com/avatars/user-306.jpg', 8, 3, 'sqm', 'Europe/London', 1107, 1140142, '2026-07-14 09:00:00', '2026-07-17 09:00:00', 40, 0, 0, '2025-05-06 09:00:00', '2025-05-06 09:00:00'),
(307, '01K2F2DKG00JDBRCKBWF8Y79QK', 'emma.al-mansouri307@example.com', 'emma.al-mansouri307@example.com', '2026-01-25 12:00:00', '44', '701444476', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-01-25 09:00:00', 'active', 'Emma', 'Al Mansouri', 'Emma Al Mansouri', 'https://cdn.livfinder.com/avatars/user-307.jpg', 3, 2, 'sqm', 'Europe/London', 1011, 1900004, '2026-06-05 09:00:00', '2026-05-18 09:00:00', 51, 0, 1, '2026-01-25 09:00:00', '2026-01-25 09:00:00'),
(308, '01K2F2DKG01FCG23NE05M5F93J', 'yuki.fairfax308@example.com', 'yuki.fairfax308@example.com', '2025-01-22 12:00:00', '44', '568110109', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-22 09:00:00', 'active', 'Yuki', 'Fairfax', 'Yuki Fairfax', 'https://cdn.livfinder.com/avatars/user-308.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1120784, '2026-05-27 09:00:00', '2026-07-29 09:00:00', 5, 0, 0, '2025-01-22 09:00:00', '2025-01-22 09:00:00'),
(309, '01K2F2DKG0GX580TQ8ZNVAYH3F', 'leila.von-habsburg309@example.com', 'leila.von-habsburg309@example.com', '2024-12-31 12:00:00', '44', '720488584', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-12-31 09:00:00', 'active', 'Leila', 'Von Habsburg', 'Leila Von Habsburg', 'https://cdn.livfinder.com/avatars/user-309.jpg', 1, 3, 'sqm', 'Europe/London', 1145, 1900000, '2026-06-19 09:00:00', '2026-05-15 09:00:00', 24, 0, 0, '2024-12-31 09:00:00', '2024-12-31 09:00:00'),
(310, '01K2F2DKG0650K3F8XNGRWKSC4', 'nikolai.whitfield310@example.com', 'nikolai.whitfield310@example.com', '2026-05-26 12:00:00', '44', '708743427', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-26 09:00:00', 'active', 'Nikolai', 'Whitfield', 'Nikolai Whitfield', 'https://cdn.livfinder.com/avatars/user-310.jpg', 3, 3, 'sqm', 'Europe/London', 1207, 1035281, '2026-08-11 09:00:00', '2026-05-22 09:00:00', 11, 0, 1, '2026-05-26 09:00:00', '2026-05-26 09:00:00'),
(311, '01K2F2DKG0HQ54SJEBBCE9J6ER', 'karim.mehta311@example.com', 'karim.mehta311@example.com', '2025-08-08 12:00:00', '971', '742232969', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-08-08 09:00:00', 'active', 'Karim', 'Mehta', 'Karim Mehta', 'https://cdn.livfinder.com/avatars/user-311.jpg', 8, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-08-07 09:00:00', '2026-05-30 09:00:00', 8, 0, 1, '2025-08-08 09:00:00', '2025-08-08 09:00:00'),
(312, '01K2F2DKG09RGZ1AB2MRA5K8F6', 'nadia.aziz312@example.com', 'nadia.aziz312@example.com', '2025-10-24 12:00:00', '44', '772939737', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-10-24 09:00:00', 'active', 'Nadia', 'Aziz', 'Nadia Aziz', 'https://cdn.livfinder.com/avatars/user-312.jpg', 9, 3, 'sqm', 'Europe/London', 1075, 1046589, '2026-05-10 09:00:00', '2026-08-02 09:00:00', 54, 0, 0, '2025-10-24 09:00:00', '2025-10-24 09:00:00'),
(313, '01K2F2DKG03BC19FFN3ZQVGPNS', 'omar.ashworth313@example.com', 'omar.ashworth313@example.com', '2024-11-16 12:00:00', '44', '591665062', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-16 09:00:00', 'active', 'Omar', 'Ashworth', 'Omar Ashworth', 'https://cdn.livfinder.com/avatars/user-313.jpg', 2, 3, 'sqm', 'Europe/London', 1207, 1035186, '2026-06-02 09:00:00', '2026-08-09 09:00:00', 8, 0, 0, '2024-11-16 09:00:00', '2024-11-16 09:00:00'),
(314, '01K2F2DKG0Z5YJN4VRZ0GF86N1', 'fatima.bin-ahmed314@example.com', 'fatima.bin-ahmed314@example.com', '2026-05-14 12:00:00', '44', '685179171', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-14 09:00:00', 'active', 'Fatima', 'Bin Ahmed', 'Fatima Bin Ahmed', 'https://cdn.livfinder.com/avatars/user-314.jpg', 9, 18, 'sqm', 'Europe/London', 1225, 1153786, '2026-05-03 09:00:00', '2026-07-05 09:00:00', 60, 0, 1, '2026-05-14 09:00:00', '2026-05-14 09:00:00'),
(315, '01K2F2DKG0TWNJNAAGTY7RVYYN', 'ingrid.kapoor315@example.com', 'ingrid.kapoor315@example.com', '2024-11-23 12:00:00', '44', '720626517', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-11-23 09:00:00', 'active', 'Ingrid', 'Kapoor', 'Ingrid Kapoor', 'https://cdn.livfinder.com/avatars/user-315.jpg', 9, 11, 'sqm', 'Europe/London', 1199, 1104057, '2026-08-08 09:00:00', '2026-07-17 09:00:00', 25, 0, 1, '2024-11-23 09:00:00', '2024-11-23 09:00:00'),
(316, '01K2F2DKG0C9DN8G50PKWFAEWF', 'aisha.whitfield316@example.com', 'aisha.whitfield316@example.com', '2025-09-13 12:00:00', '971', '766570200', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-09-13 09:00:00', 'active', 'Aisha', 'Whitfield', 'Aisha Whitfield', 'https://cdn.livfinder.com/avatars/user-316.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-06-15 09:00:00', '2026-05-18 09:00:00', 37, 0, 1, '2025-09-13 09:00:00', '2025-09-13 09:00:00'),
(317, '01K2F2DKG0K3KVWW2B1Q0EZ65B', 'james.beaumont317@example.com', 'james.beaumont317@example.com', '2026-07-26 12:00:00', '44', '668994123', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-26 09:00:00', 'closed', 'James', 'Beaumont', 'James Beaumont', 'https://cdn.livfinder.com/avatars/user-317.jpg', 2, 14, 'sqm', 'Europe/London', 1039, 1017121, NULL, NULL, 43, 0, 1, '2026-07-26 09:00:00', '2026-07-26 09:00:00'),
(318, '01K2F2DKG0PNFBYMS8NRQMQWTK', 'vikram.sato318@example.com', 'vikram.sato318@example.com', '2026-07-18 12:00:00', '44', '620692600', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-07-18 09:00:00', 'active', 'Vikram', 'Sato', 'Vikram Sato', 'https://cdn.livfinder.com/avatars/user-318.jpg', 1, 22, 'sqm', 'Europe/London', 1219, 1106650, '2026-05-23 09:00:00', '2026-07-12 09:00:00', 32, 0, 1, '2026-07-18 09:00:00', '2026-07-18 09:00:00'),
(319, '01K2F2DKG0WR3FZK9SVN0J7Z6P', 'omar.kapoor319@example.com', 'omar.kapoor319@example.com', '2025-02-24 12:00:00', '44', '607840801', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-24 09:00:00', 'active', 'Omar', 'Kapoor', 'Omar Kapoor', 'https://cdn.livfinder.com/avatars/user-319.jpg', 9, 22, 'sqm', 'Europe/London', 1219, 1106650, '2026-08-14 09:00:00', '2026-05-11 09:00:00', 41, 0, 0, '2025-02-24 09:00:00', '2025-02-24 09:00:00'),
(320, '01K2F2DKG0T41B9MJQ34EZZMEP', 'omar.rahman320@example.com', 'omar.rahman320@example.com', '2025-12-22 12:00:00', '44', '703405399', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-12-22 09:00:00', 'active', 'Omar', 'Rahman', 'Omar Rahman', 'https://cdn.livfinder.com/avatars/user-320.jpg', 1, 18, 'sqm', 'Europe/London', 1225, 1153786, '2026-04-24 09:00:00', '2026-07-01 09:00:00', 25, 0, 1, '2025-12-22 09:00:00', '2025-12-22 09:00:00'),
(321, '01K2F2DKG0KMMW9DE0Y255PNWG', 'hassan.moretti321@example.com', 'hassan.moretti321@example.com', '2025-05-09 12:00:00', '44', '600363455', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-05-09 09:00:00', 'active', 'Hassan', 'Moretti', 'Hassan Moretti', 'https://cdn.livfinder.com/avatars/user-321.jpg', 8, 3, 'sqm', 'Europe/London', 1145, 1900000, '2026-05-16 09:00:00', '2026-04-19 09:00:00', 55, 0, 1, '2025-05-09 09:00:00', '2025-05-09 09:00:00'),
(322, '01K2F2DKG0N1D2Q4T47984GSNS', 'nikolai.halabi322@example.com', 'nikolai.halabi322@example.com', '2025-04-28 12:00:00', '44', '500380596', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-04-28 09:00:00', 'active', 'Nikolai', 'Halabi', 'Nikolai Halabi', 'https://cdn.livfinder.com/avatars/user-322.jpg', 1, 3, 'sqm', 'Europe/London', 1177, 1089101, '2026-06-06 09:00:00', '2026-04-22 09:00:00', 6, 0, 0, '2025-04-28 09:00:00', '2025-04-28 09:00:00'),
(323, '01K2F2DKG04Z7Q82A6ZKJS412J', 'isabella.rahman323@example.com', 'isabella.rahman323@example.com', '2026-05-10 12:00:00', '971', '632857482', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2026-05-10 09:00:00', 'active', 'Isabella', 'Rahman', 'Isabella Rahman', 'https://cdn.livfinder.com/avatars/user-323.jpg', 1, 1, 'sqft', 'Asia/Dubai', 1231, 1000032, '2026-05-02 09:00:00', '2026-08-07 09:00:00', 42, 0, 1, '2026-05-10 09:00:00', '2026-05-10 09:00:00'),
(324, '01K2F2DKG0P510TW54SCSSX45D', 'sarah.al-otaiba324@example.com', 'sarah.al-otaiba324@example.com', '2025-11-07 12:00:00', '44', '592533739', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-11-07 09:00:00', 'active', 'Sarah', 'Al Otaiba', 'Sarah Al Otaiba', 'https://cdn.livfinder.com/avatars/user-324.jpg', 2, 3, 'sqm', 'Europe/London', 1207, 1900001, '2026-08-14 09:00:00', '2026-06-22 09:00:00', 18, 0, 0, '2025-11-07 09:00:00', '2025-11-07 09:00:00'),
(325, '01K2F2DKG0618DRFNSFCJN8YE9', 'antoine.beaumont325@example.com', 'antoine.beaumont325@example.com', '2025-02-03 12:00:00', '44', '681418667', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-02-03 09:00:00', 'active', 'Antoine', 'Beaumont', 'Antoine Beaumont', 'https://cdn.livfinder.com/avatars/user-325.jpg', 1, 6, 'sqm', 'Europe/London', 1194, 1102874, '2026-07-07 09:00:00', '2026-07-16 09:00:00', 26, 0, 1, '2025-02-03 09:00:00', '2025-02-03 09:00:00'),
(326, '01K2F2DKG05DZYARX8BD61RKVQ', 'arjun.wong326@example.com', 'arjun.wong326@example.com', '2025-01-05 12:00:00', '44', '774715142', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2025-01-05 09:00:00', 'active', 'Arjun', 'Wong', 'Arjun Wong', 'https://cdn.livfinder.com/avatars/user-326.jpg', 1, 3, 'sqm', 'Europe/London', 1075, 1046589, '2026-05-17 09:00:00', '2026-05-11 09:00:00', 16, 0, 1, '2025-01-05 09:00:00', '2025-01-05 09:00:00'),
(327, '01K2F2DKG0M3FZPWXZMGY10S3W', 'rania.mercer327@example.com', 'rania.mercer327@example.com', '2024-09-22 12:00:00', '44', '631375588', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-22 09:00:00', 'active', 'Rania', 'Mercer', 'Rania Mercer', 'https://cdn.livfinder.com/avatars/user-327.jpg', 1, 2, 'sqft', 'Europe/London', 1233, 1121746, '2026-07-19 09:00:00', '2026-07-01 09:00:00', 17, 0, 1, '2024-09-22 09:00:00', '2024-09-22 09:00:00'),
(328, '01K2F2DKG0T71XVRMGPS52AS6A', 'rania.al-mansouri328@example.com', 'rania.al-mansouri328@example.com', '2024-09-30 12:00:00', '44', '534684892', '$2y$12$LQv3c1yqBw2LeFVXQ0jGaOZ8yQeK0mJZ1kQx8xY6vN9tR2sW4uP1e', '2024-09-30 09:00:00', 'active', 'Rania', 'Al Mansouri', 'Rania Al Mansouri', 'https://cdn.livfinder.com/avatars/user-328.jpg', 3, 3, 'sqm', 'Europe/London', 1075, 1046589, '2026-04-26 09:00:00', '2026-07-19 09:00:00', 22, 0, 1, '2024-09-30 09:00:00', '2024-09-30 09:00:00');

-- Platform staff roles.
INSERT INTO user_roles (user_id, role_id, granted_at) VALUES
(1, 1, '2025-10-21 09:00:00'),
(2, 2, '2025-10-21 09:00:00'),
(3, 3, '2025-10-21 09:00:00'),
(4, 3, '2025-10-21 09:00:00'),
(5, 4, '2025-10-21 09:00:00'),
(6, 4, '2025-10-21 09:00:00'),
(7, 5, '2025-10-21 09:00:00'),
(8, 6, '2025-10-21 09:00:00'),
(9, 6, '2025-10-21 09:00:00'),
(10, 7, '2025-10-21 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(1, '01K2F2DKG0BNXZ9DKAK9JZF6J9', 4, 11, 'Prime Properties', 'prime-properties', 'active', 'verified', '2023-11-06 09:00:00', 500, 100, 'billing@prime-properties.com', 2, 1233, '2023-10-30 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(1, '01K2F2DKG0E2JBN7CQ06WDPCM1', 1, 'agency', 'Prime Properties', 'Prime Properties LLC', 'prime-properties', 'Discretion, precision, and an unrivalled portfolio.', 'Prime Properties is a agency operating from Los Angeles, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/prime-properties.png', 'https://cdn.livfinder.com/covers/prime-properties.jpg', 'hello@prime-properties.com', '+971 4 404 6293', '+971 525707862', 'https://www.prime-properties.com', '81 Via Montenapoleone', 1233, 101416, 1120784, 50000615, '34.0522300', '-118.2436800', 2005, 162, 'active', 'verified', '2023-11-06 09:00:00', 1, 1, 21, 'Prime Properties — Luxury Properties in Los Angeles | Liv Finder', 'Browse Prime Properties''s portfolio of luxury listings in Los Angeles and beyond.', '2023-10-30 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(1, 'broker_license', 'BR-743242', 'National Regulator', 1233, '2023-11-07', '2028-02-11', 'valid', '2023-11-14 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(1, 'Prime Properties — Los Angeles HQ', 1, 'hello@prime-properties.com', '+971 4 645 1148', '60 Bahnhofstrasse', 1233, 1120784, 50000615, '34.0522300', '-118.2436800', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(1, 1, 'approved', 500, '2023-10-30 09:00:00', '2023-11-02 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(1, 6, 'requested', '2026-08-10 09:00:00', 11);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(1, 1120784, 1),
(1, 50000615, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(1, 11, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-10-30 09:00:00'),
(1, 12, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-02-24 09:00:00'),
(1, 13, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-02-13 09:00:00'),
(1, 14, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-02-14 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(1, '01K2F2DKG0MSXXAYX59B702Y9S', 11, 1, 'Vikram', 'Ferrari', 'Vikram Ferrari', 'vikram-ferrari-1', 'Managing Director', 'Vikram specialises in Los Angeles and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/vikram-ferrari-1.jpg', 'vikram.ferrari@prime-properties.com', '+971 4 400 4614', '+971 553998065', 'BRN-52907', '2028-02-24', 19, 1233, 1120784, 'active', 'verified', '2023-11-19 09:00:00', 1, 0, '2023-12-07', 'Vikram Ferrari — Managing Director at Prime Properties', '2023-10-30 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(1, 1, 'native'),
(1, 8, 'fluent'),
(1, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(1, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(1, 1120784, 1),
(1, 50000615, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(2, '01K2F2DKG0QMVZJ02D59AT5JQ9', 12, 1, 'Antoine', 'Hussein', 'Antoine Hussein', 'antoine-hussein-2', 'Sales Manager', 'Antoine specialises in Los Angeles and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/antoine-hussein-2.jpg', 'antoine.hussein@prime-properties.com', '+971 4 540 9332', '+971 555911530', 'BRN-33883', '2027-09-25', 4, 1233, 1120784, 'active', 'verified', '2023-11-19 09:00:00', 1, 0, '2024-04-14', 'Antoine Hussein — Sales Manager at Prime Properties', '2023-10-30 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(2, 1, 'native'),
(2, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(2, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(2, 1120784, 1),
(2, 50000615, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(3, '01K2F2DKG0FNZPVAZVXTWFZS6Z', 13, 1, 'Layla', 'Al Suwaidi', 'Layla Al Suwaidi', 'layla-al-suwaidi-3', 'Senior Consultant', 'Layla specialises in Los Angeles and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/layla-al-suwaidi-3.jpg', 'layla.al-suwaidi@prime-properties.com', '+971 4 448 9074', '+971 549567397', 'BRN-78328', '2027-12-16', 9, 1233, 1120784, 'active', 'verified', '2023-11-19 09:00:00', 1, 0, '2024-05-09', 'Layla Al Suwaidi — Senior Consultant at Prime Properties', '2023-10-30 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(3, 1, 'native'),
(3, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(3, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(3, 1120784, 1),
(3, 50000615, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(2, '01K2F2DKG08WM6710W8KBE3RGS', 3, 15, 'Luxhabitat Real Estate', 'luxhabitat-real-estate', 'active', 'verified', '2023-04-02 09:00:00', 50, 3, 'billing@luxhabitat-real-estate.com', 4, 1232, '2023-03-26 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(2, '01K2F2DKG0TFFXMKXZXMCTHAGW', 2, 'agency', 'Luxhabitat Real Estate', 'Luxhabitat Real Estate LLC', 'luxhabitat-real-estate', 'Curating the finest addresses since day one.', 'Luxhabitat Real Estate is a agency operating from London, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/luxhabitat-real-estate.png', 'https://cdn.livfinder.com/covers/luxhabitat-real-estate.jpg', 'hello@luxhabitat-real-estate.com', '+971 4 454 7354', '+971 530926729', 'https://www.luxhabitat-real-estate.com', '3 Al Khail Road', 1232, 102357, 1050388, 50000244, '51.5085300', '-0.1257400', 2020, 143, 'active', 'verified', '2023-04-02 09:00:00', 1, 1, 37, 'Luxhabitat Real Estate — Luxury Real Estate in London | Liv Finder', 'Browse Luxhabitat Real Estate''s portfolio of luxury listings in London and beyond.', '2023-03-26 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(2, 'broker_license', 'BR-129914', 'National Regulator', 1232, '2023-04-03', '2027-04-25', 'valid', '2023-04-10 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(2, 'Luxhabitat Real Estate — London HQ', 1, 'hello@luxhabitat-real-estate.com', '+971 4 459 5119', '89 Avenue Montaigne', 1232, 1050388, 50000244, '51.5085300', '-0.1257400', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(2, 1, 'approved', 50, '2023-03-26 09:00:00', '2023-03-29 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(2, 1050388, 1),
(2, 50000244, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(2, 15, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-03-26 09:00:00'),
(2, 16, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-12-06 09:00:00'),
(2, 17, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-11-28 09:00:00'),
(2, 18, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-11-25 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(4, '01K2F2DKG08VNK3EYHZX3SFJGJ', 15, 2, 'Lucas', 'Petrova', 'Lucas Petrova', 'lucas-petrova-4', 'Managing Director', 'Lucas specialises in London and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/lucas-petrova-4.jpg', 'lucas.petrova@luxhabitat-real-estate.com', '+971 4 707 3668', '+971 556360130', 'BRN-30263', '2027-06-03', 25, 1232, 1050388, 'active', 'verified', '2023-04-15 09:00:00', 1, 0, '2023-06-24', 'Lucas Petrova — Managing Director at Luxhabitat Real Estate', '2023-03-26 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(4, 1, 'native'),
(4, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(4, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(4, 1050388, 1),
(4, 50000244, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(5, '01K2F2DKG0GPB7FN54F4N8WB4F', 16, 2, 'Rashid', 'Sato', 'Rashid Sato', 'rashid-sato-5', 'Sales Manager', 'Rashid specialises in London and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rashid-sato-5.jpg', 'rashid.sato@luxhabitat-real-estate.com', '+971 4 410 7444', '+971 521476980', 'BRN-40371', '2027-04-22', 18, 1232, 1050388, 'active', 'verified', '2023-04-15 09:00:00', 1, 0, '2023-10-09', 'Rashid Sato — Sales Manager at Luxhabitat Real Estate', '2023-03-26 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(5, 1, 'native'),
(5, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(5, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(5, 1050388, 1),
(5, 50000244, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(6, '01K2F2DKG0XXBJRQVGBRFRYDHZ', 17, 2, 'Diego', 'Ivanov', 'Diego Ivanov', 'diego-ivanov-6', 'Senior Consultant', 'Diego specialises in London and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/diego-ivanov-6.jpg', 'diego.ivanov@luxhabitat-real-estate.com', '+971 4 607 8001', '+971 529949499', 'BRN-20816', '2027-10-29', 5, 1232, 1050388, 'active', 'verified', '2023-04-15 09:00:00', 1, 0, '2023-06-22', 'Diego Ivanov — Senior Consultant at Luxhabitat Real Estate', '2023-03-26 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(6, 1, 'native'),
(6, 3, 'fluent'),
(6, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(6, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(6, 1050388, 1),
(6, 50000244, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(3, '01K2F2DKG09DH88E4YQF4E9SYN', 3, 19, 'Driven Estates', 'driven-estates', 'active', 'verified', '2022-10-22 09:00:00', 50, 3, 'billing@driven-estates.com', 2, 1233, '2022-10-15 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(3, '01K2F2DKG0HQ7YJB568QJ5ZR71', 3, 'brokerage', 'Driven Estates', 'Driven Estates LLC', 'driven-estates', 'Discretion, precision, and an unrivalled portfolio.', 'Driven Estates is a brokerage operating from Miami, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/driven-estates.png', 'https://cdn.livfinder.com/covers/driven-estates.jpg', 'hello@driven-estates.com', '+971 4 334 6952', '+971 524631723', 'https://www.driven-estates.com', '66 Al Sufouh Road', 1233, 101436, 1121746, 50000579, '25.7742700', '-80.1936600', 2011, 246, 'active', 'verified', '2022-10-22 09:00:00', 1, 1, 76, 'Driven Estates — Luxury Estates in Miami | Liv Finder', 'Browse Driven Estates''s portfolio of luxury listings in Miami and beyond.', '2022-10-15 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(3, 'broker_license', 'BR-391733', 'National Regulator', 1233, '2022-10-23', '2028-08-25', 'valid', '2022-10-30 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(3, 'Driven Estates — Miami HQ', 1, 'hello@driven-estates.com', '+971 4 491 7332', '79 Jumeirah Beach Road', 1233, 1121746, 50000579, '25.7742700', '-80.1936600', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(3, 1, 'approved', 50, '2022-10-15 09:00:00', '2022-10-18 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(3, 1121746, 1),
(3, 50000579, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(3, 19, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2022-10-15 09:00:00'),
(3, 20, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-01-16 09:00:00'),
(3, 21, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-05-09 09:00:00'),
(3, 22, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-01-08 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(7, '01K2F2DKG0D78DMM33NMYZQG7J', 19, 3, 'Lucas', 'Ivanov', 'Lucas Ivanov', 'lucas-ivanov-7', 'Managing Director', 'Lucas specialises in Miami and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/lucas-ivanov-7.jpg', 'lucas.ivanov@driven-estates.com', '+971 4 394 1748', '+971 550796163', 'BRN-10143', '2027-06-11', 19, 1233, 1121746, 'active', 'verified', '2022-11-04 09:00:00', 1, 0, '2023-05-01', 'Lucas Ivanov — Managing Director at Driven Estates', '2022-10-15 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(7, 1, 'native'),
(7, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(7, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(7, 1121746, 1),
(7, 50000579, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(8, '01K2F2DKG096GN4466ZYYZ171N', 20, 3, 'Daniel', 'Al Otaiba', 'Daniel Al Otaiba', 'daniel-al-otaiba-8', 'Sales Manager', 'Daniel specialises in Miami and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/daniel-al-otaiba-8.jpg', 'daniel.al-otaiba@driven-estates.com', '+971 4 499 6961', '+971 537035029', 'BRN-78995', '2027-07-21', 22, 1233, 1121746, 'active', 'verified', '2022-11-04 09:00:00', 1, 1, '2023-02-17', 'Daniel Al Otaiba — Sales Manager at Driven Estates', '2022-10-15 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(8, 1, 'native'),
(8, 5, 'fluent'),
(8, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(8, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(8, 1121746, 1),
(8, 50000579, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(9, '01K2F2DKG0BKQ98203540TTHSH', 21, 3, 'Olivia', 'Karim', 'Olivia Karim', 'olivia-karim-9', 'Senior Consultant', 'Olivia specialises in Miami and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/olivia-karim-9.jpg', 'olivia.karim@driven-estates.com', '+971 4 736 3813', '+971 514959527', 'BRN-34842', '2028-07-08', 16, 1233, 1121746, 'active', 'verified', '2022-11-04 09:00:00', 1, 0, '2023-03-12', 'Olivia Karim — Senior Consultant at Driven Estates', '2022-10-15 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(9, 1, 'native'),
(9, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(9, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(9, 1121746, 1),
(9, 50000579, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(4, '01K2F2DKG0N239Y31N1ZCXBG3N', 4, 23, 'Sotheby''s International Motors', 'sotheby-s-international-motors', 'active', 'verified', '2023-12-14 09:00:00', 500, 100, 'billing@sotheby-s-international-motors.com', 6, 1194, '2023-12-07 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(4, '01K2F2DKG0BK2GEGT5A86ZMREG', 4, 'dealership', 'Sotheby''s International Motors', 'Sotheby''s International Motors LLC', 'sotheby-s-international-motors', 'Curating the finest addresses since day one.', 'Sotheby''s International Motors is a dealership operating from Jeddah, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/sotheby-s-international-motors.png', 'https://cdn.livfinder.com/covers/sotheby-s-international-motors.jpg', 'hello@sotheby-s-international-motors.com', '+971 4 570 7794', '+971 538705961', 'https://www.sotheby-s-international-motors.com', '46 Collins Avenue', 1194, 102850, 1102858, 50000178, '21.5423800', '39.1979700', 2014, 63, 'active', 'verified', '2023-12-14 09:00:00', 1, 1, 15, 'Sotheby''s International Motors — Luxury Motors in Jeddah | Liv Finder', 'Browse Sotheby''s International Motors''s portfolio of luxury listings in Jeddah and beyond.', '2023-12-07 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(4, 'broker_license', 'BR-551910', 'National Regulator', 1194, '2023-12-15', '2027-01-18', 'valid', '2023-12-22 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(4, 'Sotheby''s International Motors — Jeddah HQ', 1, 'hello@sotheby-s-international-motors.com', '+971 4 249 3600', '43 Bahnhofstrasse', 1194, 1102858, 50000178, '21.5423800', '39.1979700', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(4, 2, 'approved', 500, '2023-12-07 09:00:00', '2023-12-10 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(4, 6, 'requested', '2026-08-01 09:00:00', 23);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(4, 1102858, 1),
(4, 50000178, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(4, 23, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-12-07 09:00:00'),
(4, 24, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-01-17 09:00:00'),
(4, 25, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-12-22 09:00:00'),
(4, 26, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-05-25 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(10, '01K2F2DKG04M6B9GXE41NHBYVC', 23, 4, 'Hassan', 'Fairfax', 'Hassan Fairfax', 'hassan-fairfax-10', 'Managing Director', 'Hassan specialises in Jeddah and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/hassan-fairfax-10.jpg', 'hassan.fairfax@sotheby-s-international-motors.com', '+971 4 695 3655', '+971 540191283', 'BRN-64688', '2027-12-19', 13, 1194, 1102858, 'active', 'verified', '2023-12-27 09:00:00', 1, 1, '2024-01-08', 'Hassan Fairfax — Managing Director at Sotheby''s International Motors', '2023-12-07 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(10, 1, 'native'),
(10, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(10, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(10, 1102858, 1),
(10, 50000178, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(11, '01K2F2DKG0M1Y7SCS1EE93HYA2', 24, 4, 'Theo', 'Darwish', 'Theo Darwish', 'theo-darwish-11', 'Sales Manager', 'Theo specialises in Jeddah and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/theo-darwish-11.jpg', 'theo.darwish@sotheby-s-international-motors.com', '+971 4 466 8075', '+971 544815075', 'BRN-20505', '2027-09-05', 10, 1194, 1102858, 'active', 'verified', '2023-12-27 09:00:00', 1, 0, '2024-03-19', 'Theo Darwish — Sales Manager at Sotheby''s International Motors', '2023-12-07 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(11, 1, 'native'),
(11, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(11, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(11, 1102858, 1),
(11, 50000178, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(12, '01K2F2DKG0BDASP3XB9XWFT8YS', 25, 4, 'Anastasia', 'Rossi', 'Anastasia Rossi', 'anastasia-rossi-12', 'Senior Consultant', 'Anastasia specialises in Jeddah and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/anastasia-rossi-12.jpg', 'anastasia.rossi@sotheby-s-international-motors.com', '+971 4 386 2897', '+971 556860393', 'BRN-71997', '2026-10-14', 17, 1194, 1102858, 'active', 'verified', '2023-12-27 09:00:00', 1, 0, '2024-03-28', 'Anastasia Rossi — Senior Consultant at Sotheby''s International Motors', '2023-12-07 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(12, 1, 'native'),
(12, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(12, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(12, 1102858, 1),
(12, 50000178, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(5, '01K2F2DKG051NN7CCXZ5J0MFB4', 3, 27, 'Christie''s International Automotive', 'christie-s-international-automotive', 'active', 'verified', '2023-07-16 09:00:00', 50, 3, 'billing@christie-s-international-automotive.com', 3, 1145, '2023-07-09 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(5, '01K2F2DKG0N95N3W9KYCEWBZFV', 5, 'dealership', 'Christie''s International Automotive', 'Christie''s International Automotive LLC', 'christie-s-international-automotive', 'Curating the finest addresses since day one.', 'Christie''s International Automotive is a dealership operating from Monaco, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/christie-s-international-automotive.png', 'https://cdn.livfinder.com/covers/christie-s-international-automotive.jpg', 'hello@christie-s-international-automotive.com', '+971 4 805 4436', '+971 544063133', 'https://www.christie-s-international-automotive.com', '63 Avenue Montaigne', 1145, NULL, 1900000, 50000279, '43.7384000', '7.4246000', 2007, 119, 'active', 'verified', '2023-07-16 09:00:00', 1, 1, 139, 'Christie''s International Automotive — Luxury Automotive in Monaco | Liv Finder', 'Browse Christie''s International Automotive''s portfolio of luxury listings in Monaco and beyond.', '2023-07-09 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(5, 'broker_license', 'BR-406498', 'National Regulator', 1145, '2023-07-17', '2027-07-06', 'valid', '2023-07-24 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(5, 'Christie''s International Automotive — Monaco HQ', 1, 'hello@christie-s-international-automotive.com', '+971 4 514 3824', '62 Via Montenapoleone', 1145, 1900000, 50000279, '43.7384000', '7.4246000', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(5, 2, 'approved', 50, '2023-07-09 09:00:00', '2023-07-12 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(5, 1900000, 1),
(5, 50000279, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(5, 27, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-07-09 09:00:00'),
(5, 28, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-09-28 09:00:00'),
(5, 29, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-12-26 09:00:00'),
(5, 30, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-11-21 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(13, '01K2F2DKG0ZCZREKD8QT8PBZGM', 27, 5, 'Farah', 'Herrera', 'Farah Herrera', 'farah-herrera-13', 'Managing Director', 'Farah specialises in Monaco and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/farah-herrera-13.jpg', 'farah.herrera@christie-s-international-automotive.com', '+971 4 426 8186', '+971 536409325', 'BRN-31276', '2026-12-19', 15, 1145, 1900000, 'active', 'verified', '2023-07-29 09:00:00', 1, 0, '2023-07-28', 'Farah Herrera — Managing Director at Christie''s International Automotive', '2023-07-09 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(13, 1, 'native'),
(13, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(13, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(13, 1900000, 1),
(13, 50000279, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(14, '01K2F2DKG0RGHEVYG5F7JPYJFH', 28, 5, 'Maximilian', 'Moreau', 'Maximilian Moreau', 'maximilian-moreau-14', 'Sales Manager', 'Maximilian specialises in Monaco and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/maximilian-moreau-14.jpg', 'maximilian.moreau@christie-s-international-automotive.com', '+971 4 604 5455', '+971 526240515', 'BRN-52504', '2028-06-17', 6, 1145, 1900000, 'active', 'verified', '2023-07-29 09:00:00', 1, 0, '2023-10-28', 'Maximilian Moreau — Sales Manager at Christie''s International Automotive', '2023-07-09 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(14, 1, 'native'),
(14, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(14, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(14, 1900000, 1),
(14, 50000279, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(15, '01K2F2DKG0XHN33SRBDQVNQCSB', 29, 5, 'Aisha', 'Fairfax', 'Aisha Fairfax', 'aisha-fairfax-15', 'Senior Consultant', 'Aisha specialises in Monaco and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/aisha-fairfax-15.jpg', 'aisha.fairfax@christie-s-international-automotive.com', '+971 4 570 6630', '+971 535238429', 'BRN-37974', '2027-01-17', 24, 1145, 1900000, 'active', 'verified', '2023-07-29 09:00:00', 1, 0, '2023-10-18', 'Aisha Fairfax — Senior Consultant at Christie''s International Automotive', '2023-07-09 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(15, 1, 'native'),
(15, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(15, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(15, 1900000, 1),
(15, 50000279, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(6, '01K2F2DKG041MZPT1WTK3FH53A', 3, 31, 'Knight Yachts', 'knight-yachts', 'active', 'verified', '2026-02-04 09:00:00', 50, 3, 'billing@knight-yachts.com', 3, 1075, '2026-01-28 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(6, '01K2F2DKG0BZ46RC1WBYTB5PXB', 6, 'yacht_broker', 'Knight Yachts', 'Knight Yachts LLC', 'knight-yachts', 'Where exceptional assets meet exceptional clients.', 'Knight Yachts is a yacht broker operating from Saint-Tropez, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/knight-yachts.png', 'https://cdn.livfinder.com/covers/knight-yachts.jpg', 'hello@knight-yachts.com', '+971 4 212 4034', '+971 535982217', 'https://www.knight-yachts.com', '51 Marina Walk', 1075, 105051, 1046589, 50000311, '43.2676400', '6.6404900', 2007, 196, 'active', 'verified', '2026-02-04 09:00:00', 1, 1, 122, 'Knight Yachts — Luxury Yachts in Saint-Tropez | Liv Finder', 'Browse Knight Yachts''s portfolio of luxury listings in Saint-Tropez and beyond.', '2026-01-28 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(6, 'broker_license', 'BR-301616', 'National Regulator', 1075, '2026-02-05', '2026-12-15', 'valid', '2026-02-12 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(6, 'Knight Yachts — Saint-Tropez HQ', 1, 'hello@knight-yachts.com', '+971 4 286 1581', '34 Via Montenapoleone', 1075, 1046589, 50000311, '43.2676400', '6.6404900', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(6, 3, 'approved', 50, '2026-01-28 09:00:00', '2026-01-31 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(6, 1046589, 1),
(6, 50000311, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(6, 31, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2026-01-28 09:00:00'),
(6, 32, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2026-02-02 09:00:00'),
(6, 33, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2026-11-04 09:00:00'),
(6, 34, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2026-11-19 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(16, '01K2F2DKG008A3JYRHE9T337VV', 31, 6, 'Mohammed', 'Rossellini', 'Mohammed Rossellini', 'mohammed-rossellini-16', 'Managing Director', 'Mohammed specialises in Saint-Tropez and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/mohammed-rossellini-16.jpg', 'mohammed.rossellini@knight-yachts.com', '+971 4 595 1632', '+971 535209923', 'BRN-33837', '2028-04-18', 10, 1075, 1046589, 'active', 'verified', '2026-02-17 09:00:00', 1, 1, '2026-03-09', 'Mohammed Rossellini — Managing Director at Knight Yachts', '2026-01-28 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(16, 1, 'native'),
(16, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(16, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(16, 1046589, 1),
(16, 50000311, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(17, '01K2F2DKG0Z8F3RY66802VDBT5', 32, 6, 'Zainab', 'Darwish', 'Zainab Darwish', 'zainab-darwish-17', 'Sales Manager', 'Zainab specialises in Saint-Tropez and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/zainab-darwish-17.jpg', 'zainab.darwish@knight-yachts.com', '+971 4 284 8374', '+971 555236183', 'BRN-61709', '2027-09-26', 13, 1075, 1046589, 'active', 'verified', '2026-02-17 09:00:00', 1, 1, '2026-08-02', 'Zainab Darwish — Sales Manager at Knight Yachts', '2026-01-28 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(17, 1, 'native'),
(17, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(17, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(17, 1046589, 1),
(17, 50000311, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(18, '01K2F2DKG0Q9EFBRNMRM889SXT', 33, 6, 'Rafael', 'Von Habsburg', 'Rafael Von Habsburg', 'rafael-von-habsburg-18', 'Senior Consultant', 'Rafael specialises in Saint-Tropez and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rafael-von-habsburg-18.jpg', 'rafael.von-habsburg@knight-yachts.com', '+971 4 787 4127', '+971 528210467', 'BRN-48340', '2028-02-14', 7, 1075, 1046589, 'active', 'verified', '2026-02-17 09:00:00', 1, 0, '2026-02-11', 'Rafael Von Habsburg — Senior Consultant at Knight Yachts', '2026-01-28 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(18, 1, 'native'),
(18, 6, 'fluent'),
(18, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(18, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(18, 1046589, 1),
(18, 50000311, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(7, '01K2F2DKG0RCRN62HD6F9NWE23', 4, 35, 'Halcyon Marine', 'halcyon-marine', 'active', 'verified', '2024-02-01 09:00:00', 500, 100, 'billing@halcyon-marine.com', 1, 1231, '2024-01-25 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(7, '01K2F2DKG0RZM9T2E1K0K4Z3MC', 7, 'yacht_broker', 'Halcyon Marine', 'Halcyon Marine LLC', 'halcyon-marine', 'A boutique practice with a global reach.', 'Halcyon Marine is a yacht broker operating from Dubai, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/halcyon-marine.png', 'https://cdn.livfinder.com/covers/halcyon-marine.jpg', 'hello@halcyon-marine.com', '+971 4 885 8046', '+971 557532391', 'https://www.halcyon-marine.com', '11 Bahnhofstrasse', 1231, 103391, 1000032, 50000071, '25.0657000', '55.1712800', 2003, 49, 'active', 'verified', '2024-02-01 09:00:00', 1, 1, 55, 'Halcyon Marine — Luxury Marine in Dubai | Liv Finder', 'Browse Halcyon Marine''s portfolio of luxury listings in Dubai and beyond.', '2024-01-25 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(7, 'rera', '38332', 'Dubai Land Department', 1231, '2024-02-04', '2027-01-25', 'valid', '2024-02-08 09:00:00'),
(7, 'trade_license', 'CN-6569312', 'Dubai Department of Economy and Tourism', 1231, '2024-01-30', '2027-12-13', 'valid', '2024-02-06 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(7, 'Halcyon Marine — Dubai HQ', 1, 'hello@halcyon-marine.com', '+971 4 233 7118', '11 The Crescent', 1231, 1000032, 50000071, '25.0657000', '55.1712800', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(7, 3, 'approved', 500, '2024-01-25 09:00:00', '2024-01-28 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(7, 2, 'requested', '2026-08-13 09:00:00', 35);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(7, 1000032, 1),
(7, 50000071, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(7, 35, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-01-25 09:00:00'),
(7, 36, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-04-20 09:00:00'),
(7, 37, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-04-20 09:00:00'),
(7, 38, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-04-05 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(19, '01K2F2DKG06GRE5X7K06QYYEXK', 35, 7, 'Karim', 'Sharma', 'Karim Sharma', 'karim-sharma-19', 'Managing Director', 'Karim specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/karim-sharma-19.jpg', 'karim.sharma@halcyon-marine.com', '+971 4 335 8330', '+971 519995194', 'BRN-25268', '2027-07-06', 4, 1231, 1000032, 'active', 'verified', '2024-02-14 09:00:00', 1, 0, '2024-01-28', 'Karim Sharma — Managing Director at Halcyon Marine', '2024-01-25 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(19, 1, 'native'),
(19, 4, 'fluent'),
(19, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(19, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(19, 1000032, 1),
(19, 50000071, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(20, '01K2F2DKG01X6CEFN3CVEQGY1P', 36, 7, 'Mohammed', 'Meyer', 'Mohammed Meyer', 'mohammed-meyer-20', 'Sales Manager', 'Mohammed specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/mohammed-meyer-20.jpg', 'mohammed.meyer@halcyon-marine.com', '+971 4 564 1319', '+971 518914600', 'BRN-69084', '2027-12-23', 4, 1231, 1000032, 'active', 'verified', '2024-02-14 09:00:00', 1, 0, '2024-08-09', 'Mohammed Meyer — Sales Manager at Halcyon Marine', '2024-01-25 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(20, 1, 'native'),
(20, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(20, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(20, 1000032, 1),
(20, 50000071, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(21, '01K2F2DKG0ZP56NSREP0WTHC9D', 37, 7, 'Fatima', 'Herrera', 'Fatima Herrera', 'fatima-herrera-21', 'Senior Consultant', 'Fatima specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/fatima-herrera-21.jpg', 'fatima.herrera@halcyon-marine.com', '+971 4 340 3457', '+971 519275802', 'BRN-44655', '2027-03-07', 4, 1231, 1000032, 'active', 'verified', '2024-02-14 09:00:00', 1, 0, '2024-01-30', 'Fatima Herrera — Senior Consultant at Halcyon Marine', '2024-01-25 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(21, 1, 'native'),
(21, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(21, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(21, 1000032, 1),
(21, 50000071, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(8, '01K2F2DKG0NGXJ60FYJ5CXEP3M', 3, 39, 'Aurum Aviation', 'aurum-aviation', 'active', 'verified', '2025-03-31 09:00:00', 50, 3, 'billing@aurum-aviation.com', 13, 1014, '2025-03-24 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(8, '01K2F2DKG0ZSDVA82T04X3XT9W', 8, 'aviation_broker', 'Aurum Aviation', 'Aurum Aviation LLC', 'aurum-aviation', 'A boutique practice with a global reach.', 'Aurum Aviation is a aviation broker operating from Sydney, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/aurum-aviation.png', 'https://cdn.livfinder.com/covers/aurum-aviation.jpg', 'hello@aurum-aviation.com', '+971 4 651 1749', '+971 541273202', 'https://www.aurum-aviation.com', '49 Via Montenapoleone', 1014, 103909, 1007408, 50000774, '-33.8678500', '151.2073200', 2010, 29, 'active', 'verified', '2025-03-31 09:00:00', 1, 1, 148, 'Aurum Aviation — Luxury Aviation in Sydney | Liv Finder', 'Browse Aurum Aviation''s portfolio of luxury listings in Sydney and beyond.', '2025-03-24 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(8, 'broker_license', 'BR-677570', 'National Regulator', 1014, '2025-04-01', '2026-12-04', 'valid', '2025-04-08 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(8, 'Aurum Aviation — Sydney HQ', 1, 'hello@aurum-aviation.com', '+971 4 394 9302', '13 Al Sufouh Road', 1014, 1007408, 50000774, '-33.8678500', '151.2073200', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(8, 4, 'approved', 50, '2025-03-24 09:00:00', '2025-03-27 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(8, 3, 'requested', '2026-08-08 09:00:00', 39);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(8, 1007408, 1),
(8, 50000774, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(8, 39, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2025-03-24 09:00:00'),
(8, 40, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-08-19 09:00:00'),
(8, 41, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-07-06 09:00:00'),
(8, 42, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-04-29 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(22, '01K2F2DKG06SEP4SB8K1PWHPHP', 39, 8, 'Alexander', 'Moretti', 'Alexander Moretti', 'alexander-moretti-22', 'Managing Director', 'Alexander specialises in Sydney and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/alexander-moretti-22.jpg', 'alexander.moretti@aurum-aviation.com', '+971 4 780 6311', '+971 552280322', 'BRN-22652', '2028-03-29', 4, 1014, 1007408, 'active', 'verified', '2025-04-13 09:00:00', 1, 0, '2025-07-11', 'Alexander Moretti — Managing Director at Aurum Aviation', '2025-03-24 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(22, 1, 'native'),
(22, 5, 'fluent'),
(22, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(22, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(22, 1007408, 1),
(22, 50000774, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(23, '01K2F2DKG0YPM313R4HB5WVMQW', 40, 8, 'Vikram', 'Nasser', 'Vikram Nasser', 'vikram-nasser-23', 'Sales Manager', 'Vikram specialises in Sydney and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/vikram-nasser-23.jpg', 'vikram.nasser@aurum-aviation.com', '+971 4 744 5984', '+971 534276263', 'BRN-39347', '2027-04-25', 16, 1014, 1007408, 'active', 'verified', '2025-04-13 09:00:00', 1, 0, '2025-05-03', 'Vikram Nasser — Sales Manager at Aurum Aviation', '2025-03-24 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(23, 1, 'native'),
(23, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(23, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(23, 1007408, 1),
(23, 50000774, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(24, '01K2F2DKG03SP0K50EZTSEEJ7E', 41, 8, 'Henry', 'Wong', 'Henry Wong', 'henry-wong-24', 'Senior Consultant', 'Henry specialises in Sydney and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/henry-wong-24.jpg', 'henry.wong@aurum-aviation.com', '+971 4 290 7261', '+971 549446074', 'BRN-42436', '2026-11-02', 4, 1014, 1007408, 'active', 'verified', '2025-04-13 09:00:00', 1, 0, '2025-05-16', 'Henry Wong — Senior Consultant at Aurum Aviation', '2025-03-24 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(24, 1, 'native'),
(24, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(24, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(24, 1007408, 1),
(24, 50000774, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(9, '01K2F2DKG094MCQQ1YJSQXDYZ2', 3, 43, 'Meridian Timepieces', 'meridian-timepieces', 'active', 'verified', '2023-06-17 09:00:00', 50, 3, 'billing@meridian-timepieces.com', 12, 1098, '2023-06-10 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(9, '01K2F2DKG04DQ0528Q8KWSXFP8', 9, 'watch_dealer', 'Meridian Timepieces', 'Meridian Timepieces LLC', 'meridian-timepieces', 'Curating the finest addresses since day one.', 'Meridian Timepieces is a watch dealer operating from Hong Kong, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/meridian-timepieces.png', 'https://cdn.livfinder.com/covers/meridian-timepieces.jpg', 'hello@meridian-timepieces.com', '+971 4 477 6479', '+971 518040059', 'https://www.meridian-timepieces.com', '75 Avenue Montaigne', 1098, NULL, 1900005, 50000729, '22.3193000', '114.1694000', 2007, 252, 'active', 'verified', '2023-06-17 09:00:00', 1, 0, 97, 'Meridian Timepieces — Luxury Timepieces in Hong Kong | Liv Finder', 'Browse Meridian Timepieces''s portfolio of luxury listings in Hong Kong and beyond.', '2023-06-10 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(9, 'broker_license', 'BR-422122', 'National Regulator', 1098, '2023-06-18', '2028-08-24', 'valid', '2023-06-25 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(9, 'Meridian Timepieces — Hong Kong HQ', 1, 'hello@meridian-timepieces.com', '+971 4 276 5586', '5 The Crescent', 1098, 1900005, 50000729, '22.3193000', '114.1694000', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(9, 6, 'approved', 50, '2023-06-10 09:00:00', '2023-06-13 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(9, 5, 'requested', '2026-07-23 09:00:00', 43);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(9, 1900005, 1),
(9, 50000729, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(9, 43, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-06-10 09:00:00'),
(9, 44, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-01-13 09:00:00'),
(9, 45, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-06-26 09:00:00'),
(9, 46, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-02-15 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(25, '01K2F2DKG05CTJCBK3YYJ7K71G', 43, 9, 'Rashid', 'Nasser', 'Rashid Nasser', 'rashid-nasser-25', 'Managing Director', 'Rashid specialises in Hong Kong and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rashid-nasser-25.jpg', 'rashid.nasser@meridian-timepieces.com', '+971 4 617 6587', '+971 542739780', 'BRN-30062', '2027-11-23', 12, 1098, 1900005, 'active', 'verified', '2023-06-30 09:00:00', 1, 1, '2023-09-02', 'Rashid Nasser — Managing Director at Meridian Timepieces', '2023-06-10 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(25, 1, 'native'),
(25, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(25, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(25, 1900005, 1),
(25, 50000729, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(26, '01K2F2DKG00279Z876ZQE0EGDQ', 44, 9, 'Tariq', 'Königsberg', 'Tariq Königsberg', 'tariq-konigsberg-26', 'Sales Manager', 'Tariq specialises in Hong Kong and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/tariq-konigsberg-26.jpg', 'tariq.konigsberg@meridian-timepieces.com', '+971 4 863 7593', '+971 527868550', 'BRN-16660', '2026-11-23', 3, 1098, 1900005, 'active', 'verified', '2023-06-30 09:00:00', 1, 0, '2023-10-23', 'Tariq Königsberg — Sales Manager at Meridian Timepieces', '2023-06-10 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(26, 1, 'native'),
(26, 9, 'fluent'),
(26, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(26, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(26, 1900005, 1),
(26, 50000729, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(27, '01K2F2DKG0WWK71G05RZWMV47S', 45, 9, 'Vikram', 'Sato', 'Vikram Sato', 'vikram-sato-27', 'Senior Consultant', 'Vikram specialises in Hong Kong and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/vikram-sato-27.jpg', 'vikram.sato@meridian-timepieces.com', '+971 4 852 5498', '+971 537474213', 'BRN-25968', '2028-01-24', 22, 1098, 1900005, 'active', 'verified', '2023-06-30 09:00:00', 1, 0, '2023-09-06', 'Vikram Sato — Senior Consultant at Meridian Timepieces', '2023-06-10 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(27, 1, 'native'),
(27, 3, 'fluent'),
(27, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(27, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(27, 1900005, 1),
(27, 50000729, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(10, '01K2F2DKG0F54459DJNGKMK2P3', 4, 47, 'Blackstone Development', 'blackstone-development', 'active', 'verified', '2024-12-07 09:00:00', 500, 100, 'billing@blackstone-development.com', 3, 1177, '2024-11-30 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(10, '01K2F2DKG02V99XVQZZB09W3WQ', 10, 'developer', 'Blackstone Development', 'Blackstone Development LLC', 'blackstone-development', 'Discretion, precision, and an unrivalled portfolio.', 'Blackstone Development is a developer operating from Lisbon, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/blackstone-development.png', 'https://cdn.livfinder.com/covers/blackstone-development.jpg', 'hello@blackstone-development.com', '+971 4 413 1352', '+971 552456408', 'https://www.blackstone-development.com', '17 Worth Avenue', 1177, 102228, 1089245, 50000426, '38.7263500', '-9.1484300', 2019, 182, 'active', 'verified', '2024-12-07 09:00:00', 1, 0, 23, 'Blackstone Development — Luxury Development in Lisbon | Liv Finder', 'Browse Blackstone Development''s portfolio of luxury listings in Lisbon and beyond.', '2024-11-30 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(10, 'broker_license', 'BR-161343', 'National Regulator', 1177, '2024-12-08', '2028-02-24', 'valid', '2024-12-15 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(10, 'Blackstone Development — Lisbon HQ', 1, 'hello@blackstone-development.com', '+971 4 347 8007', '57 Hessa Street', 1177, 1089245, 50000426, '38.7263500', '-9.1484300', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(10, 1, 'approved', 500, '2024-11-30 09:00:00', '2024-12-03 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(10, 2, 'requested', '2026-07-21 09:00:00', 47);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(10, 1089245, 1),
(10, 50000426, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(10, 47, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-11-30 09:00:00'),
(10, 48, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-02-04 09:00:00'),
(10, 49, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-08-21 09:00:00'),
(10, 50, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-02-19 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(28, '01K2F2DKG09WGWQCKWAM8CMBMY', 47, 10, 'Henry', 'Tanaka', 'Henry Tanaka', 'henry-tanaka-28', 'Managing Director', 'Henry specialises in Lisbon and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/henry-tanaka-28.jpg', 'henry.tanaka@blackstone-development.com', '+971 4 718 4598', '+971 523462230', 'BRN-10768', '2028-04-22', 20, 1177, 1089245, 'active', 'verified', '2024-12-20 09:00:00', 1, 0, '2025-02-26', 'Henry Tanaka — Managing Director at Blackstone Development', '2024-11-30 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(28, 1, 'native'),
(28, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(28, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(28, 1089245, 1),
(28, 50000426, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(29, '01K2F2DKG0M1PXN0XS9JM0M712', 48, 10, 'Julien', 'Ferrari', 'Julien Ferrari', 'julien-ferrari-29', 'Sales Manager', 'Julien specialises in Lisbon and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/julien-ferrari-29.jpg', 'julien.ferrari@blackstone-development.com', '+971 4 863 7613', '+971 520614261', 'BRN-50875', '2026-11-17', 20, 1177, 1089245, 'active', 'verified', '2024-12-20 09:00:00', 1, 0, '2025-05-12', 'Julien Ferrari — Sales Manager at Blackstone Development', '2024-11-30 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(29, 1, 'native'),
(29, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(29, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(29, 1089245, 1),
(29, 50000426, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(30, '01K2F2DKG0QTTEX21TPQ6SGJ0B', 49, 10, 'Hassan', 'Haddad', 'Hassan Haddad', 'hassan-haddad-30', 'Senior Consultant', 'Hassan specialises in Lisbon and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/hassan-haddad-30.jpg', 'hassan.haddad@blackstone-development.com', '+971 4 564 9265', '+971 556473557', 'BRN-70186', '2026-12-04', 22, 1177, 1089245, 'active', 'verified', '2024-12-20 09:00:00', 1, 0, '2025-04-02', 'Hassan Haddad — Senior Consultant at Blackstone Development', '2024-11-30 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(30, 1, 'native'),
(30, 6, 'fluent'),
(30, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(30, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(30, 1089245, 1),
(30, 50000426, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(11, '01K2F2DKG0N9PB23PF793CMCQ0', 5, 51, 'Crown Partners', 'crown-partners', 'active', 'verified', '2022-12-13 09:00:00', 200, 50, 'billing@crown-partners.com', 1, 1231, '2022-12-06 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(11, '01K2F2DKG0CCWDKGNVBPYXMJ0Z', 11, 'marketing_partner', 'Crown Partners', 'Crown Partners LLC', 'crown-partners', 'Curating the finest addresses since day one.', 'Crown Partners is a marketing partner operating from Dubai, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/crown-partners.png', 'https://cdn.livfinder.com/covers/crown-partners.jpg', 'hello@crown-partners.com', '+971 4 781 1193', '+971 528440973', 'https://www.crown-partners.com', '17 Emirates Hills Drive', 1231, 103391, 1000032, 50000006, '25.0657000', '55.1712800', 2004, 209, 'active', 'verified', '2022-12-13 09:00:00', 1, 0, 93, 'Crown Partners — Luxury Partners in Dubai | Liv Finder', 'Browse Crown Partners''s portfolio of luxury listings in Dubai and beyond.', '2022-12-06 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(11, 'rera', '29189', 'Dubai Land Department', 1231, '2022-12-16', '2026-08-21', 'valid', '2022-12-20 09:00:00'),
(11, 'trade_license', 'CN-7218212', 'Dubai Department of Economy and Tourism', 1231, '2022-12-11', '2027-06-12', 'valid', '2022-12-18 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(11, 'Crown Partners — Dubai HQ', 1, 'hello@crown-partners.com', '+971 4 301 4823', '17 Avenue Montaigne', 1231, 1000032, 50000006, '25.0657000', '55.1712800', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(11, 1, 'approved', 200, '2022-12-06 09:00:00', '2022-12-09 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(11, 3, 'requested', '2026-08-05 09:00:00', 51);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(11, 1000032, 1),
(11, 50000006, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(11, 51, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2022-12-06 09:00:00'),
(11, 52, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-02-15 09:00:00'),
(11, 53, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-07-02 09:00:00'),
(11, 54, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-01-20 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(31, '01K2F2DKG0XJ8V5H31JW4GEEV6', 51, 11, 'Leila', 'Kapoor', 'Leila Kapoor', 'leila-kapoor-31', 'Managing Director', 'Leila specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/leila-kapoor-31.jpg', 'leila.kapoor@crown-partners.com', '+971 4 277 1358', '+971 524672541', 'BRN-66610', '2027-12-15', 4, 1231, 1000032, 'active', 'verified', '2022-12-26 09:00:00', 1, 0, '2023-05-28', 'Leila Kapoor — Managing Director at Crown Partners', '2022-12-06 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(31, 1, 'native'),
(31, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(31, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(31, 1000032, 1),
(31, 50000006, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(32, '01K2F2DKG0QWB691CDR7YJPRBJ', 52, 11, 'Charlotte', 'Laurent', 'Charlotte Laurent', 'charlotte-laurent-32', 'Sales Manager', 'Charlotte specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/charlotte-laurent-32.jpg', 'charlotte.laurent@crown-partners.com', '+971 4 637 8716', '+971 535030147', 'BRN-41896', '2027-10-25', 19, 1231, 1000032, 'active', 'verified', '2022-12-26 09:00:00', 1, 0, '2022-12-07', 'Charlotte Laurent — Sales Manager at Crown Partners', '2022-12-06 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(32, 1, 'native'),
(32, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(32, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(32, 1000032, 1),
(32, 50000006, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(33, '01K2F2DKG0HTF8B9Q2X6GW6E49', 53, 11, 'Henry', 'Whitfield', 'Henry Whitfield', 'henry-whitfield-33', 'Senior Consultant', 'Henry specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/henry-whitfield-33.jpg', 'henry.whitfield@crown-partners.com', '+971 4 218 8791', '+971 541467724', 'BRN-38726', '2027-06-01', 23, 1231, 1000032, 'active', 'verified', '2022-12-26 09:00:00', 1, 0, '2023-05-27', 'Henry Whitfield — Senior Consultant at Crown Partners', '2022-12-06 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(33, 1, 'native'),
(33, 2, 'fluent'),
(33, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(33, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(33, 1000032, 1),
(33, 50000006, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(12, '01K2F2DKG0F7PYC6X2174VDCC3', 3, 55, 'Azure Properties', 'azure-properties', 'active', 'verified', '2024-08-22 09:00:00', 50, 3, 'billing@azure-properties.com', 6, 1194, '2024-08-15 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(12, '01K2F2DKG0YZ5R3Y0X7KBHM4KS', 12, 'agency', 'Azure Properties', 'Azure Properties LLC', 'azure-properties', 'Discretion, precision, and an unrivalled portfolio.', 'Azure Properties is a agency operating from Jeddah, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/azure-properties.png', 'https://cdn.livfinder.com/covers/azure-properties.jpg', 'hello@azure-properties.com', '+971 4 558 8554', '+971 525855092', 'https://www.azure-properties.com', '52 Sloane Street', 1194, 102850, 1102858, 50000182, '21.5423800', '39.1979700', 2009, 244, 'active', 'verified', '2024-08-22 09:00:00', 1, 0, 81, 'Azure Properties — Luxury Properties in Jeddah | Liv Finder', 'Browse Azure Properties''s portfolio of luxury listings in Jeddah and beyond.', '2024-08-15 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(12, 'broker_license', 'BR-963239', 'National Regulator', 1194, '2024-08-23', '2027-05-01', 'valid', '2024-08-30 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(12, 'Azure Properties — Jeddah HQ', 1, 'hello@azure-properties.com', '+971 4 216 7155', '20 Worth Avenue', 1194, 1102858, 50000182, '21.5423800', '39.1979700', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(12, 1, 'approved', 50, '2024-08-15 09:00:00', '2024-08-18 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(12, 1102858, 1),
(12, 50000182, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(12, 55, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-08-15 09:00:00'),
(12, 56, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-10-10 09:00:00'),
(12, 57, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-12-06 09:00:00'),
(12, 58, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-11-08 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(34, '01K2F2DKG0BV8R7XFADATTSRBZ', 55, 12, 'Hassan', 'Moretti', 'Hassan Moretti', 'hassan-moretti-34', 'Managing Director', 'Hassan specialises in Jeddah and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/hassan-moretti-34.jpg', 'hassan.moretti@azure-properties.com', '+971 4 718 8037', '+971 520700670', 'BRN-77881', '2028-02-04', 7, 1194, 1102858, 'active', 'verified', '2024-09-04 09:00:00', 1, 0, '2024-08-25', 'Hassan Moretti — Managing Director at Azure Properties', '2024-08-15 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(34, 1, 'native'),
(34, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(34, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(34, 1102858, 1),
(34, 50000182, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(35, '01K2F2DKG0BR45HXCWY9VZ058A', 56, 12, 'Tariq', 'Moreau', 'Tariq Moreau', 'tariq-moreau-35', 'Sales Manager', 'Tariq specialises in Jeddah and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/tariq-moreau-35.jpg', 'tariq.moreau@azure-properties.com', '+971 4 660 8736', '+971 530570049', 'BRN-28529', '2028-05-05', 17, 1194, 1102858, 'active', 'verified', '2024-09-04 09:00:00', 1, 0, '2024-11-18', 'Tariq Moreau — Sales Manager at Azure Properties', '2024-08-15 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(35, 1, 'native'),
(35, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(35, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(35, 1102858, 1),
(35, 50000182, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(36, '01K2F2DKG0ANV6JEBF761MY3Q1', 57, 12, 'Antoine', 'Rossellini', 'Antoine Rossellini', 'antoine-rossellini-36', 'Senior Consultant', 'Antoine specialises in Jeddah and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/antoine-rossellini-36.jpg', 'antoine.rossellini@azure-properties.com', '+971 4 682 9005', '+971 533745499', 'BRN-28383', '2026-09-23', 10, 1194, 1102858, 'active', 'verified', '2024-09-04 09:00:00', 1, 0, '2024-08-16', 'Antoine Rossellini — Senior Consultant at Azure Properties', '2024-08-15 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(36, 1, 'native'),
(36, 3, 'fluent'),
(36, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(36, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(36, 1102858, 1),
(36, 50000182, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(13, '01K2F2DKG0GBFRXY31127ZGHPH', 4, 59, 'Palladium Real Estate', 'palladium-real-estate', 'active', 'verified', '2022-10-20 09:00:00', 500, 100, 'billing@palladium-real-estate.com', 1, 1231, '2022-10-13 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(13, '01K2F2DKG01RT31JVXEAP7GNMK', 13, 'agency', 'Palladium Real Estate', 'Palladium Real Estate LLC', 'palladium-real-estate', 'Discretion, precision, and an unrivalled portfolio.', 'Palladium Real Estate is a agency operating from Abu Dhabi, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/palladium-real-estate.png', 'https://cdn.livfinder.com/covers/palladium-real-estate.jpg', 'hello@palladium-real-estate.com', '+971 4 624 2050', '+971 536350753', 'https://www.palladium-real-estate.com', '24 Collins Avenue', 1231, 103396, 1000012, 50000096, '24.4136100', '54.4329500', 2008, 217, 'active', 'verified', '2022-10-20 09:00:00', 1, 0, 112, 'Palladium Real Estate — Luxury Real Estate in Abu Dhabi | Liv Finder', 'Browse Palladium Real Estate''s portfolio of luxury listings in Abu Dhabi and beyond.', '2022-10-13 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(13, 'rera', '22918', 'Dubai Land Department', 1231, '2022-10-23', '2027-11-23', 'valid', '2022-10-27 09:00:00'),
(13, 'trade_license', 'CN-3738065', 'Dubai Department of Economy and Tourism', 1231, '2022-10-18', '2027-08-22', 'valid', '2022-10-25 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(13, 'Palladium Real Estate — Abu Dhabi HQ', 1, 'hello@palladium-real-estate.com', '+971 4 455 9501', '12 Via Montenapoleone', 1231, 1000012, 50000096, '24.4136100', '54.4329500', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(13, 1, 'approved', 500, '2022-10-13 09:00:00', '2022-10-16 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(13, 4, 'requested', '2026-07-11 09:00:00', 59);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(13, 1000012, 1),
(13, 50000096, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(13, 59, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2022-10-13 09:00:00'),
(13, 60, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2022-11-15 09:00:00'),
(13, 61, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-01-24 09:00:00'),
(13, 62, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2022-12-04 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(37, '01K2F2DKG0Z409TEJDW81XFZ7N', 59, 13, 'Rashid', 'Königsberg', 'Rashid Königsberg', 'rashid-konigsberg-37', 'Managing Director', 'Rashid specialises in Abu Dhabi and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rashid-konigsberg-37.jpg', 'rashid.konigsberg@palladium-real-estate.com', '+971 4 513 3638', '+971 540793724', 'BRN-27397', '2027-09-01', 16, 1231, 1000012, 'active', 'verified', '2022-11-02 09:00:00', 1, 0, '2022-12-04', 'Rashid Königsberg — Managing Director at Palladium Real Estate', '2022-10-13 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(37, 1, 'native'),
(37, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(37, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(37, 1000012, 1),
(37, 50000096, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(38, '01K2F2DKG0ZT5006622W543WB9', 60, 13, 'Henry', 'Al Balushi', 'Henry Al Balushi', 'henry-al-balushi-38', 'Sales Manager', 'Henry specialises in Abu Dhabi and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/henry-al-balushi-38.jpg', 'henry.al-balushi@palladium-real-estate.com', '+971 4 670 1209', '+971 551872601', 'BRN-55992', '2026-11-12', 22, 1231, 1000012, 'active', 'verified', '2022-11-02 09:00:00', 1, 0, '2022-11-13', 'Henry Al Balushi — Sales Manager at Palladium Real Estate', '2022-10-13 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(38, 1, 'native'),
(38, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(38, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(38, 1000012, 1),
(38, 50000096, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(39, '01K2F2DKG07823XVWCA0DCQY28', 61, 13, 'Noor', 'Petrova', 'Noor Petrova', 'noor-petrova-39', 'Senior Consultant', 'Noor specialises in Abu Dhabi and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/noor-petrova-39.jpg', 'noor.petrova@palladium-real-estate.com', '+971 4 394 7679', '+971 516187885', 'BRN-11737', '2026-09-23', 15, 1231, 1000012, 'active', 'verified', '2022-11-02 09:00:00', 1, 1, '2022-11-08', 'Noor Petrova — Senior Consultant at Palladium Real Estate', '2022-10-13 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(39, 1, 'native'),
(39, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(39, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(39, 1000012, 1),
(39, 50000096, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(14, '01K2F2DKG0GXQNBM2MKSTA361A', 3, 63, 'Sovereign Estates', 'sovereign-estates', 'active', 'verified', '2025-07-31 09:00:00', 50, 3, 'billing@sovereign-estates.com', 3, 1075, '2025-07-24 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(14, '01K2F2DKG0R5J5QFN096RZ6KMQ', 14, 'brokerage', 'Sovereign Estates', 'Sovereign Estates LLC', 'sovereign-estates', 'Discretion, precision, and an unrivalled portfolio.', 'Sovereign Estates is a brokerage operating from Saint-Tropez, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/sovereign-estates.png', 'https://cdn.livfinder.com/covers/sovereign-estates.jpg', 'hello@sovereign-estates.com', '+971 4 230 5622', '+971 518490272', 'https://www.sovereign-estates.com', '15 Emirates Hills Drive', 1075, 105051, 1046589, 50000308, '43.2676400', '6.6404900', 2003, 257, 'active', 'verified', '2025-07-31 09:00:00', 1, 0, 175, 'Sovereign Estates — Luxury Estates in Saint-Tropez | Liv Finder', 'Browse Sovereign Estates''s portfolio of luxury listings in Saint-Tropez and beyond.', '2025-07-24 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(14, 'broker_license', 'BR-356589', 'National Regulator', 1075, '2025-08-01', '2026-10-18', 'valid', '2025-08-08 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(14, 'Sovereign Estates — Saint-Tropez HQ', 1, 'hello@sovereign-estates.com', '+971 4 522 6997', '29 Avenue Montaigne', 1075, 1046589, 50000308, '43.2676400', '6.6404900', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(14, 1, 'approved', 50, '2025-07-24 09:00:00', '2025-07-27 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(14, 6, 'requested', '2026-07-09 09:00:00', 63);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(14, 1046589, 1),
(14, 50000308, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(14, 63, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2025-07-24 09:00:00'),
(14, 64, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-08-17 09:00:00'),
(14, 65, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-12-10 09:00:00'),
(14, 66, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2026-01-10 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(40, '01K2F2DKG0PJFK9JSKZRCDJ8Z9', 63, 14, 'Vikram', 'Johnson', 'Vikram Johnson', 'vikram-johnson-40', 'Managing Director', 'Vikram specialises in Saint-Tropez and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/vikram-johnson-40.jpg', 'vikram.johnson@sovereign-estates.com', '+971 4 521 5760', '+971 559642172', 'BRN-59242', '2027-12-23', 3, 1075, 1046589, 'active', 'verified', '2025-08-13 09:00:00', 1, 0, '2025-08-24', 'Vikram Johnson — Managing Director at Sovereign Estates', '2025-07-24 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(40, 1, 'native'),
(40, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(40, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(40, 1046589, 1),
(40, 50000308, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(41, '01K2F2DKG0V652232FYVX83QE0', 64, 14, 'Leila', 'Santos', 'Leila Santos', 'leila-santos-41', 'Sales Manager', 'Leila specialises in Saint-Tropez and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/leila-santos-41.jpg', 'leila.santos@sovereign-estates.com', '+971 4 427 8473', '+971 559206911', 'BRN-60409', '2027-07-12', 12, 1075, 1046589, 'active', 'verified', '2025-08-13 09:00:00', 1, 0, '2025-11-08', 'Leila Santos — Sales Manager at Sovereign Estates', '2025-07-24 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(41, 1, 'native'),
(41, 2, 'fluent'),
(41, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(41, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(41, 1046589, 1),
(41, 50000308, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(42, '01K2F2DKG0F42ANX919CTF64YX', 65, 14, 'Emma', 'Herrera', 'Emma Herrera', 'emma-herrera-42', 'Senior Consultant', 'Emma specialises in Saint-Tropez and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/emma-herrera-42.jpg', 'emma.herrera@sovereign-estates.com', '+971 4 413 4555', '+971 525587731', 'BRN-33730', '2027-03-31', 13, 1075, 1046589, 'active', 'verified', '2025-08-13 09:00:00', 1, 1, '2025-11-07', 'Emma Herrera — Senior Consultant at Sovereign Estates', '2025-07-24 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(42, 1, 'native'),
(42, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(42, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(42, 1046589, 1),
(42, 50000308, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(15, '01K2F2DKG0KD4H9J8G0N9GWBQC', 3, 67, 'Beaufort Motors', 'beaufort-motors', 'active', 'verified', '2022-10-21 09:00:00', 50, 3, 'billing@beaufort-motors.com', 6, 1194, '2022-10-14 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(15, '01K2F2DKG0T017BFYJXD2FPMJ3', 15, 'dealership', 'Beaufort Motors', 'Beaufort Motors LLC', 'beaufort-motors', 'A boutique practice with a global reach.', 'Beaufort Motors is a dealership operating from Riyadh, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/beaufort-motors.png', 'https://cdn.livfinder.com/covers/beaufort-motors.jpg', 'hello@beaufort-motors.com', '+971 4 311 6765', '+971 524448615', 'https://www.beaufort-motors.com', '21 Marina Walk', 1194, 102849, 1102874, 50000174, '24.6877300', '46.7218500', 2007, 166, 'active', 'verified', '2022-10-21 09:00:00', 1, 0, 47, 'Beaufort Motors — Luxury Motors in Riyadh | Liv Finder', 'Browse Beaufort Motors''s portfolio of luxury listings in Riyadh and beyond.', '2022-10-14 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(15, 'broker_license', 'BR-851598', 'National Regulator', 1194, '2022-10-22', '2028-06-26', 'valid', '2022-10-29 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(15, 'Beaufort Motors — Riyadh HQ', 1, 'hello@beaufort-motors.com', '+971 4 886 4125', '80 Al Wasl Road', 1194, 1102874, 50000174, '24.6877300', '46.7218500', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(15, 2, 'approved', 50, '2022-10-14 09:00:00', '2022-10-17 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(15, 1102874, 1),
(15, 50000174, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(15, 67, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2022-10-14 09:00:00'),
(15, 68, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-05-08 09:00:00'),
(15, 69, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-07-05 09:00:00'),
(15, 70, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2022-11-18 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(43, '01K2F2DKG0DZ121Z3BABA4BM3K', 67, 15, 'Sofia', 'Mercer', 'Sofia Mercer', 'sofia-mercer-43', 'Managing Director', 'Sofia specialises in Riyadh and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/sofia-mercer-43.jpg', 'sofia.mercer@beaufort-motors.com', '+971 4 590 4164', '+971 528848233', 'BRN-22783', '2028-07-14', 24, 1194, 1102874, 'active', 'verified', '2022-11-03 09:00:00', 1, 0, '2023-03-22', 'Sofia Mercer — Managing Director at Beaufort Motors', '2022-10-14 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(43, 1, 'native'),
(43, 9, 'fluent'),
(43, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(43, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(43, 1102874, 1),
(43, 50000174, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(44, '01K2F2DKG04GVFYSR1B221D5XQ', 68, 15, 'Camille', 'Al Mansouri', 'Camille Al Mansouri', 'camille-al-mansouri-44', 'Sales Manager', 'Camille specialises in Riyadh and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/camille-al-mansouri-44.jpg', 'camille.al-mansouri@beaufort-motors.com', '+971 4 637 7736', '+971 537186767', 'BRN-22809', '2028-04-06', 25, 1194, 1102874, 'active', 'verified', '2022-11-03 09:00:00', 1, 0, '2022-11-05', 'Camille Al Mansouri — Sales Manager at Beaufort Motors', '2022-10-14 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(44, 1, 'native'),
(44, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(44, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(44, 1102874, 1),
(44, 50000174, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(45, '01K2F2DKG05ME6R60GCRDPS7Y5', 69, 15, 'Layla', 'Ferrari', 'Layla Ferrari', 'layla-ferrari-45', 'Senior Consultant', 'Layla specialises in Riyadh and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/layla-ferrari-45.jpg', 'layla.ferrari@beaufort-motors.com', '+971 4 338 9979', '+971 536825592', 'BRN-18594', '2026-12-11', 19, 1194, 1102874, 'active', 'verified', '2022-11-03 09:00:00', 1, 1, '2022-11-13', 'Layla Ferrari — Senior Consultant at Beaufort Motors', '2022-10-14 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(45, 1, 'native'),
(45, 3, 'fluent'),
(45, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(45, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(45, 1102874, 1),
(45, 50000174, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(16, '01K2F2DKG0Q32Z9GKT2FYFYQRE', 4, 71, 'Cavendish Automotive', 'cavendish-automotive', 'active', 'verified', '2024-10-04 09:00:00', 500, 100, 'billing@cavendish-automotive.com', 2, 1233, '2024-09-27 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(16, '01K2F2DKG0MV3MESRR0HYEZ083', 16, 'dealership', 'Cavendish Automotive', 'Cavendish Automotive LLC', 'cavendish-automotive', 'Curating the finest addresses since day one.', 'Cavendish Automotive is a dealership operating from Miami Beach, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/cavendish-automotive.png', 'https://cdn.livfinder.com/covers/cavendish-automotive.jpg', 'hello@cavendish-automotive.com', '+971 4 307 9564', '+971 522842975', 'https://www.cavendish-automotive.com', '63 Bahnhofstrasse', 1233, 101436, 1121750, 50000558, '25.7906500', '-80.1300500', 2014, 138, 'active', 'verified', '2024-10-04 09:00:00', 1, 0, 36, 'Cavendish Automotive — Luxury Automotive in Miami Beach | Liv Finder', 'Browse Cavendish Automotive''s portfolio of luxury listings in Miami Beach and beyond.', '2024-09-27 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(16, 'broker_license', 'BR-125089', 'National Regulator', 1233, '2024-10-05', '2027-06-18', 'valid', '2024-10-12 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(16, 'Cavendish Automotive — Miami Beach HQ', 1, 'hello@cavendish-automotive.com', '+971 4 585 9074', '18 Al Wasl Road', 1233, 1121750, 50000558, '25.7906500', '-80.1300500', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(16, 2, 'approved', 500, '2024-09-27 09:00:00', '2024-09-30 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(16, 1121750, 1),
(16, 50000558, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(16, 71, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-09-27 09:00:00'),
(16, 72, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-04-11 09:00:00'),
(16, 73, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-07-09 09:00:00'),
(16, 74, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-11-03 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(46, '01K2F2DKG0QRNWW9SYKPB8SXYV', 71, 16, 'Elena', 'Al Balushi', 'Elena Al Balushi', 'elena-al-balushi-46', 'Managing Director', 'Elena specialises in Miami Beach and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/elena-al-balushi-46.jpg', 'elena.al-balushi@cavendish-automotive.com', '+971 4 582 5631', '+971 523666869', 'BRN-46854', '2028-05-22', 22, 1233, 1121750, 'active', 'verified', '2024-10-17 09:00:00', 1, 0, '2025-01-13', 'Elena Al Balushi — Managing Director at Cavendish Automotive', '2024-09-27 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(46, 1, 'native'),
(46, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(46, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(46, 1121750, 1),
(46, 50000558, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(47, '01K2F2DKG0REXDM01457HFJ2FX', 72, 16, 'Charlotte', 'Al Suwaidi', 'Charlotte Al Suwaidi', 'charlotte-al-suwaidi-47', 'Sales Manager', 'Charlotte specialises in Miami Beach and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/charlotte-al-suwaidi-47.jpg', 'charlotte.al-suwaidi@cavendish-automotive.com', '+971 4 711 9094', '+971 526313009', 'BRN-62284', '2027-12-26', 23, 1233, 1121750, 'active', 'verified', '2024-10-17 09:00:00', 1, 0, '2024-12-11', 'Charlotte Al Suwaidi — Sales Manager at Cavendish Automotive', '2024-09-27 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(47, 1, 'native'),
(47, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(47, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(47, 1121750, 1),
(47, 50000558, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(48, '01K2F2DKG0ER8XPM5WA5EKAXXP', 73, 16, 'Lucas', 'Ferrari', 'Lucas Ferrari', 'lucas-ferrari-48', 'Senior Consultant', 'Lucas specialises in Miami Beach and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/lucas-ferrari-48.jpg', 'lucas.ferrari@cavendish-automotive.com', '+971 4 882 9221', '+971 518453973', 'BRN-41380', '2028-07-12', 15, 1233, 1121750, 'active', 'verified', '2024-10-17 09:00:00', 1, 0, '2025-01-30', 'Lucas Ferrari — Senior Consultant at Cavendish Automotive', '2024-09-27 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(48, 1, 'native'),
(48, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(48, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(48, 1121750, 1),
(48, 50000558, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(17, '01K2F2DKG03RV8C4YDA1DG4S0B', 3, 75, 'Marchmont Yachts', 'marchmont-yachts', 'active', 'verified', '2023-10-21 09:00:00', 50, 3, 'billing@marchmont-yachts.com', 21, 1142, '2023-10-14 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(17, '01K2F2DKG0524R9XBFC95824DB', 17, 'yacht_broker', 'Marchmont Yachts', 'Marchmont Yachts LLC', 'marchmont-yachts', 'A boutique practice with a global reach.', 'Marchmont Yachts is a yacht broker operating from Cabo San Lucas, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/marchmont-yachts.png', 'https://cdn.livfinder.com/covers/marchmont-yachts.jpg', 'hello@marchmont-yachts.com', '+971 4 388 8807', '+971 557964057', 'https://www.marchmont-yachts.com', '63 Via Montenapoleone', 1142, 103460, 1068704, 50000677, '22.8908800', '-109.9123800', 2008, 299, 'active', 'verified', '2023-10-21 09:00:00', 1, 0, 159, 'Marchmont Yachts — Luxury Yachts in Cabo San Lucas | Liv Finder', 'Browse Marchmont Yachts''s portfolio of luxury listings in Cabo San Lucas and beyond.', '2023-10-14 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(17, 'broker_license', 'BR-890261', 'National Regulator', 1142, '2023-10-22', '2027-10-10', 'valid', '2023-10-29 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(17, 'Marchmont Yachts — Cabo San Lucas HQ', 1, 'hello@marchmont-yachts.com', '+971 4 886 8130', '75 Avenue Montaigne', 1142, 1068704, 50000677, '22.8908800', '-109.9123800', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(17, 3, 'approved', 50, '2023-10-14 09:00:00', '2023-10-17 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(17, 6, 'requested', '2026-07-31 09:00:00', 75);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(17, 1068704, 1),
(17, 50000677, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(17, 75, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-10-14 09:00:00'),
(17, 76, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-01-12 09:00:00'),
(17, 77, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-11-26 09:00:00'),
(17, 78, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-05-31 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(49, '01K2F2DKG0J5NZTYSS8616D25F', 75, 17, 'Zainab', 'Nasser', 'Zainab Nasser', 'zainab-nasser-49', 'Managing Director', 'Zainab specialises in Cabo San Lucas and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/zainab-nasser-49.jpg', 'zainab.nasser@marchmont-yachts.com', '+971 4 719 6741', '+971 528601612', 'BRN-35645', '2027-05-30', 9, 1142, 1068704, 'active', 'verified', '2023-11-03 09:00:00', 1, 0, '2024-04-30', 'Zainab Nasser — Managing Director at Marchmont Yachts', '2023-10-14 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(49, 1, 'native'),
(49, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(49, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(49, 1068704, 1),
(49, 50000677, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(50, '01K2F2DKG0F3HZKG7BK4FXTSCF', 76, 17, 'Valentina', 'Meyer', 'Valentina Meyer', 'valentina-meyer-50', 'Sales Manager', 'Valentina specialises in Cabo San Lucas and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/valentina-meyer-50.jpg', 'valentina.meyer@marchmont-yachts.com', '+971 4 558 8029', '+971 555217790', 'BRN-67005', '2028-07-08', 5, 1142, 1068704, 'active', 'verified', '2023-11-03 09:00:00', 1, 1, '2024-01-13', 'Valentina Meyer — Sales Manager at Marchmont Yachts', '2023-10-14 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(50, 1, 'native'),
(50, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(50, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(50, 1068704, 1),
(50, 50000677, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(51, '01K2F2DKG0661AFYRZWY2KBNCV', 77, 17, 'Henry', 'Johnson', 'Henry Johnson', 'henry-johnson-51', 'Senior Consultant', 'Henry specialises in Cabo San Lucas and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/henry-johnson-51.jpg', 'henry.johnson@marchmont-yachts.com', '+971 4 439 4605', '+971 529673828', 'BRN-34877', '2027-05-17', 17, 1142, 1068704, 'active', 'verified', '2023-11-03 09:00:00', 1, 0, '2023-12-21', 'Henry Johnson — Senior Consultant at Marchmont Yachts', '2023-10-14 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(51, 1, 'native'),
(51, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(51, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(51, 1068704, 1),
(51, 50000677, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(18, '01K2F2DKG057Y3GMP54XNP3GHA', 3, 79, 'Lumina Marine', 'lumina-marine', 'active', 'verified', '2022-07-18 09:00:00', 50, 3, 'billing@lumina-marine.com', 1, 1231, '2022-07-11 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(18, '01K2F2DKG0BAQJHQPDWDQHQWWJ', 18, 'yacht_broker', 'Lumina Marine', 'Lumina Marine LLC', 'lumina-marine', 'Curating the finest addresses since day one.', 'Lumina Marine is a yacht broker operating from Dubai, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/lumina-marine.png', 'https://cdn.livfinder.com/covers/lumina-marine.jpg', 'hello@lumina-marine.com', '+971 4 237 2094', '+971 511949406', 'https://www.lumina-marine.com', '49 Marina Walk', 1231, 103391, 1000032, 50000067, '25.0657000', '55.1712800', 2010, 177, 'active', 'verified', '2022-07-18 09:00:00', 1, 0, 100, 'Lumina Marine — Luxury Marine in Dubai | Liv Finder', 'Browse Lumina Marine''s portfolio of luxury listings in Dubai and beyond.', '2022-07-11 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(18, 'rera', '18638', 'Dubai Land Department', 1231, '2022-07-21', '2026-08-10', 'valid', '2022-07-25 09:00:00'),
(18, 'trade_license', 'CN-3268320', 'Dubai Department of Economy and Tourism', 1231, '2022-07-16', '2026-11-29', 'valid', '2022-07-23 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(18, 'Lumina Marine — Dubai HQ', 1, 'hello@lumina-marine.com', '+971 4 374 2162', '56 Avenue Montaigne', 1231, 1000032, 50000067, '25.0657000', '55.1712800', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(18, 3, 'approved', 50, '2022-07-11 09:00:00', '2022-07-14 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(18, 2, 'requested', '2026-07-13 09:00:00', 79);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(18, 1000032, 1),
(18, 50000067, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(18, 79, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2022-07-11 09:00:00'),
(18, 80, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-04-17 09:00:00'),
(18, 81, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2022-10-17 09:00:00'),
(18, 82, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2022-09-06 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(52, '01K2F2DKG0B1KGCF434N4DA95G', 79, 18, 'Hassan', 'Ashworth', 'Hassan Ashworth', 'hassan-ashworth-52', 'Managing Director', 'Hassan specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/hassan-ashworth-52.jpg', 'hassan.ashworth@lumina-marine.com', '+971 4 758 5687', '+971 540775651', 'BRN-79928', '2027-01-14', 24, 1231, 1000032, 'active', 'verified', '2022-07-31 09:00:00', 1, 0, '2022-11-09', 'Hassan Ashworth — Managing Director at Lumina Marine', '2022-07-11 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(52, 1, 'native'),
(52, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(52, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(52, 1000032, 1),
(52, 50000067, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(53, '01K2F2DKG085QGEPSF2F31PX2Q', 80, 18, 'Priya', 'Von Habsburg', 'Priya Von Habsburg', 'priya-von-habsburg-53', 'Sales Manager', 'Priya specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/priya-von-habsburg-53.jpg', 'priya.von-habsburg@lumina-marine.com', '+971 4 744 4352', '+971 540244391', 'BRN-57125', '2026-09-24', 11, 1231, 1000032, 'active', 'verified', '2022-07-31 09:00:00', 1, 0, '2022-08-14', 'Priya Von Habsburg — Sales Manager at Lumina Marine', '2022-07-11 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(53, 1, 'native'),
(53, 6, 'fluent'),
(53, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(53, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(53, 1000032, 1),
(53, 50000067, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(54, '01K2F2DKG0W219AG01Z9BBT5HX', 81, 18, 'Charlotte', 'Beaumont', 'Charlotte Beaumont', 'charlotte-beaumont-54', 'Senior Consultant', 'Charlotte specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/charlotte-beaumont-54.jpg', 'charlotte.beaumont@lumina-marine.com', '+971 4 849 5567', '+971 515414931', 'BRN-16711', '2028-07-11', 9, 1231, 1000032, 'active', 'verified', '2022-07-31 09:00:00', 1, 0, '2022-11-29', 'Charlotte Beaumont — Senior Consultant at Lumina Marine', '2022-07-11 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(54, 1, 'native'),
(54, 2, 'fluent'),
(54, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(54, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(54, 1000032, 1),
(54, 50000067, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(19, '01K2F2DKG09KNZ3BK89WR9QHKY', 4, 83, 'Veritas Aviation', 'veritas-aviation', 'active', 'verified', '2023-02-28 09:00:00', 500, 100, 'billing@veritas-aviation.com', 3, 1075, '2023-02-21 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(19, '01K2F2DKG0RK19FBESHKQRZEDF', 19, 'aviation_broker', 'Veritas Aviation', 'Veritas Aviation LLC', 'veritas-aviation', 'Discretion, precision, and an unrivalled portfolio.', 'Veritas Aviation is a aviation broker operating from Paris, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/veritas-aviation.png', 'https://cdn.livfinder.com/covers/veritas-aviation.jpg', 'hello@veritas-aviation.com', '+971 4 353 9565', '+971 554446891', 'https://www.veritas-aviation.com', '22 Marina Walk', 1075, 104816, 1044856, 50000294, '48.8534000', '2.3486000', 2008, 191, 'active', 'verified', '2023-02-28 09:00:00', 1, 0, 144, 'Veritas Aviation — Luxury Aviation in Paris | Liv Finder', 'Browse Veritas Aviation''s portfolio of luxury listings in Paris and beyond.', '2023-02-21 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(19, 'broker_license', 'BR-753252', 'National Regulator', 1075, '2023-03-01', '2027-01-27', 'valid', '2023-03-08 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(19, 'Veritas Aviation — Paris HQ', 1, 'hello@veritas-aviation.com', '+971 4 799 2828', '21 Sloane Street', 1075, 1044856, 50000294, '48.8534000', '2.3486000', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(19, 4, 'approved', 500, '2023-02-21 09:00:00', '2023-02-24 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(19, 1044856, 1),
(19, 50000294, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(19, 83, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-02-21 09:00:00'),
(19, 84, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-11-12 09:00:00'),
(19, 85, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-08-06 09:00:00'),
(19, 86, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-04-13 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(55, '01K2F2DKG0EE08NY6SSWVFHXTV', 83, 19, 'Hana', 'Mercer', 'Hana Mercer', 'hana-mercer-55', 'Managing Director', 'Hana specialises in Paris and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/hana-mercer-55.jpg', 'hana.mercer@veritas-aviation.com', '+971 4 428 8667', '+971 514862992', 'BRN-64755', '2027-10-03', 11, 1075, 1044856, 'active', 'verified', '2023-03-13 09:00:00', 1, 0, '2023-06-15', 'Hana Mercer — Managing Director at Veritas Aviation', '2023-02-21 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(55, 1, 'native'),
(55, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(55, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(55, 1044856, 1),
(55, 50000294, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(56, '01K2F2DKG04RPCCKM81Y55W621', 84, 19, 'Mariam', 'Bin Ahmed', 'Mariam Bin Ahmed', 'mariam-bin-ahmed-56', 'Sales Manager', 'Mariam specialises in Paris and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/mariam-bin-ahmed-56.jpg', 'mariam.bin-ahmed@veritas-aviation.com', '+971 4 314 4969', '+971 552799145', 'BRN-39839', '2027-07-26', 21, 1075, 1044856, 'active', 'verified', '2023-03-13 09:00:00', 1, 0, '2023-05-19', 'Mariam Bin Ahmed — Sales Manager at Veritas Aviation', '2023-02-21 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(56, 1, 'native'),
(56, 6, 'fluent'),
(56, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(56, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(56, 1044856, 1),
(56, 50000294, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(57, '01K2F2DKG0CPJGFGR2YQSWE5DC', 85, 19, 'Rashid', 'Fairfax', 'Rashid Fairfax', 'rashid-fairfax-57', 'Senior Consultant', 'Rashid specialises in Paris and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rashid-fairfax-57.jpg', 'rashid.fairfax@veritas-aviation.com', '+971 4 567 6665', '+971 540354275', 'BRN-45788', '2027-09-18', 19, 1075, 1044856, 'active', 'verified', '2023-03-13 09:00:00', 1, 1, '2023-09-08', 'Rashid Fairfax — Senior Consultant at Veritas Aviation', '2023-02-21 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(57, 1, 'native'),
(57, 4, 'fluent'),
(57, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(57, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(57, 1044856, 1),
(57, 50000294, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(20, '01K2F2DKG080HYVQ84WFZWJVSZ', 3, 87, 'Onyx Timepieces', 'onyx-timepieces', 'active', 'verified', '2024-07-19 09:00:00', 50, 3, 'billing@onyx-timepieces.com', 3, 1107, '2024-07-12 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(20, '01K2F2DKG07DB9K6BTK99H2MNF', 20, 'watch_dealer', 'Onyx Timepieces', 'Onyx Timepieces LLC', 'onyx-timepieces', 'Where exceptional assets meet exceptional clients.', 'Onyx Timepieces is a watch dealer operating from Milan, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/onyx-timepieces.png', 'https://cdn.livfinder.com/covers/onyx-timepieces.jpg', 'hello@onyx-timepieces.com', '+971 4 856 9349', '+971 513725346', 'https://www.onyx-timepieces.com', '25 Orchard Boulevard', 1107, 105633, 1140142, 50000384, '45.4642700', '9.1895100', 1999, 211, 'active', 'verified', '2024-07-19 09:00:00', 1, 0, 18, 'Onyx Timepieces — Luxury Timepieces in Milan | Liv Finder', 'Browse Onyx Timepieces''s portfolio of luxury listings in Milan and beyond.', '2024-07-12 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(20, 'broker_license', 'BR-547682', 'National Regulator', 1107, '2024-07-20', '2027-10-09', 'valid', '2024-07-27 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(20, 'Onyx Timepieces — Milan HQ', 1, 'hello@onyx-timepieces.com', '+971 4 695 4983', '84 The Crescent', 1107, 1140142, 50000384, '45.4642700', '9.1895100', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(20, 6, 'approved', 50, '2024-07-12 09:00:00', '2024-07-15 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(20, 1140142, 1),
(20, 50000384, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(20, 87, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-07-12 09:00:00'),
(20, 88, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-04-08 09:00:00'),
(20, 89, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-04-14 09:00:00'),
(20, 90, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-08-03 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(58, '01K2F2DKG0C47FQVGH2K3K9F7C', 87, 20, 'Daniel', 'Darwish', 'Daniel Darwish', 'daniel-darwish-58', 'Managing Director', 'Daniel specialises in Milan and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/daniel-darwish-58.jpg', 'daniel.darwish@onyx-timepieces.com', '+971 4 757 6119', '+971 557667628', 'BRN-29749', '2028-06-23', 3, 1107, 1140142, 'active', 'verified', '2024-08-01 09:00:00', 1, 0, '2024-08-07', 'Daniel Darwish — Managing Director at Onyx Timepieces', '2024-07-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(58, 1, 'native'),
(58, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(58, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(58, 1140142, 1),
(58, 50000384, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(59, '01K2F2DKG0E9QNNW5X7AE4V6JK', 88, 20, 'Sarah', 'Haddad', 'Sarah Haddad', 'sarah-haddad-59', 'Sales Manager', 'Sarah specialises in Milan and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/sarah-haddad-59.jpg', 'sarah.haddad@onyx-timepieces.com', '+971 4 272 3068', '+971 540298284', 'BRN-47464', '2027-06-03', 9, 1107, 1140142, 'active', 'verified', '2024-08-01 09:00:00', 1, 0, '2024-10-07', 'Sarah Haddad — Sales Manager at Onyx Timepieces', '2024-07-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(59, 1, 'native'),
(59, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(59, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(59, 1140142, 1),
(59, 50000384, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(60, '01K2F2DKG0XY6ER5NQ3CR6FZKE', 89, 20, 'Olivia', 'Blackwood', 'Olivia Blackwood', 'olivia-blackwood-60', 'Senior Consultant', 'Olivia specialises in Milan and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/olivia-blackwood-60.jpg', 'olivia.blackwood@onyx-timepieces.com', '+971 4 273 3872', '+971 516861464', 'BRN-66529', '2027-08-01', 15, 1107, 1140142, 'active', 'verified', '2024-08-01 09:00:00', 1, 0, '2024-09-17', 'Olivia Blackwood — Senior Consultant at Onyx Timepieces', '2024-07-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(60, 1, 'native'),
(60, 9, 'fluent'),
(60, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(60, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(60, 1140142, 1),
(60, 50000384, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(21, '01K2F2DKG00TE1WSKJV1630JQ9', 5, 91, 'Kingsley Development', 'kingsley-development', 'active', 'verified', '2024-12-27 09:00:00', 200, 50, 'billing@kingsley-development.com', 3, 1207, '2024-12-20 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(21, '01K2F2DKG00Y8ATPYQFWE5WW9H', 21, 'developer', 'Kingsley Development', 'Kingsley Development LLC', 'kingsley-development', 'A boutique practice with a global reach.', 'Kingsley Development is a developer operating from Sotogrande, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/kingsley-development.png', 'https://cdn.livfinder.com/covers/kingsley-development.jpg', 'hello@kingsley-development.com', '+971 4 580 4939', '+971 555669706', 'https://www.kingsley-development.com', '42 Sloane Street', 1207, 105325, 1900001, 50000376, '36.2870000', '-5.2810000', 2010, 248, 'active', 'verified', '2024-12-27 09:00:00', 1, 0, 142, 'Kingsley Development — Luxury Development in Sotogrande | Liv Finder', 'Browse Kingsley Development''s portfolio of luxury listings in Sotogrande and beyond.', '2024-12-20 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(21, 'broker_license', 'BR-202808', 'National Regulator', 1207, '2024-12-28', '2028-08-23', 'valid', '2025-01-04 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(21, 'Kingsley Development — Sotogrande HQ', 1, 'hello@kingsley-development.com', '+971 4 556 6736', '79 Marina Walk', 1207, 1900001, 50000376, '36.2870000', '-5.2810000', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(21, 1, 'approved', 200, '2024-12-20 09:00:00', '2024-12-23 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(21, 3, 'requested', '2026-07-30 09:00:00', 91);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(21, 1900001, 1),
(21, 50000376, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(21, 91, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-12-20 09:00:00'),
(21, 92, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-04-01 09:00:00'),
(21, 93, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-12-30 09:00:00'),
(21, 94, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-03-08 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(61, '01K2F2DKG09RJZ0FP8KRS00DDX', 91, 21, 'James', 'Mercer', 'James Mercer', 'james-mercer-61', 'Managing Director', 'James specialises in Sotogrande and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/james-mercer-61.jpg', 'james.mercer@kingsley-development.com', '+971 4 243 8954', '+971 534255153', 'BRN-78602', '2027-02-07', 21, 1207, 1900001, 'active', 'verified', '2025-01-09 09:00:00', 1, 0, '2025-02-25', 'James Mercer — Managing Director at Kingsley Development', '2024-12-20 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(61, 1, 'native'),
(61, 3, 'fluent'),
(61, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(61, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(61, 1900001, 1),
(61, 50000376, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(62, '01K2F2DKG0ZMYN64V9XWCZREV5', 92, 21, 'Julien', 'Beaumont', 'Julien Beaumont', 'julien-beaumont-62', 'Sales Manager', 'Julien specialises in Sotogrande and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/julien-beaumont-62.jpg', 'julien.beaumont@kingsley-development.com', '+971 4 873 2719', '+971 536177091', 'BRN-74239', '2027-01-16', 15, 1207, 1900001, 'active', 'verified', '2025-01-09 09:00:00', 1, 0, '2025-06-23', 'Julien Beaumont — Sales Manager at Kingsley Development', '2024-12-20 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(62, 1, 'native'),
(62, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(62, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(62, 1900001, 1),
(62, 50000376, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(63, '01K2F2DKG00ZSYECPRC6R1MK2Y', 93, 21, 'Chen', 'Hussein', 'Chen Hussein', 'chen-hussein-63', 'Senior Consultant', 'Chen specialises in Sotogrande and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/chen-hussein-63.jpg', 'chen.hussein@kingsley-development.com', '+971 4 353 4446', '+971 520417555', 'BRN-48349', '2028-07-15', 23, 1207, 1900001, 'active', 'verified', '2025-01-09 09:00:00', 1, 0, '2025-04-24', 'Chen Hussein — Senior Consultant at Kingsley Development', '2024-12-20 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(63, 1, 'native'),
(63, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(63, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(63, 1900001, 1),
(63, 50000376, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(22, '01K2F2DKG0691HM89B0ZC6BTEJ', 4, 95, 'Ridgeline Partners', 'ridgeline-partners', 'active', 'verified', '2023-05-30 09:00:00', 500, 100, 'billing@ridgeline-partners.com', 4, 1232, '2023-05-23 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(22, '01K2F2DKG04VDGNQSRVRB4GFBE', 22, 'marketing_partner', 'Ridgeline Partners', 'Ridgeline Partners LLC', 'ridgeline-partners', 'Discretion, precision, and an unrivalled portfolio.', 'Ridgeline Partners is a marketing partner operating from London, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/ridgeline-partners.png', 'https://cdn.livfinder.com/covers/ridgeline-partners.jpg', 'hello@ridgeline-partners.com', '+971 4 515 8226', '+971 549217044', 'https://www.ridgeline-partners.com', '41 Bahnhofstrasse', 1232, 102357, 1050388, 50000258, '51.5085300', '-0.1257400', 2021, 245, 'active', 'verified', '2023-05-30 09:00:00', 1, 0, 131, 'Ridgeline Partners — Luxury Partners in London | Liv Finder', 'Browse Ridgeline Partners''s portfolio of luxury listings in London and beyond.', '2023-05-23 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(22, 'broker_license', 'BR-388441', 'National Regulator', 1232, '2023-05-31', '2028-08-24', 'valid', '2023-06-07 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(22, 'Ridgeline Partners — London HQ', 1, 'hello@ridgeline-partners.com', '+971 4 560 5198', '9 Worth Avenue', 1232, 1050388, 50000258, '51.5085300', '-0.1257400', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(22, 1, 'approved', 500, '2023-05-23 09:00:00', '2023-05-26 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(22, 3, 'requested', '2026-07-13 09:00:00', 95);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(22, 1050388, 1),
(22, 50000258, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(22, 95, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-05-23 09:00:00'),
(22, 96, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-01-27 09:00:00'),
(22, 97, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-01-11 09:00:00'),
(22, 98, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-08-26 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(64, '01K2F2DKG08QE41GRVNCS6TG34', 95, 22, 'Hassan', 'Rossi', 'Hassan Rossi', 'hassan-rossi-64', 'Managing Director', 'Hassan specialises in London and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/hassan-rossi-64.jpg', 'hassan.rossi@ridgeline-partners.com', '+971 4 217 8540', '+971 543960551', 'BRN-23990', '2027-07-22', 6, 1232, 1050388, 'active', 'verified', '2023-06-12 09:00:00', 1, 0, '2023-10-30', 'Hassan Rossi — Managing Director at Ridgeline Partners', '2023-05-23 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(64, 1, 'native'),
(64, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(64, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(64, 1050388, 1),
(64, 50000258, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(65, '01K2F2DKG0H8GM788HYPNDXE69', 96, 22, 'Layla', 'Haddad', 'Layla Haddad', 'layla-haddad-65', 'Sales Manager', 'Layla specialises in London and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/layla-haddad-65.jpg', 'layla.haddad@ridgeline-partners.com', '+971 4 307 1149', '+971 512201738', 'BRN-15223', '2028-06-28', 20, 1232, 1050388, 'active', 'verified', '2023-06-12 09:00:00', 1, 0, '2023-11-07', 'Layla Haddad — Sales Manager at Ridgeline Partners', '2023-05-23 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(65, 1, 'native'),
(65, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(65, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(65, 1050388, 1),
(65, 50000258, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(66, '01K2F2DKG07Q8JV5ET612E2WMF', 97, 22, 'Tariq', 'Nasser', 'Tariq Nasser', 'tariq-nasser-66', 'Senior Consultant', 'Tariq specialises in London and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/tariq-nasser-66.jpg', 'tariq.nasser@ridgeline-partners.com', '+971 4 670 2778', '+971 525762031', 'BRN-66885', '2027-03-03', 19, 1232, 1050388, 'active', 'verified', '2023-06-12 09:00:00', 1, 0, '2023-10-26', 'Tariq Nasser — Senior Consultant at Ridgeline Partners', '2023-05-23 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(66, 1, 'native'),
(66, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(66, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(66, 1050388, 1),
(66, 50000258, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(23, '01K2F2DKG00MW9ZA86KT77D2HA', 3, 99, 'Vantage Properties', 'vantage-properties', 'active', 'verified', '2025-09-19 09:00:00', 50, 3, 'billing@vantage-properties.com', 2, 1233, '2025-09-12 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(23, '01K2F2DKG0X9VMDTETAE2R2K0F', 23, 'agency', 'Vantage Properties', 'Vantage Properties LLC', 'vantage-properties', 'Where exceptional assets meet exceptional clients.', 'Vantage Properties is a agency operating from Miami, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/vantage-properties.png', 'https://cdn.livfinder.com/covers/vantage-properties.jpg', 'hello@vantage-properties.com', '+971 4 312 9687', '+971 542314504', 'https://www.vantage-properties.com', '21 Avenue Montaigne', 1233, 101436, 1121746, 50000578, '25.7742700', '-80.1936600', 1998, 142, 'active', 'verified', '2025-09-19 09:00:00', 1, 0, 175, 'Vantage Properties — Luxury Properties in Miami | Liv Finder', 'Browse Vantage Properties''s portfolio of luxury listings in Miami and beyond.', '2025-09-12 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(23, 'broker_license', 'BR-795742', 'National Regulator', 1233, '2025-09-20', '2027-11-24', 'valid', '2025-09-27 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(23, 'Vantage Properties — Miami HQ', 1, 'hello@vantage-properties.com', '+971 4 896 2851', '20 Via Montenapoleone', 1233, 1121746, 50000578, '25.7742700', '-80.1936600', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(23, 1, 'approved', 50, '2025-09-12 09:00:00', '2025-09-15 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(23, 1121746, 1),
(23, 50000578, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(23, 99, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2025-09-12 09:00:00'),
(23, 100, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-11-07 09:00:00'),
(23, 101, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2026-06-17 09:00:00'),
(23, 102, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-12-25 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(67, '01K2F2DKG0V838DMEX1RRC88B0', 99, 23, 'Rania', 'Al Suwaidi', 'Rania Al Suwaidi', 'rania-al-suwaidi-67', 'Managing Director', 'Rania specialises in Miami and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rania-al-suwaidi-67.jpg', 'rania.al-suwaidi@vantage-properties.com', '+971 4 526 9842', '+971 555527621', 'BRN-60595', '2026-12-03', 17, 1233, 1121746, 'active', 'verified', '2025-10-02 09:00:00', 1, 0, '2026-03-09', 'Rania Al Suwaidi — Managing Director at Vantage Properties', '2025-09-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(67, 1, 'native'),
(67, 2, 'fluent'),
(67, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(67, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(67, 1121746, 1),
(67, 50000578, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(68, '01K2F2DKG031DMKBS3HDKCA63D', 100, 23, 'Chen', 'Bin Ahmed', 'Chen Bin Ahmed', 'chen-bin-ahmed-68', 'Sales Manager', 'Chen specialises in Miami and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/chen-bin-ahmed-68.jpg', 'chen.bin-ahmed@vantage-properties.com', '+971 4 520 4785', '+971 530896337', 'BRN-67316', '2026-11-28', 10, 1233, 1121746, 'active', 'verified', '2025-10-02 09:00:00', 1, 0, '2026-01-10', 'Chen Bin Ahmed — Sales Manager at Vantage Properties', '2025-09-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(68, 1, 'native'),
(68, 5, 'fluent'),
(68, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(68, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(68, 1121746, 1),
(68, 50000578, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(69, '01K2F2DKG05JSM5DZTDXG1Z4PA', 101, 23, 'Zainab', 'Mercer', 'Zainab Mercer', 'zainab-mercer-69', 'Senior Consultant', 'Zainab specialises in Miami and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/zainab-mercer-69.jpg', 'zainab.mercer@vantage-properties.com', '+971 4 588 2298', '+971 545923268', 'BRN-44233', '2027-12-12', 19, 1233, 1121746, 'active', 'verified', '2025-10-02 09:00:00', 1, 0, '2025-10-15', 'Zainab Mercer — Senior Consultant at Vantage Properties', '2025-09-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(69, 1, 'native'),
(69, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(69, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(69, 1121746, 1),
(69, 50000578, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(24, '01K2F2DKG0ESEFPBG2WP1671GJ', 3, 103, 'Solstice Real Estate', 'solstice-real-estate', 'active', 'verified', '2025-02-23 09:00:00', 50, 3, 'billing@solstice-real-estate.com', 1, 1231, '2025-02-16 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(24, '01K2F2DKG0M38V4YAK4RQNM2R5', 24, 'agency', 'Solstice Real Estate', 'Solstice Real Estate LLC', 'solstice-real-estate', 'Discretion, precision, and an unrivalled portfolio.', 'Solstice Real Estate is a agency operating from Abu Dhabi, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/solstice-real-estate.png', 'https://cdn.livfinder.com/covers/solstice-real-estate.jpg', 'hello@solstice-real-estate.com', '+971 4 360 7834', '+971 545894526', 'https://www.solstice-real-estate.com', '85 The Crescent', 1231, 103396, 1000012, 50000119, '24.4136100', '54.4329500', 2016, 262, 'active', 'verified', '2025-02-23 09:00:00', 1, 0, 77, 'Solstice Real Estate — Luxury Real Estate in Abu Dhabi | Liv Finder', 'Browse Solstice Real Estate''s portfolio of luxury listings in Abu Dhabi and beyond.', '2025-02-16 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(24, 'rera', '39217', 'Dubai Land Department', 1231, '2025-02-26', '2027-06-10', 'valid', '2025-03-02 09:00:00'),
(24, 'trade_license', 'CN-8102386', 'Dubai Department of Economy and Tourism', 1231, '2025-02-21', '2027-09-22', 'valid', '2025-02-28 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(24, 'Solstice Real Estate — Abu Dhabi HQ', 1, 'hello@solstice-real-estate.com', '+971 4 807 7902', '19 Bahnhofstrasse', 1231, 1000012, 50000119, '24.4136100', '54.4329500', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(24, 1, 'approved', 50, '2025-02-16 09:00:00', '2025-02-19 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(24, 2, 'requested', '2026-07-31 09:00:00', 103);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(24, 1000012, 1),
(24, 50000119, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(24, 103, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2025-02-16 09:00:00'),
(24, 104, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-09-15 09:00:00'),
(24, 105, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-10-25 09:00:00'),
(24, 106, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-02-25 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(70, '01K2F2DKG0K7JFEEPFM3BM474T', 103, 24, 'Omar', 'Herrera', 'Omar Herrera', 'omar-herrera-70', 'Managing Director', 'Omar specialises in Abu Dhabi and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/omar-herrera-70.jpg', 'omar.herrera@solstice-real-estate.com', '+971 4 650 8507', '+971 555073409', 'BRN-19672', '2028-04-16', 15, 1231, 1000012, 'active', 'verified', '2025-03-08 09:00:00', 1, 0, '2025-08-23', 'Omar Herrera — Managing Director at Solstice Real Estate', '2025-02-16 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(70, 1, 'native'),
(70, 6, 'fluent'),
(70, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(70, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(70, 1000012, 1),
(70, 50000119, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(71, '01K2F2DKG07WV2X9KXDS1T9NGS', 104, 24, 'Noor', 'Darwish', 'Noor Darwish', 'noor-darwish-71', 'Sales Manager', 'Noor specialises in Abu Dhabi and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/noor-darwish-71.jpg', 'noor.darwish@solstice-real-estate.com', '+971 4 331 5208', '+971 517999428', 'BRN-35099', '2028-06-23', 5, 1231, 1000012, 'active', 'verified', '2025-03-08 09:00:00', 1, 0, '2025-06-10', 'Noor Darwish — Sales Manager at Solstice Real Estate', '2025-02-16 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(71, 1, 'native'),
(71, 5, 'fluent'),
(71, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(71, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(71, 1000012, 1),
(71, 50000119, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(72, '01K2F2DKG0A4X745YF6RHE9PQ1', 105, 24, 'Sarah', 'Bakr', 'Sarah Bakr', 'sarah-bakr-72', 'Senior Consultant', 'Sarah specialises in Abu Dhabi and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/sarah-bakr-72.jpg', 'sarah.bakr@solstice-real-estate.com', '+971 4 843 8961', '+971 517157646', 'BRN-24433', '2027-08-19', 3, 1231, 1000012, 'active', 'verified', '2025-03-08 09:00:00', 1, 0, '2025-07-23', 'Sarah Bakr — Senior Consultant at Solstice Real Estate', '2025-02-16 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(72, 1, 'native'),
(72, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(72, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(72, 1000012, 1),
(72, 50000119, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(25, '01K2F2DKG0AS73EV9196X0Q7G0', 4, 107, 'Arcadia Estates', 'arcadia-estates', 'active', 'verified', '2024-04-10 09:00:00', 500, 100, 'billing@arcadia-estates.com', 3, 1075, '2024-04-03 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(25, '01K2F2DKG06CA7STGQS5B68NHV', 25, 'brokerage', 'Arcadia Estates', 'Arcadia Estates LLC', 'arcadia-estates', 'Discretion, precision, and an unrivalled portfolio.', 'Arcadia Estates is a brokerage operating from Saint-Tropez, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/arcadia-estates.png', 'https://cdn.livfinder.com/covers/arcadia-estates.jpg', 'hello@arcadia-estates.com', '+971 4 486 2359', '+971 516720713', 'https://www.arcadia-estates.com', '79 Al Sufouh Road', 1075, 105051, 1046589, 50000310, '43.2676400', '6.6404900', 2000, 128, 'active', 'verified', '2024-04-10 09:00:00', 1, 0, 140, 'Arcadia Estates — Luxury Estates in Saint-Tropez | Liv Finder', 'Browse Arcadia Estates''s portfolio of luxury listings in Saint-Tropez and beyond.', '2024-04-03 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(25, 'broker_license', 'BR-166917', 'National Regulator', 1075, '2024-04-11', '2027-04-08', 'valid', '2024-04-18 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(25, 'Arcadia Estates — Saint-Tropez HQ', 1, 'hello@arcadia-estates.com', '+971 4 361 5290', '68 Umm Suqeim Road', 1075, 1046589, 50000310, '43.2676400', '6.6404900', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(25, 1, 'approved', 500, '2024-04-03 09:00:00', '2024-04-06 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(25, 6, 'requested', '2026-07-22 09:00:00', 107);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(25, 1046589, 1),
(25, 50000310, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(25, 107, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-04-03 09:00:00'),
(25, 108, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-04-12 09:00:00'),
(25, 109, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-06-27 09:00:00'),
(25, 110, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-06-03 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(73, '01K2F2DKG02JS2DS5E4JKJDQYP', 107, 25, 'Elena', 'Kapoor', 'Elena Kapoor', 'elena-kapoor-73', 'Managing Director', 'Elena specialises in Saint-Tropez and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/elena-kapoor-73.jpg', 'elena.kapoor@arcadia-estates.com', '+971 4 279 9618', '+971 510086068', 'BRN-63497', '2027-06-01', 11, 1075, 1046589, 'active', 'verified', '2024-04-23 09:00:00', 1, 0, '2024-04-26', 'Elena Kapoor — Managing Director at Arcadia Estates', '2024-04-03 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(73, 1, 'native'),
(73, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(73, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(73, 1046589, 1),
(73, 50000310, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(74, '01K2F2DKG0FZKRA43W5FQDJPJZ', 108, 25, 'Karim', 'Mercer', 'Karim Mercer', 'karim-mercer-74', 'Sales Manager', 'Karim specialises in Saint-Tropez and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/karim-mercer-74.jpg', 'karim.mercer@arcadia-estates.com', '+971 4 329 9566', '+971 528993544', 'BRN-71502', '2028-06-13', 20, 1075, 1046589, 'active', 'verified', '2024-04-23 09:00:00', 1, 0, '2024-05-02', 'Karim Mercer — Sales Manager at Arcadia Estates', '2024-04-03 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(74, 1, 'native'),
(74, 8, 'fluent'),
(74, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(74, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(74, 1046589, 1),
(74, 50000310, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(75, '01K2F2DKG09BN4CW1STNCBHVE6', 109, 25, 'Layla', 'Ferrari', 'Layla Ferrari', 'layla-ferrari-75', 'Senior Consultant', 'Layla specialises in Saint-Tropez and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/layla-ferrari-75.jpg', 'layla.ferrari@arcadia-estates.com', '+971 4 224 8148', '+971 537006152', 'BRN-43702', '2027-07-15', 17, 1075, 1046589, 'active', 'verified', '2024-04-23 09:00:00', 1, 1, '2024-10-09', 'Layla Ferrari — Senior Consultant at Arcadia Estates', '2024-04-03 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(75, 1, 'native'),
(75, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(75, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(75, 1046589, 1),
(75, 50000310, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(26, '01K2F2DKG0FHHAA7H860RTZNH3', 3, 111, 'Belmont Motors', 'belmont-motors', 'active', 'verified', '2024-05-25 09:00:00', 50, 3, 'billing@belmont-motors.com', 13, 1014, '2024-05-18 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(26, '01K2F2DKG0W0PRMECWSQ2TDSWT', 26, 'dealership', 'Belmont Motors', 'Belmont Motors LLC', 'belmont-motors', 'Where exceptional assets meet exceptional clients.', 'Belmont Motors is a dealership operating from Sydney, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/belmont-motors.png', 'https://cdn.livfinder.com/covers/belmont-motors.jpg', 'hello@belmont-motors.com', '+971 4 664 4582', '+971 532464105', 'https://www.belmont-motors.com', '37 Sloane Street', 1014, 103909, 1007408, 50000776, '-33.8678500', '151.2073200', 2014, 50, 'active', 'verified', '2024-05-25 09:00:00', 1, 0, 171, 'Belmont Motors — Luxury Motors in Sydney | Liv Finder', 'Browse Belmont Motors''s portfolio of luxury listings in Sydney and beyond.', '2024-05-18 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(26, 'broker_license', 'BR-988110', 'National Regulator', 1014, '2024-05-26', '2027-01-24', 'valid', '2024-06-02 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(26, 'Belmont Motors — Sydney HQ', 1, 'hello@belmont-motors.com', '+971 4 200 8126', '69 Collins Avenue', 1014, 1007408, 50000776, '-33.8678500', '151.2073200', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(26, 2, 'approved', 50, '2024-05-18 09:00:00', '2024-05-21 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(26, 6, 'requested', '2026-07-26 09:00:00', 111);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(26, 1007408, 1),
(26, 50000776, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(26, 111, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-05-18 09:00:00'),
(26, 112, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-05-29 09:00:00'),
(26, 113, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-08-20 09:00:00'),
(26, 114, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-10-28 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(76, '01K2F2DKG0JP06XF02CD4JKQTA', 111, 26, 'Tariq', 'Sato', 'Tariq Sato', 'tariq-sato-76', 'Managing Director', 'Tariq specialises in Sydney and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/tariq-sato-76.jpg', 'tariq.sato@belmont-motors.com', '+971 4 560 3571', '+971 538976252', 'BRN-78591', '2027-11-11', 6, 1014, 1007408, 'active', 'verified', '2024-06-07 09:00:00', 1, 0, '2024-09-04', 'Tariq Sato — Managing Director at Belmont Motors', '2024-05-18 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(76, 1, 'native'),
(76, 3, 'fluent'),
(76, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(76, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(76, 1007408, 1),
(76, 50000776, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(77, '01K2F2DKG07XTSK9D1DW8Z94NW', 112, 26, 'Elena', 'Al Zaabi', 'Elena Al Zaabi', 'elena-al-zaabi-77', 'Sales Manager', 'Elena specialises in Sydney and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/elena-al-zaabi-77.jpg', 'elena.al-zaabi@belmont-motors.com', '+971 4 332 9908', '+971 543276270', 'BRN-30826', '2027-12-16', 21, 1014, 1007408, 'active', 'verified', '2024-06-07 09:00:00', 1, 0, '2024-09-10', 'Elena Al Zaabi — Sales Manager at Belmont Motors', '2024-05-18 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(77, 1, 'native'),
(77, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(77, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(77, 1007408, 1),
(77, 50000776, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(78, '01K2F2DKG0SZ21GDS3FZYCW2PP', 113, 26, 'Khalid', 'Moretti', 'Khalid Moretti', 'khalid-moretti-78', 'Senior Consultant', 'Khalid specialises in Sydney and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/khalid-moretti-78.jpg', 'khalid.moretti@belmont-motors.com', '+971 4 336 6740', '+971 520843022', 'BRN-31657', '2027-02-18', 16, 1014, 1007408, 'active', 'verified', '2024-06-07 09:00:00', 1, 1, '2024-08-16', 'Khalid Moretti — Senior Consultant at Belmont Motors', '2024-05-18 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(78, 1, 'native'),
(78, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(78, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(78, 1007408, 1),
(78, 50000776, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(27, '01K2F2DKG0SK00CZ5W0QJ0C7CZ', 3, 115, 'Cortona Automotive', 'cortona-automotive', 'active', 'verified', '2024-01-25 09:00:00', 50, 3, 'billing@cortona-automotive.com', 1, 1231, '2024-01-18 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(27, '01K2F2DKG0FPK28TSJYANG4PCS', 27, 'dealership', 'Cortona Automotive', 'Cortona Automotive LLC', 'cortona-automotive', 'Where exceptional assets meet exceptional clients.', 'Cortona Automotive is a dealership operating from Dubai, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/cortona-automotive.png', 'https://cdn.livfinder.com/covers/cortona-automotive.jpg', 'hello@cortona-automotive.com', '+971 4 338 2435', '+971 523800403', 'https://www.cortona-automotive.com', '3 Avenue Montaigne', 1231, 103391, 1000032, 50000060, '25.0657000', '55.1712800', 2002, 104, 'active', 'verified', '2024-01-25 09:00:00', 1, 0, 108, 'Cortona Automotive — Luxury Automotive in Dubai | Liv Finder', 'Browse Cortona Automotive''s portfolio of luxury listings in Dubai and beyond.', '2024-01-18 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(27, 'rera', '31951', 'Dubai Land Department', 1231, '2024-01-28', '2027-01-06', 'valid', '2024-02-01 09:00:00'),
(27, 'trade_license', 'CN-2524629', 'Dubai Department of Economy and Tourism', 1231, '2024-01-23', '2027-11-11', 'valid', '2024-01-30 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(27, 'Cortona Automotive — Dubai HQ', 1, 'hello@cortona-automotive.com', '+971 4 371 6444', '37 Avenue Montaigne', 1231, 1000032, 50000060, '25.0657000', '55.1712800', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(27, 2, 'approved', 50, '2024-01-18 09:00:00', '2024-01-21 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(27, 3, 'requested', '2026-08-13 09:00:00', 115);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(27, 1000032, 1),
(27, 50000060, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(27, 115, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-01-18 09:00:00'),
(27, 116, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-07-13 09:00:00'),
(27, 117, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-03-29 09:00:00'),
(27, 118, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-04-26 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(79, '01K2F2DKG0XE9E541HXJZAV0EA', 115, 27, 'Hassan', 'Meyer', 'Hassan Meyer', 'hassan-meyer-79', 'Managing Director', 'Hassan specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/hassan-meyer-79.jpg', 'hassan.meyer@cortona-automotive.com', '+971 4 559 3037', '+971 556813639', 'BRN-60585', '2027-05-29', 13, 1231, 1000032, 'active', 'verified', '2024-02-07 09:00:00', 1, 0, '2024-04-16', 'Hassan Meyer — Managing Director at Cortona Automotive', '2024-01-18 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(79, 1, 'native'),
(79, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(79, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(79, 1000032, 1),
(79, 50000060, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(80, '01K2F2DKG07TZSC33BDKMN1MTF', 116, 27, 'Mohammed', 'Volkov', 'Mohammed Volkov', 'mohammed-volkov-80', 'Sales Manager', 'Mohammed specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/mohammed-volkov-80.jpg', 'mohammed.volkov@cortona-automotive.com', '+971 4 548 5414', '+971 533751232', 'BRN-43697', '2027-06-04', 6, 1231, 1000032, 'active', 'verified', '2024-02-07 09:00:00', 1, 0, '2024-03-05', 'Mohammed Volkov — Sales Manager at Cortona Automotive', '2024-01-18 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(80, 1, 'native'),
(80, 3, 'fluent'),
(80, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(80, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(80, 1000032, 1),
(80, 50000060, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(81, '01K2F2DKG0S3HZN4MJBYG79RK4', 117, 27, 'Fatima', 'Whitfield', 'Fatima Whitfield', 'fatima-whitfield-81', 'Senior Consultant', 'Fatima specialises in Dubai and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/fatima-whitfield-81.jpg', 'fatima.whitfield@cortona-automotive.com', '+971 4 406 9702', '+971 536318262', 'BRN-75996', '2027-02-05', 17, 1231, 1000032, 'active', 'verified', '2024-02-07 09:00:00', 1, 0, '2024-06-19', 'Fatima Whitfield — Senior Consultant at Cortona Automotive', '2024-01-18 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(81, 1, 'native'),
(81, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(81, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(81, 1000032, 1),
(81, 50000060, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(28, '01K2F2DKG0F5YCAS556QBPXWKW', 4, 119, 'Delmar Yachts', 'delmar-yachts', 'active', 'verified', '2024-10-25 09:00:00', 500, 100, 'billing@delmar-yachts.com', 3, 1085, '2024-10-18 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(28, '01K2F2DKG0DN5Q0G9W5YMFMPM6', 28, 'yacht_broker', 'Delmar Yachts', 'Delmar Yachts LLC', 'delmar-yachts', 'A boutique practice with a global reach.', 'Delmar Yachts is a yacht broker operating from Mykonos, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/delmar-yachts.png', 'https://cdn.livfinder.com/covers/delmar-yachts.jpg', 'hello@delmar-yachts.com', '+971 4 273 4397', '+971 526630521', 'https://www.delmar-yachts.com', '75 Marina Walk', 1085, 102118, 1052950, 50000487, '37.4452900', '25.3287200', 2017, 148, 'active', 'verified', '2024-10-25 09:00:00', 1, 0, 173, 'Delmar Yachts — Luxury Yachts in Mykonos | Liv Finder', 'Browse Delmar Yachts''s portfolio of luxury listings in Mykonos and beyond.', '2024-10-18 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(28, 'broker_license', 'BR-705240', 'National Regulator', 1085, '2024-10-26', '2028-08-25', 'valid', '2024-11-02 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(28, 'Delmar Yachts — Mykonos HQ', 1, 'hello@delmar-yachts.com', '+971 4 622 4885', '52 Collins Avenue', 1085, 1052950, 50000487, '37.4452900', '25.3287200', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(28, 3, 'approved', 500, '2024-10-18 09:00:00', '2024-10-21 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(28, 1052950, 1),
(28, 50000487, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(28, 119, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-10-18 09:00:00'),
(28, 120, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-05-21 09:00:00'),
(28, 121, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-05-27 09:00:00'),
(28, 122, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-05-19 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(82, '01K2F2DKG0CABVRA3B8GRRKW6K', 119, 28, 'Nikolai', 'Halabi', 'Nikolai Halabi', 'nikolai-halabi-82', 'Managing Director', 'Nikolai specialises in Mykonos and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/nikolai-halabi-82.jpg', 'nikolai.halabi@delmar-yachts.com', '+971 4 245 6310', '+971 513441599', 'BRN-58858', '2028-05-08', 24, 1085, 1052950, 'active', 'verified', '2024-11-07 09:00:00', 1, 0, '2025-03-02', 'Nikolai Halabi — Managing Director at Delmar Yachts', '2024-10-18 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(82, 1, 'native'),
(82, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(82, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(82, 1052950, 1),
(82, 50000487, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(83, '01K2F2DKG0TY3VBHDZMTT7N5RE', 120, 28, 'Sarah', 'Al Zaabi', 'Sarah Al Zaabi', 'sarah-al-zaabi-83', 'Sales Manager', 'Sarah specialises in Mykonos and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/sarah-al-zaabi-83.jpg', 'sarah.al-zaabi@delmar-yachts.com', '+971 4 512 6764', '+971 518955636', 'BRN-62831', '2028-01-18', 3, 1085, 1052950, 'active', 'verified', '2024-11-07 09:00:00', 1, 0, '2025-04-22', 'Sarah Al Zaabi — Sales Manager at Delmar Yachts', '2024-10-18 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(83, 1, 'native'),
(83, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(83, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(83, 1052950, 1),
(83, 50000487, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(84, '01K2F2DKG0HYV4XDMT80BBW2ES', 121, 28, 'Isabella', 'Al Zaabi', 'Isabella Al Zaabi', 'isabella-al-zaabi-84', 'Senior Consultant', 'Isabella specialises in Mykonos and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/isabella-al-zaabi-84.jpg', 'isabella.al-zaabi@delmar-yachts.com', '+971 4 262 3592', '+971 528463858', 'BRN-64109', '2026-11-19', 10, 1085, 1052950, 'active', 'verified', '2024-11-07 09:00:00', 1, 0, '2024-10-29', 'Isabella Al Zaabi — Senior Consultant at Delmar Yachts', '2024-10-18 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(84, 1, 'native'),
(84, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(84, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(84, 1052950, 1),
(84, 50000487, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(29, '01K2F2DKG0RDXPF8YPTVESZEQA', 3, 123, 'Everline Marine', 'everline-marine', 'active', 'verified', '2023-06-01 09:00:00', 50, 3, 'billing@everline-marine.com', 3, 1075, '2023-05-25 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(29, '01K2F2DKG0CBR48H56A8W6EEV4', 29, 'yacht_broker', 'Everline Marine', 'Everline Marine LLC', 'everline-marine', 'A boutique practice with a global reach.', 'Everline Marine is a yacht broker operating from Paris, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/everline-marine.png', 'https://cdn.livfinder.com/covers/everline-marine.jpg', 'hello@everline-marine.com', '+971 4 415 5190', '+971 526500145', 'https://www.everline-marine.com', '11 Jumeirah Beach Road', 1075, 104816, 1044856, 50000290, '48.8534000', '2.3486000', 2021, 312, 'active', 'verified', '2023-06-01 09:00:00', 1, 0, 22, 'Everline Marine — Luxury Marine in Paris | Liv Finder', 'Browse Everline Marine''s portfolio of luxury listings in Paris and beyond.', '2023-05-25 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(29, 'broker_license', 'BR-558532', 'National Regulator', 1075, '2023-06-02', '2027-06-28', 'valid', '2023-06-09 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(29, 'Everline Marine — Paris HQ', 1, 'hello@everline-marine.com', '+971 4 810 6294', '13 Marina Walk', 1075, 1044856, 50000290, '48.8534000', '2.3486000', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(29, 3, 'approved', 50, '2023-05-25 09:00:00', '2023-05-28 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(29, 1044856, 1),
(29, 50000290, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(29, 123, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-05-25 09:00:00'),
(29, 124, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-06-08 09:00:00'),
(29, 125, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-09-15 09:00:00'),
(29, 126, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-11-12 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(85, '01K2F2DKG00YE8HHRQM442TTDH', 123, 29, 'Rashid', 'Tanaka', 'Rashid Tanaka', 'rashid-tanaka-85', 'Managing Director', 'Rashid specialises in Paris and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rashid-tanaka-85.jpg', 'rashid.tanaka@everline-marine.com', '+971 4 811 7293', '+971 539879706', 'BRN-73519', '2028-01-26', 8, 1075, 1044856, 'active', 'verified', '2023-06-14 09:00:00', 1, 0, '2023-10-27', 'Rashid Tanaka — Managing Director at Everline Marine', '2023-05-25 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(85, 1, 'native'),
(85, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(85, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(85, 1044856, 1),
(85, 50000290, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(86, '01K2F2DKG02KTREQAAMHD5AXJ8', 124, 29, 'Isabella', 'Rossellini', 'Isabella Rossellini', 'isabella-rossellini-86', 'Sales Manager', 'Isabella specialises in Paris and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/isabella-rossellini-86.jpg', 'isabella.rossellini@everline-marine.com', '+971 4 677 5315', '+971 526396866', 'BRN-55372', '2027-10-09', 22, 1075, 1044856, 'active', 'verified', '2023-06-14 09:00:00', 1, 1, '2023-07-13', 'Isabella Rossellini — Sales Manager at Everline Marine', '2023-05-25 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(86, 1, 'native'),
(86, 6, 'fluent'),
(86, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(86, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(86, 1044856, 1),
(86, 50000290, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(87, '01K2F2DKG0S9F9AMJHBHGJK6H8', 125, 29, 'James', 'Dubois', 'James Dubois', 'james-dubois-87', 'Senior Consultant', 'James specialises in Paris and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/james-dubois-87.jpg', 'james.dubois@everline-marine.com', '+971 4 268 8404', '+971 542910149', 'BRN-47114', '2026-10-19', 15, 1075, 1044856, 'active', 'verified', '2023-06-14 09:00:00', 1, 0, '2023-11-25', 'James Dubois — Senior Consultant at Everline Marine', '2023-05-25 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(87, 1, 'native'),
(87, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(87, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(87, 1044856, 1),
(87, 50000290, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(30, '01K2F2DKG0RWKT7KEY7WNF61CS', 3, 127, 'Foxhall Aviation', 'foxhall-aviation', 'active', 'verified', '2023-02-03 09:00:00', 50, 3, 'billing@foxhall-aviation.com', 2, 1233, '2023-01-27 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(30, '01K2F2DKG0B8QW8W9BRZKSQDZ2', 30, 'aviation_broker', 'Foxhall Aviation', 'Foxhall Aviation LLC', 'foxhall-aviation', 'Curating the finest addresses since day one.', 'Foxhall Aviation is a aviation broker operating from Miami, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/foxhall-aviation.png', 'https://cdn.livfinder.com/covers/foxhall-aviation.jpg', 'hello@foxhall-aviation.com', '+971 4 201 3871', '+971 553271225', 'https://www.foxhall-aviation.com', '16 Passeig de Gràcia', 1233, 101436, 1121746, 50000577, '25.7742700', '-80.1936600', 2000, 53, 'active', 'verified', '2023-02-03 09:00:00', 1, 0, 154, 'Foxhall Aviation — Luxury Aviation in Miami | Liv Finder', 'Browse Foxhall Aviation''s portfolio of luxury listings in Miami and beyond.', '2023-01-27 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(30, 'broker_license', 'BR-880030', 'National Regulator', 1233, '2023-02-04', '2027-06-14', 'valid', '2023-02-11 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(30, 'Foxhall Aviation — Miami HQ', 1, 'hello@foxhall-aviation.com', '+971 4 683 5069', '7 Hessa Street', 1233, 1121746, 50000577, '25.7742700', '-80.1936600', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(30, 4, 'approved', 50, '2023-01-27 09:00:00', '2023-01-30 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(30, 1121746, 1),
(30, 50000577, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(30, 127, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-01-27 09:00:00'),
(30, 128, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-02-16 09:00:00'),
(30, 129, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-08-01 09:00:00'),
(30, 130, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-05-15 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(88, '01K2F2DKG0GPXBDXKYF183TMRY', 127, 30, 'Youssef', 'Rahman', 'Youssef Rahman', 'youssef-rahman-88', 'Managing Director', 'Youssef specialises in Miami and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/youssef-rahman-88.jpg', 'youssef.rahman@foxhall-aviation.com', '+971 4 530 5241', '+971 516250118', 'BRN-40738', '2026-09-22', 22, 1233, 1121746, 'active', 'verified', '2023-02-16 09:00:00', 1, 0, '2023-03-18', 'Youssef Rahman — Managing Director at Foxhall Aviation', '2023-01-27 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(88, 1, 'native'),
(88, 2, 'fluent'),
(88, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(88, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(88, 1121746, 1),
(88, 50000577, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(89, '01K2F2DKG0T1A3TMZB8TX18PZ0', 128, 30, 'Chen', 'Volkov', 'Chen Volkov', 'chen-volkov-89', 'Sales Manager', 'Chen specialises in Miami and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/chen-volkov-89.jpg', 'chen.volkov@foxhall-aviation.com', '+971 4 672 4100', '+971 534031098', 'BRN-43543', '2026-10-16', 19, 1233, 1121746, 'active', 'verified', '2023-02-16 09:00:00', 1, 0, '2023-03-19', 'Chen Volkov — Sales Manager at Foxhall Aviation', '2023-01-27 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(89, 1, 'native'),
(89, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(89, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(89, 1121746, 1),
(89, 50000577, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(90, '01K2F2DKG0T9CGXF58R98CW09P', 129, 30, 'Sarah', 'Whitfield', 'Sarah Whitfield', 'sarah-whitfield-90', 'Senior Consultant', 'Sarah specialises in Miami and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/sarah-whitfield-90.jpg', 'sarah.whitfield@foxhall-aviation.com', '+971 4 679 1194', '+971 544915914', 'BRN-57979', '2028-03-02', 4, 1233, 1121746, 'active', 'verified', '2023-02-16 09:00:00', 1, 0, '2023-08-15', 'Sarah Whitfield — Senior Consultant at Foxhall Aviation', '2023-01-27 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(90, 1, 'native'),
(90, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(90, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(90, 1121746, 1),
(90, 50000577, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(31, '01K2F2DKG0CBDGGRKVWRZRVY9Q', 4, 131, 'Prime Timepieces', 'prime-timepieces', 'active', 'verified', '2022-12-19 09:00:00', 500, 100, 'billing@prime-timepieces.com', 5, 1214, '2022-12-12 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(31, '01K2F2DKG0B3VXPKZCM7923W45', 31, 'watch_dealer', 'Prime Timepieces', 'Prime Timepieces LLC', 'prime-timepieces', 'Where exceptional assets meet exceptional clients.', 'Prime Timepieces is a watch dealer operating from Geneva, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/prime-timepieces.png', 'https://cdn.livfinder.com/covers/prime-timepieces.jpg', 'hello@prime-timepieces.com', '+971 4 846 9654', '+971 540332918', 'https://www.prime-timepieces.com', '41 Jumeirah Beach Road', 1214, 101647, 1017827, 50000443, '46.2022200', '6.1456900', 2010, 78, 'active', 'verified', '2022-12-19 09:00:00', 1, 0, 107, 'Prime Timepieces — Luxury Timepieces in Geneva | Liv Finder', 'Browse Prime Timepieces''s portfolio of luxury listings in Geneva and beyond.', '2022-12-12 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(31, 'broker_license', 'BR-312660', 'National Regulator', 1214, '2022-12-20', '2028-08-22', 'valid', '2022-12-27 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(31, 'Prime Timepieces — Geneva HQ', 1, 'hello@prime-timepieces.com', '+971 4 422 3279', '73 Hessa Street', 1214, 1017827, 50000443, '46.2022200', '6.1456900', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(31, 6, 'approved', 500, '2022-12-12 09:00:00', '2022-12-15 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(31, 1017827, 1),
(31, 50000443, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(31, 131, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2022-12-12 09:00:00'),
(31, 132, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-07-13 09:00:00'),
(31, 133, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-06-10 09:00:00'),
(31, 134, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-04-22 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(91, '01K2F2DKG056N8BPA8F91889ZH', 131, 31, 'Rania', 'Nasser', 'Rania Nasser', 'rania-nasser-91', 'Managing Director', 'Rania specialises in Geneva and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rania-nasser-91.jpg', 'rania.nasser@prime-timepieces.com', '+971 4 255 2258', '+971 525018709', 'BRN-18044', '2027-12-11', 20, 1214, 1017827, 'active', 'verified', '2023-01-01 09:00:00', 1, 1, '2023-05-28', 'Rania Nasser — Managing Director at Prime Timepieces', '2022-12-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(91, 1, 'native'),
(91, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(91, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(91, 1017827, 1),
(91, 50000443, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(92, '01K2F2DKG0CH6CJJGYGHZY0MS6', 132, 31, 'Khalid', 'Ivanov', 'Khalid Ivanov', 'khalid-ivanov-92', 'Sales Manager', 'Khalid specialises in Geneva and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/khalid-ivanov-92.jpg', 'khalid.ivanov@prime-timepieces.com', '+971 4 343 5455', '+971 548936562', 'BRN-69358', '2028-05-10', 6, 1214, 1017827, 'active', 'verified', '2023-01-01 09:00:00', 1, 1, '2022-12-21', 'Khalid Ivanov — Sales Manager at Prime Timepieces', '2022-12-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(92, 1, 'native'),
(92, 4, 'fluent'),
(92, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(92, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(92, 1017827, 1),
(92, 50000443, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(93, '01K2F2DKG0AKTEWAHRYBX0H1HZ', 133, 31, 'Zainab', 'Nasser', 'Zainab Nasser', 'zainab-nasser-93', 'Senior Consultant', 'Zainab specialises in Geneva and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/zainab-nasser-93.jpg', 'zainab.nasser@prime-timepieces.com', '+971 4 527 3780', '+971 511445807', 'BRN-75937', '2028-01-18', 4, 1214, 1017827, 'active', 'verified', '2023-01-01 09:00:00', 1, 0, '2023-04-17', 'Zainab Nasser — Senior Consultant at Prime Timepieces', '2022-12-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(93, 1, 'native'),
(93, 4, 'fluent'),
(93, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(93, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(93, 1017827, 1),
(93, 50000443, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(32, '01K2F2DKG0VS418CRXN5HPX63C', 5, 135, 'Luxhabitat Development', 'luxhabitat-development', 'active', 'verified', '2023-10-26 09:00:00', 200, 50, 'billing@luxhabitat-development.com', 3, 1207, '2023-10-19 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(32, '01K2F2DKG0QF6XW5DVV8HXWH6K', 32, 'developer', 'Luxhabitat Development', 'Luxhabitat Development LLC', 'luxhabitat-development', 'Discretion, precision, and an unrivalled portfolio.', 'Luxhabitat Development is a developer operating from Madrid, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/luxhabitat-development.png', 'https://cdn.livfinder.com/covers/luxhabitat-development.jpg', 'hello@luxhabitat-development.com', '+971 4 227 8505', '+971 551683005', 'https://www.luxhabitat-development.com', '69 Al Khail Road', 1207, 101158, 1035186, 50000348, '40.4165000', '-3.7025600', 2021, 319, 'active', 'verified', '2023-10-26 09:00:00', 1, 0, 43, 'Luxhabitat Development — Luxury Development in Madrid | Liv Finder', 'Browse Luxhabitat Development''s portfolio of luxury listings in Madrid and beyond.', '2023-10-19 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(32, 'broker_license', 'BR-938445', 'National Regulator', 1207, '2023-10-27', '2027-05-29', 'valid', '2023-11-03 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(32, 'Luxhabitat Development — Madrid HQ', 1, 'hello@luxhabitat-development.com', '+971 4 472 3960', '25 Worth Avenue', 1207, 1035186, 50000348, '40.4165000', '-3.7025600', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(32, 1, 'approved', 200, '2023-10-19 09:00:00', '2023-10-22 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(32, 4, 'requested', '2026-08-09 09:00:00', 135);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(32, 1035186, 1),
(32, 50000348, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(32, 135, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-10-19 09:00:00'),
(32, 136, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-03-29 09:00:00'),
(32, 137, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-02-14 09:00:00'),
(32, 138, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-05-27 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(94, '01K2F2DKG05HXSD8S2WNA1T228', 135, 32, 'Theo', 'Bin Ahmed', 'Theo Bin Ahmed', 'theo-bin-ahmed-94', 'Managing Director', 'Theo specialises in Madrid and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/theo-bin-ahmed-94.jpg', 'theo.bin-ahmed@luxhabitat-development.com', '+971 4 879 1425', '+971 524998339', 'BRN-10883', '2027-01-05', 8, 1207, 1035186, 'active', 'verified', '2023-11-08 09:00:00', 1, 0, '2024-03-08', 'Theo Bin Ahmed — Managing Director at Luxhabitat Development', '2023-10-19 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(94, 1, 'native'),
(94, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(94, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(94, 1035186, 1),
(94, 50000348, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(95, '01K2F2DKG0E3T1B0QNJRC2N54K', 136, 32, 'Olivia', 'Haddad', 'Olivia Haddad', 'olivia-haddad-95', 'Sales Manager', 'Olivia specialises in Madrid and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/olivia-haddad-95.jpg', 'olivia.haddad@luxhabitat-development.com', '+971 4 449 3959', '+971 518229778', 'BRN-22941', '2028-02-16', 17, 1207, 1035186, 'active', 'verified', '2023-11-08 09:00:00', 1, 0, '2023-12-04', 'Olivia Haddad — Sales Manager at Luxhabitat Development', '2023-10-19 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(95, 1, 'native'),
(95, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(95, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(95, 1035186, 1),
(95, 50000348, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(96, '01K2F2DKG003V42JZ7X8SHJRHT', 137, 32, 'Emma', 'Laurent', 'Emma Laurent', 'emma-laurent-96', 'Senior Consultant', 'Emma specialises in Madrid and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/emma-laurent-96.jpg', 'emma.laurent@luxhabitat-development.com', '+971 4 557 2416', '+971 534763438', 'BRN-76272', '2027-12-28', 17, 1207, 1035186, 'active', 'verified', '2023-11-08 09:00:00', 1, 1, '2024-04-27', 'Emma Laurent — Senior Consultant at Luxhabitat Development', '2023-10-19 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(96, 1, 'native'),
(96, 6, 'fluent'),
(96, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(96, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(96, 1035186, 1),
(96, 50000348, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(33, '01K2F2DKG0XMCH0AK1XXDFB1DP', 5, 139, 'Driven Partners', 'driven-partners', 'active', 'verified', '2025-10-22 09:00:00', 200, 50, 'billing@driven-partners.com', 1, 1231, '2025-10-15 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(33, '01K2F2DKG021VFXSSXQ1FV089E', 33, 'marketing_partner', 'Driven Partners', 'Driven Partners LLC', 'driven-partners', 'Discretion, precision, and an unrivalled portfolio.', 'Driven Partners is a marketing partner operating from Abu Dhabi, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/driven-partners.png', 'https://cdn.livfinder.com/covers/driven-partners.jpg', 'hello@driven-partners.com', '+971 4 390 4463', '+971 547705706', 'https://www.driven-partners.com', '83 Marina Walk', 1231, 103396, 1000012, 50000100, '24.4136100', '54.4329500', 2019, 318, 'active', 'verified', '2025-10-22 09:00:00', 1, 0, 10, 'Driven Partners — Luxury Partners in Abu Dhabi | Liv Finder', 'Browse Driven Partners''s portfolio of luxury listings in Abu Dhabi and beyond.', '2025-10-15 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(33, 'rera', '15986', 'Dubai Land Department', 1231, '2025-10-25', '2027-08-20', 'valid', '2025-10-29 09:00:00'),
(33, 'trade_license', 'CN-7942063', 'Dubai Department of Economy and Tourism', 1231, '2025-10-20', '2028-01-28', 'valid', '2025-10-27 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(33, 'Driven Partners — Abu Dhabi HQ', 1, 'hello@driven-partners.com', '+971 4 255 7474', '48 Via Montenapoleone', 1231, 1000012, 50000100, '24.4136100', '54.4329500', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(33, 1, 'approved', 200, '2025-10-15 09:00:00', '2025-10-18 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(33, 6, 'requested', '2026-08-01 09:00:00', 139);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(33, 1000012, 1),
(33, 50000100, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(33, 139, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2025-10-15 09:00:00'),
(33, 140, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2026-05-30 09:00:00'),
(33, 141, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2026-01-05 09:00:00'),
(33, 142, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2026-03-25 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(97, '01K2F2DKG0EMKF8ZKFGT3Y3F81', 139, 33, 'Youssef', 'Tanaka', 'Youssef Tanaka', 'youssef-tanaka-97', 'Managing Director', 'Youssef specialises in Abu Dhabi and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/youssef-tanaka-97.jpg', 'youssef.tanaka@driven-partners.com', '+971 4 551 4137', '+971 519075051', 'BRN-32664', '2028-01-15', 7, 1231, 1000012, 'active', 'verified', '2025-11-04 09:00:00', 1, 0, '2026-05-03', 'Youssef Tanaka — Managing Director at Driven Partners', '2025-10-15 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(97, 1, 'native'),
(97, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(97, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(97, 1000012, 1),
(97, 50000100, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(98, '01K2F2DKG09AFTYXX5RBQN4GZ5', 140, 33, 'Julien', 'Meyer', 'Julien Meyer', 'julien-meyer-98', 'Sales Manager', 'Julien specialises in Abu Dhabi and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/julien-meyer-98.jpg', 'julien.meyer@driven-partners.com', '+971 4 684 3212', '+971 536179435', 'BRN-46644', '2027-07-09', 4, 1231, 1000012, 'active', 'verified', '2025-11-04 09:00:00', 1, 0, '2026-02-10', 'Julien Meyer — Sales Manager at Driven Partners', '2025-10-15 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(98, 1, 'native'),
(98, 9, 'fluent'),
(98, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(98, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(98, 1000012, 1),
(98, 50000100, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(99, '01K2F2DKG0KBCHJXGN09DT8M52', 141, 33, 'Camille', 'Haddad', 'Camille Haddad', 'camille-haddad-99', 'Senior Consultant', 'Camille specialises in Abu Dhabi and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/camille-haddad-99.jpg', 'camille.haddad@driven-partners.com', '+971 4 779 6909', '+971 537655799', 'BRN-67051', '2028-05-14', 8, 1231, 1000012, 'active', 'verified', '2025-11-04 09:00:00', 1, 0, '2025-11-09', 'Camille Haddad — Senior Consultant at Driven Partners', '2025-10-15 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(99, 1, 'native'),
(99, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(99, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(99, 1000012, 1),
(99, 50000100, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(34, '01K2F2DKG0Q0X3R11M0C5FDP3T', 4, 143, 'Sotheby''s International Properties', 'sotheby-s-international-properties', 'active', 'verified', '2024-08-26 09:00:00', 500, 100, 'billing@sotheby-s-international-properties.com', 3, 1177, '2024-08-19 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(34, '01K2F2DKG0T9YDGF6YXJX6G62K', 34, 'agency', 'Sotheby''s International Properties', 'Sotheby''s International Properties LLC', 'sotheby-s-international-properties', 'Where exceptional assets meet exceptional clients.', 'Sotheby''s International Properties is a agency operating from Cascais, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/sotheby-s-international-properties.png', 'https://cdn.livfinder.com/covers/sotheby-s-international-properties.jpg', 'hello@sotheby-s-international-properties.com', '+971 4 413 5383', '+971 516518455', 'https://www.sotheby-s-international-properties.com', '27 Via Montenapoleone', 1177, 102228, 1089101, 50000431, '38.6968919', '-9.4204495', 2020, 22, 'active', 'verified', '2024-08-26 09:00:00', 1, 0, 97, 'Sotheby''s International Properties — Luxury Properties in Cascais | Liv Finder', 'Browse Sotheby''s International Properties''s portfolio of luxury listings in Cascais and beyond.', '2024-08-19 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(34, 'broker_license', 'BR-186815', 'National Regulator', 1177, '2024-08-27', '2026-10-29', 'valid', '2024-09-03 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(34, 'Sotheby''s International Properties — Cascais HQ', 1, 'hello@sotheby-s-international-properties.com', '+971 4 403 4802', '76 Jumeirah Beach Road', 1177, 1089101, 50000431, '38.6968919', '-9.4204495', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(34, 1, 'approved', 500, '2024-08-19 09:00:00', '2024-08-22 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(34, 1089101, 1),
(34, 50000431, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(34, 143, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-08-19 09:00:00'),
(34, 144, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-09-03 09:00:00'),
(34, 145, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-11-09 09:00:00'),
(34, 146, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-05-04 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(100, '01K2F2DKG0J4JBJ92KM4WKJTVW', 143, 34, 'Daniel', 'Lindqvist', 'Daniel Lindqvist', 'daniel-lindqvist-100', 'Managing Director', 'Daniel specialises in Cascais and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/daniel-lindqvist-100.jpg', 'daniel.lindqvist@sotheby-s-international-properties.com', '+971 4 648 9676', '+971 535618438', 'BRN-29208', '2027-01-30', 3, 1177, 1089101, 'active', 'verified', '2024-09-08 09:00:00', 1, 0, '2025-01-18', 'Daniel Lindqvist — Managing Director at Sotheby''s International Properties', '2024-08-19 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(100, 1, 'native'),
(100, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(100, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(100, 1089101, 1),
(100, 50000431, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(101, '01K2F2DKG01Q94H99KZQ6GEHAX', 144, 34, 'Rafael', 'Sharma', 'Rafael Sharma', 'rafael-sharma-101', 'Sales Manager', 'Rafael specialises in Cascais and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rafael-sharma-101.jpg', 'rafael.sharma@sotheby-s-international-properties.com', '+971 4 647 6158', '+971 527345643', 'BRN-33329', '2027-02-19', 17, 1177, 1089101, 'active', 'verified', '2024-09-08 09:00:00', 1, 0, '2024-12-15', 'Rafael Sharma — Sales Manager at Sotheby''s International Properties', '2024-08-19 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(101, 1, 'native'),
(101, 9, 'fluent'),
(101, 5, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(101, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(101, 1089101, 1),
(101, 50000431, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(102, '01K2F2DKG0C3XDYARXPJA2QH9D', 145, 34, 'Antoine', 'Aziz', 'Antoine Aziz', 'antoine-aziz-102', 'Senior Consultant', 'Antoine specialises in Cascais and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/antoine-aziz-102.jpg', 'antoine.aziz@sotheby-s-international-properties.com', '+971 4 660 8715', '+971 555125853', 'BRN-59787', '2028-03-25', 16, 1177, 1089101, 'active', 'verified', '2024-09-08 09:00:00', 1, 0, '2024-11-24', 'Antoine Aziz — Senior Consultant at Sotheby''s International Properties', '2024-08-19 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(102, 1, 'native'),
(102, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(102, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(102, 1089101, 1),
(102, 50000431, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(35, '01K2F2DKG0FVNVZ5411YWJPH0K', 3, 147, 'Christie''s International Real Estate', 'christie-s-international-real-estate', 'active', 'verified', '2025-05-23 09:00:00', 50, 3, 'billing@christie-s-international-real-estate.com', 3, 1207, '2025-05-16 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(35, '01K2F2DKG00RY0SG9C1YN6SDBD', 35, 'agency', 'Christie''s International Real Estate', 'Christie''s International Real Estate LLC', 'christie-s-international-real-estate', 'Where exceptional assets meet exceptional clients.', 'Christie''s International Real Estate is a agency operating from Ibiza, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/christie-s-international-real-estate.png', 'https://cdn.livfinder.com/covers/christie-s-international-real-estate.jpg', 'hello@christie-s-international-real-estate.com', '+971 4 796 3252', '+971 518064272', 'https://www.christie-s-international-real-estate.com', '54 Passeig de Gràcia', 1207, 101174, 1034729, 50000372, '38.9088300', '1.4329600', 2007, 316, 'active', 'verified', '2025-05-23 09:00:00', 1, 0, 47, 'Christie''s International Real Estate — Luxury Real Estate in Ibiza | Liv Finder', 'Browse Christie''s International Real Estate''s portfolio of luxury listings in Ibiza and beyond.', '2025-05-16 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(35, 'broker_license', 'BR-371172', 'National Regulator', 1207, '2025-05-24', '2026-10-18', 'valid', '2025-05-31 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(35, 'Christie''s International Real Estate — Ibiza HQ', 1, 'hello@christie-s-international-real-estate.com', '+971 4 840 5480', '68 Orchard Boulevard', 1207, 1034729, 50000372, '38.9088300', '1.4329600', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(35, 1, 'approved', 50, '2025-05-16 09:00:00', '2025-05-19 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(35, 4, 'requested', '2026-08-13 09:00:00', 147);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(35, 1034729, 1),
(35, 50000372, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(35, 147, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2025-05-16 09:00:00'),
(35, 148, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-10-24 09:00:00'),
(35, 149, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-07-12 09:00:00'),
(35, 150, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2026-02-27 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(103, '01K2F2DKG0HSMF4Y36SNFNSD6M', 147, 35, 'Leila', 'Al Suwaidi', 'Leila Al Suwaidi', 'leila-al-suwaidi-103', 'Managing Director', 'Leila specialises in Ibiza and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/leila-al-suwaidi-103.jpg', 'leila.al-suwaidi@christie-s-international-real-estate.com', '+971 4 641 1136', '+971 543847610', 'BRN-21112', '2026-10-27', 17, 1207, 1034729, 'active', 'verified', '2025-06-05 09:00:00', 1, 0, '2025-10-10', 'Leila Al Suwaidi — Managing Director at Christie''s International Real Estate', '2025-05-16 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(103, 1, 'native'),
(103, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(103, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(103, 1034729, 1),
(103, 50000372, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(104, '01K2F2DKG073CYJ87G65X97RSJ', 148, 35, 'Rania', 'Rahman', 'Rania Rahman', 'rania-rahman-104', 'Sales Manager', 'Rania specialises in Ibiza and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rania-rahman-104.jpg', 'rania.rahman@christie-s-international-real-estate.com', '+971 4 415 8599', '+971 551613435', 'BRN-55719', '2027-09-09', 22, 1207, 1034729, 'active', 'verified', '2025-06-05 09:00:00', 1, 0, '2025-10-28', 'Rania Rahman — Sales Manager at Christie''s International Real Estate', '2025-05-16 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(104, 1, 'native'),
(104, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(104, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(104, 1034729, 1),
(104, 50000372, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(105, '01K2F2DKG0974N5DS5G3DZYQMP', 149, 35, 'Sarah', 'Khoury', 'Sarah Khoury', 'sarah-khoury-105', 'Senior Consultant', 'Sarah specialises in Ibiza and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/sarah-khoury-105.jpg', 'sarah.khoury@christie-s-international-real-estate.com', '+971 4 309 8368', '+971 529745425', 'BRN-61107', '2028-06-27', 19, 1207, 1034729, 'active', 'verified', '2025-06-05 09:00:00', 1, 0, '2025-07-16', 'Sarah Khoury — Senior Consultant at Christie''s International Real Estate', '2025-05-16 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(105, 1, 'native'),
(105, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(105, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(105, 1034729, 1),
(105, 50000372, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(36, '01K2F2DKG0FN1BC5JQPXACN1Y5', 3, 151, 'Knight Estates', 'knight-estates', 'active', 'verified', '2022-09-07 09:00:00', 50, 3, 'billing@knight-estates.com', 3, 1107, '2022-08-31 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(36, '01K2F2DKG0RADFG3GQAECRH3N1', 36, 'brokerage', 'Knight Estates', 'Knight Estates LLC', 'knight-estates', 'Discretion, precision, and an unrivalled portfolio.', 'Knight Estates is a brokerage operating from Milan, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/knight-estates.png', 'https://cdn.livfinder.com/covers/knight-estates.jpg', 'hello@knight-estates.com', '+971 4 551 2069', '+971 541220765', 'https://www.knight-estates.com', '30 Sheikh Zayed Road', 1107, 105633, 1140142, 50000381, '45.4642700', '9.1895100', 1998, 288, 'active', 'verified', '2022-09-07 09:00:00', 1, 0, 32, 'Knight Estates — Luxury Estates in Milan | Liv Finder', 'Browse Knight Estates''s portfolio of luxury listings in Milan and beyond.', '2022-08-31 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(36, 'broker_license', 'BR-363097', 'National Regulator', 1107, '2022-09-08', '2028-09-22', 'valid', '2022-09-15 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(36, 'Knight Estates — Milan HQ', 1, 'hello@knight-estates.com', '+971 4 652 9127', '77 Sloane Street', 1107, 1140142, 50000381, '45.4642700', '9.1895100', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(36, 1, 'approved', 50, '2022-08-31 09:00:00', '2022-09-03 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(36, 1140142, 1),
(36, 50000381, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(36, 151, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2022-08-31 09:00:00'),
(36, 152, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-01-16 09:00:00'),
(36, 153, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2022-10-06 09:00:00'),
(36, 154, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2022-09-20 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(106, '01K2F2DKG08S4DE7Z6ZBXXWDGK', 151, 36, 'Rania', 'Karim', 'Rania Karim', 'rania-karim-106', 'Managing Director', 'Rania specialises in Milan and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rania-karim-106.jpg', 'rania.karim@knight-estates.com', '+971 4 724 5105', '+971 533030238', 'BRN-66614', '2028-04-19', 9, 1107, 1140142, 'active', 'verified', '2022-09-20 09:00:00', 1, 0, '2022-11-17', 'Rania Karim — Managing Director at Knight Estates', '2022-08-31 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(106, 1, 'native'),
(106, 6, 'fluent'),
(106, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(106, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(106, 1140142, 1),
(106, 50000381, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(107, '01K2F2DKG0HC7KVQG1D2X2F1JA', 152, 36, 'Priya', 'Moreau', 'Priya Moreau', 'priya-moreau-107', 'Sales Manager', 'Priya specialises in Milan and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/priya-moreau-107.jpg', 'priya.moreau@knight-estates.com', '+971 4 440 7550', '+971 548783386', 'BRN-67671', '2026-12-08', 11, 1107, 1140142, 'active', 'verified', '2022-09-20 09:00:00', 1, 0, '2022-10-07', 'Priya Moreau — Sales Manager at Knight Estates', '2022-08-31 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(107, 1, 'native'),
(107, 2, 'fluent'),
(107, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(107, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(107, 1140142, 1),
(107, 50000381, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(108, '01K2F2DKG0WQRK5GZQMVWVCG16', 153, 36, 'Zainab', 'Aziz', 'Zainab Aziz', 'zainab-aziz-108', 'Senior Consultant', 'Zainab specialises in Milan and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/zainab-aziz-108.jpg', 'zainab.aziz@knight-estates.com', '+971 4 638 5676', '+971 524283652', 'BRN-61657', '2027-07-20', 23, 1107, 1140142, 'active', 'verified', '2022-09-20 09:00:00', 1, 0, '2022-09-26', 'Zainab Aziz — Senior Consultant at Knight Estates', '2022-08-31 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(108, 1, 'native'),
(108, 4, 'fluent'),
(108, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(108, 1, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(108, 1140142, 1),
(108, 50000381, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(37, '01K2F2DKG050X55MW8N6BQ7CZ2', 4, 155, 'Halcyon Motors', 'halcyon-motors', 'active', 'verified', '2025-07-24 09:00:00', 500, 100, 'billing@halcyon-motors.com', 5, 1214, '2025-07-17 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(37, '01K2F2DKG0FNBF6B25XM61GSFR', 37, 'dealership', 'Halcyon Motors', 'Halcyon Motors LLC', 'halcyon-motors', 'A boutique practice with a global reach.', 'Halcyon Motors is a dealership operating from Geneva, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/halcyon-motors.png', 'https://cdn.livfinder.com/covers/halcyon-motors.jpg', 'hello@halcyon-motors.com', '+971 4 884 5166', '+971 527186698', 'https://www.halcyon-motors.com', '31 Umm Suqeim Road', 1214, 101647, 1017827, 50000445, '46.2022200', '6.1456900', 2020, 154, 'active', 'verified', '2025-07-24 09:00:00', 1, 0, 154, 'Halcyon Motors — Luxury Motors in Geneva | Liv Finder', 'Browse Halcyon Motors''s portfolio of luxury listings in Geneva and beyond.', '2025-07-17 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(37, 'broker_license', 'BR-661182', 'National Regulator', 1214, '2025-07-25', '2027-05-30', 'valid', '2025-08-01 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(37, 'Halcyon Motors — Geneva HQ', 1, 'hello@halcyon-motors.com', '+971 4 349 3212', '48 Jumeirah Beach Road', 1214, 1017827, 50000445, '46.2022200', '6.1456900', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(37, 2, 'approved', 500, '2025-07-17 09:00:00', '2025-07-20 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(37, 1017827, 1),
(37, 50000445, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(37, 155, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2025-07-17 09:00:00'),
(37, 156, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-08-22 09:00:00'),
(37, 157, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-07-23 09:00:00'),
(37, 158, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-11-29 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(109, '01K2F2DKG0F9VN5ZBF1VS5PY9V', 155, 37, 'Hana', 'Volkov', 'Hana Volkov', 'hana-volkov-109', 'Managing Director', 'Hana specialises in Geneva and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/hana-volkov-109.jpg', 'hana.volkov@halcyon-motors.com', '+971 4 640 7912', '+971 547323818', 'BRN-79308', '2028-01-18', 17, 1214, 1017827, 'active', 'verified', '2025-08-06 09:00:00', 1, 1, '2025-10-08', 'Hana Volkov — Managing Director at Halcyon Motors', '2025-07-17 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(109, 1, 'native'),
(109, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(109, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(109, 1017827, 1),
(109, 50000445, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(110, '01K2F2DKG09XYE5FFCKFKJA41A', 156, 37, 'Julien', 'Sato', 'Julien Sato', 'julien-sato-110', 'Sales Manager', 'Julien specialises in Geneva and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/julien-sato-110.jpg', 'julien.sato@halcyon-motors.com', '+971 4 574 1796', '+971 555926707', 'BRN-72304', '2028-05-29', 7, 1214, 1017827, 'active', 'verified', '2025-08-06 09:00:00', 1, 0, '2025-10-10', 'Julien Sato — Sales Manager at Halcyon Motors', '2025-07-17 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(110, 1, 'native'),
(110, 2, 'fluent'),
(110, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(110, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(110, 1017827, 1),
(110, 50000445, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(111, '01K2F2DKG02YBRRRSV153CG1KF', 157, 37, 'Daniel', 'Al Suwaidi', 'Daniel Al Suwaidi', 'daniel-al-suwaidi-111', 'Senior Consultant', 'Daniel specialises in Geneva and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/daniel-al-suwaidi-111.jpg', 'daniel.al-suwaidi@halcyon-motors.com', '+971 4 878 9501', '+971 518388027', 'BRN-65337', '2027-04-06', 22, 1214, 1017827, 'active', 'verified', '2025-08-06 09:00:00', 1, 0, '2025-11-15', 'Daniel Al Suwaidi — Senior Consultant at Halcyon Motors', '2025-07-17 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(111, 1, 'native'),
(111, 8, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(111, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(111, 1017827, 1),
(111, 50000445, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(38, '01K2F2DKG0M974HJP29F3TD9MF', 3, 159, 'Aurum Automotive', 'aurum-automotive', 'active', 'verified', '2022-09-15 09:00:00', 50, 3, 'billing@aurum-automotive.com', 2, 1233, '2022-09-08 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(38, '01K2F2DKG0HV06SF61P4SS2K5H', 38, 'dealership', 'Aurum Automotive', 'Aurum Automotive LLC', 'aurum-automotive', 'A boutique practice with a global reach.', 'Aurum Automotive is a dealership operating from New York City, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/aurum-automotive.png', 'https://cdn.livfinder.com/covers/aurum-automotive.jpg', 'hello@aurum-automotive.com', '+971 4 887 9126', '+971 525616951', 'https://www.aurum-automotive.com', '71 Passeig de Gràcia', 1233, 101452, 1122795, 50000591, '40.7142700', '-74.0059700', 2015, 274, 'active', 'verified', '2022-09-15 09:00:00', 1, 0, 145, 'Aurum Automotive — Luxury Automotive in New York City | Liv Finder', 'Browse Aurum Automotive''s portfolio of luxury listings in New York City and beyond.', '2022-09-08 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(38, 'broker_license', 'BR-801858', 'National Regulator', 1233, '2022-09-16', '2027-10-14', 'valid', '2022-09-23 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(38, 'Aurum Automotive — New York City HQ', 1, 'hello@aurum-automotive.com', '+971 4 441 7410', '38 Sheikh Zayed Road', 1233, 1122795, 50000591, '40.7142700', '-74.0059700', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(38, 2, 'approved', 50, '2022-09-08 09:00:00', '2022-09-11 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(38, 1122795, 1),
(38, 50000591, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(38, 159, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2022-09-08 09:00:00'),
(38, 160, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2023-01-31 09:00:00'),
(38, 161, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2023-05-05 09:00:00'),
(38, 162, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2023-03-15 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(112, '01K2F2DKG0NW3SXKCE4FKZ15MS', 159, 38, 'Charlotte', 'Moretti', 'Charlotte Moretti', 'charlotte-moretti-112', 'Managing Director', 'Charlotte specialises in New York City and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/charlotte-moretti-112.jpg', 'charlotte.moretti@aurum-automotive.com', '+971 4 417 4988', '+971 553873399', 'BRN-66293', '2026-12-16', 19, 1233, 1122795, 'active', 'verified', '2022-09-28 09:00:00', 1, 0, '2022-09-12', 'Charlotte Moretti — Managing Director at Aurum Automotive', '2022-09-08 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(112, 1, 'native'),
(112, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(112, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(112, 1122795, 1),
(112, 50000591, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(113, '01K2F2DKG03BJ16ADN984D3C3W', 160, 38, 'Anastasia', 'Ferrari', 'Anastasia Ferrari', 'anastasia-ferrari-113', 'Sales Manager', 'Anastasia specialises in New York City and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/anastasia-ferrari-113.jpg', 'anastasia.ferrari@aurum-automotive.com', '+971 4 792 4950', '+971 525670599', 'BRN-13886', '2026-10-08', 10, 1233, 1122795, 'active', 'verified', '2022-09-28 09:00:00', 1, 0, '2022-12-08', 'Anastasia Ferrari — Sales Manager at Aurum Automotive', '2022-09-08 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(113, 1, 'native'),
(113, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(113, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(113, 1122795, 1),
(113, 50000591, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(114, '01K2F2DKG087XVKAFYA293AH8E', 161, 38, 'Mohammed', 'Meyer', 'Mohammed Meyer', 'mohammed-meyer-114', 'Senior Consultant', 'Mohammed specialises in New York City and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/mohammed-meyer-114.jpg', 'mohammed.meyer@aurum-automotive.com', '+971 4 757 6442', '+971 543708163', 'BRN-14102', '2027-07-29', 12, 1233, 1122795, 'active', 'verified', '2022-09-28 09:00:00', 1, 0, '2023-01-12', 'Mohammed Meyer — Senior Consultant at Aurum Automotive', '2022-09-08 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(114, 1, 'native'),
(114, 8, 'fluent'),
(114, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(114, 2, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(114, 1122795, 1),
(114, 50000591, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(39, '01K2F2DKG063C0FTNVNFJG94V6', 3, 163, 'Meridian Yachts', 'meridian-yachts', 'active', 'verified', '2025-08-31 09:00:00', 50, 3, 'billing@meridian-yachts.com', 5, 1214, '2025-08-24 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(39, '01K2F2DKG0CB9Y1XHDKE31BMQ1', 39, 'yacht_broker', 'Meridian Yachts', 'Meridian Yachts LLC', 'meridian-yachts', 'Where exceptional assets meet exceptional clients.', 'Meridian Yachts is a yacht broker operating from Geneva, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/meridian-yachts.png', 'https://cdn.livfinder.com/covers/meridian-yachts.jpg', 'hello@meridian-yachts.com', '+971 4 641 1428', '+971 518659966', 'https://www.meridian-yachts.com', '51 The Crescent', 1214, 101647, 1017827, 50000443, '46.2022200', '6.1456900', 1999, 116, 'active', 'verified', '2025-08-31 09:00:00', 1, 0, 134, 'Meridian Yachts — Luxury Yachts in Geneva | Liv Finder', 'Browse Meridian Yachts''s portfolio of luxury listings in Geneva and beyond.', '2025-08-24 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(39, 'broker_license', 'BR-108541', 'National Regulator', 1214, '2025-09-01', '2027-06-08', 'valid', '2025-09-08 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(39, 'Meridian Yachts — Geneva HQ', 1, 'hello@meridian-yachts.com', '+971 4 340 9797', '65 Orchard Boulevard', 1214, 1017827, 50000443, '46.2022200', '6.1456900', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(39, 3, 'approved', 50, '2025-08-24 09:00:00', '2025-08-27 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(39, 5, 'requested', '2026-07-09 09:00:00', 163);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(39, 1017827, 1),
(39, 50000443, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(39, 163, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2025-08-24 09:00:00'),
(39, 164, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-09-29 09:00:00'),
(39, 165, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-10-10 09:00:00'),
(39, 166, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-12-12 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(115, '01K2F2DKG0SN00JWSX7S1K2Z5M', 163, 39, 'Diego', 'Von Habsburg', 'Diego Von Habsburg', 'diego-von-habsburg-115', 'Managing Director', 'Diego specialises in Geneva and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/diego-von-habsburg-115.jpg', 'diego.von-habsburg@meridian-yachts.com', '+971 4 657 8449', '+971 559638927', 'BRN-59239', '2027-06-24', 19, 1214, 1017827, 'active', 'verified', '2025-09-13 09:00:00', 1, 0, '2026-03-06', 'Diego Von Habsburg — Managing Director at Meridian Yachts', '2025-08-24 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(115, 1, 'native'),
(115, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(115, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(115, 1017827, 1),
(115, 50000443, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(116, '01K2F2DKG065G4NWRDRMVGQD7Q', 164, 39, 'Valentina', 'Dubois', 'Valentina Dubois', 'valentina-dubois-116', 'Sales Manager', 'Valentina specialises in Geneva and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/valentina-dubois-116.jpg', 'valentina.dubois@meridian-yachts.com', '+971 4 638 2793', '+971 557871318', 'BRN-67723', '2028-06-09', 7, 1214, 1017827, 'active', 'verified', '2025-09-13 09:00:00', 1, 0, '2025-12-05', 'Valentina Dubois — Sales Manager at Meridian Yachts', '2025-08-24 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(116, 1, 'native'),
(116, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(116, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(116, 1017827, 1),
(116, 50000443, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(117, '01K2F2DKG08Y9758KJYDT9CVVW', 165, 39, 'Nikolai', 'Laurent', 'Nikolai Laurent', 'nikolai-laurent-117', 'Senior Consultant', 'Nikolai specialises in Geneva and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/nikolai-laurent-117.jpg', 'nikolai.laurent@meridian-yachts.com', '+971 4 624 6819', '+971 525279781', 'BRN-20371', '2027-05-20', 13, 1214, 1017827, 'active', 'verified', '2025-09-13 09:00:00', 1, 0, '2025-10-13', 'Nikolai Laurent — Senior Consultant at Meridian Yachts', '2025-08-24 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(117, 1, 'native'),
(117, 9, 'fluent'),
(117, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(117, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(117, 1017827, 1),
(117, 50000443, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(40, '01K2F2DKG0GRC1NZ1YKPQWXD92', 4, 167, 'Blackstone Marine', 'blackstone-marine', 'active', 'verified', '2023-11-20 09:00:00', 500, 100, 'billing@blackstone-marine.com', 3, 1145, '2023-11-13 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(40, '01K2F2DKG0JF9FMAGTJ7559YE2', 40, 'yacht_broker', 'Blackstone Marine', 'Blackstone Marine LLC', 'blackstone-marine', 'Discretion, precision, and an unrivalled portfolio.', 'Blackstone Marine is a yacht broker operating from Monaco, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/blackstone-marine.png', 'https://cdn.livfinder.com/covers/blackstone-marine.jpg', 'hello@blackstone-marine.com', '+971 4 548 5072', '+971 512169999', 'https://www.blackstone-marine.com', '62 Ocean Drive', 1145, NULL, 1900000, 50000280, '43.7384000', '7.4246000', 2017, 104, 'active', 'verified', '2023-11-20 09:00:00', 1, 0, 106, 'Blackstone Marine — Luxury Marine in Monaco | Liv Finder', 'Browse Blackstone Marine''s portfolio of luxury listings in Monaco and beyond.', '2023-11-13 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(40, 'broker_license', 'BR-978989', 'National Regulator', 1145, '2023-11-21', '2026-11-05', 'valid', '2023-11-28 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(40, 'Blackstone Marine — Monaco HQ', 1, 'hello@blackstone-marine.com', '+971 4 527 3576', '8 Umm Suqeim Road', 1145, 1900000, 50000280, '43.7384000', '7.4246000', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(40, 3, 'approved', 500, '2023-11-13 09:00:00', '2023-11-16 09:00:00', 3);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(40, 1900000, 1),
(40, 50000280, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(40, 167, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2023-11-13 09:00:00'),
(40, 168, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2024-06-23 09:00:00'),
(40, 169, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2024-06-22 09:00:00'),
(40, 170, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2024-03-01 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(118, '01K2F2DKG0CNVJECW8CK3CH69T', 167, 40, 'Mohammed', 'Al Balushi', 'Mohammed Al Balushi', 'mohammed-al-balushi-118', 'Managing Director', 'Mohammed specialises in Monaco and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/mohammed-al-balushi-118.jpg', 'mohammed.al-balushi@blackstone-marine.com', '+971 4 623 8743', '+971 520602769', 'BRN-55576', '2027-09-15', 4, 1145, 1900000, 'active', 'verified', '2023-12-03 09:00:00', 1, 0, '2024-03-25', 'Mohammed Al Balushi — Managing Director at Blackstone Marine', '2023-11-13 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(118, 1, 'native'),
(118, 9, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(118, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(118, 1900000, 1),
(118, 50000280, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(119, '01K2F2DKG0178FW3RGRJY2MP39', 168, 40, 'Farah', 'Khoury', 'Farah Khoury', 'farah-khoury-119', 'Sales Manager', 'Farah specialises in Monaco and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/farah-khoury-119.jpg', 'farah.khoury@blackstone-marine.com', '+971 4 593 8367', '+971 547782672', 'BRN-18732', '2027-01-03', 3, 1145, 1900000, 'active', 'verified', '2023-12-03 09:00:00', 1, 0, '2024-03-24', 'Farah Khoury — Sales Manager at Blackstone Marine', '2023-11-13 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(119, 1, 'native'),
(119, 8, 'fluent'),
(119, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(119, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(119, 1900000, 1),
(119, 50000280, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(120, '01K2F2DKG0XGWMNKCZNP9R6HJB', 169, 40, 'Henry', 'Fairfax', 'Henry Fairfax', 'henry-fairfax-120', 'Senior Consultant', 'Henry specialises in Monaco and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/henry-fairfax-120.jpg', 'henry.fairfax@blackstone-marine.com', '+971 4 885 5224', '+971 538839908', 'BRN-48915', '2028-06-24', 14, 1145, 1900000, 'active', 'verified', '2023-12-03 09:00:00', 1, 0, '2024-02-21', 'Henry Fairfax — Senior Consultant at Blackstone Marine', '2023-11-13 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(120, 1, 'native'),
(120, 9, 'fluent'),
(120, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(120, 3, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(120, 1900000, 1),
(120, 50000280, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(41, '01K2F2DKG0ZS10TJZM64MTDRRS', 3, 171, 'Crown Aviation', 'crown-aviation', 'active', 'verified', '2025-09-07 09:00:00', 50, 3, 'billing@crown-aviation.com', 2, 1233, '2025-08-31 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(41, '01K2F2DKG0FXTT6DNSNS4BNQDA', 41, 'aviation_broker', 'Crown Aviation', 'Crown Aviation LLC', 'crown-aviation', 'Curating the finest addresses since day one.', 'Crown Aviation is a aviation broker operating from New York City, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/crown-aviation.png', 'https://cdn.livfinder.com/covers/crown-aviation.jpg', 'hello@crown-aviation.com', '+971 4 437 3347', '+971 525449402', 'https://www.crown-aviation.com', '13 Passeig de Gràcia', 1233, 101452, 1122795, 50000596, '40.7142700', '-74.0059700', 2015, 41, 'active', 'verified', '2025-09-07 09:00:00', 1, 0, 104, 'Crown Aviation — Luxury Aviation in New York City | Liv Finder', 'Browse Crown Aviation''s portfolio of luxury listings in New York City and beyond.', '2025-08-31 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(41, 'broker_license', 'BR-350762', 'National Regulator', 1233, '2025-09-08', '2028-01-04', 'valid', '2025-09-15 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(41, 'Crown Aviation — New York City HQ', 1, 'hello@crown-aviation.com', '+971 4 823 3962', '55 Hessa Street', 1233, 1122795, 50000596, '40.7142700', '-74.0059700', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(41, 4, 'approved', 50, '2025-08-31 09:00:00', '2025-09-03 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(41, 6, 'requested', '2026-08-12 09:00:00', 171);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(41, 1122795, 1),
(41, 50000596, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(41, 171, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2025-08-31 09:00:00'),
(41, 172, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-11-22 09:00:00'),
(41, 173, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2026-06-19 09:00:00'),
(41, 174, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2026-03-15 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(121, '01K2F2DKG0P6Y97R3WRN8GNYBZ', 171, 41, 'Rafael', 'Ferrari', 'Rafael Ferrari', 'rafael-ferrari-121', 'Managing Director', 'Rafael specialises in New York City and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/rafael-ferrari-121.jpg', 'rafael.ferrari@crown-aviation.com', '+971 4 732 3794', '+971 545913005', 'BRN-41028', '2027-01-25', 7, 1233, 1122795, 'active', 'verified', '2025-09-20 09:00:00', 1, 0, '2025-11-10', 'Rafael Ferrari — Managing Director at Crown Aviation', '2025-08-31 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(121, 1, 'native'),
(121, 4, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(121, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(121, 1122795, 1),
(121, 50000596, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(122, '01K2F2DKG0BWMDTHBCTS37Q11A', 172, 41, 'Hana', 'Mercer', 'Hana Mercer', 'hana-mercer-122', 'Sales Manager', 'Hana specialises in New York City and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/hana-mercer-122.jpg', 'hana.mercer@crown-aviation.com', '+971 4 520 2923', '+971 530215217', 'BRN-42839', '2027-08-10', 8, 1233, 1122795, 'active', 'verified', '2025-09-20 09:00:00', 1, 1, '2026-02-06', 'Hana Mercer — Sales Manager at Crown Aviation', '2025-08-31 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(122, 1, 'native'),
(122, 4, 'fluent'),
(122, 6, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(122, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(122, 1122795, 1),
(122, 50000596, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(123, '01K2F2DKG0WKMTXFA1RBG8Q74S', 173, 41, 'Vikram', 'Rossellini', 'Vikram Rossellini', 'vikram-rossellini-123', 'Senior Consultant', 'Vikram specialises in New York City and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/vikram-rossellini-123.jpg', 'vikram.rossellini@crown-aviation.com', '+971 4 575 3918', '+971 553326266', 'BRN-70431', '2027-05-02', 12, 1233, 1122795, 'active', 'verified', '2025-09-20 09:00:00', 1, 0, '2026-03-11', 'Vikram Rossellini — Senior Consultant at Crown Aviation', '2025-08-31 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(123, 1, 'native'),
(123, 8, 'fluent'),
(123, 3, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(123, 4, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(123, 1122795, 1),
(123, 50000596, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(42, '01K2F2DKG0YWJ837DXYWVQT077', 3, 175, 'Azure Timepieces', 'azure-timepieces', 'active', 'verified', '2024-09-19 09:00:00', 50, 3, 'billing@azure-timepieces.com', 14, 1039, '2024-09-12 09:00:00');

INSERT INTO organizations (id, public_id, account_id, kind, name, legal_name, slug, tagline, description, logo_url, cover_image_url, email, phone, whatsapp, website_url, address_line1, country_id, state_id, city_id, community_id, latitude, longitude, founded_year, employee_count, status, verification_status, verified_at, is_publicly_visible, is_featured, response_time_minutes, seo_title, seo_description, created_at) VALUES
(42, '01K2F2DKG01T9ZAJSYNNCHPT5Y', 42, 'watch_dealer', 'Azure Timepieces', 'Azure Timepieces LLC', 'azure-timepieces', 'Where exceptional assets meet exceptional clients.', 'Azure Timepieces is a watch dealer operating from Toronto, specialising in the upper end of the market. The team combines local knowledge with an international client base, and every listing is verified before it is published.', 'https://cdn.livfinder.com/logos/azure-timepieces.png', 'https://cdn.livfinder.com/covers/azure-timepieces.jpg', 'hello@azure-timepieces.com', '+971 4 847 6552', '+971 557805380', 'https://www.azure-timepieces.com', '33 The Crescent', 1039, 100866, 1017121, 50000661, '43.7001100', '-79.4163000', 2012, 139, 'active', 'verified', '2024-09-19 09:00:00', 1, 0, 160, 'Azure Timepieces — Luxury Timepieces in Toronto | Liv Finder', 'Browse Azure Timepieces''s portfolio of luxury listings in Toronto and beyond.', '2024-09-12 09:00:00');

INSERT INTO organization_licenses (organization_id, license_type, license_number, issuing_authority, country_id, issued_at, expires_at, status, verified_at) VALUES
(42, 'broker_license', 'BR-348467', 'National Regulator', 1039, '2024-09-20', '2028-01-07', 'valid', '2024-09-27 09:00:00');

INSERT INTO organization_branches (organization_id, name, is_headquarters, email, phone, address_line1, country_id, city_id, community_id, latitude, longitude, status) VALUES
(42, 'Azure Timepieces — Toronto HQ', 1, 'hello@azure-timepieces.com', '+971 4 741 2737', '87 Orchard Boulevard', 1039, 1017121, 50000661, '43.7001100', '-79.4163000', 'active');

INSERT INTO organization_category_access (organization_id, category_id, status, listing_quota, requested_at, reviewed_at, reviewed_by_user_id) VALUES
(42, 6, 'approved', 50, '2024-09-12 09:00:00', '2024-09-15 09:00:00', 3);

INSERT INTO organization_category_access (organization_id, category_id, status, requested_at, requested_by_user_id) VALUES
(42, 1, 'requested', '2026-08-12 09:00:00', 175);

INSERT INTO organization_service_areas (organization_id, location_id, is_primary) VALUES
(42, 1017121, 1),
(42, 50000661, 0);

INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(42, 175, 'owner', 'active', 'Managing Director', 1, 1, 1, 1, 1, 1, 1, '2024-09-12 09:00:00'),
(42, 176, 'manager', 'active', 'Sales Manager', 0, 1, 1, 1, 1, 1, 0, '2025-06-07 09:00:00'),
(42, 177, 'agent', 'active', 'Senior Consultant', 0, 0, 1, 0, 1, 0, 0, '2025-06-07 09:00:00'),
(42, 178, 'viewer', 'active', 'Analyst', 0, 0, 0, 0, 0, 0, 0, '2025-04-05 09:00:00');

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(124, '01K2F2DKG0X9YZYRZCZA1YVMFZ', 175, 42, 'Vikram', 'Wong', 'Vikram Wong', 'vikram-wong-124', 'Managing Director', 'Vikram specialises in Toronto and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/vikram-wong-124.jpg', 'vikram.wong@azure-timepieces.com', '+971 4 301 2919', '+971 545020996', 'BRN-26433', '2028-03-30', 6, 1039, 1017121, 'active', 'verified', '2024-10-02 09:00:00', 1, 0, '2025-01-17', 'Vikram Wong — Managing Director at Azure Timepieces', '2024-09-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(124, 1, 'native'),
(124, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(124, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(124, 1017121, 1),
(124, 50000661, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(125, '01K2F2DKG0HNJX4M9V58ZRPS1K', 176, 42, 'Julien', 'Ivanov', 'Julien Ivanov', 'julien-ivanov-125', 'Sales Manager', 'Julien specialises in Toronto and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/julien-ivanov-125.jpg', 'julien.ivanov@azure-timepieces.com', '+971 4 780 4174', '+971 543495325', 'BRN-35156', '2028-04-12', 3, 1039, 1017121, 'active', 'verified', '2024-10-02 09:00:00', 1, 0, '2024-10-24', 'Julien Ivanov — Sales Manager at Azure Timepieces', '2024-09-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(125, 1, 'native'),
(125, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(125, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(125, 1017121, 1),
(125, 50000661, 0);

INSERT INTO agents (id, public_id, user_id, organization_id, first_name, last_name, display_name, slug, title, bio, photo_url, email, phone, whatsapp, license_number, license_expires_at, experience_years, country_id, city_id, status, verification_status, verified_at, is_publicly_visible, is_featured, joined_at, seo_title, created_at) VALUES
(126, '01K2F2DKG0X8HDJ7XBYYW45A65', 177, 42, 'Vikram', 'Al Balushi', 'Vikram Al Balushi', 'vikram-al-balushi-126', 'Senior Consultant', 'Vikram specialises in Toronto and has advised clients across the region for over a decade. Fluent, discreet, and known for knowing which properties are quietly available before they reach the market.', 'https://cdn.livfinder.com/agents/vikram-al-balushi-126.jpg', 'vikram.al-balushi@azure-timepieces.com', '+971 4 768 3824', '+971 514435730', 'BRN-10785', '2027-11-21', 15, 1039, 1017121, 'active', 'verified', '2024-10-02 09:00:00', 1, 0, '2024-10-11', 'Vikram Al Balushi — Senior Consultant at Azure Timepieces', '2024-09-12 09:00:00');

INSERT INTO agent_languages (agent_id, language_id, proficiency) VALUES
(126, 1, 'native'),
(126, 3, 'fluent'),
(126, 2, 'fluent');

INSERT INTO agent_specialties (agent_id, category_id, is_primary) VALUES
(126, 6, 1);

INSERT INTO agent_service_areas (agent_id, location_id, is_primary) VALUES
(126, 1017121, 1),
(126, 50000661, 0);

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(43, '01K2F2DKG04WAXR161W74S64F4', 2, 179, 'Chen Khoury', 'chen-khoury-43', 'active', 'verified', '2026-05-16 09:00:00', 3, 0, 'chen.khoury179@example.com', 2, 1102, '2025-06-19 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(43, 179, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2024-10-26 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(44, '01K2F2DKG0P6BPSF53TTM8GSHP', 1, 180, 'Julien Rahman', 'julien-rahman-44', 'active', 'unverified', NULL, 0, 0, 'julien.rahman180@example.com', 1, 1231, '2025-03-30 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(44, 180, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-06-05 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(45, '01K2F2DKG0P7SMM37693CCGEBD', 1, 181, 'Mariam Bin Ahmed', 'mariam-bin-ahmed-45', 'active', 'unverified', NULL, 0, 0, 'mariam.bin-ahmed181@example.com', 1, 1231, '2024-11-09 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(45, 181, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-04-08 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(46, '01K2F2DKG0KG0B654M24J2AYBP', 1, 182, 'Mohammed Al Otaiba', 'mohammed-al-otaiba-46', 'active', 'unverified', NULL, 0, 0, 'mohammed.al-otaiba182@example.com', 1, 1231, '2026-02-10 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(46, 182, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-09-09 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(47, '01K2F2DKG0PABPHK04R1HE48WD', 1, 183, 'Daniel Al Mansouri', 'daniel-al-mansouri-47', 'active', 'unverified', NULL, 0, 0, 'daniel.al-mansouri183@example.com', 3, 1177, '2024-12-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(47, 183, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-02-25 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(48, '01K2F2DKG0K526RAM792MQVMJ7', 1, 184, 'Khalid Whitfield', 'khalid-whitfield-48', 'active', 'unverified', NULL, 0, 0, 'khalid.whitfield184@example.com', 4, 1232, '2026-02-28 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(48, 184, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-11-26 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(49, '01K2F2DKG0ZJ60BB39YQKNVTDJ', 1, 185, 'Youssef Al Farsi', 'youssef-al-farsi-49', 'active', 'unverified', NULL, 0, 0, 'youssef.al-farsi185@example.com', 1, 1231, '2025-07-31 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(49, 185, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-10-07 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(50, '01K2F2DKG07XWE5542FVMTJXT3', 1, 186, 'Youssef Al Mansouri', 'youssef-al-mansouri-50', 'active', 'unverified', NULL, 0, 0, 'youssef.al-mansouri186@example.com', 1, 1231, '2025-04-30 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(50, 186, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-04 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(51, '01K2F2DKG0FNYA6WGQCKKSZDEY', 1, 187, 'Khalid Sharma', 'khalid-sharma-51', 'active', 'unverified', NULL, 0, 0, 'khalid.sharma187@example.com', 2, 1233, '2026-06-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(51, 187, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-09-12 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(52, '01K2F2DKG0EQRCYGGM2DKDSGTS', 1, 188, 'James Kapoor', 'james-kapoor-52', 'active', 'unverified', NULL, 0, 0, 'james.kapoor188@example.com', 1, 1231, '2025-01-26 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(52, 188, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-10-20 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(53, '01K2F2DKG0GM78SR5VNRWFKF8C', 1, 189, 'Lucas Meyer', 'lucas-meyer-53', 'active', 'unverified', NULL, 0, 0, 'lucas.meyer189@example.com', 3, 1085, '2025-03-26 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(53, 189, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-12-08 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(54, '01K2F2DKG0B5TMY40ZZTBPBX5P', 1, 190, 'Charlotte Marchetti', 'charlotte-marchetti-54', 'active', 'unverified', NULL, 0, 0, 'charlotte.marchetti190@example.com', 2, 1233, '2025-08-09 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(54, 190, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-04-17 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(55, '01K2F2DKG0A03B9H7EYXZ8GBYF', 1, 191, 'Rashid Sato', 'rashid-sato-55', 'active', 'unverified', NULL, 0, 0, 'rashid.sato191@example.com', 1, 1231, '2025-02-18 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(55, 191, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-12-27 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(56, '01K2F2DKG01EQ8REMGWV27ZM2P', 2, 192, 'Mariam Al Mansouri', 'mariam-al-mansouri-56', 'active', 'verified', '2025-12-16 09:00:00', 3, 0, 'mariam.al-mansouri192@example.com', 13, 1014, '2025-08-11 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(56, 192, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2025-02-19 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(57, '01K2F2DKG0RSCKGDEMX9J8C3SN', 2, 193, 'Hassan Mercer', 'hassan-mercer-57', 'active', 'verified', '2025-11-21 09:00:00', 3, 0, 'hassan.mercer193@example.com', 2, 1233, '2025-08-30 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(57, 193, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2026-07-24 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(58, '01K2F2DKG0TY3ZXWNZP4SH6KWX', 2, 194, 'Nadia Clarke', 'nadia-clarke-58', 'active', 'verified', '2026-07-15 09:00:00', 3, 0, 'nadia.clarke194@example.com', 1, 1231, '2025-06-24 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(58, 194, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2025-10-19 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(59, '01K2F2DKG0VXWF70GVHJWXP7Y1', 1, 195, 'Ingrid Kapoor', 'ingrid-kapoor-59', 'active', 'unverified', NULL, 0, 0, 'ingrid.kapoor195@example.com', 1, 1231, '2026-07-11 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(59, 195, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-01-06 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(60, '01K2F2DKG09RTEPJKYDGJPBN2D', 1, 196, 'Leila Bakr', 'leila-bakr-60', 'active', 'unverified', NULL, 0, 0, 'leila.bakr196@example.com', 1, 1231, '2026-02-22 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(60, 196, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-07 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(61, '01K2F2DKG0BH9D90B4RX7YJKDJ', 1, 197, 'Rania Al Mansouri', 'rania-al-mansouri-61', 'active', 'unverified', NULL, 0, 0, 'rania.al-mansouri197@example.com', 2, 1233, '2025-06-03 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(61, 197, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-12-09 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(62, '01K2F2DKG0NMF5MSV0ZD56HB3D', 1, 198, 'Lucas Al Otaiba', 'lucas-al-otaiba-62', 'active', 'unverified', NULL, 0, 0, 'lucas.al-otaiba198@example.com', 6, 1194, '2024-10-30 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(62, 198, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-01-16 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(63, '01K2F2DKG0V9EWWBSF7RBJTCME', 1, 199, 'Fatima Al Balushi', 'fatima-al-balushi-63', 'active', 'unverified', NULL, 0, 0, 'fatima.al-balushi199@example.com', 19, 1204, '2025-05-05 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(63, 199, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-09-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(64, '01K2F2DKG0S26C4NFZDHKJ9KM5', 1, 200, 'Emma Haddad', 'emma-haddad-64', 'active', 'unverified', NULL, 0, 0, 'emma.haddad200@example.com', 4, 1232, '2026-05-30 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(64, 200, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-07-08 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(65, '01K2F2DKG0JX6VJQZKBARHZDDT', 1, 201, 'Fatima Beaumont', 'fatima-beaumont-65', 'active', 'unverified', NULL, 0, 0, 'fatima.beaumont201@example.com', 3, 1075, '2026-07-14 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(65, 201, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(66, '01K2F2DKG0Z6BAJJM81XZQZ0N7', 1, 202, 'Zainab Al Mansouri', 'zainab-al-mansouri-66', 'active', 'unverified', NULL, 0, 0, 'zainab.al-mansouri202@example.com', 1, 1231, '2024-11-05 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(66, 202, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-05-14 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(67, '01K2F2DKG0ZCC1GV3BJVCGCZSE', 1, 203, 'Hana Laurent', 'hana-laurent-67', 'active', 'unverified', NULL, 0, 0, 'hana.laurent203@example.com', 19, 1204, '2024-10-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(67, 203, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-04-27 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(68, '01K2F2DKG0FBF77NJ02P2VD805', 1, 204, 'Hana El Sayed', 'hana-el-sayed-68', 'active', 'unverified', NULL, 0, 0, 'hana.el-sayed204@example.com', 4, 1232, '2024-10-31 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(68, 204, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-11-24 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(69, '01K2F2DKG0Q69A4KM3YV8ZW826', 1, 205, 'Aisha Moretti', 'aisha-moretti-69', 'active', 'unverified', NULL, 0, 0, 'aisha.moretti205@example.com', 2, 1233, '2025-11-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(69, 205, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-10-07 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(70, '01K2F2DKG0KNN4054YQ2TGJD8T', 1, 206, 'Hassan Volkov', 'hassan-volkov-70', 'active', 'unverified', NULL, 0, 0, 'hassan.volkov206@example.com', 2, 1102, '2025-03-17 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(70, 206, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-04-29 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(71, '01K2F2DKG0212G16VDATQEGAA9', 1, 207, 'Arjun Clarke', 'arjun-clarke-71', 'active', 'unverified', NULL, 0, 0, 'arjun.clarke207@example.com', 1, 1231, '2025-05-12 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(71, 207, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-10-05 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(72, '01K2F2DKG0YAWMZG3Q6B1JSFGA', 1, 208, 'Isabella Volkov', 'isabella-volkov-72', 'active', 'unverified', NULL, 0, 0, 'isabella.volkov208@example.com', 3, 1085, '2026-06-08 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(72, 208, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-11-18 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(73, '01K2F2DKG0D7AM8ZF1NAPGQKZH', 1, 209, 'Farah Karim', 'farah-karim-73', 'active', 'unverified', NULL, 0, 0, 'farah.karim209@example.com', 2, 1233, '2026-04-09 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(73, 209, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-02-25 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(74, '01K2F2DKG0A6GYHQXBG0A0CF2T', 1, 210, 'Mohammed Lindqvist', 'mohammed-lindqvist-74', 'active', 'unverified', NULL, 0, 0, 'mohammed.lindqvist210@example.com', 1, 1231, '2026-08-04 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(74, 210, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-10-31 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(75, '01K2F2DKG0V54CT50E8T7E1ZYJ', 1, 211, 'Sebastian Ivanov', 'sebastian-ivanov-75', 'active', 'unverified', NULL, 0, 0, 'sebastian.ivanov211@example.com', 3, 1075, '2025-05-14 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(75, 211, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-05-19 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(76, '01K2F2DKG0PBSQZ56Q4JD2GHCM', 1, 212, 'Noor Al Balushi', 'noor-al-balushi-76', 'active', 'unverified', NULL, 0, 0, 'noor.al-balushi212@example.com', 3, 1075, '2024-11-02 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(76, 212, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-05-01 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(77, '01K2F2DKG0DRAP3GZ6TVDVV3GR', 1, 213, 'Youssef Rossellini', 'youssef-rossellini-77', 'active', 'unverified', NULL, 0, 0, 'youssef.rossellini213@example.com', 4, 1232, '2026-01-13 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(77, 213, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-11-25 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(78, '01K2F2DKG0PQ4CC5HC3X9Q2J75', 1, 214, 'Sarah Al Balushi', 'sarah-al-balushi-78', 'active', 'unverified', NULL, 0, 0, 'sarah.al-balushi214@example.com', 3, 1177, '2025-01-27 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(78, 214, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-11-28 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(79, '01K2F2DKG014W014DRDVHDEV1A', 1, 215, 'Noor Al Balushi', 'noor-al-balushi-79', 'active', 'unverified', NULL, 0, 0, 'noor.al-balushi215@example.com', 19, 1204, '2024-12-10 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(79, 215, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-06-30 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(80, '01K2F2DKG0N7K0T06C26EBV5D9', 2, 216, 'Farah Königsberg', 'farah-konigsberg-80', 'active', 'verified', '2026-03-07 09:00:00', 3, 0, 'farah.konigsberg216@example.com', 1, 1231, '2026-03-29 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(80, 216, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2024-11-26 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(81, '01K2F2DKG0C39MYZTW1V5YH066', 1, 217, 'Nadia Halabi', 'nadia-halabi-81', 'active', 'unverified', NULL, 0, 0, 'nadia.halabi217@example.com', 2, 1233, '2024-11-23 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(81, 217, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-10-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(82, '01K2F2DKG02Y2C3ZR78R165W5P', 1, 218, 'Hassan Ferrari', 'hassan-ferrari-82', 'active', 'unverified', NULL, 0, 0, 'hassan.ferrari218@example.com', 6, 1194, '2026-03-12 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(82, 218, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-12 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(83, '01K2F2DKG0J3RS5EG340APQ52T', 1, 219, 'Camille Sharma', 'camille-sharma-83', 'active', 'unverified', NULL, 0, 0, 'camille.sharma219@example.com', 3, 1075, '2024-11-06 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(83, 219, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-07-25 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(84, '01K2F2DKG0K831K3EE1G6KGSYQ', 2, 220, 'Priya Al Suwaidi', 'priya-al-suwaidi-84', 'active', 'verified', '2026-02-26 09:00:00', 3, 0, 'priya.al-suwaidi220@example.com', 6, 1194, '2026-05-06 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(84, 220, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2025-09-24 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(85, '01K2F2DKG0JJDEQ4HGF3NKD0CE', 1, 221, 'Alexander Volkov', 'alexander-volkov-85', 'active', 'unverified', NULL, 0, 0, 'alexander.volkov221@example.com', 3, 1207, '2026-07-03 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(85, 221, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-01-30 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(86, '01K2F2DKG0WTZ8WT4HXQED1A7T', 1, 222, 'Vikram Rossellini', 'vikram-rossellini-86', 'active', 'unverified', NULL, 0, 0, 'vikram.rossellini222@example.com', 3, 1075, '2026-06-08 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(86, 222, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-01-17 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(87, '01K2F2DKG02T70Q6W951TWQXJZ', 1, 223, 'Sarah Al Mansouri', 'sarah-al-mansouri-87', 'active', 'unverified', NULL, 0, 0, 'sarah.al-mansouri223@example.com', 2, 1233, '2025-06-11 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(87, 223, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-06-28 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(88, '01K2F2DKG0M706Q1YGMCYPMQZX', 1, 224, 'Anastasia Laurent', 'anastasia-laurent-88', 'active', 'unverified', NULL, 0, 0, 'anastasia.laurent224@example.com', 3, 1177, '2026-04-19 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(88, 224, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-07-12 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(89, '01K2F2DKG0AVKRBAK1N07YZB2B', 1, 225, 'Marco Fairfax', 'marco-fairfax-89', 'active', 'unverified', NULL, 0, 0, 'marco.fairfax225@example.com', 1, 1231, '2024-10-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(89, 225, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(90, '01K2F2DKG0FKH158SF6BTPH4MD', 1, 226, 'Henry Whitfield', 'henry-whitfield-90', 'active', 'unverified', NULL, 0, 0, 'henry.whitfield226@example.com', 3, 1207, '2025-08-21 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(90, 226, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-03-02 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(91, '01K2F2DKG0ED38KFGF88SS3KEY', 1, 227, 'James El Sayed', 'james-el-sayed-91', 'active', 'unverified', NULL, 0, 0, 'james.el-sayed227@example.com', 13, 1014, '2026-02-26 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(91, 227, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-01-11 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(92, '01K2F2DKG01NMZW0361P06YES8', 1, 228, 'Rafael Moreau', 'rafael-moreau-92', 'active', 'unverified', NULL, 0, 0, 'rafael.moreau228@example.com', 3, 1207, '2025-12-03 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(92, 228, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-08-08 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(93, '01K2F2DKG0K79F5NXEGXW6RCAQ', 1, 229, 'Marco Santos', 'marco-santos-93', 'active', 'unverified', NULL, 0, 0, 'marco.santos229@example.com', 1, 1231, '2025-09-26 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(93, 229, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-06-04 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(94, '01K2F2DKG0GHB5NCAKTX0QRXKR', 1, 230, 'Aisha Ivanov', 'aisha-ivanov-94', 'active', 'unverified', NULL, 0, 0, 'aisha.ivanov230@example.com', 2, 1011, '2024-10-21 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(94, 230, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-02-05 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(95, '01K2F2DKG0A0B4XSTQCN0P324F', 1, 231, 'Charlotte Volkov', 'charlotte-volkov-95', 'active', 'unverified', NULL, 0, 0, 'charlotte.volkov231@example.com', 3, 1145, '2025-11-04 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(95, 231, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-06-19 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(96, '01K2F2DKG051JBEYADKBK0SR0A', 1, 232, 'Mariam Rossi', 'mariam-rossi-96', 'active', 'unverified', NULL, 0, 0, 'mariam.rossi232@example.com', 3, 1207, '2025-07-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(96, 232, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-09-24 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(97, '01K2F2DKG0KC55D0SP1EGG64EG', 2, 233, 'Anastasia El Sayed', 'anastasia-el-sayed-97', 'active', 'verified', '2026-06-18 09:00:00', 3, 0, 'anastasia.el-sayed233@example.com', 2, 1233, '2025-04-26 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(97, 233, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2024-11-15 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(98, '01K2F2DKG0JKD56NZCBB0Y4FRB', 2, 234, 'Priya Al Suwaidi', 'priya-al-suwaidi-98', 'active', 'verified', '2025-12-12 09:00:00', 3, 0, 'priya.al-suwaidi234@example.com', 21, 1142, '2026-02-17 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(98, 234, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2026-02-14 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(99, '01K2F2DKG06PS8M648DYSRJG6Q', 1, 235, 'Antoine Kapoor', 'antoine-kapoor-99', 'active', 'unverified', NULL, 0, 0, 'antoine.kapoor235@example.com', 3, 1177, '2025-06-09 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(99, 235, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-01-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(100, '01K2F2DKG0ZF0TYAN378PTMT0V', 1, 236, 'Sarah Marchetti', 'sarah-marchetti-100', 'active', 'unverified', NULL, 0, 0, 'sarah.marchetti236@example.com', 22, 1219, '2025-03-15 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(100, 236, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-03-12 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(101, '01K2F2DKG0KR95S3SS48GCV2ZJ', 1, 237, 'Daniel Rahman', 'daniel-rahman-101', 'active', 'unverified', NULL, 0, 0, 'daniel.rahman237@example.com', 1, 1231, '2025-05-23 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(101, 237, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-06-30 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(102, '01K2F2DKG041X90QEYP4BV8C1B', 1, 238, 'Omar Herrera', 'omar-herrera-102', 'active', 'unverified', NULL, 0, 0, 'omar.herrera238@example.com', 2, 1233, '2026-05-10 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(102, 238, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-01-11 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(103, '01K2F2DKG0KCC7EH08QFFC0MBS', 1, 239, 'Karim Königsberg', 'karim-konigsberg-103', 'active', 'unverified', NULL, 0, 0, 'karim.konigsberg239@example.com', 4, 1232, '2025-09-13 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(103, 239, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-12-29 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(104, '01K2F2DKG0GN1SE9MSFXYR0BZ0', 1, 240, 'Mohammed Ashworth', 'mohammed-ashworth-104', 'active', 'unverified', NULL, 0, 0, 'mohammed.ashworth240@example.com', 3, 1207, '2025-11-22 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(104, 240, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-01-08 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(105, '01K2F2DKG0MJFN2WF7KDX60Z92', 1, 241, 'Rafael Clarke', 'rafael-clarke-105', 'active', 'unverified', NULL, 0, 0, 'rafael.clarke241@example.com', 3, 1207, '2025-11-25 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(105, 241, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-06-05 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(106, '01K2F2DKG0DC9G7078YTPB3KGA', 1, 242, 'Nadia Bin Ahmed', 'nadia-bin-ahmed-106', 'active', 'unverified', NULL, 0, 0, 'nadia.bin-ahmed242@example.com', 1, 1231, '2026-08-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(106, 242, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-12-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(107, '01K2F2DKG038A13W4CBBPZ1DVN', 1, 243, 'Diego Aziz', 'diego-aziz-107', 'active', 'unverified', NULL, 0, 0, 'diego.aziz243@example.com', 19, 1204, '2025-02-25 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(107, 243, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-03-20 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(108, '01K2F2DKG0XD6S4HB9CBKX84CA', 1, 244, 'Fatima Wong', 'fatima-wong-108', 'active', 'unverified', NULL, 0, 0, 'fatima.wong244@example.com', 2, 1233, '2025-09-11 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(108, 244, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(109, '01K2F2DKG0GW2QZF4RMB7PR9KJ', 1, 245, 'Alexander Rossellini', 'alexander-rossellini-109', 'active', 'unverified', NULL, 0, 0, 'alexander.rossellini245@example.com', 4, 1232, '2026-06-30 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(109, 245, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-02-21 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(110, '01K2F2DKG0ZZGTPPYHVJXS3X45', 1, 246, 'Nikolai Marchetti', 'nikolai-marchetti-110', 'active', 'unverified', NULL, 0, 0, 'nikolai.marchetti246@example.com', 19, 1204, '2026-05-06 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(110, 246, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-03-31 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(111, '01K2F2DKG0PGVGTTZQ449JGE5B', 1, 247, 'Farah Khoury', 'farah-khoury-111', 'active', 'unverified', NULL, 0, 0, 'farah.khoury247@example.com', 1, 1231, '2025-12-29 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(111, 247, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-03-18 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(112, '01K2F2DKG0Z9TBFKTDDPJCVD6R', 1, 248, 'Rashid Rahman', 'rashid-rahman-112', 'active', 'unverified', NULL, 0, 0, 'rashid.rahman248@example.com', 2, 1227, '2026-05-15 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(112, 248, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-09-19 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(113, '01K2F2DKG06XYFMSTFYWJ696M1', 1, 249, 'James Marchetti', 'james-marchetti-113', 'active', 'unverified', NULL, 0, 0, 'james.marchetti249@example.com', 1, 1231, '2026-03-13 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(113, 249, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-06-11 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(114, '01K2F2DKG0RNGNWC7KH74N67R0', 1, 250, 'Isabella Nasser', 'isabella-nasser-114', 'active', 'unverified', NULL, 0, 0, 'isabella.nasser250@example.com', 12, 1098, '2025-03-12 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(114, 250, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-05-30 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(115, '01K2F2DKG08W2EFCJGCG21SW5Z', 1, 251, 'Sarah Sterling', 'sarah-sterling-115', 'active', 'unverified', NULL, 0, 0, 'sarah.sterling251@example.com', 3, 1107, '2025-05-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(115, 251, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-10-11 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(116, '01K2F2DKG0R9E3BZFH6WHF273G', 1, 252, 'Chen Aziz', 'chen-aziz-116', 'active', 'unverified', NULL, 0, 0, 'chen.aziz252@example.com', 2, 1233, '2025-12-29 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(116, 252, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-12-25 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(117, '01K2F2DKG0MH4H2WC6HK44SRQC', 1, 253, 'Diego Al Farsi', 'diego-al-farsi-117', 'active', 'unverified', NULL, 0, 0, 'diego.al-farsi253@example.com', 3, 1085, '2025-07-17 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(117, 253, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-10-20 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(118, '01K2F2DKG060AHD2JQ11947QCP', 1, 254, 'Camille Ferrari', 'camille-ferrari-118', 'active', 'unverified', NULL, 0, 0, 'camille.ferrari254@example.com', 2, 1233, '2026-05-23 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(118, 254, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-10-26 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(119, '01K2F2DKG0Y0J8SPZQR7CA7765', 1, 255, 'Rania Fairfax', 'rania-fairfax-119', 'active', 'unverified', NULL, 0, 0, 'rania.fairfax255@example.com', 18, 1225, '2024-11-03 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(119, 255, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-02-18 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(120, '01K2F2DKG0HQWQET14BBQ7WKDA', 1, 256, 'Chen Ashworth', 'chen-ashworth-120', 'active', 'unverified', NULL, 0, 0, 'chen.ashworth256@example.com', 4, 1232, '2025-06-24 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(120, 256, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-12-07 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(121, '01K2F2DKG0XE364J2HCB4HXN6J', 1, 257, 'Sebastian Al Mansouri', 'sebastian-al-mansouri-121', 'active', 'unverified', NULL, 0, 0, 'sebastian.al-mansouri257@example.com', 3, 1207, '2025-03-09 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(121, 257, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-08-22 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(122, '01K2F2DKG0S5258EQJX79XEHDM', 1, 258, 'Arjun Königsberg', 'arjun-konigsberg-122', 'active', 'unverified', NULL, 0, 0, 'arjun.konigsberg258@example.com', 12, 1098, '2025-03-15 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(122, 258, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-06-14 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(123, '01K2F2DKG0D9S2YJH214TVWXAZ', 1, 259, 'Daniel Mercer', 'daniel-mercer-123', 'active', 'unverified', NULL, 0, 0, 'daniel.mercer259@example.com', 1, 1231, '2025-07-01 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(123, 259, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-14 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(124, '01K2F2DKG0AYH9CE0VM1SS584Y', 2, 260, 'Sofia Marchetti', 'sofia-marchetti-124', 'active', 'verified', '2026-05-15 09:00:00', 3, 0, 'sofia.marchetti260@example.com', 22, 1219, '2025-09-10 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(124, 260, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2025-09-15 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(125, '01K2F2DKG0ZKZJV5HZTETN51FY', 1, 261, 'Arjun Kapoor', 'arjun-kapoor-125', 'active', 'unverified', NULL, 0, 0, 'arjun.kapoor261@example.com', 2, 1227, '2026-05-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(125, 261, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-11-24 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(126, '01K2F2DKG0JK29M3RBTH9XN0AW', 2, 262, 'Camille Darwish', 'camille-darwish-126', 'active', 'verified', '2026-02-03 09:00:00', 3, 0, 'camille.darwish262@example.com', 1, 1231, '2024-10-26 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(126, 262, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2024-11-16 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(127, '01K2F2DKG0BEGX7F7DMKY3RMKW', 1, 263, 'Elena Halabi', 'elena-halabi-127', 'active', 'unverified', NULL, 0, 0, 'elena.halabi263@example.com', 1, 1231, '2026-03-06 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(127, 263, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-03-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(128, '01K2F2DKG0A0MQRGC6566AT0ZP', 1, 264, 'Yuki Dubois', 'yuki-dubois-128', 'active', 'unverified', NULL, 0, 0, 'yuki.dubois264@example.com', 2, 1011, '2025-06-16 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(128, 264, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-10-11 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(129, '01K2F2DKG0D4A7BH5AY6ZAZ906', 1, 265, 'Karim Hussein', 'karim-hussein-129', 'active', 'unverified', NULL, 0, 0, 'karim.hussein265@example.com', 2, 1233, '2024-12-04 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(129, 265, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-07-05 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(130, '01K2F2DKG0WWJR1KVVKP7MVMM3', 1, 266, 'Hassan Ashworth', 'hassan-ashworth-130', 'active', 'unverified', NULL, 0, 0, 'hassan.ashworth266@example.com', 3, 1177, '2025-05-25 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(130, 266, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-10-09 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(131, '01K2F2DKG0RY96STKWFFCP1Q1V', 1, 267, 'Vikram Sterling', 'vikram-sterling-131', 'active', 'unverified', NULL, 0, 0, 'vikram.sterling267@example.com', 3, 1107, '2024-11-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(131, 267, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-04-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(132, '01K2F2DKG0DYCB2CZVJ89KZP0Z', 1, 268, 'Noor Halabi', 'noor-halabi-132', 'active', 'unverified', NULL, 0, 0, 'noor.halabi268@example.com', 3, 1207, '2026-02-28 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(132, 268, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-01-11 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(133, '01K2F2DKG0XTZWBNDJ7ZK1XE5N', 1, 269, 'Julien Fairfax', 'julien-fairfax-133', 'active', 'unverified', NULL, 0, 0, 'julien.fairfax269@example.com', 18, 1225, '2024-11-08 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(133, 269, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-11-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(134, '01K2F2DKG0PV2G4DJGQMTA7T63', 1, 270, 'Antoine Rossellini', 'antoine-rossellini-134', 'active', 'unverified', NULL, 0, 0, 'antoine.rossellini270@example.com', 1, 1231, '2025-11-08 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(134, 270, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-05-20 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(135, '01K2F2DKG0Y4WXNE96RKZF2JVH', 1, 271, 'Mohammed Clarke', 'mohammed-clarke-135', 'active', 'unverified', NULL, 0, 0, 'mohammed.clarke271@example.com', 2, 1233, '2024-12-19 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(135, 271, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-01-02 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(136, '01K2F2DKG0MHGF2MYSDGATRF85', 1, 272, 'Valentina Wong', 'valentina-wong-136', 'active', 'unverified', NULL, 0, 0, 'valentina.wong272@example.com', 3, 1107, '2025-03-04 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(136, 272, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-10-14 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(137, '01K2F2DKG0XQ5Y2YXDAFVW12C2', 1, 273, 'Hassan Tanaka', 'hassan-tanaka-137', 'active', 'unverified', NULL, 0, 0, 'hassan.tanaka273@example.com', 2, 1227, '2024-10-30 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(137, 273, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-19 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(138, '01K2F2DKG011ZK6K7WF45HRECS', 2, 274, 'Yuki Al Otaiba', 'yuki-al-otaiba-138', 'active', 'verified', '2026-04-09 09:00:00', 3, 0, 'yuki.al-otaiba274@example.com', 1, 1231, '2025-06-02 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(138, 274, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2026-06-17 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(139, '01K2F2DKG0V7CCRP5KP3CYS9YA', 1, 275, 'Karim Marchetti', 'karim-marchetti-139', 'active', 'unverified', NULL, 0, 0, 'karim.marchetti275@example.com', 19, 1204, '2025-04-26 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(139, 275, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-04-23 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(140, '01K2F2DKG0D8AND22R6JZJ851S', 1, 276, 'Elena Bin Ahmed', 'elena-bin-ahmed-140', 'active', 'unverified', NULL, 0, 0, 'elena.bin-ahmed276@example.com', 12, 1098, '2026-01-17 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(140, 276, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-12-04 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(141, '01K2F2DKG0K9Z8P2FX6K7BR6EJ', 1, 277, 'Fatima Bakr', 'fatima-bakr-141', 'active', 'unverified', NULL, 0, 0, 'fatima.bakr277@example.com', 1, 1231, '2025-09-09 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(141, 277, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-04-05 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(142, '01K2F2DKG0MC68M7Z2AYWX8TAC', 1, 278, 'Theo Rahman', 'theo-rahman-142', 'active', 'unverified', NULL, 0, 0, 'theo.rahman278@example.com', 2, 1227, '2024-09-16 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(142, 278, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-11-30 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(143, '01K2F2DKG03TH8A4Q8CSE12K9P', 1, 279, 'Maximilian Al Mansouri', 'maximilian-al-mansouri-143', 'active', 'unverified', NULL, 0, 0, 'maximilian.al-mansouri279@example.com', 3, 1207, '2026-03-30 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(143, 279, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-03-04 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(144, '01K2F2DKG021515M2XABX8M6W8', 1, 280, 'Hassan Dubois', 'hassan-dubois-144', 'active', 'unverified', NULL, 0, 0, 'hassan.dubois280@example.com', 2, 1233, '2026-01-23 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(144, 280, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-01-05 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(145, '01K2F2DKG0S87YSS70JTTVF8CE', 1, 281, 'Sarah Kapoor', 'sarah-kapoor-145', 'active', 'unverified', NULL, 0, 0, 'sarah.kapoor281@example.com', 2, 1233, '2025-01-17 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(145, 281, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-12-31 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(146, '01K2F2DKG01K4MR13340PZ6D5D', 2, 282, 'Priya Wong', 'priya-wong-146', 'active', 'verified', '2026-01-29 09:00:00', 3, 0, 'priya.wong282@example.com', 3, 1145, '2025-04-06 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(146, 282, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2026-01-23 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(147, '01K2F2DKG095G3JG5EPSQZC60J', 1, 283, 'Lucas Whitfield', 'lucas-whitfield-147', 'active', 'unverified', NULL, 0, 0, 'lucas.whitfield283@example.com', 3, 1107, '2026-03-29 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(147, 283, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-11-13 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(148, '01K2F2DKG0WC4PP48CYYFG95KJ', 1, 284, 'Hana Rahman', 'hana-rahman-148', 'active', 'unverified', NULL, 0, 0, 'hana.rahman284@example.com', 2, 1102, '2025-05-10 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(148, 284, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-12-17 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(149, '01K2F2DKG09T5ZB2B9EW2C9Q1X', 1, 285, 'Henry Al Otaiba', 'henry-al-otaiba-149', 'active', 'unverified', NULL, 0, 0, 'henry.al-otaiba285@example.com', 2, 1233, '2025-07-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(149, 285, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-11-04 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(150, '01K2F2DKG0ZKKTTBKSC2N78VHA', 1, 286, 'Youssef Kapoor', 'youssef-kapoor-150', 'active', 'unverified', NULL, 0, 0, 'youssef.kapoor286@example.com', 2, 1102, '2025-11-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(150, 286, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-13 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(151, '01K2F2DKG0AH972Y1QKF1A18TQ', 1, 287, 'Lucas Bakr', 'lucas-bakr-151', 'active', 'unverified', NULL, 0, 0, 'lucas.bakr287@example.com', 3, 1207, '2025-10-05 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(151, 287, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-11-10 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(152, '01K2F2DKG051CAPJYP6R4PA2RH', 1, 288, 'Karim Herrera', 'karim-herrera-152', 'active', 'unverified', NULL, 0, 0, 'karim.herrera288@example.com', 5, 1214, '2024-11-08 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(152, 288, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-09-19 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(153, '01K2F2DKG0TEWZCQVPNHXCVFZN', 1, 289, 'Valentina Bakr', 'valentina-bakr-153', 'active', 'unverified', NULL, 0, 0, 'valentina.bakr289@example.com', 3, 1207, '2025-11-15 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(153, 289, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-10-13 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(154, '01K2F2DKG08VB0FD76CNJ5RMH1', 1, 290, 'Charlotte Ferrari', 'charlotte-ferrari-154', 'active', 'unverified', NULL, 0, 0, 'charlotte.ferrari290@example.com', 13, 1014, '2025-07-12 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(154, 290, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-05-13 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(155, '01K2F2DKG0HKPBZ5W6G871BE7N', 1, 291, 'Layla Rahman', 'layla-rahman-155', 'active', 'unverified', NULL, 0, 0, 'layla.rahman291@example.com', 2, 1233, '2025-04-26 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(155, 291, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-02 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(156, '01K2F2DKG07WXWA8CF3X34PB0F', 1, 292, 'Amelia Fairfax', 'amelia-fairfax-156', 'active', 'unverified', NULL, 0, 0, 'amelia.fairfax292@example.com', 1, 1231, '2026-02-20 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(156, 292, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-09-21 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(157, '01K2F2DKG0WCQ4PXYZ0C5C7C29', 1, 293, 'Camille Darwish', 'camille-darwish-157', 'active', 'unverified', NULL, 0, 0, 'camille.darwish293@example.com', 11, 1199, '2025-01-14 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(157, 293, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-04-13 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(158, '01K2F2DKG0S1Y484Y6SJP7TEM6', 1, 294, 'Diego Volkov', 'diego-volkov-158', 'active', 'unverified', NULL, 0, 0, 'diego.volkov294@example.com', 3, 1085, '2026-08-13 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(158, 294, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-04-15 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(159, '01K2F2DKG0CARGPVD6TMTM88T3', 1, 295, 'Marco Haddad', 'marco-haddad-159', 'active', 'unverified', NULL, 0, 0, 'marco.haddad295@example.com', 1, 1231, '2026-02-24 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(159, 295, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-22 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(160, '01K2F2DKG076GJ4N18JT1S4KRC', 1, 296, 'Rafael Al Farsi', 'rafael-al-farsi-160', 'active', 'unverified', NULL, 0, 0, 'rafael.al-farsi296@example.com', 3, 1177, '2025-09-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(160, 296, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-08-27 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(161, '01K2F2DKG0HPSQF634PFZCYYQV', 1, 297, 'Chen Bin Ahmed', 'chen-bin-ahmed-161', 'active', 'unverified', NULL, 0, 0, 'chen.bin-ahmed297@example.com', 7, 1179, '2025-12-26 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(161, 297, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-12-08 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(162, '01K2F2DKG00WT1THRFE65VBG1J', 1, 298, 'Youssef Fairfax', 'youssef-fairfax-162', 'active', 'unverified', NULL, 0, 0, 'youssef.fairfax298@example.com', 12, 1098, '2026-02-20 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(162, 298, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-05-09 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(163, '01K2F2DKG0T8429V0S5XYJSFPT', 1, 299, 'Nadia Al Suwaidi', 'nadia-al-suwaidi-163', 'active', 'unverified', NULL, 0, 0, 'nadia.al-suwaidi299@example.com', 1, 1231, '2024-11-27 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(163, 299, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-07 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(164, '01K2F2DKG02VK33SY0K0W4F1SG', 1, 300, 'Hana Haddad', 'hana-haddad-164', 'active', 'unverified', NULL, 0, 0, 'hana.haddad300@example.com', 2, 1233, '2025-02-05 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(164, 300, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-05-28 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(165, '01K2F2DKG0CKJ7WRFFAJQ5JBS9', 1, 301, 'Mariam Beaumont', 'mariam-beaumont-165', 'active', 'unverified', NULL, 0, 0, 'mariam.beaumont301@example.com', 3, 1075, '2025-05-31 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(165, 301, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-02 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(166, '01K2F2DKG0MN68TGWCRARS5EAC', 1, 302, 'Amelia Whitfield', 'amelia-whitfield-166', 'active', 'unverified', NULL, 0, 0, 'amelia.whitfield302@example.com', 22, 1219, '2026-02-14 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(166, 302, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-04-21 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(167, '01K2F2DKG07K1PPWXMN42K1XXJ', 1, 303, 'Hassan Ferrari', 'hassan-ferrari-167', 'active', 'unverified', NULL, 0, 0, 'hassan.ferrari303@example.com', 2, 1233, '2025-08-12 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(167, 303, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-06-16 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(168, '01K2F2DKG0C1T52895X3HM7Z4Q', 1, 304, 'Yuki Moreau', 'yuki-moreau-168', 'active', 'unverified', NULL, 0, 0, 'yuki.moreau304@example.com', 3, 1085, '2024-09-22 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(168, 304, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-04-27 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(169, '01K2F2DKG0YXHH4T5EPQ4YTAPC', 1, 305, 'Noor Von Habsburg', 'noor-von-habsburg-169', 'active', 'unverified', NULL, 0, 0, 'noor.von-habsburg305@example.com', 7, 1179, '2026-07-10 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(169, 305, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-10 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(170, '01K2F2DKG0SPJVW4PCPYBTV89S', 1, 306, 'Nadia Blackwood', 'nadia-blackwood-170', 'active', 'unverified', NULL, 0, 0, 'nadia.blackwood306@example.com', 3, 1107, '2025-06-03 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(170, 306, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-05-31 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(171, '01K2F2DKG0FZGTH4WQTHQV850G', 1, 307, 'Emma Al Mansouri', 'emma-al-mansouri-171', 'active', 'unverified', NULL, 0, 0, 'emma.al-mansouri307@example.com', 2, 1011, '2026-03-13 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(171, 307, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-01-03 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(172, '01K2F2DKG0VKVMGJ2V4EFE9XHJ', 1, 308, 'Yuki Fairfax', 'yuki-fairfax-172', 'active', 'unverified', NULL, 0, 0, 'yuki.fairfax308@example.com', 2, 1233, '2026-04-10 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(172, 308, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-07 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(173, '01K2F2DKG0W3VE3KMA0WHKMHE5', 1, 309, 'Leila Von Habsburg', 'leila-von-habsburg-173', 'active', 'unverified', NULL, 0, 0, 'leila.von-habsburg309@example.com', 3, 1145, '2025-10-08 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(173, 309, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-05-02 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(174, '01K2F2DKG05CJKT5YG38VK9D36', 1, 310, 'Nikolai Whitfield', 'nikolai-whitfield-174', 'active', 'unverified', NULL, 0, 0, 'nikolai.whitfield310@example.com', 3, 1207, '2026-03-25 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(174, 310, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-09-12 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(175, '01K2F2DKG03BVDVRAM3X5J9YGK', 1, 311, 'Karim Mehta', 'karim-mehta-175', 'active', 'unverified', NULL, 0, 0, 'karim.mehta311@example.com', 1, 1231, '2026-04-22 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(175, 311, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-31 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(176, '01K2F2DKG0QJHAHCJENAZH8VST', 1, 312, 'Nadia Aziz', 'nadia-aziz-176', 'active', 'unverified', NULL, 0, 0, 'nadia.aziz312@example.com', 3, 1075, '2025-09-18 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(176, 312, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-08-28 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(177, '01K2F2DKG024KZJZWCA008VDBK', 1, 313, 'Omar Ashworth', 'omar-ashworth-177', 'active', 'unverified', NULL, 0, 0, 'omar.ashworth313@example.com', 3, 1207, '2025-07-13 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(177, 313, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-11-06 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(178, '01K2F2DKG0TA1Z5J4BZ2X4SVMJ', 1, 314, 'Fatima Bin Ahmed', 'fatima-bin-ahmed-178', 'active', 'unverified', NULL, 0, 0, 'fatima.bin-ahmed314@example.com', 18, 1225, '2026-08-07 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(178, 314, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-12-21 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(179, '01K2F2DKG0212A4XQ6BWS2HDPX', 1, 315, 'Ingrid Kapoor', 'ingrid-kapoor-179', 'active', 'unverified', NULL, 0, 0, 'ingrid.kapoor315@example.com', 11, 1199, '2024-12-31 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(179, 315, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-02-04 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(180, '01K2F2DKG0NZ1VQ600AS9AV1Q2', 1, 316, 'Aisha Whitfield', 'aisha-whitfield-180', 'active', 'unverified', NULL, 0, 0, 'aisha.whitfield316@example.com', 1, 1231, '2025-04-18 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(180, 316, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-23 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(181, '01K2F2DKG06WXB4N2WDSBBPAQ5', 1, 317, 'James Beaumont', 'james-beaumont-181', 'active', 'unverified', NULL, 0, 0, 'james.beaumont317@example.com', 14, 1039, '2025-11-24 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(181, 317, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-14 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(182, '01K2F2DKG07P2HVP4RPVJFV5TF', 2, 318, 'Vikram Sato', 'vikram-sato-182', 'active', 'verified', '2025-11-27 09:00:00', 3, 0, 'vikram.sato318@example.com', 22, 1219, '2025-06-02 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(182, 318, 'owner', 'active', 1, 0, 1, 1, 1, 0, 1, '2025-02-19 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(183, '01K2F2DKG0YSQ28NKVRJF9HZRD', 1, 319, 'Omar Kapoor', 'omar-kapoor-183', 'active', 'unverified', NULL, 0, 0, 'omar.kapoor319@example.com', 22, 1219, '2025-11-03 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(183, 319, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-04-05 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(184, '01K2F2DKG0SYNSJZ90PHFGP4WA', 1, 320, 'Omar Rahman', 'omar-rahman-184', 'active', 'unverified', NULL, 0, 0, 'omar.rahman320@example.com', 18, 1225, '2025-09-18 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(184, 320, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-11-07 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(185, '01K2F2DKG08P3RRJGDFR9FYE50', 1, 321, 'Hassan Moretti', 'hassan-moretti-185', 'active', 'unverified', NULL, 0, 0, 'hassan.moretti321@example.com', 3, 1145, '2024-12-02 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(185, 321, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-07-25 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(186, '01K2F2DKG0WNQD05VEGNGBGHSW', 1, 322, 'Nikolai Halabi', 'nikolai-halabi-186', 'active', 'unverified', NULL, 0, 0, 'nikolai.halabi322@example.com', 3, 1177, '2025-01-21 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(186, 322, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-01-23 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(187, '01K2F2DKG0BHFFJ737SGFW6GJY', 1, 323, 'Isabella Rahman', 'isabella-rahman-187', 'active', 'unverified', NULL, 0, 0, 'isabella.rahman323@example.com', 1, 1231, '2026-06-16 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(187, 323, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-04-23 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(188, '01K2F2DKG0VQ3NNVZ1QH7CGAS0', 1, 324, 'Sarah Al Otaiba', 'sarah-al-otaiba-188', 'active', 'unverified', NULL, 0, 0, 'sarah.al-otaiba324@example.com', 3, 1207, '2026-05-02 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(188, 324, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2024-11-15 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(189, '01K2F2DKG08NNDE2ZGD3FZH34Z', 1, 325, 'Antoine Beaumont', 'antoine-beaumont-189', 'active', 'unverified', NULL, 0, 0, 'antoine.beaumont325@example.com', 6, 1194, '2026-04-23 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(189, 325, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-06-25 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(190, '01K2F2DKG09783JVV4PHQ8JDVA', 1, 326, 'Arjun Wong', 'arjun-wong-190', 'active', 'unverified', NULL, 0, 0, 'arjun.wong326@example.com', 3, 1075, '2026-07-29 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(190, 326, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-08-12 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(191, '01K2F2DKG01J2D0E591K0HWRSG', 1, 327, 'Rania Mercer', 'rania-mercer-191', 'active', 'unverified', NULL, 0, 0, 'rania.mercer327@example.com', 2, 1233, '2025-08-06 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(191, 327, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2026-07-09 09:00:00');

INSERT INTO accounts (id, public_id, account_type_id, owner_user_id, name, slug, status, verification_status, verified_at, listing_quota, featured_quota, billing_email, billing_currency_id, country_id, created_at) VALUES
(192, '01K2F2DKG06RN3EWEGHP0XD8SD', 1, 328, 'Rania Al Mansouri', 'rania-al-mansouri-192', 'active', 'unverified', NULL, 0, 0, 'rania.al-mansouri328@example.com', 3, 1075, '2024-09-29 09:00:00');

INSERT INTO account_members (account_id, user_id, role, status, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(192, 328, 'owner', 'active', 1, 0, 0, 0, 1, 0, 1, '2025-03-04 09:00:00');

-- Two people hold memberships in more than one account, so the account
-- switcher has something real to switch between. The audit found no
-- code path for this anywhere; this is the data it needs.
INSERT INTO account_members (account_id, user_id, role, status, title, can_manage_organization, can_manage_members, can_manage_listings, can_publish_listings, can_manage_leads, can_view_integrations, can_manage_billing, joined_at) VALUES
(1, 180, 'agent', 'active', 'Associate', 0, 0, 1, 0, 1, 0, 0, '2026-04-19 09:00:00'),
(2, 181, 'agent', 'active', 'Associate', 0, 0, 1, 0, 1, 0, 0, '2026-04-19 09:00:00');

-- Default landing account per user.
UPDATE users u JOIN account_members am ON am.user_id = u.id SET u.default_account_id = am.account_id WHERE u.default_account_id IS NULL;

-- Account type change requests — the flow the audit found missing.
-- One approved (already applied), one under review, one rejected, so the
-- admin queue and the portal history both have real states to render.
INSERT INTO account_type_change_requests (public_id, account_id, requested_by_user_id, from_type_id, to_type_id, status, payload, reason, reviewed_by_user_id, reviewed_at, review_notes, applied_at, created_at) VALUES
('01K2F2DKG0N5754SQGK8Q9TZPY', 46, 182, 1, 2, 'approved', '{"legal_name":"Placeholder Trading LLC","license_number":"CN-1234567","country":"AE"}', 'Moving from browsing to listing our own portfolio.', 3, '2026-08-05 09:00:00', 'Trade licence verified. Converted and quota applied.', '2026-08-05 09:00:00', '2026-08-03 09:00:00'),
('01K2F2DKG02CCGVRDBCY8WYGNV', 47, 183, 1, 2, 'under_review', '{"legal_name":"Placeholder Trading LLC","license_number":"CN-1234567","country":"AE"}', 'Moving from browsing to listing our own portfolio.', NULL, NULL, NULL, NULL, '2026-07-30 09:00:00'),
('01K2F2DKG003MGEE4RT2R9KP28', 48, 184, 1, 2, 'rejected', '{"legal_name":"Placeholder Trading LLC","license_number":"CN-1234567","country":"AE"}', 'Moving from browsing to listing our own portfolio.', 3, '2026-07-03 09:00:00', 'Trade licence supplied is expired. Resubmit with a current copy.', NULL, '2026-07-01 09:00:00'),
('01K2F2DKG0Y5R7JTFM4Y75QQ71', 49, 185, 1, 2, 'submitted', '{"legal_name":"Placeholder Trading LLC","license_number":"CN-1234567","country":"AE"}', 'Moving from browsing to listing our own portfolio.', NULL, NULL, NULL, NULL, '2026-07-26 09:00:00'),
('01K2F2DKG0Q1FZXARMXP44KX5D', 50, 186, 1, 2, 'approved', '{"legal_name":"Placeholder Trading LLC","license_number":"CN-1234567","country":"AE"}', 'Moving from browsing to listing our own portfolio.', 2, '2026-08-06 09:00:00', 'Identity verified.', '2026-08-06 09:00:00', '2026-08-04 09:00:00'),
('01K2F2DKG0Q44NZNP4KN7BEMAS', 51, 187, 1, 2, 'cancelled', '{"legal_name":"Placeholder Trading LLC","license_number":"CN-1234567","country":"AE"}', 'Moving from browsing to listing our own portfolio.', NULL, NULL, NULL, NULL, '2026-05-29 09:00:00');


COMMIT;
SET autocommit = 1;
