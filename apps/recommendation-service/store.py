"""Redis-backed disposable recommendation feature/feed projection."""

from __future__ import annotations

import json
from typing import Any

from redis.asyncio import Redis

from contracts import RecommendationSignal
from ranker import score


class RecommendationStore:
    def __init__(self, redis: Redis, *, ttl_seconds: int) -> None:
        self._redis = redis
        self._ttl = ttl_seconds

    def _feed_key(self, public_user_id: str) -> str:
        return f"funkey:recommendation:v1:feed:{public_user_id}"

    def _meta_key(self, public_user_id: str) -> str:
        return f"funkey:recommendation:v1:meta:{public_user_id}"

    async def apply(self, signal: RecommendationSignal) -> None:
        feed_key = self._feed_key(signal.public_user_id)
        meta_key = self._meta_key(signal.public_user_id)
        pipe = self._redis.pipeline(transaction=False)

        if signal.action.lower() == "block":
            pipe.zrem(feed_key, signal.member)
            pipe.hdel(meta_key, signal.member)
        else:
            pipe.zincrby(feed_key, score(signal), signal.member)
            pipe.hset(
                meta_key,
                signal.member,
                json.dumps(
                    {
                        "candidate_id": signal.candidate_id,
                        "candidate_kind": signal.candidate_kind,
                        "last_action": signal.action,
                        "occurred_at": signal.occurred_at.isoformat(),
                    },
                    separators=(",", ":"),
                ),
            )
        pipe.expire(feed_key, self._ttl)
        pipe.expire(meta_key, self._ttl)
        await pipe.execute()

    async def feed(self, public_user_id: str, *, limit: int) -> list[dict[str, Any]]:
        feed_key = self._feed_key(public_user_id)
        meta_key = self._meta_key(public_user_id)
        members = await self._redis.zrevrange(feed_key, 0, max(0, limit - 1), withscores=True)
        if not members:
            return []
        raw_meta = await self._redis.hmget(meta_key, [member.decode() if isinstance(member, bytes) else member for member, _ in members])
        result = []
        for ((member, ranking_score), raw) in zip(members, raw_meta):
            member_text = member.decode() if isinstance(member, bytes) else str(member)
            metadata = {}
            if raw:
                metadata = json.loads(raw.decode() if isinstance(raw, bytes) else raw)
            result.append(
                {
                    "member": member_text,
                    "score": float(ranking_score),
                    **metadata,
                }
            )
        return result

    async def ready(self) -> bool:
        try:
            return bool(await self._redis.ping())
        except Exception:
            return False
