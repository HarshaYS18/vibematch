"""Best-effort realtime capability revocation signals.

Durable account/room state remains authoritative in PostgreSQL. These events
only make the Go transport react immediately instead of waiting for a fresh
capability mint.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from uuid import uuid4

from app.core.redis_client import get_realtime_redis
from app.core.telemetry import current_trace_id, current_traceparent


_GATEWAY_CHANNEL = "funkey:realtime:events"


def _publish(
    *,
    event_type: str,
    scope: str,
    payload: dict,
    user_id: int | None = None,
    room_public_id: str | None = None,
) -> None:
    event_id = uuid4().hex
    envelope = {
        "event_id": event_id,
        "eventId": event_id,
        "event_type": event_type,
        "type": event_type,
        "event_version": 2,
        "occurred_at": datetime.now(timezone.utc).isoformat(),
        "trace_id": current_trace_id(),
        "traceparent": current_traceparent(),
        "scope": scope,
        "priority": "critical",
        "payload": payload,
    }
    if user_id is not None:
        envelope["user_id"] = int(user_id)
    if room_public_id:
        envelope["room_public_id"] = room_public_id
    try:
        get_realtime_redis().publish(
            _GATEWAY_CHANNEL,
            json.dumps(envelope, default=str, separators=(",", ":")),
        )
    except Exception:
        # Revocation delivery is an acceleration path. The next capability
        # mint still rechecks authoritative account/room state.
        pass


def publish_session_revoked(
    user_id: int,
    *,
    reason: str,
    session_id: str | None = None,
    device_id: str | None = None,
) -> None:
    payload = {
        "reason": reason,
        "session_id": (session_id or "").strip(),
        "device_id": (device_id or "").strip(),
    }
    _publish(
        event_type="auth.session_revoked",
        scope="user",
        user_id=user_id,
        payload=payload,
    )


def publish_room_permission_revoked(
    room_public_id: str,
    *,
    reason: str,
    membership_version: int,
    user_id: int | None = None,
) -> None:
    room_id = room_public_id.strip()
    payload = {
        "room_public_id": room_id,
        "reason": reason,
        "membership_version": int(membership_version),
    }
    _publish(
        event_type="room.permission_revoked",
        scope="user" if user_id is not None else "room",
        user_id=user_id,
        room_public_id=None if user_id is not None else room_id,
        payload=payload,
    )
