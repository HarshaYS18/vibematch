from __future__ import annotations

from typing import Any

from sqlalchemy.orm import Session

from app.database import SessionLocal
from app.models.room_realtime_audit_log import RoomRealtimeAuditLog


class RoomRealtimeAuditService:
    """Writes durable PostgreSQL audit logs for realtime room state actions."""

    def log_event(
        self,
        *,
        room_id: str,
        event_type: str,
        actor_user_id: str | None,
        actor_name: str | None,
        request_id: str | None,
        payload: dict[str, Any],
        db: Session | None = None,
    ) -> None:
        owns_session = db is None
        session = db or SessionLocal()

        try:
            log = RoomRealtimeAuditLog(
                room_id=room_id,
                event_type=event_type,
                actor_user_id=actor_user_id,
                actor_name=actor_name,
                target_user_id=self._string_payload(payload, "target_user_id"),
                seat_index=self._int_payload(payload, "seat_index"),
                from_seat_index=self._int_payload(payload, "from_seat_index"),
                to_seat_index=self._int_payload(payload, "to_seat_index"),
                request_id=request_id,
                reason=self._string_payload(payload, "reason"),
                metadata_json={
                    "payload": payload,
                    "source": "room_websocket",
                },
            )
            session.add(log)
            session.commit()
        except Exception:
            session.rollback()
        finally:
            if owns_session:
                session.close()

    def _string_payload(self, payload: dict[str, Any], key: str) -> str | None:
        value = payload.get(key)
        if value is None:
            return None
        text = str(value).strip()
        return text or None

    def _int_payload(self, payload: dict[str, Any], key: str) -> int | None:
        value = payload.get(key)
        if value is None:
            return None
        if isinstance(value, int):
            return value
        try:
            return int(str(value))
        except (TypeError, ValueError):
            return None


room_realtime_audit_service = RoomRealtimeAuditService()
