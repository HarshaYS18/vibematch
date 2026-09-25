# FunKey event contracts

Two event transports intentionally coexist.

## Operational events

`event-envelope-v1.schema.json` is the durable PostgreSQL-outbox -> NATS JetStream operational envelope. NATS is the operational async bus for jobs, fanout and service workflows.

## Analytics events

`kafka-analytics-envelope-v1.schema.json` is the long-retained Kafka analytics/replay envelope. `kafka-topics-v1.json` is the canonical topic catalogue and topic-level data-classification policy. `kafka-acl-policy-v1.json` is the least-privilege access contract.

Kafka does **not** replace NATS and does not become synchronous RPC or durable business authority. The only approved application path into Kafka is:

```text
transactional outbox -> NATS JetStream -> kafka-event-bridge -> Kafka
```

Domain services must not dual-write PostgreSQL/NATS/Kafka.

## Compatibility

- Additive payload changes are allowed when consumers tolerate missing fields.
- Breaking semantic or structural changes require a new event version/topic contract.
- Existing event IDs survive the NATS -> Kafka bridge unchanged.
- Consumers must use `event_id` as the idempotency key.
- Partition-key changes are breaking ordering changes and require explicit review.
- No credential/token/card-secret fields are permitted in Kafka payloads.\n- Replay writes are isolated to pre-provisioned `funkey.replay.*` topics.
