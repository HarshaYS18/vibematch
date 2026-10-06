import unittest
from unittest.mock import Mock, patch

from app.services import media_storage_service


class _StorageError(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.response = {"Error": {"Code": code}}


class MediaMultipartRetryRecoveryTests(unittest.TestCase):
    def test_no_such_upload_recovers_when_completed_object_exists(self):
        client = Mock()
        client.complete_multipart_upload.side_effect = _StorageError("NoSuchUpload")
        client.head_object.return_value = {
            "ContentLength": 10,
            "ContentType": "image/jpeg",
        }

        with (
            patch.object(media_storage_service, "_s3_client", return_value=client),
            patch.object(media_storage_service, "_require_s3_bucket", return_value="bucket"),
        ):
            media_storage_service.complete_multipart_upload(
                object_key="incoming/test.jpg",
                upload_id="already-completed",
                parts=[{"part_number": 1, "etag": "etag-1"}],
            )

        client.head_object.assert_called_once_with(
            Bucket="bucket",
            Key="incoming/test.jpg",
        )

    def test_no_such_upload_does_not_hide_missing_object(self):
        client = Mock()
        client.complete_multipart_upload.side_effect = _StorageError("NoSuchUpload")
        client.head_object.side_effect = _StorageError("NoSuchKey")

        with (
            patch.object(media_storage_service, "_s3_client", return_value=client),
            patch.object(media_storage_service, "_require_s3_bucket", return_value="bucket"),
            self.assertRaises(_StorageError),
        ):
            media_storage_service.complete_multipart_upload(
                object_key="incoming/missing.jpg",
                upload_id="missing",
                parts=[{"part_number": 1, "etag": "etag-1"}],
            )

    def test_other_completion_errors_are_not_suppressed(self):
        client = Mock()
        client.complete_multipart_upload.side_effect = _StorageError("AccessDenied")

        with (
            patch.object(media_storage_service, "_s3_client", return_value=client),
            patch.object(media_storage_service, "_require_s3_bucket", return_value="bucket"),
            self.assertRaises(_StorageError),
        ):
            media_storage_service.complete_multipart_upload(
                object_key="incoming/test.jpg",
                upload_id="upload",
                parts=[{"part_number": 1, "etag": "etag-1"}],
            )


if __name__ == "__main__":
    unittest.main()
