# Realtime gateway drain

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Planned gateway rollout or node removal risks dropping long-lived sockets.

## Dashboards and metrics to inspect

Draining flag, ready state, active connections, new upgrades, reconnect rate, outbound queue, HPA target.

## Immediate actions

Mark target gateway draining and remove it from new upgrade routing before terminating.

## Safe mitigation

Wait for active sockets to reconnect or finish until the bounded drain deadline; keep enough healthy replicas for reconnect surge.

## Dangerous actions to avoid

Do not kill a gateway with many live sockets or rely on LB affinity for correctness.

## Recovery validation

No new upgrades reach target; active count falls; clients reconnect and fetch correct snapshots elsewhere. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Record target pod, image, start/end times, active sockets at deadline, and reconnect failures. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
