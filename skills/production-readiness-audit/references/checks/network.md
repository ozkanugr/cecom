# Networking & offline (NET)

Every network call can be slow, fail, succeed twice, or succeed after the user has moved on.

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| NET-001 | No crash or blank screen without connectivity; offline is shown to the user and recoverable | network error handling, reachability/`NWPathMonitor`, `navigator.onLine` | P1 | client |
| NET-002 | Every request has an explicit timeout (connect and total), set on the shared client, not only at some call sites | `axios.create`, `fetch` + `AbortSignal.timeout`, `URLSessionConfiguration.timeoutIntervalForRequest`, OkHttp timeouts, `requests` `timeout=` | P1 | all |
| NET-003 | Retries are bounded (maximum attempts); no infinite retry or reconnect loop | retry helpers, `while (true)` around requests, query library `retry` config | P1 | all |
| NET-004 | Retries use exponential backoff with jitter | retry delay computation | P2 | all |
| NET-005 | Only idempotent requests are retried automatically, or requests carrying an idempotency key; POST/payment requests are never blindly retried | retry interceptors, offline replay | P0 | all |
| NET-006 | Retry policy by status is deliberate: network errors, 408, 5xx retried (bounded); other 4xx not retried | retry predicates | P2 | all |
| NET-007 | 429 and 503 honour `Retry-After` | retry logic, rate-limit handling | P2 | all |
| NET-008 | On 401, token refresh is single-flight: concurrent requests wait for one refresh and then replay; a failed refresh logs out once | auth interceptor, refresh promise/mutex | P1 | client |
| NET-009 | 401 (not authenticated) and 403 (not allowed) are handled differently; 403 doesn't trigger refresh or a logout loop | interceptor status branches | P1 | client |
| NET-010 | 404 and empty results are treated by meaning (expected "not found" vs error) | not-found handling | P3 | client |
| NET-011 | In-flight requests are cancelled when the screen/component goes away or the query changes | `AbortController`, `Task` cancellation, coroutine scopes, query keys | P2 | client |
| NET-012 | Offline writes (if supported) go to a persisted, ordered, bounded queue; each item carries an idempotency key so replay can't duplicate | offline queue, sync engine | P1 | client |
| NET-013 | Reconnecting doesn't release every queued/retried request at once (concurrency limit, throttling) | queue flush logic | P2 | client |
| NET-014 | Slow network: loading states are shown, actions can't be submitted twice, partial/late responses are handled | loading flags, submit buttons | P2 | client |
| NET-015 | TLS everywhere; no cleartext exceptions in production (`NSAllowsArbitraryLoads`, `usesCleartextTraffic`, `cleartextTrafficPermitted`) and certificate validation is never disabled (`rejectUnauthorized: false`, `verify=False`, trust-all managers) | Info.plist, network security config, HTTP client options | P0 | all |
| NET-016 | Large uploads/downloads have size limits and are chunked or resumable | upload code, multipart config | P3 | all |
| NET-017 | Server-side outbound calls to third parties have timeouts, bounded retries and a fallback or circuit breaker for non-critical dependencies | server HTTP clients, SDK configs | P1 | api |
