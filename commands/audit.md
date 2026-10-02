---
description: Production-readiness audit with file:line evidence — full, by area, or for a diff; then fix findings one by one, or re-audit and compare.
argument-hint: "[project-dir] [--areas a,b] [--diff <base>] [--fix ID,ID|P0|P1] [--previous <findings.jsonl>]"
---

Use the `production-readiness-audit` skill, scoped to: $ARGUMENTS

If no directory is given, use the current working directory.

- No options: Branch A (full audit) — confirm the profile, plan, collect evidence, verify P0/P1 findings yourself, render the report, summarize.
- `--areas a,b`: Branch B, limited to those check areas (check file names, e.g. `network,auth`).
- `--diff <base>`: Branch B, limited to files changed since `<base>` and their direct callers.
- `--fix ID,ID` (or `--fix P0` / `--fix P1`): Branch C on the latest findings file in `docs/audits/`; one finding at a time, with tests.
- `--previous <findings.jsonl>`: Branch D — re-audit and include the comparison with that earlier audit.

Never change project code during an audit, never overwrite an existing report, and never mark a check PASS without evidence.
