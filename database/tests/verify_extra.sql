-- verify_extra.sql  (Shokan) -- checks the extended demo data, the four defence examples and translations.
-- Run as postgres AFTER migrations 01-03, demo_seed.sql and demo_seed_extra.sql. Run the WHOLE file.
-- It does not change data: refused statements change nothing, and the one allowed UPDATE
-- ("Attended" for B-302) is rolled back inside the test. The last statement shows PASS/FAIL per check.
DROP TABLE IF EXISTS results;
CREATE TEMP TABLE results (n serial, test_id text, description text, expected text, actual text, verdict text);

CREATE OR REPLACE FUNCTION pg_temp.t(p_id text, p_desc text, p_sql text, p_expect text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_actual text;
BEGIN
  BEGIN EXECUTE p_sql; v_actual := 'OK';
  EXCEPTION WHEN OTHERS THEN v_actual := 'ERROR: ' || SQLERRM; END;
  INSERT INTO pg_temp.results(test_id, description, expected, actual, verdict)
  VALUES (p_id, p_desc, CASE WHEN p_expect = 'OK' THEN 'OK' ELSE 'ERROR containing: ' || p_expect END, v_actual,
          CASE WHEN (p_expect = 'OK' AND v_actual = 'OK') OR (p_expect <> 'OK' AND v_actual LIKE 'ERROR:%' || p_expect || '%') THEN 'PASS' ELSE 'FAIL' END);
END $$;

-- like t(), but the statement is executed and then ROLLED BACK (proves it is allowed, changes nothing)
CREATE OR REPLACE FUNCTION pg_temp.t_rb(p_id text, p_desc text, p_sql text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_actual text;
BEGIN
  BEGIN EXECUTE p_sql; RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = '__rollback__';
  EXCEPTION WHEN SQLSTATE 'P0099' THEN v_actual := 'OK';
            WHEN OTHERS THEN v_actual := 'ERROR: ' || SQLERRM; END;
  INSERT INTO pg_temp.results(test_id, description, expected, actual, verdict)
  VALUES (p_id, p_desc, 'OK (rolled back)', v_actual, CASE WHEN v_actual = 'OK' THEN 'PASS' ELSE 'FAIL' END);
END $$;

CREATE OR REPLACE FUNCTION pg_temp.chk(p_id text, p_desc text, p_sql text, p_expect text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_actual text;
BEGIN
  EXECUTE p_sql INTO v_actual;
  INSERT INTO pg_temp.results(test_id, description, expected, actual, verdict)
  VALUES (p_id, p_desc, p_expect, v_actual, CASE WHEN v_actual = p_expect THEN 'PASS' ELSE 'FAIL' END);
END $$;

DO $do$
BEGIN
  -- totals (at least the target: other teammates may add rows later)
  PERFORM pg_temp.chk('X01', 'At least 30 members',  $q$SELECT (count(*) >= 30)::text FROM members$q$,  'true');
  PERFORM pg_temp.chk('X02', 'At least 6 trainers',  $q$SELECT (count(*) >= 6)::text FROM trainers$q$,  'true');
  PERFORM pg_temp.chk('X03', 'At least 40 sessions', $q$SELECT (count(*) >= 40)::text FROM sessions$q$, 'true');
  PERFORM pg_temp.chk('X04', 'At least 25 bookings', $q$SELECT (count(*) >= 25)::text FROM bookings$q$, 'true');

  -- example 1: free future session S-301
  PERFORM pg_temp.chk('E1a', 'Example 1: S-301 is in the future', $q$SELECT (start_time > now())::text FROM sessions WHERE session_id='S-301'$q$, 'true');
  PERFORM pg_temp.chk('E1b', 'Example 1: S-301 has no active booking (free)', $q$SELECT is_booked::text FROM sessions_overview WHERE session_id='S-301'$q$, 'false');

  -- example 2: busy future session S-302 (B-301)
  PERFORM pg_temp.chk('E2a', 'Example 2: S-302 is in the future', $q$SELECT (start_time > now())::text FROM sessions WHERE session_id='S-302'$q$, 'true');
  PERFORM pg_temp.chk('E2b', 'Example 2: S-302 is busy (booking B-301 Confirmed)', $q$SELECT is_booked::text || ' ' || (SELECT status FROM bookings WHERE booking_id='B-301') FROM sessions_overview WHERE session_id='S-302'$q$, 'true Confirmed');
  PERFORM pg_temp.t('E2c', 'Example 2: another member cannot book busy S-302', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('X-01','M-304','S-302')$q$, 'one_non_cancelled_booking_per_session');

  -- example 3: refusal by membership date
  PERFORM pg_temp.t('E3a', 'Example 3: M-302 (Active, ends in 2 days) cannot book S-301', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('X-02','M-302','S-301')$q$, 'Membership expires before the session date');
  PERFORM pg_temp.t('E3b', 'Expired member M-319 cannot book S-301', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('X-03','M-319','S-301')$q$, 'Membership must be active');
  PERFORM pg_temp.t('E3c', 'Suspended member M-320 cannot book S-301', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('X-04','M-320','S-301')$q$, 'Membership must be active');

  -- example 4: past session with a Confirmed booking, Reception can press "Attended"
  PERFORM pg_temp.chk('E4a', 'Example 4: S-303 has ended', $q$SELECT (end_time < now())::text FROM sessions WHERE session_id='S-303'$q$, 'true');
  PERFORM pg_temp.chk('E4b', 'Example 4: B-302 on S-303 is Confirmed', $q$SELECT status FROM bookings WHERE booking_id='B-302' AND session_id='S-303'$q$, 'Confirmed');
  PERFORM pg_temp.t_rb('E4c', 'Example 4: Confirmed -> Attended is allowed for B-302', $q$UPDATE bookings SET status='Attended' WHERE booking_id='B-302'$q$);
  PERFORM pg_temp.chk('E4d', 'Example 4: B-302 is still Confirmed after the test', $q$SELECT status FROM bookings WHERE booking_id='B-302'$q$, 'Confirmed');

  -- inactive trainer in the new data
  PERFORM pg_temp.t('E5', 'Session S-329 of inactive trainer T-203 cannot be booked', $q$INSERT INTO bookings(booking_id,member_id,session_id) VALUES ('X-05','M-304','S-329')$q$, 'Trainer is not active');

  -- nothing wrong was saved by the refused statements
  PERFORM pg_temp.chk('E6', 'No X-xx test bookings were saved', $q$SELECT count(*)::text FROM bookings WHERE booking_id LIKE 'X-%'$q$, '0');
  PERFORM pg_temp.chk('E7', 'No leftover test rows (V-xx, Test Hall, T-V)', $q$SELECT ((SELECT count(*) FROM bookings WHERE booking_id LIKE 'V-%') + (SELECT count(*) FROM sessions WHERE location='Test Hall') + (SELECT count(*) FROM trainers WHERE trainer_id LIKE 'T-V%'))::text$q$, '0');

  -- translations
  PERFORM pg_temp.chk('L1', 'Hall name in Kazakh',  $q$SELECT tr('location','Yoga Studio','kk')$q$, 'Йога студиясы');
  PERFORM pg_temp.chk('L2', 'Hall name in Russian', $q$SELECT tr('location','Boxing Hall','ru')$q$, 'Зал бокса');
  PERFORM pg_temp.chk('L3', 'Hall name in English', $q$SELECT tr('location','Fitness Hall','en')$q$, 'Fitness Hall');
  PERFORM pg_temp.chk('L4', 'Unknown text falls back to the original', $q$SELECT tr('location','Unknown Hall','kk')$q$, 'Unknown Hall');
  PERFORM pg_temp.chk('L5', 'Every hall used by a session has 3 translations', $q$SELECT count(*)::text FROM (SELECT DISTINCT location FROM sessions s WHERE (SELECT count(*) FROM db_translations d WHERE d.entity='location' AND d.key=s.location) <> 3) x$q$, '0');
END
$do$;

SELECT test_id, description, expected, actual, verdict FROM (
  SELECT n AS ord, test_id, description, expected, actual, verdict FROM pg_temp.results
  UNION ALL
  SELECT 100000, 'TOTAL', 'PASS=' || count(*) FILTER (WHERE verdict='PASS') || '  FAIL=' || count(*) FILTER (WHERE verdict='FAIL'), '', '', '' FROM pg_temp.results
) r ORDER BY ord;
