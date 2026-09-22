# Operational runbooks

Choose the incident matching the failing layer. For planned deployment, start with the drain runbooks before reducing replicas. Each runbook identifies observations, safe actions, validation, and evidence. Run them in staging as drills before relying on them in production.

- [API degraded](api-degraded.md)
- [Realtime degraded](realtime-degraded.md)
- [Realtime gateway drain](realtime-drain.md)
- [Media node drain](media-node-drain.md)
- [Media outage](media-outage.md)
- [TURN outage](turn-outage.md)
- [Redis/Valkey outage](redis-outage.md)
- [PostgreSQL outage](database-outage.md)
- [Database restore](database-restore.md)
- [Queue backlog](queue-backlog.md)
- [Failed deployment](failed-deployment.md)
- [Failed migration](failed-migration.md)
- [High latency](high-latency.md)
- [Capacity emergency](capacity-emergency.md)
- [Region failure](region-failure.md)
- [Security incident](security-incident.md)
- [Authority registry conformance](authority-registry.md)
