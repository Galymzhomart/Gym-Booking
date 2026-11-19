-- verify_2fa_restore.sql (Shokan, from Ruslan's list). Run as postgres in the restored database
-- AFTER the full run order (see README). All "ok" values must be true, except where noted.
SELECT 'table app_user_totp exists'      AS item, to_regclass('public.app_user_totp') IS NOT NULL AS ok
UNION ALL SELECT 'function totp_code_at',     to_regproc('public.totp_code_at') IS NOT NULL
UNION ALL SELECT 'function app_totp_enabled', EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'app_totp_enabled' AND pronamespace = 'public'::regnamespace)
UNION ALL SELECT 'function app_totp_verify',  EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'app_totp_verify'  AND pronamespace = 'public'::regnamespace)
UNION ALL SELECT 'gym_app can NOT read app_user_totp (expected true)', NOT has_table_privilege('gym_app', 'public.app_user_totp', 'SELECT')
UNION ALL SELECT 'gym_app can read sessions_overview',                  has_table_privilege('gym_app', 'public.sessions_overview', 'SELECT')
UNION ALL SELECT 'gym_app can read db_translations',                    has_table_privilege('gym_app', 'public.db_translations', 'SELECT');
-- A27b from gym_app_audit.sql must still be run by hand: expected  true, false, true, false.
-- Manual check: SET ROLE gym_app; SELECT * FROM app_user_totp;  -> permission denied.  RESET ROLE;
