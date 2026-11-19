-- enroll_2fa.sql (Ruslan). Run as postgres in pgAdmin Query Tool. Safe to re-run.
-- Creates a NEW random secret for each listed account (re-running replaces the old secret).
-- The secret is shown ONLY in the result grid (column secret_base32), not in this file.
-- Type it into the authenticator app by hand ("Enter a setup key"). No QR code is made.
-- Do NOT screenshot the result. Close the result tab after you typed the keys.
-- Edit the username list below if your demo accounts are named differently.

WITH new_secrets AS (
    INSERT INTO public.app_user_totp (user_id, secret)
    SELECT u.user_id, gen_random_bytes(20)
    FROM public.app_users u
    WHERE u.username IN ('reception1', 'ayan', 'dana', 'sofia', 'ilyas', 'amina', 'member302')
    ON CONFLICT (user_id) DO UPDATE
        SET secret = EXCLUDED.secret, enabled = true,
            last_used_step = 0, failed_attempts = 0, locked_until = NULL
    RETURNING user_id, secret
),
bits AS (
    SELECT n.user_id,
           (SELECT string_agg(get_byte(n.secret, i)::bit(8)::text, '' ORDER BY i)
            FROM generate_series(0, 19) AS i) AS b
    FROM new_secrets n
)
SELECT u.username,
       (SELECT string_agg(
                 substr('ABCDEFGHIJKLMNOPQRSTUVWXYZ234567',
                        substr(bits.b, k * 5 + 1, 5)::bit(5)::int + 1, 1),
                 '' ORDER BY k)
        FROM generate_series(0, 31) AS k) AS secret_base32
FROM bits
JOIN public.app_users u USING (user_id)
ORDER BY u.username;
