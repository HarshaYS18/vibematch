"""Idempotent handlers. Value movement is deliberately excluded."""
import requests
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError
from app.core.config import settings
from app.database import SessionLocal
from app.models.cdn_media import CdnMediaLinkedEntityType
from app.models.event_outbox import WorkerProcessedEvent
from app.services import cdn_media_service, inbox_service_client, notification_service_client
from apps.worker.events import EventEnvelope

class NotificationRequested(BaseModel):
    recipient_user_id:int=Field(gt=0); notification_type:str=Field(min_length=1,max_length=60); title:str=Field(min_length=1,max_length=160); body:str=Field(min_length=1,max_length=4000)
    target_type:str|None=Field(default=None,max_length=60); target_id:str|None=Field(default=None,max_length=120); target_url:str|None=Field(default=None,max_length=500)
    metadata:dict=Field(default_factory=dict); dedupe_key:str|None=Field(default=None,max_length=180); collapse_key:str|None=Field(default=None,max_length=120)

def handle_notification_requested(event:EventEnvelope)->str:
    payload=NotificationRequested.model_validate(event.payload)
    result=notification_service_client.create_intent(source_event_id=str(event.event_id),recipient_user_id=payload.recipient_user_id,actor_user_id=event.actor_user_id,notification_type=payload.notification_type,title=payload.title,body=payload.body,target_type=payload.target_type,target_id=payload.target_id,target_url=payload.target_url,metadata=payload.metadata,dedupe_key=payload.dedupe_key,collapse_key=payload.collapse_key)
    return "duplicate" if result.get("duplicate") else "processed"

class VibesPostPublished(BaseModel): post_id:int=Field(gt=0)
class VibesMediaRequested(BaseModel):
    action:str=Field(pattern="^(link|delete)$"); post_id:int=Field(gt=0); media_url:str=Field(min_length=1,max_length=1000); reason:str|None=Field(default=None,max_length=200)

def _processed(event:EventEnvelope,handler:str)->bool:
    with SessionLocal() as db: return db.get(WorkerProcessedEvent,{"event_id":str(event.event_id),"handler":handler}) is not None

def _mark_processed(event:EventEnvelope,handler:str)->str:
    marker={"event_id":str(event.event_id),"handler":handler}
    with SessionLocal() as db:
        try: db.add(WorkerProcessedEvent(**marker)); db.commit(); return "processed"
        except IntegrityError:
            db.rollback()
            if db.get(WorkerProcessedEvent,marker) is not None: return "duplicate"
            raise

def _vibes_fanout_snapshot(post_id:int)->dict:
    url=settings.VIBES_INTERNAL_URL.rstrip("/")+f"/posts/{post_id}/fanout"
    try: response=requests.get(url,headers={"X-FunKey-Internal-Token":settings.VIBES_INTERNAL_TOKEN,"Accept":"application/json"},timeout=settings.VIBES_SERVICE_TIMEOUT_SECONDS)
    except requests.RequestException as exc: raise RuntimeError("Vibes service unavailable") from exc
    if response.status_code<200 or response.status_code>=300: raise RuntimeError(f"Vibes fanout lookup failed: {response.status_code}")
    payload=response.json()
    if not isinstance(payload,dict): raise ValueError("Invalid Vibes fanout payload")
    return payload

def handle_vibes_post_published(event:EventEnvelope)->str:
    payload=VibesPostPublished.model_validate(event.payload); handler_name="vibes.post.published"
    if _processed(event,handler_name): return "duplicate"
    snapshot=_vibes_fanout_snapshot(payload.post_id); direct_ids={int(v) for v in snapshot.get("direct_mention_user_ids",[])}; mention_all_ids={int(v) for v in snapshot.get("mention_all_user_ids",[])}-direct_ids
    author_user_id=int(snapshot["author_user_id"]); author_public_user_id=int(snapshot["author_public_user_id"]); author_name=str(snapshot.get("author_name") or "Vibe User"); caption_preview=str(snapshot.get("caption_preview") or "")
    common={"event_id":str(event.event_id),"post_id":payload.post_id,"author_public_user_id":author_public_user_id,"author_name":author_name,"media_type":snapshot.get("media_type")}
    for user_id in sorted(direct_ids):
        notification_service_client.create_intent(source_event_id=str(event.event_id),recipient_user_id=user_id,actor_user_id=author_user_id,notification_type="vibe_mention",title=f"{author_name} mentioned you"[:160],body=f'Mentioned you in a Vibe: "{caption_preview}"',target_type="vibe",target_id=str(payload.post_id),metadata=dict(common),dedupe_key=f"vibe:{event.event_id}:{user_id}:mention",collapse_key=f"vibe:{payload.post_id}")
    for user_id in sorted(mention_all_ids):
        notification_service_client.create_intent(source_event_id=str(event.event_id),recipient_user_id=user_id,actor_user_id=author_user_id,notification_type="vibe_mention_all",title=f"{author_name} posted to followers"[:160],body=f'Mentioned all followers in a new Vibe: "{caption_preview}"',target_type="vibe",target_id=str(payload.post_id),metadata=dict(common),dedupe_key=f"vibe:{event.event_id}:{user_id}:mention-all",collapse_key=f"vibe:{payload.post_id}")
    result=_mark_processed(event,handler_name)
    inbox_text=f"Mentioned you in a Vibe\n\n{caption_preview}\n\nVibe ID: {payload.post_id}"
    for user_id in sorted(direct_ids):
        try:
            inbox_service_client.send_direct_message(sender_user_id=author_user_id,target_user_id=user_id,text=inbox_text,message_type="image" if snapshot.get("media_type")=="photo" and snapshot.get("media_url") else "text",attachment_url=snapshot.get("media_url"),metadata={"vibe_post_id":payload.post_id,"source":"vibe_mention","event_id":str(event.event_id)})
        except (inbox_service_client.InboxServiceUnavailable,ValueError): continue
    return result

def handle_vibes_media_requested(event:EventEnvelope)->str:
    payload=VibesMediaRequested.model_validate(event.payload); handler_name="vibes.media.requested"
    if _processed(event,handler_name): return "duplicate"
    with SessionLocal() as db:
        asset=cdn_media_service.link_media_to_entity(db,public_url=payload.media_url,linked_entity_type=CdnMediaLinkedEntityType.VIBES_POST,linked_entity_id=str(payload.post_id))
        if payload.action=="delete" and asset is not None: cdn_media_service.mark_media_deleted(db,asset=asset,actor_user_id=event.actor_user_id,reason=payload.reason or "vibe_deleted")
    return _mark_processed(event,handler_name)

HANDLERS={"notification.requested":handle_notification_requested,"vibes.post.published":handle_vibes_post_published,"vibes.media.requested":handle_vibes_media_requested}
