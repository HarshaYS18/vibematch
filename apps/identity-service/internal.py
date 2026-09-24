import hmac
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from app.core.config import settings
from app.core.security import decode_access_token
from app.database import get_db
from app.models.special_permission import SpecialPermission, SpecialPermissionName
from app.models.user import User
from app.services import event_outbox_service, identity_session_service, special_permission_service
from app.services.role_service import get_user_roles

router=APIRouter(prefix="/internal/identity",tags=["Identity Internal"])
class VerifyTokenRequest(BaseModel): token: str
class RevokeSessionsRequest(BaseModel):
    user_id: int
    reason: str
    device_id: str | None = None

class SetSpecialPermissionRequest(BaseModel):
    target_user_id: int
    actor_user_id: int
    permission: SpecialPermissionName
    enabled: bool
    reason: str

def require_internal_token(x_funkey_internal_token: str | None = Header(default=None)) -> None:
    if not settings.IDENTITY_INTERNAL_TOKEN.strip() or not hmac.compare_digest((x_funkey_internal_token or "").strip(), settings.IDENTITY_INTERNAL_TOKEN.strip()):
        raise HTTPException(status_code=403,detail="Internal Identity access denied")

@router.post("/verify",dependencies=[Depends(require_internal_token)])
def verify_access_token(payload: VerifyTokenRequest,db: Session=Depends(get_db)):
    claims=decode_access_token(payload.token)
    if not claims: raise HTTPException(status_code=401,detail="Invalid or expired token")
    subject=str(claims.get("sub") or "").strip()
    if not subject.isdigit(): raise HTTPException(status_code=401,detail="Invalid token subject")
    user=db.query(User).filter(User.id==int(subject)).first()
    if user is None: raise HTTPException(status_code=401,detail="User not found")
    if user.is_banned: raise HTTPException(status_code=403,detail="User is banned")
    if not user.is_active: raise HTTPException(status_code=403,detail="User is inactive")
    token_device=str(claims.get("device_id") or "").strip()
    active_device=(user.last_device_id or "").strip()
    if active_device and token_device!=active_device: raise HTTPException(status_code=401,detail="Session replaced by a newer login")
    session_id=str(claims.get("sid") or "").strip()
    if session_id and not identity_session_service.is_session_active(db,user_id=user.id,session_id=session_id,device_id=token_device or None):
        raise HTTPException(status_code=401,detail="Session is no longer active")
    return {"user_id":user.id,"public_user_id":user.public_user_id,"is_active":bool(user.is_active),"is_banned":bool(user.is_banned),"is_protected":bool(user.is_protected),"device_id":token_device or None,"session_id":session_id or None,"roles":[role.value for role in get_user_roles(user)]}

@router.post("/sessions/revoke",dependencies=[Depends(require_internal_token)])
def revoke_sessions(payload: RevokeSessionsRequest,db: Session=Depends(get_db)):
    return {"revoked":identity_session_service.revoke_user_sessions(db,user_id=payload.user_id,reason=payload.reason,device_id=payload.device_id)}


@router.post("/special-permissions/set",dependencies=[Depends(require_internal_token)])
def set_special_permission(payload:SetSpecialPermissionRequest,db:Session=Depends(get_db)):
    actor=db.query(User).filter(User.id==payload.actor_user_id).first()
    target=db.query(User).filter(User.id==payload.target_user_id).first()
    if actor is None: raise HTTPException(status_code=404,detail="Actor user not found")
    if target is None: raise HTTPException(status_code=404,detail="Target user not found")
    if payload.enabled:
        special_permission_service.grant_special_permission(
            db=db,
            target_user=target,
            permission=payload.permission,
            granted_by=actor,
            reason=payload.reason,
        )
    else:
        rows=(db.query(SpecialPermission).filter(
            SpecialPermission.user_id==target.id,
            SpecialPermission.permission==payload.permission,
            SpecialPermission.is_active.is_(True),
        ).all())
        for row in rows:
            special_permission_service.revoke_special_permission(
                db=db,
                special_permission=row,
                revoked_by=actor,
                reason=payload.reason,
            )
    event_outbox_service.enqueue_event(
        db,
        event_type="identity.special_permission.changed.v1",
        actor_user_id=actor.id,
        payload={
            "target_user_id":target.id,
            "permission":payload.permission.value,
            "enabled":bool(payload.enabled),
            "reason":payload.reason,
        },
    )
    db.commit()
    return {
        "target_user_id":target.id,
        "permission":payload.permission.value,
        "enabled":bool(payload.enabled),
    }
