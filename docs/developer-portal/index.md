# FunKey engineering portal

This portal is the starting point for engineers operating or changing FunKey.

## Start here

1. Read the authority registry before moving state or adding a service.
2. Use the module index to find the owner, API/event contract and runbook.
3. Use the relevant runbook before production recovery actions.
4. Use the release-safety and compatibility guides before a breaking change.
5. Record an ADR/RFC when changing durable authority or a distributed contract.

## Production component documentation contract

Every production component must document:

- technical owner, business owner, on-call role and tier
- purpose and explicit non-responsibilities
- REST/realtime/event/GraphQL/game contracts
- database, cache, object-storage and broker state
- security/privacy classification
- retry, idempotency and failure semantics
- scaling limits, saturation signals and SLOs
- dashboards, alerts and matching runbook
- local development and testing
- deployment, migration, rollback and feature flags
- known compatibility/deprecation status

Use the service README template for new components. Documentation changes ship in
the same pull request as architecture changes.
