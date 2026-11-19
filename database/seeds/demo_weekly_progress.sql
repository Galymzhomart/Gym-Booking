-- demo_weekly_progress.sql (Shokan). FICTIONAL data. Run as postgres AFTER 04_nearest_and_progress.sql.
-- Run ONCE, as late as possible before the defence, but NOT on Monday before 18:00 (Asia/Almaty):
-- the past sessions must fit inside the current Monday-Sunday week and before "now". A second run does nothing.
-- Creates sessions S-P00..S-P05 and one booking each for member 'ayan', the way the existing S-303 example
-- was made: the session is created in the FUTURE, booked, and then moved into the past (a Confirmed booking
-- cannot be inserted for a past session).
--
--   S-P00  last week      Attended   not counted (other week)
--   S-P01  Mon 08:00      Attended   counted
--   S-P02  Mon 10:00      Attended   counted
--   S-P03  Mon 12:00      No-show    not counted
--   S-P04  Mon 14:00      Cancelled  not counted
--   S-P05  Mon 16:00      Confirmed  the booking for the show: Reception presses "Attended"
-- Expected: app_weekly_progress(<ayan>) -> attended 2 of 4; after Attended on the S-P05 booking -> 3 of 4.
-- (Other bookings of ayan in the backup may add to the count: the verify script compares with a direct count.)
DO $seed$
DECLARE
    ws   timestamptz := (date_trunc('week', now() AT TIME ZONE 'Asia/Almaty')) AT TIME ZONE 'Asia/Almaty';  -- Monday 00:00
    mem  text;
    r    record;
    i    int := 0;
    tr   text;
    t0   timestamptz;        -- temporary FUTURE start
    s1   timestamptz;        -- final start
    bid  text;
    show_bid text;
BEGIN
    IF EXISTS (SELECT 1 FROM sessions WHERE session_id = 'S-P01') THEN
        RAISE NOTICE 'demo_weekly_progress.sql was already loaded: nothing to do';
        RETURN;
    END IF;
    IF now() < ws + interval '18 hours' THEN
        RAISE EXCEPTION 'Run this file later: on Monday only after 18:00 (Asia/Almaty), or on any other day';
    END IF;
    SELECT member_id INTO mem FROM app_users WHERE username = 'ayan';
    IF mem IS NULL THEN
        RAISE EXCEPTION 'Account ayan has no member_id: restore the backup and run migration_delta.sql first';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM members WHERE member_id = mem AND membership_status = 'Active'
                      AND membership_expiry >= ((now() + interval '40 days') AT TIME ZONE 'Asia/Almaty')::date) THEN
        RAISE EXCEPTION 'Member % must be Active for at least 40 more days (temporary sessions are 30 days ahead)', mem;
    END IF;

    FOR r IN SELECT * FROM (VALUES
        ('S-P00', 'Attended',  ws - interval '3 days' + interval '10 hours'),
        ('S-P01', 'Attended',  ws + interval '8 hours'),
        ('S-P02', 'Attended',  ws + interval '10 hours'),
        ('S-P03', 'No-show',   ws + interval '12 hours'),
        ('S-P04', 'Cancelled', ws + interval '14 hours'),
        ('S-P05', 'Confirmed', ws + interval '16 hours')
    ) AS v(id, final_status, final_start) LOOP
        i  := i + 1;
        s1 := r.final_start;
        t0 := now() + interval '30 days' + i * interval '2 hours';

        -- an active trainer who is free at both the temporary and the final time
        SELECT t.trainer_id INTO tr FROM trainers t
        WHERE t.is_active
          AND NOT EXISTS (SELECT 1 FROM sessions s WHERE s.trainer_id = t.trainer_id
                           AND tstzrange(s.start_time, s.end_time, '[)') && tstzrange(s1, s1 + interval '1 hour', '[)'))
          AND NOT EXISTS (SELECT 1 FROM sessions s WHERE s.trainer_id = t.trainer_id
                           AND tstzrange(s.start_time, s.end_time, '[)') && tstzrange(t0, t0 + interval '1 hour', '[)'))
        ORDER BY t.trainer_id LIMIT 1;
        IF tr IS NULL THEN
            RAISE EXCEPTION 'No free active trainer for %', r.id;
        END IF;

        INSERT INTO sessions (session_id, trainer_id, start_time, end_time, location)
        VALUES (r.id, tr, t0, t0 + interval '1 hour', 'Fitness Hall');
        INSERT INTO bookings (member_id, session_id) VALUES (mem, r.id) RETURNING booking_id INTO bid;

        IF r.final_status = 'Cancelled' THEN                      -- only allowed before the start
            UPDATE bookings SET status = 'Cancelled' WHERE booking_id = bid;
        END IF;
        UPDATE sessions SET start_time = s1, end_time = s1 + interval '1 hour' WHERE session_id = r.id;
        IF r.final_status IN ('Attended', 'No-show') THEN         -- only allowed after the end
            UPDATE bookings SET status = r.final_status WHERE booking_id = bid;
        END IF;
        IF r.id = 'S-P05' THEN show_bid := bid; END IF;
    END LOOP;
    RAISE NOTICE 'Booking for the show (press "Attended"): %', show_bid;
END
$seed$;

SELECT b.booking_id, b.member_id, b.session_id, b.status, s.start_time AT TIME ZONE 'Asia/Almaty' AS start_almaty
FROM bookings b JOIN sessions s USING (session_id)
WHERE b.session_id LIKE 'S-P0%' ORDER BY s.start_time;
