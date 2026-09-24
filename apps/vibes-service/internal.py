from __future__ import annotations

import hmac

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import or_
from sqlalchemy.orm import Session

from app.core.config import settings
from app.database import get_db
from app.models.follow import UserFollow
from app.models.user import User
from app.models.vibe import VibePost


router = APIRouter(prefix="/internal/vibes", tags=["Vibes Internal"])


def require_internal_token(
    x_funkey_internal_token: str | None = Header(default=None),
) -> None:
    expected = settings.VIBES_INTERNAL_TOKEN.strip()
    provided = (x_funkey_internal_token or "").strip()
    if not expected or not hmac.compare_digest(provided, expected):
        raise HTTPException(status_code=403, detail="Internal Vibes access denied")


def _tokens(post: VibePost) -> list[str]:
    return [
        item.strip()
        for item in (post.mentions_csv or "").split(",")
        if item.strip()
    ][:50]


@router.get(
    "/posts/{post_id}/fanout",
    dependencies=[Depends(require_internal_token)],
)
def fanout_snapshot(post_id: int, db: Session = Depends(get_db)):
    post = db.query(VibePost).filter(VibePost.id == post_id).first()
    if post is None:
        raise HTTPException(status_code=404, detail="Vibe not found")

    mention_conditions = []
    for token in _tokens(post):
        lowered = token.lower()
        mention_conditions.extend(
            (
                User.username.ilike(token),
                User.display_name.ilike(token),
                User.official_handle.ilike(token),
                User.official_handle.ilike(f"@{token}"),
            )
        )
        if token.isdigit():
            mention_conditions.append(User.public_user_id == int(token))

    direct_ids: set[int] = set()
    if mention_conditions:
        direct_ids = {
            int(row[0])
            for row in db.query(User.id)
            .filter(
                User.is_active.is_(True),
                User.is_banned.is_(False),
                User.id != post.author_user_id,
                or_(*mention_conditions),
            )
            .limit(50)
            .all()
        }

    follower_ids: set[int] = set()
    if post.uses_mention_all:
        follower_ids = {
            int(row[0])
            for row in db.query(User.id)
            .join(UserFollow, UserFollow.follower_user_id == User.id)
            .filter(
                UserFollow.followed_user_id == post.author_user_id,
                User.is_active.is_(True),
                User.is_banned.is_(False),
                User.id != post.author_user_id,
            )
            .limit(1000)
            .all()
        }
        follower_ids.difference_update(direct_ids)

    author = post.author
    author_name = (
        author.display_name
        or author.username
        or f"User {author.public_user_id}"
    )
    caption_preview = post.caption[:160].strip()
    if len(post.caption) > 160:
        caption_preview += "..."

    return {
        "post_id": post.id,
        "author_user_id": post.author_user_id,
        "author_public_user_id": author.public_user_id,
        "author_name": author_name,
        "caption_preview": caption_preview,
        "media_type": post.media_type,
        "media_url": post.media_url,
        "direct_mention_user_ids": sorted(direct_ids),
        "mention_all_user_ids": sorted(follower_ids),
    }
