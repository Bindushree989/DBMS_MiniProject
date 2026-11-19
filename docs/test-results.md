# Database Test Results

Run: 2026-10-19T05:50:15.637Z  |  Server: 10.11.14-MariaDB-0ubuntu0.24.04.1

**25 / 25 tests passed**

| ID | Test | Result | Evidence |
|---|---|---|---|
| T01 | Full lifecycle FOUND→REGISTERED→CLAIMED→VERIFIED→HANDED_OVER→RETURNED | PASS | custody chain = FOUND_BY_FINDER → ACCEPTED_BY_STAFF → HANDED_TO_OWNER; 7 timeline events |
| T02 | Illegal status jumps are rejected by the trigger (7 cases) | PASS | 7 illegal transitions → B2Y-E012 |
| T03 | RETURNED items are locked against any change | PASS |  |
| T04 | No VERIFIED status without a verified claim; no handover without verification | PASS |  |
| T05 | A claim with a wrong hidden-detail answer can never be verified | PASS |  |
| T06 | Retry answer: max 3 attempts, success flips answer_match | PASS |  |
| T07 | Claim rules: not on FOUND items, finder cannot claim, no duplicate claim | PASS |  |
| T08 | Role enforcement inside the database (user cannot register/review; only admin administers) | PASS |  |
| T09 | Handover only by the current custodian; custody transfer then handover works | PASS |  |
| T10 | Competing claims: verifying one auto-rejects the others; item reopens when all rejected | PASS |  |
| T11 | Fraud flags: MULTIPLE_CLAIMANTS, MANY_CLAIMS, REPEATED_WRONG_ANSWER | PASS | flags: MANY_CLAIMS, REPEATED_WRONG_ANSWER, MULTIPLE_CLAIMANTS |
| T12 | Admin DELETE: only FOUND items deletable, deletion is audited | PASS |  |
| T13 | One active custody holder per item (UNIQUE on generated column) | PASS |  |
| T14 | Custody history & handover records are immutable | PASS |  |
| T15 | CHECK / validation constraints reject bad data (8 cases) | PASS |  |
| T16 | Last active admin cannot be demoted; users cannot be deleted | PASS | guard exercised |
| T17 | Handover is atomic: failure on the LAST write rolls back everything | PASS | 3 writes (handover insert, custody close, custody insert) fully rolled back |
| T18 | Audit log is append-only, hash-chained, and never stores passwords | PASS | 8033 audit rows, chain verified, 0 broken links |
| T19 | Tampering with history (trigger bypassed by a DBA) is DETECTED by the hash chain | PASS | forged row #8028 flagged: "row content does not match its hash" |
| T20 | fn_match_score: weights category/colour/brand/location/time; sp_candidates ranks the right item first | PASS | structured score matching item = 1.0000, unrelated report = 0.4200 |
| T21 | View v_item_public never exposes the verification answer hash | PASS |  |
| T22 | Concurrency: 25 users claim the same item at once → all recorded, one MULTIPLE_CLAIMANTS flag, no deadlock | PASS | 25/25 claims committed, status CLAIMED, 1 flag |
| T23 | Concurrency: 2 staff approve 2 different claims simultaneously → exactly ONE verified | PASS |  |
| T24 | Concurrency: 20 simultaneous handover attempts → exactly one handover, one active custody row | PASS | 1 success, 19 rejected (B2Y-E171: item must be VERIFIED for hand) |
| T25 | Audit chain remains intact after all concurrent activity | PASS | 8123 audit rows verified |
