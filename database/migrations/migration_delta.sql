-- migration_delta.sql (FINAL v2, replaces the old migration_delta.sql AND fix_lifecycle.sql)
--   additions on top of Shokan's own schema (check_status_transition,
-- check_member_overlap, check_trainer_active, validate_booking are NOT touched).
-- Run as postgres AFTER your own migration.sql. Safe to re-run.
--
--   1. closes a hole: a booking could be INSERTed directly as Attended / No-show / Cancelled,
--      which skipped membership, trainer, past-date and overlap checks (all of them return early
--      for status <> 'Confirmed'). A NEW booking must be Confirmed (Cancelled appears only after
--      cancelling); existing Cancelled rows are kept. Also blocks moving a closed booking to
--      another member/session.
--   2. booking_id default (sequence), so the app does not invent IDs
--   3. app_users + app_login() for server-side login (Ruslan asked for it)

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1 ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_booking_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status <> 'Confirmed' THEN
            RAISE EXCEPTION 'New booking must have status Confirmed';
        END IF;
    ELSIF OLD.status <> 'Confirmed'
          AND (NEW.member_id <> OLD.member_id OR NEW.session_id <> OLD.session_id) THEN
        RAISE EXCEPTION 'Booking history cannot be changed (status %)', OLD.status;
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.check_booking_lifecycle() FROM PUBLIC;

DROP TRIGGER IF EXISTS check_00_booking_lifecycle ON public.bookings;
CREATE TRIGGER check_00_booking_lifecycle
    BEFORE INSERT OR UPDATE OF member_id, session_id, status ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.check_booking_lifecycle();

-- 2 ---------------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.booking_id_seq START WITH 2001;
ALTER TABLE public.bookings
    ALTER COLUMN booking_id SET DEFAULT ('B-' || nextval('public.booking_id_seq'));

-- 3 ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_users (
    user_id       integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username      varchar(50)  NOT NULL,
    password_hash text         NOT NULL,
    role          varchar(20)  NOT NULL,
    member_id     varchar(20)  REFERENCES public.members(member_id),
    is_active     boolean      NOT NULL DEFAULT true,
    CONSTRAINT app_users_role_check CHECK (role IN ('Member', 'Reception')),
    CONSTRAINT app_users_username_lower CHECK (username = lower(username)),
    CONSTRAINT app_users_role_member CHECK (
        (role = 'Member'    AND member_id IS NOT NULL) OR
        (role = 'Reception' AND member_id IS NULL))
);
CREATE UNIQUE INDEX IF NOT EXISTS app_users_username_key ON public.app_users (username);
CREATE UNIQUE INDEX IF NOT EXISTS app_users_member_key   ON public.app_users (member_id);

CREATE OR REPLACE FUNCTION public.app_login(p_username text, p_password text)
RETURNS TABLE (user_id integer, role text, member_id text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
    SELECT u.user_id, u.role::text, u.member_id::text
    FROM app_users u
    WHERE u.username = lower(p_username)
      AND u.is_active
      AND u.password_hash = crypt(p_password, u.password_hash);
$$;
REVOKE ALL ON FUNCTION public.app_login(text, text) FROM PUBLIC;
COMMIT;
