from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.admin_log import AdminLog
from app.models.login_history import LoginHistory
from app.models.role import RoleName
from app.models.room_realtime_audit_log import RoomRealtimeAuditLog
from app.models.special_permission import SpecialPermission
from app.models.user import User
from app.schemas.admin import (
    AdminUserResponse,
    AssignRoleRequest,
    AssignRoleResponse,
)
from app.schemas.audit_log import (
    AdminLogResponse,
    LoginHistoryResponse,
    RoomRealtimeAuditLogResponse,
)
from app.schemas.special_permission import (
    GrantSpecialPermissionRequest,
    RevokeSpecialPermissionRequest,
    SpecialPermissionActionResponse,
    SpecialPermissionResponse,
)
from app.services.audit_log_service import create_admin_log
from app.services.role_service import (
    assign_role,
    can_act_on,
    get_primary_role,
    get_role_power,
    get_user_roles,
)
from app.services.room_realtime_state_service import room_realtime_state_service
from app.services.special_permission_service import (
    grant_special_permission,
    revoke_special_permission,
)


router = APIRouter(prefix="/admin", tags=["Admin"])


ADMIN_CONTROL_ROLES = {
    RoleName.FOUNDER_OWNER,
    RoleName.OWNER,
    RoleName.SUPERADMIN,
    RoleName.ADMIN,
    RoleName.MONITOR,
    RoleName.CS,
}


PROTECTED_SPECIAL_PERMISSION_TARGET_ROLES = {
    RoleName.FOUNDER_OWNER,
    RoleName.OWNER,
}


def require_admin_control_access(current_user: User) -> None:
    primary_role = get_primary_role(current_user)

    if primary_role not in ADMIN_CONTROL_ROLES:
        raise HTTPException(
            status_code=403,
            detail="Official control center access required",
        )


def require_founder_owner(current_user: User) -> None:
    primary_role = get_primary_role(current_user)

    if primary_role != RoleName.FOUNDER_OWNER:
        raise HTTPException(
            status_code=403,
            detail="Founder Owner access required",
        )


def build_admin_user_response(user: User) -> AdminUserResponse:
    roles = [role.value for role in get_user_roles(user)]
    primary_role = get_primary_role(user).value

    return AdminUserResponse(
        id=user.id,
        public_user_id=user.public_user_id,
        display_custom_id=user.display_custom_id,
        display_name=user.display_name,
        username=user.username,
        is_active=user.is_active,
        is_banned=user.is_banned,
        roles=roles,
        primary_role=primary_role,
    )


@router.get("/users", response_model=list[AdminUserResponse])
def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_admin_control_access(current_user)

    users = db.query(User).order_by(User.id.asc()).limit(100).all()

    return [build_admin_user_response(user) for user in users]


@router.get("/audit-logs", response_model=list[AdminLogResponse])
def list_audit_logs(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    logs = db.query(AdminLog).order_by(AdminLog.id.desc()).limit(100).all()

    return logs


@router.get("/room-state/{room_id}")
def get_room_realtime_state(
    room_id: str,
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    return room_realtime_state_service.snapshot(room_id)


@router.get(
    "/room-realtime-audit-logs",
    response_model=list[RoomRealtimeAuditLogResponse],
)
def list_room_realtime_audit_logs(
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    logs = (
        db.query(RoomRealtimeAuditLog)
        .order_by(RoomRealtimeAuditLog.id.desc())
        .limit(limit)
        .all()
    )

    return logs


@router.get(
    "/room-realtime-audit-logs/room/{room_id}",
    response_model=list[RoomRealtimeAuditLogResponse],
)
def list_room_realtime_audit_logs_for_room(
    room_id: str,
    event_type: str | None = None,
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    query = db.query(RoomRealtimeAuditLog).filter(
        RoomRealtimeAuditLog.room_id == room_id,
    )

    if event_type:
        query = query.filter(RoomRealtimeAuditLog.event_type == event_type)

    logs = query.order_by(RoomRealtimeAuditLog.id.desc()).limit(limit).all()

    return logs


@router.get(
    "/room-realtime-audit-logs/actor/{actor_user_id}",
    response_model=list[RoomRealtimeAuditLogResponse],
)
def list_room_realtime_audit_logs_for_actor(
    actor_user_id: str,
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    logs = (
        db.query(RoomRealtimeAuditLog)
        .filter(RoomRealtimeAuditLog.actor_user_id == actor_user_id)
        .order_by(RoomRealtimeAuditLog.id.desc())
        .limit(limit)
        .all()
    )

    return logs


@router.get("/login-history", response_model=list[LoginHistoryResponse])
def list_login_history(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    history = (
        db.query(LoginHistory)
        .order_by(LoginHistory.id.desc())
        .limit(100)
        .all()
    )

    return history


@router.get(
    "/login-history/user/{user_id}",
    response_model=list[LoginHistoryResponse],
)
def list_login_history_for_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    history = (
        db.query(LoginHistory)
        .filter(LoginHistory.user_id == user_id)
        .order_by(LoginHistory.id.desc())
        .limit(100)
        .all()
    )

    return history


@router.get(
    "/login-history/device/{device_id}",
    response_model=list[LoginHistoryResponse],
)
def list_login_history_for_device(
    device_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    history = (
        db.query(LoginHistory)
        .filter(LoginHistory.device_id == device_id)
        .order_by(LoginHistory.id.desc())
        .limit(100)
        .all()
    )

    return history


@router.get(
    "/special-permissions",
    response_model=list[SpecialPermissionResponse],
)
def list_special_permissions(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    permissions = (
        db.query(SpecialPermission)
        .order_by(SpecialPermission.id.desc())
        .limit(100)
        .all()
    )

    return permissions


@router.post(
    "/special-permissions/grant",
    response_model=SpecialPermissionActionResponse,
)
def grant_user_special_permission(
    payload: GrantSpecialPermissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    target_user = db.query(User).filter(User.id == payload.target_user_id).first()

    if not target_user:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=payload.target_user_id,
            action="SPECIAL_PERMISSION_GRANT_FAILED",
            resource_type="special_permission",
            reason=payload.reason,
            metadata_json={
                "permission": payload.permission.value,
                "failure_reason": "Target user not found",
            },
        )

        raise HTTPException(status_code=404, detail="Target user not found")

    target_role = get_primary_role(target_user)

    if target_role in PROTECTED_SPECIAL_PERMISSION_TARGET_ROLES:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=target_user.id,
            action="SPECIAL_PERMISSION_GRANT_BLOCKED",
            resource_type="special_permission",
            reason=payload.reason,
            metadata_json={
                "permission": payload.permission.value,
                "target_role": target_role.value,
                "block_reason": "Cannot grant special permission to protected owner-level account",
            },
        )

        raise HTTPException(
            status_code=403,
            detail="Cannot grant special permission to Founder Owner or Owner accounts",
        )

    special_permission = grant_special_permission(
        db=db,
        user_id=target_user.id,
        permission=payload.permission,
        granted_by_user_id=current_user.id,
        reason=payload.reason,
        expires_at=payload.expires_at,
    )

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=target_user.id,
        action="SPECIAL_PERMISSION_GRANTED",
        resource_type="special_permission",
        resource_id=str(special_permission.id),
        reason=payload.reason,
        metadata_json={
            "permission": special_permission.permission.value,
            "target_role": target_role.value,
            "expires_at": payload.expires_at.isoformat() if payload.expires_at else None,
        },
    )

    return SpecialPermissionActionResponse(
        message="Special permission granted successfully",
        special_permission_id=special_permission.id,
        user_id=special_permission.user_id,
        permission=special_permission.permission.value,
        is_active=special_permission.is_active,
    )


@router.post(
    "/special-permissions/revoke",
    response_model=SpecialPermissionActionResponse,
)
def revoke_user_special_permission(
    payload: RevokeSpecialPermissionRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_founder_owner(current_user)

    special_permission = (
        db.query(SpecialPermission)
        .filter(SpecialPermission.id == payload.special_permission_id)
        .first()
    )

    if not special_permission:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            action="SPECIAL_PERMISSION_REVOKE_FAILED",
            resource_type="special_permission",
            resource_id=str(payload.special_permission_id),
            reason=payload.reason,
            metadata_json={"failure_reason": "Special permission not found"},
        )
        raise HTTPException(status_code=404, detail="Special permission not found")

    if not special_permission.is_active:
        raise HTTPException(status_code=400, detail="Special permission is already inactive")

    revoked_permission = revoke_special_permission(
        db=db,
        special_permission=special_permission,
        revoked_by_user_id=current_user.id,
        reason=payload.reason,
    )

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=revoked_permission.user_id,
        action="SPECIAL_PERMISSION_REVOKED",
        resource_type="special_permission",
        resource_id=str(revoked_permission.id),
        reason=payload.reason,
        metadata_json={"permission": revoked_permission.permission.value},
    )

    return SpecialPermissionActionResponse(
        message="Special permission revoked successfully",
        special_permission_id=revoked_permission.id,
        user_id=revoked_permission.user_id,
        permission=revoked_permission.permission.value,
        is_active=revoked_permission.is_active,
    )


@router.post("/roles/assign", response_model=AssignRoleResponse)
def assign_user_role(
    payload: AssignRoleRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    require_admin_control_access(current_user)

    actor_role = get_primary_role(current_user)

    if actor_role != RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Only Founder Owner can assign official roles in this foundation step")

    if payload.role == RoleName.FOUNDER_OWNER:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=payload.target_user_id,
            action="ROLE_ASSIGN_BLOCKED",
            resource_type="user_role",
            reason=payload.reason,
            metadata_json={
                "attempted_role": payload.role.value,
                "block_reason": "Founder Owner role cannot be assigned from API",
            },
        )
        raise HTTPException(status_code=403, detail="Founder Owner role cannot be assigned from API")

    target_user = db.query(User).filter(User.id == payload.target_user_id).first()

    if not target_user:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=payload.target_user_id,
            action="ROLE_ASSIGN_FAILED",
            resource_type="user_role",
            reason=payload.reason,
            metadata_json={
                "attempted_role": payload.role.value,
                "failure_reason": "Target user not found",
            },
        )
        raise HTTPException(status_code=404, detail="Target user not found")

    target_role = get_primary_role(target_user)

    if target_role == RoleName.FOUNDER_OWNER:
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=target_user.id,
            action="ROLE_ASSIGN_BLOCKED",
            resource_type="user_role",
            reason=payload.reason,
            metadata_json={
                "target_current_role": target_role.value,
                "attempted_role": payload.role.value,
                "block_reason": "Founder Owner cannot be modified",
            },
        )
        raise HTTPException(status_code=403, detail="Founder Owner cannot be modified")

    if get_role_power(actor_role) <= get_role_power(payload.role):
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=target_user.id,
            action="ROLE_ASSIGN_BLOCKED",
            resource_type="user_role",
            reason=payload.reason,
            metadata_json={
                "actor_role": actor_role.value,
                "target_current_role": target_role.value,
                "attempted_role": payload.role.value,
                "block_reason": "Cannot assign equal or higher role",
            },
        )
        raise HTTPException(status_code=403, detail="Cannot assign a role equal to or higher than your own role")

    if not can_act_on(current_user, target_user):
        create_admin_log(
            db=db,
            actor_user_id=current_user.id,
            target_user_id=target_user.id,
            action="ROLE_ASSIGN_BLOCKED",
            resource_type="user_role",
            reason=payload.reason,
            metadata_json={
                "actor_role": actor_role.value,
                "target_current_role": target_role.value,
                "attempted_role": payload.role.value,
                "block_reason": "Actor can only act on lower role users",
            },
        )
        raise HTTPException(status_code=403, detail="You can only act on lower role users")

    assigned_role = assign_role(
        db=db,
        user=target_user,
        role=payload.role,
        assigned_by_user_id=current_user.id,
        reason=payload.reason,
    )

    create_admin_log(
        db=db,
        actor_user_id=current_user.id,
        target_user_id=target_user.id,
        action="ROLE_ASSIGNED",
        resource_type="user_role",
        resource_id=str(assigned_role.id),
        reason=payload.reason,
        metadata_json={
            "assigned_role": assigned_role.role.value,
            "actor_role": actor_role.value,
            "target_primary_role_before": target_role.value,
        },
    )

    return AssignRoleResponse(
        message="Role assigned successfully",
        target_user_id=target_user.id,
        assigned_role=assigned_role.role.value,
        assigned_by_user_id=current_user.id,
    )
