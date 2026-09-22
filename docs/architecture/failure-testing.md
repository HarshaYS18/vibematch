# Failure and chaos testing strategy

Run fault drills in a disposable or staging environment with production-like topology and sanitized data. Define a steady-state check before injection: representative API reads/writes, room event delivery, WebSocket reconnect, media produce/consume, queue lag, and ledger invariants. Stop a drill if value integrity or user privacy is uncertain. Record blast radius, start/stop UTC time, recovered state, and the runbook used.

| Fault | Expected behavior and validation |
| --- | --- |
| API pod termination or rolling deployment | Other ready replicas serve traffic; in-flight requests finish or fail clearly; retries do not duplicate writes |
| Gateway pod termination or planned drain | Reconnects spread to healthy pods; clients refetch room snapshots; no authority depends on sticky sessions |
| Redis outage/failover | Media registry and gateway readiness reflect loss; no wallet/ban authority is lost; heartbeat and assignments recover |
| PostgreSQL restart/failover | Unsafe writes stop, pool connections recover, Alembic revision and ledgers reconcile |
| NATS backlog/worker crash | JetStream retains work; bounded retries and dead-letter behavior prevent poison-message loops |
| Kubernetes node eviction and zone/node-pool loss | Disruption budgets and spread preserve minimum capacity; pending pods drive provider node autoscaler where available |
| Media node disappearance or drain | New assignments avoid missing/draining node; existing peers re-resolve or drain by deadline |
| TURN-only network | Real clients complete ICE through relay and carry bidirectional media |
| Failed migration | Deployment stops; no runtime schema patch; reviewed forward fix or tested restore recovers |
| Object storage outage | Uploads fail explicitly, existing durable metadata remains consistent, no pod-local permanent fallback |

Automate pod kills, dependency network blocks, broker pauses, and read/write assertions in a controlled cluster where access exists. A local Docker test cannot prove provider AZ failure, global DNS failover, WebRTC packet capacity, or a live managed PostgreSQL restore. Those require a scheduled staging drill with the real provider and a recorded result.

The [runbook index](../runbooks/README.md) contains the response procedure for each layer. Do not mark a chaos scenario passed because the injection command completed; the steady-state and recovery assertions must also pass.
