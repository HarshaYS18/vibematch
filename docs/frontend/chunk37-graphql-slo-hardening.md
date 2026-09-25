# Chunk 37 — GraphQL SLO and latency hardening

**Status: M1 implemented; CI verification is the closure gate for this micro-chunk.**

## Objective

Turn the persisted GraphQL smoke from a permissive availability check into a
strict promotion signal without gaming the benchmark.

## M1 — zero-error promotion contract

The persisted Home-composite smoke now enforces:

- authenticated execution is mandatory; a missing token fails configuration;
- HTTP request failures = 0%;
- failed k6 checks = 0%;
- unexpected GraphQL failures = 0%;
- GraphQL semantic errors = 0%, including `errors[]` on HTTP 200;
- p95 < 250ms;
- p99 < 500ms;
- all expected Home fields are present;
- no blanket retries, sample filtering, lowered concurrency, or inflated
  timeout is used to manufacture a pass.

## Why 250ms instead of a universal 100ms gate

FunKey keeps 100ms as a fast-path engineering target for server-side work, but
a universal end-to-end 100ms p95 would conflate network RTT, gateway/BFF work,
owner-service calls, and legitimate composite cost. The controlled Home smoke
therefore uses a strict 250ms p95 / 500ms p99 promotion budget while later
micro-chunks add component and per-operation telemetry so bottlenecks can be
driven toward 100ms where the architecture permits it.

## Next micro-chunks

M2 adds low-cardinality per-operation and per-upstream latency telemetry so
gateway/BFF/owner-service time can be separated. M3 uses those measurements to
remove avoidable work from the request path before tightening any production
SLO further.

## Documentation invariant

Any later change to GraphQL smoke thresholds, failure semantics, or latency
measurement must update this document, `tests/load/README.md`, and the GraphQL
runbook in the same change.
