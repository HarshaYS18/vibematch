# Production-oriented architecture

FunKey is an evolutionary social/live-room platform with independently scalable
business, realtime, worker and media workloads. Repository reality through
Chunk 32 is no longer a single FastAPI monolith.

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

## Data and messaging

PostgreSQL remains durable business truth, with isolated owner/runtime roles per
extracted domain. PgBouncer transaction pooling is used for compatible traffic;
migrations use the direct migration DSN.

Redis/Valkey has separate cache, realtime/presence and media-registry roles.
Redis state is cache/ephemeral/projection only and must be reconstructable.

NATS JetStream carries durable operational async work originating from the
transactional outbox. Future Kafka/ClickHouse analytics remains downstream and
is not business authority.

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

## Evolution

Search, Recommendation, GraphQL read BFF, Kafka/ClickHouse analytics and further
service extraction remain future chunks. Their introduction must preserve the
machine authority registry and cannot create duplicate durable truth.

See `authority-registry.md`, `service-boundaries.md`, `deployment.md`, the ADR
index, capacity model and operational runbooks for the enforceable detail.
