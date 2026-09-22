# High latency

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

p95 or p99 rises while error rate may remain low.

## Dashboards and metrics to inspect

Route traces, DB slow queries/pool wait, Redis Lua latency, broker lag, GC/CPU, ingress queue, network RTT.

## Immediate actions

Scope affected path and region; stop recent rollout if correlated.

## Safe mitigation

Reduce noisy traffic, restore saturated dependency, tune only after a trace identifies the bottleneck.

## Dangerous actions to avoid

Do not multiply replicas past DB connection budget or hide timeouts with arbitrary large limits.

## Recovery validation

Representative user flows return to baseline latency without increased errors or queueing. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect trace IDs, percentile windows, top queries, lock waits, saturation and change timeline. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
