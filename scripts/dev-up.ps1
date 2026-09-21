[CmdletBinding()]
param(
    [int]$PostgresPort = 5433,
    [int]$RedisPort = 6380,
    [int]$ApiPort = 8000,
    [int]$MediaPort = 4100,
    [string]$PostgresContainer = 'funkey-postgres-test',
    [string]$RedisContainer = 'funkey-redis-6380',
    [switch]$SkipMigrations,
    [switch]$StartFlutter
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$runtimeDir = Join-Path $PSScriptRoot '.dev-runtime'
$backendDir = Join-Path $repoRoot 'backend'
$mediaDir = Join-Path $repoRoot 'backend_media'
$venvPython = Join-Path (Split-Path -Parent $repoRoot) '.venv\Scripts\python.exe'
$runtimeDir | ForEach-Object { New-Item -ItemType Directory -Force -Path $_ | Out-Null }

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found on PATH."
    }
}

function Get-DotEnvValue([string]$Path, [string]$Key) {
    $match = Get-Content $Path | Where-Object { $_ -match "^\s*$([regex]::Escape($Key))\s*=\s*(.+?)\s*$" } | Select-Object -Last 1
    if (-not $match) { return $null }
    return (($match -replace "^\s*$([regex]::Escape($Key))\s*=\s*", '').Trim()).Trim('"').Trim("'")
}

function Get-ContainerState([string]$Name) {
    $state = & docker container inspect --format '{{.State.Running}}' $Name 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $state.Trim()
}

function Get-ContainerManagedLabel([string]$Name) {
    $labelsJson = & docker container inspect --format '{{json .Config.Labels}}' $Name 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $labelsJson) { return $null }
    try {
        $labels = $labelsJson | ConvertFrom-Json
        if ($null -eq $labels) { return $null }
        $property = $labels.PSObject.Properties['com.vibematch.dev.managed']
        if ($null -eq $property) { return $null }
        return [string]$property.Value
    } catch {
        return $null
    }
}

function Start-ManagedContainer([string]$Name, [string[]]$CreateArgs) {
    $state = Get-ContainerState $Name
    if ($null -eq $state) {
        & docker run -d --name $Name --label 'com.vibematch.dev.managed=true' @CreateArgs | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not create Docker container '$Name'." }
        Write-Host "Started new container $Name"
    } elseif ($state -ne 'true') {
        $managed = Get-ContainerManagedLabel $Name
        if ($managed -ne 'true') {
            throw "Refusing to start existing unmanaged container '$Name'."
        }
        & docker start $Name | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "Could not start Docker container '$Name'." }
        Write-Host "Started existing container $Name"
    } else {
        Write-Host "Container $Name is already running"
    }
}

function Wait-ForContainerCommand([string]$Name, [string[]]$Command, [string]$Service) {
    $deadline = (Get-Date).AddSeconds(30)
    do {
        & docker exec $Name @Command *> $null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 1
    } while ((Get-Date) -lt $deadline)
    throw "$Service container '$Name' did not become ready within 30 seconds."
}

function Wait-ForHttpHealthy([string]$Url, [string]$Service, [int]$TimeoutSeconds = 30) {
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 2 -UseBasicParsing
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) { return }
        } catch { }
        Start-Sleep -Milliseconds 500
    } while ((Get-Date) -lt $deadline)
    throw "$Service did not become healthy at '$Url' within $TimeoutSeconds seconds."
}

function Test-OwnedProcessRunning([string]$Name) {
    $metadataPath = Join-Path $runtimeDir "$Name.json"
    if (-not (Test-Path $metadataPath)) { return $false }
    try {
        $metadata = Get-Content -Raw $metadataPath | ConvertFrom-Json
        $existing = Get-Process -Id $metadata.pid -ErrorAction Stop
        return $existing.StartTime.ToUniversalTime().Ticks -eq [long]$metadata.startedAtUtcTicks
    } catch { return $false }
}

function Assert-PortAvailable([int]$Port, [string]$Service) {
    $listeners = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
    if ($listeners) {
        throw "$Service cannot start: TCP port $Port is already in use. The script will not stop an existing process."
    }
}

function Start-OwnedProcess([string]$Name, [string]$FilePath, [string[]]$Arguments, [string]$WorkingDirectory, [hashtable]$EnvironmentOverrides = @{}) {
    $metadataPath = Join-Path $runtimeDir "$Name.json"
    if (Test-Path $metadataPath) {
        $metadata = Get-Content -Raw $metadataPath | ConvertFrom-Json
        try {
            $existing = Get-Process -Id $metadata.pid -ErrorAction Stop
            if ($existing.StartTime.ToUniversalTime().Ticks -eq [long]$metadata.startedAtUtcTicks) {
                Write-Host "$Name is already running (PID $($metadata.pid))"
                return
            }
        } catch { }
        Remove-Item -LiteralPath $metadataPath -Force
    }

    $stdout = Join-Path $runtimeDir "$Name.stdout.log"
    $stderr = Join-Path $runtimeDir "$Name.stderr.log"
    $previousEnvironment = @{}
    foreach ($key in $EnvironmentOverrides.Keys) {
        $previousEnvironment[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        [Environment]::SetEnvironmentVariable($key, [string]$EnvironmentOverrides[$key], 'Process')
    }
    try {
        $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments -WorkingDirectory $WorkingDirectory `
            -RedirectStandardOutput $stdout -RedirectStandardError $stderr -WindowStyle Hidden -PassThru
    } finally {
        foreach ($key in $previousEnvironment.Keys) {
            [Environment]::SetEnvironmentVariable($key, $previousEnvironment[$key], 'Process')
        }
    }
    [pscustomobject]@{
        pid = $process.Id
        startedAtUtcTicks = $process.StartTime.ToUniversalTime().Ticks
        command = "$FilePath $($Arguments -join ' ')"
    } | ConvertTo-Json | Set-Content -NoNewline $metadataPath
    Write-Host "Started $Name (PID $($process.Id)); logs: $runtimeDir"
}

Require-Command docker
Require-Command npm.cmd
Require-Command node
if (-not (Test-Path $venvPython)) { throw "Python venv was not found at '$venvPython'." }
if (-not (Test-Path (Join-Path $backendDir '.env'))) { throw "Create backend/.env from backend/.env.example before running dev-up." }
if (-not (Test-Path (Join-Path $mediaDir '.env'))) { throw "Create backend_media/.env from backend_media/.env.example before running dev-up." }
$configuredPublicUrl = Get-DotEnvValue (Join-Path $mediaDir '.env') 'MEDIA_PUBLIC_URL'
if (-not $configuredPublicUrl) { throw 'backend_media/.env must define MEDIA_PUBLIC_URL.' }
try {
    $publicUri = [Uri]$configuredPublicUrl
    $mediaPublicUrl = "{0}://{1}:{2}" -f $publicUri.Scheme, $publicUri.Host, $MediaPort
} catch { throw "MEDIA_PUBLIC_URL is not a valid URL: $configuredPublicUrl" }

Start-ManagedContainer $PostgresContainer @(
    '-e', 'POSTGRES_USER=postgres', '-e', 'POSTGRES_PASSWORD=postgres', '-e', 'POSTGRES_DB=vibematch',
    '-p', "127.0.0.1:${PostgresPort}:5432", '-v', "$PostgresContainer-data:/var/lib/postgresql/data", 'postgres:16'
)
Start-ManagedContainer $RedisContainer @('-p', "127.0.0.1:${RedisPort}:6379", 'redis:7')
Wait-ForContainerCommand $PostgresContainer @('pg_isready', '-U', 'postgres', '-d', 'vibematch') 'PostgreSQL'
Wait-ForContainerCommand $RedisContainer @('redis-cli', 'ping') 'Redis'

if (-not $SkipMigrations) {
    Push-Location $backendDir
    try { & $venvPython -m alembic upgrade head } finally { Pop-Location }
}

if (-not (Test-OwnedProcessRunning 'fastapi')) { Assert-PortAvailable $ApiPort 'FastAPI' }
if (-not (Test-OwnedProcessRunning 'backend_media')) { Assert-PortAvailable $MediaPort 'backend_media' }
Start-OwnedProcess 'fastapi' $venvPython @('-m', 'uvicorn', 'app.main:app', '--host', '127.0.0.1', '--port', $ApiPort) $backendDir @{
    database_url = "postgresql://postgres:postgres@127.0.0.1:$PostgresPort/vibematch"
    redis_url = "redis://127.0.0.1:$RedisPort/0"
}
Wait-ForHttpHealthy "http://127.0.0.1:$ApiPort/health" 'FastAPI'
Push-Location $mediaDir
try { & npm.cmd run build } finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { throw 'backend_media build failed.' }
Start-OwnedProcess 'backend_media' 'node' @('dist/server.js') $mediaDir @{
    MEDIA_SERVICE_PORT = $MediaPort
    MEDIA_PUBLIC_URL = $mediaPublicUrl
    FASTAPI_BASE_URL = "http://127.0.0.1:$ApiPort"
}

if ($StartFlutter) {
    Require-Command flutter
    Start-OwnedProcess 'flutter' 'flutter' @('run', '-d', 'edge', "--dart-define=VM_API_BASE_URL=http://127.0.0.1:$ApiPort") (Join-Path $repoRoot 'frontend\vibematch_app')
}

Write-Host 'Waiting for media registration and readiness.'
$readyDeadline = (Get-Date).AddSeconds(35)
do {
    try {
        $ready = Invoke-WebRequest -Uri "http://127.0.0.1:$MediaPort/ready" -TimeoutSec 2 -UseBasicParsing
        if ($ready.StatusCode -eq 200) { break }
    } catch { }
    Start-Sleep -Seconds 1
} while ((Get-Date) -lt $readyDeadline)
& (Join-Path $PSScriptRoot 'dev-status.ps1') -PostgresPort $PostgresPort -RedisPort $RedisPort -ApiPort $ApiPort -MediaPort $MediaPort -PostgresContainer $PostgresContainer -RedisContainer $RedisContainer
