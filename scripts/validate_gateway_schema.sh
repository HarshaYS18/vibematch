#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT_DIR}/deploy/kubernetes/gateway/VERSIONS.env"

command -v helm >/dev/null
command -v kubectl >/dev/null

helm template funkey-envoy-crds   oci://docker.io/envoyproxy/gateway-crds-helm   --version "${ENVOY_GATEWAY_VERSION}"   --set crds.gatewayAPI.enabled=true   --set crds.gatewayAPI.channel=standard   --set crds.envoyGateway.enabled=true   | kubectl apply --server-side --force-conflicts -f -

kubectl wait --for=condition=Established   crd/gateways.gateway.networking.k8s.io   crd/clienttrafficpolicies.gateway.envoyproxy.io   crd/backendtrafficpolicies.gateway.envoyproxy.io   crd/securitypolicies.gateway.envoyproxy.io   --timeout=180s

actual_gateway_api="$(
  kubectl get crd gateways.gateway.networking.k8s.io     -o jsonpath='{.metadata.annotations.gateway\.networking\.k8s\.io/bundle-version}'
)"
if [[ "${actual_gateway_api}" != "${GATEWAY_API_VERSION}" ]]; then
  echo "Gateway API bundle mismatch: expected ${GATEWAY_API_VERSION}, got ${actual_gateway_api}" >&2
  exit 1
fi

kubectl create namespace funkey --dry-run=client -o yaml | kubectl apply -f -
kubectl kustomize "${ROOT_DIR}/deploy/kubernetes/gateway" > /tmp/funkey-gateway-schema.yaml
kubectl apply --server-side --dry-run=server -f /tmp/funkey-gateway-schema.yaml
kubectl apply --server-side --dry-run=server   --namespace funkey   -f "${ROOT_DIR}/deploy/kubernetes/gateway/security-policy.example.yaml"
