param(
    [ValidateSet("realtime", "worker")]
    [string]$Workload = "realtime",
    [string]$Namespace = "funkey-staging",
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
if ($Namespace -notmatch 'staging') { throw "Only staging namespaces are permitted." }

$deployment = "funkey-$Workload"
$label = "app=$deployment"
$minimum = if ($Workload -eq "realtime") { 3 } else { 1 }
$podList = kubectl -n $Namespace get pods -l $label -o json | ConvertFrom-Json
$pods = @($podList.items | Where-Object { $_.status.phase -eq "Running" } | ForEach-Object { $_.metadata.name })
if ($pods.Count -lt $minimum) { throw "Need at least $minimum running $Workload pod(s) before fault injection." }

$targetPod = $pods[0]
Write-Host "Target $Workload pod: $targetPod in $Namespace"
if (-not $Execute) {
    Write-Host "Dry run. Pass -Execute to delete one pod."
    exit 0
}

kubectl -n $Namespace delete pod $targetPod --wait=false
kubectl -n $Namespace rollout status "deployment/$deployment" --timeout=240s
kubectl -n $Namespace wait --for=condition=Ready pod -l $label --timeout=240s

$readyList = kubectl -n $Namespace get pods -l $label -o json | ConvertFrom-Json
$ready = @(
    $readyList.items | Where-Object {
        $_.status.phase -eq "Running" -and
        ($_.status.conditions | Where-Object { $_.type -eq "Ready" -and $_.status -eq "True" })
    }
)
if ($ready.Count -lt $minimum) { throw "$Workload did not recover its minimum ready replica count." }
Write-Host "$Workload recovered after pod termination."
