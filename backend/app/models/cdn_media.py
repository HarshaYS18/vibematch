from datetime import datetime
from enum import Enum

from sqlalchemy import BigInteger, Boolean, DateTime, ForeignKey, Index, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class CdnMediaType(str, Enum):
    PROFILE_PICTURE = "profile_picture"
    COVER_PHOTO = "cover_photo"
    VIBES_MEDIA = "vibes_media"
    INBOX_MEDIA = "inbox_media"
    STORY_MEDIA = "story_media"
    ROOM_THEME = "room_theme"
    CHAT_WALLPAPER = "chat_wallpaper"
    ROOM_AVATAR = "room_avatar"
    ROOM_COVER = "room_cover"
    ROOM_BACKGROUND = "room_background"
    HOME_BANNER = "home_banner"
    ROOM_MUSIC = "room_music"


class CdnMediaUploadStatus(str, Enum):
    PENDING_UPLOAD = "pending_upload"
    UPLOADED = "uploaded"
    PROCESSING = "processing"
    PROCESSING_FAILED = "processing_failed"
    MODERATION_PENDING = "moderation_pending"
    APPROVED = "approved"
    REJECTED = "rejected"
    DELETED = "deleted"
    EXPIRED = "expired"
    QUARANTINED = "quarantined"
    DELETION_FAILED = "deletion_failed"


class MediaProcessingStatus(str, Enum):
    NOT_REQUIRED = "not_required"
    PENDING = "pending"
    PROCESSING = "processing"
    READY = "ready"
    FAILED = "failed"


class MediaUploadSessionStatus(str, Enum):
    CREATED = "created"
    UPLOADING = "uploading"
    COMPLETED = "completed"
    FAILED = "failed"
    EXPIRED = "expired"
    ABORTED = "aborted"


class MediaUploadMode(str, Enum):
    LOCAL_STREAM = "local_stream"
    SINGLE_PUT = "single_put"
    MULTIPART = "multipart"


class CdnMediaModerationStatus(str, Enum):
    NOT_REQUIRED = "not_required"
    PENDING = "pending"
    AI_APPROVED = "ai_approved"
    AI_FLAGGED = "ai_flagged"
    HUMAN_REVIEW_REQUIRED = "human_review_required"
    HUMAN_APPROVED = "human_approved"
    HUMAN_REJECTED = "human_rejected"


class CdnMediaDeletionStatus(str, Enum):
    ACTIVE = "active"
    PENDING_DELETE = "pending_delete"
    DELETED = "deleted"
    FAILED = "failed"
    RETRY_SCHEDULED = "retry_scheduled"


class CdnMediaLinkedEntityType(str, Enum):
    USER_PROFILE = "user_profile"
    VIBES_POST = "vibes_post"
    INBOX_MESSAGE = "inbox_message"
    STORY = "story"
    ROOM = "room"
    HOME_BANNER = "home_banner"


class CdnMediaAsset(Base):
    __tablename__ = "cdn_media_assets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    owner_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), index=True, nullable=True)
    public_user_id: Mapped[int | None] = mapped_column(BigInteger, index=True, nullable=True)

    media_type: Mapped[str] = mapped_column(String(50), index=True, nullable=False)
    object_key: Mapped[str] = mapped_column(String(700), unique=True, index=True, nullable=False)
    public_url: Mapped[str] = mapped_column(String(900), nullable=False)
    thumbnail_url: Mapped[str | None] = mapped_column(String(900), nullable=True)

    mime_type: Mapped[str] = mapped_column(String(120), nullable=False)
    size_bytes: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    duration_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)

    upload_status: Mapped[str] = mapped_column(String(50), default=CdnMediaUploadStatus.UPLOADED.value, index=True, nullable=False)
    moderation_status: Mapped[str] = mapped_column(String(50), default=CdnMediaModerationStatus.NOT_REQUIRED.value, index=True, nullable=False)
    deletion_status: Mapped[str] = mapped_column(String(50), default=CdnMediaDeletionStatus.ACTIVE.value, index=True, nullable=False)
    processing_status: Mapped[str] = mapped_column(
        String(50),
        default=MediaProcessingStatus.NOT_REQUIRED.value,
        index=True,
        nullable=False,
    )
    processing_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    processing_started_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    processing_completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    linked_entity_type: Mapped[str | None] = mapped_column(String(50), index=True, nullable=True)
    linked_entity_id: Mapped[str | None] = mapped_column(String(100), index=True, nullable=True)
    replaced_by_media_id: Mapped[int | None] = mapped_column(Integer, nullable=True, index=True)

    moderation_provider: Mapped[str | None] = mapped_column(String(80), nullable=True)
    moderation_model: Mapped[str | None] = mapped_column(String(120), nullable=True)
    moderation_summary: Mapped[str | None] = mapped_column(Text, nullable=True)
    human_review_status: Mapped[str | None] = mapped_column(String(50), nullable=True, index=True)
    review_reason: Mapped[str | None] = mapped_column(Text, nullable=True)

    deletion_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    is_active_reference: Mapped[bool] = mapped_column(Boolean, default=True, index=True, nullable=False)

    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    owner = relationship("User")


class MediaUploadSession(Base):
    __tablename__ = "media_upload_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    media_id: Mapped[int] = mapped_column(
        ForeignKey("cdn_media_assets.id", ondelete="CASCADE"),
        unique=True,
        index=True,
        nullable=False,
    )
    owner_user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    purpose: Mapped[str] = mapped_column(String(50), index=True, nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    expected_mime_type: Mapped[str] = mapped_column(String(120), nullable=False)
    expected_size_bytes: Mapped[int] = mapped_column(BigInteger, nullable=False)
    object_key: Mapped[str] = mapped_column(String(700), unique=True, index=True, nullable=False)
    storage_driver: Mapped[str] = mapped_column(String(30), nullable=False)
    upload_mode: Mapped[str] = mapped_column(String(30), nullable=False)
    storage_upload_id: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    part_size_bytes: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    part_count: Mapped[int | None] = mapped_column(Integer, nullable=True)
    status: Mapped[str] = mapped_column(
        String(30),
        default=MediaUploadSessionStatus.CREATED.value,
        index=True,
        nullable=False,
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime, index=True, nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    asset = relationship("CdnMediaAsset")
    owner = relationship("User")


class CdnMediaVariant(Base):
    __tablename__ = "cdn_media_variants"
    __table_args__ = (
        Index(
            "uq_cdn_media_variants_media_key",
            "media_id",
            "variant_key",
            unique=True,
        ),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    media_id: Mapped[int] = mapped_column(
        ForeignKey("cdn_media_assets.id", ondelete="CASCADE"),
        index=True,
        nullable=False,
    )
    variant_key: Mapped[str] = mapped_column(String(80), nullable=False)
    kind: Mapped[str] = mapped_column(String(40), nullable=False)
    object_key: Mapped[str] = mapped_column(String(700), unique=True, index=True, nullable=False)
    public_url: Mapped[str] = mapped_column(String(900), nullable=False)
    mime_type: Mapped[str] = mapped_column(String(120), nullable=False)
    width: Mapped[int | None] = mapped_column(Integer, nullable=True)
    height: Mapped[int | None] = mapped_column(Integer, nullable=True)
    bitrate_kbps: Mapped[int | None] = mapped_column(Integer, nullable=True)
    size_bytes: Mapped[int] = mapped_column(BigInteger, default=0, nullable=False)
    duration_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)

    asset = relationship("CdnMediaAsset")


class MediaSafetySetting(Base):
    __tablename__ = "media_safety_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    key: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    value_json: Mapped[dict] = mapped_column(JSON, nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    updated_by_user_id: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    updated_by = relationship("User")