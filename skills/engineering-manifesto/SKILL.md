---
name: engineering-manifesto
description: Applies the user's Engineering Manifesto (v1.1) to Claude Code projects — project kickoff (tier T0–T3, kickoff questions, ADRs, project CLAUDE.md, permission rules) and an additive installer that never overwrites an existing CLAUDE.md, settings.json or ADRs. Use this whenever the user starts or sets up a new project or repo (in any language, e.g. "new project", "kickoff", "set up this repo"), asks to create or extend a project CLAUDE.md, ADRs or engineering rules, wants to apply/install the manifesto to a project, or asks which engineering rules apply to a design, database schema, security, KVKK/GDPR privacy, API, reliability or code-review decision — even if the manifesto is not named.
---

# Engineering Manifesto

Pick the branch, run its steps in order, then run **Verify**. `SKILL_DIR` is the directory containing this file (in the cecom plugin: `${CLAUDE_PLUGIN_ROOT}/skills/engineering-manifesto`). The script also keeps copies of the constitution and manifesto in `~/.claude/engineering/`, because `CLAUDE.md` files must point at a path that doesn't change when the plugin updates.

| Branch | When | Outcome | Writes to |
|---|---|---|---|
| A. Kickoff | New project, or no `Tier:` declared yet | Tier chosen, decisions recorded | Project `CLAUDE.md`, `docs/adr/`, `.claude/settings.json` |
| B. Apply | Existing project; user wants the manifesto applied | Managed block + permission rules added | Same as A, without the interview |
| C. Reference | Design, schema, security, privacy, API or review question | Recommendation citing manifesto sections | Nothing (answer only) |
| D. Global install | User explicitly asks to install globally | Constitution imported every session | `~/.claude/CLAUDE.md` |

## Ground rule: additive, never overwrite

Existing `CLAUDE.md`, settings and docs hold knowledge you can't see; overwriting them destroys it silently.

- Manifesto content lives only between `<!-- engineering-manifesto:begin … -->` and `<!-- engineering-manifesto:end -->`. `scripts/apply.sh` replaces only that region, so never hand-edit inside it — the next run would discard your edit.
- Project content goes outside the block. Insert lines or sections; don't rewrite, reorder or delete existing lines unless the user asks.
- Never change an accepted ADR's decision; write a new ADR that supersedes it.
- Show what will change before writing (dry-run summary or a short description of the edit).

## A. Kickoff

1. **Inspect the repo.** Read `references/kickoff.md`, then check the target directory for `CLAUDE.md` / `.claude/CLAUDE.md`, `docs/adr/`, `.claude/settings.json`, and stack/CI files it lists.
   **Done when:** you have a list of which kickoff answers the repo already provides.

2. **Choose the tier** with the user: offer T0–T3 with one line each and a recommendation.
   **Done when:** the user has confirmed one tier.

3. **Ask the remaining kickoff questions** (T0/T1: 1–5, T2/T3: all 12; up to 4 per AskUserQuestion call). "Don't know / later" becomes an open TODO.
   **Done when:** every question is answered from the repo, answered by the user, or recorded as a TODO.

4. **Install** by running Branch B steps 1–3 with `--tier <tier>`.
   **Done when:** Branch B step 3 is done.

5. **Write ADRs** per `references/kickoff.md` ("Writing ADRs").
   **Done when:** each topic with real answers has one ADR in `docs/adr/`, numbered after the highest existing one, and no existing ADR was modified.

6. **Fill the project `CLAUDE.md`** per `references/kickoff.md` ("Filling the project CLAUDE.md").
   **Done when:** answerable `TODO`s outside the block are replaced, nothing inside the block was hand-edited, and the file is under ~150 lines.

7. Run **Verify**, then report.

## B. Apply to an existing project

1. **Dry-run:**
   ```bash
   bash SKILL_DIR/scripts/apply.sh project <dir> [--tier T0|T1|T2|T3] --dry-run
   ```
   Omit `--tier` to keep the tier already in the file. Summarize the diff in a few lines (files, what gets added).
   **Done when:** the user has seen the summary and agreed, or had already asked you to apply.

2. **Apply:**
   ```bash
   bash SKILL_DIR/scripts/apply.sh project <dir> [--tier <tier>]
   ```
   It refreshes the managed block in `CLAUDE.md` (or `.claude/CLAUDE.md`; creates `CLAUDE.md` from the template if neither exists), refreshes the copies in `~/.claude/engineering/`, creates `docs/adr/0000-template.md` only if missing, appends missing deny/ask rules to `.claude/settings.json`, and backs up every changed file to `~/.claude/engineering/backups/<timestamp>/`.
   **Done when:** the command exits 0 and prints `created`, `updated`, or `unchanged` for each file.

3. **Handle messages:**
   - `warning: the project's own line says 'Tier: …'` → ask which tier is right; change only that line outside the block.
   - `error: broken or duplicated … markers` → nothing changed; show the marker lines to the user and fix them together.
   - `skipped: … not valid JSON` → settings untouched; tell the user.
   **Done when:** no warning or error is left unaddressed.

4. **Offer to fill the TODOs** the block lists, deriving answers from the repo and adding them outside the block.
   **Done when:** the user accepted or declined.

5. Run **Verify**, then report.

## C. Reference during design and review

1. **Find the section** using `references/section-map.md`; read only that section of `references/manifesto.md` (grep the heading, then Read with offset/limit).
   **Done when:** you have read every section that governs the question, and none of the manifesto beyond them.

2. **Apply it at the project's tier** (manifesto Appendix 1; assume T2 if the project declares none and say so). Cite section numbers in the answer.
   **Done when:** every recommendation names the section it comes from.

No Verify run is needed for this branch; nothing is written.

## D. Global install

Only on explicit request — it affects every project.

1. ```bash
   bash SKILL_DIR/scripts/apply.sh global --dry-run
   bash SKILL_DIR/scripts/apply.sh global
   ```
   **Done when:** `~/.claude/CLAUDE.md` contains exactly one managed block importing `~/.claude/engineering/constitution.md`, and its other content is unchanged.

2. Run **Verify** with `global` instead of `project <dir>`.

## Verify

1. Re-run the same dry-run (`apply.sh project <dir> --dry-run`, or `apply.sh global --dry-run`).
   **Done when:** every file reports `unchanged` (ADR template: `exists, left as is`).
2. If you changed `scripts/apply.sh` itself, run `bash SKILL_DIR/scripts/test_apply.sh`.
   **Done when:** it ends with `0 failed`.

## Report

```
Changed:       files created/updated (backups exist under ~/.claude/engineering/backups/)
Why:           tier and the decisions recorded
Verified:      commands run and their real output
Not verified:  anything you could not check
Open TODOs:    kickoff answers still missing
Next:          one concrete step (usually: build one end-to-end vertical slice)
```

## Resources

| Path | Purpose |
|---|---|
| `references/kickoff.md` | Tiers, repo signals, the 12 kickoff questions, ADR and CLAUDE.md rules (Branch A) |
| `references/section-map.md` | Topic → manifesto section lookup (Branch C) |
| `references/manifesto.md` | Full manifesto; read by section only |
| `references/constitution.md` | ~50-line core rules; copied to `~/.claude/engineering/` and imported globally by Branch D |
| `scripts/apply.sh` | Additive, idempotent installer (Branches A, B, D) |
| `scripts/test_apply.sh` | Focused test for `apply.sh` (Verify step 2) |
| `assets/templates/project-claude.md` | Seed for a missing project `CLAUDE.md` (used by `apply.sh`) |
| `assets/templates/adr-template.md` | ADR template (used by `apply.sh` and Branch A step 5) |
| `assets/templates/permissions.json` | Deny/ask rules merged into `.claude/settings.json` (used by `apply.sh`) |
