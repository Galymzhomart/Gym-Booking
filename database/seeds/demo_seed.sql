-- demo_seed.sql  (Shokan) -- FICTIONAL demo data for testing the new rules.
-- Run as postgres AFTER migration.sql. Safe to run again (ON CONFLICT DO NOTHING).
-- Dates are counted from today in Asia/Almaty: sessions are always in the FUTURE
-- (day D = today + 7 days), so the data does not get "old" like the 2 November rows.
-- Existing rows M-101..M-105, T-001..T-003, S-001..S-006, B-1001..B-1004 are NOT touched.

BEGIN;

-- Trainers: two active, one inactive
INSERT INTO trainers (trainer_id, full_name, specialization, is_active) VALUES
  ('T-201', 'Demo Trainer Aigerim', 'Fitness', true),
  ('T-202', 'Demo Trainer Nurlan',  'Yoga',    true),
  ('T-203', 'Demo Trainer Inactive','Boxing',  false)
ON CONFLICT DO NOTHING;

-- Members: suitable and unsuitable memberships
INSERT INTO members (member_id, full_name, membership_status, membership_expiry) VALUES
  ('M-201', 'Demo Member Active A',        'Active',    (now() AT TIME ZONE 'Asia/Almaty')::date + 90),  -- suitable
  ('M-202', 'Demo Member Active B',        'Active',    (now() AT TIME ZONE 'Asia/Almaty')::date + 90),  -- suitable
  ('M-203', 'Demo Member Expired',         'Expired',   (now() AT TIME ZONE 'Asia/Almaty')::date - 30),  -- wrong status
  ('M-204', 'Demo Member Suspended',       'Suspended', (now() AT TIME ZONE 'Asia/Almaty')::date + 90),  -- wrong status
  ('M-205', 'Demo Member Expires Soon',    'Active',    (now() AT TIME ZONE 'Asia/Almaty')::date + 2)    -- Active, but ends before day D
ON CONFLICT DO NOTHING;

-- Sessions on day D = today + 7 (Asia/Almaty)
WITH d AS (SELECT ((now() AT TIME ZONE 'Asia/Almaty')::date + 7) AS day)
INSERT INTO sessions (session_id, trainer_id, start_time, end_time, location)
SELECT v.session_id, v.trainer_id,
       make_timestamptz(extract(year FROM d.day)::int, extract(month FROM d.day)::int, extract(day FROM d.day)::int, v.sh, v.sm, 0, 'Asia/Almaty'),
       make_timestamptz(extract(year FROM d.day)::int, extract(month FROM d.day)::int, extract(day FROM d.day)::int, v.eh, v.em, 0, 'Asia/Almaty'),
       v.location
FROM d, (VALUES
  --  id      trainer  start   end      place
  ('S-201', 'T-201', 10, 0, 11, 0,  'Fitness Hall'),   -- free
  ('S-202', 'T-201', 11, 0, 12, 0,  'Fitness Hall'),   -- free, ADJACENT to S-201 (11:00 = end of S-201)
  ('S-203', 'T-202', 10, 30, 11, 30,'Yoga Studio'),     -- free, OVERLAPS S-201 and S-202 (other trainer)
  ('S-204', 'T-201', 14, 0, 15, 0,  'Fitness Hall'),   -- OCCUPIED by B-201
  ('S-205', 'T-203', 10, 0, 11, 0,  'Boxing Hall'),    -- trainer is INACTIVE
  ('S-206', 'T-202', 16, 0, 17, 0,  'Yoga Studio')     -- free, for cancel / re-book
) AS v(session_id, trainer_id, sh, sm, eh, em, location)
ON CONFLICT DO NOTHING;

-- One occupied session (goes through all triggers, so it is a valid booking)
INSERT INTO bookings (booking_id, member_id, session_id, status)
VALUES ('B-201', 'M-202', 'S-204', 'Confirmed')
ON CONFLICT DO NOTHING;

COMMIT;

-- Quick look at the result
SELECT s.session_id, t.full_name AS trainer, t.is_active,
       s.start_time AT TIME ZONE 'Asia/Almaty' AS start_almaty,
       s.end_time   AT TIME ZONE 'Asia/Almaty' AS end_almaty,
       CASE WHEN b.booking_id IS NULL THEN 'free' ELSE 'occupied by ' || b.booking_id END AS state
FROM sessions s
JOIN trainers t ON t.trainer_id = s.trainer_id
LEFT JOIN bookings b ON b.session_id = s.session_id AND b.status <> 'Cancelled'
WHERE s.session_id LIKE 'S-2%'
ORDER BY s.start_time, s.session_id;
