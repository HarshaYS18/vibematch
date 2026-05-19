from dataclasses import dataclass
from enum import Enum

from sqlalchemy.orm import Session

from app.models.cdn_media import CdnMediaAsset, CdnMediaModerationStatus
from app.services.audit_log_service import create_admin_log


class ModerationDecision(str, Enum):
    APPROVED = "approved"
    FLAGGED = "flagged"
    REVIEW_REQUIRED = "review_required"
    REJECTED = "rejected"
    DISABLED = "disabled"


@dataclass(frozen=True)
class ModerationResult:
    decision: ModerationDecision
    provider: str
    model: str | None
    summary: str
    categories: dict


def audit_image_media(
    db: Session,
    *,
    asset: CdnMediaAsset,
    actor_user_id: int | None = None,
) -> ModerationResult:
    """Provider-neutral image moderation hook.

    OpenAI wiring must be added behind this function after confirming the
    current official SDK/model names and configuring OPENAI_API_KEY in env.
    Until enabled by Media Safety settings, this keeps uploads non-blocking and
    stores a clear moderation summary for CP visibility.
    """
    result = ModerationResult(
        decision=ModerationDecision.DISABLED,
        provider="openai",
        model=None,
        summary="OpenAI image auditing is configured but not enabled yet.",
        categories={},
    )
    asset.moderation_provider = result.provider
    asset.moderation_model = result.model
    asset.moderation_summary = result.summary
    if asset.moderation_status == CdnMediaModerationStatus.PENDING.value:
        asset.moderation_status = CdnMediaModerationStatus.HUMAN_REVIEW_REQUIRED.value
        asset.human_review_status = "pending"
    db.add(asset)
    db.commit()
    create_admin_log(
        db=db,
        actor_user_id=actor_user_id,
        target_user_id=asset.owner_user_id,
        action="MEDIA_IMAGE_AUDIT_STUB_RECORDED",
        resource_type="cdn_media",
        resource_id=asset.public_id,
        reason="provider_not_enabled",
        metadata_json={"provider": result.provider, "decision": result.decision.value},
    )
    return result


def audit_text_content(
    db: Session,
    *,
    entity_type: str,
    entity_id: str,
    text: str,
    actor_user_id: int | None = None,
) -> ModerationResult:
    """Provider-neutral text moderation hook.

    This intentionally avoids importing OpenAI directly until provider settings
    and current official model names are finalized. Existing profile/vibes/inbox
    routes should call this service later instead of creating duplicate APIs.
    """
    result = ModerationResult(
        decision=ModerationDecision.DISABLED,
        provider="openai",
        model=None,
        summary="OpenAI text moderation is configured but not enabled yet.",
        categories={},
    )
    create_admin_log(
        db=db,
        actor_user_id=actor_user_id,
        action="MEDIA_TEXT_AUDIT_STUB_RECORDED",
        resource_type=entity_type,
        resource_id=entity_id,
        reason="provider_not_enabled",
        metadata_json={"provider": result.provider, "decision": result.decision.value, "text_length": len(text)},
    )
    return result
