from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class MediaV2ControlPlaneTests(unittest.TestCase):
    def test_direct_upload_api_is_registered(self):
        router = (ROOT / "backend/app/api/router.py").read_text(encoding="utf-8")
        routes = (ROOT / "backend/app/api/routes/media_uploads_v2.py").read_text(encoding="utf-8")
        self.assertIn("media_uploads_v2.router", router)
        self.assertIn('/upload-sessions"', routes)
        self.assertIn('/complete"', routes)
        self.assertIn('/status"', routes)

    def test_public_media_control_assignment_alias_is_registered(self):
        routes = (ROOT / "backend/app/api/routes/media_control.py").read_text(encoding="utf-8")
        self.assertIn('"/media-control/rooms/{room_public_id}/assignment"', routes)
        self.assertIn('"/rooms/{room_public_id}/media"', routes)

    def test_completion_verifies_object_before_media_uploaded_event(self):
        service = (ROOT / "backend/app/services/media_upload_session_service.py").read_text(encoding="utf-8")
        head_index = service.index("head_media_object")
        event_index = service.index('event_type="media.uploaded"')
        self.assertLess(head_index, event_index)
        self.assertIn("size_mismatch", service)
        self.assertIn("content_type_mismatch", service)
        self.assertIn("for_update=True", service)
        self.assertIn(".with_for_update()", service)

    def test_production_uploads_are_direct_and_private_by_default(self):
        storage = (ROOT / "backend/app/services/media_storage_service.py").read_text(encoding="utf-8")
        config = (ROOT / "backend/app/core/config.py").read_text(encoding="utf-8")
        self.assertIn("generate_presigned_url", storage)
        self.assertIn("create_multipart_upload", storage)
        self.assertIn("complete_multipart_upload", storage)
        self.assertIn("MEDIA_S3_PUBLIC_READ: bool = False", config)

    def test_local_dev_upload_streams_request_body(self):
        routes = (ROOT / "backend/app/api/routes/media_uploads_v2.py").read_text(encoding="utf-8")
        self.assertIn("async for chunk in request.stream()", routes)
        self.assertNotIn("await request.body()", routes)

    def test_schema_has_upload_sessions_variants_and_processing_state(self):
        migration = (ROOT / "backend/alembic/versions/20260924_1000_media_v2.py").read_text(encoding="utf-8")
        for marker in ("media_upload_sessions", "cdn_media_variants", "processing_status"):
            self.assertIn(marker, migration)


if __name__ == "__main__":
    unittest.main()
