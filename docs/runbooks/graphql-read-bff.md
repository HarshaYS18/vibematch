# GraphQL Read BFF runbook

## Trigger

Use for `/graphql` 5xx/429/413 spikes, persisted-operation rejections, elevated partial errors, BFF saturation, owner-service timeout concentration, or GraphQL SLO smoke failures.

## First checks

1. Check `HTTPRoute/funkey-graphql` Accepted/ResolvedRefs and `Service/funkey-graphql-bff` readiness.
2. Check `/ready`; `compiled_operations` must equal the persisted allowlist size.
3. Check `/metrics`: compare rejected/execution-error counters and `funkey_graphql_operation_duration_seconds`.
4. Compare slow operations with `funkey_graphql_upstream_duration_seconds` before changing limits.
5. Inspect traces by request ID and operation name; never log bearer tokens or sensitive variables.
6. Compare client/gateway-observed duration with the response `Server-Timing` `bff` duration to separate network/gateway cost from BFF work.
7. For Home latency, confirm event and policy banners still share one owner `/home-banners` read per request.

## Failure actions

For unknown-operation spikes, verify Flutter and BFF persisted IDs against the checked-in contract. Do not enable ad-hoc query text as a workaround.

For 413, preserve the 16KiB application cap. Do not use GraphQL variables to carry media or large blobs.

For one unhealthy owner, restore that owner service or temporarily return to the previous client read path. Do not add direct database access to the BFF.

For BFF pressure, scale replicas inside the HPA range and investigate upstream latency/concurrency before raising limits.

For p95/p99 regressions, inspect the slowest owner-service histogram/span, connection-pool saturation, database latency, and event-loop pressure. Do not mask regressions with blanket retries, lower concurrency, sample exclusion, or inflated timeouts.

If the BFF fails startup after a persisted-operation change, fix the invalid/unsafe checked-in operation. Do not move persisted-query validation back to the request hot path.

## Rollback

Rollback the BFF image/Gateway route and client read cutover while preserving owner services and command paths. No database rollback exists because the BFF owns no schema.

## Recovery evidence

Verify Home, Profile, Discovery, and authorized Creator/Admin composites; partial-error behavior; request-ID propagation; bounded operation/upstream latency metrics; Server-Timing; the one-read Home banner path; and zero mutation/database authority.

## Load verification

Before promotion after BFF/upstream changes, run the persisted GraphQL smoke against staging with a disposable authenticated test account.

The smoke first verifies three expected security rejections: ad-hoc query text
must return `PERSISTED_ONLY` (400), an unknown operation ID must return
`UNKNOWN_OPERATION` (400), and a known operation without bearer auth must
return `UNAUTHENTICATED` (401). k6 marks those statuses as expected, and
their contract-correctness rate must be 100%.

The positive Home-composite gate is:

- HTTP request failure rate = 0%;
- k6 check failure rate = 0%;
- unexpected GraphQL failure rate = 0%;
- GraphQL semantic error rate = 0%;
- end-to-end p95 < 250ms;
- end-to-end p99 < 500ms;
- BFF server p95 < 200ms;
- BFF server p99 < 400ms;
- GraphQL security-contract correctness = 100%.

A missing `FUNKEY_TEST_TOKEN` is a hard configuration failure. Every failed sample is evidence to investigate, not something to hide with retries.

These are strict controlled-smoke promotion budgets, not a claim that every global/mobile path must meet the same latency.
