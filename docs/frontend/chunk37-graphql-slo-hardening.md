# Chunk 37 — GraphQL SLO and latency hardening

**Status: implementation complete; final CI is the closure gate.**

## Objective

Make the persisted GraphQL read path a strict, measurable promotion surface:
zero unexpected failures in controlled smoke tests, explicit semantic-error
detection, operation-level latency budgets, and no benchmark gaming.

## M1 — zero-error promotion contract

The persisted Home-composite smoke enforces:

- authenticated execution is mandatory; missing test auth is a hard failure;
- HTTP request failures = 0%;
- k6 check failures = 0%;
- unexpected GraphQL failures = 0%;
- GraphQL semantic errors = 0%, including `errors[]` on HTTP 200;
- required Home fields must all be present;
- end-to-end p95 < 250ms and p99 < 500ms;
- no blanket retries, sample filtering, reduced concurrency, or inflated
  timeout is used to manufacture a pass.

## M2 — hot-path telemetry and startup compilation

M2 adds the measurements required to improve latency from evidence:

- persisted-query security inspection and schema validation happen once at
  startup instead of on every accepted request;
- invalid/unsafe checked-in operations fail process startup;
- `funkey_graphql_operation_duration_seconds` records total accepted BFF
  latency by immutable operation name and `ok|error`;
- `funkey_graphql_upstream_duration_seconds` records owner-read latency by
  fixed service name and `ok|error`;
- fixed histogram buckets support p50/p95/p99 without high-cardinality labels;
- successful responses emit aggregate `graphql-exec` and `bff`
  `Server-Timing`;
- smoke validates the Server-Timing contract and gates BFF p95 < 200ms and
  p99 < 400ms.

No user ID, room ID, request ID, URL path, token, or GraphQL variable is used
as a metric label.

## M3 — Home composite fast-path optimization

Static request-path inspection showed duplicate owner reads for event and policy
banners. They now share one request-scoped active-banner read:

1. the BFF reads `/home-banners` once;
2. DataLoader deduplicates sibling access inside the request;
3. the BFF partitions the authoritative list by `placement`;
4. no result survives the request, so there is no stale cross-request cache.

This reduces owner HTTP requests for the Home composite from three to two
(`my-created-room` plus one banner read), lowers connection-pool pressure and
JSON work, and preserves domain authority.

## Latency philosophy

A universal 100ms end-to-end gate would mix mobile/network RTT with server
work and encourage benchmark distortion. FunKey instead treats ~100ms as the
fast-path engineering target and uses operation-specific controlled budgets.
The Home promotion contract is currently 250ms end-to-end / 200ms BFF p95,
with component histograms available to justify future tightening.

## Closure criteria

Chunk 37 closes only when:

- BFF unit/boundary tests pass;
- architecture guard enforces the new SLO/telemetry/one-read invariants;
- all existing CI remains green;
- the k6 harness parses successfully;
- staging smoke, when run with valid test credentials, is required to satisfy
  the zero-error and latency thresholds above.

## Documentation invariant

Any later change to GraphQL failure semantics, latency thresholds, metric
labels, startup validation, or Home read composition must update this document,
`tests/load/README.md`, BFF/module architecture docs, tests, and the runbook
in the same change.
