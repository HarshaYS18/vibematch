from __future__ import annotations
import hmac
from typing import Any
from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from app.core.config import settings
from app.database import get_db
from app.services import notification_delivery_service

router=APIRouter(prefix="/internal/notifications",tags=["Notification Internal"])
def require_internal_token(x_funkey_internal_token:str|None=Header(default=None))->None:
    expected=settings.NOTIFICATION_INTERNAL_TOKEN.strip(); provided=(x_funkey_internal_token or "").strip()
    if not expected or not hmac.compare_digest(provided,expected): raise HTTPException(status_code=403,detail="Internal Notification access denied")

class NotificationIntentRequest(BaseModel):
    source_event_id:str=Field(min_length=8,max_length=36)
    recipient_user_id:int=Field(gt=0)
    actor_user_id:int|None=Field(default=None,gt=0)
    notification_type:str=Field(min_length=1,max_length=60)
    title:str|None=Field(default=None,max_length=160)
    body:str|None=Field(default=None,max_length=4000)
    target_type:str|None=Field(default=None,max_length=60)
    target_id:str|None=Field(default=None,max_length=120)
    target_url:str|None=Field(default=None,max_length=500)
    metadata:dict[str,Any]=Field(default_factory=dict)
    dedupe_key:str|None=Field(default=None,max_length=180)
    collapse_key:str|None=Field(default=None,max_length=120)
    template_key:str|None=Field(default=None,max_length=120)
    template_values:dict[str,Any]=Field(default_factory=dict)

class TemplateUpsertRequest(BaseModel):
    version:int=Field(default=1,ge=1,le=10000)
    notification_type:str=Field(min_length=1,max_length=60)
    title_template:str=Field(min_length=1,max_length=160)
    body_template:str=Field(min_length=1,max_length=4000)
    enabled:bool=True

@router.post("/intents",dependencies=[Depends(require_internal_token)])
def create_intent(payload:NotificationIntentRequest,db:Session=Depends(get_db)):
    try:
        notification,duplicate=notification_delivery_service.create_intent(db,source_event_id=payload.source_event_id,recipient_user_id=payload.recipient_user_id,actor_user_id=payload.actor_user_id,notification_type=payload.notification_type,title=payload.title,body=payload.body,target_type=payload.target_type,target_id=payload.target_id,target_url=payload.target_url,metadata=payload.metadata,dedupe_key=payload.dedupe_key,collapse_key=payload.collapse_key,template_key=payload.template_key,template_values=payload.template_values)
    except ValueError as exc: raise HTTPException(status_code=422,detail=str(exc)) from exc
    return {"notification_id":notification.id,"duplicate":duplicate}

@router.put("/templates/{template_key}",dependencies=[Depends(require_internal_token)])
def upsert_template(template_key:str,payload:TemplateUpsertRequest,db:Session=Depends(get_db)):
    template=notification_delivery_service.upsert_template(db,template_key=template_key[:120],version=payload.version,notification_type=payload.notification_type,title_template=payload.title_template,body_template=payload.body_template,enabled=payload.enabled)
    return {"template_key":template.template_key,"version":template.version,"enabled":template.enabled}
