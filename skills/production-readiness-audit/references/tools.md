# Audit tools

Tools the audit may run to collect evidence. None are bundled with the plugin. Use what is installed; when a tool is missing, get the user's approval before downloading it, then use the latest stable release from its official source and record the version in the finding (`evidence[].cmd`).

Versions below are from the scan on 2026-10-06. They are a snapshot, not a pin: before installing, check the current release (`brew info <formula>`, `npm view <pkg> version`, PyPI).

## Rules

1. **Ask before any download.** Nothing is installed or fetched without the user's approval, including ephemeral runners (`npx --yes`, `uvx`) that download into a cache.
2. **Latest stable release from the official source** — no release candidates, nightlies, forks, or unofficial taps.
3. **Verify what you install.** Prefer Homebrew bottles (Homebrew checks each bottle's SHA-256). For direct downloads, check the published checksum and, where offered, the signature or provenance. For npm and PyPI packages, check registry signatures/provenance (`npm audit signatures`, PyPI attestations).
4. **Latest *compatible*, not just latest.** Plugins lag behind majors: on 2026-10-06 `eslint-plugin-react`, `-import` and `-jsx-a11y` did not yet accept ESLint 10, and `typescript-eslint` required TypeScript < 6.1 while TypeScript 7.0 was out. Resolve versions against peer dependencies (`npm install --strict-peer-deps`, stepping a major back on conflicts — `js_checks.sh prepare` does this) instead of forcing `@latest`.
5. **Pin the resolved version in the command** (`npx --yes dependency-cruiser@18.5.0 …`, `uvx pip-audit==2.10.1 …`) so the run is reproducible, and record it in the finding.
6. **Never install into the audited project.** No `npm install --save-dev`, no edits to the project's lockfiles or manifests. Use system tools, Homebrew, or ephemeral runners.
7. **Keep data local.** Disable telemetry where a tool has it (`semgrep --metrics=off`). Don't use features that send code or secrets to third parties (e.g. TruffleHog's live secret verification calls provider APIs — leave it off unless the user agrees).

## Core tools

| Tool | Used for | Checks | Version (scan) | Install / run | Verification |
|---|---|---|---|---|---|
| ripgrep (`rg`) | All code searches | all | 15.2.0 | `brew install ripgrep` | SHA-256 per release asset; Homebrew bottle |
| Gitleaks | Secrets in files and Git history | SEC-002, SEC-019 | 8.30.1 | `brew install gitleaks` → `gitleaks git --no-banner --redact` (history) and `gitleaks dir . --no-banner --redact` (working tree; use this too for shallow clones) | `checksums.txt`; Homebrew bottle |
| TruffleHog | Second opinion on secrets, many detectors | SEC-002 | 3.98.0 | `brew install trufflehog` → `trufflehog git file://. --no-verification` | checksums + Sigstore signature; Homebrew bottle |
| OSV-Scanner | Known-vulnerable dependencies: JS, Python, Java/Gradle, Dart, Go, Rust and more | SUPPLY-003 | 2.6.0 | `brew install osv-scanner` → `osv-scanner scan source -r .` | `SHA256SUMS` + in-toto provenance; Homebrew bottle |
| npm audit | Vulnerable npm dependencies | SUPPLY-003 | ships with npm | `npm audit --omit=dev` (read-only; never `npm audit fix` during an audit) | — |
| pip-audit | Vulnerable Python dependencies | SUPPLY-003 | 2.10.1 | `brew install pip-audit` or `uvx pip-audit==<ver>` | PyPI attestations; Homebrew bottle |
| Semgrep CE | Static analysis for injection, XSS, SSRF, path traversal, crypto misuse | SEC-005, SEC-006, SEC-008, SEC-009, SEC-022 | 1.179.0 | `brew install semgrep` → `semgrep scan --metrics=off --config p/owasp-top-ten --config p/secrets` | PyPI attestations; Homebrew bottle |
| SwiftLint | Force unwraps, `try!`, unsafe patterns in Swift | AIGEN-004, CONTRACT-008 | 0.65.1 | `brew install swiftlint` → `swiftlint lint --reporter json` (read-only; never `--fix`) | Homebrew bottle |
| dependency-cruiser | Circular deps and layer rules (JS/TS) | ARCH-003, ARCH-006 | 18.5.0 | `npx --yes dependency-cruiser@<ver> --no-config --output-type err src` | npm SLSA provenance + registry signature |
| Knip | Unused files, exports and dependencies (JS/TS) | AIGEN-009, SUPPLY-004 | 6.39.0 | `npx --yes knip@<ver> --no-progress` | npm registry signature |
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

## Known gaps

- **Apple dependency vulnerabilities.** OSV-Scanner does not read CocoaPods `Podfile.lock` or Swift Package Manager `Package.resolved`. For SPM projects hosted on GitHub, use the Dependabot alerts of the dependency graph; for CocoaPods, review each pod's advisories and `pod outdated` by hand. Without one of these, mark SUPPLY-003 `UNCERTAIN` and say why.
- **Mobile binary analysis** (MASVS-RESILIENCE: tampering, reverse engineering, jailbreak detection) is out of scope for this source-code audit. MobSF (4.5.3, runs in Docker) can analyze an `.ipa`/`.apk` if the user wants that separately.

## Not audit tools

Playwright, Cypress, Detox, Maestro, XCUITest, Espresso, k6, Artillery, Locust, Gatling, Lighthouse CI, size-limit and Testcontainers appear in checks because the **audited project** is expected to use them. The audit looks for their configuration; it does not install them.

## Test target: OWASP iGoat-Swift

A deliberately vulnerable iOS app, used to measure whether the audit finds known iOS weaknesses.

| Property | Value (scan) |
|---|---|
| Source | `github.com/OWASP/iGoat-Swift`, branch `master` |
| Last commit | `8c8a8ed`, 2025-12-29, "Support for iOS 26.x" |
| License | GPL-3.0 — keep it outside the plugin; clone on demand into `~/.cache/cecom/fixtures/` |
| Size | ~433 files, 66 Swift files, CocoaPods (`Podfile`, `Podfile.lock`; pods not vendored) |
| Static audit | No build needed; building would require `pod install` |
| Expected findings | `evals/igoat-swift/expected.json`; score with `scripts/eval_fixture.py` |
| Last result | 2026-10-06, catalog of 331 checks: detected 24/24, located 23/24, 1 flagged UNCERTAIN at the right place (S3 bucket policy is outside the repo). Pre-registered score before ground-truth corrections: located 20/24. |
