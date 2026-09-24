from __future__ import annotations

import hashlib
from typing import Any
from uuid import NAMESPACE_URL, uuid5

import requests

from app.core.config import settings


class EconomyServiceUnavailable(RuntimeError):
    pass


class EconomyServiceError(ValueError):
    def __init__(self, status_code: int, detail: str):
        super().__init__(detail)
        self.status_code = int(status_code)
        self.detail = detail


def mutation_context(operation: str, business_reference: str) -> dict[str, str]:
    canonical = f"funkey:economy:{operation}:{business_reference}"
    return {
        "transaction_id": str(uuid5(NAMESPACE_URL, canonical)),
        "idempotency_key": hashlib.sha256(canonical.encode("utf-8")).hexdigest(),
        "business_reference": business_reference,
    }


def _request(path: str, payload: dict[str, Any]) -> dict[str, Any]:
    url = settings.ECONOMY_INTERNAL_URL.rstrip("/") + "/" + path.lstrip("/")
    try:
        response = requests.post(
            url,
            headers={
                "X-FunKey-Internal-Token": settings.ECONOMY_INTERNAL_TOKEN,
                "Accept": "application/json",
            },
            json=payload,
            timeout=settings.ECONOMY_SERVICE_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise EconomyServiceUnavailable("Economy service unavailable") from exc

    if not 200 <= response.status_code < 300:
        detail = "Economy service request failed"
        try:
            decoded = response.json()
            detail = str(decoded.get("detail") or detail)
        except Exception:
            pass
        if response.status_code >= 500:
            raise EconomyServiceUnavailable(detail)
        raise EconomyServiceError(response.status_code, detail)

    decoded = response.json()
    if not isinstance(decoded, dict):
        raise EconomyServiceUnavailable("Economy service returned an invalid response")
    return decoded


def debit_wallet(
    *,
    user_id: int,
    amount: int,
    source_type: str,
    business_reference: str,
    source_id: str | None = None,
    reason: str | None = None,
    actor_user_id: int | None = None,
    currency: str = "COIN",
    operation: str = "wallet.debit",
) -> dict[str, Any]:
    return _request(
        "wallet/debit",
        {
            **mutation_context(operation, business_reference),
            "user_id": int(user_id),
            "amount": int(amount),
            "currency": currency,
            "source_type": source_type,
            "source_id": source_id,
            "reason": reason,
            "actor_user_id": actor_user_id,
        },
    )


def credit_wallet(
    *,
    user_id: int,
    amount: int,
    source_type: str,
    business_reference: str,
    source_id: str | None = None,
    reason: str | None = None,
    actor_user_id: int | None = None,
    currency: str = "COIN",
    operation: str = "wallet.credit",
) -> dict[str, Any]:
    return _request(
        "wallet/credit",
        {
            **mutation_context(operation, business_reference),
            "user_id": int(user_id),
            "amount": int(amount),
            "currency": currency,
            "source_type": source_type,
            "source_id": source_id,
            "reason": reason,
            "actor_user_id": actor_user_id,
        },
    )


def claim_mission_reward(
    *,
    user_id: int,
    mission_id: str,
    cycle_key: str,
    reward_coin_amount: int,
) -> dict[str, Any]:
    business_reference = f"mission:{user_id}:{mission_id}:{cycle_key}"
    return _request(
        "mission-rewards/claim",
        {
            **mutation_context("mission.reward", business_reference),
            "user_id": int(user_id),
            "mission_id": mission_id,
            "cycle_key": cycle_key,
            "reward_coin_amount": int(reward_coin_amount),
        },
    )


def game_wager(
    *,
    user_id: int,
    game_id: str,
    round_id: str | None,
    wager_amount: int,
    business_reference: str,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return _request(
        "game/wager",
        {
            **mutation_context("game.wager", business_reference),
            "user_id": int(user_id),
            "game_id": game_id,
            "round_id": round_id,
            "wager_amount": int(wager_amount),
            "metadata": metadata or {},
        },
    )


def game_settle(
    *,
    user_id: int,
    game_id: str,
    round_id: str | None,
    wager_amount: int,
    win_amount: int,
    multiplier: int,
    business_reference: str,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    return _request(
        "game/settle",
        {
            **mutation_context("game.settle", business_reference),
            "user_id": int(user_id),
            "game_id": game_id,
            "round_id": round_id,
            "wager_amount": int(wager_amount),
            "win_amount": int(win_amount),
            "multiplier": int(multiplier),
            "metadata": metadata or {},
        },
    )


def settle_gift(
    *,
    request_id: str,
    sender_user_id: int,
    receiver_user_id: int,
    gift_id: str,
    coin_value: int,
    quantity: int,
    room_id: int | None,
    relationship_id: int | None,
    is_relationship_gift: bool,
) -> dict[str, Any]:
    business_reference = f"gift:{sender_user_id}:{request_id}"
    return _request(
        "gifts/settle",
        {
            **mutation_context("gift.settle", business_reference),
            "sender_user_id": int(sender_user_id),
            "receiver_user_id": int(receiver_user_id),
            "gift_id": gift_id,
            "coin_value": int(coin_value),
            "quantity": int(quantity),
            "room_id": room_id,
            "relationship_id": relationship_id,
            "is_relationship_gift": bool(is_relationship_gift),
        },
    )


def settle_lucky_gift(
    *,
    request_id: str,
    sender_user_id: int,
    receiver_user_id: int,
    gift_id: str,
    gift_name: str | None,
    coin_value: int,
    quantity: int,
    room_id: int | None,
    relationship_id: int | None,
    is_relationship_gift: bool,
) -> dict[str, Any]:
    business_reference = f"lucky-gift:{sender_user_id}:{request_id}"
    return _request(
        "gifts/lucky/settle",
        {
            **mutation_context("gift.lucky.settle", business_reference),
            "sender_user_id": int(sender_user_id),
            "receiver_user_id": int(receiver_user_id),
            "gift_id": gift_id,
            "gift_name": gift_name,
            "coin_value": int(coin_value),
            "quantity": int(quantity),
            "room_id": room_id,
            "relationship_id": relationship_id,
            "is_relationship_gift": bool(is_relationship_gift),
        },
    )
