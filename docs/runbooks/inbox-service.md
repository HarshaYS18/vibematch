# Inbox Service Runbook

## Readiness

Check the `funkey-inbox` /live and /ready endpoints, PostgreSQL pool health, NATS connectivity from Inbox, and `funkey_realtime_nats_inbox_subscription_up` on the Go gateway.

## Common failures

If Inbox is unavailable, keep core-domain writers from falling back to shared-table writes. Restore service/DB connectivity and replay or reconcile adapter state where needed.

If realtime delivery is degraded but Inbox HTTP/DB are healthy, users can continue durable writes and recover by REST refresh. Repair NATS or the Go gateway; do not move message truth into Redis.

If PostgreSQL pool saturation occurs, compare Inbox replicas and per-pod pool size against `DB_INBOX_CONNECTION_BUDGET` before scaling. The global pooler budget includes API, Inbox, workers, and rollout reserve.

## Checks

Verify a conversation list GET produces no commits, returns at most the requested capped page, and embeds only the active message window. Verify older history advances through cursors without duplicates or gaps.

Verify mark-read creates recent read receipts, clears the participant unread count, and emits a Go-delivered realtime update.

Verify core API credentials cannot write Inbox tables in production and that the Inbox login can read only the required identity context.

## Rollout

Migrate first, apply ownership grants, deploy Inbox, verify direct service health, verify Go NATS subscription, then move ingress traffic. Keep the compatibility proxy available until the canary/soak gates in the wider production plan pass.
