# Observability

## Purpose

Collects traces, metrics, and structured logs across requests, events, workers, and media.

## Responsibilities

Telemetry contracts and dashboards; never domain state.

## What this module owns

Telemetry contracts and dashboards; never domain state.

## What this module does NOT own

This module does not take over an adjacent domain merely because it transports or caches its data.

## Source of truth

PostgreSQL remains the durable source of truth for application state.

## Important files

`backend/app/core/operational.py`, `backend/app/main.py`, `apps/realtime-gateway/internal/gateway/hub.go`, `apps/worker/main.py`, `backend_media/src/server.ts`, and `deploy/observability/`.

## Public API/contracts

`/live`, `/ready`, and `/metrics` are operational contracts for API/gateway/worker; media exposes `/health`, `/ready`, and `/metrics`. Prometheus alert rules and a Grafana dashboard are deployable from `deploy/observability/`.

## Events published

This component may publish or consume versioned domain events as contracts are implemented. Existing room WebSocket/Redis events are distinct from durable JetStream publication; do not assume all proposed events are live.

## Events consumed

No durable broker consumer is implied by this ownership guide. Add a consumer only with a versioned contract, idempotency, retry limits, and an integration test.

## Database tables/state owned

Database: No business tables; retention belongs to observability platform.

## Redis keys/state owned

No application authority in Redis.

## Dependencies

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable.

## Security considerations

Redact JWTs, OTPs, passwords, payment data, private message bodies, and secret keys. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes

Loss of telemetry must not silently mark unhealthy business writes as successful.

## Retry/idempotency behavior

Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling behavior

Scale this workload independently when deployed.

## Autoscaling metrics

Measure its primary work unit, CPU, memory, saturation, errors, p95 latency, queue/backpressure where relevant, and dependency pressure. Respect the database connection budget and drain before scale-in.

## Observability

Propagate request and trace IDs through internal calls. Emit structured logs and low-cardinality metrics for readiness, throughput, failures, and drain progress. Pair alerts with the matching runbook.

## Local development

See the root README and local development guide for PostgreSQL, Redis, FastAPI, media, and optional broker setup.

## Testing

Run the component's unit/contract checks and an integration test against real dependencies before changing a distributed contract.

## Deployment notes

Deploy compatible contracts first, then producers/consumers or routing. Verify health, rollback path, and operational dashboards.

## Change checklist

Review security boundaries, schema changes, resource limits, autoscaling signals, and scale-in drain behavior.

## Known migration status

Repository observability package implemented: structured API/gateway/worker/media operational logs, Prometheus metrics, SLO-style alert rules, dashboard configuration and incident runbooks are present. The repository now includes the OpenTelemetry Collector edge plus Prometheus rules and Grafana dashboard configuration. Tempo, Loki, Prometheus/Grafana installations, the Kubernetes stdout log agent, retention storage, credentials, and paging remain environment integrations and must not be treated as deployed merely because their contracts exist.

## Chunk 16 tracing contract

Chunk 16 adds opt-in OpenTelemetry tracing to the Python API/worker, W3C `traceparent`
continuation through the durable outbox/NATS boundary, and request-scoped SQL query
counting for N+1 regression tests. Prometheus remains the metric source and telemetry
export failure remains fail-open. See `docs/architecture/observability-platform.md`.

## Chunk 16 deployed edge

`deploy/observability/otel-collector.yaml` provides the bounded OTLP edge. Applications target the collector service; it exports to environment-supplied Tempo/Loki endpoints. Prometheus metrics remain pull-based.
