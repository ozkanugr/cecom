#!/usr/bin/env bash
# ESLint and TypeScript checks for JS/TS projects (Next.js aware). Read-only for the audited project.
#
#   js_checks.sh plan <project-dir>                     What would run, how, and what would be downloaded
#   js_checks.sh prepare <next|ts>                      Build the lint sandbox (DOWNLOADS — ask the user first)
#   js_checks.sh lint <project-dir> --out <file>        Run ESLint (JSON output)
#   js_checks.sh typecheck <project-dir> --out <file>   Run the project's own `tsc --noEmit`
#
# Lint modes:
#   project       the project has its own ESLint config and local eslint: run that. Its config is JS that
#                 executes, so only for repositories the user trusts.
#   sandbox-next  Next.js project without usable ESLint: eslint-config-next (core-web-vitals + typescript)
#   sandbox-ts    TypeScript project without usable ESLint: typescript-eslint recommended
# The sandbox lives in ~/.cache/cecom/tools/js-lint/<kind>/ — never in the project. `prepare` resolves the
# newest mutually compatible versions (npm --strict-peer-deps; steps a major back on peer conflicts),
# installs with --ignore-scripts and verifies registry signatures with `npm audit signatures`.
# Type checking always uses the project's own TypeScript; without node_modules it can't be trusted, so
# the audit marks it UNCERTAIN instead of installing anything into the project.
set -uo pipefail

CACHE="${CECOM_CACHE:-$HOME/.cache/cecom}/tools/js-lint"
NPM_FLAGS="--ignore-scripts --no-audit --no-fund --strict-peer-deps --save-exact --loglevel=error"

die() { echo "error: $*" >&2; exit 2; }

pkg_has_dep() { # pkg_has_dep <dir> <name> → true if package.json lists it in any dependency section
  [ -f "$1/package.json" ] || return 1
  python3 - "$1/package.json" "$2" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(1)
name = sys.argv[2]
for k in ("dependencies", "devDependencies", "peerDependencies", "optionalDependencies"):
    if name in (d.get(k) or {}):
        sys.exit(0)
sys.exit(1)
PY
}

project_eslint_config() { # prints the project's ESLint config file, if any
  local f
  for f in eslint.config.js eslint.config.mjs eslint.config.cjs eslint.config.ts eslint.config.mts eslint.config.cts \
           .eslintrc.js .eslintrc.cjs .eslintrc.json .eslintrc.yml .eslintrc.yaml .eslintrc; do
    [ -f "$1/$f" ] && { echo "$f"; return 0; }
  done
  return 1
}

lint_mode() { # lint_mode <dir> → project | sandbox-next | sandbox-ts | none
  local d="$1"
  if project_eslint_config "$d" >/dev/null && [ -x "$d/node_modules/.bin/eslint" ]; then echo project; return; fi
  if pkg_has_dep "$d" next; then echo sandbox-next; return; fi
  if [ -f "$d/tsconfig.json" ]; then echo sandbox-ts; return; fi
  echo none
}

typecheck_mode() { # typecheck_mode <dir> → project | uncertain | none
  local d="$1"
  [ -f "$d/tsconfig.json" ] || { echo none; return; }
  [ -x "$d/node_modules/.bin/tsc" ] && { echo project; return; }
  echo uncertain
}

cmd_plan() {
  local d="${1:-}"; [ -n "$d" ] && [ -d "$d" ] || die "usage: js_checks.sh plan <project-dir>"
  d="$(cd "$d" && pwd)"
  local lm tm cfg
  lm=$(lint_mode "$d"); tm=$(typecheck_mode "$d")
  cfg=$(project_eslint_config "$d" || true)
  echo "project: $d"
  echo "next.js: $(pkg_has_dep "$d" next && echo yes || echo no)   typescript: $([ -f "$d/tsconfig.json" ] && echo yes || echo no)   own eslint config: ${cfg:-none}   node_modules: $([ -d "$d/node_modules" ] && echo yes || echo no)"
  echo "lint: $lm"
  case "$lm" in
    project) echo "  runs the project's own eslint with $cfg (executes project config code: trusted repos only); no download" ;;
    sandbox-next|sandbox-ts)
      local kind="${lm#sandbox-}"
      if [ -f "$CACHE/$kind/versions.txt" ]; then echo "  sandbox ready: $(tr '\n' ' ' < "$CACHE/$kind/versions.txt")"
      else echo "  needs: js_checks.sh prepare $kind  (downloads ESLint and plugins from npm into $CACHE/$kind — ask the user first)"; fi ;;
    none) echo "  no ESLint config and neither Next.js nor TypeScript: no lint run (record checks from manual review)" ;;
  esac
  echo "typecheck: $tm"
  case "$tm" in
    project) echo "  runs the project's own tsc --noEmit ($("$d/node_modules/.bin/tsc" --version 2>/dev/null))" ;;
    uncertain) echo "  tsconfig.json but no installed dependencies: a type check would report missing modules, not real errors -> AIGEN-003 UNCERTAIN (don't install into the project)" ;;
  esac
}

install_compatible() { # install_compatible <dir> <package...>
  # Every package starts at @latest. On a peer conflict, the package the conflict names (or, failing that,
  # the first one still at latest) steps one major back. Up to 4 attempts.
  local dir="$1"; shift
  local specs="" p
  for p in "$@"; do specs="$specs $p@latest"; done
  local attempt=0
  while [ "$attempt" -lt 5 ]; do
    # shellcheck disable=SC2086
    if (cd "$dir" && npm install $NPM_FLAGS $specs >"$dir/install.log" 2>&1); then return 0; fi
    grep -q 'ERESOLVE' "$dir/install.log" || { cat "$dir/install.log" >&2; return 1; }
    local target="" s
    for s in $specs; do
      local name="${s%@*}"
      case "$name" in "") name="$s" ;; esac
      if grep -q "peer $name@\|Found: $name@\|Could not resolve dependency:.*$name@" "$dir/install.log"; then target="$name"; break; fi
    done
    if [ -z "$target" ]; then
      for s in $specs; do case "$s" in *@latest) target="${s%@latest}"; break ;; esac; done
    fi
    [ -n "$target" ] || { cat "$dir/install.log" >&2; return 1; }
    local next="" stepped=0
    for s in $specs; do
      local name="${s%@*}" ver="${s##*@}"
      if [ "$stepped" -eq 0 ] && [ "$name" = "$target" ]; then
        local major
        case "$ver" in
          latest) major=$(npm view "$name" version 2>/dev/null | cut -d. -f1) ;;
          \<*) major="${ver#<}" ;;
          *) major="" ;;
        esac
        if [ -n "$major" ] && [ "$major" -gt 1 ]; then next="$next $name@<$major"; stepped=1; continue; fi
      fi
      next="$next $s"
    done
    [ "$stepped" -eq 1 ] || { cat "$dir/install.log" >&2; return 1; }
    specs="$next"
    echo "  peer conflict on $target; retrying with:$specs" >&2
    attempt=$((attempt + 1))
  done
  cat "$dir/install.log" >&2; return 1
}

cmd_prepare() {
  local kind="${1:-}"
  case "$kind" in next|ts) ;; *) die "usage: js_checks.sh prepare <next|ts>" ;; esac
  command -v npm >/dev/null || die "npm not found"
  local dir="$CACHE/$kind"
  rm -rf "$dir"; mkdir -p "$dir"
  printf '{ "name": "cecom-js-lint-%s", "private": true, "type": "module" }\n' "$kind" > "$dir/package.json"
  echo "Downloading into $dir (official npm registry; install scripts disabled)"
  if [ "$kind" = next ]; then
    # eslint-config-next parses code with the Babel parser bundled inside `next`, so the sandbox needs
    # next (and its required peers react, react-dom) as well — a real Next.js project already has them.
    install_compatible "$dir" eslint-config-next eslint typescript next react react-dom || die "could not resolve a compatible set"
    cat > "$dir/eslint.config.mjs" <<'JS'
// Generated by cecom js_checks.sh — Next.js recommended config (nextjs.org/docs/app/api-reference/config/eslint).
import { defineConfig, globalIgnores } from 'eslint/config'
import nextVitals from 'eslint-config-next/core-web-vitals'
import nextTs from 'eslint-config-next/typescript'

export default defineConfig([
  ...nextVitals,
  ...nextTs,
  globalIgnores(['.next/**', 'out/**', 'build/**', 'dist/**', 'node_modules/**', 'next-env.d.ts']),
])
JS
  else
    install_compatible "$dir" typescript-eslint eslint @eslint/js typescript || die "could not resolve a compatible set"
    cat > "$dir/eslint.config.mjs" <<'JS'
// Generated by cecom js_checks.sh — typescript-eslint recommended (typescript-eslint.io/getting-started).
import { defineConfig, globalIgnores } from 'eslint/config'
import js from '@eslint/js'
import tseslint from 'typescript-eslint'

export default defineConfig([
  js.configs.recommended,
  ...tseslint.configs.recommended,
  globalIgnores(['dist/**', 'build/**', 'out/**', 'coverage/**', 'node_modules/**']),
])
JS
  fi
  (cd "$dir" && npm ls --depth=0 --json 2>/dev/null) | python3 -c "
import json,sys
d=json.load(sys.stdin).get('dependencies',{})
print('\n'.join(k + '@' + str(v.get('version')) for k,v in sorted(d.items())))" > "$dir/versions.txt"
  echo "Resolved: $(tr '\n' ' ' < "$dir/versions.txt")"
  echo "Verifying registry signatures and provenance:"
  (cd "$dir" && npm audit signatures 2>&1 | tail -6)
  (cd "$dir" && npm audit signatures >/dev/null 2>&1) || { rm -f "$dir/versions.txt"; die "signature verification failed — sandbox disabled"; }
}

cmd_lint() {
  local d="${1:-}" out=""; shift || true
  [ -n "$d" ] && [ -d "$d" ] || die "usage: js_checks.sh lint <project-dir> --out <file>"
  while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift ;; esac; shift; done
  [ -n "$out" ] || die "--out is required"
  d="$(cd "$d" && pwd)"
  local mode rc; mode=$(lint_mode "$d")
  case "$mode" in
    project)
      (cd "$d" && ./node_modules/.bin/eslint . --format json --no-warn-ignored > "$out" 2>"$out.stderr"); rc=$? ;;
    sandbox-next|sandbox-ts)
      local kind="${mode#sandbox-}" sb="$CACHE/${mode#sandbox-}"
      [ -f "$sb/versions.txt" ] || die "sandbox not prepared: run 'js_checks.sh prepare $kind' (downloads — ask the user first)"
      (cd "$d" && "$sb/node_modules/.bin/eslint" --config "$sb/eslint.config.mjs" --format json --no-warn-ignored . \
         > "$out" 2>"$out.stderr"); rc=$? ;;
    none) die "nothing to lint (no ESLint config, no Next.js, no tsconfig.json)" ;;
  esac
  [ "$rc" -le 1 ] && [ -s "$out" ] || { cat "$out.stderr" >&2; die "eslint failed to run (exit $rc)"; }
  python3 - "$out" "$mode" <<'PY'
import json, sys
res = json.load(open(sys.argv[1]))
files = len(res); errs = sum(r.get("errorCount", 0) for r in res); warns = sum(r.get("warningCount", 0) for r in res)
rules = {}
for r in res:
    for m in r.get("messages", []):
        k = m.get("ruleId") or "parse-error"
        rules[k] = rules.get(k, 0) + 1
print(f"mode: {sys.argv[2]}  files: {files}  errors: {errs}  warnings: {warns}")
for k, v in sorted(rules.items(), key=lambda x: -x[1])[:15]:
    print(f"  {v:5}  {k}")
PY
}

cmd_typecheck() {
  local d="${1:-}" out=""; shift || true
  [ -n "$d" ] && [ -d "$d" ] || die "usage: js_checks.sh typecheck <project-dir> --out <file>"
  while [ $# -gt 0 ]; do case "$1" in --out) out="$2"; shift ;; esac; shift; done
  [ -n "$out" ] || die "--out is required"
  d="$(cd "$d" && pwd)"
  case "$(typecheck_mode "$d")" in
    project) ;;
    uncertain) echo "uncertain: dependencies are not installed; a type check would only report missing modules (record AIGEN-003 as UNCERTAIN)"; return 0 ;;
    none) die "no tsconfig.json" ;;
  esac
  local rc n
  (cd "$d" && ./node_modules/.bin/tsc --noEmit --pretty false -p tsconfig.json > "$out" 2>&1); rc=$?
  n=$(grep -c 'error TS' "$out" || true)
  echo "tsc $("$d/node_modules/.bin/tsc" --version) exit=$rc errors=$n  (output: $out)"
}

case "${1:-}" in
  plan) shift; cmd_plan "$@" ;;
  prepare) shift; cmd_prepare "$@" ;;
  lint) shift; cmd_lint "$@" ;;
  typecheck) shift; cmd_typecheck "$@" ;;
  *) sed -n '4,7p' "$0" | sed 's/^# *//'; exit 2 ;;
esac
