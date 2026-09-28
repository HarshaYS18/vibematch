"""Request-scoped DataLoader with batching and key de-duplication."""

from __future__ import annotations

import asyncio
from collections.abc import Awaitable, Callable, Hashable, Mapping
from typing import Any


BatchFunction = Callable[[list[Hashable]], Awaitable[Mapping[Hashable, Any]]]


class DataLoader:
    def __init__(self, batch_function: BatchFunction) -> None:
        self._batch_function = batch_function
        self._cache: dict[Hashable, asyncio.Future[Any]] = {}
        self._pending: list[Hashable] = []
        self._scheduled = False

    async def load(self, key: Hashable) -> Any:
        existing = self._cache.get(key)
        if existing is not None:
            return await existing

        loop = asyncio.get_running_loop()
        future: asyncio.Future[Any] = loop.create_future()
        self._cache[key] = future
        self._pending.append(key)
        if not self._scheduled:
            self._scheduled = True
            loop.call_soon(self._schedule_dispatch)
        return await future

    def _schedule_dispatch(self) -> None:
        asyncio.create_task(self._dispatch())

    async def _dispatch(self) -> None:
        keys = self._pending
        self._pending = []
        self._scheduled = False
        if not keys:
            return
        try:
            values = await self._batch_function(keys)
            for key in keys:
                future = self._cache[key]
                value = values.get(key)
                if isinstance(value, Exception):
                    future.set_exception(value)
                else:
                    future.set_result(value)
        except Exception as exc:
            for key in keys:
                future = self._cache[key]
                if not future.done():
                    future.set_exception(exc)
