# Kafka Event Bridge module

## Owns

- the only approved NATS -> Kafka application bridge
- analytics event routing and retained-envelope enrichment
- Kafka topic catalogue/provisioning
- producer delivery semantics and bridge backpressure
- projection-consumer framework
- replay tooling
- bridge metrics/health

## Does not own

- domain transactions or command authorization
- PostgreSQL business truth
- NATS operational producers/consumers
- analytics model correctness
- search/recommendation business decisions
- production Kafka credentials

## Reliability

Source JetStream ACK occurs only after Kafka ACK. Kafka failure results in source NAK/retry. Poison source data is quarantined in NATS DLQ before ACK. Consumers commit the exact processed partition offset only after sink success and use `event_id` idempotency.

## Security

Production Kafka must use SASL_SSL, a dedicated `funkey-kafka-secrets` credential boundary and ACLs. The bridge producer receives write access only to approved analytics topics. Consumer identities receive read access only to their topic/group. Secret-looking payload keys are rejected.

## Scaling

Scale bridge replicas against source durable lag and publish saturation. All replicas share the same JetStream durable and Kafka producer semantics. Do not use replica-local state for correctness.

## Changes

Any topic, partition key, retention, schema, security-protocol or replay change must update contracts, architecture docs, runbook, tests and the Chunk 37 closure document.
