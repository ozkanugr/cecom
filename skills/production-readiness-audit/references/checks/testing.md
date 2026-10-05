# Testing (TEST, TQ)

Two questions: are the risky scenarios covered (TEST), and do the existing tests actually prove anything (TQ)?

## TEST — scenario matrix

For each scenario, record `PASS` when an automated test covers it (cite the test), `UNCERTAIN` when only manual verification is possible or documented, and `FAIL` when the scenario is untested on a path where it matters. In `finding`, name the related checks.

| ID | Scenario | Related checks | Sev | Scope |
|---|---|---|---|---|
| TEST-001 | Fresh install | REL-007 | P1 | client |
| TEST-002 | Upgrade from the previous released version with real data | REL-008, DATA-010, LIFE-010 | P0 | client |
| TEST-003 | Logout, login, and switching accounts | AUTH-010, AUTH-011, PUSH-004 | P1 | client |
| TEST-004 | Offline, slow network, and recovery when the network returns | NET-001, NET-012, NET-013, NET-014 | P1 | client |
| TEST-005 | Background/foreground and process killed by the OS | LIFE-001, LIFE-002 | P1 | mobile |
| TEST-006 | Low memory | LIFE-002, PERF-001 | P2 | mobile |
| TEST-007 | Rotation/resize and keyboard shown | LIFE-004, UI-004 | P2 | client |
| TEST-008 | Permission denied, and granted later | PUSH-005, PUSH-006, PRIV-012 | P2 | mobile |
| TEST-009 | Expired, invalid, and revoked tokens | AUTH-007, AUTH-009, NET-008 | P1 | client |
| TEST-010 | Duplicate request / double tap / webhook replay | CONC-001, IDEM-001…IDEM-005 | P0 | all |
| TEST-011 | Server responses 401, 403, 404, 429, 500, timeout | NET-006…NET-010, ERR-006 | P1 | client |
| TEST-012 | Corrupt cache or local database | LIFE-009, DATA-011 | P2 | client |
| TEST-013 | Contract drift: missing field, `null` field, unknown enum value, extra field | CONTRACT-002, CONTRACT-005, CONTRACT-006, CONTRACT-008 | P1 | client |
| TEST-014 | Old and new schema versions (API and local storage) | CONTRACT-007, CONTRACT-012, DATA-009 | P1 | all |
| TEST-015 | Concurrent writes to the same record/balance | CONC-008, CONC-009, CONC-011 | P0 | api |
| TEST-016 | Authorization: user A requests user B's resources (expect 403/404) | AUTH-001, AUTH-002 | P0 | api |
| TEST-017 | Turkish locale (`tr-TR`) and an RTL locale | I18N-001, I18N-010, I18N-011 | P2 | all |
| TEST-018 | Timezone and DST changes; device clock set wrong | TIME-001…TIME-005 | P2 | all |
| TEST-019 | Deep link and notification tap on cold start and when logged out | LIFE-005, LINK-006, LINK-007 | P1 | client |
| TEST-020 | Payments: success, failure, cancellation, retry, restore | IDEM-001, IDEM-002, SEC-018 | P0 | pay |

## TQ — test quality

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| TQ-001 | Critical flows (auth, payments, data writes) have automated tests | test directories vs critical modules | P1 | all |
| TQ-002 | Tests assert behavior; no tests without assertions, snapshot-only coverage of logic, or assertions only on mocks | test bodies | P2 | all |
| TQ-003 | No committed `.only`, `.skip`, `xit`, `@Disabled`, `@pytest.mark.skip` hiding failures without a tracked reason | `rg -n "\.only\(\|\.skip\(\|xit\(\|@Disabled\|mark\.skip"` | P1 | all |
| TQ-004 | Mocks don't replace the unit under test, and tests don't special-case production code (`if (process.env.NODE_ENV === "test")` in business logic) | test doubles, env checks in src | P1 | all |
| TQ-005 | Tests run in CI and the suite passes now (run it; report the real output) | CI config; run the test command | P1 | all |
| TQ-006 | Tests are deterministic: no real network, real time, or ordering dependence without control | `sleep`, `Date.now()`, live URLs in tests | P2 | all |
| TQ-007 | Integration tests exercise real dependencies where it matters (database via Testcontainers or a test instance, the real HTTP layer), not only mocks | integration test setup | P1 | api, db |
| TQ-008 | Critical user journeys (sign up, sign in, core action, payment) have end-to-end tests (Playwright, Cypress, XCUITest, Espresso, Maestro, Detox) that run in CI or before every release | e2e directories, CI jobs | P1 | client |
| TQ-009 | Bug fixes come with a regression test that fails without the fix | recent `fix:` commits vs their test changes (`git log --stat`) | P2 | all |
