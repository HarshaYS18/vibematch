# FunKey production runbook

This is the operational entry point for the production-backend branch. The authoritative implementation audit is [docs/FUNKEY_PRODUCTION_BACKEND_COMPLETION_REPORT.md](docs/FUNKEY_PRODUCTION_BACKEND_COMPLETION_REPORT.md); provider/account prerequisites remain in [docs/EXTERNAL_PREREQUISITES.md](docs/EXTERNAL_PREREQUISITES.md).

## Runtime topology

The production application is split into four independently scalable deployables:

1. **FastAPI control/API plane** — port `8000`
   - REST APIs and the compatibility WebSocket paths under `/api/v1`
   - authentication, authorization, users, profiles, rooms, seats, inbox, economy, games and durable application state
   - authoritative realtime subscription verification
   - media-node registry, room assignment and drain controls
   - PostgreSQL is authoritative; Redis is coordination/cache, never wallet or identity truth

2. **Go realtime gateway** — port `8081`
   - authenticated WebSocket transport
   - bounded outbound queues and per-pod/per-user connection budgets
   - subscription authorization and periodic revalidation
   - Redis cross-instance fanout, event-ID deduplication, reconnect/resync signaling and graceful drain
   - no direct durable business writes

3. **Python worker** — health/metrics port `8082`
   - transactional-outbox relay to NATS JetStream
   - durable pull consumer, idempotent handling, bounded retry and dead-letter behavior
   - graceful drain and health/readiness/metrics endpoints

4. **`backend_media` mediasoup media plane** — signaling port `4100`
   - Socket.IO signaling and mediasoup transport
   - node heartbeat/capacity registration, sticky assignment and graceful drain
   - sensitive media actions re-authorized through FastAPI

There is exactly one executable media implementation: `backend_media/`.

## Required infrastructure

Production needs PostgreSQL, a highly available Redis/Valkey primary, NATS JetStream, S3-compatible object storage/CDN, TURN, Kubernetes with separate application/realtime/media node-pool capacity, TLS/DNS, secret management/workload identity, and a metrics/logging platform. The repository provides provider-neutral Terraform contracts and Kubernetes/GitOps desired state; real cloud resources require the selected provider, account IDs, credentials, DNS zones and quotas.

## Database schema ownership

**Alembic is the only schema mutation authority.** Runtime schema creation/patching is forbidden.

The GitOps migration job is an Argo CD `PreSync` hook. It must succeed before compatible workloads are promoted. Do not automatically downgrade a production schema during rollback; use expand/contract migrations and restore procedures.

## Local development

Use `infra/docker-compose.yml` for PostgreSQL, Redis and NATS, then run the application deployables independently. The convenience task runner is `scripts/task.ps1`.

Typical checks:

```powershell
pwsh scripts/task.ps1 test
pwsh scripts/task.ps1 lint
pwsh scripts/task.ps1 integration-test
pwsh scripts/task.ps1 load-test-smoke
```

The canonical media worker remains under `backend_media/`; removed legacy media servers must not be restored.

## Production boot order

1. Managed PostgreSQL, Redis/Valkey, NATS JetStream, object storage/CDN and TURN are healthy.
2. Kubernetes nodes, ingress/load balancers, DNS/TLS, secret injection and observability are healthy.
3. Run the Alembic migration hook to the expected head.
4. Start/roll FastAPI and confirm `/live`, `/ready` and `/metrics`.
5. Start/roll workers and confirm JetStream connectivity, readiness and no unexpected dead-letter growth.
6. Start/roll realtime gateway replicas and confirm Redis subscription health, authentication verification and WebSocket upgrade/reconnect.
7. Start/roll media nodes, verify registry heartbeat, media discovery and TURN-only connectivity.
8. Promote client traffic only after smoke, rollback and dashboard checks pass.

## GitOps release path

Images are built, scanned, signed and published by `.github/workflows/publish-backend-images.yml`. Production desired state is digest-pinned. Use `.github/workflows/prepare-gitops-promotion.yml` with immutable `name@sha256:<digest>` references; it creates a reviewable environment promotion PR.

Staging Argo CD is configured for automated prune/self-heal. Production requires an explicit reviewed sync. The migration job runs before workload sync.

## Scaling and drain rules

- API: HPA on CPU and inflight requests; DB pool sizes are bounded by the Terraform/Kubernetes connection budget.
- Realtime: HPA on CPU and `funkey_realtime_connections`; each gateway enforces local and per-user connection ceilings.
- Worker: KEDA scales from JetStream consumer lag with a safe fallback replica count.
- Media: HPA contracts use CPU, peer and room metrics, but real SFU capacity must be measured with actual WebRTC/TURN traffic.
- PDBs and topology spread protect API, realtime and media availability.
- Realtime and media scale-in must drain first. Media nodes stop receiving new room assignments before termination.

## Observability and incident response

API, gateway, worker and media expose Prometheus metrics and structured operational logs. Repository alert rules and the Grafana dashboard are under `deploy/observability/`. The environment must provide the Prometheus Operator/metrics adapter, Grafana discovery, log collection and paging routes.

Use [docs/runbooks/README.md](docs/runbooks/README.md) for database, Redis, queue, realtime, media, TURN, deployment, migration, latency, capacity, region and security incidents.

## Load, soak and failure validation

`tests/load/` contains HTTP, WebSocket, media-discovery and reconnect-storm k6 scenarios. `tests/chaos/` contains staging-only pod termination/drain exercises. Large-scale capacity claims require a real staging environment with distributed load generators and real WebRTC clients; the repository deliberately does not claim an unmeasured concurrency number.

## Required pre-deploy gates

The branch CI must pass:

- architecture guard and backend tests/migration replay
- media typecheck/build/lint/tests
- Flutter tests/analyze/release web build
- Go format/vet/unit/race tests
- Terraform format/init/validate
- local/staging/production/media/observability Kustomize renders
- immutable production-image policy
- load/chaos harness parse checks
- container builds, secret scan, filesystem scan and SBOM generation

After repository CI, staging must still verify real provider bindings, backup/restore, TURN, load/soak, failure drills, alert delivery and rollback before production traffic.

## Architecture invariants

- FastAPI/PostgreSQL remain authoritative for identity, authorization, room membership, seats, messages, wallet/economy and other durable state.
- Redis/Valkey provides ephemeral fanout, leases, presence/routing coordination and caching.
- NATS JetStream carries durable asynchronous work from the PostgreSQL transactional outbox.
- The Go gateway transports authorized realtime events; it does not become a second business-state authority.
- `backend_media` owns media transport, not application authorization.
- Alembic owns schema evolution.
- Production images are immutable digest pins.
