from types import SimpleNamespace
from unittest import TestCase
from unittest.mock import Mock, patch

import fakeredis
from fastapi import Request

from app.api.routes import media_control, media_realtime_auth
from app.models.role import RoleName
from app.realtime.connection_manager import (
    has_active_room_user_lease,
    room_user_lease_key,
)
from app.schemas.media_realtime_auth import MediaRealtimeVerifyRequest
from app.services import media_node_registry_service
from app.services.permissions import media_room_permission_service as permissions


class MediaRoomLivePresenceTests(TestCase):
    def test_authenticated_room_lease_is_live_presence_proof(self):
        redis_client = fakeredis.FakeRedis(decode_responses=True)
        key = room_user_lease_key("VM123456", 7)

        redis_client.zadd(key, {"expired": 90.0, "live": 130.0})

        self.assertTrue(
            has_active_room_user_lease(
                redis_client,
                "VM123456",
                7,
                now=100.0,
            )
        )
        self.assertFalse(
            has_active_room_user_lease(
                redis_client,
                "VM123456",
                7,
                now=140.0,
            )
        )

    def test_live_connection_bridges_stale_participant_flag_for_media_join(self):
        room = SimpleNamespace(
            id=3,
            room_public_id="VM123456",
            owner_user_id=99,
            is_secret=False,
            is_locked=False,
            is_members_only=False,
            apply_only_mode_enabled=False,
        )
        user = SimpleNamespace(id=7)
        stale_participant = SimpleNamespace(
            is_active=False,
            is_room_admin=False,
            is_member=False,
        )

        with (
            patch.object(
                permissions.role_service,
                "get_primary_role",
                return_value=RoleName.USER,
            ),
            patch.object(
                permissions,
                "_participant",
                return_value=stale_participant,
            ),
            patch.object(permissions, "_active_kickout", return_value=None),
            patch.object(permissions, "_occupied_seat", return_value=None),
        ):
            allowed = permissions.evaluate_media_room_permission(
                db=SimpleNamespace(),
                user=user,
                room=room,
                action="join_room",
                has_active_room_connection=True,
            )
            denied = permissions.evaluate_media_room_permission(
                db=SimpleNamespace(),
                user=user,
                room=room,
                action="join_room",
                has_active_room_connection=False,
            )

        self.assertTrue(allowed.allowed)
        self.assertTrue(allowed.context["has_active_room_connection"])
        self.assertFalse(allowed.context["has_active_participant_record"])
        self.assertTrue(allowed.context["has_active_room_presence"])

        self.assertFalse(denied.allowed)
        self.assertEqual(
            denied.reason,
            "Join the room before using room media.",
        )


    def test_media_discovery_passes_live_room_lease_to_permission_check(self):
        redis_client = fakeredis.FakeRedis(decode_responses=True)
        user = SimpleNamespace(id=7)
        node = media_node_registry_service.MediaNode(
            node_id="node-a",
            public_url="http://127.0.0.1:4100",
            room_count=0,
            peer_count=0,
            max_rooms=10,
            max_peers=100,
            draining=False,
            updated_at=1.0,
        )

        with (
            patch.object(media_control, "get_redis", return_value=redis_client),
            patch.object(
                media_control,
                "has_active_room_user_lease",
                return_value=True,
            ),
            patch.object(
                media_control,
                "verify_media_realtime_request",
                return_value={"allowed": True, "reason": None},
            ) as verify,
            patch.object(
                media_control.media_node_registry_service,
                "resolve_room_node",
                return_value=node,
            ),
        ):
            response = media_control.resolve_room_media(
                "VM123456",
                device_id="device",
                current_user=user,
                db=Mock(),
            )

        self.assertEqual(response.node_id, "node-a")
        self.assertTrue(
            verify.call_args.kwargs["has_active_room_connection"]
        )

    def test_media_verify_endpoint_passes_live_room_lease_to_permission_check(self):
        redis_client = fakeredis.FakeRedis(decode_responses=True)
        user = SimpleNamespace(id=7)
        payload = MediaRealtimeVerifyRequest(
            room_public_id="VM123456",
            requested_action="join_room",
        )
        request = Request({"type": "http", "headers": []})
        verified_payload = {
            "allowed": True,
            "reason": None,
            "user": {
                "user_id": 7,
                "public_user_id": 7000007,
                "username": "test",
                "display_name": "Test",
                "avatar_url": None,
                "roles": ["user"],
                "primary_role": "user",
                "is_active": True,
                "is_banned": False,
            },
            "room_public_id": "VM123456",
            "requested_action": "join_room",
            "permissions": ["ROOM_MEDIA_PERMISSION_VERIFIED"],
            "mediasoup_context": {},
        }

        with (
            patch.object(
                media_realtime_auth,
                "get_redis",
                return_value=redis_client,
            ),
            patch.object(
                media_realtime_auth,
                "has_active_room_user_lease",
                return_value=True,
            ),
            patch.object(
                media_realtime_auth,
                "verify_media_realtime_request",
                return_value=verified_payload,
            ) as verify,
        ):
            response = media_realtime_auth.verify_media_realtime_access(
                payload,
                request,
                db=Mock(),
                current_user=user,
            )

        self.assertTrue(response.allowed)
        self.assertTrue(
            verify.call_args.kwargs["has_active_room_connection"]
        )

    def test_live_connection_does_not_bypass_kickout(self):
        room = SimpleNamespace(
            id=3,
            room_public_id="VM123456",
            owner_user_id=99,
            is_secret=False,
            is_locked=False,
            is_members_only=False,
            apply_only_mode_enabled=False,
        )
        user = SimpleNamespace(id=7)
        stale_participant = SimpleNamespace(
            is_active=False,
            is_room_admin=False,
            is_member=False,
        )

        with (
            patch.object(
                permissions.role_service,
                "get_primary_role",
                return_value=RoleName.USER,
            ),
            patch.object(
                permissions,
                "_participant",
                return_value=stale_participant,
            ),
            patch.object(
                permissions,
                "_active_kickout",
                return_value=SimpleNamespace(id=1),
            ),
            patch.object(permissions, "_occupied_seat", return_value=None),
        ):
            decision = permissions.evaluate_media_room_permission(
                db=SimpleNamespace(),
                user=user,
                room=room,
                action="join_room",
                has_active_room_connection=True,
            )

        self.assertFalse(decision.allowed)
        self.assertEqual(
            decision.reason,
            "User is kicked out from this room.",
        )


if __name__ == "__main__":
    import unittest

    unittest.main()
