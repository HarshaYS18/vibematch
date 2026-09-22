# Capacity emergency

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Demand exceeds measured API, gateway, worker, media, DB, Redis, or TURN headroom.

## Dashboards and metrics to inspect

Active work units vs tested per-pod capacity, HPA/KEDA status, pending pods, node autoscaler, DB connection budget, media peers/bandwidth.

## Immediate actions

Protect authoritative writes and ongoing calls; classify saturated layer and stop optional workloads.

## Safe mitigation

Scale the measured bottleneck within dependency budget; add provider node capacity if pending pods require it; apply rate limiting where necessary.

## Dangerous actions to avoid

Do not claim one-million-user capacity from pod counts or scale media solely on CPU.

## Recovery validation

Headroom and errors recover; test room join, WebSocket reconnect, media produce/consume, and ledger consistency. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Record peak RPS/sockets/peers, per-pod utilization, pending duration, DB connections, and applied limits. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
