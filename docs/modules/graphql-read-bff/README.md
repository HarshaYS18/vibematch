# GraphQL Read BFF module

## Owns

- persisted read allowlist and query budgets
- startup validation/compilation of persisted documents
- request-scoped read batching
- composite response execution
- read-only upstream timeout/error mapping
- low-cardinality per-operation and per-owner latency telemetry
- GraphQL transport metrics/tracing

## Does not own

- authentication truth or authorization policy
- durable state or database sessions
- command/mutation execution
- realtime transport
- cross-request authoritative caches

## Approved composites

Home, Profile, Discovery, and Creator/Admin dashboard. Adding another operation requires an owning-service review, persisted-ID update, complexity-budget review, Flutter/contract parity, latency-budget review, tests, and documentation.

Metric labels must remain bounded to approved operation names, fixed owner-service identifiers, and the `ok|error` outcome dimension. Never label metrics with user IDs, room IDs, request IDs, URLs, bearer tokens, or GraphQL variables.

Home event/policy banner composition intentionally uses one request-scoped active-banner owner read and partitions by placement inside the BFF. Any replacement must preserve the same authority and no-cross-request-cache guarantees.
