# Chunk 36 — GraphQL Read BFF

**Status: closed. Implementation, CI and authenticated disposable-session smoke are green.**

## Delivered

- dedicated stateless `graphql-bff` service on port 8091
- real graphql-core schema with no mutation root
- four SHA-256 persisted composite operations
- query allowlist, introspection rejection, depth 4, complexity 30 and 16KiB payload cap
- request-scoped DataLoader batching/deduplication
- 2.5s owner-service deadlines and bounded concurrency
- forwarded bearer auth, request ID and trace context
- OpenTelemetry operation/upstream spans and Prometheus metrics
- GraphQL partial-data field errors
- exact Envoy `/graphql` route with dedicated timeout/rate/payload policy
- Kubernetes Deployment/Service/PDB/HPA/NetworkPolicy and immutable image publishing
- Flutter persisted-read client with no GraphQL package
- Home chrome cut over from three client REST reads to one persisted composite without UI changes
- canonical Python/Dart operation-ID contract and architecture guard

## Authority invariant

GraphQL remains read composition only. Writes stay on existing REST/gRPC command APIs and domain services remain authoritative. The BFF owns no database schema, durable cache, wallet state, room authority, or realtime authority.

## Chunk 36 reliability and latency improvement

This hardening belongs to **Chunk 36**. It is not a new chunk.

### Zero-unexpected-failure smoke contract

The authenticated Home persisted-read smoke now requires:

- HTTP unexpected failure rate = **0%**
- k6 failed-check rate = **0%**
- unexpected GraphQL failure rate = **0%**
- GraphQL semantic-error rate = **0%**, including `errors[]` carried by HTTP 200
- every required Home field present
- end-to-end p95 < **250ms**
- end-to-end p99 < **500ms**
- BFF `Server-Timing` p95 < **200ms**
- BFF `Server-Timing` p99 < **400ms**

A missing `FUNKEY_TEST_TOKEN` is a hard configuration failure, so an empty authenticated workload cannot create a false-green result.

### Expected security rejections are separated from real failures

Before positive load begins, the smoke verifies three negative/security contracts:

- ad-hoc query text -> `PERSISTED_ONLY` / HTTP 400
- unknown persisted ID -> `UNKNOWN_OPERATION` / HTTP 400
- known operation without bearer auth -> `UNAUTHENTICATED` / HTTP 401

k6 marks those statuses as expected. Their contract-correctness metric must be **100%**, while they do not contaminate the unexpected HTTP failure rate.

### Request hot-path improvements

The improvement reduces avoidable work instead of merely tightening thresholds:

- persisted-operation security inspection and schema validation are compiled once at process startup rather than repeated on every accepted request
- unsafe or schema-invalid persisted documents fail startup
- Home event and policy banners share one request-scoped authoritative `/home-banners` read instead of two duplicate owner requests
- the BFF partitions the active banner list by placement in memory
- no Home banner result survives the request, so there is no cross-request stale cache or authority drift
- Home owner HTTP requests are reduced from three to two: `my-created-room` plus one banner read
- the upstream client retains bounded concurrency and no automatic retry masking

### Latency observability

Chunk 36 now exposes bounded-cardinality telemetry needed to find actual bottlenecks:

- `funkey_graphql_operation_duration_seconds` by immutable operation name and `ok|error`
- `funkey_graphql_upstream_duration_seconds` by fixed owner-service name and `ok|error`
- response `Server-Timing` with aggregate GraphQL execution and BFF duration
- OpenTelemetry operation/upstream spans remain available for trace-level diagnosis

User IDs, room IDs, request IDs, bearer tokens, GraphQL variables, and dynamic URL paths are forbidden as metric labels.

### Protocol/error hardening

Home banner composition rejects malformed owner payloads as `UPSTREAM_PROTOCOL` rather than silently converting bad owner data into apparently valid empty results.

Owner-service contract tests verify:

- bearer auth propagation
- `X-Request-ID` propagation
- traceparent propagation
- query parameter propagation
- timeout -> `UPSTREAM_TIMEOUT`
- owner 401/403 -> GraphQL `FORBIDDEN`
- invalid JSON -> `UPSTREAM_PROTOCOL`

### Benchmark integrity

The smoke does **not** manufacture a pass by:

- blanket retries
- lowering VU concurrency
- excluding slow samples
- inflating timeouts
- ignoring GraphQL `errors[]`
- treating security rejections as unexpected transport failures

The 100ms figure remains an engineering fast-path target where realistic, not a universal end-to-end requirement that would mix mobile RTT, gateway cost, GraphQL composition and owner-service work.

## Closure audit repairs

The final deployment audit also closed the earlier integration drifts:

- staging rewrites the dedicated GraphQL HTTPRoute to `api.staging.funkey.com`
- production pins the GraphQL BFF image by digest and the immutable-image gate requires all 13 backend workloads
- local development scales the BFF/HPA to one replica and removes the production node selector
- the frontend workflow avoids duplicate GraphQL path filters and runs the persisted-read guard when the shared contract changes

These are enforced by `check_graphql_bff_architecture.py`.

## Gateway guard compatibility

Chunk 36 updates the earlier Chunk 35 buffer-count invariant from two to three intentional non-streaming policies. The guard explicitly verifies that the realtime WebSocket policy remains unbuffered rather than relying only on a global count.

## Closure test

Chunk 36 closes only when:

- GraphQL BFF unit, runtime, owner-contract and boundary tests are green
- the architecture guard is green
- frontend architecture checks are green
- infrastructure/Gateway render checks are green
- GraphQL BFF and platform container builds are green
- security-source checks remain green
- the k6 harness parses cleanly
- the authenticated disposable-session smoke satisfies the zero-error and latency thresholds; a live staging promotion run still requires a staging-only credential/provider environment

## Final measured smoke evidence

The authenticated disposable-session smoke completed with:

- k6 checks: **100% (728/728)**
- HTTP failures: **0.00%**
- unexpected GraphQL failures: **0.00%**
- GraphQL semantic errors: **0.00%**
- security-contract checks: **100% (3/3)**
- HomeComposite p95: **95.51ms**
- HomeComposite p99: **207.03ms**
- BFF server p95: **92.81ms**
- BFF server p99: **205.46ms**
- HomeComposite average: **37.3ms**
- BFF average: **36.09ms**

This evidence came from the disposable session environment created inside CI.
It proves the controlled application path, not public-Internet/mobile latency.
A live staging promotion smoke remains a separate environment validation.

## Documentation invariant

Any later change to GraphQL failure semantics, latency thresholds, metric labels, startup validation, Home read composition, or owner-service failure mapping must update this document, `tests/load/README.md`, BFF/module architecture docs, tests, and the GraphQL runbook in the same change.
