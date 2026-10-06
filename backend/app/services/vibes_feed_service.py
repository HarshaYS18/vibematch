"""Bounded Vibes feed read model with keyset pagination and set-based viewer state."""

from __future__ import annotations

import base64
import json
from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import and_, or_
from sqlalchemy.orm import Query, Session, joinedload

from app.models.follow import UserFollow
from app.models.user import User
from app.models.vibe import VibePost, VibeReaction, VibeSave


@dataclass(frozen=True)
class FeedCursor:
    created_at: datetime
    post_id: int


@dataclass(frozen=True)
class FeedPage:
    posts: list[VibePost]
    liked_post_ids: frozenset[int]
    saved_post_ids: frozenset[int]
    next_cursor: str | None
    has_more: bool


def encode_feed_cursor(created_at: datetime, post_id: int) -> str:
    raw = json.dumps(
        {"created_at": created_at.isoformat(), "id": int(post_id)},
        separators=(",", ":"),
    ).encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def decode_feed_cursor(value: str | None) -> FeedCursor | None:
    if value is None or not value.strip():
        return None
    token = value.strip()
    try:
        padded = token + ("=" * (-len(token) % 4))
        payload = json.loads(base64.urlsafe_b64decode(padded.encode("ascii")))
        created_at = datetime.fromisoformat(str(payload["created_at"]))
        post_id = int(payload["id"])
    except (ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
        raise ValueError("Invalid Vibes feed cursor") from exc
    if post_id < 1:
        raise ValueError("Invalid Vibes feed cursor")
    return FeedCursor(created_at=created_at, post_id=post_id)


class FeedPolicy:
    """Applies visibility rules before ranking."""

    def apply(self, query: Query) -> Query:
        return query.filter(VibePost.is_deleted.is_(False))


class FeedCandidateProvider:
    """Builds candidate sets without materializing large follower ID lists."""

    def candidates(
        self,
        db: Session,
        *,
        current_user: User,
        mode: str,
        author_user_id: int | None = None,
    ) -> Query:
        query = db.query(VibePost).options(joinedload(VibePost.author))
        if mode == "friends":
            query = query.join(
                UserFollow,
                and_(
                    UserFollow.followed_user_id == VibePost.author_user_id,
                    UserFollow.follower_user_id == current_user.id,
                ),
            )
        elif mode == "saved":
            query = query.join(
                VibeSave,
                and_(
                    VibeSave.post_id == VibePost.id,
                    VibeSave.user_id == current_user.id,
                ),
            )
        elif mode == "author":
            if author_user_id is None:
                raise ValueError("author_user_id is required")
            query = query.filter(VibePost.author_user_id == author_user_id)
        elif mode != "global":
            raise ValueError("Unsupported Vibes feed mode")
        return query


class FeedRanker:
    """Ranking seam. Chunk 24 intentionally starts with chronological ordering."""

    def apply(self, query: Query) -> Query:
        return query.order_by(VibePost.created_at.desc(), VibePost.id.desc())


class FeedRepository:
    def __init__(
        self,
        *,
        candidates: FeedCandidateProvider | None = None,
        ranker: FeedRanker | None = None,
        policy: FeedPolicy | None = None,
    ):
        self.candidates = candidates or FeedCandidateProvider()
        self.ranker = ranker or FeedRanker()
        self.policy = policy or FeedPolicy()

    def page(
        self,
        db: Session,
        *,
        current_user: User,
        mode: str,
        limit: int,
        cursor: str | None = None,
        author_user_id: int | None = None,
    ) -> FeedPage:
        parsed = decode_feed_cursor(cursor)
        query = self.candidates.candidates(
            db,
            current_user=current_user,
            mode=mode,
            author_user_id=author_user_id,
        )
        query = self.policy.apply(query)
        if parsed is not None:
            query = query.filter(
                or_(
                    VibePost.created_at < parsed.created_at,
                    and_(
                        VibePost.created_at == parsed.created_at,
                        VibePost.id < parsed.post_id,
                    ),
                )
            )
        rows = self.ranker.apply(query).limit(limit + 1).all()
        has_more = len(rows) > limit
        posts = rows[:limit]
        post_ids = [post.id for post in posts]
        liked_ids: set[int] = set()
        saved_ids: set[int] = set()
        if post_ids:
            liked_ids = {
                int(row[0])
                for row in db.query(VibeReaction.post_id)
                .filter(
                    VibeReaction.user_id == current_user.id,
                    VibeReaction.post_id.in_(post_ids),
                )
                .all()
            }
            saved_ids = {
                int(row[0])
                for row in db.query(VibeSave.post_id)
                .filter(
                    VibeSave.user_id == current_user.id,
                    VibeSave.post_id.in_(post_ids),
                )
                .all()
            }
        next_cursor = (
            encode_feed_cursor(posts[-1].created_at, posts[-1].id)
            if has_more and posts
            else None
        )
        return FeedPage(
            posts=posts,
            liked_post_ids=frozenset(liked_ids),
            saved_post_ids=frozenset(saved_ids),
            next_cursor=next_cursor,
            has_more=has_more,
        )
