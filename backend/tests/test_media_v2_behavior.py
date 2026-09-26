from datetime import datetime, timedelta
import unittest
from unittest.mock import patch

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base
from app.models.cdn_media import (
    CdnMediaAsset,
    CdnMediaDeletionStatus,
    CdnMediaLinkedEntityType,
    CdnMediaModerationStatus,
    CdnMediaType,
    CdnMediaUploadStatus,
    MediaProcessingStatus,
    MediaUploadMode,
    MediaUploadSession,
    MediaUploadSessionStatus,
)
from app.models.user import User
from app.services import media_upload_session_service, media_storage_service


class MediaV2BehaviorTests(unittest.TestCase):
    def _factory(self):
        engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(
            engine,
            tables=[User.__table__, CdnMediaAsset.__table__, MediaUploadSession.__table__],
        )
        return engine, sessionmaker(bind=engine)

    def _seed(self, factory, *, expected_size=5):
        with factory.begin() as db:
            db.add(User(id=1, public_user_id=6418000001, username="media-user"))
            asset = CdnMediaAsset(
                id=10,
                public_id="media_test",
                owner_user_id=1,
                public_user_id=6418000001,
                media_type=CdnMediaType.VIBES_MEDIA.value,
                object_key="incoming/vibes/user_1/test.mp4",
                public_url="https://cdn.example/test.mp4",
                mime_type="video/mp4",
                size_bytes=expected_size,
                upload_status=CdnMediaUploadStatus.PENDING_UPLOAD.value,
                moderation_status=CdnMediaModerationStatus.PENDING.value,
                deletion_status=CdnMediaDeletionStatus.ACTIVE.value,
                processing_status=MediaProcessingStatus.PENDING.value,
                linked_entity_type=CdnMediaLinkedEntityType.VIBES_POST.value,
                is_active_reference=False,
            )
            db.add(asset)
            db.add(
                MediaUploadSession(
                    id=20,
                    public_id="upload_test",
                    media_id=10,
                    owner_user_id=1,
                    purpose="vibes",
                    original_filename="test.mp4",
                    expected_mime_type="video/mp4",
                    expected_size_bytes=expected_size,
                    object_key=asset.object_key,
                    storage_driver="s3",
                    upload_mode=MediaUploadMode.SINGLE_PUT.value,
                    status=MediaUploadSessionStatus.CREATED.value,
                    expires_at=datetime.utcnow() + timedelta(minutes=10),
                )
            )

    def test_completion_verifies_object_and_enqueues_processing_once(self):
        engine, factory = self._factory()
        try:
            self._seed(factory)
            head = media_storage_service.MediaObjectHead(
                size_bytes=5, content_type="video/mp4", etag="abc"
            )
            with factory() as db, patch.object(
                media_upload_session_service.media_storage_service,
                "head_media_object",
                return_value=head,
            ), patch.object(
                media_upload_session_service.event_outbox_service,
                "enqueue_event",
            ) as enqueue:
                asset, duplicate = media_upload_session_service.complete_upload_session(
                    db, owner_user_id=1, session_id="upload_test", parts=[]
                )
                self.assertFalse(duplicate)
                self.assertEqual(asset.upload_status, CdnMediaUploadStatus.PROCESSING.value)
                self.assertEqual(asset.processing_status, MediaProcessingStatus.PENDING.value)
                enqueue.assert_called_once()
                self.assertEqual(enqueue.call_args.kwargs["event_type"], "media.uploaded")

            with factory() as db, patch.object(
                media_upload_session_service.event_outbox_service,
                "enqueue_event",
            ) as enqueue:
                _asset, duplicate = media_upload_session_service.complete_upload_session(
                    db, owner_user_id=1, session_id="upload_test", parts=[]
                )
                self.assertTrue(duplicate)
                enqueue.assert_not_called()
        finally:
            engine.dispose()

    def test_size_mismatch_fails_closed_and_schedules_delete(self):
        engine, factory = self._factory()
        try:
            self._seed(factory, expected_size=5)
            head = media_storage_service.MediaObjectHead(
                size_bytes=4, content_type="video/mp4", etag="bad"
            )
            with factory() as db, patch.object(
                media_upload_session_service.media_storage_service,
                "head_media_object",
                return_value=head,
            ), patch.object(
                media_upload_session_service.event_outbox_service,
                "enqueue_event",
            ) as enqueue:
                with self.assertRaises(media_upload_session_service.MediaUploadSessionError):
                    media_upload_session_service.complete_upload_session(
                        db, owner_user_id=1, session_id="upload_test", parts=[]
                    )
                enqueue.assert_called_once()
                self.assertEqual(enqueue.call_args.kwargs["event_type"], "media.delete.requested")

            with factory() as db:
                session = db.query(MediaUploadSession).filter_by(public_id="upload_test").one()
                asset = db.query(CdnMediaAsset).filter_by(public_id="media_test").one()
                self.assertEqual(session.status, MediaUploadSessionStatus.FAILED.value)
                self.assertEqual(asset.upload_status, CdnMediaUploadStatus.REJECTED.value)
                self.assertEqual(asset.processing_status, MediaProcessingStatus.FAILED.value)
                self.assertEqual(asset.processing_error, "size_mismatch")
        finally:
            engine.dispose()


if __name__ == "__main__":
    unittest.main()
