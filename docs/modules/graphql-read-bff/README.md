# GraphQL Read BFF module

## Owns

- persisted read allowlist and query budgets
- request-scoped read batching
- composite response execution
- read-only upstream timeout/error mapping
- GraphQL transport metrics/tracing

## Does not own

- authentication truth or authorization policy
- durable state or database sessions
- command/mutation execution
- realtime transport
- cross-request authoritative caches

## Approved composites

Home, Profile, Discovery and Creator/Admin dashboard. Adding another operation requires an owning-service review, persisted ID update, complexity budget review, Flutter/contract parity, tests and documentation.
