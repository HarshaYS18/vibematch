param(
    [string]$Namespace = "funkey-staging",
    [string]$ApiUrl = "https://api.staging.example.invalid",
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
if ($Namespace -notmatch 'staging') { throw "Only staging namespaces are permitted." }
$podList = kubectl -n $Namespace get pods -l app=funkey-api -o json | ConvertFrom-Json
$pods = @($podList.items | ForEach-Object { $_.metadata.name })
if ($pods.Count -lt 3) { throw "Need at least three API replicas before fault injection." }
$targetPod = $pods[0]
Write-Host "Target API pod: $targetPod in $Namespace"
if (-not $Execute) { Write-Host "Dry run. Pass -Execute to delete one pod."; exit 0 }
kubectl -n $Namespace delete pod $targetPod --wait=false
for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
        $response = Invoke-WebRequest -Uri "$ApiUrl/ready" -TimeoutSec 3
        if ($response.StatusCode -eq 200) { Start-Sleep -Seconds 2; continue }
    } catch { throw "API availability failed after pod termination: $_" }
}
kubectl -n $Namespace rollout status deployment/funkey-api --timeout=180s
Write-Host "API remained available and deployment recovered."
