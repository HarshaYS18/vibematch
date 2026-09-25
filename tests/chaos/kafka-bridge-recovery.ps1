param(
    [string]$Namespace = "funkey"
)

$ErrorActionPreference = "Stop"
if ($env:FUNKEY_CHAOS_APPROVED -ne "true") {
    throw "Set FUNKEY_CHAOS_APPROVED=true only for an approved disposable staging exercise."
}
if ($Namespace -match "prod") {
    throw "This harness refuses production namespaces."
}

$selector = "app=funkey-kafka-event-bridge"
$pod = kubectl -n $Namespace get pods -l $selector -o jsonpath='{.items[0].metadata.name}'
if (-not $pod) { throw "Kafka bridge pod not found." }

Write-Host "Deleting one Kafka bridge pod. JetStream must retain unacknowledged records."
kubectl -n $Namespace delete pod $pod --wait=false
kubectl -n $Namespace rollout status deployment/funkey-kafka-event-bridge --timeout=300s

Write-Host "Bridge recovered. Inspect source_pending/source_redelivered and verify backlog drains without silent loss."
kubectl -n $Namespace get pods -l $selector
