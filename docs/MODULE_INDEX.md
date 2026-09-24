# FunKey module index

Each guide records ownership, contracts, state, security, scaling, operations, and migration status. Read the [source-of-truth architecture](master-source-of-truth-architecture.md) before moving a domain boundary. A target module is a design boundary until its implementation and tests land; the module README states its current status.

## Deployables

- [core-api](modules/core-api/README.md)
- [realtime-gateway](modules/realtime-gateway/README.md)
- [worker](modules/worker/README.md)
- [notification](modules/notification/README.md)
- [media](modules/media/README.md)

## Business domains

- [auth](modules/auth/README.md)
- [users](modules/users/README.md)
- [profiles](modules/profiles/README.md)
- [rooms](modules/rooms/README.md)
- [presence](modules/presence/README.md)
- [social](modules/social/README.md)
- [inbox](modules/inbox/README.md)
- [moderation](modules/moderation/README.md)
- [economy](modules/economy/README.md)
- [wallet](modules/wallet/README.md)
- [gifts](modules/gifts/README.md)
- [store](modules/store/README.md)
- [games](modules/games/README.md)
- [vibes](modules/vibes/README.md)
- [notifications](modules/notification/README.md)
- [agency](modules/agency/README.md)
- [admin](modules/admin/README.md)

## Platform and operations

- [database](modules/database/README.md)
- [cache](modules/cache/README.md)
- [events](modules/events/README.md)
- [observability](modules/observability/README.md)
- [security](modules/security/README.md)
- [infrastructure](modules/infrastructure/README.md)
- [kubernetes](modules/kubernetes/README.md)
- [TURN](modules/TURN/README.md)
- [object-storage](modules/object-storage/README.md)
- [media-upload-v2](modules/media-upload-v2/README.md)
- [migrations](modules/migrations/README.md)
- [runbooks](modules/runbooks/README.md)

## Related guides

- [Architecture decisions](adr/README.md)
- [Architecture authority registry](architecture/authority-registry.md)
- [State classification](architecture/state-classification.md)
- [Service boundaries](architecture/service-boundaries.md)
- [Service contracts](architecture/service-contracts.md)
- [PostgreSQL platform foundation](architecture/postgresql-platform.md)
- [Redis / Valkey platform](architecture/redis-valkey-platform.md)
- [Room State Engine v2](architecture/room-state-engine-v2.md)
- [Protobuf contract source tree](../contracts/proto/README.md)
- [Authority conformance runbook](runbooks/authority-registry.md)
- [Capacity model](architecture/capacity-model.md)
- [Node autoscaling strategy](architecture/node-autoscaling.md)
- [Failure testing strategy](architecture/failure-testing.md)
- [Migration policy](architecture/migrations.md)
- [Deployment and rollback](architecture/deployment.md)
- [Operational runbooks](runbooks/README.md)
- [External prerequisites](EXTERNAL_PREREQUISITES.md)
- [Go realtime gateway implementation guide](../apps/realtime-gateway/README.md)
