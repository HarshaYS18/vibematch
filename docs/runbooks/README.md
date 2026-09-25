# Operational runbooks

Choose the incident matching the owning layer. A healthy core API does not prove
an extracted domain is healthy. For planned deployment, use the relevant drain/
rollback runbook before reducing capacity. Exercise these procedures in staging.

## Domain services
- [Economy Service](economy-service.md)
- [Game Platform Service](game-platform-service.md)
- [Inbox Service](inbox-service.md)
- [Vibes Service](vibes-service.md)
- [Room Control Service](room-control-service.md)
- [Identity / Profile-Social](identity-profile-social-services.md)
- [Notification Service](notification-service.md)
- [Worker Platform](worker-platform.md)
- [Media v2 upload/processing](media-v2-upload.md)

## Platform incidents
- [GraphQL Read BFF](graphql-read-bff.md)
- [API Gateway / edge](api-gateway.md)
- [API degraded](api-degraded.md)
- [Realtime degraded](realtime-degraded.md)
- [Room state replay / desynchronization](room-state-desync.md)
- [Realtime gateway drain](realtime-drain.md)
- [Media node drain](media-node-drain.md)
- [Media outage](media-outage.md)
- [TURN outage](turn-outage.md)
- [Redis/Valkey outage](redis-outage.md)
- [PostgreSQL outage](database-outage.md)
- [PostgreSQL / PgBouncer saturation](database-pool-saturation.md)
- [Database restore](database-restore.md)
- [Queue backlog](queue-backlog.md)
- [Failed deployment](failed-deployment.md)
- [Failed migration](failed-migration.md)
- [High latency](high-latency.md)
- [Capacity emergency](capacity-emergency.md)
- [Region failure](region-failure.md)
- [Security incident](security-incident.md)
- [Authority registry conformance](authority-registry.md)
- [Observability degraded](observability-degraded.md)

## Incident rule

Never recover by creating a second durable writer. If an extracted service is
down, preserve its ownership boundary and recover/rollback that service or route
through a compatible facade; do not grant its DB mutation role to core.
