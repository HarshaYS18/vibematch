# Realtime degraded

Use this procedure with the production incident commander and environment-specific access controls. Record every change and its UTC timestamp. Never paste bearer tokens or private message content into incident notes.

## Symptoms

- Go `/ws` upgrades fail or reconnect rate spikes.
- Inbox/global/notification/wallet events stop arriving together.
- Room deltas lag, sequence gaps increase, or snapshot fallbacks spike.
- Best-effort drops or slow-client closes increase.
- `/ready` fails because Redis subscription/health is unavailable.
- FastAPI command relay returns elevated `command/error` rates.

Mediasoup/WebRTC failures are a separate media-plane incident unless application realtime is also unhealthy.

## Dashboards and metrics to inspect

Check:

- gateway active/accepted connections;
- auth/capacity denials;
- Redis subscription health and latency;
- best-effort drops and lower-priority evictions;
- slow-client closes;
- reconnect rate and close codes;
- room replay attempts/success/fallback and sequence-gap rate;
- FastAPI `/realtime/capability`, `/realtime/capability-key`, and `/realtime/command` latency/errors;
- gateway/FastAPI pod restarts, CPU, memory, network egress;
- PostgreSQL lock/deadlock/serialization errors for room commands.

## Immediate actions

1. Freeze the realtime rollout.
2. Determine whether the failure is gateway process/edge, capability issuance/public-key refresh, FastAPI command authority, Redis fanout/replay/revocation, or a domain backend.
3. Keep healthy gateway replicas ready for reconnect surge.
4. Do not reroute application traffic to the retired FastAPI Inbox/room sockets.

## Safe mitigation

- Remove unhealthy gateway replicas from readiness and allow clients to reconnect to healthy replicas.
- Restore Redis/Valkey health before increasing gateway capacity.
- Let room clients use bounded replay when possible and authoritative snapshot recovery when continuity is not provable.
- For command-plane errors, restore FastAPI/PostgreSQL authority; do not execute durable mutations inside Go.
- Preserve queue limits. Dropping best-effort hints is safer than allowing unbounded memory growth.

## Dangerous actions to avoid

- Do not restore retired `/ws/inbox` or `/ws/room-realtime` as a quick fix.
- Do not route mediasoup signaling through the application gateway.
- Do not disable capability signature/scope/expiry checks or revocation handling to improve availability.
- Do not remove queue/rate/connection bounds to hide saturation.
- Do not claim correctness from sticky sessions; replicas are designed to be stateless for application truth.

## Capability-specific checks

If connect/subscription denials spike after Chunk 22:

1. Confirm the API can mint a capability with the expected issuer, audience, token version, expiry, and `kid`.
2. Confirm `GET /api/v1/realtime/capability-key` exposes the matching public key and no private material.
3. Confirm gateway `REALTIME_CAPABILITY_KEY_URL`, issuer, audience, and token version match the API.
4. For room failures, mint through the authenticated room-capability endpoint and verify the requested room ID exactly matches the signed room binding.
5. Inspect critical `auth.session_revoked` and `room.permission_revoked` event flow on the canonical realtime channel.
6. Never copy `REALTIME_CAPABILITY_PRIVATE_KEY_B64` into the gateway as a workaround.

If the active signing key must be rolled back, restore the previous API key/public-key pair using the approved secret-manager/deployment rollback. Because the first implementation exposes one active key, abrupt rotation invalidates outstanding capabilities; use a controlled rollout and reconnect/resubscribe soak.

## Recovery validation

Across at least two gateway replicas verify:

1. authenticated connection and `funkey.v2` negotiation;
2. Inbox message/activity delivery;
3. room subscribe with a room-bound capability and local Go verification;
4. room delta delivery;
5. reconnect with contiguous replay;
6. forced replay miss causing authoritative snapshot recovery;
7. seat/settings/chat command round trip through FastAPI;
8. user/staff/all routing isolation;
9. session/device revocation plus room-permission revocation and capability remint;
10. mediasoup audio still works independently.

Keep elevated monitoring through the normal incident soak window.

## Escalation and data to collect

Collect gateway node ID, connection ID, affected user/room IDs, event IDs, stream/sequence cursor, close code, trace/request IDs, queue/replay metrics, Redis errors, FastAPI control-plane status, active capability `kid` (never the token), and rollout image SHA. Never collect bearer tokens, capability tokens, or private signing material.
