# Flutter Resource Runtime

This module documents the AppShell/session-scoped runtime that coordinates
heavy Flutter resources.

## Source of truth

The resource runtime is **not** a domain source of truth. It coordinates
lifecycle pressure only. Domain authorities remain unchanged:

- room state: `RoomSessionRepository`;
- room media: `RoomMediaEngine`;
- Watch Party: its canonical repository/coordinator;
- games: Game Platform runtime/bridge;
- identity/session/realtime: their existing canonical repositories/runtimes.

## Lifecycle rules

Heavy resource owners register a small adapter with
`MediaResourceCoordinator`. The coordinator may broadcast app
foreground/background changes, memory pressure, and authenticated-session
teardown. Feature owners still create, mutate, and normally dispose their own
resources.

The coordinator itself is provided through Riverpod `Provider.autoDispose`;
a process-global singleton is forbidden.

## Current rollout

Chunk 34-M1 introduces only the contract, provider, tests, and guard. No
production resource has been migrated yet.
