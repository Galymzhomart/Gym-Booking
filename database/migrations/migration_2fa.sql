-- migration_2fa.sql (Ruslan, 2FA). Run as postgres. Safe to re-run.
-- Run AFTER migration_delta.sql (needs app_users) and BEFORE permissions.sql.
-- Adds TOTP (RFC 6238: SHA-1, 6 digits, 30 s step) checked INSIDE the database.
-- Nothing existing is changed. The app role gym_app never reads the secret.
--
-- New objects:
--   table    app_user_totp                 (secret + counters, no rights for gym_app)
--   function totp_code_at(bytea, bigint)   (helper, postgres only)
--   function app_totp_enabled(<user_id type>)     (gym_app may call it)
--   function app_totp_verify(<user_id type>,text) (gym_app may call it)

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- user_id gets the same type as app_users.user_id (integer, bigint, uuid, ...), so this file does not guess it.
DO $do$
BEGIN
    IF to_regclass('public.app_user_totp') IS NULL THEN
        EXECUTE format($t$
            CREATE TABLE public.app_user_totp (
                user_id         %s PRIMARY KEY REFERENCES public.app_users(user_id) ON DELETE CASCADE,
                secret          bytea       NOT NULL,
                enabled         boolean     NOT NULL DEFAULT true,
                last_used_step  bigint      NOT NULL DEFAULT 0,
                failed_attempts integer     NOT NULL DEFAULT 0,
                locked_until    timestamptz,
                created_at      timestamptz NOT NULL DEFAULT now(),
                CONSTRAINT app_user_totp_secret_len CHECK (length(secret) = 20)
            )$t$,
            (SELECT format_type(atttypid, atttypmod) FROM pg_attribute
              WHERE attrelid = 'public.app_users'::regclass AND attname = 'user_id'));
    END IF;
END
$do$;


-- Helper: the 6-digit code for one time step (RFC 4226 dynamic truncation).
CREATE OR REPLACE FUNCTION public.totp_code_at(p_secret bytea, p_step bigint)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_catalog
AS $$
DECLARE
    h   bytea;
    off integer;
    bin bigint;
BEGIN
    h   := hmac(int8send(p_step), p_secret, 'sha1');   -- step as 8 bytes, big-endian
    off := get_byte(h, 19) & 15;
    bin := ((get_byte(h, off)     & 127)::bigint << 24)
         |  (get_byte(h, off + 1)::bigint << 16)
         |  (get_byte(h, off + 2)::bigint << 8)
         |   get_byte(h, off + 3)::bigint;
    RETURN lpad((bin % 1000000)::text, 6, '0');
END;
$$;

-- Does this user have 2FA turned on?
CREATE OR REPLACE FUNCTION public.app_totp_enabled(p_user_id public.app_users.user_id%TYPE)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
    SELECT EXISTS (SELECT 1 FROM app_user_totp WHERE user_id = p_user_id AND enabled);
$$;

-- Check a code. Returns: ok | invalid | replay | locked | not_enrolled
--   window: current step and one step before/after (+-30 s)
--   replay: a step that is not newer than last_used_step is refused
--   lock:   5 wrong codes in a row -> locked for 5 minutes (per user, in the database)
CREATE OR REPLACE FUNCTION public.app_totp_verify(p_user_id public.app_users.user_id%TYPE, p_code text)
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    r        app_user_totp%ROWTYPE;
    cur_step bigint;
    s        bigint;
    matched  bigint := NULL;
    result   text;
BEGIN
    SELECT * INTO r FROM app_user_totp WHERE user_id = p_user_id AND enabled FOR UPDATE;
    IF NOT FOUND THEN
        RETURN 'not_enrolled';
    END IF;

    IF r.locked_until IS NOT NULL AND r.locked_until > now() THEN
        RETURN 'locked';
    END IF;

    IF p_code IS NULL OR p_code !~ '^[0-9]{6}$' THEN
        RETURN 'invalid';              -- bad format is not counted as an attempt
    END IF;

    cur_step := floor(extract(epoch FROM now()) / 30)::bigint;
    FOR s IN (cur_step - 1)..(cur_step + 1) LOOP
        IF totp_code_at(r.secret, s) = p_code THEN
            matched := s;
        END IF;
    END LOOP;

    IF matched IS NOT NULL AND matched > r.last_used_step THEN
        UPDATE app_user_totp
           SET last_used_step = matched, failed_attempts = 0, locked_until = NULL
         WHERE user_id = p_user_id;
        RETURN 'ok';
    END IF;

    result := CASE WHEN matched IS NULL THEN 'invalid' ELSE 'replay' END;

    IF r.failed_attempts + 1 >= 5 THEN
        UPDATE app_user_totp
           SET failed_attempts = 0, locked_until = now() + interval '5 minutes'
         WHERE user_id = p_user_id;
        RETURN 'locked';
    END IF;

    UPDATE app_user_totp SET failed_attempts = failed_attempts + 1 WHERE user_id = p_user_id;
    RETURN result;
END;
$$;

DO $do$
DECLARE f regprocedure;
BEGIN
    REVOKE ALL ON TABLE public.app_user_totp FROM PUBLIC;
    FOR f IN SELECT p.oid::regprocedure FROM pg_proc p
             WHERE p.pronamespace = 'public'::regnamespace
               AND p.proname IN ('totp_code_at', 'app_totp_enabled', 'app_totp_verify')
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', f);
    END LOOP;
END
$do$;
COMMIT;
