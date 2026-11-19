-- 03b_grants_translations.sql (Shokan). Run as postgres AFTER permissions.sql and permissions_additions.sql.
-- Reason: permissions.sql (Ruslan) resets the rights of gym_app, so the rights from 03_translations.sql are lost.
-- Safe to run again.
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'gym_app') THEN
        GRANT SELECT ON public.db_translations, public.sessions_overview TO gym_app;
        GRANT EXECUTE ON FUNCTION public.tr(text, text, text) TO gym_app;
    END IF;
END $$;
