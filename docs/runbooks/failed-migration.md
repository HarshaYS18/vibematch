# Failed migration

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Alembic job exits nonzero, API schema guard fails, or DDL remains blocked.

## Dashboards and metrics to inspect

alembic current/heads, job logs, pg_stat_activity locks, schema diff, backup/PITR state.

## Immediate actions

Stop API promotion; isolate migration job and preserve error output.

## Safe mitigation

Fix forward with a reviewed migration when safe; restore from backup only with explicit recovery plan and data reconciliation.

## Dangerous actions to avoid

Do not run Base.metadata.create_all(), edit applied revision history, or force stamp without proving schema parity.

## Recovery validation

Migration completes on staging clone, single head confirmed, API starts and smoke tests pass. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect revision ID, DDL statement, lock wait, DB version, backup ID, and schema diff. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
