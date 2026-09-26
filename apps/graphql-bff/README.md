# GraphQL Read BFF

This service implements read-only GraphQL composition and owns no durable business state.

## File map

- `main.py`: FastAPI lifecycle, persisted-only endpoint, startup operation compilation, request-ID and Server-Timing propagation, health and metrics.
- `operations.py`: canonical query text and immutable SHA-256 allowlist.
- `security.py`: query-only, introspection, depth and complexity checks.
- `schema.py`: Home, Profile, Discovery and Creator/Admin read schema.
- `context.py`: per-request context and DataLoaders, including shared Home-banner loading.
- `dataloader.py`: request-scoped batching/de-duplication only.
- `upstream.py`: GET-only owner-service client with deadlines, bounded concurrency, auth/request-ID/trace forwarding, error mapping, and latency telemetry.
- `metrics.py`: low-cardinality Prometheus counters and operation/upstream histograms.
- `config.py`: environment-only runtime limits/upstream URLs.
- `requirements.txt`: BFF-specific dependency pins.
- `Dockerfile`: non-root production image.
- `tests/README.md`: test ownership.

## Authority

The BFF does not import SQLAlchemy, database sessions, or domain models and has no mutation root. Business writes remain REST/gRPC commands at the owning service.

## Request contract

Production accepts only persisted operation `id` plus `variables`. Ad-hoc query text and unknown IDs are rejected. Bearer authentication is mandatory and forwarded unchanged to owners.

## Hot-path rules

Persisted documents are security-inspected and schema-validated once at process startup. Invalid checked-in operations fail startup instead of charging every request for repeated validation.

Home event and policy banners come from one request-scoped `/home-banners` owner read and are partitioned in the BFF. This removes duplicate HTTP/JSON work without introducing cross-request caching or stale authority.

## Latency observability

Accepted requests emit `funkey_graphql_operation_duration_seconds` histograms keyed only by immutable operation name and `ok|error`. Owner reads emit `funkey_graphql_upstream_duration_seconds` keyed only by fixed service name and `ok|error`.

Successful responses also include aggregate `graphql-exec` and total `bff` durations in `Server-Timing`. No user IDs, room IDs, request IDs, variables, tokens, or dynamic paths are metric labels.

## Failure semantics

Sibling fields execute independently. Upstream timeout/HTTP/protocol failures become field-level GraphQL errors so valid sibling data can still return. The BFF does not retry internally.

## Batching and caching

DataLoaders live for one request only. They deduplicate repeated keys but create no cross-request cache or alternative source of truth.
