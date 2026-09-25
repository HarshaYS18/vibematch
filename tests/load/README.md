# Load test suite

These k6 scenarios exercise real HTTP, WebSocket upgrades, and backend media discovery. They do not generate RTP and cannot establish SFU capacity. Use dedicated WebRTC clients and actual TURN paths for media-plane testing.

Run `pwsh scripts/task.ps1 load-test-smoke` after `pwsh scripts/task.ps1 dev`. For authenticated cases, provide a disposable test account token through `FUNKEY_TEST_TOKEN`; media discovery also needs `FUNKEY_TEST_ROOM_ID`. Never use production accounts or the production environment for exploratory load tests.

Run increasing stages only after the preceding stage passes: local correctness, 1k, 10k, 50k, 100k, 250k, 500k, then 1M concurrent users. These are test stages, not supported capacity claims. Each stage needs distributed generators, representative room sizes, churn, reconnect storms, and sustained duration. Record RPS per API pod, WebSockets and messages per gateway, DB connections per pod, Redis ops/sec, JetStream events/sec, and rooms/peers/bandwidth per media node. Stop scaling when p95 latency, error budget, reconnect success, queue age, or dependency saturation crosses its observed safe limit.

The smoke thresholds in scripts are local correctness checks. They are not production SLOs. Media heartbeat/drain and Redis failure exercises belong in a disposable staging cluster with the chaos suite; issuing synthetic node heartbeats against production can corrupt assignments.


## Reconnect and soak execution

`reconnect-storm.js` repeatedly upgrades, optionally subscribes to a disposable room, disconnects, and reconnects. Use it while normal room traffic is being generated through the authoritative API to measure reconnect success and gateway fanout recovery. Set `VUS`, `DURATION`, and `HOLD_MS` explicitly for each stage.

A soak run reuses the same scenarios with a longer `DURATION` (for example several hours) and fixed representative concurrency. Do not promote a measured capacity number until HTTP, realtime, worker backlog, Redis, PostgreSQL, JetStream, media CPU/bandwidth, TURN relay use, and client reconnect success were captured from the same environment.


## GraphQL persisted-read smoke

`graphql-read-smoke.js` exercises the real persisted Home composite at
`/graphql`. It requires `FUNKEY_TEST_TOKEN`; without a token the scenario
only sleeps and does not generate authenticated load.

The smoke budget is intentionally stricter than the Gateway's 10-second hard
deadline: less than 2% request failures and p95 below 1500ms. These are
promotion/smoke thresholds, not a universal production SLO. Run this scenario
against staging with representative owner-service latency before raising BFF
HPA or concurrency limits.
