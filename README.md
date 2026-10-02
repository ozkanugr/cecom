# cecom — Claude Code plugin

Personal engineering toolkit. Replaces the `context-gardener` plugin (v0.1.0) and bundles two skills in one package.

| Skill | What it does | How to invoke |
|---|---|---|
| **engineering-manifesto** | New-project kickoff (tier T0–T3, kickoff questions, ADRs, project CLAUDE.md, permission rules) and applying the manifesto to existing projects **without overwriting anything**. During design and review, finds and applies the relevant manifesto sections. | `/kickoff`, "we're starting a new project", "apply the manifesto to this project" |
| **context-gardener** | Keeps CLAUDE.md and project memory files accurate and lean: verifies every claim against the repo, removes duplicate and stale content, splits bloated files. | `/tidy-context`, or Claude offers it on its own |

A SessionStart hook reminds Claude when context files have grown large or haven't been groomed in a while (defaults: 150 lines / 21 days). It never edits anything.

## Layout

```
cecom/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json          For local installation
├── commands/
│   ├── kickoff.md                /kickoff
│   └── tidy-context.md           /tidy-context
├── hooks/
│   ├── hooks.json                SessionStart
│   └── check-staleness.sh        Context file size/age check (works on macOS bash 3.2)
└── skills/
    ├── engineering-manifesto/    SKILL.md, scripts/, references/, assets/
    └── context-gardener/         SKILL.md
```

## Installation

```bash
claude plugin marketplace add ~/Desktop/cecom
claude plugin install cecom@cecom
```

Remove the old plugin to avoid duplicates (the skill would appear twice and the hook would run twice):

```bash
claude plugin uninstall context-gardener@context-gardener
```

To add the core rules globally (once; existing `~/.claude/CLAUDE.md` content is left untouched):

```bash
bash ~/Desktop/cecom/skills/engineering-manifesto/scripts/apply.sh global
```

## Manifesto installation guarantees

- Existing `CLAUDE.md` content is never changed. Only the region between `<!-- engineering-manifesto:begin … -->` and `<!-- engineering-manifesto:end -->` is managed.
- If there is no CLAUDE.md, the template is written as project-owned content; lines you fill in survive later runs.
- Existing ADRs are never modified. `settings.json` is merged; no rule is removed.
- Every changed file is backed up to `~/.claude/engineering/backups/<timestamp>/` first.
- CLAUDE.md files point to stable copies at `~/.claude/engineering/constitution.md` and `manifesto.md`, not to the plugin folder, so paths keep working when the plugin is updated.

## Tests

```bash
bash skills/engineering-manifesto/scripts/test_apply.sh
```

## Changelog

- **0.2.0** — Renamed `context-gardener` to `cecom`; added the `engineering-manifesto` skill and the `/kickoff` command; fixed the SessionStart hook to run on macOS's stock bash 3.2 (removed `mapfile`).
- **0.1.0** — Initial `context-gardener` release.

## License

MIT — see `LICENSE`.
