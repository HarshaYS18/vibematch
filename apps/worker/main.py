"""NATS JetStream outbox relay and idempotent notification consumer."""

import asyncio
import json
import logging
import os
import random
import signal
import socket
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
from opentelemetry.trace import SpanKind

from app.core.telemetry import configure_telemetry, current_traceparent, shutdown_telemetry, traced
from app.database import SessionLocal, engine
from app.services import outbox_relay_service
from apps.worker.events import EventEnvelope
from apps.worker.handlers import HANDLERS
from apps.worker.pools import get_pool


NATS_URL = os.getenv("NATS_URL", "nats://127.0.0.1:4222")
STREAM = os.getenv("NATS_STREAM", "FUNKEY_EVENTS")
DLQ_STREAM = os.getenv("NATS_DLQ_STREAM", "FUNKEY_DLQ")
POOL = get_pool(os.getenv("WORKER_POOL", "general"))
MAX_ATTEMPTS = max(1, min(int(os.getenv("WORKER_MAX_ATTEMPTS", "5")), 20))
OUTBOX_BATCH_SIZE = max(1, min(int(os.getenv("OUTBOX_BATCH_SIZE", "25")), 500))
OUTBOX_LEASE_SECONDS = max(30, min(int(os.getenv("OUTBOX_LEASE_SECONDS", "120")), 900))
SHUTDOWN_GRACE_SECONDS = max(
    5.0,
    min(float(os.getenv("WORKER_SHUTDOWN_GRACE_SECONDS", "30")), 300.0),
)
WORKER_INSTANCE_ID = os.getenv("WORKER_INSTANCE_ID") or f"{socket.gethostname()}-{os.getpid()}"
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
        self.outbox_retries = 0
        self.in_flight = 0
        self._lock = Lock()

    def count(self, name: str, amount: int = 1):
        with self._lock:
            setattr(self, name, getattr(self, name) + amount)

    def metrics(self) -> str:
        with self._lock:
            values = {name: getattr(self, name) for name in (
                "processed", "duplicates", "retries", "dead_lettered",
                "outbox_published", "outbox_retries")}
            in_flight = self.in_flight
        lines = [f'funkey_worker_pool_info{{pool="{POOL.name}"}} 1']
        lines.extend(f'funkey_worker_{name}_total{{pool="{POOL.name}"}} {value}' for name, value in values.items())
        lines.append(f'funkey_worker_in_flight{{pool="{POOL.name}"}} {in_flight}')
        lines.append(f'funkey_worker_ready{{pool="{POOL.name}"}} {1 if self.is_ready() else 0}')
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


def _claim_envelope(claim: outbox_relay_service.ClaimedOutboxEvent) -> EventEnvelope:
    return EventEnvelope(
        event_id=claim.event_id,
        event_type=claim.event_type,
        event_version=claim.event_version,
        occurred_at=claim.occurred_at,
        request_id=claim.request_id,
        trace_id=claim.trace_id,
        traceparent=claim.traceparent,
        actor_user_id=claim.actor_user_id,
        payload=claim.payload,
    )


async def relay_outbox(js, stop: asyncio.Event):
    while not stop.is_set():
        try:
            claims = await asyncio.to_thread(
                outbox_relay_service.claim_outbox_batch,
                WORKER_INSTANCE_ID,
                limit=OUTBOX_BATCH_SIZE,
                lease_seconds=OUTBOX_LEASE_SECONDS,
            )
            for claim in claims:
                envelope = _claim_envelope(claim)
                try:
                    with traced(
                        "worker.outbox.publish",
                        traceparent=envelope.traceparent,
                        kind=SpanKind.PRODUCER,
                        attributes={
                            "messaging.system": "nats",
                            "messaging.destination.name": envelope.subject,
                            "funkey.event_type": envelope.event_type,
                            "funkey.worker_pool": POOL.name,
                        },
                    ):
                        headers = {"Nats-Msg-Id": str(envelope.event_id)}
                        propagated = current_traceparent()
                        if propagated:
                            headers["traceparent"] = propagated
                        if envelope.request_id:
                            headers["x-request-id"] = envelope.request_id
                        await js.publish(
                            envelope.subject,
                            envelope.model_dump_json().encode(),
                            headers=headers,
                            timeout=3,
                        )
                    marked = await asyncio.to_thread(
                        outbox_relay_service.mark_outbox_published,
                        claim.event_id,
                        WORKER_INSTANCE_ID,
                    )
                    if marked:
                        state.count("outbox_published")
                    else:
                        _logger.warning(json.dumps({
                            "event": "outbox.publish_mark_lost",
                            "pool": POOL.name,
                            "event_id": claim.event_id,
                        }))
                except asyncio.CancelledError:
                    raise
                except Exception as exc:
                    delay = min(300.0, (2 ** min(claim.attempt_count, 8)) + random.random())
                    await asyncio.to_thread(
                        outbox_relay_service.release_outbox_claim,
                        claim.event_id,
                        WORKER_INSTANCE_ID,
                        error=type(exc).__name__,
                        delay_seconds=delay,
                    )
                    state.count("outbox_retries")
                    _logger.warning(json.dumps({
                        "event": "outbox.retry",
                        "pool": POOL.name,
                        "event_id": claim.event_id,
                        "attempt": claim.attempt_count,
                        "error": type(exc).__name__,
                        "delay_seconds": round(delay, 2),
                    }))
            await asyncio.sleep(0.25 if claims else 2)
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            _logger.error(json.dumps({"event": "outbox.claim_retry", "pool": POOL.name, "error": type(exc).__name__}))
            await asyncio.sleep(3 + random.random() * 2)


async def _dead_letter(js, msg, *, event_id: str, event_type: str | None, reason: str):
    # The dead-letter stream is durable; ack the source only after publish ack.
    suffix = event_type if event_type and "." in event_type else "invalid"
    body = json.dumps({"event_id": event_id, "event_type": event_type, "pool": POOL.name,
                       "reason": reason, "source_subject": msg.subject,
                       "attempts": msg.metadata.num_delivered if msg.metadata else None}).encode()
    await js.publish(f"funkey.dlq.{suffix}", body, timeout=3)
    await msg.ack()
    state.count("dead_lettered")


async def process_message(js, msg, slots: asyncio.Semaphore):
    event_id = "unknown"
    event_type = None
    try:
        envelope = EventEnvelope.model_validate_json(msg.data)
        event_id = str(envelope.event_id)
        event_type = envelope.event_type
        if envelope.event_type not in POOL.allowed_handlers:
            await _dead_letter(js, msg, event_id=event_id, event_type=event_type, reason="unsupported_pool_event")
            return
        handler = HANDLERS.get(envelope.event_type)
        if handler is None:
            await _dead_letter(js, msg, event_id=event_id, event_type=event_type, reason="missing_handler")
            return
        incoming_traceparent = None
        if msg.headers:
            incoming_traceparent = msg.headers.get("traceparent")
        async with slots:
            with traced(
                "worker.message.consume",
                traceparent=incoming_traceparent or envelope.traceparent,
                kind=SpanKind.CONSUMER,
                attributes={
                    "messaging.system": "nats",
                    "messaging.destination.name": msg.subject,
                    "funkey.event_type": envelope.event_type,
                    "funkey.worker_pool": POOL.name,
                },
            ):
                state.count("in_flight")
                try:
                    result = await asyncio.to_thread(handler, envelope)
                    await msg.ack()
                finally:
                    state.count("in_flight", -1)
        state.count("duplicates" if result == "duplicate" else "processed")
        _logger.info(json.dumps({"event": "job.completed", "pool": POOL.name,
                                "event_id": event_id, "event_type": event_type, "result": result}))
    except (ValidationError, ValueError) as exc:
        await _dead_letter(js, msg, event_id=event_id, event_type=event_type, reason=type(exc).__name__)
    except Exception as exc:
        attempts = msg.metadata.num_delivered if msg.metadata else 1
        if attempts >= MAX_ATTEMPTS:
            try:
                await _dead_letter(js, msg, event_id=event_id, event_type=event_type, reason=type(exc).__name__)
            except Exception:
                # Never ack before the durable dead-letter publish succeeds.
                await msg.nak(delay=30)
        else:
            delay = min(60, 2 ** attempts + random.random())
            await msg.nak(delay=delay)
            state.count("retries")
        _logger.warning(json.dumps({"event": "job.retry_or_dlq", "pool": POOL.name,
                                    "event_id": event_id, "event_type": event_type,
                                    "attempt": attempts, "error": type(exc).__name__}))


async def consume(
    js,
    subscription,
    stop: asyncio.Event,
    slots: asyncio.Semaphore,
):
    while not stop.is_set():
        try:
            messages = await subscription.fetch(batch=max(1, min(POOL.max_in_flight, 50)), timeout=2)
            await asyncio.gather(*[
                process_message(js, msg, slots)
                for msg in messages
                if not stop.is_set()
            ])
        except NatsTimeoutError:
            continue
        except asyncio.CancelledError:
            raise
        except Exception as exc:
            _logger.error(json.dumps({"event": "consumer.retry", "pool": POOL.name, "error": type(exc).__name__}))
            await asyncio.sleep(2 + random.random())


async def run():
    settings.validate_worker_runtime()
    if not POOL.active:
        raise RuntimeError(
            f"WORKER_POOL={POOL.name} is intentionally inactive until its transport is configured"
        )
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    configure_telemetry(f"funkey-worker-{POOL.name}", engine=engine)
    stop = asyncio.Event()
    slots = asyncio.Semaphore(max(1, POOL.max_in_flight))
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
        if POOL.relay_outbox:
            tasks.append(asyncio.create_task(relay_outbox(js, stop)))
        for spec in POOL.subscriptions:
            subscription = await js.pull_subscribe(
                spec.subject, durable=spec.durable_name, stream=STREAM,
                config=js_api.ConsumerConfig(
                    durable_name=spec.durable_name, filter_subject=spec.subject,
                    ack_policy=js_api.AckPolicy.EXPLICIT, ack_wait=spec.ack_wait_seconds,
                    max_deliver=MAX_ATTEMPTS, max_ack_pending=spec.max_ack_pending,
                ),
            )
            tasks.append(
                asyncio.create_task(consume(js, subscription, stop, slots))
            )
        state.ready = True
        _logger.info(json.dumps({"event": "worker.ready", "pool": POOL.name,
                                "subscriptions": [s.subject for s in POOL.subscriptions],
                                "relay_outbox": POOL.relay_outbox}))
        if tasks:
            stop_waiter = asyncio.create_task(stop.wait())
            done, _ = await asyncio.wait([stop_waiter, *tasks], return_when=asyncio.FIRST_COMPLETED)
            if stop_waiter not in done:
                raise RuntimeError("worker task exited unexpectedly")
        else:
            await stop.wait()
    finally:
        state.ready = False
        state.draining = True
        stop.set()
        if tasks:
            done, pending = await asyncio.wait(tasks, timeout=SHUTDOWN_GRACE_SECONDS)
            if pending:
                _logger.warning(json.dumps({
                    "event": "worker.shutdown_timeout",
                    "pool": POOL.name,
                    "pending_tasks": len(pending),
                    "grace_seconds": SHUTDOWN_GRACE_SECONDS,
                }))
                for task in pending:
                    task.cancel()
                await asyncio.gather(*pending, return_exceptions=True)
            if done:
                await asyncio.gather(*done, return_exceptions=True)
        if nc is not None:
            await nc.drain()
        await asyncio.to_thread(health.shutdown)
        health.server_close()
        engine.dispose()
        shutdown_telemetry()


if __name__ == "__main__":
    asyncio.run(run())
