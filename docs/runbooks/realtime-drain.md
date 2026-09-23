# Realtime gateway drain

Use this procedure for rolling deploys, scale-in, or controlled node removal. Record every change and its UTC timestamp. Never paste credentials into incident notes.

## Goal

Drain one Go application-realtime replica without losing durable application truth or causing an uncontrolled reconnect storm. Mediasoup nodes are drained separately.

## Before drain

Check:

- enough healthy `/ready` gateway replicas remain for the reconnect surge;
- Redis subscription health is green;
- FastAPI `/realtime/verify` and `/realtime/command` are healthy;
- reconnect rate, slow-client closes, and queue pressure are normal.

## Drain behavior

On SIGTERM the gateway:

1. marks itself draining and stops being ready for new upgrades;
2. sends the critical `server.draining` control event;
3. refreshes node state as draining;
4. waits up to the configured drain deadline;
5. closes remaining sockets;
6. removes its node lease.

Clients reconnect to another ready replica. Room clients re-subscribe with their last stream/sequence cursor and either receive bounded replay or fetch an authoritative snapshot.

## Safe procedure

1. Remove the target pod from new upgrade routing through readiness/drain.
2. Confirm new connections stop landing on the target.
3. Watch active connection count fall and reconnect rate rise within expected bounds.
4. Keep sufficient healthy replicas available; do not simultaneously drain too many pods.
5. Allow the configured drain deadline to complete before force termination.
6. Verify room replay/snapshot fallback and application command round trips on replacement replicas.

## Dangerous actions to avoid

- Do not kill a gateway with many live sockets unless required for security/safety.
- Do not depend on load-balancer affinity for correctness.
- Do not re-enable retired FastAPI application sockets during normal drain.
- Do not drain mediasoup/SFU nodes as though they were application gateway replicas; use the media-plane procedure.

## Recovery validation

Verify:

- target `/ready` is false while draining;
- no new upgrades reach it;
- active connections trend toward zero;
- clients reconnect with `funkey.v2`;
- room subscriptions are re-authorized;
- contiguous room replay works;
- replay misses cause authoritative snapshot refresh rather than stale state;
- Inbox/global/notification/wallet events continue on replacement replicas;
- command execution remains authoritative in FastAPI.

## Escalation data

Record target pod/node ID, image SHA, drain start/end UTC, active sockets at start/deadline, reconnect failures, close codes, replay fallback rate, Redis/control-plane errors, and replacement-replica capacity.
