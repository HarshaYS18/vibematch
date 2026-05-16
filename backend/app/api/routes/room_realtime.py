import json
from collections import defaultdict
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter(tags=["Room Realtime"])

_room_clients: dict[str, set[WebSocket]] = defaultdict(set)
_peer_room: dict[WebSocket, str] = {}
_room_state: dict[str, dict[str, Any]] = {}
_ALLOWED_SEAT_LAYOUT_IDS = {"4x2", "5x2", "4x3", "5x3", "host_4x2", "host_5x2", "host_4x3", "host_5x3"}


def _room(room_id: str) -> dict[str, Any]:
    state = _room_state.setdefault(
        room_id,
        {
            "room_id": room_id,
            "peer_count": 0,
            "peers": [],
            "locked_seat_indexes": [],
            "seat_layout_id": "5x2",
        },
    )
    state["room_id"] = room_id
    return state


def _peer_key(payload: dict[str, Any]) -> str:
    peer_id = str(payload.get("peer_id") or "").strip()
    if peer_id:
        return peer_id
    user_id = str(payload.get("user_id") or "").strip()
    return user_id


def _active_peers(state: dict[str, Any]) -> list[dict[str, Any]]:
    raw = state.get("peers")
    return raw if isinstance(raw, list) else []


def _set_peer(room_id: str, payload: dict[str, Any]) -> None:
    key = _peer_key(payload)
    if not key:
        return
    state = _room(room_id)
    peers = [peer for peer in _active_peers(state) if _peer_key(peer) != key]
    peer = {
        "peer_id": str(payload.get("peer_id") or key),
        "user_id": str(payload.get("user_id") or key),
        "display_name": str(payload.get("display_name") or "Vibe User"),
        "avatar_url": payload.get("avatar_url"),
        "vip_level": int(payload.get("vip_level") or 0),
        "svip_level": int(payload.get("svip_level") or 0),
        "sending_level": int(payload.get("sending_level") or 0),
        "receiving_level": int(payload.get("receiving_level") or 0),
        "is_host": bool(payload.get("is_host")),
        "is_room_admin": bool(payload.get("is_room_admin")) or bool(payload.get("is_host")),
        "role_label": str(payload.get("role_label") or "Member"),
        "seat_index": payload.get("seat_index"),
        "mic_enabled": bool(payload.get("mic_enabled")),
        "admin_muted": bool(payload.get("admin_muted")),
    }
    peers.append(peer)
    state["peers"] = peers
    state["peer_count"] = len(peers)


def _update_peer(room_id: str, peer_key: str, updates: dict[str, Any]) -> None:
    if not peer_key:
        return
    state = _room(room_id)
    for peer in _active_peers(state):
        if _peer_key(peer) == peer_key or peer.get("user_id") == peer_key:
            peer.update(updates)
            break


def _remove_peer(room_id: str, peer_key: str) -> None:
    if not peer_key:
        return
    state = _room(room_id)
    state["peers"] = [peer for peer in _active_peers(state) if _peer_key(peer) != peer_key and peer.get("user_id") != peer_key]
    state["peer_count"] = len(_active_peers(state))


def _take_seat(room_id: str, peer_key: str, seat_index: int) -> None:
    state = _room(room_id)
    locked = set(int(item) for item in state.get("locked_seat_indexes", []) if str(item).lstrip("-").isdigit())
    if seat_index in locked:
        return
    for peer in _active_peers(state):
        if peer.get("seat_index") == seat_index:
            peer["seat_index"] = None
        if _peer_key(peer) == peer_key or peer.get("user_id") == peer_key:
            peer["seat_index"] = seat_index


def _leave_seat(room_id: str, peer_key: str) -> None:
    for peer in _active_peers(_room(room_id)):
        if _peer_key(peer) == peer_key or peer.get("user_id") == peer_key:
            peer["seat_index"] = None


def _lock_seat(room_id: str, seat_index: int, locked: bool) -> None:
    state = _room(room_id)
    locked_indexes = set(int(item) for item in state.get("locked_seat_indexes", []) if str(item).lstrip("-").isdigit())
    if locked:
        locked_indexes.add(seat_index)
        for peer in _active_peers(state):
            if peer.get("seat_index") == seat_index:
                peer["seat_index"] = None
    else:
        locked_indexes.discard(seat_index)
    state["locked_seat_indexes"] = sorted(locked_indexes)


def _set_layout(room_id: str, layout_id: str) -> None:
    safe_layout = layout_id if layout_id in _ALLOWED_SEAT_LAYOUT_IDS else "5x2"
    state = _room(room_id)
    state["seat_layout_id"] = safe_layout
    max_seats = _seat_count_for_layout(safe_layout)
    state["locked_seat_indexes"] = [index for index in state.get("locked_seat_indexes", []) if isinstance(index, int) and index < max_seats]
    for peer in _active_peers(state):
        seat_index = peer.get("seat_index")
        if isinstance(seat_index, int) and seat_index >= max_seats:
            peer["seat_index"] = None


def _seat_count_for_layout(layout_id: str) -> int:
    has_host = layout_id.startswith("host_")
    raw = layout_id.replace("host_", "", 1)
    try:
        columns, rows = raw.split("x", 1)
        count = int(columns) * int(rows)
        return count + (2 if has_host else 0)
    except Exception:
        return 10


async def _broadcast(room_id: str, payload: dict[str, Any]) -> None:
    clients = list(_room_clients.get(room_id, set()))
    for client in clients:
        try:
            await client.send_json(payload)
        except Exception:
            _room_clients[room_id].discard(client)
            _peer_room.pop(client, None)


async def _broadcast_room_state(room_id: str, event_type: str, extra: dict[str, Any] | None = None) -> None:
    state = _room(room_id)
    payload = {"room_id": room_id, "room": state}
    if extra:
        payload.update(extra)
    await _broadcast(room_id, {"type": event_type, "payload": payload})


@router.websocket("/ws/room-realtime")
async def room_realtime_socket(websocket: WebSocket) -> None:
    await websocket.accept()
    active_room_id: str | None = None
    active_peer_key: str = ""
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
                active_peer_key = _peer_key(payload)
                _set_peer(room_id, payload)
                await _broadcast_room_state(room_id, "room/joined")
                continue

            if event_type == "room/leave":
                _remove_peer(room_id, active_peer_key)
                await _broadcast_room_state(room_id, "room/peer_left")
                continue

            if event_type == "seat/take":
                seat_index = int(payload.get("seat_index") or -1)
                _take_seat(room_id, active_peer_key, seat_index)
                await _broadcast_room_state(room_id, "seat/updated")
                continue

            if event_type == "seat/leave":
                _leave_seat(room_id, active_peer_key)
                await _broadcast_room_state(room_id, "seat/updated")
                continue

            if event_type == "admin/seat_assign":
                target_user_id = str(payload.get("target_user_id") or "")
                seat_index = int(payload.get("seat_index") or -1)
                _take_seat(room_id, target_user_id, seat_index)
                await _broadcast_room_state(room_id, "seat/updated")
                continue

            if event_type in {"admin/seat_leave", "admin/seat_leave_lock"}:
                target_user_id = str(payload.get("target_user_id") or "")
                seat_index = int(payload.get("seat_index") or -1)
                _leave_seat(room_id, target_user_id)
                if event_type == "admin/seat_leave_lock" and seat_index >= 0:
                    _lock_seat(room_id, seat_index, True)
                await _broadcast_room_state(room_id, "seat/updated")
                continue

            if event_type == "admin/seat_lock":
                seat_index = int(payload.get("seat_index") or -1)
                if seat_index >= 0:
                    _lock_seat(room_id, seat_index, True)
                await _broadcast_room_state(room_id, "seat/updated")
                continue

            if event_type == "admin/seat_unlock":
                seat_index = int(payload.get("seat_index") or -1)
                if seat_index >= 0:
                    _lock_seat(room_id, seat_index, False)
                await _broadcast_room_state(room_id, "seat/updated")
                continue

            if event_type == "mic/set_enabled":
                _update_peer(room_id, active_peer_key, {"mic_enabled": payload.get("enabled") == True})
                await _broadcast_room_state(room_id, "seat/updated")
                continue

            if event_type == "admin_mute/set":
                target_user_id = str(payload.get("target_user_id") or "")
                muted = payload.get("muted") == True
                _update_peer(room_id, target_user_id, {"admin_muted": muted, "mic_enabled": False if muted else None})
                await _broadcast_room_state(room_id, "admin_mute/updated", {"target_user_id": target_user_id, "admin_muted": muted})
                continue

            if event_type == "room_settings/seat_layout":
                layout_id = str(payload.get("seat_layout_id") or "5x2").strip()
                _set_layout(room_id, layout_id)
                await _broadcast_room_state(room_id, "room_settings/updated", {"seat_layout_id": _room(room_id).get("seat_layout_id")})
                continue

            if event_type == "room_settings/background_theme":
                await _broadcast(room_id, {"type": "room_settings/updated", "payload": {"room_id": room_id, "background_theme_id": payload.get("background_theme_id"), "room": _room(room_id)}})
                continue

            if event_type.startswith("room_settings/"):
                await _broadcast(room_id, {"type": "room_settings/updated", "payload": {"room_id": room_id, **payload, "room": _room(room_id)}})
                continue

            await _broadcast(room_id, {"type": event_type, "payload": payload})
    except WebSocketDisconnect:
        pass
    finally:
        room_id = active_room_id or _peer_room.get(websocket)
        if room_id:
            _room_clients[room_id].discard(websocket)
            if active_peer_key:
                _remove_peer(room_id, active_peer_key)
            await _broadcast_room_state(room_id, "room/peer_left")
        _peer_room.pop(websocket, None)