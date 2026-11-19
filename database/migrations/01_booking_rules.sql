-- migration.sql  (Shokan, Data & Database)
-- Adds the new booking rules on top of the restored gym_booking backup.
-- Old objects (tables, constraints, unique index, validate_booking logic) are NOT changed.
-- Run as postgres, once, on the restored copy. Safe to run again (idempotent).
--
-- New rules (all checked by triggers on bookings):
--   R1  new Confirmed booking is not allowed if the trainer of the session is inactive
--   R2  one member cannot have two overlapping non-cancelled bookings
--       (adjacent intervals like 10:00-11:00 and 11:00-12:00 are allowed)
--   R3  status transitions:
--         Confirmed -> Cancelled        only before the session starts
--         Confirmed -> Attended/No-show only after the session ends
--         everything else is forbidden (no way back, Attended/No-show/Cancelled are final)
-- All trigger functions are SECURITY DEFINER with a fixed search_path, so the
-- limited role gym_app can fire them without extra privileges on members/sessions/trainers.

BEGIN;

-- 0. Existing function: keep the logic, only change how it runs (needed for gym_app).
ALTER FUNCTION public.validate_booking()
    SECURITY DEFINER
    SET search_path = public, pg_catalog;
REVOKE ALL ON FUNCTION public.validate_booking() FROM PUBLIC;

-- R1. Inactive trainer ---------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_trainer_active() RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, pg_catalog
AS $$
BEGIN
    IF NEW.status <> 'Confirmed' THEN
        RETURN NEW;
    END IF;
    -- On UPDATE check only when the booking becomes Confirmed or moves to another session/member.
    IF TG_OP = 'UPDATE'
       AND OLD.status = NEW.status
       AND OLD.session_id = NEW.session_id
       AND OLD.member_id = NEW.member_id THEN
        RETURN NEW;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM sessions s
        JOIN trainers t ON t.trainer_id = s.trainer_id
        WHERE s.session_id = NEW.session_id
          AND NOT t.is_active
    ) THEN
        RAISE EXCEPTION 'Trainer is not active';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.check_trainer_active() FROM PUBLIC;

-- R2. Client overlap -----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_member_overlap() RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, pg_catalog
AS $$
DECLARE
    new_range tstzrange;
BEGIN
    IF NEW.status = 'Cancelled' THEN
        RETURN NEW;
    END IF;

    SELECT tstzrange(s.start_time, s.end_time, '[)')
    INTO new_range
    FROM sessions s
    WHERE s.session_id = NEW.session_id;

    IF new_range IS NULL THEN
        RETURN NEW;  -- unknown session: the foreign key will reject it
    END IF;

    -- Serialize concurrent bookings of the same member (two parallel INSERTs).
    PERFORM pg_advisory_xact_lock(hashtext('member_overlap:' || NEW.member_id));

    IF EXISTS (
        SELECT 1
        FROM bookings b
        JOIN sessions s ON s.session_id = b.session_id
        WHERE b.member_id = NEW.member_id
          AND b.booking_id <> NEW.booking_id          -- a row never conflicts with itself
          AND b.status <> 'Cancelled'
          AND tstzrange(s.start_time, s.end_time, '[)') && new_range   -- '[)' => adjacent is OK
    ) THEN
        RAISE EXCEPTION 'Member already has a booking that overlaps in time';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.check_member_overlap() FROM PUBLIC;

-- R3. Status transitions -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.check_status_transition() RETURNS trigger
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public, pg_catalog
AS $$
DECLARE
    sess sessions%ROWTYPE;
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    IF OLD.status <> 'Confirmed' THEN
        RAISE EXCEPTION 'Status transition % -> % is not allowed', OLD.status, NEW.status;
    END IF;

    SELECT * INTO sess FROM sessions WHERE session_id = NEW.session_id;

    IF NEW.status = 'Cancelled' THEN
        IF sess.start_time <= CURRENT_TIMESTAMP THEN
            RAISE EXCEPTION 'Cannot cancel: the session has already started';
        END IF;
    ELSIF NEW.status IN ('Attended', 'No-show') THEN
        IF sess.end_time > CURRENT_TIMESTAMP THEN
            RAISE EXCEPTION 'Cannot set %: the session has not ended yet', NEW.status;
        END IF;
    ELSE
        RAISE EXCEPTION 'Status transition % -> % is not allowed', OLD.status, NEW.status;
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.check_status_transition() FROM PUBLIC;

-- Triggers (PostgreSQL runs BEFORE triggers in alphabetical order of their names)
DROP TRIGGER IF EXISTS trg_check_trainer_active ON public.bookings;
CREATE TRIGGER trg_check_trainer_active
    BEFORE INSERT OR UPDATE OF member_id, session_id, status ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.check_trainer_active();

DROP TRIGGER IF EXISTS trg_check_member_overlap ON public.bookings;
CREATE TRIGGER trg_check_member_overlap
    BEFORE INSERT OR UPDATE OF member_id, session_id, status ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.check_member_overlap();

-- Named check_00_... so it runs FIRST (digits sort before letters): for a forbidden status
-- change the user then sees the clear transition message, not a message from validate_booking.
DROP TRIGGER IF EXISTS trg_check_status_transition ON public.bookings;   -- name from an earlier draft
DROP TRIGGER IF EXISTS check_00_status_transition ON public.bookings;
CREATE TRIGGER check_00_status_transition
    BEFORE UPDATE OF status ON public.bookings
    FOR EACH ROW EXECUTE FUNCTION public.check_status_transition();

COMMIT;
