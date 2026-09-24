# FunKey

FunKey is a social live-room application with a Flutter client, a FastAPI application control plane, and a separate mediasoup media plane. This repository preserves existing mobile and API contracts while building a platform that can scale each workload independently. Astra is the in-product assistant.

## Architecture

FunKey is a social/live-room platform built as an evolutionary service architecture.
PostgreSQL remains durable truth, while each extracted domain has one mutation
owner and isolated production credentials.

```text
Flutter apps
  | REST/control plane                       | WebRTC
  v                                          v
Core compatibility API :8000            TURN / backend_media :4100
  |
  +--> Identity :8086
  +--> Profile/Social :8087
  +--> Inbox :8083
  +--> Vibes :8084
  +--> Room Control :8085
  +--> Economy :8088  <---- Game Platform :8089
  +--> Notification :8090 + provider worker
  |
  +--> Go realtime gateway :8081  (single application WebSocket)
  +--> Worker pools :8082

PostgreSQL/PgBouncer -> durable authority
Redis/Valkey roles     -> cache / realtime presence+replay / media registry
NATS JetStream         -> durable operational async work
Object storage/CDN     -> media/game bytes, never business authority
```

### Authority rules

- Identity, Profile/Social, Inbox, Vibes, Room Control, Economy, Game Platform
  and Notification are separately deployed mutation boundaries.
- Economy is the exclusive financial writer. Game Platform owns gameplay
  lifecycle but calls Economy for wager/settlement.
- Go realtime owns transport/routing/presence/replay only.
- `backend_media` owns mediasoup/WebRTC transport only.
- Redis, NATS, Flutter caches and future search/analytics systems are never
  durable business truth.
- Media v2 uses direct object-store uploads while PostgreSQL owns control state.
- Flutter REST traffic converges on `AppNetworkClient -> CanonicalNetworkTransport -> Dio`.

See `docs/architecture/authority-registry.md`,
`contracts/architecture/authorities.yaml`, and
`docs/architecture/service-boundaries.md` before moving any domain boundary.

## Repository map

| Path | Responsibility |
| --- | --- |
| `backend/` | Shared Python domain code, core compatibility API, canonical models/migrations/tests |
| `apps/` | Extracted domain services, Go realtime gateway and worker platform |
| `backend_media/` | Sole Node/TypeScript mediasoup signaling/SFU implementation |
| `frontend/vibematch_app/` | Flutter client (directory name retained for compatibility) |
| `contracts/` | Authority, Redis and versioned service/event contracts |
| `deploy/` | Kubernetes, PostgreSQL ownership, observability and GitOps desired state |
| `infra/` | Local/runtime infrastructure definitions |
| `scripts/` | Validation, developer and release workflows |
| `docs/` | Architecture, ADRs, module ownership and operations |

Go remains preferred for high-concurrency transport components; Python remains
appropriate for existing business/domain services and workers; Node/TypeScript
remains canonical for mediasoup. Language choice never changes state authority.

## Local development

The supported Windows workflow uses PowerShell and Docker Desktop; Kubernetes is not required to edit an API endpoint. Install Python, Node.js, Docker Desktop, and Flutter when working on the client. Copy `backend/.env.example` and `backend_media/.env.example` to untracked `.env` files, set matching local `MEDIA_INTERNAL_TOKEN` values, then run:

```powershell
.\scripts\dev-up.ps1
.\scripts\dev-status.ps1
```

The startup script starts local PostgreSQL plus isolated cache, realtime, and media-registry Redis roles, applies Alembic migrations, and launches FastAPI plus `backend_media`. See [local development](docs/local-development.md) for ports, overrides, client setup, and safe shutdown. Where a new event broker or worker is enabled, follow its module guide and local Compose configuration.

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

Deploy API, realtime, workers, and media as separately scalable workloads as their implementations become ready. Production needs private PostgreSQL/PgBouncer and three isolated HA Redis/Valkey roles, object storage and CDN, TURN, TLS ingress, secret management, monitoring, backups, and a tested migration job. A Kubernetes manifest or Terraform configuration alone does not prove capacity. Use [capacity planning](docs/architecture/capacity-model.md), [deployment sequence](docs/architecture/deployment.md), and the [runbooks](docs/runbooks/README.md). External account and credential requirements are listed in [external prerequisites](docs/EXTERNAL_PREREQUISITES.md).

## Contributing

Branch from the current implementation branch, keep HTTP and Flutter contracts compatible, and add tests for changed behavior. Preserve the canonical media implementation and Alembic history. Describe domain ownership, security impact, rollout, and rollback in the change. Update the relevant [module README](docs/MODULE_INDEX.md) and ADR when changing an architectural boundary. Run the affected tests and formatting checks before review.
