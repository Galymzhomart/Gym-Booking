-- permissions_password_reset.sql (Ruslan). Run as postgres AFTER permissions.sql, permissions_additions.sql
-- and permissions_2fa.sql. Safe to re-run. permissions.sql resets gym_app, so run this file again after it.
-- gym_app gets EXECUTE on three functions only. It gets nothing on app_password_resets and nothing on app_users.

DO $do$
DECLARE f regprocedure;
BEGIN
    FOR f IN SELECT p.oid::regprocedure FROM pg_proc p
             WHERE p.pronamespace = 'public'::regnamespace
               AND p.proname IN ('app_password_reset_request', 'app_password_reset_check', 'app_password_reset_confirm')
    LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO gym_app', f);
    END LOOP;
    REVOKE ALL ON TABLE public.app_password_resets FROM gym_app;
END
$do$;
