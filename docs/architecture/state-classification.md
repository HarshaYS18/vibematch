# State Classification

**Owner:** Platform Architecture  
**Status:** Canonical classification policy

Every mutable FunKey state is classified before adding a store, cache, broker, index, or client copy.

## AUTHORITY

Canonical truth with one logical mutation owner. Examples include room membership, the wallet ledger, Inbox messages, Vibe posts, and media metadata.

Rules:

- No duplicate writers.
- Other domains call the owner rather than mutating its storage.
- Authority cannot depend on a projection for correctness.
- A transport does not become authority because it carries the freshest event.
- Financial truth stays server-side and ledger-backed.

## PROJECTION

Derived state optimized for query or downstream work. Examples include OpenSearch documents, feed candidates, rankings, Kafka analytical streams, and ClickHouse rows.

Every projection names its upstream source states, can be rebuilt, and may lag without corrupting business correctness. Never treat synchronous writes to PostgreSQL plus OpenSearch, Kafka, or ClickHouse as two sources of truth.

## CACHE

A replaceable copy used for latency or offline UX. Examples include Flutter master-state caches, room snapshot caches, and Redis read caches.

A cache names its source, has a bounded freshness/version policy when implemented, and never wins against newer backend truth. Financial and permission checks cannot trust a cache unless the owner defines the consistency contract.

## EPHEMERAL

Live operational coordination that is intentionally reconstructable. Examples include socket leases, typing, connection routing, mediasoup transports, temporary matchmaking, and rate-limit buckets.

Redis/Valkey may be operational authority for this class. Each entry records how it is rebuilt; total Redis loss must not destroy permanent business correctness.

## Decision order

1. Permanent loss changes money, ownership, identity, permissions, content, or audit truth -> **AUTHORITY**.
2. Deterministically rebuildable query/index/analytics output -> **PROJECTION**.
3. Faster or offline copy of another state -> **CACHE**.
4. Exists only while a connection, job, or lease is live -> **EPHEMERAL**.

If none fits cleanly, write an ADR before adding the store.

## Systems that are not durable business authorities

Without a later explicit ADR, the Go realtime gateway, GraphQL BFF, Flutter, Redis cache (except ephemeral leases), remote game JavaScript, OpenSearch, Kafka, ClickHouse, and recommendation rankers do not own durable business truth.

Object storage is a special case: canonical uploaded bytes may be authoritative there, while metadata, ownership, moderation, and lifecycle state remain database-owned by Media Control.
