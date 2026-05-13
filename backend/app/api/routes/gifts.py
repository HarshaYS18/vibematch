from __future__ import annotations

from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.routes.users import get_current_user
from app.database import get_db
from app.models.economy import GiftTransaction
from app.models.room import Room
from app.models.user import User
from app.services import economy_service

router = APIRouter(prefix="/gifts", tags=["Gifts"])


class GiftCatalogItemResponse(BaseModel):
    id: str
    name: str
    category: str
    coin_value: int
    chat_symbol: str
    asset_path: str | None = None
    video_asset_path: str | None = None
    enabled: bool = True


class GiftSendRequest(BaseModel):
    receiver_user_id: int = Field(gt=0)
    gift_id: str = Field(min_length=1, max_length=80)
    coin_value: int = Field(gt=0, le=100_000_000)
    quantity: int = Field(default=1, ge=1, le=999)
    room_public_id: str | None = Field(default=None, max_length=80)
    relationship_id: int | None = None
    is_relationship_gift: bool = False


class GiftPreviewResponse(BaseModel):
    total_coin_value: int
    receiver_ruby_amount: int
    platform_share_coin_value: int
    send_exp_amount: int
    receive_exp_amount: int
    room_exp_amount: int
    love_score_amount: int
    rule: str


class GiftSendResponse(GiftPreviewResponse):
    gift_transaction_id: int
    sender_user_id: int
    receiver_user_id: int
    sender_coin_balance: int
    receiver_ruby_balance: int
    created_at: datetime


class GiftTransactionResponse(BaseModel):
    id: int
    sender_user_id: int
    receiver_user_id: int
    room_id: int | None
    gift_id: str
    coin_value: int
    quantity: int
    total_coin_value: int
    receiver_ruby_amount: int
    platform_share_coin_value: int
    agency_share_coin_value: int
    room_exp_amount: int
    send_exp_amount: int
    receive_exp_amount: int
    relationship_id: int | None
    love_score_amount: int
    created_at: datetime


_GIFT_CATALOG = [
    GiftCatalogItemResponse(id="love_bomb", name="Love Bomb", category="classic", coin_value=1, chat_symbol="❤️", asset_path="assets/images/gifts/love_bomb.png"),
    GiftCatalogItemResponse(id="rose_rain", name="Rose Rain", category="classic", coin_value=5, chat_symbol="🌹", asset_path="assets/images/gifts/rose_rain.png"),
    GiftCatalogItemResponse(id="rocket", name="Rocket", category="classic", coin_value=99, chat_symbol="🚀", asset_path="assets/images/gifts/rocket.png"),
    GiftCatalogItemResponse(id="lucky_star", name="Lucky Star", category="lucky", coin_value=19, chat_symbol="✨", asset_path="assets/images/gifts/lucky_star.png"),
    GiftCatalogItemResponse(id="lucky_packet", name="Lucky Packet", category="lucky", coin_value=39, chat_symbol="🧧", asset_path="assets/images/gifts/lucky_packet.png"),
    GiftCatalogItemResponse(id="relationship_ring", name="Couple Ring", category="relationship", coin_value=299, chat_symbol="💍", asset_path="assets/images/gifts/couple_ring.png"),
    GiftCatalogItemResponse(id="event_crown", name="Event Crown", category="event", coin_value=199, chat_symbol="🏆", asset_path="assets/images/gifts/event_crown.png"),
    GiftCatalogItemResponse(id="vip_crown", name="VIP Crown", category="vip", coin_value=499, chat_symbol="👑", asset_path="assets/images/gifts/royal_crown.png"),
    GiftCatalogItemResponse(id="svip_aura", name="SVIP Aura", category="svip", coin_value=399, chat_symbol="💎", asset_path="assets/images/gifts/svip_aura.png"),
    GiftCatalogItemResponse(id="love_rocket", name="Love Rocket", category="premium", coin_value=999, chat_symbol="🚀", asset_path="assets/gifts/love_rocket/icon/love_rocket_icon.webp", video_asset_path="assets/videos/gifts/love_rocket.mp4"),
    GiftCatalogItemResponse(id="premium_castle", name="Castle", category="premium", coin_value=1999, chat_symbol="🏰", asset_path="assets/images/gifts/premium_castle.png"),
    GiftCatalogItemResponse(id="owned_rose_pack", name="Rose Pack", category="baggage", coin_value=0, chat_symbol="🎒", asset_path="assets/images/gifts/rose_pack.png"),
]


def _resolve_room_internal_id(db: Session, room_public_id: str | None) -> int | None:
    if not room_public_id:
        return None
    room = db.query(Room).filter(Room.room_public_id == room_public_id).first()
    if room is None:
        return None
    return room.id


def _transaction_response(tx: GiftTransaction) -> GiftTransactionResponse:
    return GiftTransactionResponse(
        id=tx.id,
        sender_user_id=tx.sender_user_id,
        receiver_user_id=tx.receiver_user_id,
        room_id=tx.room_id,
        gift_id=tx.gift_id,
        coin_value=tx.coin_value,
        quantity=tx.quantity,
        total_coin_value=tx.total_coin_value,
        receiver_ruby_amount=tx.receiver_ruby_amount,
        platform_share_coin_value=tx.platform_share_coin_value,
        agency_share_coin_value=tx.agency_share_coin_value,
        room_exp_amount=tx.room_exp_amount,
        send_exp_amount=tx.send_exp_amount,
        receive_exp_amount=tx.receive_exp_amount,
        relationship_id=tx.relationship_id,
        love_score_amount=tx.love_score_amount,
        created_at=tx.created_at,
    )


@router.get("/catalog", response_model=list[GiftCatalogItemResponse])
def get_gift_catalog():
    return _GIFT_CATALOG


@router.post("/preview", response_model=GiftPreviewResponse)
def preview_gift(payload: GiftSendRequest, db: Session = Depends(get_db)):
    room_id = _resolve_room_internal_id(db, payload.room_public_id)
    return economy_service.preview_gift_economy(
        coin_value=payload.coin_value,
        quantity=payload.quantity,
        room_id=room_id,
        relationship_id=payload.relationship_id,
        is_relationship_gift=payload.is_relationship_gift,
    )


@router.post("/send", response_model=GiftSendResponse)
def send_gift(
    payload: GiftSendRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if payload.coin_value <= 0:
        raise HTTPException(status_code=400, detail="Only paid gifts can be sent through the real wallet path")
    room_id = _resolve_room_internal_id(db, payload.room_public_id)
    result = economy_service.send_gift(
        db=db,
        sender=current_user,
        receiver_user_id=payload.receiver_user_id,
        gift_id=payload.gift_id,
        coin_value=payload.coin_value,
        quantity=payload.quantity,
        room_id=room_id,
        relationship_id=payload.relationship_id,
        is_relationship_gift=payload.is_relationship_gift,
    )
    return GiftSendResponse(**result, created_at=datetime.utcnow())


@router.get("/transactions/me", response_model=list[GiftTransactionResponse])
def get_my_gift_transactions(
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    safe_limit = max(1, min(limit, 100))
    items = (
        db.query(GiftTransaction)
        .filter((GiftTransaction.sender_user_id == current_user.id) | (GiftTransaction.receiver_user_id == current_user.id))
        .order_by(GiftTransaction.id.desc())
        .limit(safe_limit)
        .all()
    )
    return [_transaction_response(item) for item in items]
