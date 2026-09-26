# FunKey module index

Use this index to find the current owner, contracts, runbooks and architecture
for the repository through Chunk 47. A service name here means the deployable
exists. GraphQL read composition and the Kafka analytics bridge are now deployed
platform boundaries; Search and Recommendation are deployed projection boundaries.

## Deployables

- [core-api](modules/core-api/README.md)
- [Go realtime gateway](../apps/realtime-gateway/README.md)
- [Worker Platform](modules/worker/README.md)
- [GraphQL Read BFF](modules/graphql-read-bff/README.md)
- [Kafka Event Bridge](modules/kafka-event-bridge/README.md)
- [Search Service](modules/search/README.md)
- [Recommendation Service](modules/recommendation/README.md)
- [Inbox Service](architecture/inbox-service.md)
- [Vibes Service](architecture/vibes-service.md)
- [Room Control Service](architecture/room-control-service.md)
- [Identity + Profile/Social](architecture/identity-profile-social-services.md)
- [Economy Service](architecture/economy-service.md)
- [Game Platform Service](architecture/game-platform-service.md)
- [Notification Service](modules/notification/README.md)
- [Media / mediasoup](modules/media/README.md)
- [Media upload v2](modules/media-upload-v2/README.md)

## Business domains

- [auth / Identity](modules/auth/README.md)
- [users](modules/users/README.md)
- [profiles](modules/profiles/README.md)
- [social](modules/social/README.md)
- [rooms](modules/rooms/README.md)
- [presence](modules/presence/README.md)
- [inbox](modules/inbox/README.md)
- [vibes](modules/vibes/README.md)
- [economy](modules/economy/README.md)
- [wallet](modules/wallet/README.md)
- [gifts](modules/gifts/README.md)
- [games](modules/games/README.md)
- [notifications](modules/notification/README.md)
- [store](modules/store/README.md)
- [moderation](modules/moderation/README.md)
- [agency](modules/agency/README.md)
- [admin](modules/admin/README.md)

## Platform and operations

- [database](modules/database/README.md)
- [cache / Redis](modules/cache/README.md)
- [events / NATS](modules/events/README.md)
- [observability](modules/observability/README.md)
- [security](modules/security/README.md)
- [Privacy / data governance](architecture/privacy-data-governance.md)
- [Trust / safety / Economy integrity](architecture/trust-safety-integrity.md)
- [infrastructure](modules/infrastructure/README.md)
- [Kubernetes](modules/kubernetes/README.md)
- [TURN](modules/TURN/README.md)
- [object storage](modules/object-storage/README.md)
- [migrations](modules/migrations/README.md)
- [runbooks](runbooks/README.md)

## Canonical architecture

- [Machine authority registry](../contracts/architecture/authorities.yaml)
- [Human authority guide](architecture/authority-registry.md)
- [Service boundaries](architecture/service-boundaries.md)
- [Architecture overview](architecture/overview.md)
- [State classification](architecture/state-classification.md)
- [Service contracts](architecture/service-contracts.md)
- [PostgreSQL platform](architecture/postgresql-platform.md)
- [Redis / Valkey platform](architecture/redis-valkey-platform.md)
- [Kafka data platform](architecture/kafka-data-platform.md)
- [Search platform](architecture/search-platform.md)
- [Recommendation platform](architecture/recommendation-platform.md)
- [Multi-region platform](architecture/multi-region.md)
- [Realtime / media QoS](architecture/realtime-media-qos.md)
- [Mobile runtime / offline](architecture/mobile-runtime-offline.md)
- [Cache / edge](architecture/cache-edge.md)
- [Room State Engine v2](architecture/room-state-engine-v2.md)
- [Go realtime v2](architecture/go-realtime-platform-v2.md)
- [Media v2](architecture/media-v2-upload.md)
- [Canonical Flutter networking](architecture/flutter-canonical-networking.md)
- [Observability platform](architecture/observability-platform.md)
- [Capacity model](architecture/capacity-model.md)
- [Deployment](architecture/deployment.md)
- [Failure testing](architecture/failure-testing.md)
- [ADRs](adr/README.md)

## Rule

When changing a boundary, update the machine registry, this index, the owning
module/service README, architecture guide, runbook and enforcement test/guard in
the same change.
