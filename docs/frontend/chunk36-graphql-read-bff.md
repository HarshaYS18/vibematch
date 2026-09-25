# Chunk 36 — GraphQL Read BFF

**Status: implementation complete; CI is the final closure gate.**

## Delivered

- dedicated stateless `graphql-bff` service on port 8091
- real graphql-core schema with no mutation root
- four SHA-256 persisted composite operations
- query allowlist, introspection rejection, depth 4, complexity 30 and 16KiB payload cap
- request-scoped DataLoader batching/deduplication
- 2.5s owner-service deadlines and bounded concurrency
- forwarded bearer auth, request ID and trace context
- OpenTelemetry operation/upstream spans and Prometheus counters
- GraphQL partial-data field errors
- exact Envoy `/graphql` route with dedicated timeout/rate/payload policy
- Kubernetes Deployment/Service/PDB/HPA/NetworkPolicy and immutable image publishing
- Flutter persisted-read client with no GraphQL package
- Home chrome cut over from three REST reads to one composite without UI changes
- canonical Python/Dart operation-ID contract and architecture guard

## Authority invariant

GraphQL is read composition only. Writes stay on existing REST/gRPC command APIs and domain services remain authoritative.

## Closure test

Chunk 36 is complete only when BFF unit/boundary tests, frontend guard, infrastructure/Gateway render, container build and repository architecture guard are green.

## Closure audit repairs

The final deployment audit closed four integration drifts before Chunk 36
completion:

- staging now rewrites the dedicated GraphQL HTTPRoute to
  `api.staging.funkey.com`;
- production now pins the GraphQL BFF image by digest and the immutable-image
  gate requires all 13 backend workloads;
- local development scales the BFF/HPA to one replica and removes the
  production node selector;
- the frontend workflow no longer duplicates GraphQL path filters and now runs
  the persisted-read guard when the shared contract changes on push.

These are enforced by `check_graphql_bff_architecture.py`.

## Gateway guard compatibility

Chunk 36 updates the earlier Chunk 35 buffer-count invariant from two to three
intentional non-streaming policies. The guard now explicitly verifies that the
realtime WebSocket policy remains unbuffered rather than relying only on a
global count.

## Composite-read load budget

Chunk 36 introduced `tests/load/graphql-read-smoke.js` for the persisted Home
composite. The Chunk 36 reliability/latency improvement hardens that promotion
signal: authenticated execution is mandatory, unexpected/semantic failure rates
must be exactly 0%, p95 must stay below 250ms, and p99 below 500ms. The test does not use blanket retries and
validates GraphQL `errors[]` even when transport status is HTTP 200.

These controlled-smoke thresholds are intentionally stricter than the original
Chunk 36 <2% / 1500ms gate and are not a universal latency promise for every
FunKey operation or global mobile path.
