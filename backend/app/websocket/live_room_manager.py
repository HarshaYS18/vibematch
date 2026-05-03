from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any

from fastapi import WebSocket


MAX_RECENT_EVENTS_PER_ROOM = 80
MAX_CONNECTIONS_PER_ROOM = 2000


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

        if not room.peers:
            self._rooms.pop(room_id, None)
        else:
            room.updated_at = datetime.now(timezone.utc)

        return existed

    async def send_snapshot(self, *, room_id: str, websocket: WebSocket) -> None:
        room = self._rooms.get(room_id)
        if room is None:
            await websocket.send_json({"type": "room/snapshot", "room_id": room_id, "online_count": 0, "users": []})
            return

        await websocket.send_json(
            {
                "type": "room/snapshot",
                "room_id": room_id,
                "online_count": len(room.peers),
                "users": [self._peer_payload(peer) for peer in room.peers.values()],
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
            },
            persist=False,
        )

    def stats(self) -> dict[str, Any]:
        return {
            "room_count": len(self._rooms),
            "connection_count": sum(len(room.peers) for room in self._rooms.values()),
            "rooms": [
                {
                    "room_id": room.room_id,
                    "online_count": len(room.peers),
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
