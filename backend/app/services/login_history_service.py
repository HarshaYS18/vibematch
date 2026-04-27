from sqlalchemy.orm import Session

from app.models.login_history import (
    LoginHistory,
    LoginHistoryFailureReason,
    LoginHistoryStatus,
)


def create_login_history(
    db: Session,
    email: str,
    provider: str,
    provider_user_id: str,
    status: LoginHistoryStatus,
    is_success: bool,
    user_id: int | None = None,
    device_id: str | None = None,
    ip_address: str | None = None,
    failure_reason: LoginHistoryFailureReason | None = None,
    failure_detail: str | None = None,
) -> LoginHistory:
    login_history = LoginHistory(
        user_id=user_id,
        email=email,
        provider=provider,
        provider_user_id=provider_user_id,
        device_id=device_id,
        ip_address=ip_address,
        status=status,
        failure_reason=failure_reason,
        failure_detail=failure_detail,
        is_success=is_success,
    )

    db.add(login_history)
    db.commit()
    db.refresh(login_history)

    return login_history