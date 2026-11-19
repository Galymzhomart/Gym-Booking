-- cleanup_test_rows.sql  (Shokan)
-- Removes the leftovers of OLD verify_rules.sql runs: test bookings V-xx, test sessions V-Sx
-- (location 'Test Hall') and test trainers T-V1 / T-V2. Real and demo data is not touched.
-- Run as postgres. Step 1: look at what will be deleted. Step 2: delete.

-- STEP 1 (preview, run it first)
SELECT 'booking' AS kind, booking_id AS id, status AS info FROM bookings WHERE booking_id LIKE 'V-%'
UNION ALL SELECT 'session', session_id, location FROM sessions WHERE session_id LIKE 'V-S%'
UNION ALL SELECT 'trainer', trainer_id, full_name FROM trainers WHERE trainer_id LIKE 'T-V%'
ORDER BY 1, 2;

-- STEP 2 (delete: bookings first, then sessions, then trainers)
BEGIN;
DELETE FROM bookings WHERE booking_id LIKE 'V-%';
DELETE FROM sessions WHERE session_id LIKE 'V-S%';
DELETE FROM trainers WHERE trainer_id LIKE 'T-V%';
COMMIT;

-- STEP 3 (check: no 'Test Hall' any more)
SELECT DISTINCT location FROM sessions ORDER BY 1;
