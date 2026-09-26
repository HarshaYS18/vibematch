# <Service name>

## Ownership
- Technical owner:
- Business owner:
- On-call:
- Tier:
- Repository path:
- Dashboard:
- SLO:
- Runbook:

## Purpose

Describe the service's responsibility in one paragraph.

## Explicit non-responsibilities

List adjacent domains this service does not own.

## Authority and durable state

Describe the authoritative database/tables, or state that the service is a
rebuildable projection/transport.

## APIs and contracts

List REST, realtime, event, GraphQL, game bridge and manifest contracts.

## Dependencies

List owner services, PostgreSQL/Redis/NATS/Kafka/object storage and external
providers.

## Security and privacy

Data classification, authentication/authorization, secret handling and audit
requirements.

## Retry and idempotency

Document timeout, retry, dedupe, idempotency keys, DLQ/replay and reconciliation.

## Scaling and limits

Primary work unit, connection budgets, queues, rate limits, hot partitions and
autoscaling signals.

## SLO and observability

SLIs/SLOs, metrics, traces, logs, dashboards and alerts.

## Failure modes and runbook

Link the matching runbook and call out dangerous recovery actions.

## Local development and testing

Commands, fixtures, dependencies, unit/integration/load/chaos coverage.

## Deployment / migration / rollback

Order of operations, schema/event compatibility, canary strategy and rollback
constraints.

## Feature flags and compatibility

Flags/kill switches, supported client/server versions and deprecation state.

## Status

Production, staging-only, experimental, decommissioning or retired.
