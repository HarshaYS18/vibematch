from datetime import datetime
from enum import Enum

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class InboxBackupProvider(str, Enum):
    GOOGLE_DRIVE = "google_drive"


class InboxBackupStatus(str, Enum):
    NOT_CONNECTED = "not_connected"
    CONNECTED = "connected"
    BACKUP_RUNNING = "backup_running"
    BACKUP_COMPLETED = "backup_completed"
    BACKUP_FAILED = "backup_failed"
    RESTORE_RUNNING = "restore_running"
    RESTORE_COMPLETED = "restore_completed"
    RESTORE_FAILED = "restore_failed"


class InboxBackupFrequency(str, Enum):
    DAILY = "daily"
    WEEKLY = "weekly"
    MONTHLY = "monthly"
    MANUAL = "manual"


class InboxBackupSetting(Base):
    __tablename__ = "inbox_backup_settings"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), unique=True, index=True, nullable=False)
    provider: Mapped[str] = mapped_column(String(40), default=InboxBackupProvider.GOOGLE_DRIVE.value, index=True)
    is_enabled: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    is_authorized: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    frequency: Mapped[str] = mapped_column(String(24), default=InboxBackupFrequency.WEEKLY.value)
    google_drive_email: Mapped[str | None] = mapped_column(String(160), nullable=True)
    google_drive_folder_id: Mapped[str | None] = mapped_column(String(240), nullable=True)
    encrypted_refresh_token: Mapped[str | None] = mapped_column(Text, nullable=True)
    last_backup_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_restore_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    last_status: Mapped[str] = mapped_column(String(40), default=InboxBackupStatus.NOT_CONNECTED.value, index=True)
    last_error: Mapped[str | None] = mapped_column(Text, nullable=True)
    backup_count: Mapped[int] = mapped_column(Integer, default=0)
    restore_count: Mapped[int] = mapped_column(Integer, default=0)
    metadata_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, index=True)

    user = relationship("User")


class InboxBackupJob(Base):
    __tablename__ = "inbox_backup_jobs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    public_id: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True, nullable=False)
    job_type: Mapped[str] = mapped_column(String(24), index=True, nullable=False)
    provider: Mapped[str] = mapped_column(String(40), default=InboxBackupProvider.GOOGLE_DRIVE.value, index=True)
    status: Mapped[str] = mapped_column(String(40), default=InboxBackupStatus.BACKUP_RUNNING.value, index=True)
    backup_file_id: Mapped[str | None] = mapped_column(String(240), nullable=True)
    backup_file_name: Mapped[str | None] = mapped_column(String(240), nullable=True)
    encrypted_payload_json: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    error_message: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, index=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True, index=True)

    user = relationship("User")
