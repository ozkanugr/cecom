---
name: production-readiness-audit
description: Evidence-based production-readiness audit for AI-generated / vibe-coded apps (mobile, web, backend). Runs ~330 concrete checks across architecture/domain, contracts, text/time/money, lifecycle, networking/offline, concurrency/idempotency, performance, scalability, auth, security/supply chain (OWASP-mapped), privacy/KVKK, persistence/migrations, push/deep links, errors/observability, config/release, UI/accessibility, testing, AI-generated code smells and LLM features. Every check ends PASS, FAIL, UNCERTAIN or NOT_APPLICABLE with file:line evidence; failures are then fixed one by one with approval. Use this whenever the user asks to audit, review, harden or bug-hunt an app before release, asks whether code is production ready, wants an edge-case / "what could break" / pre-launch / control-list review of a codebase, or asks about a single risk area across the codebase (offline handling, race conditions, double submits, token refresh, migrations, secrets) — even if they don't say "audit".
---

# Production readiness audit

Pick the branch, run its steps in order, then run **Verify**. `SKILL_DIR` is the directory containing this file. The scripts locate their own data, so they can be run from anywhere.

| Branch | When | Outcome | Writes to |
|---|---|---|---|
| A. Full audit | "Is this production ready?", pre-release review | Report + findings for every applicable check | `docs/audits/` in the project (or where the user says) |
| B. Scoped audit | Specific areas ("check offline and auth"), specific paths, or a diff/PR | Same, limited to that scope | Same |
| C. Fix findings | After an audit, the user picks findings to fix | Code fixes with tests; findings updated | Project source, findings file |
| D. Re-audit | After fixes, or before the next release | New report with fixed / regressed / still failing | New report next to the old one |

## Rules for every branch

- **Evidence or it didn't happen.** Read `references/method.md` before collecting evidence. Statuses come from files you opened and commands you ran; "looks fine" is `UNCERTAIN`, not `PASS`. An absence claim needs the exact searches in `searched`.
- **Audit and fix are separate passes.** Never change project code during A, B or D. Fixing while auditing changes the evidence for other checks and produces a diff no one can review.
- **Never overwrite.** Reports and findings get a new dated file; `render_report.py` refuses to overwrite an existing report.
- **Never copy secrets into findings.** Cite where a secret is, not its value (at most 4 leading characters); `render_report.py` rejects recognizable keys. A found secret must be rotated — say so. Reports describe weaknesses: suggest the user review them before committing to a public repository.
- **Fixes are current and secure, with a cited source.** Every proposed or applied fix follows the official documentation for the versions in use and current security guidance (OWASP Cheat Sheets, ASVS/MASVS, platform docs) — looked up, not remembered — with no deprecated APIs or outdated algorithms. Cite it in `fix.reference`; `render_report.py` rejects fixes without one.
- **Run project commands only when trusted.** Build/test scripts execute the project's code; for code of unknown origin ask first. Never run anything that deploys, migrates shared data, sends messages, or touches production.
- **Respect the engineering manifesto.** If the project declares `Tier: T0–T3` in `CLAUDE.md`, use it: for T0 suggest a scoped audit (security, config-release, ai-generated); for T2/T3 run the full audit. Fixes that touch auth, DB schema, dependencies, CI or production configuration need the user's approval first.

## A. Full audit

1. **Profile and scope.**
   ```bash
   bash SKILL_DIR/scripts/detect_profile.sh <project-dir>
   ```
   Show the detected tags (`mobile web api db push pay llm`) with their reasons, the tier from `CLAUDE.md` if any, and the output location (default `docs/audits/<YYYY-MM-DD>-production-readiness.md` plus `.jsonl`). Ask the user to confirm or correct the tags — detection is heuristic.
   **Done when:** the user has confirmed the profile tags, and you know the tier (or that none is declared) and the output path.

2. **Plan.**
   ```bash
   python3 SKILL_DIR/scripts/catalog.py plan --profile <tags> --out <scratch>/plan.jsonl
   ```
   The plan has one line per check: `NOT_APPLICABLE` (profile mismatch, already filled in) or `PENDING`. The catalog lives in `references/checks/*.md` (area table below).
   **Done when:** `plan.jsonl` exists and you know how many checks are `PENDING`.

3. **Collect evidence.** Replace every `PENDING` line with a finding in the format from `references/method.md`.
   - Full audits or large projects: one subagent per group of areas, up to 6 in parallel. Give each the "Subagent brief" from `references/method.md`, its check files, the profile, and its own output file `<scratch>/findings-<area>.jsonl`. Merge the files afterwards.
   - Small projects: work through the areas yourself, one check file at a time.
   A planned check may still be `NOT_APPLICABLE` with a concrete reason when the profile was too broad (e.g. "no offline writes: no queue or local mutation store"). That is different from `PASS`.
   **Done when:** every `PENDING` check has exactly one finding with status PASS, FAIL, UNCERTAIN or NOT_APPLICABLE.

4. **Verify the findings yourself.** Subagents can misread code. For every `FAIL` and `UNCERTAIN` at P0/P1, and every `PASS` on a P0 check, open the cited `file:line` and confirm it supports the status; downgrade unsupported claims to `UNCERTAIN`. Run the project's build, typecheck, lint and test commands (they settle AIGEN-003 and TQ-005) and record their real output.
   **Done when:** each P0/P1 finding cites lines you have read in this session, and the command results are recorded.

5. **Render the report.**
   ```bash
   python3 SKILL_DIR/scripts/render_report.py <scratch>/findings.jsonl --plan <scratch>/plan.jsonl \
     --out <project>/docs/audits/<date>-production-readiness.md \
     --project <name> --profile <tags> --tier <tier> --scope "all areas"
   ```
   Copy `findings.jsonl` next to the report under the same name with a `.jsonl` extension, so Branches C and D can use it. If the script exits 2, fix the listed problems in the findings — don't weaken findings just to pass validation — and render again.
   **Done when:** the script exits 0 and prints the verdict.

6. **Present the result** using the chat summary format below, then ask which findings to fix (Branch C). Don't start fixing on your own.
   **Done when:** the user has the summary and the report path.

## B. Scoped audit

Same steps as A, with the scope narrowed in step 2:

- **By area:** `catalog.py plan … --areas network,auth` (area names are the check file names in the table below).
- **By diff or paths:** plan the areas the change touches, then collect evidence only from the changed files and their direct callers and callees:
  ```bash
  git -C <project> diff --name-only <base>...HEAD
  ```
  Leave out checks the changed code doesn't touch (drop whole areas with `--areas`); don't mark them PASS. If you audit only part of a plan, don't pass `--plan` to `render_report.py`.
- Always pass `--scope "<what you audited>"` so the report states what it covers.

**Done when:** the report's Scope line states exactly what was audited.

## C. Fix findings

1. **Choose.** List the open FAILs by severity and let the user choose; the default order is all P0, then P1.
   **Done when:** the user has confirmed which IDs to fix.

2. **Fix one finding at a time** following "Fix policy" in `references/method.md`: before writing, look up the current recommended and secure approach for the versions in use and cite it in `fix.reference`; smallest safe change in the existing style; ask first if it crosses a manifesto boundary (auth/authz, schema, dependencies, CI, production config, deleting data or tests); add or update a test that would have caught it, or describe the manual check.
   **Done when:** the change is made and its test or manual check has been run, with the result recorded.

3. **Update the finding** in the findings file: `fix.status` → `fixed`, `fix.files`, `test`. Re-check the item and set `status` to `PASS` only with new evidence.
   **Done when:** the finding reflects the new code, with new evidence.

4. **Repeat** for the next ID. If the user commits, use one commit per finding, with the check ID in the message.
   **Done when:** every chosen ID is fixed or explicitly deferred by the user.

5. Run Branch D, scoped to the fixed areas, to produce the updated report.

## D. Re-audit

Run Branch A or B again and pass the previous findings file:

```bash
python3 SKILL_DIR/scripts/render_report.py <new findings> --out <new report path> --previous <old findings.jsonl> …
```

The report gains a "Changes since the previous audit" section (fixed, regressed, still failing, new failures).
**Done when:** the new report exists alongside the old one and lists the changes.

## Check areas

| File (`references/checks/`) | Prefixes | Covers |
|---|---|---|
| `architecture.md` | ARCH, DOMAIN | Business-logic placement, module boundaries, SDK adapters, DI, state machines, workflows/sagas |
| `contract.md` | CONTRACT | API/client contracts, nullability, enums, 64-bit IDs, runtime validation, versioning |
| `text-time-money.md` | I18N, TIME, MONEY | Turkish İ/ı and other locale bugs, Unicode, time zones, clocks, money arithmetic |
| `lifecycle.md` | LIFE | Background/foreground, process death, cold start, persisted-state upgrades, multiple tabs |
| `network.md` | NET | Timeouts, bounded retries, backoff, token refresh, cancellation, offline queue, TLS |
| `concurrency.md` | CONC, IDEM | Races, double submit, out-of-order responses, atomic updates, idempotency |
| `performance.md` | PERF | Images, lists, caches, leaks, main-thread work, N+1 queries, indexes, bundle size |
| `auth.md` | AUTH | Object-level authorization, token handling and storage, logout/account switch, deletion |
| `security.md` | SEC, SUPPLY | Client secrets, open DB rules, injection, SSRF, uploads, CORS, webhooks, receipts, password hashing, crypto, audit log, dependencies; OWASP Top 10:2025 / LLM / MASVS mapping |
| `privacy.md` | PRIV | Minimization, PII in analytics and crash logs, consent and privacy notices, KVKK/GDPR records and transfers, deletion/export, SDK disclosures |
| `scalability.md` | SCALE | Stateless servers, queues and dead-letter handling, schedulers, connection pooling, cache invalidation, quotas |
| `persistence.md` | DATA | Transactions, constraints, migrations, local DB upgrades and corruption, backups |
| `entry-points.md` | PUSH, LINK | Push tokens and payloads, deep-link validation and routing |
| `errors-observability.md` | ERR, OBS | Swallowed errors, error UI, crash reporting, correlation ids, alerts |
| `config-release.md` | CONF, REL | Environments, debug flags, default secrets, release builds, upgrades, store rules |
| `ui-accessibility.md` | UI, A11Y | Edge-case layouts and states, screen readers, contrast, touch targets, keyboard |
| `testing.md` | TEST, TQ | Scenario matrix and the quality of existing tests |
| `ai-generated.md` | AIGEN, LLM | Stubs, mock data, silenced checks, tutorial configs; prompt injection, LLM output, cost |

## Verify

1. `render_report.py` exited 0 for the final report, and the `.jsonl` findings file sits next to it.
   **Done when:** both files exist at the reported path.
2. After Branch C, the project's tests (or the manual checks recorded in `test`) were run after the last fix.
   **Done when:** their real output is quoted in the summary.
3. If you changed this skill's scripts or check files, run its checks:
   ```bash
   python3 SKILL_DIR/scripts/catalog.py lint
   python3 -m unittest discover -s SKILL_DIR/scripts/tests
   ```
   **Done when:** lint prints `ok` and the tests end with `OK`.

## Chat summary format

```
Verdict:    BLOCKED | AT RISK | READY WITH CAVEATS   (profile, tier, scope)
Counts:     PASS n · FAIL n (P0 n, P1 n) · UNCERTAIN n · N/A n
Blockers:   ID — one line — file:line        (P0/P1 failures)
To settle:  ID — what would resolve it       (key uncertainties)
Report:     path to the .md and .jsonl
Next:       which findings to fix first
```

## Resources

| Path | Purpose |
|---|---|
| `references/method.md` | Evidence rules, statuses, severity, scope tags, finding schema, fix policy, subagent brief |
| `references/checks/*.md` | The check catalog (18 area files, table above) |
| `scripts/detect_profile.sh` | Detects profile tags from manifests and source (A step 1) |
| `scripts/catalog.py` | Lints the catalog and builds the audit plan (A step 2, Verify) |
| `scripts/render_report.py` | Validates findings and renders the report, optionally compared with a previous audit (A step 5, D) |
| `scripts/tests/test_scripts.py` | Tests for the three scripts (Verify step 3) |
