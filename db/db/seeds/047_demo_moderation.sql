-- =============================================================================
-- Liv Finder — demo seed · reports, moderation queue, verification and audit trail
-- =============================================================================
-- Plain SQL. Edit it directly; there is no generator behind it.
-- Regenerate with:  python3 db/tools/build_demo_seed.py
--
-- The persistent moderation and audit store the audit found missing:
-- "there is no production admin API, persistent moderation, or audit
-- store yet", and the six report action modals mutated React state only.
-- 
-- Reports are spread across the full lifecycle so the queue has real work
-- in it, and every moderator action leaves a report_actions row.
-- =============================================================================

SET NAMES utf8mb4;
SET autocommit = 0;

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(1, '01K2F2DKG0JT660DHDNKQ9RDDS', 'RPT-5001', 'organization', 29, '{"captured_at":"2026-07-11 05:00:00","note":"Snapshot of the reported content at the time of the report."}', 4, 'Review appears to be written by a member of staff.', NULL, 'reporter@example.com', 'in_review', 'normal', 4, '2026-07-12 12:00:00', NULL, NULL, NULL, NULL, 6, '2026-07-18 05:00:00', '2026-07-11 05:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(1, 'created', 'new', NULL, 0, '2026-07-11 05:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(1, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-07-11 11:00:00'),
(1, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-07-12 05:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(2, '01K2F2DKG0X028HGE0MJAW08XC', 'RPT-5002', 'listing', 357, '{"captured_at":"2026-07-09 10:00:00","note":"Snapshot of the reported content at the time of the report."}', 8, 'This was sold weeks ago — I bought it myself.', NULL, 'reporter@example.com', 'resolved', 'normal', 4, '2026-07-10 16:00:00', 'account_warned', 'Verified with the agency and actioned.', 4, '2026-07-21 10:00:00', 6, '2026-07-16 10:00:00', '2026-07-09 10:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(2, 'created', 'new', NULL, 0, '2026-07-09 10:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(2, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-07-09 15:00:00'),
(2, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-07-10 10:00:00'),
(2, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-07-21 10:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(3, '01K2F2DKG0G54EAK0HKD2N1NRN', 'RPT-5003', 'listing', 221, '{"captured_at":"2026-07-17 03:00:00","note":"Snapshot of the reported content at the time of the report."}', 12, 'The agent is not licensed for this emirate.', 198, 'reporter@example.com', 'resolved', 'normal', 3, '2026-07-17 14:00:00', 'listing_unpublished', 'Verified with the agency and actioned.', 3, '2026-07-18 03:00:00', 6, '2026-07-24 03:00:00', '2026-07-17 03:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(3, 'created', 'new', NULL, 0, '2026-07-17 03:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(3, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-07-17 16:00:00'),
(3, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-07-18 03:00:00'),
(3, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-07-28 03:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(4, '01K2F2DKG08FQTVKQGWK8RHGZR', 'RPT-5004', 'listing', 30, '{"captured_at":"2026-06-15 04:00:00","note":"Snapshot of the reported content at the time of the report."}', 10, 'The price shown is far below what the agent quotes on the phone.', 249, 'reporter@example.com', 'duplicate', 'low', 3, '2026-06-16 05:00:00', NULL, NULL, NULL, NULL, 6, '2026-06-22 04:00:00', '2026-06-15 04:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(4, 'created', 'new', NULL, 0, '2026-06-15 04:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(4, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-06-15 08:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(5, '01K2F2DKG0NH97B8ZK6K0W45MK', 'RPT-5005', 'listing', 273, '{"captured_at":"2026-08-07 10:00:00","note":"Snapshot of the reported content at the time of the report."}', 11, 'The agent is not licensed for this emirate.', 320, 'reporter@example.com', 'resolved', 'low', 4, '2026-08-08 14:00:00', 'account_warned', 'Verified with the agency and actioned.', 4, '2026-08-19 10:00:00', 2, '2026-08-14 10:00:00', '2026-08-07 10:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(5, 'created', 'new', NULL, 0, '2026-08-07 10:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(5, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-08-08 08:00:00'),
(5, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-08-08 10:00:00'),
(5, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-08-09 10:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(6, '01K2F2DKG0QM6TKKRB3YQX9GRY', 'RPT-5006', 'listing', 337, '{"captured_at":"2026-04-30 11:00:00","note":"Snapshot of the reported content at the time of the report."}', 1, 'This was sold weeks ago — I bought it myself.', 273, 'reporter@example.com', 'dismissed', 'low', 3, '2026-05-01 22:00:00', 'no_action', 'Verified with the agency and actioned.', 3, '2026-05-11 11:00:00', 1, '2026-05-07 11:00:00', '2026-04-30 11:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(6, 'created', 'new', NULL, 0, '2026-04-30 11:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(6, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-02 02:00:00'),
(6, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-05-01 11:00:00'),
(6, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 3, '2026-05-01 11:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(7, '01K2F2DKG05P28WYBWP5N16W3J', 'RPT-5007', 'agent', 61, '{"captured_at":"2026-08-05 10:00:00","note":"Snapshot of the reported content at the time of the report."}', 4, 'Review appears to be written by a member of staff.', 231, 'reporter@example.com', 'resolved', 'normal', 4, '2026-08-07 01:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-08-09 10:00:00', 1, '2026-08-12 10:00:00', '2026-08-05 10:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(7, 'created', 'new', NULL, 0, '2026-08-05 10:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(7, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-08-06 00:00:00'),
(7, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-08-06 10:00:00'),
(7, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-08-06 10:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(8, '01K2F2DKG0MSSK0ZRPMZA8M41J', 'RPT-5008', 'listing', 352, '{"captured_at":"2026-05-10 06:00:00","note":"Snapshot of the reported content at the time of the report."}', 13, 'The photos are from a different unit in the same tower.', 209, 'reporter@example.com', 'resolved', 'low', 3, '2026-05-11 16:00:00', 'account_warned', 'Verified with the agency and actioned.', 3, '2026-05-13 06:00:00', 5, '2026-05-17 06:00:00', '2026-05-10 06:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(8, 'created', 'new', NULL, 0, '2026-05-10 06:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(8, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-11 18:00:00'),
(8, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-05-11 06:00:00'),
(8, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-05-22 06:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(9, '01K2F2DKG0M66PM6CDV35P2TX5', 'RPT-5009', 'listing', 278, '{"captured_at":"2026-04-24 15:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'The price shown is far below what the agent quotes on the phone.', 290, 'reporter@example.com', 'resolved', 'high', 3, '2026-04-26 04:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-05-03 15:00:00', 4, '2026-05-01 15:00:00', '2026-04-24 15:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(9, 'created', 'new', NULL, 0, '2026-04-24 15:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(9, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-04-26 04:00:00'),
(9, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-04-25 15:00:00'),
(9, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-05-05 15:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(10, '01K2F2DKG0FXA76JY8H8JBFGBH', 'RPT-5010', 'listing', 471, '{"captured_at":"2026-04-05 04:00:00","note":"Snapshot of the reported content at the time of the report."}', 10, 'This was sold weeks ago — I bought it myself.', 269, 'reporter@example.com', 'duplicate', 'high', 3, '2026-04-06 08:00:00', NULL, NULL, NULL, NULL, 5, '2026-04-12 04:00:00', '2026-04-05 04:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(10, 'created', 'new', NULL, 0, '2026-04-05 04:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(10, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-04-06 08:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(11, '01K2F2DKG08N2BQCM3WCS2GEP8', 'RPT-5011', 'listing', 364, '{"captured_at":"2026-06-10 00:00:00","note":"Snapshot of the reported content at the time of the report."}', 11, 'This was sold weeks ago — I bought it myself.', 273, 'reporter@example.com', 'duplicate', 'low', 3, '2026-06-10 05:00:00', NULL, NULL, NULL, NULL, 6, '2026-06-17 00:00:00', '2026-06-10 00:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(11, 'created', 'new', NULL, 0, '2026-06-10 00:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(11, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-06-11 14:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(12, '01K2F2DKG04DT2Q7FQG0KQXEH3', 'RPT-5012', 'organization', 35, '{"captured_at":"2026-05-06 01:00:00","note":"Snapshot of the reported content at the time of the report."}', 12, 'The price shown is far below what the agent quotes on the phone.', NULL, 'reporter@example.com', 'new', 'normal', NULL, NULL, NULL, NULL, NULL, NULL, 1, '2026-05-13 01:00:00', '2026-05-06 01:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(12, 'created', 'new', NULL, 0, '2026-05-06 01:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(13, '01K2F2DKG0690C1AAWD40YNF1Y', 'RPT-5013', 'listing', 312, '{"captured_at":"2026-06-19 15:00:00","note":"Snapshot of the reported content at the time of the report."}', 6, 'This was sold weeks ago — I bought it myself.', 275, 'reporter@example.com', 'new', 'urgent', NULL, NULL, NULL, NULL, NULL, NULL, 6, '2026-06-26 15:00:00', '2026-06-19 15:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(13, 'created', 'new', NULL, 0, '2026-06-19 15:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(14, '01K2F2DKG022V2MS2W3QSDR7RW', 'RPT-5014', 'review', 21, '{"captured_at":"2026-08-10 20:00:00","note":"Snapshot of the reported content at the time of the report."}', 4, 'Review appears to be written by a member of staff.', NULL, 'reporter@example.com', 'resolved', 'high', 3, '2026-08-12 02:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-08-22 20:00:00', 5, '2026-08-17 20:00:00', '2026-08-10 20:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(14, 'created', 'new', NULL, 0, '2026-08-10 20:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(14, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-08-11 08:00:00'),
(14, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-08-11 20:00:00'),
(14, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-08-14 20:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(15, '01K2F2DKG0A7732DGT162N8Q6Y', 'RPT-5015', 'agent', 78, '{"captured_at":"2026-08-01 04:00:00","note":"Snapshot of the reported content at the time of the report."}', 13, 'This was sold weeks ago — I bought it myself.', 210, 'reporter@example.com', 'resolved', 'normal', 4, '2026-08-01 15:00:00', 'content_removed', 'Verified with the agency and actioned.', 4, '2026-08-08 04:00:00', 6, '2026-08-08 04:00:00', '2026-08-01 04:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(15, 'created', 'new', NULL, 0, '2026-08-01 04:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(15, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-08-01 12:00:00'),
(15, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-08-02 04:00:00'),
(15, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-08-09 04:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(16, '01K2F2DKG0GG3DMPMBQ72502V5', 'RPT-5016', 'organization', 36, '{"captured_at":"2026-08-02 10:00:00","note":"Snapshot of the reported content at the time of the report."}', 5, 'This was sold weeks ago — I bought it myself.', 209, 'reporter@example.com', 'triaged', 'low', 4, '2026-08-03 23:00:00', NULL, NULL, NULL, NULL, 4, '2026-08-09 10:00:00', '2026-08-02 10:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(16, 'created', 'new', NULL, 0, '2026-08-02 10:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(16, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-08-02 12:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(17, '01K2F2DKG0XE0APMM6A35YYY1K', 'RPT-5017', 'listing', 275, '{"captured_at":"2026-04-08 09:00:00","note":"Snapshot of the reported content at the time of the report."}', 12, 'This was sold weeks ago — I bought it myself.', NULL, 'reporter@example.com', 'new', 'normal', NULL, NULL, NULL, NULL, NULL, NULL, 4, '2026-04-15 09:00:00', '2026-04-08 09:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(17, 'created', 'new', NULL, 0, '2026-04-08 09:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(18, '01K2F2DKG0SA9WKT38256JYQZ9', 'RPT-5018', 'listing', 31, '{"captured_at":"2026-07-13 10:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'The agent is not licensed for this emirate.', NULL, 'reporter@example.com', 'new', 'normal', NULL, NULL, NULL, NULL, NULL, NULL, 3, '2026-07-20 10:00:00', '2026-07-13 10:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(18, 'created', 'new', NULL, 0, '2026-07-13 10:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(19, '01K2F2DKG06KNR9QZ8JGM3PP5W', 'RPT-5019', 'listing', 26, '{"captured_at":"2026-06-26 21:00:00","note":"Snapshot of the reported content at the time of the report."}', 2, 'The photos are from a different unit in the same tower.', 224, 'reporter@example.com', 'resolved', 'high', 4, '2026-06-28 05:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-06-27 21:00:00', 5, '2026-07-03 21:00:00', '2026-06-26 21:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(19, 'created', 'new', NULL, 0, '2026-06-26 21:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(19, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-06-27 15:00:00'),
(19, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-06-27 21:00:00'),
(19, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-06-30 21:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(20, '01K2F2DKG0Y9A25J7AQSRXQNCD', 'RPT-5020', 'listing', 364, '{"captured_at":"2026-07-28 03:00:00","note":"Snapshot of the reported content at the time of the report."}', 1, 'Same listing appears three times from the same agency.', NULL, 'reporter@example.com', 'in_review', 'normal', 3, '2026-07-28 05:00:00', NULL, NULL, NULL, NULL, 1, '2026-08-04 03:00:00', '2026-07-28 03:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(20, 'created', 'new', NULL, 0, '2026-07-28 03:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(20, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-07-28 18:00:00'),
(20, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-07-29 03:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(21, '01K2F2DKG0QT45NPMP5AB2Z831', 'RPT-5021', 'review', 199, '{"captured_at":"2026-07-16 11:00:00","note":"Snapshot of the reported content at the time of the report."}', 10, 'Review appears to be written by a member of staff.', 265, 'reporter@example.com', 'new', 'high', NULL, NULL, NULL, NULL, NULL, NULL, 6, '2026-07-23 11:00:00', '2026-07-16 11:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(21, 'created', 'new', NULL, 0, '2026-07-16 11:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(22, '01K2F2DKG041XQWGDBGM6H95M3', 'RPT-5022', 'listing', 114, '{"captured_at":"2026-05-02 19:00:00","note":"Snapshot of the reported content at the time of the report."}', 4, 'Same listing appears three times from the same agency.', 320, 'reporter@example.com', 'resolved', 'high', 4, '2026-05-03 20:00:00', 'account_warned', 'Verified with the agency and actioned.', 4, '2026-05-12 19:00:00', 2, '2026-05-09 19:00:00', '2026-05-02 19:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(22, 'created', 'new', NULL, 0, '2026-05-02 19:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(22, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-05-03 07:00:00'),
(22, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-05-03 19:00:00'),
(22, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-05-04 19:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(23, '01K2F2DKG086P10D46HYYPXC41', 'RPT-5023', 'listing', 149, '{"captured_at":"2026-04-08 06:00:00","note":"Snapshot of the reported content at the time of the report."}', 6, 'The agent is not licensed for this emirate.', NULL, 'reporter@example.com', 'dismissed', 'normal', 4, '2026-04-09 06:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-04-17 06:00:00', 3, '2026-04-15 06:00:00', '2026-04-08 06:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(23, 'created', 'new', NULL, 0, '2026-04-08 06:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(23, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-09 18:00:00'),
(23, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-09 06:00:00'),
(23, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 4, '2026-04-20 06:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(24, '01K2F2DKG026DDPP5NH7B252TV', 'RPT-5024', 'listing', 514, '{"captured_at":"2026-05-20 12:00:00","note":"Snapshot of the reported content at the time of the report."}', 7, 'The photos are from a different unit in the same tower.', 321, 'reporter@example.com', 'in_review', 'normal', 3, '2026-05-22 00:00:00', NULL, NULL, NULL, NULL, 2, '2026-05-27 12:00:00', '2026-05-20 12:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(24, 'created', 'new', NULL, 0, '2026-05-20 12:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(24, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-21 10:00:00'),
(24, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-05-21 12:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(25, '01K2F2DKG0NP669GQ543CKGE1M', 'RPT-5025', 'listing', 166, '{"captured_at":"2026-04-19 13:00:00","note":"Snapshot of the reported content at the time of the report."}', 5, 'The price shown is far below what the agent quotes on the phone.', 237, 'reporter@example.com', 'resolved', 'high', 3, '2026-04-20 14:00:00', 'content_edited', 'Verified with the agency and actioned.', 3, '2026-04-25 13:00:00', 1, '2026-04-26 13:00:00', '2026-04-19 13:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(25, 'created', 'new', NULL, 0, '2026-04-19 13:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(25, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-04-21 05:00:00'),
(25, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-04-20 13:00:00'),
(25, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-04-28 13:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(26, '01K2F2DKG0TCRTZCKRCTPEQSSF', 'RPT-5026', 'listing', 249, '{"captured_at":"2026-07-16 06:00:00","note":"Snapshot of the reported content at the time of the report."}', 3, 'The photos are from a different unit in the same tower.', 287, 'reporter@example.com', 'in_review', 'normal', 3, '2026-07-17 19:00:00', NULL, NULL, NULL, NULL, 4, '2026-07-23 06:00:00', '2026-07-16 06:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(26, 'created', 'new', NULL, 0, '2026-07-16 06:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(26, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-07-17 09:00:00'),
(26, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-07-17 06:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(27, '01K2F2DKG0EETMHG77BDWYT85M', 'RPT-5027', 'listing', 48, '{"captured_at":"2026-06-12 06:00:00","note":"Snapshot of the reported content at the time of the report."}', 1, 'Review appears to be written by a member of staff.', 186, 'reporter@example.com', 'triaged', 'low', 4, '2026-06-12 19:00:00', NULL, NULL, NULL, NULL, 4, '2026-06-19 06:00:00', '2026-06-12 06:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(27, 'created', 'new', NULL, 0, '2026-06-12 06:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(27, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-06-13 13:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(28, '01K2F2DKG0D6XMGFF10B4TQWR1', 'RPT-5028', 'listing', 99, '{"captured_at":"2026-08-09 05:00:00","note":"Snapshot of the reported content at the time of the report."}', 13, 'This was sold weeks ago — I bought it myself.', 179, 'reporter@example.com', 'resolved', 'high', 3, '2026-08-10 09:00:00', 'listing_unpublished', 'Verified with the agency and actioned.', 4, '2026-08-14 05:00:00', 3, '2026-08-16 05:00:00', '2026-08-09 05:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(28, 'created', 'new', NULL, 0, '2026-08-09 05:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(28, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-08-10 09:00:00'),
(28, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-08-10 05:00:00'),
(28, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-08-11 05:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(29, '01K2F2DKG0CQ0AGWQ6ZW8Z950K', 'RPT-5029', 'listing', 433, '{"captured_at":"2026-08-09 06:00:00","note":"Snapshot of the reported content at the time of the report."}', 4, 'This was sold weeks ago — I bought it myself.', 305, 'reporter@example.com', 'duplicate', 'normal', 4, '2026-08-10 18:00:00', NULL, NULL, NULL, NULL, 3, '2026-08-16 06:00:00', '2026-08-09 06:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(29, 'created', 'new', NULL, 0, '2026-08-09 06:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(29, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-08-10 08:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(30, '01K2F2DKG02QB97BDGTB24VQSR', 'RPT-5030', 'listing', 503, '{"captured_at":"2026-08-07 13:00:00","note":"Snapshot of the reported content at the time of the report."}', 1, 'Same listing appears three times from the same agency.', 254, 'reporter@example.com', 'new', 'low', NULL, NULL, NULL, NULL, NULL, NULL, 4, '2026-08-14 13:00:00', '2026-08-07 13:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(30, 'created', 'new', NULL, 0, '2026-08-07 13:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(31, '01K2F2DKG00QFXXHM0125Z78J9', 'RPT-5031', 'agent', 78, '{"captured_at":"2026-06-29 07:00:00","note":"Snapshot of the reported content at the time of the report."}', 14, 'The photos are from a different unit in the same tower.', NULL, 'reporter@example.com', 'dismissed', 'high', 4, '2026-06-30 03:00:00', 'no_action', 'Verified with the agency and actioned.', 3, '2026-07-10 07:00:00', 5, '2026-07-06 07:00:00', '2026-06-29 07:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(31, 'created', 'new', NULL, 0, '2026-06-29 07:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(31, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-06-30 21:00:00'),
(31, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-06-30 07:00:00'),
(31, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 3, '2026-07-10 07:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(32, '01K2F2DKG0AGTBFQ9GX2W9R142', 'RPT-5032', 'organization', 10, '{"captured_at":"2026-06-28 23:00:00","note":"Snapshot of the reported content at the time of the report."}', 11, 'The photos are from a different unit in the same tower.', NULL, 'reporter@example.com', 'resolved', 'normal', 4, '2026-06-30 12:00:00', 'content_edited', 'Verified with the agency and actioned.', 3, '2026-07-09 23:00:00', 3, '2026-07-05 23:00:00', '2026-06-28 23:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(32, 'created', 'new', NULL, 0, '2026-06-28 23:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(32, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-06-29 18:00:00'),
(32, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-06-29 23:00:00'),
(32, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-07-07 23:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(33, '01K2F2DKG0JS8VQC44P475G40F', 'RPT-5033', 'listing', 328, '{"captured_at":"2026-04-16 12:00:00","note":"Snapshot of the reported content at the time of the report."}', 7, 'The agent is not licensed for this emirate.', 236, 'reporter@example.com', 'escalated', 'normal', 3, '2026-04-16 23:00:00', NULL, NULL, NULL, NULL, 5, '2026-04-23 12:00:00', '2026-04-16 12:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(33, 'created', 'new', NULL, 0, '2026-04-16 12:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(33, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-04-16 16:00:00'),
(33, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-04-17 12:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, note, actor_user_id, created_at) VALUES
(33, 'escalated', 'escalated', 'Possible unlicensed practice — referred to compliance.', 3, '2026-04-18 12:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(34, '01K2F2DKG03MJTSNN3K796AS34', 'RPT-5034', 'review', 134, '{"captured_at":"2026-04-03 21:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'The price shown is far below what the agent quotes on the phone.', 285, 'reporter@example.com', 'resolved', 'normal', 3, '2026-04-05 04:00:00', 'listing_unpublished', 'Verified with the agency and actioned.', 3, '2026-04-09 21:00:00', 6, '2026-04-10 21:00:00', '2026-04-03 21:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(34, 'created', 'new', NULL, 0, '2026-04-03 21:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(34, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-04-03 22:00:00'),
(34, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-04-04 21:00:00'),
(34, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-04-15 21:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(35, '01K2F2DKG009ZE0DPZ4B8XV5K1', 'RPT-5035', 'listing', 518, '{"captured_at":"2026-04-03 20:00:00","note":"Snapshot of the reported content at the time of the report."}', 2, 'Review appears to be written by a member of staff.', 196, 'reporter@example.com', 'escalated', 'normal', 3, '2026-04-04 07:00:00', NULL, NULL, NULL, NULL, 1, '2026-04-10 20:00:00', '2026-04-03 20:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(35, 'created', 'new', NULL, 0, '2026-04-03 20:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(35, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-04-05 01:00:00'),
(35, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-04-04 20:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, note, actor_user_id, created_at) VALUES
(35, 'escalated', 'escalated', 'Possible unlicensed practice — referred to compliance.', 3, '2026-04-05 20:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(36, '01K2F2DKG0H6K19EW027WX7D9C', 'RPT-5036', 'agent', 116, '{"captured_at":"2026-04-27 08:00:00","note":"Snapshot of the reported content at the time of the report."}', 10, 'The photos are from a different unit in the same tower.', 300, 'reporter@example.com', 'dismissed', 'normal', 4, '2026-04-28 06:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-04-28 08:00:00', 3, '2026-05-04 08:00:00', '2026-04-27 08:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(36, 'created', 'new', NULL, 0, '2026-04-27 08:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(36, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-28 09:00:00'),
(36, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-28 08:00:00'),
(36, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 4, '2026-04-28 08:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(37, '01K2F2DKG0VFGYG2XPYF85XWZS', 'RPT-5037', 'listing', 325, '{"captured_at":"2026-06-07 03:00:00","note":"Snapshot of the reported content at the time of the report."}', 10, 'Review appears to be written by a member of staff.', 325, 'reporter@example.com', 'new', 'normal', NULL, NULL, NULL, NULL, NULL, NULL, 3, '2026-06-14 03:00:00', '2026-06-07 03:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(37, 'created', 'new', NULL, 0, '2026-06-07 03:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(38, '01K2F2DKG09GX1YZB626YP8M46', 'RPT-5038', 'listing', 13, '{"captured_at":"2026-04-10 12:00:00","note":"Snapshot of the reported content at the time of the report."}', 10, 'The agent is not licensed for this emirate.', 271, 'reporter@example.com', 'new', 'low', NULL, NULL, NULL, NULL, NULL, NULL, 2, '2026-04-17 12:00:00', '2026-04-10 12:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(38, 'created', 'new', NULL, 0, '2026-04-10 12:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(39, '01K2F2DKG0JBKEB3ZGAAVQH7Z4', 'RPT-5039', 'listing', 150, '{"captured_at":"2026-08-10 23:00:00","note":"Snapshot of the reported content at the time of the report."}', 6, 'The agent is not licensed for this emirate.', 307, 'reporter@example.com', 'resolved', 'low', 4, '2026-08-12 02:00:00', 'account_suspended', 'Verified with the agency and actioned.', 3, '2026-08-13 23:00:00', 6, '2026-08-17 23:00:00', '2026-08-10 23:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(39, 'created', 'new', NULL, 0, '2026-08-10 23:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(39, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-08-12 06:00:00'),
(39, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-08-11 23:00:00'),
(39, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-08-21 23:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(40, '01K2F2DKG02W5F35TN06DB86H4', 'RPT-5040', 'listing', 517, '{"captured_at":"2026-06-02 16:00:00","note":"Snapshot of the reported content at the time of the report."}', 3, 'Same listing appears three times from the same agency.', 328, 'reporter@example.com', 'resolved', 'high', 4, '2026-06-04 07:00:00', 'content_edited', 'Verified with the agency and actioned.', 4, '2026-06-14 16:00:00', 5, '2026-06-09 16:00:00', '2026-06-02 16:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(40, 'created', 'new', NULL, 0, '2026-06-02 16:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(40, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-06-03 08:00:00'),
(40, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-06-03 16:00:00'),
(40, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-06-09 16:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(41, '01K2F2DKG0N638ZYW5XYXY41T2', 'RPT-5041', 'review', 96, '{"captured_at":"2026-04-30 15:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'The price shown is far below what the agent quotes on the phone.', NULL, 'reporter@example.com', 'resolved', 'low', 4, '2026-05-01 20:00:00', 'no_action', 'Verified with the agency and actioned.', 3, '2026-05-03 15:00:00', 3, '2026-05-07 15:00:00', '2026-04-30 15:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(41, 'created', 'new', NULL, 0, '2026-04-30 15:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(41, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-05-01 00:00:00'),
(41, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-05-01 15:00:00'),
(41, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-05-12 15:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(42, '01K2F2DKG0K9AGHBZH955S036B', 'RPT-5042', 'listing', 264, '{"captured_at":"2026-05-10 12:00:00","note":"Snapshot of the reported content at the time of the report."}', 5, 'This was sold weeks ago — I bought it myself.', 319, 'reporter@example.com', 'triaged', 'low', 3, '2026-05-12 02:00:00', NULL, NULL, NULL, NULL, 3, '2026-05-17 12:00:00', '2026-05-10 12:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(42, 'created', 'new', NULL, 0, '2026-05-10 12:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(42, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-11 05:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(43, '01K2F2DKG0ZR6CD2C7K0A57J8G', 'RPT-5043', 'listing', 338, '{"captured_at":"2026-07-03 13:00:00","note":"Snapshot of the reported content at the time of the report."}', 1, 'The photos are from a different unit in the same tower.', 251, 'reporter@example.com', 'in_review', 'normal', 4, '2026-07-04 16:00:00', NULL, NULL, NULL, NULL, 1, '2026-07-10 13:00:00', '2026-07-03 13:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(43, 'created', 'new', NULL, 0, '2026-07-03 13:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(43, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-07-05 02:00:00'),
(43, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-07-04 13:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(44, '01K2F2DKG0E4T7JWS4TK7X3304', 'RPT-5044', 'organization', 14, '{"captured_at":"2026-04-20 21:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'The photos are from a different unit in the same tower.', 200, 'reporter@example.com', 'resolved', 'normal', 4, '2026-04-21 07:00:00', 'content_removed', 'Verified with the agency and actioned.', 4, '2026-04-23 21:00:00', 6, '2026-04-27 21:00:00', '2026-04-20 21:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(44, 'created', 'new', NULL, 0, '2026-04-20 21:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(44, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-22 11:00:00'),
(44, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-21 21:00:00'),
(44, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-04-27 21:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(45, '01K2F2DKG0JYPG36P3209BGP4G', 'RPT-5045', 'listing', 239, '{"captured_at":"2026-04-06 17:00:00","note":"Snapshot of the reported content at the time of the report."}', 3, 'Review appears to be written by a member of staff.', 244, 'reporter@example.com', 'escalated', 'high', 4, '2026-04-07 10:00:00', NULL, NULL, NULL, NULL, 3, '2026-04-13 17:00:00', '2026-04-06 17:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(45, 'created', 'new', NULL, 0, '2026-04-06 17:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(45, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-07 23:00:00'),
(45, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-07 17:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, note, actor_user_id, created_at) VALUES
(45, 'escalated', 'escalated', 'Possible unlicensed practice — referred to compliance.', 4, '2026-04-08 17:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(46, '01K2F2DKG0SXGRMA42GRNEAMG4', 'RPT-5046', 'review', 152, '{"captured_at":"2026-05-06 01:00:00","note":"Snapshot of the reported content at the time of the report."}', 10, 'Review appears to be written by a member of staff.', 206, 'reporter@example.com', 'dismissed', 'low', 4, '2026-05-06 17:00:00', 'no_action', 'Verified with the agency and actioned.', 3, '2026-05-09 01:00:00', 4, '2026-05-13 01:00:00', '2026-05-06 01:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(46, 'created', 'new', NULL, 0, '2026-05-06 01:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(46, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-05-07 11:00:00'),
(46, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-05-07 01:00:00'),
(46, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 3, '2026-05-13 01:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(47, '01K2F2DKG0AW0TJ3HPD07RKJKG', 'RPT-5047', 'review', 98, '{"captured_at":"2026-07-10 22:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'The agent is not licensed for this emirate.', 268, 'reporter@example.com', 'duplicate', 'low', 4, '2026-07-11 21:00:00', NULL, NULL, NULL, NULL, 5, '2026-07-17 22:00:00', '2026-07-10 22:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(47, 'created', 'new', NULL, 0, '2026-07-10 22:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(47, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-07-12 14:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(48, '01K2F2DKG06T9R51HQ8HX661NT', 'RPT-5048', 'listing', 411, '{"captured_at":"2026-04-06 06:00:00","note":"Snapshot of the reported content at the time of the report."}', 8, 'This was sold weeks ago — I bought it myself.', 241, 'reporter@example.com', 'in_review', 'normal', 4, '2026-04-06 07:00:00', NULL, NULL, NULL, NULL, 5, '2026-04-13 06:00:00', '2026-04-06 06:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(48, 'created', 'new', NULL, 0, '2026-04-06 06:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(48, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-07 13:00:00'),
(48, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-07 06:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(49, '01K2F2DKG083CWGWR5VMYKVXCQ', 'RPT-5049', 'organization', 21, '{"captured_at":"2026-05-17 21:00:00","note":"Snapshot of the reported content at the time of the report."}', 4, 'The photos are from a different unit in the same tower.', 212, 'reporter@example.com', 'resolved', 'high', 3, '2026-05-18 23:00:00', 'no_action', 'Verified with the agency and actioned.', 3, '2026-05-26 21:00:00', 6, '2026-05-24 21:00:00', '2026-05-17 21:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(49, 'created', 'new', NULL, 0, '2026-05-17 21:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(49, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-18 23:00:00'),
(49, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-05-18 21:00:00'),
(49, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-05-26 21:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(50, '01K2F2DKG0FHFYMZ36R7WGDV15', 'RPT-5050', 'agent', 48, '{"captured_at":"2026-05-20 04:00:00","note":"Snapshot of the reported content at the time of the report."}', 13, 'The photos are from a different unit in the same tower.', 249, 'reporter@example.com', 'escalated', 'normal', 3, '2026-05-20 11:00:00', NULL, NULL, NULL, NULL, 4, '2026-05-27 04:00:00', '2026-05-20 04:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(50, 'created', 'new', NULL, 0, '2026-05-20 04:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(50, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-20 23:00:00'),
(50, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-05-21 04:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, note, actor_user_id, created_at) VALUES
(50, 'escalated', 'escalated', 'Possible unlicensed practice — referred to compliance.', 3, '2026-05-22 04:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(51, '01K2F2DKG0HFDAWH57FHV5NJJR', 'RPT-5051', 'agent', 34, '{"captured_at":"2026-03-19 14:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'The agent is not licensed for this emirate.', 251, 'reporter@example.com', 'resolved', 'normal', 4, '2026-03-20 03:00:00', 'content_removed', 'Verified with the agency and actioned.', 4, '2026-03-31 14:00:00', 6, '2026-03-26 14:00:00', '2026-03-19 14:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(51, 'created', 'new', NULL, 0, '2026-03-19 14:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(51, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-03-20 02:00:00'),
(51, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-03-20 14:00:00'),
(51, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-03-29 14:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(52, '01K2F2DKG0JEWHJ3HDJAYS5J7N', 'RPT-5052', 'listing', 271, '{"captured_at":"2026-06-22 08:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'This was sold weeks ago — I bought it myself.', 187, 'reporter@example.com', 'in_review', 'normal', 4, '2026-06-23 19:00:00', NULL, NULL, NULL, NULL, 1, '2026-06-29 08:00:00', '2026-06-22 08:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(52, 'created', 'new', NULL, 0, '2026-06-22 08:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(52, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-06-22 12:00:00'),
(52, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-06-23 08:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(53, '01K2F2DKG038SD13JBDTREDCZN', 'RPT-5053', 'organization', 27, '{"captured_at":"2026-05-21 20:00:00","note":"Snapshot of the reported content at the time of the report."}', 3, 'The agent is not licensed for this emirate.', 293, 'reporter@example.com', 'in_review', 'normal', 3, '2026-05-22 11:00:00', NULL, NULL, NULL, NULL, 6, '2026-05-28 20:00:00', '2026-05-21 20:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(53, 'created', 'new', NULL, 0, '2026-05-21 20:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(53, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-23 03:00:00'),
(53, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-05-22 20:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(54, '01K2F2DKG08AH02CRG3ZRRVY1P', 'RPT-5054', 'listing', 273, '{"captured_at":"2026-04-05 19:00:00","note":"Snapshot of the reported content at the time of the report."}', 6, 'The photos are from a different unit in the same tower.', NULL, 'reporter@example.com', 'escalated', 'high', 4, '2026-04-07 11:00:00', NULL, NULL, NULL, NULL, 5, '2026-04-12 19:00:00', '2026-04-05 19:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(54, 'created', 'new', NULL, 0, '2026-04-05 19:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(54, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-07 09:00:00'),
(54, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-06 19:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, note, actor_user_id, created_at) VALUES
(54, 'escalated', 'escalated', 'Possible unlicensed practice — referred to compliance.', 4, '2026-04-07 19:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(55, '01K2F2DKG04KK6XRDCYAGR4J26', 'RPT-5055', 'listing', 96, '{"captured_at":"2026-06-27 14:00:00","note":"Snapshot of the reported content at the time of the report."}', 14, 'Same listing appears three times from the same agency.', 301, 'reporter@example.com', 'resolved', 'normal', 3, '2026-06-28 12:00:00', 'no_action', 'Verified with the agency and actioned.', 3, '2026-07-03 14:00:00', 3, '2026-07-04 14:00:00', '2026-06-27 14:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(55, 'created', 'new', NULL, 0, '2026-06-27 14:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(55, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-06-28 09:00:00'),
(55, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-06-28 14:00:00'),
(55, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-07-04 14:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(56, '01K2F2DKG0K2VZ6RMN56VK61W3', 'RPT-5056', 'listing', 206, '{"captured_at":"2026-06-16 21:00:00","note":"Snapshot of the reported content at the time of the report."}', 5, 'The agent is not licensed for this emirate.', 198, 'reporter@example.com', 'resolved', 'normal', 4, '2026-06-17 14:00:00', 'content_edited', 'Verified with the agency and actioned.', 3, '2026-06-23 21:00:00', 3, '2026-06-23 21:00:00', '2026-06-16 21:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(56, 'created', 'new', NULL, 0, '2026-06-16 21:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(56, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-06-17 01:00:00'),
(56, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-06-17 21:00:00'),
(56, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-06-17 21:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(57, '01K2F2DKG0S3WRJ772Y0V6XP14', 'RPT-5057', 'listing', 18, '{"captured_at":"2026-04-30 13:00:00","note":"Snapshot of the reported content at the time of the report."}', 3, 'This was sold weeks ago — I bought it myself.', NULL, 'reporter@example.com', 'dismissed', 'normal', 4, '2026-05-01 22:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-05-08 13:00:00', 5, '2026-05-07 13:00:00', '2026-04-30 13:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(57, 'created', 'new', NULL, 0, '2026-04-30 13:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(57, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-05-01 07:00:00'),
(57, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-05-01 13:00:00'),
(57, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 4, '2026-05-01 13:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(58, '01K2F2DKG0VR6CP610Z1C6ZSW6', 'RPT-5058', 'listing', 11, '{"captured_at":"2026-03-31 12:00:00","note":"Snapshot of the reported content at the time of the report."}', 11, 'This was sold weeks ago — I bought it myself.', 232, 'reporter@example.com', 'triaged', 'normal', 3, '2026-04-01 03:00:00', NULL, NULL, NULL, NULL, 4, '2026-04-07 12:00:00', '2026-03-31 12:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(58, 'created', 'new', NULL, 0, '2026-03-31 12:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(58, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-04-01 18:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(59, '01K2F2DKG0ZMCQMH02M9NZ9AFT', 'RPT-5059', 'review', 206, '{"captured_at":"2026-05-19 15:00:00","note":"Snapshot of the reported content at the time of the report."}', 3, 'The agent is not licensed for this emirate.', 288, 'reporter@example.com', 'dismissed', 'normal', 4, '2026-05-20 01:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-05-26 15:00:00', 4, '2026-05-26 15:00:00', '2026-05-19 15:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(59, 'created', 'new', NULL, 0, '2026-05-19 15:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(59, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-05-21 00:00:00'),
(59, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-05-20 15:00:00'),
(59, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 4, '2026-05-24 15:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(60, '01K2F2DKG0S56PDE3GYGRW3AZ1', 'RPT-5060', 'listing', 402, '{"captured_at":"2026-06-20 09:00:00","note":"Snapshot of the reported content at the time of the report."}', 14, 'This was sold weeks ago — I bought it myself.', 243, 'reporter@example.com', 'resolved', 'normal', 3, '2026-06-21 22:00:00', 'account_suspended', 'Verified with the agency and actioned.', 4, '2026-06-27 09:00:00', 5, '2026-06-27 09:00:00', '2026-06-20 09:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(60, 'created', 'new', NULL, 0, '2026-06-20 09:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(60, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-06-21 14:00:00'),
(60, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-06-21 09:00:00'),
(60, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-06-21 09:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(61, '01K2F2DKG0MY1QD1V627CYMPCR', 'RPT-5061', 'listing', 248, '{"captured_at":"2026-08-04 21:00:00","note":"Snapshot of the reported content at the time of the report."}', 12, 'Review appears to be written by a member of staff.', 315, 'reporter@example.com', 'new', 'normal', NULL, NULL, NULL, NULL, NULL, NULL, 4, '2026-08-11 21:00:00', '2026-08-04 21:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(61, 'created', 'new', NULL, 0, '2026-08-04 21:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(62, '01K2F2DKG0N7V8EXAM80KJ9XFQ', 'RPT-5062', 'agent', 9, '{"captured_at":"2026-05-16 02:00:00","note":"Snapshot of the reported content at the time of the report."}', 6, 'This was sold weeks ago — I bought it myself.', NULL, 'reporter@example.com', 'dismissed', 'low', 4, '2026-05-17 12:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-05-17 02:00:00', 1, '2026-05-23 02:00:00', '2026-05-16 02:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(62, 'created', 'new', NULL, 0, '2026-05-16 02:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(62, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-05-17 16:00:00'),
(62, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-05-17 02:00:00'),
(62, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 4, '2026-05-20 02:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(63, '01K2F2DKG0M1DY7ZK8RSNHY1AD', 'RPT-5063', 'listing', 141, '{"captured_at":"2026-04-14 16:00:00","note":"Snapshot of the reported content at the time of the report."}', 1, 'The photos are from a different unit in the same tower.', 251, 'reporter@example.com', 'resolved', 'normal', 4, '2026-04-15 05:00:00', 'listing_unpublished', 'Verified with the agency and actioned.', 3, '2026-04-25 16:00:00', 4, '2026-04-21 16:00:00', '2026-04-14 16:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(63, 'created', 'new', NULL, 0, '2026-04-14 16:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(63, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-16 07:00:00'),
(63, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-15 16:00:00'),
(63, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-04-17 16:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(64, '01K2F2DKG0HDQNQ4KNJ70A72T8', 'RPT-5064', 'listing', 251, '{"captured_at":"2026-08-02 16:00:00","note":"Snapshot of the reported content at the time of the report."}', 11, 'The agent is not licensed for this emirate.', 204, 'reporter@example.com', 'new', 'normal', NULL, NULL, NULL, NULL, NULL, NULL, 5, '2026-08-09 16:00:00', '2026-08-02 16:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(64, 'created', 'new', NULL, 0, '2026-08-02 16:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(65, '01K2F2DKG0X2C3ZM3F9B43Y7RQ', 'RPT-5065', 'listing', 190, '{"captured_at":"2026-08-09 16:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'Same listing appears three times from the same agency.', 248, 'reporter@example.com', 'duplicate', 'normal', 3, '2026-08-11 05:00:00', NULL, NULL, NULL, NULL, 3, '2026-08-16 16:00:00', '2026-08-09 16:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(65, 'created', 'new', NULL, 0, '2026-08-09 16:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(65, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-08-11 08:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(66, '01K2F2DKG0D4PMN3QM2NM5TYM1', 'RPT-5066', 'agent', 66, '{"captured_at":"2026-05-24 02:00:00","note":"Snapshot of the reported content at the time of the report."}', 5, 'Same listing appears three times from the same agency.', 276, 'reporter@example.com', 'resolved', 'low', 4, '2026-05-25 07:00:00', 'content_edited', 'Verified with the agency and actioned.', 3, '2026-05-28 02:00:00', 6, '2026-05-31 02:00:00', '2026-05-24 02:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(66, 'created', 'new', NULL, 0, '2026-05-24 02:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(66, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-05-25 01:00:00'),
(66, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-05-25 02:00:00'),
(66, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-05-28 02:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(67, '01K2F2DKG09W6TYXNH4F2Z7SZJ', 'RPT-5067', 'agent', 1, '{"captured_at":"2026-03-28 18:00:00","note":"Snapshot of the reported content at the time of the report."}', 4, 'Same listing appears three times from the same agency.', 309, 'reporter@example.com', 'new', 'normal', NULL, NULL, NULL, NULL, NULL, NULL, 6, '2026-04-04 18:00:00', '2026-03-28 18:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(67, 'created', 'new', NULL, 0, '2026-03-28 18:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(68, '01K2F2DKG0CWQQWZNMKA196470', 'RPT-5068', 'listing', 12, '{"captured_at":"2026-04-24 06:00:00","note":"Snapshot of the reported content at the time of the report."}', 13, 'This was sold weeks ago — I bought it myself.', 295, 'reporter@example.com', 'resolved', 'normal', 4, '2026-04-25 07:00:00', 'listing_unpublished', 'Verified with the agency and actioned.', 4, '2026-04-27 06:00:00', 6, '2026-05-01 06:00:00', '2026-04-24 06:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(68, 'created', 'new', NULL, 0, '2026-04-24 06:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(68, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-24 07:00:00'),
(68, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-25 06:00:00'),
(68, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-05-01 06:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(69, '01K2F2DKG01210G52TSR60KZXA', 'RPT-5069', 'listing', 260, '{"captured_at":"2026-07-27 12:00:00","note":"Snapshot of the reported content at the time of the report."}', 4, 'Review appears to be written by a member of staff.', NULL, 'reporter@example.com', 'in_review', 'urgent', 3, '2026-07-27 18:00:00', NULL, NULL, NULL, NULL, 6, '2026-08-03 12:00:00', '2026-07-27 12:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(69, 'created', 'new', NULL, 0, '2026-07-27 12:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(69, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-07-28 19:00:00'),
(69, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-07-28 12:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(70, '01K2F2DKG03WHHGSDETSG8SD2P', 'RPT-5070', 'listing', 416, '{"captured_at":"2026-04-25 02:00:00","note":"Snapshot of the reported content at the time of the report."}', 5, 'This was sold weeks ago — I bought it myself.', 307, 'reporter@example.com', 'new', 'high', NULL, NULL, NULL, NULL, NULL, NULL, 1, '2026-05-02 02:00:00', '2026-04-25 02:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(70, 'created', 'new', NULL, 0, '2026-04-25 02:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(71, '01K2F2DKG0V59Z963A25ZDNJ1P', 'RPT-5071', 'listing', 508, '{"captured_at":"2026-07-26 18:00:00","note":"Snapshot of the reported content at the time of the report."}', 5, 'Review appears to be written by a member of staff.', 257, 'reporter@example.com', 'new', 'normal', NULL, NULL, NULL, NULL, NULL, NULL, 1, '2026-08-02 18:00:00', '2026-07-26 18:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(71, 'created', 'new', NULL, 0, '2026-07-26 18:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(72, '01K2F2DKG0CZHNDWMR4CTKVQ14', 'RPT-5072', 'agent', 79, '{"captured_at":"2026-05-25 05:00:00","note":"Snapshot of the reported content at the time of the report."}', 14, 'This was sold weeks ago — I bought it myself.', NULL, 'reporter@example.com', 'dismissed', 'normal', 3, '2026-05-26 18:00:00', 'no_action', 'Verified with the agency and actioned.', 3, '2026-05-27 05:00:00', 1, '2026-06-01 05:00:00', '2026-05-25 05:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(72, 'created', 'new', NULL, 0, '2026-05-25 05:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(72, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-25 11:00:00'),
(72, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-05-26 05:00:00'),
(72, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 3, '2026-06-02 05:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(73, '01K2F2DKG0KW2X48K7R5Y37ZBF', 'RPT-5073', 'listing', 388, '{"captured_at":"2026-07-02 01:00:00","note":"Snapshot of the reported content at the time of the report."}', 8, 'Review appears to be written by a member of staff.', 256, 'reporter@example.com', 'resolved', 'normal', 4, '2026-07-02 12:00:00', 'content_removed', 'Verified with the agency and actioned.', 4, '2026-07-14 01:00:00', 1, '2026-07-09 01:00:00', '2026-07-02 01:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(73, 'created', 'new', NULL, 0, '2026-07-02 01:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(73, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-07-03 14:00:00'),
(73, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-07-03 01:00:00'),
(73, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-07-12 01:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(74, '01K2F2DKG097G1A6S19XBPDZRD', 'RPT-5074', 'listing', 319, '{"captured_at":"2026-05-03 02:00:00","note":"Snapshot of the reported content at the time of the report."}', 10, 'Same listing appears three times from the same agency.', NULL, 'reporter@example.com', 'resolved', 'normal', 4, '2026-05-04 04:00:00', 'no_action', 'Verified with the agency and actioned.', 3, '2026-05-06 02:00:00', 2, '2026-05-10 02:00:00', '2026-05-03 02:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(74, 'created', 'new', NULL, 0, '2026-05-03 02:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(74, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-05-04 06:00:00'),
(74, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-05-04 02:00:00'),
(74, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-05-14 02:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(75, '01K2F2DKG0SM41PBTCHNFFYK85', 'RPT-5075', 'review', 155, '{"captured_at":"2026-05-28 09:00:00","note":"Snapshot of the reported content at the time of the report."}', 13, 'The photos are from a different unit in the same tower.', 303, 'reporter@example.com', 'dismissed', 'normal', 3, '2026-05-28 22:00:00', 'no_action', 'Verified with the agency and actioned.', 3, '2026-06-07 09:00:00', 2, '2026-06-04 09:00:00', '2026-05-28 09:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(75, 'created', 'new', NULL, 0, '2026-05-28 09:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(75, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-29 03:00:00'),
(75, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-05-29 09:00:00'),
(75, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 3, '2026-06-01 09:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(76, '01K2F2DKG07KFSND72RARF5EAV', 'RPT-5076', 'listing', 381, '{"captured_at":"2026-07-08 03:00:00","note":"Snapshot of the reported content at the time of the report."}', 13, 'Review appears to be written by a member of staff.', 253, 'reporter@example.com', 'in_review', 'low', 4, '2026-07-08 08:00:00', NULL, NULL, NULL, NULL, 3, '2026-07-15 03:00:00', '2026-07-08 03:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(76, 'created', 'new', NULL, 0, '2026-07-08 03:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(76, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-07-08 07:00:00'),
(76, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-07-09 03:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(77, '01K2F2DKG0CFRC8YS5KFDF5W2J', 'RPT-5077', 'listing', 376, '{"captured_at":"2026-06-13 06:00:00","note":"Snapshot of the reported content at the time of the report."}', 1, 'The photos are from a different unit in the same tower.', 321, 'reporter@example.com', 'dismissed', 'low', 3, '2026-06-14 04:00:00', 'no_action', 'Verified with the agency and actioned.', 4, '2026-06-16 06:00:00', 2, '2026-06-20 06:00:00', '2026-06-13 06:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(77, 'created', 'new', NULL, 0, '2026-06-13 06:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(77, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-06-13 14:00:00'),
(77, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-06-14 06:00:00'),
(77, 'dismissed', 'in_review', 'dismissed', 'No breach of guidelines found.', 4, '2026-06-14 06:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(78, '01K2F2DKG0QTYB97SNSHGTGPJ4', 'RPT-5078', 'listing', 92, '{"captured_at":"2026-03-26 12:00:00","note":"Snapshot of the reported content at the time of the report."}', 8, 'Same listing appears three times from the same agency.', 247, 'reporter@example.com', 'triaged', 'high', 3, '2026-03-27 21:00:00', NULL, NULL, NULL, NULL, 4, '2026-04-02 12:00:00', '2026-03-26 12:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(78, 'created', 'new', NULL, 0, '2026-03-26 12:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(78, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-03-27 06:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(79, '01K2F2DKG0TGQ9CG272P5VQ5J5', 'RPT-5079', 'agent', 10, '{"captured_at":"2026-05-20 02:00:00","note":"Snapshot of the reported content at the time of the report."}', 6, 'Same listing appears three times from the same agency.', 295, 'reporter@example.com', 'resolved', 'normal', 4, '2026-05-21 02:00:00', 'content_removed', 'Verified with the agency and actioned.', 3, '2026-05-28 02:00:00', 2, '2026-05-27 02:00:00', '2026-05-20 02:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(79, 'created', 'new', NULL, 0, '2026-05-20 02:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(79, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-05-21 00:00:00'),
(79, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-05-21 02:00:00'),
(79, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 3, '2026-05-29 02:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(80, '01K2F2DKG0JJPZA97CFPCV4T5P', 'RPT-5080', 'listing', 404, '{"captured_at":"2026-04-14 21:00:00","note":"Snapshot of the reported content at the time of the report."}', 3, 'Review appears to be written by a member of staff.', 283, 'reporter@example.com', 'resolved', 'urgent', 4, '2026-04-16 00:00:00', 'account_suspended', 'Verified with the agency and actioned.', 4, '2026-04-17 21:00:00', 5, '2026-04-21 21:00:00', '2026-04-14 21:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(80, 'created', 'new', NULL, 0, '2026-04-14 21:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(80, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-15 18:00:00'),
(80, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-15 21:00:00'),
(80, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-04-22 21:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(81, '01K2F2DKG0BF094HYF0DCQ1V7G', 'RPT-5081', 'listing', 456, '{"captured_at":"2026-04-09 03:00:00","note":"Snapshot of the reported content at the time of the report."}', 9, 'The price shown is far below what the agent quotes on the phone.', NULL, 'reporter@example.com', 'resolved', 'normal', 4, '2026-04-10 09:00:00', 'account_warned', 'Verified with the agency and actioned.', 4, '2026-04-12 03:00:00', 3, '2026-04-16 03:00:00', '2026-04-09 03:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(81, 'created', 'new', NULL, 0, '2026-04-09 03:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(81, 'assigned', NULL, '4', 'Picked up from the queue.', 4, '2026-04-10 08:00:00'),
(81, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 4, '2026-04-10 03:00:00'),
(81, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-04-10 03:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(82, '01K2F2DKG0RRV7Q8ZH49RFXBE6', 'RPT-5082', 'agent', 83, '{"captured_at":"2026-06-27 16:00:00","note":"Snapshot of the reported content at the time of the report."}', 8, 'Review appears to be written by a member of staff.', NULL, 'reporter@example.com', 'in_review', 'high', 3, '2026-06-28 11:00:00', NULL, NULL, NULL, NULL, 3, '2026-07-04 16:00:00', '2026-06-27 16:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(82, 'created', 'new', NULL, 0, '2026-06-27 16:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(82, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-06-28 20:00:00'),
(82, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-06-28 16:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(83, '01K2F2DKG0GDQ8VHCWQ6K9BHQQ', 'RPT-5083', 'organization', 4, '{"captured_at":"2026-07-31 06:00:00","note":"Snapshot of the reported content at the time of the report."}', 13, 'Same listing appears three times from the same agency.', 203, 'reporter@example.com', 'resolved', 'normal', 3, '2026-08-01 21:00:00', 'account_warned', 'Verified with the agency and actioned.', 4, '2026-08-07 06:00:00', 6, '2026-08-07 06:00:00', '2026-07-31 06:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(83, 'created', 'new', NULL, 0, '2026-07-31 06:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(83, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-08-01 02:00:00'),
(83, 'status_changed', 'triaged', 'in_review', 'Contacted the listing agency for clarification.', 3, '2026-08-01 06:00:00'),
(83, 'resolved', 'in_review', 'resolved', 'Listing unpublished and the agency notified.', 4, '2026-08-11 06:00:00');

INSERT INTO reports (id, public_id, reference, subject_type, subject_id, subject_snapshot, reason_id, details, reporter_user_id, reporter_email, status, priority, assigned_to_user_id, assigned_at, resolution, resolution_note, resolved_by_user_id, resolved_at, report_count, due_at, created_at) VALUES
(84, '01K2F2DKG0DF7JPZD19KQG9SD5', 'RPT-5084', 'listing', 329, '{"captured_at":"2026-04-30 21:00:00","note":"Snapshot of the reported content at the time of the report."}', 7, 'Same listing appears three times from the same agency.', 217, 'reporter@example.com', 'triaged', 'normal', 3, '2026-05-01 12:00:00', NULL, NULL, NULL, NULL, 2, '2026-05-07 21:00:00', '2026-04-30 21:00:00');

INSERT INTO report_actions (report_id, action_type, to_value, actor_user_id, is_internal, created_at) VALUES
(84, 'created', 'new', NULL, 0, '2026-04-30 21:00:00');

INSERT INTO report_actions (report_id, action_type, from_value, to_value, note, actor_user_id, created_at) VALUES
(84, 'assigned', NULL, '3', 'Picked up from the queue.', 3, '2026-05-02 09:00:00');

INSERT INTO moderation_queue (subject_type, subject_id, queue_reason, risk_score, signals, status, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_note, created_at) VALUES
('listing', 419, 'new_submission', 8, '{"detector":"new_submission","confidence":0.08}', 'in_review', 4, NULL, NULL, NULL, '2026-08-17 09:00:00'),
('listing', 341, 'duplicate_suspected', 76, '{"detector":"duplicate_suspected","confidence":0.76}', 'approved', 3, 3, '2026-08-14 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-09 09:00:00'),
('listing', 369, 'flagged_automatic', 66, '{"detector":"flagged_automatic","confidence":0.66}', 'approved', 4, 3, '2026-08-02 09:00:00', 'Checked against the guidelines; no action needed.', '2026-08-07 09:00:00'),
('listing', 94, 'banned_terms', 80, '{"detector":"banned_terms","confidence":0.8}', 'approved', 3, 3, '2026-08-12 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-24 09:00:00'),
('listing', 313, 'price_anomaly', 80, '{"detector":"price_anomaly","confidence":0.8}', 'approved', NULL, 3, '2026-08-08 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-20 09:00:00'),
('listing', 190, 'image_check', 51, '{"detector":"image_check","confidence":0.51}', 'pending', 3, NULL, NULL, NULL, '2026-07-29 09:00:00'),
('listing', 185, 'flagged_automatic', 88, '{"detector":"flagged_automatic","confidence":0.88}', 'pending', NULL, NULL, NULL, NULL, '2026-07-30 09:00:00'),
('listing', 324, 'duplicate_suspected', 69, '{"detector":"duplicate_suspected","confidence":0.69}', 'skipped', NULL, NULL, NULL, NULL, '2026-08-06 09:00:00'),
('listing', 393, 'price_anomaly', 61, '{"detector":"price_anomaly","confidence":0.61}', 'approved', NULL, 3, '2026-07-28 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-24 09:00:00'),
('listing', 153, 'duplicate_suspected', 63, '{"detector":"duplicate_suspected","confidence":0.63}', 'in_review', 4, NULL, NULL, NULL, '2026-07-22 09:00:00'),
('listing', 376, 'banned_terms', 98, '{"detector":"banned_terms","confidence":0.98}', 'rejected', NULL, 3, '2026-08-06 09:00:00', 'Photographs reused from another listing.', '2026-07-15 09:00:00'),
('listing', 448, 'price_anomaly', 80, '{"detector":"price_anomaly","confidence":0.8}', 'pending', 3, NULL, NULL, NULL, '2026-07-20 09:00:00'),
('listing', 393, 'flagged_automatic', 58, '{"detector":"flagged_automatic","confidence":0.58}', 'pending', 4, NULL, NULL, NULL, '2026-08-05 09:00:00'),
('listing', 112, 'new_submission', 25, '{"detector":"new_submission","confidence":0.25}', 'rejected', 4, 3, '2026-08-14 09:00:00', 'Photographs reused from another listing.', '2026-07-31 09:00:00'),
('listing', 170, 'duplicate_suspected', 76, '{"detector":"duplicate_suspected","confidence":0.76}', 'approved', NULL, 3, '2026-08-13 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-27 09:00:00'),
('listing', 270, 'price_anomaly', 54, '{"detector":"price_anomaly","confidence":0.54}', 'pending', NULL, NULL, NULL, NULL, '2026-07-31 09:00:00'),
('listing', 31, 'random_audit', 15, '{"detector":"random_audit","confidence":0.15}', 'approved', NULL, 3, '2026-08-09 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-19 09:00:00'),
('listing', 232, 'price_anomaly', 79, '{"detector":"price_anomaly","confidence":0.79}', 'skipped', 3, NULL, NULL, NULL, '2026-07-23 09:00:00'),
('listing', 461, 'flagged_automatic', 91, '{"detector":"flagged_automatic","confidence":0.91}', 'approved', NULL, 3, '2026-08-15 09:00:00', 'Checked against the guidelines; no action needed.', '2026-08-05 09:00:00'),
('listing', 520, 'flagged_automatic', 86, '{"detector":"flagged_automatic","confidence":0.86}', 'in_review', 4, NULL, NULL, NULL, '2026-08-14 09:00:00'),
('listing', 121, 'new_submission', 9, '{"detector":"new_submission","confidence":0.09}', 'in_review', NULL, NULL, NULL, NULL, '2026-07-22 09:00:00'),
('listing', 412, 'random_audit', 6, '{"detector":"random_audit","confidence":0.06}', 'approved', 4, 3, '2026-08-17 09:00:00', 'Checked against the guidelines; no action needed.', '2026-08-05 09:00:00'),
('listing', 152, 'price_anomaly', 56, '{"detector":"price_anomaly","confidence":0.56}', 'approved', 4, 3, '2026-07-31 09:00:00', 'Checked against the guidelines; no action needed.', '2026-08-11 09:00:00'),
('listing', 487, 'duplicate_suspected', 81, '{"detector":"duplicate_suspected","confidence":0.81}', 'approved', 3, 3, '2026-08-06 09:00:00', 'Checked against the guidelines; no action needed.', '2026-08-04 09:00:00'),
('listing', 377, 'duplicate_suspected', 77, '{"detector":"duplicate_suspected","confidence":0.77}', 'approved', 3, 3, '2026-08-17 09:00:00', 'Checked against the guidelines; no action needed.', '2026-08-06 09:00:00'),
('listing', 268, 'price_anomaly', 57, '{"detector":"price_anomaly","confidence":0.57}', 'pending', NULL, NULL, NULL, NULL, '2026-08-09 09:00:00'),
('listing', 248, 'new_submission', 7, '{"detector":"new_submission","confidence":0.07}', 'pending', 4, NULL, NULL, NULL, '2026-08-05 09:00:00'),
('listing', 336, 'flagged_automatic', 65, '{"detector":"flagged_automatic","confidence":0.65}', 'pending', NULL, NULL, NULL, NULL, '2026-07-24 09:00:00'),
('listing', 197, 'edited', 11, '{"detector":"edited","confidence":0.11}', 'in_review', NULL, NULL, NULL, NULL, '2026-07-10 09:00:00'),
('listing', 49, 'random_audit', 7, '{"detector":"random_audit","confidence":0.07}', 'skipped', NULL, NULL, NULL, NULL, '2026-08-10 09:00:00'),
('listing', 1, 'new_submission', 13, '{"detector":"new_submission","confidence":0.13}', 'approved', 3, 3, '2026-07-29 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-17 09:00:00'),
('listing', 114, 'price_anomaly', 71, '{"detector":"price_anomaly","confidence":0.71}', 'approved', 3, 3, '2026-08-14 09:00:00', 'Checked against the guidelines; no action needed.', '2026-08-15 09:00:00'),
('listing', 392, 'image_check', 51, '{"detector":"image_check","confidence":0.51}', 'approved', 3, 3, '2026-08-09 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-11 09:00:00'),
('listing', 231, 'image_check', 30, '{"detector":"image_check","confidence":0.3}', 'pending', 3, NULL, NULL, NULL, '2026-07-11 09:00:00'),
('listing', 236, 'random_audit', 10, '{"detector":"random_audit","confidence":0.1}', 'in_review', NULL, NULL, NULL, NULL, '2026-07-30 09:00:00'),
('listing', 236, 'random_audit', 14, '{"detector":"random_audit","confidence":0.14}', 'pending', 3, NULL, NULL, NULL, '2026-07-10 09:00:00'),
('listing', 247, 'new_submission', 22, '{"detector":"new_submission","confidence":0.22}', 'pending', NULL, NULL, NULL, NULL, '2026-07-14 09:00:00'),
('listing', 333, 'flagged_automatic', 66, '{"detector":"flagged_automatic","confidence":0.66}', 'pending', 3, NULL, NULL, NULL, '2026-07-10 09:00:00'),
('listing', 32, 'new_submission', 25, '{"detector":"new_submission","confidence":0.25}', 'pending', 3, NULL, NULL, NULL, '2026-08-11 09:00:00'),
('listing', 278, 'price_anomaly', 41, '{"detector":"price_anomaly","confidence":0.41}', 'approved', 4, 3, '2026-08-01 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-16 09:00:00'),
('listing', 88, 'flagged_automatic', 68, '{"detector":"flagged_automatic","confidence":0.68}', 'in_review', 3, NULL, NULL, NULL, '2026-07-30 09:00:00'),
('listing', 229, 'new_submission', 13, '{"detector":"new_submission","confidence":0.13}', 'approved', NULL, 3, '2026-08-02 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-28 09:00:00'),
('listing', 420, 'image_check', 68, '{"detector":"image_check","confidence":0.68}', 'in_review', 4, NULL, NULL, NULL, '2026-07-11 09:00:00'),
('listing', 94, 'new_submission', 18, '{"detector":"new_submission","confidence":0.18}', 'pending', NULL, NULL, NULL, NULL, '2026-07-27 09:00:00'),
('listing', 78, 'image_check', 66, '{"detector":"image_check","confidence":0.66}', 'skipped', NULL, NULL, NULL, NULL, '2026-08-01 09:00:00'),
('listing', 262, 'price_anomaly', 75, '{"detector":"price_anomaly","confidence":0.75}', 'rejected', 4, 3, '2026-08-10 09:00:00', 'Photographs reused from another listing.', '2026-08-04 09:00:00'),
('listing', 38, 'flagged_automatic', 64, '{"detector":"flagged_automatic","confidence":0.64}', 'approved', NULL, 3, '2026-08-12 09:00:00', 'Checked against the guidelines; no action needed.', '2026-07-08 09:00:00'),
('listing', 51, 'duplicate_suspected', 69, '{"detector":"duplicate_suspected","confidence":0.69}', 'pending', 3, NULL, NULL, NULL, '2026-07-29 09:00:00'),
('listing', 162, 'banned_terms', 80, '{"detector":"banned_terms","confidence":0.8}', 'pending', 3, NULL, NULL, NULL, '2026-07-17 09:00:00'),
('listing', 323, 'edited', 25, '{"detector":"edited","confidence":0.25}', 'pending', 4, NULL, NULL, NULL, '2026-07-15 09:00:00'),
('listing', 424, 'edited', 18, '{"detector":"edited","confidence":0.18}', 'skipped', NULL, NULL, NULL, NULL, '2026-07-26 09:00:00'),
('listing', 461, 'random_audit', 4, '{"detector":"random_audit","confidence":0.04}', 'pending', 3, NULL, NULL, NULL, '2026-08-09 09:00:00'),
('listing', 259, 'banned_terms', 63, '{"detector":"banned_terms","confidence":0.63}', 'pending', NULL, NULL, NULL, NULL, '2026-07-10 09:00:00'),
('listing', 26, 'image_check', 70, '{"detector":"image_check","confidence":0.7}', 'approved', 3, 3, '2026-08-01 09:00:00', 'Checked against the guidelines; no action needed.', '2026-08-08 09:00:00'),
('listing', 428, 'flagged_automatic', 81, '{"detector":"flagged_automatic","confidence":0.81}', 'in_review', 3, NULL, NULL, NULL, '2026-07-24 09:00:00'),
('listing', 36, 'new_submission', 25, '{"detector":"new_submission","confidence":0.25}', 'skipped', 3, NULL, NULL, NULL, '2026-08-13 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(1, '01K2F2DKG0EQS6W445RDMNAYKV', 'organization', 1, NULL, 'rejected', 'normal', '2025-02-04 09:00:00', 3, 3, '2025-02-06 09:00:00', NULL, 'Trade licence supplied has expired.', NULL, '2025-02-04 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(1, 'trade_license', 'https://cdn.livfinder.com/verification/1/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2025-02-04 09:00:00'),
(1, 'rera_certificate', 'https://cdn.livfinder.com/verification/1/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2025-02-04 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(2, '01K2F2DKG0BNRKMAAZV4Z1RXP7', 'organization', 2, NULL, 'approved', 'normal', '2025-04-19 09:00:00', 4, 3, '2025-04-20 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2026-04-19 09:00:00', '2025-04-19 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(2, 'trade_license', 'https://cdn.livfinder.com/verification/2/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2025-04-19 09:00:00'),
(2, 'rera_certificate', 'https://cdn.livfinder.com/verification/2/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2025-04-19 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(3, '01K2F2DKG06C6X6ZH7RTXFSY1Q', 'organization', 3, NULL, 'expired', 'high', '2025-04-27 09:00:00', 3, NULL, NULL, NULL, NULL, NULL, '2025-04-27 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(3, 'trade_license', 'https://cdn.livfinder.com/verification/3/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2025-04-27 09:00:00'),
(3, 'rera_certificate', 'https://cdn.livfinder.com/verification/3/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2025-04-27 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(4, '01K2F2DKG09G0X41V2J9PED42G', 'organization', 4, NULL, 'pending', 'normal', '2025-07-17 09:00:00', NULL, NULL, NULL, NULL, NULL, NULL, '2025-07-17 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(4, 'trade_license', 'https://cdn.livfinder.com/verification/4/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2025-07-17 09:00:00'),
(4, 'rera_certificate', 'https://cdn.livfinder.com/verification/4/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2025-07-17 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(5, '01K2F2DKG0RM9RJDTYXJN7NDAK', 'organization', 5, NULL, 'approved', 'normal', '2026-07-08 09:00:00', 4, 3, '2026-07-11 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2027-07-08 09:00:00', '2026-07-08 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(5, 'trade_license', 'https://cdn.livfinder.com/verification/5/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2026-07-08 09:00:00'),
(5, 'rera_certificate', 'https://cdn.livfinder.com/verification/5/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2026-07-08 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(6, '01K2F2DKG066JJBYYTE1EM59B2', 'organization', 6, NULL, 'approved', 'normal', '2025-03-12 09:00:00', 3, 3, '2025-03-15 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2026-03-12 09:00:00', '2025-03-12 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(6, 'trade_license', 'https://cdn.livfinder.com/verification/6/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2025-03-12 09:00:00'),
(6, 'rera_certificate', 'https://cdn.livfinder.com/verification/6/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2025-03-12 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(7, '01K2F2DKG010MYNJKXGP5TBD5H', 'organization', 7, NULL, 'in_review', 'normal', '2026-05-20 09:00:00', 3, NULL, NULL, NULL, NULL, NULL, '2026-05-20 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(7, 'trade_license', 'https://cdn.livfinder.com/verification/7/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2026-05-20 09:00:00'),
(7, 'rera_certificate', 'https://cdn.livfinder.com/verification/7/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2026-05-20 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(8, '01K2F2DKG0Y4WKH0Y0TVK323Z7', 'organization', 8, NULL, 'approved', 'high', '2025-08-09 09:00:00', 3, 3, '2025-08-17 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2026-08-09 09:00:00', '2025-08-09 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(8, 'trade_license', 'https://cdn.livfinder.com/verification/8/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2025-08-09 09:00:00'),
(8, 'rera_certificate', 'https://cdn.livfinder.com/verification/8/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2025-08-09 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(9, '01K2F2DKG0Q4QRC48SDTRH8Z5D', 'organization', 9, NULL, 'approved', 'normal', '2025-10-22 09:00:00', 4, 3, '2025-10-25 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2026-10-22 09:00:00', '2025-10-22 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(9, 'trade_license', 'https://cdn.livfinder.com/verification/9/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2025-10-22 09:00:00'),
(9, 'rera_certificate', 'https://cdn.livfinder.com/verification/9/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2025-10-22 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(10, '01K2F2DKG0GJ9CQP4D566QM3ZT', 'organization', 10, NULL, 'approved', 'normal', '2026-06-27 09:00:00', 4, 3, '2026-07-03 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2027-06-27 09:00:00', '2026-06-27 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(10, 'trade_license', 'https://cdn.livfinder.com/verification/10/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2026-06-27 09:00:00'),
(10, 'rera_certificate', 'https://cdn.livfinder.com/verification/10/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2026-06-27 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(11, '01K2F2DKG0WZA357SHG3H6TDD2', 'organization', 11, NULL, 'expired', 'normal', '2025-04-24 09:00:00', 4, NULL, NULL, NULL, NULL, NULL, '2025-04-24 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(11, 'trade_license', 'https://cdn.livfinder.com/verification/11/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2025-04-24 09:00:00'),
(11, 'rera_certificate', 'https://cdn.livfinder.com/verification/11/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2025-04-24 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(12, '01K2F2DKG0X3C0T375PX4E7BWG', 'organization', 12, NULL, 'rejected', 'normal', '2026-06-10 09:00:00', 3, 3, '2026-06-12 09:00:00', NULL, 'Trade licence supplied has expired.', NULL, '2026-06-10 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(12, 'trade_license', 'https://cdn.livfinder.com/verification/12/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2026-06-10 09:00:00'),
(12, 'rera_certificate', 'https://cdn.livfinder.com/verification/12/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2026-06-10 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(13, '01K2F2DKG0192RSPY65TBQCY60', 'organization', 13, NULL, 'approved', 'normal', '2025-12-04 09:00:00', 4, 3, '2025-12-05 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2026-12-04 09:00:00', '2025-12-04 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(13, 'trade_license', 'https://cdn.livfinder.com/verification/13/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2025-12-04 09:00:00'),
(13, 'rera_certificate', 'https://cdn.livfinder.com/verification/13/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2025-12-04 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(14, '01K2F2DKG0M0NYZ915RXE3HPVR', 'organization', 14, NULL, 'approved', 'normal', '2025-11-28 09:00:00', 4, 3, '2025-11-30 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2026-11-28 09:00:00', '2025-11-28 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(14, 'trade_license', 'https://cdn.livfinder.com/verification/14/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2025-11-28 09:00:00'),
(14, 'rera_certificate', 'https://cdn.livfinder.com/verification/14/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2025-11-28 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(15, '01K2F2DKG022MP86XAFAE8C67Y', 'organization', 15, NULL, 'approved', 'high', '2026-07-12 09:00:00', 4, 3, '2026-07-13 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2027-07-12 09:00:00', '2026-07-12 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(15, 'trade_license', 'https://cdn.livfinder.com/verification/15/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2026-07-12 09:00:00'),
(15, 'rera_certificate', 'https://cdn.livfinder.com/verification/15/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2026-07-12 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(16, '01K2F2DKG0SXRG9DF1MSNVMAVX', 'organization', 16, NULL, 'rejected', 'normal', '2025-04-21 09:00:00', 3, 3, '2025-04-27 09:00:00', NULL, 'Trade licence supplied has expired.', NULL, '2025-04-21 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(16, 'trade_license', 'https://cdn.livfinder.com/verification/16/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2025-04-21 09:00:00'),
(16, 'rera_certificate', 'https://cdn.livfinder.com/verification/16/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2025-04-21 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(17, '01K2F2DKG0J6GQBFQ32VQFP34M', 'organization', 17, NULL, 'rejected', 'normal', '2026-03-20 09:00:00', 3, 3, '2026-03-23 09:00:00', NULL, 'Trade licence supplied has expired.', NULL, '2026-03-20 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(17, 'trade_license', 'https://cdn.livfinder.com/verification/17/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2026-03-20 09:00:00'),
(17, 'rera_certificate', 'https://cdn.livfinder.com/verification/17/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2026-03-20 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(18, '01K2F2DKG0725NS3QE3PYS4GSB', 'organization', 18, NULL, 'approved', 'normal', '2026-07-13 09:00:00', 3, 3, '2026-07-15 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2027-07-13 09:00:00', '2026-07-13 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(18, 'trade_license', 'https://cdn.livfinder.com/verification/18/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2026-07-13 09:00:00'),
(18, 'rera_certificate', 'https://cdn.livfinder.com/verification/18/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2026-07-13 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(19, '01K2F2DKG0AFWY5Y47TTVXEJTP', 'organization', 19, NULL, 'pending', 'normal', '2026-05-29 09:00:00', NULL, NULL, NULL, NULL, NULL, NULL, '2026-05-29 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(19, 'trade_license', 'https://cdn.livfinder.com/verification/19/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2026-05-29 09:00:00'),
(19, 'rera_certificate', 'https://cdn.livfinder.com/verification/19/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2026-05-29 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(20, '01K2F2DKG02BGJJS72TP60FGJM', 'organization', 20, NULL, 'approved', 'normal', '2025-03-26 09:00:00', 4, 3, '2025-04-01 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2026-03-26 09:00:00', '2025-03-26 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(20, 'trade_license', 'https://cdn.livfinder.com/verification/20/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2025-03-26 09:00:00'),
(20, 'rera_certificate', 'https://cdn.livfinder.com/verification/20/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2025-03-26 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(21, '01K2F2DKG0PSEBQPCF6083MQ8F', 'organization', 21, NULL, 'rejected', 'normal', '2025-09-14 09:00:00', 4, 3, '2025-09-22 09:00:00', NULL, 'Trade licence supplied has expired.', NULL, '2025-09-14 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(21, 'trade_license', 'https://cdn.livfinder.com/verification/21/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2025-09-14 09:00:00'),
(21, 'rera_certificate', 'https://cdn.livfinder.com/verification/21/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2025-09-14 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(22, '01K2F2DKG0X259CTSPV0MC98C7', 'organization', 22, NULL, 'approved', 'normal', '2025-11-07 09:00:00', 4, 3, '2025-11-12 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2026-11-07 09:00:00', '2025-11-07 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(22, 'trade_license', 'https://cdn.livfinder.com/verification/22/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2025-11-07 09:00:00'),
(22, 'rera_certificate', 'https://cdn.livfinder.com/verification/22/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2025-11-07 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(23, '01K2F2DKG0QN6DAH1KH154A9VD', 'organization', 23, NULL, 'approved', 'normal', '2026-04-20 09:00:00', 3, 3, '2026-04-27 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2027-04-20 09:00:00', '2026-04-20 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(23, 'trade_license', 'https://cdn.livfinder.com/verification/23/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2026-04-20 09:00:00'),
(23, 'rera_certificate', 'https://cdn.livfinder.com/verification/23/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2026-04-20 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(24, '01K2F2DKG0E6351BM0QW0YXXNE', 'organization', 24, NULL, 'pending', 'normal', '2025-07-29 09:00:00', NULL, NULL, NULL, NULL, NULL, NULL, '2025-07-29 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(24, 'trade_license', 'https://cdn.livfinder.com/verification/24/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2025-07-29 09:00:00'),
(24, 'rera_certificate', 'https://cdn.livfinder.com/verification/24/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2025-07-29 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(25, '01K2F2DKG0526S2SQ6QR66TAMQ', 'organization', 25, NULL, 'in_review', 'normal', '2025-01-28 09:00:00', 3, NULL, NULL, NULL, NULL, NULL, '2025-01-28 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(25, 'trade_license', 'https://cdn.livfinder.com/verification/25/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'pending', '2025-01-28 09:00:00'),
(25, 'rera_certificate', 'https://cdn.livfinder.com/verification/25/rera.pdf', 'rera.pdf', 'application/pdf', 'pending', '2025-01-28 09:00:00');

INSERT INTO verification_requests (id, public_id, subject_type, subject_id, requested_by_user_id, status, priority, submitted_at, assigned_to_user_id, reviewed_by_user_id, reviewed_at, decision_notes, rejection_reason, expires_at, created_at) VALUES
(26, '01K2F2DKG07NABQ51Z77FGEGA7', 'organization', 26, NULL, 'approved', 'normal', '2025-08-03 09:00:00', 3, 3, '2025-08-11 09:00:00', 'Trade licence and RERA registration both confirmed against the registry.', NULL, '2026-08-03 09:00:00', '2025-08-03 09:00:00');

INSERT INTO verification_documents (verification_request_id, document_type, file_url, file_name, mime_type, status, uploaded_at) VALUES
(26, 'trade_license', 'https://cdn.livfinder.com/verification/26/trade-license.pdf', 'trade-license.pdf', 'application/pdf', 'accepted', '2025-08-03 09:00:00'),
(26, 'rera_certificate', 'https://cdn.livfinder.com/verification/26/rera.pdf', 'rera.pdf', 'application/pdf', 'accepted', '2025-08-03 09:00:00');

INSERT INTO audit_logs (occurred_at, actor_user_id, actor_type, actor_label, impersonator_user_id, action, subject_type, subject_id, subject_label, changes, metadata, request_id) VALUES
('2026-05-05 11:56:00', 1, 'admin', 'staff-1', NULL, 'location.created', 'location', 296, 'location #64', '{"note":"see metadata"}', '{"ip":"203.0.113.109","portal":"admin"}', '01K2F2DKG0Y6BHD1WJ0ASS9ZJD'),
('2026-04-30 13:11:00', 4, 'admin', 'staff-4', NULL, 'listing.rejected', 'listing', 106, 'listing #331', '{"note":"see metadata"}', '{"ip":"203.0.113.226","portal":"admin"}', '01K2F2DKG0YRT6SGNBVX3EF8QP'),
('2026-07-01 19:29:00', 3, 'admin', 'staff-3', NULL, 'listing.approved', 'listing', 208, 'listing #161', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.141","portal":"admin"}', '01K2F2DKG0NJK1MFQBTADA98H2'),
('2026-03-30 12:13:00', 1, 'admin', 'staff-1', NULL, 'settings.updated', 'setting', 340, 'setting #316', '{"note":"see metadata"}', '{"ip":"203.0.113.218","portal":"admin"}', '01K2F2DKG0RCBWT4PQZP7DZRWK'),
('2026-03-31 02:34:00', 1, 'admin', 'staff-1', NULL, 'payout.approved', 'payout', 297, 'payout #281', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.232","portal":"admin"}', '01K2F2DKG0DZTGCTW61BAR8SR4'),
('2026-05-01 23:27:00', 7, 'admin', 'staff-7', NULL, 'feature_flag.toggled', 'feature_flag', 114, 'feature_flag #361', '{"note":"see metadata"}', '{"ip":"203.0.113.197","portal":"admin"}', '01K2F2DKG0VX4PVXJ48R0V95WB'),
('2026-03-03 17:58:00', 1, 'admin', 'staff-1', NULL, 'organization.verified', 'organization', 215, 'organization #340', '{"note":"see metadata"}', '{"ip":"203.0.113.41","portal":"admin"}', '01K2F2DKG0V736VBK1PTZ7272A'),
('2026-08-12 23:13:00', 4, 'admin', 'staff-4', NULL, 'feature_flag.toggled', 'feature_flag', 102, 'feature_flag #324', '{"note":"see metadata"}', '{"ip":"203.0.113.30","portal":"admin"}', '01K2F2DKG0SCJT68WM5P08PDQJ'),
('2026-07-16 14:54:00', 2, 'admin', 'staff-2', NULL, 'feature_flag.toggled', 'feature_flag', 181, 'feature_flag #160', '{"note":"see metadata"}', '{"ip":"203.0.113.105","portal":"admin"}', '01K2F2DKG0G1WJ00TCFSZ4XC7G'),
('2026-03-22 12:04:00', 3, 'admin', 'staff-3', NULL, 'payout.approved', 'payout', 206, 'payout #207', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.169","portal":"admin"}', '01K2F2DKG0MCPQ4XGF0TDKRPEX'),
('2026-06-10 22:05:00', 5, 'admin', 'staff-5', NULL, 'organization.suspended', 'organization', 105, 'organization #46', '{"note":"see metadata"}', '{"ip":"203.0.113.184","portal":"admin"}', '01K2F2DKG0HDESG4HA6BRTY78D'),
('2026-06-15 08:13:00', 8, 'admin', 'staff-8', NULL, 'feature_flag.toggled', 'feature_flag', 1, 'feature_flag #10', '{"note":"see metadata"}', '{"ip":"203.0.113.169","portal":"admin"}', '01K2F2DKG09BGG14BEEKRKP06Z'),
('2026-03-30 21:30:00', 1, 'admin', 'staff-1', NULL, 'api_client.created', 'api_client', 173, 'api_client #305', '{"note":"see metadata"}', '{"ip":"203.0.113.222","portal":"admin"}', '01K2F2DKG0F5F60Q17T5ZGFAQD'),
('2026-03-14 22:54:00', 4, 'admin', 'staff-4', NULL, 'listing.unpublished', 'listing', 395, 'listing #195', '{"note":"see metadata"}', '{"ip":"203.0.113.193","portal":"admin"}', '01K2F2DKG0J3QN4WZSSKK0NJWF'),
('2026-04-20 18:06:00', 2, 'admin', 'staff-2', NULL, 'payout.approved', 'payout', 272, 'payout #176', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.85","portal":"admin"}', '01K2F2DKG0ZHW1WPB4X5JFZ9KX'),
('2026-04-15 20:20:00', 1, 'admin', 'staff-1', NULL, 'listing.approved', 'listing', 242, 'listing #111', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.66","portal":"admin"}', '01K2F2DKG0GX1DBZNDZ724C121'),
('2026-07-20 17:24:00', 3, 'admin', 'staff-3', NULL, 'settings.updated', 'setting', 111, 'setting #258', '{"note":"see metadata"}', '{"ip":"203.0.113.155","portal":"admin"}', '01K2F2DKG0F6XZQ9CR6RKH1S9Z'),
('2026-07-18 10:20:00', 8, 'admin', 'staff-8', NULL, 'user.suspended', 'user', 319, 'user #310', '{"note":"see metadata"}', '{"ip":"203.0.113.192","portal":"admin"}', '01K2F2DKG0346YWSGKZ35V2GAE'),
('2026-04-09 06:05:00', 8, 'admin', 'staff-8', NULL, 'settings.updated', 'setting', 29, 'setting #333', '{"note":"see metadata"}', '{"ip":"203.0.113.78","portal":"admin"}', '01K2F2DKG0V6CW4H416YE66YW9'),
('2026-04-12 18:55:00', 8, 'admin', 'staff-8', NULL, 'organization.verified', 'organization', 186, 'organization #333', '{"note":"see metadata"}', '{"ip":"203.0.113.64","portal":"admin"}', '01K2F2DKG0964YZYSJ5521FTNN'),
('2026-05-06 07:20:00', 4, 'admin', 'staff-4', NULL, 'feature_flag.toggled', 'feature_flag', 172, 'feature_flag #96', '{"note":"see metadata"}', '{"ip":"203.0.113.17","portal":"admin"}', '01K2F2DKG0YXEBBZAW0JBKFACD'),
('2026-03-12 01:44:00', 1, 'admin', 'staff-1', NULL, 'listing.price_changed', 'listing', 132, 'listing #259', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.52","portal":"admin"}', '01K2F2DKG0A71RN9NKVMVRKAKH'),
('2026-04-27 19:54:00', 4, 'admin', 'staff-4', NULL, 'listing.price_changed', 'listing', 330, 'listing #298', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.80","portal":"admin"}', '01K2F2DKG056RWYM5EHZ9JWHR7'),
('2026-03-11 14:41:00', 2, 'admin', 'staff-2', NULL, 'organization.suspended', 'organization', 284, 'organization #16', '{"note":"see metadata"}', '{"ip":"203.0.113.180","portal":"admin"}', '01K2F2DKG04AVRV5Q6XRFTSWK5'),
('2026-02-28 05:01:00', 3, 'admin', 'staff-3', NULL, 'listing.unpublished', 'listing', 104, 'listing #344', '{"note":"see metadata"}', '{"ip":"203.0.113.246","portal":"admin"}', '01K2F2DKG0MDECDFZ2E9JTVX21'),
('2026-07-24 09:07:00', 3, 'admin', 'staff-3', NULL, 'settings.updated', 'setting', 105, 'setting #261', '{"note":"see metadata"}', '{"ip":"203.0.113.200","portal":"admin"}', '01K2F2DKG03EWDQQJ7D3B4CCY3'),
('2026-03-26 15:10:00', 3, 'admin', 'staff-3', NULL, 'user.suspended', 'user', 259, 'user #323', '{"note":"see metadata"}', '{"ip":"203.0.113.65","portal":"admin"}', '01K2F2DKG0X952Y15RVC3QS5FG'),
('2026-03-28 18:27:00', 1, 'admin', 'staff-1', NULL, 'user.reinstated', 'user', 379, 'user #23', '{"note":"see metadata"}', '{"ip":"203.0.113.12","portal":"admin"}', '01K2F2DKG0CW4B9VBJMC3BVYFN'),
('2026-06-11 23:10:00', 2, 'admin', 'staff-2', NULL, 'api_client.created', 'api_client', 72, 'api_client #159', '{"note":"see metadata"}', '{"ip":"203.0.113.230","portal":"admin"}', '01K2F2DKG00GNJ59F4N1E7FRWA'),
('2026-07-07 15:48:00', 5, 'admin', 'staff-5', NULL, 'listing.unpublished', 'listing', 392, 'listing #254', '{"note":"see metadata"}', '{"ip":"203.0.113.23","portal":"admin"}', '01K2F2DKG08CATY1V2NQDXNK1K'),
('2026-07-04 01:06:00', 2, 'admin', 'staff-2', NULL, 'user.suspended', 'user', 226, 'user #225', '{"note":"see metadata"}', '{"ip":"203.0.113.168","portal":"admin"}', '01K2F2DKG0HG0TYPS47P1ZEDHW'),
('2026-03-02 21:17:00', 6, 'admin', 'staff-6', NULL, 'listing.rejected', 'listing', 363, 'listing #222', '{"note":"see metadata"}', '{"ip":"203.0.113.240","portal":"admin"}', '01K2F2DKG02661SD96Y61DD7XY'),
('2026-08-05 11:03:00', 1, 'admin', 'staff-1', NULL, 'account.type_changed', 'account', 389, 'account #185', '{"note":"see metadata"}', '{"ip":"203.0.113.129","portal":"admin"}', '01K2F2DKG0NXDN3TSH8Z630X12'),
('2026-08-03 00:44:00', 7, 'admin', 'staff-7', NULL, 'api_client.created', 'api_client', 162, 'api_client #292', '{"note":"see metadata"}', '{"ip":"203.0.113.152","portal":"admin"}', '01K2F2DKG0S030532D074P7EK0'),
('2026-05-17 02:52:00', 1, 'admin', 'staff-1', 5, 'user.impersonated', 'user', 320, 'user #92', '{"note":"see metadata"}', '{"ip":"203.0.113.226","portal":"admin"}', '01K2F2DKG0R5664WCWN5F7BT47'),
('2026-04-30 00:49:00', 2, 'admin', 'staff-2', NULL, 'category.updated', 'category', 333, 'category #332', '{"note":"see metadata"}', '{"ip":"203.0.113.197","portal":"admin"}', '01K2F2DKG0CJ8Q5T4QT6WTG5J3'),
('2026-08-11 11:39:00', 4, 'admin', 'staff-4', NULL, 'report.resolved', 'report', 289, 'report #310', '{"note":"see metadata"}', '{"ip":"203.0.113.132","portal":"admin"}', '01K2F2DKG0P3KM5GVDHQ7B2SC8'),
('2026-05-26 03:49:00', 4, 'admin', 'staff-4', NULL, 'feature_flag.toggled', 'feature_flag', 344, 'feature_flag #245', '{"note":"see metadata"}', '{"ip":"203.0.113.227","portal":"admin"}', '01K2F2DKG09A13E8VSY4E84VVC'),
('2026-05-02 12:41:00', 6, 'admin', 'staff-6', NULL, 'category.updated', 'category', 100, 'category #161', '{"note":"see metadata"}', '{"ip":"203.0.113.173","portal":"admin"}', '01K2F2DKG04SYQVNP9ZW22WZH2'),
('2026-05-14 09:50:00', 3, 'admin', 'staff-3', NULL, 'listing.rejected', 'listing', 201, 'listing #154', '{"note":"see metadata"}', '{"ip":"203.0.113.159","portal":"admin"}', '01K2F2DKG07D359TZ68KVMBFJV'),
('2026-03-12 06:49:00', 8, 'admin', 'staff-8', NULL, 'settings.updated', 'setting', 388, 'setting #175', '{"note":"see metadata"}', '{"ip":"203.0.113.56","portal":"admin"}', '01K2F2DKG02YXSNQ9XKC4N85K5'),
('2026-06-21 20:38:00', 2, 'admin', 'staff-2', NULL, 'payment.refunded', 'payment', 83, 'payment #279', '{"note":"see metadata"}', '{"ip":"203.0.113.161","portal":"admin"}', '01K2F2DKG0N5GMP3NVFCBXVVS3'),
('2026-06-14 20:50:00', 1, 'admin', 'staff-1', NULL, 'user.suspended', 'user', 284, 'user #32', '{"note":"see metadata"}', '{"ip":"203.0.113.163","portal":"admin"}', '01K2F2DKG02PT432KV83V80GMD'),
('2026-05-16 17:17:00', 2, 'admin', 'staff-2', NULL, 'organization.suspended', 'organization', 275, 'organization #84', '{"note":"see metadata"}', '{"ip":"203.0.113.152","portal":"admin"}', '01K2F2DKG07QYJYVAAEPEHDNT7'),
('2026-07-10 18:34:00', 4, 'admin', 'staff-4', 5, 'user.impersonated', 'user', 197, 'user #266', '{"note":"see metadata"}', '{"ip":"203.0.113.138","portal":"admin"}', '01K2F2DKG012ZGRE4RCEDMR435'),
('2026-04-29 04:36:00', 7, 'admin', 'staff-7', NULL, 'user.suspended', 'user', 103, 'user #27', '{"note":"see metadata"}', '{"ip":"203.0.113.9","portal":"admin"}', '01K2F2DKG0BQG1F38G1SMDQW8D'),
('2026-03-19 09:14:00', 7, 'admin', 'staff-7', NULL, 'listing.rejected', 'listing', 85, 'listing #220', '{"note":"see metadata"}', '{"ip":"203.0.113.116","portal":"admin"}', '01K2F2DKG05N55378QGV6YQJK9'),
('2026-07-07 05:56:00', 5, 'admin', 'staff-5', NULL, 'account.type_changed', 'account', 200, 'account #144', '{"note":"see metadata"}', '{"ip":"203.0.113.130","portal":"admin"}', '01K2F2DKG0APMKYMKCJNQAK48J'),
('2026-03-14 20:23:00', 2, 'admin', 'staff-2', 5, 'user.impersonated', 'user', 288, 'user #304', '{"note":"see metadata"}', '{"ip":"203.0.113.181","portal":"admin"}', '01K2F2DKG04XTGNJ1YWB4S4E9A'),
('2026-06-19 22:12:00', 5, 'admin', 'staff-5', NULL, 'payout.approved', 'payout', 371, 'payout #324', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.137","portal":"admin"}', '01K2F2DKG0S214WWS3NJH6RJDW'),
('2026-05-27 16:36:00', 1, 'admin', 'staff-1', NULL, 'location.created', 'location', 313, 'location #315', '{"note":"see metadata"}', '{"ip":"203.0.113.61","portal":"admin"}', '01K2F2DKG0W6AQED7Q3M28D3FP'),
('2026-06-24 04:22:00', 4, 'admin', 'staff-4', NULL, 'account.type_changed', 'account', 29, 'account #242', '{"note":"see metadata"}', '{"ip":"203.0.113.80","portal":"admin"}', '01K2F2DKG03YHGGKWN348GFFJH'),
('2026-04-24 14:04:00', 7, 'admin', 'staff-7', NULL, 'category.updated', 'category', 23, 'category #175', '{"note":"see metadata"}', '{"ip":"203.0.113.110","portal":"admin"}', '01K2F2DKG0G48KQAFDV1E2FYFF'),
('2026-04-04 12:30:00', 1, 'admin', 'staff-1', NULL, 'report.resolved', 'report', 267, 'report #210', '{"note":"see metadata"}', '{"ip":"203.0.113.43","portal":"admin"}', '01K2F2DKG0S7GEPG092VNSC5H6'),
('2026-04-23 11:54:00', 8, 'admin', 'staff-8', NULL, 'location.created', 'location', 352, 'location #382', '{"note":"see metadata"}', '{"ip":"203.0.113.48","portal":"admin"}', '01K2F2DKG0GDM9KFGZM36XQ3H4'),
('2026-06-18 11:53:00', 1, 'admin', 'staff-1', NULL, 'organization.suspended', 'organization', 148, 'organization #326', '{"note":"see metadata"}', '{"ip":"203.0.113.218","portal":"admin"}', '01K2F2DKG0CJ9AK4786HVTMQ7Q'),
('2026-03-10 10:29:00', 5, 'admin', 'staff-5', NULL, 'listing.rejected', 'listing', 145, 'listing #100', '{"note":"see metadata"}', '{"ip":"203.0.113.128","portal":"admin"}', '01K2F2DKG0JPSSJ92P524CPEED'),
('2026-03-20 14:48:00', 1, 'admin', 'staff-1', NULL, 'listing.unpublished', 'listing', 151, 'listing #196', '{"note":"see metadata"}', '{"ip":"203.0.113.123","portal":"admin"}', '01K2F2DKG0JFAQMWCBT6K3R1SM'),
('2026-04-26 06:49:00', 4, 'admin', 'staff-4', NULL, 'category.updated', 'category', 250, 'category #124', '{"note":"see metadata"}', '{"ip":"203.0.113.30","portal":"admin"}', '01K2F2DKG0K2Q5PNVJDG7SA4QJ'),
('2026-04-05 11:24:00', 5, 'admin', 'staff-5', NULL, 'category.updated', 'category', 239, 'category #89', '{"note":"see metadata"}', '{"ip":"203.0.113.64","portal":"admin"}', '01K2F2DKG08HV77PE3KFYVBMR4'),
('2026-07-26 03:32:00', 1, 'admin', 'staff-1', NULL, 'user.reinstated', 'user', 82, 'user #64', '{"note":"see metadata"}', '{"ip":"203.0.113.173","portal":"admin"}', '01K2F2DKG0FP4F1257SE17WASN'),
('2026-04-12 20:12:00', 5, 'admin', 'staff-5', 5, 'user.impersonated', 'user', 41, 'user #131', '{"note":"see metadata"}', '{"ip":"203.0.113.166","portal":"admin"}', '01K2F2DKG0FJ3H07K18N410YG3'),
('2026-06-09 19:31:00', 1, 'admin', 'staff-1', NULL, 'payout.approved', 'payout', 296, 'payout #338', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.44","portal":"admin"}', '01K2F2DKG0HCF188NF3GRW2KXG'),
('2026-05-13 07:58:00', 5, 'admin', 'staff-5', NULL, 'settings.updated', 'setting', 66, 'setting #37', '{"note":"see metadata"}', '{"ip":"203.0.113.140","portal":"admin"}', '01K2F2DKG04JZ30FXSKXDV3SDB'),
('2026-07-29 05:25:00', 1, 'admin', 'staff-1', NULL, 'listing.approved', 'listing', 124, 'listing #394', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.201","portal":"admin"}', '01K2F2DKG0GZW3EQ0R84T2Q9HB'),
('2026-04-25 13:06:00', 5, 'admin', 'staff-5', NULL, 'settings.updated', 'setting', 249, 'setting #106', '{"note":"see metadata"}', '{"ip":"203.0.113.239","portal":"admin"}', '01K2F2DKG0TY6AEDT85WQK8A7B'),
('2026-07-27 16:31:00', 5, 'admin', 'staff-5', NULL, 'listing.price_changed', 'listing', 123, 'listing #148', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.225","portal":"admin"}', '01K2F2DKG0RQZWB73ZXVWBQ160'),
('2026-08-11 17:19:00', 4, 'admin', 'staff-4', NULL, 'listing.price_changed', 'listing', 216, 'listing #215', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.126","portal":"admin"}', '01K2F2DKG0T5ZXJH1YSBH4CA41'),
('2026-04-05 09:51:00', 3, 'admin', 'staff-3', NULL, 'account.type_changed', 'account', 183, 'account #229', '{"note":"see metadata"}', '{"ip":"203.0.113.52","portal":"admin"}', '01K2F2DKG0T0YGJVNE9FDYQWK6'),
('2026-08-04 09:54:00', 1, 'admin', 'staff-1', NULL, 'listing.unpublished', 'listing', 246, 'listing #223', '{"note":"see metadata"}', '{"ip":"203.0.113.103","portal":"admin"}', '01K2F2DKG0TPZS8M5FQ085FGHP'),
('2026-05-01 22:31:00', 3, 'admin', 'staff-3', NULL, 'api_client.created', 'api_client', 397, 'api_client #5', '{"note":"see metadata"}', '{"ip":"203.0.113.95","portal":"admin"}', '01K2F2DKG0WQRBCJAHYPTH8KYC'),
('2026-07-04 09:39:00', 6, 'admin', 'staff-6', NULL, 'report.resolved', 'report', 264, 'report #106', '{"note":"see metadata"}', '{"ip":"203.0.113.18","portal":"admin"}', '01K2F2DKG0JG8NZ7SP7V46PB95'),
('2026-05-16 19:42:00', 7, 'admin', 'staff-7', NULL, 'user.reinstated', 'user', 312, 'user #384', '{"note":"see metadata"}', '{"ip":"203.0.113.189","portal":"admin"}', '01K2F2DKG0Q742M595TCX6789Q'),
('2026-05-05 09:35:00', 1, 'admin', 'staff-1', NULL, 'api_client.created', 'api_client', 312, 'api_client #361', '{"note":"see metadata"}', '{"ip":"203.0.113.118","portal":"admin"}', '01K2F2DKG0WXGXXTNSJBK6VXJG'),
('2026-07-07 21:46:00', 6, 'admin', 'staff-6', NULL, 'user.suspended', 'user', 40, 'user #304', '{"note":"see metadata"}', '{"ip":"203.0.113.172","portal":"admin"}', '01K2F2DKG0R8GQ6YD8Q6N2Q78N'),
('2026-04-17 09:40:00', 4, 'admin', 'staff-4', NULL, 'listing.price_changed', 'listing', 371, 'listing #395', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.87","portal":"admin"}', '01K2F2DKG0VGXWEEV3AQ84Z8TN'),
('2026-05-10 03:26:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 189, 'location #391', '{"note":"see metadata"}', '{"ip":"203.0.113.27","portal":"admin"}', '01K2F2DKG05DMT71A3PAN0KE1T'),
('2026-07-21 03:55:00', 7, 'admin', 'staff-7', NULL, 'listing.rejected', 'listing', 32, 'listing #3', '{"note":"see metadata"}', '{"ip":"203.0.113.62","portal":"admin"}', '01K2F2DKG0GR2A2A0FG458HN20'),
('2026-06-27 08:31:00', 8, 'admin', 'staff-8', NULL, 'category.updated', 'category', 189, 'category #45', '{"note":"see metadata"}', '{"ip":"203.0.113.76","portal":"admin"}', '01K2F2DKG0H0E3906JP0NAJPVW'),
('2026-06-24 06:48:00', 2, 'admin', 'staff-2', NULL, 'payout.approved', 'payout', 59, 'payout #184', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.167","portal":"admin"}', '01K2F2DKG02HJDKAE65FS3RTE8'),
('2026-04-08 04:56:00', 7, 'admin', 'staff-7', 5, 'user.impersonated', 'user', 204, 'user #92', '{"note":"see metadata"}', '{"ip":"203.0.113.188","portal":"admin"}', '01K2F2DKG0HH0CZVTPD1SSR245'),
('2026-06-27 12:45:00', 1, 'admin', 'staff-1', NULL, 'listing.rejected', 'listing', 140, 'listing #372', '{"note":"see metadata"}', '{"ip":"203.0.113.199","portal":"admin"}', '01K2F2DKG0YHBS1X9KM1H03VZT'),
('2026-03-19 04:18:00', 1, 'admin', 'staff-1', NULL, 'listing.price_changed', 'listing', 1, 'listing #136', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.242","portal":"admin"}', '01K2F2DKG0CH545X9K9QC4JM8G'),
('2026-05-15 20:57:00', 8, 'admin', 'staff-8', NULL, 'settings.updated', 'setting', 103, 'setting #166', '{"note":"see metadata"}', '{"ip":"203.0.113.51","portal":"admin"}', '01K2F2DKG04XK7G3VBJ6NZBBCT'),
('2026-08-03 03:59:00', 7, 'admin', 'staff-7', NULL, 'listing.price_changed', 'listing', 57, 'listing #279', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.54","portal":"admin"}', '01K2F2DKG0T7P2M533060REYN9'),
('2026-07-25 00:22:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 122, 'location #222', '{"note":"see metadata"}', '{"ip":"203.0.113.104","portal":"admin"}', '01K2F2DKG0TSTY93R9B9YTDR3W'),
('2026-07-09 07:08:00', 1, 'admin', 'staff-1', NULL, 'feature_flag.toggled', 'feature_flag', 72, 'feature_flag #64', '{"note":"see metadata"}', '{"ip":"203.0.113.230","portal":"admin"}', '01K2F2DKG0NTTXSNTX0MG1V0QS'),
('2026-06-11 21:20:00', 7, 'admin', 'staff-7', NULL, 'feature_flag.toggled', 'feature_flag', 138, 'feature_flag #178', '{"note":"see metadata"}', '{"ip":"203.0.113.130","portal":"admin"}', '01K2F2DKG07BMAN39R4D8QWW3P'),
('2026-03-15 14:18:00', 1, 'admin', 'staff-1', NULL, 'listing.price_changed', 'listing', 72, 'listing #370', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.186","portal":"admin"}', '01K2F2DKG0EF6YPWX0EB67N3HE'),
('2026-08-09 07:53:00', 1, 'admin', 'staff-1', NULL, 'account.type_changed', 'account', 276, 'account #392', '{"note":"see metadata"}', '{"ip":"203.0.113.128","portal":"admin"}', '01K2F2DKG0MRTQNKMM94EJJHXW'),
('2026-03-12 00:32:00', 8, 'admin', 'staff-8', NULL, 'report.resolved', 'report', 298, 'report #31', '{"note":"see metadata"}', '{"ip":"203.0.113.47","portal":"admin"}', '01K2F2DKG00VR7M03SVG8KDGAT'),
('2026-08-09 12:37:00', 7, 'admin', 'staff-7', NULL, 'payout.approved', 'payout', 322, 'payout #63', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.20","portal":"admin"}', '01K2F2DKG0BEHB0SCJMRD8MWXV'),
('2026-04-04 10:02:00', 8, 'admin', 'staff-8', NULL, 'listing.rejected', 'listing', 198, 'listing #140', '{"note":"see metadata"}', '{"ip":"203.0.113.65","portal":"admin"}', '01K2F2DKG0T1XMZ6TG4175WQ48'),
('2026-03-01 06:34:00', 2, 'admin', 'staff-2', NULL, 'organization.suspended', 'organization', 114, 'organization #25', '{"note":"see metadata"}', '{"ip":"203.0.113.72","portal":"admin"}', '01K2F2DKG0QK5WEV593X3WH1YG'),
('2026-03-24 03:20:00', 4, 'admin', 'staff-4', NULL, 'settings.updated', 'setting', 159, 'setting #159', '{"note":"see metadata"}', '{"ip":"203.0.113.109","portal":"admin"}', '01K2F2DKG0N5X6RJ257XSVNAYW'),
('2026-08-14 08:44:00', 7, 'admin', 'staff-7', NULL, 'feature_flag.toggled', 'feature_flag', 169, 'feature_flag #352', '{"note":"see metadata"}', '{"ip":"203.0.113.156","portal":"admin"}', '01K2F2DKG0ZMQ90RB0KC0Z5WNW'),
('2026-04-19 15:18:00', 5, 'admin', 'staff-5', NULL, 'category.updated', 'category', 140, 'category #178', '{"note":"see metadata"}', '{"ip":"203.0.113.244","portal":"admin"}', '01K2F2DKG0B2VZ06EYQX5XVPAH'),
('2026-07-08 10:58:00', 1, 'admin', 'staff-1', NULL, 'settings.updated', 'setting', 326, 'setting #331', '{"note":"see metadata"}', '{"ip":"203.0.113.43","portal":"admin"}', '01K2F2DKG03Q4HWGJ3R8PPC12W'),
('2026-05-29 17:49:00', 8, 'admin', 'staff-8', NULL, 'location.created', 'location', 387, 'location #12', '{"note":"see metadata"}', '{"ip":"203.0.113.3","portal":"admin"}', '01K2F2DKG0T86CTJGA72Q7AHTJ'),
('2026-07-14 05:46:00', 1, 'admin', 'staff-1', NULL, 'payment.refunded', 'payment', 385, 'payment #71', '{"note":"see metadata"}', '{"ip":"203.0.113.92","portal":"admin"}', '01K2F2DKG08X0QJF6PGWDAEZFG'),
('2026-06-20 08:54:00', 2, 'admin', 'staff-2', NULL, 'category.updated', 'category', 258, 'category #168', '{"note":"see metadata"}', '{"ip":"203.0.113.161","portal":"admin"}', '01K2F2DKG0BHX89CQ7K6E9M4ND'),
('2026-05-25 05:42:00', 5, 'admin', 'staff-5', 5, 'user.impersonated', 'user', 67, 'user #340', '{"note":"see metadata"}', '{"ip":"203.0.113.63","portal":"admin"}', '01K2F2DKG0MSVQR7J54W3H6TTV'),
('2026-04-14 07:23:00', 3, 'admin', 'staff-3', NULL, 'user.suspended', 'user', 337, 'user #292', '{"note":"see metadata"}', '{"ip":"203.0.113.35","portal":"admin"}', '01K2F2DKG0KM60GCVHC0M40CGD'),
('2026-03-26 21:10:00', 5, 'admin', 'staff-5', NULL, 'payment.refunded', 'payment', 4, 'payment #36', '{"note":"see metadata"}', '{"ip":"203.0.113.166","portal":"admin"}', '01K2F2DKG0TXYREB3ZH8V8NF5N'),
('2026-03-23 12:16:00', 4, 'admin', 'staff-4', NULL, 'organization.verified', 'organization', 284, 'organization #99', '{"note":"see metadata"}', '{"ip":"203.0.113.34","portal":"admin"}', '01K2F2DKG0JBETWPP9NQ7R0J9S'),
('2026-06-23 04:00:00', 7, 'admin', 'staff-7', NULL, 'settings.updated', 'setting', 67, 'setting #98', '{"note":"see metadata"}', '{"ip":"203.0.113.49","portal":"admin"}', '01K2F2DKG01NS7XXBXRNW1PV9R'),
('2026-06-13 15:49:00', 3, 'admin', 'staff-3', NULL, 'settings.updated', 'setting', 7, 'setting #377', '{"note":"see metadata"}', '{"ip":"203.0.113.179","portal":"admin"}', '01K2F2DKG04P9Z0GHDP734DS6F'),
('2026-03-10 01:40:00', 2, 'admin', 'staff-2', NULL, 'category.updated', 'category', 203, 'category #24', '{"note":"see metadata"}', '{"ip":"203.0.113.165","portal":"admin"}', '01K2F2DKG0V8GGEX47Y0RQPFKG'),
('2026-06-03 15:20:00', 1, 'admin', 'staff-1', NULL, 'user.reinstated', 'user', 122, 'user #321', '{"note":"see metadata"}', '{"ip":"203.0.113.237","portal":"admin"}', '01K2F2DKG0HD49Z3YCNXABFEJ2'),
('2026-08-15 23:48:00', 1, 'admin', 'staff-1', NULL, 'api_client.created', 'api_client', 128, 'api_client #252', '{"note":"see metadata"}', '{"ip":"203.0.113.228","portal":"admin"}', '01K2F2DKG0KP4TJM0W21BNBSQ7'),
('2026-07-19 20:43:00', 1, 'admin', 'staff-1', NULL, 'listing.price_changed', 'listing', 176, 'listing #155', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.230","portal":"admin"}', '01K2F2DKG0ZGKDH81WCB6VBHDD'),
('2026-03-25 23:54:00', 2, 'admin', 'staff-2', NULL, 'payment.refunded', 'payment', 182, 'payment #2', '{"note":"see metadata"}', '{"ip":"203.0.113.54","portal":"admin"}', '01K2F2DKG0003JWKHRY53TCTZG'),
('2026-06-29 07:19:00', 2, 'admin', 'staff-2', NULL, 'user.suspended', 'user', 338, 'user #387', '{"note":"see metadata"}', '{"ip":"203.0.113.60","portal":"admin"}', '01K2F2DKG0SC86NT66MBT6PA6K'),
('2026-03-08 10:28:00', 6, 'admin', 'staff-6', NULL, 'account.type_changed', 'account', 42, 'account #122', '{"note":"see metadata"}', '{"ip":"203.0.113.179","portal":"admin"}', '01K2F2DKG0QR44G1NS2WJFSN39'),
('2026-06-14 01:41:00', 3, 'admin', 'staff-3', NULL, 'location.created', 'location', 72, 'location #51', '{"note":"see metadata"}', '{"ip":"203.0.113.54","portal":"admin"}', '01K2F2DKG0HR03F5TH7K5F85SM'),
('2026-06-26 18:57:00', 4, 'admin', 'staff-4', NULL, 'api_client.created', 'api_client', 24, 'api_client #169', '{"note":"see metadata"}', '{"ip":"203.0.113.59","portal":"admin"}', '01K2F2DKG0ANYKZTV6ZS9ZABW0'),
('2026-03-17 10:53:00', 1, 'admin', 'staff-1', NULL, 'listing.rejected', 'listing', 172, 'listing #365', '{"note":"see metadata"}', '{"ip":"203.0.113.248","portal":"admin"}', '01K2F2DKG0BZ57BY3WJYHPG38Y'),
('2026-05-11 19:01:00', 2, 'admin', 'staff-2', NULL, 'listing.unpublished', 'listing', 134, 'listing #35', '{"note":"see metadata"}', '{"ip":"203.0.113.28","portal":"admin"}', '01K2F2DKG0C0BV6RXA31HSM7EG'),
('2026-05-19 05:28:00', 4, 'admin', 'staff-4', NULL, 'category.updated', 'category', 102, 'category #73', '{"note":"see metadata"}', '{"ip":"203.0.113.128","portal":"admin"}', '01K2F2DKG095RRJ2F5Q9XD1J7F'),
('2026-07-19 06:33:00', 8, 'admin', 'staff-8', NULL, 'api_client.created', 'api_client', 242, 'api_client #251', '{"note":"see metadata"}', '{"ip":"203.0.113.128","portal":"admin"}', '01K2F2DKG0CD2TJ7KEDGJWCKCY'),
('2026-05-30 10:42:00', 7, 'admin', 'staff-7', NULL, 'listing.unpublished', 'listing', 55, 'listing #391', '{"note":"see metadata"}', '{"ip":"203.0.113.61","portal":"admin"}', '01K2F2DKG09MQ682A1FAH3R663'),
('2026-03-07 14:29:00', 8, 'admin', 'staff-8', NULL, 'api_client.created', 'api_client', 208, 'api_client #167', '{"note":"see metadata"}', '{"ip":"203.0.113.158","portal":"admin"}', '01K2F2DKG00XKEPSANR1V2WHDA'),
('2026-07-10 14:23:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 104, 'location #164', '{"note":"see metadata"}', '{"ip":"203.0.113.193","portal":"admin"}', '01K2F2DKG0YYZJNKTTG8YWCN8C'),
('2026-03-20 15:51:00', 6, 'admin', 'staff-6', NULL, 'report.resolved', 'report', 57, 'report #355', '{"note":"see metadata"}', '{"ip":"203.0.113.70","portal":"admin"}', '01K2F2DKG07D9JYCCG2GYGFV8B'),
('2026-03-03 11:33:00', 6, 'admin', 'staff-6', NULL, 'listing.rejected', 'listing', 358, 'listing #216', '{"note":"see metadata"}', '{"ip":"203.0.113.72","portal":"admin"}', '01K2F2DKG0BE8DWC1AAXX6RQRN'),
('2026-06-12 19:23:00', 6, 'admin', 'staff-6', NULL, 'account.type_changed', 'account', 307, 'account #304', '{"note":"see metadata"}', '{"ip":"203.0.113.1","portal":"admin"}', '01K2F2DKG0HBZ8RNRRVEQY2FJ3'),
('2026-05-28 07:07:00', 1, 'admin', 'staff-1', NULL, 'organization.verified', 'organization', 376, 'organization #79', '{"note":"see metadata"}', '{"ip":"203.0.113.185","portal":"admin"}', '01K2F2DKG0HT6GZ4RPCMY1MSEW'),
('2026-05-21 12:04:00', 8, 'admin', 'staff-8', NULL, 'category.updated', 'category', 127, 'category #286', '{"note":"see metadata"}', '{"ip":"203.0.113.141","portal":"admin"}', '01K2F2DKG0V1PYV0129KCPHT7J'),
('2026-08-03 16:55:00', 7, 'admin', 'staff-7', NULL, 'location.created', 'location', 145, 'location #176', '{"note":"see metadata"}', '{"ip":"203.0.113.126","portal":"admin"}', '01K2F2DKG0H64ZMTR5NTQY3XVM'),
('2026-07-24 14:21:00', 1, 'admin', 'staff-1', NULL, 'account.type_changed', 'account', 249, 'account #392', '{"note":"see metadata"}', '{"ip":"203.0.113.214","portal":"admin"}', '01K2F2DKG0HET0PMRA1HSRY5JK'),
('2026-08-04 01:59:00', 8, 'admin', 'staff-8', NULL, 'category.updated', 'category', 191, 'category #171', '{"note":"see metadata"}', '{"ip":"203.0.113.197","portal":"admin"}', '01K2F2DKG07VEKWPK58FNF532V'),
('2026-05-13 21:47:00', 4, 'admin', 'staff-4', NULL, 'payout.approved', 'payout', 127, 'payout #135', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.124","portal":"admin"}', '01K2F2DKG0XHY4Y2F78PH8255C'),
('2026-05-10 04:19:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 192, 'location #197', '{"note":"see metadata"}', '{"ip":"203.0.113.194","portal":"admin"}', '01K2F2DKG01H30CHT1J8H0NK87'),
('2026-08-02 04:39:00', 3, 'admin', 'staff-3', NULL, 'listing.price_changed', 'listing', 128, 'listing #235', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.176","portal":"admin"}', '01K2F2DKG0CYCDMFXZ6QPEW7JK'),
('2026-06-01 00:21:00', 6, 'admin', 'staff-6', NULL, 'feature_flag.toggled', 'feature_flag', 297, 'feature_flag #301', '{"note":"see metadata"}', '{"ip":"203.0.113.182","portal":"admin"}', '01K2F2DKG08T54H7HG6N95JQFQ'),
('2026-04-17 16:40:00', 1, 'admin', 'staff-1', NULL, 'listing.price_changed', 'listing', 305, 'listing #266', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.136","portal":"admin"}', '01K2F2DKG077CR7YYYA108AHCG'),
('2026-03-18 19:50:00', 1, 'admin', 'staff-1', NULL, 'category.updated', 'category', 58, 'category #78', '{"note":"see metadata"}', '{"ip":"203.0.113.70","portal":"admin"}', '01K2F2DKG00VQXHFF6QBAHEJM7'),
('2026-03-16 07:51:00', 6, 'admin', 'staff-6', NULL, 'listing.approved', 'listing', 268, 'listing #168', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.46","portal":"admin"}', '01K2F2DKG09293Y05NNWM86W08'),
('2026-04-07 00:27:00', 6, 'admin', 'staff-6', NULL, 'listing.approved', 'listing', 234, 'listing #356', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.170","portal":"admin"}', '01K2F2DKG0Y4AP6B02A92WPNVX'),
('2026-07-10 11:51:00', 5, 'admin', 'staff-5', NULL, 'payment.refunded', 'payment', 290, 'payment #9', '{"note":"see metadata"}', '{"ip":"203.0.113.3","portal":"admin"}', '01K2F2DKG0N8QMJKH7K76QSZFH'),
('2026-07-27 15:22:00', 1, 'admin', 'staff-1', NULL, 'settings.updated', 'setting', 195, 'setting #102', '{"note":"see metadata"}', '{"ip":"203.0.113.130","portal":"admin"}', '01K2F2DKG014P5RMVCXFHN73RV'),
('2026-08-01 17:37:00', 3, 'admin', 'staff-3', NULL, 'payment.refunded', 'payment', 46, 'payment #245', '{"note":"see metadata"}', '{"ip":"203.0.113.235","portal":"admin"}', '01K2F2DKG00C7DK6XY9256NTDH'),
('2026-04-13 15:18:00', 6, 'admin', 'staff-6', NULL, 'listing.price_changed', 'listing', 295, 'listing #24', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.53","portal":"admin"}', '01K2F2DKG0247PFW5Y9FXXK61Q'),
('2026-05-03 23:16:00', 8, 'admin', 'staff-8', NULL, 'account.type_changed', 'account', 78, 'account #50', '{"note":"see metadata"}', '{"ip":"203.0.113.245","portal":"admin"}', '01K2F2DKG0XGJPE8GAG0JF0YE6'),
('2026-04-01 19:04:00', 2, 'admin', 'staff-2', NULL, 'report.resolved', 'report', 251, 'report #264', '{"note":"see metadata"}', '{"ip":"203.0.113.178","portal":"admin"}', '01K2F2DKG0N1FBHTRZ6YTV17BT'),
('2026-04-01 19:35:00', 7, 'admin', 'staff-7', NULL, 'category.updated', 'category', 77, 'category #175', '{"note":"see metadata"}', '{"ip":"203.0.113.182","portal":"admin"}', '01K2F2DKG0WKPR71DT6KYZ5D1W'),
('2026-06-13 20:18:00', 2, 'admin', 'staff-2', NULL, 'payout.approved', 'payout', 223, 'payout #12', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.37","portal":"admin"}', '01K2F2DKG0AX7NY6RC11SFEEEM'),
('2026-04-04 23:47:00', 3, 'admin', 'staff-3', NULL, 'listing.price_changed', 'listing', 267, 'listing #182', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.231","portal":"admin"}', '01K2F2DKG0T3Z4C0WBNMDPVGS7'),
('2026-04-08 13:19:00', 8, 'admin', 'staff-8', NULL, 'listing.approved', 'listing', 39, 'listing #75', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.61","portal":"admin"}', '01K2F2DKG0QDCWY5X51R2P2HK4'),
('2026-03-10 06:40:00', 6, 'admin', 'staff-6', NULL, 'user.suspended', 'user', 171, 'user #361', '{"note":"see metadata"}', '{"ip":"203.0.113.183","portal":"admin"}', '01K2F2DKG0NJBN7X8HMFC7NJ1M'),
('2026-04-27 13:58:00', 7, 'admin', 'staff-7', NULL, 'listing.unpublished', 'listing', 160, 'listing #400', '{"note":"see metadata"}', '{"ip":"203.0.113.57","portal":"admin"}', '01K2F2DKG0PBG0H7P4B45QCXZT'),
('2026-03-07 04:11:00', 4, 'admin', 'staff-4', NULL, 'organization.suspended', 'organization', 255, 'organization #2', '{"note":"see metadata"}', '{"ip":"203.0.113.49","portal":"admin"}', '01K2F2DKG0JWEAPGAXJ0TH2Q0E'),
('2026-03-31 16:18:00', 4, 'admin', 'staff-4', NULL, 'user.suspended', 'user', 377, 'user #295', '{"note":"see metadata"}', '{"ip":"203.0.113.27","portal":"admin"}', '01K2F2DKG0HEKZS76ESBB41Z1Y'),
('2026-06-14 06:26:00', 3, 'admin', 'staff-3', NULL, 'listing.rejected', 'listing', 31, 'listing #41', '{"note":"see metadata"}', '{"ip":"203.0.113.199","portal":"admin"}', '01K2F2DKG0Q26W9T6KQM03KAE7'),
('2026-04-30 12:55:00', 8, 'admin', 'staff-8', NULL, 'listing.price_changed', 'listing', 375, 'listing #209', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.247","portal":"admin"}', '01K2F2DKG0T0AMYN924A2D8FAY'),
('2026-06-16 13:36:00', 3, 'admin', 'staff-3', NULL, 'listing.unpublished', 'listing', 353, 'listing #279', '{"note":"see metadata"}', '{"ip":"203.0.113.81","portal":"admin"}', '01K2F2DKG0FHWX076SHA6B7DZ9'),
('2026-06-15 13:07:00', 8, 'admin', 'staff-8', NULL, 'organization.verified', 'organization', 144, 'organization #163', '{"note":"see metadata"}', '{"ip":"203.0.113.194","portal":"admin"}', '01K2F2DKG0F10EWYVSZJ9T1JPQ'),
('2026-05-10 12:12:00', 8, 'admin', 'staff-8', NULL, 'user.suspended', 'user', 178, 'user #125', '{"note":"see metadata"}', '{"ip":"203.0.113.125","portal":"admin"}', '01K2F2DKG0P0ZH6WYJKDH0A376'),
('2026-07-02 12:21:00', 5, 'admin', 'staff-5', NULL, 'feature_flag.toggled', 'feature_flag', 308, 'feature_flag #391', '{"note":"see metadata"}', '{"ip":"203.0.113.235","portal":"admin"}', '01K2F2DKG0Y5Y475AHG6G1VQJX'),
('2026-06-15 09:17:00', 3, 'admin', 'staff-3', NULL, 'user.reinstated', 'user', 69, 'user #185', '{"note":"see metadata"}', '{"ip":"203.0.113.149","portal":"admin"}', '01K2F2DKG0H3RPP9DDYGGKAA79'),
('2026-04-25 22:23:00', 7, 'admin', 'staff-7', NULL, 'location.created', 'location', 374, 'location #193', '{"note":"see metadata"}', '{"ip":"203.0.113.243","portal":"admin"}', '01K2F2DKG0WJEVVC5EX800N5PA'),
('2026-07-31 03:14:00', 8, 'admin', 'staff-8', NULL, 'payment.refunded', 'payment', 228, 'payment #366', '{"note":"see metadata"}', '{"ip":"203.0.113.87","portal":"admin"}', '01K2F2DKG08GJGMNGHHQD8NRMK'),
('2026-06-16 01:23:00', 6, 'admin', 'staff-6', NULL, 'payout.approved', 'payout', 381, 'payout #197', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.110","portal":"admin"}', '01K2F2DKG0TTZ4Z37GJV76JSDE'),
('2026-05-01 01:57:00', 8, 'admin', 'staff-8', NULL, 'account.type_changed', 'account', 4, 'account #154', '{"note":"see metadata"}', '{"ip":"203.0.113.215","portal":"admin"}', '01K2F2DKG0DEE5BFG6EE079BX3'),
('2026-04-02 13:12:00', 4, 'admin', 'staff-4', NULL, 'listing.rejected', 'listing', 258, 'listing #189', '{"note":"see metadata"}', '{"ip":"203.0.113.175","portal":"admin"}', '01K2F2DKG0HTVZQTHD37SD4HMZ'),
('2026-07-18 12:34:00', 5, 'admin', 'staff-5', NULL, 'category.updated', 'category', 79, 'category #383', '{"note":"see metadata"}', '{"ip":"203.0.113.84","portal":"admin"}', '01K2F2DKG0RJ8CVR958WNEZVEN'),
('2026-05-03 19:28:00', 4, 'admin', 'staff-4', NULL, 'category.updated', 'category', 74, 'category #134', '{"note":"see metadata"}', '{"ip":"203.0.113.4","portal":"admin"}', '01K2F2DKG0K9JD1GTQRYJ72FY3'),
('2026-05-18 13:49:00', 8, 'admin', 'staff-8', NULL, 'listing.approved', 'listing', 73, 'listing #86', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.61","portal":"admin"}', '01K2F2DKG0JC66ZDVXRN1FE01N'),
('2026-03-10 20:31:00', 2, 'admin', 'staff-2', NULL, 'location.created', 'location', 365, 'location #329', '{"note":"see metadata"}', '{"ip":"203.0.113.6","portal":"admin"}', '01K2F2DKG002ZTESWA6AEAAS7C'),
('2026-03-13 08:56:00', 5, 'admin', 'staff-5', NULL, 'organization.verified', 'organization', 107, 'organization #338', '{"note":"see metadata"}', '{"ip":"203.0.113.192","portal":"admin"}', '01K2F2DKG0GF3Z8CBQ5D593P82'),
('2026-05-09 17:12:00', 7, 'admin', 'staff-7', NULL, 'api_client.created', 'api_client', 276, 'api_client #393', '{"note":"see metadata"}', '{"ip":"203.0.113.248","portal":"admin"}', '01K2F2DKG0V3EFTQ3K0GFXDRTZ'),
('2026-06-21 02:47:00', 7, 'admin', 'staff-7', NULL, 'payment.refunded', 'payment', 62, 'payment #296', '{"note":"see metadata"}', '{"ip":"203.0.113.130","portal":"admin"}', '01K2F2DKG0BZHGK5EZTWJS99ZZ'),
('2026-05-06 13:22:00', 5, 'admin', 'staff-5', NULL, 'report.resolved', 'report', 78, 'report #271', '{"note":"see metadata"}', '{"ip":"203.0.113.71","portal":"admin"}', '01K2F2DKG0QVT09EAW66EWGBRQ'),
('2026-07-26 02:34:00', 2, 'admin', 'staff-2', NULL, 'user.suspended', 'user', 7, 'user #282', '{"note":"see metadata"}', '{"ip":"203.0.113.235","portal":"admin"}', '01K2F2DKG0VHEKNCQANJH93CAT'),
('2026-06-08 21:15:00', 7, 'admin', 'staff-7', NULL, 'organization.verified', 'organization', 182, 'organization #213', '{"note":"see metadata"}', '{"ip":"203.0.113.116","portal":"admin"}', '01K2F2DKG0AAC44J7CSZ3ZXN7V'),
('2026-06-06 04:53:00', 2, 'admin', 'staff-2', NULL, 'api_client.created', 'api_client', 80, 'api_client #219', '{"note":"see metadata"}', '{"ip":"203.0.113.126","portal":"admin"}', '01K2F2DKG07N58GBZXGCJ7SVDN'),
('2026-04-29 12:41:00', 6, 'admin', 'staff-6', 5, 'user.impersonated', 'user', 173, 'user #273', '{"note":"see metadata"}', '{"ip":"203.0.113.79","portal":"admin"}', '01K2F2DKG07E23WQTE92N05VVM'),
('2026-07-24 06:12:00', 3, 'admin', 'staff-3', NULL, 'listing.price_changed', 'listing', 266, 'listing #394', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.243","portal":"admin"}', '01K2F2DKG0T2TEM8Z7GS9WB3N6'),
('2026-06-29 09:04:00', 3, 'admin', 'staff-3', NULL, 'payment.refunded', 'payment', 328, 'payment #108', '{"note":"see metadata"}', '{"ip":"203.0.113.163","portal":"admin"}', '01K2F2DKG0PYY2HWNA5W1142B6'),
('2026-05-24 22:35:00', 8, 'admin', 'staff-8', NULL, 'location.created', 'location', 348, 'location #271', '{"note":"see metadata"}', '{"ip":"203.0.113.38","portal":"admin"}', '01K2F2DKG0C2FEY6PZ9WABC338'),
('2026-05-20 12:45:00', 4, 'admin', 'staff-4', NULL, 'listing.approved', 'listing', 286, 'listing #40', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.93","portal":"admin"}', '01K2F2DKG0196E6ZR47ET7223Q'),
('2026-05-31 17:47:00', 2, 'admin', 'staff-2', NULL, 'location.created', 'location', 281, 'location #209', '{"note":"see metadata"}', '{"ip":"203.0.113.94","portal":"admin"}', '01K2F2DKG0VADBCVSR3JHXERVY'),
('2026-03-08 13:20:00', 7, 'admin', 'staff-7', NULL, 'listing.unpublished', 'listing', 314, 'listing #212', '{"note":"see metadata"}', '{"ip":"203.0.113.181","portal":"admin"}', '01K2F2DKG0HFEQDK63JTQA3CND'),
('2026-03-08 13:18:00', 8, 'admin', 'staff-8', NULL, 'organization.verified', 'organization', 345, 'organization #152', '{"note":"see metadata"}', '{"ip":"203.0.113.4","portal":"admin"}', '01K2F2DKG0X63CT4426D8YEY5W'),
('2026-03-04 21:34:00', 1, 'admin', 'staff-1', NULL, 'account.type_changed', 'account', 57, 'account #48', '{"note":"see metadata"}', '{"ip":"203.0.113.104","portal":"admin"}', '01K2F2DKG0ZR06WVS3PXHQNDTM'),
('2026-04-17 12:09:00', 7, 'admin', 'staff-7', NULL, 'payout.approved', 'payout', 167, 'payout #39', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.243","portal":"admin"}', '01K2F2DKG0W9PNB3YQK7JS7717'),
('2026-08-11 17:32:00', 6, 'admin', 'staff-6', NULL, 'organization.suspended', 'organization', 351, 'organization #122', '{"note":"see metadata"}', '{"ip":"203.0.113.194","portal":"admin"}', '01K2F2DKG0Y06EN77WEVC7R72Y'),
('2026-04-22 03:30:00', 1, 'admin', 'staff-1', NULL, 'listing.approved', 'listing', 391, 'listing #41', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.105","portal":"admin"}', '01K2F2DKG00BD5BW1NWRQ2T7AJ'),
('2026-06-09 08:19:00', 1, 'admin', 'staff-1', NULL, 'api_client.created', 'api_client', 359, 'api_client #344', '{"note":"see metadata"}', '{"ip":"203.0.113.180","portal":"admin"}', '01K2F2DKG0CFM9BT312S9D3JMY'),
('2026-06-17 03:19:00', 3, 'admin', 'staff-3', NULL, 'organization.suspended', 'organization', 115, 'organization #35', '{"note":"see metadata"}', '{"ip":"203.0.113.99","portal":"admin"}', '01K2F2DKG0A19NDWJBHC27SHES'),
('2026-07-31 06:37:00', 2, 'admin', 'staff-2', NULL, 'payout.approved', 'payout', 47, 'payout #362', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.168","portal":"admin"}', '01K2F2DKG08V8TGV92BG8JZ9R3'),
('2026-08-07 17:38:00', 1, 'admin', 'staff-1', NULL, 'listing.approved', 'listing', 306, 'listing #27', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.69","portal":"admin"}', '01K2F2DKG0CQY8ZFX5WDT4D1X8'),
('2026-04-14 21:49:00', 3, 'admin', 'staff-3', NULL, 'listing.rejected', 'listing', 361, 'listing #72', '{"note":"see metadata"}', '{"ip":"203.0.113.5","portal":"admin"}', '01K2F2DKG0GZ6NGJQJFQJQ4FKJ'),
('2026-06-01 08:11:00', 5, 'admin', 'staff-5', NULL, 'listing.unpublished', 'listing', 293, 'listing #348', '{"note":"see metadata"}', '{"ip":"203.0.113.17","portal":"admin"}', '01K2F2DKG0Y82AM1J6DC3T9Q30'),
('2026-07-10 14:34:00', 6, 'admin', 'staff-6', NULL, 'user.suspended', 'user', 72, 'user #125', '{"note":"see metadata"}', '{"ip":"203.0.113.20","portal":"admin"}', '01K2F2DKG0C19KXMZQVA2RXYM7'),
('2026-07-22 09:03:00', 4, 'admin', 'staff-4', NULL, 'payment.refunded', 'payment', 43, 'payment #292', '{"note":"see metadata"}', '{"ip":"203.0.113.184","portal":"admin"}', '01K2F2DKG063FKK9RKQBE76BVH'),
('2026-06-28 01:58:00', 8, 'admin', 'staff-8', NULL, 'feature_flag.toggled', 'feature_flag', 39, 'feature_flag #73', '{"note":"see metadata"}', '{"ip":"203.0.113.101","portal":"admin"}', '01K2F2DKG0WHT4V2JY8M474A6P'),
('2026-06-28 20:12:00', 4, 'admin', 'staff-4', NULL, 'user.reinstated', 'user', 121, 'user #85', '{"note":"see metadata"}', '{"ip":"203.0.113.240","portal":"admin"}', '01K2F2DKG0V3CG7GZ3B2N9ZN29'),
('2026-03-13 16:57:00', 3, 'admin', 'staff-3', NULL, 'listing.unpublished', 'listing', 273, 'listing #46', '{"note":"see metadata"}', '{"ip":"203.0.113.13","portal":"admin"}', '01K2F2DKG0RWZ7G9RPS9XF9JP3'),
('2026-08-05 20:15:00', 4, 'admin', 'staff-4', NULL, 'category.updated', 'category', 331, 'category #180', '{"note":"see metadata"}', '{"ip":"203.0.113.217","portal":"admin"}', '01K2F2DKG0D3RAAHHXDGG1BM87'),
('2026-04-11 16:00:00', 6, 'admin', 'staff-6', NULL, 'listing.price_changed', 'listing', 377, 'listing #232', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.93","portal":"admin"}', '01K2F2DKG09F78AB1P1W1BJGY7'),
('2026-07-31 16:45:00', 7, 'admin', 'staff-7', NULL, 'listing.price_changed', 'listing', 51, 'listing #17', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.206","portal":"admin"}', '01K2F2DKG0YQ36DZ5MHBYQ3AT9'),
('2026-07-11 07:17:00', 2, 'admin', 'staff-2', NULL, 'api_client.created', 'api_client', 103, 'api_client #387', '{"note":"see metadata"}', '{"ip":"203.0.113.222","portal":"admin"}', '01K2F2DKG0NB9QV52BQVM0SBZZ'),
('2026-05-20 07:10:00', 1, 'admin', 'staff-1', NULL, 'category.updated', 'category', 196, 'category #234', '{"note":"see metadata"}', '{"ip":"203.0.113.240","portal":"admin"}', '01K2F2DKG04BC4NFRZ8Z84HKX4'),
('2026-08-09 14:55:00', 6, 'admin', 'staff-6', NULL, 'category.updated', 'category', 360, 'category #121', '{"note":"see metadata"}', '{"ip":"203.0.113.174","portal":"admin"}', '01K2F2DKG019H1M71TVC8528ZD'),
('2026-07-26 19:32:00', 5, 'admin', 'staff-5', NULL, 'organization.suspended', 'organization', 294, 'organization #222', '{"note":"see metadata"}', '{"ip":"203.0.113.50","portal":"admin"}', '01K2F2DKG09PYQKNN4B4QZRGAB'),
('2026-04-07 14:04:00', 5, 'admin', 'staff-5', NULL, 'api_client.created', 'api_client', 173, 'api_client #294', '{"note":"see metadata"}', '{"ip":"203.0.113.244","portal":"admin"}', '01K2F2DKG0SVR6P5RKVQX4BN36'),
('2026-08-01 00:48:00', 2, 'admin', 'staff-2', NULL, 'listing.unpublished', 'listing', 278, 'listing #236', '{"note":"see metadata"}', '{"ip":"203.0.113.81","portal":"admin"}', '01K2F2DKG07Z55QJTYJFFVRWMQ'),
('2026-07-19 10:34:00', 1, 'admin', 'staff-1', NULL, 'user.suspended', 'user', 37, 'user #114', '{"note":"see metadata"}', '{"ip":"203.0.113.112","portal":"admin"}', '01K2F2DKG0RD9JW2QBAJ22TPT6'),
('2026-04-05 09:52:00', 2, 'admin', 'staff-2', NULL, 'feature_flag.toggled', 'feature_flag', 110, 'feature_flag #74', '{"note":"see metadata"}', '{"ip":"203.0.113.202","portal":"admin"}', '01K2F2DKG079VCJS9MJR7KWKMY'),
('2026-07-09 13:15:00', 1, 'admin', 'staff-1', NULL, 'listing.unpublished', 'listing', 360, 'listing #78', '{"note":"see metadata"}', '{"ip":"203.0.113.74","portal":"admin"}', '01K2F2DKG00S9TF5573VWRQ5FQ'),
('2026-06-08 04:18:00', 5, 'admin', 'staff-5', NULL, 'listing.unpublished', 'listing', 179, 'listing #170', '{"note":"see metadata"}', '{"ip":"203.0.113.158","portal":"admin"}', '01K2F2DKG078BC853EBFD79ABW'),
('2026-02-27 19:49:00', 6, 'admin', 'staff-6', NULL, 'report.resolved', 'report', 150, 'report #74', '{"note":"see metadata"}', '{"ip":"203.0.113.240","portal":"admin"}', '01K2F2DKG0C9Z2MG1KRT9PRM28'),
('2026-03-09 10:20:00', 1, 'admin', 'staff-1', NULL, 'category.updated', 'category', 29, 'category #24', '{"note":"see metadata"}', '{"ip":"203.0.113.207","portal":"admin"}', '01K2F2DKG0SP7FNGY0BJ9Y29TS'),
('2026-04-27 15:04:00', 4, 'admin', 'staff-4', NULL, 'location.created', 'location', 195, 'location #66', '{"note":"see metadata"}', '{"ip":"203.0.113.139","portal":"admin"}', '01K2F2DKG0BYN382FR8GRVM77H'),
('2026-05-03 10:54:00', 3, 'admin', 'staff-3', NULL, 'api_client.created', 'api_client', 340, 'api_client #19', '{"note":"see metadata"}', '{"ip":"203.0.113.127","portal":"admin"}', '01K2F2DKG0GG3M2XCVK5NP8SSH'),
('2026-07-06 16:17:00', 5, 'admin', 'staff-5', NULL, 'category.updated', 'category', 26, 'category #226', '{"note":"see metadata"}', '{"ip":"203.0.113.128","portal":"admin"}', '01K2F2DKG0JKMN0A3RMAH0FQ6W'),
('2026-06-28 04:12:00', 2, 'admin', 'staff-2', NULL, 'listing.price_changed', 'listing', 337, 'listing #216', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.14","portal":"admin"}', '01K2F2DKG0TAXCC7S25NYWVG5V'),
('2026-07-20 18:50:00', 5, 'admin', 'staff-5', NULL, 'listing.rejected', 'listing', 122, 'listing #1', '{"note":"see metadata"}', '{"ip":"203.0.113.60","portal":"admin"}', '01K2F2DKG0XMWDZ1SCHRFSEDN4'),
('2026-03-01 20:21:00', 7, 'admin', 'staff-7', NULL, 'user.reinstated', 'user', 81, 'user #141', '{"note":"see metadata"}', '{"ip":"203.0.113.116","portal":"admin"}', '01K2F2DKG047GWNJ9D8EN5AKQH'),
('2026-03-28 21:21:00', 5, 'admin', 'staff-5', NULL, 'organization.verified', 'organization', 164, 'organization #162', '{"note":"see metadata"}', '{"ip":"203.0.113.23","portal":"admin"}', '01K2F2DKG07H4PHAK6YH0NT9Q3'),
('2026-08-04 15:27:00', 3, 'admin', 'staff-3', 5, 'user.impersonated', 'user', 342, 'user #205', '{"note":"see metadata"}', '{"ip":"203.0.113.58","portal":"admin"}', '01K2F2DKG0B6TQDESKDJ1TV8P5'),
('2026-06-23 03:35:00', 7, 'admin', 'staff-7', NULL, 'listing.unpublished', 'listing', 247, 'listing #238', '{"note":"see metadata"}', '{"ip":"203.0.113.199","portal":"admin"}', '01K2F2DKG02BS4P541NWBB1EFD'),
('2026-07-26 16:51:00', 2, 'admin', 'staff-2', NULL, 'user.reinstated', 'user', 398, 'user #113', '{"note":"see metadata"}', '{"ip":"203.0.113.139","portal":"admin"}', '01K2F2DKG0ZPAZY6MGSJ76EBT3'),
('2026-05-08 23:01:00', 2, 'admin', 'staff-2', NULL, 'category.updated', 'category', 20, 'category #138', '{"note":"see metadata"}', '{"ip":"203.0.113.52","portal":"admin"}', '01K2F2DKG05BDQBRMHWS2MCGRN'),
('2026-07-17 03:37:00', 4, 'admin', 'staff-4', NULL, 'feature_flag.toggled', 'feature_flag', 226, 'feature_flag #277', '{"note":"see metadata"}', '{"ip":"203.0.113.25","portal":"admin"}', '01K2F2DKG0JQ0FTYVASPAR9RTR'),
('2026-08-05 20:39:00', 5, 'admin', 'staff-5', NULL, 'listing.price_changed', 'listing', 130, 'listing #149', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.61","portal":"admin"}', '01K2F2DKG0KX722CDKGGV9HS7Y'),
('2026-08-01 14:10:00', 7, 'admin', 'staff-7', NULL, 'account.type_changed', 'account', 161, 'account #48', '{"note":"see metadata"}', '{"ip":"203.0.113.225","portal":"admin"}', '01K2F2DKG0KG6HZC6GEZ5BSHM7'),
('2026-03-24 09:14:00', 6, 'admin', 'staff-6', NULL, 'location.created', 'location', 79, 'location #317', '{"note":"see metadata"}', '{"ip":"203.0.113.134","portal":"admin"}', '01K2F2DKG0XKPJJ9VZK00EAV04'),
('2026-07-23 16:41:00', 7, 'admin', 'staff-7', NULL, 'listing.price_changed', 'listing', 20, 'listing #130', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.27","portal":"admin"}', '01K2F2DKG0F57NQSHYBPB929Z1'),
('2026-06-04 16:00:00', 3, 'admin', 'staff-3', NULL, 'payment.refunded', 'payment', 215, 'payment #294', '{"note":"see metadata"}', '{"ip":"203.0.113.32","portal":"admin"}', '01K2F2DKG0N4RV1MQYHP7YNT6S'),
('2026-05-06 04:45:00', 6, 'admin', 'staff-6', NULL, 'account.type_changed', 'account', 373, 'account #184', '{"note":"see metadata"}', '{"ip":"203.0.113.113","portal":"admin"}', '01K2F2DKG0QKXM3RGRQAFDEHD9'),
('2026-08-12 17:58:00', 3, 'admin', 'staff-3', NULL, 'payment.refunded', 'payment', 395, 'payment #241', '{"note":"see metadata"}', '{"ip":"203.0.113.33","portal":"admin"}', '01K2F2DKG0KQ6QJJQ6YPADY910'),
('2026-06-03 05:00:00', 5, 'admin', 'staff-5', NULL, 'feature_flag.toggled', 'feature_flag', 256, 'feature_flag #71', '{"note":"see metadata"}', '{"ip":"203.0.113.125","portal":"admin"}', '01K2F2DKG06XRM9RQR3EDC46RY'),
('2026-06-05 12:47:00', 4, 'admin', 'staff-4', NULL, 'organization.verified', 'organization', 260, 'organization #303', '{"note":"see metadata"}', '{"ip":"203.0.113.144","portal":"admin"}', '01K2F2DKG00TMJZSAS64KDKG8J'),
('2026-07-26 07:31:00', 1, 'admin', 'staff-1', NULL, 'listing.unpublished', 'listing', 325, 'listing #317', '{"note":"see metadata"}', '{"ip":"203.0.113.25","portal":"admin"}', '01K2F2DKG0483HGWSB421Z62SC'),
('2026-06-10 07:46:00', 3, 'admin', 'staff-3', NULL, 'listing.price_changed', 'listing', 294, 'listing #13', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.166","portal":"admin"}', '01K2F2DKG0DD3WGBCQ8PZDW4K9'),
('2026-07-28 23:21:00', 8, 'admin', 'staff-8', NULL, 'account.type_changed', 'account', 34, 'account #369', '{"note":"see metadata"}', '{"ip":"203.0.113.219","portal":"admin"}', '01K2F2DKG01YZ5P5VZARKBMCY7'),
('2026-07-05 12:20:00', 3, 'admin', 'staff-3', NULL, 'api_client.created', 'api_client', 2, 'api_client #350', '{"note":"see metadata"}', '{"ip":"203.0.113.27","portal":"admin"}', '01K2F2DKG0MA3VFCKJSHYHRJP6'),
('2026-07-18 00:14:00', 2, 'admin', 'staff-2', NULL, 'user.suspended', 'user', 130, 'user #102', '{"note":"see metadata"}', '{"ip":"203.0.113.61","portal":"admin"}', '01K2F2DKG0ZEECWPV6ETKMEXA4'),
('2026-07-25 21:56:00', 6, 'admin', 'staff-6', NULL, 'category.updated', 'category', 43, 'category #193', '{"note":"see metadata"}', '{"ip":"203.0.113.22","portal":"admin"}', '01K2F2DKG060NZJD181N6V6DZG'),
('2026-05-24 10:55:00', 2, 'admin', 'staff-2', NULL, 'organization.verified', 'organization', 307, 'organization #29', '{"note":"see metadata"}', '{"ip":"203.0.113.69","portal":"admin"}', '01K2F2DKG0FWJ1C8H5GE0ZM8JC'),
('2026-04-17 18:44:00', 8, 'admin', 'staff-8', NULL, 'location.created', 'location', 242, 'location #234', '{"note":"see metadata"}', '{"ip":"203.0.113.200","portal":"admin"}', '01K2F2DKG0FFNG7EH93DKBF467'),
('2026-03-23 22:11:00', 1, 'admin', 'staff-1', NULL, 'location.created', 'location', 265, 'location #346', '{"note":"see metadata"}', '{"ip":"203.0.113.169","portal":"admin"}', '01K2F2DKG0FKBATB1XPHFRR537'),
('2026-07-26 05:03:00', 1, 'admin', 'staff-1', NULL, 'user.reinstated', 'user', 161, 'user #338', '{"note":"see metadata"}', '{"ip":"203.0.113.16","portal":"admin"}', '01K2F2DKG0BM0CWMPHEQ481WN4'),
('2026-07-29 08:27:00', 1, 'admin', 'staff-1', NULL, 'category.updated', 'category', 171, 'category #385', '{"note":"see metadata"}', '{"ip":"203.0.113.1","portal":"admin"}', '01K2F2DKG002MYPFRGGX2MAVRX'),
('2026-07-22 13:14:00', 7, 'admin', 'staff-7', NULL, 'category.updated', 'category', 268, 'category #322', '{"note":"see metadata"}', '{"ip":"203.0.113.157","portal":"admin"}', '01K2F2DKG0RCYXXK7D605HRXJW'),
('2026-04-10 04:55:00', 7, 'admin', 'staff-7', NULL, 'settings.updated', 'setting', 94, 'setting #339', '{"note":"see metadata"}', '{"ip":"203.0.113.208","portal":"admin"}', '01K2F2DKG003997N8FESV7G574'),
('2026-05-08 19:09:00', 6, 'admin', 'staff-6', NULL, 'payment.refunded', 'payment', 214, 'payment #147', '{"note":"see metadata"}', '{"ip":"203.0.113.55","portal":"admin"}', '01K2F2DKG0NQBHQN7SPV2QG23Q'),
('2026-04-11 00:25:00', 3, 'admin', 'staff-3', 5, 'user.impersonated', 'user', 362, 'user #169', '{"note":"see metadata"}', '{"ip":"203.0.113.118","portal":"admin"}', '01K2F2DKG03MK258RE1VET8XNW'),
('2026-03-25 11:10:00', 1, 'admin', 'staff-1', NULL, 'organization.suspended', 'organization', 37, 'organization #101', '{"note":"see metadata"}', '{"ip":"203.0.113.170","portal":"admin"}', '01K2F2DKG0C3B835XHAQRSPRCH'),
('2026-05-11 10:03:00', 5, 'admin', 'staff-5', 5, 'user.impersonated', 'user', 30, 'user #79', '{"note":"see metadata"}', '{"ip":"203.0.113.134","portal":"admin"}', '01K2F2DKG0PNYYJD362CDDYEB1'),
('2026-05-06 10:53:00', 8, 'admin', 'staff-8', NULL, 'report.resolved', 'report', 114, 'report #204', '{"note":"see metadata"}', '{"ip":"203.0.113.218","portal":"admin"}', '01K2F2DKG02E4V4Y2KM3G1FTHW'),
('2026-05-11 14:16:00', 2, 'admin', 'staff-2', NULL, 'report.resolved', 'report', 167, 'report #13', '{"note":"see metadata"}', '{"ip":"203.0.113.197","portal":"admin"}', '01K2F2DKG0M4K7H9GV1C9EC6RF'),
('2026-06-19 13:39:00', 6, 'admin', 'staff-6', NULL, 'listing.unpublished', 'listing', 234, 'listing #78', '{"note":"see metadata"}', '{"ip":"203.0.113.206","portal":"admin"}', '01K2F2DKG0EXEBY65GFZGVMY5N'),
('2026-07-04 07:55:00', 1, 'admin', 'staff-1', NULL, 'listing.rejected', 'listing', 111, 'listing #345', '{"note":"see metadata"}', '{"ip":"203.0.113.192","portal":"admin"}', '01K2F2DKG0A67SS8MJ6X128XF3'),
('2026-06-28 15:11:00', 4, 'admin', 'staff-4', NULL, 'api_client.created', 'api_client', 295, 'api_client #24', '{"note":"see metadata"}', '{"ip":"203.0.113.93","portal":"admin"}', '01K2F2DKG0Z5WKS8R3N9KB87QP'),
('2026-08-04 22:40:00', 1, 'admin', 'staff-1', NULL, 'account.type_changed', 'account', 245, 'account #79', '{"note":"see metadata"}', '{"ip":"203.0.113.34","portal":"admin"}', '01K2F2DKG0AFVARBXXA4QNQXT3'),
('2026-05-01 16:19:00', 4, 'admin', 'staff-4', NULL, 'listing.rejected', 'listing', 1, 'listing #298', '{"note":"see metadata"}', '{"ip":"203.0.113.172","portal":"admin"}', '01K2F2DKG0ZEJCVBT2PSE3FT87'),
('2026-06-21 15:20:00', 4, 'admin', 'staff-4', NULL, 'listing.unpublished', 'listing', 24, 'listing #293', '{"note":"see metadata"}', '{"ip":"203.0.113.200","portal":"admin"}', '01K2F2DKG0TM5N6D4YKWCXEPFW'),
('2026-03-22 14:56:00', 8, 'admin', 'staff-8', NULL, 'payment.refunded', 'payment', 23, 'payment #103', '{"note":"see metadata"}', '{"ip":"203.0.113.131","portal":"admin"}', '01K2F2DKG0XYZB5N9B28NV72YB'),
('2026-05-06 05:15:00', 8, 'admin', 'staff-8', NULL, 'organization.verified', 'organization', 67, 'organization #214', '{"note":"see metadata"}', '{"ip":"203.0.113.41","portal":"admin"}', '01K2F2DKG0QKGJKYNYZZKF836Q'),
('2026-06-14 19:26:00', 2, 'admin', 'staff-2', NULL, 'payout.approved', 'payout', 381, 'payout #50', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.126","portal":"admin"}', '01K2F2DKG07YGM7VJN020525NQ'),
('2026-03-25 14:53:00', 3, 'admin', 'staff-3', NULL, 'organization.suspended', 'organization', 169, 'organization #61', '{"note":"see metadata"}', '{"ip":"203.0.113.222","portal":"admin"}', '01K2F2DKG07HH134Q30DBWTFAP'),
('2026-06-06 23:24:00', 8, 'admin', 'staff-8', NULL, 'organization.suspended', 'organization', 141, 'organization #392', '{"note":"see metadata"}', '{"ip":"203.0.113.131","portal":"admin"}', '01K2F2DKG0DNG93D9ZSTTBEB50'),
('2026-03-29 21:46:00', 5, 'admin', 'staff-5', NULL, 'feature_flag.toggled', 'feature_flag', 154, 'feature_flag #260', '{"note":"see metadata"}', '{"ip":"203.0.113.44","portal":"admin"}', '01K2F2DKG0M2JTVZPG17QAQ91W'),
('2026-04-08 23:11:00', 6, 'admin', 'staff-6', NULL, 'location.created', 'location', 237, 'location #261', '{"note":"see metadata"}', '{"ip":"203.0.113.49","portal":"admin"}', '01K2F2DKG04VKKM8057ETKA41X'),
('2026-06-13 06:26:00', 6, 'admin', 'staff-6', NULL, 'settings.updated', 'setting', 301, 'setting #77', '{"note":"see metadata"}', '{"ip":"203.0.113.186","portal":"admin"}', '01K2F2DKG02MY4P2F5HR5SBM48'),
('2026-06-20 17:58:00', 4, 'admin', 'staff-4', NULL, 'listing.unpublished', 'listing', 70, 'listing #301', '{"note":"see metadata"}', '{"ip":"203.0.113.72","portal":"admin"}', '01K2F2DKG004HYW9EEGM7ZEF6X'),
('2026-07-16 18:00:00', 6, 'admin', 'staff-6', NULL, 'organization.verified', 'organization', 294, 'organization #313', '{"note":"see metadata"}', '{"ip":"203.0.113.3","portal":"admin"}', '01K2F2DKG004SQXPMAMF3TPKYE'),
('2026-04-27 23:27:00', 3, 'admin', 'staff-3', NULL, 'account.type_changed', 'account', 185, 'account #140', '{"note":"see metadata"}', '{"ip":"203.0.113.52","portal":"admin"}', '01K2F2DKG0FNWJCJKWN8JTZAD3'),
('2026-03-18 15:22:00', 1, 'admin', 'staff-1', NULL, 'listing.approved', 'listing', 7, 'listing #370', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.158","portal":"admin"}', '01K2F2DKG0RE3CGJPPGXANZ35C'),
('2026-07-20 18:37:00', 5, 'admin', 'staff-5', NULL, 'payout.approved', 'payout', 276, 'payout #291', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.221","portal":"admin"}', '01K2F2DKG0GMC3FAD9Z954XJGT'),
('2026-05-16 05:14:00', 5, 'admin', 'staff-5', NULL, 'listing.approved', 'listing', 2, 'listing #6', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.107","portal":"admin"}', '01K2F2DKG0BJ65CEHYY4Y4J985'),
('2026-07-11 00:49:00', 1, 'admin', 'staff-1', NULL, 'account.type_changed', 'account', 301, 'account #367', '{"note":"see metadata"}', '{"ip":"203.0.113.214","portal":"admin"}', '01K2F2DKG05P7P5JC2KHSRWGZ8'),
('2026-05-04 16:59:00', 3, 'admin', 'staff-3', NULL, 'payout.approved', 'payout', 108, 'payout #233', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.179","portal":"admin"}', '01K2F2DKG0RFXHJKVX4M5HD156'),
('2026-04-01 21:20:00', 6, 'admin', 'staff-6', NULL, 'payment.refunded', 'payment', 171, 'payment #130', '{"note":"see metadata"}', '{"ip":"203.0.113.95","portal":"admin"}', '01K2F2DKG0TTK0F8J2CRZ268JH'),
('2026-06-25 01:18:00', 5, 'admin', 'staff-5', NULL, 'feature_flag.toggled', 'feature_flag', 346, 'feature_flag #196', '{"note":"see metadata"}', '{"ip":"203.0.113.91","portal":"admin"}', '01K2F2DKG0VJG7W6C1Q1TH2S3Z'),
('2026-06-08 01:10:00', 2, 'admin', 'staff-2', NULL, 'listing.approved', 'listing', 241, 'listing #39', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.109","portal":"admin"}', '01K2F2DKG0K2BWRFW0AWXEEQ3N'),
('2026-03-28 23:54:00', 7, 'admin', 'staff-7', NULL, 'account.type_changed', 'account', 173, 'account #149', '{"note":"see metadata"}', '{"ip":"203.0.113.39","portal":"admin"}', '01K2F2DKG0TNR3Y8KM2D8ZCHZY'),
('2026-06-01 18:04:00', 7, 'admin', 'staff-7', 5, 'user.impersonated', 'user', 260, 'user #65', '{"note":"see metadata"}', '{"ip":"203.0.113.13","portal":"admin"}', '01K2F2DKG0XCQ4VSAQXXPWB5GC'),
('2026-07-08 09:21:00', 1, 'admin', 'staff-1', NULL, 'user.suspended', 'user', 61, 'user #96', '{"note":"see metadata"}', '{"ip":"203.0.113.176","portal":"admin"}', '01K2F2DKG0TVZP50WW1E7JY96F'),
('2026-05-07 14:38:00', 3, 'admin', 'staff-3', 5, 'user.impersonated', 'user', 107, 'user #104', '{"note":"see metadata"}', '{"ip":"203.0.113.145","portal":"admin"}', '01K2F2DKG0C730Q0EVHFHPE117'),
('2026-04-08 23:11:00', 8, 'admin', 'staff-8', NULL, 'account.type_changed', 'account', 207, 'account #59', '{"note":"see metadata"}', '{"ip":"203.0.113.184","portal":"admin"}', '01K2F2DKG02CBHHCCX9STZPV4V'),
('2026-08-05 14:44:00', 2, 'admin', 'staff-2', NULL, 'feature_flag.toggled', 'feature_flag', 242, 'feature_flag #167', '{"note":"see metadata"}', '{"ip":"203.0.113.188","portal":"admin"}', '01K2F2DKG04TFHRK81KPP32928'),
('2026-03-16 09:32:00', 8, 'admin', 'staff-8', NULL, 'organization.verified', 'organization', 225, 'organization #197', '{"note":"see metadata"}', '{"ip":"203.0.113.94","portal":"admin"}', '01K2F2DKG0PMTA029BYQPY172K'),
('2026-07-04 05:16:00', 6, 'admin', 'staff-6', NULL, 'listing.unpublished', 'listing', 26, 'listing #55', '{"note":"see metadata"}', '{"ip":"203.0.113.197","portal":"admin"}', '01K2F2DKG0QCK10Y0AVTVX1PWY'),
('2026-05-04 15:53:00', 6, 'admin', 'staff-6', NULL, 'user.reinstated', 'user', 327, 'user #175', '{"note":"see metadata"}', '{"ip":"203.0.113.41","portal":"admin"}', '01K2F2DKG0NTPV9QAVM7NBRQZJ'),
('2026-03-01 20:18:00', 2, 'admin', 'staff-2', NULL, 'listing.approved', 'listing', 193, 'listing #23', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.7","portal":"admin"}', '01K2F2DKG06DP974TA9FR8NR71'),
('2026-05-15 08:14:00', 2, 'admin', 'staff-2', NULL, 'api_client.created', 'api_client', 30, 'api_client #246', '{"note":"see metadata"}', '{"ip":"203.0.113.235","portal":"admin"}', '01K2F2DKG0FGRVY9DED9D11JM7'),
('2026-05-03 01:21:00', 4, 'admin', 'staff-4', NULL, 'organization.verified', 'organization', 222, 'organization #319', '{"note":"see metadata"}', '{"ip":"203.0.113.27","portal":"admin"}', '01K2F2DKG0D52H9BTAPBSWF1DW'),
('2026-04-22 13:07:00', 5, 'admin', 'staff-5', NULL, 'api_client.created', 'api_client', 283, 'api_client #41', '{"note":"see metadata"}', '{"ip":"203.0.113.149","portal":"admin"}', '01K2F2DKG0CVXFBZW8WZFE5WCE'),
('2026-07-07 01:32:00', 6, 'admin', 'staff-6', NULL, 'account.type_changed', 'account', 249, 'account #212', '{"note":"see metadata"}', '{"ip":"203.0.113.79","portal":"admin"}', '01K2F2DKG08MGRMW2P6P83KR1J'),
('2026-06-16 01:09:00', 4, 'admin', 'staff-4', NULL, 'feature_flag.toggled', 'feature_flag', 100, 'feature_flag #265', '{"note":"see metadata"}', '{"ip":"203.0.113.83","portal":"admin"}', '01K2F2DKG01X03V60S9K8Y69HA'),
('2026-04-29 21:54:00', 4, 'admin', 'staff-4', NULL, 'user.suspended', 'user', 279, 'user #350', '{"note":"see metadata"}', '{"ip":"203.0.113.168","portal":"admin"}', '01K2F2DKG09ZXX6FA5KSGVF4TX'),
('2026-07-20 17:44:00', 3, 'admin', 'staff-3', NULL, 'listing.price_changed', 'listing', 388, 'listing #136', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.109","portal":"admin"}', '01K2F2DKG01XJX5E01RJVARQBW'),
('2026-06-16 00:12:00', 5, 'admin', 'staff-5', NULL, 'listing.price_changed', 'listing', 163, 'listing #149', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.218","portal":"admin"}', '01K2F2DKG0CVWVWJN66P8F88FD'),
('2026-05-30 20:38:00', 7, 'admin', 'staff-7', NULL, 'user.suspended', 'user', 171, 'user #301', '{"note":"see metadata"}', '{"ip":"203.0.113.184","portal":"admin"}', '01K2F2DKG03XJ13MDJAHHDYRNW'),
('2026-07-31 12:25:00', 7, 'admin', 'staff-7', NULL, 'organization.suspended', 'organization', 315, 'organization #182', '{"note":"see metadata"}', '{"ip":"203.0.113.67","portal":"admin"}', '01K2F2DKG0ZECN391YBCZFWBWT'),
('2026-02-28 21:00:00', 3, 'admin', 'staff-3', NULL, 'listing.rejected', 'listing', 235, 'listing #200', '{"note":"see metadata"}', '{"ip":"203.0.113.237","portal":"admin"}', '01K2F2DKG0NHA3WTA67FPJNGS5'),
('2026-07-21 08:35:00', 2, 'admin', 'staff-2', NULL, 'payment.refunded', 'payment', 290, 'payment #390', '{"note":"see metadata"}', '{"ip":"203.0.113.34","portal":"admin"}', '01K2F2DKG0QJFWB0TQRRY931HE'),
('2026-05-13 20:43:00', 3, 'admin', 'staff-3', NULL, 'settings.updated', 'setting', 340, 'setting #55', '{"note":"see metadata"}', '{"ip":"203.0.113.101","portal":"admin"}', '01K2F2DKG095YMVNS7PCC5RPTK'),
('2026-03-11 09:08:00', 7, 'admin', 'staff-7', NULL, 'listing.price_changed', 'listing', 70, 'listing #71', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.27","portal":"admin"}', '01K2F2DKG0CKMQF9SED2EX11KR'),
('2026-03-16 04:13:00', 7, 'admin', 'staff-7', NULL, 'account.type_changed', 'account', 149, 'account #391', '{"note":"see metadata"}', '{"ip":"203.0.113.162","portal":"admin"}', '01K2F2DKG0DNFEYMCWJ8QB4TKY'),
('2026-07-01 12:40:00', 8, 'admin', 'staff-8', NULL, 'organization.suspended', 'organization', 373, 'organization #159', '{"note":"see metadata"}', '{"ip":"203.0.113.242","portal":"admin"}', '01K2F2DKG0K37T3HH8ZE4GSR8H'),
('2026-06-14 08:33:00', 8, 'admin', 'staff-8', NULL, 'listing.price_changed', 'listing', 380, 'listing #356', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.218","portal":"admin"}', '01K2F2DKG07927977APFHN2EA5'),
('2026-08-01 15:20:00', 8, 'admin', 'staff-8', NULL, 'payout.approved', 'payout', 183, 'payout #297', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.87","portal":"admin"}', '01K2F2DKG0D4E8101C97JQPMSZ'),
('2026-03-21 15:03:00', 4, 'admin', 'staff-4', NULL, 'organization.suspended', 'organization', 60, 'organization #92', '{"note":"see metadata"}', '{"ip":"203.0.113.131","portal":"admin"}', '01K2F2DKG0ENTCQX2DTMBQGSV6'),
('2026-05-04 15:50:00', 5, 'admin', 'staff-5', NULL, 'api_client.created', 'api_client', 4, 'api_client #172', '{"note":"see metadata"}', '{"ip":"203.0.113.109","portal":"admin"}', '01K2F2DKG04GV1HKS913T8SBZ9'),
('2026-07-12 00:23:00', 4, 'admin', 'staff-4', NULL, 'payment.refunded', 'payment', 82, 'payment #128', '{"note":"see metadata"}', '{"ip":"203.0.113.184","portal":"admin"}', '01K2F2DKG0BK3DS621D8817JS4'),
('2026-03-09 05:02:00', 7, 'admin', 'staff-7', NULL, 'feature_flag.toggled', 'feature_flag', 329, 'feature_flag #152', '{"note":"see metadata"}', '{"ip":"203.0.113.202","portal":"admin"}', '01K2F2DKG0PFG16TBKTDYRN0N6'),
('2026-06-13 19:46:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 233, 'location #161', '{"note":"see metadata"}', '{"ip":"203.0.113.170","portal":"admin"}', '01K2F2DKG0MY8Q7MACC9H8BZ30'),
('2026-04-07 14:26:00', 6, 'admin', 'staff-6', NULL, 'payout.approved', 'payout', 236, 'payout #170', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.16","portal":"admin"}', '01K2F2DKG04G65XT4W0HPXAYDQ'),
('2026-08-15 23:53:00', 2, 'admin', 'staff-2', 5, 'user.impersonated', 'user', 389, 'user #351', '{"note":"see metadata"}', '{"ip":"203.0.113.61","portal":"admin"}', '01K2F2DKG0FP4JNAA2XW4VP6KA'),
('2026-03-12 09:03:00', 8, 'admin', 'staff-8', NULL, 'location.created', 'location', 355, 'location #327', '{"note":"see metadata"}', '{"ip":"203.0.113.98","portal":"admin"}', '01K2F2DKG0S2M01RDAYS1D6ETC'),
('2026-03-31 14:04:00', 7, 'admin', 'staff-7', NULL, 'user.reinstated', 'user', 252, 'user #309', '{"note":"see metadata"}', '{"ip":"203.0.113.93","portal":"admin"}', '01K2F2DKG0EZBSE33F8QFS7M3X'),
('2026-04-16 01:29:00', 2, 'admin', 'staff-2', NULL, 'settings.updated', 'setting', 324, 'setting #223', '{"note":"see metadata"}', '{"ip":"203.0.113.8","portal":"admin"}', '01K2F2DKG082YJG55SKJSH6WRS'),
('2026-07-09 19:12:00', 5, 'admin', 'staff-5', NULL, 'settings.updated', 'setting', 338, 'setting #74', '{"note":"see metadata"}', '{"ip":"203.0.113.138","portal":"admin"}', '01K2F2DKG0CR5F7CXY9MJSKHRJ'),
('2026-03-25 16:18:00', 8, 'admin', 'staff-8', NULL, 'user.suspended', 'user', 229, 'user #165', '{"note":"see metadata"}', '{"ip":"203.0.113.23","portal":"admin"}', '01K2F2DKG017MDQ4WYK0Q9HXPG'),
('2026-05-06 09:06:00', 7, 'admin', 'staff-7', NULL, 'listing.price_changed', 'listing', 31, 'listing #302', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.222","portal":"admin"}', '01K2F2DKG0157CPSGCF05KD7F1'),
('2026-06-29 21:10:00', 1, 'admin', 'staff-1', NULL, 'organization.verified', 'organization', 82, 'organization #358', '{"note":"see metadata"}', '{"ip":"203.0.113.77","portal":"admin"}', '01K2F2DKG00NHCA4C5TQTTY9G6'),
('2026-04-07 05:08:00', 6, 'admin', 'staff-6', NULL, 'location.created', 'location', 40, 'location #10', '{"note":"see metadata"}', '{"ip":"203.0.113.27","portal":"admin"}', '01K2F2DKG0HD9771HAXX2G2A82'),
('2026-05-16 15:52:00', 3, 'admin', 'staff-3', NULL, 'account.type_changed', 'account', 371, 'account #179', '{"note":"see metadata"}', '{"ip":"203.0.113.64","portal":"admin"}', '01K2F2DKG07M3NRA5PD8TA2S7Z'),
('2026-05-31 22:57:00', 6, 'admin', 'staff-6', NULL, 'listing.price_changed', 'listing', 234, 'listing #317', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.210","portal":"admin"}', '01K2F2DKG0C6KZK7993SWDYRP2'),
('2026-05-04 13:28:00', 1, 'admin', 'staff-1', NULL, 'payment.refunded', 'payment', 330, 'payment #367', '{"note":"see metadata"}', '{"ip":"203.0.113.162","portal":"admin"}', '01K2F2DKG0J8Z3GXG94CJNFR10'),
('2026-05-27 18:48:00', 4, 'admin', 'staff-4', NULL, 'location.created', 'location', 340, 'location #69', '{"note":"see metadata"}', '{"ip":"203.0.113.39","portal":"admin"}', '01K2F2DKG0TPKGPK7ADSW3XMNR'),
('2026-04-13 21:29:00', 3, 'admin', 'staff-3', NULL, 'organization.suspended', 'organization', 184, 'organization #211', '{"note":"see metadata"}', '{"ip":"203.0.113.213","portal":"admin"}', '01K2F2DKG0NWDGCRRT135NV7BJ'),
('2026-05-09 06:20:00', 3, 'admin', 'staff-3', NULL, 'listing.unpublished', 'listing', 340, 'listing #180', '{"note":"see metadata"}', '{"ip":"203.0.113.25","portal":"admin"}', '01K2F2DKG0TFFNSNXE9NSB025S'),
('2026-07-28 12:09:00', 6, 'admin', 'staff-6', NULL, 'organization.verified', 'organization', 349, 'organization #289', '{"note":"see metadata"}', '{"ip":"203.0.113.41","portal":"admin"}', '01K2F2DKG0BS11857P084X36T4'),
('2026-07-15 20:49:00', 5, 'admin', 'staff-5', NULL, 'report.resolved', 'report', 384, 'report #162', '{"note":"see metadata"}', '{"ip":"203.0.113.36","portal":"admin"}', '01K2F2DKG021DNEGZM3JGHEYMD'),
('2026-06-26 15:41:00', 5, 'admin', 'staff-5', NULL, 'report.resolved', 'report', 244, 'report #298', '{"note":"see metadata"}', '{"ip":"203.0.113.170","portal":"admin"}', '01K2F2DKG0QYY8WGGPMRT9823S'),
('2026-07-11 12:02:00', 5, 'admin', 'staff-5', NULL, 'listing.price_changed', 'listing', 109, 'listing #239', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.75","portal":"admin"}', '01K2F2DKG0H91R5NAH97CJGDPD'),
('2026-08-14 09:19:00', 2, 'admin', 'staff-2', 5, 'user.impersonated', 'user', 292, 'user #167', '{"note":"see metadata"}', '{"ip":"203.0.113.128","portal":"admin"}', '01K2F2DKG0SG4S8NCN01QD95SW'),
('2026-04-17 03:18:00', 1, 'admin', 'staff-1', NULL, 'payout.approved', 'payout', 327, 'payout #242', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.129","portal":"admin"}', '01K2F2DKG0HKEPGAP8CPZSAZ1J'),
('2026-07-09 11:08:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 226, 'location #354', '{"note":"see metadata"}', '{"ip":"203.0.113.7","portal":"admin"}', '01K2F2DKG02129AP9E1A1BMWQ0'),
('2026-05-23 22:01:00', 5, 'admin', 'staff-5', NULL, 'listing.price_changed', 'listing', 67, 'listing #299', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.212","portal":"admin"}', '01K2F2DKG02SXFNRC3SSV648H8'),
('2026-05-09 22:58:00', 6, 'admin', 'staff-6', NULL, 'organization.suspended', 'organization', 208, 'organization #128', '{"note":"see metadata"}', '{"ip":"203.0.113.118","portal":"admin"}', '01K2F2DKG0VRP3JW4QQ3PHD18M'),
('2026-03-14 21:09:00', 5, 'admin', 'staff-5', NULL, 'organization.suspended', 'organization', 294, 'organization #254', '{"note":"see metadata"}', '{"ip":"203.0.113.157","portal":"admin"}', '01K2F2DKG0X8XKHVQ42561AA30'),
('2026-04-30 07:39:00', 2, 'admin', 'staff-2', NULL, 'user.reinstated', 'user', 235, 'user #353', '{"note":"see metadata"}', '{"ip":"203.0.113.56","portal":"admin"}', '01K2F2DKG0JW0Q9CKXSK1ESFP0'),
('2026-03-03 06:19:00', 6, 'admin', 'staff-6', NULL, 'user.reinstated', 'user', 97, 'user #353', '{"note":"see metadata"}', '{"ip":"203.0.113.207","portal":"admin"}', '01K2F2DKG0B752EMDCCTS4S0MR'),
('2026-07-16 14:41:00', 7, 'admin', 'staff-7', NULL, 'listing.rejected', 'listing', 139, 'listing #238', '{"note":"see metadata"}', '{"ip":"203.0.113.89","portal":"admin"}', '01K2F2DKG0GW1J53YGE028E3DH'),
('2026-05-17 21:32:00', 8, 'admin', 'staff-8', NULL, 'payout.approved', 'payout', 238, 'payout #169', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.248","portal":"admin"}', '01K2F2DKG06R3YAH4KZ9GZNK90'),
('2026-05-21 23:57:00', 8, 'admin', 'staff-8', NULL, 'listing.unpublished', 'listing', 130, 'listing #361', '{"note":"see metadata"}', '{"ip":"203.0.113.131","portal":"admin"}', '01K2F2DKG0GN24ZTSMGNJDP9C3'),
('2026-06-03 00:03:00', 6, 'admin', 'staff-6', NULL, 'organization.verified', 'organization', 234, 'organization #351', '{"note":"see metadata"}', '{"ip":"203.0.113.237","portal":"admin"}', '01K2F2DKG0FX83AEESCH1JNYMX'),
('2026-03-20 15:05:00', 8, 'admin', 'staff-8', NULL, 'feature_flag.toggled', 'feature_flag', 111, 'feature_flag #248', '{"note":"see metadata"}', '{"ip":"203.0.113.27","portal":"admin"}', '01K2F2DKG0Y5V55MTW8VEPKT8W'),
('2026-08-04 17:51:00', 2, 'admin', 'staff-2', NULL, 'listing.approved', 'listing', 191, 'listing #215', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.200","portal":"admin"}', '01K2F2DKG070S9C47WZJGB63Q9'),
('2026-08-05 01:25:00', 3, 'admin', 'staff-3', NULL, 'organization.verified', 'organization', 274, 'organization #193', '{"note":"see metadata"}', '{"ip":"203.0.113.112","portal":"admin"}', '01K2F2DKG0XYKGJ0RBYB1MXQ22'),
('2026-04-04 10:51:00', 8, 'admin', 'staff-8', NULL, 'api_client.created', 'api_client', 79, 'api_client #315', '{"note":"see metadata"}', '{"ip":"203.0.113.195","portal":"admin"}', '01K2F2DKG0BAK0T7MREBTV5M2D'),
('2026-07-11 19:25:00', 4, 'admin', 'staff-4', NULL, 'category.updated', 'category', 189, 'category #394', '{"note":"see metadata"}', '{"ip":"203.0.113.15","portal":"admin"}', '01K2F2DKG029KSHP9213HTYW6S'),
('2026-03-03 23:44:00', 5, 'admin', 'staff-5', NULL, 'account.type_changed', 'account', 165, 'account #142', '{"note":"see metadata"}', '{"ip":"203.0.113.47","portal":"admin"}', '01K2F2DKG0JZNHBGRJGNJF01GW'),
('2026-07-08 00:06:00', 8, 'admin', 'staff-8', NULL, 'user.reinstated', 'user', 235, 'user #354', '{"note":"see metadata"}', '{"ip":"203.0.113.75","portal":"admin"}', '01K2F2DKG05JYKMJ7VKFT0HW95'),
('2026-05-15 14:04:00', 8, 'admin', 'staff-8', NULL, 'user.reinstated', 'user', 245, 'user #81', '{"note":"see metadata"}', '{"ip":"203.0.113.192","portal":"admin"}', '01K2F2DKG0AFVJSA04JHEVPXPG'),
('2026-08-07 07:16:00', 8, 'admin', 'staff-8', 5, 'user.impersonated', 'user', 279, 'user #335', '{"note":"see metadata"}', '{"ip":"203.0.113.216","portal":"admin"}', '01K2F2DKG0H0ZZG9NCE29MMXMY'),
('2026-03-22 03:12:00', 1, 'admin', 'staff-1', NULL, 'user.reinstated', 'user', 123, 'user #323', '{"note":"see metadata"}', '{"ip":"203.0.113.221","portal":"admin"}', '01K2F2DKG0GD16S81JPWK3Z0NW'),
('2026-05-23 23:12:00', 2, 'admin', 'staff-2', NULL, 'listing.rejected', 'listing', 49, 'listing #351', '{"note":"see metadata"}', '{"ip":"203.0.113.37","portal":"admin"}', '01K2F2DKG0ZXF6ZQZ762X93Y7A'),
('2026-05-27 11:26:00', 1, 'admin', 'staff-1', NULL, 'feature_flag.toggled', 'feature_flag', 182, 'feature_flag #267', '{"note":"see metadata"}', '{"ip":"203.0.113.9","portal":"admin"}', '01K2F2DKG0NMX11YBKJ98BFWTT'),
('2026-05-30 15:05:00', 6, 'admin', 'staff-6', NULL, 'settings.updated', 'setting', 23, 'setting #152', '{"note":"see metadata"}', '{"ip":"203.0.113.22","portal":"admin"}', '01K2F2DKG03TC3ZSSJE7D72HHZ'),
('2026-07-24 22:50:00', 4, 'admin', 'staff-4', NULL, 'organization.verified', 'organization', 338, 'organization #86', '{"note":"see metadata"}', '{"ip":"203.0.113.26","portal":"admin"}', '01K2F2DKG0DTAV47SCBMZJXZKY'),
('2026-03-16 13:06:00', 8, 'admin', 'staff-8', NULL, 'listing.unpublished', 'listing', 135, 'listing #177', '{"note":"see metadata"}', '{"ip":"203.0.113.48","portal":"admin"}', '01K2F2DKG0E66321TEXFB39TQV'),
('2026-05-02 19:27:00', 1, 'admin', 'staff-1', NULL, 'feature_flag.toggled', 'feature_flag', 127, 'feature_flag #170', '{"note":"see metadata"}', '{"ip":"203.0.113.181","portal":"admin"}', '01K2F2DKG0ADY333NKWBQDVR6A'),
('2026-04-03 01:42:00', 6, 'admin', 'staff-6', 5, 'user.impersonated', 'user', 59, 'user #118', '{"note":"see metadata"}', '{"ip":"203.0.113.243","portal":"admin"}', '01K2F2DKG016Q0HA324ZXSJSWP'),
('2026-05-28 08:53:00', 6, 'admin', 'staff-6', NULL, 'payment.refunded', 'payment', 311, 'payment #217', '{"note":"see metadata"}', '{"ip":"203.0.113.213","portal":"admin"}', '01K2F2DKG0S1SYF4CBXWS4CD56'),
('2026-08-02 21:34:00', 8, 'admin', 'staff-8', NULL, 'organization.suspended', 'organization', 173, 'organization #283', '{"note":"see metadata"}', '{"ip":"203.0.113.236","portal":"admin"}', '01K2F2DKG0RD41MP0V43C59FV8'),
('2026-07-25 00:34:00', 3, 'admin', 'staff-3', NULL, 'organization.verified', 'organization', 1, 'organization #78', '{"note":"see metadata"}', '{"ip":"203.0.113.37","portal":"admin"}', '01K2F2DKG00BJR6H8RG3P6B518'),
('2026-07-07 05:30:00', 4, 'admin', 'staff-4', NULL, 'payment.refunded', 'payment', 366, 'payment #304', '{"note":"see metadata"}', '{"ip":"203.0.113.171","portal":"admin"}', '01K2F2DKG00FR5MKWTJDR544XX'),
('2026-06-17 14:27:00', 2, 'admin', 'staff-2', NULL, 'account.type_changed', 'account', 249, 'account #3', '{"note":"see metadata"}', '{"ip":"203.0.113.173","portal":"admin"}', '01K2F2DKG0SEJ96C3Z6G0W4M3K'),
('2026-05-01 09:03:00', 5, 'admin', 'staff-5', NULL, 'report.resolved', 'report', 165, 'report #330', '{"note":"see metadata"}', '{"ip":"203.0.113.80","portal":"admin"}', '01K2F2DKG003MF2D4ZBMGRD8DM'),
('2026-07-14 18:13:00', 4, 'admin', 'staff-4', NULL, 'organization.verified', 'organization', 351, 'organization #8', '{"note":"see metadata"}', '{"ip":"203.0.113.88","portal":"admin"}', '01K2F2DKG0QGAR4WQ2Z209E9G6'),
('2026-05-06 22:41:00', 4, 'admin', 'staff-4', NULL, 'report.resolved', 'report', 18, 'report #317', '{"note":"see metadata"}', '{"ip":"203.0.113.145","portal":"admin"}', '01K2F2DKG0XJ0TEVKGGGH92Z7W'),
('2026-06-13 21:44:00', 4, 'admin', 'staff-4', NULL, 'category.updated', 'category', 88, 'category #253', '{"note":"see metadata"}', '{"ip":"203.0.113.164","portal":"admin"}', '01K2F2DKG06PVXGK33KMCFKRYE'),
('2026-03-22 15:43:00', 8, 'admin', 'staff-8', NULL, 'report.resolved', 'report', 255, 'report #273', '{"note":"see metadata"}', '{"ip":"203.0.113.227","portal":"admin"}', '01K2F2DKG0B1KYJS4HXQYF7YRX'),
('2026-06-01 10:22:00', 8, 'admin', 'staff-8', NULL, 'settings.updated', 'setting', 314, 'setting #381', '{"note":"see metadata"}', '{"ip":"203.0.113.87","portal":"admin"}', '01K2F2DKG0EAWSGVB3C04G5KE9'),
('2026-03-17 22:15:00', 1, 'admin', 'staff-1', NULL, 'user.reinstated', 'user', 41, 'user #6', '{"note":"see metadata"}', '{"ip":"203.0.113.196","portal":"admin"}', '01K2F2DKG0500MZJBG9D4NV82W'),
('2026-08-14 03:13:00', 5, 'admin', 'staff-5', NULL, 'feature_flag.toggled', 'feature_flag', 72, 'feature_flag #314', '{"note":"see metadata"}', '{"ip":"203.0.113.20","portal":"admin"}', '01K2F2DKG01M0QM43W80PXK2WD'),
('2026-08-03 23:32:00', 8, 'admin', 'staff-8', 5, 'user.impersonated', 'user', 175, 'user #199', '{"note":"see metadata"}', '{"ip":"203.0.113.89","portal":"admin"}', '01K2F2DKG03G9AZN2SAF1PF12A'),
('2026-05-11 03:38:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 175, 'location #358', '{"note":"see metadata"}', '{"ip":"203.0.113.222","portal":"admin"}', '01K2F2DKG0NEYH120FH5438KPH'),
('2026-04-22 09:30:00', 1, 'admin', 'staff-1', NULL, 'organization.verified', 'organization', 53, 'organization #283', '{"note":"see metadata"}', '{"ip":"203.0.113.236","portal":"admin"}', '01K2F2DKG0VWGHDQNX26ZZF9HN'),
('2026-03-26 15:18:00', 5, 'admin', 'staff-5', NULL, 'category.updated', 'category', 187, 'category #5', '{"note":"see metadata"}', '{"ip":"203.0.113.70","portal":"admin"}', '01K2F2DKG00B6FT8C2ADKCD2WC'),
('2026-05-21 21:59:00', 3, 'admin', 'staff-3', NULL, 'user.suspended', 'user', 324, 'user #373', '{"note":"see metadata"}', '{"ip":"203.0.113.149","portal":"admin"}', '01K2F2DKG0T26S9K012ZH6SH6N'),
('2026-04-12 11:32:00', 6, 'admin', 'staff-6', NULL, 'listing.rejected', 'listing', 128, 'listing #165', '{"note":"see metadata"}', '{"ip":"203.0.113.112","portal":"admin"}', '01K2F2DKG035H2TJ9N8QMEJ1YZ'),
('2026-04-23 09:43:00', 7, 'admin', 'staff-7', NULL, 'payout.approved', 'payout', 79, 'payout #106', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.226","portal":"admin"}', '01K2F2DKG0V4HE49SGVZP7P6ZS'),
('2026-03-31 10:31:00', 5, 'admin', 'staff-5', NULL, 'listing.approved', 'listing', 39, 'listing #266', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.6","portal":"admin"}', '01K2F2DKG0G4TNWBTXZ3PD6NV6'),
('2026-06-18 23:07:00', 4, 'admin', 'staff-4', NULL, 'settings.updated', 'setting', 104, 'setting #211', '{"note":"see metadata"}', '{"ip":"203.0.113.58","portal":"admin"}', '01K2F2DKG0PE661Y3MD71PEJDA'),
('2026-04-24 15:11:00', 2, 'admin', 'staff-2', NULL, 'user.reinstated', 'user', 109, 'user #32', '{"note":"see metadata"}', '{"ip":"203.0.113.93","portal":"admin"}', '01K2F2DKG0KX4K0RYYMR199MZZ'),
('2026-07-27 03:52:00', 5, 'admin', 'staff-5', NULL, 'feature_flag.toggled', 'feature_flag', 322, 'feature_flag #164', '{"note":"see metadata"}', '{"ip":"203.0.113.228","portal":"admin"}', '01K2F2DKG09BGVYST4FHZ51M3N'),
('2026-03-18 08:24:00', 5, 'admin', 'staff-5', NULL, 'user.suspended', 'user', 264, 'user #62', '{"note":"see metadata"}', '{"ip":"203.0.113.155","portal":"admin"}', '01K2F2DKG0PJK7WYP6X1Y3F71Y'),
('2026-03-19 01:07:00', 8, 'admin', 'staff-8', NULL, 'user.reinstated', 'user', 13, 'user #187', '{"note":"see metadata"}', '{"ip":"203.0.113.42","portal":"admin"}', '01K2F2DKG0BHBYEE35YR2TD4DA'),
('2026-05-16 20:46:00', 6, 'admin', 'staff-6', NULL, 'user.suspended', 'user', 77, 'user #361', '{"note":"see metadata"}', '{"ip":"203.0.113.26","portal":"admin"}', '01K2F2DKG0GXR46XVV8M1ZNFCG'),
('2026-08-02 08:43:00', 7, 'admin', 'staff-7', NULL, 'user.suspended', 'user', 111, 'user #198', '{"note":"see metadata"}', '{"ip":"203.0.113.166","portal":"admin"}', '01K2F2DKG0H4YGC1D7XV5Y284H'),
('2026-05-31 03:04:00', 4, 'admin', 'staff-4', NULL, 'payment.refunded', 'payment', 300, 'payment #247', '{"note":"see metadata"}', '{"ip":"203.0.113.53","portal":"admin"}', '01K2F2DKG0ETYPNZPGD4B75ZF4'),
('2026-03-22 15:30:00', 6, 'admin', 'staff-6', NULL, 'listing.unpublished', 'listing', 21, 'listing #261', '{"note":"see metadata"}', '{"ip":"203.0.113.76","portal":"admin"}', '01K2F2DKG0CF16D08Z445YTS2X'),
('2026-02-27 20:39:00', 6, 'admin', 'staff-6', NULL, 'account.type_changed', 'account', 254, 'account #331', '{"note":"see metadata"}', '{"ip":"203.0.113.169","portal":"admin"}', '01K2F2DKG05QXGW3DXVJXGQVHJ'),
('2026-03-10 19:03:00', 6, 'admin', 'staff-6', NULL, 'payment.refunded', 'payment', 18, 'payment #172', '{"note":"see metadata"}', '{"ip":"203.0.113.222","portal":"admin"}', '01K2F2DKG0X2H3ZSP8H97Q385D'),
('2026-08-02 16:11:00', 3, 'admin', 'staff-3', NULL, 'listing.price_changed', 'listing', 253, 'listing #156', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.79","portal":"admin"}', '01K2F2DKG0HR7F4TX7MSJRHVV7'),
('2026-08-06 16:12:00', 2, 'admin', 'staff-2', NULL, 'account.type_changed', 'account', 219, 'account #385', '{"note":"see metadata"}', '{"ip":"203.0.113.223","portal":"admin"}', '01K2F2DKG08MWPZPB72E4RYXT4'),
('2026-03-02 14:41:00', 7, 'admin', 'staff-7', NULL, 'location.created', 'location', 278, 'location #284', '{"note":"see metadata"}', '{"ip":"203.0.113.88","portal":"admin"}', '01K2F2DKG0XCATWW79RC5FH72P'),
('2026-03-24 00:22:00', 6, 'admin', 'staff-6', NULL, 'organization.suspended', 'organization', 190, 'organization #296', '{"note":"see metadata"}', '{"ip":"203.0.113.178","portal":"admin"}', '01K2F2DKG0ZT77SVEEH7ME2WBK'),
('2026-05-02 01:06:00', 8, 'admin', 'staff-8', NULL, 'listing.rejected', 'listing', 237, 'listing #154', '{"note":"see metadata"}', '{"ip":"203.0.113.153","portal":"admin"}', '01K2F2DKG0P4BGKM6PV8ARWRN2'),
('2026-05-23 11:12:00', 3, 'admin', 'staff-3', NULL, 'listing.price_changed', 'listing', 169, 'listing #292', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.67","portal":"admin"}', '01K2F2DKG0RNXYPA0NDS5B1687'),
('2026-03-22 04:09:00', 4, 'admin', 'staff-4', NULL, 'user.suspended', 'user', 254, 'user #53', '{"note":"see metadata"}', '{"ip":"203.0.113.12","portal":"admin"}', '01K2F2DKG0608NWEVN3K9X875Y');

INSERT INTO audit_logs (occurred_at, actor_user_id, actor_type, actor_label, impersonator_user_id, action, subject_type, subject_id, subject_label, changes, metadata, request_id) VALUES
('2026-05-25 04:51:00', 4, 'admin', 'staff-4', NULL, 'location.created', 'location', 279, 'location #6', '{"note":"see metadata"}', '{"ip":"203.0.113.236","portal":"admin"}', '01K2F2DKG01CQK1J7ZT4E7DGB9'),
('2026-08-01 11:04:00', 3, 'admin', 'staff-3', NULL, 'settings.updated', 'setting', 255, 'setting #89', '{"note":"see metadata"}', '{"ip":"203.0.113.110","portal":"admin"}', '01K2F2DKG03X4MXAVMVD678QG4'),
('2026-05-31 17:35:00', 5, 'admin', 'staff-5', NULL, 'listing.unpublished', 'listing', 6, 'listing #163', '{"note":"see metadata"}', '{"ip":"203.0.113.202","portal":"admin"}', '01K2F2DKG0PZ4RTASKC9NQG90H'),
('2026-05-09 14:48:00', 5, 'admin', 'staff-5', NULL, 'listing.price_changed', 'listing', 64, 'listing #199', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.207","portal":"admin"}', '01K2F2DKG033N5RYJ90ECSV1NF'),
('2026-04-01 21:38:00', 1, 'admin', 'staff-1', NULL, 'payout.approved', 'payout', 251, 'payout #308', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.219","portal":"admin"}', '01K2F2DKG0YGYPPHS7T3VV79GX'),
('2026-05-30 19:04:00', 8, 'admin', 'staff-8', NULL, 'organization.verified', 'organization', 7, 'organization #12', '{"note":"see metadata"}', '{"ip":"203.0.113.131","portal":"admin"}', '01K2F2DKG0XNZR4N1X9KG3KG1T'),
('2026-06-18 10:58:00', 8, 'admin', 'staff-8', NULL, 'payment.refunded', 'payment', 64, 'payment #378', '{"note":"see metadata"}', '{"ip":"203.0.113.178","portal":"admin"}', '01K2F2DKG07AKZSHD5YFVQ1MWK'),
('2026-05-14 23:44:00', 3, 'admin', 'staff-3', NULL, 'organization.verified', 'organization', 16, 'organization #330', '{"note":"see metadata"}', '{"ip":"203.0.113.28","portal":"admin"}', '01K2F2DKG0QB5WZBNV1GJZA3J9'),
('2026-03-02 02:35:00', 6, 'admin', 'staff-6', NULL, 'organization.suspended', 'organization', 25, 'organization #399', '{"note":"see metadata"}', '{"ip":"203.0.113.60","portal":"admin"}', '01K2F2DKG09C5MZQH7KWMZZK43'),
('2026-06-11 12:55:00', 6, 'admin', 'staff-6', NULL, 'organization.verified', 'organization', 395, 'organization #325', '{"note":"see metadata"}', '{"ip":"203.0.113.169","portal":"admin"}', '01K2F2DKG05882PKHKMDRM61DP'),
('2026-04-25 05:21:00', 4, 'admin', 'staff-4', NULL, 'api_client.created', 'api_client', 204, 'api_client #258', '{"note":"see metadata"}', '{"ip":"203.0.113.142","portal":"admin"}', '01K2F2DKG00J7VPNQXX9KTST1J'),
('2026-08-13 01:13:00', 4, 'admin', 'staff-4', NULL, 'listing.price_changed', 'listing', 132, 'listing #168', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.161","portal":"admin"}', '01K2F2DKG0BJWZ7T4AFKRR1RWB'),
('2026-03-25 08:24:00', 6, 'admin', 'staff-6', NULL, 'settings.updated', 'setting', 24, 'setting #175', '{"note":"see metadata"}', '{"ip":"203.0.113.71","portal":"admin"}', '01K2F2DKG0Q02YS66F8EYJJDNW'),
('2026-05-22 04:03:00', 2, 'admin', 'staff-2', NULL, 'payment.refunded', 'payment', 391, 'payment #156', '{"note":"see metadata"}', '{"ip":"203.0.113.55","portal":"admin"}', '01K2F2DKG01B8RZV0QVZ859J1H'),
('2026-07-27 04:18:00', 7, 'admin', 'staff-7', NULL, 'category.updated', 'category', 21, 'category #289', '{"note":"see metadata"}', '{"ip":"203.0.113.71","portal":"admin"}', '01K2F2DKG004X71ZNWKS8T3A8Y'),
('2026-06-27 17:59:00', 6, 'admin', 'staff-6', NULL, 'payment.refunded', 'payment', 393, 'payment #160', '{"note":"see metadata"}', '{"ip":"203.0.113.55","portal":"admin"}', '01K2F2DKG0PP49N72SZZCVB66G'),
('2026-08-14 19:32:00', 6, 'admin', 'staff-6', NULL, 'organization.suspended', 'organization', 296, 'organization #68', '{"note":"see metadata"}', '{"ip":"203.0.113.153","portal":"admin"}', '01K2F2DKG0561RDSE2K87Q1A8M'),
('2026-04-10 03:27:00', 5, 'admin', 'staff-5', NULL, 'account.type_changed', 'account', 222, 'account #183', '{"note":"see metadata"}', '{"ip":"203.0.113.243","portal":"admin"}', '01K2F2DKG064Q9YBSP473JAJBJ'),
('2026-07-21 10:41:00', 5, 'admin', 'staff-5', NULL, 'listing.approved', 'listing', 318, 'listing #37', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.208","portal":"admin"}', '01K2F2DKG06TY7B2ZKSF3HTKAB'),
('2026-04-09 19:52:00', 4, 'admin', 'staff-4', NULL, 'payment.refunded', 'payment', 236, 'payment #230', '{"note":"see metadata"}', '{"ip":"203.0.113.12","portal":"admin"}', '01K2F2DKG0CFMM9WBJEZPV0KWN'),
('2026-02-27 10:17:00', 2, 'admin', 'staff-2', NULL, 'organization.verified', 'organization', 126, 'organization #206', '{"note":"see metadata"}', '{"ip":"203.0.113.92","portal":"admin"}', '01K2F2DKG0BVZQ7H5XHW4AEYEC'),
('2026-06-26 09:50:00', 3, 'admin', 'staff-3', NULL, 'account.type_changed', 'account', 56, 'account #206', '{"note":"see metadata"}', '{"ip":"203.0.113.150","portal":"admin"}', '01K2F2DKG093JY4W1KE51H7ZKT'),
('2026-06-14 18:15:00', 5, 'admin', 'staff-5', NULL, 'organization.suspended', 'organization', 238, 'organization #103', '{"note":"see metadata"}', '{"ip":"203.0.113.167","portal":"admin"}', '01K2F2DKG08XE80F4QP2YYGJW8'),
('2026-03-26 09:10:00', 7, 'admin', 'staff-7', NULL, 'payout.approved', 'payout', 182, 'payout #14', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.172","portal":"admin"}', '01K2F2DKG0DJEX11XPYZPQHN9N'),
('2026-05-25 08:29:00', 2, 'admin', 'staff-2', NULL, 'listing.unpublished', 'listing', 369, 'listing #252', '{"note":"see metadata"}', '{"ip":"203.0.113.147","portal":"admin"}', '01K2F2DKG0PMDTMMNYKVPBJ7YW'),
('2026-04-16 14:08:00', 8, 'admin', 'staff-8', NULL, 'location.created', 'location', 187, 'location #223', '{"note":"see metadata"}', '{"ip":"203.0.113.122","portal":"admin"}', '01K2F2DKG0P93NX9Q1M426HY4T'),
('2026-06-19 02:32:00', 3, 'admin', 'staff-3', NULL, 'user.suspended', 'user', 299, 'user #191', '{"note":"see metadata"}', '{"ip":"203.0.113.241","portal":"admin"}', '01K2F2DKG0MGWGT92K6X8Y7A7W'),
('2026-07-21 06:41:00', 5, 'admin', 'staff-5', 5, 'user.impersonated', 'user', 265, 'user #343', '{"note":"see metadata"}', '{"ip":"203.0.113.186","portal":"admin"}', '01K2F2DKG0BERR16WAYFT94TF9'),
('2026-03-03 10:51:00', 1, 'admin', 'staff-1', NULL, 'settings.updated', 'setting', 189, 'setting #122', '{"note":"see metadata"}', '{"ip":"203.0.113.110","portal":"admin"}', '01K2F2DKG0E47KF1SWPSBASST2'),
('2026-04-20 05:38:00', 1, 'admin', 'staff-1', NULL, 'organization.suspended', 'organization', 236, 'organization #127', '{"note":"see metadata"}', '{"ip":"203.0.113.21","portal":"admin"}', '01K2F2DKG057SR3F0YXZ8EHSG9'),
('2026-03-01 21:51:00', 1, 'admin', 'staff-1', NULL, 'location.created', 'location', 370, 'location #113', '{"note":"see metadata"}', '{"ip":"203.0.113.119","portal":"admin"}', '01K2F2DKG0APJSTT3CG70RBGDD'),
('2026-06-20 03:25:00', 2, 'admin', 'staff-2', NULL, 'report.resolved', 'report', 281, 'report #360', '{"note":"see metadata"}', '{"ip":"203.0.113.109","portal":"admin"}', '01K2F2DKG0FTTYX8CHG5V3JEZZ'),
('2026-07-18 21:32:00', 6, 'admin', 'staff-6', 5, 'user.impersonated', 'user', 310, 'user #88', '{"note":"see metadata"}', '{"ip":"203.0.113.38","portal":"admin"}', '01K2F2DKG05Y59ZFKP5V43NX60'),
('2026-04-04 19:27:00', 3, 'admin', 'staff-3', NULL, 'organization.verified', 'organization', 348, 'organization #378', '{"note":"see metadata"}', '{"ip":"203.0.113.71","portal":"admin"}', '01K2F2DKG09ZVEQKHNF2RJWEPS'),
('2026-07-17 07:06:00', 5, 'admin', 'staff-5', NULL, 'api_client.created', 'api_client', 146, 'api_client #119', '{"note":"see metadata"}', '{"ip":"203.0.113.26","portal":"admin"}', '01K2F2DKG0VESPK4DAM08G2MQ7'),
('2026-07-09 14:05:00', 6, 'admin', 'staff-6', NULL, 'listing.unpublished', 'listing', 21, 'listing #351', '{"note":"see metadata"}', '{"ip":"203.0.113.165","portal":"admin"}', '01K2F2DKG0F0B1A52S8H348RW6'),
('2026-06-24 16:43:00', 6, 'admin', 'staff-6', NULL, 'user.suspended', 'user', 346, 'user #238', '{"note":"see metadata"}', '{"ip":"203.0.113.116","portal":"admin"}', '01K2F2DKG0DJFVJ7TFSX5G712T'),
('2026-04-08 13:33:00', 6, 'admin', 'staff-6', NULL, 'listing.unpublished', 'listing', 93, 'listing #240', '{"note":"see metadata"}', '{"ip":"203.0.113.198","portal":"admin"}', '01K2F2DKG0SRYPKSC8XEK1YXRA'),
('2026-03-12 03:16:00', 6, 'admin', 'staff-6', NULL, 'listing.rejected', 'listing', 331, 'listing #187', '{"note":"see metadata"}', '{"ip":"203.0.113.180","portal":"admin"}', '01K2F2DKG0FVZ092EH59TQ7ZFZ'),
('2026-04-29 11:36:00', 6, 'admin', 'staff-6', NULL, 'listing.rejected', 'listing', 313, 'listing #169', '{"note":"see metadata"}', '{"ip":"203.0.113.28","portal":"admin"}', '01K2F2DKG0XA14TH55Q77S50SF'),
('2026-03-31 15:41:00', 5, 'admin', 'staff-5', NULL, 'listing.approved', 'listing', 378, 'listing #67', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.211","portal":"admin"}', '01K2F2DKG05GR6RMX3TWY622K4'),
('2026-08-10 14:58:00', 1, 'admin', 'staff-1', NULL, 'report.resolved', 'report', 82, 'report #150', '{"note":"see metadata"}', '{"ip":"203.0.113.37","portal":"admin"}', '01K2F2DKG0WZNW1AB571YC4C2E'),
('2026-03-03 06:32:00', 8, 'admin', 'staff-8', NULL, 'listing.price_changed', 'listing', 269, 'listing #286', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.136","portal":"admin"}', '01K2F2DKG04D66HEGANXW0R9EW'),
('2026-04-04 20:54:00', 6, 'admin', 'staff-6', NULL, 'api_client.created', 'api_client', 393, 'api_client #112', '{"note":"see metadata"}', '{"ip":"203.0.113.181","portal":"admin"}', '01K2F2DKG0QHRJ4GKSV2030C8C'),
('2026-06-27 13:34:00', 3, 'admin', 'staff-3', NULL, 'organization.suspended', 'organization', 188, 'organization #162', '{"note":"see metadata"}', '{"ip":"203.0.113.169","portal":"admin"}', '01K2F2DKG0W77R0Q9PDE3VFCYQ'),
('2026-04-28 06:04:00', 8, 'admin', 'staff-8', NULL, 'report.resolved', 'report', 325, 'report #17', '{"note":"see metadata"}', '{"ip":"203.0.113.128","portal":"admin"}', '01K2F2DKG078CKQ4YAWPKFN0WD'),
('2026-04-06 10:09:00', 3, 'admin', 'staff-3', NULL, 'organization.suspended', 'organization', 132, 'organization #353', '{"note":"see metadata"}', '{"ip":"203.0.113.170","portal":"admin"}', '01K2F2DKG09MRYC2Q5QVFC4GCN'),
('2026-08-15 16:36:00', 2, 'admin', 'staff-2', NULL, 'settings.updated', 'setting', 304, 'setting #290', '{"note":"see metadata"}', '{"ip":"203.0.113.149","portal":"admin"}', '01K2F2DKG0RAT6MV2GGDA56C9D'),
('2026-03-11 07:24:00', 3, 'admin', 'staff-3', NULL, 'payout.approved', 'payout', 18, 'payout #382', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.191","portal":"admin"}', '01K2F2DKG0EWH5N560TSBWVYGV'),
('2026-03-21 16:58:00', 7, 'admin', 'staff-7', 5, 'user.impersonated', 'user', 73, 'user #364', '{"note":"see metadata"}', '{"ip":"203.0.113.96","portal":"admin"}', '01K2F2DKG0G36D3VWFKDQQED98'),
('2026-07-23 02:12:00', 2, 'admin', 'staff-2', NULL, 'payment.refunded', 'payment', 324, 'payment #184', '{"note":"see metadata"}', '{"ip":"203.0.113.208","portal":"admin"}', '01K2F2DKG0RHFT11P8FN53VZKP'),
('2026-08-01 17:05:00', 7, 'admin', 'staff-7', NULL, 'account.type_changed', 'account', 384, 'account #57', '{"note":"see metadata"}', '{"ip":"203.0.113.168","portal":"admin"}', '01K2F2DKG0CH0FSS6Q4P77MXR2'),
('2026-04-21 06:02:00', 1, 'admin', 'staff-1', NULL, 'api_client.created', 'api_client', 172, 'api_client #317', '{"note":"see metadata"}', '{"ip":"203.0.113.150","portal":"admin"}', '01K2F2DKG0HESKHTKZS9TWD94R'),
('2026-07-07 07:44:00', 2, 'admin', 'staff-2', NULL, 'payout.approved', 'payout', 393, 'payout #109', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.23","portal":"admin"}', '01K2F2DKG09QR2N752BCTEEN9N'),
('2026-06-07 05:25:00', 3, 'admin', 'staff-3', NULL, 'organization.suspended', 'organization', 287, 'organization #120', '{"note":"see metadata"}', '{"ip":"203.0.113.163","portal":"admin"}', '01K2F2DKG0VGWZV099NTR6AMBT'),
('2026-06-13 06:49:00', 5, 'admin', 'staff-5', NULL, 'api_client.created', 'api_client', 188, 'api_client #231', '{"note":"see metadata"}', '{"ip":"203.0.113.75","portal":"admin"}', '01K2F2DKG0YCSBD22RFWN0Z3QV'),
('2026-05-05 10:16:00', 3, 'admin', 'staff-3', 5, 'user.impersonated', 'user', 260, 'user #294', '{"note":"see metadata"}', '{"ip":"203.0.113.9","portal":"admin"}', '01K2F2DKG0P8AV6VF8RKMG305K'),
('2026-05-04 20:28:00', 2, 'admin', 'staff-2', NULL, 'payout.approved', 'payout', 393, 'payout #20', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.92","portal":"admin"}', '01K2F2DKG0JEFT9CV68W2TSN39'),
('2026-06-03 12:59:00', 8, 'admin', 'staff-8', NULL, 'user.suspended', 'user', 24, 'user #4', '{"note":"see metadata"}', '{"ip":"203.0.113.132","portal":"admin"}', '01K2F2DKG0QPV4Z4R15EBPPRGZ'),
('2026-06-03 05:57:00', 4, 'admin', 'staff-4', NULL, 'organization.verified', 'organization', 139, 'organization #332', '{"note":"see metadata"}', '{"ip":"203.0.113.149","portal":"admin"}', '01K2F2DKG0ZBMN8RXH6KNG1FFD'),
('2026-06-08 15:59:00', 1, 'admin', 'staff-1', NULL, 'settings.updated', 'setting', 51, 'setting #168', '{"note":"see metadata"}', '{"ip":"203.0.113.96","portal":"admin"}', '01K2F2DKG069C2NNAE0A0ASNQ2'),
('2026-04-07 23:00:00', 1, 'admin', 'staff-1', NULL, 'account.type_changed', 'account', 49, 'account #75', '{"note":"see metadata"}', '{"ip":"203.0.113.38","portal":"admin"}', '01K2F2DKG0KM5KVBY4RPM6CHKD'),
('2026-03-29 11:12:00', 5, 'admin', 'staff-5', NULL, 'user.suspended', 'user', 256, 'user #120', '{"note":"see metadata"}', '{"ip":"203.0.113.116","portal":"admin"}', '01K2F2DKG0RMTDME0KZFV93MBX'),
('2026-06-08 20:16:00', 8, 'admin', 'staff-8', NULL, 'api_client.created', 'api_client', 366, 'api_client #370', '{"note":"see metadata"}', '{"ip":"203.0.113.214","portal":"admin"}', '01K2F2DKG0BPB77FYBJSDWD2WK'),
('2026-03-07 06:58:00', 8, 'admin', 'staff-8', NULL, 'account.type_changed', 'account', 234, 'account #303', '{"note":"see metadata"}', '{"ip":"203.0.113.216","portal":"admin"}', '01K2F2DKG0443HVWZS76KABTMX'),
('2026-06-15 12:06:00', 1, 'admin', 'staff-1', NULL, 'account.type_changed', 'account', 112, 'account #150', '{"note":"see metadata"}', '{"ip":"203.0.113.18","portal":"admin"}', '01K2F2DKG0108W794K091M17DN'),
('2026-04-19 23:49:00', 7, 'admin', 'staff-7', NULL, 'listing.approved', 'listing', 324, 'listing #55', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.2","portal":"admin"}', '01K2F2DKG05YSKPTF9ADCG4VRN'),
('2026-06-18 18:16:00', 3, 'admin', 'staff-3', NULL, 'user.suspended', 'user', 4, 'user #13', '{"note":"see metadata"}', '{"ip":"203.0.113.37","portal":"admin"}', '01K2F2DKG0RVNX3K6Y0446QQH4'),
('2026-03-06 15:10:00', 6, 'admin', 'staff-6', NULL, 'payout.approved', 'payout', 272, 'payout #25', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.207","portal":"admin"}', '01K2F2DKG0XKZ32DJTZCKA9EV6'),
('2026-04-03 23:53:00', 3, 'admin', 'staff-3', NULL, 'listing.rejected', 'listing', 386, 'listing #15', '{"note":"see metadata"}', '{"ip":"203.0.113.200","portal":"admin"}', '01K2F2DKG0N56QRKXE3NSA7QWB'),
('2026-05-03 22:27:00', 8, 'admin', 'staff-8', NULL, 'settings.updated', 'setting', 395, 'setting #53', '{"note":"see metadata"}', '{"ip":"203.0.113.179","portal":"admin"}', '01K2F2DKG0WMJD3PSK8QRWWDYY'),
('2026-06-24 08:18:00', 1, 'admin', 'staff-1', NULL, 'report.resolved', 'report', 128, 'report #261', '{"note":"see metadata"}', '{"ip":"203.0.113.120","portal":"admin"}', '01K2F2DKG0J43M5DWJ8JVGN3ZN'),
('2026-03-23 08:55:00', 6, 'admin', 'staff-6', NULL, 'organization.suspended', 'organization', 188, 'organization #129', '{"note":"see metadata"}', '{"ip":"203.0.113.104","portal":"admin"}', '01K2F2DKG0FEAXVGSMA9ES8Y9P'),
('2026-06-09 17:40:00', 2, 'admin', 'staff-2', NULL, 'payment.refunded', 'payment', 225, 'payment #72', '{"note":"see metadata"}', '{"ip":"203.0.113.175","portal":"admin"}', '01K2F2DKG0QMHN2C4QDJP1F8NJ'),
('2026-04-09 15:16:00', 8, 'admin', 'staff-8', NULL, 'listing.approved', 'listing', 290, 'listing #316', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.155","portal":"admin"}', '01K2F2DKG0VJ3APMWP6CV5AJJ0'),
('2026-04-04 08:40:00', 1, 'admin', 'staff-1', 5, 'user.impersonated', 'user', 169, 'user #297', '{"note":"see metadata"}', '{"ip":"203.0.113.172","portal":"admin"}', '01K2F2DKG0966F1J17C6BA8DEG'),
('2026-05-03 14:02:00', 5, 'admin', 'staff-5', NULL, 'listing.rejected', 'listing', 336, 'listing #229', '{"note":"see metadata"}', '{"ip":"203.0.113.67","portal":"admin"}', '01K2F2DKG0MK35MSDYDWK44FF8'),
('2026-07-25 19:16:00', 5, 'admin', 'staff-5', NULL, 'payout.approved', 'payout', 339, 'payout #355', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.234","portal":"admin"}', '01K2F2DKG0JZQFMSJHP0HYY4S5'),
('2026-03-03 12:12:00', 1, 'admin', 'staff-1', NULL, 'organization.suspended', 'organization', 339, 'organization #219', '{"note":"see metadata"}', '{"ip":"203.0.113.146","portal":"admin"}', '01K2F2DKG0AGTZF9B2YEX7DZEJ'),
('2026-03-09 07:03:00', 6, 'admin', 'staff-6', NULL, 'user.suspended', 'user', 44, 'user #114', '{"note":"see metadata"}', '{"ip":"203.0.113.143","portal":"admin"}', '01K2F2DKG0A3K6X6QKHVDFKQSS'),
('2026-06-07 06:44:00', 2, 'admin', 'staff-2', NULL, 'user.reinstated', 'user', 153, 'user #60', '{"note":"see metadata"}', '{"ip":"203.0.113.40","portal":"admin"}', '01K2F2DKG0A90P49XZERJ8XG0C'),
('2026-04-21 03:33:00', 8, 'admin', 'staff-8', NULL, 'listing.unpublished', 'listing', 164, 'listing #26', '{"note":"see metadata"}', '{"ip":"203.0.113.38","portal":"admin"}', '01K2F2DKG0NJ7ME8A85WJMFR0J'),
('2026-04-21 01:24:00', 2, 'admin', 'staff-2', NULL, 'organization.suspended', 'organization', 193, 'organization #164', '{"note":"see metadata"}', '{"ip":"203.0.113.14","portal":"admin"}', '01K2F2DKG0KGEC6NQBVX67V891'),
('2026-03-01 03:30:00', 5, 'admin', 'staff-5', NULL, 'listing.approved', 'listing', 277, 'listing #125', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.201","portal":"admin"}', '01K2F2DKG0WG2174HR3H3JAN7G'),
('2026-04-13 02:36:00', 2, 'admin', 'staff-2', 5, 'user.impersonated', 'user', 384, 'user #188', '{"note":"see metadata"}', '{"ip":"203.0.113.215","portal":"admin"}', '01K2F2DKG00A9SXQDKXRXGVCG5'),
('2026-06-20 12:00:00', 8, 'admin', 'staff-8', NULL, 'organization.verified', 'organization', 75, 'organization #343', '{"note":"see metadata"}', '{"ip":"203.0.113.163","portal":"admin"}', '01K2F2DKG0RY1WBKXQTGCPN0HE'),
('2026-03-05 14:06:00', 8, 'admin', 'staff-8', 5, 'user.impersonated', 'user', 67, 'user #121', '{"note":"see metadata"}', '{"ip":"203.0.113.176","portal":"admin"}', '01K2F2DKG053Y7W72FDF7RZ8EK'),
('2026-04-12 16:32:00', 8, 'admin', 'staff-8', NULL, 'payment.refunded', 'payment', 149, 'payment #143', '{"note":"see metadata"}', '{"ip":"203.0.113.3","portal":"admin"}', '01K2F2DKG0N3KG6GPDHP06EYYY'),
('2026-07-09 03:55:00', 7, 'admin', 'staff-7', NULL, 'listing.price_changed', 'listing', 271, 'listing #137', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.191","portal":"admin"}', '01K2F2DKG0WFXNNM3AR1PJ9XP3'),
('2026-03-09 09:24:00', 4, 'admin', 'staff-4', NULL, 'listing.approved', 'listing', 212, 'listing #332', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.104","portal":"admin"}', '01K2F2DKG0CCTFQAT65MF8JMBT'),
('2026-04-08 17:28:00', 5, 'admin', 'staff-5', NULL, 'user.suspended', 'user', 368, 'user #221', '{"note":"see metadata"}', '{"ip":"203.0.113.193","portal":"admin"}', '01K2F2DKG0E3S51QG9VA9GH5EH'),
('2026-07-23 14:59:00', 7, 'admin', 'staff-7', NULL, 'user.reinstated', 'user', 300, 'user #318', '{"note":"see metadata"}', '{"ip":"203.0.113.100","portal":"admin"}', '01K2F2DKG0AEHX26X0EAQ7KM0S'),
('2026-05-12 22:57:00', 7, 'admin', 'staff-7', NULL, 'user.reinstated', 'user', 397, 'user #288', '{"note":"see metadata"}', '{"ip":"203.0.113.207","portal":"admin"}', '01K2F2DKG0XMM3JH18C6NR6R6K'),
('2026-07-13 15:01:00', 1, 'admin', 'staff-1', NULL, 'category.updated', 'category', 147, 'category #58', '{"note":"see metadata"}', '{"ip":"203.0.113.32","portal":"admin"}', '01K2F2DKG0NWG6MFP0K88D16WE'),
('2026-04-16 13:47:00', 2, 'admin', 'staff-2', NULL, 'category.updated', 'category', 75, 'category #211', '{"note":"see metadata"}', '{"ip":"203.0.113.134","portal":"admin"}', '01K2F2DKG0H39WV5DGS2QEFA31'),
('2026-05-18 14:27:00', 7, 'admin', 'staff-7', NULL, 'organization.verified', 'organization', 176, 'organization #92', '{"note":"see metadata"}', '{"ip":"203.0.113.228","portal":"admin"}', '01K2F2DKG0B1G7NJQZ5X31H16C'),
('2026-04-15 00:03:00', 2, 'admin', 'staff-2', NULL, 'report.resolved', 'report', 370, 'report #149', '{"note":"see metadata"}', '{"ip":"203.0.113.56","portal":"admin"}', '01K2F2DKG0YTQDA05K9F830YBQ'),
('2026-03-15 03:11:00', 5, 'admin', 'staff-5', NULL, 'user.suspended', 'user', 359, 'user #359', '{"note":"see metadata"}', '{"ip":"203.0.113.136","portal":"admin"}', '01K2F2DKG08DTJJ1ZPM21B3NPH'),
('2026-08-05 00:24:00', 2, 'admin', 'staff-2', NULL, 'account.type_changed', 'account', 94, 'account #108', '{"note":"see metadata"}', '{"ip":"203.0.113.33","portal":"admin"}', '01K2F2DKG0GACTVKF8ZYBSQQ4G'),
('2026-05-29 19:28:00', 3, 'admin', 'staff-3', NULL, 'listing.approved', 'listing', 249, 'listing #382', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.195","portal":"admin"}', '01K2F2DKG0SQWFYB1TWAJRJEFS'),
('2026-06-21 14:01:00', 8, 'admin', 'staff-8', NULL, 'payment.refunded', 'payment', 193, 'payment #306', '{"note":"see metadata"}', '{"ip":"203.0.113.105","portal":"admin"}', '01K2F2DKG0ZBXKSKVAT4A6XK64'),
('2026-06-26 09:37:00', 8, 'admin', 'staff-8', NULL, 'api_client.created', 'api_client', 82, 'api_client #392', '{"note":"see metadata"}', '{"ip":"203.0.113.34","portal":"admin"}', '01K2F2DKG0AAFVYTZFDJGV47J3'),
('2026-03-28 13:26:00', 5, 'admin', 'staff-5', NULL, 'report.resolved', 'report', 66, 'report #166', '{"note":"see metadata"}', '{"ip":"203.0.113.220","portal":"admin"}', '01K2F2DKG02PDRXZ5B8WHB1B34'),
('2026-07-21 20:16:00', 5, 'admin', 'staff-5', NULL, 'listing.unpublished', 'listing', 290, 'listing #343', '{"note":"see metadata"}', '{"ip":"203.0.113.181","portal":"admin"}', '01K2F2DKG0PNF0ZPQXC2370PWT'),
('2026-04-22 02:58:00', 2, 'admin', 'staff-2', NULL, 'account.type_changed', 'account', 255, 'account #54', '{"note":"see metadata"}', '{"ip":"203.0.113.174","portal":"admin"}', '01K2F2DKG0AER4S10E33EZKAGF'),
('2026-06-25 06:06:00', 8, 'admin', 'staff-8', NULL, 'settings.updated', 'setting', 31, 'setting #98', '{"note":"see metadata"}', '{"ip":"203.0.113.36","portal":"admin"}', '01K2F2DKG0BF45XTME4RGAY71Z'),
('2026-08-09 22:53:00', 7, 'admin', 'staff-7', NULL, 'settings.updated', 'setting', 130, 'setting #204', '{"note":"see metadata"}', '{"ip":"203.0.113.224","portal":"admin"}', '01K2F2DKG04ZXMD7DS0BRZFM8X'),
('2026-08-14 06:10:00', 1, 'admin', 'staff-1', NULL, 'report.resolved', 'report', 371, 'report #246', '{"note":"see metadata"}', '{"ip":"203.0.113.196","portal":"admin"}', '01K2F2DKG0A3ENHX7XAK9JXXCE'),
('2026-06-21 21:38:00', 2, 'admin', 'staff-2', NULL, 'location.created', 'location', 202, 'location #242', '{"note":"see metadata"}', '{"ip":"203.0.113.217","portal":"admin"}', '01K2F2DKG0BMXMY705K896433A'),
('2026-07-14 11:47:00', 8, 'admin', 'staff-8', NULL, 'listing.price_changed', 'listing', 44, 'listing #301', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.113","portal":"admin"}', '01K2F2DKG0DYCYPAMJ9WSFW7VF'),
('2026-05-20 01:50:00', 6, 'admin', 'staff-6', NULL, 'api_client.created', 'api_client', 320, 'api_client #310', '{"note":"see metadata"}', '{"ip":"203.0.113.73","portal":"admin"}', '01K2F2DKG086B0MRW49GF5XYXM'),
('2026-04-08 16:57:00', 4, 'admin', 'staff-4', NULL, 'feature_flag.toggled', 'feature_flag', 131, 'feature_flag #117', '{"note":"see metadata"}', '{"ip":"203.0.113.8","portal":"admin"}', '01K2F2DKG0V5ETW50EQYX9WVES'),
('2026-03-17 15:55:00', 2, 'admin', 'staff-2', NULL, 'organization.suspended', 'organization', 220, 'organization #328', '{"note":"see metadata"}', '{"ip":"203.0.113.104","portal":"admin"}', '01K2F2DKG0Q3QNQG8PQPN3MNDY'),
('2026-04-03 01:31:00', 6, 'admin', 'staff-6', NULL, 'location.created', 'location', 367, 'location #25', '{"note":"see metadata"}', '{"ip":"203.0.113.95","portal":"admin"}', '01K2F2DKG0C8X5D1CSKPXEWSQK'),
('2026-03-26 09:45:00', 5, 'admin', 'staff-5', NULL, 'account.type_changed', 'account', 126, 'account #168', '{"note":"see metadata"}', '{"ip":"203.0.113.171","portal":"admin"}', '01K2F2DKG03Q7GNT63QW2RA1EB'),
('2026-08-11 09:32:00', 8, 'admin', 'staff-8', NULL, 'category.updated', 'category', 183, 'category #387', '{"note":"see metadata"}', '{"ip":"203.0.113.85","portal":"admin"}', '01K2F2DKG0N9PTG0RV580DA31V'),
('2026-07-21 06:04:00', 4, 'admin', 'staff-4', NULL, 'payment.refunded', 'payment', 374, 'payment #346', '{"note":"see metadata"}', '{"ip":"203.0.113.20","portal":"admin"}', '01K2F2DKG00RZYXBFFRQHX67SJ'),
('2026-06-07 04:42:00', 7, 'admin', 'staff-7', NULL, 'feature_flag.toggled', 'feature_flag', 205, 'feature_flag #207', '{"note":"see metadata"}', '{"ip":"203.0.113.200","portal":"admin"}', '01K2F2DKG08J8CH2HT5B69DR29'),
('2026-03-19 21:40:00', 4, 'admin', 'staff-4', NULL, 'organization.suspended', 'organization', 250, 'organization #205', '{"note":"see metadata"}', '{"ip":"203.0.113.131","portal":"admin"}', '01K2F2DKG05VA51D83MES2KK6T'),
('2026-06-27 10:21:00', 6, 'admin', 'staff-6', NULL, 'account.type_changed', 'account', 328, 'account #338', '{"note":"see metadata"}', '{"ip":"203.0.113.167","portal":"admin"}', '01K2F2DKG0QSW1ZEYX0A8ZNWGF'),
('2026-06-03 11:30:00', 6, 'admin', 'staff-6', NULL, 'listing.approved', 'listing', 111, 'listing #20', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.133","portal":"admin"}', '01K2F2DKG0AZPM2YHVWVNKEXTA'),
('2026-07-25 19:08:00', 1, 'admin', 'staff-1', NULL, 'user.reinstated', 'user', 383, 'user #27', '{"note":"see metadata"}', '{"ip":"203.0.113.166","portal":"admin"}', '01K2F2DKG0XAEB53ATZYZJXNEF'),
('2026-06-05 23:03:00', 5, 'admin', 'staff-5', NULL, 'feature_flag.toggled', 'feature_flag', 168, 'feature_flag #94', '{"note":"see metadata"}', '{"ip":"203.0.113.119","portal":"admin"}', '01K2F2DKG0HPHV4H9J4MWW3P8Y'),
('2026-05-21 09:25:00', 1, 'admin', 'staff-1', NULL, 'location.created', 'location', 340, 'location #147', '{"note":"see metadata"}', '{"ip":"203.0.113.138","portal":"admin"}', '01K2F2DKG0X7WJQ7DMF7ENEVE9'),
('2026-03-14 17:14:00', 3, 'admin', 'staff-3', NULL, 'account.type_changed', 'account', 51, 'account #100', '{"note":"see metadata"}', '{"ip":"203.0.113.237","portal":"admin"}', '01K2F2DKG0HZKV9T95HSM8AS01'),
('2026-05-30 08:26:00', 8, 'admin', 'staff-8', NULL, 'account.type_changed', 'account', 161, 'account #291', '{"note":"see metadata"}', '{"ip":"203.0.113.246","portal":"admin"}', '01K2F2DKG07NT76C7RE0ET45E3'),
('2026-04-10 09:58:00', 7, 'admin', 'staff-7', NULL, 'listing.unpublished', 'listing', 116, 'listing #278', '{"note":"see metadata"}', '{"ip":"203.0.113.126","portal":"admin"}', '01K2F2DKG0EFNCX9C12J4YXZT5'),
('2026-06-15 02:05:00', 6, 'admin', 'staff-6', NULL, 'organization.verified', 'organization', 367, 'organization #51', '{"note":"see metadata"}', '{"ip":"203.0.113.159","portal":"admin"}', '01K2F2DKG0VF5HM2WRT51R251J'),
('2026-07-03 14:44:00', 3, 'admin', 'staff-3', NULL, 'category.updated', 'category', 69, 'category #366', '{"note":"see metadata"}', '{"ip":"203.0.113.6","portal":"admin"}', '01K2F2DKG08AERZ4335YS1ZFGC'),
('2026-08-02 18:27:00', 3, 'admin', 'staff-3', NULL, 'listing.rejected', 'listing', 214, 'listing #266', '{"note":"see metadata"}', '{"ip":"203.0.113.166","portal":"admin"}', '01K2F2DKG055HMYDWJS6RED5M8'),
('2026-03-15 13:55:00', 8, 'admin', 'staff-8', NULL, 'listing.unpublished', 'listing', 170, 'listing #296', '{"note":"see metadata"}', '{"ip":"203.0.113.21","portal":"admin"}', '01K2F2DKG0MWJX3SC3YJP0RKH1'),
('2026-05-18 23:54:00', 7, 'admin', 'staff-7', NULL, 'listing.unpublished', 'listing', 290, 'listing #237', '{"note":"see metadata"}', '{"ip":"203.0.113.169","portal":"admin"}', '01K2F2DKG0GPE1DNMG19EST93G'),
('2026-07-24 02:40:00', 6, 'admin', 'staff-6', NULL, 'listing.approved', 'listing', 232, 'listing #381', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.127","portal":"admin"}', '01K2F2DKG0TC1713MNJRYZ5PK3'),
('2026-07-15 23:42:00', 2, 'admin', 'staff-2', NULL, 'listing.rejected', 'listing', 223, 'listing #372', '{"note":"see metadata"}', '{"ip":"203.0.113.149","portal":"admin"}', '01K2F2DKG0EAN2X93M0FXZ1YVA'),
('2026-03-22 02:39:00', 4, 'admin', 'staff-4', NULL, 'payout.approved', 'payout', 287, 'payout #150', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.92","portal":"admin"}', '01K2F2DKG0PS438D4PGKHXPBK2'),
('2026-05-09 19:19:00', 1, 'admin', 'staff-1', NULL, 'user.suspended', 'user', 27, 'user #312', '{"note":"see metadata"}', '{"ip":"203.0.113.26","portal":"admin"}', '01K2F2DKG0S1Z3F3BYMK3C529V'),
('2026-04-08 01:19:00', 2, 'admin', 'staff-2', NULL, 'api_client.created', 'api_client', 96, 'api_client #4', '{"note":"see metadata"}', '{"ip":"203.0.113.223","portal":"admin"}', '01K2F2DKG0YS6R0DMS6RX52G0N'),
('2026-04-02 23:13:00', 6, 'admin', 'staff-6', NULL, 'api_client.created', 'api_client', 229, 'api_client #94', '{"note":"see metadata"}', '{"ip":"203.0.113.80","portal":"admin"}', '01K2F2DKG0H2RFAMKEAA9M2TXQ'),
('2026-07-02 06:29:00', 8, 'admin', 'staff-8', NULL, 'listing.price_changed', 'listing', 27, 'listing #305', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.36","portal":"admin"}', '01K2F2DKG0HVXQRZ4ENYQV3711'),
('2026-06-25 19:11:00', 3, 'admin', 'staff-3', NULL, 'api_client.created', 'api_client', 104, 'api_client #195', '{"note":"see metadata"}', '{"ip":"203.0.113.29","portal":"admin"}', '01K2F2DKG07QAV379564MB5G9R'),
('2026-08-13 04:58:00', 1, 'admin', 'staff-1', NULL, 'account.type_changed', 'account', 172, 'account #199', '{"note":"see metadata"}', '{"ip":"203.0.113.126","portal":"admin"}', '01K2F2DKG05YCBF804ZBTTR8P8'),
('2026-05-31 00:07:00', 7, 'admin', 'staff-7', NULL, 'listing.approved', 'listing', 1, 'listing #205', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.117","portal":"admin"}', '01K2F2DKG0H3K5RJSMJ6K0RJ09'),
('2026-05-30 12:39:00', 7, 'admin', 'staff-7', NULL, 'api_client.created', 'api_client', 67, 'api_client #273', '{"note":"see metadata"}', '{"ip":"203.0.113.179","portal":"admin"}', '01K2F2DKG0FT2NCJ5C48FP4FJD'),
('2026-07-02 19:33:00', 2, 'admin', 'staff-2', NULL, 'location.created', 'location', 51, 'location #71', '{"note":"see metadata"}', '{"ip":"203.0.113.79","portal":"admin"}', '01K2F2DKG0R51C4TAVQYABHX39'),
('2026-03-08 13:36:00', 2, 'admin', 'staff-2', NULL, 'settings.updated', 'setting', 371, 'setting #89', '{"note":"see metadata"}', '{"ip":"203.0.113.209","portal":"admin"}', '01K2F2DKG0801KR5XHJK407WR8'),
('2026-07-09 22:06:00', 5, 'admin', 'staff-5', NULL, 'settings.updated', 'setting', 69, 'setting #122', '{"note":"see metadata"}', '{"ip":"203.0.113.39","portal":"admin"}', '01K2F2DKG030RY4RHK0HWQT5WY'),
('2026-05-13 11:56:00', 6, 'admin', 'staff-6', NULL, 'listing.approved', 'listing', 273, 'listing #253', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.47","portal":"admin"}', '01K2F2DKG0YRW8QS6F99XKVW4J'),
('2026-05-07 02:19:00', 1, 'admin', 'staff-1', NULL, 'report.resolved', 'report', 343, 'report #195', '{"note":"see metadata"}', '{"ip":"203.0.113.205","portal":"admin"}', '01K2F2DKG0KX5KE6BEXBG0KVFS'),
('2026-04-01 11:17:00', 8, 'admin', 'staff-8', NULL, 'payment.refunded', 'payment', 16, 'payment #52', '{"note":"see metadata"}', '{"ip":"203.0.113.235","portal":"admin"}', '01K2F2DKG080CJKEZJK7NW5TJY'),
('2026-08-11 12:08:00', 8, 'admin', 'staff-8', NULL, 'settings.updated', 'setting', 162, 'setting #1', '{"note":"see metadata"}', '{"ip":"203.0.113.173","portal":"admin"}', '01K2F2DKG002NN9BKF7NAA85S8'),
('2026-06-24 06:13:00', 8, 'admin', 'staff-8', NULL, 'payout.approved', 'payout', 3, 'payout #114', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.158","portal":"admin"}', '01K2F2DKG0XEDFT0GHE3JGPVMV'),
('2026-04-17 19:12:00', 5, 'admin', 'staff-5', NULL, 'listing.approved', 'listing', 268, 'listing #28', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.134","portal":"admin"}', '01K2F2DKG02RPGV3SNKTK8GM9D'),
('2026-04-27 21:41:00', 8, 'admin', 'staff-8', NULL, 'listing.price_changed', 'listing', 231, 'listing #62', '{"price":{"from":4500000,"to":4200000}}', '{"ip":"203.0.113.126","portal":"admin"}', '01K2F2DKG0S2CK24RMJWDZA2FT'),
('2026-08-10 22:51:00', 4, 'admin', 'staff-4', NULL, 'listing.approved', 'listing', 279, 'listing #215', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.98","portal":"admin"}', '01K2F2DKG0SYVB61BRMYQKJWXE'),
('2026-07-25 09:55:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 363, 'location #71', '{"note":"see metadata"}', '{"ip":"203.0.113.93","portal":"admin"}', '01K2F2DKG0D4EPQ090BKWMAWG2'),
('2026-08-10 16:38:00', 2, 'admin', 'staff-2', NULL, 'payout.approved', 'payout', 166, 'payout #187', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.89","portal":"admin"}', '01K2F2DKG00JDBBJR62EPNXF54'),
('2026-04-21 08:56:00', 3, 'admin', 'staff-3', NULL, 'user.suspended', 'user', 64, 'user #150', '{"note":"see metadata"}', '{"ip":"203.0.113.45","portal":"admin"}', '01K2F2DKG098E6TQ0E1ZG59X9C'),
('2026-07-28 08:06:00', 2, 'admin', 'staff-2', NULL, 'settings.updated', 'setting', 30, 'setting #148', '{"note":"see metadata"}', '{"ip":"203.0.113.70","portal":"admin"}', '01K2F2DKG03FJYPNV4ZPRWCQ58'),
('2026-05-17 02:19:00', 1, 'admin', 'staff-1', NULL, 'listing.rejected', 'listing', 300, 'listing #108', '{"note":"see metadata"}', '{"ip":"203.0.113.116","portal":"admin"}', '01K2F2DKG0VQ3FRHWKASFWJAT5'),
('2026-08-01 15:12:00', 3, 'admin', 'staff-3', 5, 'user.impersonated', 'user', 172, 'user #63', '{"note":"see metadata"}', '{"ip":"203.0.113.101","portal":"admin"}', '01K2F2DKG0WKJPTAKC32WJ470Z'),
('2026-07-24 17:42:00', 2, 'admin', 'staff-2', NULL, 'listing.rejected', 'listing', 118, 'listing #6', '{"note":"see metadata"}', '{"ip":"203.0.113.144","portal":"admin"}', '01K2F2DKG0M6NGDNMK2TATYMXD'),
('2026-06-07 18:06:00', 2, 'admin', 'staff-2', 5, 'user.impersonated', 'user', 97, 'user #230', '{"note":"see metadata"}', '{"ip":"203.0.113.42","portal":"admin"}', '01K2F2DKG0G2SF3TBP9XSQTRD4'),
('2026-03-03 10:25:00', 2, 'admin', 'staff-2', NULL, 'user.reinstated', 'user', 95, 'user #172', '{"note":"see metadata"}', '{"ip":"203.0.113.231","portal":"admin"}', '01K2F2DKG04GNZDAGSH00EJD0N'),
('2026-06-08 17:20:00', 8, 'admin', 'staff-8', NULL, 'organization.suspended', 'organization', 123, 'organization #295', '{"note":"see metadata"}', '{"ip":"203.0.113.89","portal":"admin"}', '01K2F2DKG09XEKZ0E6JRQC6M5J'),
('2026-03-25 16:41:00', 2, 'admin', 'staff-2', NULL, 'user.suspended', 'user', 119, 'user #322', '{"note":"see metadata"}', '{"ip":"203.0.113.202","portal":"admin"}', '01K2F2DKG0YAXDDHVVHNDC9YKY'),
('2026-07-01 04:19:00', 4, 'admin', 'staff-4', NULL, 'user.reinstated', 'user', 285, 'user #47', '{"note":"see metadata"}', '{"ip":"203.0.113.79","portal":"admin"}', '01K2F2DKG06WS8F41KE4P0JW9S'),
('2026-05-11 09:15:00', 1, 'admin', 'staff-1', NULL, 'user.suspended', 'user', 23, 'user #115', '{"note":"see metadata"}', '{"ip":"203.0.113.237","portal":"admin"}', '01K2F2DKG0W0R0M6Z25TF5ZRD0'),
('2026-08-09 10:53:00', 5, 'admin', 'staff-5', NULL, 'settings.updated', 'setting', 86, 'setting #397', '{"note":"see metadata"}', '{"ip":"203.0.113.227","portal":"admin"}', '01K2F2DKG02TMX08WZBPBBV3WT'),
('2026-04-05 18:49:00', 7, 'admin', 'staff-7', NULL, 'listing.rejected', 'listing', 140, 'listing #6', '{"note":"see metadata"}', '{"ip":"203.0.113.159","portal":"admin"}', '01K2F2DKG0X0R3D25BNWSSF282'),
('2026-06-22 21:02:00', 6, 'admin', 'staff-6', NULL, 'user.suspended', 'user', 83, 'user #131', '{"note":"see metadata"}', '{"ip":"203.0.113.199","portal":"admin"}', '01K2F2DKG0Q2PQZVJP1GN8RBFA'),
('2026-03-07 01:16:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 398, 'location #53', '{"note":"see metadata"}', '{"ip":"203.0.113.122","portal":"admin"}', '01K2F2DKG0PANPAQRV9P4ZCEK1'),
('2026-03-21 04:50:00', 4, 'admin', 'staff-4', NULL, 'organization.suspended', 'organization', 130, 'organization #235', '{"note":"see metadata"}', '{"ip":"203.0.113.177","portal":"admin"}', '01K2F2DKG0JP8YW2X5PX6YHN4Y'),
('2026-06-30 16:09:00', 6, 'admin', 'staff-6', NULL, 'api_client.created', 'api_client', 241, 'api_client #102', '{"note":"see metadata"}', '{"ip":"203.0.113.147","portal":"admin"}', '01K2F2DKG0YNA4RQ31T364NE4F'),
('2026-07-27 11:37:00', 8, 'admin', 'staff-8', NULL, 'feature_flag.toggled', 'feature_flag', 242, 'feature_flag #180', '{"note":"see metadata"}', '{"ip":"203.0.113.18","portal":"admin"}', '01K2F2DKG023XZYQT6JPBVKTCK'),
('2026-03-09 07:38:00', 6, 'admin', 'staff-6', NULL, 'account.type_changed', 'account', 59, 'account #396', '{"note":"see metadata"}', '{"ip":"203.0.113.21","portal":"admin"}', '01K2F2DKG0X4MR0G2JXHMTE84N'),
('2026-07-10 04:47:00', 1, 'admin', 'staff-1', NULL, 'location.created', 'location', 182, 'location #298', '{"note":"see metadata"}', '{"ip":"203.0.113.176","portal":"admin"}', '01K2F2DKG02308VH8GP2YFQCC1'),
('2026-05-06 13:18:00', 4, 'admin', 'staff-4', NULL, 'feature_flag.toggled', 'feature_flag', 109, 'feature_flag #288', '{"note":"see metadata"}', '{"ip":"203.0.113.168","portal":"admin"}', '01K2F2DKG0QS5CM4HST21NBNB1'),
('2026-07-16 18:22:00', 4, 'admin', 'staff-4', NULL, 'organization.suspended', 'organization', 163, 'organization #227', '{"note":"see metadata"}', '{"ip":"203.0.113.176","portal":"admin"}', '01K2F2DKG023VVE1PX4XTS6G2D'),
('2026-03-29 08:27:00', 6, 'admin', 'staff-6', NULL, 'listing.rejected', 'listing', 269, 'listing #287', '{"note":"see metadata"}', '{"ip":"203.0.113.157","portal":"admin"}', '01K2F2DKG0RT7JBAQES1PDPAFG'),
('2026-05-14 14:47:00', 8, 'admin', 'staff-8', NULL, 'category.updated', 'category', 145, 'category #257', '{"note":"see metadata"}', '{"ip":"203.0.113.4","portal":"admin"}', '01K2F2DKG0VNTH4E8E4914JR9T'),
('2026-08-01 17:47:00', 6, 'admin', 'staff-6', NULL, 'category.updated', 'category', 195, 'category #8', '{"note":"see metadata"}', '{"ip":"203.0.113.25","portal":"admin"}', '01K2F2DKG075VK1NK00ME7X6YN'),
('2026-06-21 06:36:00', 2, 'admin', 'staff-2', NULL, 'account.type_changed', 'account', 147, 'account #132', '{"note":"see metadata"}', '{"ip":"203.0.113.126","portal":"admin"}', '01K2F2DKG0BE9GR3SMFYZJA8CP'),
('2026-05-19 03:15:00', 7, 'admin', 'staff-7', NULL, 'organization.suspended', 'organization', 235, 'organization #219', '{"note":"see metadata"}', '{"ip":"203.0.113.170","portal":"admin"}', '01K2F2DKG0P5MR8GNTNJGEBH4F'),
('2026-06-06 16:33:00', 3, 'admin', 'staff-3', NULL, 'payout.approved', 'payout', 293, 'payout #25', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.104","portal":"admin"}', '01K2F2DKG0DBYR4P3042GCT5QQ'),
('2026-07-01 10:57:00', 1, 'admin', 'staff-1', NULL, 'user.reinstated', 'user', 316, 'user #397', '{"note":"see metadata"}', '{"ip":"203.0.113.126","portal":"admin"}', '01K2F2DKG0FA6AXJ24K0Z0DT5F'),
('2026-05-07 03:55:00', 8, 'admin', 'staff-8', NULL, 'organization.verified', 'organization', 263, 'organization #228', '{"note":"see metadata"}', '{"ip":"203.0.113.191","portal":"admin"}', '01K2F2DKG0QA1XF12QH3TYM42N'),
('2026-04-12 23:26:00', 5, 'admin', 'staff-5', NULL, 'user.reinstated', 'user', 119, 'user #226', '{"note":"see metadata"}', '{"ip":"203.0.113.142","portal":"admin"}', '01K2F2DKG0QMT7Q0E77M3EGEW4'),
('2026-04-19 21:14:00', 2, 'admin', 'staff-2', 5, 'user.impersonated', 'user', 366, 'user #166', '{"note":"see metadata"}', '{"ip":"203.0.113.225","portal":"admin"}', '01K2F2DKG04WBH5GXBGFC9BCC2'),
('2026-03-04 12:12:00', 2, 'admin', 'staff-2', NULL, 'user.reinstated', 'user', 117, 'user #286', '{"note":"see metadata"}', '{"ip":"203.0.113.38","portal":"admin"}', '01K2F2DKG024Q8XVFKVKJKYY0K'),
('2026-06-26 10:56:00', 1, 'admin', 'staff-1', NULL, 'api_client.created', 'api_client', 339, 'api_client #109', '{"note":"see metadata"}', '{"ip":"203.0.113.165","portal":"admin"}', '01K2F2DKG0RBEWZM47342K5894'),
('2026-03-30 03:44:00', 3, 'admin', 'staff-3', NULL, 'account.type_changed', 'account', 250, 'account #387', '{"note":"see metadata"}', '{"ip":"203.0.113.64","portal":"admin"}', '01K2F2DKG0P5SG5BCXJX056MC0'),
('2026-07-01 00:29:00', 2, 'admin', 'staff-2', NULL, 'report.resolved', 'report', 237, 'report #104', '{"note":"see metadata"}', '{"ip":"203.0.113.57","portal":"admin"}', '01K2F2DKG0QDAX0Q5MFZ04R8B2'),
('2026-05-16 00:07:00', 7, 'admin', 'staff-7', NULL, 'user.suspended', 'user', 354, 'user #95', '{"note":"see metadata"}', '{"ip":"203.0.113.169","portal":"admin"}', '01K2F2DKG0XW1JGJ6CTV1S4254'),
('2026-05-23 06:05:00', 6, 'admin', 'staff-6', NULL, 'user.suspended', 'user', 143, 'user #238', '{"note":"see metadata"}', '{"ip":"203.0.113.12","portal":"admin"}', '01K2F2DKG0TD0SSFAF6W0P9FMM'),
('2026-03-21 02:56:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 346, 'location #66', '{"note":"see metadata"}', '{"ip":"203.0.113.211","portal":"admin"}', '01K2F2DKG0SKT0TJCDK01FJZ8B'),
('2026-03-13 09:32:00', 2, 'admin', 'staff-2', NULL, 'account.type_changed', 'account', 81, 'account #105', '{"note":"see metadata"}', '{"ip":"203.0.113.214","portal":"admin"}', '01K2F2DKG0HKKFVKWEQKV05Z56'),
('2026-08-16 03:05:00', 1, 'admin', 'staff-1', NULL, 'listing.approved', 'listing', 40, 'listing #88', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.118","portal":"admin"}', '01K2F2DKG06V6MVBQ02TQ40R84'),
('2026-04-12 00:54:00', 3, 'admin', 'staff-3', NULL, 'user.reinstated', 'user', 52, 'user #176', '{"note":"see metadata"}', '{"ip":"203.0.113.121","portal":"admin"}', '01K2F2DKG01KA8V8WD1M2D5MQF'),
('2026-05-18 17:07:00', 5, 'admin', 'staff-5', NULL, 'listing.approved', 'listing', 188, 'listing #154', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.37","portal":"admin"}', '01K2F2DKG00NE0TE77XZNF5J0T'),
('2026-06-23 21:34:00', 2, 'admin', 'staff-2', NULL, 'user.reinstated', 'user', 123, 'user #250', '{"note":"see metadata"}', '{"ip":"203.0.113.171","portal":"admin"}', '01K2F2DKG0ZAJA9YJ8D0MYKTC6'),
('2026-06-16 13:42:00', 7, 'admin', 'staff-7', NULL, 'feature_flag.toggled', 'feature_flag', 260, 'feature_flag #14', '{"note":"see metadata"}', '{"ip":"203.0.113.166","portal":"admin"}', '01K2F2DKG0ZJFGX6WYJM7JQ8SS'),
('2026-07-27 10:25:00', 3, 'admin', 'staff-3', NULL, 'settings.updated', 'setting', 245, 'setting #302', '{"note":"see metadata"}', '{"ip":"203.0.113.6","portal":"admin"}', '01K2F2DKG06AMERCV3WKBN4C1J'),
('2026-03-02 04:53:00', 8, 'admin', 'staff-8', NULL, 'organization.suspended', 'organization', 230, 'organization #302', '{"note":"see metadata"}', '{"ip":"203.0.113.128","portal":"admin"}', '01K2F2DKG0ZTT81Q263ERSMGPR'),
('2026-07-03 12:44:00', 6, 'admin', 'staff-6', NULL, 'listing.unpublished', 'listing', 347, 'listing #152', '{"note":"see metadata"}', '{"ip":"203.0.113.77","portal":"admin"}', '01K2F2DKG0ERT4EQT51TAMNAFY'),
('2026-03-11 21:08:00', 1, 'admin', 'staff-1', NULL, 'report.resolved', 'report', 100, 'report #187', '{"note":"see metadata"}', '{"ip":"203.0.113.239","portal":"admin"}', '01K2F2DKG02JB853GP4YC61ZPD'),
('2026-04-25 09:59:00', 2, 'admin', 'staff-2', NULL, 'listing.approved', 'listing', 242, 'listing #347', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.177","portal":"admin"}', '01K2F2DKG0ZTAC42XE6KPXS3VD'),
('2026-03-20 01:35:00', 5, 'admin', 'staff-5', NULL, 'location.created', 'location', 68, 'location #229', '{"note":"see metadata"}', '{"ip":"203.0.113.206","portal":"admin"}', '01K2F2DKG0VE9H9SFRD51XJXFG'),
('2026-07-28 23:01:00', 1, 'admin', 'staff-1', NULL, 'listing.approved', 'listing', 88, 'listing #83', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.2","portal":"admin"}', '01K2F2DKG0357MXTKDC43B6VD5'),
('2026-07-28 05:33:00', 2, 'admin', 'staff-2', NULL, 'payout.approved', 'payout', 13, 'payout #231', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.250","portal":"admin"}', '01K2F2DKG0Y37XX8CV4RMK1T6V'),
('2026-07-15 10:43:00', 8, 'admin', 'staff-8', NULL, 'category.updated', 'category', 174, 'category #114', '{"note":"see metadata"}', '{"ip":"203.0.113.169","portal":"admin"}', '01K2F2DKG0A3FGKG6TN538QK0H'),
('2026-03-09 04:56:00', 6, 'admin', 'staff-6', NULL, 'listing.unpublished', 'listing', 159, 'listing #27', '{"note":"see metadata"}', '{"ip":"203.0.113.52","portal":"admin"}', '01K2F2DKG0K490KTJBTV2CR2PF'),
('2026-06-12 19:47:00', 6, 'admin', 'staff-6', NULL, 'api_client.created', 'api_client', 176, 'api_client #143', '{"note":"see metadata"}', '{"ip":"203.0.113.8","portal":"admin"}', '01K2F2DKG03HYH18DG94CP80BR'),
('2026-05-16 17:19:00', 3, 'admin', 'staff-3', NULL, 'payout.approved', 'payout', 367, 'payout #287', '{"status":{"from":"pending","to":"approved"}}', '{"ip":"203.0.113.245","portal":"admin"}', '01K2F2DKG09JQZTEF4RGV29ENX'),
('2026-06-24 02:55:00', 2, 'admin', 'staff-2', NULL, 'payment.refunded', 'payment', 335, 'payment #197', '{"note":"see metadata"}', '{"ip":"203.0.113.224","portal":"admin"}', '01K2F2DKG0026DQFJPSC6X340R'),
('2026-08-08 08:18:00', 6, 'admin', 'staff-6', NULL, 'category.updated', 'category', 113, 'category #51', '{"note":"see metadata"}', '{"ip":"203.0.113.199","portal":"admin"}', '01K2F2DKG0730SR7HSYNQR1P5H'),
('2026-04-22 12:11:00', 1, 'admin', 'staff-1', NULL, 'listing.rejected', 'listing', 97, 'listing #216', '{"note":"see metadata"}', '{"ip":"203.0.113.214","portal":"admin"}', '01K2F2DKG02FA3ZC76N4EHCHCP'),
('2026-03-28 23:26:00', 4, 'admin', 'staff-4', NULL, 'payment.refunded', 'payment', 284, 'payment #26', '{"note":"see metadata"}', '{"ip":"203.0.113.192","portal":"admin"}', '01K2F2DKG0MTR5G630FEXCCXH0'),
('2026-06-06 00:18:00', 8, 'admin', 'staff-8', NULL, 'category.updated', 'category', 194, 'category #163', '{"note":"see metadata"}', '{"ip":"203.0.113.23","portal":"admin"}', '01K2F2DKG00V6RZJ59K2N0Q1ZG'),
('2026-05-07 17:51:00', 5, 'admin', 'staff-5', NULL, 'payment.refunded', 'payment', 172, 'payment #345', '{"note":"see metadata"}', '{"ip":"203.0.113.88","portal":"admin"}', '01K2F2DKG0QPCBF5EJ8E10CVAT'),
('2026-08-13 22:38:00', 4, 'admin', 'staff-4', NULL, 'location.created', 'location', 320, 'location #4', '{"note":"see metadata"}', '{"ip":"203.0.113.1","portal":"admin"}', '01K2F2DKG03666TMAZ8V846WWG');

INSERT INTO system_logs (occurred_at, level, channel, message, context, exception_class, request_id, url, http_method, http_status, duration_ms) VALUES
('2026-07-30 15:00:00', 'debug', 'app', 'Cache miss on category tree', '{"rows":4638}', NULL, '01K2F2DKG0RRA6NG4FAJ5JXPEP', '/real-estate/for-sale', 'GET', 400, 2158),
('2026-07-21 03:00:00', 'error', 'media', 'Media derivative generation failed', '{"rows":2123}', 'MediaProcessingException', '01K2F2DKG0Q59FDSJ03NJRCCDD', '/webhooks/stripe', 'GET', 200, 713),
('2026-07-01 11:00:00', 'error', 'jobs', 'Media derivative generation failed', '{"rows":802}', 'MediaProcessingException', '01K2F2DKG00103836RECWN8HH6', '/admin/listings', 'POST', 200, 1563),
('2026-07-29 02:00:00', 'warning', 'jobs', 'FX rate older than 12 hours; using last known value', '{"rows":3313}', NULL, '01K2F2DKG0QD8JCBHPQ9RJY28X', '/real-estate/for-sale', 'POST', 200, 11),
('2026-06-18 03:00:00', 'debug', 'payments', 'Cache miss on category tree', '{"rows":4295}', NULL, '01K2F2DKG0KK5ZHQPBJV5PME1W', '/api/v1/search', 'GET', 200, 2202),
('2026-07-02 17:00:00', 'debug', 'payments', 'Cache miss on category tree', '{"rows":457}', NULL, '01K2F2DKG08HTG83JKKBW8A8Y5', '/webhooks/stripe', 'GET', 200, 2736),
('2026-07-14 16:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":1376}', NULL, '01K2F2DKG0NAR7ZKC8CCH71D9M', '/admin/listings', 'GET', 500, 2578),
('2026-08-06 04:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":417}', NULL, '01K2F2DKG0827WGQMRAZP6P4H9', '/webhooks/stripe', 'POST', 404, 1834),
('2026-07-28 04:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":3814}', NULL, '01K2F2DKG0HVX77PQQXY6EARPD', '/webhooks/stripe', 'GET', 200, 1909),
('2026-06-18 16:00:00', 'debug', 'search', 'Cache miss on category tree', '{"rows":1300}', NULL, '01K2F2DKG0RJ3Z5YZ0W26N09D7', '/api/v1/search', 'POST', 404, 351),
('2026-08-15 08:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":429}', NULL, '01K2F2DKG0Z57KY3H0936B1MXR', '/real-estate/for-sale', 'GET', 201, 2173),
('2026-06-30 01:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":2158}', NULL, '01K2F2DKG0RR1TZNBQ2YS2VEYZ', '/real-estate/for-sale', 'POST', 200, 1584),
('2026-06-29 18:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":390}', NULL, '01K2F2DKG0KJT89MEYM70YHV9T', '/api/v1/listings', 'GET', 500, 1582),
('2026-06-26 06:00:00', 'error', 'app', 'Media derivative generation failed', '{"rows":2211}', 'MediaProcessingException', '01K2F2DKG0K1M48DG06NPQMVBN', '/api/v1/listings', 'POST', 500, 2574),
('2026-08-11 13:00:00', 'error', 'jobs', 'Media derivative generation failed', '{"rows":2291}', 'MediaProcessingException', '01K2F2DKG0ZN0FZDJEE76BN2DK', '/webhooks/stripe', 'GET', 200, 2915),
('2026-07-05 00:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":1681}', NULL, '01K2F2DKG06VE8938GVZ71KVCW', '/api/v1/search', 'GET', 404, 819),
('2026-07-08 20:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":4006}', NULL, '01K2F2DKG0KXCFBAY2DN5ZPCYP', '/api/v1/search', 'GET', 404, 92),
('2026-06-22 19:00:00', 'critical', 'search', 'Payment provider webhook signature mismatch', '{"rows":2808}', NULL, '01K2F2DKG0W8XTNEG9YN3BNYNN', '/real-estate/for-sale', 'GET', 200, 608),
('2026-07-16 14:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":2736}', 'MediaProcessingException', '01K2F2DKG01A8AHTZHNM4X2G5G', '/webhooks/stripe', 'GET', 200, 2664),
('2026-08-10 10:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":4742}', NULL, '01K2F2DKG079K5A1YZ2F8NWTJP', '/api/v1/search', 'GET', 200, 760),
('2026-06-20 06:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":2837}', NULL, '01K2F2DKG0GF81X243KJS1E9TA', '/api/v1/search', 'GET', 400, 2894),
('2026-07-10 02:00:00', 'error', 'payments', 'Media derivative generation failed', '{"rows":2893}', 'MediaProcessingException', '01K2F2DKG00847HM9B5WE4139B', '/api/v1/search', 'GET', 200, 2483),
('2026-08-15 18:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":1069}', NULL, '01K2F2DKG09ZJ35MS1T8F4CCN2', '/real-estate/for-sale', 'POST', 400, 3047),
('2026-07-14 20:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":1430}', NULL, '01K2F2DKG0N82EFNNTNKB1ZRT8', '/webhooks/stripe', 'GET', 500, 2761),
('2026-08-06 16:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":4807}', NULL, '01K2F2DKG0SKVSAATRQHPAK3T7', '/api/v1/listings', 'GET', 200, 2755),
('2026-08-16 19:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":4202}', NULL, '01K2F2DKG0WG68ZETS3YJNKVEM', '/real-estate/for-sale', 'GET', 201, 766),
('2026-07-06 17:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":897}', NULL, '01K2F2DKG0AK8VPTYDANJK8Z5H', '/webhooks/stripe', 'POST', 400, 3170),
('2026-07-06 20:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":1355}', NULL, '01K2F2DKG098G1TT306V0PWG81', '/api/v1/listings', 'GET', 200, 1393),
('2026-06-21 10:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":2692}', NULL, '01K2F2DKG0JPSCTDPBB5R92014', '/api/v1/search', 'POST', 400, 1719),
('2026-06-19 15:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":2908}', 'MediaProcessingException', '01K2F2DKG09XCW0MZGCS2K6MS9', '/admin/listings', 'GET', 200, 2619),
('2026-06-21 09:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":2557}', NULL, '01K2F2DKG0QE7J3RQQQR1MNM6F', '/admin/listings', 'GET', 200, 183),
('2026-08-16 16:00:00', 'error', 'payments', 'Media derivative generation failed', '{"rows":1526}', 'MediaProcessingException', '01K2F2DKG0HMV3K2BKNR4WBB3Y', '/real-estate/for-sale', 'GET', 200, 257),
('2026-08-17 06:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":3800}', NULL, '01K2F2DKG0QWAGTR01FSPF5E83', '/webhooks/stripe', 'GET', 404, 1947),
('2026-06-27 04:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":229}', NULL, '01K2F2DKG0T71DCFTMMEK2X7MS', '/api/v1/search', 'GET', 200, 2221),
('2026-08-14 06:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":3173}', NULL, '01K2F2DKG0PSXR213BD345PXQ8', '/api/v1/listings', 'POST', 201, 2574),
('2026-07-23 14:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":329}', NULL, '01K2F2DKG0DSX1VB4NE8CHTB1K', '/admin/listings', 'POST', 500, 1099),
('2026-08-13 13:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":1261}', NULL, '01K2F2DKG0M37XX2S231229H9S', '/real-estate/for-sale', 'GET', 200, 2104),
('2026-08-02 16:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":4689}', NULL, '01K2F2DKG0FXNH2ZREYRW8S4J5', '/webhooks/stripe', 'POST', 404, 2531),
('2026-07-08 08:00:00', 'critical', 'app', 'Payment provider webhook signature mismatch', '{"rows":4853}', NULL, '01K2F2DKG0YB92MAEPP9Y0XH01', '/webhooks/stripe', 'GET', 400, 1145),
('2026-07-10 23:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":2721}', NULL, '01K2F2DKG0FKF9BNS46VTS3W4Y', '/api/v1/listings', 'GET', 404, 1977),
('2026-08-11 03:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":3550}', NULL, '01K2F2DKG0RMZBSFMJR54GSDXQ', '/api/v1/search', 'GET', 500, 1215),
('2026-06-25 10:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":1682}', NULL, '01K2F2DKG0DXWCF4TT6SAW34J5', '/real-estate/for-sale', 'GET', 200, 2812),
('2026-07-29 10:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":1514}', NULL, '01K2F2DKG0MJHBD57TYZJHAE52', '/api/v1/search', 'GET', 404, 1635),
('2026-08-02 16:00:00', 'warning', 'search', 'FX rate older than 12 hours; using last known value', '{"rows":981}', NULL, '01K2F2DKG0K6YK2EV18N1YE4RM', '/admin/listings', 'GET', 500, 1704),
('2026-08-10 19:00:00', 'warning', 'jobs', 'FX rate older than 12 hours; using last known value', '{"rows":4923}', NULL, '01K2F2DKG02G3Y9ZQ3B6C069F3', '/webhooks/stripe', 'GET', 400, 1499),
('2026-07-12 22:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":3062}', NULL, '01K2F2DKG0RM5N089SY6TVXKKJ', '/webhooks/stripe', 'GET', 500, 1726),
('2026-08-11 08:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":768}', NULL, '01K2F2DKG0ATF7DF6ZYQMSEH9A', '/api/v1/search', 'POST', 200, 900),
('2026-07-06 22:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":1718}', NULL, '01K2F2DKG07Y6WNKY1EE4H19B6', '/real-estate/for-sale', 'GET', 400, 1864),
('2026-06-21 22:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":3435}', NULL, '01K2F2DKG0JE54B1ANG9K03Y33', '/api/v1/search', 'POST', 201, 520),
('2026-08-11 03:00:00', 'debug', 'app', 'Cache miss on category tree', '{"rows":4427}', NULL, '01K2F2DKG0BHG3VCK4N1EPPF7K', '/webhooks/stripe', 'POST', 200, 655),
('2026-07-11 03:00:00', 'warning', 'jobs', 'FX rate older than 12 hours; using last known value', '{"rows":4460}', NULL, '01K2F2DKG0ANG3X48EZYYWT0D0', '/api/v1/search', 'GET', 201, 953),
('2026-07-17 03:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":3194}', NULL, '01K2F2DKG0BEYXCKZRJVKYJ6X3', '/webhooks/stripe', 'GET', 200, 2227),
('2026-07-16 03:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":1497}', NULL, '01K2F2DKG0YHF4YFP81KQ1WJBT', '/real-estate/for-sale', 'GET', 200, 1642),
('2026-07-15 01:00:00', 'critical', 'jobs', 'Payment provider webhook signature mismatch', '{"rows":4302}', NULL, '01K2F2DKG0N613EKRQQVQBZJ17', '/webhooks/stripe', 'GET', 200, 5),
('2026-06-30 02:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":4891}', NULL, '01K2F2DKG0Z2EZ2Q34FHCFZ3J6', '/webhooks/stripe', 'POST', 500, 1479),
('2026-07-23 10:00:00', 'error', 'webhooks', 'Media derivative generation failed', '{"rows":317}', 'MediaProcessingException', '01K2F2DKG0ZWZXTP4D6XK0V97X', '/api/v1/search', 'GET', 400, 2607),
('2026-07-27 13:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":2514}', NULL, '01K2F2DKG04DGJPPCRSNCHVVNT', '/admin/listings', 'GET', 404, 1205),
('2026-06-24 02:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":251}', NULL, '01K2F2DKG0FJBCNZPY76P4RWNW', '/webhooks/stripe', 'POST', 201, 1663),
('2026-07-12 08:00:00', 'critical', 'search', 'Payment provider webhook signature mismatch', '{"rows":285}', NULL, '01K2F2DKG0FGZDN4EWX4HRMEDS', '/api/v1/search', 'GET', 200, 1775),
('2026-06-21 09:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":3612}', NULL, '01K2F2DKG03DRFQ6J2RJYG0K63', '/real-estate/for-sale', 'POST', 200, 1873),
('2026-07-02 04:00:00', 'error', 'webhooks', 'Media derivative generation failed', '{"rows":2557}', 'MediaProcessingException', '01K2F2DKG09FQFXV62890VR52G', '/real-estate/for-sale', 'GET', 200, 2581),
('2026-07-02 07:00:00', 'debug', 'search', 'Cache miss on category tree', '{"rows":4239}', NULL, '01K2F2DKG0EHY1D9R5ENBMAEA8', '/api/v1/search', 'GET', 400, 1075),
('2026-06-23 23:00:00', 'warning', 'app', 'FX rate older than 12 hours; using last known value', '{"rows":4132}', NULL, '01K2F2DKG02R5C5T262M2377JR', '/admin/listings', 'GET', 400, 3176),
('2026-08-06 14:00:00', 'warning', 'payments', 'FX rate older than 12 hours; using last known value', '{"rows":277}', NULL, '01K2F2DKG0BB8WEX0598ZWB0KF', '/api/v1/listings', 'GET', 201, 1900),
('2026-07-31 17:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":985}', 'MediaProcessingException', '01K2F2DKG0JXJ9Q47BFJ2ZWTBK', '/admin/listings', 'GET', 400, 1538),
('2026-07-04 15:00:00', 'warning', 'search', 'FX rate older than 12 hours; using last known value', '{"rows":1190}', NULL, '01K2F2DKG0G98GD45THCQ5B3EJ', '/real-estate/for-sale', 'GET', 201, 481),
('2026-07-14 10:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":1531}', NULL, '01K2F2DKG0WQ6V1W16E7KG8V37', '/webhooks/stripe', 'GET', 200, 908),
('2026-08-03 02:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":3408}', NULL, '01K2F2DKG0HSNRZ56DYVFDV8NK', '/real-estate/for-sale', 'GET', 200, 696),
('2026-07-04 01:00:00', 'debug', 'webhooks', 'Cache miss on category tree', '{"rows":3141}', NULL, '01K2F2DKG0WQJ0R3R6CWA986XE', '/api/v1/listings', 'GET', 200, 495),
('2026-08-09 07:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":3171}', NULL, '01K2F2DKG03DFY6GHGSSZ3RB6A', '/api/v1/listings', 'POST', 200, 1173),
('2026-06-23 13:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":3124}', 'MediaProcessingException', '01K2F2DKG0GY2YM26XT3X7V40S', '/admin/listings', 'POST', 201, 2215),
('2026-07-02 03:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":3549}', NULL, '01K2F2DKG0X9CTX82GJ6EB9YMS', '/real-estate/for-sale', 'GET', 200, 1750),
('2026-06-18 05:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":2054}', NULL, '01K2F2DKG0KNY8WDHWN5YQWC07', '/api/v1/search', 'GET', 200, 929),
('2026-07-27 17:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":3741}', NULL, '01K2F2DKG0AT5J0JCPQH7SW1J4', '/real-estate/for-sale', 'GET', 500, 3157),
('2026-06-25 12:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":3004}', NULL, '01K2F2DKG06BMF3PJQW167QX95', '/webhooks/stripe', 'POST', 400, 341),
('2026-07-16 21:00:00', 'debug', 'payments', 'Cache miss on category tree', '{"rows":855}', NULL, '01K2F2DKG0777MG9M13FHDN1EK', '/api/v1/search', 'GET', 400, 2701),
('2026-08-15 04:00:00', 'warning', 'payments', 'FX rate older than 12 hours; using last known value', '{"rows":3749}', NULL, '01K2F2DKG0E2RD7T38G6RASCXN', '/api/v1/search', 'POST', 404, 1428),
('2026-07-30 03:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":3727}', NULL, '01K2F2DKG0V4GTSEX5WYGGEH0J', '/real-estate/for-sale', 'GET', 500, 1177),
('2026-06-28 14:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":4442}', NULL, '01K2F2DKG0VWJWEPC857Q6FDTG', '/webhooks/stripe', 'POST', 404, 1616),
('2026-07-01 15:00:00', 'warning', 'payments', 'FX rate older than 12 hours; using last known value', '{"rows":2013}', NULL, '01K2F2DKG08TMWR5MBWF6JWAVT', '/real-estate/for-sale', 'GET', 400, 804),
('2026-06-29 05:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":3132}', NULL, '01K2F2DKG029MX810FXPJSVA0A', '/webhooks/stripe', 'GET', 400, 1495),
('2026-08-10 13:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":726}', NULL, '01K2F2DKG0WHCCWA6PE9GKPFA4', '/real-estate/for-sale', 'POST', 200, 277),
('2026-07-26 09:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":634}', NULL, '01K2F2DKG02MXEGPPJXKY7J2SK', '/admin/listings', 'GET', 200, 1309),
('2026-07-11 00:00:00', 'warning', 'jobs', 'FX rate older than 12 hours; using last known value', '{"rows":4489}', NULL, '01K2F2DKG09YD652W3C77894CC', '/api/v1/listings', 'POST', 201, 1854),
('2026-06-21 10:00:00', 'debug', 'payments', 'Cache miss on category tree', '{"rows":2729}', NULL, '01K2F2DKG0JJ8X2DS9ST8T707Q', '/admin/listings', 'GET', 200, 1400),
('2026-08-03 11:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":4462}', NULL, '01K2F2DKG0R6GFS0NBMJ9XV37F', '/admin/listings', 'GET', 200, 497),
('2026-06-23 00:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":1192}', NULL, '01K2F2DKG02VNPQ52Y6DHAG99C', '/api/v1/search', 'GET', 200, 533),
('2026-07-30 20:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":1375}', NULL, '01K2F2DKG0HDDDFDBQ29WF7FB3', '/webhooks/stripe', 'GET', 404, 1537),
('2026-07-03 03:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":4223}', NULL, '01K2F2DKG015GA53S3NK14XYQ2', '/admin/listings', 'GET', 201, 2741),
('2026-08-07 09:00:00', 'debug', 'app', 'Cache miss on category tree', '{"rows":755}', NULL, '01K2F2DKG0VRD1RB5M2WR85G31', '/real-estate/for-sale', 'GET', 404, 2201),
('2026-06-29 04:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":1824}', NULL, '01K2F2DKG0HTS70R5035CNCFMH', '/api/v1/search', 'POST', 400, 490),
('2026-08-13 22:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":4093}', NULL, '01K2F2DKG0TB5HJ569FK1AAQN4', '/webhooks/stripe', 'GET', 200, 762),
('2026-07-29 16:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":1198}', 'MediaProcessingException', '01K2F2DKG0AAZS1PMEP2AR9R7B', '/webhooks/stripe', 'GET', 201, 568),
('2026-07-04 14:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":1629}', NULL, '01K2F2DKG0M6HE72V5VT68NTTE', '/real-estate/for-sale', 'POST', 500, 1427),
('2026-07-10 23:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":504}', NULL, '01K2F2DKG08NDBR56K06VVSXC7', '/api/v1/search', 'GET', 400, 2756),
('2026-07-07 08:00:00', 'warning', 'payments', 'FX rate older than 12 hours; using last known value', '{"rows":2152}', NULL, '01K2F2DKG0XQ7CQ5QPGCCMX9QE', '/api/v1/listings', 'GET', 500, 1777),
('2026-07-05 10:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":4557}', NULL, '01K2F2DKG0FARGDPWPXVNHEYDB', '/admin/listings', 'POST', 200, 2295),
('2026-07-16 13:00:00', 'warning', 'jobs', 'FX rate older than 12 hours; using last known value', '{"rows":4015}', NULL, '01K2F2DKG0R4QTEGTBE2TQTE3G', '/webhooks/stripe', 'POST', 404, 1982),
('2026-07-07 07:00:00', 'debug', 'jobs', 'Cache miss on category tree', '{"rows":196}', NULL, '01K2F2DKG0QRTM4YRK4K2984G8', '/admin/listings', 'GET', 404, 2201),
('2026-08-09 11:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":2193}', NULL, '01K2F2DKG03KQQ2VJ7N3B5QXCA', '/webhooks/stripe', 'GET', 201, 11),
('2026-06-22 03:00:00', 'debug', 'jobs', 'Cache miss on category tree', '{"rows":2100}', NULL, '01K2F2DKG023937JEMQB69M3ZP', '/admin/listings', 'GET', 201, 555),
('2026-08-10 19:00:00', 'debug', 'media', 'Cache miss on category tree', '{"rows":1848}', NULL, '01K2F2DKG0RAPPZC2BDR4BKETV', '/admin/listings', 'GET', 200, 1392),
('2026-07-11 01:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":975}', NULL, '01K2F2DKG04BFGQJV38B8ZJ1VE', '/real-estate/for-sale', 'GET', 404, 1741),
('2026-07-03 13:00:00', 'error', 'media', 'Media derivative generation failed', '{"rows":3943}', 'MediaProcessingException', '01K2F2DKG0WMQYN1VS9R7VADSV', '/real-estate/for-sale', 'GET', 404, 1677),
('2026-06-24 13:00:00', 'warning', 'app', 'FX rate older than 12 hours; using last known value', '{"rows":4915}', NULL, '01K2F2DKG0S7Z70CXHAYV6XMHD', '/api/v1/search', 'GET', 201, 592),
('2026-07-28 06:00:00', 'warning', 'search', 'FX rate older than 12 hours; using last known value', '{"rows":894}', NULL, '01K2F2DKG0Y3TQGEQ2VVY707V1', '/webhooks/stripe', 'GET', 201, 2544),
('2026-07-10 09:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":3523}', NULL, '01K2F2DKG0QGS0X58A5YW38F81', '/admin/listings', 'GET', 200, 2937),
('2026-06-24 15:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":451}', NULL, '01K2F2DKG0GXWT00DZRWQ5PBSV', '/api/v1/listings', 'GET', 200, 717),
('2026-07-14 06:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":4153}', NULL, '01K2F2DKG0B1J64N3XW4ZKJ5E0', '/api/v1/listings', 'POST', 201, 1067),
('2026-07-04 14:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":2822}', NULL, '01K2F2DKG0PNH36Z5CWAGXYHXN', '/api/v1/search', 'GET', 200, 816),
('2026-08-01 12:00:00', 'debug', 'search', 'Cache miss on category tree', '{"rows":588}', NULL, '01K2F2DKG0P37P6RV20EXJXTCR', '/api/v1/listings', 'GET', 404, 2611),
('2026-07-17 15:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":4143}', NULL, '01K2F2DKG04N2E9BXAQATMDM70', '/api/v1/listings', 'GET', 404, 2346),
('2026-07-30 11:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":253}', NULL, '01K2F2DKG0YEZP05N6ZJWJHNXW', '/api/v1/search', 'GET', 500, 823),
('2026-08-17 09:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":4648}', NULL, '01K2F2DKG0B6B649E2BYCGYBF9', '/admin/listings', 'GET', 400, 2813),
('2026-07-18 19:00:00', 'warning', 'app', 'FX rate older than 12 hours; using last known value', '{"rows":412}', NULL, '01K2F2DKG09DW4MNZ5F7GYP3D8', '/api/v1/search', 'GET', 200, 892),
('2026-07-05 18:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":2463}', NULL, '01K2F2DKG0BYKX27CHS6STKDS5', '/webhooks/stripe', 'GET', 200, 1305),
('2026-07-19 04:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":4786}', NULL, '01K2F2DKG0A5SKR87RMX97J0E4', '/admin/listings', 'GET', 200, 1077),
('2026-08-17 01:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":3207}', NULL, '01K2F2DKG0W6YRNGBT3KZ8MFR5', '/api/v1/search', 'GET', 200, 2491),
('2026-08-10 12:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":4733}', NULL, '01K2F2DKG0X5T3CN7FM7CCV11Z', '/api/v1/search', 'GET', 400, 2005),
('2026-07-23 11:00:00', 'debug', 'media', 'Cache miss on category tree', '{"rows":4260}', NULL, '01K2F2DKG0P4YV6YW8AK3TZ5YS', '/api/v1/listings', 'GET', 200, 1736),
('2026-08-14 05:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":234}', 'MediaProcessingException', '01K2F2DKG0T7P2SV6BQPE1ERM9', '/api/v1/listings', 'GET', 201, 623),
('2026-06-20 04:00:00', 'debug', 'app', 'Cache miss on category tree', '{"rows":4449}', NULL, '01K2F2DKG0RFQDW0M385P7S504', '/real-estate/for-sale', 'GET', 500, 1991),
('2026-08-12 18:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":4349}', NULL, '01K2F2DKG0KZP6Y2DCGAJP72PP', '/api/v1/search', 'GET', 400, 2357),
('2026-07-11 08:00:00', 'error', 'webhooks', 'Media derivative generation failed', '{"rows":4746}', 'MediaProcessingException', '01K2F2DKG0E2V2GSVHSG5RTQTW', '/api/v1/listings', 'GET', 200, 825),
('2026-08-15 11:00:00', 'warning', 'search', 'FX rate older than 12 hours; using last known value', '{"rows":2900}', NULL, '01K2F2DKG0RGXH8D7CGW4YB0V2', '/api/v1/search', 'GET', 201, 241),
('2026-07-20 16:00:00', 'error', 'payments', 'Media derivative generation failed', '{"rows":3161}', 'MediaProcessingException', '01K2F2DKG0PTXAVCSSWTFHGCJB', '/admin/listings', 'GET', 201, 758),
('2026-06-21 00:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":4364}', NULL, '01K2F2DKG0SY879J34AW0FBXG3', '/webhooks/stripe', 'GET', 200, 787),
('2026-06-20 17:00:00', 'warning', 'jobs', 'FX rate older than 12 hours; using last known value', '{"rows":3406}', NULL, '01K2F2DKG04XG3ENVSEYWHDGA9', '/real-estate/for-sale', 'GET', 200, 2024),
('2026-08-01 16:00:00', 'debug', 'media', 'Cache miss on category tree', '{"rows":3557}', NULL, '01K2F2DKG0F6BBZ2F6DJGQMAWG', '/webhooks/stripe', 'GET', 200, 1716),
('2026-07-27 03:00:00', 'debug', 'jobs', 'Cache miss on category tree', '{"rows":3884}', NULL, '01K2F2DKG0VHDQ0N9FYPEYJQV4', '/admin/listings', 'GET', 404, 1391),
('2026-06-23 11:00:00', 'warning', 'search', 'FX rate older than 12 hours; using last known value', '{"rows":4435}', NULL, '01K2F2DKG0PA2GK15CBVF604CC', '/admin/listings', 'GET', 200, 2191),
('2026-07-21 00:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":4172}', 'MediaProcessingException', '01K2F2DKG01BGM1DSZP053249J', '/real-estate/for-sale', 'GET', 200, 2965),
('2026-07-02 21:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":2907}', NULL, '01K2F2DKG0GSN0GK1C8GEG1BJ5', '/api/v1/search', 'POST', 200, 1571),
('2026-07-22 22:00:00', 'debug', 'webhooks', 'Cache miss on category tree', '{"rows":3670}', NULL, '01K2F2DKG0BPMV57N95JB1PZ00', '/api/v1/listings', 'GET', 200, 427),
('2026-07-20 18:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":3971}', NULL, '01K2F2DKG0YZ6QT1QQSB6M0JHC', '/admin/listings', 'GET', 500, 207),
('2026-07-27 06:00:00', 'warning', 'app', 'FX rate older than 12 hours; using last known value', '{"rows":3277}', NULL, '01K2F2DKG05768S9JF0GJQB823', '/api/v1/search', 'GET', 400, 330),
('2026-06-30 19:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":1857}', NULL, '01K2F2DKG0ZWQ8FW2XYCYWC0MC', '/admin/listings', 'GET', 200, 2567),
('2026-07-05 10:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":161}', NULL, '01K2F2DKG0E327WQAR7TTW1NJ2', '/admin/listings', 'GET', 500, 2034),
('2026-08-01 17:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":4287}', NULL, '01K2F2DKG0SQ1NZVCXV4R3493T', '/real-estate/for-sale', 'GET', 201, 1956),
('2026-06-19 17:00:00', 'critical', 'jobs', 'Payment provider webhook signature mismatch', '{"rows":4213}', NULL, '01K2F2DKG0G9HJBQ14XG6XNEVJ', '/webhooks/stripe', 'GET', 200, 1556),
('2026-07-23 09:00:00', 'debug', 'payments', 'Cache miss on category tree', '{"rows":3646}', NULL, '01K2F2DKG0D6RMVW6KKBSZN1ZQ', '/webhooks/stripe', 'POST', 200, 2665),
('2026-08-12 08:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":3186}', NULL, '01K2F2DKG0PAQ727C3W0AZPBEW', '/admin/listings', 'POST', 201, 124),
('2026-06-18 14:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":1334}', NULL, '01K2F2DKG0AKA6QCRYCE7KHBA1', '/admin/listings', 'GET', 200, 2228),
('2026-07-19 13:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":2512}', NULL, '01K2F2DKG0QZ0A8FQHZFJC11B3', '/api/v1/search', 'GET', 500, 3066),
('2026-07-16 17:00:00', 'debug', 'webhooks', 'Cache miss on category tree', '{"rows":1880}', NULL, '01K2F2DKG01S6MQW9W3EJ23JHX', '/real-estate/for-sale', 'GET', 200, 1860),
('2026-07-20 14:00:00', 'error', 'webhooks', 'Media derivative generation failed', '{"rows":1484}', 'MediaProcessingException', '01K2F2DKG0GA2J3QTDF5MVX7HD', '/api/v1/search', 'POST', 200, 408),
('2026-07-19 21:00:00', 'error', 'webhooks', 'Media derivative generation failed', '{"rows":1151}', 'MediaProcessingException', '01K2F2DKG04HYVK17ATGXXKY1B', '/webhooks/stripe', 'POST', 200, 197),
('2026-07-30 00:00:00', 'error', 'payments', 'Media derivative generation failed', '{"rows":4252}', 'MediaProcessingException', '01K2F2DKG04EJXYKNMXHATXGX7', '/admin/listings', 'GET', 201, 2473),
('2026-07-05 23:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":1667}', 'MediaProcessingException', '01K2F2DKG0BXCSZH54CRSWJNPB', '/real-estate/for-sale', 'GET', 404, 1830),
('2026-08-03 02:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":2075}', 'MediaProcessingException', '01K2F2DKG0TBKSZAC5XDN6FJCC', '/webhooks/stripe', 'GET', 404, 606),
('2026-07-11 07:00:00', 'debug', 'search', 'Cache miss on category tree', '{"rows":3875}', NULL, '01K2F2DKG0TGKP17JYQKZZKT6D', '/admin/listings', 'POST', 404, 2289),
('2026-07-01 01:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":2726}', NULL, '01K2F2DKG08SKHZV6R0WHFNSWQ', '/api/v1/listings', 'GET', 400, 1058),
('2026-08-10 04:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":4292}', NULL, '01K2F2DKG0W9RNV0177GPVHE9X', '/real-estate/for-sale', 'GET', 200, 2580),
('2026-06-28 04:00:00', 'warning', 'app', 'FX rate older than 12 hours; using last known value', '{"rows":4977}', NULL, '01K2F2DKG0N2RJR364XJ740MQC', '/admin/listings', 'GET', 404, 2559),
('2026-07-16 15:00:00', 'debug', 'payments', 'Cache miss on category tree', '{"rows":114}', NULL, '01K2F2DKG0E5D8GR5QH0HN2EA8', '/admin/listings', 'GET', 500, 1953),
('2026-07-17 08:00:00', 'warning', 'app', 'FX rate older than 12 hours; using last known value', '{"rows":2946}', NULL, '01K2F2DKG0BT43HBBZ5VZ4P86E', '/api/v1/search', 'GET', 200, 2386),
('2026-08-15 03:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":3307}', NULL, '01K2F2DKG07XDQPNSZB29FX44N', '/admin/listings', 'GET', 200, 2673),
('2026-07-03 03:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":3756}', NULL, '01K2F2DKG07HKTMEZ5771EG38R', '/webhooks/stripe', 'GET', 200, 1160),
('2026-07-06 13:00:00', 'warning', 'search', 'FX rate older than 12 hours; using last known value', '{"rows":4092}', NULL, '01K2F2DKG094RC0JS6TGC3EDYY', '/api/v1/listings', 'GET', 200, 2098),
('2026-06-19 08:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":2211}', NULL, '01K2F2DKG099JZ3TJ27Y8EE9AG', '/api/v1/search', 'POST', 500, 1925),
('2026-08-04 06:00:00', 'warning', 'payments', 'FX rate older than 12 hours; using last known value', '{"rows":1363}', NULL, '01K2F2DKG0C59WQNA1H2X34DNJ', '/real-estate/for-sale', 'GET', 400, 514),
('2026-06-19 23:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":3330}', NULL, '01K2F2DKG0WZC4XKNEW2K0QESJ', '/admin/listings', 'GET', 400, 1987),
('2026-07-31 18:00:00', 'debug', 'jobs', 'Cache miss on category tree', '{"rows":3548}', NULL, '01K2F2DKG0E9F4AA3RCM3QP27N', '/api/v1/listings', 'GET', 500, 644),
('2026-06-18 08:00:00', 'debug', 'media', 'Cache miss on category tree', '{"rows":1743}', NULL, '01K2F2DKG0YXNA9PQ0CJ3PQRA0', '/admin/listings', 'POST', 201, 2879),
('2026-08-01 18:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":1269}', NULL, '01K2F2DKG0AHYE1AFB70ZAEE76', '/webhooks/stripe', 'GET', 200, 2242),
('2026-07-22 12:00:00', 'error', 'app', 'Media derivative generation failed', '{"rows":3126}', 'MediaProcessingException', '01K2F2DKG0D20EBCHCFFDJ5KT4', '/api/v1/search', 'GET', 200, 2710),
('2026-07-03 16:00:00', 'debug', 'media', 'Cache miss on category tree', '{"rows":2438}', NULL, '01K2F2DKG0GQMCAS4MMDA76J75', '/real-estate/for-sale', 'GET', 404, 2454),
('2026-07-29 01:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":1006}', NULL, '01K2F2DKG02F74A4NFHQF1NTBE', '/api/v1/listings', 'GET', 200, 3089),
('2026-07-06 13:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":1158}', NULL, '01K2F2DKG08P4X6NSRA0JQAYMN', '/webhooks/stripe', 'POST', 201, 2198),
('2026-06-17 14:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":683}', NULL, '01K2F2DKG00ZZC1REKXTFEPEQP', '/api/v1/listings', 'GET', 200, 1556),
('2026-07-28 18:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":1805}', NULL, '01K2F2DKG0XF90HN3Y8B814D3X', '/webhooks/stripe', 'POST', 400, 2660),
('2026-07-19 17:00:00', 'error', 'app', 'Media derivative generation failed', '{"rows":622}', 'MediaProcessingException', '01K2F2DKG05NN8RKYDAYS8T5ZD', '/webhooks/stripe', 'GET', 200, 183),
('2026-08-04 18:00:00', 'critical', 'jobs', 'Payment provider webhook signature mismatch', '{"rows":509}', NULL, '01K2F2DKG0F2XBF6F1NF0QHVSM', '/api/v1/listings', 'GET', 400, 2292),
('2026-07-01 17:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":270}', NULL, '01K2F2DKG0NHQTZ18XESFSDV0F', '/api/v1/search', 'GET', 200, 770),
('2026-08-09 09:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":441}', NULL, '01K2F2DKG02T3HM91QFK48SBRX', '/api/v1/listings', 'GET', 200, 513),
('2026-07-12 05:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":1077}', NULL, '01K2F2DKG0V656CZ4EE0V8SF4Q', '/api/v1/search', 'GET', 500, 1168),
('2026-06-26 09:00:00', 'debug', 'media', 'Cache miss on category tree', '{"rows":1297}', NULL, '01K2F2DKG08JSSP4Z3MT46XYDC', '/real-estate/for-sale', 'POST', 404, 2415),
('2026-07-17 23:00:00', 'error', 'app', 'Media derivative generation failed', '{"rows":3597}', 'MediaProcessingException', '01K2F2DKG04CJKTSM6Z6FKAH9H', '/webhooks/stripe', 'GET', 400, 1891),
('2026-07-02 19:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":4307}', NULL, '01K2F2DKG0E7W1N8NNFD4ZN5YC', '/admin/listings', 'GET', 200, 1613),
('2026-07-23 21:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":4044}', NULL, '01K2F2DKG0JQFAWE5QRMH4NC3M', '/real-estate/for-sale', 'POST', 201, 2379),
('2026-06-26 15:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":1009}', 'MediaProcessingException', '01K2F2DKG0AYXKRD5SVJRV2XCG', '/real-estate/for-sale', 'GET', 200, 213),
('2026-07-09 11:00:00', 'warning', 'search', 'FX rate older than 12 hours; using last known value', '{"rows":1450}', NULL, '01K2F2DKG01PBTBFBKYZY08XP4', '/webhooks/stripe', 'POST', 200, 886),
('2026-07-09 22:00:00', 'error', 'jobs', 'Media derivative generation failed', '{"rows":2508}', 'MediaProcessingException', '01K2F2DKG03JCKSW29FB289132', '/api/v1/listings', 'GET', 400, 445),
('2026-08-14 02:00:00', 'debug', 'jobs', 'Cache miss on category tree', '{"rows":1824}', NULL, '01K2F2DKG0NCDDKXY0MFH50DFB', '/webhooks/stripe', 'GET', 201, 141),
('2026-07-19 06:00:00', 'debug', 'app', 'Cache miss on category tree', '{"rows":893}', NULL, '01K2F2DKG0BZ5PD7565G78TWQ9', '/admin/listings', 'GET', 200, 2990),
('2026-07-14 06:00:00', 'error', 'jobs', 'Media derivative generation failed', '{"rows":4507}', 'MediaProcessingException', '01K2F2DKG0SC71F1XZJ32D0J5P', '/admin/listings', 'GET', 500, 1524),
('2026-07-20 05:00:00', 'error', 'media', 'Media derivative generation failed', '{"rows":1366}', 'MediaProcessingException', '01K2F2DKG04HJ2RWVBEN1C024K', '/admin/listings', 'GET', 500, 1153),
('2026-06-26 04:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":4590}', NULL, '01K2F2DKG06GDJK7VD65C8EGNP', '/admin/listings', 'GET', 200, 2634),
('2026-07-25 10:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":3671}', NULL, '01K2F2DKG0N0Y71RCVRGKDZXJ3', '/real-estate/for-sale', 'POST', 201, 468),
('2026-07-30 05:00:00', 'critical', 'jobs', 'Payment provider webhook signature mismatch', '{"rows":2205}', NULL, '01K2F2DKG0XYB1X317MFYQYAQD', '/admin/listings', 'GET', 400, 1253),
('2026-06-25 19:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":4502}', NULL, '01K2F2DKG0YFP83EJAY9DYPY86', '/admin/listings', 'GET', 200, 445),
('2026-07-09 19:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":827}', NULL, '01K2F2DKG0NYHJ7TB5Z7WKA04H', '/webhooks/stripe', 'POST', 200, 2848),
('2026-08-02 03:00:00', 'warning', 'search', 'FX rate older than 12 hours; using last known value', '{"rows":34}', NULL, '01K2F2DKG0ABEH0VNVNAYC0NNQ', '/api/v1/search', 'GET', 404, 588),
('2026-07-21 21:00:00', 'info', 'search', 'Search projection refreshed', '{"rows":4352}', NULL, '01K2F2DKG0BPX8PP09EC8P7YP9', '/webhooks/stripe', 'GET', 400, 1757),
('2026-06-30 03:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":448}', 'MediaProcessingException', '01K2F2DKG0E6DWXB3D66SAS4EP', '/api/v1/search', 'GET', 200, 1938),
('2026-08-11 10:00:00', 'debug', 'media', 'Cache miss on category tree', '{"rows":2105}', NULL, '01K2F2DKG0KMR4K21NCKPEN1Z6', '/api/v1/search', 'GET', 404, 2612),
('2026-06-30 06:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":3270}', NULL, '01K2F2DKG0B2NC1E3BV7HGRNDW', '/api/v1/listings', 'GET', 200, 1874),
('2026-07-03 23:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":1826}', NULL, '01K2F2DKG0N9AHW33BYB84FKZ8', '/admin/listings', 'GET', 200, 767),
('2026-07-03 09:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":3928}', NULL, '01K2F2DKG019C3HN5C6EZ0DWFA', '/real-estate/for-sale', 'POST', 500, 3100),
('2026-06-19 10:00:00', 'critical', 'jobs', 'Payment provider webhook signature mismatch', '{"rows":2792}', NULL, '01K2F2DKG0SHHQPGT8M0XEWEMH', '/admin/listings', 'GET', 400, 2907),
('2026-07-06 17:00:00', 'warning', 'search', 'FX rate older than 12 hours; using last known value', '{"rows":4890}', NULL, '01K2F2DKG0PD55V5V9AKM4PTNW', '/admin/listings', 'GET', 200, 1204),
('2026-08-11 22:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":3889}', NULL, '01K2F2DKG0RT187ZSRVNSAPK4Z', '/admin/listings', 'GET', 400, 2382),
('2026-08-16 20:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":2785}', NULL, '01K2F2DKG07PAG1319HJ1H8373', '/api/v1/listings', 'GET', 200, 1376),
('2026-06-22 05:00:00', 'error', 'search', 'Media derivative generation failed', '{"rows":2846}', 'MediaProcessingException', '01K2F2DKG01TGMP3BQRS2M4NXC', '/webhooks/stripe', 'POST', 404, 812),
('2026-07-13 20:00:00', 'debug', 'webhooks', 'Cache miss on category tree', '{"rows":1232}', NULL, '01K2F2DKG009FD64ZK332D14Y9', '/webhooks/stripe', 'GET', 201, 1650),
('2026-06-28 08:00:00', 'error', 'jobs', 'Media derivative generation failed', '{"rows":4668}', 'MediaProcessingException', '01K2F2DKG014MHX035RXQRW2Y3', '/api/v1/listings', 'GET', 200, 1688),
('2026-07-02 13:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":3270}', NULL, '01K2F2DKG0HFRXXF7TE33MFT5E', '/webhooks/stripe', 'GET', 400, 2785),
('2026-08-06 05:00:00', 'debug', 'media', 'Cache miss on category tree', '{"rows":4698}', NULL, '01K2F2DKG06YXPVNVAMZ38DF5J', '/api/v1/search', 'GET', 404, 1792),
('2026-08-04 05:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":1297}', NULL, '01K2F2DKG0AGW3YF153S4WP1CN', '/real-estate/for-sale', 'GET', 404, 2626),
('2026-08-03 03:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":4437}', NULL, '01K2F2DKG0MYQ5TZ5N08Z52NR0', '/api/v1/search', 'GET', 404, 2758),
('2026-07-05 05:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":4291}', NULL, '01K2F2DKG08KTCV3G0EJH7RAEZ', '/api/v1/search', 'POST', 404, 1705),
('2026-06-27 23:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":2528}', NULL, '01K2F2DKG0AVRBHHHZE15GKJZT', '/webhooks/stripe', 'GET', 200, 2655),
('2026-08-03 10:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":3386}', NULL, '01K2F2DKG0KQXEVN4G2QMG2DDH', '/api/v1/listings', 'GET', 200, 1726),
('2026-07-08 02:00:00', 'error', 'media', 'Media derivative generation failed', '{"rows":52}', 'MediaProcessingException', '01K2F2DKG08M25HEHTJP9T09PK', '/api/v1/listings', 'GET', 404, 2947),
('2026-06-21 13:00:00', 'debug', 'payments', 'Cache miss on category tree', '{"rows":1856}', NULL, '01K2F2DKG0N3VC367AAHAE2XM9', '/admin/listings', 'GET', 200, 451),
('2026-07-25 07:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":3918}', NULL, '01K2F2DKG0PJ0X24EPES1T32D7', '/api/v1/search', 'GET', 200, 771),
('2026-07-22 10:00:00', 'error', 'payments', 'Media derivative generation failed', '{"rows":321}', 'MediaProcessingException', '01K2F2DKG0ZN6CPJZCBSBJA0P8', '/webhooks/stripe', 'GET', 400, 2637),
('2026-07-19 14:00:00', 'critical', 'payments', 'Payment provider webhook signature mismatch', '{"rows":4596}', NULL, '01K2F2DKG0D3QFYF4HVQJD6KM6', '/admin/listings', 'GET', 400, 1990),
('2026-06-28 03:00:00', 'debug', 'media', 'Cache miss on category tree', '{"rows":17}', NULL, '01K2F2DKG0H090K94BK97B4CRR', '/api/v1/search', 'POST', 201, 1992),
('2026-07-07 13:00:00', 'debug', 'jobs', 'Cache miss on category tree', '{"rows":2477}', NULL, '01K2F2DKG0EK0T154SYC10KP5M', '/api/v1/listings', 'GET', 200, 761),
('2026-06-29 10:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":401}', NULL, '01K2F2DKG02SYWBA4KSCZFSJEM', '/real-estate/for-sale', 'GET', 200, 2960),
('2026-07-13 10:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":2804}', NULL, '01K2F2DKG0KX2RHP0X79WXQ4QM', '/admin/listings', 'POST', 200, 2012),
('2026-08-10 06:00:00', 'info', 'payments', 'Search projection refreshed', '{"rows":807}', NULL, '01K2F2DKG00965W8DWJHGX664T', '/admin/listings', 'GET', 400, 3075),
('2026-07-01 08:00:00', 'critical', 'jobs', 'Payment provider webhook signature mismatch', '{"rows":3869}', NULL, '01K2F2DKG0BS38THBAZ6QJ9J4K', '/api/v1/listings', 'GET', 404, 2849),
('2026-08-08 21:00:00', 'error', 'media', 'Media derivative generation failed', '{"rows":1784}', 'MediaProcessingException', '01K2F2DKG0H4ZYF3DBYQ0T6P02', '/api/v1/listings', 'GET', 200, 168),
('2026-07-23 12:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":4936}', NULL, '01K2F2DKG0KPS884S2CDH3HMY8', '/api/v1/search', 'GET', 400, 853),
('2026-08-12 19:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":3429}', NULL, '01K2F2DKG0ZBCQ25MZR6RH2JMA', '/admin/listings', 'GET', 200, 1491),
('2026-06-18 18:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":1778}', NULL, '01K2F2DKG0WQFZJ0MXP20JXP9J', '/real-estate/for-sale', 'GET', 200, 690),
('2026-07-04 19:00:00', 'error', 'app', 'Media derivative generation failed', '{"rows":4016}', 'MediaProcessingException', '01K2F2DKG0ZDRK8ZAFJC1TXEQY', '/api/v1/search', 'GET', 200, 2536),
('2026-06-30 20:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":913}', NULL, '01K2F2DKG0C8G6SMGX0Q560ZB9', '/api/v1/search', 'GET', 200, 2873),
('2026-06-27 02:00:00', 'critical', 'app', 'Payment provider webhook signature mismatch', '{"rows":234}', NULL, '01K2F2DKG0AZ534K17B4K57XXP', '/admin/listings', 'POST', 404, 2047),
('2026-07-27 12:00:00', 'info', 'media', 'Search projection refreshed', '{"rows":4458}', NULL, '01K2F2DKG05YZRZJXEFCJE65P5', '/api/v1/listings', 'GET', 200, 1158),
('2026-08-07 23:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":4022}', NULL, '01K2F2DKG08VP71ZDMG0VEAVG0', '/admin/listings', 'GET', 201, 2183),
('2026-06-21 07:00:00', 'info', 'jobs', 'Search projection refreshed', '{"rows":527}', NULL, '01K2F2DKG0ESYM11061RKT1BKJ', '/api/v1/listings', 'GET', 200, 2935),
('2026-08-12 22:00:00', 'warning', 'webhooks', 'FX rate older than 12 hours; using last known value', '{"rows":2587}', NULL, '01K2F2DKG0GMYRV4NJN6JCXTKE', '/webhooks/stripe', 'GET', 200, 1527),
('2026-07-09 21:00:00', 'error', 'webhooks', 'Media derivative generation failed', '{"rows":596}', 'MediaProcessingException', '01K2F2DKG0HPEVWA1W6QSMMNXM', '/real-estate/for-sale', 'GET', 400, 1062),
('2026-07-12 20:00:00', 'warning', 'media', 'FX rate older than 12 hours; using last known value', '{"rows":928}', NULL, '01K2F2DKG0VAGKV2502WF0ZD67', '/admin/listings', 'GET', 200, 2192),
('2026-08-06 17:00:00', 'info', 'app', 'Search projection refreshed', '{"rows":788}', NULL, '01K2F2DKG0Q6N7DCVXHEN7TGWZ', '/webhooks/stripe', 'GET', 200, 544),
('2026-07-15 23:00:00', 'info', 'webhooks', 'Search projection refreshed', '{"rows":942}', NULL, '01K2F2DKG0VJZ7SR15GY3ATMJZ', '/admin/listings', 'POST', 200, 2177),
('2026-06-29 19:00:00', 'critical', 'media', 'Payment provider webhook signature mismatch', '{"rows":4861}', NULL, '01K2F2DKG0Q4MBTKKZFRCNB0Q6', '/webhooks/stripe', 'GET', 400, 521);

INSERT INTO api_clients (id, public_id, organization_id, name, client_id, secret_hash, secret_hint, scopes, rate_limit_per_minute, status, last_used_at, created_by_user_id, created_at) VALUES
(1, '01K2F2DKG0YDMJDBSFKJ3DTZS7', 1, 'Prime Properties — inventory feed', 'lf_01k2f2dkg0s6bf2qj61y', UNHEX(SHA2('demo-api-secret-1', 256)), 'dead', '["listings:read","listings:write","inquiries:read"]', 300, 'active', '2026-08-11 14:00:00', 1, '2025-05-02 09:00:00'),
(2, '01K2F2DKG0SYS07HZEC1QR8R8Z', 2, 'Luxhabitat Real Estate — inventory feed', 'lf_01k2f2dkg0cqe5e90mbw', UNHEX(SHA2('demo-api-secret-2', 256)), 'bae9', '["listings:read","listings:write","inquiries:read"]', 300, 'active', '2026-08-15 03:00:00', 1, '2026-04-03 09:00:00'),
(3, '01K2F2DKG0J63JN5W4HVN1K4PV', 3, 'Driven Estates — inventory feed', 'lf_01k2f2dkg0qnt53pgkmt', UNHEX(SHA2('demo-api-secret-3', 256)), 'f463', '["listings:read","listings:write","inquiries:read"]', 60, 'active', '2026-08-09 11:00:00', 1, '2026-04-20 09:00:00'),
(4, '01K2F2DKG0HZVKE2Z14Y1H3NAY', 4, 'Sotheby''s International Motors — inventory feed', 'lf_01k2f2dkg0h63xw10h0q', UNHEX(SHA2('demo-api-secret-4', 256)), '0a13', '["listings:read","listings:write","inquiries:read"]', 120, 'active', '2026-08-16 04:00:00', 1, '2026-02-18 09:00:00'),
(5, '01K2F2DKG0ZG3Q1241EJ22WZD2', 5, 'Christie''s International Automotive — inventory feed', 'lf_01k2f2dkg0by34400wgr', UNHEX(SHA2('demo-api-secret-5', 256)), '08a9', '["listings:read","listings:write","inquiries:read"]', 300, 'active', '2026-08-12 22:00:00', 1, '2025-08-05 09:00:00'),
(6, '01K2F2DKG030FMC4QR0Q0V4PVX', 6, 'Knight Yachts — inventory feed', 'lf_01k2f2dkg0pt529mymna', UNHEX(SHA2('demo-api-secret-6', 256)), 'eb49', '["listings:read","listings:write","inquiries:read"]', 120, 'active', '2026-08-15 02:00:00', 1, '2025-11-04 09:00:00'),
(7, '01K2F2DKG0AMQFXZ6AC7JYNBP8', 7, 'Halcyon Marine — inventory feed', 'lf_01k2f2dkg0sfbwyd7te6', UNHEX(SHA2('demo-api-secret-7', 256)), '5518', '["listings:read","listings:write","inquiries:read"]', 120, 'active', '2026-08-12 10:00:00', 1, '2025-05-27 09:00:00'),
(8, '01K2F2DKG0VZJZD4XX96NTDBQW', 8, 'Aurum Aviation — inventory feed', 'lf_01k2f2dkg07fcjeayq25', UNHEX(SHA2('demo-api-secret-8', 256)), 'c9ce', '["listings:read","listings:write","inquiries:read"]', 60, 'active', '2026-08-12 11:00:00', 1, '2025-05-28 09:00:00');

-- secret_hash above is the SHA-256 of a throwaway string. No usable secret
-- exists for these demo clients, and none should: rotate before any
-- non-local use.
INSERT INTO webhooks (public_id, account_id, name, target_url, events, status, consecutive_failures, last_success_at, created_at) VALUES
('01K2F2DKG0SQXA262AKCMV3HRY', 1, 'Prime Properties — lead push', 'https://crm.prime-properties.com/hooks/livfinder', '["inquiry.created","listing.published","offer.received"]', 'active', 0, '2026-08-13 22:00:00', '2026-01-20 09:00:00'),
('01K2F2DKG0STF8C3JVFAA3P3PX', 2, 'Luxhabitat Real Estate — lead push', 'https://crm.luxhabitat-real-estate.com/hooks/livfinder', '["inquiry.created","listing.published","offer.received"]', 'paused', 3, '2026-08-16 17:00:00', '2026-01-28 09:00:00'),
('01K2F2DKG0KN2VK21NNF5RJQVF', 3, 'Driven Estates — lead push', 'https://crm.driven-estates.com/hooks/livfinder', '["inquiry.created","listing.published","offer.received"]', 'failing', 0, '2026-08-09 20:00:00', '2026-02-19 09:00:00'),
('01K2F2DKG0PXBT0WXCK8VJHM3J', 4, 'Sotheby''s International Motors — lead push', 'https://crm.sotheby-s-international-motors.com/hooks/livfinder', '["inquiry.created","listing.published","offer.received"]', 'failing', 0, '2026-08-17 05:00:00', '2025-11-17 09:00:00'),
('01K2F2DKG0CKQ9EX9QSRFNJ5N1', 5, 'Christie''s International Automotive — lead push', 'https://crm.christie-s-international-automotive.com/hooks/livfinder', '["inquiry.created","listing.published","offer.received"]', 'active', 3, '2026-08-17 02:00:00', '2026-01-03 09:00:00'),
('01K2F2DKG0JKXXF108DWM6EFEW', 6, 'Knight Yachts — lead push', 'https://crm.knight-yachts.com/hooks/livfinder', '["inquiry.created","listing.published","offer.received"]', 'active', 0, '2026-08-13 18:00:00', '2026-06-28 09:00:00');

-- Same treatment for webhook signing secrets.
UPDATE webhooks SET secret_hash = UNHEX(SHA2(CONCAT('demo-webhook-', id), 256));

COMMIT;
SET autocommit = 1;
