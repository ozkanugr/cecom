# {{PROJECT_NAME}}
Tier: {{TIER}}
Product: TODO — one sentence: what it does, for whom.

Engineering rules: Engineering Manifesto v1.1 (`{{MANIFESTO}}`). Run the kickoff in manifesto §55 before the first feature.

## Commands
install: TODO
dev: TODO
test: TODO          (single test: TODO)
lint: TODO
typecheck: TODO
build: TODO

## Architecture map
TODO — layers and dependency direction, e.g.
src/domain/   business rules, no framework imports
src/app/      use cases
src/infra/    database, external service adapters
src/web/      UI / HTTP
Dependency direction: web → app → domain ← infra

## Decisions (docs/adr/)
TODO — list ADRs as they are written (001 Stack · 002 Auth & tenancy · 003 Data & privacy · …)

## Conventions
TODO — naming, error format, log fields, i18n key format, test file location

## Budgets
TODO for T2+ — see manifesto §54

## Gotchas
TODO — project-specific traps ("do not touch X because…")
