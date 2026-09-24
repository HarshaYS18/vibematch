from __future__ import annotations

import random
from datetime import datetime, timedelta, timezone
from string import Formatter
from uuid import uuid4
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import func, or_
from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.notification import NotificationDelivery, NotificationPreference, NotificationTemplate, UserNotification
from app.models.push_device_token import PushDeviceToken
from app.models.user import User
from app.services import event_outbox_service, notification_service, push_notification_service

ACTIVE_DELIVERY_STATUSES = ("PENDING", "RETRY", "DEFERRED")


def _render(template: str, values: dict[str, object]) -> str:
    normalized = {str(key): str(value) for key, value in values.items()}
    required = {field_name for _, field_name, _, _ in Formatter().parse(template) if field_name}
    missing = sorted(required - normalized.keys())
    if missing:
        raise ValueError("Missing notification template values: " + ", ".join(missing))
    return template.format_map(normalized)


def _resolve_content(db: Session, *, notification_type: str, title: str | None, body: str | None, template_key: str | None, template_values: dict[str, object]) -> tuple[str, str, str]:
    resolved_type = notification_type
    if template_key:
        template = db.query(NotificationTemplate).filter(NotificationTemplate.template_key == template_key, NotificationTemplate.enabled.is_(True)).order_by(NotificationTemplate.version.desc()).first()
        if template is None:
            raise ValueError("Notification template not found")
        resolved_type = template.notification_type
        title = _render(template.title_template, template_values)
        body = _render(template.body_template, template_values)
    if not title or not title.strip() or not body or not body.strip():
        raise ValueError("Notification title and body are required")
    return resolved_type[:60], title.strip()[:160], body.strip()[:4000]


def create_intent(db: Session, *, source_event_id: str, recipient_user_id: int, actor_user_id: int | None, notification_type: str, title: str | None, body: str | None, target_type: str | None, target_id: str | None, target_url: str | None, metadata: dict, dedupe_key: str | None, collapse_key: str | None, template_key: str | None = None, template_values: dict[str, object] | None = None) -> tuple[UserNotification, bool]:
    recipient = db.get(User, int(recipient_user_id))
    if recipient is None:
        raise ValueError("notification recipient does not exist")
    if actor_user_id is not None and db.get(User, int(actor_user_id)) is None:
        actor_user_id = None
    stable_dedupe = (dedupe_key or source_event_id).strip()[:180]
    existing = db.query(UserNotification).filter(UserNotification.recipient_user_id == recipient.id, UserNotification.dedupe_key == stable_dedupe).first()
    if existing is not None:
        return existing, True

    resolved_type, resolved_title, resolved_body = _resolve_content(db,notification_type=notification_type,title=title,body=body,template_key=template_key,template_values=template_values or {})
    notification = UserNotification(
        recipient_user_id=recipient.id,actor_user_id=actor_user_id,notification_type=resolved_type,
        title=resolved_title,body=resolved_body,target_type=target_type,target_id=target_id,target_url=target_url,
        metadata_json={**dict(metadata or {}), "source_event_id": source_event_id},
        source_event_id=source_event_id,dedupe_key=stable_dedupe,collapse_key=(collapse_key or "")[:120] or None,is_read=False,
    )
    db.add(notification); db.flush()
    preference = notification_service.get_or_create_preference(db, recipient.id)
    type_enabled = dict(preference.notification_types_json or {}).get(resolved_type, True)
    push_allowed = bool(preference.push_enabled) and bool(type_enabled)
    now = datetime.utcnow()
    for token in push_notification_service.active_tokens_for_user(db, recipient.id):
        db.add(NotificationDelivery(
            notification_id=notification.id,device_token_id=token.id,
            status="PENDING" if push_allowed else "SUPPRESSED",next_attempt_at=now,
            collapse_key=notification.collapse_key,last_error_code=None if push_allowed else "preference_disabled",
        ))
    event_outbox_service.enqueue_event(db,event_type="notification.created",actor_user_id=actor_user_id,payload={"notification_id":notification.id,"recipient_user_id":recipient.id,"notification_type":resolved_type})
    db.commit(); db.refresh(notification)
    return notification, False


def upsert_template(db: Session, *, template_key: str, version: int, notification_type: str, title_template: str, body_template: str, enabled: bool) -> NotificationTemplate:
    existing = db.query(NotificationTemplate).filter(NotificationTemplate.template_key == template_key, NotificationTemplate.version == int(version)).first()
    if existing is None:
        existing = NotificationTemplate(template_key=template_key, version=int(version))
    existing.notification_type=notification_type[:60]; existing.title_template=title_template[:160]; existing.body_template=body_template[:4000]; existing.enabled=bool(enabled)
    db.add(existing); db.commit(); db.refresh(existing); return existing


def claim_due_deliveries(db: Session, *, limit: int, lease_seconds: int) -> list[tuple[int, str]]:
    now=datetime.utcnow(); lock_token=str(uuid4())
    rows=(db.query(NotificationDelivery).filter(
        NotificationDelivery.status.in_(ACTIVE_DELIVERY_STATUSES),
        NotificationDelivery.next_attempt_at<=now,
        or_(NotificationDelivery.locked_until.is_(None),NotificationDelivery.locked_until<now),
    ).order_by(NotificationDelivery.next_attempt_at.asc(),NotificationDelivery.id.asc()).with_for_update(skip_locked=True).limit(max(1,min(int(limit),1000))).all())
    locked_until=now+timedelta(seconds=max(10,int(lease_seconds))); claims=[]
    for row in rows:
        row.lock_token=lock_token; row.locked_until=locked_until; db.add(row); claims.append((row.id,lock_token))
    db.commit(); return claims


def _quiet_end(preference: NotificationPreference, now: datetime) -> datetime | None:
    start=preference.quiet_start_minute; end=preference.quiet_end_minute
    if start is None or end is None or start==end: return None
    try: tz=ZoneInfo(preference.timezone or "UTC")
    except ZoneInfoNotFoundError: tz=ZoneInfo("UTC")
    local=now.replace(tzinfo=timezone.utc).astimezone(tz); minute=local.hour*60+local.minute
    if start<end:
        quiet=start<=minute<end; end_day=local.date()
    else:
        quiet=minute>=start or minute<end; end_day=(local+timedelta(days=1)).date() if minute>=start else local.date()
    if not quiet: return None
    end_local=datetime.combine(end_day,datetime.min.time(),tzinfo=tz)+timedelta(minutes=end)
    return end_local.astimezone(timezone.utc).replace(tzinfo=None)


def _hourly_sent_count(db: Session, recipient_user_id: int, now: datetime) -> int:
    return int(db.query(func.count(NotificationDelivery.id)).join(UserNotification,UserNotification.id==NotificationDelivery.notification_id).filter(
        UserNotification.recipient_user_id==int(recipient_user_id),NotificationDelivery.status=="SENT",NotificationDelivery.sent_at>=now-timedelta(hours=1)
    ).scalar() or 0)


def process_claimed_delivery(db: Session, *, delivery_id: int, lock_token: str) -> str:
    delivery=db.get(NotificationDelivery,int(delivery_id))
    if delivery is None or delivery.lock_token!=lock_token: return "lost"
    notification=db.get(UserNotification,delivery.notification_id); token=db.get(PushDeviceToken,delivery.device_token_id); now=datetime.utcnow()
    if notification is None or token is None or not token.is_active:
        delivery.status="INVALID_TOKEN" if token is not None else "FAILED"; delivery.last_error_code="token_inactive" if token is not None else "missing_dependency"; delivery.lock_token=None; delivery.locked_until=None; db.commit(); return delivery.status.lower()
    preference=notification_service.get_or_create_preference(db,notification.recipient_user_id)
    type_enabled=dict(preference.notification_types_json or {}).get(notification.notification_type,True)
    if not preference.push_enabled or not type_enabled:
        delivery.status="SUPPRESSED"; delivery.last_error_code="preference_disabled"; delivery.lock_token=None; delivery.locked_until=None; db.commit(); return "suppressed"
    quiet_end=_quiet_end(preference,now)
    if quiet_end is not None:
        delivery.status="DEFERRED"; delivery.next_attempt_at=quiet_end; delivery.last_error_code="quiet_hours"; delivery.lock_token=None; delivery.locked_until=None; db.commit(); return "deferred"
    if _hourly_sent_count(db,notification.recipient_user_id,now)>=int(preference.max_push_per_hour or 20):
        delivery.status="SUPPRESSED"; delivery.last_error_code="frequency_cap"; delivery.lock_token=None; delivery.locked_until=None; db.commit(); return "suppressed"
    delivery.attempt_count=int(delivery.attempt_count or 0)+1; db.commit()
    result=push_notification_service.send_fcm_message_result(token.fcm_token,title=notification.title,body=notification.body,data={"notification_id":notification.id,"notification_type":notification.notification_type,"target_type":notification.target_type,"target_id":notification.target_id,"target_url":notification.target_url},collapse_key=delivery.collapse_key)
    delivery=db.get(NotificationDelivery,int(delivery_id))
    if delivery is None or delivery.lock_token!=lock_token: return "lost"
    delivery.lock_token=None; delivery.locked_until=None; delivery.last_error_code=result.code; delivery.last_error_detail=result.detail
    if result.ok:
        delivery.status="SENT"; delivery.sent_at=datetime.utcnow(); delivery.provider_message_id=result.provider_message_id
    elif result.invalid_token:
        delivery.status="INVALID_TOKEN"; token=db.get(PushDeviceToken,delivery.device_token_id)
        if token is not None: token.is_active=False; db.add(token)
    elif result.retryable and delivery.attempt_count<settings.NOTIFICATION_PROVIDER_MAX_ATTEMPTS:
        delivery.status="RETRY"; delay=min(900.0,float(2**min(delivery.attempt_count,8)))+random.random(); delivery.next_attempt_at=datetime.utcnow()+timedelta(seconds=delay)
    else: delivery.status="FAILED"
    db.add(delivery); db.commit(); return delivery.status.lower()
