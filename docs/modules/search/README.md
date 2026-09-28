# Search module

Owner: Search Service.

Owns OpenSearch mappings, search relevance, projection consumption and query
availability. Does not own profile/room/Vibe state.

Projection producers must add an explicit `search_projection` object to durable
domain events. Search does not scrape service databases and domain services do
not import OpenSearch clients.

Failure mode: return a bounded 503/degraded state; never route writes through
Search or treat stale index data as authorization truth.
