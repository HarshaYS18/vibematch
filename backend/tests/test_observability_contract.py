import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from opentelemetry import trace
from sqlalchemy import create_engine, text

from app.core.operational import (
    begin_query_count,
    current_query_count,
    end_query_count,
    install_query_counter,
    standard_flow_name,
)
from app.core.telemetry import extract_trace_context
from apps.worker.events import EventEnvelope


class TelemetryContractTests(unittest.TestCase):
    def test_standard_business_flow_names_are_low_cardinality(self):
        cases = {
            ("POST", "/api/v1/auth/google-login"): "auth.login",
            ("GET", "/api/v1/home-banners"): "home.load",
            ("POST", "/api/v1/rooms/{room_public_id}/realtime/join"): "room.join",
            ("POST", "/api/v1/rooms/{room_public_id}/realtime/seat/take"): "room.seat.change",
            ("POST", "/api/v1/economy/gifts/send"): "gift.send",
            ("POST", "/api/v1/inbox/conversations/{conversation_id}/messages"): "inbox.send",
            ("GET", "/api/v1/vibes/feed"): "vibes.load",
            ("POST", "/api/v1/rooms/{room_public_id}/realtime/watch-party/command"): "watch_party.command",
            ("POST", "/api/v1/games/{game_key}/rounds"): "game.start",
            ("POST", "/api/v1/media/avatar"): "media.upload",
            ("POST", "/api/v1/wallets/recharge"): "wallet.mutate",
        }
        for (method, path), expected in cases.items():
            with self.subTest(method=method, path=path):
                self.assertEqual(expected, standard_flow_name(method, path))

    def test_query_counter_is_context_scoped(self):
        engine = create_engine("sqlite:///:memory:")
        install_query_counter(engine)
        token = begin_query_count()
        try:
            with engine.connect() as connection:
                connection.execute(text("SELECT 1"))
                connection.execute(text("SELECT 2"))
            self.assertEqual(2, current_query_count())
        finally:
            end_query_count(token)
            engine.dispose()
        self.assertEqual(0, current_query_count())

    def test_traceparent_extracts_valid_parent_context(self):
        raw = "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01"
        context = extract_trace_context(raw)
        span_context = trace.get_current_span(context).get_span_context()
        self.assertTrue(span_context.is_valid)
        self.assertEqual("0123456789abcdef0123456789abcdef", f"{span_context.trace_id:032x}")
        self.assertEqual("0123456789abcdef", f"{span_context.span_id:016x}")

    def test_event_envelope_preserves_traceparent(self):
        envelope = EventEnvelope.model_validate({
            "event_id": "12345678-1234-5678-1234-567812345678",
            "event_type": "notification.requested",
            "event_version": 1,
            "occurred_at": "2026-09-23T00:00:00+00:00",
            "trace_id": "0123456789abcdef0123456789abcdef",
            "traceparent": "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
            "payload": {},
        })
        self.assertEqual(
            "00-0123456789abcdef0123456789abcdef-0123456789abcdef-01",
            envelope.traceparent,
        )


if __name__ == "__main__":
    unittest.main()
