# Authority registry conformance

**Owner:** Platform Architecture

CI runs the backend architecture guard and registry regression tests. Failure means the proposed repository state violates or cannot parse the authority contract.

Common failures are duplicate IDs, invalid classes, missing required states, projections/caches without valid sources, ephemeral state without reconstruction, or financial truth assigned outside Economy.

Safe response: identify the failing state, determine whether code changed ownership or docs drifted, update ADR/migration plan first if ownership truly changes, otherwise correct the registry/docs, rerun checks, and never weaken the guard simply to make CI green.

Chunk 15 has no data/runtime migration; rollback is a Git revert. For later service migrations, restore routing to the previous authoritative owner rather than allowing two writers.

Retain failing/passing CI, changed state IDs, architecture decisions, and cutover/rollback evidence.
