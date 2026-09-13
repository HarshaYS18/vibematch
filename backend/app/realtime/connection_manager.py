from __future__ import annotations

import asyncio
import json
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from fastapi import WebSocket
from redis.asyncio import Redis
from starlette.websockets import WebSocketState

from app.core.config import settings


class RealtimeConnectionManager:
    """Local socket registry backed by Redis pub/sub for cross-worker delivery."""

    def __init__(self) -> None:
        self._room_clients: dict[str, set[WebSocket]] = defaultdict(set)
        self._client_rooms: dict[WebSocket, set[str]] = defaultdict(set)
        self._client_users: dict[WebSocket, int | None] = {}
        self._room_versions: dict[str, int] = {}
        self._instance_id = uuid4().hex
        self._redis: Redis = Redis.from_url(settings.redis_url, decode_responses=True)
        self._listener_task: asyncio.Task[None] | None = None

    async def _ensure_listener(self) -> None:
        if self._listener_task is not None and not self._listener_task.done():
            return
        self._listener_task = asyncio.create_task(self._listen())

    async def _listen(self) -> None:
        while True:
            pubsub = self._redis.pubsub(ignore_subscribe_messages=True)
            try:
                await pubsub.psubscribe("funkey:room:*")
                async for message in pubsub.listen():
                    raw = message.get("data")
                    if not isinstance(raw, str):
                        continue
                    try:
                        envelope = json.loads(raw)
                    except json.JSONDecodeError:
                        continue
                    if envelope.get("origin") == self._instance_id:
                        continue
                    room_id = str(envelope.get("room_id") or "")
                    payload = envelope.get("payload")
                    if not room_id or not isinstance(payload, dict):
                        continue
                    target = envelope.get("target_user_id")
                    await self._deliver_local(
                        room_id,
                        payload,
                        int(target) if target is not None else None,
                    )
            except asyncio.CancelledError:
                raise
            except Exception:
                await asyncio.sleep(1)
            finally:
                try:
                    await pubsub.aclose()
                except Exception:
                    pass

    async def connect_room(self, room_public_id: str, websocket: WebSocket, user_id: int | None = None) -> None:
        await self._ensure_listener()
        self._room_clients[room_public_id].add(websocket)
        self._client_rooms[websocket].add(room_public_id)
        self._client_users[websocket] = user_id

    def disconnect(self, websocket: WebSocket) -> list[str]:
        rooms = list(self._client_rooms.pop(websocket, set()))
        for room_public_id in rooms:
            sockets = self._room_clients.get(room_public_id)
            if sockets:
                sockets.discard(websocket)
                if not sockets:
                    self._room_clients.pop(room_public_id, None)
        self._client_users.pop(websocket, None)
        return rooms

    def connected_count(self, room_public_id: str) -> int:
        return len(self._room_clients.get(room_public_id, set()))

    @staticmethod
    def _is_connected(websocket: WebSocket) -> bool:
        return (
            websocket.client_state == WebSocketState.CONNECTED
            and websocket.application_state == WebSocketState.CONNECTED
        )

    async def send_json(self, websocket: WebSocket, payload: dict[str, Any]) -> bool:
        if not self._is_connected(websocket):
            return False
        try:
            await websocket.send_json(payload)
            return True
        except Exception:
            return False

    def _version(self, payload: dict[str, Any]) -> int | None:
        body = payload.get("payload")
        room = body.get("room") if isinstance(body, dict) else None
        if not isinstance(room, dict):
            return None
        try:
            return int(room.get("state_version"))
        except (TypeError, ValueError):
            return None

    async def _deliver_local(self, room_public_id: str, payload: dict[str, Any], target_user_id: int | None = None) -> None:
        version = self._version(payload)
        current = self._room_versions.get(room_public_id)
        if version is not None and current is not None and version < current:
            return
        if version is not None:
            self._room_versions[room_public_id] = max(version, current or version)
        for client in list(self._room_clients.get(room_public_id, set())):
            if target_user_id is not None and self._client_users.get(client) != target_user_id:
                continue
            await self.send_json(client, payload)

    def _decorate(self, payload: dict[str, Any]) -> dict[str, Any]:
        event = dict(payload)
        event.setdefault("event_id", uuid4().hex)
        event.setdefault("sent_at", datetime.now(timezone.utc).isoformat())
        return event

    async def _publish(self, room_public_id: str, payload: dict[str, Any], target_user_id: int | None = None) -> None:
        await self._ensure_listener()
        envelope = {
            "origin": self._instance_id,
            "room_id": room_public_id,
            "target_user_id": target_user_id,
            "payload": payload,
        }
        try:
            await self._redis.publish(f"funkey:room:{room_public_id}", json.dumps(envelope, default=str))
        except Exception:
            pass

    async def broadcast_room(self, room_public_id: str, payload: dict[str, Any]) -> None:
        event = self._decorate(payload)
        await self._deliver_local(room_public_id, event)
        await self._publish(room_public_id, event)

    async def send_room_user(self, room_public_id: str, user_id: int, payload: dict[str, Any]) -> None:
        event = self._decorate(payload)
        await self._deliver_local(room_public_id, event, user_id)
        await self._publish(room_public_id, event, user_id)


room_realtime_connections = RealtimeConnectionManager()
