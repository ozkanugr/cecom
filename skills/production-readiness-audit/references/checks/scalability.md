# Scalability (SCALE)

Design against a written target, not vague growth (engineering manifesto §18). These checks find what breaks first when traffic or the number of server instances grows.

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| SCALE-001 | Server instances are stateless: sessions, uploads and data needed for correctness aren't kept in process memory or on local disk; they live in a shared store (database, Redis, object storage) | in-memory session stores (`MemoryStore`), files written to local disk, in-process caches relied on for correctness | P1 | api |
| SCALE-002 | Work that can exceed a request's time budget (emails, media processing, exports, third-party sync, LLM batches) runs in background jobs/queues, not in the request handler | long awaits in handlers, serverless function timeouts | P1 | api |
| SCALE-003 | Queue consumers have bounded retries, a dead-letter queue or failed-jobs table for poison messages, and an alert on its size | worker/queue config (BullMQ, Celery, SQS, Sidekiq, Cloud Tasks, pg-boss) | P1 | api |
| SCALE-004 | Scheduled jobs run once per schedule even with several instances (managed scheduler, leader election, or distributed lock) | `setInterval`/cron libraries inside the web process | P1 | api |
| SCALE-005 | Database connections are pooled and bounded; serverless functions go through a pooler (PgBouncer, Supabase/Neon pooler, RDS Proxy, Prisma Accelerate) instead of opening a connection per invocation | DB client created inside handlers, pool size settings | P1 | api, db |
| SCALE-006 | Caches have an explicit invalidation strategy (TTL and/or event-based) and are never the only copy of data | cache writes without TTL, updates that don't invalidate | P2 | api |
| SCALE-007 | Hot paths avoid fan-out proportional to user data (one request causing N external calls or N queries) | loops calling services or the database per item | P2 | api |
| SCALE-008 | Per-user/tenant quotas or rate limits stop one heavy user from exhausting shared resources | rate-limit keys (user/tenant vs IP only), quota tables | P2 | api |
| SCALE-009 | Responses carry deliberate cache headers: public data can be cached at the CDN/edge, and private data is never publicly cacheable (`Cache-Control: private` or `no-store`) | response headers, CDN rules, framework caching defaults | P1 | api, web |
| SCALE-010 | Capacity assumptions are written down (expected users and requests, largest tenant, data growth) and were load-tested or at least estimated | ADRs, load-test scripts (k6, Artillery, Locust, Gatling) | P3 | api |
