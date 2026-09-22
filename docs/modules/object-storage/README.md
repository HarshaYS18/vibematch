# Object Storage

## Purpose and responsibilities

Persists uploaded assets outside application pods and returns CDN/object URLs. S3-compatible media objects and asset metadata.

## Ownership and source of truth

PostgreSQL remains the durable source of truth for application state. This module does not take over an adjacent domain merely because it transports or caches its data. Refer to the source-of-truth architecture before changing ownership.

## Important files and public contracts

`backend/app/services/media_storage_service.py`, `backend/app/services/cdn_media_service.py`, `backend/app/models/cdn_media.py`. Contract surface: Media upload and retrieval routes under /api/v1. Keep existing Flutter-compatible paths and payloads until a versioned migration is ready.

## Events published and consumed

This component may publish or consume versioned domain events as contracts are implemented. Existing room WebSocket/Redis events are distinct from durable JetStream publication; do not assume all proposed events are live.

## Database and Redis state

Database: cdn_media_assets, media_safety_settings, support_attachments. Redis/Valkey: No permanent object bytes or authorization in Redis.

## Dependencies and security

Dependencies include the configured runtime, PostgreSQL, Redis/Valkey, and relevant internal contracts where applicable. Validate size/type, ownership, moderation, signed URL scope, and private object ACLs. Do not log tokens, credentials, private content, or payment secrets.

## Failure modes and retry/idempotency

On object-store outage reject new uploads safely; do not pretend a DB row proves bytes exist. Use bounded timeouts and explicit retry budgets. Only replay writes when a stable idempotency key or reconciliation proves the commit outcome.

## Scaling and autoscaling metrics

Scale this workload independently when deployed. Measure its primary work unit, CPU, memory, saturation, errors, p95 latency, queue/backpressure where relevant, and dependency pressure. Respect the database connection budget and drain before scale-in.

## Observability

Propagate request and trace IDs through internal calls. Emit structured logs and low-cardinality metrics for readiness, throughput, failures, and drain progress. Pair alerts with the matching runbook.

## Local development and testing

See the root README and local development guide for PostgreSQL, Redis, FastAPI, media, and optional broker setup. Run the component's unit/contract checks and an integration test against real dependencies before changing a distributed contract.

## Deployment notes and change checklist

Deploy compatible contracts first, then producers/consumers or routing. Verify health, rollback path, and operational dashboards. Review security boundaries, schema changes, resource limits, autoscaling signals, and scale-in drain behavior. Known migration status: **S3-compatible driver exists; production bucket/CDN provisioning is external.**
