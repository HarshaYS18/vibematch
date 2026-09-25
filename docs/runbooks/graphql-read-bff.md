# GraphQL Read BFF runbook

## Trigger

Use for `/graphql` 5xx/429/413 spikes, persisted-operation rejections, elevated partial errors, BFF saturation, owner-service timeout concentration, or a GraphQL SLO smoke failure.

## First checks

1. Check `HTTPRoute/funkey-graphql` Accepted/ResolvedRefs and `Service/funkey-graphql-bff` ready endpoints.
2. Check BFF `/ready` and `/metrics`.
3. Compare rejected vs execution-error counters.
4. Inspect traces by request ID and operation name; never log bearer tokens or variables containing sensitive values.
5. Identify whether one owner service is timing out while sibling fields remain healthy.
6. For latency regressions, separate gateway/BFF time from owner-service time before changing capacity or deadlines.

## Failure actions

For unknown-operation spikes, verify Flutter and BFF persisted IDs match the checked-in contract. Do not enable ad-hoc query text as a workaround.

For 413, keep the 16KiB application cap; composite variables should remain small. Do not raise limits to carry media or large blobs.

For one unhealthy owner, restore that owner service or temporarily return the previous client read path. Do not add direct database access to the BFF.

For BFF capacity pressure, scale replicas within the HPA range and investigate upstream latency/concurrency before raising limits.

For a p95/p99 regression, inspect the slowest owner-service span, connection-pool saturation, database latency, and event-loop pressure. Do not hide the regression with blanket retries, lower concurrency, excluded slow samples, or inflated timeouts.

## Rollback

Rollback the BFF image/Gateway route and client read cutover while preserving existing owner services and command paths. No database rollback exists because the BFF owns no schema.

## Recovery evidence

Verify one Home composite, Profile composite, Discovery composite and authorized Creator/Admin composite; verify partial-error behavior, request-ID propagation, operation-level latency, and zero mutation/database access.

## Load verification

Before promotion after a BFF/upstream routing change, run the persisted GraphQL
smoke against staging with a disposable authenticated test account. The
controlled Home-composite gate is:

- HTTP request failure rate = 0%;
- k6 check failure rate = 0%;
- unexpected GraphQL failure rate = 0%;
- GraphQL semantic error rate = 0%;
- p95 < 250ms;
- p99 < 500ms.

A missing `FUNKEY_TEST_TOKEN` is a hard test configuration failure. Any failed
sample is evidence to investigate rather than something to mask with retries.
Production SLOs remain operation-specific; this controlled smoke is a strict
promotion signal, not a claim that every global/mobile path has the same budget.
