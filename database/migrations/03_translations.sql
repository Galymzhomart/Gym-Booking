-- 03_translations.sql  -- Kazakh / Russian / English texts that come from the database.
-- Only hall names (sessions.location) and trainer specializations are translated.
-- Trainer names and status values stay as they are (agreed rule).
-- sessions.location stays the KEY; nothing in sessions/trainers is changed, so old code keeps working.
-- Safe to run again.
BEGIN;

CREATE TABLE IF NOT EXISTS public.db_translations (
    entity text NOT NULL CHECK (entity IN ('location', 'specialization')),
    key    text NOT NULL,                                   -- value as stored in sessions / trainers
    lang   text NOT NULL CHECK (lang IN ('kk', 'ru', 'en')),
    value  text NOT NULL CHECK (length(trim(value)) > 0),
    PRIMARY KEY (entity, key, lang)
);

INSERT INTO public.db_translations (entity, key, lang, value) VALUES
  ('location', 'Fitness Hall', 'kk', 'Фитнес залы'),
  ('location', 'Fitness Hall', 'ru', 'Фитнес-зал'),
  ('location', 'Fitness Hall', 'en', 'Fitness Hall'),
  ('location', 'Yoga Studio',  'kk', 'Йога студиясы'),
  ('location', 'Yoga Studio',  'ru', 'Студия йоги'),
  ('location', 'Yoga Studio',  'en', 'Yoga Studio'),
  ('location', 'Boxing Hall',  'kk', 'Бокс залы'),
  ('location', 'Boxing Hall',  'ru', 'Зал бокса'),
  ('location', 'Boxing Hall',  'en', 'Boxing Hall'),
  ('specialization', 'Fitness', 'kk', 'Фитнес'),
  ('specialization', 'Fitness', 'ru', 'Фитнес'),
  ('specialization', 'Fitness', 'en', 'Fitness'),
  ('specialization', 'Yoga',    'kk', 'Йога'),
  ('specialization', 'Yoga',    'ru', 'Йога'),
  ('specialization', 'Yoga',    'en', 'Yoga'),
  ('specialization', 'Boxing',  'kk', 'Бокс'),
  ('specialization', 'Boxing',  'ru', 'Бокс'),
  ('specialization', 'Boxing',  'en', 'Boxing')
ON CONFLICT DO NOTHING;

-- tr('location', 'Yoga Studio', 'kk') -> 'Йога студиясы'. Unknown text or language -> the original key.
CREATE OR REPLACE FUNCTION public.tr(p_entity text, p_key text, p_lang text) RETURNS text
LANGUAGE sql STABLE AS $$
    SELECT COALESCE((SELECT value FROM public.db_translations
                     WHERE entity = p_entity AND key = p_key AND lang = p_lang), p_key)
$$;

-- One list for the sessions screen: includes the "busy" flag (is_booked) for the interface.
CREATE OR REPLACE VIEW public.sessions_overview AS
SELECT s.session_id, s.trainer_id, t.full_name AS trainer_name, t.specialization,
       t.is_active AS trainer_active, s.start_time, s.end_time, s.location,
       EXISTS (SELECT 1 FROM public.bookings b
               WHERE b.session_id = s.session_id AND b.status <> 'Cancelled') AS is_booked
FROM public.sessions s
JOIN public.trainers t ON t.trainer_id = s.trainer_id;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'gym_app') THEN
        GRANT SELECT ON public.db_translations, public.sessions_overview TO gym_app;
        GRANT EXECUTE ON FUNCTION public.tr(text, text, text) TO gym_app;
    END IF;
END $$;

COMMIT;

-- Example for the interface (language 'kk' | 'ru' | 'en'):
--   SELECT session_id, trainer_name, start_time, end_time,
--          tr('location', location, 'kk') AS location_name, is_booked
--   FROM sessions_overview WHERE start_time > now() AND trainer_active ORDER BY start_time;
