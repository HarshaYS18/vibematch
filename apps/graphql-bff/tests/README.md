# GraphQL BFF tests

`test_runtime.py` checks the exact four persisted operations, SHA-256 IDs, read-only schema, depth/complexity budgets and DataLoader deduplication.

`test_boundary.py` prevents database/SQLAlchemy authority and non-GET upstream methods from entering this service.

Repository-level `scripts/check_graphql_bff_architecture.py` additionally checks Python/Dart operation-ID parity, Gateway/Kubernetes wiring, Flutter Home cutover and mandatory documentation.
