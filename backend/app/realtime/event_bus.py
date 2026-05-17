from __future__ import annotations

import asyncio
from collections import defaultdict
from typing import Any, Awaitable, Callable


EventHandler = Callable[[str, dict[str, Any]], Awaitable[None]]


class RealtimeEventBus:
    """Small async event bus with a Redis-ready boundary.

    For local beta this runs in-process. The service API is intentionally shaped
    around channels so it can be replaced with Redis pub/sub without changing
    room/inbox/gift services later.
    """

    def __init__(self) -> None:
        self._subscribers: dict[str, set[EventHandler]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def subscribe(self, channel: str, handler: EventHandler) -> None:
        async with self._lock:
            self._subscribers[channel].add(handler)

    async def unsubscribe(self, channel: str, handler: EventHandler) -> None:
        async with self._lock:
            handlers = self._subscribers.get(channel)
            if not handlers:
                return
            handlers.discard(handler)
            if not handlers:
                self._subscribers.pop(channel, None)

    async def publish(self, channel: str, payload: dict[str, Any]) -> None:
        handlers = list(self._subscribers.get(channel, set()))
        for handler in handlers:
            try:
                await handler(channel, payload)
            except Exception:
                # A broken subscriber should never break the saved backend action.
                continue


def room_channel(room_public_id: str) -> str:
    return f"room:{room_public_id}"


def user_channel(user_id: int) -> str:
    return f"user:{user_id}"


realtime_event_bus = RealtimeEventBus()
