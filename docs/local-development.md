# Local development

Work from the current FunKey repository branch. The local platform includes the
core compatibility API plus extracted services, one Go application realtime
gateway, specialized Python workers and canonical `backend_media`.

## Dependencies

Install Docker Desktop, Python, Node.js, Go and Flutter as needed. Copy untracked
environment templates and never commit real secrets.

Local infrastructure in `infra/docker-compose.yml` provides PostgreSQL/PgBouncer
development topology, three Redis/Valkey roles and NATS JetStream. Kubernetes is
not required for routine local feature work.

## PowerShell convenience workflow

```powershell
.\scripts\dev-up.ps1
.\scripts\dev-status.ps1
.\scripts\dev-down.ps1
```

The convenience script is intentionally smaller than production topology. It
starts its managed infrastructure, applies Alembic and starts the configured
core/media development processes. When changing an extracted service, run that
service explicitly or use the Compose app profile; do not assume the core process
is its mutation authority.

## Compose application topology

```powershell
docker compose -f infra/docker-compose.yml up -d postgres cache-redis realtime-redis media-redis nats
docker compose -f infra/docker-compose.yml --profile app up --build
```

The app profile is the preferred topology check for service-boundary work. Go
realtime is the canonical application WebSocket, not a shadow component.
`backend_media` remains a separate media-plane process.

Do not run convenience and Compose stacks on overlapping ports unless mappings
are changed.

## Key local ports

- core API: 8000
- Go realtime: 8081
- worker health: 8082
- Inbox: 8083
- Vibes: 8084
- Room Control: 8085
- Identity: 8086
- Profile/Social: 8087
- Economy: 8088
- Game Platform: 8089
- Notification: 8090
- backend_media: 4100

## Validation

```powershell
python scripts/check_backend_architecture.py
Push-Location backend
python -m unittest discover -s tests -p "test_*.py" -v
alembic heads
Pop-Location
Push-Location apps/realtime-gateway
go test ./...
Pop-Location
Push-Location backend_media
npm ci
npm run typecheck
npm run build
npm test
Pop-Location
Push-Location frontend/vibematch_app
flutter pub get
flutter test
flutter analyze
Pop-Location
```

Tests using in-memory SQLite do not prove PostgreSQL locking/role behavior.
Distributed Redis/NATS/WebRTC/provider behavior still requires the relevant local
service or staging environment.

## Secrets and compatibility

Keep `.env`, provider credentials and `backend/secrets/` out of Git. Historical
`vibematch` path/database names remain only for compatibility; the product is FunKey.
