# Database restore

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Primary data is unavailable or corrupted and failover cannot meet recovery objective.

## Dashboards and metrics to inspect

Latest verified backup/PITR point, WAL continuity, replica lag, integrity checks, migration revision.

## Immediate actions

Declare recovery lead and freeze writes; record target restore timestamp and expected data loss before action.

## Safe mitigation

Restore into an isolated instance, validate schema and row counts, then switch traffic under an approved cutover plan.

## Dangerous actions to avoid

Do not overwrite the only surviving primary/backup or run new migrations before verifying restored history.

## Recovery validation

Alembic revision matches release, critical ledger totals reconcile, application smoke tests pass, backups resume. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Retain backup IDs, restore commands, RPO/RTO measurements, checksums, and approver record. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
