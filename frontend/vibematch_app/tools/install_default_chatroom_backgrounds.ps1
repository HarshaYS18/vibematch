param(
  [Parameter(Mandatory = $true)]
  [string]$SourceFolder
)

$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$targetFolder = Join-Path $projectRoot 'assets/images/room_backgrounds/chat_room/default'

$requiredFiles = @(
  'celestial_falls.webp',
  'moonlit_biolume_shore.webp',
  'aurora_frost_lake.webp',
  'desert_dusk_oasis.webp',
  'alpine_twilight_mirror.webp',
  'crimson_coast_beacon.webp',
  'moonlit_whisper_grove.webp',
  'cosmic_horizon_veil.webp'
)

if (-not (Test-Path $SourceFolder)) {
  throw "Source folder not found: $SourceFolder"
}

New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null

# Remove old local default background files from the default folder.
Get-ChildItem -Path $targetFolder -File -Include *.png, *.jpg, *.jpeg, *.webp -ErrorAction SilentlyContinue |
  Remove-Item -Force

foreach ($fileName in $requiredFiles) {
  $sourceFile = Join-Path $SourceFolder $fileName
  if (-not (Test-Path $sourceFile)) {
    throw "Missing required background file: $sourceFile"
  }

  Copy-Item -Path $sourceFile -Destination (Join-Path $targetFolder $fileName) -Force
}

Write-Host 'Installed default chatroom backgrounds:' -ForegroundColor Green
foreach ($fileName in $requiredFiles) {
  Write-Host " - $fileName"
}

Write-Host ''
Write-Host 'Next commands:' -ForegroundColor Cyan
Write-Host 'flutter pub get'
Write-Host 'flutter analyze'
