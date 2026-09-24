from __future__ import annotations
import json, logging, os, signal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Event, Thread
from app.core.config import settings
from app.core.telemetry import configure_telemetry, shutdown_telemetry
from app.services import notification_delivery_service
from database import SessionLocal, engine

_logger=logging.getLogger("funkey.notification-provider"); _stop=Event(); _ready=False
class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path=="/live": status,body=200,b'{"status":"live"}'
        elif self.path=="/ready": status,body=(200,b'{"status":"ready"}') if _ready else (503,b'{"status":"starting"}')
        else: status,body=404,b"not found"
        self.send_response(status); self.send_header("Content-Type","application/json" if body.startswith(b"{") else "text/plain"); self.send_header("Content-Length",str(len(body))); self.end_headers(); self.wfile.write(body)
    def log_message(self,_format,*_args): return
def _signal_handler(*_args): _stop.set()
def run():
    global _ready
    settings.validate_notification_service(); logging.basicConfig(level=logging.INFO,format="%(message)s"); configure_telemetry("funkey-notification-provider",engine=engine)
    signal.signal(signal.SIGINT,_signal_handler); signal.signal(signal.SIGTERM,_signal_handler)
    health=ThreadingHTTPServer(("0.0.0.0",int(os.getenv("NOTIFICATION_PROVIDER_HEALTH_PORT","8091"))),HealthHandler); Thread(target=health.serve_forever,daemon=True).start(); _ready=True
    try:
        while not _stop.is_set():
            with SessionLocal() as db:
                claims=notification_delivery_service.claim_due_deliveries(db,limit=settings.NOTIFICATION_PROVIDER_BATCH_SIZE,lease_seconds=settings.NOTIFICATION_PROVIDER_LEASE_SECONDS)
            for delivery_id,lock_token in claims:
                if _stop.is_set(): break
                try:
                    with SessionLocal() as db: status=notification_delivery_service.process_claimed_delivery(db,delivery_id=delivery_id,lock_token=lock_token)
                    _logger.info(json.dumps({"event":"notification.delivery","delivery_id":delivery_id,"status":status}))
                except Exception as exc:
                    _logger.warning(json.dumps({"event":"notification.delivery.error","delivery_id":delivery_id,"error":type(exc).__name__}))
            _stop.wait(settings.NOTIFICATION_PROVIDER_POLL_SECONDS if not claims else 0.05)
    finally:
        _ready=False; health.shutdown(); health.server_close(); engine.dispose(); shutdown_telemetry()
if __name__=="__main__": run()
