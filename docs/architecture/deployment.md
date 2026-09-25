# Staging and production rollout

Repository manifests and CI do not provision cloud credentials, DNS, certificates,
backups or measured capacity. Argo CD is the GitOps reconciler; production uses
reviewed immutable image digests.

## Traffic paths

```text
HTTPS API -> CDN/WAF/DDoS -> Envoy Gateway -> core compatibility / extracted services
Application WebSocket -> Envoy Gateway -> Go realtime gateway (funkey.v2)
Media control/discovery -> Envoy Gateway -> core control plane -> assigned backend_media node
Media RTP/RTC -> assigned public SFU or TURN (never HTTP Gateway)
Static/media delivery -> cdn.funkey.com -> provider CDN/object origin
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

## Chunk 35 Gateway contract

Production dynamic traffic uses Kubernetes Gateway API with Envoy Gateway. Public hostnames are `api.funkey.com`, `realtime.funkey.com`, and `media.funkey.com`; `cdn.funkey.com` stays at the upstream provider CDN/WAF. The gateway is routing/lifecycle infrastructure only and does not become a business authority.

API requests are version-routed before the core compatibility fallback. Realtime `/ws` is upgrade-safe and has no request buffering. Media control is a stable public alias for discovery/control; mediasoup/TURN data-plane addresses remain assignment-derived. The API canary backend starts at zero weight.

The provider WAF/DDoS layer must protect the Envoy origin. Optional Envoy `SecurityPolicy` external authorization is defense in depth and is activated only after a real ext-auth service is deployed.
