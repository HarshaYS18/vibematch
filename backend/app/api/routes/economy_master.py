from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import UserWallet
from app.models.user import User
from app.services import economy_level_service, experience_service

router = APIRouter(prefix="/economy", tags=["Economy Master"])


def _wallet(db: Session, user_id: int) -> UserWallet:
    return economy_level_service.get_or_create_wallet(db, user_id)


def _summary_for_user(db: Session, user: User, *, private: bool) -> dict:
    wallet = _wallet(db, user.id)
    levels = economy_level_service.wallet_level_payload(db, wallet)
    exp = experience_service.get_or_create_user_exp(db, user.id)
    payload = {
        "user": {
            "user_id": user.id,
            "public_user_id": user.public_user_id,
            "display_name": user.display_name or user.username,
            "username": user.username,
            "avatar_url": user.avatar_url,
        },
        "vip": levels.get("vip", {}),
        "svip": levels.get("svip", {}),
        "levels": {
            "send_level": exp.send_level,
            "send_exp": exp.send_total_exp,
            "receive_level": exp.receive_level,
            "receive_exp": exp.receive_total_exp,
            "send": levels.get("sent", {}),
            "receive": levels.get("received", {}),
        },
        "contribution": {
            "monthly_sent_coins": levels.get("monthly_gift_coins_sent", 0),
            "monthly_received_coins": levels.get("monthly_gift_coins_received", 0),
        },
        "family": None,
        "relationship": None,
    }
    if private:
        payload["wallet"] = {
            "coins": wallet.coin_balance,
            "rubies": wallet.ruby_balance,
            "withdrawable_rubies": max(wallet.ruby_balance - wallet.locked_ruby_balance, 0),
            "pending_withdraw_rubies": wallet.pending_withdraw_rubies,
        }
    return payload


@router.get("/me/master")
def get_my_master_economy(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return _summary_for_user(db, current_user, private=True)


@router.get("/users/{public_user_id}/public-card")
def get_public_economy_card(public_user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.public_user_id == public_user_id, User.is_active.is_(True)).first()
    if user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return _summary_for_user(db, user, private=False)
