# FunKey system map

This diagram is documentation of the same authority model enforced in code and
contracts. It must evolve with deployable/service-boundary changes.

```mermaid
flowchart LR
  Flutter[Flutter client] --> Edge[Gateway / compatibility API]
  Flutter --> RT[Go application realtime]
  Flutter --> Media[mediasoup media plane]

  Edge --> Identity[Identity]
  Edge --> Profile[Profile / Social]
  Edge --> Inbox[Inbox]
  Edge --> Vibes[Vibes]
  Edge --> Room[Room Control]
  Edge --> Economy[Economy]
  Edge --> Games[Game Platform]
  Edge --> Notify[Notification]
  Edge --> GraphQL[GraphQL Read BFF]
  Edge --> Search[Search]
  Edge --> Reco[Recommendation]

  Games --> Economy
  Room --> RT
  Room --> Media

  Identity --> PG[(PostgreSQL)]
  Profile --> PG
  Inbox --> PG
  Vibes --> PG
  Room --> PG
  Economy --> PG
  Games --> PG
  Notify --> PG

  Identity --> NATS[NATS JetStream]
  Profile --> NATS
  Inbox --> NATS
  Vibes --> NATS
  Room --> NATS
  Economy --> NATS
  Games --> NATS

  NATS --> KafkaBridge[Kafka Event Bridge]
  KafkaBridge --> Kafka[(Kafka)]
  Kafka --> Reco
  Kafka --> Analytics[Analytics Sink]
  Analytics --> CH[(ClickHouse)]
  Analytics --> Lake[(Parquet / object storage)]

  NATS --> Search
  Search --> OS[(OpenSearch)]

  RT --> RRedis[(Realtime Redis)]
  Search -. rebuildable .-> OS
  Reco -. rebuildable .-> CRedis[(Cache Redis)]

  PG:::authority
  classDef authority fill:#fff,stroke:#111,stroke-width:3px
```

## Conformance invariants

- PostgreSQL/domain owners remain durable business truth.
- Economy is the only financial mutation authority.
- Redis, OpenSearch, Recommendation state, ClickHouse and the data lake are
  reconstructable/cache/analytical state, not command authority.
- NATS is operational async transport; Kafka is retained analytics/replay/ML,
  not synchronous RPC.
- Flutter has one application WebSocket and one canonical REST networking path.
- mediasoup owns media transport only.
