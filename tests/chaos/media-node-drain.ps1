param(
    [string]$Namespace = "funkey-staging",
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
if ($Namespace -notmatch 'staging') { throw "Only staging namespaces are permitted." }

$podList = kubectl -n $Namespace get pods -l app=funkey-media -o json | ConvertFrom-Json
$pods = @($podList.items | Where-Object { $_.status.phase -eq "Running" } | ForEach-Object { $_.metadata.name })
if ($pods.Count -lt 3) { throw "Need at least three running media pods before drain testing." }
$targetPod = $pods[0]
Write-Host "Target media pod: $targetPod in $Namespace"
Write-Host "Deleting the pod exercises the configured preStop drain hook and 420s termination grace period."
if (-not $Execute) {
    Write-Host "Dry run. Pass -Execute only with active dashboards and disposable test sessions."
    exit 0
}

kubectl -n $Namespace delete pod $targetPod --wait=false
kubectl -n $Namespace rollout status deployment/funkey-media --timeout=540s
kubectl -n $Namespace wait --for=condition=Ready pod -l app=funkey-media --timeout=540s
Write-Host "Media deployment recovered. Verify the dashboard showed draining=1 and no forced peer loss before marking the exercise passed."
