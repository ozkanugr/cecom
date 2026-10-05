# Manifesto section map (Branch C)

`references/manifesto.md` is ~1,300 lines. Do not read it whole. Find the section heading, then read only that section (it runs to the next `---` line):

```bash
grep -n '^## 17\.' references/manifesto.md      # numbered sections
grep -n '^## A[0-9]\|^### A3.1' references/manifesto.md   # Part A
grep -n '^## Appendix' references/manifesto.md
```

Then use Read with `offset` = the matched line and a `limit` of about 60.

| Topic | Sections |
|---|---|
| Tiers, requirement levels, conflict rules, additive install | Part A (A1–A4, A3.1) |
| Non-negotiables (constitution) | Part B — same text as `references/constitution.md` |
| Architecture, SOLID, patterns, modularity, abstraction | §3–§8 |
| Domain logic, state machines, workflows/sagas | §9 |
| Database, migrations (expand/contract) | §10 |
| Data lifecycle, KVKK/GDPR | §11–§12 |
| i18n, accessibility | §13–§14 |
| Security baselines (OWASP ASVS/MASVS), cryptography, secrets, authN/authZ, multi-tenancy | §15–§17 |
| Scale, performance and resource limits, reliability, idempotency | §18–§21 |
| External services, API design, errors | §22–§24 |
| Observability, logging | §25, §31 |
| Testing, CI, compatibility, versioning | §26–§30 |
| ADRs, dependencies, refactoring, change impact | §33–§36 |
| Feature flags, concurrency, backups | §37–§39 |
| Agent governance, boundaries, DoD, verification | §40–§44, §46 |
| AI-specific risks, stop conditions | §47–§48 |
| Git, environments, supply chain, threat modeling | §49–§52 |
| Cost, budgets, kickoff, enforcement map | §53–§56 |
| Which sections apply at which tier | Appendix 1 |

Apply a section at the project's tier (Appendix 1). Cite the section number when it drives a recommendation, so the user can check it.
