param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('dev', 'test', 'lint', 'integration-test', 'load-test-smoke', 'down', 'bootstrap', 'seed', 'scaffold-service')]
    [string]$Task,
    [string]$Name = ''
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$compose = Join-Path $repo 'infra/docker-compose.yml'

function Invoke-Step([string]$label, [scriptblock]$action) {
    Write-Host "== $label =="
    & $action
    if ($LASTEXITCODE -ne 0) { throw "$label failed with exit code $LASTEXITCODE" }
}

switch ($Task) {
    'bootstrap' {
        & (Join-Path $PSScriptRoot 'bootstrap_dev.ps1')
        if ($LASTEXITCODE -ne 0) { throw "Developer bootstrap failed with exit code $LASTEXITCODE" }
    }
    'seed' {
        Invoke-Step 'Start local application dependencies' { docker compose -f $compose --profile app up --build -d postgres pgbouncer cache-redis realtime-redis media-redis nats migrate }
        Push-Location (Join-Path $repo 'backend')
        try {
            $previous = $env:FUNKEY_DEV_SEED_CONFIRM
            $env:FUNKEY_DEV_SEED_CONFIRM = 'YES'
            try { Invoke-Step 'Apply deterministic development seed' { python ../scripts/seed_dev.py } }
            finally {
                if ($null -eq $previous) { Remove-Item Env:FUNKEY_DEV_SEED_CONFIRM -ErrorAction SilentlyContinue }
                else { $env:FUNKEY_DEV_SEED_CONFIRM = $previous }
            }
        } finally { Pop-Location }
    }
    'scaffold-service' {
        if ([string]::IsNullOrWhiteSpace($Name)) { throw 'scaffold-service requires -Name <service-name>' }
        Invoke-Step 'Generate service golden path' { python (Join-Path $PSScriptRoot 'scaffold_service.py') $Name }
    }
    'dev' {
        Invoke-Step 'Start local platform and services' { docker compose -f $compose --profile app up --build -d }
        Invoke-Step 'Show service status' { docker compose -f $compose --profile app ps }
    }
    'down' {
        Invoke-Step 'Stop local services' { docker compose -f $compose --profile app down }
    }
    'test' {
        Push-Location (Join-Path $repo 'backend')
        try { Invoke-Step 'Python tests' { python -m unittest discover -s tests -p 'test_*.py' -v } } finally { Pop-Location }
        Push-Location (Join-Path $repo 'backend_media')
        try { Invoke-Step 'Media tests' { npm test } } finally { Pop-Location }
        Push-Location (Join-Path $repo 'apps/realtime-gateway')
        try { Invoke-Step 'Go tests' { go test ./... } } finally { Pop-Location }
    }
    'lint' {
        Push-Location (Join-Path $repo 'backend')
        try { Invoke-Step 'Python compile' { python -m compileall -q app } } finally { Pop-Location }
        Push-Location (Join-Path $repo 'backend_media')
        try {
            Invoke-Step 'Media typecheck' { npm run typecheck }
            Invoke-Step 'Media lint' { npm run lint }
        } finally { Pop-Location }
        Push-Location (Join-Path $repo 'apps/realtime-gateway')
        try {
            $unformatted = @(gofmt -l .)
            if ($unformatted.Count -gt 0) { throw "Go files require formatting: $($unformatted -join ', ')" }
            Invoke-Step 'Go vet' { go vet ./... }
        } finally { Pop-Location }
    }
    'integration-test' {
        Invoke-Step 'Start databases and JetStream' { docker compose -f $compose up -d postgres redis nats }
        Push-Location (Join-Path $repo 'backend')
        try {
            $env:MIGRATION_TEST_DATABASE_URL = 'postgresql://funkey:funkey_dev_only@127.0.0.1:5432/funkey'
            Invoke-Step 'Migration replay' { python check_migrations.py }
        } finally {
            Remove-Item Env:MIGRATION_TEST_DATABASE_URL -ErrorAction SilentlyContinue
            Pop-Location
        }
    }
    'load-test-smoke' {
        Invoke-Step 'k6 HTTP smoke' {
            docker run --rm --add-host host.docker.internal:host-gateway -e FUNKEY_API_URL=http://host.docker.internal:8000 -v "${repo}/tests/load:/scripts:ro" grafana/k6:0.52.0 run /scripts/http-smoke.js
        }
    }
}
