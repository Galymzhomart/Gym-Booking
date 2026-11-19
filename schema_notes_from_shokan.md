# schema_notes.md — Gym Booking System (PostgreSQL 18)
Author: Shokan (Data & Database). Table and column names are unchanged from Task 9.

## Tables
| Table | Columns |
|---|---|
| members | member_id (PK, varchar20), full_name, membership_status (Active/Expired/Suspended), membership_expiry (date) |
| trainers | trainer_id (PK), full_name, specialization, is_active (bool, default true) |
| sessions | session_id (PK), trainer_id (FK), start_time, end_time (timestamptz, end > start), location |
| bookings | booking_id (PK; default `'B-' \|\| nextval('booking_id_seq')`, starts at B-2001), member_id (FK), session_id (FK), status (Confirmed/Cancelled/Attended/No-show, default Confirmed), created_at |
| app_users | user_id (PK), username (unique, lower-case), password_hash (bcrypt), role (Member/Reception), member_id (FK; required for Member, NULL for Reception), is_active |

## Rules and the error you get (SQLSTATE P0001 unless stated)
| Rule | Where | Error text |
|---|---|---|
| One non-cancelled booking per session | unique index `one_non_cancelled_booking_per_session` | `duplicate key value violates unique constraint "one_non_cancelled_booking_per_session"` (23505) |
| Trainer sessions cannot overlap | exclusion constraint `no_trainer_time_overlap` | `conflicting key value violates exclusion constraint` (23P01) |
| Member exists / session exists | `validate_booking` | `Member does not exist` / `Session does not exist` |
| Membership Active | `validate_booking` | `Membership must be active` |
| Membership valid on the session date (Asia/Almaty) | `validate_booking` | `Membership expires before the session date` |
| Session in the future | `validate_booking` | `Cannot book a session in the past` |
| Trainer active | `check_trainer_active` | `Trainer is not active` |
| No overlapping non-cancelled booking of the member; adjacent OK | `check_member_overlap` (advisory lock per member) | `Member already has a booking that overlaps in time` |
| Status transitions: only from Confirmed | `check_status_transition` | `Status transition X -> Y is not allowed` |
| Cancel only before start | `check_status_transition` | `Cannot cancel: the session has already started` |
| Attended / No-show only after end | `check_status_transition` | `Cannot set Attended: the session has not ended yet` |
| New booking only as Confirmed or Cancelled | `check_booking_lifecycle` | `New booking cannot be created as X (use Confirmed, then change status)` |
| Closed booking cannot be moved to another member/session | `check_booking_lifecycle` | `Booking history cannot be changed (status X)` |
| Role has no right | PostgreSQL | `permission denied ...` (42501) |

Cancel = `UPDATE bookings SET status='Cancelled' WHERE booking_id=$1` (row stays). Re-booking = a new INSERT with a new booking_id.
All trigger functions are SECURITY DEFINER with `search_path = public, pg_catalog`, which is why the limited role `gym_app` can INSERT.

## Login for the server
`SELECT * FROM app_login($1, $2);` -> one row `(user_id, role, member_id)` or no rows (wrong login/password). `gym_app` calls this function and cannot read `app_users`.
Member vs Reception and "own booking only" are NOT database rules: the server must check them using the `role` / `member_id` returned by `app_login`.
