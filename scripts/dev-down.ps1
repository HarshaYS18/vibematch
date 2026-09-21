[CmdletBinding()]
param(
    [string]$PostgresContainer = 'funkey-postgres-test',
    [string]$RedisContainer = 'funkey-redis-6380'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$runtimeDir = Join-Path $PSScriptRoot '.dev-runtime'

function Stop-OwnedProcess([string]$Name) {
    $metadataPath = Join-Path $runtimeDir "$Name.json"
    if (-not (Test-Path $metadataPath)) { return }
    $metadata = Get-Content -Raw $metadataPath | ConvertFrom-Json
    try {
        $process = Get-Process -Id $metadata.pid -ErrorAction Stop
        if ($process.StartTime.ToUniversalTime().Ticks -ne [long]$metadata.startedAtUtcTicks) {
            Write-Warning "Refusing to stop PID $($metadata.pid): it has been reused since $Name was started."
        } else {
            # The Windows venv launcher starts a child Python process. Stop only
            # descendants of the recorded process, deepest first, so no server
            # or mediasoup worker survives this workflow's shutdown.
            $processes = @(Get-CimInstance Win32_Process)
            $descendants = [System.Collections.Generic.List[int]]::new()
            $frontier = @([int]$metadata.pid)
            while ($frontier.Count -gt 0) {
                $children = @($processes | Where-Object { $_.ParentProcessId -in $frontier })
                if ($children.Count -eq 0) { break }
                foreach ($child in $children) { $descendants.Add([int]$child.ProcessId) }
                $frontier = @($children | ForEach-Object { [int]$_.ProcessId })
            }
            for ($index = $descendants.Count - 1; $index -ge 0; $index--) {
                Stop-Process -Id $descendants[$index] -ErrorAction SilentlyContinue
            }
            Stop-Process -Id $metadata.pid
            Write-Host "Stopped $Name (PID $($metadata.pid))"
        }
    } catch {
        Write-Host "$Name is no longer running"
    }
    Remove-Item -LiteralPath $metadataPath -Force
}

function Get-ContainerManagedLabel([string]$Name) {
    $labelsJson = & docker container inspect --format '{{json .Config.Labels}}' $Name 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $labelsJson) { return $null }
    try {
        $labels = $labelsJson | ConvertFrom-Json
        return $labels.'com.vibematch.dev.managed'
    } catch {
        return $null
    }
}

function Stop-ManagedContainer([string]$Name) {
    $managed = Get-ContainerManagedLabel $Name
    if ($null -eq $managed) { return }
    if ($managed -ne 'true') {
        Write-Warning "Refusing to stop '$Name': it is not marked as managed by this workflow."
        return
    }
    $running = & docker container inspect --format '{{.State.Running}}' $Name
    if ($running.Trim() -eq 'true') {
        & docker stop $Name | Out-Null
        Write-Host "Stopped container $Name (data volume retained)"
    }
}

Stop-OwnedProcess 'flutter'
Stop-OwnedProcess 'backend_media'
Stop-OwnedProcess 'fastapi'
Stop-ManagedContainer $RedisContainer
Stop-ManagedContainer $PostgresContainer
