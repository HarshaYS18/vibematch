from datetime import datetime

from fastapi import WebSocket


class InboxWebSocketManager:
    def __init__(self):
        self._connections: dict[int, set[WebSocket]] = {}
        self._staff_user_ids: set[int] = set()
        self._last_seen_at: dict[int, datetime] = {}

    async def connect(self, user_id: int, websocket: WebSocket, is_staff: bool = False) -> None:
        await self.disconnect_existing_user(user_id, reason="inbox_session_replaced")
        await websocket.accept()
        self._connections.setdefault(user_id, set()).add(websocket)
        self._last_seen_at.pop(user_id, None)
        if is_staff:
            self._staff_user_ids.add(user_id)

    async def disconnect_existing_user(self, user_id: int, reason: str = "session_replaced") -> None:
        sockets = list(self._connections.get(user_id, set()))
        for socket in sockets:
            try:
                await socket.send_json({"event": "session_replaced", "reason": reason})
            except Exception:
                pass
            try:
                await socket.close(code=4409)
            except Exception:
                pass
            self.disconnect(user_id, socket)

    def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        sockets = self._connections.get(user_id)
        if not sockets:
            self._staff_user_ids.discard(user_id)
            return
        sockets.discard(websocket)
        if not sockets:
            self._connections.pop(user_id, None)
            self._staff_user_ids.discard(user_id)
            self._last_seen_at[user_id] = datetime.utcnow()

    async def send_to_user(self, user_id: int, payload: dict) -> None:
        sockets = list(self._connections.get(user_id, set()))
        for socket in sockets:
            try:
                await socket.send_json(payload)
            except Exception:
                self.disconnect(user_id, socket)

    async def broadcast_to_users(self, user_ids: list[int], payload: dict) -> None:
        for user_id in user_ids:
            await self.send_to_user(user_id, payload)

    async def broadcast_all_staff(self, payload: dict) -> None:
        await self.broadcast_to_users(list(self._staff_user_ids), payload)

    async def broadcast_all_users(self, payload: dict) -> None:
        await self.broadcast_to_users(list(self._connections.keys()), payload)

    def is_user_online(self, user_id: int | None) -> bool:
        if user_id is None:
            return False
        return bool(self._connections.get(user_id))

    def last_seen_at(self, user_id: int | None) -> datetime | None:
        if user_id is None:
            return None
        return self._last_seen_at.get(user_id)


inbox_ws_manager = InboxWebSocketManager()
