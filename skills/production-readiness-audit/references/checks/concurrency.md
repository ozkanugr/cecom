# Concurrency & idempotency (CONC, IDEM)

The single most useful question for AI-generated code: **"What happens if this runs twice — at the same time, or out of order?"**

## CONC — races

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| CONC-001 | Submit actions can't be triggered twice by a fast double tap/click (button disabled while pending, or the handler is idempotent) | submit handlers, `isLoading` guards, `onPress` | P1 | client |
| CONC-002 | The same request isn't started twice by re-renders or effects (deduplication, query keys, `useEffect` deps) | data-fetch effects, `onAppear`, `LaunchedEffect` | P2 | client |
| CONC-003 | Two async operations writing the same state don't silently clobber each other; last-write-wins is intentional or guarded | stores/reducers updated from async callbacks | P2 | client |
| CONC-004 | Out-of-order responses can't overwrite newer state (search "a" returns after "ab"): cancel previous, or compare a request id/sequence | search/autocomplete, filters, pagination | P2 | client |
| CONC-005 | Callbacks from a previous session (before logout or account switch) can't mutate the new session's state (session generation/token check, cancellation on logout) | auth store, in-flight request handling on logout | P1 | client |
| CONC-006 | Async work completing after the screen/component is gone doesn't update it or crash (cancellation, `isMounted`, `[weak self]`, lifecycle-scoped coroutines) | `setState` after await, closures capturing `self` | P2 | client |
| CONC-007 | Shared mutable state accessed from several threads/tasks is protected (actors, `@MainActor`, `Mutex`, locks, serial queues); UI is updated only on the main thread | singletons, caches, managers; Swift 6 strict concurrency warnings | P1 | mobile, api |
| CONC-008 | Server read-modify-write on counters, balances, stock and quotas is atomic (`UPDATE … SET x = x - 1 WHERE x > 0`, row locks, optimistic version columns) — not read in code, then write back | balance/inventory/credit updates, ORM `save()` after read | P0 | api, db |
| CONC-009 | Concurrent edits to the same record are detected (version/ETag, `If-Match`) where losing an update matters | update endpoints for shared documents | P2 | api |
| CONC-010 | Scheduled jobs and workers can't overlap with themselves (distributed lock, lease, unique job id) | cron jobs, queue consumers, serverless schedules | P1 | api |
| CONC-011 | Check-then-act sequences (`if not exists: insert`) are replaced by constraints or atomic upserts | uniqueness checks in code before insert | P1 | api, db |

## IDEM — duplicate operations

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| IDEM-001 | Charges and payment intents carry an idempotency key generated once per user intent and reused on retry, end to end (client → server → payment provider) | Stripe `idempotencyKey`, payment endpoints | P0 | pay |
| IDEM-002 | Purchase restore, receipt processing and subscription renewal handling are idempotent (keyed by transaction id) | StoreKit/Play Billing handlers, RevenueCat webhooks | P0 | pay |
| IDEM-003 | Creating orders/resources on retry can't create duplicates (idempotency key or natural unique constraint) | create endpoints, client retry paths | P1 | api |
| IDEM-004 | Webhooks are deduplicated by event id (processed-events table or unique constraint) and tolerate out-of-order delivery | webhook handlers | P0 | api |
| IDEM-005 | Background jobs can run twice safely (at-least-once delivery) | job handlers, queue consumers | P1 | api |
| IDEM-006 | Emails, SMS and push sends aren't repeated on retry (outbox pattern or sent-marker) | notification senders | P2 | api |
| IDEM-007 | Push token registration is an upsert per device, not an insert | token registration endpoint | P2 | push |
| IDEM-008 | Analytics events that drive business decisions (purchases, signups) are deduplicated | analytics calls on mount/retry | P3 | client |
