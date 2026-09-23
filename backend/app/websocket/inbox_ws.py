from __future__ import annotations

import asyncio
import json
import time
from datetime import datetime
from typing import Any
from uuid import uuid4

from fastapi import WebSocket
from redis.asyncio import Redis
from starlette.websockets import WebSocketState

from app.core.config import settings
from app.core.redis_client import get_realtime_redis
from app.core.telemetry import current_trace_id, current_traceparent


_INBOX_CHANNEL = "funkey:realtime:inbox:events"
_GATEWAY_CHANNEL = "funkey:realtime:events"
_INBOX_LEASE_PREFIX = "funkey:realtime:inbox:leases"
_CLIENT_SEQUENCE_PREFIX = "funkey:realtime:app-sequence"
_SOCKET_LEASE_SECONDS = 30
_SOCKET_LEASE_REFRESH_SECONDS = 10
_REMOTE_EVENT_TTL_SECONDS = 5 * 60


class InboxWebSocketManager:
    """Distributed inbox socket registry with expiring per-device leases."""

    def __init__(self, redis_client: Any | None = None):
        self._connections: dict[int, set[WebSocket]] = {}
        self._staff_sockets: set[WebSocket] = set()
        self._client_user_ids: dict[WebSocket, int] = {}
        self._last_seen_at: dict[int, datetime] = {}
        self._client_connection_ids: dict[WebSocket, str] = {}
        self._lease_tasks: dict[WebSocket, asyncio.Task[None]] = {}
        self._instance_id = uuid4().hex
        self._redis: Any = redis_client or Redis.from_url(
            settings.realtime_redis_url,
            decode_responses=True,
            socket_connect_timeout=settings.REDIS_CONNECT_TIMEOUT_SECONDS,
            socket_timeout=settings.REDIS_SOCKET_TIMEOUT_SECONDS,
            health_check_interval=20,
            max_connections=settings.REALTIME_REDIS_MAX_CONNECTIONS,
            client_name="funkey-inbox-realtime",
        )
        self._listener_task: asyncio.Task[None] | None = None
        self._seen_remote_events: dict[str, float] = {}
        self._local_sequence_fallback: dict[str, int] = {}

    @staticmethod
    def _lease_key(user_id: int) -> str:
        return f"{_INBOX_LEASE_PREFIX}:{user_id}"

    @staticmethod
    def _is_connected(websocket: WebSocket) -> bool:
        return (
            websocket.client_state == WebSocketState.CONNECTED
            and websocket.application_state == WebSocketState.CONNECTED
        )

    async def _ensure_listener(self) -> None:
        if self._listener_task is not None and not self._listener_task.done():
            return
        self._listener_task = asyncio.create_task(self._listen())

    async def _listen(self) -> None:
        while True:
            pubsub = self._redis.pubsub(ignore_subscribe_messages=True)
            try:
                await pubsub.subscribe(_INBOX_CHANNEL)
                async for message in pubsub.listen():
                    raw = message.get("data")
                    if not isinstance(raw, str):
                        continue
                    try:
                        envelope = json.loads(raw)
                    except json.JSONDecodeError:
                        continue
                    if not isinstance(envelope, dict):
                        continue
                    if envelope.get("origin") == self._instance_id:
                        continue
                    if not self._accept_remote_event(envelope):
                        continue
                    await self._handle_envelope(envelope)
            except asyncio.CancelledError:
                raise
            except Exception:
                await asyncio.sleep(1)
            finally:
                try:
                    await pubsub.aclose()
                except Exception:
                    pass

    def _accept_remote_event(self, envelope: dict[str, Any]) -> bool:
        event_id = str(envelope.get("event_id") or "").strip()
        if not event_id:
            return True
        now = time.monotonic()
        for key, expires_at in list(self._seen_remote_events.items()):
            if expires_at <= now:
                self._seen_remote_events.pop(key, None)
        if event_id in self._seen_remote_events:
            return False
        self._seen_remote_events[event_id] = now + _REMOTE_EVENT_TTL_SECONDS
        return True

    async def shutdown(self) -> None:
        listener = self._listener_task
        self._listener_task = None
        if listener is not None and not listener.done():
            listener.cancel()
        tasks = [task for task in self._lease_tasks.values() if not task.done()]
        sockets = [
            (user_id, socket)
            for user_id, user_sockets in list(self._connections.items())
            for socket in list(user_sockets)
        ]
        for user_id, socket in sockets:
            await self.release_connection(user_id, socket)
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

    async def _handle_envelope(self, envelope: dict[str, Any]) -> None:
        payload = envelope.get("payload")
        if not isinstance(payload, dict):
            return

        scope = str(envelope.get("scope") or "")
        if scope == "user":
            try:
                user_id = int(envelope.get("user_id"))
            except (TypeError, ValueError):
                return
            await self._send_to_user_local(user_id, payload)
            return

        if scope == "users":
            raw_user_ids = envelope.get("user_ids")
            if not isinstance(raw_user_ids, list):
                return
            user_ids: list[int] = []
            for raw_user_id in raw_user_ids:
                try:
                    user_ids.append(int(raw_user_id))
                except (TypeError, ValueError):
                    continue
            await self._broadcast_to_users_local(user_ids, payload)
            return

        if scope == "staff":
            await self._broadcast_staff_local(payload)
            return

        if scope == "all":
            await self._broadcast_all_local(payload)

    async def _publish(
        self,
        scope: str,
        payload: dict,
        *,
        user_id: int | None = None,
        user_ids: list[int] | None = None,
    ) -> None:
        await self._ensure_listener()
        envelope: dict[str, Any] = {
            "event_id": uuid4().hex,
            "origin": self._instance_id,
            "scope": scope,
            "payload": payload,
        }
        if user_id is not None:
            envelope["user_id"] = int(user_id)
        if user_ids is not None:
            envelope["user_ids"] = [int(item) for item in user_ids]
        try:
            await self._redis.publish(
                _INBOX_CHANNEL,
                json.dumps(envelope, default=str),
            )
        except Exception:
            # Inbox data is durable in PostgreSQL. Reconnects recover through
            # the authoritative REST snapshot when transient fanout is lost.
            pass

        event_id = str(
            payload.get("eventId")
            or payload.get("event_id")
            or envelope["event_id"]
        )
        event_type = str(
            payload.get("type")
            or payload.get("event")
            or "inbox.event"
        ).strip() or "inbox.event"
        priority = (
            "best_effort"
            if event_type in {
                "inbox_typing_start",
                "inbox_typing_stop",
                "inbox_chat_activity",
                "inbox_presence_updated",
            }
            else "critical"
            if event_type == "session_replaced"
            else "normal"
        )
        gateway_envelope: dict[str, Any] = {
            "event_id": event_id,
            "eventId": event_id,
            "event_type": event_type,
            "type": event_type,
            "event_version": 2,
            "occurred_at": datetime.utcnow().isoformat(timespec="milliseconds") + "Z",
            "serverTime": payload.get("serverTime") or payload.get("server_time"),
            "trace_id": current_trace_id(),
            "traceparent": current_traceparent(),
            "scope": scope,
            "stream": payload.get("stream"),
            "sequence": int(payload.get("sequence") or 0),
            "priority": priority,
            "payload": payload,
        }
        if user_id is not None:
            gateway_envelope["user_id"] = int(user_id)
        if user_ids is not None:
            gateway_envelope["user_ids"] = [int(item) for item in user_ids]
        try:
            await self._redis.publish(
                _GATEWAY_CHANNEL,
                json.dumps(gateway_envelope, default=str),
            )
        except Exception:
            # Shadow transport failure must never fail the committed domain action.
            pass

    async def connect(
        self,
        user_id: int,
        websocket: WebSocket,
        is_staff: bool = False,
    ) -> bool:
        """Register one device and return True only for a global offline->online edge."""
        await self._ensure_listener()
        was_online = await self.has_user_connections(user_id)
        await websocket.accept()
        self._connections.setdefault(user_id, set()).add(websocket)
        self._client_user_ids[websocket] = user_id
        self._client_connection_ids[websocket] = uuid4().hex
        self._last_seen_at.pop(user_id, None)
        if is_staff:
            self._staff_sockets.add(websocket)
        await self.touch_connection(user_id, websocket)
        task = self._lease_tasks.get(websocket)
        if task is None or task.done():
            self._lease_tasks[websocket] = asyncio.create_task(
                self._refresh_connection_lease(user_id, websocket)
            )
        return not was_online

    async def _refresh_connection_lease(
        self,
        user_id: int,
        websocket: WebSocket,
    ) -> None:
        try:
            while (
                websocket in self._connections.get(user_id, set())
                and self._is_connected(websocket)
            ):
                await asyncio.sleep(_SOCKET_LEASE_REFRESH_SECONDS)
                if websocket not in self._connections.get(user_id, set()):
                    return
                await self.touch_connection(user_id, websocket)
        except asyncio.CancelledError:
            raise
        except Exception:
            return

    async def touch_connection(self, user_id: int, websocket: WebSocket) -> None:
        connection_id = self._client_connection_ids.get(websocket)
        if not connection_id:
            return
        now = time.time()
        expires_at = now + _SOCKET_LEASE_SECONDS
        try:
            pipe = self._redis.pipeline(transaction=False)
            pipe.zadd(self._lease_key(user_id), {connection_id: expires_at})
            pipe.zremrangebyscore(self._lease_key(user_id), "-inf", now)
            pipe.expire(self._lease_key(user_id), _SOCKET_LEASE_SECONDS * 3)
            await pipe.execute()
        except Exception:
            pass

    def _disconnect_local(self, user_id: int, websocket: WebSocket) -> None:
        task = self._lease_tasks.pop(websocket, None)
        if task is not None and not task.done():
            task.cancel()
        self._client_connection_ids.pop(websocket, None)
        self._client_user_ids.pop(websocket, None)
        self._staff_sockets.discard(websocket)

        sockets = self._connections.get(user_id)
        if not sockets:
            return
        sockets.discard(websocket)
        if not sockets:
            self._connections.pop(user_id, None)
            self._last_seen_at[user_id] = datetime.utcnow()

    async def release_connection(self, user_id: int, websocket: WebSocket) -> bool:
        """Release one device and return whether any local/remote device remains."""
        connection_id = self._client_connection_ids.get(websocket)
        if connection_id:
            try:
                await self._redis.zrem(self._lease_key(user_id), connection_id)
            except Exception:
                pass
        self._disconnect_local(user_id, websocket)
        return await self.has_user_connections(user_id, fail_open=True)

    async def disconnect_existing_user(
        self,
        user_id: int,
        reason: str = "session_replaced",
    ) -> None:
        """Explicitly close this instance's sessions without affecting other devices."""
        sockets = list(self._connections.get(user_id, set()))
        session_event = await self._canonical_client_event(
            user_id,
            {"event": "session_replaced", "reason": reason},
        )
        for socket in sockets:
            try:
                await socket.send_json(session_event)
            except Exception:
                pass
            try:
                await socket.close(code=4409)
            except Exception:
                pass
            await self.release_connection(user_id, socket)

    async def has_user_connections(
        self,
        user_id: int,
        *,
        fail_open: bool = False,
    ) -> bool:
        for socket in self._connections.get(user_id, set()):
            if self._is_connected(socket):
                return True

        now = time.time()
        try:
            pipe = self._redis.pipeline(transaction=False)
            pipe.zremrangebyscore(self._lease_key(user_id), "-inf", now)
            pipe.zcard(self._lease_key(user_id))
            _, count = await pipe.execute()
            return int(count or 0) > 0
        except Exception:
            # On disconnect, fail open so a Redis outage cannot make one API
            # replica incorrectly announce a remote device as offline.
            return fail_open

    @staticmethod
    def _is_client_envelope(payload: dict[str, Any]) -> bool:
        return (
            bool(payload.get("eventId") or payload.get("event_id"))
            and bool(payload.get("stream"))
            and isinstance(payload.get("sequence"), int)
        )

    async def _next_client_sequence(self, stream: str) -> int:
        key = f"{_CLIENT_SEQUENCE_PREFIX}:{stream}"
        try:
            return int(await self._redis.incr(key))
        except Exception:
            next_value = self._local_sequence_fallback.get(stream, 0) + 1
            self._local_sequence_fallback[stream] = next_value
            return next_value

    async def _canonical_client_event(
        self,
        user_id: int | None,
        payload: dict[str, Any],
        *,
        stream: str | None = None,
    ) -> dict[str, Any]:
        if self._is_client_envelope(payload):
            return payload

        resolved_stream = stream or (
            f"app:user:{int(user_id)}" if user_id is not None else "app:global"
        )
        event_type = str(
            payload.get("type")
            or payload.get("event")
            or "app.event"
        ).strip() or "app.event"
        sequence = await self._next_client_sequence(resolved_stream)
        event_id = uuid4().hex
        server_time = datetime.utcnow().isoformat(timespec="milliseconds") + "Z"
        nested_payload = payload.get("payload")
        if not isinstance(nested_payload, dict):
            nested_payload = dict(payload)

        # Preserve legacy top-level fields during migration while also exposing
        # the canonical envelope expected by the new frontend realtime client.
        return {
            **payload,
            "eventId": event_id,
            "event_id": event_id,
            "sequence": sequence,
            "stream": resolved_stream,
            "type": event_type,
            "serverTime": server_time,
            "server_time": server_time,
            "payload": nested_payload,
        }

    async def _send_to_user_local(self, user_id: int, payload: dict) -> None:
        outgoing = (
            payload
            if self._is_client_envelope(payload)
            else await self._canonical_client_event(user_id, payload)
        )
        sockets = list(self._connections.get(user_id, set()))
        for socket in sockets:
            try:
                await socket.send_json(outgoing)
            except Exception:
                await self.release_connection(user_id, socket)

    async def _broadcast_to_users_local(
        self,
        user_ids: list[int],
        payload: dict,
    ) -> None:
        for user_id in list(dict.fromkeys(user_ids)):
            await self._send_to_user_local(user_id, payload)

    async def _broadcast_staff_local(self, payload: dict) -> None:
        for socket in list(self._staff_sockets):
            user_id = self._client_user_ids.get(socket)
            if user_id is None:
                self._staff_sockets.discard(socket)
                continue
            try:
                await socket.send_json(payload)
            except Exception:
                await self.release_connection(user_id, socket)

    async def _broadcast_all_local(self, payload: dict) -> None:
        for user_id in list(self._connections.keys()):
            await self._send_to_user_local(user_id, payload)

    async def send_to_user(self, user_id: int, payload: dict) -> None:
        canonical = await self._canonical_client_event(user_id, payload)
        await self._send_to_user_local(user_id, canonical)
        await self._publish("user", canonical, user_id=user_id)

    async def broadcast_to_users(self, user_ids: list[int], payload: dict) -> None:
        resolved_user_ids = list(dict.fromkeys(int(item) for item in user_ids))
        for user_id in resolved_user_ids:
            canonical = await self._canonical_client_event(user_id, payload)
            await self._send_to_user_local(user_id, canonical)
            await self._publish("user", canonical, user_id=user_id)

    async def broadcast_all_staff(self, payload: dict) -> None:
        canonical = await self._canonical_client_event(
            None,
            payload,
            stream="app:staff",
        )
        await self._broadcast_staff_local(canonical)
        await self._publish("staff", canonical)

    async def broadcast_all_users(self, payload: dict) -> None:
        canonical = await self._canonical_client_event(
            None,
            payload,
            stream="app:global",
        )
        await self._broadcast_all_local(canonical)
        await self._publish("all", canonical)

    def is_user_online(self, user_id: int | None) -> bool:
        """Return app-online state from local legacy sockets or Go gateway leases."""
        if user_id is None:
            return False
        if any(
            self._is_connected(socket)
            for socket in self._connections.get(user_id, set())
        ):
            return True

        key = f"funkey:realtime:gateway:user-active:{int(user_id)}"
        try:
            now = time.time()
            redis_client = get_realtime_redis()
            pipe = redis_client.pipeline(transaction=False)
            pipe.zremrangebyscore(key, "-inf", now)
            pipe.zcard(key)
            _, count = pipe.execute()
            return int(count or 0) > 0
        except Exception:
            return False

    def last_seen_at(self, user_id: int | None) -> datetime | None:
        if user_id is None:
            return None
        return self._last_seen_at.get(user_id)


inbox_ws_manager = InboxWebSocketManager()
