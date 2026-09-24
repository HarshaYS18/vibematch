from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MediaV2OperationalTests(unittest.TestCase):
    def test_expired_uploads_use_retryable_abort_event(self):
        service = (ROOT / "backend/app/services/media_upload_session_service.py").read_text(encoding="utf-8")
        handlers = (ROOT / "apps/worker/handlers.py").read_text(encoding="utf-8")
        pools = (ROOT / "apps/worker/pools.py").read_text(encoding="utf-8")
        self.assertIn("with_for_update(skip_locked=True)", service)
        self.assertIn('event_type="media.upload.abort.requested"', service)
        self.assertIn('"media.upload.abort.requested": handle_media_upload_abort_requested', handlers)
        self.assertIn("funkey-worker-media-upload-abort", pools)

    def test_maintenance_sweep_is_bounded(self):
        main = (ROOT / "apps/worker/main.py").read_text(encoding="utf-8")
        self.assertIn("MEDIA_UPLOAD_CLEANUP_INTERVAL_SECONDS", main)
        self.assertIn("MEDIA_UPLOAD_CLEANUP_BATCH_SIZE", main)
        self.assertIn('POOL.name == "maintenance"', main)

    def test_no_such_multipart_upload_is_idempotent_cleanup(self):
        storage = (ROOT / "backend/app/services/media_storage_service.py").read_text(encoding="utf-8")
        self.assertIn('"NoSuchUpload"', storage)

    def test_media_v2_docs_exist(self):
        self.assertTrue((ROOT / "docs/architecture/media-v2-upload.md").is_file())
        self.assertTrue((ROOT / "docs/modules/media-upload-v2/README.md").is_file())
        self.assertTrue((ROOT / "docs/runbooks/media-v2-upload.md").is_file())


if __name__ == "__main__":
    unittest.main()
