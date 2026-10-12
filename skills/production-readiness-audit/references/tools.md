# Audit tools

Tools the audit may run to collect evidence. None are bundled with the plugin. Use what is installed; when a tool is missing, get the user's approval before downloading it, then use the latest stable release from its official source and record the version in the finding (`evidence[].cmd`).

Versions below are from the scan on 2026-10-06. They are a snapshot, not a pin: before installing, check the current release (`brew info <formula>`, `npm view <pkg> version`, PyPI).

## Rules

1. **Ask before any download.** Nothing is installed or fetched without the user's approval, including ephemeral runners (`npx --yes`, `uvx`) that download into a cache.
2. **Latest stable release from the official source** — no release candidates, nightlies, forks, or unofficial taps.
3. **Verify what you install.** Prefer Homebrew bottles (Homebrew checks each bottle's SHA-256). For direct downloads, check the published checksum and, where offered, the signature or provenance. For npm and PyPI packages, check registry signatures/provenance (`npm audit signatures`, PyPI attestations).
4. **Latest *compatible*, not just latest.** Plugins lag behind majors: on 2026-10-06 `eslint-plugin-react`, `-import` and `-jsx-a11y` did not yet accept ESLint 10, and `typescript-eslint` required TypeScript < 6.1 while TypeScript 7.0 was out. Resolve versions against peer dependencies (`npm install --strict-peer-deps`, stepping a major back on conflicts — `js_checks.sh prepare` does this) instead of forcing `@latest`.
5. **Pin the resolved version in the command** (`npx --yes dependency-cruiser@18.5.0 …`, `uvx --from import-linter==2.15 lint-imports`) so the run is reproducible, and record it in the finding.
6. **Never install into the audited project.** No `npm install --save-dev`, no edits to the project's lockfiles or manifests. Use system tools, Homebrew, or ephemeral runners.
7. **Keep data local.** Disable telemetry where a tool has it. Don't use features that send code or secrets to third parties unless the user agrees.

## Core tools

| Tool | Used for | Checks | Version (scan) | Install / run | Verification |
|---|---|---|---|---|---|
| ripgrep (`rg`) | All code searches | all | 15.2.0 | `brew install ripgrep` | SHA-256 per release asset; Homebrew bottle |
| SwiftLint | Force unwraps, `try!`, unsafe patterns in Swift | AIGEN-004, CONTRACT-008 | 0.65.1 | `brew install swiftlint` → `swiftlint lint --reporter json` (read-only; never `--fix`) | Homebrew bottle |
| dependency-cruiser | Circular deps and layer rules (JS/TS) | ARCH-003, ARCH-006 | 18.5.0 | `npx --yes dependency-cruiser@<ver> --no-config --output-type err src` | npm SLSA provenance + registry signature |
| Knip | Unused files, exports and dependencies (JS/TS) | AIGEN-009 | 6.39.0 | `npx --yes knip@<ver> --no-progress` | npm registry signature |
| import-linter | Layer and dependency rules (Python; needs the project's import-linter contracts) | ARCH-003, ARCH-006 | 2.15 | `uvx --from import-linter==<ver> lint-imports` | PyPI |
| ESLint + Next.js config | Lint for Next.js apps: React, React Hooks and Next.js rules, core-web-vitals as errors, plus TypeScript rules; 6 jsx-a11y rules as warnings | AIGEN-003, AIGEN-004, CONC-002, CONC-006, LIFE-008, PERF-002, PERF-015, A11Y-010 (partial), A11Y-001 (partial) | eslint 9.39.5 + eslint-config-next 16.3.8 + next 16.3.8 + react 19.3.0 + typescript 6.0.3 (newest compatible set on 2026-10-06; eslint 10 conflicted with the react/import/jsx-a11y plugins, TypeScript 7 with typescript-eslint). `next` is required because eslint-config-next parses with the Babel parser bundled in `next`; the sandbox is ~440 MB | `js_checks.sh plan` → `prepare next` (sandbox in `~/.cache/cecom/tools/js-lint/next/`) → `lint <dir> --out` | eslint-config-next: npm SLSA provenance; all: `npm audit signatures` |
| ESLint + typescript-eslint | Lint for non-Next TypeScript projects (`recommended`) | AIGEN-003, AIGEN-004 | eslint 10.12.0 + @eslint/js 10.0.1 + typescript-eslint 8.71.1 + typescript 6.0.3 (typescript-eslint needs TypeScript < 6.1); ~45 MB | `js_checks.sh prepare ts` → `lint` | npm SLSA provenance; `npm audit signatures` |
| TypeScript (`tsc`) | Type check with the project's own compiler and dependencies | AIGEN-003, AIGEN-014 | project's version | `js_checks.sh typecheck <dir> --out` — needs the project's `node_modules`; otherwise UNCERTAIN, never install into the project | — |
| Xcode (`xcodebuild`) | Build and tests for Apple projects | AIGEN-003, TQ-005 | Xcode 27.0 (installed) | `xcodebuild -list`, then `build`/`test` for the main scheme | Apple-signed |

Verified on 2026-10-06 with deliberately flawed fixtures: the Next.js sandbox reported `no-img-element`, `alt-text`, `exhaustive-deps`, `rules-of-hooks`, `no-async-client-component` and `no-explicit-any` with file and line (a line silenced by `eslint-disable` was not reported — AIGEN-004 finds the suppression itself); the TypeScript sandbox reported `no-explicit-any`; `typecheck` reported `TS2322` with file and line. Prepared sandboxes passed `npm audit signatures` (Next: 340 signatures, 78 attestations; TS: 96 signatures, 30 attestations).

## Replaced tools

| Tool | Status | Use instead |
|---|---|---|
| madge | No release since 2024-08 | dependency-cruiser |
| ts-prune | No release since 2022 | Knip |
| depcheck | Repository archived (2025-02) | Knip |

## Security scanning

Secret scanning, dependency-vulnerability scanning and static security analysis (gitleaks, TruffleHog, Semgrep, OSV-Scanner, npm audit, pip-audit) are not part of this audit. Use the separate `security-audit` skill for vulnerability review.

## Not audit tools

Playwright, Cypress, Detox, Maestro, XCUITest, Espresso, k6, Artillery, Locust, Gatling, Lighthouse CI, size-limit and Testcontainers appear in checks because the **audited project** is expected to use them. The audit looks for their configuration; it does not install them.
