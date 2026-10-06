# Security & supply chain (SEC, SUPPLY)

Includes the misconfigurations that AI-generated and tutorial-derived code ships most often: secrets in the client, open database rules, debug endpoints left on.

## SEC — application security

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| SEC-001 | No privileged secrets in the client bundle or app binary (service-role keys such as Supabase `service_role`, Firebase Admin credentials, OpenAI/Stripe secret keys, DB URLs). Publishable keys are fine only if restricted (bundle id/referrer, scoped permissions) | client code, `.env` vars exposed to client (`NEXT_PUBLIC_`, `EXPO_PUBLIC_`, `VITE_`), Info.plist, `google-services.json` restrictions | P0 | client |
| SEC-002 | No secrets are committed — now or in Git history; `.env` files are git-ignored and not tracked | `git ls-files \| rg -i "\.env"`, `gitleaks detect`, `git log -p -S "sk_"` | P0 | all |
| SEC-003 | Database/BaaS access rules are not open: Supabase RLS enabled on every table with real policies, Firebase/Firestore/Storage rules not `allow read, write: if true`, no public buckets for private files | `supabase/migrations`, `firestore.rules`, `storage.rules`, bucket policies | P0 | api, db |
| SEC-004 | Every endpoint validates input server-side against a schema (types, lengths, ranges, formats) | validators at handler entry | P1 | api |
| SEC-005 | No injection: SQL is parameterized — on the server and in on-device SQLite/Core Data predicates (`sqlite3_prepare` with bound parameters, `NSPredicate` with arguments, never string-built `executeSQL`) — no NoSQL operator injection (`$where`, `$ne` from JSON bodies), no shell commands built from input, no template injection | raw queries, string-built SQL, `exec(`, `child_process`, `subprocess(..., shell=True)`, `sqlite3_exec`, `NSPredicate(format:` with interpolation | P0 | all |
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
| SEC-020 | Passwords are hashed with a current password-hashing function — Argon2id preferred, otherwise scrypt or bcrypt with current cost parameters (OWASP Password Storage Cheat Sheet) — never MD5/SHA-x alone or reversible encryption; or authentication is delegated to a maintained identity provider | password storage code, `createHash(`, `hashlib.sha256(`, `CC_SHA256` near passwords | P0 | api |
| SEC-021 | Tokens, reset codes, session ids and nonces come from a cryptographically secure generator (`crypto.randomBytes`/`randomUUID`, Python `secrets`, `SecRandomCopyBytes`, `SecureRandom`), never `Math.random`/`random`; reset and OTP codes expire and are single-use | token/code generation | P0 | all |
| SEC-022 | Cryptography uses vetted libraries and current algorithms (AES-GCM or ChaCha20-Poly1305, TLS 1.2+ with 1.3 preferred); no home-made crypto, no ECB mode, no hard-coded keys or IVs | `createCipheriv`, `CryptoKit`/`CommonCrypto`, `javax.crypto.Cipher`, key literals | P1 | all |
| SEC-023 | Security-relevant events go to an audit log the actor can't edit (sign-ins and failures, password/email changes, role and permission changes, data exports, admin actions), without secrets or unnecessary personal data | audit log table/service | P2 | api |
| SEC-024 | Session cookies use `Secure`, `HttpOnly` and `SameSite`; sessions rotate on sign-in, expire on inactivity, and sign-out invalidates the server-side session | cookie and session configuration | P1 | web, api |
| SEC-025 | Screens showing sensitive data are hidden from the app-switcher snapshot and, where needed, from screen recording (cover or blur on `sceneWillResignActive`; Android `FLAG_SECURE`) | scene/app delegate lifecycle, `UIScreen.isCaptured`, window flags | P2 | mobile |
| SEC-026 | Sensitive values aren't left on the general pasteboard: copying is disabled on secret fields, or items are local-only and expiring (`UIPasteboard` `.localOnly`/`.expirationDate`; Android `ClipDescription.EXTRA_IS_SENSITIVE`) | `UIPasteboard.general`, `ClipboardManager`, copy actions on sensitive fields | P2 | mobile |
| SEC-027 | Sensitive text inputs aren't cached by the keyboard: secrets use secure entry, other sensitive fields disable autocorrection and suggestions (`isSecureTextEntry`, `autocorrectionType = .no`, `.textContentType`; Android `textPassword`/`textNoSuggestions`) | text fields for passwords, PINs, card numbers, personal data | P2 | mobile |
| SEC-028 | Keychain items use a restrictive accessibility class (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` or `…AfterFirstUnlockThisDeviceOnly`), never `kSecAttrAccessibleAlways*`; Android Keystore keys are non-exportable and hardware-backed where available | `SecItemAdd`/`SecItemUpdate` attributes, keychain wrapper config, `KeyGenParameterSpec` | P1 | mobile |

## SUPPLY — dependencies

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| SUPPLY-001 | A lockfile is committed and CI installs from it (`npm ci`, `pnpm install --frozen-lockfile`, `pip install -r` with pins/hashes) | lockfiles, CI install step | P1 | all |
| SUPPLY-002 | Every dependency is the intended, real package: names checked against the registry (AI tools hallucinate package names that attackers then register), publisher and download counts plausible | `package.json`, `requirements.txt`, `Podfile`, `build.gradle`, `pubspec.yaml` | P0 | all |
| SUPPLY-003 | Known vulnerabilities are scanned (`npm audit`, `pip-audit`, `osv-scanner`, Dependabot) and high/critical ones addressed | run the scanner; CI config | P1 | all |
| SUPPLY-004 | Unused dependencies are removed (smaller attack surface and bundle) | `knip`, imports vs manifest | P3 | all |
| SUPPLY-005 | Dependency licenses are compatible with how the product is distributed | license checker output | P2 | all |
| SUPPLY-006 | CI actions and container base images are pinned (version or digest), not `@main`/`latest` | `.github/workflows`, `Dockerfile` | P2 | all |

## Standards mapping

Use this to answer "does the audit cover OWASP?". The mapping is by intent; a full OWASP ASVS (web/API) or MASVS (mobile) verification has more requirements than this catalog.

**OWASP Top 10:2025**

| Category | Checks |
|---|---|
| A01 Broken Access Control | AUTH-001, AUTH-002, AUTH-003, AUTH-011, SEC-003, LINK-001, SCALE-009 |
| A02 Security Misconfiguration | SEC-012, SEC-013, SEC-016, CONF-001, CONF-003, CONF-004, CONF-005, AIGEN-007, NET-015 |
| A03 Software Supply Chain Failures | SUPPLY-001 … SUPPLY-006 |
| A04 Cryptographic Failures | SEC-020, SEC-021, SEC-022, SEC-011, AUTH-006, NET-015 |
| A05 Injection | SEC-005, SEC-006, SEC-009, LLM-003 |
| A06 Insecure Design | DOMAIN-001 … DOMAIN-003, CONC-008, IDEM-001 … IDEM-004, MONEY-003, TIME-005 |
| A07 Authentication Failures | AUTH-004 … AUTH-010, AUTH-012, SEC-024 |
| A08 Software or Data Integrity Failures | SEC-017, SEC-018, SUPPLY-002, SUPPLY-006, CONTRACT-009 |
| A09 Security Logging and Alerting Failures | SEC-023, SEC-019, OBS-001, OBS-006, ERR-001 |
| A10 Mishandling of Exceptional Conditions | ERR-001 … ERR-010, NET-001, LIFE-009 |

**OWASP Top 10 for LLM Applications** — LLM-001 … LLM-007, PRIV-010.

**OWASP MASVS (mobile)**

| Group | Checks |
|---|---|
| MASVS-STORAGE | AUTH-006, SEC-011, SEC-028, PRIV-005 |
| MASVS-CRYPTO | SEC-021, SEC-022 |
| MASVS-AUTH | AUTH-004 … AUTH-011 |
| MASVS-NETWORK | NET-015 |
| MASVS-PLATFORM | SEC-007, SEC-025, SEC-026, SEC-027, LINK-001, LINK-010, PUSH-009 |
| MASVS-CODE | SUPPLY-001 … SUPPLY-003, REL-002, AIGEN-004 |
| MASVS-RESILIENCE | Not covered: tampering, reverse engineering and runtime-manipulation resistance need binary analysis, which is outside this source-code audit (see `references/tools.md`) |
| MASVS-PRIVACY | PRIV-001 … PRIV-015 |
