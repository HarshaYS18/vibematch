from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import CoinSupplyPool, GamePool, UserWallet
from app.models.user import User
from app.schemas.economy import EconomyDashboardResponse, EconomyPoolResponse, EconomyWalletResponse, GiftEconomyPreviewRequest, GiftEconomyPreviewResponse, GiftSendRequest, GiftSendResponse, RubyConversionRequest, RubyWithdrawRequestCreate
from app.services import economy_level_service, economy_service
from app.websocket.inbox_ws import inbox_ws_manager

router = APIRouter(prefix="/economy", tags=["Economy"])


def _wallet_response(db: Session, wallet: UserWallet) -> EconomyWalletResponse:
    levels = economy_level_service.wallet_level_payload(db, wallet)
    return EconomyWalletResponse(
        user_id=wallet.user_id,
        coin_balance=wallet.coin_balance,
        ruby_balance=wallet.ruby_balance,
        withdrawable_rubies=max(wallet.ruby_balance - wallet.locked_ruby_balance, 0),
        pending_withdraw_rubies=wallet.pending_withdraw_rubies,
        lifetime_coins_spent=wallet.lifetime_coins_spent,
        lifetime_coins_received_as_gifts=wallet.lifetime_coins_received_as_gifts,
        lifetime_rubies_earned=wallet.lifetime_rubies_earned,
        lifetime_recharge_coin_exp=levels["lifetime_recharge_coin_exp"],
        monthly_recharge_coin_exp=levels["monthly_recharge_coin_exp"],
        vip=levels["vip"],
        svip=levels["svip"],
        sent=levels["sent"],
        received=levels["received"],
    )


def _pool_response(pool: CoinSupplyPool | GamePool | None) -> EconomyPoolResponse | None:
    if pool is None:
        return None
    return EconomyPoolResponse(
        id=pool.id,
        owner_user_id=getattr(pool, "owner_user_id", None),
        pool_type=pool.pool_type,
        balance=pool.balance,
        reserved_balance=pool.reserved_balance,
        status=pool.status,
    )


@router.get("/me", response_model=EconomyDashboardResponse)
def get_my_economy_dashboard(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    data = economy_service.dashboard_for_user(db, current_user)
    return EconomyDashboardResponse(
        wallet=_wallet_response(db, data["wallet"]),
        seller_pool=_pool_response(data["seller_pool"]),
        merchant_pool=_pool_response(data["merchant_pool"]),
        gaming_pool=_pool_response(data["gaming_pool"]),
    )


@router.post("/gifts/preview", response_model=GiftEconomyPreviewResponse)
def preview_gift_economy(payload: GiftEconomyPreviewRequest):
    return GiftEconomyPreviewResponse(
        **economy_service.preview_gift_economy(
            coin_value=payload.coin_value,
            quantity=payload.quantity,
            room_id=payload.room_id,
            relationship_id=payload.relationship_id,
            is_relationship_gift=payload.is_relationship_gift,
        )
    )


@router.post("/gifts/send", response_model=GiftSendResponse)
async def send_gift(
    payload: GiftSendRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    result = economy_service.send_gift(
        db=db,
        sender=current_user,
        receiver_user_id=payload.receiver_user_id,
        gift_id=payload.gift_id,
        coin_value=payload.coin_value,
        quantity=payload.quantity,
        room_id=payload.room_id,
        relationship_id=payload.relationship_id,
        is_relationship_gift=payload.is_relationship_gift,
    )
    exp_updates = result.get("experience_updates") if isinstance(result.get("experience_updates"), dict) else {}
    await inbox_ws_manager.send_to_user(current_user.id, {"event": "experience_updated", "scope": "send", "payload": exp_updates.get("sender")})
    await inbox_ws_manager.send_to_user(payload.receiver_user_id, {"event": "experience_updated", "scope": "receive", "payload": exp_updates.get("receiver"), "ruby": {"earned": result.get("receiver_ruby_amount"), "balance": result.get("receiver_ruby_balance"), "lifetime_rubies_earned": result.get("receiver_lifetime_rubies_earned")}})
    if exp_updates.get("room") is not None:
        await inbox_ws_manager.broadcast_to_users([current_user.id, payload.receiver_user_id], {"event": "room_experience_updated", "payload": exp_updates.get("room")})
    return GiftSendResponse(**result)


@router.post("/rubies/convert-to-coins", response_model=EconomyWalletResponse)
def convert_rubies_to_coins(payload: RubyConversionRequest, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    wallet = economy_service.convert_rubies_to_coins(db, current_user, payload.ruby_amount)
    return _wallet_response(db, wallet)


@router.post("/rubies/withdraw")
def request_ruby_withdrawal(payload: RubyWithdrawRequestCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    request = economy_service.create_withdraw_request(
        db=db,
        user=current_user,
        ruby_amount=payload.ruby_amount,
        payout_method=payload.payout_method,
        payout_account_snapshot=payload.payout_account_snapshot,
    )
    return {"id": request.id, "ruby_amount": request.ruby_amount, "status": request.status}
