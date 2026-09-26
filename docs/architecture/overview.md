# Production-oriented architecture

FunKey is an evolutionary social/live-room platform with independently scalable
business, realtime, worker, projection, analytics and media workloads. Repository
reality through Chunk 56 is an evolutionary multi-service platform rather than a
single FastAPI monolith.

## Runtime topology

- **Core FastAPI API (`8000`)** — stable public compatibility/composite-read
  surface plus domains not yet extracted. It is not allowed to regain mutation
  authority for extracted services.
- **Identity (`8086`)** and **Profile/Social (`8087`)** — durable identity and
  social/profile mutation boundaries.
- **Inbox (`8083`)**, **Vibes (`8084`)**, **Room Control (`8085`)** — extracted
  durable domain authorities.
- **Economy (`8088`)** — exclusive Tier-0 financial writer.
- **Game Platform (`8089`)** — game lifecycle authority; calls Economy for value.
- **Notification (`8090`)** plus provider worker — notification/delivery authority.
- **Go realtime (`8081`)** — the single application WebSocket transport.
- **Python worker pools (`8082`)** — bounded async execution/retry/DLQ.
- **`backend_media` (`4100`)** — canonical mediasoup/WebRTC media plane.
- **GraphQL Read BFF (`8091`)** — stateless persisted composite reads over owning APIs.
- **Kafka Event Bridge** — the only approved NATS-to-Kafka application bridge.
- **Search Service** — OpenSearch-backed rebuildable discovery projection.
- **Recommendation Service** — rebuildable candidate/ranking feed projection.
- **Analytics Sink** — Kafka consumer that materializes ClickHouse and Parquet/data-lake projections.

## Data and messaging

PostgreSQL remains durable business truth, with isolated owner/runtime roles per
extracted domain. PgBouncer transaction pooling is used for compatible traffic;
migrations use the direct migration DSN.

Redis/Valkey has separate cache, realtime/presence and media-registry roles.
Redis state is cache/ephemeral/projection only and must be reconstructable.

NATS JetStream carries durable operational async work originating from the
transactional outbox. Kafka is the retained analytics/replay/ML stream fed only
through the Kafka Event Bridge. OpenSearch, Recommendation Redis projections,
ClickHouse and Parquet/object-storage lake data are reconstructable downstream
projections and are not business authority.

## Realtime

The Go gateway carries Inbox, room, presence, notification and other application
realtime over `funkey.v2`. Signed short-lived capabilities authorize connect and
room subscriptions locally at the gateway. Durable commands still execute at
their owning service. Mediasoup signaling remains a separate media channel.

## Media

Media v2 uses API upload-session control plus direct object-store data transfer.
PostgreSQL owns upload/processing/variant state; object storage/CDN owns bytes.
Processing/moderation/cleanup execute asynchronously. `backend_media` owns only
SFU transport lifecycle.

## Flutter

Flutter is never durable authority. Room state converges through
`RoomSessionRepository`; REST/control-plane traffic converges on
`AppNetworkClient -> CanonicalNetworkTransport -> Dio`. Feature code may not
instantiate competing HTTP clients.

## Roadmap closure

Chunks 15–56 are implemented as repository architecture and deployable
boundaries. The GraphQL Read BFF, Kafka data platform, Search/OpenSearch,
Recommendation, multi-region/DR contracts, security/privacy/trust controls,
realtime/media QoS, mobile/offline runtime, cache/edge policy, Analytics
Sink/ClickHouse/Parquet, release safety, SRE/FinOps, documentation/governance,
release management and final decommissioning controls are part of the current
repository.

This is not a claim that every external production dependency has been
provisioned or that capacity/SLO certification has been measured. External
credentials, managed services and the versioned production-certification
evidence remain deployment-time prerequisites.

See `authority-registry.md`, `service-boundaries.md`, `deployment.md`, the ADR
index, capacity model and operational runbooks for the enforceable detail.
