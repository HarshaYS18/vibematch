# Media node drain

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

A media pod must be retired for deployment, scale-in, or host maintenance.

## Dashboards and metrics to inspect

GET /api/v1/admin/media/nodes, node /ready, room_count, peer_count, heartbeat age, new assignments.

## Immediate actions

Use the authorized admin PATCH /api/v1/admin/media/nodes/{node_id}/drain with {"draining":true}, or the pod loopback /drain hook; verify the registry reports draining.

## Safe mitigation

Stop new room assignment; keep existing room sessions alive; wait for peer count to reach zero or approved deadline; then terminate.

## Dangerous actions to avoid

Do not delete the Redis node key first, change room assignment by hand, or terminate with active rooms without incident approval.

## Recovery validation

Discovery selects other nodes for new rooms; existing room audio remains; target goes offline after peer drain. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Record node ID, rooms, peers, signaling URL, drain duration, and users forced to reconnect. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
