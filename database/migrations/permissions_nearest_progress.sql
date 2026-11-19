-- permissions_nearest_progress.sql (Shokan). Run as postgres AFTER permissions.sql, permissions_additions.sql,
-- permissions_2fa.sql and permissions_password_reset.sql. permissions.sql resets gym_app on every run,
-- so run this file again after it. Safe to re-run. gym_app gets EXECUTE on three read-only functions.
DO $do$
DECLARE f regprocedure;
BEGIN
    FOR f IN SELECT p.oid::regprocedure FROM pg_proc p
             WHERE p.pronamespace = 'public'::regnamespace
               AND p.proname IN ('app_trainer_slots_for_member', 'app_nearest_session', 'app_weekly_progress')
    LOOP
        EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO gym_app', f);
    END LOOP;
END
$do$;
