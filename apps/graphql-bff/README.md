# GraphQL Read BFF

This directory implements Chunk 36 read composition and owns no durable business state.

## File map

- `main.py`: FastAPI lifecycle, persisted-only GraphQL HTTP endpoint, payload/auth checks, request-ID response propagation, health and metrics.
- `operations.py`: canonical query text and immutable SHA-256 allowlist.
- `security.py`: query-only, introspection, depth and complexity checks.
- `schema.py`: Home, Profile, Discovery and Creator/Admin read schema.
- `context.py`: per-request context and DataLoaders.
- `dataloader.py`: request-scoped batching/de-duplication only.
- `upstream.py`: GET-only owning-service client with deadlines, bounded concurrency, auth/request-ID/trace forwarding and GraphQL error mapping.
- `metrics.py`: low-cardinality Prometheus counters.
- `config.py`: environment-only runtime limits/upstream URLs.
- `requirements.txt`: BFF-specific dependency pins.
- `Dockerfile`: non-root production image.
- `tests/README.md`: test ownership.

## Authority

The BFF does not import SQLAlchemy, database sessions or domain models. It has no GraphQL mutation root. Business writes remain REST/gRPC commands at the owning domain service.

## Request contract

Production accepts JSON containing only persisted operation `id` and `variables`. Ad-hoc query text and unknown IDs are rejected. Bearer authentication is mandatory and is forwarded unchanged to owning services.

## Failure semantics

Sibling fields execute independently. Upstream timeout/HTTP/protocol failures become field-level GraphQL errors, allowing usable sibling data to remain in the response. The BFF does not retry internally.

## Batching and caching

DataLoaders live for one request only. They deduplicate/batch repeated keys but create no cross-request cache or alternative source of truth.
