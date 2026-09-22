# Service Boundaries

**Owner:** Platform Architecture  
**Status:** Logical boundaries established in Chunk 15; physical extraction occurs later

A boundary is a coherent business capability, not a reason to create more processes. After extraction only the owning service may mutate its database; other services use APIs or versioned events.

| Logical owner | Current deployable | Target |
|---|---|---|
| Identity | core-api | Identity Service |
| Profile/Social | core-api | Profile/Social Service |
| Room Control | core-api | Room Control Service |
| Inbox | core-api | Inbox Service |
| Vibes | core-api | Vibes/Feed Service |
| Economy | core-api | Economy Service |
| Game Platform | core-api + CDN bridge | Game Platform Service |
| Notification | core-api + worker | Notification Service |
| Media Control | core-api + backend_media | Media Platform |
| Realtime | Go gateway + compatibility FastAPI sockets | one Go application WebSocket |
| Worker Platform | worker | specialized worker pools |
| Search Projection | direct DB search | OpenSearch projection workers |
| Recommendation | not deployed | Recommendation Platform |
| Analytics | outbox/NATS operational path | Kafka + ClickHouse/data lake |
| GraphQL Read BFF | not deployed | composite-read BFF only |

## Communication

Immediate answer: REST now and gRPC/Protobuf for extracted internal services after Chunk 17. Operational async: NATS JetStream through transactional outbox. Long-retained analytics/ML: Kafka after Chunk 37. Composite reads: GraphQL BFF after service boundaries; never business authority.

## Database ownership

Shared PostgreSQL today does not mean shared ownership. After extraction, Game Platform calls Economy for settlement, Inbox uses Profile APIs/events for display metadata, and Go realtime never writes wallet/room business truth.

Economy exclusively owns wallet balances/ledger, coin supply/pool ledger, gift settlement, game financial settlement, mission rewards, purchases/refunds and other value movement. Game Platform owns round lifecycle but asks Economy to settle.

Go realtime owns connections, subscriptions, fanout, typing, routing and reconstructable presence leases. `backend_media` owns mediasoup transport lifecycle. Flutter repositories own displayed client state only; `RoomSessionRepository` remains the one room client authority.

Do not physically extract a service until authority, contracts, isolated writes, observability, runbook, backward-compatible migration, shadow/compare/canary and rollback are ready. This is why Chunks 15–19 precede extraction.
