# Architecture & domain (ARCH, DOMAIN)

Structural problems become production bugs: logic in the wrong layer gets copied and drifts, SDKs spread through the code can't be swapped, mocked or upgraded safely, and status fields without rules end up in impossible states.

## ARCH — structure

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| ARCH-001 | Business rules live in domain/service code — not in UI components, controllers/route handlers, or queries scattered across files | pricing, discount, permission and eligibility logic in components or fat handlers | P2 | all |
| ARCH-002 | Each module has one clear responsibility and a public interface; modules don't import each other's internals | deep relative imports into another module's internals, bypassed index/barrel files | P3 | all |
| ARCH-003 | No circular dependencies between modules or packages | `dependency-cruiser`, `import-linter`, Xcode/Gradle module graph | P2 | all |
| ARCH-004 | Third-party SDKs (payments, analytics, AI, storage, auth, email, push) sit behind an internal interface/adapter instead of being called from many places | SDK imports across the codebase | P2 | all |
| ARCH-005 | Dependencies are injected (constructor/parameters/DI container/environment) and replaceable in tests; business logic doesn't reach databases or networks through hidden singletons | `shared`/static clients used inside domain code | P2 | all |
| ARCH-006 | Dependency direction is respected (UI → application → domain ← infrastructure): domain code imports no UI, HTTP or ORM framework types | imports in domain/service folders | P3 | all |
| ARCH-007 | Variation by provider/platform/plan is resolved in one place (strategy, factory, registry), not by `if provider == …` scattered through the code | conditionals on provider, platform or environment names | P3 | all |
| ARCH-008 | Global mutable state is avoided or has a single owner with defined writers | module-level mutable variables, singletons with public setters | P2 | all |

## DOMAIN — business rules and workflows

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| DOMAIN-001 | Entities with a lifecycle (order, payment, subscription, booking) have explicit states, and invalid transitions are rejected in one place on the server | status fields set straight from requests (`status = body.status`), missing transition guards | P1 | api |
| DOMAIN-002 | Business invariants (stock ≥ 0, one active subscription, one booking per slot) are enforced server-side and, where possible, by database constraints — not only in client code | client-only rule checks, missing constraints | P1 | api, db |
| DOMAIN-003 | Multi-step workflows (checkout, onboarding, provisioning, imports) persist their progress, resume after a crash, and compensate completed steps when a later step fails (saga), with idempotent steps | orchestration code, job chains calling external services | P1 | api |
| DOMAIN-004 | Long-running workflows have timeouts and a visible stuck/failed state, so items can't wait forever in `processing`/`pending` | status values without expiry or reconciliation jobs | P2 | api |
| DOMAIN-005 | A domain concept has one name across client, server and database (no `customer`/`client`/`user` drift for the same thing) | model names, API fields, table names | P3 | all |
