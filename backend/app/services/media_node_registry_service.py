from __future__ import annotations

import json
import time
from dataclasses import asdict, dataclass

from redis import Redis
from redis.exceptions import RedisError

from app.core.config import settings


NODE_PREFIX = "funkey:media:nodes:"
ROOM_PREFIX = "funkey:media:rooms:"


class MediaNodeUnavailable(RuntimeError):
    pass


@dataclass(frozen=True)
class MediaNode:
    node_id: str
    public_url: str
    room_count: int
    peer_count: int
    max_rooms: int
    max_peers: int
    draining: bool
    updated_at: float

    @property
    def room_load(self) -> float:
        return self.room_count / max(self.max_rooms, 1)

    @property
    def peer_load(self) -> float:
        return self.peer_count / max(self.max_peers, 1)

    @property
    def load_score(self) -> float:
        return max(self.room_load, self.peer_load)

    @property
    def has_capacity(self) -> bool:
        return (
            not self.draining
            and self.room_count < self.max_rooms
            and self.peer_count < self.max_peers
        )


def _node_key(node_id: str) -> str:
    return f"{NODE_PREFIX}{node_id}"


def _room_key(room_public_id: str) -> str:
    return f"{ROOM_PREFIX}{room_public_id}"


def _decode_node(raw: str | bytes | None) -> MediaNode | None:
    if raw is None:
        return None
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8")
    try:
        payload = json.loads(raw)
        return MediaNode(
            node_id=str(payload["node_id"]),
            public_url=str(payload["public_url"]).rstrip("/"),
            room_count=max(int(payload.get("room_count", 0)), 0),
            peer_count=max(int(payload.get("peer_count", 0)), 0),
            max_rooms=max(int(payload.get("max_rooms", 1)), 1),
            max_peers=max(int(payload.get("max_peers", 1)), 1),
            draining=bool(payload.get("draining", False)),
            updated_at=float(payload.get("updated_at", 0)),
        )
    except (KeyError, TypeError, ValueError, json.JSONDecodeError):
        return None


def get_node(redis: Redis, node_id: str) -> MediaNode | None:
    try:
        return _decode_node(redis.get(_node_key(node_id)))
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc


def list_nodes(redis: Redis) -> list[MediaNode]:
    try:
        nodes: list[MediaNode] = []
        for key in redis.scan_iter(match=f"{NODE_PREFIX}*"):
            node = _decode_node(redis.get(key))
            if node is not None:
                nodes.append(node)
        return sorted(nodes, key=lambda item: (item.draining, item.load_score, item.node_id))
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc


def heartbeat_node(
    redis: Redis,
    *,
    node_id: str,
    public_url: str,
    room_count: int,
    peer_count: int,
    max_rooms: int,
    max_peers: int,
    room_ids: list[str],
) -> MediaNode:
    existing = get_node(redis, node_id)
    node = MediaNode(
        node_id=node_id,
        public_url=public_url.rstrip("/"),
        room_count=max(room_count, 0),
        peer_count=max(peer_count, 0),
        max_rooms=max(max_rooms, 1),
        max_peers=max(max_peers, 1),
        draining=existing.draining if existing is not None else False,
        updated_at=time.time(),
    )
    try:
        redis.set(
            _node_key(node_id),
            json.dumps(asdict(node), separators=(",", ":")),
            ex=settings.MEDIA_NODE_TTL_SECONDS,
        )
        for room_public_id in room_ids:
            room_public_id = room_public_id.strip()
            if not room_public_id:
                continue
            assignment_key = _room_key(room_public_id)
            if redis.get(assignment_key) == node_id:
                redis.expire(assignment_key, settings.MEDIA_ROOM_ASSIGNMENT_TTL_SECONDS)
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc
    return node


def set_node_draining(redis: Redis, node_id: str, draining: bool) -> MediaNode:
    node = get_node(redis, node_id)
    if node is None:
        raise MediaNodeUnavailable("Media node is not registered or its heartbeat expired.")
    updated = MediaNode(
        node_id=node.node_id,
        public_url=node.public_url,
        room_count=node.room_count,
        peer_count=node.peer_count,
        max_rooms=node.max_rooms,
        max_peers=node.max_peers,
        draining=draining,
        updated_at=node.updated_at,
    )
    try:
        redis.set(
            _node_key(node_id),
            json.dumps(asdict(updated), separators=(",", ":")),
            ex=settings.MEDIA_NODE_TTL_SECONDS,
        )
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc
    return updated


def remove_node(redis: Redis, node_id: str) -> None:
    try:
        redis.delete(_node_key(node_id))
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc


def resolve_room_node(redis: Redis, room_public_id: str) -> MediaNode:
    assignment_key = _room_key(room_public_id)
    try:
        existing_id = redis.get(assignment_key)
        if existing_id:
            node = get_node(redis, str(existing_id))
            if node is not None:
                redis.expire(assignment_key, settings.MEDIA_ROOM_ASSIGNMENT_TTL_SECONDS)
                return node
            redis.delete(assignment_key)

        candidates = [node for node in list_nodes(redis) if node.has_capacity]
        if not candidates:
            raise MediaNodeUnavailable("No healthy media node currently has room capacity.")

        candidate = min(candidates, key=lambda item: (item.load_score, item.room_count, item.peer_count, item.node_id))
        claimed = redis.set(
            assignment_key,
            candidate.node_id,
            nx=True,
            ex=settings.MEDIA_ROOM_ASSIGNMENT_TTL_SECONDS,
        )
        if claimed:
            return candidate

        winner_id = redis.get(assignment_key)
        winner = get_node(redis, str(winner_id)) if winner_id else None
        if winner is not None:
            return winner
        raise MediaNodeUnavailable("Unable to establish a stable media-node assignment.")
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc


def room_is_assigned_to_node(redis: Redis, room_public_id: str, node_id: str) -> bool:
    try:
        assigned = redis.get(_room_key(room_public_id))
        return bool(assigned and str(assigned) == node_id and get_node(redis, node_id) is not None)
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc
