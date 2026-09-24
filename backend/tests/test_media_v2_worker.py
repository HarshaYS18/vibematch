from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MediaV2WorkerTests(unittest.TestCase):
    def test_media_uploaded_has_dedicated_worker_subscription(self):
        pools = (ROOT / "apps/worker/pools.py").read_text(encoding="utf-8")
        handlers = (ROOT / "apps/worker/handlers.py").read_text(encoding="utf-8")
        self.assertEqual(pools.count('"media.uploaded"'), 1)
        self.assertIn("funkey-worker-media-uploaded", pools)
        self.assertIn('"media.uploaded": handle_media_uploaded', handlers)

    def test_image_derivatives_cover_required_widths(self):
        processing = (ROOT / "backend/app/services/media_processing_service.py").read_text(encoding="utf-8")
        self.assertIn("IMAGE_WIDTHS = (64, 128, 256, 512, 1024)", processing)
        self.assertIn('format="WEBP"', processing)

    def test_video_uses_fmp4_hls_and_required_renditions(self):
        processing = (ROOT / "backend/app/services/media_processing_service.py").read_text(encoding="utf-8")
        for height in ("360", "540", "720"):
            self.assertIn(height, processing)
        self.assertIn('"fmp4"', processing)
        self.assertIn("master.m3u8", processing)
        dockerfile = (ROOT / "apps/worker/Dockerfile").read_text(encoding="utf-8")
        self.assertIn("ffmpeg", dockerfile)

    def test_video_moderation_uses_generated_poster(self):
        moderation = (ROOT / "backend/app/services/media_moderation_service.py").read_text(encoding="utf-8")
        self.assertIn("asset.thumbnail_url or asset.public_url", moderation)

    def test_processing_is_retryable_and_transitions_terminal_state(self):
        processing = (ROOT / "backend/app/services/media_processing_service.py").read_text(encoding="utf-8")
        self.assertIn("PROCESSING_FAILED", processing)
        self.assertIn('event_type="media.moderation.requested"', processing)
        self.assertIn("MediaProcessingStatus.READY", processing)


if __name__ == "__main__":
    unittest.main()
