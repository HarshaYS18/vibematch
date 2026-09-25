# Chunk 38 — Search / Discovery

**Status: implementation complete; CI/integration validation is the closure gate.**

Delivered:

- standalone Search service and OpenSearch projection boundary
- NATS JetStream projector with ACK-after-index-write
- strict searchable document contract and tombstone deletes
- user/room/Vibe query kinds with bounded fuzzy multi-match
- compatibility `/api/v1/search` facade
- Flutter search cutover without UI redesign
- local/staging OpenSearch support and managed-production prerequisite
- architecture guard, tests, container build, docs and runbook

Definition of done: no synchronous DB/OpenSearch dual-write, projection failure
does not affect durable commands, index is rebuildable, Search CI is green and
the existing UI consumes the canonical Search endpoint.
