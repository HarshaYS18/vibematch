# Privacy / data governance architecture

Chunk 43 defines public, internal, restricted and highly-restricted data classes,
retention rules and a durable user privacy-request workflow owned by Identity.

A user can request export or deletion. Identity records the request and emits a
durable transactional-outbox event; domain owners perform their own export/
deletion/pseudonymization according to authority and legal retention rules.

Search and Recommendation are disposable projections and must delete/rebuild on
domain tombstones. Analytics may not ingest credentials or private message bodies
without an explicit approved purpose.

Deletion never means silently corrupting Economy/audit integrity: legally
required financial/security records are pseudonymized/minimized according to the
retention policy rather than rewritten as if transactions never existed.
