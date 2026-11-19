-- demo_seed_extra.sql  (Shokan) -- extends the demo database for the defence. FICTIONAL data.
-- Run as postgres AFTER migrations 01-03 (and after demo_seed.sql). RUN IT ONCE, as late as possible
-- before the defence: all dates are counted from the day of the run (Asia/Almaty), so the future
-- sessions are in the future on the day of the defence. A second run does nothing (it says so).
--
-- Totals after demo_seed.sql + this file:  30 members, 6 trainers, 40 sessions, 25 bookings.
--
-- FOUR EXAMPLES FOR THE DEFENCE (details: demo_examples.md)
--   1 free future session ........ S-301
--   2 busy future session ........ S-302 (booking B-301)
--   3 refusal by membership date . member M-302 (Active, but ends in 2 days) tries to book S-301
--   4 past session with a Confirmed booking: S-303 / B-302  -> Reception can press "Attended"
--   (+ inactive trainer: S-329 belongs to T-203;  Expired member M-319, Suspended member M-320)

DO $seed$
DECLARE
    base  date := (now() AT TIME ZONE 'Asia/Almaty')::date;          -- today in Almaty
    trs   text[] := ARRAY['T-001', 'T-002', 'T-003', 'T-201', 'T-202'];
    halls text[] := ARRAY['Fitness Hall', 'Yoga Studio', 'Boxing Hall', 'Fitness Hall', 'Yoga Studio'];
    n int; d date; k int;
BEGIN
    IF EXISTS (SELECT 1 FROM sessions WHERE session_id = 'S-301') THEN
        RAISE NOTICE 'demo_seed_extra.sql was already loaded: nothing to do';
        RETURN;
    END IF;

    -- 20 members M-301 .. M-320
    INSERT INTO members (member_id, full_name, membership_status, membership_expiry)
    SELECT 'M-' || (300 + i), 'Demo Member ' || (300 + i),
           CASE i WHEN 19 THEN 'Expired' WHEN 20 THEN 'Suspended' ELSE 'Active' END,
           CASE i WHEN 2  THEN base + 2          -- M-302: ends before the session dates (example 3)
                  WHEN 19 THEN base - 30
                  ELSE base + 120 END
    FROM generate_series(1, 20) AS i;

    -- example sessions
    INSERT INTO sessions (session_id, trainer_id, start_time, end_time, location) VALUES
      ('S-301', 'T-201', make_timestamptz(extract(year FROM base + 5)::int, extract(month FROM base + 5)::int, extract(day FROM base + 5)::int, 10, 0, 0, 'Asia/Almaty'),
                         make_timestamptz(extract(year FROM base + 5)::int, extract(month FROM base + 5)::int, extract(day FROM base + 5)::int, 11, 0, 0, 'Asia/Almaty'), 'Fitness Hall'),
      ('S-302', 'T-202', make_timestamptz(extract(year FROM base + 5)::int, extract(month FROM base + 5)::int, extract(day FROM base + 5)::int, 12, 0, 0, 'Asia/Almaty'),
                         make_timestamptz(extract(year FROM base + 5)::int, extract(month FROM base + 5)::int, extract(day FROM base + 5)::int, 13, 0, 0, 'Asia/Almaty'), 'Yoga Studio'),
      -- S-303 is created in the FUTURE first (a Confirmed booking cannot be inserted in the past)
      ('S-303', 'T-002', make_timestamptz(extract(year FROM base + 1)::int, extract(month FROM base + 1)::int, extract(day FROM base + 1)::int, 10, 0, 0, 'Asia/Almaty'),
                         make_timestamptz(extract(year FROM base + 1)::int, extract(month FROM base + 1)::int, extract(day FROM base + 1)::int, 11, 0, 0, 'Asia/Almaty'), 'Yoga Studio'),
      -- session of the INACTIVE trainer T-203
      ('S-329', 'T-203', make_timestamptz(extract(year FROM base + 6)::int, extract(month FROM base + 6)::int, extract(day FROM base + 6)::int, 10, 0, 0, 'Asia/Almaty'),
                         make_timestamptz(extract(year FROM base + 6)::int, extract(month FROM base + 6)::int, extract(day FROM base + 6)::int, 11, 0, 0, 'Asia/Almaty'), 'Boxing Hall');

    -- 24 regular sessions S-304 .. S-327: 5 trainers x 5 days (+4 .. +8), one hour each, no overlaps
    FOR n IN 0..23 LOOP
        d := base + 4 + n / 5;
        k := n % 5 + 1;
        INSERT INTO sessions (session_id, trainer_id, start_time, end_time, location)
        VALUES ('S-' || (304 + n), trs[k],
                make_timestamptz(extract(year FROM d)::int, extract(month FROM d)::int, extract(day FROM d)::int, 9 + (k - 1) * 2, 0, 0, 'Asia/Almaty'),
                make_timestamptz(extract(year FROM d)::int, extract(month FROM d)::int, extract(day FROM d)::int, 10 + (k - 1) * 2, 0, 0, 'Asia/Almaty'),
                halls[k]);
    END LOOP;

    -- bookings (every row goes through all triggers)
    INSERT INTO bookings (booking_id, member_id, session_id) VALUES ('B-301', 'M-301', 'S-302');  -- example 2: busy
    INSERT INTO bookings (booking_id, member_id, session_id) VALUES ('B-302', 'M-303', 'S-303');  -- example 4 (still in the future here)
    FOR n IN 0..17 LOOP                                                                           -- 18 regular bookings B-303 .. B-320
        INSERT INTO bookings (booking_id, member_id, session_id)
        VALUES ('B-' || (303 + n), 'M-' || (304 + n % 15), 'S-' || (304 + n));
    END LOOP;
    UPDATE bookings SET status = 'Cancelled' WHERE booking_id IN ('B-319', 'B-320');              -- history: 2 cancelled bookings

    -- example 4: S-303 ended earlier today; B-302 stays Confirmed, so Reception can set "Attended"
    UPDATE sessions SET start_time = now() - interval '3 hours', end_time = now() - interval '2 hours'
    WHERE session_id = 'S-303';
END
$seed$;

-- Result: totals and the four examples
SELECT 'members' AS what, count(*)::text AS value FROM members
UNION ALL SELECT 'trainers', count(*)::text FROM trainers
UNION ALL SELECT 'sessions', count(*)::text FROM sessions
UNION ALL SELECT 'bookings', count(*)::text FROM bookings;
