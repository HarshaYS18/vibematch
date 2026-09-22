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
)
from app.core.telemetry import extract_trace_context
from apps.worker.events import EventEnvelope


class TelemetryContractTests(unittest.TestCase):
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
