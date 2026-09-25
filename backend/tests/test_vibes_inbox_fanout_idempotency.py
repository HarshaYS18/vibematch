from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[2]


class VibesInboxFanoutRepairTests(unittest.TestCase):
    def test_worker_marks_processed_only_after_inbox_fanout(self):
        source = (ROOT / "apps/worker/handlers.py").read_text(encoding="utf-8")
        start = source.index("def handle_vibes_post_published")
        end = source.index("\ndef handle_vibes_media_requested", start)
        handler = source[start:end]

        send_index = handler.index("inbox_service_client.send_direct_message")
        mark_index = handler.rindex("_mark_processed(event,handler_name)")
        self.assertLess(send_index, mark_index)
        self.assertIn("source_dedupe_key=", handler)
        self.assertNotIn("except (inbox_service_client.InboxServiceUnavailable", handler)

    def test_inbox_effect_key_is_unique_and_migrated(self):
        model = (ROOT / "backend/app/models/inbox.py").read_text(encoding="utf-8")
        migration = (
            ROOT / "backend/alembic/versions/20260925_0300_inbox_source_dedupe_key.py"
        ).read_text(encoding="utf-8")
        service = (ROOT / "backend/app/services/inbox_service.py").read_text(encoding="utf-8")
        internal = (ROOT / "apps/inbox-service/internal.py").read_text(encoding="utf-8")

        self.assertIn("source_dedupe_key", model)
        self.assertIn("unique=True", model)
        self.assertIn("uq_inbox_messages_source_dedupe_key", migration)
        self.assertIn("IntegrityError", service)
        self.assertIn("source_dedupe_key=payload.source_dedupe_key", internal)


if __name__ == "__main__":
    unittest.main()
