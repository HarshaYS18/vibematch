import inspect
from unittest import IsolatedAsyncioTestCase, TestCase
from unittest.mock import AsyncMock, patch

import fakeredis.aioredis
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.routes import room_realtime_commands
from app.api.routes.rooms import rooms as legacy_rooms
from app.database import Base
from app.models.room import Room
from app.models.room_realtime_state import (
    RoomMemberRequest,
    RoomRealtimeEvent,
    RoomSeatApplication,
)
from app.realtime import connection_manager
from app.services.rooms import room_action_service, room_state_service


class RoomStateEngineCounterTests(TestCase):
    def test_room_and_event_counters_are_explicit_and_monotonic(self):
        engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
        Base.metadata.create_all(
            engine,
            tables=[Room.__table__, RoomRealtimeEvent.__table__],
        )
        factory = sessionmaker(bind=engine)
        with factory() as db:
            room = Room(
                room_public_id="VM200001",
                name="Room State v2",
                language="English",
            )
            db.add(room)
            db.flush()

            first = room_action_service.record_room_event(
                db, room, "room.test.first"
            )
            second = room_action_service.record_room_event(
                db, room, "room.test.second"
            )
            db.flush()

            self.assertEqual(2, room.realtime_version)
            self.assertEqual(2, room.realtime_event_sequence)
            self.assertEqual((1, 2), (first.sequence, second.sequence))
            self.assertEqual((1, 2), (first.room_version, second.room_version))
            self.assertTrue(first.event_id)
            self.assertNotEqual(first.event_id, second.event_id)
        engine.dispose()

    def test_current_request_state_has_dedicated_tables(self):
        self.assertEqual("room_member_requests", RoomMemberRequest.__tablename__)
        self.assertEqual("room_seat_applications", RoomSeatApplication.__tablename__)

    def test_snapshot_and_heartbeat_sources_are_read_only(self):
        snapshot_source = inspect.getsource(room_state_service.room_snapshot)
        self.assertNotIn("ensure_room_seats(", snapshot_source)
        self.assertNotIn("cleanup_orphaned_seat_occupants(", snapshot_source)
        self.assertNotIn("cleanup_stale_participants(", snapshot_source)
        self.assertNotIn("db.flush()", snapshot_source)

        realtime_heartbeat = inspect.getsource(room_realtime_commands.heartbeat)
        self.assertNotIn("room_snapshot(", realtime_heartbeat)
        self.assertNotIn("heartbeat_room(", realtime_heartbeat)

        legacy_heartbeat = inspect.getsource(legacy_rooms.heartbeat_live_room)
        self.assertNotIn("heartbeat_room(", legacy_heartbeat)
        self.assertNotIn("list_room_participants(", legacy_heartbeat)

    def test_current_request_queries_do_not_scan_event_history(self):
        member_source = inspect.getsource(
            room_state_service.pending_room_member_requests
        )
        seat_source = inspect.getsource(
            room_state_service.pending_seat_applications
        )
        self.assertNotIn("RoomRealtimeEvent", member_source)
        self.assertNotIn("RoomRealtimeEvent", seat_source)
        self.assertIn("RoomMemberRequest", member_source)
        self.assertIn("RoomSeatApplication", seat_source)


class RoomReplayTests(IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.manager = connection_manager.RealtimeConnectionManager()
        self.original_redis = self.manager._redis
        self.redis = fakeredis.aioredis.FakeRedis(decode_responses=True)
        self.manager._redis = self.redis

    async def asyncTearDown(self):
        await self.redis.aclose()
        await self.original_redis.aclose()

    async def _event(self, version: int):
        return await self.manager._decorate_room(
            "VM200001",
            {
                "type": "room/test",
                "payload": {
                    "room_id": "VM200001",
                    "room": {
                        "room_id": "VM200001",
                        "state_version": version,
                        "event_sequence": version,
                    },
                },
            },
        )

    async def test_room_transport_sequence_is_contiguous_and_replayable(self):
        first = await self._event(10)
        second = await self._event(11)

        self.assertEqual(first["stream"], second["stream"])
        self.assertEqual(1, first["sequence"])
        self.assertEqual(2, second["sequence"])
        self.assertEqual(10, first["room_version"])
        self.assertEqual(11, second["room_version"])

        sender = AsyncMock(return_value=True)
        with patch.object(self.manager, "send_json", sender):
            replayed = await self.manager.replay_room(
                object(),
                "VM200001",
                stream=first["stream"],
                after_sequence=0,
            )
        self.assertTrue(replayed)
        self.assertEqual(2, sender.await_count)

    async def test_trimmed_replay_requires_snapshot_when_gap_is_too_old(self):
        with patch.object(connection_manager, "_ROOM_REPLAY_MAX_EVENTS", 3):
            events = [await self._event(version) for version in range(1, 5)]

        sender = AsyncMock(return_value=True)
        with patch.object(self.manager, "send_json", sender):
            too_old = await self.manager.replay_room(
                object(),
                "VM200001",
                stream=events[-1]["stream"],
                after_sequence=0,
            )
            available = await self.manager.replay_room(
                object(),
                "VM200001",
                stream=events[-1]["stream"],
                after_sequence=1,
            )

        self.assertFalse(too_old)
        self.assertTrue(available)
