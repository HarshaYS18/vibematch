from __future__ import annotations

import json
import time
from dataclasses import asdict, dataclass

from redis import Redis
from redis.exceptions import RedisError

from app.core.config import settings


NODE_PREFIX = "funkey:media:nodes:"
ROOM_PREFIX = "funkey:media:rooms:"
DRAIN_PREFIX = "funkey:media:draining:"
RESERVATION_PREFIX = "funkey:media:reservations:"

# All keys live in one Redis primary (Redis Cluster is not supported). Lua keeps
# selection, reservations and sticky assignment atomic across API replicas.
RESOLVE_SCRIPT = """
local now = tonumber(redis.call('TIME')[1])
local existing = redis.call('GET', KEYS[1])
if existing then
    local raw = redis.call('GET', ARGV[1] .. existing)
    if raw then
        redis.call('EXPIRE', KEYS[1], ARGV[4])
        redis.call('ZADD', ARGV[2] .. existing, now + tonumber(ARGV[5]), ARGV[3])
        redis.call('EXPIRE', ARGV[2] .. existing, ARGV[4])
        return raw
    end
end
local best = nil
local score = math.huge
for i = 2, #KEYS do
    local raw = redis.call('GET', KEYS[i])
    if raw then
        local node = cjson.decode(raw)
        local reservations = ARGV[2] .. node.node_id
        redis.call('ZREMRANGEBYSCORE', reservations, '-inf', now)
        local rooms = math.max(node.room_count, redis.call('ZCARD', reservations))
        local load = math.max(rooms / node.max_rooms, node.peer_count / node.max_peers)
        if not node.draining and rooms < node.max_rooms and node.peer_count < node.max_peers and load < score then
            best = raw
            score = load
        end
    end
end
if not best then return false end
local node = cjson.decode(best)
redis.call('SET', KEYS[1], node.node_id, 'EX', ARGV[4])
redis.call('ZADD', ARGV[2] .. node.node_id, now + tonumber(ARGV[5]), ARGV[3])
redis.call('EXPIRE', ARGV[2] .. node.node_id, ARGV[4])
return best
"""

HEARTBEAT_SCRIPT = """
local node = cjson.decode(ARGV[1])
node.draining = redis.call('GET', KEYS[2]) == '1'
local now = tonumber(redis.call('TIME')[1])
node.updated_at = now
local raw = cjson.encode(node)
redis.call('SET', KEYS[1], raw, 'EX', ARGV[2])
for _, room in ipairs(cjson.decode(ARGV[5])) do
    if redis.call('GET', ARGV[3] .. room) == node.node_id then
        redis.call('EXPIRE', ARGV[3] .. room, ARGV[4])
        redis.call('ZADD', KEYS[3], now + tonumber(ARGV[2]), room)
    end
end
redis.call('ZREMRANGEBYSCORE', KEYS[3], '-inf', now)
redis.call('EXPIRE', KEYS[3], ARGV[4])
return raw
"""

DRAIN_SCRIPT = """
local raw = redis.call('GET', KEYS[1])
if not raw then return false end
local node = cjson.decode(raw)
node.draining = ARGV[1] == '1'
if node.draining then redis.call('SET', KEYS[2], '1')
else redis.call('DEL', KEYS[2]) end
raw = cjson.encode(node)
redis.call('SET', KEYS[1], raw, 'KEEPTTL')
return raw
"""


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
    node = MediaNode(
        node_id=node_id,
        public_url=public_url.rstrip("/"),
        room_count=max(room_count, 0),
        peer_count=max(peer_count, 0),
        max_rooms=max(max_rooms, 1),
        max_peers=max(max_peers, 1),
        draining=False,
        updated_at=time.time(),
    )
    try:
        raw = redis.eval(
            HEARTBEAT_SCRIPT, 3, _node_key(node_id), DRAIN_PREFIX + node_id,
            RESERVATION_PREFIX + node_id,
            json.dumps(asdict(node), separators=(",", ":")),
            settings.MEDIA_NODE_TTL_SECONDS, ROOM_PREFIX,
            settings.MEDIA_ROOM_ASSIGNMENT_TTL_SECONDS,
            json.dumps([room.strip() for room in room_ids if room.strip()]),
        )
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc
    return _decode_node(raw)


def set_node_draining(redis: Redis, node_id: str, draining: bool) -> MediaNode:
    try:
        raw = redis.eval(
            DRAIN_SCRIPT, 2, _node_key(node_id), DRAIN_PREFIX + node_id,
            "1" if draining else "0",
        )
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc
    node = _decode_node(raw)
    if node is None:
        raise MediaNodeUnavailable("Media node is not registered or its heartbeat expired.")
    return node


def remove_node(redis: Redis, node_id: str) -> None:
    try:
        redis.delete(_node_key(node_id), RESERVATION_PREFIX + node_id)
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc


def resolve_room_node(redis: Redis, room_public_id: str) -> MediaNode:
    assignment_key = _room_key(room_public_id)
    try:
        keys = sorted(redis.scan_iter(match=f"{NODE_PREFIX}*"))
        raw = redis.eval(
            RESOLVE_SCRIPT, len(keys) + 1, assignment_key, *keys,
            NODE_PREFIX, RESERVATION_PREFIX, room_public_id,
            settings.MEDIA_ROOM_ASSIGNMENT_TTL_SECONDS,
            max(settings.MEDIA_NODE_TTL_SECONDS * 2, 60),
        )
        node = _decode_node(raw)
        if node is None:
            raise MediaNodeUnavailable("No healthy media node currently has room capacity.")
        return node
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc


def room_is_assigned_to_node(redis: Redis, room_public_id: str, node_id: str) -> bool:
    try:
        assigned = redis.get(_room_key(room_public_id))
        if isinstance(assigned, bytes):
            assigned = assigned.decode("utf-8")
        return bool(assigned == node_id and get_node(redis, node_id) is not None)
    except RedisError as exc:
        raise MediaNodeUnavailable("Media registry is unavailable.") from exc
