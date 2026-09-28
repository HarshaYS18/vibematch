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
from app.services import economy_bulk_grant_service, economy_reconciliation_service, lucky_packet_service
from bulk_database import SessionLocal, engine


WORKER_ID = os.getenv("ECONOMY_BULK_WORKER_ID") or f"{socket.gethostname()}-{os.getpid()}"
HEALTH_PORT = int(os.getenv("ECONOMY_BULK_HEALTH_PORT", "8090"))
_stop = threading.Event()
_ready = False
_batches = 0
_failures = 0
_reconciliation_runs = 0
_reconciliation_failures = 0
_reconciliation_wallet_mismatches = 0
_reconciliation_supply_pool_mismatches = 0
_reconciliation_game_pool_mismatches = 0
_reconciliation_reservation_mismatches = 0
_reconciliation_unbalanced_journals = 0
_lucky_packet_finalizations = 0
_lucky_packet_finalize_failures = 0


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
                f"funkey_economy_reconciliation_runs_total {_reconciliation_runs}\n"
                f"funkey_economy_reconciliation_failures_total {_reconciliation_failures}\n"
                f"funkey_economy_reconciliation_wallet_mismatches {_reconciliation_wallet_mismatches}\n"
                f"funkey_economy_reconciliation_supply_pool_mismatches {_reconciliation_supply_pool_mismatches}\n"
                f"funkey_economy_reconciliation_game_pool_mismatches {_reconciliation_game_pool_mismatches}\n"
                f"funkey_economy_reconciliation_reservation_mismatches {_reconciliation_reservation_mismatches}\n"
                f"funkey_economy_reconciliation_unbalanced_journals {_reconciliation_unbalanced_journals}\n"
                f"funkey_economy_lucky_packet_finalizations_total {_lucky_packet_finalizations}\n"
                f"funkey_economy_lucky_packet_finalize_failures_total {_lucky_packet_finalize_failures}\n"
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
    global _reconciliation_runs, _reconciliation_failures
    global _reconciliation_wallet_mismatches, _reconciliation_supply_pool_mismatches
    global _reconciliation_game_pool_mismatches, _reconciliation_reservation_mismatches
    global _reconciliation_unbalanced_journals
    global _lucky_packet_finalizations, _lucky_packet_finalize_failures
    settings.validate_economy_service()
    settings.validate_economy_bulk_worker()

    signal.signal(signal.SIGTERM, _handle_signal)
    signal.signal(signal.SIGINT, _handle_signal)

    health = ThreadingHTTPServer(("0.0.0.0", HEALTH_PORT), HealthHandler)
    health_thread = threading.Thread(target=health.serve_forever, daemon=True)
    health_thread.start()
    _ready = True
    next_reconciliation_at = 0.0

    try:
        while not _stop.is_set():
            now = time.monotonic()
            if now >= next_reconciliation_at:
                try:
                    with SessionLocal() as db:
                        report = economy_reconciliation_service.reconcile(
                            db,
                            wallet_limit=settings.ECONOMY_RECONCILIATION_WALLET_BATCH_SIZE,
                            pool_limit=settings.ECONOMY_RECONCILIATION_POOL_BATCH_SIZE,
                            journal_transaction_limit=settings.ECONOMY_RECONCILIATION_JOURNAL_BATCH_SIZE,
                        )
                    _reconciliation_runs += 1
                    _reconciliation_wallet_mismatches = report.wallet_mismatches
                    _reconciliation_supply_pool_mismatches = report.supply_pool_mismatches
                    _reconciliation_game_pool_mismatches = report.game_pool_mismatches
                    _reconciliation_reservation_mismatches = report.reservation_mismatches
                    _reconciliation_unbalanced_journals = report.unbalanced_journal_transactions
                    if not report.healthy:
                        _reconciliation_failures += 1
                except Exception:
                    _reconciliation_failures += 1

                try:
                    with SessionLocal() as db:
                        finalized_packets = lucky_packet_service.finalize_expired_packets(
                            db,
                            limit=settings.ECONOMY_LUCKY_PACKET_FINALIZE_BATCH_SIZE,
                        )
                    _lucky_packet_finalizations += finalized_packets
                except Exception:
                    _lucky_packet_finalize_failures += 1

                next_reconciliation_at = (
                    time.monotonic()
                    + settings.ECONOMY_RECONCILIATION_INTERVAL_SECONDS
                )
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
