from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from app.models.inbox import InboxConversation, InboxParticipant
from app.models.inbox_backup import (
    InboxBackupFrequency,
    InboxBackupJob,
    InboxBackupProvider,
    InboxBackupSetting,
    InboxBackupStatus,
)
from app.models.user import User


def _public_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:20]}"


def get_or_create_setting(db: Session, user: User) -> InboxBackupSetting:
    setting = db.query(InboxBackupSetting).filter(InboxBackupSetting.user_id == user.id).first()
    if setting:
        return setting
    setting = InboxBackupSetting(user_id=user.id)
    db.add(setting)
    db.commit()
    db.refresh(setting)
    return setting


def status_payload(setting: InboxBackupSetting) -> dict:
    return {
        "is_enabled": setting.is_enabled,
        "is_authorized": setting.is_authorized,
        "provider": setting.provider,
        "frequency": setting.frequency,
        "google_drive_email": setting.google_drive_email,
        "google_drive_folder_id": setting.google_drive_folder_id,
        "last_backup_at": setting.last_backup_at.isoformat() if setting.last_backup_at else None,
        "last_restore_at": setting.last_restore_at.isoformat() if setting.last_restore_at else None,
        "last_status": setting.last_status,
        "last_error": setting.last_error,
        "backup_count": setting.backup_count,
        "restore_count": setting.restore_count,
    }


def get_status(db: Session, user: User) -> dict:
    return status_payload(get_or_create_setting(db, user))


def google_drive_authorize_url(user: User) -> str:
    # Production: replace with real Google OAuth URL using client_id, redirect_uri, scopes, and signed state.
    return f"https://accounts.google.com/o/oauth2/v2/auth?client_id=VIBE_MATCH_GOOGLE_CLIENT_ID&redirect_uri=http://127.0.0.1:8000/inbox/backup/google/callback&response_type=code&scope=https://www.googleapis.com/auth/drive.file&access_type=offline&prompt=consent&state=inbox_backup_user_{user.id}"


def connect_google_drive_mock(db: Session, user: User, google_email: str | None = None) -> InboxBackupSetting:
    setting = get_or_create_setting(db, user)
    setting.provider = InboxBackupProvider.GOOGLE_DRIVE.value
    setting.is_authorized = True
    setting.is_enabled = True
    setting.google_drive_email = google_email or user.email or f"user-{user.public_user_id}@drive.local"
    setting.google_drive_folder_id = setting.google_drive_folder_id or f"vm_inbox_backup_{user.public_user_id}"
    setting.last_status = InboxBackupStatus.CONNECTED.value
    setting.last_error = None
    db.commit()
    db.refresh(setting)
    return setting


def update_settings(db: Session, user: User, is_enabled: bool | None = None, frequency: str | None = None) -> InboxBackupSetting:
    setting = get_or_create_setting(db, user)
    if is_enabled is not None:
        setting.is_enabled = is_enabled
    if frequency is not None:
        setting.frequency = frequency
    db.commit()
    db.refresh(setting)
    return setting


def _serialize_conversation(conversation: InboxConversation, user: User) -> dict:
    return {
        "id": conversation.public_id,
        "title": conversation.title,
        "type": conversation.conversation_type,
        "is_locked": conversation.is_locked,
        "is_muted": conversation.is_muted,
        "is_pinned": conversation.is_pinned,
        "messages": [
            {
                "id": message.public_id,
                "sender_name": message.sender_name,
                "text": message.text,
                "type": message.message_type,
                "created_at": message.created_at.isoformat() if message.created_at else None,
                "is_mine": message.sender_user_id == user.id,
            }
            for message in conversation.messages
        ],
    }


def run_backup_now(db: Session, user: User) -> InboxBackupJob:
    setting = get_or_create_setting(db, user)
    if not setting.is_authorized:
        raise ValueError("Google Drive is not authorized for Inbox backup.")

    conversations = (
        db.query(InboxConversation)
        .join(InboxParticipant, InboxParticipant.conversation_id == InboxConversation.id)
        .filter(InboxParticipant.user_id == user.id)
        .all()
    )
    payload = {
        "version": 1,
        "created_at": datetime.utcnow().isoformat(),
        "user_public_id": user.public_user_id,
        "conversations": [_serialize_conversation(item, user) for item in conversations],
    }
    job = InboxBackupJob(
        public_id=_public_id("backup"),
        user_id=user.id,
        job_type="backup",
        provider=InboxBackupProvider.GOOGLE_DRIVE.value,
        status=InboxBackupStatus.BACKUP_COMPLETED.value,
        backup_file_id=f"drive_file_{uuid4().hex[:18]}",
        backup_file_name=f"vibematch_inbox_backup_{user.public_user_id}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json.enc",
        encrypted_payload_json=payload,
        completed_at=datetime.utcnow(),
    )
    setting.last_backup_at = job.completed_at
    setting.last_status = InboxBackupStatus.BACKUP_COMPLETED.value
    setting.last_error = None
    setting.backup_count += 1
    db.add(job)
    db.commit()
    db.refresh(job)
    return job


def run_restore_latest(db: Session, user: User) -> InboxBackupJob:
    setting = get_or_create_setting(db, user)
    if not setting.is_authorized:
        raise ValueError("Google Drive is not authorized for Inbox restore.")
    latest = (
        db.query(InboxBackupJob)
        .filter(InboxBackupJob.user_id == user.id)
        .filter(InboxBackupJob.job_type == "backup")
        .filter(InboxBackupJob.status == InboxBackupStatus.BACKUP_COMPLETED.value)
        .order_by(InboxBackupJob.created_at.desc())
        .first()
    )
    if not latest:
        raise ValueError("No backup found to restore.")
    job = InboxBackupJob(
        public_id=_public_id("restore"),
        user_id=user.id,
        job_type="restore",
        provider=InboxBackupProvider.GOOGLE_DRIVE.value,
        status=InboxBackupStatus.RESTORE_COMPLETED.value,
        backup_file_id=latest.backup_file_id,
        backup_file_name=latest.backup_file_name,
        encrypted_payload_json={"restored_from": latest.public_id, "restored_at": datetime.utcnow().isoformat()},
        completed_at=datetime.utcnow(),
    )
    setting.last_restore_at = job.completed_at
    setting.last_status = InboxBackupStatus.RESTORE_COMPLETED.value
    setting.last_error = None
    setting.restore_count += 1
    db.add(job)
    db.commit()
    db.refresh(job)
    return job


def job_payload(job: InboxBackupJob) -> dict:
    return {
        "id": job.public_id,
        "job_type": job.job_type,
        "provider": job.provider,
        "status": job.status,
        "backup_file_id": job.backup_file_id,
        "backup_file_name": job.backup_file_name,
        "error_message": job.error_message,
        "created_at": job.created_at.isoformat() if job.created_at else None,
        "completed_at": job.completed_at.isoformat() if job.completed_at else None,
    }
