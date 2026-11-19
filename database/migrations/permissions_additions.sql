-- permissions_additions.sql — for Ruslan. Run as postgres AFTER migration.sql and permissions.sql.
-- Gives gym_app the two things the migration added; nothing else.
GRANT USAGE ON SEQUENCE public.booking_id_seq TO gym_app;          -- booking_id default
GRANT EXECUTE ON FUNCTION public.app_login(text, text) TO gym_app;  -- login without reading password hashes
-- app_users is deliberately NOT granted to gym_app.
