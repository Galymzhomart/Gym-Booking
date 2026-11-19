-- Run as database owner/postgres after connecting to the target gym_booking database.
-- The limited gym_app role needs this table for persistent login sessions.
CREATE TABLE IF NOT EXISTS public.app_sessions (
  sid varchar NOT NULL COLLATE "default",
  sess json NOT NULL,
  expire timestamp(6) NOT NULL,
  CONSTRAINT app_sessions_pkey PRIMARY KEY (sid)
);
CREATE INDEX IF NOT EXISTS app_sessions_expire_idx ON public.app_sessions (expire);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.app_sessions TO gym_app;
