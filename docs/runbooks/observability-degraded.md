# Observability degraded

**Owner:** Platform / SRE

Observability is diagnostic projection, not business authority. An observability outage must not make login, rooms, Inbox, media, games, wallet, or worker processing unavailable.

## Signals

Use this runbook for collector restart loops, exporter queue pressure, missing Tempo traces, missing Loki logs, missing Prometheus targets, stale Grafana panels, missing Sentry events, or measurable telemetry overhead.

## First checks

1. Confirm business `/live` and `/ready` endpoints separately from telemetry.
2. Check collector readiness, CPU/memory, queue, retry, and rejected/dropped telemetry.
3. Verify Tempo/Loki endpoint DNS, TLS, credentials, tenant headers, and quotas.
4. Check Prometheus target/scrape failures independently.
5. For Sentry, verify release/environment and build-time DSN without logging the DSN.
6. Compare application error and latency metrics before and after the incident.

## Safe mitigations

- Reduce trace sampling.
- Temporarily set `OTEL_TRACES_ENABLED=false` if instrumentation overhead is implicated.
- Scale collectors while preserving bounded queues.
- Restore the previous backend endpoint/credential configuration.
- Disable optional Sentry with an empty DSN only if client telemetry causes impact.
- Preserve structured stdout logs even when trace export is disabled.

Do not make application readiness depend on Tempo, Loki, Grafana, Prometheus, Sentry, or the collector.

## Query-count regression

For `FunKeyApiQueryCountRegression`, identify the highest-query route, reproduce with representative data, assert the request-scoped query count in a regression test, inspect eager-loading/batching/index strategy, and fix the query path rather than raising the threshold without evidence.

## Recovery validation

Collector replicas are ready; export pressure returns to normal; new traces reach Tempo; new logs reach Loki when the cluster log agent is configured; Prometheus targets are healthy; Grafana advances; a non-sensitive Sentry test event reaches the intended environment; and application p95/error ratio has not regressed.

## Rollback

Chunk 16 schema change `event_outbox.traceparent` is additive and nullable. Do not drop it during an incident. Runtime rollback is configuration-first: disable exporters/tracing, then roll back instrumentation code if required. Older workers can ignore the nullable trace context.

The collector can be rolled back independently because applications fail open when its endpoint is absent.
