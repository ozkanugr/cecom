# Kickoff details (Branch A)

Read this when running a new-project kickoff.

## Tiers

Offer all four with one line each and recommend one based on what the repo shows.

| Tier | Meaning |
|---|---|
| T0 | Prototype / script — no real users, no personal data |
| T1 | Internal tool — small known user group |
| T2 | Production product — real users and data |
| T3 | Regulated or multi-tenant — legal, financial, health, or cross-customer risk |

A T0 project that gains real users or personal data must be re-tiered (manifesto §A2).

## Where to look before asking

Answer from the repo whatever it can tell you, so the user only gets the questions it cannot:

| Signal | Files |
|---|---|
| Stack, commands | `package.json` scripts, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Makefile`, `justfile` |
| Test runner, lint, typecheck | config files (`vitest.config.*`, `jest.config.*`, `pytest.ini`, `ruff.toml`, `tsconfig.json`, `.eslintrc*`) |
| CI | `.github/workflows/`, `.gitlab-ci.yml` |
| External services | dependencies (Stripe, OpenAI/Anthropic SDKs, S3, SendGrid, Auth0/Clerk/Supabase…) and `.env.example` names |
| Existing decisions | `docs/adr/`, `docs/`, existing `CLAUDE.md` |

Never open `.env` files to answer questions; `.env.example` is fine.

## Kickoff questions

T0/T1: questions 1–5. T2/T3: all 12. Ask in batches of up to 4 (one AskUserQuestion call). "Don't know / later" is a valid answer: record it as an open TODO instead of blocking.

| # | Question | Recorded in |
|---|---|---|
| 1 | What does the product do, for whom? | `CLAUDE.md` |
| 2 | Stack and commands (install, dev, test, lint, typecheck, build)? | `CLAUDE.md` |
| 3 | Personal data processed? Which categories? Special categories? | ADR: data & privacy |
| 4 | External services (payments, AI, email, storage, auth)? | ADR: external adapters |
| 5 | Where are secrets stored? | ADR: stack |
| 6 | Single- or multi-tenant? Role/permission model? | ADR: auth & tenancy |
| 7 | Languages, regions, currencies, RTL? | ADR: i18n |
| 8 | 12-month numeric scale target? | ADR: stack |
| 9 | Performance budgets? | `CLAUDE.md` |
| 10 | Data residency and retention periods? | ADR: data & privacy |
| 11 | RPO / RTO? | ADR: backup & DR |
| 12 | Domain entities with state machines? | ADR: domain model |

## Writing ADRs

- Template: `assets/templates/adr-template.md`.
- Location: `docs/adr/NNNN-short-title.md`. Number after the highest existing number; never reuse or overwrite a number.
- Group answers by the "Recorded in" column: one ADR per topic (stack, auth & tenancy, data & privacy, i18n, external adapters, backup & DR, domain model).
- Write only what the answers support. An ADR full of guesses is worse than an open TODO.
- Status: `Accepted` for decisions the user made, `Proposed` for your recommendations.
- Accepted ADRs are not edited to change a decision; write a new ADR that supersedes it.

## Filling the project CLAUDE.md

- Edit only outside the `engineering-manifesto` managed block.
- Replace `TODO` placeholders you can now answer; leave the others.
- Insert lines and sections; do not rewrite, reorder, or delete existing lines unless the user asks.
- Keep the file under ~150 lines. It loads every session, so every line costs attention. Link to `docs/` and ADRs for detail instead of copying it in.
