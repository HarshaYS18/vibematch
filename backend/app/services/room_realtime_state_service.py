from __future__ import annotations

from copy import deepcopy
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any


@dataclass
class RealtimeSeatUserState:
    user_id: str
    display_name: str
    self_muted: bool = False
    admin_muted: bool = False

    def to_payload(self) -> dict[str, Any]:
        return {
            "user_id": self.user_id,
            "display_name": self.display_name,
            "self_muted": self.self_muted,
            "admin_muted": self.admin_muted,
        }


@dataclass
class RealtimeSeatState:
    seat_index: int
    locked: bool = False
    user: RealtimeSeatUserState | None = None

    def to_payload(self) -> dict[str, Any]:
        return {
            "seat_index": self.seat_index,
            "locked": self.locked,
            "user": self.user.to_payload() if self.user else None,
        }


@dataclass
class RealtimeRoomState:
    room_id: str
    seats: dict[int, RealtimeSeatState] = field(default_factory=dict)
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))

    def touch(self) -> None:
        self.updated_at = datetime.now(timezone.utc)

    def to_payload(self) -> dict[str, Any]:
        return {
            "room_id": self.room_id,
            "seats": [seat.to_payload() for _, seat in sorted(self.seats.items())],
            "updated_at": self.updated_at.isoformat(),
        }


class RoomRealtimeStateService:
    """In-memory room state snapshot store for local/dev realtime.

    This keeps room seat/mic state consistent for late joiners while running a
    single backend process. Later this should move to Redis/PostgreSQL and be
    permission-checked through room services.
    """

    def __init__(self) -> None:
        self._rooms: dict[str, RealtimeRoomState] = {}

    def snapshot(self, room_id: str) -> dict[str, Any]:
        return deepcopy(self._room(room_id).to_payload())

    def apply_event(
        self,
        *,
        room_id: str,
        event_type: str,
        actor_user_id: str,
        actor_name: str,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        room = self._room(room_id)

        if event_type == "room.seat.occupy":
            self._occupy_seat(
                room=room,
                seat_index=self._int_payload(payload, "seat_index"),
                user_id=actor_user_id,
                display_name=actor_name,
            )
        elif event_type == "room.seat.leave":
            self._leave_seat(
                room=room,
                seat_index=self._int_payload(payload, "seat_index"),
            )
        elif event_type == "room.seat.switch":
            self._leave_seat(
                room=room,
                seat_index=self._int_payload(payload, "from_seat_index"),
            )
            self._occupy_seat(
                room=room,
                seat_index=self._int_payload(payload, "to_seat_index"),
                user_id=actor_user_id,
                display_name=actor_name,
            )
        elif event_type == "room.seat.lock":
            self._lock_seat(
                room=room,
                seat_index=self._int_payload(payload, "seat_index"),
            )
        elif event_type == "room.seat.unlock":
            self._unlock_seat(
                room=room,
                seat_index=self._int_payload(payload, "seat_index"),
            )
        elif event_type in {"room.mic.self_mute", "room.mic.self_unmute"}:
            self._set_self_mute(
                room=room,
                user_id=str(payload.get("target_user_id") or actor_user_id),
                display_name=actor_name,
                muted=bool(payload.get("muted", event_type.endswith("self_mute"))),
            )
        elif event_type in {"room.mic.admin_mute", "room.mic.admin_unmute"}:
            self._set_admin_mute(
                room=room,
                user_id=str(payload.get("target_user_id") or ""),
                muted=bool(payload.get("muted", event_type.endswith("admin_mute"))),
            )

        room.touch()
        return self.snapshot(room_id)

    def _room(self, room_id: str) -> RealtimeRoomState:
        if room_id not in self._rooms:
            self._rooms[room_id] = RealtimeRoomState(room_id=room_id)
        return self._rooms[room_id]

    def _seat(self, room: RealtimeRoomState, seat_index: int) -> RealtimeSeatState:
        if seat_index < 0:
            seat_index = 0
        if seat_index not in room.seats:
            room.seats[seat_index] = RealtimeSeatState(seat_index=seat_index)
        return room.seats[seat_index]

    def _occupy_seat(
        self,
        *,
        room: RealtimeRoomState,
        seat_index: int,
        user_id: str,
        display_name: str,
    ) -> None:
        for seat in room.seats.values():
            if seat.user and seat.user.user_id == user_id:
                seat.user = None

        seat = self._seat(room, seat_index)
        seat.locked = False
        seat.user = RealtimeSeatUserState(
            user_id=user_id,
            display_name=display_name,
        )

    def _leave_seat(self, *, room: RealtimeRoomState, seat_index: int) -> None:
        seat = self._seat(room, seat_index)
        seat.user = None

    def _lock_seat(self, *, room: RealtimeRoomState, seat_index: int) -> None:
        seat = self._seat(room, seat_index)
        seat.locked = True
        seat.user = None

    def _unlock_seat(self, *, room: RealtimeRoomState, seat_index: int) -> None:
        seat = self._seat(room, seat_index)
        seat.locked = False

    def _set_self_mute(
        self,
        *,
        room: RealtimeRoomState,
        user_id: str,
        display_name: str,
        muted: bool,
    ) -> None:
        user = self._find_or_create_user(room=room, user_id=user_id, display_name=display_name)
        user.self_muted = muted

    def _set_admin_mute(self, *, room: RealtimeRoomState, user_id: str, muted: bool) -> None:
        if not user_id:
            return
        for seat in room.seats.values():
            if seat.user and seat.user.user_id == user_id:
                seat.user.admin_muted = muted
                return

    def _find_or_create_user(
        self,
        *,
        room: RealtimeRoomState,
        user_id: str,
        display_name: str,
    ) -> RealtimeSeatUserState:
        for seat in room.seats.values():
            if seat.user and seat.user.user_id == user_id:
                return seat.user

        seat = self._seat(room, 0)
        if seat.user is None:
            seat.user = RealtimeSeatUserState(user_id=user_id, display_name=display_name)
            return seat.user

        return seat.user

    def _int_payload(self, payload: dict[str, Any], key: str) -> int:
        value = payload.get(key)
        if isinstance(value, int):
            return value
        try:
            return int(str(value))
        except (TypeError, ValueError):
            return -1


room_realtime_state_service = RoomRealtimeStateService()
