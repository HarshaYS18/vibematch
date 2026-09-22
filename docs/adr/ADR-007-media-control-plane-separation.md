# ADR-007: Media control plane and media plane separation

Status: Accepted architectural direction (implementation status is tracked separately)

## Context

The checkpoint consolidated media into backend_media and a backend-assigned node registry.

## Decision

FastAPI remains authoritative for auth, bans, rooms, membership, seats, roles, permissions, kicks, and call participation. backend_media owns only mediasoup routers, transports, producers, consumers, and RTP lifecycle. Clients resolve a node through FastAPI; sensitive signaling actions call back for authorization.

## Consequences

This adds a control-plane dependency to media joins but prevents a second business source of truth. A media node may be healthy as a process yet unready if registry heartbeat fails.

## Validation and change criteria

Preserve the canonical backend_media implementation. Never restore historical parallel media servers or allow client-selected SFU nodes.
