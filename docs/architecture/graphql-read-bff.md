# GraphQL Read BFF architecture

## Purpose

Chunk 36 introduces GraphQL only for composite reads. Home, Profile, Discovery and creator/admin dashboards can aggregate multiple owning services without Flutter discovering internal service endpoints.

## Non-authority rule

The BFF owns no PostgreSQL tables, Redis truth, NATS subjects, WebSocket, or business commands. It receives no database secret. All reads flow through owning HTTP APIs with the caller bearer token.

## Security envelope

Only four SHA-256 persisted operations are accepted. Ad-hoc `query` payloads are rejected, the allowlist is checked into `contracts/graphql`, introspection is rejected, maximum depth is 4, complexity budget is 30 and JSON request size is capped at 16KiB.

Envoy adds a 64KiB outer buffer/rate limit; the smaller application cap is authoritative for the BFF payload.

## Composition

GraphQL sibling fields are asynchronous, so unrelated owner reads execute concurrently. Request-scoped DataLoaders deduplicate profile/user-Vibes keys. No cross-request DataLoader cache exists.

Upstream reads use a 2.5-second deadline and a request-local concurrency semaphore. Authorization, `X-Request-ID` and `traceparent` propagate to owner services. OpenTelemetry spans identify operation ID/name and upstream service without recording variables or tokens.

## Partial data

Owner timeouts, HTTP failures and protocol errors map to field-level GraphQL errors. Other fields may still return data. This is a read-composition availability feature, not permission to synthesize missing business state.

## Client

Flutter uses the existing AppNetworkRuntime and sends only operation IDs plus variables. No `graphql_flutter` stack is introduced. Home chrome is the first live cutover: my room plus event/policy banners replace three independent reads with one persisted operation while preserving existing domain models/UI.

## Commands

All writes remain existing REST/gRPC-backed command APIs. The Go realtime gateway remains the sole application WebSocket.
