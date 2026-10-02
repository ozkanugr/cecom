# Authentication, session & authorization (AUTH)

Authentication answers *who are you*; authorization answers *what may you do*. AI-generated code most often gets the second wrong: it hides buttons in the UI and trusts the client.

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| AUTH-001 | Authorization is enforced server-side on every protected operation, at the object level: the server checks that *this* user may access *this* record (no IDOR) | route handlers, resolvers, RLS policies; endpoints taking `:id` | P0 | api |
| AUTH-002 | The server never trusts a client-sent `userId`, `role`, `tenantId` or `isAdmin`; identity comes from the verified session/token | request bodies/params used for identity | P0 | api |
| AUTH-003 | Every route/function is covered by an auth check; list all routes and confirm none is unintentionally public (including serverless functions and RPCs) | router files, middleware order, `functions/`, Supabase RPC | P0 | api |
| AUTH-004 | Tokens are verified server-side: signature, algorithm pinned (no `none`, no HS/RS confusion), `exp`, `iss`, `aud` | JWT verify calls, auth middleware | P0 | api |
| AUTH-005 | OAuth/OIDC flows use `state` and PKCE, and redirect URIs are allow-listed | OAuth callbacks, auth SDK config | P0 | api, client |
| AUTH-006 | Tokens are stored in secure storage (Keychain, Android Keystore/EncryptedSharedPreferences, httpOnly secure cookies) — not `localStorage`, `UserDefaults`, `AsyncStorage`, plain `SharedPreferences` | token persistence code | P1 | client |
| AUTH-007 | A locally present token with a dead server session (revoked, expired, user deleted) is detected and leads to a clean logout, not a loop or a half-logged-in UI | 401 handling, app start auth check | P1 | client |
| AUTH-008 | A valid server session with missing/corrupt local credentials leads to a clean re-auth path | app start, secure storage read errors | P2 | client |
| AUTH-009 | Access-token expiry is handled (proactive refresh or single-flight refresh on 401 — see NET-008); refresh-token expiry or revocation logs the user out with a clear message | auth interceptor | P1 | client |
| AUTH-010 | Logout clears **all** local user state: tokens, query/HTTP caches, local DB, files, in-memory stores, web storage, cookies, cached images of private content | logout function vs every store the app writes | P1 | client |
| AUTH-011 | After an account switch, nothing from the previous user is shown: caches are keyed by user or cleared | cache keys, persisted stores | P0 | client |
| AUTH-012 | Password, OTP and login endpoints are rate-limited; responses don't reveal whether an account exists (enumeration) | auth endpoints, error messages | P1 | api |
| AUTH-013 | Account deletion revokes sessions and tokens server-side, unlinks push tokens, deletes or anonymizes data, and clears local data (also an App Store / Play requirement) | delete-account flow | P1 | all |
| AUTH-014 | Sessions on other devices are revocable; password change or account compromise invalidates them where expected | session store, refresh-token rotation | P3 | api |
| AUTH-015 | Privileged/admin actions require a fresh or step-up authentication and are audit-logged | admin endpoints | P2 | api |
