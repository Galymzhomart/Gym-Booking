-- verify_nearest_progress.sql (Shokan) -- checks the nearest-session and weekly-progress functions and demo data.
-- Run as postgres AFTER 04_nearest_and_progress.sql, permissions_nearest_progress.sql,
-- demo_nearest_session.sql and demo_weekly_progress.sql. Run the WHOLE file. It changes nothing:
-- the one "Attended" update is rolled back inside the test. Expected: every verdict PASS.
DROP TABLE IF EXISTS pg_temp.results;
CREATE TEMP TABLE results (n serial, test_id text, description text, expected text, actual text, verdict text);

CREATE OR REPLACE FUNCTION pg_temp.chk(p_id text, p_desc text, p_sql text, p_expect text) RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_actual text;
BEGIN
  EXECUTE p_sql INTO v_actual;
  INSERT INTO pg_temp.results(test_id, description, expected, actual, verdict)
  VALUES (p_id, p_desc, p_expect, v_actual, CASE WHEN v_actual IS NOT DISTINCT FROM p_expect THEN 'PASS' ELSE 'FAIL' END);
END $$;

DO $do$
DECLARE
  mem text := (SELECT member_id FROM app_users WHERE username = 'ayan');
  show_bid text := (SELECT booking_id FROM bookings WHERE session_id = 'S-P05' AND member_id = (SELECT member_id FROM app_users WHERE username = 'ayan'));
  v_before int; v_after int;
  v_n14 text := 'OK';
BEGIN
  PERFORM pg_temp.chk('N01', 'ayan wanted busy S-N01: nearest suitable slot is S-N03',
    format($q$SELECT session_id FROM app_nearest_session(%L, 'S-N01')$q$, mem), 'S-N03');
  PERFORM pg_temp.chk('N02', 'S-N01 is really busy', $q$SELECT is_booked::text FROM sessions_overview WHERE session_id = 'S-N01'$q$, 'true');
  PERFORM pg_temp.chk('N03', 'S-N02 is skipped: overlaps own booking',
    format($q$SELECT reason FROM app_trainer_slots_for_member(%L, 'S-N01') WHERE session_id = 'S-N02'$q$, mem), 'overlaps_own_booking');
  PERFORM pg_temp.chk('N04', 'S-N03 and S-N05 are both ok (only the first is offered)',
    format($q$SELECT string_agg(session_id, ',' ORDER BY start_time) FROM app_trainer_slots_for_member(%L, 'S-N01') WHERE reason = 'ok' AND session_id LIKE 'S-N0%%'$q$, mem), 'S-N03,S-N05');
  PERFORM pg_temp.chk('N05', 'All offered slots belong to the same trainer as S-N01',
    format($q$SELECT count(*)::text FROM app_trainer_slots_for_member(%L, 'S-N01') WHERE trainer_id <> 'T-003'$q$, mem), '0');
  PERFORM pg_temp.chk('N06', 'All offered slots are in the future',
    format($q$SELECT count(*)::text FROM app_trainer_slots_for_member(%L, 'S-N01') WHERE start_time <= now()$q$, mem), '0');
  PERFORM pg_temp.chk('N07', 'Nothing before the requested session is offered',
    format($q$SELECT count(*)::text FROM app_trainer_slots_for_member(%L, 'S-N01') WHERE start_time <= (SELECT start_time FROM sessions WHERE session_id = 'S-N01')$q$, mem), '0');
  PERFORM pg_temp.chk('N08', 'The offered slot can really be booked (rolled back)',
    format($q$SELECT 'ok'::text FROM app_nearest_session(%L, 'S-N01')$q$, mem), 'ok');
  PERFORM pg_temp.chk('N09', 'Member M-302 (membership ends in 2 days): no suitable slot',
    $q$SELECT count(*)::text FROM app_nearest_session('M-302', 'S-N01')$q$, '0');
  PERFORM pg_temp.chk('N10', 'Expired member M-319: reason membership_inactive',
    $q$SELECT DISTINCT reason FROM app_trainer_slots_for_member('M-319', 'S-N01')$q$, 'membership_inactive');
  PERFORM pg_temp.chk('N11', 'Unknown member: no rows', $q$SELECT count(*)::text FROM app_nearest_session('M-NOPE', 'S-N01')$q$, '0');
  PERFORM pg_temp.chk('N12', 'Unknown session: no rows', format($q$SELECT count(*)::text FROM app_nearest_session(%L, 'S-NOPE')$q$, mem), '0');
  PERFORM pg_temp.chk('N13', 'Inactive trainer: no offers (S-329 of T-203)',
    format($q$SELECT count(*)::text FROM app_trainer_slots_for_member(%L, 'S-329')$q$, mem), '0');

  -- the real booking must succeed on the offered slot: try it and roll back
  -- (the verdict is written AFTER the sub-block, otherwise the rollback would also remove it)
  BEGIN
    INSERT INTO bookings(booking_id, member_id, session_id) VALUES ('X-N1', mem, 'S-N03');
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = '__rollback__';
  EXCEPTION
    WHEN SQLSTATE 'P0099' THEN NULL;
    WHEN OTHERS THEN v_n14 := 'ERROR: ' || SQLERRM;
  END;
  INSERT INTO results(test_id, description, expected, actual, verdict)
  VALUES ('N14', 'Booking of the offered S-N03 passes all triggers (rolled back)', 'OK', v_n14,
          CASE WHEN v_n14 = 'OK' THEN 'PASS' ELSE 'FAIL' END);

  -- weekly progress
  PERFORM pg_temp.chk('P01', 'S-P01 and S-P02 are Attended',
    $q$SELECT count(*)::text FROM bookings WHERE session_id IN ('S-P01', 'S-P02') AND status = 'Attended'$q$, '2');
  PERFORM pg_temp.chk('P02', 'S-P03 No-show, S-P04 Cancelled, S-P05 Confirmed',
    $q$SELECT string_agg(status, ',' ORDER BY session_id) FROM bookings WHERE session_id IN ('S-P03', 'S-P04', 'S-P05')$q$, 'No-show,Cancelled,Confirmed');
  PERFORM pg_temp.chk('P03', 'Last-week Attended S-P00 starts before this week (not counted)',
    $q$SELECT (start_time < (date_trunc('week', now() AT TIME ZONE 'Asia/Almaty')) AT TIME ZONE 'Asia/Almaty')::text FROM sessions WHERE session_id = 'S-P00'$q$, 'true');
  PERFORM pg_temp.chk('P04', 'Progress equals a direct count of Attended this week',
    format($q$SELECT (SELECT attended FROM app_weekly_progress(%L, 4))::text || '=' || count(*)::text
              FROM bookings b JOIN sessions s USING (session_id)
              WHERE b.member_id = %L AND b.status = 'Attended'
                AND s.start_time >= (date_trunc('week', now() AT TIME ZONE 'Asia/Almaty')) AT TIME ZONE 'Asia/Almaty'
                AND s.start_time <  (date_trunc('week', now() AT TIME ZONE 'Asia/Almaty')) AT TIME ZONE 'Asia/Almaty' + interval '7 days'$q$, mem, mem),
    (SELECT attended FROM app_weekly_progress(mem, 4))::text || '=' || (SELECT attended FROM app_weekly_progress(mem, 4))::text);
  PERFORM pg_temp.chk('P05', 'At least 2 counted this week (S-P01, S-P02)',
    format($q$SELECT (attended >= 2)::text FROM app_weekly_progress(%L, 4)$q$, mem), 'true');
  PERFORM pg_temp.chk('P06', 'Goal 4: remaining and percent are consistent',
    format($q$SELECT (remaining = greatest(4 - attended, 0) AND percent = least(100, attended * 25))::text FROM app_weekly_progress(%L, 4)$q$, mem), 'true');
  PERFORM pg_temp.chk('P07', 'Member without bookings: 0 of 4', $q$SELECT attended::text FROM app_weekly_progress('M-NOPE', 4)$q$, '0');

  -- Attended on the show booking raises the count by exactly one (rolled back)
  SELECT attended INTO v_before FROM app_weekly_progress(mem, 4);
  BEGIN
    UPDATE bookings SET status = 'Attended' WHERE booking_id = show_bid;
    SELECT attended INTO v_after FROM app_weekly_progress(mem, 4);
    RAISE EXCEPTION USING ERRCODE = 'P0099', MESSAGE = '__rollback__';
  EXCEPTION WHEN SQLSTATE 'P0099' THEN NULL;
  END;
  INSERT INTO results(test_id, description, expected, actual, verdict)
  VALUES ('P08', 'Attended on the show booking (S-P05) adds exactly 1 (rolled back)', (v_before + 1)::text, v_after::text,
          CASE WHEN v_after = v_before + 1 THEN 'PASS' ELSE 'FAIL' END);
  PERFORM pg_temp.chk('P09', 'Show booking is Confirmed again after the test',
    format($q$SELECT status FROM bookings WHERE booking_id = %L$q$, show_bid), 'Confirmed');

  -- rights of gym_app (skipped when the role does not exist on this server)
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'gym_app') THEN
    PERFORM pg_temp.chk('G1', 'gym_app can run the three new functions',
      $q$SELECT (has_function_privilege('gym_app', 'public.app_nearest_session(text,text)', 'EXECUTE')
             AND has_function_privilege('gym_app', 'public.app_trainer_slots_for_member(text,text)', 'EXECUTE')
             AND has_function_privilege('gym_app', 'public.app_weekly_progress(text,integer)', 'EXECUTE'))::text$q$, 'true');
    PERFORM pg_temp.chk('G2', 'gym_app still cannot read app_users', $q$SELECT has_table_privilege('gym_app', 'public.app_users', 'SELECT')::text$q$, 'false');
    IF to_regclass('public.app_password_resets') IS NOT NULL THEN
      PERFORM pg_temp.chk('G3', 'gym_app cannot read app_password_resets', $q$SELECT has_table_privilege('gym_app', 'public.app_password_resets', 'SELECT')::text$q$, 'false');
    END IF;
  END IF;
  PERFORM pg_temp.chk('G4', 'No leftover test bookings X-xx', $q$SELECT count(*)::text FROM bookings WHERE booking_id LIKE 'X-%'$q$, '0');
END
$do$;

SELECT test_id, description, expected, actual, verdict FROM (
  SELECT n AS ord, test_id, description, expected, actual, verdict FROM pg_temp.results
  UNION ALL
  SELECT 100000, 'TOTAL', 'PASS=' || count(*) FILTER (WHERE verdict='PASS') || '  FAIL=' || count(*) FILTER (WHERE verdict='FAIL'), '', '', '' FROM pg_temp.results
) r ORDER BY ord;
