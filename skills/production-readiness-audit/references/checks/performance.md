# Memory & performance (PERF)

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| PERF-001 | Images are decoded at display size (downsampling), and pixel dimensions/byte size are checked before decoding user-supplied images | image loading, `UIImage(data:)`, `BitmapFactory` without `inSampleSize`, image libraries' resize options | P1 | mobile |
| PERF-002 | Thumbnails or responsive image sizes are used instead of originals where available (`srcset`, CDN resize params) | image URLs, `<img>`, `Image` components | P2 | client |
| PERF-003 | Long or unbounded lists are virtualized (`FlatList`/`FlashList`, `LazyColumn`, `List`/`UICollectionView`, `react-window`) — not `ScrollView` + `map` | list screens | P1 | client |
| PERF-004 | Infinite scroll/pagination has an end condition and doesn't keep every page in memory forever | pagination state | P2 | client |
| PERF-005 | Caches (memory and disk) have size limits and eviction | image cache config, custom caches, `Map` used as cache | P2 | all |
| PERF-006 | Listeners, observers, subscriptions, timers and intervals are removed on teardown | `addEventListener`, `NotificationCenter`, `setInterval`, `subscribe(`, effect cleanups | P1 | client |
| PERF-007 | Long-lived closures don't capture `self`/context strongly, causing leaks (retain cycles) | closures stored in properties, Combine sinks, Android context leaks | P2 | mobile |
| PERF-008 | Large payloads (JSON, files, query results) are streamed or paginated, not loaded fully into memory | `res.json()` on big responses, `readFile` of large files, `SELECT *` without limit | P1 | all |
| PERF-009 | The main/UI thread does no heavy work: large JSON parsing, image processing, database queries, file I/O, crypto | main-thread calls in view code; `@MainActor` heavy functions; Android StrictMode | P1 | client |
| PERF-010 | No N+1 queries (ORM lazy loading in loops) on list endpoints | ORM calls inside loops, missing `include`/`select_related`/`JOIN` | P1 | api |
| PERF-011 | Frequent filters, sorts and joins are indexed; slow queries checked with `EXPLAIN` where possible | migrations, schema, query patterns | P1 | db |
| PERF-012 | No unbounded queries on user-controlled ranges (missing `LIMIT`, date ranges without caps) | list/search/export endpoints | P1 | api |
| PERF-013 | Web: bundle size within budget; routes/heavy components code-split; no large dependency for a small feature | bundler config, `import` of heavy libs, build output | P2 | web |
| PERF-014 | Web/React: no re-render storms from unstable props/context values or effects that set state every render | context providers, memoization, effect deps | P3 | web |
| PERF-015 | Startup does only what the first screen needs; analytics/SDK init and prefetching are deferred | app bootstrap, `didFinishLaunching`, `Application.onCreate` | P2 | client |
| PERF-016 | Numeric performance budgets exist (e.g. p95 API latency, LCP/INP, bundle size, app launch time) and the key ones are measured automatically (Lighthouse CI, `size-limit`, XCTest/Macrobenchmark metrics, APM alerts) | budgets in `CLAUDE.md`, CI config | P2 | all |
| PERF-017 | Static assets are compressed (Brotli or gzip), content-hashed and served with long-lived cache headers through a CDN; images use modern formats (AVIF/WebP) and fonts are subset | build and hosting config, response headers | P2 | web |
| PERF-018 | The server enforces resource limits: maximum request body and upload size, request/handler timeouts, pagination caps, worker concurrency, and container memory/CPU limits | body-parser limits, server timeouts, Dockerfile/Kubernetes resources, serverless limits | P1 | api |
