from fastapi import WebSocket


class WalletWebSocketManager:
    def __init__(self):
        self._connections: dict[int, set[WebSocket]] = {}

    async def connect(self, user_id: int, websocket: WebSocket) -> None:
        await websocket.accept()
        self._connections.setdefault(user_id, set()).add(websocket)

    def disconnect(self, user_id: int, websocket: WebSocket) -> None:
        sockets = self._connections.get(user_id)
        if not sockets:
            return
        sockets.discard(websocket)
        if not sockets:
            self._connections.pop(user_id, None)

    async def send_to_user(self, user_id: int, payload: dict) -> None:
        sockets = list(self._connections.get(user_id, set()))
        for socket in sockets:
            try:
                await socket.send_json(payload)
            except Exception:
                self.disconnect(user_id, socket)

    async def wallet_updated(self, user_id: int, payload: dict) -> None:
        await self.send_to_user(
            user_id,
            {
                "event": "wallet.updated",
                "payload": payload,
            },
        )


wallet_ws_manager = WalletWebSocketManager()
