# Persisted GraphQL read contract

`persisted_operations.json` is the machine-readable Chunk 36 allowlist shared by the Python BFF and Flutter persisted-read client.

Each ID is the SHA-256 hash of the canonical query text held by the BFF. Changing a query requires changing its hash, this manifest, the Flutter operation catalog, tests, architecture guard and relevant feature documentation in one review.

The contract contains read operations only. It is not a schema for business commands and does not authorize callers; owning services still enforce authorization.
