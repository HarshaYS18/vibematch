import unittest

from app.websocket.inbox_ws import InboxWebSocketManager


class _FakeRedis:
    def __init__(self):
        self.values = {}

    async def incr(self, key):
        self.values[key] = self.values.get(key, 0) + 1
        return self.values[key]


class InboxRealtimeEnvelopeTests(unittest.IsolatedAsyncioTestCase):
    async def test_client_events_are_sequenced_per_stream(self):
        manager = InboxWebSocketManager(redis_client=_FakeRedis())

        first = await manager._canonical_client_event(
            42,
            {"event": "inbox_message_created", "conversation_id": "abc"},
        )
        second = await manager._canonical_client_event(
            42,
            {"event": "inbox_message_updated", "conversation_id": "abc"},
        )

        self.assertEqual("app:user:42", first["stream"])
        self.assertEqual(1, first["sequence"])
        self.assertEqual(2, second["sequence"])
        self.assertEqual("inbox_message_created", first["type"])
        self.assertTrue(first["eventId"])
        self.assertTrue(first["serverTime"])
        self.assertEqual("abc", first["payload"]["conversation_id"])

    async def test_global_events_use_one_global_sequence(self):
        manager = InboxWebSocketManager(redis_client=_FakeRedis())

        event = await manager._canonical_client_event(
            None,
            {"event": "inbox_presence_updated", "user_id": 7},
            stream="app:global",
        )

        self.assertEqual("app:global", event["stream"])
        self.assertEqual(1, event["sequence"])
