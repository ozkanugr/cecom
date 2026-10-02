#!/usr/bin/env bash
# Focused test for apply.sh. Runs entirely in a temporary HOME; touches nothing real.
#   bash scripts/test_apply.sh
set -uo pipefail

SKILL_SRC="$(cd "$(dirname "$0")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"
mkdir -p "$HOME/.claude/skills"
cp -R "$SKILL_SRC" "$HOME/.claude/skills/engineering-manifesto"
A="$HOME/.claude/skills/engineering-manifesto/scripts/apply.sh"

pass=0; fail=0
check() { # check <name> <command...>
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then pass=$((pass + 1)); printf 'ok    %s\n' "$name"
  else fail=$((fail + 1)); printf 'FAIL  %s\n' "$name"; fi
}
run() { bash "$A" "$@" 2>&1; }

# --- global: appends to an existing file, keeps user content, idempotent
printf '# Mine\n- keep this' > "$HOME/.claude/CLAUDE.md"   # no trailing newline on purpose
run global >/dev/null
check "global keeps user content"      grep -qx -- '- keep this' "$HOME/.claude/CLAUDE.md"
check "global imports stable copy"     grep -qx '@~/.claude/engineering/constitution.md' "$HOME/.claude/CLAUDE.md"
check "constitution copy matches"      cmp -s "$HOME/.claude/engineering/constitution.md" "$SKILL_SRC/references/constitution.md"
check "manifesto copy matches"         cmp -s "$HOME/.claude/engineering/manifesto.md" "$SKILL_SRC/references/manifesto.md"
check "global second run unchanged"    sh -c "bash '$A' global | grep -q unchanged"
check "global has one block"           test "$(grep -c 'engineering-manifesto:begin' "$HOME/.claude/CLAUDE.md")" -eq 1

# --- dry run writes nothing
P="$T/dry"; mkdir -p "$P"
run project "$P" --tier T2 --dry-run >/dev/null
check "dry-run creates no files"       test -z "$(ls -A "$P")"

# --- existing project: original bytes preserved as a prefix, settings merged
P="$T/existing"; mkdir -p "$P/.claude"
printf '# App\nTier: T2\n\n## Commands\nnpm test\n' > "$P/CLAUDE.md"
cp "$P/CLAUDE.md" "$T/orig.md"
printf '{"permissions":{"allow":["Bash(npm test:*)"],"deny":["Read(./.env)"]},"model":"x"}' > "$P/.claude/settings.json"
run project "$P" >/dev/null
check "existing content preserved"     sh -c "head -c \$(wc -c < '$T/orig.md') '$P/CLAUDE.md' | cmp -s - '$T/orig.md'"
check "block appended once"            test "$(grep -c 'engineering-manifesto:begin' "$P/CLAUDE.md")" -eq 1
check "own tier picked up"             sh -c "sed -n '/managed block/,\$p' '$P/CLAUDE.md' | grep -qx 'Tier: T2'"
check "block points to stable path"    grep -q '~/.claude/engineering/manifesto.md' "$P/CLAUDE.md"
check "commands not re-requested"      sh -c "! grep -q 'Add a Commands section' '$P/CLAUDE.md'"
check "missing architecture listed"    grep -q 'Add an Architecture map' "$P/CLAUDE.md"
check "settings keeps allow rule"      sh -c "jq -e '.permissions.allow == [\"Bash(npm test:*)\"]' '$P/.claude/settings.json'"
check "settings keeps other keys"      sh -c "jq -e '.model == \"x\"' '$P/.claude/settings.json'"
check "settings no duplicate deny"     sh -c "test \$(jq '[.permissions.deny[] | select(. == \"Read(./.env)\")] | length' '$P/.claude/settings.json') -eq 1"
check "settings adds force-push deny"  sh -c "jq -e '.permissions.deny | index(\"Bash(git push --force:*)\")' '$P/.claude/settings.json'"
check "backup written"                 test -n "$(find "$HOME/.claude/engineering/backups" -name CLAUDE.md -path "*existing*")"
out="$(run project "$P")"
check "second run all unchanged"       sh -c "! printf '%s' \"\$1\" | grep -Eq 'updated|created'" _ "$out"
out="$(run project "$P" --tier T3)"
check "tier conflict warns"            sh -c "printf '%s' \"\$1\" | grep -q warning" _ "$out"

# --- existing ADR template is never replaced
printf 'mine\n' > "$P/docs/adr/0000-template.md"
run project "$P" >/dev/null
check "existing ADR untouched"         grep -qx mine "$P/docs/adr/0000-template.md"

# --- fresh project: template is project-owned, user edits survive reruns
P="$T/fresh"; mkdir -p "$P"
run project "$P" --tier T1 >/dev/null
check "fresh CLAUDE.md created"        test -f "$P/CLAUDE.md"
check "template outside block"         sh -c "head -1 '$P/CLAUDE.md' | grep -qx '# fresh'"
sed -i.bak 's/^install: TODO/install: npm ci/' "$P/CLAUDE.md" && rm -f "$P/CLAUDE.md.bak"
run project "$P" >/dev/null
check "user edit survives rerun"       grep -qx 'install: npm ci' "$P/CLAUDE.md"
check "tier kept on rerun"             grep -qx 'Tier: T1' "$P/CLAUDE.md"

# --- .claude/CLAUDE.md location is respected
P="$T/dotclaude"; mkdir -p "$P/.claude"; printf '# Dot\n' > "$P/.claude/CLAUDE.md"
run project "$P" >/dev/null
check ".claude/CLAUDE.md used"         grep -q 'engineering-manifesto:begin' "$P/.claude/CLAUDE.md"
check "no root CLAUDE.md created"      test ! -e "$P/CLAUDE.md"

# --- broken markers: refuse and change nothing
P="$T/broken"; mkdir -p "$P"
printf '# B\n<!-- engineering-manifesto:begin v1.1 -->\nno end\n' > "$P/CLAUDE.md"; cp "$P/CLAUDE.md" "$T/broken.orig"
check "broken markers exit non-zero"   sh -c "! bash '$A' project '$P'"
check "broken file unchanged"          cmp -s "$P/CLAUDE.md" "$T/broken.orig"

# --- invalid settings JSON is left alone
P="$T/badjson"; mkdir -p "$P/.claude"; printf '{oops' > "$P/.claude/settings.json"
run project "$P" >/dev/null
check "invalid JSON untouched"         grep -qx '{oops' "$P/.claude/settings.json"

# --- bad tier rejected
check "bad tier rejected"              sh -c "! bash '$A' project '$T/fresh' --tier T9"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
