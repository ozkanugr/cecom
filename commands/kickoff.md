---
description: Start or set up a project with the Engineering Manifesto — choose the tier, answer kickoff questions, write ADRs, and add the managed CLAUDE.md block and permission rules without overwriting anything.
argument-hint: "[project-dir] [--tier T0|T1|T2|T3] [--apply-only]"
---

Use the `engineering-manifesto` skill, scoped to: $ARGUMENTS

If no directory is given, use the current working directory.

- Default: run Branch A (Kickoff) — inspect the repo, confirm the tier, ask the remaining kickoff questions, install, write ADRs, fill the project CLAUDE.md, verify, report.
- If `--tier` is given: treat that tier as confirmed and skip the tier question.
- If `--apply-only` is given: run Branch B (Apply to an existing project) instead — dry-run, apply, handle messages, verify, report. No interview and no ADRs.

Always dry-run before writing, and never overwrite existing CLAUDE.md content, settings, or ADRs.
