# Configuration, build & release (CONF, REL)

## CONF — configuration and environments

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| CONF-001 | Production builds point at production services only; no dev/staging/localhost URLs or keys can ship in a release build (and vice versa) | env files per build, build schemes/flavors, `localhost`, `10.0.2.2`, `ngrok` | P0 | all |
| CONF-002 | Configuration is validated at startup; a missing or malformed variable fails fast with a clear message | config loading, `process.env.X!`, schema validation of env | P1 | all |
| CONF-003 | No default or fallback secrets (`process.env.JWT_SECRET \|\| "secret"`, example keys from tutorials) | `\|\| "`, `?? "`, `getenv(..., "default")` near secrets | P0 | all |
| CONF-004 | Debug modes are off in production (`DEBUG=True`, verbose logging, React Native dev menu, Flipper, devtools, GraphQL playground) | framework settings, build configs | P0 | all |
| CONF-005 | Test accounts, mock data, seed users, sandbox payment keys and fake providers can't be active in production | seed scripts, mock flags, sandbox keys | P0 | all |
| CONF-006 | Environment-specific values come from configuration, not hard-coded literals or scattered `if (env === "prod")` branches | URL literals, environment conditionals | P2 | all |
| CONF-007 | Feature flags fail safe when the flag service is unreachable; risky features have a kill switch | flag defaults, remote config fallbacks | P2 | all |
| CONF-008 | Remote config values are validated before use | remote config parsing | P3 | client |

## REL — build and release

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| REL-001 | CI runs lint, type check, tests and a release build on every change; merges are blocked on failure | CI workflows, branch protection | P1 | all |
| REL-002 | Release builds behave like debug builds: minification/obfuscation (R8/ProGuard, Hermes, terser) doesn't break reflection, serialization or dynamic imports | keep rules, release-only crashes | P1 | client |
| REL-003 | Logging is reduced in release builds; no sensitive debug output | logger level by build type | P2 | client |
| REL-004 | Source maps and mapping files are uploaded privately, not publicly served | build output, hosting config | P2 | web |
| REL-005 | Signing, provisioning and entitlements are correct (push, associated domains, keychain sharing) | `.entitlements`, signing config | P1 | mobile |
| REL-006 | Version and build numbers increase every release, and the server can see the client version | version config, request headers | P2 | client |
| REL-007 | Fresh install works end to end | onboarding/first-run paths | P1 | client |
| REL-008 | Upgrading from the previous released version works with real persisted data (local DB, stored state, cached tokens) | migration code, upgrade testing | P0 | client |
| REL-009 | Uninstall/reinstall is handled (iOS Keychain survives reinstall: stale tokens must not log in a different context) | first-launch detection vs Keychain | P2 | mobile |
| REL-010 | A minimum supported app version can be enforced (forced/soft update) for breaking API changes | version gate endpoint, update prompt | P1 | mobile |
| REL-011 | Store requirements are met: privacy manifest, permission usage strings, in-app account deletion, required-reason APIs | Info.plist, `PrivacyInfo.xcprivacy`, deletion flow | P1 | mobile |
| REL-012 | A rollback path exists: server deploys can be rolled back; mobile releases use phased/staged rollout | deploy config, release process | P2 | all |
| REL-013 | Minimum OS versions and architectures are intentional and match the APIs used | deployment target, `minSdk`, availability checks | P3 | mobile |
