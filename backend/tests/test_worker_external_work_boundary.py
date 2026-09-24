from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[2]


class WorkerExternalWorkBoundaryTests(unittest.TestCase):
    def test_media_upload_does_not_call_provider_inline(self):
        route=(ROOT/"backend/app/api/routes/media.py").read_text(encoding="utf-8")
        service=(ROOT/"backend/app/services/cdn_media_service.py").read_text(encoding="utf-8")
        self.assertNotIn("media_moderation_service",route)
        self.assertIn('event_type="media.moderation.requested"',service)

    def test_object_delete_is_queued_from_request_paths(self):
        service=(ROOT/"backend/app/services/cdn_media_service.py").read_text(encoding="utf-8")
        request_part=service.split("def execute_media_delete",1)[0]
        self.assertNotIn("delete_media_object",request_part)
        self.assertIn('event_type="media.delete.requested"',request_part)

    def test_media_cleanup_is_worker_queued(self):
        route=(ROOT/"backend/app/api/routes/media_safety_admin.py").read_text(encoding="utf-8")
        service=(ROOT/"backend/app/services/cdn_media_service.py").read_text(encoding="utf-8")
        self.assertIn("request_expired_inbox_media_cleanup",route)
        self.assertIn('event_type="media.cleanup.requested"',service)

    def test_google_backup_api_only_creates_durable_job(self):
        service=(ROOT/"backend/app/services/inbox_backup_service.py").read_text(encoding="utf-8")
        enqueue=service.split("def execute_backup_job",1)[0]
        self.assertIn('event_type="inbox.backup.requested"',enqueue)
        self.assertNotIn("upload_backup_file(",enqueue)
        self.assertIn("idempotency_key=job.public_id",service)

    def test_worker_pools_own_external_work(self):
        pools=(ROOT/"apps/worker/pools.py").read_text(encoding="utf-8")
        handlers=(ROOT/"apps/worker/handlers.py").read_text(encoding="utf-8")
        for event in (
            "media.moderation.requested",
            "media.delete.requested",
            "media.cleanup.requested",
            "inbox.backup.requested",
            "inbox.restore.requested",
        ):
            self.assertIn(event,pools)
            self.assertIn(event,handlers)

    def test_google_provider_errors_do_not_persist_response_bodies(self):
        google=(ROOT/"backend/app/services/google_drive_service.py").read_text(encoding="utf-8")
        self.assertNotIn("backup upload failed: {response.text}",google)
        self.assertIn("funkey_job_id",google)

    def test_pending_profile_media_is_not_auto_approved(self):
        service=(ROOT/"backend/app/services/cdn_media_service.py").read_text(encoding="utf-8")
        handlers=(ROOT/"apps/worker/handlers.py").read_text(encoding="utf-8")
        self.assertIn("pending_profile_reference",service)
        self.assertNotIn(
            "CdnMediaModerationStatus.AI_APPROVED.value if new_asset.moderation_status",
            service,
        )
        self.assertIn("activate_approved_profile_media",handlers)


if __name__=="__main__": unittest.main()
