# Flutter GraphQL read foundation

This directory owns the Chunk 36 persisted-read transport contract.

- `persisted_operations.dart` is the checked-in SHA-256 operation catalog and must match the backend BFF registry.
- `persisted_graphql_client.dart` sends only operation IDs and variables through the existing process-scoped `AppNetworkRuntime`; it adds no second HTTP stack or GraphQL package.
- `composite_read_repository.dart` exposes the four read composites: Home, Profile, Discovery and Creator/Admin dashboard.

GraphQL is read-only. Feature command methods continue to use their existing REST/gRPC command APIs. The first production cutover is Home chrome, replacing three parallel reads with one persisted composite while mapping back into the same Home domain models and UI state.

GraphQL partial errors are retained in `GraphqlReadResult.errors`; callers may render usable partial data instead of converting one upstream failure into an all-or-nothing page failure.
