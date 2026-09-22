# Load test suite

These k6 scenarios exercise real HTTP, WebSocket upgrades, and backend media discovery. They do not generate RTP and cannot establish SFU capacity. Use dedicated WebRTC clients and actual TURN paths for media-plane testing.

Run `pwsh scripts/task.ps1 load-test-smoke` after `pwsh scripts/task.ps1 dev`. For authenticated cases, provide a disposable test account token through `FUNKEY_TEST_TOKEN`; media discovery also needs `FUNKEY_TEST_ROOM_ID`. Never use production accounts or the production environment for exploratory load tests.

Run increasing stages only after the preceding stage passes: local correctness, 1k, 10k, 50k, 100k, 250k, 500k, then 1M concurrent users. These are test stages, not supported capacity claims. Each stage needs distributed generators, representative room sizes, churn, reconnect storms, and sustained duration. Record RPS per API pod, WebSockets and messages per gateway, DB connections per pod, Redis ops/sec, JetStream events/sec, and rooms/peers/bandwidth per media node. Stop scaling when p95 latency, error budget, reconnect success, queue age, or dependency saturation crosses its observed safe limit.

The smoke thresholds in scripts are local correctness checks. They are not production SLOs. Media heartbeat/drain and Redis failure exercises belong in a disposable staging cluster with the chaos suite; issuing synthetic node heartbeats against production can corrupt assignments.
