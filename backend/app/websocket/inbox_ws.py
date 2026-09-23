from __future__ import annotations

import json
import time
from datetime import datetime
from typing import Any
from uuid import uuid4

from app.core.redis_client import get_async_realtime_redis, get_realtime_redis
from app.core.telemetry import current_trace_id, current_traceparent


_GATEWAY_CHANNEL = "funkey:realtime:events"
_CLIENT_SEQUENCE_PREFIX = "funkey:realtime:app-sequence"
_GATEWAY_USER_ACTIVE_PREFIX = "funkey:realtime:gateway:user-active"


class InboxWebSocketManager:
    """Compatibility publisher facade for the single Go application socket.

    Historical callers retain the inbox_ws_manager name, but this class no
    longer owns WebSocket connections, Pub/Sub listeners, or per-instance
    presence leases. All application delivery is published to the Go gateway.
    """

    def __init__(self, redis_client: Any | None = None):
        self._redis: Any = redis_client or get_async_realtime_redis()
        self._local_sequence_fallback: dict[str, int] = {}

    async def shutdown(self) -> None:
        # The shared realtime Redis client is closed by FastAPI lifespan.
        return None

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

    async def _publish(
        self,
        scope: str,
        payload: dict[str, Any],
        *,
        user_id: int | None = None,
        user_ids: list[int] | None = None,
    ) -> None:
        event_id = str(
            payload.get("eventId")
            or payload.get("event_id")
            or uuid4().hex
        )
        event_type = str(
            payload.get("type")
            or payload.get("event")
            or "inbox.event"
        ).strip() or "inbox.event"
        priority = (
            "best_effort"
            if event_type
            in {
                "inbox_typing_start",
                "inbox_typing_stop",
                "inbox_chat_activity",
                "inbox_presence_updated",
            }
            else "critical"
            if event_type == "session_replaced"
            else "normal"
        )
        envelope: dict[str, Any] = {
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
            envelope["user_id"] = int(user_id)
        if user_ids is not None:
            envelope["user_ids"] = [int(item) for item in user_ids]

        try:
            await self._redis.publish(
                _GATEWAY_CHANNEL,
                json.dumps(envelope, default=str, separators=(",", ":")),
            )
        except Exception:
            # Delivery is transient. Durable Inbox/wallet/social state remains
            # authoritative in PostgreSQL and reconnects recover through REST.
            pass

    async def send_to_user(self, user_id: int, payload: dict) -> None:
        canonical = await self._canonical_client_event(user_id, payload)
        await self._publish("user", canonical, user_id=user_id)

    async def broadcast_to_users(self, user_ids: list[int], payload: dict) -> None:
        for user_id in list(dict.fromkeys(int(item) for item in user_ids)):
            canonical = await self._canonical_client_event(user_id, payload)
            await self._publish("user", canonical, user_id=user_id)

    async def broadcast_all_staff(self, payload: dict) -> None:
        canonical = await self._canonical_client_event(
            None,
            payload,
            stream="app:staff",
        )
        await self._publish("staff", canonical)

    async def broadcast_all_users(self, payload: dict) -> None:
        canonical = await self._canonical_client_event(
            None,
            payload,
            stream="app:global",
        )
        await self._publish("all", canonical)

    async def disconnect_existing_user(
        self,
        user_id: int,
        reason: str = "session_replaced",
    ) -> None:
        await self.send_to_user(
            user_id,
            {"event": "session_replaced", "reason": reason},
        )

    async def has_user_connections(
        self,
        user_id: int,
        *,
        fail_open: bool = False,
    ) -> bool:
        key = f"{_GATEWAY_USER_ACTIVE_PREFIX}:{int(user_id)}"
        now = time.time()
        try:
            pipe = self._redis.pipeline(transaction=False)
            pipe.zremrangebyscore(key, "-inf", now)
            pipe.zcard(key)
            _, count = await pipe.execute()
            return int(count or 0) > 0
        except Exception:
            return fail_open

    def is_user_online(self, user_id: int | None) -> bool:
        if user_id is None:
            return False
        key = f"{_GATEWAY_USER_ACTIVE_PREFIX}:{int(user_id)}"
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
        # Durable last_seen_at is updated by the authoritative presence/control
        # path. The realtime publisher no longer maintains replica-local state.
        del user_id
        return None


inbox_ws_manager = InboxWebSocketManager()
