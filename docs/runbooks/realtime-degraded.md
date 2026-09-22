# Realtime degraded

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

WebSocket upgrades fail, room events lag, reconnect rate spikes, or outbound queues saturate.

## Dashboards and metrics to inspect

Gateway/FastAPI socket count, upgrade errors, messages/sec, queue depth, reconnect rate, Redis and broker latency, pod restarts.

## Immediate actions

Freeze gateway rollout; identify whether transport, auth, Redis fanout, or room authority is failing.

## Safe mitigation

Shift new connections to healthy ready replicas; let clients reconnect and refetch room snapshots; restore broker/cache before raising capacity.

## Dangerous actions to avoid

Do not claim delivery by sticky sessions or drop backpressure limits to hide saturation.

## Recovery validation

Join, seat update, chat, reconnect, and event-gap snapshot recovery work across two replicas. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect connection IDs without tokens, trace IDs, close codes, queue metrics, and affected room IDs. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
