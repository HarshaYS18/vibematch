# Region failure

Use this procedure with the production incident commander. Record every action
and UTC timestamp. Never paste credentials into incident notes.

## Symptoms

A regional edge, cluster, PostgreSQL, Redis, media, Search or Recommendation
path becomes unavailable.

## Immediate checks

Inspect global routing health, regional pod readiness, authoritative PostgreSQL
state/replica lag, object storage reachability, regional Redis roles, Kafka/NATS
lag and media/TURN reachability. Record current RPO and estimated RTO against
`contracts/platform/recovery-objectives-v1.json`.

## Economy writer rule

Economy is single-writer. Before moving `ECONOMY_WRITER_REGION`, prove the
previous writer cannot accept mutations and confirm the database writer/failover
state. A region receiving Economy traffic while it is not configured as writer
must return `REGION_NOT_WRITER`.

Never run two Economy writer regions or two writable PostgreSQL primaries.

## Safe mitigation

Route stateless/read/reconstructable traffic to the nearest healthy region only
after its dependencies are ready. Realtime clients reconnect and resync from
authoritative snapshots. Search and Recommendation may rebuild/degrade.

## Recovery validation

Critical identity, room and Economy flows pass in the surviving region; ledgers
reconcile; no dual writer exists; delayed NATS/Kafka work drains; realtime/media
reconnect succeeds; achieved RPO/RTO is recorded.

## Failback

Return traffic gradually after the recovered region has synchronized projections
and dependencies. Move Economy writer ownership only through another explicit
single-writer transition. Keep elevated monitoring until backlogs and ledgers
are reconciled.
