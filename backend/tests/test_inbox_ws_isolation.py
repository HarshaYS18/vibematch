from unittest import IsolatedAsyncioTestCase
from unittest.mock import AsyncMock, Mock, call, patch

from fastapi import HTTPException

from app.api.routes import inbox_ws


class InboxWebSocketIsolationTests(IsolatedAsyncioTestCase):
    async def test_invalidated_session_closes_and_always_cleans_presence(self):
        websocket = Mock()
        websocket.query_params = {"token": "access-token"}
        websocket.close = AsyncMock()
        websocket.receive_json = AsyncMock(
            return_value={
                "event": "typing_start",
                "conversation_id": "conversation_1",
            }
        )
        socket_user = inbox_ws.InboxSocketUser(
            id=7,
            public_user_id=6418000000007,
            display_name="Test User",
            username="test-user",
            is_staff=False,
        )

        to_thread = AsyncMock(
            side_effect=[
                socket_user,
                HTTPException(status_code=403, detail="Inbox session is no longer valid"),
            ]
        )

        with (
            patch.object(inbox_ws.asyncio, "to_thread", to_thread),
            patch.object(inbox_ws.inbox_ws_manager, "connect", AsyncMock()) as connect,
            patch.object(inbox_ws.inbox_ws_manager, "disconnect", Mock()) as disconnect,
            patch.object(inbox_ws, "_broadcast_presence", AsyncMock()) as presence,
        ):
            await inbox_ws.inbox_websocket(websocket)

        self.assertEqual(to_thread.await_count, 2)
        connect.assert_awaited_once_with(7, websocket, is_staff=False)
        websocket.close.assert_awaited_once_with(code=4403)
        disconnect.assert_called_once_with(7, websocket)
        self.assertEqual(
            presence.await_args_list,
            [call(7, True), call(7, False)],
        )

    async def test_disconnect_also_cleans_presence_once(self):
        websocket = Mock()
        websocket.query_params = {"token": "access-token"}
        websocket.close = AsyncMock()
        websocket.receive_json = AsyncMock(side_effect=inbox_ws.WebSocketDisconnect())
        socket_user = inbox_ws.InboxSocketUser(
            id=9,
            public_user_id=6418000000009,
            display_name=None,
            username="user9",
            is_staff=True,
        )

        with (
            patch.object(inbox_ws.asyncio, "to_thread", AsyncMock(return_value=socket_user)),
            patch.object(inbox_ws.inbox_ws_manager, "connect", AsyncMock()),
            patch.object(inbox_ws.inbox_ws_manager, "disconnect", Mock()) as disconnect,
            patch.object(inbox_ws, "_broadcast_presence", AsyncMock()) as presence,
        ):
            await inbox_ws.inbox_websocket(websocket)

        disconnect.assert_called_once_with(9, websocket)
        self.assertEqual(
            presence.await_args_list,
            [call(9, True), call(9, False)],
        )


if __name__ == "__main__":
    import unittest

    unittest.main()
