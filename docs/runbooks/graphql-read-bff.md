# GraphQL Read BFF runbook

## Trigger

Use for `/graphql` 5xx/429/413 spikes, persisted-operation rejections, elevated partial errors, BFF saturation, or owner-service timeout concentration.

## First checks

1. Check `HTTPRoute/funkey-graphql` Accepted/ResolvedRefs and `Service/funkey-graphql-bff` ready endpoints.
2. Check BFF `/ready` and `/metrics`.
3. Compare rejected vs execution-error counters.
4. Inspect traces by request ID and operation name; never log bearer tokens or variables containing sensitive values.
5. Identify whether one owner service is timing out while sibling fields remain healthy.

## Failure actions

For unknown-operation spikes, verify Flutter and BFF persisted IDs match the checked-in contract. Do not enable ad-hoc query text as a workaround.

For 413, keep the 16KiB application cap; composite variables should remain small. Do not raise limits to carry media or large blobs.

For one unhealthy owner, restore that owner service or temporarily return the previous client read path. Do not add direct database access to the BFF.

For BFF capacity pressure, scale replicas within the HPA range and investigate upstream latency/concurrency before raising limits.

## Rollback

Rollback the BFF image/Gateway route and client read cutover while preserving existing owner services and command paths. No database rollback exists because the BFF owns no schema.

## Recovery evidence

Verify one Home composite, Profile composite, Discovery composite and authorized Creator/Admin composite; verify partial-error behavior, request-ID propagation, p95 latency and zero mutation/database access.


## Load verification

Before promotion after a BFF/upstream routing change, run the persisted GraphQL
smoke against staging with a disposable authenticated test account. Treat a
p95 above 1500ms or request-failure rate at/above 2% as a signal to inspect
owner-service latency, BFF concurrency, and trace spans before increasing
capacity limits.
