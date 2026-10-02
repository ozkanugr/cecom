#!/usr/bin/env bash
# Engineering Manifesto installer — additive and idempotent (manifesto §A3.1).
#
#   apply.sh global  [--dry-run]
#   apply.sh project <dir> [--tier T0|T1|T2|T3] [--dry-run]
#
# Guarantees:
#   - Content outside the engineering-manifesto begin/end markers is never changed.
#   - Existing ADRs and templates are never replaced; only missing files are created.
#   - settings.json is merged: missing permission rules are appended, nothing is removed.
#   - Every file is backed up to ~/.claude/engineering/backups/<timestamp>/ before it changes.
#   - --dry-run prints the diff and writes nothing. Re-running gives the same result.
set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATES="${SKILL_DIR}/assets/templates"
CONSTITUTION="${SKILL_DIR}/references/constitution.md"
MANIFESTO="${SKILL_DIR}/references/manifesto.md"
# Stable, version-independent home for files that CLAUDE.md imports/points to. Plugin caches
# are versioned paths, so CLAUDE.md never references the skill directory directly.
STABLE_DIR="${HOME}/.claude/engineering"
STABLE_CONSTITUTION="${STABLE_DIR}/constitution.md"
STABLE_MANIFESTO="${STABLE_DIR}/manifesto.md"
BACKUP_DIR="${STABLE_DIR}/backups"
VERSION="1.1"

# Paths written into CLAUDE.md files use ~ so they work for any user with the skill installed.
tilde() { case "$1" in "$HOME"/*) printf '~%s' "${1#"$HOME"}" ;; *) printf '%s' "$1" ;; esac; }
BEGIN_PREFIX="<!-- engineering-manifesto:begin"
BEGIN="${BEGIN_PREFIX} v${VERSION} — managed block, edit outside it -->"
END="<!-- engineering-manifesto:end -->"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0
TIER=""
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

usage() {
  sed -n '4,5p' "$0" | sed 's/^# *//'
  exit 2
}

log() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

backup() {
  local f="$1"
  [ -f "$f" ] || return 0
  local dest="${BACKUP_DIR}/${STAMP}${f}"
  mkdir -p "$(dirname "$dest")"
  cp -p "$f" "$dest"
  log "    backup: ${dest}"
}

# write_if_changed <new-content-file> <target>
write_if_changed() {
  local new="$1" target="$2"
  if [ -f "$target" ] && cmp -s "$new" "$target"; then
    log "  unchanged: ${target}"
    return 0
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    log "  would write: ${target}"
    if [ -f "$target" ]; then diff -u "$target" "$new" || true; else sed 's/^/+ /' "$new"; fi
    return 0
  fi
  local existed=0
  [ -f "$target" ] && existed=1
  backup "$target"
  mkdir -p "$(dirname "$target")"
  cat "$new" > "$target"
  if [ "$existed" -eq 1 ]; then log "  updated: ${target}"; else log "  created: ${target}"; fi
}

# strip_block <file> — print the file without the managed block
strip_block() {
  awk -v b="$BEGIN_PREFIX" -v e="$END" '
    index($0, b) == 1 { skip = 1; next }
    skip && index($0, e) == 1 { skip = 0; next }
    !skip { print }' "$1"
}

# upsert_block <target> <block-file> [<base>]   (block-file includes begin and end markers;
# base defaults to target and is the content the block is merged into)
upsert_block() {
  local target="$1" block="$2" src="${3:-$1}" out="${WORK}/upsert.out"
  if [ -f "$src" ]; then
    local nb ne
    nb=$(grep -c -F "$BEGIN_PREFIX" "$src" || true)
    ne=$(grep -c -F "$END" "$src" || true)
    if [ "$nb" -gt 1 ] || [ "$ne" -gt 1 ] || [ "$nb" -ne "$ne" ]; then
      die "${target}: broken or duplicated engineering-manifesto markers (begin=${nb}, end=${ne}). Fix by hand; nothing was changed."
    fi
    if [ "$nb" -eq 1 ]; then
      awk -v b="$BEGIN_PREFIX" -v e="$END" -v blk="$block" '
        index($0, b) == 1 { while ((getline l < blk) > 0) print l; skip = 1; next }
        skip && index($0, e) == 1 { skip = 0; next }
        !skip { print }' "$src" > "$out"
    else
      cat "$src" > "$out"
      if [ -s "$src" ]; then
        [ -n "$(tail -c1 "$src")" ] && printf '\n' >> "$out"
        printf '\n' >> "$out"
      fi
      cat "$block" >> "$out"
    fi
  else
    cat "$block" > "$out"
  fi
  write_if_changed "$out" "$target"
}

# publish_refs — copy constitution and manifesto to STABLE_DIR (backed up, dry-run aware)
publish_refs() {
  [ -f "$CONSTITUTION" ] || die "missing ${CONSTITUTION}"
  [ -f "$MANIFESTO" ] || die "missing ${MANIFESTO}"
  log "Reference copies: ${STABLE_DIR}"
  write_if_changed "$CONSTITUTION" "$STABLE_CONSTITUTION"
  write_if_changed "$MANIFESTO" "$STABLE_MANIFESTO"
}

apply_global() {
  local target="${HOME}/.claude/CLAUDE.md" block="${WORK}/global.block"
  publish_refs
  log "Global: ${target}"
  {
    printf '%s\n' "$BEGIN"
    printf '%s\n' "# Engineering constitution"
    printf '%s\n' "@$(tilde "$STABLE_CONSTITUTION")"
    printf '%s\n' "$END"
  } > "$block"
  upsert_block "$target" "$block"
}

apply_project_claude_md() {
  local dir="$1" target block="${WORK}/project.block"
  if [ -f "${dir}/CLAUDE.md" ]; then
    target="${dir}/CLAUDE.md"
  elif [ -f "${dir}/.claude/CLAUDE.md" ]; then
    target="${dir}/.claude/CLAUDE.md"
  else
    target="${dir}/CLAUDE.md"
  fi
  log "Project CLAUDE.md: ${target}"

  # Tier precedence: --tier > the project's own Tier line (outside the block) > the managed block.
  local tier="$TIER" own_tier="" block_tier=""
  if [ -f "$target" ]; then
    own_tier=$(strip_block "$target" | grep -Eo 'Tier: T[0-3]' | head -n1 | sed 's/Tier: //' || true)
    block_tier=$(awk -v b="$BEGIN_PREFIX" -v e="$END" '
      index($0, b) == 1 { inb = 1; next } inb && index($0, e) == 1 { inb = 0 } inb { print }' "$target" \
      | grep -Eo 'Tier: T[0-3]' | head -n1 | sed 's/Tier: //' || true)
  fi
  if [ -n "$tier" ] && [ -n "$own_tier" ] && [ "$tier" != "$own_tier" ]; then
    log "  warning: the project's own line says 'Tier: ${own_tier}' (outside the managed block). Update it by hand to ${tier}."
  fi
  [ -n "$tier" ] || tier="${own_tier:-$block_tier}"
  [ -n "$tier" ] || tier="T? (TODO: choose T0–T3, manifesto §A2)"

  # New file: the template becomes project-owned content (outside the block), so the
  # project can fill it in and later runs never touch it.
  local base="$target"
  if [ ! -f "$target" ]; then
    base="${WORK}/seed.md"
    sed -e "s|{{PROJECT_NAME}}|$(basename "$dir")|" -e "s|{{TIER}}|${tier}|" \
        -e "s|{{MANIFESTO}}|$(tilde "$STABLE_MANIFESTO")|" "${TEMPLATES}/project-claude.md" > "$base"
  fi

  # Only list what the project does not already document. Patterns include Turkish
  # heading words (komut, mimari, karar, bütçe…) so Turkish CLAUDE.md files are recognized.
  local own="${WORK}/own.md" todos=""
  strip_block "$base" > "$own"
  grep -Eiq '^#{1,6} .*(command|komut|script|getting started|kurulum)' "$own" \
    || todos="${todos}- [ ] Add a Commands section (install, dev, test, lint, typecheck, build)\n"
  grep -Eiq '^#{1,6} .*(architecture|mimari|structure|yapı|layout)' "$own" \
    || todos="${todos}- [ ] Add an Architecture map (layers, dependency direction)\n"
  grep -Eiq '(docs/adr|^#{1,6} .*(decision|karar|adr))' "$own" \
    || todos="${todos}- [ ] Reference docs/adr/ and list key decisions\n"
  case "$tier" in
    T2|T3) grep -Eiq '^#{1,6} .*(budget|bütçe|performance|performans)' "$own" \
      || todos="${todos}- [ ] Add numeric Budgets (manifesto §54)\n" ;;
  esac

  {
    printf '%s\n' "$BEGIN"
    printf '%s\n' "## Engineering rules"
    printf '%s\n' "Tier: ${tier}"
    printf '%s\n' "Rules: Engineering Manifesto v${VERSION} (\`$(tilde "$STABLE_MANIFESTO")\`; constitution loaded globally). Skill: engineering-manifesto (cecom plugin)."
    printf '%s\n' "Project-specific rules elsewhere in this file win over manifesto defaults, unless they break a manifesto MUST rule — then flag the conflict."
    if [ -n "$todos" ]; then
      printf '\n%s\n' "Missing for kickoff (manifesto §55):"
      printf '%b' "$todos"
    fi
    printf '%s\n' "$END"
  } > "$block"
  upsert_block "$target" "$block" "$base"
}

apply_project_adr() {
  local dir="$1" target="${1}/docs/adr/0000-template.md"
  log "ADR template: ${target}"
  if [ -e "$target" ]; then
    log "  exists, left as is: ${target}"
    return 0
  fi
  write_if_changed "${TEMPLATES}/adr-template.md" "$target"
}

apply_project_settings() {
  local dir="$1" target="${1}/.claude/settings.json" out="${WORK}/settings.json"
  log "Permissions: ${target}"
  if ! command -v jq >/dev/null 2>&1; then
    log "  skipped: jq not installed. Add the rules from ${TEMPLATES}/permissions.json by hand."
    return 0
  fi
  local base="${WORK}/settings.base.json"
  if [ -f "$target" ]; then
    jq empty "$target" 2>/dev/null || { log "  skipped: ${target} is not valid JSON (left untouched)."; return 0; }
    cp "$target" "$base"
  else
    printf '{}\n' > "$base"
  fi
  jq --slurpfile p "${TEMPLATES}/permissions.json" '
    def addmissing($xs): reduce $xs[] as $r (. // []; if any(.[]; . == $r) then . else . + [$r] end);
    .permissions = (.permissions // {})
    | .permissions.deny = (.permissions.deny | addmissing($p[0].deny))
    | .permissions.ask  = (.permissions.ask  | addmissing($p[0].ask))
  ' "$base" > "$out"
  if [ -f "$target" ] && [ "$(jq -S . "$target")" = "$(jq -S . "$out")" ]; then
    log "  unchanged: ${target}"
    return 0
  fi
  write_if_changed "$out" "$target"
}

main() {
  [ $# -ge 1 ] || usage
  local mode="$1"; shift
  local dir=""
  if [ "$mode" = "project" ]; then
    [ $# -ge 1 ] || usage
    dir="$1"; shift
  fi
  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run) DRY_RUN=1 ;;
      --tier) shift; [ $# -gt 0 ] || usage; TIER="$1" ;;
      *) usage ;;
    esac
    shift
  done
  if [ -n "$TIER" ]; then
    case "$TIER" in T0|T1|T2|T3) ;; *) die "--tier must be T0, T1, T2 or T3" ;; esac
  fi
  [ "$DRY_RUN" -eq 1 ] && log "(dry run — nothing will be written)"

  case "$mode" in
    global) apply_global ;;
    project)
      [ -d "$dir" ] || die "not a directory: ${dir}"
      dir="$(cd "$dir" && pwd)"
      publish_refs
      apply_project_claude_md "$dir"
      apply_project_adr "$dir"
      apply_project_settings "$dir"
      ;;
    *) usage ;;
  esac
}

main "$@"
