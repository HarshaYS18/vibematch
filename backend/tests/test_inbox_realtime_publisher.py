import json
import unittest

from app.websocket.inbox_ws import InboxWebSocketManager


class _FakePipeline:
    def __init__(self, redis):
        self.redis = redis
        self.ops = []

    def zremrangebyscore(self, key, minimum, maximum):
        self.ops.append(("zremrangebyscore", key, minimum, maximum))
        return self

    def zcard(self, key):
        self.ops.append(("zcard", key))
        return self

    async def execute(self):
        return [0, self.redis.connection_count]


class _FakeRedis:
    def __init__(self):
        self.values = {}
        self.published = []
        self.connection_count = 0

    async def incr(self, key):
        self.values[key] = self.values.get(key, 0) + 1
        return self.values[key]

    async def publish(self, channel, payload):
        self.published.append((channel, payload))
        return 1

    def pipeline(self, transaction=False):
        del transaction
        return _FakePipeline(self)


class InboxRealtimePublisherTests(unittest.IsolatedAsyncioTestCase):
    async def test_user_event_publishes_only_to_go_gateway_channel(self):
        redis = _FakeRedis()
        manager = InboxWebSocketManager(redis_client=redis)

        await manager.send_to_user(
            42,
            {
                "event": "inbox_message_created",
                "conversation_id": "conversation-1",
            },
        )

        self.assertEqual(1, len(redis.published))
        channel, raw = redis.published[0]
        self.assertEqual("funkey:realtime:events", channel)
        envelope = json.loads(raw)
        self.assertEqual("user", envelope["scope"])
        self.assertEqual(42, envelope["user_id"])
        self.assertEqual("inbox_message_created", envelope["event_type"])
        self.assertEqual("normal", envelope["priority"])
        self.assertEqual("app:user:42", envelope["stream"])
        self.assertEqual(1, envelope["sequence"])
        self.assertEqual(
            "conversation-1",
            envelope["payload"]["conversation_id"],
        )

    async def test_best_effort_and_critical_priorities_are_preserved(self):
        redis = _FakeRedis()
        manager = InboxWebSocketManager(redis_client=redis)

        await manager.send_to_user(
            7,
            {"event": "inbox_typing_start", "conversation_id": "c1"},
        )
        await manager.disconnect_existing_user(7, reason="login_replaced")

        typing = json.loads(redis.published[0][1])
        session = json.loads(redis.published[1][1])
        self.assertEqual("best_effort", typing["priority"])
        self.assertEqual("critical", session["priority"])
        self.assertEqual("session_replaced", session["event_type"])

    async def test_user_presence_reads_go_gateway_active_lease(self):
        redis = _FakeRedis()
        redis.connection_count = 2
        manager = InboxWebSocketManager(redis_client=redis)

        self.assertTrue(await manager.has_user_connections(99))
        redis.connection_count = 0
        self.assertFalse(await manager.has_user_connections(99))


if __name__ == "__main__":
    unittest.main()
