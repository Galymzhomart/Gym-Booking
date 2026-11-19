-- migration_password_reset.sql (Ruslan, agreed with Shokan). Run as postgres. Safe to re-run.
-- Run AFTER migration_delta.sql (needs app_users) and migration_2fa.sql, BEFORE permissions.sql.
-- Password recovery by e-mail link. Only a SHA-256 hash of the token is stored; the token itself
-- exists only in the e-mail. gym_app gets EXECUTE on three functions and nothing on the tables.
--
-- New objects:
--   column   app_users.email                     (nullable, lower-case, unique when set)
--   table    app_password_resets                 (token hash, expiry, used time; no rights for gym_app)
--   function app_password_reset_request(text, bytea, integer)  -> username, email   (0 rows = nothing to send)
--   function app_password_reset_check(bytea)                   -> valid | expired | used | invalid
--   function app_password_reset_confirm(bytea, text)           -> ok | invalid | expired | used | weak | same
--
-- Rules inside the database:
--   * only an active user with a matching e-mail gets a token
--   * a new request expires every older unused link of that user
--   * at most 3 requests per user per hour (further requests return 0 rows)
--   * a token works once; confirm is atomic (row lock), so two parallel submits cannot both succeed
--   * confirm stores a new bcrypt hash, expires other links and deletes the user's login sessions
--   * 2FA is not touched: the next login with the new password still asks for the code

BEGIN;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.app_users ADD COLUMN IF NOT EXISTS email varchar(254);

DO $do$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'app_users_email_format'
                   AND conrelid = 'public.app_users'::regclass) THEN
        ALTER TABLE public.app_users ADD CONSTRAINT app_users_email_format
            CHECK (email IS NULL OR (email = lower(email) AND email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'));
    END IF;
END
$do$;
CREATE UNIQUE INDEX IF NOT EXISTS app_users_email_key ON public.app_users (email) WHERE email IS NOT NULL;

DO $do$
BEGIN
    IF to_regclass('public.app_password_resets') IS NULL THEN
        EXECUTE format($t$
            CREATE TABLE public.app_password_resets (
                reset_id   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                user_id    %s NOT NULL REFERENCES public.app_users(user_id) ON DELETE CASCADE,
                token_hash bytea       NOT NULL UNIQUE,
                created_at timestamptz NOT NULL DEFAULT now(),
                expires_at timestamptz NOT NULL,
                used_at    timestamptz,
                CONSTRAINT app_password_resets_hash_len CHECK (length(token_hash) = 32),
                CONSTRAINT app_password_resets_expiry   CHECK (expires_at > created_at)
            )$t$,
            (SELECT format_type(atttypid, atttypmod) FROM pg_attribute
              WHERE attrelid = 'public.app_users'::regclass AND attname = 'user_id'));
        CREATE INDEX app_password_resets_user_idx ON public.app_password_resets (user_id, created_at DESC);
    END IF;
END
$do$;

-- Create a reset token for an e-mail. The server makes the random token and passes only its SHA-256.
-- Returns the user to write to; 0 rows when there is nothing to send (unknown/inactive/throttled).
CREATE OR REPLACE FUNCTION public.app_password_reset_request(p_email text, p_token_hash bytea, p_ttl_minutes integer DEFAULT 30)
RETURNS TABLE (username text, email text)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    u   app_users%ROWTYPE;
    ttl integer := least(greatest(coalesce(p_ttl_minutes, 30), 5), 1440);
BEGIN
    IF p_email IS NULL OR p_token_hash IS NULL OR length(p_token_hash) <> 32 THEN
        RETURN;
    END IF;

    SELECT * INTO u FROM app_users
     WHERE app_users.email = lower(btrim(p_email)) AND is_active
     FOR UPDATE;                                   -- serializes parallel requests of one user
    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF (SELECT count(*) FROM app_password_resets r
         WHERE r.user_id = u.user_id AND r.created_at > now() - interval '1 hour') >= 3 THEN
        RETURN;
    END IF;

    UPDATE app_password_resets r SET expires_at = now()
     WHERE r.user_id = u.user_id AND r.used_at IS NULL AND r.expires_at > now();

    INSERT INTO app_password_resets (user_id, token_hash, expires_at)
    VALUES (u.user_id, p_token_hash, now() + make_interval(mins => ttl));

    username := u.username;
    email    := u.email;
    RETURN NEXT;
END;
$$;

-- Is the link usable? valid | expired | used | invalid (unknown token or inactive user)
CREATE OR REPLACE FUNCTION public.app_password_reset_check(p_token_hash bytea)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    r app_password_resets%ROWTYPE;
BEGIN
    IF p_token_hash IS NULL THEN RETURN 'invalid'; END IF;
    SELECT * INTO r FROM app_password_resets WHERE token_hash = p_token_hash;
    IF NOT FOUND THEN RETURN 'invalid'; END IF;
    IF NOT EXISTS (SELECT 1 FROM app_users WHERE user_id = r.user_id AND is_active) THEN RETURN 'invalid'; END IF;
    IF r.used_at IS NOT NULL THEN RETURN 'used'; END IF;
    IF r.expires_at <= now() THEN RETURN 'expired'; END IF;
    RETURN 'valid';
END;
$$;

-- Set the new password. Returns: ok | invalid | expired | used | weak | same
CREATE OR REPLACE FUNCTION public.app_password_reset_confirm(p_token_hash bytea, p_password text)
RETURNS text
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
DECLARE
    r app_password_resets%ROWTYPE;
    u app_users%ROWTYPE;
BEGIN
    IF p_token_hash IS NULL THEN RETURN 'invalid'; END IF;

    SELECT * INTO r FROM app_password_resets WHERE token_hash = p_token_hash FOR UPDATE;
    IF NOT FOUND THEN RETURN 'invalid'; END IF;
    IF r.used_at IS NOT NULL THEN RETURN 'used'; END IF;
    IF r.expires_at <= now() THEN RETURN 'expired'; END IF;

    SELECT * INTO u FROM app_users WHERE user_id = r.user_id AND is_active FOR UPDATE;
    IF NOT FOUND THEN RETURN 'invalid'; END IF;

    -- A weak password does not burn the link: the user can try again.
    IF p_password IS NULL OR length(p_password) < 8 OR length(p_password) > 200
       OR p_password !~ '[[:alpha:]]' OR p_password !~ '[0-9]' THEN
        RETURN 'weak';
    END IF;
    IF u.password_hash = crypt(p_password, u.password_hash) THEN
        RETURN 'same';
    END IF;

    UPDATE app_users SET password_hash = crypt(p_password, gen_salt('bf')) WHERE user_id = u.user_id;
    UPDATE app_password_resets SET used_at = now() WHERE reset_id = r.reset_id;
    UPDATE app_password_resets SET expires_at = now()
     WHERE user_id = u.user_id AND used_at IS NULL AND expires_at > now();

    -- Sign out everywhere (finished and half-finished logins of this user).
    IF to_regclass('public.app_sessions') IS NOT NULL THEN
        DELETE FROM app_sessions
         WHERE sess::jsonb #>> '{user,userId}' = u.user_id::text
            OR sess::jsonb #>> '{pending2fa,userId}' = u.user_id::text;
    END IF;
    RETURN 'ok';
END;
$$;

DO $do$
DECLARE f regprocedure;
BEGIN
    REVOKE ALL ON TABLE public.app_password_resets FROM PUBLIC;
    FOR f IN SELECT p.oid::regprocedure FROM pg_proc p
             WHERE p.pronamespace = 'public'::regnamespace
               AND p.proname IN ('app_password_reset_request', 'app_password_reset_check', 'app_password_reset_confirm')
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC', f);
    END LOOP;
END
$do$;
COMMIT;
