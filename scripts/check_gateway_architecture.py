from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
K8S = ROOT / 'deploy' / 'kubernetes'
GATEWAY = K8S / 'gateway'
FLUTTER = ROOT / 'frontend' / 'vibematch_app' / 'lib'
TERRAFORM = ROOT / 'infra' / 'terraform'

violations: list[str] = []


def require(path: Path, markers: tuple[str, ...]) -> str:
    if not path.exists():
        violations.append(f'{path.relative_to(ROOT)}: required by Chunk 35')
        return ''
    text = path.read_text(encoding='utf-8-sig')
    for marker in markers:
        if marker not in text:
            violations.append(
                f'{path.relative_to(ROOT)}: missing Chunk 35 marker: {marker}'
            )
    return text


base_kustomization = require(
    K8S / 'base' / 'kustomization.yaml',
    ('api.yaml', 'realtime.yaml'),
)
network_policy_text = require(
    K8S / 'base' / 'network-policy.yaml',
    (
        'kubernetes.io/metadata.name: envoy-gateway-system',
        'funkey.io/observability-access: "true"',
        '- podSelector: {}',
    ),
)
if 'namespaceSelector: {}' in network_policy_text:
    violations.append(
        'deploy/kubernetes/base/network-policy.yaml: empty namespaceSelector would trust every namespace'
    )
if 'ingress.yaml' in base_kustomization:
    violations.append('deploy/kubernetes/base/kustomization.yaml: legacy Ingress must stay removed')
if (K8S / 'base' / 'ingress.yaml').exists():
    violations.append('deploy/kubernetes/base/ingress.yaml: legacy NGINX Ingress must stay deleted')

gateway_kustomization = require(
    GATEWAY / 'kustomization.yaml',
    ('gateway-class.yaml', 'gateway.yaml', 'routes.yaml', 'policies.yaml', 'canary-service.yaml'),
)
if 'security-policy.example.yaml' in gateway_kustomization:
    violations.append('optional ext-auth SecurityPolicy must not be auto-applied')

require(
    GATEWAY / 'gateway-class.yaml',
    ('kind: GatewayClass', 'gateway.envoyproxy.io/gatewayclass-controller'),
)
require(
    GATEWAY / 'gateway.yaml',
    ('kind: Gateway', 'gatewayClassName: funkey-envoy', 'api.funkey.com', 'realtime.funkey.com', 'media.funkey.com', 'funkey-api-tls', 'funkey-realtime-tls', 'funkey-media-tls'),
)
routes_text = require(
    GATEWAY / 'routes.yaml',
    (
        'name: funkey-api',
        'name: funkey-realtime',
        'name: funkey-media-control',
        '/api/v1/media-control',
        '/ws',
        'weight: 100',
        'weight: 0',
        'funkey-api-canary',
        'request: 0s',
    ),
)
media_route = routes_text.split('name: funkey-media-control', 1)[1]
if 'value: /api/v1\n' in media_route or 'value: /\n' in media_route:
    violations.append(
        'deploy/kubernetes/gateway/routes.yaml: media.funkey.com must not expose broad API/root catch-alls'
    )
policies_text = require(
    GATEWAY / 'policies.yaml',
    ('kind: ClientTrafficPolicy', 'requestID: Generate', 'kind: BackendTrafficPolicy', 'rateLimit:', 'requestBuffer:', 'limit: 10Mi', 'idleTimeout: 3600s'),
)
if policies_text.count('requestBuffer:') != 2:
    violations.append('gateway/policies.yaml: request buffering must be limited to API and media-control routes')

require(
    GATEWAY / 'security-policy.example.yaml',
    ('kind: SecurityPolicy', 'extAuth:', 'funkey-edge-auth'),
)
require(
    K8S / 'overlays' / 'staging' / 'kustomization.yaml',
    ('../../gateway', 'api.staging.funkey.com', 'realtime.staging.funkey.com', 'media.staging.funkey.com'),
)
require(
    K8S / 'overlays' / 'production' / 'kustomization.yaml',
    ('../../gateway',),
)
api_text = require(
    K8S / 'base' / 'api.yaml',
    (
        'name: funkey-api-stable',
        'matchLabels: {app: funkey-api, funkey.io/release-track: stable}',
        'selector: {app: funkey-api, funkey.io/release-track: stable}',
        'argocd.argoproj.io/sync-wave: "0"',
    ),
)
if "kind: Deployment\nmetadata:\n  name: funkey-api\n" in api_text:
    violations.append(
        'deploy/kubernetes/base/api.yaml: legacy overlapping funkey-api Deployment must stay removed'
    )
require(
    K8S / 'base' / 'autoscaling.yaml',
    (
        'scaleTargetRef: {apiVersion: apps/v1, kind: Deployment, name: funkey-api-stable}',
        'argocd.argoproj.io/sync-wave: "1"',
    ),
)
require(GATEWAY / 'canary-service.yaml', ('funkey.io/release-track: canary', 'name: funkey-api-canary'))

require(
    TERRAFORM / 'main.tf',
    ('"api.funkey.com"', '"realtime.funkey.com"', '"media.funkey.com"', '"cdn.funkey.com"'),
)
require(
    TERRAFORM / 'variables.tf',
    (
        'media_dns',
        'cdn_dns',
        'waf_policy_ref',
        'origin_restriction_ref',
        'edge_security_binding_verified',
    ),
)
require(
    TERRAFORM / 'main.tf',
    (
        'var.services.origin_restriction_ref',
        'var.services.edge_security_binding_verified',
        'operator-verified WAF and origin-restriction binding',
    ),
)

vm_config = require(
    FLUTTER / 'core' / 'network' / 'vm_api_config.dart',
    (
        'https://api.funkey.com',
        'wss://realtime.funkey.com/ws',
        'https://media.funkey.com',
        'https://cdn.funkey.com',
        'mediaControlEndpoint',
        '/media-control',
    ),
)
require(
    FLUTTER / 'features' / 'rooms' / 'data' / 'live_room_audio_service.dart',
    (
        'VmApiConfig.mediaControlEndpoint',
        "'/rooms/${Uri.encodeComponent(roomId)}/assignment'",
    ),
)
for path in FLUTTER.rglob('*.dart'):
    text = path.read_text(encoding='utf-8-sig')
    rel = path.relative_to(ROOT).as_posix()
    for marker in ('.svc.cluster.local', 'http://funkey-api:', 'http://funkey-inbox:', 'http://funkey-realtime:'):
        if marker in text:
            violations.append(f'{rel}: Flutter internal-service discovery is forbidden: {marker}')

require(
    GATEWAY / 'VERSIONS.env',
    (
        'ENVOY_GATEWAY_VERSION=v1.9.1',
        'GATEWAY_API_VERSION=v1.6.1',
        'KIND_VERSION=v0.33.0',
        'KUBERNETES_SCHEMA_VERSION=v1.36.4',
    ),
)
require(
    GATEWAY / 'install-envoy-gateway.sh',
    (
        'gateway-crds-helm',
        'crds.gatewayAPI.channel=standard',
        'crds.enabled=false',
        'deployment/envoy-gateway',
    ),
)
require(
    ROOT / 'scripts' / 'validate_gateway_schema.sh',
    ('--dry-run=server', 'GATEWAY_API_VERSION', 'gateway-crds-helm'),
)
workflow_text = require(
    ROOT / '.github' / 'workflows' / 'production-platform.yml',
    ('validate_gateway_schema.sh', 'kind create cluster', 'v1.36.4'),
)

for doc in (
    ROOT / 'docs' / 'frontend' / 'chunk35-api-gateway.md',
    ROOT / 'docs' / 'architecture' / 'api-gateway.md',
    ROOT / 'docs' / 'modules' / 'api-gateway' / 'README.md',
    ROOT / 'docs' / 'runbooks' / 'api-gateway.md',
    GATEWAY / 'README.md',
):
    if not doc.exists():
        violations.append(f'{doc.relative_to(ROOT)}: mandatory Chunk 35 documentation is missing')

if violations:
    print('Chunk 35 API Gateway architecture guard failed:')
    for violation in violations:
        print(f' - {violation}')
    raise SystemExit(1)

print('Chunk 35 API Gateway architecture guard passed.')
