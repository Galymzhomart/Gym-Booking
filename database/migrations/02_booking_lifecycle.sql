-- 02_booking_lifecycle.sql
-- This trigger already exists in the shared database (added by a teammate). This file only
-- REPRODUCES it, so that a clean rebuild (backup -> migrations) gives the same database.
-- Safe to run on the shared database: CREATE OR REPLACE with the same body, and the trigger
-- is created only if no trigger uses this function yet.
-- Rules: a NEW booking must be Confirmed; member_id / session_id of a closed booking
-- (Cancelled, Attended, No-show) cannot be changed (booking history).
CREATE OR REPLACE FUNCTION public.check_booking_lifecycle()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_catalog'
AS $function$
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
$function$;
REVOKE ALL ON FUNCTION public.check_booking_lifecycle() FROM PUBLIC;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_trigger
                   WHERE tgfoid = 'public.check_booking_lifecycle()'::regprocedure AND NOT tgisinternal) THEN
        -- ASSUMED definition (events as in the other booking triggers). Compare with the shared DB:
        --   SELECT pg_get_triggerdef(oid) FROM pg_trigger WHERE tgname LIKE 'check_00_booking_lifecy%';
        CREATE TRIGGER check_00_booking_lifecycle
            BEFORE INSERT OR UPDATE OF member_id, session_id, status ON public.bookings
            FOR EACH ROW EXECUTE FUNCTION public.check_booking_lifecycle();
    END IF;
END $$;
