import base64
import json
import unittest

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

from app.core.config import settings
from app.services import realtime_capability_service


def _decode(value: str) -> bytes:
    padding = "=" * ((4 - len(value) % 4) % 4)
    return base64.urlsafe_b64decode(value + padding)


class RealtimeCapabilityServiceTests(unittest.TestCase):
    def setUp(self):
        self.previous_key = settings.REALTIME_CAPABILITY_PRIVATE_KEY_B64
        settings.REALTIME_CAPABILITY_PRIVATE_KEY_B64 = base64.urlsafe_b64encode(
            bytes(range(32))
        ).rstrip(b"=").decode("ascii")

    def tearDown(self):
        settings.REALTIME_CAPABILITY_PRIVATE_KEY_B64 = self.previous_key

    def test_connect_capability_contains_session_scope_and_valid_signature(self):
        issued = realtime_capability_service.issue_realtime_capability(
            access_token="access-token",
            user_id=42,
            device_id="device-1",
            is_staff=False,
            scopes=["realtime:connect"],
        )
        header_part, payload_part, signature_part = issued.token.split(".")
        payload = json.loads(_decode(payload_part))
        self.assertEqual(42, payload["user_id"])
        self.assertEqual(["realtime:connect"], payload["scopes"])
        self.assertEqual(
            realtime_capability_service.session_id_for_access_token("access-token"),
            payload["session_id"],
        )
        jwk = realtime_capability_service.public_jwk()
        public_key = Ed25519PublicKey.from_public_bytes(_decode(str(jwk["x"])))
        public_key.verify(
            _decode(signature_part),
            f"{header_part}.{payload_part}".encode("ascii"),
        )

    def test_room_capability_is_bound_to_room_and_membership_version(self):
        issued = realtime_capability_service.issue_realtime_capability(
            access_token="access-token",
            user_id=42,
            device_id="device-1",
            is_staff=True,
            scopes=["room:subscribe"],
            room_id="VM123",
            permissions=["CAN_LISTEN", "ROOM_MEMBER"],
            membership_version=9,
        )
        payload = json.loads(_decode(issued.token.split(".")[1]))
        self.assertEqual("VM123", payload["room_id"])
        self.assertEqual(9, payload["membership_version"])
        self.assertEqual(["CAN_LISTEN", "ROOM_MEMBER"], payload["permissions"])


if __name__ == "__main__":
    unittest.main()
