# cecom — Claude Code plugin

Personal engineering toolkit. Replaces the `context-gardener` plugin (v0.1.0) and bundles three skills in one package.

| Skill | What it does | How to invoke |
|---|---|---|
| **engineering-manifesto** | New-project kickoff (tier T0–T3, kickoff questions, ADRs, project CLAUDE.md, permission rules) and applying the manifesto to existing projects **without overwriting anything**. During design and review, finds and applies the relevant manifesto sections. | `/kickoff`, "we're starting a new project", "apply the manifesto to this project" |
| **production-readiness-audit** | Evidence-based audit of AI-generated / vibe-coded apps: ~290 checks across 16 areas (contracts, locale/time/money, lifecycle, networking, concurrency and idempotency, performance, auth, security, privacy, migrations, push and deep links, errors and observability, config and release, UI and accessibility, testing, AI-generated code and LLM features). Each check is PASS / FAIL / UNCERTAIN / NOT_APPLICABLE with `file:line` evidence; produces a report with a release verdict, then fixes findings one at a time and re-audits. | `/audit`, "is this production ready?", "audit this app before release" |
| **context-gardener** | Keeps CLAUDE.md and project memory files accurate and lean: verifies every claim against the repo, removes duplicate and stale content, splits bloated files. | `/tidy-context`, or Claude offers it on its own |

A SessionStart hook reminds Claude when context files have grown large or haven't been groomed in a while (defaults: 150 lines / 21 days). It never edits anything.

## Layout

```
cecom/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json          For local installation
├── commands/
│   ├── audit.md                  /audit
│   ├── kickoff.md                /kickoff
│   └── tidy-context.md           /tidy-context
├── hooks/
│   ├── hooks.json                SessionStart
│   └── check-staleness.sh        Context file size/age check (works on macOS bash 3.2)
└── skills/
    ├── engineering-manifesto/    SKILL.md, scripts/, references/, assets/
    ├── production-readiness-audit/  SKILL.md, references/method.md, references/checks/, scripts/
    └── context-gardener/         SKILL.md
```

## Requirements

- Claude Code with plugin support
- `bash` (macOS's stock 3.2 is fine), `git`
- `jq` — used by the manifesto installer to merge `.claude/settings.json` (without it, that step is skipped and reported)
- `python3` (3.8+) — used by the audit scripts; standard library only

## Installation

```bash
claude plugin marketplace add ozkanugr/cecom
claude plugin install cecom@cecom
```

From a local clone instead: `claude plugin marketplace add /path/to/cecom`. Restart Claude Code afterwards so the skills, commands and hook load.

Remove the old plugin to avoid duplicates (the skill would appear twice and the hook would run twice):

```bash
claude plugin uninstall context-gardener@context-gardener
```

To add the manifesto's core rules globally (once; existing `~/.claude/CLAUDE.md` content is left untouched), either ask Claude — "install the engineering manifesto globally" — or run the installer from a clone of this repository:

```bash
bash skills/engineering-manifesto/scripts/apply.sh global --dry-run   # review
bash skills/engineering-manifesto/scripts/apply.sh global
```

## Manifesto installation guarantees

- Existing `CLAUDE.md` content is never changed. Only the region between `<!-- engineering-manifesto:begin … -->` and `<!-- engineering-manifesto:end -->` is managed.
- If there is no CLAUDE.md, the template is written as project-owned content; lines you fill in survive later runs.
- Existing ADRs are never modified. `settings.json` is merged; no rule is removed.
- Every changed file is backed up to `~/.claude/engineering/backups/<timestamp>/` first.
- CLAUDE.md files point to stable copies at `~/.claude/engineering/constitution.md` and `manifesto.md`, not to the plugin folder, so paths keep working when the plugin is updated.

The permission rules added to a project's `.claude/settings.json` (deny reading/editing `.env` files and `secrets/`, deny force-push, ask before `rm -rf`, `git reset --hard`, `git clean`) are **defense in depth, not a security boundary**. Claude Code matches Bash rules against the command text, so variations (different argument order, a wrapper script, `sh -c`) can avoid them. Keep secrets out of the repository, and use branch protection on the server to make force-pushes impossible.

## Security notes

- The plugin's own scripts and hook make no network calls: they read and write local files only, and the hook reads file sizes and a timestamp and never edits anything. (Commands Claude runs during an audit, such as `npm audit`, may use the network.)
- The SessionStart hook does nothing when Claude Code starts in your home directory or `/`, and searches at most 6 directory levels.
- Audit findings never contain secret values: findings cite `file:line` and the kind of secret, and the report renderer rejects recognizable keys (AWS, GitHub, Stripe, OpenAI, Anthropic, Slack, Google, private keys, JWTs). Audit reports still describe weaknesses — review them before committing to a public repository.
- The audit runs project build/test commands only for repositories you trust; those commands execute the project's own code.

## Tests

```bash
bash skills/engineering-manifesto/scripts/test_apply.sh       # runs in a temporary HOME
python3 skills/production-readiness-audit/scripts/catalog.py lint
python3 -m unittest discover -s skills/production-readiness-audit/scripts/tests
```

## Changelog

- **0.3.1** — Security and accuracy review: permission rules use the current syntax and match `.env` files at any depth, with more force-push variants; documented that Bash rules are not a security boundary; audit findings are checked for leaked secrets and the method forbids copying them; project commands run only for trusted repositories; the SessionStart hook skips `$HOME` and `/` and limits search depth; context-gardener backs up files before editing; the manifesto installer escapes project names safely; corrected the locale-sensitivity facts in I18N-001; README gained requirements and security notes.
- **0.3.0** — Added the `production-readiness-audit` skill and the `/audit` command: a 286-check catalog, an evidence and severity method, profile detection, plan/report scripts with validation, and tests.
- **0.2.0** — Renamed `context-gardener` to `cecom`; added the `engineering-manifesto` skill and the `/kickoff` command; fixed the SessionStart hook to run on macOS's stock bash 3.2 (removed `mapfile`).
- **0.1.0** — Initial `context-gardener` release.

## License

MIT — see `LICENSE`.
