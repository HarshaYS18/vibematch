[CmdletBinding()]
param(
    [int]$PostgresPort = 5433,
    [int]$RedisPort = 6380,
    [int]$RealtimeRedisPort = 6381,
    [int]$MediaRedisPort = 6382,
    [int]$ApiPort = 8000,
    [int]$MediaPort = 4100,
    [string]$PostgresContainer = 'funkey-postgres-test',
    [string]$RedisContainer = 'funkey-redis-6380',
    [string]$RealtimeRedisContainer = 'funkey-realtime-redis-6381',
    [string]$MediaRedisContainer = 'funkey-media-redis-6382'
)

$ErrorActionPreference = 'Continue'

function Report([string]$Name, [bool]$Healthy, [string]$Detail) {
    $state = if ($Healthy) { 'OK' } else { 'FAIL' }
    Write-Host ("{0,-14} {1,-4} {2}" -f "${Name}:", $state, $Detail)
    return $Healthy
}

function ContainerRunning([string]$Name) {
    $state = & docker container inspect --format '{{.State.Running}}' $Name 2>$null
    return $LASTEXITCODE -eq 0 -and $state.Trim() -eq 'true'
}

function HttpHealthy([string]$Url) {
    try {
        $response = Invoke-WebRequest -Uri $Url -TimeoutSec 2 -UseBasicParsing
        return $response.StatusCode -ge 200 -and $response.StatusCode -lt 300
    } catch { return $false }
}

$postgresOk = $false
if (ContainerRunning $PostgresContainer) {
    & docker exec $PostgresContainer pg_isready -U postgres -d vibematch *> $null
    $postgresOk = $LASTEXITCODE -eq 0
}
Report 'Postgres' $postgresOk "$PostgresContainer :$PostgresPort" | Out-Null

function RedisHealthy([string]$Container) {
    if (-not (ContainerRunning $Container)) { return $false }
    $pong = & docker exec $Container redis-cli ping 2>$null
    return $LASTEXITCODE -eq 0 -and $pong.Trim() -eq 'PONG'
}

Report 'Cache Redis' (RedisHealthy $RedisContainer) "$RedisContainer :$RedisPort" | Out-Null
Report 'Realtime Redis' (RedisHealthy $RealtimeRedisContainer) "$RealtimeRedisContainer :$RealtimeRedisPort" | Out-Null
Report 'Media Redis' (RedisHealthy $MediaRedisContainer) "$MediaRedisContainer :$MediaRedisPort" | Out-Null
Report 'FastAPI' (HttpHealthy "http://127.0.0.1:$ApiPort/health") "http://127.0.0.1:$ApiPort/health" | Out-Null
Report 'Media /health' (HttpHealthy "http://127.0.0.1:$MediaPort/health") "http://127.0.0.1:$MediaPort/health" | Out-Null
Report 'Media /ready' (HttpHealthy "http://127.0.0.1:$MediaPort/ready") "http://127.0.0.1:$MediaPort/ready" | Out-Null
