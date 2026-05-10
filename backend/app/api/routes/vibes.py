from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.models.vibe import VibeComment, VibePost, VibeReaction
from app.schemas.vibes import (
    VibeAuthorResponse,
    VibeCommentCreateRequest,
    VibeCommentResponse,
    VibeDeleteResponse,
    VibeFeedResponse,
    VibeLikeResponse,
    VibePostCreateRequest,
    VibePostResponse,
)

router = APIRouter(prefix="/vibes", tags=["Vibes"])


def _mentions_to_csv(mentions: list[str]) -> str | None:
    cleaned = [item.strip()[:80] for item in mentions if item.strip()]
    if not cleaned:
        return None
    return ",".join(cleaned[:50])


def _csv_to_mentions(raw: str | None) -> list[str]:
    if not raw:
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


def _author_response(user: User) -> VibeAuthorResponse:
    return VibeAuthorResponse(
        id=user.id,
        public_user_id=user.public_user_id,
        username=user.username,
        display_name=user.display_name,
        avatar_url=user.avatar_url,
    )


def _post_response(db: Session, post: VibePost, current_user: User) -> VibePostResponse:
    likes_count = db.query(func.count(VibeReaction.id)).filter(VibeReaction.post_id == post.id).scalar() or 0
    comments_count = db.query(func.count(VibeComment.id)).filter(
        VibeComment.post_id == post.id,
        VibeComment.is_deleted.is_(False),
    ).scalar() or 0
    liked_by_me = db.query(VibeReaction.id).filter(
        VibeReaction.post_id == post.id,
        VibeReaction.user_id == current_user.id,
    ).first() is not None
    return VibePostResponse(
        id=post.id,
        caption=post.caption,
        media_type=post.media_type,
        media_url=post.media_url,
        tag=post.tag,
        mentions=_csv_to_mentions(post.mentions_csv),
        uses_mention_all=post.uses_mention_all,
        author=_author_response(post.author),
        likes_count=likes_count,
        comments_count=comments_count,
        liked_by_me=liked_by_me,
        created_at=post.created_at,
    )


@router.get("/feed", response_model=VibeFeedResponse)
def list_vibes_feed(
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    posts = db.query(VibePost).filter(VibePost.is_deleted.is_(False)).order_by(VibePost.created_at.desc()).limit(limit).all()
    return VibeFeedResponse(posts=[_post_response(db, post, current_user) for post in posts])


@router.post("", response_model=VibePostResponse)
def create_vibe(
    payload: VibePostCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = VibePost(
        author_user_id=current_user.id,
        caption=payload.caption.strip(),
        media_type=payload.media_type,
        media_url=payload.media_url.strip() if payload.media_url else None,
        tag=payload.tag.strip() if payload.tag else None,
        mentions_csv=_mentions_to_csv(payload.mentions),
        uses_mention_all=payload.uses_mention_all,
    )
    db.add(post)
    db.commit()
    db.refresh(post)
    return _post_response(db, post, current_user)


@router.post("/{post_id}/like", response_model=VibeLikeResponse)
def toggle_vibe_like(
    post_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = db.query(VibePost).filter(VibePost.id == post_id, VibePost.is_deleted.is_(False)).first()
    if not post:
        raise HTTPException(status_code=404, detail="Vibe not found")
    existing = db.query(VibeReaction).filter(VibeReaction.post_id == post_id, VibeReaction.user_id == current_user.id).first()
    liked_by_me = False
    if existing:
        db.delete(existing)
    else:
        db.add(VibeReaction(post_id=post_id, user_id=current_user.id, reaction_type="like"))
        liked_by_me = True
    db.commit()
    likes_count = db.query(func.count(VibeReaction.id)).filter(VibeReaction.post_id == post_id).scalar() or 0
    return VibeLikeResponse(post_id=post_id, liked_by_me=liked_by_me, likes_count=likes_count)


@router.post("/{post_id}/comments", response_model=VibeCommentResponse)
def add_vibe_comment(
    post_id: int,
    payload: VibeCommentCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = db.query(VibePost).filter(VibePost.id == post_id, VibePost.is_deleted.is_(False)).first()
    if not post:
        raise HTTPException(status_code=404, detail="Vibe not found")
    comment = VibeComment(post_id=post_id, user_id=current_user.id, text=payload.text.strip())
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return VibeCommentResponse(id=comment.id, post_id=post_id, text=comment.text, author=_author_response(current_user), created_at=comment.created_at)


@router.get("/{post_id}/comments", response_model=list[VibeCommentResponse])
def list_vibe_comments(
    post_id: int,
    limit: int = Query(default=50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = db.query(VibePost).filter(VibePost.id == post_id, VibePost.is_deleted.is_(False)).first()
    if not post:
        raise HTTPException(status_code=404, detail="Vibe not found")
    comments = db.query(VibeComment).filter(VibeComment.post_id == post_id, VibeComment.is_deleted.is_(False)).order_by(VibeComment.created_at.asc()).limit(limit).all()
    return [VibeCommentResponse(id=item.id, post_id=post_id, text=item.text, author=_author_response(item.user), created_at=item.created_at) for item in comments]


@router.delete("/{post_id}", response_model=VibeDeleteResponse)
def delete_vibe(
    post_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = db.query(VibePost).filter(VibePost.id == post_id, VibePost.is_deleted.is_(False)).first()
    if not post:
        raise HTTPException(status_code=404, detail="Vibe not found")
    if post.author_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the author can delete this Vibe")
    post.is_deleted = True
    db.commit()
    return VibeDeleteResponse(post_id=post_id, deleted=True)
