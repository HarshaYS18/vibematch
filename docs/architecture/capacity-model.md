# Capacity model and evidence

The design target is a path toward approximately one million concurrent users, not a measured result. No pod count or environment variable in this repository proves that target. Record every stage with hardware, region, dataset, test scripts, duration, error budget, and observed percentiles before declaring support.

## Work units to measure

| Layer | Per-instance measure | Saturation and dependency checks |
| --- | --- | --- |
| API | Sustained RPS, in-flight requests, p95/p99, error rate | DB pool wait, PostgreSQL queries/locks, Redis latency, CPU/memory |
| Realtime | Active WebSockets, messages/sec, fanout recipients/sec | Outbound queue, reconnect rate, event lag, CPU/memory/network |
| Worker | Jobs/sec, oldest message age, redelivery rate | Downstream provider rate, DB pool, JetStream lag, DLQ |
| Media | Rooms, peers, packets/sec, ingress/egress bandwidth | SFU CPU/memory, loss/jitter, join failure, TURN use, registry health |
| PostgreSQL | Transactions/sec, connections, slow queries, WAL | Pool waits, replication lag, lock waits, disk and IOPS |
| Redis/Valkey | Ops/sec and script latency | Memory, evictions, failover, registry heartbeat age |
| NATS | Events/sec, pending and oldest age | Stream storage, consumer ack/redelivery, broker CPU/disk |

## Planning equations

Use measured sustainable rates with a safety factor, not theoretical maxima:

```text
api_pods >= peak_api_rps / (measured_rps_per_pod × target_utilization)
gateway_pods >= max(peak_sockets / safe_sockets_per_pod,
                    peak_messages_per_second / safe_messages_per_second_per_pod)
media_nodes >= max(peak_rooms / safe_rooms_per_node,
                   peak_peers / safe_peers_per_node,
                   peak_bandwidth / safe_bandwidth_per_node)
max_api_pods × api_pool_per_pod
  + max_worker_pods × worker_pool_per_pod
  + rollout_surge_connections
  + migration/admin/monitoring/failover_reserve
  <= allowed_postgresql_connections
```

Separate system, API/worker, realtime, and media node pools. The provider node autoscaler can add a worker VM only when the cluster has quota, address space, image access, and suitable zone capacity. Pending pods are an input to node scaling, not proof that a VM can be created.

## Test ladder

Run local correctness, then 1k, 10k, 50k, 100k, 250k, 500k, and 1M concurrent stages only when the previous stage meets latency, error, recovery, and cost targets. At each stage include auth, snapshots, room join, WebSocket fanout, reconnect storm, node drain, media discovery, and real WebRTC/RTP capacity tests. HTTP discovery tests cannot stand in for SFU packet or TURN bandwidth tests. Exercise deployment and one-node failure during sustained load.

Record results in a separate dated report with exact scripts and topology. A failed stage is useful evidence; retain the bottleneck and remediation plan. Never copy projected values into a measured-capacity column.
