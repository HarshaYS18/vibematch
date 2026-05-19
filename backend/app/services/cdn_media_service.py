from datetime import datetime, timedelta
from pathlib import Path
from uuid import uuid4

from sqlalchemy.orm import Session

from app.models.cdn_media import (
    CdnMediaAsset,
    CdnMediaDeletionStatus,
    CdnMediaLinkedEntityType,
    CdnMediaModerationStatus,
    CdnMediaType,
    CdnMediaUploadStatus,
    MediaSafetySetting,
)
from app.models.inbox import InboxMessage
from app.models.user import User
from app.services.audit_log_service import create_admin_log


LOCAL_STATIC_PREFIX = "/static/uploads/"
DEFAULT_INBOX_RETENTION_DAYS = 7
INBOX_EXPIRED_PLACEHOLDER = "Media expired"


def object_key_from_public_url(public_url: str) -> str:
    marker = LOCAL_STATIC_PREFIX
    if marker in public_url:
        return public_url.split(marker, 1)[1].lstrip("/")
    return public_url.strip()


def create_media_asset(
    db: Session,
    *,
    owner: User | None,
    media_type: CdnMediaType,
    public_url: str,
    object_key: str | None,
    mime_type: str,
    size_bytes: int,
    linked_entity_type: CdnMediaLinkedEntityType | None = None,
    linked_entity_id: str | None = None,
    expires_at: datetime | None = None,
    moderation_required: bool = False,
    metadata_json: dict | None = None,
) -> CdnMediaAsset:
    status = CdnMediaModerationStatus.PENDING if moderation_required else CdnMediaModerationStatus.NOT_REQUIRED
    upload_status = CdnMediaUploadStatus.MODERATION_PENDING if moderation_required else CdnMediaUploadStatus.APPROVED
    asset = CdnMediaAsset(
        public_id=f"media_{uuid4().hex}",
        owner_user_id=owner.id if owner else None,
        public_user_id=owner.public_user_id if owner else None,
        media_type=media_type.value,
        object_key=object_key or object_key_from_public_url(public_url),
        public_url=public_url,
        mime_type=mime_type,
        size_bytes=size_bytes,
        upload_status=upload_status.value,
        moderation_status=status.value,
        deletion_status=CdnMediaDeletionStatus.ACTIVE.value,
        linked_entity_type=linked_entity_type.value if linked_entity_type else None,
        linked_entity_id=linked_entity_id,
        expires_at=expires_at,
        metadata_json=metadata_json or {},
        is_active_reference=True,
    )
    db.add(asset)
    db.commit()
    db.refresh(asset)
    return asset


def register_uploaded_media(
    db: Session,
    *,
    owner: User,
    media_type: CdnMediaType,
    public_url: str,
    object_key: str | None,
    mime_type: str,
    size_bytes: int,
    linked_entity_type: CdnMediaLinkedEntityType | None = None,
    linked_entity_id: str | None = None,
    metadata_json: dict | None = None,
) -> CdnMediaAsset:
    expires_at = None
    if media_type == CdnMediaType.INBOX_MEDIA:
        expires_at = datetime.utcnow() + timedelta(days=get_inbox_retention_days(db))
    moderation_required = media_type in {
        CdnMediaType.PROFILE_PICTURE,
        CdnMediaType.COVER_PHOTO,
        CdnMediaType.VIBES_MEDIA,
        CdnMediaType.STORY_MEDIA,
    }
    return create_media_asset(
        db,
        owner=owner,
        media_type=media_type,
        public_url=public_url,
        object_key=object_key,
        mime_type=mime_type,
        size_bytes=size_bytes,
        linked_entity_type=linked_entity_type,
        linked_entity_id=linked_entity_id,
        expires_at=expires_at,
        moderation_required=moderation_required,
        metadata_json=metadata_json,
    )


def mark_profile_picture_replaced(
    db: Session,
    *,
    user: User,
    new_asset: CdnMediaAsset,
    actor_user_id: int | None = None,
) -> None:
    old_url = user.avatar_url
    if old_url:
        old_asset = find_active_asset_by_url(db, old_url)
        if old_asset and old_asset.id != new_asset.id:
            old_asset.replaced_by_media_id = new_asset.id
            mark_media_deleted(db, asset=old_asset, actor_user_id=actor_user_id, reason="profile_picture_replaced")
    user.avatar_url = new_asset.public_url
    new_asset.upload_status = CdnMediaUploadStatus.APPROVED.value
    new_asset.moderation_status = CdnMediaModerationStatus.AI_APPROVED.value if new_asset.moderation_status == CdnMediaModerationStatus.PENDING.value else new_asset.moderation_status
    new_asset.is_active_reference = True
    db.add(user)
    db.add(new_asset)
    db.commit()


def add_cover_photo_reference(
    db: Session,
    *,
    user: User,
    new_asset: CdnMediaAsset,
    actor_user_id: int | None = None,
) -> None:
    old_urls = list(user.cover_photo_urls or [])
    for old_url in old_urls:
        old_asset = find_active_asset_by_url(db, old_url)
        if old_asset and old_asset.id != new_asset.id:
            old_asset.replaced_by_media_id = new_asset.id
            mark_media_deleted(db, asset=old_asset, actor_user_id=actor_user_id, reason="cover_photo_replaced")
    user.cover_photo_urls = [new_asset.public_url]
    new_asset.upload_status = CdnMediaUploadStatus.APPROVED.value
    new_asset.moderation_status = CdnMediaModerationStatus.AI_APPROVED.value if new_asset.moderation_status == CdnMediaModerationStatus.PENDING.value else new_asset.moderation_status
    new_asset.is_active_reference = True
    db.add(user)
    db.add(new_asset)
    db.commit()


def find_active_asset_by_url(db: Session, public_url: str) -> CdnMediaAsset | None:
    return (
        db.query(CdnMediaAsset)
        .filter(CdnMediaAsset.public_url == public_url)
        .filter(CdnMediaAsset.deletion_status == CdnMediaDeletionStatus.ACTIVE.value)
        .order_by(CdnMediaAsset.id.desc())
        .first()
    )


def link_media_to_entity(
    db: Session,
    *,
    public_url: str | None,
    linked_entity_type: CdnMediaLinkedEntityType,
    linked_entity_id: str,
) -> CdnMediaAsset | None:
    if not public_url:
        return None
    asset = db.query(CdnMediaAsset).filter(CdnMediaAsset.public_url == public_url).order_by(CdnMediaAsset.id.desc()).first()
    if not asset:
        return None
    asset.linked_entity_type = linked_entity_type.value
    asset.linked_entity_id = linked_entity_id
    db.add(asset)
    db.commit()
    db.refresh(asset)
    return asset


def mark_media_deleted(
    db: Session,
    *,
    asset: CdnMediaAsset,
    actor_user_id: int | None = None,
    reason: str = "media_deleted",
) -> CdnMediaAsset:
    asset.upload_status = CdnMediaUploadStatus.DELETED.value
    asset.deletion_status = CdnMediaDeletionStatus.DELETED.value
    asset.is_active_reference = False
    asset.deleted_at = datetime.utcnow()
    try_delete_local_object(asset.object_key)
    db.add(asset)
    db.commit()
    db.refresh(asset)
    create_admin_log(
        db=db,
        actor_user_id=actor_user_id,
        target_user_id=asset.owner_user_id,
        action="CDN_MEDIA_DELETED",
        resource_type="cdn_media",
        resource_id=asset.public_id,
        reason=reason,
        metadata_json={"media_type": asset.media_type, "object_key": asset.object_key},
    )
    return asset


def _expire_inbox_message_references(db: Session, asset: CdnMediaAsset, now: datetime) -> int:
    messages = db.query(InboxMessage).filter(InboxMessage.attachment_url == asset.public_url).all()
    updated = 0
    for message in messages:
        metadata = dict(message.metadata_json or {})
        metadata["media_expired"] = True
        metadata["expired_media_id"] = asset.public_id
        metadata["media_expired_at"] = now.isoformat()
        message.attachment_url = None
        if message.message_type in {"image", "voice", "document"}:
            message.text = INBOX_EXPIRED_PLACEHOLDER
        message.metadata_json = metadata
        db.add(message)
        updated += 1
    return updated


def expire_due_inbox_media(db: Session, *, limit: int = 100, actor_user_id: int | None = None) -> dict:
    now = datetime.utcnow()
    assets = (
        db.query(CdnMediaAsset)
        .filter(CdnMediaAsset.media_type == CdnMediaType.INBOX_MEDIA.value)
        .filter(CdnMediaAsset.expires_at.isnot(None))
        .filter(CdnMediaAsset.expires_at <= now)
        .filter(CdnMediaAsset.deletion_status == CdnMediaDeletionStatus.ACTIVE.value)
        .order_by(CdnMediaAsset.expires_at.asc())
        .limit(limit)
        .all()
    )
    deleted = 0
    failed = 0
    placeholders = 0
    for asset in assets:
        try:
            asset.upload_status = CdnMediaUploadStatus.EXPIRED.value
            asset.deletion_status = CdnMediaDeletionStatus.DELETED.value
            asset.is_active_reference = False
            asset.deleted_at = now
            placeholders += _expire_inbox_message_references(db, asset, now)
            try_delete_local_object(asset.object_key)
            db.add(asset)
            deleted += 1
        except Exception as exc:  # pragma: no cover - defensive cleanup guard
            asset.deletion_status = CdnMediaDeletionStatus.FAILED.value
            asset.deletion_error = str(exc)
            db.add(asset)
            failed += 1
    db.commit()
    create_admin_log(
        db=db,
        actor_user_id=actor_user_id,
        action="INBOX_MEDIA_EXPIRY_CLEANUP_RUN",
        resource_type="cdn_media_cleanup",
        reason="manual_or_scheduled_cleanup",
        metadata_json={"checked": len(assets), "deleted": deleted, "failed": failed, "placeholders": placeholders},
    )
    return {"checked": len(assets), "deleted": deleted, "failed": failed}


def try_delete_local_object(object_key: str | None) -> None:
    if not object_key:
        return
    normalized = object_key.replace("\\", "/").lstrip("/")
    if ".." in Path(normalized).parts:
        return
    path = Path("static/uploads") / normalized
    if path.exists() and path.is_file():
        path.unlink()


def get_inbox_retention_days(db: Session) -> int:
    setting = db.query(MediaSafetySetting).filter(MediaSafetySetting.key == "inbox_media_retention").first()
    if not setting:
        return DEFAULT_INBOX_RETENTION_DAYS
    try:
        days = int(setting.value_json.get("days", DEFAULT_INBOX_RETENTION_DAYS))
    except Exception:
        days = DEFAULT_INBOX_RETENTION_DAYS
    return max(1, min(days, 90))


def upsert_media_safety_setting(
    db: Session,
    *,
    key: str,
    value_json: dict,
    description: str | None,
    actor_user_id: int,
) -> MediaSafetySetting:
    setting = db.query(MediaSafetySetting).filter(MediaSafetySetting.key == key).first()
    old_value = setting.value_json if setting else None
    if setting is None:
        setting = MediaSafetySetting(key=key, value_json=value_json, description=description, updated_by_user_id=actor_user_id)
    else:
        setting.value_json = value_json
        setting.description = description
        setting.updated_by_user_id = actor_user_id
    db.add(setting)
    db.commit()
    db.refresh(setting)
    create_admin_log(
        db=db,
        actor_user_id=actor_user_id,
        action="MEDIA_SAFETY_SETTING_UPDATED",
        resource_type="media_safety_setting",
        resource_id=key,
        metadata_json={"old_value": old_value, "new_value": value_json},
    )
    return setting


def default_media_safety_settings() -> list[dict]:
    return [
        {
            "key": "inbox_media_retention",
            "description": "Inbox media CDN retention policy.",
            "value_json": {"days": DEFAULT_INBOX_RETENTION_DAYS, "placeholder_enabled": True, "cleanup_enabled": True, "batch_size": 100},
        },
        {
            "key": "openai_image_moderation",
            "description": "OpenAI image auditing surfaces and fallback behavior.",
            "value_json": {"enabled": False, "profile_picture": True, "cover_photo": True, "vibes_media": True, "inbox_media": False, "uncertain_to_review": True},
        },
        {
            "key": "openai_text_moderation",
            "description": "OpenAI text moderation mode by surface.",
            "value_json": {"enabled": False, "default_mode": "flag_only", "inbox_messages": "flag_only", "profile_text": "block_high_risk", "vibes_caption": "block_high_risk"},
        },
    ]