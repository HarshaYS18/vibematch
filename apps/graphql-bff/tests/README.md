# GraphQL BFF tests

`test_runtime.py` checks the exact four persisted operations, SHA-256 IDs, read-only schema, depth/complexity budgets, request-scoped DataLoader deduplication, the one-read Home-banner optimization, and Prometheus operation/upstream latency histogram exposition.

`test_boundary.py` prevents database/SQLAlchemy authority and non-GET upstream methods from entering this service.

Repository-level `scripts/check_graphql_bff_architecture.py` additionally checks Python/Dart operation-ID parity, Gateway/Kubernetes wiring, Flutter Home cutover, strict smoke-SLO markers, startup-compiled operation budgets, bounded-cardinality latency telemetry, the Home-banner deduplication path, and mandatory documentation.
