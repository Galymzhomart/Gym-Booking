-- demo_nearest_session.sql (Shokan). FICTIONAL data. Run as postgres AFTER 04_nearest_and_progress.sql
-- and after demo_seed_extra.sql. Run ONCE, as late as possible before the defence: all dates are counted
-- from the day of the run (Asia/Almaty), day D = today + 9. A second run does nothing.
--
-- Story for member 'ayan' (member found by app_users.username) and trainer T-003, all on day D:
--   S-N01  T-003  10:00-11:00  BUSY (booked by M-305)            <- the session the member wanted
--   S-N02  T-003  11:00-12:00  free, but OVERLAPS the member's own booking B on S-N04 (11:30-12:30)
--   S-N03  T-003  13:00-14:00  free and fits                     <- expected answer of "nearest session"
--   S-N05  T-003  15:00-16:00  free and fits too (shows that only the FIRST fitting slot is offered)
--   S-N04  T-202  11:30-12:30  the member's own booking (other trainer, Yoga Studio)
-- Expected: app_nearest_session(<ayan>, 'S-N01') -> S-N03.
DO $seed$
DECLARE
    base date := (now() AT TIME ZONE 'Asia/Almaty')::date + 16;
    mem  text;
BEGIN
    IF EXISTS (SELECT 1 FROM sessions WHERE session_id = 'S-N01') THEN
        RAISE NOTICE 'demo_nearest_session.sql was already loaded: nothing to do';
        RETURN;
    END IF;
    SELECT member_id INTO mem FROM app_users WHERE username = 'ayan';
    IF mem IS NULL THEN
        RAISE EXCEPTION 'Account ayan has no member_id: restore the backup and run migration_delta.sql first';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM members WHERE member_id = mem AND membership_status = 'Active'
                      AND membership_expiry >= base) THEN
        RAISE EXCEPTION 'Member % is not Active until %: change the member or extend membership_expiry', mem, base;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM trainers WHERE trainer_id IN ('T-003', 'T-202') AND is_active HAVING count(*) = 2) THEN
        RAISE EXCEPTION 'Trainers T-003 and T-202 must exist and be active';
    END IF;

    INSERT INTO sessions (session_id, trainer_id, start_time, end_time, location)
    SELECT v.id, v.trainer, make_timestamptz(extract(year FROM base)::int, extract(month FROM base)::int, extract(day FROM base)::int, v.sh, v.sm, 0, 'Asia/Almaty'),
           make_timestamptz(extract(year FROM base)::int, extract(month FROM base)::int, extract(day FROM base)::int, v.eh, v.em, 0, 'Asia/Almaty'), v.loc
    FROM (VALUES
        ('S-N01', 'T-003', 10, 0, 11, 0, 'Fitness Hall'),
        ('S-N02', 'T-003', 11, 0, 12, 0, 'Fitness Hall'),
        ('S-N03', 'T-003', 13, 0, 14, 0, 'Fitness Hall'),
        ('S-N05', 'T-003', 15, 0, 16, 0, 'Fitness Hall'),
        ('S-N04', 'T-202', 11, 30, 12, 30, 'Yoga Studio')
    ) AS v(id, trainer, sh, sm, eh, em, loc);

    INSERT INTO bookings (member_id, session_id) VALUES ('M-305', 'S-N01');   -- busy
    INSERT INTO bookings (member_id, session_id) VALUES (mem,     'S-N04');   -- own booking, blocks S-N02
END
$seed$;

SELECT s.session_id, s.trainer_id, s.start_time AT TIME ZONE 'Asia/Almaty' AS start_almaty,
       s.end_time AT TIME ZONE 'Asia/Almaty' AS end_almaty, b.member_id AS booked_by, b.status
FROM sessions s LEFT JOIN bookings b ON b.session_id = s.session_id AND b.status <> 'Cancelled'
WHERE s.session_id LIKE 'S-N0%' ORDER BY s.start_time, s.session_id;
