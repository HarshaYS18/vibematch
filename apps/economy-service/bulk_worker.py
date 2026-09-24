from __future__ import annotations

import json
import os
import signal
import socket
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from sqlalchemy import text

from app.core.config import settings
from app.services import economy_bulk_grant_service
from bulk_database import SessionLocal, engine


WORKER_ID = os.getenv("ECONOMY_BULK_WORKER_ID") or f"{socket.gethostname()}-{os.getpid()}"
HEALTH_PORT = int(os.getenv("ECONOMY_BULK_HEALTH_PORT", "8090"))
_stop = threading.Event()
_ready = False
_batches = 0
_failures = 0


class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        global _ready
        if self.path == "/live":
            status, payload = 200, {"status": "alive"}
        elif self.path == "/ready":
            healthy = _ready
            if healthy:
                try:
                    with engine.connect() as connection:
                        connection.execute(text("SELECT 1"))
                except Exception:
                    healthy = False
            status, payload = (200 if healthy else 503), {
                "status": "ready" if healthy else "unavailable"
            }
        elif self.path == "/metrics":
            body = (
                f"funkey_economy_bulk_worker_ready {1 if _ready else 0}\n"
                f"funkey_economy_bulk_worker_batches_total {_batches}\n"
                f"funkey_economy_bulk_worker_failures_total {_failures}\n"
            ).encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        else:
            status, payload = 404, {"detail": "not found"}
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, _format, *_args):
        return


def _handle_signal(_signum, _frame):
    _stop.set()


def main() -> None:
    global _ready, _batches, _failures
    settings.validate_economy_service()
    settings.validate_economy_bulk_worker()

    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    health = ThreadingHTTPServer(("0.0.0.0", HEALTH_PORT), HealthHandler)
    health_thread = threading.Thread(target=health.serve_forever, daemon=True)
    health_thread.start()
    _ready = True

    try:
        while not _stop.is_set():
            with SessionLocal() as db:
                job_id = economy_bulk_grant_service.claim_next_job(
                    db,
                    worker_id=WORKER_ID,
                    lease_seconds=settings.ECONOMY_BULK_LEASE_SECONDS,
                )
            if job_id is None:
                _stop.wait(settings.ECONOMY_BULK_POLL_SECONDS)
                continue

            try:
                with SessionLocal() as db:
                    economy_bulk_grant_service.process_claimed_batch(
                        db,
                        job_id=job_id,
                        worker_id=WORKER_ID,
                        batch_size=settings.ECONOMY_BULK_BATCH_SIZE,
                    )
                _batches += 1
            except Exception as exc:
                _failures += 1
                with SessionLocal() as db:
                    economy_bulk_grant_service.mark_attempt_failed(
                        db,
                        job_id=job_id,
                        worker_id=WORKER_ID,
                        error=type(exc).__name__ + ": " + str(exc),
                    )
                _stop.wait(min(settings.ECONOMY_BULK_POLL_SECONDS * 2, 5.0))
    finally:
        _ready = False
        health.shutdown()
        health.server_close()
        engine.dispose()


if __name__ == "__main__":
    main()
