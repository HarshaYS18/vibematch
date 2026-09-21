import inspect
from unittest import TestCase

from app.api.routes.rooms.rooms import _record_and_broadcast


class RoomBroadcastContractTests(TestCase):
    def test_record_and_broadcast_requires_wire_type(self):
        signature = inspect.signature(_record_and_broadcast)
        self.assertIn("wire_type", signature.parameters)
        self.assertEqual(
            signature.parameters["wire_type"].kind,
            inspect.Parameter.KEYWORD_ONLY,
        )


if __name__ == "__main__":
    import unittest

    unittest.main()
