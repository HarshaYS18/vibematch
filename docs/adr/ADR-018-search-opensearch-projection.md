# ADR-018: OpenSearch as rebuildable search projection

Status: Accepted and implemented in Chunk 38

Search is not business authority. PostgreSQL/domain services remain authoritative
for users, rooms and Vibes. Search documents are emitted through the transactional
outbox and NATS JetStream, then projected asynchronously into OpenSearch.

The prohibited design is a synchronous domain transaction that commits PostgreSQL
and OpenSearch together. OpenSearch unavailability may degrade search while
durable business state remains correct.

The Search service owns relevance, mappings, index lifecycle and projection
consumption. It may be rebuilt from durable events/backfill without changing
business truth.
