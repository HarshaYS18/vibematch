from datetime import datetime
import hmac
from typing import Any
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session
from app.api.routes import users
from app.core.config import settings
from app.database import get_db
from app.models.profile_visit import ProfileVisit
from app.models.profile_display import ProfileDisplayAudit
from app.services import event_outbox_service, profile_display_service
from app.models.user import User
from app.schemas.user import UserProfileUpdateRequest

router=APIRouter(prefix="/internal/profile-social",tags=["Profile Social Internal"])
class ProfilePatchRequest(BaseModel): profile: dict[str,Any]=Field(default_factory=dict)
class ProfileVisitRequest(BaseModel):
    profile_owner_user_id:int
    visitor_user_id:int
    source:str="public_profile"

class CustomIdRequest(BaseModel):
    display_custom_id: int | None = None

class StealthRequest(BaseModel):
    enabled: bool
    actor_user_id: int
    reason: str = Field(min_length=3, max_length=255)

class StealthGrantStateRequest(BaseModel):
    enabled: bool
    actor_user_id: int
    reason: str = Field(min_length=3, max_length=255)

def require_internal_token(x_funkey_internal_token: str | None=Header(default=None))->None:
    if not settings.PROFILE_SOCIAL_INTERNAL_TOKEN.strip() or not hmac.compare_digest((x_funkey_internal_token or "").strip(),settings.PROFILE_SOCIAL_INTERNAL_TOKEN.strip()):
        raise HTTPException(status_code=403,detail="Internal Profile/Social access denied")

@router.patch("/users/{user_id}/profile",dependencies=[Depends(require_internal_token)])
def update_profile(user_id:int,payload:ProfilePatchRequest,db:Session=Depends(get_db)):
    current_user=db.query(User).filter(User.id==user_id).first()
    if current_user is None: raise HTTPException(status_code=404,detail="User not found")
    request=UserProfileUpdateRequest(**payload.profile)
    fields=request.model_fields_set
    if "display_name" in fields and request.display_name is not None:
        value=request.display_name.strip()
        if len(value)<2: raise HTTPException(status_code=400,detail="Display name must be at least 2 characters")
        current_user.display_name=value
    if "bio" in fields: current_user.bio=users._clean_optional(request.bio)
    if "avatar_url" in fields: current_user.avatar_url=users._validate_profile_media_url(db,user=current_user,url=request.avatar_url,media_type=users.CdnMediaType.PROFILE_PICTURE,label="avatar")
    if "cover_photo_urls" in fields: current_user.cover_photo_urls=users._validate_cover_photo_urls(db,user=current_user,urls=request.cover_photo_urls or [])
    if "date_of_birth" in fields: current_user.date_of_birth=request.date_of_birth
    if "gender" in fields: current_user.gender=users._clean_enum(request.gender,users._ALLOWED_GENDERS,"gender")
    if "profession" in fields: current_user.profession=users._clean_optional(request.profession)
    if "marital_status" in fields: current_user.marital_status=users._clean_enum(request.marital_status,users._ALLOWED_MARITAL,"marital status")
    if "friend_gender_preference" in fields: current_user.friend_gender_preference=users._clean_enum(request.friend_gender_preference,users._ALLOWED_GENDER_PREFS,"friend gender preference")
    if "friend_marital_preference" in fields: current_user.friend_marital_preference=users._clean_enum(request.friend_marital_preference,users._ALLOWED_MARITAL_PREFS,"friend marital preference")
    if "interests" in fields: current_user.interests=users._clean_interests(request.interests or [])
    db.add(current_user)
    db.commit()
    return {"updated": True, "user_id": current_user.id}

@router.post("/profile-visits",dependencies=[Depends(require_internal_token)])
def record_profile_visit(payload:ProfileVisitRequest,db:Session=Depends(get_db)):
    if payload.profile_owner_user_id==payload.visitor_user_id: return {"recorded":False}
    visit=db.query(ProfileVisit).filter(ProfileVisit.profile_owner_user_id==payload.profile_owner_user_id,ProfileVisit.visitor_user_id==payload.visitor_user_id).first()
    now=datetime.utcnow()
    if visit is None:
        visit=ProfileVisit(profile_owner_user_id=payload.profile_owner_user_id,visitor_user_id=payload.visitor_user_id,source=payload.source,visit_count=1,first_visited_at=now,last_visited_at=now); db.add(visit)
    else:
        visit.visit_count+=1; visit.source=payload.source; visit.last_visited_at=now
    db.commit()
    return {"recorded":True}


@router.post("/admin/users/{user_id}/custom-id", dependencies=[Depends(require_internal_token)])
def assign_custom_id(user_id: int, payload: CustomIdRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if payload.display_custom_id is not None:
        existing = db.query(User).filter(
            User.display_custom_id == payload.display_custom_id,
            User.id != user_id,
        ).first()
        if existing is not None:
            raise HTTPException(status_code=409, detail="Custom ID is already assigned")
    previous = user.display_custom_id
    user.display_custom_id = payload.display_custom_id
    audit = ProfileDisplayAudit(
        actor_user_id=None,
        target_user_id=user_id,
        action="CUSTOM_ID_UPDATED",
        previous_value=str(previous) if previous is not None else None,
        new_value=str(payload.display_custom_id) if payload.display_custom_id is not None else None,
        reason="super_owner_command",
    )
    db.add(user)
    db.add(audit)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise HTTPException(status_code=409, detail="Custom ID is already assigned") from exc
    return {"user_id": user_id, "display_custom_id": payload.display_custom_id}


@router.get("/users/{user_id}/stealth", dependencies=[Depends(require_internal_token)])
def get_stealth(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    state = profile_display_service.get_or_create_stealth_state(db, user_id)
    db.commit()
    db.refresh(state)
    return {
        "state_id": state.id,
        "user_id": user_id,
        "enabled": bool(state.is_enabled),
        "updated_at": state.updated_at,
    }


@router.post("/admin/users/{user_id}/stealth", dependencies=[Depends(require_internal_token)])
def set_stealth(user_id: int, payload: StealthRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    state = profile_display_service.get_or_create_stealth_state(db, user_id)
    previous = bool(state.is_enabled)
    state.is_enabled = bool(payload.enabled)
    state.granted_by_user_id = payload.actor_user_id
    state.toggle_reason = payload.reason
    db.add(state)
    db.add(ProfileDisplayAudit(
        actor_user_id=payload.actor_user_id,
        target_user_id=user_id,
        action="STEALTH_UPDATED",
        previous_value=str(previous).lower(),
        new_value=str(bool(payload.enabled)).lower(),
        reason=payload.reason,
    ))
    event_outbox_service.enqueue_event(
        db,
        event_type="profile_social.stealth.toggled.v1",
        actor_user_id=payload.actor_user_id,
        payload={"user_id":user_id,"enabled":bool(payload.enabled)},
    )
    db.commit()
    db.refresh(state)
    return {
        "state_id": state.id,
        "user_id": user_id,
        "enabled": bool(state.is_enabled),
        "updated_at": state.updated_at,
    }


@router.post("/admin/users/{user_id}/stealth-grant-state", dependencies=[Depends(require_internal_token)])
def set_stealth_grant_state(user_id: int, payload: StealthGrantStateRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    state = profile_display_service.get_or_create_stealth_state(db, user_id)
    state.granted_by_user_id = payload.actor_user_id
    state.grant_reason = payload.reason
    if not payload.enabled:
        state.is_enabled = False
        state.toggle_reason = payload.reason
    db.add(state)
    db.add(ProfileDisplayAudit(
        actor_user_id=payload.actor_user_id,
        target_user_id=user_id,
        action="STEALTH_GRANT_UPDATED",
        previous_value=None,
        new_value=str(bool(payload.enabled)).lower(),
        reason=payload.reason,
    ))
    event_outbox_service.enqueue_event(
        db,
        event_type="profile_social.stealth_eligibility.changed.v1",
        actor_user_id=payload.actor_user_id,
        payload={"user_id":user_id,"enabled":bool(payload.enabled)},
    )
    db.commit()
    db.refresh(state)
    return {
        "state_id": state.id,
        "user_id": user_id,
        "enabled": bool(state.is_enabled),
        "updated_at": state.updated_at,
    }
