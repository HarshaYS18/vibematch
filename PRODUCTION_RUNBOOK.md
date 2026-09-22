# FunKey production runbook

This guide records the established FastAPI and canonical media control-plane contract. The evolving Go gateway, worker, NATS, Kubernetes, and GitOps rollout are described in the [deployment guide](docs/architecture/deployment.md), [module index](docs/MODULE_INDEX.md), and [incident runbooks](docs/runbooks/README.md). Use `docs/FUNKEY_PRODUCTION_BACKEND_COMPLETION_REPORT.md` for this branch's verified implementation status before operating a new component.

FunKey has one canonical media implementation and a separate application control plane and media plane.

## Runtime topology

Production requires these application processes:

1. **FastAPI control/API plane** — default port `8000`
   - REST and WebSocket API under `/api/v1`
   - authentication, authorization, rooms, seats, presence, inbox, economy and games
   - authoritative room/media permission checks
   - media-node registry, room-to-node assignment and drain controls

2. **`backend_media` mediasoup media plane** — default signaling port `4100`
   - Socket.IO signaling
   - mediasoup workers/routers/transports/producers/consumers
   - media-node heartbeat and capacity reporting
   - graceful drain/offline behavior
   - sensitive media actions re-authorized through FastAPI

Infrastructure:

- PostgreSQL
- Redis
- TLS reverse proxy / ingress in production

There is exactly one executable media implementation in this repository: `backend_media/`.
The former `audio-server/`, `media-server/` and `services/mediasoup-audio-server/` implementations have been removed.

## Database schema ownership

**Alembic is the only schema mutation authority.**

Do not add `Base.metadata.create_all()`, runtime `ALTER TABLE`, runtime `CREATE TABLE`, or another startup schema patcher under `backend/app`.

Before starting a new backend release:

```bash
cd backend
alembic upgrade head
```

The API schema guard can fail startup when the connected database is not at the current Alembic head. That is intentional: apply migrations first rather than mutating the database from application startup.

## Local development

### 1. PostgreSQL and Redis

Start PostgreSQL and Redis and configure `backend/.env`.

### 2. FastAPI

PowerShell:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Linux/macOS:

```bash
cd backend
source .venv/bin/activate
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

### 3. Media worker

```bash
cd backend_media
npm ci
npm run typecheck
npm run build
npm run dev
```

Health and readiness:

```bash
curl http://127.0.0.1:4100/health
curl http://127.0.0.1:4100/ready
```

A media worker is ready only when mediasoup is ready and its FastAPI registry heartbeat is healthy.

## Media discovery and load distribution

Clients do not choose a media server manually.

The authenticated control-plane endpoint:

```text
GET /api/v1/rooms/{room_public_id}/media
```

verifies room access and returns the signaling URL of the assigned healthy media node.

FastAPI stores node heartbeats and sticky room assignments in Redis. New rooms are assigned to a non-draining node using reported room/peer capacity and load. Existing room assignments remain sticky while the assigned node stays healthy.

Administrative drain controls live under:

```text
GET   /api/v1/admin/media/nodes
PATCH /api/v1/admin/media/nodes/{node_id}/drain
```

Set a node to draining before terminating it. Draining nodes stop receiving new room assignments while existing room assignments can finish naturally.

Actual process/pod creation is owned by the deployment orchestrator. The application control plane supplies the node health/capacity/drain contract; Kubernetes, ECS, Nomad or another orchestrator should scale `backend_media` replicas.

## Production boot order

1. PostgreSQL
2. Redis
3. `alembic upgrade head`
4. FastAPI
5. one or more `backend_media` workers
6. ingress/reverse proxy and client deployment

Do not run a media worker against a FastAPI instance with mismatched schema or API version.

## Production process rules

- Do not use Uvicorn `--reload` in production.
- Run FastAPI and media workers under a supervisor/orchestrator.
- Use HTTPS/WSS at the public edge.
- Keep PostgreSQL and Redis private.
- Set mediasoup announced IP/addressing for the actual public/NAT topology.
- Open only the signaling port and configured mediasoup RTC UDP/TCP range required by the deployment.
- Use the same `MEDIA_INTERNAL_TOKEN` on the FastAPI control plane and media workers.
- Drain a media node before planned shutdown.

Example systemd operations:

```bash
sudo systemctl restart funkey-api
sudo systemctl status funkey-api --no-pager
sudo journalctl -u funkey-api -n 200 --no-pager

sudo systemctl restart funkey-media
sudo systemctl status funkey-media --no-pager
sudo journalctl -u funkey-media -n 200 --no-pager
```

## Required pre-deploy checks

```bash
python scripts/check_backend_architecture.py

cd backend
python -m unittest discover -s tests -p "test_*.py" -v

cd ../backend_media
npm ci
npm run typecheck
npm run build

cd ../frontend/vibematch_app
flutter pub get
flutter test
flutter build web --release
```

CI runs the same architecture/backend/media/frontend checks for this consolidation branch.

## Architecture invariants

- `backend/app/api/router.py` owns the `/api/v1` root.
- FastAPI owns authentication, authorization, room membership, seats and business state.
- `backend_media` owns media transport state, not application authorization or seat truth.
- Every sensitive media action is verified against FastAPI.
- Redis coordinates realtime distribution, media-node liveness and room assignment.
- Alembic owns every database schema change.
- A second executable media server implementation is a CI failure.
