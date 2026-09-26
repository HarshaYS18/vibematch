from unittest import TestCase
from unittest.mock import Mock, patch

import fakeredis
from fastapi import BackgroundTasks, HTTPException, Request
from redis.exceptions import ConnectionError, TimeoutError

from app.api.routes import media_control
from app.core.config import settings
from app.schemas.media_node import MediaNodeHeartbeatRequest


class MediaControlFailureTests(TestCase):
    def setUp(self):
        self.redis = fakeredis.FakeRedis()
        self.heartbeat = MediaNodeHeartbeatRequest(
            node_id="test-node",
            public_url="https://media.example.test",
            room_count=0,
            peer_count=0,
            max_rooms=2,
            max_peers=10,
        )
        self.request = Request({
            "type": "http",
            "headers": [(b"x-media-internal-token", settings.MEDIA_INTERNAL_TOKEN.encode())],
        })

    def test_heartbeat_returns_503_when_redis_is_unavailable(self):
        with patch.object(self.redis, "eval", side_effect=ConnectionError("offline")):
            with patch.object(media_control, "get_media_registry_redis", return_value=self.redis):
                with self.assertRaises(HTTPException) as raised:
                    media_control.media_node_heartbeat(self.heartbeat, self.request, BackgroundTasks())
        self.assertEqual(raised.exception.status_code, 503)

    def test_heartbeat_returns_503_on_redis_command_timeout(self):
        with patch.object(self.redis, "eval", side_effect=TimeoutError("command timed out")):
            with patch.object(media_control, "get_media_registry_redis", return_value=self.redis):
                with self.assertRaises(HTTPException) as raised:
                    media_control.media_node_heartbeat(self.heartbeat, self.request, BackgroundTasks())
        self.assertEqual(raised.exception.status_code, 503)

    def test_discovery_returns_503_on_redis_command_timeout(self):
        with patch.object(media_control, "verify_media_realtime_request", return_value={"allowed": True, "reason": None}):
            with patch.object(self.redis, "eval", side_effect=TimeoutError("command timed out")):
                with patch.object(media_control, "get_media_registry_redis", return_value=self.redis):
                    with self.assertRaises(HTTPException) as raised:
                        media_control.resolve_room_media("room", current_user=Mock(), db=Mock())
        self.assertEqual(raised.exception.status_code, 503)
