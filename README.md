# FunKey

FunKey is a social live-room application with a Flutter client, a FastAPI application control plane, and a separate mediasoup media plane. This repository preserves existing mobile and API contracts while building a platform that can scale each workload independently. Astra is the in-product assistant.

## Architecture

```text
Flutter clients
  | HTTPS / WebSocket                    | WebRTC media
  v                                      v
Edge TLS and load balancer          TURN / SFU network path
  |                                      |
  +--> FastAPI core control plane        +--> backend_media (mediasoup)
  |      |                                      ^
  |      +--> PostgreSQL (durable truth)        | internal authorization
  |      +--> Redis/Valkey (ephemeral state) ---+
  |      +--> object storage / CDN
  |
  +--> Go realtime gateway (incremental migration target)
         +--> distributed events / Redis coordination

Workers, Kubernetes autoscaling and infrastructure automation are introduced
incrementally; see the completion report for the implemented state of this branch.
```

The backend is authoritative for identity, bans, memberships, rooms, seats, roles, permissions, moderation, calls, and value movement. PostgreSQL holds durable truth. Redis coordinates transient presence, fanout, and media placement; it must not become the only record of a wallet balance or ban. `backend_media` owns only SFU transport state. Clients resolve a media node through the backend and never choose one directly. See [the media architecture](docs/production_realtime_media_architecture.md) and [source-of-truth rules](docs/master-source-of-truth-architecture.md).

## Repository map

| Path | Responsibility |
| --- | --- |
| `backend/` | Current Python/FastAPI API, domain services, models, tests, and canonical Alembic migration graph |
| `backend_media/` | The sole Node.js/TypeScript mediasoup signaling and SFU implementation |
| `frontend/vibematch_app/` | Flutter client; the directory name is retained for compatibility |
| `infra/` | Local services, TURN, and infrastructure definitions |
| `scripts/` | Local and validation workflows |
| `docs/` | Architecture decisions, module ownership, operations, and deployment guides |

Go is the preferred language for new high-concurrency backend components. FastAPI remains operational during the strangler migration; Python remains appropriate for existing domain logic and selected jobs. Node.js/TypeScript remains the canonical mediasoup runtime. Do not move durable authority simply because a new process exists. [ADR-001](docs/adr/ADR-001-go-target-language.md) and [ADR-002](docs/adr/ADR-002-strangler-migration.md) explain the transition.

## Local development

The supported Windows workflow uses PowerShell and Docker Desktop; Kubernetes is not required to edit an API endpoint. Install Python, Node.js, Docker Desktop, and Flutter when working on the client. Copy `backend/.env.example` and `backend_media/.env.example` to untracked `.env` files, set matching local `MEDIA_INTERNAL_TOKEN` values, then run:

```powershell
.\scripts\dev-up.ps1
.\scripts\dev-status.ps1
```

The startup script starts local PostgreSQL and Redis, applies Alembic migrations, and launches FastAPI plus `backend_media`. See [local development](docs/local-development.md) for ports, overrides, client setup, and safe shutdown. Where a new event broker or worker is enabled, follow its module guide and local Compose configuration.

## Validation and schema changes

From the repository root, run the architecture check and backend tests:

```powershell
python scripts/check_backend_architecture.py
Push-Location backend
python -m unittest discover -s tests -p "test_*.py" -v
alembic heads
Pop-Location
Push-Location backend_media
npm ci
npm run typecheck
npm run build
npm test
Pop-Location
```

See [CI](.github/workflows/room-production-hardening.yml) for the full gate, including Flutter. Alembic is the sole production schema writer. Add migrations to the existing `backend/alembic/` graph; apply them before starting a release. Do not call `create_all()` or patch schema at runtime. [Migration procedure](docs/architecture/migrations.md) covers verification and rollback.

## Realtime and media

Room commands and snapshots are registered by `backend/app/api/router.py`; `backend/app/realtime/` holds event and connection abstractions. The Go realtime gateway is a bounded migration target and must defer durable decisions to domain authority. Clients reconnect by fetching an authoritative snapshot and then receiving incremental events. Media discovery is `GET /api/v1/rooms/{room_public_id}/media`; the backend authorizes, chooses a healthy non-draining media node, and maintains sticky room assignment in Redis. The SFU reauthorizes sensitive signaling actions with FastAPI. See the [realtime](docs/modules/realtime-gateway/README.md) and [media](docs/modules/media/README.md) guides.

## Operations and deployment

Deploy API, realtime, workers, and media as separately scalable workloads as their implementations become ready. Production needs private PostgreSQL and Redis, object storage and CDN, TURN, TLS ingress, secret management, monitoring, backups, and a tested migration job. A Kubernetes manifest or Terraform configuration alone does not prove capacity. Use [capacity planning](docs/architecture/capacity-model.md), [deployment sequence](docs/architecture/deployment.md), and the [runbooks](docs/runbooks/README.md). External account and credential requirements are listed in [external prerequisites](docs/EXTERNAL_PREREQUISITES.md).

## Contributing

Branch from the current implementation branch, keep HTTP and Flutter contracts compatible, and add tests for changed behavior. Preserve the canonical media implementation and Alembic history. Describe domain ownership, security impact, rollout, and rollback in the change. Update the relevant [module README](docs/MODULE_INDEX.md) and ADR when changing an architectural boundary. Run the affected tests and formatting checks before review.
