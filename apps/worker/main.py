"""NATS JetStream outbox relay and idempotent notification consumer."""

import asyncio
import json
import logging
import os
import random
import signal
import sys
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from threading import Lock, Thread

# Keep the Python control plane as the single model/migration owner.
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "backend"))

import nats
from nats.errors import TimeoutError as NatsTimeoutError
from nats.js import api as js_api
from nats.js.errors import NotFoundError
from pydantic import ValidationError
from sqlalchemy import text

from app.database import SessionLocal, engine
from app.models.event_outbox import EventOutbox
from apps.worker.events import EventEnvelope
from apps.worker.handlers import HANDLERS


NATS_URL = os.getenv("NATS_URL", "nats://127.0.0.1:4222")
STREAM = os.getenv("NATS_STREAM", "FUNKEY_EVENTS")
DLQ_STREAM = os.getenv("NATS_DLQ_STREAM", "FUNKEY_DLQ")
CONSUMER = os.getenv("NATS_CONSUMER", "funkey-worker")
MAX_ATTEMPTS = 5
_logger = logging.getLogger("funkey.worker")


class WorkerState:
    def __init__(self):
        self.ready = False
        self.draining = False
        self.connection = None
        self.processed = 0
        self.duplicates = 0
        self.retries = 0
        self.dead_lettered = 0
        self.outbox_published = 0
        self._lock = Lock()

    def count(self, name: str):
        with self._lock:
            setattr(self, name, getattr(self, name) + 1)

    def metrics(self) -> str:
        with self._lock:
            values = {name: getattr(self, name) for name in (
                "processed", "duplicates", "retries", "dead_lettered", "outbox_published")}
        lines = [f"funkey_worker_{name}_total {value}" for name, value in values.items()]
        lines.append(f"funkey_worker_ready {1 if self.is_ready() else 0}")
        return "\n".join(lines) + "\n"

    def is_ready(self) -> bool:
        return bool(self.ready and not self.draining and self.connection is not None and self.connection.is_connected)


state = WorkerState()


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/live":
            status, body, content_type = 200, b'{"status":"alive"}', "application/json"
        elif self.path == "/ready":
            healthy = state.is_ready()
            if healthy:
                try:
                    with engine.connect() as connection:
                        connection.execute(text("SELECT 1"))
                except Exception:
                    healthy = False
            status = 200 if healthy else 503
            body, content_type = json.dumps({"status": "ready" if healthy else "unavailable"}).encode(), "application/json"
        elif self.path == "/metrics":
            status, body, content_type = 200, state.metrics().encode(), "text/plain; version=0.0.4"
        else:
            status, body, content_type = 404, b"not found", "text/plain"
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format, *_args):
        return


def _row_envelope(row: EventOutbox) -> EventEnvelope:
    return EventEnvelope(
        event_id=row.event_id, event_type=row.event_type,
        event_version=row.event_version, occurred_at=row.occurred_at,
        request_id=row.request_id, trace_id=row.trace_id,
        actor_user_id=row.actor_user_id, payload=row.payload,
    )


async def relay_outbox(js, stop: asyncio.Event):
    while not stop.is_set():
        try:
            # PostgreSQL SKIP LOCKED prevents duplicate concurrent relays.
            with SessionLocal.begin() as db:
                rows = (db.query(EventOutbox)
                    .filter(EventOutbox.published_at.is_(None))
                    .order_by(EventOutbox.occurred_at)
                    .with_for_update(skip_locked=True)
                    .limit(25).all())
                for row in rows:
                    envelope = _row_envelope(row)
                    await js.publish(
                        envelope.subject,
                        envelope.model_dump_json().encode(),
                        headers={"Nats-Msg-Id": str(envelope.event_id)}, timeout=3,
                    )
                    row.published_at = datetime.now(timezone.utc)
                    row.attempt_count += 1
                    state.count("outbox_published")
            await asyncio.sleep(0.25 if rows else 2)
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            _logger.error(json.dumps({"event": "outbox.retry", "error": type(exc).__name__}))
            await asyncio.sleep(3 + random.random() * 2)


async def _dead_letter(js, msg, *, event_id: str, reason: str):
    # The dead-letter stream is durable; ack the source only after publish ack.
    body = json.dumps({"event_id": event_id, "reason": reason,
                       "source_subject": msg.subject,
                       "attempts": msg.metadata.num_delivered if msg.metadata else None}).encode()
    await js.publish("funkey.dlq.notification.requested", body, timeout=3)
    await msg.ack()
    state.count("dead_lettered")


async def process_message(js, msg):
    event_id = "unknown"
    try:
        envelope = EventEnvelope.model_validate_json(msg.data)
        event_id = str(envelope.event_id)
        handler = HANDLERS.get(envelope.event_type)
        if handler is None:
            await msg.ack()
            return
        result = await asyncio.to_thread(handler, envelope)
        await msg.ack()
        state.count("duplicates" if result == "duplicate" else "processed")
    except (ValidationError, ValueError) as exc:
        await _dead_letter(js, msg, event_id=event_id, reason=type(exc).__name__)
    except Exception as exc:
        attempts = msg.metadata.num_delivered if msg.metadata else 1
        if attempts >= MAX_ATTEMPTS:
            try:
                await _dead_letter(js, msg, event_id=event_id, reason=type(exc).__name__)
            except Exception:
                # Never ack before the durable dead-letter publish succeeds.
                await msg.nak(delay=30)
        else:
            delay = min(60, 2 ** attempts + random.random())
            await msg.nak(delay=delay)
            state.count("retries")
        _logger.warning(json.dumps({"event": "job.retry_or_dlq", "event_id": event_id,
                                    "attempt": attempts, "error": type(exc).__name__}))


async def consume(js, subscription, stop: asyncio.Event):
    while not stop.is_set():
        try:
            messages = await subscription.fetch(batch=10, timeout=2)
            for msg in messages:
                if stop.is_set():
                    break
                await process_message(js, msg)
        except NatsTimeoutError:
            continue
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            _logger.error(json.dumps({"event": "consumer.retry", "error": type(exc).__name__}))
            await asyncio.sleep(2 + random.random())


async def run():
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, stop.set)
        except NotImplementedError:  # Windows local development
            signal.signal(sig, lambda *_: loop.call_soon_threadsafe(stop.set))

    health = ThreadingHTTPServer(("0.0.0.0", int(os.getenv("WORKER_HEALTH_PORT", "8082"))), HealthHandler)
    health_thread = Thread(target=health.serve_forever, daemon=True)
    health_thread.start()
    nc = None
    tasks = []
    try:
        nc = await nats.connect(NATS_URL, reconnect_time_wait=2, max_reconnect_attempts=-1)
        state.connection = nc
        js = nc.jetstream(timeout=3)
        try:
            await js.stream_info(STREAM)
        except NotFoundError:
            await js.add_stream(name=STREAM, subjects=["funkey.events.>"], max_age=7 * 86400)
        try:
            await js.stream_info(DLQ_STREAM)
        except NotFoundError:
            await js.add_stream(name=DLQ_STREAM, subjects=["funkey.dlq.>"], max_age=30 * 86400)
        subscription = await js.pull_subscribe(
            "funkey.events.notification.requested", durable=CONSUMER, stream=STREAM,
            config=js_api.ConsumerConfig(
                durable_name=CONSUMER, filter_subject="funkey.events.notification.requested",
                ack_policy=js_api.AckPolicy.EXPLICIT, ack_wait=90,
                max_deliver=1000, max_ack_pending=100,
            ),
        )
        tasks = [asyncio.create_task(relay_outbox(js, stop)), asyncio.create_task(consume(js, subscription, stop))]
        state.ready = True
        stop_waiter = asyncio.create_task(stop.wait())
        done, _ = await asyncio.wait([stop_waiter, *tasks], return_when=asyncio.FIRST_COMPLETED)
        if stop_waiter not in done:
            raise RuntimeError("worker task exited unexpectedly")
    finally:
        state.draining = True
        stop.set()
        for task in tasks:
            task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)
        if nc is not None:
            await nc.drain()
        await asyncio.to_thread(health.shutdown)
        health.server_close()
        engine.dispose()


if __name__ == "__main__":
    asyncio.run(run())
