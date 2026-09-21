from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.special_permission import SpecialPermission, SpecialPermissionName
from app.models.user import User
from app.schemas.control_center import EconomyRuleSetUpdateRequest, ManifestImportRequest, StoreCategoryUpsertRequest, StoreItemUpsertRequest
from app.schemas.profile_display import StealthGrantRequest, StealthStateResponse, StealthToggleRequest
from app.services import economy_rules_service, profile_display_service, store_control_center_service
from app.services.audit_log_service import create_admin_log
from app.services.permissions import room_permission_service
from app.services.role_service import get_primary_role
from app.services.special_permission_service import grant_special_permission
from app.models.role import RoleName

router = APIRouter(prefix="/control-center", tags=["Control Center"])


def _owner_control(actor: User) -> None:
    if get_primary_role(actor) not in {RoleName.FOUNDER_OWNER, RoleName.OWNER, RoleName.SUPERADMIN}:
        raise HTTPException(status_code=403, detail="Control Center owner access required")



@router.get("/economy/rules")
def list_economy_rules(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _owner_control(current_user)
    return economy_rules_service.list_rule_sets(db)


@router.post("/economy/rules/{track_key}")
def update_economy_rule_set(
    track_key: str,
    payload: EconomyRuleSetUpdateRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return economy_rules_service.replace_rule_set(
        db,
        actor=current_user,
        track_key=track_key,
        title=payload.title,
        levels=[item.model_dump() for item in payload.levels],
        reason=payload.reason,
    )


@router.get("/store/categories")
def list_store_categories(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    _owner_control(current_user)
    return store_control_center_service.list_categories(db)


@router.post("/store/categories")
def upsert_store_category(
    payload: StoreCategoryUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return store_control_center_service.upsert_category(db, actor=current_user, data=payload.model_dump())


@router.get("/store/items")
def list_store_items(
    category: str | None = Query(default=None),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    _owner_control(current_user)
    return store_control_center_service.list_items(db, category=category)


@router.post("/store/items")
def upsert_store_item(
    payload: StoreItemUpsertRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return store_control_center_service.upsert_item(db, actor=current_user, data=payload.model_dump())


@router.post("/store/manifest/preview")
def preview_store_manifest(payload: ManifestImportRequest, current_user: User = Depends(get_current_user)):
    _owner_control(current_user)
    return store_control_center_service.preview_manifest(payload.manifest)


@router.post("/store/manifest/import")
def import_store_manifest(
    payload: ManifestImportRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return store_control_center_service.import_manifest(db, actor=current_user, payload=payload.manifest, reason=payload.reason)


@router.get("/stealth/me", response_model=StealthStateResponse)
def get_my_stealth_state(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    state = profile_display_service.get_or_create_stealth_state(db, current_user.id)
    can_use = room_permission_service.can_use_hidden_presence(db, current_user)
    db.commit()
    return StealthStateResponse(user_id=current_user.id, is_enabled=bool(state.is_enabled), can_use_stealth=can_use, updated_at=state.updated_at)


@router.post("/stealth/me", response_model=StealthStateResponse)
def toggle_my_stealth(
    payload: StealthToggleRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if not room_permission_service.can_use_hidden_presence(db, current_user):
        raise HTTPException(status_code=403, detail="Stealth mode is not enabled for this account")
    state = profile_display_service.get_or_create_stealth_state(db, current_user.id)
    state.is_enabled = payload.enabled
    state.toggle_reason = payload.reason
    db.commit()
    create_admin_log(db=db, action="STEALTH_TOGGLED", actor_user_id=current_user.id, target_user_id=current_user.id, resource_type="stealth_state", resource_id=str(state.id), reason=payload.reason, metadata_json={"enabled": payload.enabled})
    return StealthStateResponse(user_id=current_user.id, is_enabled=bool(state.is_enabled), can_use_stealth=True, updated_at=state.updated_at)


@router.post("/stealth/grants", response_model=StealthStateResponse)
def grant_stealth(
    payload: StealthGrantRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if get_primary_role(current_user) != RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Only Founder Owner can grant stealth eligibility")
    target = db.query(User).filter(User.id == payload.target_user_id).first()
    if target is None:
        raise HTTPException(status_code=404, detail="Target user not found")
    if get_primary_role(target) == RoleName.FOUNDER_OWNER and get_primary_role(current_user) != RoleName.FOUNDER_OWNER:
        raise HTTPException(status_code=403, detail="Founder Owner cannot be modified")
    if payload.enabled:
        grant_special_permission(
            db=db,
            target_user=target,
            permission=SpecialPermissionName.USE_STEALTH,
            granted_by=current_user,
            reason=payload.reason,
        )
    else:
        rows = db.query(SpecialPermission).filter(
            SpecialPermission.user_id == target.id,
            SpecialPermission.permission == SpecialPermissionName.USE_STEALTH,
            SpecialPermission.is_active.is_(True),
        ).all()
        for row in rows:
            row.is_active = False
            row.revoked_by_user_id = current_user.id
            row.revoked_reason = payload.reason
    state = profile_display_service.get_or_create_stealth_state(db, target.id)
    state.granted_by_user_id = current_user.id
    state.grant_reason = payload.reason
    if not payload.enabled:
        state.is_enabled = False
    db.commit()
    create_admin_log(db=db, action="STEALTH_GRANT_UPDATED", actor_user_id=current_user.id, target_user_id=target.id, resource_type="stealth_state", resource_id=str(state.id), reason=payload.reason, metadata_json={"enabled": payload.enabled})
    return StealthStateResponse(user_id=target.id, is_enabled=bool(state.is_enabled), can_use_stealth=room_permission_service.can_use_hidden_presence(db, target), updated_at=state.updated_at)
