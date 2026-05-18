from collections import defaultdict
from typing import Any

from fastapi import WebSocket
from starlette.websockets import WebSocketState


class RealtimeConnectionManager:
    """In-process WebSocket registry.

    State is not stored here. This only tracks currently connected sockets.
    Source-of-truth room state must stay in the database/services.
    """

    def __init__(self) -> None:
        self._room_clients: dict[str, set[WebSocket]] = defaultdict(set)
        self._client_rooms: dict[WebSocket, set[str]] = defaultdict(set)
        self._client_users: dict[WebSocket, int | None] = {}

    async def connect_room(self, room_public_id: str, websocket: WebSocket, user_id: int | None = None) -> None:
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
            self.disconnect(websocket)
            return False

    async def broadcast_room(self, room_public_id: str, payload: dict[str, Any]) -> None:
        clients = list(self._room_clients.get(room_public_id, set()))
        for client in clients:
            await self.send_json(client, payload)

    async def send_room_user(self, room_public_id: str, user_id: int, payload: dict[str, Any]) -> None:
        clients = list(self._room_clients.get(room_public_id, set()))
        for client in clients:
            if self._client_users.get(client) == user_id:
                await self.send_json(client, payload)


room_realtime_connections = RealtimeConnectionManager()
