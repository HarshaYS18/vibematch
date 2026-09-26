# Cache / edge architecture

Chunk 47 formalizes one cache hierarchy:

Flutter memory -> bounded offline read projection -> CDN/edge (public
immutable/revalidatable content only) -> service-local cache where safe ->
cache Redis -> rebuildable Search/Recommendation projections -> authoritative
domain/PostgreSQL.

Caches never own wallet, ledger, session, ban, authorization, private-message or
settlement truth. Cache keys hash entity identifiers and use versioned namespaces.

Redis cache misses use bounded distributed single-flight using SET NX locks, TTL
jitter and a 500ms waiter budget to reduce stampedes. Failure to cache falls back
to the owner-service loader; the cache is not required for correctness.

CDN/edge caching is allowed only for public/reconstructable responses and
immutable media/assets. Personalized/private responses must be private/no-store
unless a reviewed keying model proves isolation.
