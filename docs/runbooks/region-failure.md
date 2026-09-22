# Region failure

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

A regional edge, cluster, PostgreSQL, Redis, or media path becomes unavailable.

## Dashboards and metrics to inspect

Global traffic, DNS/edge health, regional pods, DB replica lag, backup currency, object storage reachability.

## Immediate actions

Declare regional incident; stop writes that cannot be reconciled; identify the authoritative DB failover state.

## Safe mitigation

Fail over traffic only to a region with confirmed data and service readiness; use client reconnect/snapshot recovery.

## Dangerous actions to avoid

Do not create two writable PostgreSQL primaries or split media registry authority.

## Recovery validation

Critical flows pass in surviving region and ledgers reconcile; monitor return traffic and latency. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect timeline, region/provider status, last committed LSN, failover decision, RPO/RTO, and impacted sessions. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
