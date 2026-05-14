from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.inbox import InboxConversation, InboxParticipant
from app.models.inbox_backup import (
    InboxBackupJob,
    InboxBackupProvider,
    InboxBackupSetting,
    InboxBackupStatus,
)
from app.models.user import User
from app.services import google_drive_service


def _public_id(prefix: str) -> str:
    return f"{prefix}_{uuid4().hex[:20]}"


def _is_google_drive_configured() -> bool:
    return bool(settings.GOOGLE_DRIVE_CLIENT_ID and settings.GOOGLE_DRIVE_CLIENT_SECRET)


def _dev_mock_auth_url(user: User) -> str:
    return (
        "vibematch-dev://inbox-backup/google-drive/mock-authorize"
        f"?state=inbox_backup_user_{user.id}"
        "&code=dev_mock_drive_code"
    )


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
    if not _is_google_drive_configured():
        return _dev_mock_auth_url(user)
    return google_drive_service.build_authorization_url(state=f"inbox_backup_user_{user.id}")


def connect_google_drive(db: Session, user: User, authorization_code: str | None, google_email: str | None = None) -> InboxBackupSetting:
    setting = get_or_create_setting(db, user)

    if not _is_google_drive_configured():
        setting.provider = InboxBackupProvider.GOOGLE_DRIVE.value
        setting.is_authorized = True
        setting.is_enabled = True
        setting.google_drive_email = google_email or user.email or f"user_{user.public_user_id}@vibematch.dev"
        setting.google_drive_folder_id = setting.google_drive_folder_id or f"dev_drive_folder_{user.public_user_id}"
        setting.encrypted_refresh_token = google_drive_service.encrypt_text("dev_mock_refresh_token")
        setting.last_status = InboxBackupStatus.CONNECTED.value
        setting.last_error = None
        setting.metadata_json = {
            "mode": "dev_mock",
            "note": "Google OAuth is not configured. This connection is for local/dev testing only.",
            "connected_at": datetime.utcnow().isoformat(),
        }
        db.commit()
        db.refresh(setting)
        return setting

    if not authorization_code:
        raise ValueError("Authorization code is required to connect Google Drive.")

    tokens = google_drive_service.exchange_code_for_tokens(authorization_code)
    access_token = tokens.get("access_token")
    refresh_token = tokens.get("refresh_token")
    if not access_token or not refresh_token:
        raise ValueError("Google did not return the required access and refresh tokens.")

    email = google_email or google_drive_service.get_profile_email(access_token) or user.email
    folder_id = google_drive_service.ensure_backup_folder(access_token, setting.google_drive_folder_id)

    setting.provider = InboxBackupProvider.GOOGLE_DRIVE.value
    setting.is_authorized = True
    setting.is_enabled = True
    setting.google_drive_email = email
    setting.google_drive_folder_id = folder_id
    setting.encrypted_refresh_token = google_drive_service.encrypt_text(refresh_token)
    setting.last_status = InboxBackupStatus.CONNECTED.value
    setting.last_error = None
    setting.metadata_json = {
        "token_type": tokens.get("token_type"),
        "scope": tokens.get("scope"),
        "access_token_expires_at": google_drive_service.utc_expiry(tokens.get("expires_in")),
    }
    db.commit()
    db.refresh(setting)
    return setting


def update_settings(db: Session, user: User, is_enabled: bool | None = None, frequency: str | None = None) -> InboxBackupSetting:
    setting = get_or_create_setting(db, user)
    if is_enabled is not None:
        if is_enabled and not setting.is_authorized:
            raise ValueError("Connect Google Drive before enabling Inbox backup.")
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


def _access_token_from_setting(setting: InboxBackupSetting) -> str:
    if not setting.encrypted_refresh_token:
        raise ValueError("Google Drive refresh token is missing. Reconnect Google Drive.")
    refresh_token = google_drive_service.decrypt_text(setting.encrypted_refresh_token)
    tokens = google_drive_service.refresh_access_token(refresh_token)
    access_token = tokens.get("access_token")
    if not access_token:
        raise ValueError("Could not refresh Google Drive access token.")
    return access_token


def _build_backup_payload(db: Session, user: User) -> dict:
    conversations = (
        db.query(InboxConversation)
        .join(InboxParticipant, InboxParticipant.conversation_id == InboxConversation.id)
        .filter(InboxParticipant.user_id == user.id)
        .all()
    )
    return {
        "version": 1,
        "created_at": datetime.utcnow().isoformat(),
        "user_public_id": user.public_user_id,
        "conversations": [_serialize_conversation(item, user) for item in conversations],
    }


def run_backup_now(db: Session, user: User) -> InboxBackupJob:
    setting = get_or_create_setting(db, user)
    if not setting.is_authorized:
        raise ValueError("Google Drive is not authorized for Inbox backup.")

    payload = _build_backup_payload(db, user)
    encrypted_payload = {"payload": google_drive_service.encrypt_text(str(payload))}
    filename = f"vibematch_inbox_backup_{user.public_user_id}_{datetime.utcnow().strftime('%Y%m%d_%H%M%S')}.json.enc"

    job = InboxBackupJob(
        public_id=_public_id("backup"),
        user_id=user.id,
        job_type="backup",
        provider=InboxBackupProvider.GOOGLE_DRIVE.value,
        status=InboxBackupStatus.BACKUP_RUNNING.value,
        backup_file_name=filename,
        encrypted_payload_json=encrypted_payload,
    )
    db.add(job)
    db.commit()
    db.refresh(job)

    try:
        if not _is_google_drive_configured():
            job.backup_file_id = f"dev_drive_file_{job.public_id}"
            job.status = InboxBackupStatus.BACKUP_COMPLETED.value
            job.completed_at = datetime.utcnow()
            setting.last_backup_at = job.completed_at
            setting.last_status = InboxBackupStatus.BACKUP_COMPLETED.value
            setting.last_error = None
            setting.backup_count += 1
            setting.metadata_json = {
                **(setting.metadata_json or {}),
                "last_dev_backup_file_id": job.backup_file_id,
                "last_dev_backup_file_name": filename,
            }
        else:
            access_token = _access_token_from_setting(setting)
            folder_id = google_drive_service.ensure_backup_folder(access_token, setting.google_drive_folder_id)
            setting.google_drive_folder_id = folder_id
            file_id = google_drive_service.upload_backup_file(access_token, folder_id, filename, encrypted_payload)
            job.backup_file_id = file_id
            job.status = InboxBackupStatus.BACKUP_COMPLETED.value
            job.completed_at = datetime.utcnow()
            setting.last_backup_at = job.completed_at
            setting.last_status = InboxBackupStatus.BACKUP_COMPLETED.value
            setting.last_error = None
            setting.backup_count += 1
    except Exception as error:
        job.status = InboxBackupStatus.BACKUP_FAILED.value
        job.error_message = str(error)
        job.completed_at = datetime.utcnow()
        setting.last_status = InboxBackupStatus.BACKUP_FAILED.value
        setting.last_error = str(error)
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
    if not latest or not latest.backup_file_id:
        raise ValueError("No Google Drive backup found to restore.")

    job = InboxBackupJob(
        public_id=_public_id("restore"),
        user_id=user.id,
        job_type="restore",
        provider=InboxBackupProvider.GOOGLE_DRIVE.value,
        status=InboxBackupStatus.RESTORE_RUNNING.value,
        backup_file_id=latest.backup_file_id,
        backup_file_name=latest.backup_file_name,
    )
    db.add(job)
    db.commit()
    db.refresh(job)

    try:
        if not _is_google_drive_configured():
            job.encrypted_payload_json = {
                "restored_from": latest.public_id,
                "downloaded_payload": latest.encrypted_payload_json,
                "mode": "dev_mock",
            }
            job.status = InboxBackupStatus.RESTORE_COMPLETED.value
            job.completed_at = datetime.utcnow()
            setting.last_restore_at = job.completed_at
            setting.last_status = InboxBackupStatus.RESTORE_COMPLETED.value
            setting.last_error = None
            setting.restore_count += 1
        else:
            access_token = _access_token_from_setting(setting)
            payload = google_drive_service.download_backup_file(access_token, latest.backup_file_id)
            job.encrypted_payload_json = {"restored_from": latest.public_id, "downloaded_payload": payload}
            job.status = InboxBackupStatus.RESTORE_COMPLETED.value
            job.completed_at = datetime.utcnow()
            setting.last_restore_at = job.completed_at
            setting.last_status = InboxBackupStatus.RESTORE_COMPLETED.value
            setting.last_error = None
            setting.restore_count += 1
    except Exception as error:
        job.status = InboxBackupStatus.RESTORE_FAILED.value
        job.error_message = str(error)
        job.completed_at = datetime.utcnow()
        setting.last_status = InboxBackupStatus.RESTORE_FAILED.value
        setting.last_error = str(error)
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
