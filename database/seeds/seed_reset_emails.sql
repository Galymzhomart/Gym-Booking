-- seed_reset_emails.sql (Ruslan, for Shokan's demo data). Run as postgres after migration_password_reset.sql.
-- Test e-mail addresses for the demo accounts. Domain .test is reserved: nothing is delivered outside
-- the test mailbox (outbox folder / Ethereal / Mailpit). Safe to re-run.
UPDATE public.app_users AS u
SET email = v.email
FROM (VALUES
    ('ayan',       'ayan@gym.test'),
    ('dana',       'dana@gym.test'),
    ('amina',      'amina@gym.test'),
    ('member302',  'member302@gym.test'),
    ('reception1', 'reception1@gym.test')
) AS v(username, email)
WHERE u.username = v.username;

SELECT username, email, role, is_active FROM public.app_users WHERE email IS NOT NULL ORDER BY username;
