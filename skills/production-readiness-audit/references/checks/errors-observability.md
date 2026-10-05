# Error handling & observability (ERR, OBS)

When a user says "it doesn't work", can you tell why — from telemetry alone?

## ERR — error handling

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| ERR-001 | No swallowed errors: empty `catch {}`, `except: pass`, `.catch(() => {})`, `try?` discarding failures that matter, `_ = err` | `rg -n "catch\s*(\(\w*\))?\s*\{\s*\}"`, `except.*:\s*pass`, `try\?` | P1 | all |
| ERR-002 | Errors aren't only printed to the console; they reach error reporting with context | `console.log(err)`, `print(error)` as the only handling | P2 | all |
| ERR-003 | A global safety net exists: React error boundaries, uncaught exception and unhandled promise rejection handlers, server error middleware | root component, process handlers | P1 | all |
| ERR-004 | Loading state is always cleared on failure (`finally`), so the UI can't hang on a spinner | async handlers setting `isLoading` | P1 | client |
| ERR-005 | User-facing messages are accurate and actionable; raw exceptions, stack traces and server internals are never shown | error display components | P2 | client |
| ERR-006 | Backend error codes map to UI messages, with a fallback for unknown errors | error mapping | P2 | client |
| ERR-007 | Network errors, validation errors and business-rule errors are distinguished and handled differently | error types | P2 | all |
| ERR-008 | Recoverable errors offer a retry | error UIs | P2 | client |
| ERR-009 | Server returns a structured error format with a request id; 500s don't leak stack traces, SQL or paths | error middleware, framework debug settings | P1 | api |
| ERR-010 | Error messages and logs contain no secrets or personal data | error construction, log statements | P1 | all |

## OBS — observability

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| OBS-001 | Crash reporting is integrated and release builds are symbolicated (dSYMs, ProGuard/R8 mappings, source maps uploaded privately) | crash SDK init, build upload steps | P1 | client |
| OBS-002 | Logging is structured, with consistent levels and fields | logger setup | P2 | all |
| OBS-003 | A request/correlation id flows client → server → logs, and appears in error reports | request headers, log context | P2 | all |
| OBS-004 | Users/support can see an error reference id for failures | error UI | P3 | client |
| OBS-005 | Critical flows emit metrics: signup, login failures, payment failures, push delivery failures | metrics/analytics for these flows | P2 | all |
| OBS-006 | API latency and error rate are monitored with alerts that reach someone | APM, uptime checks, alert config | P1 | api |
| OBS-007 | Health endpoints distinguish liveness and readiness (dependencies) | `/health`, `/ready` | P2 | api |
| OBS-008 | Telemetry includes app version, platform and feature-flag state, so production issues can be reproduced | event/global context | P2 | client |
| OBS-009 | Unusual conditions are visible: retry counts, offline queue size, unexpected state transitions | logs/metrics around retries and state machines | P3 | client |
| OBS-010 | Requests that cross services, queues or serverless functions are traced end to end (OpenTelemetry or the APM's tracing, with context propagated through queue messages), so one slow or failed request can be followed through every hop | tracing SDK init, propagation headers, message metadata | P2 | api |
