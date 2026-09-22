# Media outage

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Media discovery returns 503, signaling fails, or users join rooms without audio.

## Dashboards and metrics to inspect

Media node /health and /ready, heartbeat age, registry availability, room/peer capacity, SFU worker errors, UDP/TCP loss.

## Immediate actions

Stop media rollout; separate control-plane authorization failure from SFU/registry/network failure.

## Safe mitigation

Restore a healthy node and registry; ask clients to re-resolve media through FastAPI after a node disappears.

## Dangerous actions to avoid

Do not direct clients to an arbitrary media host or bypass reauthorization.

## Recovery validation

New and existing rooms can produce/consume audio across the intended network, including a restricted network test. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect node ID, room ID, ICE state, announced address, RTP port range, request IDs, and worker crash logs. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
