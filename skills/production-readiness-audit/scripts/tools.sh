#!/usr/bin/env bash
# On-demand audit tools. Nothing is bundled with the plugin; tools are installed only when an
# audit needs them, only after the user approves, and never into the audited project.
#
#   tools.sh needed <project-dir>   Which tools this project's audit can use, and which are missing
#   tools.sh status                 Every known tool and its installed version
#   tools.sh install <tool>...      Install via Homebrew (official formulae, verified bottles)
#
# Ephemeral npm/PyPI tools (dependency-cruiser, knip, import-linter) are not installed; run them with
# a pinned version via `npx --yes pkg@<ver>` / `uvx`, after approval (see references/tools.md).
# Works with macOS's stock bash 3.2.
set -uo pipefail

BREW_TOOLS="ripgrep gitleaks trufflehog osv-scanner semgrep swiftlint pip-audit"

bin_of() { # tool name → command name
  case "$1" in
    ripgrep) echo rg ;;
    *) echo "$1" ;;
  esac
}

version_of() { # prints the installed version, or nothing
  local b; b=$(bin_of "$1")
  command -v "$b" >/dev/null 2>&1 || return 0
  case "$1" in
    xcodebuild) xcodebuild -version 2>/dev/null | head -1 ;;
    gitleaks) gitleaks version 2>/dev/null | head -1 ;;
    *) "$b" --version 2>&1 | head -1 | sed 's/^[^0-9]*//' | cut -d' ' -f1 ;;
  esac
}

row() { # row <tool> <why>
  local v; v=$(version_of "$1")
  if [ -n "$v" ]; then printf '%s\tinstalled\t%s\t%s\n' "$1" "$v" "$2"
  else
    case " $BREW_TOOLS " in
      *" $1 "*) printf '%s\tmissing\t-\t%s (brew install %s)\n' "$1" "$2" "$1" ;;
      *) printf '%s\tmissing\t-\t%s\n' "$1" "$2" ;;
    esac
  fi
}

ephemeral() { # ephemeral <tool> <why>
  printf '%s\ton-demand\t-\t%s\n' "$1" "$2"
}

has() { # has <name-pattern…> → true if any path matches under the project (bounded depth, vendored dirs skipped)
  local name
  for name in "$@"; do
    if find . -maxdepth 4 \( -path '*/node_modules' -o -path '*/.git' -o -path '*/Pods' -o -path '*/build' \) -prune \
         -o -name "$name" -print 2>/dev/null | grep -q .; then
      return 0
    fi
  done
  return 1
}

cmd_needed() {
  local dir="${1:-}"
  [ -n "$dir" ] && [ -d "$dir" ] || { echo "usage: tools.sh needed <project-dir>" >&2; return 2; }
  cd "$dir" || return 2
  printf 'tool\tstatus\tversion\twhy\n'
  row ripgrep "code search for every check"
  row gitleaks "secrets in files and Git history (SEC-002, SEC-019)"
  row trufflehog "second secrets scanner (SEC-002)"
  row semgrep "static analysis: injection, XSS, SSRF, crypto (SEC-005/006/008/009/022)"
  local js=0 py=0 osv=0
  has package.json && js=1
  has requirements.txt pyproject.toml Pipfile && py=1
  has package-lock.json pnpm-lock.yaml yarn.lock bun.lock requirements.txt poetry.lock uv.lock Pipfile.lock pdm.lock \
      pubspec.lock go.mod Cargo.lock gradle.lockfile pom.xml Gemfile.lock composer.lock && osv=1
  [ "$osv" -eq 1 ] && row osv-scanner "known-vulnerable dependencies (SUPPLY-003)"
  if [ "$js" -eq 1 ] || has tsconfig.json; then
    printf 'eslint\ton-demand\t-\tESLint (Next.js config for Next apps, typescript-eslint for TS): AIGEN-003/004, CONC-002/006, PERF-002, A11Y-010 — see js_checks.sh plan\n'
  fi
  if has tsconfig.json; then
    printf 'tsc\ton-demand\t-\tproject'"'"'s own TypeScript type check (AIGEN-003, AIGEN-014) — js_checks.sh typecheck; UNCERTAIN without node_modules\n'
  fi
  if [ "$js" -eq 1 ]; then
    row npm "npm audit for JS dependencies (SUPPLY-003)"
    ephemeral dependency-cruiser "circular deps and layers, JS/TS (ARCH-003/006): npx --yes dependency-cruiser@<ver>"
    ephemeral knip "unused files/exports/deps, JS/TS (AIGEN-009, SUPPLY-004): npx --yes knip@<ver>"
  fi
  [ "$py" -eq 1 ] && row pip-audit "Python dependency vulnerabilities (SUPPLY-003)"
  if has '*.swift'; then
    row swiftlint "force unwraps, try!, unsafe Swift patterns (AIGEN-004, CONTRACT-008)"
  fi
  if has '*.xcodeproj' '*.xcworkspace'; then
    row xcodebuild "build and tests for Apple projects (AIGEN-003, TQ-005)"
  fi
  if has Podfile.lock Package.resolved; then
    printf 'apple-deps\tgap\t-\tno scanner reads Podfile.lock/Package.resolved: use Dependabot (SPM on GitHub) or manual review; else SUPPLY-003 UNCERTAIN\n'
  fi
  return 0
}

cmd_status() {
  printf 'tool\tstatus\tversion\twhy\n'
  for t in $BREW_TOOLS npm xcodebuild; do row "$t" "-"; done
}

cmd_install() {
  [ $# -gt 0 ] || { echo "usage: tools.sh install <tool>..." >&2; return 2; }
  command -v brew >/dev/null 2>&1 || { echo "error: Homebrew not found; install the tools manually from their official releases (references/tools.md)" >&2; return 1; }
  local t rc=0
  for t in "$@"; do
    case " $BREW_TOOLS " in
      *" $t "*) ;;
      *) echo "error: $t is not a Homebrew-installed audit tool (allowed: $BREW_TOOLS)" >&2; rc=1; continue ;;
    esac
    if [ -n "$(version_of "$t")" ]; then echo "$t: already installed ($(version_of "$t"))"; continue; fi
    echo "$t: brew install $t"
    if HOMEBREW_NO_INSTALL_CLEANUP=1 brew install "$t"; then echo "$t: installed $(version_of "$t")"; else rc=1; fi
  done
  return "$rc"
}

case "${1:-}" in
  needed) shift; cmd_needed "$@" ;;
  status) cmd_status ;;
  install) shift; cmd_install "$@" ;;
  *) sed -n '5,7p' "$0" | sed 's/^# *//'; exit 2 ;;
esac
