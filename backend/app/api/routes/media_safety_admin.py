from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.api.routes.admin import require_founder_owner
from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.cdn_media import (
    CdnMediaAsset,
    CdnMediaDeletionStatus,
    CdnMediaModerationStatus,
    CdnMediaType,
    CdnMediaUploadStatus,
    MediaSafetySetting,
)
from app.models.user import User
from app.schemas.cdn_media import (
    CdnMediaActionRequest,
    CdnMediaAssetResponse,
    CdnMediaCleanupResponse,
    CdnMediaDashboardResponse,
    MediaSafetySettingResponse,
    MediaSafetySettingUpdateRequest,
)
from app.services import cdn_media_service, inbox_service_client
from app.services.audit_log_service import create_admin_log


router = APIRouter(prefix="/admin/media/safety", tags=["Admin Media Safety"])


def _require_media_safety_access(current_user: User) -> None:
    require_founder_owner(current_user)


def _asset_or_404(db: Session, media_id: str) -> CdnMediaAsset:
    asset = db.query(CdnMediaAsset).filter(CdnMediaAsset.public_id == media_id).first()
    if not asset:
        raise HTTPException(status_code=404, detail="Media asset not found")
    return asset


def _asset_owner(db: Session, asset: CdnMediaAsset) -> User | None:
    if asset.owner_user_id is None:
        return None
    return db.query(User).filter(User.id == asset.owner_user_id).first()


def _friendly_media_type(asset: CdnMediaAsset) -> str:
    return asset.media_type.replace("_", " ")


def _send_media_team_message(db: Session, *, asset: CdnMediaAsset, text: str) -> None:
    owner = _asset_owner(db, asset)
    if owner is None:
        return
    try:
        inbox_service_client.send_team_message(
            target_user_id=owner.id,
            text=text,
        )
    except (inbox_service_client.InboxServiceUnavailable, ValueError):
        return


@router.get("/dashboard", response_model=CdnMediaDashboardResponse)
def media_safety_dashboard(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_media_safety_access(current_user)
    now = datetime.utcnow()
    recent = db.query(CdnMediaAsset).order_by(CdnMediaAsset.id.desc()).limit(25).all()
    return CdnMediaDashboardResponse(
        total_count=db.query(func.count(CdnMediaAsset.id)).scalar() or 0,
        pending_review_count=db.query(func.count(CdnMediaAsset.id)).filter(
            CdnMediaAsset.moderation_status.in_([
                CdnMediaModerationStatus.PENDING.value,
                CdnMediaModerationStatus.AI_FLAGGED.value,
                CdnMediaModerationStatus.HUMAN_REVIEW_REQUIRED.value,
            ])
        ).scalar() or 0,
        deletion_failed_count=db.query(func.count(CdnMediaAsset.id)).filter(
            CdnMediaAsset.deletion_status == CdnMediaDeletionStatus.FAILED.value
        ).scalar() or 0,
        inbox_expiring_count=db.query(func.count(CdnMediaAsset.id)).filter(
            CdnMediaAsset.media_type == CdnMediaType.INBOX_MEDIA.value,
            CdnMediaAsset.expires_at.isnot(None),
            CdnMediaAsset.expires_at <= now + timedelta(days=1),
            CdnMediaAsset.deletion_status == CdnMediaDeletionStatus.ACTIVE.value,
        ).scalar() or 0,
        recent_assets=recent,
    )


@router.get("/assets", response_model=list[CdnMediaAssetResponse])
def list_media_assets(
    media_type: str | None = Query(default=None),
    upload_status: str | None = Query(default=None),
    moderation_status: str | None = Query(default=None),
    deletion_status: str | None = Query(default=None),
    public_user_id: int | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_media_safety_access(current_user)
    query = db.query(CdnMediaAsset)
    if media_type:
        query = query.filter(CdnMediaAsset.media_type == media_type)
    if upload_status:
        query = query.filter(CdnMediaAsset.upload_status == upload_status)
    if moderation_status:
        query = query.filter(CdnMediaAsset.moderation_status == moderation_status)
    if deletion_status:
        query = query.filter(CdnMediaAsset.deletion_status == deletion_status)
    if public_user_id is not None:
        query = query.filter(CdnMediaAsset.public_user_id == public_user_id)
    return query.order_by(CdnMediaAsset.id.desc()).limit(limit).all()


@router.get("/settings", response_model=list[MediaSafetySettingResponse])
def list_media_safety_settings(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_media_safety_access(current_user)
    existing = {setting.key for setting in db.query(MediaSafetySetting).all()}
    for item in cdn_media_service.default_media_safety_settings():
        if item["key"] not in existing:
            cdn_media_service.upsert_media_safety_setting(
                db,
                key=item["key"],
                value_json=item["value_json"],
                description=item.get("description"),
                actor_user_id=current_user.id,
            )
    return db.query(MediaSafetySetting).order_by(MediaSafetySetting.key.asc()).all()


@router.patch("/settings/{key}", response_model=MediaSafetySettingResponse)
def update_media_safety_setting(
    key: str,
    payload: MediaSafetySettingUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_media_safety_access(current_user)
    return cdn_media_service.upsert_media_safety_setting(
        db,
        key=key,
        value_json=payload.value_json,
        description=payload.description,
        actor_user_id=current_user.id,
    )


@router.post("/assets/{media_id}/approve", response_model=CdnMediaAssetResponse)
def approve_media_asset(
    media_id: str,
    payload: CdnMediaActionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_media_safety_access(current_user)
    asset = _asset_or_404(db, media_id)
    asset.upload_status = CdnMediaUploadStatus.APPROVED.value
    asset.moderation_status = CdnMediaModerationStatus.HUMAN_APPROVED.value
    asset.human_review_status = "approved"
    asset.review_reason = payload.reason
    db.add(asset)
    db.commit()
    db.refresh(asset)
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=asset.owner_user_id,
        action="CDN_MEDIA_APPROVED",
        resource_type="cdn_media",
        resource_id=asset.public_id,
        reason=payload.reason,
        metadata_json={"media_type": asset.media_type},
    )
    _send_media_team_message(
        db,
        asset=asset,
        text=f"Your {_friendly_media_type(asset)} was approved after review.",
    )
    return asset


@router.post("/assets/{media_id}/reject", response_model=CdnMediaAssetResponse)
def reject_media_asset(
    media_id: str,
    payload: CdnMediaActionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_media_safety_access(current_user)
    asset = _asset_or_404(db, media_id)
    asset.upload_status = CdnMediaUploadStatus.REJECTED.value
    asset.moderation_status = CdnMediaModerationStatus.HUMAN_REJECTED.value
    asset.human_review_status = "rejected"
    asset.review_reason = payload.reason
    db.add(asset)
    db.commit()
    db.refresh(asset)
    cdn_media_service.mark_media_deleted(db, asset=asset, actor_user_id=current_user.id, reason="media_rejected")
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=asset.owner_user_id,
        action="CDN_MEDIA_REJECTED",
        resource_type="cdn_media",
        resource_id=asset.public_id,
        reason=payload.reason,
        metadata_json={"media_type": asset.media_type},
    )
    _send_media_team_message(
        db,
        asset=asset,
        text=f"Your {_friendly_media_type(asset)} was rejected after review and removed. Reason: {payload.reason}",
    )
    db.refresh(asset)
    return asset


@router.post("/assets/{media_id}/retry-delete", response_model=CdnMediaAssetResponse)
def retry_delete_media_asset(
    media_id: str,
    payload: CdnMediaActionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_media_safety_access(current_user)
    asset = _asset_or_404(db, media_id)
    cdn_media_service.mark_media_deleted(db, asset=asset, actor_user_id=current_user.id, reason=payload.reason)
    db.refresh(asset)
    return asset


@router.post("/cleanup/inbox-expired", response_model=CdnMediaCleanupResponse)
def cleanup_expired_inbox_media(
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_media_safety_access(current_user)
    return cdn_media_service.expire_due_inbox_media(db, limit=limit, actor_user_id=current_user.id)