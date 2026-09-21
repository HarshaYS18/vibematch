from pathlib import Path
from tempfile import TemporaryDirectory
from unittest import TestCase

from app.services.push_notification_service import assert_firebase_configuration


class FirebaseConfigurationTests(TestCase):
    def test_unconfigured_fcm_is_optional(self):
        assert_firebase_configuration("", "")

    def test_partial_or_missing_credentials_fail_startup(self):
        with self.assertRaisesRegex(RuntimeError, "configured together"):
            assert_firebase_configuration("project", "")
        with self.assertRaisesRegex(RuntimeError, "file is missing"):
            assert_firebase_configuration("project", "missing-service-account.json")

    def test_invalid_credentials_do_not_leak_file_contents(self):
        with TemporaryDirectory() as directory:
            path = Path(directory) / "service-account.json"
            path.write_text('{"private_key":"test-sensitive-text"}', encoding="utf-8")
            with self.assertRaises(RuntimeError) as raised:
                assert_firebase_configuration("project", str(path))
        self.assertEqual(str(raised.exception), "Firebase service account file is invalid.")
