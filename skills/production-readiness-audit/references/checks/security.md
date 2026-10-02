# Security & supply chain (SEC, SUPPLY)

Includes the misconfigurations that AI-generated and tutorial-derived code ships most often: secrets in the client, open database rules, debug endpoints left on.

## SEC — application security

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| SEC-001 | No privileged secrets in the client bundle or app binary (service-role keys such as Supabase `service_role`, Firebase Admin credentials, OpenAI/Stripe secret keys, DB URLs). Publishable keys are fine only if restricted (bundle id/referrer, scoped permissions) | client code, `.env` vars exposed to client (`NEXT_PUBLIC_`, `EXPO_PUBLIC_`, `VITE_`), Info.plist, `google-services.json` restrictions | P0 | client |
| SEC-002 | No secrets are committed — now or in Git history; `.env` files are git-ignored and not tracked | `git ls-files \| rg -i "\.env"`, `gitleaks detect`, `git log -p -S "sk_"` | P0 | all |
| SEC-003 | Database/BaaS access rules are not open: Supabase RLS enabled on every table with real policies, Firebase/Firestore/Storage rules not `allow read, write: if true`, no public buckets for private files | `supabase/migrations`, `firestore.rules`, `storage.rules`, bucket policies | P0 | api, db |
| SEC-004 | Every endpoint validates input server-side against a schema (types, lengths, ranges, formats) | validators at handler entry | P1 | api |
| SEC-005 | No injection: SQL is parameterized, no NoSQL operator injection (`$where`, `$ne` from JSON bodies), no shell commands built from input, no template injection | raw queries, string-built SQL, `exec(`, `child_process`, `subprocess(..., shell=True)` | P0 | api |
| SEC-006 | No XSS/HTML/Markdown injection: output is escaped; `dangerouslySetInnerHTML`/`v-html`/`innerHTML` only with sanitized input; Markdown renderers sanitize | renderers, rich text, WebViews | P0 | client |
| SEC-007 | WebViews: JavaScript bridges are minimal, only trusted origins load, no arbitrary URL loading from untrusted input, file access disabled | `WKWebView`, `WebView`, `react-native-webview` props | P1 | mobile |
| SEC-008 | No SSRF: the server fetches user-supplied URLs only via an allow-list, blocking private ranges and cloud metadata (`169.254.169.254`) | URL fetchers, link previews, webhooks registration, image proxies | P0 | api |
| SEC-009 | No path traversal in file reads/writes/downloads; user-supplied file names are sanitized or replaced with generated ids | file paths built from input, `..` handling | P0 | api |
| SEC-010 | Uploads: type checked by content (magic bytes), size limited, stored outside the web root/private by default, served with safe content types | upload handlers, storage config | P1 | api |
| SEC-011 | Sensitive data on device is in secure storage or encrypted; nothing sensitive in plaintext local storage, logs or caches | local persistence | P1 | client |
| SEC-012 | Debug, admin, test and seed endpoints are disabled or protected in production | routes like `/debug`, `/admin`, `/seed`, `/test`, GraphQL introspection/playground | P0 | api |
| SEC-013 | CORS uses an allow-list; never `*` with credentials; never reflects the request `Origin` blindly | CORS middleware config | P1 | api |
| SEC-014 | Rate limiting on authentication, expensive, and abuse-prone endpoints (signup, SMS/email send, search, LLM calls) | rate-limit middleware, gateway config | P1 | api |
| SEC-015 | Cookie-authenticated state-changing requests are protected against CSRF (SameSite + token or origin check) | cookie settings, CSRF middleware | P1 | web, api |
| SEC-016 | Web responses send security headers: CSP, HSTS, `X-Content-Type-Options`, `frame-ancestors`/`X-Frame-Options`, `Referrer-Policy` | server/CDN/framework headers config | P2 | web |
| SEC-017 | Webhooks verify the provider signature over the raw body and reject stale timestamps | webhook handlers (Stripe, RevenueCat, GitHub…) | P0 | api |
| SEC-018 | In-app purchases and subscriptions are verified server-side (App Store Server API, Google Play Developer API, or a trusted provider); entitlements are never granted from a client claim | entitlement checks, receipt handling | P0 | pay |
| SEC-019 | Secrets and tokens never appear in logs, error reports, analytics or URLs (query strings end up in logs and referrers) | logging calls, URL construction | P1 | all |

## SUPPLY — dependencies

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| SUPPLY-001 | A lockfile is committed and CI installs from it (`npm ci`, `pnpm install --frozen-lockfile`, `pip install -r` with pins/hashes) | lockfiles, CI install step | P1 | all |
| SUPPLY-002 | Every dependency is the intended, real package: names checked against the registry (AI tools hallucinate package names that attackers then register), publisher and download counts plausible | `package.json`, `requirements.txt`, `Podfile`, `build.gradle`, `pubspec.yaml` | P0 | all |
| SUPPLY-003 | Known vulnerabilities are scanned (`npm audit`, `pip-audit`, `osv-scanner`, Dependabot) and high/critical ones addressed | run the scanner; CI config | P1 | all |
| SUPPLY-004 | Unused dependencies are removed (smaller attack surface and bundle) | `depcheck`/`knip`, imports vs manifest | P3 | all |
| SUPPLY-005 | Dependency licenses are compatible with how the product is distributed | license checker output | P2 | all |
| SUPPLY-006 | CI actions and container base images are pinned (version or digest), not `@main`/`latest` | `.github/workflows`, `Dockerfile` | P2 | all |
