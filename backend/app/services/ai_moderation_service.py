from uuid import uuid4

from sqlalchemy.orm import Session

from app.models.moderation_event import ModerationEvent
from app.models.user import User
from app.schemas.support import ImageModerationRequest, ModerationResponse, TextModerationRequest
from app.services.ai_provider_router import configured_provider


ABUSE_TERMS = {"abuse", "idiot", "stupid", "hate", "kill", "threat"}
SPAM_TERMS = {"spam", "follow me", "join now", "free coins", "click here"}
SCAM_TERMS = {"upi refund", "password", "otp", "send money", "investment", "double your"}
LINK_TERMS = {"http://", "https://", "t.me/", "wa.me/", "bit.ly"}


def moderate_text(db: Session, *, actor: User, payload: TextModerationRequest) -> ModerationResponse:
    text = payload.text.strip()
    lowered = text.lower()
    categories: list[str] = []
    if any(term in lowered for term in ABUSE_TERMS):
        categories.append("abuse")
    if any(term in lowered for term in SPAM_TERMS):
        categories.append("spam")
    if any(term in lowered for term in SCAM_TERMS):
        categories.append("scam")
    if any(term in lowered for term in LINK_TERMS):
        categories.append("link")
    if len(text) > 0 and len(set(text.split())) <= 2 and len(text) > 80:
        categories.append("flood")

    if "scam" in categories:
        decision, severity, message = ("block", "high", "This message looks like a scam or credential request, so it was blocked for safety.")
    elif "abuse" in categories or "flood" in categories:
        decision, severity, message = ("warn", "medium", "Please keep chat respectful. This message may be reviewed if sent again.")
    elif "spam" in categories or "link" in categories:
        decision, severity, message = ("warn", "low", "This looks promotional or link-heavy. Keep room chat safe and relevant.")
    else:
        decision, severity, message = ("allow", "none", "Message passed local safety checks.")

    provider = configured_provider()
    event = ModerationEvent(
        public_id=f"MOD-{uuid4().hex[:12].upper()}",
        actor_user_id=actor.id,
        target_user_id=payload.target_user_id,
        room_id=payload.room_id,
        content_type="text",
        surface=payload.surface,
        decision=decision,
        severity=severity,
        provider=provider.provider if provider.configured else "local_rules",
        categories_json=categories,
        snippet=text[:260],
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return ModerationResponse(event_id=event.public_id, decision=decision, severity=severity, categories=categories, user_message=message, provider=event.provider)


def moderate_image(db: Session, *, actor: User, payload: ImageModerationRequest) -> ModerationResponse:
    provider = configured_provider()
    event = ModerationEvent(
        public_id=f"MOD-{uuid4().hex[:12].upper()}",
        actor_user_id=actor.id,
        target_user_id=payload.target_user_id,
        room_id=payload.room_id,
        content_type="image",
        surface=payload.surface,
        decision="pending_review",
        severity="unknown",
        provider=provider.provider if provider.configured else "local_rules",
        categories_json=["image_pending_review"],
        snippet=payload.image_url[:260],
        metadata_json={"image_url": payload.image_url, "safe_to_display": False},
    )
    db.add(event)
    db.commit()
    db.refresh(event)
    return ModerationResponse(event_id=event.public_id, decision="pending_review", severity="unknown", categories=["image_pending_review"], user_message="Image is pending safety review before it can be shown.", provider=event.provider)
