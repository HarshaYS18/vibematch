# FunKey Protobuf Contracts

This directory is the canonical source for internal synchronous service contracts.

- `common/v1`: cross-service metadata and primitive shared messages.
- domain packages: service-specific RPCs/messages.
- generated code must not be edited by hand.
- existing REST APIs remain compatibility/public interfaces until later service extraction chunks.

The contract tree is intentionally introduced before microservice extraction so callers and owners can evolve independently without creating a distributed monolith.
