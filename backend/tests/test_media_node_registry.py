from concurrent.futures import ThreadPoolExecutor
from unittest import TestCase
from unittest.mock import patch

import fakeredis
from redis.exceptions import ConnectionError, TimeoutError

from app.services import media_node_registry_service as registry


class MediaRegistryTests(TestCase):
    def setUp(self):
        # Byte responses deliberately exercise deployments without decode_responses.
        self.redis = fakeredis.FakeRedis()

    def heartbeat(self, name="a", rooms=0, max_rooms=2, room_ids=None):
        return registry.heartbeat_node(
            self.redis, node_id=name, public_url=f"https://{name}.example.test",
            room_count=rooms, peer_count=rooms, max_rooms=max_rooms,
            max_peers=100, room_ids=room_ids or [],
        )

    def test_sticky_assignment_and_drain(self):
        self.heartbeat()
        self.assertEqual(registry.resolve_room_node(self.redis, "room").node_id, "a")
        ttl = self.redis.pttl(registry.NODE_PREFIX + "a")
        registry.set_node_draining(self.redis, "a", True)
        self.assertLessEqual(self.redis.pttl(registry.NODE_PREFIX + "a"), ttl)
        self.heartbeat("b")
        self.assertEqual(registry.resolve_room_node(self.redis, "room").node_id, "a")
        self.assertEqual(registry.resolve_room_node(self.redis, "new").node_id, "b")
        self.assertTrue(registry.room_is_assigned_to_node(self.redis, "room", "a"))
        self.assertFalse(registry.room_is_assigned_to_node(self.redis, "room", "b"))

    def test_drain_survives_heartbeat_expiry(self):
        self.heartbeat()
        registry.set_node_draining(self.redis, "a", True)
        self.redis.expire(registry.NODE_PREFIX + "a", 0)
        self.assertTrue(self.heartbeat().draining)
        with self.assertRaises(registry.MediaNodeUnavailable):
            registry.resolve_room_node(self.redis, "new")

    def test_stale_or_offline_node_is_reassigned(self):
        self.heartbeat()
        registry.resolve_room_node(self.redis, "room")
        self.redis.expire(registry.NODE_PREFIX + "a", 0)
        self.heartbeat("b")
        self.assertEqual(registry.resolve_room_node(self.redis, "room").node_id, "b")
        registry.remove_node(self.redis, "b")
        with self.assertRaises(registry.MediaNodeUnavailable):
            registry.resolve_room_node(self.redis, "room")

    def test_same_node_id_restart_reuses_sticky_assignment(self):
        self.heartbeat("a")
        registry.resolve_room_node(self.redis, "room")
        self.redis.expire(registry.NODE_PREFIX + "a", 0)
        self.heartbeat("a")
        self.assertEqual(registry.resolve_room_node(self.redis, "room").node_id, "a")
        self.assertTrue(registry.room_is_assigned_to_node(self.redis, "room", "a"))

    def test_pending_assignments_reserve_capacity_atomically(self):
        self.heartbeat(max_rooms=2)
        def assign(index):
            try:
                return registry.resolve_room_node(self.redis, f"room-{index}").node_id
            except registry.MediaNodeUnavailable:
                return None
        with ThreadPoolExecutor(max_workers=8) as pool:
            results = list(pool.map(assign, range(12)))
        self.assertEqual(results.count("a"), 2)

    def test_heartbeat_refreshes_only_owned_assignments(self):
        self.heartbeat()
        registry.resolve_room_node(self.redis, "room")
        self.redis.expire(registry.ROOM_PREFIX + "room", 5)
        self.heartbeat("b", room_ids=["room"])
        self.assertLessEqual(self.redis.ttl(registry.ROOM_PREFIX + "room"), 5)
        self.heartbeat("a", rooms=1, room_ids=["room"])
        self.assertGreater(self.redis.ttl(registry.ROOM_PREFIX + "room"), 5)

    def test_redis_failure_is_unavailable_not_local_fallback(self):
        with patch.object(self.redis, "eval", side_effect=ConnectionError("offline")):
            with self.assertRaises(registry.MediaNodeUnavailable):
                registry.resolve_room_node(self.redis, "room")

    def test_redis_command_timeout_is_unavailable(self):
        with patch.object(self.redis, "eval", side_effect=TimeoutError("timed out")):
            with self.assertRaises(registry.MediaNodeUnavailable):
                self.heartbeat()
            with self.assertRaises(registry.MediaNodeUnavailable):
                registry.resolve_room_node(self.redis, "room")

    def test_discovery_uses_one_atomic_command_without_scanning(self):
        self.heartbeat("a")
        with patch.object(self.redis, "scan_iter", side_effect=AssertionError("hot path scanned Redis")):
            self.assertEqual(registry.resolve_room_node(self.redis, "room").node_id, "a")
