from pathlib import Path
import unittest
ROOT=Path(__file__).resolve().parents[2]
class NotificationServiceBoundaryTests(unittest.TestCase):
    def test_core_routes_proxy_notification_authority(self):
        router=(ROOT/"backend/app/api/router.py").read_text(encoding="utf-8")
        self.assertIn("notification_proxy.router",router); self.assertNotIn("notifications.router",router); self.assertNotIn("push.router",router)
    def test_generic_worker_never_writes_notification_tables(self):
        worker=(ROOT/"apps/worker/handlers.py").read_text(encoding="utf-8")
        self.assertNotIn("UserNotification(",worker); self.assertNotIn("PushDeviceToken(",worker); self.assertIn("notification_service_client.create_intent",worker)
    def test_provider_delivery_is_durable_and_leased(self):
        model=(ROOT/"backend/app/models/notification.py").read_text(encoding="utf-8"); delivery=(ROOT/"backend/app/services/notification_delivery_service.py").read_text(encoding="utf-8")
        self.assertIn("class NotificationDelivery",model); self.assertIn(".with_for_update(skip_locked=True)",delivery)
        for value in ('status="RETRY"','status="INVALID_TOKEN"','status="DEFERRED"','status="SUPPRESSED"'): self.assertIn(value,delivery)
    def test_fcm_transport_has_single_backend_implementation(self):
        provider=(ROOT/"backend/app/services/push_notification_service.py").read_text(encoding="utf-8"); worker=(ROOT/"apps/notification-service/provider_worker.py").read_text(encoding="utf-8")
        self.assertIn("fcm.googleapis.com/v1/projects",provider); self.assertNotIn("fcm.googleapis.com",worker)
    def test_notification_tables_have_isolated_owner(self):
        ownership=(ROOT/"deploy/postgres/notification-ownership.sql").read_text(encoding="utf-8")
        for table in ("user_notifications","push_device_tokens","notification_preferences","notification_templates","notification_deliveries"): self.assertIn(table,ownership)
        self.assertIn("Do not grant funkey_notification_runtime to core-api",ownership)
    def test_migration_and_registry_cover_chunk_29(self):
        migration=(ROOT/"backend/alembic/versions/20260924_0900_notification_service.py").read_text(encoding="utf-8"); registry=(ROOT/"contracts/architecture/authorities.yaml").read_text(encoding="utf-8")
        for table in ("notification_preferences","notification_templates","notification_deliveries"): self.assertIn(table,migration)
        self.assertIn('"current_deployable": "notification-service"',registry); self.assertIn('"id": "notifications.delivery"',registry)
if __name__=="__main__": unittest.main()
