# Security incident

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Replace example paths with the active environment; never paste credentials into incident notes.

## Symptoms

Credential exposure, suspicious privileged actions, token abuse, or unexpected data access.

## Dashboards and metrics to inspect

Auth failures, role/audit logs, rate-limit hits, secret-manager access, source IP/device signals, outbound transfers.

## Immediate actions

Preserve evidence and restrict active abuse; rotate exposed credentials through the owner-managed secret manager.

## Safe mitigation

Revoke sessions/keys when supported, deploy patched policy, and review affected data and transactions.

## Dangerous actions to avoid

Do not paste secrets into tickets or logs, erase evidence, or silently rewrite ledger history.

## Recovery validation

Attempted abuse is blocked; rotated credentials work; affected privileged actions are reconciled and monitored. Keep elevated monitoring until the incident window and delayed work are reconciled.

## Escalation and data to collect

Record request IDs, actor IDs, timestamps, affected keys/data, rotation proof, and incident owner. Escalate to the owning application, database, network, or security team when mitigation exceeds the runbook or data integrity is uncertain.
