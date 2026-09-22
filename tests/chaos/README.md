# Failure tests

Run chaos exercises in a disposable staging namespace with dashboards and rollback access. First capture baseline API p95/error rate, WebSocket connections/reconnects, media joins, queue age, DB pool pressure, and Redis errors. Record recovery time and data consistency after each test.

| Exercise | Fault | Required observation |
| --- | --- | --- |
| API replica | Delete one API pod | Readiness removes it; requests continue through remaining replicas |
| Gateway replica | Delete or drain one gateway pod | New upgrades avoid draining node; clients reconnect; no authoritative room state is lost |
| Media node | Invoke drain, then evict | New rooms avoid node; existing peers leave or reach stated deadline |
| Redis | Isolate endpoint | Presence/media discovery degrade explicitly; wallet/identity remain DB-authoritative |
| PostgreSQL | Restart/fail over | API readiness responds; liveness does not restart-loop; no partial value transfer |
| JetStream | Pause consumer | Queue age rises, KEDA scales workers, replay remains idempotent |
| Worker | Kill during delivery | Message redelivers once safely; dead-letter after bounded retries |
| Object storage | Block bucket | Upload fails cleanly without local permanent fallback |
| TURN only | Block direct UDP | Real WebRTC clients complete relay connection |
| Deployment | Roll API and gateway under traffic | No version-contract break, controlled reconnects |
| Migration | Simulate failed expand step | Old app stays healthy; rollback follows migration runbook |
| Zone loss | Cordon/drain one zone | PDB/topology policy preserves minimum replicas where capacity allows |

`api-pod-termination.ps1` automates the first case. It is staging-only and requires `-Execute`; without it the script displays the target and exits. Media, TURN, region, and database tests require provider-specific fault injection and are intentionally not automated against unknown infrastructure.
