# Staging and production rollout

This is the release sequence once an environment has the external prerequisites. Repository manifests and CI do not themselves provision credentials, DNS, certificates, backups, or a validated cluster. Argo CD is the selected GitOps reconciler; use pinned immutable image digests and reviewed environment configuration.

## Traffic paths

```text
HTTPS API: Internet -> CDN/WAF -> regional LB -> ingress -> core API
WebSocket: Internet -> WS-capable LB -> realtime gateway (or current FastAPI route)
Media: client -> backend media discovery -> assigned SFU signaling and RTC ports
       restricted networks -> TURN relay -> SFU
```

HTTP ingress should enforce TLS, request limits, forwarded request IDs, and timeouts. WebSocket ingress must support upgrade, appropriate idle timeout, and connection draining. SFU RTP/UDP traffic and TURN need their own network path; do not send RTP through ordinary HTTP ingress. Backend assignment and authorization remain mandatory.

## Release sequence

1. Confirm staging/production secrets, DNS, certificate, managed PostgreSQL backup/PITR, Redis single-primary media topology, NATS streams, bucket/CDN, TURN credentials, and monitoring.
2. Build and scan images in CI, run backend, Go, media, contract, and relevant Flutter checks, and publish immutable digests. Review manifest diff and connection budget including rollout surge.
3. Deploy additive schema first with the single Alembic job. Validate its head and a smoke test against a staging clone; then apply to production during the approved release window.
4. Promote compatible API and worker versions, then gateway canary. Keep Go gateway in shadow/foundation until Flutter and room contract parity is proven. Observe readiness, p95, 5xx, DB pool, event lag, and duplicate handling.
5. For media rollout, mark each old node draining through the canonical registry, stop new assignments, wait for peer count to fall, and terminate only at the approved deadline. Verify media discovery and real WebRTC audio between devices, including TURN-only connectivity.
6. Promote client traffic only after API/realtime/media smoke tests and rollback path pass. Record image digests, migration revision, manifest commit, and observed capacity.

## Rollback

Pause GitOps promotion and restore the last known-good compatible image/config digest. Keep the new schema if it is additive and backward compatible; do not automatically downgrade an applied migration. Drain gateway and media replicas before removal, keep enough healthy capacity for reconnects, and verify snapshots, room events, media, inbox, and ledger reconciliation. A broken migration or data integrity event follows its dedicated runbook. Restore the previous traffic split only after the old version is healthy.
