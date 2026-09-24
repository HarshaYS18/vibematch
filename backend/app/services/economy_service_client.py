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


def _get(path: str) -> dict[str, Any]:
    url = settings.ECONOMY_INTERNAL_URL.rstrip("/") + "/" + path.lstrip("/")
    try:
        response = requests.get(
            url,
            headers={
                "X-FunKey-Internal-Token": settings.ECONOMY_INTERNAL_TOKEN,
                "Accept": "application/json",
            },
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


def wallet_snapshot(*, user_id: int) -> dict[str, Any]:
    return _get(f"wallet/snapshot/{int(user_id)}")


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



def adjust_wallet_levels(
    *,
    request_id: str,
    actor_user_id: int,
    target_user_id: int,
    send_exp_total: int | None,
    receive_exp_total: int | None,
    ruby_total: int | None,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"super-owner-level-adjust:{target_user_id}:{request_id}"
    return _request(
        "wallet/admin-level-adjust",
        {
            **mutation_context("wallet.admin_level_adjust", business_reference),
            "actor_user_id": int(actor_user_id),
            "target_user_id": int(target_user_id),
            "send_exp_total": send_exp_total,
            "receive_exp_total": receive_exp_total,
            "ruby_total": ruby_total,
            "reason": reason,
        },
    )

def adjust_vip_override(
    *,
    request_id: str,
    actor_user_id: int,
    target_user_id: int,
    vip_level: int,
    svip_level: int,
    vip_is_active: bool,
    svip_is_active: bool,
    svip_expires_at: str | None,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"vip-override:{target_user_id}:{request_id}"
    return _request(
        "vip/admin-override",
        {
            **mutation_context("vip.admin_override", business_reference),
            "actor_user_id": int(actor_user_id),
            "target_user_id": int(target_user_id),
            "vip_level": int(vip_level),
            "svip_level": int(svip_level),
            "vip_is_active": bool(vip_is_active),
            "svip_is_active": bool(svip_is_active),
            "svip_expires_at": svip_expires_at,
            "reason": reason,
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


def recharge_wallet(
    *,
    user_id: int,
    amount_inr: int,
    provider_reference: str,
) -> dict[str, Any]:
    business_reference = f"recharge:{user_id}:{provider_reference}"
    return _request(
        "wallet/recharge",
        {
            **mutation_context("wallet.recharge", business_reference),
            "user_id": int(user_id),
            "amount_inr": int(amount_inr),
            "provider_reference": provider_reference,
        },
    )


def convert_ruby(
    *,
    user_id: int,
    ruby_amount: int,
    request_id: str,
) -> dict[str, Any]:
    business_reference = f"ruby-convert:{user_id}:{request_id}"
    return _request(
        "wallet/convert-ruby",
        {
            **mutation_context("wallet.convert_ruby", business_reference),
            "user_id": int(user_id),
            "ruby_amount": int(ruby_amount),
        },
    )


def withdraw_ruby(
    *,
    user_id: int,
    ruby_amount: int,
    payout_method: str | None,
    payout_account_snapshot: str | None,
    request_id: str,
) -> dict[str, Any]:
    business_reference = f"ruby-withdraw:{user_id}:{request_id}"
    return _request(
        "wallet/withdraw-ruby",
        {
            **mutation_context("wallet.withdraw_ruby", business_reference),
            "user_id": int(user_id),
            "ruby_amount": int(ruby_amount),
            "payout_method": payout_method,
            "payout_account_snapshot": payout_account_snapshot,
        },
    )


def mint_supply(
    *,
    request_id: str,
    actor_user_id: int,
    target_pool_type: str,
    target_user_id: int | None,
    amount: int,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"supply-mint:{actor_user_id}:{request_id}"
    return _request(
        "supply/mint",
        {
            **mutation_context("supply.mint", business_reference),
            "actor_user_id": actor_user_id,
            "target_pool_type": target_pool_type,
            "target_user_id": target_user_id,
            "amount": amount,
            "reason": reason,
        },
    )


def allocate_supply(
    *,
    request_id: str,
    actor_user_id: int,
    source_pool_id: int,
    target_pool_type: str,
    target_user_id: int | None,
    amount: int,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"supply-allocate:{actor_user_id}:{request_id}"
    return _request(
        "supply/allocate",
        {
            **mutation_context("supply.allocate", business_reference),
            "actor_user_id": actor_user_id,
            "source_pool_id": source_pool_id,
            "target_pool_type": target_pool_type,
            "target_user_id": target_user_id,
            "amount": amount,
            "reason": reason,
        },
    )


def seller_sale(
    *,
    request_id: str,
    seller_user_id: int,
    buyer_user_id: int,
    source_pool_id: int,
    coin_amount: int,
    payment_amount: int,
    payment_currency: str,
    proof_url: str | None,
) -> dict[str, Any]:
    business_reference = f"seller-sale:{seller_user_id}:{request_id}"
    return _request(
        "supply/seller-sale",
        {
            **mutation_context("supply.seller_sale", business_reference),
            "seller_user_id": seller_user_id,
            "buyer_user_id": buyer_user_id,
            "source_pool_id": source_pool_id,
            "coin_amount": coin_amount,
            "payment_amount": payment_amount,
            "payment_currency": payment_currency,
            "proof_url": proof_url,
        },
    )


def official_recharge(
    *,
    request_id: str,
    actor_user_id: int,
    target_user_id: int | None,
    target_public_user_id: int | None,
    coin_amount: int,
    payment_amount: int,
    payment_currency: str,
    reason: str,
    proof_url: str | None,
) -> dict[str, Any]:
    business_reference = f"official-recharge:{actor_user_id}:{request_id}"
    return _request(
        "recharge/official",
        {
            **mutation_context("recharge.official", business_reference),
            "actor_user_id": actor_user_id,
            "target_user_id": target_user_id,
            "target_public_user_id": target_public_user_id,
            "coin_amount": coin_amount,
            "payment_amount": payment_amount,
            "payment_currency": payment_currency,
            "reason": reason,
            "proof_url": proof_url,
        },
    )


def configure_game_pool(
    *,
    request_id: str,
    actor_user_id: int,
    game_key: str,
    pool_type: str,
    opening_balance: int,
    daily_payout_cap: int,
    daily_loss_limit: int,
    max_single_payout: int,
    rtp_target_basis_points: int,
) -> dict[str, Any]:
    business_reference = f"game-pool-configure:{actor_user_id}:{request_id}"
    return _request(
        "game-pools/configure",
        {
            **mutation_context("game_pool.configure", business_reference),
            "actor_user_id": actor_user_id,
            "game_key": game_key,
            "pool_type": pool_type,
            "opening_balance": opening_balance,
            "daily_payout_cap": daily_payout_cap,
            "daily_loss_limit": daily_loss_limit,
            "max_single_payout": max_single_payout,
            "rtp_target_basis_points": rtp_target_basis_points,
        },
    )


def queue_bulk_grant(
    *,
    request_id: str,
    actor_user_id: int,
    coin_amount: int,
    active_only: bool,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"bulk-grant:{actor_user_id}:{request_id}"
    return _request(
        "bulk-grants/enqueue",
        {
            **mutation_context("bulk_grant.queue", business_reference),
            "actor_user_id": actor_user_id,
            "coin_amount": coin_amount,
            "active_only": active_only,
            "reason": reason,
        },
    )

def get_lucky_gift_control_house_pool() -> dict[str, Any]:
    return _get("lucky-gifts/admin/control-center/house-pool")


def update_lucky_gift_control_house_pool(
    *,
    request_id: str,
    actor_user_id: int,
    balance: int | None,
    reserved_balance: int | None,
    max_payout_per_round: int | None,
    daily_house_loss_limit: int | None,
    rtp_target_basis_points: int | None,
    status: str | None,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"lucky-gift-control-house-pool:{actor_user_id}:{request_id}"
    return _request(
        "lucky-gifts/admin/control-center/house-pool",
        {
            **mutation_context(
                "lucky_gift.control_house_pool.update",
                business_reference,
            ),
            "actor_user_id": actor_user_id,
            "balance": balance,
            "reserved_balance": reserved_balance,
            "max_payout_per_round": max_payout_per_round,
            "daily_house_loss_limit": daily_house_loss_limit,
            "rtp_target_basis_points": rtp_target_basis_points,
            "status": status,
            "reason": reason,
        },
    )


def get_lucky_gift_admin_props() -> dict[str, Any]:
    return _get("lucky-gifts/admin/props")


def get_lucky_gift_admin_moderation() -> dict[str, Any]:
    return _get("lucky-gifts/admin/moderation")


def get_lucky_gift_admin_house_pool() -> dict[str, Any]:
    return _get("lucky-gifts/admin/house-pool")


def list_lucky_gift_admin_house_pools() -> dict[str, Any]:
    return _get("lucky-gifts/admin/house-pool/list")


def update_lucky_gift_props(
    *,
    request_id: str,
    actor_user_id: int,
    props: dict[str, Any],
) -> dict[str, Any]:
    business_reference = f"lucky-gift-props:{actor_user_id}:{request_id}"
    return _request(
        "lucky-gifts/admin/props",
        {
            **mutation_context("lucky_gift.props.update", business_reference),
            "actor_user_id": actor_user_id,
            "props": props,
        },
    )


def adjust_lucky_gift_pool(
    *,
    request_id: str,
    actor_user_id: int,
    game_key: str,
    pool_type: str,
    direction: str,
    amount: int,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"lucky-gift-pool-adjust:{actor_user_id}:{request_id}"
    return _request(
        "lucky-gifts/admin/house-pool/adjust",
        {
            **mutation_context("lucky_gift.pool.adjust", business_reference),
            "actor_user_id": actor_user_id,
            "game_key": game_key,
            "pool_type": pool_type,
            "direction": direction,
            "amount": amount,
            "reason": reason,
        },
    )


def allocate_lucky_gift_pool(
    *,
    request_id: str,
    actor_user_id: int,
    amount: int,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"lucky-gift-pool-allocate:{actor_user_id}:{request_id}"
    return _request(
        "lucky-gifts/admin/house-pool/allocate",
        {
            **mutation_context("lucky_gift.pool.allocate", business_reference),
            "actor_user_id": actor_user_id,
            "amount": amount,
            "reason": reason,
        },
    )


def withdraw_lucky_gift_pool(
    *,
    request_id: str,
    actor_user_id: int,
    amount: int,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"lucky-gift-pool-withdraw:{actor_user_id}:{request_id}"
    return _request(
        "lucky-gifts/admin/house-pool/withdraw",
        {
            **mutation_context("lucky_gift.pool.withdraw", business_reference),
            "actor_user_id": actor_user_id,
            "amount": amount,
            "reason": reason,
        },
    )


def update_lucky_gift_pool_settings(
    *,
    request_id: str,
    actor_user_id: int,
    game_key: str,
    pool_type: str,
    status: str | None,
    daily_payout_cap: int | None,
    daily_loss_limit: int | None,
    max_single_payout: int | None,
    rtp_target_basis_points: int | None,
    reason: str,
) -> dict[str, Any]:
    business_reference = f"lucky-gift-pool-settings:{actor_user_id}:{request_id}"
    return _request(
        "lucky-gifts/admin/house-pool/settings",
        {
            **mutation_context("lucky_gift.pool.settings", business_reference),
            "actor_user_id": actor_user_id,
            "game_key": game_key,
            "pool_type": pool_type,
            "status": status,
            "daily_payout_cap": daily_payout_cap,
            "daily_loss_limit": daily_loss_limit,
            "max_single_payout": max_single_payout,
            "rtp_target_basis_points": rtp_target_basis_points,
            "reason": reason,
        },
    )

