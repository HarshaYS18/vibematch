# FunKey observability package

This directory contains the deployable provider-neutral observability edge for FunKey:

- a pinned OpenTelemetry Collector accepting OTLP gRPC/HTTP;
- bounded memory, batch, retry, and export queues;
- trace export contract to Tempo;
- OTLP log export contract to Loki;
- Prometheus alert rules;
- Grafana dashboard configuration.

## Installed by this repository

`kubectl kustomize deploy/observability` renders the collector, PrometheusRule, and Grafana dashboard ConfigMap. The collector is pinned to `otel/opentelemetry-collector-contrib:0.161.0`.

The repository intentionally does not install production Tempo, Loki, Prometheus, Grafana, object storage, or paging infrastructure. Those require environment-specific retention, durability, authentication, encryption, backup, and cost decisions. `funkey-otel-backends` is an integration contract and must be patched to real Tempo/Loki endpoints before production rollout.

## Application trace contract

Applications send traces to `http://funkey-otel-collector.monitoring.svc.cluster.local:4318/v1/traces`. Trace export is best effort and cannot fail application readiness or business transactions. The collector has two replicas and bounded queues; prolonged backend loss eventually drops telemetry rather than creating unbounded application backpressure.

Existing structured stdout logs remain the runtime logging source. A cluster-level log agent should send Kubernetes container logs to Loki. The collector also exposes an OTLP logs receiver/export path for workloads that emit OTLP logs; Chunk 16 does not claim stdout collection exists until that cluster agent is installed.

## Backend binding

Patch `TEMPO_OTLP_HTTP_ENDPOINT` and `LOKI_OTLP_HTTP_ENDPOINT` in the target environment. Managed-provider tenant tokens/headers belong in secret infrastructure and must never be committed.

## Flutter/Sentry binding

Sentry is optional at Flutter build time through `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`, and `SENTRY_TRACES_SAMPLE_RATE`. An empty DSN disables Sentry. The app renders before optional observability initialization, so Sentry availability cannot cause a white screen.

## Initial objectives

Existing Prometheus rules cover API errors/latency, database pool pressure, realtime subscription/capacity, worker DLQ, media registry, and an API query-count regression signal. These are initial guardrails, not measured capacity claims; tune only from staging/load-test evidence.

See `docs/runbooks/observability-degraded.md` and `docs/architecture/observability-platform.md`.
