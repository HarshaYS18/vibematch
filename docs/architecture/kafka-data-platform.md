# Kafka data platform architecture

## Authority boundary

PostgreSQL remains durable business authority. Redis/Valkey remains reconstructable cache/realtime state. NATS JetStream remains the operational async bus. Kafka is a retained analytical copy for replay, analytics, ML, recommendation and data-lake workloads.

No normal domain request waits for Kafka.

## End-to-end path

```text
domain transaction
  -> event_outbox row in same PostgreSQL transaction
  -> outbox relay
  -> NATS JetStream FUNKEY_EVENTS
  -> durable pull consumer funkey-kafka-bridge-v1
  -> idempotent Kafka producer
  -> approved topic family
  -> manual-commit analytics consumer
```

The bridge is the sole application Kafka producer boundary. The architecture guard rejects Kafka client imports elsewhere.

## Topic families

- `funkey.user.activity.v1`
- `funkey.room.events.v1`
- `funkey.vibes.engagement.v1`
- `funkey.economy.analytics.v1`
- `funkey.game.events.v1`
- `funkey.media.events.v1`
- `funkey.recommendation.events.v1`
- `funkey.analytics.dlq.v1`

The economy topic is an analytical copy only. Wallet balances, gifts, purchases, refunds and settlement remain PostgreSQL/Economy authority.

## Delivery and backpressure

The bridge pulls from JetStream with bounded batch size and in-flight concurrency. Source messages are ACKed only after Kafka ACK. Kafka unavailability causes a source NAK with bounded jitter; operational NATS state remains durable and user commands do not depend on bridge health.

Unapproved event families are intentionally filtered for this bridge. Invalid or secret-bearing source events are published to the durable NATS DLQ before source ACK.

## Schema and compatibility

Kafka preserves the original `event_id`, event type/version and occurrence timestamp, and enriches the retained copy with publication time, source domain, topic family and partition key. The schema contract forbids unknown top-level fields.

Breaking envelope/topic/partition-key semantics require a versioned migration. Payload evolution must be backwards-compatible or increment the event version.

## Consumer contract

Consumers disable auto-commit. A projection commit occurs only after the projection sink succeeds. Sinks must be idempotent on `event_id`. Poison Kafka records go to `funkey.analytics.dlq.v1` with source topic/partition/offset provenance.

Analytics/search/recommendation projections are disposable derivatives. They never authorize commands.

## Replay

Replay is dry-run by default, time-bounded to at most 31 days per invocation, refuses source=destination, requires an isolated `funkey.replay.*` destination, and writes replay provenance into Kafka headers. Replay must target a projection/rebuild topic or isolated consumer path and must not invoke business commands.

## Environments

Local: one KRaft broker through Docker Compose, plaintext on loopback/internal Docker networking.

Staging: three KRaft brokers in the FunKey namespace for integration/chaos tests.

Production: managed multi-AZ Kafka. `SASL_SSL` is mandatory; credentials come from secret storage. Broker endpoints are configured through `KAFKA_BOOTSTRAP_SERVERS`.

## Observability

Required signals include bridge receive/publish/failure/filter/DLQ counts, in-flight records, publish latency, JetStream durable lag/oldest age, Kafka producer errors, consumer group lag, rebalance count, DLQ rate, broker storage/ISR health and replay throughput.

Never put user/room/request IDs into Prometheus labels.
