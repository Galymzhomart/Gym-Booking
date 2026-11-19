-- backup_restore_check.sql  (Shokan) -- "fingerprint" of a database. Run the SAME file on the SOURCE
-- database and on the RESTORED database (pgAdmin Query Tool, run all with F5). The two result tables
-- must be identical. If a row differs, the restore lost something.
-- It compares: row counts, constraints by type, indexes, triggers, our functions,
-- one booking (number + status) and a checksum (md5) of all bookings and all sessions.
SELECT item, value FROM (
  SELECT 'rows:members'  AS item, count(*)::text AS value FROM public.members
  UNION ALL SELECT 'rows:trainers', count(*)::text FROM public.trainers
  UNION ALL SELECT 'rows:sessions', count(*)::text FROM public.sessions
  UNION ALL SELECT 'rows:bookings', count(*)::text FROM public.bookings
  UNION ALL SELECT 'constraints:' || contype::text, count(*)::text
            FROM pg_constraint WHERE connamespace = 'public'::regnamespace AND contype <> 'n' GROUP BY contype
  UNION ALL SELECT 'indexes', count(*)::text FROM pg_indexes WHERE schemaname = 'public'
  UNION ALL SELECT 'trigger:' || tgname, tgenabled::text FROM pg_trigger WHERE NOT tgisinternal
  UNION ALL SELECT 'function:' || proname, 'defined' FROM pg_proc p WHERE pronamespace = 'public'::regnamespace
            AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')   -- only our functions, not extension ones
  UNION ALL SELECT 'booking:' || booking_id, member_id || ' | ' || session_id || ' | ' || status
            FROM public.bookings WHERE booking_id = 'B-1002'
  UNION ALL SELECT 'md5:bookings', md5(string_agg(booking_id || member_id || session_id || status || created_at::text, ',' ORDER BY booking_id)) FROM public.bookings
  UNION ALL SELECT 'md5:sessions', md5(string_agg(session_id || trainer_id || start_time::text || end_time::text || location, ',' ORDER BY session_id)) FROM public.sessions
) q ORDER BY item;
