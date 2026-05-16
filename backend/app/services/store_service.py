from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from fastapi import HTTPException
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.room_theme import UserRoomThemeInventory
from app.models.store import StoreItem, StoreItemCategory, UserStoreInventory
from app.models.user import User
from app.schemas.store import (
    EquippedStoreItemResponse,
    EquippedStoreItemsResponse,
    InventoryItemResponse,
    InventoryResponse,
    StoreCatalogResponse,
    StoreItemResponse,
)
from app.services.rooms import room_theme_service

# Avatar frames and chat bubbles are 30-day ownership items by default.
# Other future store categories can be made permanent by omitting duration_days.
DEFAULT_STORE_ITEMS: list[dict[str, Any]] = [
    {
        "item_id": "bubble_pink_racer_car",
        "name": "Pink Racer Car Bubble",
        "category": StoreItemCategory.CHAT_BUBBLE.value,
        "description": "Glossy pink racing-car chat bubble. Valid for 30 days.",
        "price_coins": 200_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/chat_bubbles/pink_racer_car.png",
        "is_featured": True,
        "sort_order": 10,
    },
    {
        "item_id": "bubble_neon_bike_speed",
        "name": "Neon Bike Speed Bubble",
        "category": StoreItemCategory.CHAT_BUBBLE.value,
        "description": "Fast neon motorcycle bubble with pink light trail. Valid for 30 days.",
        "price_coins": 220_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/chat_bubbles/neon_bike_speed.png",
        "is_featured": True,
        "sort_order": 20,
    },
    {
        "item_id": "bubble_celestial_lotus_royal",
        "name": "Celestial Lotus Bubble",
        "category": StoreItemCategory.CHAT_BUBBLE.value,
        "description": "Royal lotus crystal chat bubble. Valid for 30 days.",
        "price_coins": 240_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/chat_bubbles/celestial_lotus_royal.png",
        "is_featured": True,
        "sort_order": 30,
    },
    {
        "item_id": "bubble_cricket_green_gold",
        "name": "Cricket Green Gold Bubble",
        "category": StoreItemCategory.CHAT_BUBBLE.value,
        "description": "Cricket mode inspired green-gold chat bubble. Valid for 30 days.",
        "price_coins": 260_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/chat_bubbles/cricket_green_gold.png",
        "sort_order": 40,
    },
    {
        "item_id": "bubble_butterfly_heart_gems",
        "name": "Butterfly Heart Bubble",
        "category": StoreItemCategory.CHAT_BUBBLE.value,
        "description": "Pink butterfly gemstone bubble. Valid for 30 days.",
        "price_coins": 280_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/chat_bubbles/butterfly_heart_gems.png",
        "is_featured": True,
        "sort_order": 50,
    },
    {
        "item_id": "frame_neon_bike_racer",
        "name": "Neon Bike Racer Frame",
        "category": StoreItemCategory.AVATAR_FRAME.value,
        "description": "Round neon motorcycle avatar frame. Valid for 30 days.",
        "price_coins": 300_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/avatar_frames/neon_bike_racer.png",
        "is_featured": True,
        "sort_order": 60,
    },
    {
        "item_id": "frame_royal_wing_crown",
        "name": "Royal Wing Crown Frame",
        "category": StoreItemCategory.AVATAR_FRAME.value,
        "description": "Gold wing crown avatar frame. Valid for 30 days.",
        "price_coins": 320_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/avatar_frames/royal_wing_crown.png",
        "is_featured": True,
        "sort_order": 70,
    },
    {
        "item_id": "frame_butterfly_crystal_heart",
        "name": "Butterfly Crystal Heart Frame",
        "category": StoreItemCategory.AVATAR_FRAME.value,
        "description": "Pink crystal butterfly avatar frame. Valid for 30 days.",
        "price_coins": 340_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/avatar_frames/butterfly_crystal_heart.png",
        "is_featured": True,
        "sort_order": 80,
    },
    {
        "item_id": "frame_speed_king_car",
        "name": "Speed King Car Frame",
        "category": StoreItemCategory.AVATAR_FRAME.value,
        "description": "Luxury racing car avatar frame. Valid for 30 days.",
        "price_coins": 360_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/avatar_frames/speed_king_car.png",
        "is_featured": True,
        "sort_order": 90,
    },
    {
        "item_id": "frame_cricket_champion",
        "name": "Cricket Champion Frame",
        "category": StoreItemCategory.AVATAR_FRAME.value,
        "description": "Cricket champion avatar frame. Valid for 30 days.",
        "price_coins": 380_000,
        "duration_days": 30,
        "asset_path": "assets/images/store/avatar_frames/cricket_champion.png",
        "is_featured": True,
        "sort_order": 100,
    },
    {
        "item_id": "entrance_starlight",
        "name": "Starlight Entrance",
        "category": StoreItemCategory.ENTRANCE_EFFECT.value,
        "description": "Animated room entry effect with starlight trail.",
        "price_coins": 500_000,
        "asset_path": "assets/images/store/entrance_effects/starlight.webp",
        "preview_url": "assets/videos/store/entrance_effects/starlight.mp4",
        "is_featured": True,
        "sort_order": 150,
    },
    {
        "item_id": "room_bg_royal_stage",
        "name": "Royal Stage Background",
        "category": StoreItemCategory.ROOM_BACKGROUND.value,
        "description": "Royal live-room stage background.",
        "price_coins": 250_000,
        "asset_path": "assets/images/room_backgrounds/store/royal_stage.webp",
        "linked_theme_id": "royal_stage",
        "sort_order": 160,
    },
    {
        "item_id": "room_bg_neon_vibe",
        "name": "Neon Vibe Background",
        "category": StoreItemCategory.ROOM_BACKGROUND.value,
        "description": "Neon live-room background for party rooms.",
        "price_coins": 500_000,
        "asset_path": "assets/images/room_backgrounds/store/neon_vibe_room.webp",
        "linked_theme_id": "neon_vibe_room",
        "is_featured": True,
        "sort_order": 170,
    },
    {
        "item_id": "profile_midnight_theme",
        "name": "Midnight Profile Theme",
        "category": StoreItemCategory.PROFILE_THEME.value,
        "description": "Dark premium theme for public profile card.",
        "price_coins": 220_000,
        "asset_path": "assets/images/store/profile_themes/midnight.webp",
        "sort_order": 180,
    },
    {
        "item_id": "badge_top_supporter",
        "name": "Top Supporter Badge",
        "category": StoreItemCategory.BADGE.value,
        "description": "Decorative badge for supporters. Official badges are never purchasable.",
        "price_coins": 150_000,
        "asset_path": "assets/images/store/badges/top_supporter.webp",
        "sort_order": 190,
    },
]

CATEGORY_ORDER = [
    StoreItemCategory.CHAT_BUBBLE.value,
    StoreItemCategory.AVATAR_FRAME.value,
    StoreItemCategory.ROOM_BACKGROUND.value,
    StoreItemCategory.ENTRANCE_EFFECT.value,
    StoreItemCategory.PROFILE_THEME.value,
    StoreItemCategory.BADGE.value,
]

_TIMED_CATEGORIES = {StoreItemCategory.AVATAR_FRAME.value, StoreItemCategory.CHAT_BUBBLE.value}


def seed_default_store_items(db: Session) -> None:
    room_theme_service.seed_default_room_themes(db)
    for item_data in DEFAULT_STORE_ITEMS:
        data = dict(item_data)
        duration_days = data.pop("duration_days", None)
        item = db.query(StoreItem).filter(StoreItem.item_id == data["item_id"]).first()
        if item is None:
            db.add(StoreItem(**data))
            continue
        for key, value in data.items():
            setattr(item, key, value)
        item.is_active = True
    db.flush()


def _duration_days_for_item(item: StoreItem) -> int | None:
    for data in DEFAULT_STORE_ITEMS:
        if data["item_id"] == item.item_id:
            duration = data.get("duration_days")
            return int(duration) if duration is not None else None
    if item.category in _TIMED_CATEGORIES:
        return 30
    return None


def _is_inventory_active(row: UserStoreInventory, now: datetime | None = None) -> bool:
    current = now or datetime.utcnow()
    return row.expires_at is None or row.expires_at > current


def _wallet_for_update(db: Session, user_id: int) -> UserWallet:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).with_for_update().first()
    if wallet is not None:
        return wallet
    wallet = UserWallet(user_id=user_id)
    db.add(wallet)
    db.flush()
    return wallet


def _inventory_for_item(db: Session, user_id: int, item_id: str, *, active_only: bool = True) -> UserStoreInventory | None:
    row = db.query(UserStoreInventory).filter(UserStoreInventory.user_id == user_id, UserStoreInventory.item_id == item_id).first()
    if row is None:
        return None
    if active_only and not _is_inventory_active(row):
        if row.is_equipped:
            row.is_equipped = False
            row.updated_at = datetime.utcnow()
            db.flush()
        return None
    return row


def _grant_linked_room_theme_inventory(db: Session, *, user_id: int, theme_id: str) -> None:
    existing = db.query(UserRoomThemeInventory).filter(UserRoomThemeInventory.user_id == user_id, UserRoomThemeInventory.theme_id == theme_id).first()
    if existing is None:
        db.add(UserRoomThemeInventory(user_id=user_id, theme_id=theme_id, source="store_purchase"))


def _item_payload(db: Session, item: StoreItem, user_id: int) -> StoreItemResponse:
    inventory = _inventory_for_item(db, user_id, item.item_id)
    is_owned = inventory is not None or item.price_coins <= 0
    return StoreItemResponse(
        item_id=item.item_id,
        name=item.name,
        category=item.category,
        description=item.description,
        price_coins=int(item.price_coins or 0),
        duration_days=_duration_days_for_item(item),
        asset_path=item.asset_path,
        image_url=item.image_url,
        preview_url=item.preview_url,
        linked_theme_id=item.linked_theme_id,
        is_active=item.is_active,
        is_featured=item.is_featured,
        is_owned=is_owned,
        is_equipped=bool(inventory and inventory.is_equipped),
        expires_at=inventory.expires_at if inventory is not None else None,
    )


def catalog(db: Session, user: User) -> StoreCatalogResponse:
    seed_default_store_items(db)
    db.commit()
    items = db.query(StoreItem).filter(StoreItem.is_active.is_(True)).order_by(StoreItem.sort_order.asc(), StoreItem.id.asc()).all()
    sections: dict[str, list[StoreItemResponse]] = {category: [] for category in CATEGORY_ORDER}
    for item in items:
        sections.setdefault(item.category, []).append(_item_payload(db, item, user.id))
    return StoreCatalogResponse(categories=[category for category in CATEGORY_ORDER if sections.get(category)], sections=sections)


def purchase(db: Session, user: User, item_id: str) -> StoreItemResponse:
    seed_default_store_items(db)
    item = db.query(StoreItem).filter(StoreItem.item_id == item_id, StoreItem.is_active.is_(True)).first()
    if item is None:
        raise HTTPException(status_code=404, detail="Store item not found")
    existing = _inventory_for_item(db, user.id, item.item_id)
    if existing is not None:
        return _item_payload(db, item, user.id)

    wallet = _wallet_for_update(db, user.id)
    price = int(item.price_coins or 0)
    if price > 0:
        if wallet.coin_balance < price:
            raise HTTPException(status_code=400, detail="Insufficient coins to purchase this item")
        before = wallet.coin_balance
        wallet.coin_balance -= price
        wallet.lifetime_coins_spent += price
        db.add(
            WalletLedger(
                user_id=user.id,
                currency_type=EconomyCurrency.COIN.value,
                direction=EconomyDirection.DEBIT.value,
                amount=price,
                before_balance=before,
                after_balance=wallet.coin_balance,
                source_type="STORE_PURCHASE",
                source_id=item.item_id,
                created_by_user_id=user.id,
                reason=f"Purchased store item {item.name}",
            )
        )

    if item.category == StoreItemCategory.ROOM_BACKGROUND.value and item.linked_theme_id:
        _grant_linked_room_theme_inventory(db, user_id=user.id, theme_id=item.linked_theme_id)

    duration_days = _duration_days_for_item(item)
    expires_at = datetime.utcnow() + timedelta(days=duration_days) if duration_days is not None else None
    db.add(UserStoreInventory(user_id=user.id, item_id=item.item_id, category=item.category, source="purchase", expires_at=expires_at))
    db.commit()
    return _item_payload(db, item, user.id)


def inventory(db: Session, user: User) -> InventoryResponse:
    seed_default_store_items(db)
    db.commit()
    now = datetime.utcnow()
    db.query(UserStoreInventory).filter(UserStoreInventory.user_id == user.id, UserStoreInventory.is_equipped.is_(True), UserStoreInventory.expires_at.is_not(None), UserStoreInventory.expires_at <= now).update({"is_equipped": False, "updated_at": now}, synchronize_session=False)
    rows = (
        db.query(UserStoreInventory, StoreItem)
        .join(StoreItem, StoreItem.item_id == UserStoreInventory.item_id)
        .filter(UserStoreInventory.user_id == user.id)
        .filter(or_(UserStoreInventory.expires_at.is_(None), UserStoreInventory.expires_at > now))
        .order_by(UserStoreInventory.created_at.desc())
        .all()
    )
    sections: dict[str, list[InventoryItemResponse]] = {category: [] for category in CATEGORY_ORDER}
    for owned, item in rows:
        sections.setdefault(item.category, []).append(
            InventoryItemResponse(
                item_id=item.item_id,
                name=item.name,
                category=item.category,
                source=owned.source,
                is_equipped=owned.is_equipped,
                duration_days=_duration_days_for_item(item),
                asset_path=item.asset_path,
                image_url=item.image_url,
                preview_url=item.preview_url,
                linked_theme_id=item.linked_theme_id,
                expires_at=owned.expires_at,
                created_at=owned.created_at,
            )
        )
    db.commit()
    return InventoryResponse(categories=[category for category in CATEGORY_ORDER if sections.get(category)], sections=sections)


def equip(db: Session, user: User, item_id: str, equipped: bool) -> InventoryItemResponse:
    owned = _inventory_for_item(db, user.id, item_id)
    if owned is None:
        raise HTTPException(status_code=404, detail="You do not own this item or it has expired")
    item = db.query(StoreItem).filter(StoreItem.item_id == item_id).first()
    if item is None:
        raise HTTPException(status_code=404, detail="Store item not found")
    if equipped:
        db.query(UserStoreInventory).filter(UserStoreInventory.user_id == user.id, UserStoreInventory.category == owned.category).update({"is_equipped": False, "updated_at": datetime.utcnow()})
    owned.is_equipped = equipped
    owned.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(owned)
    return InventoryItemResponse(
        item_id=item.item_id,
        name=item.name,
        category=item.category,
        source=owned.source,
        is_equipped=owned.is_equipped,
        duration_days=_duration_days_for_item(item),
        asset_path=item.asset_path,
        image_url=item.image_url,
        preview_url=item.preview_url,
        linked_theme_id=item.linked_theme_id,
        expires_at=owned.expires_at,
        created_at=owned.created_at,
    )


def _equipped_item(db: Session, user_id: int, category: str) -> EquippedStoreItemResponse | None:
    now = datetime.utcnow()
    row = (
        db.query(UserStoreInventory, StoreItem)
        .join(StoreItem, StoreItem.item_id == UserStoreInventory.item_id)
        .filter(UserStoreInventory.user_id == user_id)
        .filter(UserStoreInventory.category == category)
        .filter(UserStoreInventory.is_equipped.is_(True))
        .filter(or_(UserStoreInventory.expires_at.is_(None), UserStoreInventory.expires_at > now))
        .order_by(UserStoreInventory.updated_at.desc())
        .first()
    )
    if row is None:
        return None
    owned, item = row
    return EquippedStoreItemResponse(
        item_id=item.item_id,
        name=item.name,
        category=item.category,
        asset_path=item.asset_path,
        image_url=item.image_url,
        expires_at=owned.expires_at,
    )


def equipped_items(db: Session, user: User) -> EquippedStoreItemsResponse:
    return EquippedStoreItemsResponse(
        avatar_frame=_equipped_item(db, user.id, StoreItemCategory.AVATAR_FRAME.value),
        chat_bubble=_equipped_item(db, user.id, StoreItemCategory.CHAT_BUBBLE.value),
    )


def equipped_items_dict(db: Session, user: User) -> dict:
    payload = equipped_items(db, user)
    return payload.model_dump()
