import unittest
from datetime import datetime, timezone
from uuid import uuid4

from projector import process_message


class FakeMessage:
    def __init__(self, body: bytes):
        self.data = body
        self.acked = False
        self.naks = []
        self.termed = False

    async def ack(self):
        self.acked = True

    async def nak(self, delay=None):
        self.naks.append(delay)

    async def term(self):
        self.termed = True


class FakeStore:
    def __init__(self, fail=False):
        self.fail = fail
        self.docs = []

    async def apply(self, document):
        if self.fail:
            raise RuntimeError("opensearch unavailable")
        self.docs.append(document)


class ProjectorTests(unittest.IsolatedAsyncioTestCase):
    def event(self):
        import json
        return json.dumps({
            "event_id": str(uuid4()),
            "event_type": "room.updated",
            "event_version": 1,
            "occurred_at": datetime.now(timezone.utc).isoformat(),
            "payload": {
                "search_projection": {
                    "kind": "room",
                    "public_id": "R1",
                    "title": "Music",
                    "updated_at": datetime.now(timezone.utc).isoformat(),
                }
            },
        }).encode()

    async def test_ack_after_projection_write(self):
        msg = FakeMessage(self.event())
        store = FakeStore()
        await process_message(store, msg)
        self.assertTrue(msg.acked)
        self.assertEqual(len(store.docs), 1)

    async def test_projection_failure_naks(self):
        msg = FakeMessage(self.event())
        await process_message(FakeStore(fail=True), msg)
        self.assertFalse(msg.acked)
        self.assertEqual(msg.naks, [5])


if __name__ == "__main__":
    unittest.main()
