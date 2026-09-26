# Observability Platform

**Owner:** Platform Architecture / SRE  
**Status:** Chunk 16 implementation contract  
**Authority:** telemetry is diagnostic projection only; it never owns business state

## Goals

FunKey uses one correlation model across Flutter, FastAPI, workers, Go realtime, and backend_media:

```text
user action
-> W3C trace context
-> API / realtime / media
-> PostgreSQL / Redis
-> transactional outbox
-> NATS JetStream
-> worker / realtime fanout
```

The platform preserves the metrics and structured logs that already exist. Chunk 16 adds distributed tracing and query-budget tooling; it does not replace working Prometheus instrumentation.

## Standard stack

- OpenTelemetry semantics and OTLP/HTTP for backend distributed traces.
- OTel Collector as the application-facing telemetry endpoint.
- Prometheus for metrics.
- Grafana for dashboards.
- Tempo as the trace backend contract.
- Loki as the log backend contract.
- Sentry Flutter for client crashes, Dart/native exceptions, performance spans, and breadcrumbs.

No repository manifest is proof that an external production backend is deployed. Production endpoints, retention, storage, credentials, and paging integrations must be bound by the target environment.

## Trace propagation

Use W3C `traceparent` for synchronous HTTP boundaries and preserve `trace_id` / `request_id` in durable event envelopes. Every component must tolerate missing trace context and create a new trace rather than failing business work.

Trace/log export is best effort. Telemetry backpressure must never block a wallet mutation, room command, realtime socket, media action, Inbox send, or worker acknowledgement.

## Services

### FastAPI

The API uses the official OpenTelemetry Python SDK with FastAPI, SQLAlchemy, and Redis instrumentation. The existing request metrics remain the Prometheus source.

### Worker

The Python worker uses the same tracer provider and creates spans around outbox publication and durable message handling. Existing event envelopes already carry `trace_id`; Chunk 16 links worker spans to that correlation data.

### Go realtime

The gateway keeps its low-allocation hot path. It propagates W3C context, creates bounded trace records for connection/subscription/control-plane calls, and exports OTLP asynchronously with a drop-on-overload policy. Trace export cannot hold hub locks or socket queues.

### backend_media

Media signaling creates spans around Socket.IO actions and control-plane calls, propagates trace context to FastAPI, and exports asynchronously. Mediasoup packet/media transport remains outside the application trace payload; QoS metrics belong to the later media QoS chunk.

### Flutter

Sentry is enabled only when a DSN is supplied through build configuration. The app still renders immediately if Sentry is absent or initialization/reporting fails. `AppTelemetry` provides standard flow names and wraps client network operations with performance spans as clients converge onto `AppNetworkClient`.

## Standard flow names

Use stable low-cardinality names:

- `auth.login`
- `home.load`
- `room.join`
- `room.seat.change`
- `gift.send`
- `inbox.send`
- `vibes.load`
- `watch_party.command`
- `game.start`
- `media.upload`
- `wallet.mutate`

Do not put user IDs, room IDs, message IDs, URLs with identifiers, or arbitrary content in span names. Put safe identifiers in attributes only when needed and allowed by the privacy policy.

## Database query counting

SQLAlchemy query counting is request/context scoped. Critical endpoint tests can assert a bounded query count without relying on production APM. Development/test responses may expose `X-FunKey-DB-Query-Count`; production keeps the count in logs/traces and does not expose it by default.

Query count is a regression signal, not a substitute for latency plans, query plans, or `pg_stat_statements`.

## Sampling and privacy

Production tracing must use bounded sampling. Tier-0 mutations may use higher sampling when incident response requires it, but never record credentials, bearer tokens, cookies, message bodies, payment secrets, or uploaded media contents.

Sentry and OTel environments/releases are explicit. PII defaults remain disabled unless a later privacy review approves specific fields.

## Failure model

If Sentry, the collector, Tempo, Loki, Prometheus scraping, or Grafana is unavailable:

- application requests continue;
- realtime/media continue;
- worker processing continues;
- bounded exporter queues may drop telemetry;
- a telemetry-drop metric/log is emitted where practical;
- readiness is not failed solely because an observability backend is down.

## Kubernetes topology

Applications send OTLP to the in-cluster `funkey-otel-collector` service. The collector can export traces to a configured Tempo-compatible OTLP endpoint and logs to the platform log pipeline. Prometheus continues scraping service `/metrics` endpoints.

Reference manifests are provider-neutral and contain placeholder backend endpoints. Do not claim production Tempo/Loki storage exists until infrastructure credentials and retention are configured.

## Validation

Chunk 16 is complete only when:

1. FastAPI and worker tracing can be enabled/disabled without changing business behavior.
2. realtime/media trace exporters are bounded and non-blocking.
3. trace context crosses HTTP control-plane calls and durable outbox/worker boundaries.
4. DB query counts are testable.
5. Flutter Sentry integration is optional and preserves first-frame behavior.
6. collector/Tempo/Loki contracts are documented/renderable.
7. architecture tests protect the observability seams.
8. existing backend/media/Flutter CI remains green.
