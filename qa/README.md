# Temirlan 20 Tests v1

Owner: Islam Temirlan, Testing, Analytics & Integration.
Prepared: 10 November 2026, Kazakhstan time (UTC+05:00).

This is the first test-plan handoff for the new 2FA, language and backup requirements. It is not acceptance of the integrated application.

## Contents

- `test_results.csv`: exactly 20 scenarios, with inputs, steps, expected/actual results, status, evidence, date and build reference.
- `report.md`: current independent results and limitations.
- `evidence/`: actual connection-attempt output, JavaScript syntax-check results and source archive hash.

Distribution: 4 login/2FA, 5 languages, 5 interface/booking, 3 rules/permissions, 3 backup/restore. Subcases belong to the listed scenario; Pass requires every stated subcase to pass. These N01–N20 identifiers are a new cycle and do not replace the earlier T01–T19 records.

## How to execute

1. Obtain the integrated build and its commit or immutable archive hash, final SQL order, demo account mapping and four demonstration fixture IDs. Save them in the run manifest before testing.
2. Use an isolated test database and the documented SQL order. Confirm the actual schema, version and grants. Obtain the new extended seed and backup from Shokan; do not treat the earlier seed as current.
3. Enrol locally according to Ruslan's instructions. Do not include passwords, TOTP secrets, QR setup images, one-time codes, cookies, `.env` or unredacted technical session rows in evidence. Do not copy a locally enrolled database into the submission archive.
4. Run N01–N04 for Member and Reception. API tests must use real two-step sessions. A generated local TOTP may support an API test but does not prove a phone-authenticator or browser workflow.
5. Run N05–N14 through the stated UI/API routes. N09 must reproduce the same error in kk, ru and en using the team's agreed language transport; a translation dictionary alone is not execution evidence.
6. Run N15–N17 with independent fixtures so one failed rule does not mask another. Capture business rows before/after each rejected request.
7. Run N18–N20 using the supplied sanitized backup and a new empty restoration target. Compare with a snapshot taken at backup time, not a database that has subsequently changed. Verify effective permissions, including PUBLIC/inherited grants. Check that TOTP secret rows are absent before local re-enrolment.
8. Save one evidence set per test/run. Preserve failures and their original version. Add retests to a separate run file with the same 20 scenario IDs rather than adding extra scenarios to this table.

## Handoff schedule

- v1: 10 November, 20:00–21:00.
- Results on received versions: 11 November, before 10:00.
- After Galymzhomart's integration on 11 November: rerun all 20, report defects, retest changes and record the final commit. Deliver `Temirlan_20_Tests_final.zip`.
- Defence: 12 November.

All times are Kazakhstan time. These are team deadlines, not claims of completed future runs.
