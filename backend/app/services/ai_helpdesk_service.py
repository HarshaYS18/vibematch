from app.schemas.support import AiHelpdeskClassification
from app.services.ai_provider_router import configured_provider


_CATEGORY_RULES: list[tuple[str, str, str, list[str]]] = [
    ("recharge_issue", "recharge_missing", "payment", ["amount", "date", "payment screenshot/order id"]),
    ("recharge_issue", "coins_not_credited", "coin", ["amount", "transaction id", "time"]),
    ("ban_appeal", "ban_appeal", "ban", ["ban message", "public user ID", "appeal reason"]),
    ("room_issue", "room_access", "room locked", ["room name or ID", "host name"]),
    ("room_issue", "room_access", "locked room", ["room name or ID", "host name"]),
    ("vip_svip_issue", "vip_frozen", "vip frozen", ["VIP/SVIP level", "last recharge date"]),
    ("vip_svip_issue", "svip_issue", "svip", ["SVIP level", "monthly recharge details"]),
    ("gift_issue", "gift_issue", "gift", ["gift name", "receiver", "time"]),
    ("payout_issue", "payout_issue", "payout", ["amount", "bank/UPI reference", "date"]),
    ("custom_theme_issue", "custom_theme", "theme", ["theme name", "upload/reference"]),
    ("account_issue", "account_access", "login", ["device", "mobile/email", "error message"]),
    ("inbox_issue", "inbox_help", "inbox", ["chat name", "what is missing"]),
    ("report_user", "report_abuse", "abuse", ["reported user", "what happened", "evidence"]),
    ("report_user", "report_abuse", "scam", ["reported user", "screenshots", "payment details if any"]),
]


def classify_support_message(message: str, explicit_category: str | None = None) -> AiHelpdeskClassification:
    text = message.strip()
    lowered = text.lower()
    category = explicit_category or "other"
    intent = "general_help"
    missing_fields: list[str] = []
    priority = "normal"

    for rule_category, rule_intent, needle, fields in _CATEGORY_RULES:
        if needle in lowered:
            category = explicit_category or rule_category
            intent = rule_intent
            missing_fields = fields
            break

    if any(word in lowered for word in ["abuse", "scam", "threat", "blackmail", "harass"]):
        priority = "high"
    elif any(word in lowered for word in ["urgent", "money", "payment", "recharge", "ban"]):
        priority = "normal"
    else:
        priority = "low" if len(text) < 40 else "normal"

    should_escalate = category in {"ban_appeal", "report_user", "payout_issue"} or priority == "high"
    suggested_reply = _suggested_reply(category, missing_fields, should_escalate)
    provider = configured_provider()
    active_provider = provider.provider if provider.configured else "local_rules"
    model = provider.model if provider.configured and provider.provider != "local_rules" else None
    return AiHelpdeskClassification(
        category=category,
        intent=intent,
        priority=priority,
        missing_fields=missing_fields,
        suggested_reply=suggested_reply,
        should_create_ticket=True,
        should_escalate=should_escalate,
        provider=active_provider,
        model=model,
    )


def classification_metadata(classification: AiHelpdeskClassification) -> dict:
    if hasattr(classification, "model_dump"):
        return classification.model_dump()
    if hasattr(classification, "dict"):
        return classification.dict()
    return {}


def _suggested_reply(category: str, missing_fields: list[str], should_escalate: bool) -> str:
    fields = ", ".join(missing_fields[:3])
    if category == "recharge_issue":
        return f"Vibe Match Team · AI Assistant: I can help with this recharge issue. Please share {fields} so support can verify it."
    if category == "ban_appeal":
        return f"Vibe Match Team · AI Assistant: I can create a ban appeal ticket. Please include {fields}; a human reviewer will decide."
    if category == "report_user":
        return f"Vibe Match Team · AI Assistant: I can route this safety report for review. Please add {fields}."
    if should_escalate:
        return "Vibe Match Team · AI Assistant: I can create a ticket and route it for human review."
    return "Vibe Match Team · AI Assistant: I can help with this and create a support ticket if needed."
