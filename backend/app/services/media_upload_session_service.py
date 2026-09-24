from __future__ import annotations

import math
import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path
from uuid import uuid4

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.cdn_media import (
    CdnMediaAsset,
    CdnMediaDeletionStatus,
    CdnMediaLinkedEntityType,
    CdnMediaModerationStatus,
    CdnMediaType,
    CdnMediaUploadStatus,
    CdnMediaVariant,
    MediaProcessingStatus,
    MediaUploadMode,
    MediaUploadSession,
    MediaUploadSessionStatus,
)
from app.models.user import User
from app.services import cdn_media_service, event_outbox_service, media_storage_service


ALLOWED_IMAGE_TYPES = frozenset({"image/jpeg", "image/png", "image/webp", "image/gif"})
ALLOWED_VIDEO_TYPES = frozenset({"video/mp4", "video/webm", "video/quicktime"})
ALLOWED_AUDIO_TYPES = frozenset({
    "audio/mpeg", "audio/mp3", "audio/mp4", "audio/aac", "audio/x-aac",
    "audio/wav", "audio/x-wav", "audio/webm", "audio/ogg", "application/ogg",
    "audio/m4a", "audio/flac", "audio/x-flac",
})
ALLOWED_DOCUMENT_TYPES = frozenset({
    "application/pdf", "text/plain", "text/csv", "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "application/vnd.ms-excel",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "application/vnd.ms-powerpoint",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "application/zip",
})
_CONTENT_TYPE_BY_EXTENSION = {
    ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png",
    ".webp": "image/webp", ".gif": "image/gif", ".mp4": "video/mp4",
    ".webm": "video/webm", ".mov": "video/quicktime", ".mp3": "audio/mpeg",
    ".m4a": "audio/mp4", ".aac": "audio/aac", ".wav": "audio/wav",
    ".ogg": "audio/ogg", ".oga": "audio/ogg", ".opus": "audio/ogg",
    ".weba": "audio/webm", ".flac": "audio/flac", ".pdf": "application/pdf",
    ".txt": "text/plain", ".csv": "text/csv", ".doc": "application/msword",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".xls": "application/vnd.ms-excel",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".ppt": "application/vnd.ms-powerpoint",
    ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".zip": "application/zip",
}


@dataclass(frozen=True)
class PurposeSpec:
    folder: str
    max_size_bytes: int
    allowed_content_types: frozenset[str]
    media_type: CdnMediaType
    linked_entity_type: CdnMediaLinkedEntityType
    moderation_required: bool = False


PURPOSES: dict[str, PurposeSpec] = {
    "avatar": PurposeSpec("avatars", 10 * 1024 * 1024, ALLOWED_IMAGE_TYPES, CdnMediaType.PROFILE_PICTURE, CdnMediaLinkedEntityType.USER_PROFILE, True),
    "profile_cover": PurposeSpec("profile_covers", 10 * 1024 * 1024, ALLOWED_IMAGE_TYPES, CdnMediaType.COVER_PHOTO, CdnMediaLinkedEntityType.USER_PROFILE, True),
    "room_avatar": PurposeSpec("room_avatars", 10 * 1024 * 1024, ALLOWED_IMAGE_TYPES, CdnMediaType.ROOM_AVATAR, CdnMediaLinkedEntityType.ROOM),
    "room_cover": PurposeSpec("room_covers", 10 * 1024 * 1024, ALLOWED_IMAGE_TYPES, CdnMediaType.ROOM_COVER, CdnMediaLinkedEntityType.ROOM),
    "room_background": PurposeSpec("room_backgrounds", 15 * 1024 * 1024, ALLOWED_IMAGE_TYPES, CdnMediaType.ROOM_BACKGROUND, CdnMediaLinkedEntityType.ROOM),
    "home_banner": PurposeSpec("home_banners", 10 * 1024 * 1024, ALLOWED_IMAGE_TYPES, CdnMediaType.HOME_BANNER, CdnMediaLinkedEntityType.HOME_BANNER),
    "chat_image": PurposeSpec("chat_images", 10 * 1024 * 1024, ALLOWED_IMAGE_TYPES, CdnMediaType.INBOX_MEDIA, CdnMediaLinkedEntityType.INBOX_MESSAGE),
    "chat_document": PurposeSpec("chat_documents", 20 * 1024 * 1024, ALLOWED_DOCUMENT_TYPES, CdnMediaType.INBOX_MEDIA, CdnMediaLinkedEntityType.INBOX_MESSAGE),
    "chat_voice": PurposeSpec("chat_voice", 10 * 1024 * 1024, ALLOWED_AUDIO_TYPES, CdnMediaType.INBOX_MEDIA, CdnMediaLinkedEntityType.INBOX_MESSAGE),
    "vibes": PurposeSpec("vibes", 20 * 1024 * 1024, ALLOWED_IMAGE_TYPES | ALLOWED_VIDEO_TYPES, CdnMediaType.VIBES_MEDIA, CdnMediaLinkedEntityType.VIBES_POST, True),
    "story": PurposeSpec("stories", 20 * 1024 * 1024, ALLOWED_IMAGE_TYPES | ALLOWED_VIDEO_TYPES, CdnMediaType.STORY_MEDIA, CdnMediaLinkedEntityType.STORY, True),
    "room_music": PurposeSpec("room_music", 25 * 1024 * 1024, ALLOWED_AUDIO_TYPES, CdnMediaType.ROOM_MUSIC, CdnMediaLinkedEntityType.ROOM),
}


class MediaUploadSessionError(ValueError):
    pass


def _normalized_content_type(filename: str, raw: str) -> str:
    value = (raw or "").split(";", 1)[0].strip().lower()
    inferred = _CONTENT_TYPE_BY_EXTENSION.get(Path(filename).suffix.lower())
    if value in {"", "application/octet-stream"} and inferred:
        return inferred
    return value


def _safe_extension(filename: str, content_type: str) -> str:
    suffix = Path(filename or "").suffix.lower()
    if re.fullmatch(r"\.[a-z0-9]{1,8}", suffix):
        return suffix
    for extension, mime_type in _CONTENT_TYPE_BY_EXTENSION.items():
        if mime_type == content_type:
            return extension
    return ".bin"


def _purpose(value: str) -> tuple[str, PurposeSpec]:
    key = (value or "").strip().lower().replace("-", "_")
    spec = PURPOSES.get(key)
    if spec is None:
        raise MediaUploadSessionError("Unsupported media upload purpose")
    return key, spec


def create_upload_session(
    db: Session,
    *,
    owner: User,
    purpose: str,
    filename: str,
    content_type: str,
    size_bytes: int,
    request_base_url: str,
) -> tuple[MediaUploadSession, CdnMediaAsset, media_storage_service.DirectUploadPlan | None]:
    purpose_key, spec = _purpose(purpose)
    if size_bytes <= 0:
        raise MediaUploadSessionError("Media size must be greater than zero")
    if size_bytes > spec.max_size_bytes:
        raise MediaUploadSessionError(
            f"Media exceeds the {spec.max_size_bytes // (1024 * 1024)} MB limit"
        )
    resolved_type = _normalized_content_type(filename, content_type)
    if resolved_type not in spec.allowed_content_types:
        raise MediaUploadSessionError("Unsupported media content type")

    now = datetime.utcnow()
    expires_at = now + timedelta(seconds=settings.MEDIA_UPLOAD_SESSION_TTL_SECONDS)
    object_key = (
        f"incoming/{spec.folder}/user_{owner.id}/"
        f"{uuid4().hex}{_safe_extension(filename, resolved_type)}"
    )
    public_url = media_storage_service.public_url_for_object(
        object_key=object_key,
        request_base_url=request_base_url,
    )
    moderation_status = (
        CdnMediaModerationStatus.PENDING.value
        if spec.moderation_required
        else CdnMediaModerationStatus.NOT_REQUIRED.value
    )
    asset = CdnMediaAsset(
        public_id=f"media_{uuid4().hex}",
        owner_user_id=owner.id,
        public_user_id=owner.public_user_id,
        media_type=spec.media_type.value,
        object_key=object_key,
        public_url=public_url,
        mime_type=resolved_type,
        size_bytes=int(size_bytes),
        upload_status=CdnMediaUploadStatus.PENDING_UPLOAD.value,
        moderation_status=moderation_status,
        deletion_status=CdnMediaDeletionStatus.ACTIVE.value,
        processing_status=MediaProcessingStatus.PENDING.value,
        linked_entity_type=spec.linked_entity_type.value,
        linked_entity_id=(
            str(owner.id)
            if spec.linked_entity_type == CdnMediaLinkedEntityType.USER_PROFILE
            else None
        ),
        metadata_json={
            "upload_purpose": purpose_key,
            "original_filename": Path(filename).name[:255],
        },
        is_active_reference=False,
        expires_at=(
            now + timedelta(days=cdn_media_service.get_inbox_retention_days(db))
            if spec.media_type == CdnMediaType.INBOX_MEDIA
            else None
        ),
    )
    db.add(asset)
    db.flush()

    driver = media_storage_service.storage_driver()
    plan: media_storage_service.DirectUploadPlan | None = None
    upload_mode = MediaUploadMode.LOCAL_STREAM.value
    if driver == "s3":
        plan = media_storage_service.create_direct_upload(
            object_key=object_key,
            content_type=resolved_type,
            size_bytes=int(size_bytes),
            expires_seconds=settings.MEDIA_UPLOAD_SESSION_TTL_SECONDS,
        )
        upload_mode = plan.mode
    elif driver != "local":
        raise MediaUploadSessionError("Unsupported media storage driver")

    session = MediaUploadSession(
        public_id=f"upload_{uuid4().hex}",
        media_id=asset.id,
        owner_user_id=owner.id,
        purpose=purpose_key,
        original_filename=Path(filename).name[:255] or "media.bin",
        expected_mime_type=resolved_type,
        expected_size_bytes=int(size_bytes),
        object_key=object_key,
        storage_driver=driver,
        upload_mode=upload_mode,
        storage_upload_id=plan.upload_id if plan else None,
        part_size_bytes=plan.part_size_bytes if plan else None,
        part_count=len(plan.parts) if plan else None,
        status=MediaUploadSessionStatus.CREATED.value,
        expires_at=expires_at,
    )
    db.add(session)
    try:
        db.commit()
    except Exception:
        db.rollback()
        if plan and plan.upload_id:
            try:
                media_storage_service.abort_multipart_upload(
                    object_key=object_key,
                    upload_id=plan.upload_id,
                )
            except Exception:
                pass
        raise
    db.refresh(session)
    db.refresh(asset)
    return session, asset, plan


def get_owned_session(
    db: Session,
    *,
    owner_user_id: int,
    session_id: str,
    for_update: bool = False,
) -> MediaUploadSession:
    query = (
        db.query(MediaUploadSession)
        .filter(
            MediaUploadSession.public_id == session_id,
            MediaUploadSession.owner_user_id == int(owner_user_id),
        )
    )
    if for_update:
        query = query.with_for_update()
    session = query.first()
    if session is None:
        raise MediaUploadSessionError("Media upload session not found")
    return session


def mark_local_stream_uploaded(
    db: Session,
    *,
    session: MediaUploadSession,
    bytes_written: int,
) -> None:
    if session.storage_driver != "local":
        raise MediaUploadSessionError("Local upload endpoint is disabled for this session")
    if datetime.utcnow() > session.expires_at:
        session.status = MediaUploadSessionStatus.EXPIRED.value
        db.add(session)
        db.commit()
        raise MediaUploadSessionError("Media upload session expired")
    if bytes_written != int(session.expected_size_bytes):
        raise MediaUploadSessionError("Uploaded byte count does not match the session")
    session.status = MediaUploadSessionStatus.UPLOADING.value
    db.add(session)
    db.commit()


def _fail_verification(
    db: Session,
    *,
    session: MediaUploadSession,
    asset: CdnMediaAsset,
    reason: str,
) -> None:
    session.status = MediaUploadSessionStatus.FAILED.value
    asset.upload_status = CdnMediaUploadStatus.REJECTED.value
    asset.processing_status = MediaProcessingStatus.FAILED.value
    asset.processing_error = reason[:500]
    event_outbox_service.enqueue_event(
        db,
        event_type="media.delete.requested",
        actor_user_id=session.owner_user_id,
        payload={"media_id": asset.public_id, "reason": "upload_verification_failed"},
    )
    db.add(session)
    db.add(asset)
    db.commit()


def complete_upload_session(
    db: Session,
    *,
    owner_user_id: int,
    session_id: str,
    parts: list[dict[str, object]],
) -> tuple[CdnMediaAsset, bool]:
    session = get_owned_session(
        db,
        owner_user_id=owner_user_id,
        session_id=session_id,
        for_update=True,
    )
    asset = (
        db.query(CdnMediaAsset)
        .filter(CdnMediaAsset.id == session.media_id)
        .with_for_update()
        .first()
    )
    if asset is None:
        raise MediaUploadSessionError("Media asset not found")
    if session.status == MediaUploadSessionStatus.COMPLETED.value:
        return asset, True
    if session.status in {
        MediaUploadSessionStatus.FAILED.value,
        MediaUploadSessionStatus.ABORTED.value,
        MediaUploadSessionStatus.EXPIRED.value,
    }:
        raise MediaUploadSessionError("Media upload session is not completable")
    if datetime.utcnow() > session.expires_at:
        session.status = MediaUploadSessionStatus.EXPIRED.value
        db.add(session)
        db.commit()
        raise MediaUploadSessionError("Media upload session expired")

    if session.upload_mode == MediaUploadMode.MULTIPART.value:
        expected_parts = int(session.part_count or 0)
        if len(parts) != expected_parts:
            raise MediaUploadSessionError("Multipart completion is missing parts")
        normalized_parts = sorted(
            (
                {
                    "part_number": int(part["part_number"]),
                    "etag": str(part["etag"]).strip(),
                }
                for part in parts
            ),
            key=lambda item: int(item["part_number"]),
        )
        if [int(item["part_number"]) for item in normalized_parts] != list(
            range(1, expected_parts + 1)
        ):
            raise MediaUploadSessionError("Multipart part numbers are invalid")
        if not all(str(item["etag"]) for item in normalized_parts):
            raise MediaUploadSessionError("Multipart ETags are required")
        media_storage_service.complete_multipart_upload(
            object_key=session.object_key,
            upload_id=session.storage_upload_id or "",
            parts=normalized_parts,
        )
    elif parts:
        raise MediaUploadSessionError("Single-part upload must not include multipart parts")

    head = media_storage_service.head_media_object(session.object_key)
    if head.size_bytes != int(session.expected_size_bytes):
        _fail_verification(
            db,
            session=session,
            asset=asset,
            reason="size_mismatch",
        )
        raise MediaUploadSessionError("Uploaded object size does not match the session")
    actual_type = (head.content_type or "").split(";", 1)[0].strip().lower()
    if actual_type and actual_type != session.expected_mime_type:
        _fail_verification(
            db,
            session=session,
            asset=asset,
            reason="content_type_mismatch",
        )
        raise MediaUploadSessionError("Uploaded object content type does not match the session")

    now = datetime.utcnow()
    session.status = MediaUploadSessionStatus.COMPLETED.value
    session.completed_at = now
    asset.size_bytes = head.size_bytes
    asset.mime_type = session.expected_mime_type
    asset.upload_status = CdnMediaUploadStatus.PROCESSING.value
    asset.processing_status = MediaProcessingStatus.PENDING.value
    asset.processing_error = None
    event_outbox_service.enqueue_event(
        db,
        event_type="media.uploaded",
        actor_user_id=session.owner_user_id,
        payload={
            "media_id": asset.public_id,
            "upload_session_id": session.public_id,
        },
    )
    db.add(session)
    db.add(asset)
    db.commit()
    db.refresh(asset)
    return asset, False


def media_status(
    db: Session,
    *,
    owner_user_id: int,
    media_id: str,
) -> tuple[CdnMediaAsset, list[CdnMediaVariant]]:
    asset = (
        db.query(CdnMediaAsset)
        .filter(
            CdnMediaAsset.public_id == media_id,
            CdnMediaAsset.owner_user_id == int(owner_user_id),
        )
        .first()
    )
    if asset is None:
        raise MediaUploadSessionError("Media asset not found")
    variants = (
        db.query(CdnMediaVariant)
        .filter(CdnMediaVariant.media_id == asset.id)
        .order_by(CdnMediaVariant.variant_key.asc())
        .all()
    )
    return asset, variants
