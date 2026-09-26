from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class SubscriptionSpec:
    subject: str
    durable_name: str
    ack_wait_seconds: int = 90
    max_ack_pending: int = 100


@dataclass(frozen=True)
class PoolSpec:
    name: str
    subscriptions: tuple[SubscriptionSpec, ...]
    allowed_handlers: frozenset[str]
    relay_outbox: bool = False
    max_in_flight: int = 10
    active: bool = True


POOLS: dict[str, PoolSpec] = {
    "general": PoolSpec("general", (), frozenset(), relay_outbox=True, max_in_flight=1),
    "notification": PoolSpec(
        "notification",
        (SubscriptionSpec("funkey.events.notification.requested", "funkey-worker-notification"),),
        frozenset({"notification.requested"}),
        max_in_flight=20,
    ),
    "media": PoolSpec(
        "media",
        (
            SubscriptionSpec("funkey.events.vibes.media.requested", "funkey-worker-media-vibes"),
            SubscriptionSpec("funkey.events.media.uploaded", "funkey-worker-media-uploaded", ack_wait_seconds=1800, max_ack_pending=24),
            SubscriptionSpec("funkey.events.media.upload.abort.requested", "funkey-worker-media-upload-abort", ack_wait_seconds=300, max_ack_pending=24),
            SubscriptionSpec("funkey.events.media.moderation.requested", "funkey-worker-media-moderation"),
            SubscriptionSpec("funkey.events.media.delete.requested", "funkey-worker-media-delete"),
        ),
        frozenset({
            "vibes.media.requested",
            "media.uploaded",
            "media.upload.abort.requested",
            "media.moderation.requested",
            "media.delete.requested",
        }),
        max_in_flight=8,
    ),
    "fanout": PoolSpec(
        "fanout",
        (SubscriptionSpec("funkey.events.vibes.post.published", "funkey-worker-fanout"),),
        frozenset({"vibes.post.published"}),
        max_in_flight=12,
    ),
    "maintenance": PoolSpec(
        "maintenance",
        (
            SubscriptionSpec("funkey.events.inbox.backup.requested", "funkey-worker-maintenance-backup"),
            SubscriptionSpec("funkey.events.inbox.restore.requested", "funkey-worker-maintenance-restore"),
            SubscriptionSpec("funkey.events.media.cleanup.requested", "funkey-worker-maintenance-media-cleanup"),
        ),
        frozenset({
            "inbox.backup.requested",
            "inbox.restore.requested",
            "media.cleanup.requested",
        }),
        max_in_flight=4,
    ),
    # Kafka analytics is handled by the separate Chunk 37 bridge. Keep this
    # historical worker boundary inactive to prevent a second analytics owner.
    "analytics": PoolSpec("analytics", (), frozenset(), max_in_flight=8, active=False),
}


def get_pool(name: str) -> PoolSpec:
    normalized = (name or "general").strip().lower()
    if normalized not in POOLS:
        raise RuntimeError("Unknown WORKER_POOL: " + normalized)
    return POOLS[normalized]
