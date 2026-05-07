from fastapi import WebSocket


class InboxWebSocketManager:
    def __init__(self):
        self._connections: dict[int, set[WebSocket]] = {}
        self._staff_user_ids: set[int] = set()

    async def connect(self, user_id: int, websocket: WebSocket, is_staff: bool = False) -> None:
        await websocket.accept()
        self._connections.setdefault(user_id, set()).add(websocket)
        if is_staff:
            self._staff_user_ids.add(user_id)

    def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        sockets = self._connections.get(user_id)
        if not sockets:
            self._staff_user_ids.discard(user_id)
            return
        sockets.discard(websocket)
        if not sockets:
            self._connections.pop(user_id, None)
            self._staff_user_ids.discard(user_id)

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


inbox_ws_manager = InboxWebSocketManager()
