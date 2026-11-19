-- permissions.sql  (FINAL version; older copies such as "permissions (1).sql" are obsolete)
-- Sets up the PostgreSQL connection role for the app (gym_app).
-- It only covers database privileges. Member / Reception rules are checked by the server.
--
-- Run as postgres, on a TEST copy of the database, while CONNECTED TO THAT DATABASE
-- (in pgAdmin the Query Tool must be open on your copy, not on "postgres").
-- The database name is taken automatically, so the file works on any copy.
--
-- Safe to run more than once. If gym_app already exists, this file also removes
-- extra attributes, extra role memberships and extra privileges it may have had.
--
-- ORDER OF FILES (see README.md):
--   backup -> migration.sql -> migration_delta.sql -> fix_lifecycle.sql   (Shokan)
--   -> permissions.sql (this file) -> permissions_additions.sql (Shokan)
--   -> app_sessions.sql (Yernur) -> ALTER ROLE gym_app PASSWORD '<secret>';
-- This file resets the rights of gym_app first, so permissions_additions.sql and
-- app_sessions.sql must be run AFTER it (they give the sequence, app_login()
-- and app_sessions back).

DO $$
DECLARE
  r record;
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'gym_app') THEN
    CREATE ROLE gym_app LOGIN;
  END IF;

  -- Force the safe attributes, also when the role already existed.
  ALTER ROLE gym_app WITH LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;

  -- gym_app must not be a member of any other role.
  FOR r IN
    SELECT g.rolname
    FROM pg_auth_members m
    JOIN pg_roles g ON g.oid = m.roleid
    JOIN pg_roles u ON u.oid = m.member
    WHERE u.rolname = 'gym_app'
  LOOP
    EXECUTE format('REVOKE %I FROM gym_app', r.rolname);
  END LOOP;

  EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database());
  EXECUTE format('REVOKE ALL ON DATABASE %I FROM gym_app', current_database());
  EXECUTE format('GRANT CONNECT ON DATABASE %I TO gym_app', current_database());
END $$;
-- The password is NOT stored here. Set it by hand in a separate command:
--   ALTER ROLE gym_app PASSWORD '<secret>';

-- Start from zero: remove everything gym_app may have had before.
REVOKE ALL ON SCHEMA public FROM gym_app;
REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM gym_app;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM gym_app;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM gym_app;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO gym_app;

GRANT SELECT ON members, trainers, sessions, bookings TO gym_app;
GRANT INSERT ON bookings TO gym_app;
GRANT UPDATE (status) ON bookings TO gym_app;
-- No DELETE on bookings on purpose: booking history must be kept.
-- Not granted at all: app_users (password hashes). Login goes through app_login().

-- Shokan's trigger functions are SECURITY DEFINER, which is why gym_app can INSERT
-- without having UPDATE on members or sessions. gym_app must NOT get that privilege.

-- LIMITATIONS (checked by the server, not by these privileges):
-- * The app uses one database account, so Member / Reception rules live on the server.
-- * gym_app can read all columns of members.
-- * gym_app can insert a booking as Confirmed, or as Cancelled (a history row).
-- * After permissions_additions.sql and app_sessions.sql, gym_app can also use
--   booking_id_seq, run app_login(), and read/write the login-session table
--   app_sessions (it has no DELETE on bookings).
