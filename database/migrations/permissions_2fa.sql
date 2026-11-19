-- permissions_2fa.sql (Ruslan, 2FA). Run as postgres AFTER permissions.sql
-- and permissions_additions.sql. Safe to re-run.
-- permissions.sql resets the rights of gym_app on every run, so this file must be run again after it.
-- gym_app gets only EXECUTE on two functions. It gets nothing on the table app_user_totp.

DO $do$
DECLARE f regprocedure;
BEGIN
    FOR f IN SELECT p.oid::regprocedure FROM pg_proc p
             WHERE p.pronamespace = 'public'::regnamespace
               AND p.proname IN ('app_totp_enabled', 'app_totp_verify')
    LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO gym_app', f);
    END LOOP;
    -- Explicit, even if already true:
    REVOKE ALL ON TABLE public.app_user_totp FROM gym_app;
    FOR f IN SELECT p.oid::regprocedure FROM pg_proc p
             WHERE p.pronamespace = 'public'::regnamespace AND p.proname = 'totp_code_at'
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM gym_app', f);
    END LOOP;
END
$do$;
