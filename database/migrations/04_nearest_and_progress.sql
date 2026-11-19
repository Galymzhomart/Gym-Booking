-- 04_nearest_and_progress.sql (Shokan). Run as postgres AFTER 03_translations.sql. Safe to re-run.
-- Three read-only functions for the interface. They change no data.
--
--   app_trainer_slots_for_member(member_id, session_id)
--       every LATER future session of the SAME ACTIVE trainer, with a reason:
--       ok | booked | overlaps_own_booking | membership_inactive | membership_expires
--   app_nearest_session(member_id, session_id)
--       the first row with reason = 'ok' (0 rows = no suitable slot)
--   app_weekly_progress(member_id, goal)
--       Attended bookings of the member in the current week (Mon-Sun, Asia/Almaty), one row.
--
-- Definition of a "suitable slot":
--   same trainer, trainer active, starts later than the requested session and later than now(),
--   not booked by anybody (status <> 'Cancelled'), no overlap with a non-cancelled booking
--   of the member (adjacent 11:00-12:00 / 12:00-13:00 is allowed, like check_member_overlap),
--   membership Active and valid on the session date (Asia/Almaty, like validate_booking).
-- The functions run with the rights of the caller (gym_app already has SELECT on the four tables).

BEGIN;

CREATE OR REPLACE FUNCTION public.app_trainer_slots_for_member(p_member_id text, p_session_id text)
RETURNS TABLE (session_id text, trainer_id text, trainer_name text, start_time timestamptz,
               end_time timestamptz, location text, reason text)
LANGUAGE sql
STABLE
SET search_path = public, pg_catalog
AS $$
    SELECT c.session_id::text, c.trainer_id::text, t.full_name::text, c.start_time, c.end_time, c.location::text,
           CASE
             WHEN m.membership_status <> 'Active'
                  THEN 'membership_inactive'
             WHEN m.membership_expiry < (c.start_time AT TIME ZONE 'Asia/Almaty')::date
                  THEN 'membership_expires'
             WHEN EXISTS (SELECT 1 FROM public.bookings b
                           WHERE b.session_id = c.session_id AND b.status <> 'Cancelled')
                  THEN 'booked'
             WHEN EXISTS (SELECT 1 FROM public.bookings mb
                            JOIN public.sessions o ON o.session_id = mb.session_id
                           WHERE mb.member_id = m.member_id AND mb.status <> 'Cancelled'
                             AND tstzrange(o.start_time, o.end_time, '[)')
                              && tstzrange(c.start_time, c.end_time, '[)'))
                  THEN 'overlaps_own_booking'
             ELSE 'ok'
           END AS reason
    FROM public.sessions ref
    JOIN public.sessions c ON c.trainer_id = ref.trainer_id
                          AND c.session_id <> ref.session_id
                          AND c.start_time > greatest(ref.start_time, now())
    JOIN public.trainers t ON t.trainer_id = c.trainer_id AND t.is_active
    JOIN public.members  m ON m.member_id = p_member_id
    WHERE ref.session_id = p_session_id
    ORDER BY c.start_time, c.session_id
$$;

CREATE OR REPLACE FUNCTION public.app_nearest_session(p_member_id text, p_session_id text)
RETURNS TABLE (session_id text, trainer_id text, trainer_name text, start_time timestamptz,
               end_time timestamptz, location text, reason text)
LANGUAGE sql
STABLE
SET search_path = public, pg_catalog
AS $$
    SELECT * FROM public.app_trainer_slots_for_member(p_member_id, p_session_id) s
    WHERE s.reason = 'ok'
    ORDER BY s.start_time, s.session_id
    LIMIT 1
$$;

-- Weekly progress: only 'Attended', session start inside the current Monday-Sunday week (Asia/Almaty).
CREATE OR REPLACE FUNCTION public.app_weekly_progress(p_member_id text, p_goal integer DEFAULT 4)
RETURNS TABLE (week_start date, week_end date, attended integer, goal integer, remaining integer, percent integer)
LANGUAGE sql
STABLE
SET search_path = public, pg_catalog
AS $$
    WITH w AS (
        SELECT date_trunc('week', now() AT TIME ZONE 'Asia/Almaty') AS ws,
               greatest(coalesce(p_goal, 4), 1) AS g
    ), a AS (
        SELECT count(*)::int AS n
        FROM w, public.bookings b
        JOIN public.sessions s ON s.session_id = b.session_id
        WHERE b.member_id = p_member_id
          AND b.status = 'Attended'
          AND (s.start_time AT TIME ZONE 'Asia/Almaty') >= w.ws
          AND (s.start_time AT TIME ZONE 'Asia/Almaty') <  w.ws + interval '7 days'
    )
    SELECT w.ws::date, (w.ws + interval '6 days')::date, a.n, w.g,
           greatest(w.g - a.n, 0), least(100, a.n * 100 / w.g)
    FROM w, a
$$;

DO $do$
DECLARE f regprocedure;
BEGIN
    FOR f IN SELECT p.oid::regprocedure FROM pg_proc p
             WHERE p.pronamespace = 'public'::regnamespace
               AND p.proname IN ('app_trainer_slots_for_member', 'app_nearest_session', 'app_weekly_progress')
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', f);
    END LOOP;
END
$do$;
COMMIT;
