from __future__ import annotations

from datetime import datetime
from typing import Any

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.economy import EconomyCurrency, EconomyDirection, UserWallet, WalletLedger
from app.models.room_theme import UserRoomThemeInventory
from app.models.store import StoreItem, StoreItemCategory, UserStoreInventory
from app.models.user import User
from app.schemas.store import InventoryItemResponse, InventoryResponse, StoreCatalogResponse, StoreItemResponse
from app.services.rooms import room_theme_service

DEFAULT_STORE_ITEMS: list[dict[str, Any]] = [
    {
        "item_id": "frame_aqua_glow",
        "name": "Aqua Glow Frame",
        "category": StoreItemCategory.AVATAR_FRAME.value,
        "description": "Clean glowing avatar frame for profile and room seats.",
        "price_coins": 120_000,
        "asset_path": "assets/images/store/avatar_frames/aqua_glow.webp",
        "is_featured": True,
        "sort_order": 10,
    },
    {
        "item_id": "frame_royal_gold",
        "name": "Royal Gold Frame",
        "category": StoreItemCategory.AVATAR_FRAME.value,
        "description": "Premium gold frame for high-value profiles.",
        "price_coins": 350_000,
        "asset_path": "assets/images/store/avatar_frames/royal_gold.webp",
        "is_featured": True,
        "sort_order": 20,
    },
    {
        "item_id": "bubble_pearl_chat",
        "name": "Pearl Chat Bubble",
        "category": StoreItemCategory.CHAT_BUBBLE.value,
        "description": "Soft pearl message bubble for live rooms and inbox.",
        "price_coins": 80_000,
        "asset_path": "assets/images/store/chat_bubbles/pearl_chat.webp",
        "sort_order": 30,
    },
    {
        "item_id": "bubble_neon_pulse",
        "name": "Neon Pulse Bubble",
        "category": StoreItemCategory.CHAT_BUBBLE.value,
        "description": "Bright neon chat bubble for premium room chat.",
        "price_coins": 180_000,
        "asset_path": "assets/images/store/chat_bubbles/neon_pulse.webp",
        "sort_order": 40,
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
        "sort_order": 50,
    },
    {
        "item_id": "room_bg_royal_stage",
        "name": "Royal Stage Background",
        "category": StoreItemCategory.ROOM_BACKGROUND.value,
        "description": "Royal live-room stage background.",
        "price_coins": 250_000,
        "asset_path": "assets/images/room_backgrounds/store/royal_stage.webp",
        "linked_theme_id": "royal_stage",
        "sort_order": 60,
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
        "sort_order": 70,
    },
    {
        "item_id": "profile_midnight_theme",
        "name": "Midnight Profile Theme",
        "category": StoreItemCategory.PROFILE_THEME.value,
        "description": "Dark premium theme for public profile card.",
        "price_coins": 220_000,
        "asset_path": "assets/images/store/profile_themes/midnight.webp",
        "sort_order": 80,
    },
    {
        "item_id": "badge_top_supporter",
        "name": "Top Supporter Badge",
        "category": StoreItemCategory.BADGE.value,
        "description": "Decorative badge for supporters. Official badges are never purchasable.",
        "price_coins": 150_000,
        "asset_path": "assets/images/store/badges/top_supporter.webp",
        "sort_order": 90,
    },
]

CATEGORY_ORDER = [
    StoreItemCategory.ROOM_BACKGROUND.value,
    StoreItemCategory.AVATAR_FRAME.value,
    StoreItemCategory.CHAT_BUBBLE.value,
    StoreItemCategory.ENTRANCE_EFFECT.value,
    StoreItemCategory.PROFILE_THEME.value,
    StoreItemCategory.BADGE.value,
]


def seed_default_store_items(db: Session) -> None:
    room_theme_service.seed_default_room_themes(db)
    for item_data in DEFAULT_STORE_ITEMS:
        item = db.query(StoreItem).filter(StoreItem.item_id == item_data["item_id"]).first()
        if item is None:
            db.add(StoreItem(**item_data))
            continue
        for key, value in item_data.items():
            setattr(item, key, value)
        item.is_active = True
    db.flush()


def _wallet_for_update(db: Session, user_id: int) -> UserWallet:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).with_for_update().first()
    if wallet is not None:
        return wallet
    wallet = UserWallet(user_id=user_id)
    db.add(wallet)
    db.flush()
    return wallet


def _inventory_for_item(db: Session, user_id: int, item_id: str) -> UserStoreInventory | None:
    return db.query(UserStoreInventory).filter(UserStoreInventory.user_id == user_id, UserStoreInventory.item_id == item_id).first()


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
        asset_path=item.asset_path,
        image_url=item.image_url,
        preview_url=item.preview_url,
        linked_theme_id=item.linked_theme_id,
        is_active=item.is_active,
        is_featured=item.is_featured,
        is_owned=is_owned,
        is_equipped=bool(inventory and inventory.is_equipped),
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

    db.add(UserStoreInventory(user_id=user.id, item_id=item.item_id, category=item.category, source="purchase"))
    db.commit()
    return _item_payload(db, item, user.id)


def inventory(db: Session, user: User) -> InventoryResponse:
    seed_default_store_items(db)
    db.commit()
    rows = (
        db.query(UserStoreInventory, StoreItem)
        .join(StoreItem, StoreItem.item_id == UserStoreInventory.item_id)
        .filter(UserStoreInventory.user_id == user.id)
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
                asset_path=item.asset_path,
                image_url=item.image_url,
                preview_url=item.preview_url,
                linked_theme_id=item.linked_theme_id,
                expires_at=owned.expires_at,
                created_at=owned.created_at,
            )
        )
    return InventoryResponse(categories=[category for category in CATEGORY_ORDER if sections.get(category)], sections=sections)


def equip(db: Session, user: User, item_id: str, equipped: bool) -> InventoryItemResponse:
    owned = _inventory_for_item(db, user.id, item_id)
    if owned is None:
        raise HTTPException(status_code=404, detail="You do not own this item")
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
        asset_path=item.asset_path,
        image_url=item.image_url,
        preview_url=item.preview_url,
        linked_theme_id=item.linked_theme_id,
        expires_at=owned.expires_at,
        created_at=owned.created_at,
    )
