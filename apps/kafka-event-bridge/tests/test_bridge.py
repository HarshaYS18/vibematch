import asyncio
import json
import unittest
from datetime import datetime, timezone
from uuid import uuid4

from bridge import process_message


class FakeMessage:
    def __init__(self, body: dict, subject: str = "funkey.events.room.joined"):
        self.data = json.dumps(body).encode()
        self.subject = subject
        self.acked = False
        self.naks = []

    async def ack(self):
        self.acked = True

    async def nak(self, delay=None):
        self.naks.append(delay)


class FakeJetStream:
    def __init__(self):
        self.published = []

    async def publish(self, subject, body, timeout=3):
        self.published.append((subject, body, timeout))


class FakeProducer:
    def __init__(self, fail=False):
        self.fail = fail
        self.records = []

    async def send_and_wait(self, topic, value, key=None, headers=None):
        if self.fail:
            raise RuntimeError("kafka unavailable")
        self.records.append((topic, value, key, headers))


def event(event_type="room.joined", payload=None):
    return {
        "event_id": str(uuid4()),
        "event_type": event_type,
        "event_version": 1,
        "occurred_at": datetime.now(timezone.utc).isoformat(),
        "request_id": "req-1",
        "trace_id": "trace-1",
        "traceparent": None,
        "actor_user_id": 10,
        "payload": payload or {"room_public_id": "R1"},
    }


class BridgeTests(unittest.IsolatedAsyncioTestCase):
    async def test_ack_only_after_kafka_ack(self):
        js = FakeJetStream()
        producer = FakeProducer()
        msg = FakeMessage(event())
        await process_message(js, producer, msg, nak_delay_seconds=1)
        self.assertTrue(msg.acked)
        self.assertEqual(msg.naks, [])
        self.assertEqual(producer.records[0][0], "funkey.room.events.v1")

    async def test_kafka_failure_naks_source(self):
        js = FakeJetStream()
        producer = FakeProducer(fail=True)
        msg = FakeMessage(event())
        await process_message(js, producer, msg, nak_delay_seconds=1)
        self.assertFalse(msg.acked)
        self.assertEqual(len(msg.naks), 1)

    async def test_unapproved_event_is_filtered(self):
        js = FakeJetStream()
        producer = FakeProducer()
        msg = FakeMessage(event("notification.requested", {"kind": "push"}))
        await process_message(js, producer, msg, nak_delay_seconds=1)
        self.assertTrue(msg.acked)
        self.assertEqual(producer.records, [])

    async def test_secret_payload_is_quarantined_before_ack(self):
        js = FakeJetStream()
        producer = FakeProducer()
        msg = FakeMessage(event("identity.login", {"access_token": "bad"}))
        await process_message(js, producer, msg, nak_delay_seconds=1)
        self.assertTrue(msg.acked)
        self.assertEqual(producer.records, [])
        self.assertEqual(js.published[0][0], "funkey.dlq.kafka_bridge.invalid")


if __name__ == "__main__":
    unittest.main()
