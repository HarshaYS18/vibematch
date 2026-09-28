from sqlalchemy.orm import Session

from app.models.admin_log import AdminLog


class AuditAction:
    # Auth / login security events
    LOGIN_SUCCESS = "LOGIN_SUCCESS"
    LOGIN_FAILED_DEVICE_BANNED = "LOGIN_FAILED_DEVICE_BANNED"
    LOGIN_FAILED_USER_BANNED = "LOGIN_FAILED_USER_BANNED"
    LOGIN_FAILED_USER_INACTIVE = "LOGIN_FAILED_USER_INACTIVE"

    # Role / permission events
    ROLE_ASSIGNED = "ROLE_ASSIGNED"
    ROLE_REMOVED = "ROLE_REMOVED"
    SPECIAL_PERMISSION_GRANTED = "SPECIAL_PERMISSION_GRANTED"
    SPECIAL_PERMISSION_REVOKED = "SPECIAL_PERMISSION_REVOKED"

    # Ban / moderation events
    USER_BANNED = "USER_BANNED"
    USER_UNBANNED = "USER_UNBANNED"
    DEVICE_BANNED = "DEVICE_BANNED"
    DEVICE_UNBANNED = "DEVICE_UNBANNED"


class AuditResourceType:
    AUTH = "auth"
    USER = "user"
    DEVICE = "device"
    ROLE = "role"
    SPECIAL_PERMISSION = "special_permission"
    BAN = "ban"


def create_admin_log(
    db: Session,
    action: str,
    actor_user_id: int | None = None,
    target_user_id: int | None = None,
    resource_type: str | None = None,
    resource_id: str | None = None,
    reason: str | None = None,
    metadata_json: dict | None = None,
    ip_address: str | None = None,
    device_id: str | None = None,
    commit: bool = True,
) -> AdminLog:
    log = AdminLog(
        actor_user_id=actor_user_id,
        target_user_id=target_user_id,
        action=action,
        resource_type=resource_type,
        resource_id=resource_id,
        reason=reason,
        metadata_json=metadata_json,
        ip_address=ip_address,
        device_id=device_id,
    )

    db.add(log)
    if commit:
        db.commit()
        db.refresh(log)
    else:
        db.flush()

    return log


def create_login_security_log(
    db: Session,
    action: str,
    email: str,
    device_id: str | None = None,
    target_user_id: int | None = None,
    reason: str | None = None,
    ip_address: str | None = None,
    extra_metadata: dict | None = None,
) -> AdminLog:
    """
    Step 2L login/security audit log helper.

    Used for:
    - LOGIN_SUCCESS
    - LOGIN_FAILED_DEVICE_BANNED
    - LOGIN_FAILED_USER_BANNED
    - LOGIN_FAILED_USER_INACTIVE
    """

    metadata = {
        "email": email,
    }

    if extra_metadata:
        metadata.update(extra_metadata)

    return create_admin_log(
        db=db,
        action=action,
        actor_user_id=None,
        target_user_id=target_user_id,
        resource_type=AuditResourceType.AUTH,
        resource_id=email,
        reason=reason,
        metadata_json=metadata,
        ip_address=ip_address,
        device_id=device_id,
    )