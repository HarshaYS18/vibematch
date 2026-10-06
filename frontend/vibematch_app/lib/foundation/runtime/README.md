# Foundation Runtime

This directory contains runtime contracts that may be consumed by features
without depending on AppShell implementation details.

## Media resource lifecycle

`media_resource_lifecycle.dart` defines the Chunk 34 foundation port for heavy
resource lifecycle coordination:

- `MediaResourceKind` classifies lifecycle cost;
- `MediaResourceParticipant` is implemented by feature/app adapters;
- `MediaResourceRegistry` is the registration/lifecycle interface;
- `mediaResourceRegistryProvider` is nullable by default and overridden by the
  authenticated AppShell.

No durable domain state belongs in these contracts. Features must not import
`app/runtime/media_resource_coordinator.dart`.


## Resource budget policy

`media_resource_budget.dart` assigns every `MediaResourceKind` a recommended
active-count budget and pressure tier. This policy is lifecycle infrastructure
only; it never becomes application/domain authority.
