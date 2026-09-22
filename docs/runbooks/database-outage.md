# PostgreSQL outage

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Durable reads/writes fail, API readiness drops, pool waits or connection errors spike.

## Dashboards and metrics to inspect

Primary status, replication lag, active connections, locks, disk/WAL, PgBouncer stats, failed migration jobs.

## Immediate actions

Stop application rollouts and value-changing retries; determine primary outage versus pool saturation.

## Safe mitigation

Use managed failover procedure or restore service; cap API/worker concurrency until DB stabilizes.

## Dangerous actions to avoid

Do not repeatedly retry ambiguous wallet/gift writes or run migrations during failover.

## Recovery validation

Read and write a safe test record; inspect ledger reconciliation, API error rate, Alembic head, replication. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect DB incident ID, LSN/timeline, connection chart, first error time, and affected transaction IDs. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
