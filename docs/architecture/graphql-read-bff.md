# GraphQL Read BFF architecture

## Purpose

The GraphQL BFF exists only for composite reads. Home, Profile, Discovery, and creator/admin dashboards can aggregate owning services without Flutter learning internal service topology.

Chunk 37 hardening adds strict SLO measurement and removes avoidable request-path work.

## Non-authority rule

The BFF owns no PostgreSQL tables, Redis truth, NATS subjects, WebSocket authority, or business commands. It receives no database secret. All reads go through owning HTTP APIs with the caller bearer token.

## Security envelope

Only four SHA-256 persisted operations are accepted. Ad-hoc query text is rejected. Introspection is rejected. Maximum depth is 4, complexity is 30, and the JSON request cap is 16KiB.

Persisted documents are immutable for a process lifetime, so security inspection and GraphQL schema validation happen once at startup. Unsafe or invalid checked-in operations fail process startup; accepted requests do not repeat this work.

## Composition

Sibling fields execute asynchronously. Request-scoped DataLoaders deduplicate repeated profile/user-Vibes keys.

Home event and policy banners intentionally share one request-scoped `/home-banners` owner read. The BFF partitions the active list by placement after the single authoritative read. This removes duplicate upstream HTTP and JSON work while preserving request-level freshness and the no-cross-request-cache rule.

Upstream reads have a bounded deadline and request-local concurrency limit. Authorization, `X-Request-ID`, and `traceparent` propagate to owner services.

## SLO observability

The service emits cumulative Prometheus histograms:

- `funkey_graphql_operation_duration_seconds`, labelled only by persisted operation name and `ok|error`;
- `funkey_graphql_upstream_duration_seconds`, labelled only by fixed owner-service name and `ok|error`.

No user ID, room ID, request ID, URL path, token, or GraphQL variable is permitted as a metric label.

Successful responses include aggregate `graphql-exec` and total `bff` values in `Server-Timing`. Per-service topology remains in server-side metrics/traces.

## Partial data

Owner timeout, HTTP, and protocol failures map to field-level GraphQL errors. Valid sibling data may still return. This is a read-composition availability feature, not permission to synthesize missing state.

## Client

Flutter uses the existing networking runtime and sends only persisted operation IDs plus variables. No second GraphQL transport stack is introduced.

## Commands

All writes stay on existing REST/gRPC command APIs. The Go realtime gateway remains the sole application WebSocket.
