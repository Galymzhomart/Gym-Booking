-- verify_rules.sql  (Shokan) -- checks every new rule and every allowed case.
-- Needs migrations 01 and 02 (02 = the lifecycle trigger that is in the shared database).
-- Run as postgres, AFTER migration.sql and demo_seed.sql. Run the WHOLE file at once.
-- The last statement shows ONE table with PASS/FAIL for every check.
-- Test rows (bookings V-xx, sessions V-Sx, trainers T-V1/T-V2) are removed at the start AND at the end:
-- nothing is left in the database, so the file is safe to run on a shared database.
-- Original data (B-1001..B-1004, S-001..S-006, ...) is not modified.
-- (Sessions V-S1..V-S3 are moved into the past with UPDATE sessions, as an admin would,
--  to test "after the session" transitions: a Confirmed booking cannot be INSERTed in the past.)

DROP TABLE IF EXISTS results;
CREATE TEMP TABLE results (n serial, test_id text, description text, expected text, actual text, verdict text);

CREATE OR REPLACE FUNCTION pg_temp.t(p_id text, p_desc text, p_sql text, p_expect text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE v_actual text;
BEGIN
  BEGIN
    EXECUTE p_sql;
    v_actual := 'OK';
  EXCEPTION WHEN OTHERS THEN
    v_actual := 'ERROR: ' || SQLERRM;
  END;
  INSERT INTO pg_temp.results(test_id, description, expected, actual, verdict)
  VALUES (p_id, p_desc, CASE WHEN p_expect = 'OK' THEN 'OK' ELSE 'ERROR containing: ' || p_expect END, v_actual,
          CASE WHEN (p_expect = 'OK' AND v_actual = 'OK')
                 OR (p_expect <> 'OK' AND v_actual LIKE 'ERROR:%' || p_expect || '%') THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- check a query result (used after a refusal: "no wrong row was saved")
CREATE OR REPLACE FUNCTION pg_temp.chk(p_id text, p_desc text, p_sql text, p_expect text) RETURNS void
LANGUAGE plpgsql AS $$
DECLARE v_actual text;
BEGIN
  EXECUTE p_sql INTO v_actual;
  INSERT INTO pg_temp.results(test_id, description, expected, actual, verdict)
  VALUES (p_id, p_desc, p_expect, v_actual, CASE WHEN v_actual = p_expect THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- ---------- cleanup + test sessions ----------
DELETE FROM bookings WHERE booking_id LIKE 'V-%';
DELETE FROM sessions WHERE session_id LIKE 'V-S%';
DELETE FROM trainers WHERE trainer_id LIKE 'T-V%';
-- own test trainers: the test never touches sessions of real/demo trainers
INSERT INTO trainers (trainer_id, full_name, specialization, is_active) VALUES
  ('T-V1', 'Verify Trainer 1', 'Test', true), ('T-V2', 'Verify Trainer 2', 'Test', true);
INSERT INTO sessions (session_id, trainer_id, start_time, end_time, location)
SELECT x.id, x.tr,
       make_timestamptz(extract(year FROM q.d)::int, extract(month FROM q.d)::int, extract(day FROM q.d)::int, x.h, 0, 0, 'Asia/Almaty'),
       make_timestamptz(extract(year FROM q.d)::int, extract(month FROM q.d)::int, extract(day FROM q.d)::int, x.h + 1, 0, 0, 'Asia/Almaty'),
       'Test Hall'
FROM (SELECT (now() AT TIME ZONE 'Asia/Almaty')::date + 8 AS d) q,
     (VALUES ('V-S1','T-V1',10), ('V-S2','T-V1',12), ('V-S3','T-V2',10)) AS x(id, tr, h);

DO $do$
BEGIN
-- ---------- old rules still work ----------
PERFORM pg_temp.t('OLD-1', 'Unknown member is rejected', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-90','M-999','S-201')$q$, 'Member does not exist');
PERFORM pg_temp.t('OLD-2', 'Trainer cannot have two overlapping sessions', $q$INSERT INTO sessions VALUES ('V-SX','T-201', (SELECT start_time + interval '30 minutes' FROM sessions WHERE session_id='S-201'), (SELECT end_time + interval '30 minutes' FROM sessions WHERE session_id='S-201'), 'Test')$q$, 'no_trainer_time_overlap');
PERFORM pg_temp.chk('OLD-2b', 'Overlapping session was not saved', $q$SELECT count(*)::text FROM sessions WHERE session_id='V-SX'$q$, '0');

-- ---------- T01 successful booking ----------
PERFORM pg_temp.t('T01', 'Valid booking M-201 -> S-201 (Confirmed)', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-01','M-201','S-201')$q$, 'OK');
PERFORM pg_temp.chk('T01b', 'Booking V-01 is saved as Confirmed', $q$SELECT status FROM bookings WHERE booking_id='V-01'$q$, 'Confirmed');

-- ---------- T02 occupied session ----------
PERFORM pg_temp.t('T02', 'Second booking of an occupied session (S-204, B-201) is rejected', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-02','M-201','S-204')$q$, 'one_non_cancelled_booking_per_session');
PERFORM pg_temp.chk('T02b', 'Rejected booking V-02 does not exist', $q$SELECT count(*)::text FROM bookings WHERE booking_id='V-02'$q$, '0');

-- ---------- T03 membership ----------
PERFORM pg_temp.t('T03a', 'Expired membership (M-203) is rejected', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-03','M-203','S-206')$q$, 'Membership must be active');
PERFORM pg_temp.t('T03b', 'Suspended membership (M-204) is rejected', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-04','M-204','S-206')$q$, 'Membership must be active');
PERFORM pg_temp.t('T03c', 'Active membership that ends before the session date (M-205) is rejected', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-05','M-205','S-206')$q$, 'Membership expires before the session date');
PERFORM pg_temp.chk('T03d', 'No rejected membership booking was saved (V-03, V-04, V-05)', $q$SELECT count(*)::text FROM bookings WHERE booking_id IN ('V-03','V-04','V-05')$q$, '0');

-- ---------- T04 past session ----------
PERFORM pg_temp.t('T04', 'Booking of a past session (S-001) is rejected', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-06','M-201','S-001')$q$, 'Cannot book a session in the past');
PERFORM pg_temp.chk('T04b', 'Rejected booking V-06 does not exist', $q$SELECT count(*)::text FROM bookings WHERE booking_id='V-06'$q$, '0');

-- ---------- T05 inactive trainer (R1) ----------
PERFORM pg_temp.t('T05', 'New Confirmed booking with inactive trainer (S-205) is rejected', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-07','M-202','S-205')$q$, 'Trainer is not active');
PERFORM pg_temp.chk('T05b', 'Rejected booking V-07 does not exist', $q$SELECT count(*)::text FROM bookings WHERE booking_id='V-07'$q$, '0');
-- UPDATE variant: move a Confirmed booking to a session of the inactive trainer
PERFORM pg_temp.t('T05c', 'UPDATE: moving V-01 to the inactive trainer session (S-205) is rejected', $q$UPDATE bookings SET session_id='S-205' WHERE booking_id='V-01'$q$, 'Trainer is not active');
PERFORM pg_temp.chk('T05d', 'V-01 stayed on S-201', $q$SELECT session_id FROM bookings WHERE booking_id='V-01'$q$, 'S-201');
-- a Cancelled history row for the inactive trainer is allowed (only NEW Confirmed is forbidden)
PERFORM pg_temp.t('T05e', 'Inserting a booking that is not Confirmed is rejected (lifecycle rule)', $q$INSERT INTO bookings(booking_id,member_id,session_id,status) VALUES ('V-08','M-202','S-205','Cancelled')$q$, 'New booking must have status Confirmed');
PERFORM pg_temp.chk('T05f', 'Rejected booking V-08 does not exist', $q$SELECT count(*)::text FROM bookings WHERE booking_id='V-08'$q$, '0');

-- ---------- T06 client overlap (R2) ----------
PERFORM pg_temp.t('T06', 'M-201 already has S-201 (10:00-11:00); S-203 (10:30-11:30, other trainer) is rejected', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-09','M-201','S-203')$q$, 'overlaps in time');
PERFORM pg_temp.chk('T06b', 'Rejected booking V-09 does not exist', $q$SELECT count(*)::text FROM bookings WHERE booking_id='V-09'$q$, '0');

-- ---------- T07 adjacent intervals ----------
PERFORM pg_temp.t('T07', 'Adjacent S-202 (11:00-12:00) right after S-201 (10:00-11:00) is allowed', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-10','M-201','S-202')$q$, 'OK');

-- ---------- UPDATE and overlap ----------
PERFORM pg_temp.t('T06c', 'UPDATE: moving V-10 (S-202) to S-203 would overlap V-01 -> rejected', $q$UPDATE bookings SET session_id='S-203' WHERE booking_id='V-10'$q$, 'overlaps in time');
PERFORM pg_temp.chk('T06d', 'V-10 stayed on S-202', $q$SELECT session_id FROM bookings WHERE booking_id='V-10'$q$, 'S-202');
PERFORM pg_temp.t('T06e', 'UPDATE of a row that changes nothing does not conflict with itself', $q$UPDATE bookings SET session_id = session_id, member_id = member_id, status = status WHERE booking_id='V-01'$q$, 'OK');

-- ---------- T08 cancel keeps history, re-booking ----------
PERFORM pg_temp.t('T08a', 'Cancel V-01 before the session starts', $q$UPDATE bookings SET status='Cancelled' WHERE booking_id='V-01'$q$, 'OK');
PERFORM pg_temp.chk('T08b', 'Cancelled row V-01 is still in the table', $q$SELECT status FROM bookings WHERE booking_id='V-01'$q$, 'Cancelled');
PERFORM pg_temp.t('T08c', 'Re-book the freed session S-201 (new row V-11, M-202)', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-11','M-202','S-201')$q$, 'OK');
PERFORM pg_temp.chk('T08d', 'S-201 has 2 rows: old Cancelled + new Confirmed (different ids)', $q$SELECT string_agg(booking_id||':'||status, ', ' ORDER BY booking_id) FROM bookings WHERE session_id='S-201'$q$, 'V-01:Cancelled, V-11:Confirmed');
PERFORM pg_temp.t('T08e', 'History of a Cancelled booking cannot be moved to another session (V-01)', $q$UPDATE bookings SET session_id='S-206' WHERE booking_id='V-01'$q$, 'Booking history cannot be changed');
PERFORM pg_temp.chk('T08f', 'V-01 stayed on S-201', $q$SELECT session_id FROM bookings WHERE booking_id='V-01'$q$, 'S-201');

-- ---------- T09 status transitions (R3) ----------
PERFORM pg_temp.t('T09a', 'Confirmed -> Attended before the session ends is rejected (V-11)', $q$UPDATE bookings SET status='Attended' WHERE booking_id='V-11'$q$, 'has not ended yet');
PERFORM pg_temp.t('T09b', 'Confirmed -> No-show before the session ends is rejected (V-11)', $q$UPDATE bookings SET status='No-show' WHERE booking_id='V-11'$q$, 'has not ended yet');
PERFORM pg_temp.t('T09c', 'Cancelled -> Confirmed is rejected (V-01)', $q$UPDATE bookings SET status='Confirmed' WHERE booking_id='V-01'$q$, 'Cancelled -> Confirmed is not allowed');
PERFORM pg_temp.t('T09d', 'Cancelled -> Attended is rejected (V-01)', $q$UPDATE bookings SET status='Attended' WHERE booking_id='V-01'$q$, 'Cancelled -> Attended is not allowed');
PERFORM pg_temp.chk('T09e', 'Statuses did not change: V-01 Cancelled, V-11 Confirmed', $q$SELECT string_agg(booking_id||':'||status, ', ' ORDER BY booking_id) FROM bookings WHERE booking_id IN ('V-01','V-11')$q$, 'V-01:Cancelled, V-11:Confirmed');

-- after the session: V-S1 ended 3 days ago, V-S3 ended 4 days ago, V-S2 is running now
INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('V-20','M-202','V-S1'), ('V-21','M-201','V-S3'), ('V-22','M-201','V-S2');
UPDATE sessions SET start_time = now() - interval '3 days', end_time = now() - interval '3 days' + interval '1 hour' WHERE session_id = 'V-S1';
UPDATE sessions SET start_time = now() - interval '4 days', end_time = now() - interval '4 days' + interval '1 hour' WHERE session_id = 'V-S3';
UPDATE sessions SET start_time = now() - interval '1 hour',  end_time = now() + interval '1 hour' WHERE session_id = 'V-S2';

PERFORM pg_temp.t('T09f', 'Cancel after the session ended is rejected (V-20)', $q$UPDATE bookings SET status='Cancelled' WHERE booking_id='V-20'$q$, 'already started');
PERFORM pg_temp.t('T09g', 'Cancel a session that has already started is rejected (V-22)', $q$UPDATE bookings SET status='Cancelled' WHERE booking_id='V-22'$q$, 'already started');
PERFORM pg_temp.t('T09h', 'Attended while the session is still running is rejected (V-22)', $q$UPDATE bookings SET status='Attended' WHERE booking_id='V-22'$q$, 'has not ended yet');
PERFORM pg_temp.t('T09i', 'Confirmed -> Attended after the session ended is allowed (V-20)', $q$UPDATE bookings SET status='Attended' WHERE booking_id='V-20'$q$, 'OK');
PERFORM pg_temp.t('T09j', 'Confirmed -> No-show after the session ended is allowed (V-21)', $q$UPDATE bookings SET status='No-show' WHERE booking_id='V-21'$q$, 'OK');
PERFORM pg_temp.t('T09k', 'Attended -> No-show is rejected (V-20)', $q$UPDATE bookings SET status='No-show' WHERE booking_id='V-20'$q$, 'Attended -> No-show is not allowed');
PERFORM pg_temp.t('T09l', 'Attended -> Confirmed is rejected (V-20)', $q$UPDATE bookings SET status='Confirmed' WHERE booking_id='V-20'$q$, 'Attended -> Confirmed is not allowed');
PERFORM pg_temp.t('T09m', 'No-show -> Attended is rejected (V-21)', $q$UPDATE bookings SET status='Attended' WHERE booking_id='V-21'$q$, 'No-show -> Attended is not allowed');
PERFORM pg_temp.chk('T09n', 'Final statuses: V-20 Attended, V-21 No-show, V-22 Confirmed', $q$SELECT string_agg(booking_id||':'||status, ', ' ORDER BY booking_id) FROM bookings WHERE booking_id IN ('V-20','V-21','V-22')$q$, 'V-20:Attended, V-21:No-show, V-22:Confirmed');

-- ---------- originals untouched ----------
PERFORM pg_temp.chk('ORIG', 'Original bookings B-1001..B-1004 unchanged', $q$SELECT string_agg(booking_id||':'||status, ', ' ORDER BY booking_id) FROM bookings WHERE booking_id LIKE 'B-100%'$q$, 'B-1001:Cancelled, B-1002:Confirmed, B-1003:Confirmed, B-1004:Confirmed');

END
$do$;

-- ---------- cleanup: remove every test row (results are already in the temp table) ----------
DELETE FROM bookings WHERE booking_id LIKE 'V-%';
DELETE FROM sessions WHERE session_id LIKE 'V-S%';
DELETE FROM trainers WHERE trainer_id LIKE 'T-V%';
-- ---------- RESULT (one table) ----------
SELECT test_id, description, expected, actual, verdict FROM (
  SELECT n AS ord, test_id, description, expected, actual, verdict FROM pg_temp.results
  UNION ALL
  SELECT 100000, 'TOTAL', 'PASS=' || count(*) FILTER (WHERE verdict='PASS') || '  FAIL=' || count(*) FILTER (WHERE verdict='FAIL'), '', '', ''
  FROM pg_temp.results
) r ORDER BY ord;
