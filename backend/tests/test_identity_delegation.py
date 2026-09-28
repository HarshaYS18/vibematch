from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import Mock, patch

from app.api.routes import users


class IdentityDelegationTests(TestCase):
    def test_sid_token_delegates_session_authority_to_identity(self):
        db = Mock()
        user = SimpleNamespace(
            id=7,
            is_banned=False,
            is_active=True,
            last_device_id="device-1",
        )
        db.query.return_value.filter.return_value.first.return_value = user
        with patch.object(
            users,
            "decode_access_token",
            return_value={"sub": "7", "device_id": "device-1", "sid": "session-1"},
        ), patch.object(
            users.identity_service_client,
            "verify_access_token",
            return_value={"user_id": 7, "session_id": "session-1"},
        ) as verify:
            result = users.get_current_user_from_token(db, "jwt")
        self.assertIs(result, user)
        verify.assert_called_once_with("jwt")
