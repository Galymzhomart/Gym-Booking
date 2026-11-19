-- verify_password_reset.sql (Ruslan). Run as postgres in the target database after migration_password_reset.sql,
-- permissions.sql, permissions_additions.sql, permissions_2fa.sql, permissions_password_reset.sql. All "ok" must be true.
SELECT 'column app_users.email exists' AS item,
       EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_users' AND column_name='email') AS ok
UNION ALL SELECT 'table app_password_resets exists', to_regclass('public.app_password_resets') IS NOT NULL
UNION ALL SELECT 'gym_app can EXECUTE app_password_reset_request', has_function_privilege('gym_app', 'public.app_password_reset_request(text,bytea,integer)', 'EXECUTE')
UNION ALL SELECT 'gym_app can EXECUTE app_password_reset_check',   has_function_privilege('gym_app', 'public.app_password_reset_check(bytea)', 'EXECUTE')
UNION ALL SELECT 'gym_app can EXECUTE app_password_reset_confirm', has_function_privilege('gym_app', 'public.app_password_reset_confirm(bytea,text)', 'EXECUTE')
UNION ALL SELECT 'gym_app can NOT read app_password_resets (expected true)', NOT has_table_privilege('gym_app', 'public.app_password_resets', 'SELECT')
UNION ALL SELECT 'gym_app can NOT read app_users (expected true)',           NOT has_table_privilege('gym_app', 'public.app_users', 'SELECT')
UNION ALL SELECT 'PUBLIC can NOT execute app_password_reset_confirm (expected true)',
       NOT has_function_privilege('public', 'public.app_password_reset_confirm(bytea,text)', 'EXECUTE')
UNION ALL SELECT 'demo accounts have e-mail (seed_reset_emails.sql)', (SELECT count(*) FROM public.app_users WHERE email IS NOT NULL) >= 2;

-- Evidence of one reset (no secrets): the table shows a hash, an expiry and the use time, never the link.
-- SELECT reset_id, user_id, left(encode(token_hash,'hex'), 12) AS hash_start, created_at, expires_at, used_at
--   FROM public.app_password_resets ORDER BY reset_id DESC LIMIT 5;
-- Make a link expire for the "expired link" test (replace the user):
-- UPDATE public.app_password_resets SET created_at = now() - interval '31 minutes', expires_at = now() - interval '1 minute'
--  WHERE used_at IS NULL AND user_id = (SELECT user_id FROM public.app_users WHERE username = 'dana');
