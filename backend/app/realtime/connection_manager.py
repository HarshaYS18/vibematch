from __future__ import annotations

import asyncio
import json
import time
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from fastapi import WebSocket
from redis.asyncio import Redis
from starlette.websockets import WebSocketState

from app.core.config import settings
from app.core.telemetry import current_trace_id, current_traceparent


_REDIS_PREFIX = "funkey:realtime:room"
_GLOBAL_ROOM_ID = "__global__"
_SOCKET_LEASE_SECONDS = 30
_SOCKET_LEASE_REFRESH_SECONDS = 10
_COMMAND_CLAIM_SECONDS = 5 * 60
_REMOTE_EVENT_TTL_SECONDS = 5 * 60
_ROOM_REPLAY_TTL_SECONDS = 5 * 60
_ROOM_REPLAY_MAX_EVENTS = 256
_ROOM_STREAM_TTL_SECONDS = 24 * 60 * 60
_GATEWAY_CHANNEL = "funkey:realtime:events"

_ROOM_STREAM_SEQUENCE_SCRIPT = """
local epoch = redis.call('GET', KEYS[1])
if not epoch then
    redis.call('SET', KEYS[1], ARGV[1], 'EX', ARGV[2], 'NX')
    epoch = redis.call('GET', KEYS[1])
end
local sequence = redis.call('INCR', KEYS[2])
redis.call('EXPIRE', KEYS[1], ARGV[2])
redis.call('EXPIRE', KEYS[2], ARGV[2])
return {epoch, sequence}
"""

_ROOM_REPLAY_APPEND_SCRIPT = """
redis.call('ZADD', KEYS[1], ARGV[1], ARGV[2])
local size = redis.call('ZCARD', KEYS[1])
local maximum = tonumber(ARGV[3])
if size > maximum then
    redis.call('ZREMRANGEBYRANK', KEYS[1], 0, size - maximum - 1)
end
redis.call('EXPIRE', KEYS[1], ARGV[4])
return size
"""


def room_user_lease_key(room_public_id: str, user_id: int) -> str:
    return f"{_REDIS_PREFIX}:leases:{room_public_id}:{user_id}"


def has_active_room_user_lease(
    redis_client: Any,
    room_public_id: str,
    user_id: int,
    *,
    now: float | None = None,
) -> bool:
    """Return whether FastAPI has an unexpired authenticated room socket lease.

    The lease is written only after a room websocket authenticates and joins
    the room. Media authorization can therefore use it as cross-worker proof
    of a live control-plane session when the durable participant flag is
    temporarily stale. Redis failure is fail-closed here; the DB participant
    record remains the normal authorization path.
    """
    safe_room_id = (room_public_id or "").strip()
    try:
        resolved_user_id = int(user_id)
    except (TypeError, ValueError):
        return False
    if not safe_room_id or resolved_user_id <= 0:
        return False
    try:
        current = time.time() if now is None else now
        count = redis_client.zcount(
            room_user_lease_key(safe_room_id, resolved_user_id),
            current,
            "+inf",
        )
        return int(count or 0) > 0
    except Exception:
        return False


def build_global_premium_gift_event(
    room_public_id: str,
    event: dict[str, Any],
) -> dict[str, Any] | None:
    body = event.get("payload")
    if not isinstance(body, dict):
        return None
    event_type = str(body.get("event_type") or body.get("type") or "")
    if event_type != "room_gift_sent":
        return None
    if not bool(body.get("show_premium_broadcast")):
        return None

    global_event = dict(event)
    global_body = dict(body)
    global_body["event_type"] = "global_gift_broadcast"
    global_body["type"] = "global_gift_broadcast"
    global_body["broadcast_scope"] = "global"
    global_body["source_room_id"] = room_public_id
    global_body["message"] = ""
    global_event["payload"] = global_body
    return global_event


class RealtimeConnectionManager:
    """Local socket registry backed by Redis for cross-worker delivery and leases."""

    def __init__(self) -> None:
        self._room_clients: dict[str, set[WebSocket]] = defaultdict(set)
        self._client_rooms: dict[WebSocket, set[str]] = defaultdict(set)
        self._client_users: dict[WebSocket, int | None] = {}
        self._client_connection_ids: dict[WebSocket, str] = {}
        self._lease_tasks: dict[WebSocket, asyncio.Task[None]] = {}
        self._room_versions: dict[str, int] = {}
        self._instance_id = uuid4().hex
        self._redis: Redis = Redis.from_url(
            settings.realtime_redis_url,
            decode_responses=True,
            socket_connect_timeout=settings.REDIS_CONNECT_TIMEOUT_SECONDS,
            socket_timeout=settings.REDIS_SOCKET_TIMEOUT_SECONDS,
            health_check_interval=20,
            max_connections=settings.REALTIME_REDIS_MAX_CONNECTIONS,
            client_name="funkey-fastapi-realtime",
        )
        self._listener_task: asyncio.Task[None] | None = None
        self._local_command_claims: dict[str, float] = {}
        self._seen_remote_events: dict[str, float] = {}

    async def _ensure_listener(self) -> None:
        if self._listener_task is not None and not self._listener_task.done():
            return
        self._listener_task = asyncio.create_task(self._listen())

    async def _listen(self) -> None:
        while True:
            pubsub = self._redis.pubsub(ignore_subscribe_messages=True)
            try:
                await pubsub.psubscribe(f"{_REDIS_PREFIX}:events:*")
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
                    payload = envelope.get("payload")
                    if not isinstance(payload, dict):
                        continue
                    if not self._accept_remote_event(envelope, payload):
                        continue
                    if envelope.get("scope") == "global":
                        await self._deliver_global_local(payload)
                        continue
                    room_id = str(envelope.get("room_id") or "")
                    if not room_id:
                        continue
                    target = envelope.get("target_user_id")
                    try:
                        target_user_id = int(target) if target is not None else None
                    except (TypeError, ValueError):
                        target_user_id = None
                    await self._deliver_local(room_id, payload, target_user_id)
            except asyncio.CancelledError:
                raise
            except Exception:
                await asyncio.sleep(1)
            finally:
                try:
                    await pubsub.aclose()
                except Exception:
                    pass

    def _accept_remote_event(
        self,
        envelope: dict[str, Any],
        payload: dict[str, Any],
    ) -> bool:
        event_id = str(payload.get("event_id") or "").strip()
        if not event_id:
            return True
        now = time.monotonic()
        for key, expires_at in list(self._seen_remote_events.items()):
            if expires_at <= now:
                self._seen_remote_events.pop(key, None)
        key = ":".join(
            [
                event_id,
                str(envelope.get("scope") or "room"),
                str(envelope.get("room_id") or ""),
                str(envelope.get("target_user_id") or ""),
            ]
        )
        if key in self._seen_remote_events:
            return False
        self._seen_remote_events[key] = now + _REMOTE_EVENT_TTL_SECONDS
        return True

    async def shutdown(self) -> None:
        listener = self._listener_task
        self._listener_task = None
        if listener is not None and not listener.done():
            listener.cancel()
        tasks = [task for task in self._lease_tasks.values() if not task.done()]
        sockets = list(self._client_rooms)
        for websocket in sockets:
            await self.release_connection(websocket)
        for task in tasks:
            task.cancel()
        if listener is not None:
            await asyncio.gather(listener, return_exceptions=True)
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
        close = getattr(self._redis, "aclose", None)
        if callable(close):
            result = close()
            if asyncio.iscoroutine(result):
                await result

    async def connect_room(
        self,
        room_public_id: str,
        websocket: WebSocket,
        user_id: int | None = None,
    ) -> None:
        await self._ensure_listener()
        self._room_clients[room_public_id].add(websocket)
        self._client_rooms[websocket].add(room_public_id)
        self._client_users[websocket] = user_id
        self._client_connection_ids.setdefault(websocket, uuid4().hex)
        await self.touch_connection(websocket)
        task = self._lease_tasks.get(websocket)
        if task is None or task.done():
            self._lease_tasks[websocket] = asyncio.create_task(
                self._refresh_connection_lease(websocket)
            )

    async def _refresh_connection_lease(self, websocket: WebSocket) -> None:
        try:
            while websocket in self._client_rooms and self._is_connected(websocket):
                await asyncio.sleep(_SOCKET_LEASE_REFRESH_SECONDS)
                if websocket not in self._client_rooms:
                    return
                await self.touch_connection(websocket)
        except asyncio.CancelledError:
            raise
        except Exception:
            return

    def disconnect(self, websocket: WebSocket) -> list[str]:
        task = self._lease_tasks.pop(websocket, None)
        if task is not None and not task.done():
            task.cancel()
        rooms = list(self._client_rooms.pop(websocket, set()))
        for room_public_id in rooms:
            sockets = self._room_clients.get(room_public_id)
            if sockets:
                sockets.discard(websocket)
                if not sockets:
                    self._room_clients.pop(room_public_id, None)
        self._client_users.pop(websocket, None)
        self._client_connection_ids.pop(websocket, None)
        return rooms

    async def release_connection(self, websocket: WebSocket) -> list[tuple[str, int]]:
        rooms = list(self._client_rooms.get(websocket, set()))
        user_id = self._client_users.get(websocket)
        connection_id = self._client_connection_ids.get(websocket)
        released: list[tuple[str, int]] = []
        if user_id is not None and connection_id:
            for room_id in rooms:
                released.append((room_id, user_id))
                try:
                    await self._redis.zrem(
                        self._lease_key(room_id, user_id),
                        connection_id,
                    )
                except Exception:
                    pass
        self.disconnect(websocket)
        return released

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

    async def _deliver_local(
        self,
        room_public_id: str,
        payload: dict[str, Any],
        target_user_id: int | None = None,
    ) -> None:
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

    async def _deliver_global_local(self, payload: dict[str, Any]) -> None:
        clients: set[WebSocket] = set()
        for room_clients in self._room_clients.values():
            clients.update(room_clients)
        for client in list(clients):
            await self.send_json(client, payload)

    def _decorate(self, payload: dict[str, Any]) -> dict[str, Any]:
        event = dict(payload)
        event.setdefault("event_id", uuid4().hex)
        event.setdefault("sent_at", datetime.now(timezone.utc).isoformat())
        return event

    @staticmethod
    def _room_stream_epoch_key(room_public_id: str) -> str:
        return f"{_REDIS_PREFIX}:stream-epoch:{room_public_id}"

    @staticmethod
    def _room_stream_sequence_key(room_public_id: str) -> str:
        return f"{_REDIS_PREFIX}:stream-sequence:{room_public_id}"

    @staticmethod
    def _room_replay_key(room_public_id: str, epoch: str) -> str:
        return f"{_REDIS_PREFIX}:replay:{room_public_id}:{epoch}"

    async def _decorate_room(
        self,
        room_public_id: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        event = self._decorate(payload)
        try:
            epoch, sequence = await self._redis.eval(
                _ROOM_STREAM_SEQUENCE_SCRIPT,
                2,
                self._room_stream_epoch_key(room_public_id),
                self._room_stream_sequence_key(room_public_id),
                uuid4().hex,
                _ROOM_STREAM_TTL_SECONDS,
            )
            resolved_epoch = str(epoch)
            resolved_sequence = int(sequence)
            stream = f"room:{room_public_id}:{resolved_epoch}"
            event.update(
                {
                    "eventId": event["event_id"],
                    "stream": stream,
                    "sequence": resolved_sequence,
                    "serverTime": event["sent_at"],
                }
            )
            body = event.get("payload")
            room = body.get("room") if isinstance(body, dict) else None
            if isinstance(room, dict):
                event["room_version"] = int(room.get("state_version") or 0)
                event["event_sequence"] = int(room.get("event_sequence") or 0)
            await self._redis.eval(
                _ROOM_REPLAY_APPEND_SCRIPT,
                1,
                self._room_replay_key(room_public_id, resolved_epoch),
                resolved_sequence,
                json.dumps(event, default=str, separators=(",", ":")),
                _ROOM_REPLAY_MAX_EVENTS,
                _ROOM_REPLAY_TTL_SECONDS,
            )
        except Exception:
            # The durable room action already committed. Local compatibility
            # delivery may continue, but sequenced clients must resync because
            # cross-instance replay is unavailable without Redis.
            event.update(
                {
                    "eventId": event["event_id"],
                    "stream": f"room:{room_public_id}:degraded:{self._instance_id}",
                    "sequence": 0,
                    "serverTime": event["sent_at"],
                    "resync_required": True,
                }
            )
        return event

    async def replay_room(
        self,
        websocket: WebSocket,
        room_public_id: str,
        *,
        stream: str,
        after_sequence: int,
    ) -> bool:
        """Replay one bounded contiguous room stream, otherwise require snapshot."""
        prefix = f"room:{room_public_id}:"
        if after_sequence < 0 or not stream.startswith(prefix):
            return False
        epoch = stream[len(prefix):]
        if not epoch or epoch.startswith("degraded:"):
            return False
        try:
            current_epoch, current_sequence = await self._redis.mget(
                self._room_stream_epoch_key(room_public_id),
                self._room_stream_sequence_key(room_public_id),
            )
            if str(current_epoch or "") != epoch:
                return False
            current = int(current_sequence or 0)
            if after_sequence >= current:
                return after_sequence == current
            raw_events = await self._redis.zrangebyscore(
                self._room_replay_key(room_public_id, epoch),
                f"({after_sequence}",
                "+inf",
            )
            if not raw_events:
                return False
            expected = after_sequence + 1
            events: list[dict[str, Any]] = []
            for raw in raw_events:
                decoded = json.loads(raw)
                if not isinstance(decoded, dict) or int(decoded.get("sequence") or 0) != expected:
                    return False
                events.append(decoded)
                expected += 1
            if expected - 1 != current:
                return False
            for event in events:
                if not await self.send_json(websocket, event):
                    return False
            return True
        except Exception:
            return False

    async def _publish(
        self,
        room_public_id: str,
        payload: dict[str, Any],
        target_user_id: int | None = None,
    ) -> None:
        await self._ensure_listener()
        envelope = {
            "origin": self._instance_id,
            "room_id": room_public_id,
            "target_user_id": target_user_id,
            "payload": payload,
        }
        try:
            await self._redis.publish(
                f"{_REDIS_PREFIX}:events:{room_public_id}",
                json.dumps(envelope, default=str),
            )
        except Exception:
            pass

    async def _publish_global(self, payload: dict[str, Any]) -> None:
        await self._ensure_listener()
        envelope = {
            "origin": self._instance_id,
            "scope": "global",
            "room_id": _GLOBAL_ROOM_ID,
            "payload": payload,
        }
        try:
            await self._redis.publish(
                f"{_REDIS_PREFIX}:events:{_GLOBAL_ROOM_ID}",
                json.dumps(envelope, default=str),
            )
        except Exception:
            pass

    async def _publish_gateway(
        self, payload: dict[str, Any], *, room_public_id: str | None = None,
        user_id: int | None = None,
    ) -> None:
        """Mirror committed transport events for Go gateway shadow traffic.

        Redis pub/sub is deliberately best effort; clients recover from the
        authoritative REST snapshot after reconnect. Durable domain events use
        the PostgreSQL outbox, not this transport channel.
        """
        event_id = str(payload.get("event_id") or uuid4().hex)
        envelope = {
            "event_id": event_id,
            "eventId": event_id,
            "event_type": "room.realtime",
            "type": str(payload.get("type") or "room.realtime"),
            "event_version": 2,
            "occurred_at": datetime.now(timezone.utc).isoformat(),
            "serverTime": payload.get("serverTime") or payload.get("sent_at"),
            "trace_id": current_trace_id(),
            "traceparent": current_traceparent(),
            "scope": "user" if user_id is not None else "room",
            "stream": payload.get("stream"),
            "sequence": int(payload.get("sequence") or 0),
            "room_version": int(payload.get("room_version") or 0),
            "event_sequence": int(payload.get("event_sequence") or 0),
            "resync_required": bool(payload.get("resync_required", False)),
            "payload": payload,
        }
        if user_id is not None:
            envelope["user_id"] = user_id
        else:
            envelope["room_public_id"] = room_public_id
        try:
            await self._redis.publish(_GATEWAY_CHANNEL, json.dumps(envelope, default=str))
        except Exception:
            pass

    async def broadcast_global(self, payload: dict[str, Any]) -> None:
        event = self._decorate(payload)
        await self._deliver_global_local(event)
        await self._publish_global(event)

    async def broadcast_room(self, room_public_id: str, payload: dict[str, Any]) -> None:
        event = await self._decorate_room(room_public_id, payload)
        await self._deliver_local(room_public_id, event)
        await self._publish(room_public_id, event)
        await self._publish_gateway(event, room_public_id=room_public_id)

        global_gift_event = build_global_premium_gift_event(room_public_id, event)
        if global_gift_event is not None:
            await self._deliver_global_local(global_gift_event)
            await self._publish_global(global_gift_event)

    async def send_room_user(
        self,
        room_public_id: str,
        user_id: int,
        payload: dict[str, Any],
    ) -> None:
        event = self._decorate(payload)
        await self._deliver_local(room_public_id, event, user_id)
        await self._publish(room_public_id, event, user_id)
        await self._publish_gateway(event, user_id=user_id)

    @staticmethod
    def _lease_key(room_public_id: str, user_id: int) -> str:
        return room_user_lease_key(room_public_id, user_id)

    async def touch_connection(self, websocket: WebSocket) -> None:
        user_id = self._client_users.get(websocket)
        connection_id = self._client_connection_ids.get(websocket)
        if user_id is None or not connection_id:
            return
        now = time.time()
        expires_at = now + _SOCKET_LEASE_SECONDS
        for room_id in self._client_rooms.get(websocket, set()):
            key = self._lease_key(room_id, user_id)
            try:
                pipe = self._redis.pipeline(transaction=False)
                pipe.zadd(key, {connection_id: expires_at})
                pipe.zremrangebyscore(key, "-inf", now)
                pipe.expire(key, _SOCKET_LEASE_SECONDS * 3)
                await pipe.execute()
            except Exception:
                pass

    async def has_room_user_connections(
        self,
        room_public_id: str,
        user_id: int,
    ) -> bool:
        for client in self._room_clients.get(room_public_id, set()):
            if self._client_users.get(client) == user_id and self._is_connected(client):
                return True
        key = self._lease_key(room_public_id, user_id)
        try:
            pipe = self._redis.pipeline(transaction=False)
            pipe.zremrangebyscore(key, "-inf", time.time())
            pipe.zcard(key)
            _, count = await pipe.execute()
            return int(count or 0) > 0
        except Exception:
            return True

    async def claim_command(
        self,
        room_public_id: str,
        user_id: int,
        command_id: str,
    ) -> bool:
        safe_id = command_id.strip()
        if not safe_id:
            return True
        key = f"{_REDIS_PREFIX}:commands:{room_public_id}:{user_id}:{safe_id}"
        try:
            return bool(
                await self._redis.set(
                    key,
                    self._instance_id,
                    ex=_COMMAND_CLAIM_SECONDS,
                    nx=True,
                )
            )
        except Exception:
            now = time.monotonic()
            for item, expires_at in list(self._local_command_claims.items()):
                if expires_at <= now:
                    self._local_command_claims.pop(item, None)
            if key in self._local_command_claims:
                return False
            self._local_command_claims[key] = now + _COMMAND_CLAIM_SECONDS
            return True

    async def release_command_claim(
        self,
        room_public_id: str,
        user_id: int,
        command_id: str,
    ) -> None:
        safe_id = command_id.strip()
        if not safe_id:
            return
        key = f"{_REDIS_PREFIX}:commands:{room_public_id}:{user_id}:{safe_id}"
        self._local_command_claims.pop(key, None)
        try:
            await self._redis.delete(key)
        except Exception:
            pass


room_realtime_connections = RealtimeConnectionManager()
