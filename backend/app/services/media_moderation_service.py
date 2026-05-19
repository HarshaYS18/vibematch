import os
from dataclasses import dataclass
from enum import Enum
from urllib import request as urlrequest
from urllib.error import HTTPError, URLError
import json

from sqlalchemy.orm import Session

from app.models.cdn_media import CdnMediaAsset, CdnMediaModerationStatus, MediaSafetySetting
from app.services.audit_log_service import create_admin_log


OPENAI_MODERATION_ENDPOINT = "https://api.openai.com/v1/moderations"
DEFAULT_OPENAI_MODERATION_MODEL = "omni-moderation-latest"


class ModerationDecision(str, Enum):
    APPROVED = "approved"
    FLAGGED = "flagged"
    REVIEW_REQUIRED = "review_required"
    REJECTED = "rejected"
    DISABLED = "disabled"
    PROVIDER_FAILED = "provider_failed"


@dataclass(frozen=True)
class ModerationResult:
    decision: ModerationDecision
    provider: str
    model: str | None
    summary: str
    categories: dict


def _setting(db: Session, key: str) -> dict:
    row = db.query(MediaSafetySetting).filter(MediaSafetySetting.key == key).first()
    return dict(row.value_json or {}) if row else {}


def _surface_enabled(settings: dict, surface: str) -> bool:
    return settings.get("enabled") is True and settings.get(surface, True) is True


def _openai_api_key() -> str | None:
    return os.getenv("OPENAI_API_KEY") or os.getenv("FUNKEY_OPENAI_API_KEY")


def _safe_openai_moderation(input_payload: object, *, model: str) -> tuple[bool, dict]:
    api_key = _openai_api_key()
    if not api_key:
        return False, {"error": "OPENAI_API_KEY not configured"}
    body = json.dumps({"model": model, "input": input_payload}).encode("utf-8")
    req = urlrequest.Request(
        OPENAI_MODERATION_ENDPOINT,
        data=body,
        headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urlrequest.urlopen(req, timeout=15) as response:  # nosec - fixed official HTTPS endpoint
            payload = json.loads(response.read().decode("utf-8"))
            return True, payload
    except (HTTPError, URLError, TimeoutError, json.JSONDecodeError) as exc:
        return False, {"error": str(exc)}


def _summarize_result(payload: dict) -> tuple[bool, dict, dict]:
    result = (payload.get("results") or [{}])[0]
    flagged = bool(result.get("flagged"))
    categories = result.get("categories") if isinstance(result.get("categories"), dict) else {}
    scores = result.get("category_scores") if isinstance(result.get("category_scores"), dict) else {}
    return flagged, categories, scores


def _decision_for_flagged(settings: dict, *, flagged: bool) -> ModerationDecision:
    if not flagged:
        return ModerationDecision.APPROVED if settings.get("auto_approve_safe") else ModerationDecision.REVIEW_REQUIRED
    if settings.get("auto_reject_clear_violation"):
        return ModerationDecision.REJECTED
    return ModerationDecision.REVIEW_REQUIRED if settings.get("uncertain_to_review", True) else ModerationDecision.FLAGGED


def audit_image_media(db: Session, *, asset: CdnMediaAsset, actor_user_id: int | None = None) -> ModerationResult:
    settings = _setting(db, "openai_image_moderation")
    surface = asset.media_type
    model = settings.get("model") or DEFAULT_OPENAI_MODERATION_MODEL
    if not _surface_enabled(settings, surface):
        result = ModerationResult(ModerationDecision.DISABLED, "openai", model, "OpenAI image auditing is disabled for this media type.", {})
        _apply_asset_result(db, asset, result, actor_user_id=actor_user_id)
        return result

    input_payload = [{"type": "image_url", "image_url": {"url": asset.public_url}}]
    ok, payload = _safe_openai_moderation(input_payload, model=model)
    if not ok:
        fallback = settings.get("fallback_if_provider_fails", "human_review_required")
        decision = ModerationDecision.REVIEW_REQUIRED if fallback in {"human_review_required", "block_until_reviewed"} else ModerationDecision.PROVIDER_FAILED
        result = ModerationResult(decision, "openai", model, f"OpenAI image audit failed: {payload.get('error')}", {})
        _apply_asset_result(db, asset, result, actor_user_id=actor_user_id)
        return result

    flagged, categories, scores = _summarize_result(payload)
    decision = _decision_for_flagged(settings, flagged=flagged)
    summary = "OpenAI image audit flagged content." if flagged else "OpenAI image audit did not flag content."
    result = ModerationResult(decision, "openai", model, summary, {"categories": categories, "scores": scores})
    _apply_asset_result(db, asset, result, actor_user_id=actor_user_id)
    return result


def _apply_asset_result(db: Session, asset: CdnMediaAsset, result: ModerationResult, *, actor_user_id: int | None = None) -> None:
    asset.moderation_provider = result.provider
    asset.moderation_model = result.model
    asset.moderation_summary = result.summary
    if result.decision == ModerationDecision.APPROVED:
        asset.moderation_status = CdnMediaModerationStatus.AI_APPROVED.value
        asset.human_review_status = None
    elif result.decision in {ModerationDecision.REVIEW_REQUIRED, ModerationDecision.PROVIDER_FAILED}:
        asset.moderation_status = CdnMediaModerationStatus.HUMAN_REVIEW_REQUIRED.value
        asset.human_review_status = "pending"
    elif result.decision in {ModerationDecision.FLAGGED, ModerationDecision.REJECTED}:
        asset.moderation_status = CdnMediaModerationStatus.AI_FLAGGED.value
        asset.human_review_status = "pending"
    db.add(asset)
    db.commit()
    create_admin_log(
        db=db,
        actor_user_id=actor_user_id,
        target_user_id=asset.owner_user_id,
        action="MEDIA_IMAGE_AUDIT_RECORDED",
        resource_type="cdn_media",
        resource_id=asset.public_id,
        reason=result.summary,
        metadata_json={"provider": result.provider, "model": result.model, "decision": result.decision.value, "categories": result.categories},
    )


def audit_text_content(db: Session, *, entity_type: str, entity_id: str, text: str, actor_user_id: int | None = None) -> ModerationResult:
    settings = _setting(db, "openai_text_moderation")
    model = settings.get("model") or DEFAULT_OPENAI_MODERATION_MODEL
    if settings.get("enabled") is not True:
        result = ModerationResult(ModerationDecision.DISABLED, "openai", model, "OpenAI text moderation is disabled.", {})
        _record_text_result(db, entity_type=entity_type, entity_id=entity_id, text=text, result=result, actor_user_id=actor_user_id)
        return result

    ok, payload = _safe_openai_moderation(text, model=model)
    if not ok:
        fallback = settings.get("fallback_if_provider_fails", "allow_and_log")
        decision = ModerationDecision.REVIEW_REQUIRED if fallback in {"human_review_required", "block_until_reviewed"} else ModerationDecision.PROVIDER_FAILED
        result = ModerationResult(decision, "openai", model, f"OpenAI text moderation failed: {payload.get('error')}", {})
        _record_text_result(db, entity_type=entity_type, entity_id=entity_id, text=text, result=result, actor_user_id=actor_user_id)
        return result

    flagged, categories, scores = _summarize_result(payload)
    mode = settings.get(entity_type) or settings.get("default_mode") or "flag_only"
    if not flagged:
        decision = ModerationDecision.APPROVED
    elif mode == "block_high_risk":
        decision = ModerationDecision.REJECTED
    elif mode == "route_uncertain_to_review":
        decision = ModerationDecision.REVIEW_REQUIRED
    else:
        decision = ModerationDecision.FLAGGED
    summary = "OpenAI text moderation flagged content." if flagged else "OpenAI text moderation did not flag content."
    result = ModerationResult(decision, "openai", model, summary, {"categories": categories, "scores": scores})
    _record_text_result(db, entity_type=entity_type, entity_id=entity_id, text=text, result=result, actor_user_id=actor_user_id)
    return result


def _record_text_result(db: Session, *, entity_type: str, entity_id: str, text: str, result: ModerationResult, actor_user_id: int | None = None) -> None:
    create_admin_log(
        db=db,
        actor_user_id=actor_user_id,
        action="MEDIA_TEXT_AUDIT_RECORDED",
        resource_type=entity_type,
        resource_id=entity_id,
        reason=result.summary,
        metadata_json={"provider": result.provider, "model": result.model, "decision": result.decision.value, "text_length": len(text), "categories": result.categories},
    )
