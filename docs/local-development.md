# Local development

Work from this repository checkout on `codex/funkey-production-backend-v1`. The current Python/FastAPI API and the canonical `backend_media` TypeScript process are separate. PostgreSQL, three isolated Redis/Valkey roles, and NATS JetStream are available through `infra/docker-compose.yml`. Kubernetes is not required for routine endpoint work.

## PowerShell workflow for the checkpoint stack

Install Docker Desktop, Python dependencies, Node.js, and Flutter when working on the client. The existing `scripts/dev-up.ps1` expects a Python virtual environment in the parent of the repository directory (`.venv/Scripts/python.exe`) and untracked `backend/.env` and `backend_media/.env` files. Copy each `.env.example` and replace local placeholders. Set matching `MEDIA_INTERNAL_TOKEN` values in both files. With default script ports, use PostgreSQL on `5433`, cache Redis on `6380`, realtime Redis on `6381`, and media-registry Redis on `6382`. `dev-up.ps1` injects the three Redis role URLs into FastAPI; keep `APP_ENV=development` locally and use `FASTAPI_BASE_URL=http://127.0.0.1:8000` for media. Run `npm ci` once in `backend_media`.

```powershell
.\scripts\dev-up.ps1
.\scripts\dev-status.ps1
.\scripts\dev-down.ps1
```

`dev-up.ps1` starts only its managed PostgreSQL plus cache/realtime/media Redis containers, applies `alembic upgrade head`, and launches FastAPI and `backend_media`. It records owned processes under ignored `scripts/.dev-runtime/`. `dev-down.ps1` stops those processes and managed containers without deleting database volumes. Port and container overrides are exposed as script parameters. Use `-StartFlutter` if desired, or run Flutter separately with the correct `VM_API_BASE_URL` define.

## Compose platform workflow

The new `infra/docker-compose.yml` defines local PostgreSQL, cache Redis, realtime Redis, media-registry Redis, and NATS by default. Its `app` profile also defines a migration job, API, Go gateway, and worker. The gateway is a foundation/shadow component until Flutter WebSocket routing is migrated and parity tested. Check each service's health and logs before treating it as usable. Compose development credentials are local only.

```powershell
docker compose -f infra/docker-compose.yml up -d postgres cache-redis realtime-redis media-redis nats
docker compose -f infra/docker-compose.yml --profile app up --build
```

Do not start the checkpoint script stack and Compose stack on overlapping ports without changing one set of mappings. The local Compose stack does not replace the canonical `backend_media` process; start it with its `.env` and `npm run dev` when testing WebRTC signaling.

## Validation

```powershell
python scripts/check_backend_architecture.py
Push-Location backend
python -m unittest discover -s tests -p "test_*.py" -v
alembic heads
Pop-Location
Push-Location backend_media
npm run typecheck
npm run build
npm test
Pop-Location
```

Go gateway and worker checks are documented in their module guides as implementation lands. A test that uses real PostgreSQL or Redis should name those prerequisites; an in-memory unit test does not prove failover or distributed behavior.

## Secrets and compatibility

Keep `.env` and `backend/secrets/` out of Git. `FIREBASE_SERVICE_ACCOUNT_PATH` points to a private deployment file. Revoke a service account key if it appears in a terminal log, chat, recording, or Git history. Historical database names, environment variable names, Flutter path, and the managed Docker label retain `vibematch` for compatibility; they are not a request to rename the application. The application name is FunKey.
