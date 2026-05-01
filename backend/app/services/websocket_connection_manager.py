from __future__ import annotations

import json
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone

from fastapi import WebSocket
from starlette.websockets import WebSocketState


@dataclass(frozen=True)
class RoomSocketConnection:
    connection_id: str
    room_id: str
    user_id: str
    display_name: str
    connected_at: datetime


class WebSocketConnectionManager:
    """In-memory WebSocket manager for local/dev room realtime.

    This is intentionally simple for Step 1. It works for one backend process.
    Later, for multiple backend workers/nodes, replace the broadcast internals
    with Redis Pub/Sub while keeping the public service methods stable.
    """

    def __init__(self) -> None:
        self._room_connections: dict[str, dict[WebSocket, RoomSocketConnection]] = defaultdict(dict)
        self._connection_rooms: dict[WebSocket, str] = {}

    async def connect(
        self,
        *,
        websocket: WebSocket,
        room_id: str,
        user_id: str,
        display_name: str,
    ) -> RoomSocketConnection:
        await websocket.accept()

        connection = RoomSocketConnection(
            connection_id=f"ws_{datetime.now(timezone.utc).timestamp()}_{id(websocket)}",
            room_id=room_id,
            user_id=user_id,
            display_name=display_name,
            connected_at=datetime.now(timezone.utc),
        )

        self._room_connections[room_id][websocket] = connection
        self._connection_rooms[websocket] = room_id
        return connection

    async def disconnect(self, websocket: WebSocket) -> RoomSocketConnection | None:
        room_id = self._connection_rooms.pop(websocket, None)
        if room_id is None:
            return None

        connection = self._room_connections[room_id].pop(websocket, None)
        if not self._room_connections[room_id]:
            self._room_connections.pop(room_id, None)

        return connection

    async def send_json(self, websocket: WebSocket, data: dict) -> None:
        if websocket.client_state != WebSocketState.CONNECTED:
            return
        await websocket.send_text(json.dumps(data, default=str))

    async def broadcast_to_room(
        self,
        *,
        room_id: str,
        data: dict,
        exclude: WebSocket | None = None,
    ) -> None:
        connections = list(self._room_connections.get(room_id, {}).keys())
        stale_connections: list[WebSocket] = []

        for websocket in connections:
            if exclude is not None and websocket is exclude:
                continue

            try:
                await self.send_json(websocket, data)
            except Exception:
                stale_connections.append(websocket)

        for websocket in stale_connections:
            await self.disconnect(websocket)

    def room_connection_count(self, room_id: str) -> int:
        return len(self._room_connections.get(room_id, {}))

    def room_online_user_count(self, room_id: str) -> int:
        connections = self._room_connections.get(room_id, {})
        return len({connection.user_id for connection in connections.values()})

    def room_presence_payload(self, room_id: str) -> dict:
        return {
            "room_id": room_id,
            "online_count": self.room_online_user_count(room_id),
            "connection_count": self.room_connection_count(room_id),
        }


websocket_manager = WebSocketConnectionManager()
