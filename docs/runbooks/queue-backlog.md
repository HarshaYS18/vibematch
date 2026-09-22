# Queue backlog

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

JetStream consumer lag or oldest message age rises; notifications or post-processing fall behind.

## Dashboards and metrics to inspect

Stream and consumer health, pending count, oldest age, ack/nack/redelivery, dead-letter volume, worker CPU/DB pressure.

## Immediate actions

Pause new nonessential producers if safe; identify poison event or downstream dependency outage.

## Safe mitigation

Scale workers within DB/provider limits; fix handler failure; replay dead-letter items only after idempotency review.

## Dangerous actions to avoid

Do not clear a stream, increase retries without bound, or replay value events with a new idempotency key.

## Recovery validation

Backlog age and depth decline, no duplicate user effects, dead-letter queue stabilizes. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect event IDs, consumer group, schema version, trace IDs, retry counts, and provider errors. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
