$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

function Require-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required developer tool '$Name' was not found in PATH."
    }
}

Require-Command python
Require-Command docker
Require-Command git

$backendEnv = Join-Path $repo 'backend/.env'
$backendExample = Join-Path $repo 'backend/.env.example'
if (-not (Test-Path $backendEnv) -and (Test-Path $backendExample)) {
    Copy-Item $backendExample $backendEnv
    Write-Host 'Created backend/.env from .env.example'
}

$mediaEnv = Join-Path $repo 'backend_media/.env'
$mediaExample = Join-Path $repo 'backend_media/.env.example'
if (-not (Test-Path $mediaEnv) -and (Test-Path $mediaExample)) {
    Copy-Item $mediaExample $mediaEnv
    Write-Host 'Created backend_media/.env from .env.example'
}

Push-Location (Join-Path $repo 'backend')
try {
    python -m pip install -r requirements-test.txt
    if ($LASTEXITCODE -ne 0) { throw 'Backend dependency install failed.' }
} finally { Pop-Location }

if (Get-Command npm -ErrorAction SilentlyContinue) {
    Push-Location (Join-Path $repo 'backend_media')
    try {
        npm ci
        if ($LASTEXITCODE -ne 0) { throw 'Media dependency install failed.' }
    } finally { Pop-Location }
}

if (Get-Command flutter -ErrorAction SilentlyContinue) {
    Push-Location (Join-Path $repo 'frontend/vibematch_app')
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Flutter dependency resolution failed.' }
    } finally { Pop-Location }
}

Write-Host 'FunKey developer bootstrap complete.'
Write-Host 'Next: make dev, then make seed.'
