# Cache / edge architecture

Chunk 47 formalizes one cache hierarchy:

Flutter memory -> bounded offline read projection -> CDN/edge (public
immutable/revalidatable content only) -> service-local cache where safe ->
cache Redis -> rebuildable Search/Recommendation projections -> authoritative
domain/PostgreSQL.

PostgreSQL/domain services remain business authority; every cache and projection
in this hierarchy is reconstructable.

Caches never own wallet, ledger, session, ban, authorization, private-message or
settlement truth. Cache keys hash entity identifiers and use versioned namespaces.

Redis cache misses use bounded distributed single-flight using SET NX locks, TTL
jitter and a 500ms waiter budget to reduce stampedes. Failure to cache falls back
to the owner-service loader; the cache is not required for correctness.

CDN/edge caching is allowed only for public/reconstructable responses and
immutable media/assets. Personalized/private responses must be private/no-store
unless a reviewed keying model proves isolation.


## Flutter product media

FunKey product media is CDN-owned. The Flutter bundle keeps only the FunKey
logo required for application branding/launcher generation. Gift art and video,
room backgrounds, VIP/SVIP tags, family badges and presentation decorations use
versioned CDN object keys.

Static UI media resolves through `VmApiConfig.cdnOrigin`. Server-driven media
uses authoritative public URLs returned by its owning API; gift catalog URLs
resolve from `GIFT_CDN_BASE_URL` with `MEDIA_CDN_BASE_URL` as the canonical
fallback. The legacy gift-specific base exists only as a compatibility override.

Versioned CDN objects should be immutable with long cache lifetimes. A visual
replacement increments the object-key version rather than mutating cached bytes.
Client renderers retain Flutter-drawn/icon/gradient failure fallbacks but never
fall back to a bundled copy.
