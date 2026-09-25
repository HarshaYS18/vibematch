import os
import unittest
from unittest.mock import patch

from config import Settings


class ConfigTests(unittest.TestCase):
    def test_plaintext_local_configuration_does_not_require_credentials(self):
        with patch.dict(os.environ, {
            "KAFKA_BOOTSTRAP_SERVERS": "localhost:19092",
            "KAFKA_SECURITY_PROTOCOL": "PLAINTEXT",
        }, clear=True):
            settings = Settings.from_env()
            settings.validate()
            self.assertEqual(settings.kafka_security_protocol, "PLAINTEXT")

    def test_production_rejects_plaintext(self):
        with patch.dict(os.environ, {
            "APP_ENV": "production",
            "KAFKA_BOOTSTRAP_SERVERS": "kafka.example:9092",
            "KAFKA_SECURITY_PROTOCOL": "PLAINTEXT",
        }, clear=True):
            with self.assertRaises(RuntimeError):
                Settings.from_env().validate()

    def test_sasl_requires_credentials(self):
        with patch.dict(os.environ, {
            "KAFKA_BOOTSTRAP_SERVERS": "kafka.example:9093",
            "KAFKA_SECURITY_PROTOCOL": "SASL_SSL",
        }, clear=True):
            with self.assertRaises(RuntimeError):
                Settings.from_env().validate()


if __name__ == "__main__":
    unittest.main()
