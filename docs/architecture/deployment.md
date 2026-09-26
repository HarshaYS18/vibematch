# Staging and production rollout

Repository manifests and CI do not provision cloud credentials, DNS, certificates,
backups or measured capacity. Argo CD is the GitOps reconciler; production uses
reviewed immutable image digests.

## Traffic paths

```text
HTTPS API -> CDN/WAF/DDoS -> Envoy Gateway -> core compatibility / extracted services
GraphQL reads -> api.funkey.com/graphql -> GraphQL Read BFF -> owning service APIs
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

1. Verify external prerequisites, secrets, DNS/TLS, PostgreSQL/PgBouncer, three Redis roles, NATS, object storage/CDN, TURN and monitoring. For the full Chunk 37–48 platform, also verify Kafka, OpenSearch, ClickHouse and lake/object-storage dependencies.
2. Build/scan/sign immutable images and run all repository CI gates.
3. Apply additive Alembic migration using the direct migration DSN.
4. Apply/verify PostgreSQL ownership roles for extracted domains.
5. Deploy Identity/Profile-Social and Economy; verify Economy reconciliation is clean.
6. Deploy Inbox, Vibes, Room Control, Game Platform and Notification/provider workers.
7. Deploy core compatibility API with only documented reader roles for extracted domains.
8. Deploy specialized workers and verify JetStream consumers, retry/DLQ and readiness.
9. Deploy the Kafka Event Bridge only after NATS and Kafka are healthy; verify source-lag, ACK-after-Kafka-ACK behavior and outage recovery.
10. Deploy Search, rebuild a versioned OpenSearch index from owner events, validate it, then switch the query alias.
11. Deploy Recommendation, replay/warm its reconstructable candidate/ranking projection and verify blocked-content filtering.
12. Deploy the Analytics Sink after Kafka, ClickHouse and lake storage are healthy; verify idempotent ClickHouse writes and deterministic Parquet objects.
13. Deploy the GraphQL Read BFF after all owner read APIs are healthy; verify persisted-operation, auth, complexity and latency smoke tests.
14. Deploy/verify Envoy Gateway routes and canary weights only after their backends are ready; keep realtime upgrade-safe and media data-plane traffic outside HTTP Gateway.
15. Deploy Go realtime, verify public capability key, connect/room grants, Redis replay and drain.
16. Roll media nodes by drain; verify discovery, direct WebRTC and TURN-only paths.
17. Verify Media v2 signed upload -> completion -> processing/status in staging.
18. Promote client traffic after GraphQL/Search/Recommendation/data-platform smoke, application smoke, dashboards and rollback evidence pass.

## Rollback

Keep additive schema unless a reviewed data migration rollback explicitly requires
otherwise. Roll back application routing/images while preserving exactly one
durable owner per domain. Do not re-enable old DB mutation grants or dual writes.

For Economy, preserve transaction/ledger/journal history and the Economy writer
role. For realtime/media, drain before removal. Kafka/Search/Recommendation/
Analytics are downstream projection/read systems: disable their consumers or
routes when necessary, then replay/rebuild from the retained owner event path;
never recover them by enabling a second business writer. After rollback verify
snapshots, Inbox pagination, room replay, Watch Party/game control, notification
delivery, GraphQL reads, Search/Recommendation behavior, analytics lag, media
upload/RTC and Economy reconciliation.

## Evidence

Record image digests, migration head, ownership SQL version, manifest commit,
provider configuration version, smoke results, alert health and measured capacity.

## Chunk 35 Gateway contract

Production dynamic traffic uses Kubernetes Gateway API with Envoy Gateway. Public hostnames are `api.funkey.com`, `realtime.funkey.com`, and `media.funkey.com`; `cdn.funkey.com` stays at the upstream provider CDN/WAF. The gateway is routing/lifecycle infrastructure only and does not become a business authority.

API requests are version-routed before the core compatibility fallback. Realtime `/ws` is upgrade-safe and has no request buffering. Media control is a stable public alias for discovery/control; mediasoup/TURN data-plane addresses remain assignment-derived. The API canary backend starts at zero weight.

The provider WAF/DDoS layer must protect the Envoy origin. Optional Envoy `SecurityPolicy` external authorization is defense in depth and is activated only after a real ext-auth service is deployed.

## Chunk 36 GraphQL Read BFF rollout

Deploy the stateless GraphQL BFF after its owning read services are healthy and before enabling Flutter composite reads. The BFF has no database migration or durable state.

Rollback is routing/client-only: restore the previous Flutter read path or remove the exact `/graphql` route while preserving owner services. Never grant the BFF direct database access as an outage workaround.
