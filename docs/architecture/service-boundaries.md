# Service Boundaries

**Owner:** Platform Architecture  
**Status:** current repository reality through Chunk 56 plus the final audit repair pass

A boundary is a coherent business capability, not a reason to create duplicate
truth. After extraction, only the owning service may mutate its durable tables;
other services use authenticated APIs, versioned events, or explicitly read-only
database roles for bounded composite reads.

| Logical owner | Current deployable | Durable / operational rule |
|---|---|---|
| Identity | `identity-service` | Owns account/security/session/device truth. Core is a compatibility facade/read composer only. |
| Profile/Social | `profile-social-service` | Owns profile mutation, social graph, relationships and family membership. |
| Room Control | `room-control-service` | Owns room definition/membership/permissions/seats/Watch Party/activity and Room Cricket tournament/match/ball truth. |
| Inbox | `inbox-service` | Owns conversations/messages/read state/Inbox preferences and family community chat. |
| Vibes | `vibes-service` | Owns Vibes content/reactions/feed source state; ranking copies remain projections. |
| Economy | `economy-service` | Exclusive writer for wallet/ledger, supply/game pools, durable house liability, gift/Lucky Packet settlement, mission rewards and game financial settlement. |
| Game Platform | `game-platform-service` + CDN runtime bridge | Owns game catalog/session/round/bet/risk/stats lifecycle. Calls Economy for value. |
| Notification | `notification-service` + provider worker | Owns in-app notification truth, device tokens/preferences/templates and delivery state. FCM is transport. |
| Media Control | core media control + direct object storage + media worker | PostgreSQL owns media metadata/upload/processing truth; object storage owns bytes only. |
| Realtime | Go realtime gateway | Owns application WebSocket transport/routing/presence/replay only; never durable business truth. |
| Worker Platform | specialized Python worker pools | Owns execution/retry/backpressure/DLQ mechanics, not domain truth. |
| Media plane | `backend_media` | Owns mediasoup/WebRTC transport lifecycle only. |
| Search Projection | `search-service` + OpenSearch | Owns search projection/query availability only; indexes are versioned and rebuildable from owner events. |
| Recommendation | `recommendation-service` + Redis | Owns candidate/ranking projection availability only; output is reconstructable and never business truth. |
| Analytics retained stream | `kafka-event-bridge` + Kafka | Owns retained analytical/replay transport downstream of NATS; never RPC or command authority. |
| Analytics warehouse/lake | `analytics-sink` + ClickHouse/Parquet | Owns rebuildable analytical materialization only; never authorization or business truth. |
| GraphQL Read BFF | `graphql-bff` | Composite-read surface for Home, Profile, Discovery and creator/admin dashboards. Calls owning APIs only; never a mutation or database authority. |

## Communication

- Public/mobile compatibility: stable REST paths through core where needed.
- Extracted synchronous service calls: authenticated internal HTTP today; versioned protobuf contracts define the approved gRPC direction.
- Application realtime: one Go `funkey.v2` WebSocket plus Redis/Valkey routing/replay.
- Operational async work: NATS JetStream through the transactional outbox.
- Long-retained analytics/ML: Kafka is fed only through the transactional-outbox -> NATS -> Kafka Event Bridge path; it never replaces NATS operational messaging or becomes RPC.
- Search and Recommendation: versioned/rebuildable projections served by their dedicated services; domain owners remain authoritative.
- Analytical materialization: the Analytics Sink writes ClickHouse and Parquet/object-storage projections from Kafka.
- Composite reads: GraphQL Read BFF composes owner APIs for approved persisted reads; direct owner APIs remain valid for non-composite reads. GraphQL never owns commands.

## Database ownership

PostgreSQL remains the durable database platform, but shared physical PostgreSQL
does not imply shared mutation authority. Extracted domains use isolated owner/
runtime roles. Core may receive documented reader roles for composite reads.

Economy is Tier-0: other deployables must not receive the Economy runtime role.
Game Platform calls Economy for wager/settlement. Go realtime never writes room,
Inbox or wallet business tables. Redis is CACHE/EPHEMERAL only.

## Client boundary

Flutter repositories own displayed/cache state only. Durable conflicts resolve
to backend snapshots/events. REST/control-plane traffic follows:

`Repository / feature service -> AppNetworkClient -> CanonicalNetworkTransport -> Dio`

`RoomSessionRepository` remains the single Flutter room-state authority. Media
engines own transport/producer/consumer lifecycle, not room business state.

## Extraction standard

No service boundary is considered complete without authority registration,
isolated writes, stable compatibility contracts, observability, regression and
architecture guards, runbooks, rollback procedure, and a no-dual-write cutover.
