# Independent test report v1

Islam Temirlan | Gym Booking System | 10 November 2026

## Current result

**0 Pass, 0 Fail, 20 Not run** for the new acceptance scenarios. This means no new acceptance scenario has yet completed independent execution; it does not mean the application has passed.

The test table is complete and follows the required distribution of 4 / 5 / 5 / 3 / 3. The earlier November 4 results are a separate version and have not been carried forward.

## Received and checked

`Ruslan_2FA_v1.zip` was found locally and inspected. Its SHA256 is recorded in `evidence/source-hash.json`. Ruslan reports passing checks in his own environment; these remain author-reported results, not Temirlan's independently reproduced results.

Independent preparatory checks were performed on `server.js`, `twofa_routes.js`, `public/app.js` and `public/twofa_ui.js`: all four passed `node --check`. See `evidence/static-syntax.json`. Syntax validation is supplementary and is not counted among the 20 functional tests.

An isolated local test environment was prepared using a working copy of the earlier application plus Ruslan's supplied files. Attempts to connect to PostgreSQL at 127.0.0.1:55439 timed out. Database cloning, the new migration and functional 2FA checks could not be completed. The actual failed connection output is saved in `evidence/connection-attempt.txt`. This is an environment blocker, not a confirmed defect in Ruslan's code.

## Dependencies and remaining work

- N01–N04: restore a working isolated PostgreSQL connection, apply 2FA SQL and locally enrol test accounts; then execute actual API/browser checks.
- N05–N09: obtain Yernur's three-language interface and Galymzhomart's server language integration, including the agreed language transport. No new language build was available in the inspected delivery folders.
- N10–N17: obtain the integrated interface/server and current demo fixtures. Do not substitute the old application for the November acceptance build.
- N18–N20: obtain Shokan's new backup, extended seed, four demo fixture IDs, source snapshot and restoration instructions.

No final integrated version or commit has been supplied. The source hash identifies only the received 2FA component. The final report must identify the integrated build actually tested.

No new functional defect has been confirmed in this cycle. The earlier D01/D02 have not been retested against the new integrated version and are not assumed fixed or still present. Their earlier records remain preserved in the November 4 package.

## Next handoff

Execute available checks as soon as the environment and versions are ready. Send received-version results by 11 November, 10:00, then rerun all 20 after integration. Preserve initial failures and separate retest evidence. Team messages have not been sent from this chat.

AI assistance: Codex prepared the scenario table and report, inspected the received files, ran syntax checks and attempted local environment setup. Functional results are left Not run where execution has not occurred.
