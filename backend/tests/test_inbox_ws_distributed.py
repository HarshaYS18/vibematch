import asyncio
import json
import time
from unittest import IsolatedAsyncioTestCase
from unittest.mock import AsyncMock, Mock

from starlette.websockets import WebSocketState

from app.websocket.inbox_ws import InboxWebSocketManager


class FakePipeline:
    def __init__(self, redis):
        self.redis = redis
        self.operations = []

    def zadd(self, key, values):
        self.operations.append(("zadd", key, values))
        return self

    def zremrangebyscore(self, key, minimum, maximum):
        self.operations.append(("zremrangebyscore", key, minimum, maximum))
        return self

    def expire(self, key, seconds):
        self.operations.append(("expire", key, seconds))
        return self

    def zcard(self, key):
        self.operations.append(("zcard", key))
        return self

    async def execute(self):
        results = []
        for operation in self.operations:
            name = operation[0]
            if name == "zadd":
                _, key, values = operation
                bucket = self.redis.scores.setdefault(key, {})
                bucket.update(values)
                results.append(len(values))
            elif name == "zremrangebyscore":
                _, key, _, maximum = operation
                bucket = self.redis.scores.setdefault(key, {})
                cutoff = float(maximum)
                removed = [
                    member
                    for member, score in bucket.items()
                    if float(score) <= cutoff
                ]
                for member in removed:
                    bucket.pop(member, None)
                results.append(len(removed))
            elif name == "expire":
                results.append(True)
            elif name == "zcard":
                _, key = operation
                results.append(len(self.redis.scores.get(key, {})))
        return results


class FakeRedis:
    def __init__(self):
        self.scores = {}
        self.published = []

    def pipeline(self, transaction=False):
        del transaction
        return FakePipeline(self)

    async def zrem(self, key, member):
        bucket = self.scores.setdefault(key, {})
        existed = member in bucket
        bucket.pop(member, None)
        return int(existed)

    async def publish(self, channel, payload):
        self.published.append((channel, payload))
        return 1


def websocket_mock():
    websocket = Mock()
    websocket.client_state = WebSocketState.CONNECTED
    websocket.application_state = WebSocketState.CONNECTED
    websocket.accept = AsyncMock()
    websocket.send_json = AsyncMock()
    websocket.close = AsyncMock()
    return websocket


class InboxWebSocketDistributedTests(IsolatedAsyncioTestCase):
    def manager(self, redis):
        manager = InboxWebSocketManager(redis_client=redis)
        manager._ensure_listener = AsyncMock()
        return manager

    async def test_multiple_devices_share_one_user_presence_lease_set(self):
        redis = FakeRedis()
        manager = self.manager(redis)
        first = websocket_mock()
        second = websocket_mock()

        self.assertTrue(await manager.connect(7, first))
        self.assertFalse(await manager.connect(7, second))
        first.close.assert_not_awaited()

        self.assertTrue(await manager.release_connection(7, first))
        self.assertFalse(await manager.release_connection(7, second))
        await asyncio.sleep(0)

    async def test_remote_user_event_is_delivered_without_republishing(self):
        redis = FakeRedis()
        publisher = self.manager(redis)
        subscriber = self.manager(redis)
        websocket = websocket_mock()
        await subscriber.connect(11, websocket)
        redis.published.clear()

        payload = {"event": "inbox_message_created", "conversation_id": "c1"}
        await publisher.send_to_user(11, payload)

        self.assertEqual(len(redis.published), 1)
        _, raw = redis.published[0]
        envelope = json.loads(raw)
        self.assertEqual(envelope["scope"], "user")
        self.assertEqual(envelope["user_id"], 11)

        await subscriber._handle_envelope(envelope)
        websocket.send_json.assert_awaited_once_with(payload)
        self.assertEqual(len(redis.published), 1)

        await subscriber.release_connection(11, websocket)
        await asyncio.sleep(0)

    async def test_remote_staff_event_only_reaches_staff_sockets(self):
        redis = FakeRedis()
        manager = self.manager(redis)
        staff_socket = websocket_mock()
        user_socket = websocket_mock()
        await manager.connect(21, staff_socket, is_staff=True)
        await manager.connect(22, user_socket, is_staff=False)
        staff_socket.send_json.reset_mock()
        user_socket.send_json.reset_mock()

        payload = {"event": "inbox_report_task_updated"}
        await manager._handle_envelope({"scope": "staff", "payload": payload})

        staff_socket.send_json.assert_awaited_once_with(payload)
        user_socket.send_json.assert_not_awaited()

        await manager.release_connection(21, staff_socket)
        await manager.release_connection(22, user_socket)
        await asyncio.sleep(0)

    async def test_expired_instance_lease_is_removed_during_presence_check(self):
        redis = FakeRedis()
        manager = self.manager(redis)
        key = manager._lease_key(33)
        redis.scores[key] = {"crashed-instance-socket": time.time() - 1}

        self.assertFalse(await manager.has_user_connections(33))
        self.assertEqual(redis.scores[key], {})


if __name__ == "__main__":
    import unittest

    unittest.main()
