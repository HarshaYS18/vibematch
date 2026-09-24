# Staging and production rollout

Repository manifests and CI do not provision cloud credentials, DNS, certificates,
backups or measured capacity. Argo CD is the GitOps reconciler; production uses
reviewed immutable image digests.

## Traffic paths

```text
HTTPS API -> edge/WAF/LB -> ingress -> core compatibility and extracted domain services
Application WebSocket -> WS ingress -> Go realtime gateway (funkey.v2)
Media signaling/RTC -> discovery -> backend_media SFU; restricted networks -> TURN
Direct media upload -> signed object-store URL; control/status -> Media v2 API
```

There is no normal FastAPI application-WebSocket fallback after Chunk 21. A
rollback may use a specifically compatible build, but production topology should
not keep duplicate application socket authorities.

## Release sequence

1. Verify external prerequisites, secrets, DNS/TLS, PostgreSQL/PgBouncer, three Redis roles, NATS, object storage/CDN, TURN and monitoring.
2. Build/scan/sign immutable images and run all repository CI gates.
3. Apply additive Alembic migration using the direct migration DSN.
4. Apply/verify PostgreSQL ownership roles for extracted domains.
5. Deploy Identity/Profile-Social and Economy; verify Economy reconciliation is clean.
6. Deploy Inbox, Vibes, Room Control, Game Platform and Notification/provider workers.
7. Deploy core compatibility API with only documented reader roles for extracted domains.
8. Deploy specialized workers and verify JetStream consumers, retry/DLQ and readiness.
9. Deploy Go realtime, verify public capability key, connect/room grants, Redis replay and drain.
10. Roll media nodes by drain; verify discovery, direct WebRTC and TURN-only paths.
11. Verify Media v2 signed upload -> completion -> processing/status in staging.
12. Promote client traffic after smoke, dashboards and rollback evidence pass.

## Rollback

Keep additive schema unless a reviewed data migration rollback explicitly requires
otherwise. Roll back application routing/images while preserving exactly one
durable owner per domain. Do not re-enable old DB mutation grants or dual writes.

For Economy, preserve transaction/ledger/journal history and the Economy writer
role. For realtime/media, drain before removal. After rollback verify snapshots,
Inbox pagination, room replay, Watch Party/game control, notification delivery,
media upload/RTC and Economy reconciliation.

## Evidence

Record image digests, migration head, ownership SQL version, manifest commit,
provider configuration version, smoke results, alert health and measured capacity.
