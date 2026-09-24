import asyncio
from datetime import datetime, timezone
import unittest
from unittest.mock import patch
from uuid import uuid4

from apps.worker import main as worker_main
from apps.worker.events import EventEnvelope
from apps.worker.pools import get_pool


class _Metadata:
    def __init__(self, delivered: int):
        self.num_delivered = delivered


class _Message:
    def __init__(self, envelope: EventEnvelope, *, delivered: int = 1):
        self.data = envelope.model_dump_json().encode()
        self.subject = envelope.subject
        self.headers = {}
        self.metadata = _Metadata(delivered)
        self.acked = 0
        self.naks = []

    async def ack(self):
        self.acked += 1

    async def nak(self, *, delay):
        self.naks.append(delay)


class _JetStream:
    def __init__(self, *, fail_publish: bool = False):
        self.fail_publish = fail_publish
        self.published = []

    async def publish(self, subject, body, *, timeout):
        if self.fail_publish:
            raise RuntimeError("dlq unavailable")
        self.published.append((subject, body, timeout))
        return object()


def _event(event_type: str) -> EventEnvelope:
    return EventEnvelope(
        event_id=uuid4(),
        event_type=event_type,
        event_version=1,
        occurred_at=datetime.now(timezone.utc),
        payload={
            "recipient_user_id": 7,
            "notification_type": "test",
            "title": "Hello",
            "body": "Body",
        },
    )


class WorkerRuntimeBehaviorTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        worker_main.state.processed = 0
        worker_main.state.duplicates = 0
        worker_main.state.retries = 0
        worker_main.state.dead_lettered = 0
        worker_main.state.in_flight = 0

    async def test_unsupported_pool_event_is_durable_dlq_then_ack(self):
        envelope = _event("notification.requested")
        msg = _Message(envelope)
        js = _JetStream()
        with patch.object(worker_main, "POOL", get_pool("media")):
            await worker_main.process_message(js, msg, asyncio.Semaphore(1))
        self.assertEqual(msg.acked, 1)
        self.assertEqual(msg.naks, [])
        self.assertEqual(len(js.published), 1)
        self.assertEqual(js.published[0][0], "funkey.dlq.notification.requested")
        self.assertEqual(worker_main.state.dead_lettered, 1)

    async def test_transient_handler_failure_naks_without_ack(self):
        envelope = _event("notification.requested")
        msg = _Message(envelope, delivered=1)
        js = _JetStream()

        def fail(_envelope):
            raise RuntimeError("provider unavailable")

        handlers = dict(worker_main.HANDLERS)
        handlers["notification.requested"] = fail
        with (
            patch.object(worker_main, "POOL", get_pool("notification")),
            patch.object(worker_main, "HANDLERS", handlers),
            patch.object(worker_main.random, "random", return_value=0.0),
        ):
            await worker_main.process_message(js, msg, asyncio.Semaphore(1))
        self.assertEqual(msg.acked, 0)
        self.assertEqual(msg.naks, [2.0])
        self.assertEqual(js.published, [])
        self.assertEqual(worker_main.state.retries, 1)

    async def test_exhausted_failure_dead_letters_before_ack(self):
        envelope = _event("notification.requested")
        msg = _Message(envelope, delivered=worker_main.MAX_ATTEMPTS)
        js = _JetStream()

        def fail(_envelope):
            raise RuntimeError("provider unavailable")

        handlers = dict(worker_main.HANDLERS)
        handlers["notification.requested"] = fail
        with (
            patch.object(worker_main, "POOL", get_pool("notification")),
            patch.object(worker_main, "HANDLERS", handlers),
        ):
            await worker_main.process_message(js, msg, asyncio.Semaphore(1))
        self.assertEqual(len(js.published), 1)
        self.assertEqual(msg.acked, 1)
        self.assertEqual(msg.naks, [])

    async def test_dlq_publish_failure_never_acks_source(self):
        envelope = _event("notification.requested")
        msg = _Message(envelope, delivered=worker_main.MAX_ATTEMPTS)
        js = _JetStream(fail_publish=True)

        def fail(_envelope):
            raise RuntimeError("provider unavailable")

        handlers = dict(worker_main.HANDLERS)
        handlers["notification.requested"] = fail
        with (
            patch.object(worker_main, "POOL", get_pool("notification")),
            patch.object(worker_main, "HANDLERS", handlers),
        ):
            await worker_main.process_message(js, msg, asyncio.Semaphore(1))
        self.assertEqual(msg.acked, 0)
        self.assertEqual(msg.naks, [30])


if __name__ == "__main__":
    unittest.main()
