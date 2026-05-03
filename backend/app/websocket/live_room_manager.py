from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from fastapi import WebSocket


MAX_RECENT_EVENTS_PER_ROOM = 80
MAX_CONNECTIONS_PER_ROOM = 2000
MAX_SEATS_PER_ROOM = 30


@dataclass
class LiveRoomPeer:
    websocket: WebSocket
    user_id: int
    public_user_id: int
    display_name: str | None
    joined_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))
    last_seen_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


@dataclass
class LiveRoomRuntimeState:
    room_id: str
    peers: dict[int, LiveRoomPeer] = field(default_factory=dict)
    recent_events: deque[dict[str, Any]] = field(
        default_factory=lambda: deque(maxlen=MAX_RECENT_EVENTS_PER_ROOM),
    )
    seats: dict[int, dict[str, Any]] = field(default_factory=dict)
    updated_at: datetime = field(default_factory=lambda: datetime.now(timezone.utc))


class LiveRoomConnectionManager:
    """In-memory live-room realtime manager.

    This is intentionally lightweight for small-beta performance:
    - one WebSocket per active client
    - one in-memory room state map
    - bounded recent event buffer
    - broadcast fanout only to the target room

    Production scaling note: once more than one backend instance is used, fanout
    should move to Redis Pub/Sub or a dedicated realtime gateway.
    """

    def __init__(self) -> None:
        self._rooms: dict[str, LiveRoomRuntimeState] = {}
        self._user_room_index: dict[int, set[str]] = defaultdict(set)

    async def connect(
        self,
        *,
        websocket: WebSocket,
        room_id: str,
        user_id: int,
        public_user_id: int,
        display_name: str | None,
    ) -> LiveRoomRuntimeState:
        room = self._rooms.setdefault(room_id, LiveRoomRuntimeState(room_id=room_id))
        if len(room.peers) >= MAX_CONNECTIONS_PER_ROOM:
            await websocket.close(code=1013, reason="room is at realtime capacity")
            raise RuntimeError("room is at realtime capacity")

        await websocket.accept()

        previous_peer = room.peers.get(user_id)
        if previous_peer is not None:
            try:
                await previous_peer.websocket.close(code=4001, reason="replaced by newer connection")
            except Exception:
                pass

        peer = LiveRoomPeer(
            websocket=websocket,
            user_id=user_id,
            public_user_id=public_user_id,
            display_name=display_name,
        )
        room.peers[user_id] = peer
        room.updated_at = datetime.now(timezone.utc)
        self._user_room_index[user_id].add(room_id)
        return room

    def disconnect(self, *, room_id: str, user_id: int) -> bool:
        room = self._rooms.get(room_id)
        if room is None:
            return False

        existed = room.peers.pop(user_id, None) is not None
        self._user_room_index[user_id].discard(room_id)
        if not self._user_room_index[user_id]:
            self._user_room_index.pop(user_id, None)

        for seat_no, seat in list(room.seats.items()):
            if seat.get("user_id") == user_id:
                room.seats.pop(seat_no, None)

        if not room.peers:
            self._rooms.pop(room_id, None)
        else:
            room.updated_at = datetime.now(timezone.utc)

        return existed

    async def send_snapshot(self, *, room_id: str, websocket: WebSocket) -> None:
        room = self._rooms.get(room_id)
        if room is None:
            await websocket.send_json({"type": "room/snapshot", "room_id": room_id, "online_count": 0, "users": [], "seats": []})
            return

        await websocket.send_json(
            {
                "type": "room/snapshot",
                "room_id": room_id,
                "online_count": len(room.peers),
                "users": [self._peer_payload(peer) for peer in room.peers.values()],
                "seats": self.seat_snapshot(room_id),
                "recent_events": list(room.recent_events),
                "server_time": datetime.now(timezone.utc).isoformat(),
            },
        )

    async def broadcast(
        self,
        *,
        room_id: str,
        event: dict[str, Any],
        exclude_user_id: int | None = None,
        persist: bool = True,
    ) -> None:
        room = self._rooms.get(room_id)
        if room is None:
            return

        payload = {
            "room_id": room_id,
            "server_time": datetime.now(timezone.utc).isoformat(),
            **event,
        }
        if persist:
            room.recent_events.append(payload)

        disconnected: list[int] = []
        for user_id, peer in list(room.peers.items()):
            if exclude_user_id is not None and user_id == exclude_user_id:
                continue
            try:
                await peer.websocket.send_json(payload)
            except Exception:
                disconnected.append(user_id)

        for user_id in disconnected:
            self.disconnect(room_id=room_id, user_id=user_id)

    async def broadcast_presence(self, *, room_id: str) -> None:
        room = self._rooms.get(room_id)
        if room is None:
            return

        await self.broadcast(
            room_id=room_id,
            event={
                "type": "room/presence",
                "online_count": len(room.peers),
                "users": [self._peer_payload(peer) for peer in room.peers.values()],
                "seats": self.seat_snapshot(room_id),
            },
            persist=False,
        )

    async def accept_action(
        self,
        *,
        websocket: WebSocket,
        room_id: str,
        request_id: str | None,
        action: str,
        payload: dict[str, Any] | None = None,
    ) -> None:
        await websocket.send_json(
            {
                "type": "room/action_result",
                "ok": True,
                "request_id": request_id,
                "action": action,
                "payload": payload or {},
                "server_time": datetime.now(timezone.utc).isoformat(),
            },
        )

    async def reject_action(
        self,
        *,
        websocket: WebSocket,
        request_id: str | None,
        action: str,
        message: str,
    ) -> None:
        await websocket.send_json(
            {
                "type": "room/action_result",
                "ok": False,
                "request_id": request_id,
                "action": action,
                "message": message,
                "server_time": datetime.now(timezone.utc).isoformat(),
            },
        )

    def take_seat(
        self,
        *,
        room_id: str,
        user: Any,
        seat_no: int,
    ) -> dict[str, Any]:
        room = self._rooms.get(room_id)
        if room is None:
            raise ValueError("room not found")
        if seat_no < 1 or seat_no > MAX_SEATS_PER_ROOM:
            raise ValueError("invalid seat number")

        existing = room.seats.get(seat_no)
        if existing is not None and existing.get("user_id") != user.id:
            raise ValueError("seat already occupied")
        if existing is not None and existing.get("locked") is True:
            raise ValueError("seat is locked")

        for old_seat_no, old_seat in list(room.seats.items()):
            if old_seat.get("user_id") == user.id and old_seat_no != seat_no:
                room.seats.pop(old_seat_no, None)

        seat = {
            "seat_no": seat_no,
            "seat_index": seat_no - 1,
            "user_id": user.id,
            "public_user_id": user.public_user_id,
            "display_name": user.display_name or user.username or f"User {user.public_user_id}",
            "self_muted": False,
            "admin_muted": False,
            "locked": False,
        }
        room.seats[seat_no] = seat
        room.updated_at = datetime.now(timezone.utc)
        return seat

    def leave_seat(self, *, room_id: str, user_id: int, seat_no: int | None = None) -> dict[str, Any] | None:
        room = self._rooms.get(room_id)
        if room is None:
            raise ValueError("room not found")

        removed: dict[str, Any] | None = None
        for existing_seat_no, seat in list(room.seats.items()):
            if seat_no is not None and existing_seat_no != seat_no:
                continue
            if seat.get("user_id") == user_id:
                removed = room.seats.pop(existing_seat_no, None)
                break

        room.updated_at = datetime.now(timezone.utc)
        return removed

    def set_mute_state(
        self,
        *,
        room_id: str,
        user_id: int,
        seat_no: int,
        muted: bool,
        admin_muted: bool,
    ) -> dict[str, Any]:
        room = self._rooms.get(room_id)
        if room is None:
            raise ValueError("room not found")
        seat = room.seats.get(seat_no)
        if seat is None:
            raise ValueError("seat not occupied")
        if seat.get("user_id") != user_id:
            raise ValueError("cannot update another user seat mute state")

        seat["self_muted"] = bool(muted)
        seat["admin_muted"] = bool(admin_muted)
        room.updated_at = datetime.now(timezone.utc)
        return seat

    def seat_snapshot(self, room_id: str) -> list[dict[str, Any]]:
        room = self._rooms.get(room_id)
        if room is None:
            return []
        return [room.seats[key] for key in sorted(room.seats.keys())]

    def stats(self) -> dict[str, Any]:
        return {
            "room_count": len(self._rooms),
            "connection_count": sum(len(room.peers) for room in self._rooms.values()),
            "rooms": [
                {
                    "room_id": room.room_id,
                    "online_count": len(room.peers),
                    "seat_count": len(room.seats),
                    "recent_event_count": len(room.recent_events),
                    "updated_at": room.updated_at.isoformat(),
                }
                for room in self._rooms.values()
            ],
        }

    def _peer_payload(self, peer: LiveRoomPeer) -> dict[str, Any]:
        return {
            "user_id": peer.user_id,
            "public_user_id": peer.public_user_id,
            "display_name": peer.display_name,
            "joined_at": peer.joined_at.isoformat(),
        }


live_room_manager = LiveRoomConnectionManager()
