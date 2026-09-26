"""Chunk 45 realtime/media QoS guard."""
from __future__ import annotations
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def require(path, markers):
    p=ROOT/path
    if not p.is_file(): raise SystemExit(f"missing QoS file: {path}")
    text=p.read_text(encoding="utf-8")
    for marker in markers:
        if marker not in text: raise SystemExit(f"{path} missing {marker}")
    return text

def main():
    policy=json.loads((ROOT/"contracts/realtime/qos-v1.json").read_text())
    if policy["realtime"]["local_route_shards"] < 16: raise SystemExit("realtime sharding too small")
    if policy["targets"]["realtime_event_propagation_p95_ms"] > 200: raise SystemExit("realtime p95 target regressed")
    require("apps/realtime-gateway/internal/gateway/hub.go",("defaultHubShardCount = 32","funkey_realtime_hot_rooms","deliveryCritical"))
    require("backend_media/src/mediasoup/roomManager.ts",("hotRoomCount","initialAvailableOutgoingBitrate","preferUdp: true"))
    require("backend_media/src/signaling/metrics.ts",("joinDurationBucketsMs","durationObservations"))
    require("docs/architecture/realtime-media-qos.md",("hot room","QoS"))
    require("docs/runbooks/realtime-media-qos.md",("packet","TURN"))
    print("Realtime/media QoS guard: OK")
if __name__=="__main__": main()
