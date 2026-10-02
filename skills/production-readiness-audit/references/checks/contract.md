# Contract & data integrity (CONTRACT)

Guards the boundary between server and clients, and between today's code and data written by older versions. Mobile apps make this harder: old app versions stay installed for months and can't be forced to update instantly.

| ID | Check | Look at | Sev | Scope |
|---|---|---|---|---|
| CONTRACT-001 | Date/time fields use one wire format (ISO 8601 with offset or UTC `Z`) and clients parse it with that exact format, never locale-dependent parsing | serializers, DTOs/models, `new Date(`, `DateFormatter`, `SimpleDateFormat`, `JSONDecoder.dateDecodingStrategy` | P1 | all |
| CONTRACT-002 | `null`, `undefined` and a missing field are distinguished where they mean different things (e.g. PATCH "clear" vs "unchanged") | PATCH handlers, partial update DTOs, `??`, `\|\|`, optional decoding | P2 | api, client |
| CONTRACT-003 | Booleans and numbers are not sent as strings (`"true"`, `"42"`); any coercion is explicit and tested | API responses, form serialization, query params parsing | P2 | all |
| CONTRACT-004 | 64-bit integer IDs are not parsed as JavaScript `number` (precision loss above 2^53); they travel as strings | ID fields, `BigInt`, `JSON.parse` of IDs, Twitter-style snowflake IDs | P1 | web, mobile |
| CONTRACT-005 | An unknown enum value from the server does not crash the client or fall into a wrong branch; there is a fallback case | `switch` on enums, `Codable` enums, Kotlin `when`, TS union narrowing, `default:` | P1 | client |
| CONTRACT-006 | Extra/unknown fields in payloads are ignored safely by clients (forward compatibility) and rejected or stripped by server input validation | decoder config (`ignoreUnknownKeys`, strict schemas), server validators | P2 | all |
| CONTRACT-007 | Removing or renaming an API field does not break app versions still in the field (versioned API, additive changes, deprecation window, minimum-version gate) | API versioning, changelog, min-supported-version check | P1 | api, mobile |
| CONTRACT-008 | Fields typed as required in client code are really always present; no force unwraps/non-null assertions on server data (`!`, `!!`, `as Foo`, `try!`) | models, `!.`, `!!`, `as ` casts, `force_unwrapping` | P1 | client |
| CONTRACT-009 | Data from outside the process (API responses, request bodies, storage, deep links) is validated at runtime at the boundary — static types alone don't validate (TypeScript types vanish at runtime) | zod/yup/valibot/io-ts, pydantic, Codable validation, `as SomeType` on `fetch` results | P1 | all |
| CONTRACT-010 | One source of truth for the API schema (OpenAPI, shared types package, codegen) instead of hand-copied models drifting apart | `openapi.*`, generated clients, duplicated interfaces | P2 | api, client |
| CONTRACT-011 | Client-side validation matches server rules, and the server is authoritative (client validation is UX only) | form validators vs server validators (lengths, formats, required) | P2 | api, client |
| CONTRACT-012 | Persisted and exchanged formats carry a version (API version, payload `schemaVersion`, local storage version) so readers can migrate | stored JSON, message payloads, cache keys | P2 | all |
| CONTRACT-013 | Pagination contract is enforced server-side: maximum page size, stable ordering/cursor, no unbounded `limit` from the client | list endpoints, `limit`/`pageSize` params, ORDER BY | P1 | api |
| CONTRACT-014 | Error responses have one consistent shape (code, message, request id) that clients actually parse | error middleware, client error mapping | P2 | api, client |
