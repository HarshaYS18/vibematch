# Failed deployment

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

New revision fails readiness, error rates rise, or canary behavior differs.

## Dashboards and metrics to inspect

Image digest, Argo CD diff/sync history, pod events, probes, p95/error panels, migration version.

## Immediate actions

Pause promotion; preserve current logs; compare revision and config to last known-good state.

## Safe mitigation

Reconcile prior immutable image/config digest when schema remains compatible; keep media/gateway drain rules.

## Dangerous actions to avoid

Do not roll back a schema blindly or force-delete media pods to speed recovery.

## Recovery validation

Old revision ready, new errors cease, room/WebSocket/media smoke tests pass, drift is resolved. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Collect commit, image digest, manifest diff, rollout timestamp, migrations, and failing traces. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
