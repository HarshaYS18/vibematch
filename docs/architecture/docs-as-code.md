# Docs-as-code and architecture conformance

Chunk 54 makes architectural documentation executable enough to fail CI when
core invariants drift.

The high-level conformance gate composes the existing backend, frontend,
contract, documentation and ownership guards. It additionally rejects
feature-local raw networking, requires exactly one `RoomSessionRepository`
definition and verifies that the Mermaid system map includes every major
platform boundary.

The Markdown link checker validates repository-local links across architecture,
runbooks, governance, developer portal, module indexes and primary READMEs.

Conformance gates are intentionally structural. They do not replace unit,
integration, load, chaos, security or production-certification evidence.
