# FunKey / VibeMatch production runbook

This document describes the service topology that the current repository actually uses.

## Runtime topology

There are **two application server processes** in the current branch, plus PostgreSQL and Redis infrastructure:

1. **FastAPI API + room realtime WebSocket** — port `8000`
   - REST API
   - authentication and authorization
   - room state and presence
   - `/ws/room-realtime`
   - `/media-realtime/verify`

   The room WebSocket is mounted in `backend/app/main.py`; it is **not a separate Python server process** in the current codebase.

2. **`backend_media` mediasoup / Socket.IO service** — port `4100`
   - mediasoup worker/router
   - audio send/receive transports
   - producer/consumer signaling
   - calls FastAPI for JWT-backed media authorization

Infrastructure required by the application:

- PostgreSQL
- Redis

The older `audio-server/` service on port `4000` is legacy. The Flutter client currently points at `backend_media` on port `4100`; do not run the old service as the production audio endpoint.

## Local development startup

### FastAPI

PowerShell:

```powershell
cd backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Linux/macOS:

```bash
cd backend
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

Expected response contains `"status":"healthy"`.

### Mediasoup service

```bash
cd backend_media
npm ci
npm run typecheck
npm run build
npm run dev
```

Health check:

```bash
curl http://127.0.0.1:4100/health
```

## Restarting Uvicorn

For a foreground development process, stop it with `Ctrl+C`, then restart:

```bash
cd backend
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

For production, do not use `--reload`. Run the API under systemd, Docker, or another process supervisor and restart that unit/container instead of manually killing Python processes.

Example systemd commands when the unit is named `vibematch-api`:

```bash
sudo systemctl restart vibematch-api
sudo systemctl status vibematch-api --no-pager
sudo journalctl -u vibematch-api -n 200 --no-pager
```

Example media-service commands when the unit is named `vibematch-media`:

```bash
sudo systemctl restart vibematch-media
sudo systemctl status vibematch-media --no-pager
sudo journalctl -u vibematch-media -n 200 --no-pager
```

## Production boot order

Start PostgreSQL and Redis first, then FastAPI, then `backend_media`, and finally deploy/start the Flutter client. `backend_media` depends on FastAPI authorization for sensitive media actions.

## Required production checks

Before deployment:

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

The branch also contains `.github/workflows/room-production-hardening.yml`, which runs these checks on pushes to `chatgpt/room-production-hardening`.

## Realtime security invariants

- WebSocket actor identity comes from the access token, never from a client-supplied user id.
- Joined room actions require an active `RoomParticipant` record.
- Media access requires active room presence.
- Publishing microphone audio requires an authoritative occupied room seat.
- In apply-only rooms, the assigned seat is the proof of approval; approved users can publish only after assignment.
- Redis distributes room realtime events and connection leases across FastAPI workers.

## Deployment notes

- Put FastAPI and `backend_media` behind TLS (`https` / `wss`) for public traffic.
- Set the mediasoup announced IP to the public IP reachable by clients.
- Open the configured mediasoup RTC UDP/TCP port range in the firewall.
- Keep PostgreSQL and Redis private; do not expose them directly to the internet.
- Run database migrations deliberately before starting production workers. The current backend still contains beta-era runtime schema guards, so migration cleanup should be completed before treating schema startup behavior as fully production-grade.
