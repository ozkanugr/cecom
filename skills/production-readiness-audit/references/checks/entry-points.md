# Push notifications & deep links (PUSH, LINK)

Both are external entry points: someone else decides when they arrive and what they contain. Treat their payloads as untrusted input.

## PUSH — push notifications

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| PUSH-001 | Token refreshes (APNs device token change, FCM `onNewToken`) are sent to the backend | token callbacks | P1 | push |
| PUSH-002 | Stale tokens are removed: invalid-token responses from APNs/FCM delete the token server-side | push sender error handling | P2 | push |
| PUSH-003 | Token registration is an upsert per device and user (no duplicate rows → duplicate notifications) | registration endpoint, unique constraint | P2 | push |
| PUSH-004 | On logout or account switch the token is unlinked from the old user, so their notifications don't reach the next user of the device | logout flow | P0 | push |
| PUSH-005 | The app works fully when notification permission is denied, and doesn't re-prompt repeatedly | permission request flow | P2 | push |
| PUSH-006 | Permission granted later in system Settings is detected (re-check on foreground) and the token registered | foreground handler | P3 | push |
| PUSH-007 | Foreground presentation is defined (show banner, in-app UI, or silent) | `willPresent`, foreground message handler | P3 | push |
| PUSH-008 | Missing, malformed or older-version payloads don't crash the app | payload parsing | P1 | push |
| PUSH-009 | Notification taps route through the same validated deep-link handler (LINK checks apply) | tap handler | P1 | push |
| PUSH-010 | Server-side sending is idempotent and rate-limited; failures are logged and measured | send pipeline | P2 | push |

## LINK — deep links and routing

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| LINK-001 | Link parameters are untrusted input: validated, and they can't bypass authorization or load arbitrary URLs in a WebView (open redirect) | link handlers, WebView URL params, `redirect=` params | P0 | client |
| LINK-002 | Missing parameters lead to a safe fallback, not a crash | `params.id!`, route param parsing | P1 | client |
| LINK-003 | Parameters of the wrong type or format are rejected | numeric/UUID parsing | P1 | client |
| LINK-004 | Percent-encoding is decoded exactly once | URL parsing helpers | P2 | client |
| LINK-005 | Unknown routes and unknown parameters go to a fallback screen | router config, catch-all routes | P2 | client |
| LINK-006 | A protected route opened while logged out leads to login and then continues to the target | auth guard, pending-link storage | P1 | client |
| LINK-007 | Links work both on cold start and while the app is in the background | launch options/initial URL handling vs runtime handler | P1 | mobile |
| LINK-008 | The same link arriving twice doesn't duplicate actions or screens | link dedupe | P3 | client |
| LINK-009 | Navigation stack stays sane after a link (back goes somewhere sensible; no stacked duplicates) | navigation reset/push logic | P3 | client |
| LINK-010 | Universal Links / App Links are verified (`apple-app-site-association`, `assetlinks.json`); auth callbacks don't rely on hijackable custom URL schemes | associated domains, intent filters with `autoVerify` | P1 | mobile |
