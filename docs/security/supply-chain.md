# Software supply-chain security

Chunk 42 makes dependency review, CodeQL, secret scanning and critical filesystem
vulnerability scanning mandatory CI surfaces.

Published backend images must remain immutable by digest in production and the
existing publication workflow generates SBOM/provenance artifacts. Dependency
updates are automated but still require normal tests/architecture guards.

Never suppress a scanner globally to make CI green. A temporary exception must
identify the exact advisory, affected component, compensating control, owner and
expiry date.

GitHub dependency review additionally requires the repository dependency graph to be enabled. Until that repository setting is available, its workflow step is advisory rather than a false blocking gate; CodeQL, gitleaks and critical Trivy findings remain hard failures.
