param(
    [string]$Namespace = "funkey",
    [string]$Broker = "funkey-kafka-2"
)

$ErrorActionPreference = "Stop"
if ($env:FUNKEY_CHAOS_APPROVED -ne "true") {
    throw "Set FUNKEY_CHAOS_APPROVED=true only for an approved disposable staging exercise."
}
if ($Namespace -match "prod") {
    throw "This harness refuses production namespaces."
}

Write-Host "Deleting one staging Kafka broker pod to exercise KRaft recovery."
$pod = kubectl -n $Namespace get pods -l "statefulset.kubernetes.io/pod-name=$Broker-0" -o jsonpath='{.items[0].metadata.name}'
if (-not $pod) { throw "Broker pod not found: $Broker-0" }
kubectl -n $Namespace delete pod $pod --wait=false

Write-Host "Wait for the StatefulSet and Kafka PDB-backed cluster to recover before checking bridge/consumer lag."
kubectl -n $Namespace rollout status "statefulset/$Broker" --timeout=300s
kubectl -n $Namespace get pods -l app=funkey-kafka
