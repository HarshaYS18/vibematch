param(
  [string]$DeviceId = ""
)

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {
    $_.IPAddress -like "192.168.*" -and
    $_.PrefixOrigin -ne "WellKnown"
  } |
  Select-Object -First 1 -ExpandProperty IPAddress)

if (-not $ip) {
  Write-Host "Could not find LAN IP. Check Wi-Fi connection."
  exit 1
}

$envDir = "env"
$envFile = "$envDir/dev_lan_auto.json"

if (!(Test-Path $envDir)) {
  New-Item -ItemType Directory -Path $envDir | Out-Null
}

@"
{
  "VM_API_BASE_URL": "http://${ip}:8000",
  "VM_MEDIA_WS_URL": "ws://${ip}:9000/ws",
  "VM_AUDIO_URL": "http://${ip}:4000",
  "VM_GOOGLE_ANDROID_SERVER_CLIENT_ID": "112046889240-db25nkdrkv5i0qtcveo878g3e9v8gctb.apps.googleusercontent.com"
}
"@ | Set-Content -Encoding UTF8 $envFile

Write-Host "Using LAN IP: $ip"
Write-Host "Generated env:"
Get-Content $envFile

if ($DeviceId -eq "") {
  flutter run --dart-define-from-file=$envFile
} else {
  flutter run -d $DeviceId --dart-define-from-file=$envFile
}