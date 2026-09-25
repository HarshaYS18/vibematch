# App Runtime

Files in this directory are authenticated AppShell/session-scoped runtimes.
They coordinate cross-feature lifecycle or realtime wiring without becoming
parallel domain-state authorities.

## Resource coordination

`media_resource_coordinator.dart` is the Chunk 34 lifecycle registry for
heavy resources. It is created with Riverpod `Provider.autoDispose`, contains
no feature singleton, and owns no room/Watch Party/game/gift state.

Feature integrations must register adapters explicitly and preserve their
existing canonical repositories/controllers. Memory-pressure operations may
discard reconstructable/warm resources only; durable state is never stored
here.
