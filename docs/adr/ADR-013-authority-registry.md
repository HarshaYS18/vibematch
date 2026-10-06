# ADR-013: Machine-readable state authority registry

**Status:** Accepted  
**Date:** 2026-09-23

## Context

FunKey is evolving from a modular monolith plus dedicated realtime/media/worker deployables toward selectively extracted services. Prose ownership documentation can drift and accidentally claim overlapping authority.

## Decision

Maintain one machine-readable registry at `contracts/architecture/authorities.yaml`, backed by the architecture authority/classification docs. Each state declares classification, logical owner, current deployable/storage, target storage, mutators, source states or reconstruction path, change-contract status and migration status.

CI rejects duplicate/missing required states, unresolved projection sources, unreconstructable ephemeral state, and financial ownership outside Economy.

The file intentionally uses JSON syntax. JSON is valid YAML 1.2 and can be parsed with the Python standard library, avoiding a new runtime dependency.

## Consequences

Logical ownership becomes enforceable before microservice extraction. Target infrastructure can be recorded without falsely claiming deployment. Projection/cache/ephemeral stores cannot silently become business authorities.

## Non-goals

Chunk 15 does not extract services, move tables, change runtime request behavior, deploy Kafka/OpenSearch/ClickHouse, or migrate presence.
