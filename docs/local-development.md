# Local development

Use the canonical checkout at `D:\Vibe Match\vibematch-backend-consolidation` and the checkpoint branch. The app has separate FastAPI and `backend_media` processes; `scripts/dev-up.ps1` starts them after starting the local PostgreSQL and Redis containers.

## One-time setup

1. Install Docker Desktop, Node 22, Flutter, and Python dependencies in `D:\Vibe Match\.venv`.
2. Copy `backend/.env.example` to `backend/.env`. For this workflow set `database_url=postgresql://postgres:postgres@127.0.0.1:5433/vibematch`, `redis_url=redis://127.0.0.1:6380/0`, `APP_ENV=development`, `ENFORCE_SCHEMA_CURRENT=true`, and a shared development `MEDIA_INTERNAL_TOKEN`.
3. Copy `backend_media/.env.example` to `backend_media/.env`. Set the same `MEDIA_INTERNAL_TOKEN`, `FASTAPI_BASE_URL=http://127.0.0.1:8000`, and a `MEDIA_PUBLIC_URL` reachable by the Flutter client.
4. Install media dependencies once: `cd backend_media; npm ci`.
5. Install Flutter dependencies once: `cd frontend/vibematch_app; flutter pub get`.

## Start and stop

From the repository root:

```powershell
.\scripts\dev-up.ps1
.\scripts\dev-status.ps1
flutter run -d edge --dart-define=VM_API_BASE_URL=http://127.0.0.1:8000
```

`dev-up.ps1` uses PostgreSQL `funkey-postgres-test` on `127.0.0.1:5433` and Redis `funkey-redis-6380` on `127.0.0.1:6380`. It runs `alembic upgrade head`, then launches FastAPI and the canonical `backend_media` worker. Logs and owned-process metadata are placed in the ignored `scripts/.dev-runtime/` directory.

To launch Flutter from the workflow too, use `./scripts/dev-up.ps1 -StartFlutter`. To use non-default ports or container names, pass `-PostgresPort`, `-RedisPort`, `-ApiPort`, `-MediaPort`, `-PostgresContainer`, or `-RedisContainer` to both `dev-up.ps1` and `dev-status.ps1`. `dev-up.ps1` supplies the selected database, Redis, FastAPI, and media ports to the processes it launches and derives the selected media port from `MEDIA_PUBLIC_URL` without changing its host.

```powershell
.\scripts\dev-down.ps1
```

`dev-down.ps1` stops only processes whose PID and start time were recorded by `dev-up.ps1`, and only Docker containers carrying its `com.vibematch.dev.managed=true` label. It keeps database data volumes. It does not kill arbitrary listeners or unrelated Docker containers.

`dev-status.ps1` reports PostgreSQL, Redis, FastAPI `/health`, media `/health`, and media `/ready`. A media worker is ready only after mediasoup is live and its registry heartbeat to FastAPI succeeds.

## Secret handling

`backend/secrets/` and `backend/secrets/firebase-service-account.json` are ignored and must never be committed. The service account must stay outside source control, with `FIREBASE_SERVICE_ACCOUNT_PATH` pointing at its deployment location. If a service-account private key was exposed in a terminal, log, chat, or screen recording, revoke and replace that Google service-account key in Google Cloud IAM immediately; update the deployed secret afterward.

The repository check for this checkpoint found no tracked `backend/secrets/firebase-service-account.json` path in reachable Git history. Repeat the check without printing file contents when auditing another remote or rewritten history:

```powershell
git log --all -- backend/secrets/firebase-service-account.json
git ls-files -- backend/secrets/firebase-service-account.json
```
