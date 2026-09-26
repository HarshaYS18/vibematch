# Privacy request runbook

Identity owns the durable request record. Domain owners own the underlying data.

For an export request, verify every registered authority contributes only the
requesting user's exportable fields and excludes secrets/internal moderation
material. Deliver the bundle through an authenticated, expiring channel.

For deletion, stop new user sessions, process domain tombstones/deletions, remove
Search/Recommendation projections and media objects where permitted, and
pseudonymize legally retained audit/financial records.

Never manually delete Economy ledger rows to satisfy a privacy request. Record
completion/failure evidence against the privacy request ID.
