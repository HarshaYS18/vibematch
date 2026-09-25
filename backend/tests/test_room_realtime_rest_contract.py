import unittest

from fastapi import HTTPException
from fastapi.routing import APIRoute

from app.api.routes.room_realtime_commands import _chat_message_fields, router
from app.schemas.room_realtime import (
    RoomChatSendCommand,
    RoomJoinCommand,
    RoomWatchPartyCommand,
)
from app.services.rooms.room_action_service import _safe_room_join_event_payload


class RoomRealtimeRestContractTests(unittest.TestCase):
    def test_join_accepts_room_lock_password(self):
        command = RoomJoinCommand(lock_password="secret")
        self.assertEqual("secret", command.lock_password)

    def test_join_event_payload_never_persists_room_password(self):
        payload = _safe_room_join_event_payload(
            {
                "lock_password": "super-secret",
                "password": "legacy-secret",
                "is_stealth": True,
            },
            is_stealth=True,
        )
        self.assertNotIn("lock_password", payload)
        self.assertNotIn("password", payload)
        self.assertTrue(payload["is_stealth"])

    def test_canonical_room_lifecycle_routes_exist(self):
        routes = {
            (route.path, method)
            for route in router.routes
            if isinstance(route, APIRoute)
            for method in route.methods
        }
        prefix = "/rooms/{room_public_id}/realtime"
        self.assertIn((f"{prefix}/snapshot", "GET"), routes)
        self.assertIn((f"{prefix}/join", "POST"), routes)
        self.assertIn((f"{prefix}/heartbeat", "POST"), routes)
        self.assertIn((f"{prefix}/leave", "POST"), routes)
        self.assertIn((f"{prefix}/watch-party/command", "POST"), routes)
        self.assertIn((f"{prefix}/chat/clear", "POST"), routes)

    def test_image_chat_command_allows_media_without_placeholder_text(self):
        command = RoomChatSendCommand(
            message_type="image",
            media_url="https://cdn.example/room/image.webp",
            content_type="image/webp",
        )
        self.assertIsNone(command.text)
        self.assertEqual("image", command.message_type)
        self.assertEqual(
            "https://cdn.example/room/image.webp",
            command.media_url,
        )

        text, message_type, media_url = _chat_message_fields(
            command.model_dump(exclude_none=True)
        )
        self.assertIsNone(text)
        self.assertEqual("image", message_type)
        self.assertEqual(command.media_url, media_url)

    def test_image_chat_requires_http_media_url(self):
        with self.assertRaises(HTTPException):
            _chat_message_fields(
                {
                    "message_type": "image",
                    "media_url": "file:///tmp/image.png",
                    "content_type": "image/png",
                }
            )

    def test_watch_party_command_accepts_revisioned_sync_payload(self):
        command = RoomWatchPartyCommand(
            action="SYNC",
            expected_revision=7,
            position_ms=57340,
            playback_state="playing",
            playback_rate=1.0,
        )
        self.assertEqual("SYNC", command.action)
        self.assertEqual(7, command.expected_revision)


if __name__ == "__main__":
    unittest.main()
