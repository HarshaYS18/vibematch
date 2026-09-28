from pathlib import Path
import unittest
from unittest.mock import patch
from uuid import uuid4

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.database import Base
from app.models.notification import NotificationPreference, UserNotification
from app.models.user import User
from app.services import notification_delivery_service

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

    def test_notification_intent_is_idempotent_at_authority(self):
        engine=create_engine("sqlite://",connect_args={"check_same_thread":False},poolclass=StaticPool)
        Base.metadata.create_all(engine,tables=[User.__table__,UserNotification.__table__,NotificationPreference.__table__])
        factory=sessionmaker(bind=engine)
        with factory.begin() as db:
            db.add(User(id=7,public_user_id=6418000007,username="recipient"))
        source_event_id=str(uuid4())
        with patch.object(notification_delivery_service.push_notification_service,"active_tokens_for_user",return_value=[]), patch.object(notification_delivery_service.event_outbox_service,"enqueue_event"):
            with factory() as db:
                first,first_duplicate=notification_delivery_service.create_intent(
                    db,source_event_id=source_event_id,recipient_user_id=7,actor_user_id=None,
                    notification_type="test",title="Hello",body="Body",target_type=None,target_id=None,target_url=None,
                    metadata={},dedupe_key="stable-key",collapse_key=None,
                )
                second,second_duplicate=notification_delivery_service.create_intent(
                    db,source_event_id=source_event_id,recipient_user_id=7,actor_user_id=None,
                    notification_type="test",title="Hello",body="Body",target_type=None,target_id=None,target_url=None,
                    metadata={},dedupe_key="stable-key",collapse_key=None,
                )
                self.assertEqual(first.id,second.id)
                self.assertFalse(first_duplicate); self.assertTrue(second_duplicate)
                self.assertEqual(db.query(UserNotification).count(),1)
        engine.dispose()

    def test_api_does_not_hold_fcm_credentials(self):
        main=(ROOT/"apps/notification-service/main.py").read_text(encoding="utf-8")
        deployment=(ROOT/"deploy/kubernetes/base/notification.yaml").read_text(encoding="utf-8")
        api_block=deployment.split("kind: Service\n",1)[0]
        self.assertNotIn("assert_firebase_configuration",main)
        self.assertNotIn("firebase-service-account",api_block)
        self.assertIn("funkey-notification-provider-secrets",deployment)

    def test_fcm_transport_has_single_backend_implementation(self):
        provider=(ROOT/"backend/app/services/push_notification_service.py").read_text(encoding="utf-8"); worker=(ROOT/"apps/notification-service/provider_worker.py").read_text(encoding="utf-8")
        self.assertIn("fcm.googleapis.com/v1/projects",provider); self.assertNotIn("fcm.googleapis.com",worker)
        self.assertIn("assert_firebase_configuration",worker)

    def test_notification_tables_have_isolated_owner(self):
        ownership=(ROOT/"deploy/postgres/notification-ownership.sql").read_text(encoding="utf-8")
        for table in ("user_notifications","push_device_tokens","notification_preferences","notification_templates","notification_deliveries"): self.assertIn(table,ownership)
        self.assertIn("Do not grant funkey_notification_runtime to core-api",ownership)

    def test_migration_and_registry_cover_chunk_29(self):
        migration=(ROOT/"backend/alembic/versions/20260924_0900_notification_service.py").read_text(encoding="utf-8"); registry=(ROOT/"contracts/architecture/authorities.yaml").read_text(encoding="utf-8")
        for table in ("notification_preferences","notification_templates","notification_deliveries"): self.assertIn(table,migration)
        self.assertIn('"current_deployable": "notification-service"',registry); self.assertIn('"id": "notifications.delivery"',registry)


if __name__=="__main__": unittest.main()
