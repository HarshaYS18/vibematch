# API degraded

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Elevated HTTP 5xx, p95 latency, or falling ready replicas; room commands fail while media may continue.

## Dashboards and metrics to inspect

API request/error/latency panels, pod readiness and restart count, DB pool waits, PostgreSQL active connections, Redis timeouts, recent rollout.

## Immediate actions

Declare incident; stop further promotion; compare affected routes and pods; preserve a known-good replica.

## Safe mitigation

Roll back the most recent compatible API image if regression is confirmed; scale within the DB connection budget and restore dependencies first.

## Dangerous actions to avoid

Do not raise HPA max without connection math or restart all replicas simultaneously.

## Recovery validation

Sample auth, user snapshot, room join, media discovery, and write/readback; confirm p95 and error rate return to baseline. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect request IDs, revision/image digest, pod events, DB/Redis metrics, and first bad timestamp. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
