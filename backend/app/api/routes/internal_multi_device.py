from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.core.config import settings
from app.core.security import create_access_token
from app.database import get_db
from app.models.auth_identity import AuthIdentity
from app.models.role import ROLE_POWER, RoleName, UserRole
from app.models.user import User
from app.schemas.admin import AdminUserResponse
from app.services.audit_log_service import create_admin_log
from app.services.identity_service import generate_public_user_id
from app.services.role_service import assign_role, get_primary_role, get_user_roles

router = APIRouter(prefix="/internal-test/multi-device", tags=["Internal Multi Device"])

TEST_ACCOUNTS = {
    "founder": {
        "email": "founder@vibematch.com",
        "username": "founder",
        "display_name": "Founder Owner",
        "device_id": "internal-founder-device",
    },
    "user_a": {
        "email": "internal.user.a@vibematch.test",
        "username": "internal_user_a",
        "display_name": "Internal User A",
        "device_id": "internal-user-a-device",
    },
    "user_b": {
        "email": "internal.user.b@vibematch.test",
        "username": "internal_user_b",
        "display_name": "Internal User B",
        "device_id": "internal-user-b-device",
    },
}

PROMOTABLE_TEST_ROLES = {
    RoleName.OWNER,
    RoleName.SUPERADMIN,
    RoleName.ADMIN,
    RoleName.MONITOR,
    RoleName.CS,
    RoleName.AGENCY_OWNER,
    RoleName.BD,
    RoleName.COIN_SELLER,
    RoleName.MERCHANT,
    RoleName.RESELLER,
}


class PromoteByPublicIdRequest(BaseModel):
    public_user_id: int
    role: RoleName
    reason: str = "Internal multi-device role test"


class RevokeRoleByPublicIdRequest(BaseModel):
    public_user_id: int
    role: RoleName
    reason: str = "Internal multi-device role revoke test"


class InternalLoginResponse(BaseModel):
    label: str
    email: str
    device_id: str
    user_id: int
    public_user_id: int
    access_token: str
    roles: list[str]
    primary_role: str


class RoleActionResponse(BaseModel):
    ok: bool
    message: str
    target_user: AdminUserResponse


def _require_founder(current_user: User) -> None:
    if get_primary_role(current_user) != RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Founder Owner access required")


def _admin_user_response(user: User) -> AdminUserResponse:
    return AdminUserResponse(
        id=user.id,
        public_user_id=user.public_user_id,
        display_custom_id=user.display_custom_id,
        display_name=user.display_name,
        username=user.username,
        is_active=user.is_active,
        is_banned=user.is_banned,
        roles=[role.value for role in get_user_roles(user)],
        primary_role=get_primary_role(user).value,
    )


def _get_or_create_test_user(db: Session, *, label: str) -> User:
    account = TEST_ACCOUNTS[label]
    email = account["email"].lower().strip()
    provider = "dev_email"

    identity = (
        db.query(AuthIdentity)
        .filter(AuthIdentity.provider == provider, AuthIdentity.provider_user_id == email)
        .first()
    )
    if identity:
        return identity.user

    is_founder = label == "founder"
    public_user_id = settings.FOUNDER_OWNER_PUBLIC_ID if is_founder else generate_public_user_id(db)
    user = User(
        public_user_id=public_user_id,
        username=account["username"],
        display_name=account["display_name"],
        is_protected=is_founder,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    identity = AuthIdentity(
        user_id=user.id,
        provider=provider,
        provider_user_id=email,
        email=email,
    )
    db.add(identity)
    db.commit()

    assign_role(
        db=db,
        user=user,
        role=RoleName.FOUNDER_OWNER if is_founder else RoleName.USER,
        reason="Internal multi-device seed account",
    )
    db.refresh(user)
    return user


def _login_response(db: Session, *, label: str) -> InternalLoginResponse:
    account = TEST_ACCOUNTS[label]
    user = _get_or_create_test_user(db, label=label)
    user.last_device_id = account["device_id"]
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token(subject=str(user.id))
    return InternalLoginResponse(
        label=label,
        email=account["email"],
        device_id=account["device_id"],
        user_id=user.id,
        public_user_id=user.public_user_id,
        access_token=token,
        roles=[role.value for role in get_user_roles(user)],
        primary_role=get_primary_role(user).value,
    )


@router.get("/accounts")
def get_internal_test_accounts(db: Session = Depends(get_db)):
    responses = [_login_response(db, label=label) for label in TEST_ACCOUNTS]
    return {
        "ok": True,
        "message": "Use each account on a different device/browser profile for internal testing.",
        "accounts": responses,
    }


@router.get("/login/{label}", response_model=InternalLoginResponse)
def login_internal_test_account(label: str, db: Session = Depends(get_db)):
    if label not in TEST_ACCOUNTS:
        raise HTTPException(status_code=404, detail="Unknown test account label. Use founder, user_a, or user_b.")
    return _login_response(db, label=label)


@router.post("/promote", response_model=RoleActionResponse)
def promote_test_user(
    payload: PromoteByPublicIdRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_founder(current_user)
    if payload.role == RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Founder Owner role cannot be assigned from internal test API")
    if payload.role not in PROMOTABLE_TEST_ROLES:
        raise HTTPException(status_code=400, detail="This role is not supported for internal testing promotion")

    target = db.query(User).filter(User.public_user_id == payload.public_user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Target user not found")
    if get_primary_role(target) == RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Founder Owner cannot be modified")
    if ROLE_POWER[get_primary_role(current_user)] <= ROLE_POWER[payload.role]:
        raise HTTPException(status_code=403, detail="Cannot assign equal or higher role")

    assigned = assign_role(
        db=db,
        user=target,
        role=payload.role,
        assigned_by_user_id=current_user.id,
        reason=payload.reason,
    )
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=target.id,
        action="INTERNAL_TEST_ROLE_PROMOTED",
        resource_type="user_role",
        resource_id=str(assigned.id),
        reason=payload.reason,
        metadata_json={"assigned_role": payload.role.value, "target_public_user_id": target.public_user_id},
    )
    db.refresh(target)
    return RoleActionResponse(ok=True, message=f"User promoted to {payload.role.value}", target_user=_admin_user_response(target))


@router.post("/revoke-role", response_model=RoleActionResponse)
def revoke_test_user_role(
    payload: RevokeRoleByPublicIdRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_founder(current_user)
    if payload.role == RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Founder Owner role cannot be revoked from internal test API")

    target = db.query(User).filter(User.public_user_id == payload.public_user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Target user not found")
    if get_primary_role(target) == RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Founder Owner cannot be modified")

    role_row = db.query(UserRole).filter(UserRole.user_id == target.id, UserRole.role == payload.role).first()
    if not role_row:
        raise HTTPException(status_code=404, detail="Target user does not have this role")

    db.delete(role_row)
    db.commit()

    if not get_user_roles(target):
        assign_role(db=db, user=target, role=RoleName.USER, assigned_by_user_id=current_user.id, reason="Default role after revoke")

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=target.id,
        action="INTERNAL_TEST_ROLE_REVOKED",
        resource_type="user_role",
        reason=payload.reason,
        metadata_json={"revoked_role": payload.role.value, "target_public_user_id": target.public_user_id},
    )
    db.refresh(target)
    return RoleActionResponse(ok=True, message=f"Role {payload.role.value} revoked", target_user=_admin_user_response(target))


@router.post("/reset-user-roles/{public_user_id}", response_model=RoleActionResponse)
def reset_test_user_roles(
    public_user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _require_founder(current_user)
    target = db.query(User).filter(User.public_user_id == public_user_id).first()
    if not target:
        raise HTTPException(status_code=404, detail="Target user not found")
    if get_primary_role(target) == RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Founder Owner cannot be modified")

    db.query(UserRole).filter(UserRole.user_id == target.id).delete()
    db.commit()
    assign_role(db=db, user=target, role=RoleName.USER, assigned_by_user_id=current_user.id, reason="Internal role reset")
    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=target.id,
        action="INTERNAL_TEST_ROLES_RESET",
        resource_type="user_role",
        reason="Internal multi-device test reset",
        metadata_json={"target_public_user_id": target.public_user_id},
    )
    db.refresh(target)
    return RoleActionResponse(ok=True, message="User roles reset to user", target_user=_admin_user_response(target))
