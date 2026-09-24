from datetime import datetime
import hmac
from typing import Any
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from app.api.routes import users
from app.core.config import settings
from app.database import get_db
from app.models.profile_visit import ProfileVisit
from app.models.user import User
from app.schemas.user import UserProfileUpdateRequest

router=APIRouter(prefix="/internal/profile-social",tags=["Profile Social Internal"])
class ProfilePatchRequest(BaseModel): profile: dict[str,Any]=Field(default_factory=dict)
class ProfileVisitRequest(BaseModel):
    profile_owner_user_id:int
    visitor_user_id:int
    source:str="public_profile"

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
    db.add(current_user); db.commit(); db.refresh(current_user)
    return users._user_me_response(db,current_user)

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
