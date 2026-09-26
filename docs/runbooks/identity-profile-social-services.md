# Identity and Profile/Social Runbook

## Healthy state
Both services expose /live, /ready and /metrics. Core proxy 5xx should remain near zero. Watch DB pool saturation, p95/p99 latency, error rate and dependency failures.

## Identity incident
Stop rollout expansion if Identity readiness fails. Verify service DB credentials, Alembic head, pool saturation, signing configuration and internal token. Do not bypass account-ban or session checks.

## Profile/Social incident
Profile/social writes should fail closed with bounded 503 responses while unrelated APIs remain healthy. Check DB readiness, Inbox dependency for relationship/family-chat operations, internal token and pool saturation. Do not restore direct core writes as an incident shortcut.

## Session reconciliation
A successful new login revokes the user's older active durable session. Tokens without sid belong only to the pre-Chunk-27 compatibility window and disappear by normal expiry.

## Database cutover
Run Alembic first. Apply identity-ownership.sql and profile-social-ownership.sql with an admin/migration role. Bind distinct production service logins to the runtime roles. Bind the core API login only to funkey_identity_reader and funkey_profile_social_reader for composite reads. Verify column-level profile grants before removing legacy core write privilege; never grant the core API either mutation runtime role.

## Rollback
Rollback code/routing first. Do not drop identity_sessions or identity_devices. They are additive and safe to retain during investigation.
