# Realtime / media QoS runbook

Check realtime connection count, hot-room count, max room subscribers, best-effort
drops, priority evictions and slow-client closes. For media check join p95,
hot-room peers, node capacity, CPU, packet loss, jitter, RTT and TURN relay usage.

If a hot room grows, scale gateways/media capacity and confirm client distribution
before increasing per-node limits. Do not create another WebSocket or SFU authority.

For degraded media prefer adaptation/lower bitrate before forcing TCP. Verify TURN
fallback on restrictive networks. After recovery, reconnect clients must resync
authoritative room snapshots.
