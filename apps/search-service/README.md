# Search Service

Chunk 38 introduces OpenSearch as a **rebuildable search projection**, never a
business source of truth.

Canonical write path:

```text
PostgreSQL transaction -> transactional outbox -> NATS JetStream
                         -> Search projector -> OpenSearch
```

Domain services never synchronously dual-write OpenSearch. Search documents are
carried in explicit `payload.search_projection` event projections and can be
rebuilt/replayed. If OpenSearch is unavailable, search may return 503 while the
authoritative application remains correct.

The service owns query relevance, index mappings, projection consumption and
search-specific observability. It does not own users, rooms, Vibes or permissions.
