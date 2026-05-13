import json
from collections import defaultdict
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter(tags=["Room Realtime"])

_room_clients: dict[str, set[WebSocket]] = defaultdict(set)
_peer_room: dict[WebSocket, str] = {}


async def _broadcast(room_id: str, payload: dict[str, Any]) -> None:
    clients = list(_room_clients.get(room_id, set()))
    for client in clients:
        try:
            await client.send_json(payload)
        except Exception:
            _room_clients[room_id].discard(client)
            _peer_room.pop(client, None)


@router.websocket("/ws/room-realtime")
async def room_realtime_socket(websocket: WebSocket) -> None:
    await websocket.accept()
    active_room_id: str | None = None
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                message = json.loads(raw)
            except json.JSONDecodeError:
                continue

            event_type = str(message.get("type") or "unknown")
            payload = message.get("payload") if isinstance(message.get("payload"), dict) else {}
            room_id = str(payload.get("room_id") or active_room_id or "").strip()
            if not room_id:
                continue

            if active_room_id is None:
                active_room_id = room_id
                _room_clients[room_id].add(websocket)
                _peer_room[websocket] = room_id

            if event_type == "room/join":
                await _broadcast(room_id, {"type": "room/joined", "payload": {"room_id": room_id, "room": {"room_id": room_id, "peer_count": len(_room_clients[room_id]), "peers": [], "locked_seat_indexes": []}}})
                continue

            await _broadcast(room_id, {"type": event_type, "payload": payload})
    except WebSocketDisconnect:
        pass
    finally:
        room_id = active_room_id or _peer_room.get(websocket)
        if room_id:
            _room_clients[room_id].discard(websocket)
            await _broadcast(room_id, {"type": "room/peer_left", "payload": {"room_id": room_id, "peer_count": len(_room_clients[room_id])}})
        _peer_room.pop(websocket, None)
