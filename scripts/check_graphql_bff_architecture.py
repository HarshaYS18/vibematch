from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BFF = ROOT / 'apps' / 'graphql-bff'
FLUTTER = ROOT / 'frontend' / 'vibematch_app' / 'lib'
K8S = ROOT / 'deploy' / 'kubernetes'
GATEWAY = K8S / 'gateway'
violations: list[str] = []


def require(path: Path, markers: tuple[str, ...] = ()) -> str:
    if not path.exists():
        violations.append(f'{path.relative_to(ROOT)}: required by Chunk 36')
        return ''
    text = path.read_text(encoding='utf-8-sig')
    for marker in markers:
        if marker not in text:
            violations.append(f'{path.relative_to(ROOT)}: missing Chunk 36 marker: {marker}')
    return text


required_bff_files = (
    'main.py', 'operations.py', 'security.py', 'schema.py', 'context.py',
    'dataloader.py', 'upstream.py', 'metrics.py', 'config.py',
    'requirements.txt', 'Dockerfile', 'README.md',
)
for name in required_bff_files:
    require(BFF / name)

main_text = require(BFF / 'main.py', ('PERSISTED_ONLY', 'UNKNOWN_OPERATION', 'max_request_bytes', 'Bearer authentication is required', 'X-Request-ID'))
schema_text = require(BFF / 'schema.py', ('GraphQLSchema(query=Query)', 'HomeComposite', 'ProfileComposite', 'DiscoveryComposite', 'CreatorAdminDashboard'))
operations_text = require(BFF / 'operations.py', ('HomeComposite', 'ProfileComposite', 'DiscoveryComposite', 'CreatorAdminDashboard', 'hashlib.sha256'))
require(BFF / 'security.py', ('max_depth', 'max_complexity', 'introspection is not available'))
require(BFF / 'dataloader.py', ('class DataLoader', '_cache', '_pending'))
upstream_text = require(BFF / 'upstream.py', ('async def get_json', 'X-Request-ID', 'traceparent', 'UPSTREAM_TIMEOUT'))

bff_python = '\n'.join(path.read_text(encoding='utf-8-sig') for path in BFF.glob('*.py'))
for marker in ('sqlalchemy', 'app.database', 'Session(', 'mutation_type='):
    if marker in bff_python:
        violations.append(f'apps/graphql-bff: forbidden authority marker: {marker}')
if 'async def post_' in upstream_text or 'async def put_' in upstream_text or 'async def delete_' in upstream_text:
    violations.append('apps/graphql-bff/upstream.py: BFF upstream client must remain read-only')

contract_path = ROOT / 'contracts' / 'graphql' / 'persisted_operations.json'
if not contract_path.exists():
    violations.append('contracts/graphql/persisted_operations.json: missing persisted allowlist contract')
    contract_ids = set()
else:
    contract = json.loads(contract_path.read_text(encoding='utf-8'))
    contract_ids = {item['id'] for item in contract.get('operations', [])}
    if len(contract_ids) != 4:
        violations.append('contracts/graphql/persisted_operations.json: exactly four Chunk 36 operations are required')

python_ids = set(re.findall(r'"([0-9a-f]{64})"', operations_text))
dart_ops = require(FLUTTER / 'foundation' / 'graphql' / 'persisted_operations.dart', ('homeComposite', 'profileComposite', 'discoveryComposite', 'creatorAdminDashboard'))
dart_ids = set(re.findall(r"'([0-9a-f]{64})'", dart_ops))
if contract_ids and python_ids != contract_ids:
    violations.append('apps/graphql-bff/operations.py: operation IDs differ from contracts/graphql manifest')
if contract_ids and dart_ids != contract_ids:
    violations.append('frontend persisted operation IDs differ from contracts/graphql manifest')

flutter_client = require(FLUTTER / 'foundation' / 'graphql' / 'persisted_graphql_client.dart', ("'id': operationId", "'variables': variables", 'VmApiConfig.graphqlEndpoint'))
if "'query':" in flutter_client or 'graphql_flutter' in flutter_client:
    violations.append('Flutter GraphQL read client must send persisted IDs only and use existing transport')
require(FLUTTER / 'features' / 'home' / 'controllers' / 'home_controller.dart', ('fetchHomeChromeComposite', 'hasPartialErrors'))
require(FLUTTER / 'features' / 'home' / 'data' / 'home_repository.dart', ('CompositeReadRepository', 'fetchHomeChromeComposite'))

require(K8S / 'base' / 'graphql-bff.yaml', ('name: funkey-graphql-bff', 'containerPort: 8091', 'readOnlyRootFilesystem: true', 'minAvailable: 2'))
require(K8S / 'base' / 'kustomization.yaml', ('graphql-bff.yaml',))
require(K8S / 'base' / 'config.yaml', ('GRAPHQL_CORE_URL', 'GRAPHQL_PROFILE_SOCIAL_URL', 'GRAPHQL_VIBES_URL', 'GRAPHQL_MAX_REQUEST_BYTES: "16384"'))
require(K8S / 'base' / 'autoscaling.yaml', ('name: funkey-graphql-bff', 'maxReplicas: 20'))
require(K8S / 'base' / 'network-policy.yaml', ('name: funkey-graphql-bff-ingress', 'port: 8091'))

routes = require(GATEWAY / 'routes.yaml', ('name: funkey-graphql', 'type: Exact, value: /graphql', 'name: funkey-graphql-bff', 'request: 10s', 'backendRequest: 8s'))
policies = require(GATEWAY / 'policies.yaml', ('name: funkey-graphql-traffic', 'limit: 64Ki', 'requests: 200'))

require(
    K8S / 'overlays' / 'staging' / 'kustomization.yaml',
    ('name: funkey-graphql', 'api.staging.funkey.com'),
)
require(
    K8S / 'overlays' / 'production' / 'kustomization.yaml',
    ('name: funkey-graphql-bff', 'ghcr.io/harshays18/vibematch/funkey-graphql-bff'),
)
require(
    K8S / 'overlays' / 'local' / 'local-scale.yaml',
    ('name: funkey-graphql-bff', 'minReplicas: 1, maxReplicas: 1'),
)
require(
    ROOT / '.github' / 'workflows' / 'production-platform.yml',
    ('funkey-graphql-bff', 'manifest.count("@sha256:") < 13', 'graphql-bff:'),
)

for doc in (
    BFF / 'README.md',
    BFF / 'tests' / 'README.md',
    ROOT / 'contracts' / 'graphql' / 'README.md',
    ROOT / 'docs' / 'frontend' / 'chunk36-graphql-read-bff.md',
    ROOT / 'docs' / 'architecture' / 'graphql-read-bff.md',
    ROOT / 'docs' / 'modules' / 'graphql-read-bff' / 'README.md',
    ROOT / 'docs' / 'runbooks' / 'graphql-read-bff.md',
    FLUTTER / 'foundation' / 'graphql' / 'README.md',
):
    if not doc.exists():
        violations.append(f'{doc.relative_to(ROOT)}: mandatory Chunk 36 documentation is missing')

if violations:
    print('Chunk 36 GraphQL BFF architecture guard failed:')
    for violation in violations:
        print(f' - {violation}')
    raise SystemExit(1)

print('Chunk 36 GraphQL BFF architecture guard passed.')
