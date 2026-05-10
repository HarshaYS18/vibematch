from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.user import User
from app.models.vibe import VibeComment, VibePost, VibeReaction, VibeReport, VibeShare
from app.schemas.vibes import (
    VibeAuthorResponse,
    VibeCommentCreateRequest,
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
    VibeShareCreateRequest,
    VibeShareResponse,
)

router = APIRouter(prefix="/vibes", tags=["Vibes"])

_REVIEW_ROLES = {"founder_owner", "owner", "superadmin", "admin", "monitor", "cs"}


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


def _role_names(user: User) -> set[str]:
    return {role.role_name.value if hasattr(role.role_name, "value") else str(role.role_name) for role in getattr(user, "roles", [])}


def _require_report_reviewer(current_user: User) -> None:
    if not (_role_names(current_user) & _REVIEW_ROLES):
        raise HTTPException(status_code=403, detail="Vibes report review requires CS/Monitor/Admin/Owner permission")


def _get_visible_post_or_404(db: Session, post_id: int) -> VibePost:
    post = db.query(VibePost).filter(VibePost.id == post_id, VibePost.is_deleted.is_(False)).first()
    if not post:
        raise HTTPException(status_code=404, detail="Vibe not found")
    return post


def _post_response(db: Session, post: VibePost, current_user: User) -> VibePostResponse:
    likes_count = db.query(func.count(VibeReaction.id)).filter(VibeReaction.post_id == post.id).scalar() or 0
    comments_count = db.query(func.count(VibeComment.id)).filter(
        VibeComment.post_id == post.id,
        VibeComment.is_deleted.is_(False),
    ).scalar() or 0
    shares_count = db.query(func.count(VibeShare.id)).filter(VibeShare.post_id == post.id).scalar() or 0
    reports_count = db.query(func.count(VibeReport.id)).filter(VibeReport.post_id == post.id).scalar() or 0
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
        shares_count=shares_count,
        reports_count=reports_count,
        liked_by_me=liked_by_me,
        created_at=post.created_at,
    )


def _report_queue_item(report: VibeReport) -> VibeReportQueueItemResponse:
    return VibeReportQueueItemResponse(
        id=report.id,
        post_id=report.post_id,
        reporter=_author_response(report.reporter),
        post_author=_author_response(report.post.author),
        post_caption=report.post.caption,
        post_media_type=report.post.media_type,
        reason=report.reason,
        details=report.details,
        status=report.status,
        created_at=report.created_at,
    )


@router.get("/feed", response_model=VibeFeedResponse)
def list_vibes_feed(
    limit: int = Query(default=30, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    posts = db.query(VibePost).filter(VibePost.is_deleted.is_(False)).order_by(VibePost.created_at.desc()).limit(limit).all()
    return VibeFeedResponse(posts=[_post_response(db, post, current_user) for post in posts])


@router.get("/reports", response_model=VibeReportQueueResponse)
def list_vibe_reports(
    status: str | None = Query(default="PENDING"),
    limit: int = Query(default=50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_report_reviewer(current_user)
    query = db.query(VibeReport).join(VibePost, VibeReport.post_id == VibePost.id)
    if status and status.upper() != "ALL":
        query = query.filter(VibeReport.status == status.upper())
    reports = query.order_by(VibeReport.created_at.desc()).limit(limit).all()
    return VibeReportQueueResponse(reports=[_report_queue_item(report) for report in reports])


@router.post("/reports/{report_id}/review", response_model=VibeReportResponse)
def review_vibe_report(
    report_id: int,
    payload: VibeReportReviewRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_report_reviewer(current_user)
    report = db.query(VibeReport).filter(VibeReport.id == report_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Vibe report not found")
    report.status = payload.status
    if payload.delete_post:
        report.post.is_deleted = True
        report.status = "ACTION_TAKEN"
    db.commit()
    db.refresh(report)
    return VibeReportResponse(id=report.id, post_id=report.post_id, reason=report.reason, status=report.status, created_at=report.created_at)


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


@router.post("/{post_id}/share", response_model=VibeShareResponse)
def share_vibe(
    post_id: int,
    payload: VibeShareCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_visible_post_or_404(db, post_id)
    target_user: User | None = None
    if payload.target_public_user_id is not None:
        target_user = db.query(User).filter(User.public_user_id == payload.target_public_user_id).first()
        if not target_user:
            raise HTTPException(status_code=404, detail="Share target user not found")
    share = VibeShare(
        post_id=post_id,
        sender_user_id=current_user.id,
        target_user_id=target_user.id if target_user else None,
        target_public_user_id=payload.target_public_user_id,
        share_channel=payload.share_channel.strip() or "inbox",
    )
    db.add(share)
    db.commit()
    db.refresh(share)
    shares_count = db.query(func.count(VibeShare.id)).filter(VibeShare.post_id == post_id).scalar() or 0
    return VibeShareResponse(
        id=share.id,
        post_id=post_id,
        share_channel=share.share_channel,
        target_public_user_id=share.target_public_user_id,
        shares_count=shares_count,
        created_at=share.created_at,
    )


@router.post("/{post_id}/report", response_model=VibeReportResponse)
def report_vibe(
    post_id: int,
    payload: VibeReportCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = _get_visible_post_or_404(db, post_id)
    if post.author_user_id == current_user.id:
        raise HTTPException(status_code=400, detail="You cannot report your own Vibe")
    report = VibeReport(
        post_id=post_id,
        reporter_user_id=current_user.id,
        reason=payload.reason.strip(),
        details=payload.details.strip() if payload.details else None,
        status="PENDING",
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return VibeReportResponse(id=report.id, post_id=post_id, reason=report.reason, status=report.status, created_at=report.created_at)


@router.post("/{post_id}/comments", response_model=VibeCommentResponse)
def add_vibe_comment(
    post_id: int,
    payload: VibeCommentCreateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _get_visible_post_or_404(db, post_id)
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
    _get_visible_post_or_404(db, post_id)
    comments = db.query(VibeComment).filter(VibeComment.post_id == post_id, VibeComment.is_deleted.is_(False)).order_by(VibeComment.created_at.asc()).limit(limit).all()
    return [VibeCommentResponse(id=item.id, post_id=post_id, text=item.text, author=_author_response(item.user), created_at=item.created_at) for item in comments]


@router.delete("/{post_id}", response_model=VibeDeleteResponse)
def delete_vibe(
    post_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = _get_visible_post_or_404(db, post_id)
    if post.author_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the author can delete this Vibe")
    post.is_deleted = True
    db.commit()
    return VibeDeleteResponse(post_id=post_id, deleted=True)
