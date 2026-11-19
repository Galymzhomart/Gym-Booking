-- Run on the restored fictional demo database as its owner.
BEGIN;

UPDATE public.app_users AS u
SET password_hash = crypt(demo.password, gen_salt('bf'))
FROM (VALUES
    ('reception1', 'Reception#Demo1'),
    ('ayan', 'Member#Demo1'),
    ('dana', 'Member#Demo2'),
    ('amina', 'Member#Demo3'),
    ('member302', 'Member#Demo4')
) AS demo(username, password)
WHERE u.username = demo.username;

-- Keep the time relationships of the overlap and adjacency fixtures.
WITH anchor AS (
    SELECT (now() AT TIME ZONE 'Asia/Almaty')::date + 14
         - (start_time AT TIME ZONE 'Asia/Almaty')::date AS days
    FROM public.sessions
    WHERE session_id = 'S-201' AND start_time <= now()
)
UPDATE public.sessions AS s
SET start_time = s.start_time + make_interval(days => anchor.days),
    end_time = s.end_time + make_interval(days => anchor.days)
FROM anchor
WHERE s.session_id IN ('S-201', 'S-202', 'S-203', 'S-204', 'S-205', 'S-206');

COMMIT;
