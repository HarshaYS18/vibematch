# Kafka data platform runbook

## First checks

1. Check `funkey-kafka-event-bridge` readiness and `/metrics`.
2. Check JetStream durable `funkey-kafka-bridge-v1` pending count and oldest message age.
3. Check Kafka broker/ISR health and storage.
4. Check bridge publish-failure and latency metrics.
5. Check affected consumer-group lag before replaying anything.

Kafka/bridge incidents must not be mitigated by routing synchronous user commands through Kafka or by bypassing the transactional outbox.

## Kafka unavailable

Leave the bridge running unless it is crash-looping. JetStream retains source events and bridge messages remain unacknowledged. Restore Kafka, confirm producer health, then watch durable lag drain. Do not mark source events as delivered manually.

## Bridge unavailable

Restore/roll back the bridge image. The shared JetStream durable resumes from unacknowledged messages. Verify event IDs at the target; duplicates are acceptable and consumers must deduplicate.

## Poison source event

Inspect the NATS DLQ reason and source event contract. Never paste credentials or private payloads into tickets/logs. Correct the producer contract before replaying a sanitized replacement.

## Kafka consumer failure

Stop the unhealthy consumer if it is producing bad projections. Kafka retention protects history. Repair the sink/handler, then resume from committed offsets or execute a bounded replay.

## Replay procedure

1. Identify source topic, pre-provisioned isolated `funkey.replay.*` destination and exact UTC interval.
2. Run `replay.py` **without** `--execute`; record scanned count and replay ID.
3. Confirm the destination cannot trigger transactional commands.
4. Review capacity/lag and downstream idempotency.
5. Run the same command with `--execute`.
6. Track replay throughput, DLQ and destination consumer lag.
7. Record replay ID, operator, time window and result in the incident/change record.

The tool refuses source=destination, non-`funkey.replay.*` destinations and intervals longer than 31 days.

## Broker failure/partition recovery

For staging KRaft, validate remaining quorum/ISR, restore the failed broker and wait for replicas to recover before load testing. For production managed Kafka, follow provider broker-recovery guidance and FunKey alerts. Never lower production replication or min-ISR simply to clear an alert.

## Promotion evidence

Before production promotion capture:

- bridge unit/architecture tests
- container build
- local integration: NATS event -> Kafka event with identical event_id
- zero silent loss in controlled bridge test
- duplicate/redelivery tolerance
- broker interruption/recovery evidence
- consumer restart/offset evidence
- replay dry-run and executed isolated replay evidence
- current ACL/TLS configuration
- dashboards/alerts and rollback plan
