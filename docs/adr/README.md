# Architecture decision records

These decisions describe the target and invariants; they do not assert every implementation is deployed. The completion report records actual implementation and validation.

- [ADR-001: Go as target backend language](ADR-001-go-target-language.md)
- [ADR-002: Strangler migration instead of a big-bang rewrite](ADR-002-strangler-migration.md)
- [ADR-003: PostgreSQL as durable source of truth](ADR-003-postgresql-durable-truth.md)
- [ADR-004: Redis/Valkey ephemeral-state policy](ADR-004-redis-ephemeral-state.md)
- [ADR-005: NATS JetStream as primary distributed event broker](ADR-005-nats-jetstream.md)
- [ADR-006: Kubernetes orchestration](ADR-006-kubernetes-orchestration.md)
- [ADR-007: Media control plane and media plane separation](ADR-007-media-control-plane-separation.md)
- [ADR-008: Dedicated HA single-primary Redis for media registry](ADR-008-media-redis-topology.md)
- [ADR-009: Object storage and CDN policy](ADR-009-object-storage-policy.md)
- [ADR-010: Realtime gateway ownership](ADR-010-realtime-gateway-ownership.md)
- [ADR-011: Database connection budget](ADR-011-database-connection-budget.md)
- [ADR-012: Argo CD GitOps deployment strategy](ADR-012-gitops-deployment.md)
- [ADR-013: Machine-readable state authority registry](ADR-013-authority-registry.md)
- [ADR-014: PostgreSQL transaction pooling and credential boundaries](ADR-014-postgresql-pooling-boundaries.md)
- [ADR-015: Redis role isolation and ephemeral-state policy](ADR-015-redis-role-isolation.md)
- [ADR-016: Room State Engine v2](ADR-016-room-state-engine-v2.md)
