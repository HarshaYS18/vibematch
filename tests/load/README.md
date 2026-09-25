# Load test suite

These k6 scenarios exercise real HTTP, WebSocket upgrades, and backend media discovery. They do not generate RTP and cannot establish SFU capacity. Use dedicated WebRTC clients and actual TURN paths for media-plane testing.

Run `pwsh scripts/task.ps1 load-test-smoke` after `pwsh scripts/task.ps1 dev`. For authenticated cases, provide a disposable test-account token through `FUNKEY_TEST_TOKEN`; media discovery also needs `FUNKEY_TEST_ROOM_ID`. Never use production accounts or the production environment for exploratory load tests.

Run increasing stages only after the preceding stage passes: local correctness, 1k, 10k, 50k, 100k, 250k, 500k, then 1M concurrent users. These are test stages, not supported-capacity claims. Each stage needs distributed generators, representative room sizes, churn, reconnect storms, and sustained duration. Record RPS per API pod, WebSockets/messages per gateway, DB connections per pod, Redis ops/sec, JetStream events/sec, and rooms/peers/bandwidth per media node. Stop scaling when p95 latency, error budget, reconnect success, queue age, or dependency saturation crosses its observed safe limit.

The smoke thresholds in scripts are controlled correctness/promotion gates, not universal production SLOs. Media heartbeat/drain and Redis-failure exercises belong in a disposable staging cluster with the chaos suite; issuing synthetic node heartbeats against production can corrupt assignments.

## Reconnect and soak execution

`reconnect-storm.js` repeatedly upgrades, optionally subscribes to a disposable room, disconnects, and reconnects. Use it while normal room traffic is generated through the authoritative API to measure reconnect success and fanout recovery. Set `VUS`, `DURATION`, and `HOLD_MS` explicitly for each stage.

A soak run reuses the same scenarios with a longer `DURATION` and fixed representative concurrency. Do not promote a measured capacity number until HTTP, realtime, worker backlog, Redis, PostgreSQL, JetStream, media CPU/bandwidth, TURN relay use, and client reconnect success were captured from the same environment.

## GraphQL persisted-read smoke

`graphql-read-smoke.js` exercises the real persisted Home composite at
`/graphql`. It requires `FUNKEY_TEST_TOKEN`; missing auth aborts the test so
an empty workload can never create a false-green result.

The controlled promotion gate requires:

- HTTP request failures = 0%;
- k6 failed checks = 0%;
- unexpected GraphQL failures = 0%;
- GraphQL semantic errors = 0%, including `errors[]` returned with HTTP 200;
- every required Home field present;
- Home end-to-end p95 < 250ms and p99 < 500ms;
- BFF `Server-Timing` present on every accepted response;
- BFF server p95 < 200ms and p99 < 400ms.

The scenario performs no blanket retry and therefore exposes real transport,
protocol, owner-service, and tail-latency instability.

Chunk 37 also removes duplicate Home banner owner reads: event and policy
placements now share one request-scoped active-banner read. The smoke remains
end-to-end and therefore still includes gateway/network cost; BFF timing is
tracked separately so a regression can be localized instead of hidden by a
single aggregate percentile.

These budgets are intentionally aggressive for a controlled same-region smoke.
They do not imply that every FunKey operation, mobile network, or global user
path has the same budget. Production SLOs remain operation-specific.
