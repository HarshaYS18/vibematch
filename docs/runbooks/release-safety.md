# Release safety runbook

For a bad rollout, stop exposure with the narrowest available kill switch or
traffic canary before rolling back binaries. Confirm old and new clients still
speak a supported contract.

Do not remove a deprecated REST/event/realtime/GraphQL/game/manifest version
until usage evidence shows no supported client depends on it and the published
notice window has elapsed.

If a schema migration is involved, roll application traffic back only to a
version compatible with the already-applied schema. Never "undo" a production
migration by ad-hoc destructive SQL.
