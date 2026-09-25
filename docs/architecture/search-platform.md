# Search / Discovery architecture

Chunk 38 replaces client-side room filtering and direct multi-endpoint discovery
with one Search service boundary while preserving the existing UI.

```text
PostgreSQL transaction
  -> transactional outbox
  -> NATS JetStream
  -> Search projector
  -> OpenSearch
  -> Search API
  -> existing Flutter search UI
```

## Invariants

- no synchronous PostgreSQL + OpenSearch dual-write
- OpenSearch contains only rebuildable projections
- search failures never mutate or corrupt business state
- projection ACK occurs only after OpenSearch accepts the document
- deletes are represented as tombstone projections
- user/room/Vibe permissions remain owner-service concerns; only publicly
  searchable projection fields belong in the index
- production OpenSearch is a managed/private prerequisite; credentials never
  live in the repository

## Rollout

The compatibility API exposes `GET /api/v1/search` and forwards it to the Search
service so the Flutter base URL does not change. The Search service supports
`user`, `room` and `vibe` kinds and bounded result limits.

## Rebuild

Rebuild into a new versioned index, validate counts/relevance, then atomically
switch the search alias. Never clear the active index in place during production
rebuilds.
