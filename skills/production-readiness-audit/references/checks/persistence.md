# Persistence & migration (DATA)

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| DATA-001 | Multi-step writes that must succeed together run in one transaction | services writing several tables/documents | P1 | db |
| DATA-002 | No network calls or long work inside database transactions (holds locks; partial external effects on rollback) | code between `BEGIN`/`transaction(` and commit | P1 | db |
| DATA-003 | Rollback is guaranteed on exceptions (transaction helpers, `try/finally`, context managers) — no manual begin/commit with early returns | transaction usage | P1 | db |
| DATA-004 | Uniqueness is enforced by database constraints, not only by application checks | schema: `UNIQUE`, unique indexes vs `findFirst` before insert | P1 | db |
| DATA-005 | Foreign keys and delete behavior (cascade/restrict/set null) are defined; no orphan records; soft-delete filters applied everywhere they should be | schema, `deleted_at` usage | P2 | db |
| DATA-006 | Migrations are ordered, versioned and never edited after being applied; schema version is bumped consistently | `migrations/` history, local DB version numbers | P1 | db |
| DATA-007 | Migrations were tested against realistic existing data (volume and messy values), not only an empty database | migration tests, staging process | P1 | db |
| DATA-008 | An interrupted migration can be recovered (transactional DDL, idempotent steps, resumable backfills) | migration scripts | P1 | db |
| DATA-009 | Breaking schema changes use expand/contract so the old app/server version keeps working during rollout | rename/drop columns in migrations | P1 | api, db |
| DATA-010 | Local DB: upgrade from every shipped schema version works (Core Data/SwiftData/Room/SQLite migrations); downgrade is either supported or explicitly guarded | local migration code | P1 | mobile |
| DATA-011 | Local DB: corruption or a failed migration is detected and recovered (rebuild from server, reset with user data preserved where possible) instead of crash-looping | DB open error handling | P2 | mobile |
| DATA-012 | First run with an empty database works (no assumptions of seed data) | init code, queries assuming rows | P2 | db |
| DATA-013 | Server backups exist, are encrypted, kept off the primary, and a restore has actually been tested | backup config, runbook | P1 | api, db |
| DATA-014 | The storage type fits the data: no large or growing data in `UserDefaults`, `SharedPreferences`, `localStorage`, `AsyncStorage` | key-value store usage | P2 | client |
