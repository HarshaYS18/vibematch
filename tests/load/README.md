# Load test suite

These k6 scenarios exercise real HTTP, WebSocket upgrades, and backend media discovery. They do not generate RTP and cannot establish SFU capacity. Use dedicated WebRTC clients and actual TURN paths for media-plane testing.

Run `pwsh scripts/task.ps1 load-test-smoke` after `pwsh scripts/task.ps1 dev`. For authenticated cases, provide a disposable test account token through `FUNKEY_TEST_TOKEN`; media discovery also needs `FUNKEY_TEST_ROOM_ID`. Never use production accounts or the production environment for exploratory load tests.

Run increasing stages only after the preceding stage passes: local correctness, 1k, 10k, 50k, 100k, 250k, 500k, then 1M concurrent users. These are test stages, not supported capacity claims. Each stage needs distributed generators, representative room sizes, churn, reconnect storms, and sustained duration. Record RPS per API pod, WebSockets and messages per gateway, DB connections per pod, Redis ops/sec, JetStream events/sec, and rooms/peers/bandwidth per media node. Stop scaling when p95 latency, error budget, reconnect success, queue age, or dependency saturation crosses its observed safe limit.

The smoke thresholds in scripts are controlled correctness/promotion gates. They are not universal production SLOs. Media heartbeat/drain and Redis failure exercises belong in a disposable staging cluster with the chaos suite; issuing synthetic node heartbeats against production can corrupt assignments.

## Reconnect and soak execution

`reconnect-storm.js` repeatedly upgrades, optionally subscribes to a disposable room, disconnects, and reconnects. Use it while normal room traffic is being generated through the authoritative API to measure reconnect success and gateway fanout recovery. Set `VUS`, `DURATION`, and `HOLD_MS` explicitly for each stage.

A soak run reuses the same scenarios with a longer `DURATION` (for example several hours) and fixed representative concurrency. Do not promote a measured capacity number until HTTP, realtime, worker backlog, Redis, PostgreSQL, JetStream, media CPU/bandwidth, TURN relay use, and client reconnect success were captured from the same environment.

## GraphQL persisted-read smoke

`graphql-read-smoke.js` exercises the real persisted Home composite at
`/graphql`. It requires `FUNKEY_TEST_TOKEN`. Missing authentication now aborts
the test instead of silently sleeping, so an empty workload can never produce
a false-green promotion result.

The controlled smoke gate requires all of the following:

- zero HTTP request failures;
- zero failed k6 checks;
- zero unexpected GraphQL failures;
- zero GraphQL semantic errors, including `errors[]` returned with HTTP 200;
- p95 Home-composite latency below 250ms;
- p99 Home-composite latency below 500ms.

The Home response is also required to contain `myRoom`, `eventBanners`, and
`policyBanners`, while allowing legitimate null field values. The test performs
no blanket retry and therefore exposes real transport, protocol, owner-service,
and tail-latency instability.

These thresholds are intentionally aggressive for a controlled same-region
promotion smoke. They do not imply that every FunKey operation, mobile network,
or global user path must complete within 250ms. Operation-specific SLOs remain
the production rule.
