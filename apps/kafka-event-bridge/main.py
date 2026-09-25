"""Production runtime for the FunKey NATS -> Kafka analytics bridge."""

from __future__ import annotations

import asyncio
import json
import logging
import signal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Thread

import nats
from aiokafka import AIOKafkaProducer
from nats.js import api as js_api

from bridge import consume_loop
from config import Settings
from metrics import render, set_source_lag

_logger = logging.getLogger("funkey.kafka_bridge")


class RuntimeState:
    def __init__(self) -> None:
        self.ready = False
        self.nats_connection = None
        self.kafka_ready = False

    def is_ready(self) -> bool:
        return bool(
            self.ready
            and self.kafka_ready
            and self.nats_connection is not None
            and self.nats_connection.is_connected
        )


state = RuntimeState()


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path == "/live":
            status, body, content_type = 200, b'{"status":"alive"}', "application/json"
        elif self.path == "/ready":
            healthy = state.is_ready()
            status = 200 if healthy else 503
            body = json.dumps({"status": "ready" if healthy else "unavailable"}).encode()
            content_type = "application/json"
        elif self.path == "/metrics":
            nats_connected = bool(
                state.nats_connection is not None and state.nats_connection.is_connected
            )
            body = render(
                ready=state.is_ready(),
                nats_connected=nats_connected,
                kafka_ready=state.kafka_ready,
            ).encode()
            status, content_type = 200, "text/plain; version=0.0.4"
        else:
            status, body, content_type = 404, b"not found", "text/plain"

        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format: str, *_args) -> None:
        return


async def monitor_source_lag(js, settings: Settings, stop: asyncio.Event) -> None:
    """Expose JetStream durable backlog without high-cardinality labels."""
    while not stop.is_set():
        try:
            info = await js.consumer_info(settings.nats_stream, settings.nats_durable)
            set_source_lag(
                pending=getattr(info, "num_pending", 0),
                ack_pending=getattr(info, "num_ack_pending", 0),
                redelivered=getattr(info, "num_redelivered", 0),
            )
        except asyncio.CancelledError:
            raise
        except Exception:
            pass
        try:
            await asyncio.wait_for(stop.wait(), timeout=5)
        except asyncio.TimeoutError:
            pass


async def run() -> None:
    settings = Settings.from_env()
    settings.validate()
    logging.basicConfig(level=logging.INFO, format="%(message)s")

    stop = asyncio.Event()
    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, stop.set)
        except NotImplementedError:
            signal.signal(sig, lambda *_: loop.call_soon_threadsafe(stop.set))

    health = ThreadingHTTPServer(("0.0.0.0", settings.bridge_health_port), HealthHandler)
    Thread(target=health.serve_forever, daemon=True).start()

    producer = AIOKafkaProducer(
        **settings.kafka_client_kwargs(),
        acks="all",
        enable_idempotence=True,
        max_batch_size=131072,
        linger_ms=5,
        request_timeout_ms=10000,
    )
    nc = None
    task = None
    lag_task = None
    try:
        await producer.start()
        state.kafka_ready = True

        nc = await nats.connect(
            settings.nats_url,
            reconnect_time_wait=2,
            max_reconnect_attempts=-1,
        )
        state.nats_connection = nc
        js = nc.jetstream(timeout=3)

        subscription = await js.pull_subscribe(
            "funkey.events.>",
            durable=settings.nats_durable,
            stream=settings.nats_stream,
            config=js_api.ConsumerConfig(
                durable_name=settings.nats_durable,
                filter_subject="funkey.events.>",
                ack_policy=js_api.AckPolicy.EXPLICIT,
                ack_wait=120,
                max_ack_pending=max(settings.bridge_batch_size * 4, settings.bridge_max_in_flight),
            ),
        )

        state.ready = True
        _logger.info(json.dumps({
            "event": "kafka_bridge.ready",
            "nats_stream": settings.nats_stream,
            "durable": settings.nats_durable,
            "batch_size": settings.bridge_batch_size,
            "max_in_flight": settings.bridge_max_in_flight,
        }))

        lag_task = asyncio.create_task(monitor_source_lag(js, settings, stop))
        task = asyncio.create_task(
            consume_loop(
                js,
                subscription,
                producer,
                stop,
                batch_size=settings.bridge_batch_size,
                max_in_flight=settings.bridge_max_in_flight,
                nak_delay_seconds=settings.bridge_nak_delay_seconds,
            )
        )
        stop_task = asyncio.create_task(stop.wait())
        done, _ = await asyncio.wait([task, stop_task], return_when=asyncio.FIRST_COMPLETED)
        if task in done and not stop.is_set():
            raise RuntimeError("Kafka bridge consumer loop exited unexpectedly")
    finally:
        state.ready = False
        stop.set()
        if task is not None:
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)
        if lag_task is not None:
            lag_task.cancel()
            await asyncio.gather(lag_task, return_exceptions=True)
        if nc is not None:
            await nc.drain()
        state.nats_connection = None
        state.kafka_ready = False
        await producer.stop()
        await asyncio.to_thread(health.shutdown)
        health.server_close()


if __name__ == "__main__":
    asyncio.run(run())
