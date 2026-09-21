# FunKey / VibeMatch production runbook

This document describes the canonical backend/media runtime on this branch.

## Runtime topology

There are exactly **two application process types**, plus PostgreSQL and Redis:

1. **FastAPI control/API plane** — port `8000`
   - REST API under `/api/v1`
   - authentication and authorization
   - room state, seats, presence and realtime WebSocket
   - inbox/economy/games/admin APIs
   - media authorization and media-node assignment
   - media-node registry backed by Redis

2. **Canonical mediasoup media worker: `backend_media/`** — port `4100` by default
   - mediasoup workers/routers
   - Socket.IO signaling
   - audio producers/consumers
   - room/music media runtime
   - periodic heartbeats to FastAPI
   - no independent authority for users, room membership, seats, bans or permissions

Infrastructure:
- PostgreSQL — durable application state
- Redis — realtime coordination, media-node registry and sticky room-to-node assignment

The old `audio-server/`, `media-server/`, and `services/mediasoup-audio-server/` implementations were removed from this branch. Git history remains the archive; do not restore them as production entrypoints.

## Database ownership

Alembic is the only database schema authority.

Application startup does not call `Base.metadata.create_all()` and must not execute runtime `ALTER TABLE`/`CREATE TABLE` mutations. FastAPI verifies that the database is at the current Alembic head and fails fast when it is not.

Before starting or restarting the API after a deploy:

```bash
cd backend
alembic upgrade head
```

Do not add startup-time schema repair code. Add a new Alembic revision instead.

## Local development

### FastAPI

```bash
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Health:
```bash
curl http://127.0.0.1:8000/health
```

### Media worker

```bash
cd backend_media
npm ci
npm run typecheck
npm run build
npm run dev
```

Health/readiness:
```bash
curl http://127.0.0.1:4100/health
curl http://127.0.0.1:4100/ready
```

## Production boot order

1. Start PostgreSQL and Redis.
2. Run `alembic upgrade head`.
3. Start FastAPI.
4. Start one or more `backend_media` workers.
5. Route public API/WebSocket traffic through the gateway/load balancer.

A media worker is ready only after mediasoup is initialized and it has successfully registered with FastAPI. Workers heartbeat into the registry; FastAPI assigns rooms to healthy non-draining nodes and preserves sticky assignments in Redis.

## Media scaling/draining

Scale by adding/removing `backend_media` replicas. Each replica must have:
- a unique `MEDIA_NODE_ID`
- a client-reachable `MEDIA_PUBLIC_URL`
- the same `MEDIA_INTERNAL_TOKEN` as FastAPI
- a valid public `MEDIASOUP_ANNOUNCED_IP`
- an open RTC UDP/TCP port range

To drain a node, mark it draining through the admin media endpoint. Draining nodes stop receiving new room assignments while existing assignments remain stable until they expire or the node leaves the registry.

## Required production checks

```bash
cd backend
python -m unittest discover -s tests -p "test_*.py" -v

cd ../backend_media
npm ci
npm run typecheck
npm run build

cd ../frontend/vibematch_app
flutter pub get
flutter test
```

## Realtime/media invariants

- FastAPI is authoritative for identity, room membership, seats, moderation and permissions.
- The media worker never trusts a client-provided user identity or seat state as authority.
- Publishing audio is re-authorized against FastAPI.
- Room-to-media-node assignment is owned by the FastAPI/Redis control plane.
- Redis failure makes media assignment unavailable rather than silently creating a second source of truth.
- PostgreSQL and Redis remain private infrastructure; public clients connect only to approved API/media gateway endpoints.

## Production process management

Do not use `--reload` in production. Run FastAPI and media workers under Docker, systemd, Kubernetes or another supervisor.

Example:

```bash
sudo systemctl restart vibematch-api
sudo systemctl restart vibematch-media
sudo systemctl status vibematch-api vibematch-media --no-pager
```

Keep TLS enabled for all public HTTP/WebSocket traffic.
