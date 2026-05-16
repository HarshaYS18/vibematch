from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from google.auth.transport import requests as google_requests
from google.oauth2 import id_token as google_id_token
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import create_access_token
from app.database import get_db
from app.models.auth_identity import AuthIdentity
from app.models.login_history import LoginHistoryFailureReason, LoginHistoryStatus
from app.models.role import RoleName
from app.models.user import User
from app.schemas.auth import AuthResponse, DevLoginRequest, GoogleLoginRequest
from app.services.audit_log_service import AuditAction, create_login_security_log
from app.services.ban_service import is_device_banned
from app.services.identity_service import generate_public_user_id
from app.services.login_history_service import create_login_history
from app.services.role_badge_service import get_primary_role_badge, get_role_badges
from app.services.role_service import assign_role, get_primary_role, get_user_roles


router = APIRouter(prefix="/auth", tags=["Auth"])


def _auth_response_for_user(db: Session, user: User) -> AuthResponse:
    user_roles = get_user_roles(user)
    roles = [role.value for role in user_roles]
    primary_role = get_primary_role(user)
    token = create_access_token(subject=str(user.id))
    return AuthResponse(
        access_token=token,
        user_id=user.id,
        public_user_id=user.public_user_id,
        username=user.username,
        display_name=user.display_name,
        roles=roles,
        primary_role=primary_role.value,
        primary_role_badge=get_primary_role_badge(primary_role),
        role_badges=get_role_badges(user_roles),
    )


def _record_login_success(db: Session, user: User, email: str, provider: str, provider_user_id: str, device_id: str | None, client_ip: str | None) -> None:
    user.last_device_id = device_id
    user.last_login_at = datetime.utcnow()
    user.last_seen_at = datetime.utcnow()
    db.add(user)
    db.commit()
    db.refresh(user)
    user_roles = get_user_roles(user)
    roles = [role.value for role in user_roles]
    create_login_security_log(
        db=db,
        action=AuditAction.LOGIN_SUCCESS,
        email=email,
        device_id=device_id,
        target_user_id=user.id,
        reason="User logged in successfully.",
        ip_address=client_ip,
        extra_metadata={"provider": provider, "provider_user_id": provider_user_id, "public_user_id": user.public_user_id, "roles": roles},
    )
    create_login_history(
        db=db,
        user_id=user.id,
        email=email,
        provider=provider,
        provider_user_id=provider_user_id,
        status=LoginHistoryStatus.SUCCESS,
        is_success=True,
        device_id=device_id,
        ip_address=client_ip,
        failure_reason=None,
        failure_detail=None,
    )


def _fail_if_banned_or_inactive(db: Session, user: User, email: str, provider: str, provider_user_id: str, device_id: str | None, client_ip: str | None) -> None:
    if user.is_banned:
        create_login_security_log(
            db=db,
            action=AuditAction.LOGIN_FAILED_USER_BANNED,
            email=email,
            device_id=device_id,
            target_user_id=user.id,
            reason="Login blocked because user account is banned.",
            ip_address=client_ip,
            extra_metadata={"provider": provider, "provider_user_id": provider_user_id, "public_user_id": user.public_user_id},
        )
        create_login_history(
            db=db,
            user_id=user.id,
            email=email,
            provider=provider,
            provider_user_id=provider_user_id,
            status=LoginHistoryStatus.FAILED,
            is_success=False,
            device_id=device_id,
            ip_address=client_ip,
            failure_reason=LoginHistoryFailureReason.USER_BANNED,
            failure_detail="User account is banned.",
        )
        raise HTTPException(status_code=403, detail="User is banned")

    if not user.is_active:
        create_login_security_log(
            db=db,
            action=AuditAction.LOGIN_FAILED_USER_INACTIVE,
            email=email,
            device_id=device_id,
            target_user_id=user.id,
            reason="Login blocked because user account is inactive.",
            ip_address=client_ip,
            extra_metadata={"provider": provider, "provider_user_id": provider_user_id, "public_user_id": user.public_user_id},
        )
        create_login_history(
            db=db,
            user_id=user.id,
            email=email,
            provider=provider,
            provider_user_id=provider_user_id,
            status=LoginHistoryStatus.FAILED,
            is_success=False,
            device_id=device_id,
            ip_address=client_ip,
            failure_reason=LoginHistoryFailureReason.USER_INACTIVE,
            failure_detail="User account is inactive.",
        )
        raise HTTPException(status_code=403, detail="User is inactive")


def _fail_if_device_banned(db: Session, email: str, provider: str, provider_user_id: str, device_id: str | None, client_ip: str | None) -> None:
    if is_device_banned(db, device_id):
        create_login_security_log(
            db=db,
            action=AuditAction.LOGIN_FAILED_DEVICE_BANNED,
            email=email,
            device_id=device_id,
            reason="Login blocked because device_id has an active device ban.",
            ip_address=client_ip,
            extra_metadata={"provider": provider, "provider_user_id": provider_user_id},
        )
        create_login_history(
            db=db,
            email=email,
            provider=provider,
            provider_user_id=provider_user_id,
            status=LoginHistoryStatus.FAILED,
            is_success=False,
            device_id=device_id,
            ip_address=client_ip,
            failure_reason=LoginHistoryFailureReason.DEVICE_BANNED,
            failure_detail="This device has been permanently banned.",
        )
        raise HTTPException(status_code=403, detail="This device has been permanently banned.")


def _get_or_create_identity_user(db: Session, provider: str, provider_user_id: str, email: str, username: str | None, display_name: str | None, avatar_url: str | None = None) -> User:
    identity = (
        db.query(AuthIdentity)
        .filter(AuthIdentity.provider == provider, AuthIdentity.provider_user_id == provider_user_id)
        .first()
    )
    if identity:
        user = identity.user
        changed = False
        if avatar_url and user.avatar_url != avatar_url:
            user.avatar_url = avatar_url
            changed = True
        if display_name and not user.display_name:
            user.display_name = display_name
            changed = True
        if changed:
            db.add(user)
            db.commit()
            db.refresh(user)
        return user

    is_founder_email = email == "founder@vibematch.com"
    public_user_id = settings.FOUNDER_OWNER_PUBLIC_ID if is_founder_email else generate_public_user_id(db)
    user = User(
        public_user_id=public_user_id,
        username=username,
        display_name=display_name or "Vibe User",
        avatar_url=avatar_url,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    identity = AuthIdentity(user_id=user.id, provider=provider, provider_user_id=provider_user_id, email=email)
    db.add(identity)
    db.commit()

    assign_role(db=db, user=user, role=RoleName.FOUNDER_OWNER if is_founder_email else RoleName.USER, reason="Founder Owner seed account" if is_founder_email else "Default user role")
    db.refresh(user)
    return user


if settings.ENABLE_DEV_LOGIN:

    @router.post("/dev-login", response_model=AuthResponse)
    def dev_login(payload: DevLoginRequest, request: Request, db: Session = Depends(get_db)):
        provider = "dev_email"
        email = str(payload.email).lower().strip()
        provider_user_id = email
        client_ip = request.client.host if request.client else None
        device_id = payload.device_id.strip() if payload.device_id else None

        _fail_if_device_banned(db, email, provider, provider_user_id, device_id, client_ip)
        user = _get_or_create_identity_user(db, provider, provider_user_id, email, payload.username, payload.display_name)
        _fail_if_banned_or_inactive(db, user, email, provider, provider_user_id, device_id, client_ip)
        _record_login_success(db, user, email, provider, provider_user_id, device_id, client_ip)
        return _auth_response_for_user(db, user)


@router.post("/google-login", response_model=AuthResponse)
def google_login(payload: GoogleLoginRequest, request: Request, db: Session = Depends(get_db)):
    client_ids = [item.strip() for item in settings.GOOGLE_AUTH_CLIENT_IDS.split(",") if item.strip()]
    if not client_ids:
        raise HTTPException(status_code=500, detail="Google login is not configured. Set GOOGLE_AUTH_CLIENT_IDS in backend .env.")

    try:
        verified = google_id_token.verify_oauth2_token(payload.id_token, google_requests.Request())
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=f"Invalid Google token: {exc}") from exc

    audience = str(verified.get("aud") or "")
    if audience not in client_ids:
        raise HTTPException(status_code=401, detail="Google token audience is not allowed for this app.")

    email = str(verified.get("email") or "").lower().strip()
    email_verified = bool(verified.get("email_verified"))
    google_sub = str(verified.get("sub") or "").strip()
    if not email or not google_sub or not email_verified:
        raise HTTPException(status_code=401, detail="Google account email is not verified.")

    provider = "google"
    provider_user_id = google_sub
    client_ip = request.client.host if request.client else None
    device_id = payload.device_id.strip() if payload.device_id else None

    _fail_if_device_banned(db, email, provider, provider_user_id, device_id, client_ip)
    user = _get_or_create_identity_user(
        db=db,
        provider=provider,
        provider_user_id=provider_user_id,
        email=email,
        username=email.split("@")[0],
        display_name=str(verified.get("name") or verified.get("given_name") or "Vibe User"),
        avatar_url=str(verified.get("picture") or "") or None,
    )
    _fail_if_banned_or_inactive(db, user, email, provider, provider_user_id, device_id, client_ip)
    _record_login_success(db, user, email, provider, provider_user_id, device_id, client_ip)
    return _auth_response_for_user(db, user)
