# Audit method

Read this before collecting evidence. Subagents get this file verbatim.

## Principles

1. **Don't assume — inspect.** A check's status comes from code you opened, commands you ran, or configuration you read. "The code looks clean" is not evidence.
2. **Every status carries evidence.** Cite `file:line` and quote the decisive line(s), or cite the command you ran and its output.
3. **Absence needs a search record.** A claim like "no request has a timeout" or "no secrets are committed" is only as good as the search behind it. List the exact searches in `searched` (e.g. `rg -n "timeout" src/`). If you can't search thoroughly enough to be confident, the status is `UNCERTAIN`.
4. **Runtime behavior is not static evidence.** Many lifecycle, memory and UI checks depend on what happens on a device. Static evidence is the code path that handles the scenario (e.g. an `onSaveInstanceState` that persists the draft). If correctness can only be shown by running the app, mark `UNCERTAIN` and name, in `finding`, the runtime scenario that would settle it; it feeds the test plan.
5. **Platform defaults count only when cited.** "React Query retries 3 times by default" is evidence only together with the version in the lockfile and the config line that leaves the default in place.
6. **Audit first, fix later.** Don't change code while auditing. Fixes alter the evidence for other checks, and a mixed audit-and-fix diff can't be reviewed.

## Statuses

| Status | Meaning | Required fields |
|---|---|---|
| `PASS` | The scenario is handled correctly, shown by evidence | `evidence` (≥1) or, for absence-based passes (e.g. "no plaintext tokens"), `searched` (≥1) |
| `FAIL` | The scenario is mishandled or unhandled | `severity`, `evidence` with ≥1 `file` entry, `finding` |
| `UNCERTAIN` | Can't be determined from the repo (runtime-only, config outside the repo, too large to search fully) | `severity` (what it would be if it failed), `finding` (what is unknown and how to settle it) |
| `NOT_APPLICABLE` | The check doesn't apply to this project | `reason` (e.g. "no push notifications: no messaging SDK in package.json") |

Never use `PASS` to mean "probably fine". That is `UNCERTAIN`.

## Severity

Severity is the impact **if the check fails**. Each check has a default; raise or lower it when the project's context justifies it, and say why in `finding`.

| Level | Meaning | Examples |
|---|---|---|
| `P0` | Blocks release. Security breach, data loss or corruption, money errors, cross-user data exposure, crash on a core path for most users | IDOR, secret in client bundle, duplicate charges, open database rules, dev API in production |
| `P1` | Must fix soon. Crash or broken core flow in a common edge case, privacy leak, missing timeout on a critical call | Logout leaves the previous user's cache, unbounded retries, token-refresh stampede |
| `P2` | Should fix. Degraded experience in a plausible case, weak observability, maintainability risk | No virtualization on a long list, no request cancellation |
| `P3` | Polish | Pluralization, dark-mode glitch |

Release verdict (computed by `scripts/render_report.py`):
- **BLOCKED** — any `FAIL` at P0.
- **AT RISK** — any `FAIL` at P1, or any `UNCERTAIN` at P0.
- **READY WITH CAVEATS** — otherwise; remaining findings and uncertainties are listed.

## Scope tags

Each check lists where it applies. The project profile (from `scripts/detect_profile.sh`, confirmed with the user) decides which checks run. Checks whose scope doesn't match are recorded as `NOT_APPLICABLE` with reason `profile`.

| Tag | Applies when the project has |
|---|---|
| `all` | anything |
| `client` | a mobile or web front end |
| `mobile` | iOS, Android, React Native, Flutter, or another native app |
| `web` | a browser front end |
| `api` | a server, API, serverless functions, or BaaS rules (Supabase, Firebase) |
| `db` | a database, local or server |
| `push` | push notifications |
| `pay` | payments, purchases, or subscriptions |
| `llm` | calls to an LLM provider |

## Finding format (JSON Lines)

One JSON object per line, one line per check. `scripts/render_report.py` validates this shape.

```json
{"id": "NET-002", "check": "Every request has an explicit timeout", "status": "FAIL", "severity": "P1",
 "evidence": [{"file": "src/api/client.ts", "line": 12, "note": "axios.create({ baseURL }) — no timeout set"}],
 "searched": ["rg -n \"timeout\" src/"],
 "finding": "The shared axios instance has no timeout; requests can hang until the OS gives up.",
 "fix": {"status": "proposed", "summary": "Set timeout: 15000 on the shared instance; override for uploads.", "files": ["src/api/client.ts:12"]},
 "test": ""}
```

(Shown wrapped for readability; in the file each finding is a single line.)

| Field | Type | Notes |
|---|---|---|
| `id` | string | Check ID from the check file, e.g. `NET-002` |
| `check` | string | The check text (short form is fine) |
| `status` | `PASS` \| `FAIL` \| `UNCERTAIN` \| `NOT_APPLICABLE` | |
| `severity` | `P0`–`P3` | Required for FAIL and UNCERTAIN |
| `evidence` | list | Items are `{"file", "line"?, "note"}` or `{"cmd", "note"}` |
| `searched` | list of strings | Exact search commands run |
| `finding` | string | What is wrong or unknown, in one or two sentences |
| `reason` | string | Required for NOT_APPLICABLE |
| `fix` | object | `{"status": "none" \| "proposed" \| "fixed", "summary", "files"}` |
| `test` | string | Required when `fix.status` is `fixed`: the test added or the command run |

## Searching efficiently

- Prefer `rg` over `grep -r`; exclude `node_modules`, `build`, `dist`, `.git`, `Pods`, and generated code.
- Start from the entry points: API client, router, auth module, DB layer, app/scene delegate, root component. Most checks in an area are answered by the same three or four files.
- Each check file's "Look at" column gives starting points and search terms. They are hints, not limits.
- Read enough surrounding code to be sure: a `timeout` at one call site doesn't make NET-002 pass if the shared client has none.

## Fix policy (Branch C only)

- Fix in severity order: P0, then P1, then whatever the user picks.
- One finding per change; smallest safe change; follow existing patterns.
- Changes that cross the engineering manifesto's agent boundaries (auth/authz, DB schema, dependencies, CI, production configuration, deleting data or tests) need the user's approval first.
- Add or update a test that would have caught the failure where the project has a test setup; otherwise describe the manual check in `test`.
- After a fix, re-run the check: set `fix.status` to `fixed`, and change `status` to `PASS` only with new evidence.
- Don't "fix" `UNCERTAIN` findings; investigate them until they become PASS or FAIL.

## Subagent brief (Branch A step 3)

```
You are auditing <repo path> for production readiness. Area(s): <area names>.
Project profile: <tags>. Tier: <T0–T3>.
Read references/method.md and the check files for your area(s): <paths>.
For every check in those files: if its scope doesn't match the profile, write NOT_APPLICABLE with
reason "profile"; otherwise collect evidence and write exactly one finding.
Do not modify any project file. Write findings as JSON Lines to <scratch path>/findings-<area>.jsonl.
Return: the file path, counts by status, and the IDs of FAIL and UNCERTAIN findings at P0/P1.
```
