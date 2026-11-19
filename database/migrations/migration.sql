-- migration.sql — Shokan (Data & Database), stage 2. Rebuilt from my_schema.sql (pg_dump of gym_booking_shokan).
-- Run as postgres on a database restored from gym_booking.backup. Safe to re-run.
-- Adds: inactive-trainer rule, member overlap rule (adjacent allowed), status transitions,
-- and makes validate_booking SECURITY DEFINER so the limited role gym_app can INSERT.
-- Old constraints, the unique index and the trigger check_booking_before_save are kept.
-- Next files: migration_delta.sql, fix_lifecycle.sql.

BEGIN;

CREATE OR REPLACE FUNCTION public.check_member_overlap() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_catalog'
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


CREATE OR REPLACE FUNCTION public.check_status_transition() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_catalog'
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


CREATE OR REPLACE FUNCTION public.check_trainer_active() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_catalog'
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


CREATE OR REPLACE FUNCTION public.validate_booking() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public', 'pg_catalog'
    AS $$
DECLARE
    selected_member members%ROWTYPE;
    selected_session sessions%ROWTYPE;
BEGIN
    -- Отмена и закрытие брони не требуют нового абонемента.
    IF NEW.status <> 'Confirmed' THEN
        RETURN NEW;
    END IF;

    SELECT *
    INTO selected_member
    FROM members
    WHERE member_id = NEW.member_id
    FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Member does not exist';
    END IF;

    SELECT *
    INTO selected_session
    FROM sessions
    WHERE session_id = NEW.session_id
    FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Session does not exist';
    END IF;

    IF selected_member.membership_status <> 'Active' THEN
        RAISE EXCEPTION 'Membership must be active';
    END IF;

    IF selected_member.membership_expiry <
       (selected_session.start_time
        AT TIME ZONE 'Asia/Almaty')::DATE THEN
        RAISE EXCEPTION
            'Membership expires before the session date';
    END IF;

    IF selected_session.start_time <= CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Cannot book a session in the past';
    END IF;

    RETURN NEW;
END;
$$;


REVOKE ALL ON FUNCTION public.check_member_overlap() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_status_transition() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.check_trainer_active() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.validate_booking() FROM PUBLIC;

DROP TRIGGER IF EXISTS check_00_status_transition ON public.bookings;
CREATE TRIGGER check_00_status_transition BEFORE UPDATE OF status ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.check_status_transition();

DROP TRIGGER IF EXISTS trg_check_member_overlap ON public.bookings;
CREATE TRIGGER trg_check_member_overlap BEFORE INSERT OR UPDATE OF member_id, session_id, status ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.check_member_overlap();

DROP TRIGGER IF EXISTS trg_check_trainer_active ON public.bookings;
CREATE TRIGGER trg_check_trainer_active BEFORE INSERT OR UPDATE OF member_id, session_id, status ON public.bookings FOR EACH ROW EXECUTE FUNCTION public.check_trainer_active();

COMMIT;
