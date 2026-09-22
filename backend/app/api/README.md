# Canonical FunKey API composition

`app.api.router` is the sole production composition root for `/api/v1`. Routes do not register child routers as import side effects. The composition groups system/identity, social/content, rooms/realtime, inbox/communication, economy/gifts/games/store, and administration.

Each method and path pair must be registered once. Extend the canonical resource instead of adding parallel `v2`, `mvp`, `compat`, `public`, or placeholder routes. Keep compatibility translation in a service or adapter when possible. Routes should validate request shape and call a domain service; authorization, durable writes, and transaction boundaries belong in the domain layer.

`app.database` provides SQLAlchemy sessions; `app.core.config.settings.redis_url` configures Redis. Alembic alone changes schema. New routes must include permission checks, bounded input, structured errors, and tests for both allowed and denied paths. Preserve Flutter contracts during the Go strangler migration.

For ownership details see the [module index](../../../docs/MODULE_INDEX.md), [source-of-truth architecture](../../../docs/master-source-of-truth-architecture.md), and [media split](../../../docs/production_realtime_media_architecture.md).
