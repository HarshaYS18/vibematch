from __future__ import annotations
from typing import Any
import requests
from app.core.config import settings

class NotificationServiceUnavailable(RuntimeError):
    pass

def create_intent(*,source_event_id:str,recipient_user_id:int,actor_user_id:int|None,notification_type:str,title:str,body:str,target_type:str|None=None,target_id:str|None=None,target_url:str|None=None,metadata:dict[str,Any]|None=None,dedupe_key:str|None=None,collapse_key:str|None=None)->dict:
    url=settings.NOTIFICATION_INTERNAL_URL.rstrip("/")+"/intents"
    payload={"source_event_id":source_event_id,"recipient_user_id":int(recipient_user_id),"actor_user_id":actor_user_id,"notification_type":notification_type,"title":title,"body":body,"target_type":target_type,"target_id":target_id,"target_url":target_url,"metadata":dict(metadata or {}),"dedupe_key":dedupe_key,"collapse_key":collapse_key}
    try:
        response=requests.post(url,headers={"X-FunKey-Internal-Token":settings.NOTIFICATION_INTERNAL_TOKEN,"Accept":"application/json"},json=payload,timeout=settings.NOTIFICATION_SERVICE_TIMEOUT_SECONDS)
    except requests.RequestException as exc:
        raise NotificationServiceUnavailable("Notification service unavailable") from exc
    if response.status_code<200 or response.status_code>=300:
        raise NotificationServiceUnavailable(f"Notification service rejected intent: {response.status_code}")
    data=response.json()
    if not isinstance(data,dict): raise NotificationServiceUnavailable("Invalid Notification service response")
    return data
