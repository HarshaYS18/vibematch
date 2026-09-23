# ADR-018: Ed25519 realtime capability authentication

**Status:** Accepted  
**Date:** 2026-09-23

## Context

Chunk 21 centralized application realtime on one Go WebSocket, but the gateway still called FastAPI to authorize every connection and room subscription and periodically re-authorized every live room. At production connection counts that makes identity/room authorization traffic scale with socket count and timer cadence instead of real authority changes.

Go must not become identity, session, ban, or room-membership authority. At the same time, transient FastAPI latency must not create a large periodic authorization storm.

## Decision

FastAPI/Identity remains the capability issuer and authoritative policy evaluator. It issues short-lived, Ed25519-signed realtime capabilities after validating the normal access token, current user/session/device state, bans, and requested room permission.

Two grants are used:

- a connect capability with `realtime:connect`;
- a room-bound capability with `room:subscribe`, exact `room_id`, server-derived permission hints, and a membership/room-state version.

Capabilities also carry `user_id`, opaque `session_id`, `device_id`, `iat`, `nbf`, `exp`, `token_version`, issuer, and audience. Default lifetime is five minutes and production configuration bounds it to 60–600 seconds.

The API alone owns the Ed25519 private seed. The Go gateway fetches and caches only the public key, validates capabilities locally, and never derives user/staff identity from client fields.

The existing access token remains available inside the gateway only for forwarding allowlisted commands to FastAPI, where every durable mutation is re-authorized.

Immediate invalidation uses critical `auth.session_revoked` and `room.permission_revoked` events over the existing application realtime channel. These events accelerate disconnect/unsubscribe behavior; durable PostgreSQL state and the next capability mint remain the authority if a revocation event is missed.

The legacy `POST /api/v1/realtime/verify` endpoint remains temporarily as a rollback/control-plane seam but is removed from the normal connection/subscription hot path. Periodic HTTP reauthorization is removed.

## Key rotation

Capability tokens identify the signing key with `kid`. Rotation must be an expand/canary/soak operation: deploy a new API signing key and corresponding public-key availability before relying on the new `kid`, keep old-key verification available for at least the maximum token lifetime, then retire the old key. Never overwrite the only production key in a way that invalidates all live capabilities simultaneously.

The first implementation exposes one active public key. Multi-key/JWKS rotation support must be added before the first production key rotation if zero-disruption rotation is required.

## Consequences

Normal reconnect/subscribe authorization becomes one capability mint followed by local signature verification rather than repeated Go-to-FastAPI verification calls. Permission changes are event-driven and short token lifetime bounds missed-revocation exposure.

FastAPI remains required for minting new grants and executing business commands. If capability issuance is unavailable, new connections/subscriptions fail closed while existing authorized sockets continue until revoked/disconnected.

The private signing seed becomes production secret material that must be stored only in the API secret manager. It must never be committed, logged, placed in ConfigMaps, or mounted into the Go gateway.
