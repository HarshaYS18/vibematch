# Redis/Valkey outage

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Media assignment, presence, fanout, or rate limiting fails; media nodes may become unready.

## Dashboards and metrics to inspect

Primary/replica health, failover state, memory and eviction, Lua latency, connection errors, registry heartbeat failures.

## Immediate actions

Identify whether media dedicated primary or general cache is affected; stop media scale-in and risky deployments.

## Safe mitigation

Fail over through the managed HA mechanism; restore connectivity; let nodes heartbeat and clients re-resolve.

## Dangerous actions to avoid

Do not switch registry to Redis Cluster or delete all keys to clear an incident; Lua spans dynamic keys.

## Recovery validation

Media registry rebuilds heartbeats, discovery selects healthy nodes, room snapshots reconcile, cache errors clear. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect failover timeline, key/ops metrics, script errors, data loss window, and affected node IDs. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
