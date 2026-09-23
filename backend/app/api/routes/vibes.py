from datetime import datetime, timedelta
import re

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.cdn_media import CdnMediaLinkedEntityType
from app.models.follow import UserFollow
from app.models.user import User
from app.models.vibe import VibeComment, VibeCommentReaction, VibePost, VibeReaction, VibeReport, VibeSave, VibeShare
from app.schemas.vibes import (
    VibeAuthorResponse,
    VibeCommentActionResponse,
    VibeCommentCreateRequest,
    VibeCommentLikeResponse,
    VibeCommentResponse,
    VibeDeleteResponse,
    VibeFeedResponse,
    VibeLikeResponse,
    VibePostCreateRequest,
    VibePostResponse,
    VibeReportCreateRequest,
    VibeReportQueueItemResponse,
    VibeReportQueueResponse,
    VibeReportResponse,
    VibeReportReviewRequest,
    VibeSaveResponse,
    VibeShareCreateRequest,
    VibeShareResponse,
)
from app.services import cdn_media_service, inbox_service_client, notification_service

router = APIRouter(prefix="/vibes", tags=["Vibes"])
admin_router = APIRouter(prefix="/admin/moderation/vibes", tags=["Admin Vibes"])

_REVIEW_ROLES = {"founder_owner", "owner", "superadmin", "admin", "monitor", "cs"}
_MENTION_ALL_DAILY_LIMIT = 2
_MENTION_TOKEN_RE = re.compile(r"^@?(?P<token>[A-Za-z0-9_\.\-]{2,80})$")


def _mentions_to_csv(mentions: list[str]) -> str | None:
    cleaned: list[str] = []
    for item in mentions:
        normalized = _normalize_mention(item)
        if normalized and normalized not in cleaned:
            cleaned.append(normalized)
    if not cleaned:
        return None
    return ",".join(cleaned[:50])


def _csv_to_mentions(raw: str | None) -> list[str]:
    if not raw:
        return []
    return [item.strip() for item in raw.split(",") if item.strip()]


def _normalize_mention(raw: str) -> str | None:
    value = (raw or "").strip()
    if not value:
        return None
    match = _MENTION_TOKEN_RE.match(value)
    if not match:
        return None
    token = match.group("token").strip()
    if token.lower() == "all":
        return "all"
    return token


def _display_name(user: User) -> str:
    return user.display_name or user.username or f"User {user.public_user_id}"


def _author_response(user: User) -> VibeAuthorResponse:
    return VibeAuthorResponse(id=user.id, public_user_id=user.public_user_id, username=user.username, display_name=user.display_name, avatar_url=user.avatar_url)


def _comment_response(db: Session, comment: VibeComment, post: VibePost, current_user: User) -> VibeCommentResponse:
    likes_count = db.query(func.count(VibeCommentReaction.id)).filter(VibeCommentReaction.comment_id == comment.id).scalar() or 0
    liked_by_me = db.query(VibeCommentReaction.id).filter(VibeCommentReaction.comment_id == comment.id, VibeCommentReaction.user_id == current_user.id).first() is not None
    return VibeCommentResponse(
        id=comment.id,
        post_id=comment.post_id,
        parent_comment_id=getattr(comment, "parent_comment_id", None),
        text=comment.text,
        author=_author_response(comment.user),
        is_pinned=getattr(comment, "is_pinned", False),
        can_pin=post.author_user_id == current_user.id and getattr(comment, "parent_comment_id", None) is None,
        can_delete=comment.user_id == current_user.id or post.author_user_id == current_user.id,
        liked_by_me=liked_by_me,
        likes_count=likes_count,
        created_at=comment.created_at,
    )


def _role_names(user: User) -> set[str]:
    names: set[str] = set()
    for user_role in getattr(user, "roles", []) or []:
        raw_role = getattr(user_role, "role", None) or getattr(user_role, "role_name", None)
        if raw_role is not None:
            names.add(raw_role.value if hasattr(raw_role, "value") else str(raw_role))
    return names


def _require_report_reviewer(current_user: User) -> None:
    if not (_role_names(current_user) & _REVIEW_ROLES):
        raise HTTPException(status_code=403, detail="Vibes report review requires CS/Monitor/Admin/Owner permission")


def _get_visible_post_or_404(db: Session, post_id: int) -> VibePost:
    post = db.query(VibePost).filter(VibePost.id == post_id, VibePost.is_deleted.is_(False)).first()
    if not post:
        raise HTTPException(status_code=404, detail="Vibe not found")
    return post


def _get_visible_comment_or_404(db: Session, post_id: int, comment_id: int) -> VibeComment:
    comment = db.query(VibeComment).filter(VibeComment.id == comment_id, VibeComment.post_id == post_id, VibeComment.is_deleted.is_(False)).first()
    if not comment:
        raise HTTPException(status_code=404, detail="Vibe comment not found")
    return comment


def _post_response(db: Session, post: VibePost, current_user: User) -> VibePostResponse:
    likes_count = db.query(func.count(VibeReaction.id)).filter(VibeReaction.post_id == post.id).scalar() or 0
    comments_count = db.query(func.count(VibeComment.id)).filter(VibeComment.post_id == post.id, VibeComment.is_deleted.is_(False)).scalar() or 0
    shares_count = db.query(func.count(VibeShare.id)).filter(VibeShare.post_id == post.id).scalar() or 0
    saves_count = db.query(func.count(VibeSave.id)).filter(VibeSave.post_id == post.id).scalar() or 0
    reports_count = db.query(func.count(VibeReport.id)).filter(VibeReport.post_id == post.id).scalar() or 0
    liked_by_me = db.query(VibeReaction.id).filter(VibeReaction.post_id == post.id, VibeReaction.user_id == current_user.id).first() is not None
    saved_by_me = db.query(VibeSave.id).filter(VibeSave.post_id == post.id, VibeSave.user_id == current_user.id).first() is not None
    return VibePostResponse(id=post.id, caption=post.caption, media_type=post.media_type, media_url=post.media_url, tag=post.tag, mentions=_csv_to_mentions(post.mentions_csv), uses_mention_all=post.uses_mention_all, comments_enabled=getattr(post, "comments_enabled", True), author=_author_response(post.author), likes_count=likes_count, comments_count=comments_count, shares_count=shares_count, saves_count=saves_count, reports_count=reports_count, liked_by_me=liked_by_me, saved_by_me=saved_by_me, created_at=post.created_at)


def _report_queue_item(report: VibeReport) -> VibeReportQueueItemResponse:
    return VibeReportQueueItemResponse(id=report.id, post_id=report.post_id, reporter=_author_response(report.reporter), post_author=_author_response(report.post.author), post_caption=report.post.caption, post_media_type=report.post.media_type, reason=report.reason, details=report.details, status=report.status, created_at=report.created_at)


def _check_mention_all_limit(db: Session, current_user: User) -> None:
    since = datetime.utcnow() - timedelta(days=1)
    used_count = db.query(func.count(VibePost.id)).filter(VibePost.author_user_id == current_user.id, VibePost.uses_mention_all.is_(True), VibePost.is_deleted.is_(False), VibePost.created_at >= since).scalar() or 0
    if used_count >= _MENTION_ALL_DAILY_LIMIT:
        raise HTTPException(status_code=429, detail=f"@all is limited to {_MENTION_ALL_DAILY_LIMIT} Vibes per 24 hours")


def _resolve_mentioned_users(db: Session, current_user: User, mentions: list[str]) -> list[User]:
    normalized: list[str] = []
    for mention in mentions:
        token = _normalize_mention(mention)
        if token and token != "all" and token.lower() not in [item.lower() for item in normalized]:
            normalized.append(token)
    if not normalized:
        return []
    users: list[User] = []
    seen_ids: set[int] = set()
    for token in normalized[:50]:
        query = db.query(User).filter(User.is_active.is_(True), User.is_banned.is_(False))
        public_id = int(token) if token.isdigit() else None
        user = query.filter((User.username.ilike(token)) | (User.display_name.ilike(token)) | (User.official_handle.ilike(token)) | (User.official_handle.ilike(f"@{token}")) | (User.public_user_id == public_id if public_id is not None else False)).first()
        if user and user.id != current_user.id and user.id not in seen_ids:
            seen_ids.add(user.id)
            users.append(user)
    return users


def _followers_for_mention_all(db: Session, current_user: User) -> list[User]:
    return db.query(User).join(UserFollow, UserFollow.follower_user_id == User.id).filter(UserFollow.followed_user_id == current_user.id, User.is_active.is_(True), User.is_banned.is_(False), User.id != current_user.id).limit(1000).all()


def _send_direct_mention_inbox_snapshot(db: Session, post: VibePost, sender: User, recipient: User, caption_preview: str) -> None:
    del db
    text = f"Mentioned you in a Vibe\n\n{caption_preview}\n\nVibe ID: {post.id}"
    message_type = "image" if post.media_type == "photo" and post.media_url else "text"
    try:
        inbox_service_client.send_direct_message(
            sender_user_id=sender.id,
            target_user_id=recipient.id,
            text=text,
            message_type=message_type,
            attachment_url=post.media_url,
            metadata={"vibe_post_id": post.id, "source": "vibe_mention"},
        )
    except (inbox_service_client.InboxServiceUnavailable, ValueError):
        # The Vibe is authoritative and already committed. Inbox mention
        # delivery is a secondary projection and must not fake a failed post.
        return


def _send_vibe_notifications(db: Session, post: VibePost, current_user: User, mentions: list[str], uses_mention_all: bool) -> None:
    notified_user_ids: set[int] = set()
    author_name = _display_name(current_user)
    caption_preview = post.caption[:160].strip()
    if len(post.caption) > 160:
        caption_preview += "..."

    def create_vibe_notification(user: User, notification_type: str, title: str, body: str) -> None:
        notification_service.create_notification(db, recipient=user, actor=current_user, notification_type=notification_type, title=title, body=body, target_type="vibe", target_id=str(post.id), metadata={"post_id": post.id, "author_public_user_id": current_user.public_user_id, "author_name": author_name, "media_type": post.media_type})

    for user in _resolve_mentioned_users(db, current_user, mentions):
        if user.id in notified_user_ids:
            continue
        notified_user_ids.add(user.id)
        create_vibe_notification(user, "vibe_mention", f"{author_name} mentioned you", f"Mentioned you in a Vibe: \"{caption_preview}\"")
        _send_direct_mention_inbox_snapshot(db, post, current_user, user, caption_preview)
    if uses_mention_all:
        for user in _followers_for_mention_all(db, current_user):
            if user.id in notified_user_ids:
                continue
            notified_user_ids.add(user.id)
            create_vibe_notification(user, "vibe_mention_all", f"{author_name} posted to followers", f"Mentioned all followers in a new Vibe: \"{caption_preview}\"")


@router.get("/feed", response_model=VibeFeedResponse)
def list_vibes_feed(limit: int = Query(default=30, ge=1, le=100), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    posts = db.query(VibePost).filter(VibePost.is_deleted.is_(False)).order_by(VibePost.created_at.desc()).limit(limit).all()
    return VibeFeedResponse(posts=[_post_response(db, post, current_user) for post in posts])


@router.get("/friends", response_model=VibeFeedResponse)
def list_friends_vibes_feed(limit: int = Query(default=30, ge=1, le=100), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    followed_ids = [row[0] for row in db.query(UserFollow.followed_user_id).filter(UserFollow.follower_user_id == current_user.id).all()]
    if not followed_ids:
        return VibeFeedResponse(posts=[])
    posts = db.query(VibePost).filter(VibePost.author_user_id.in_(followed_ids), VibePost.is_deleted.is_(False)).order_by(VibePost.created_at.desc()).limit(limit).all()
    return VibeFeedResponse(posts=[_post_response(db, post, current_user) for post in posts])


@router.get("/saved", response_model=VibeFeedResponse)
def list_saved_vibes(limit: int = Query(default=50, ge=1, le=100), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    saves = db.query(VibeSave).join(VibePost, VibeSave.post_id == VibePost.id).filter(VibeSave.user_id == current_user.id, VibePost.is_deleted.is_(False)).order_by(VibeSave.created_at.desc()).limit(limit).all()
    return VibeFeedResponse(posts=[_post_response(db, save.post, current_user) for save in saves])


@router.get("/user/{public_user_id}", response_model=list[VibePostResponse])
def list_public_user_vibes(public_user_id: int, limit: int = Query(default=30, ge=1, le=100), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    user = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    posts = db.query(VibePost).filter(VibePost.author_user_id == user.id, VibePost.is_deleted.is_(False)).order_by(VibePost.created_at.desc()).limit(limit).all()
    return [_post_response(db, post, current_user) for post in posts]


@admin_router.get("/reports", response_model=VibeReportQueueResponse)
def list_vibe_reports(status: str | None = Query(default="PENDING"), limit: int = Query(default=50, ge=1, le=100), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_report_reviewer(current_user)
    query = db.query(VibeReport).join(VibePost, VibeReport.post_id == VibePost.id)
    if status and status.upper() != "ALL":
        query = query.filter(VibeReport.status == status.upper())
    reports = query.order_by(VibeReport.created_at.desc()).limit(limit).all()
    return VibeReportQueueResponse(reports=[_report_queue_item(report) for report in reports])


@admin_router.post("/reports/{report_id}/review", response_model=VibeReportResponse)
def review_vibe_report(report_id: int, payload: VibeReportReviewRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _require_report_reviewer(current_user)
    report = db.query(VibeReport).filter(VibeReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Vibe report not found")
    report.status = payload.status
    if payload.delete_post:
        report.post.is_deleted = True
        report.status = "ACTION_TAKEN"
        cdn_media_service.link_media_to_entity(
            db,
            public_url=report.post.media_url,
            linked_entity_type=CdnMediaLinkedEntityType.VIBES_POST,
            linked_entity_id=str(report.post.id),
        )
        asset = cdn_media_service.link_media_to_entity(
            db,
            public_url=report.post.media_url,
            linked_entity_type=CdnMediaLinkedEntityType.VIBES_POST,
            linked_entity_id=str(report.post.id),
        )
        if asset:
            cdn_media_service.mark_media_deleted(db, asset=asset, actor_user_id=current_user.id, reason="vibe_report_action_taken")
    db.commit()
    db.refresh(report)
    return VibeReportResponse(id=report.id, post_id=report.post_id, reason=report.reason, status=report.status, created_at=report.created_at)


@router.post("", response_model=VibePostResponse)
def create_vibe(payload: VibePostCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if payload.uses_mention_all:
        _check_mention_all_limit(db, current_user)
    normalized_mentions = [mention for mention in (_normalize_mention(item) for item in payload.mentions) if mention and mention != "all"]
    post = VibePost(author_user_id=current_user.id, caption=payload.caption.strip(), media_type=payload.media_type, media_url=payload.media_url.strip() if payload.media_url else None, tag=payload.tag.strip() if payload.tag else None, mentions_csv=_mentions_to_csv(normalized_mentions), uses_mention_all=payload.uses_mention_all, comments_enabled=payload.comments_enabled)
    db.add(post)
    db.commit()
    db.refresh(post)
    cdn_media_service.link_media_to_entity(
        db,
        public_url=post.media_url,
        linked_entity_type=CdnMediaLinkedEntityType.VIBES_POST,
        linked_entity_id=str(post.id),
    )
    _send_vibe_notifications(db, post, current_user, normalized_mentions, payload.uses_mention_all)
    db.refresh(post)
    return _post_response(db, post, current_user)


@router.get("/{post_id}", response_model=VibePostResponse)
def get_vibe_detail(post_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = _get_visible_post_or_404(db, post_id)
    return _post_response(db, post, current_user)


@router.post("/{post_id}/like", response_model=VibeLikeResponse)
def toggle_vibe_like(post_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _get_visible_post_or_404(db, post_id)
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


@router.post("/{post_id}/save", response_model=VibeSaveResponse)
def toggle_vibe_save(post_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _get_visible_post_or_404(db, post_id)
    existing = db.query(VibeSave).filter(VibeSave.post_id == post_id, VibeSave.user_id == current_user.id).first()
    saved_by_me = False
    if existing:
        db.delete(existing)
    else:
        db.add(VibeSave(post_id=post_id, user_id=current_user.id))
        saved_by_me = True
    db.commit()
    saves_count = db.query(func.count(VibeSave.id)).filter(VibeSave.post_id == post_id).scalar() or 0
    return VibeSaveResponse(post_id=post_id, saved_by_me=saved_by_me, saves_count=saves_count)


@router.post("/{post_id}/share", response_model=VibeShareResponse)
def share_vibe(post_id: int, payload: VibeShareCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _get_visible_post_or_404(db, post_id)
    target_user: User | None = None
    if payload.target_public_user_id is not None:
        target_user = db.query(User).filter(User.public_user_id == payload.target_public_user_id).first()
        if not target_user:
            raise HTTPException(status_code=404, detail="Share target user not found")
    share = VibeShare(post_id=post_id, sender_user_id=current_user.id, target_user_id=target_user.id if target_user else None, target_public_user_id=payload.target_public_user_id, share_channel=payload.share_channel.strip() or "inbox")
    db.add(share)
    db.commit()
    db.refresh(share)
    shares_count = db.query(func.count(VibeShare.id)).filter(VibeShare.post_id == post_id).scalar() or 0
    return VibeShareResponse(id=share.id, post_id=post_id, share_channel=share.share_channel, target_public_user_id=share.target_public_user_id, shares_count=shares_count, created_at=share.created_at)


@router.post("/{post_id}/report", response_model=VibeReportResponse)
def report_vibe(post_id: int, payload: VibeReportCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = _get_visible_post_or_404(db, post_id)
    if post.author_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot report your own Vibe")
    report = VibeReport(post_id=post_id, reporter_user_id=current_user.id, reason=payload.reason.strip(), details=payload.details.strip() if payload.details else None, status="PENDING")
    db.add(report)
    db.commit()
    db.refresh(report)
    return VibeReportResponse(id=report.id, post_id=post_id, reason=report.reason, status=report.status, created_at=report.created_at)


@router.post("/{post_id}/comments", response_model=VibeCommentResponse)
def add_vibe_comment(post_id: int, payload: VibeCommentCreateRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = _get_visible_post_or_404(db, post_id)
    if not getattr(post, "comments_enabled", True) and post.author_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Comments are disabled for this Vibe")
    parent_comment_id = payload.parent_comment_id
    if parent_comment_id is not None:
        parent = _get_visible_comment_or_404(db, post_id, parent_comment_id)
        parent_comment_id = parent.parent_comment_id or parent.id
    comment = VibeComment(post_id=post_id, user_id=current_user.id, parent_comment_id=parent_comment_id, text=payload.text.strip())
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return _comment_response(db, comment, post, current_user)


@router.get("/{post_id}/comments", response_model=list[VibeCommentResponse])
def list_vibe_comments(post_id: int, limit: int = Query(default=100, ge=1, le=200), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = _get_visible_post_or_404(db, post_id)
    comments = db.query(VibeComment).filter(VibeComment.post_id == post_id, VibeComment.is_deleted.is_(False)).order_by(VibeComment.is_pinned.desc(), VibeComment.parent_comment_id.asc().nullsfirst(), VibeComment.created_at.asc()).limit(limit).all()
    return [_comment_response(db, item, post, current_user) for item in comments]


@router.post("/{post_id}/comments/{comment_id}/like", response_model=VibeCommentLikeResponse)
def toggle_vibe_comment_like(post_id: int, comment_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _get_visible_post_or_404(db, post_id)
    _get_visible_comment_or_404(db, post_id, comment_id)
    existing = db.query(VibeCommentReaction).filter(VibeCommentReaction.comment_id == comment_id, VibeCommentReaction.user_id == current_user.id).first()
    liked_by_me = False
    if existing:
        db.delete(existing)
    else:
        db.add(VibeCommentReaction(comment_id=comment_id, user_id=current_user.id, reaction_type="like"))
        liked_by_me = True
    db.commit()
    likes_count = db.query(func.count(VibeCommentReaction.id)).filter(VibeCommentReaction.comment_id == comment_id).scalar() or 0
    return VibeCommentLikeResponse(comment_id=comment_id, liked_by_me=liked_by_me, likes_count=likes_count)


@router.patch("/{post_id}/comments/{comment_id}/pin", response_model=VibeCommentActionResponse)
def toggle_vibe_comment_pin(post_id: int, comment_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = _get_visible_post_or_404(db, post_id)
    if post.author_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the Vibe author can pin comments")
    comment = _get_visible_comment_or_404(db, post_id, comment_id)
    if getattr(comment, "parent_comment_id", None) is not None:
        raise HTTPException(status_code=400, detail="Only top-level comments can be pinned")
    comment.is_pinned = not getattr(comment, "is_pinned", False)
    db.commit()
    db.refresh(comment)
    return VibeCommentActionResponse(id=comment.id, post_id=post_id, is_pinned=comment.is_pinned, deleted=False)


@router.delete("/{post_id}/comments/{comment_id}", response_model=VibeCommentActionResponse)
def delete_vibe_comment(post_id: int, comment_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = _get_visible_post_or_404(db, post_id)
    comment = _get_visible_comment_or_404(db, post_id, comment_id)
    if comment.user_id != current_user.id and post.author_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the comment author or Vibe author can delete this comment")
    comment.is_deleted = True
    db.commit()
    return VibeCommentActionResponse(id=comment.id, post_id=post_id, is_pinned=getattr(comment, "is_pinned", False), deleted=True)


@router.delete("/{post_id}", response_model=VibeDeleteResponse)
def delete_vibe(post_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    post = _get_visible_post_or_404(db, post_id)
    if post.author_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the author can delete this Vibe")
    asset = cdn_media_service.link_media_to_entity(
        db,
        public_url=post.media_url,
        linked_entity_type=CdnMediaLinkedEntityType.VIBES_POST,
        linked_entity_id=str(post.id),
    )
    if asset:
        cdn_media_service.mark_media_deleted(db, asset=asset, actor_user_id=current_user.id, reason="vibe_deleted_by_author")
    post.is_deleted = True
    db.commit()
    return VibeDeleteResponse(post_id=post_id, deleted=True)
