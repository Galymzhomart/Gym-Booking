-- gym_app_audit.sql: final check of the role gym_app. Run as postgres on the test database.
-- Run each SELECT separately (select it, press F5) and take a screenshot of each result.

-- A25a. Role attributes. Expected: f, f, f, f, f, t
SELECT rolsuper, rolcreatedb, rolcreaterole, rolreplication, rolbypassrls, rolcanlogin
FROM pg_roles WHERE rolname = 'gym_app';

-- A25b. Membership in other roles. Expected: 0 rows
SELECT g.rolname AS member_of
FROM pg_auth_members m
JOIN pg_roles g ON g.oid = m.roleid
JOIN pg_roles u ON u.oid = m.member
WHERE u.rolname = 'gym_app';

-- A26a. Table privileges. Expected:
--   app_sessions  t t t t
--   app_users     f f f f
--   bookings      t t f f
--   members, sessions, trainers  t f f f
SELECT c.relname,
       has_table_privilege('gym_app', c.oid, 'SELECT') AS can_select,
       has_table_privilege('gym_app', c.oid, 'INSERT') AS can_insert,
       has_table_privilege('gym_app', c.oid, 'UPDATE') AS can_update,
       has_table_privilege('gym_app', c.oid, 'DELETE') AS can_delete
FROM pg_class c
WHERE c.relnamespace = 'public'::regnamespace AND c.relkind = 'r'
ORDER BY c.relname;

-- A26b. Columns of bookings that gym_app may UPDATE. Expected: status only
SELECT attname FROM pg_attribute
WHERE attrelid = 'public.bookings'::regclass AND attnum > 0 AND NOT attisdropped
  AND has_column_privilege('gym_app', 'public.bookings', attname, 'UPDATE');

-- A27a. Sequence and login function. Expected: t, t
SELECT has_sequence_privilege('gym_app', 'booking_id_seq', 'USAGE') AS seq_usage,
       has_function_privilege('gym_app', 'app_login(text,text)', 'EXECUTE') AS login_exec;

-- A27b. Database and schema. Expected: CONNECT t, CREATE f, schema USAGE t, schema CREATE f
SELECT has_database_privilege('gym_app', current_database(), 'CONNECT') AS db_connect,
       has_database_privilege('gym_app', current_database(), 'CREATE')  AS db_create,
       has_schema_privilege('gym_app', 'public', 'USAGE')  AS schema_usage,
       has_schema_privilege('gym_app', 'public', 'CREATE') AS schema_create;
