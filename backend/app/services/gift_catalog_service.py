from copy import deepcopy
from random import random
from urllib.parse import quote

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models.gift_catalog import GiftCatalogCategory, GiftCatalogItem

GIFT_CATALOG_VERSION = 1

CATEGORY_LABELS = {
    "classic": "Classic",
    "lucky": "Lucky",
    "relationship": "Relationship",
    "event": "Event",
    "premium": "Premium",
    "svip": "SVIP",
    "vip": "VIP",
    "baggage": "Baggage",
}

CATEGORY_ORDER = {
    "premium": 10,
    "lucky": 20,
    "classic": 30,
    "relationship": 40,
    "event": 50,
    "svip": 60,
    "vip": 70,
    "baggage": 80,
}

NORMAL_GIFTS = [
    {
        "id": "rose_bloom",
        "name": "Rose Bloom",
        "category": "classic",
        "gift_type": "normal",
        "coin_value": 9,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_favorite",
        "chat_symbol": "🌹",
        "asset_path": "assets/gifts/normal/rose_bloom.webp",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/rose_bloom/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 10,
    },
    {
        "id": "gold_coin",
        "name": "Gold Coin",
        "category": "classic",
        "gift_type": "normal",
        "coin_value": 29,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_paid",
        "chat_symbol": "🪙",
        "asset_path": "assets/gifts/normal/gold_coin.webp",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/gold_coin/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 20,
    },
    {
        "id": "party_pop",
        "name": "Party Pop",
        "category": "classic",
        "gift_type": "normal",
        "coin_value": 99,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_celebration",
        "chat_symbol": "🎉",
        "asset_path": "assets/gifts/normal/party_pop.webp",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/party_pop/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 30,
    },
    {
        "id": "love_rocket",
        "name": "Love Rocket",
        "category": "premium",
        "gift_type": "normal",
        "coin_value": 999,
        "min_combo": 1,
        "max_combo": 1,
        "icon_key": "local_rocket",
        "chat_symbol": "🚀",
        "asset_path": "assets/gifts/love_rocket/icon/love_rocket_icon.webp",
        "video_asset_path": "assets/videos/gifts/love_rocket.mp4",
        "cdn_asset_path": "gifts/love_rocket/v1/icon.webp",
        "cdn_video_path": "gifts/love_rocket/v1/animation.mp4",
        "animation_type": "video",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": True,
        "show_gift_flight": False,
        "version": 1,
        "sort_order": 100,
    },
    {
        "id": "proposal",
        "name": "Proposal",
        "category": "premium",
        "gift_type": "normal",
        "coin_value": 1299,
        "min_combo": 1,
        "max_combo": 1,
        "icon_key": "local_favorite",
        "chat_symbol": "💍",
        "asset_path": "assets/images/gifts/proposal.png",
        "video_asset_path": "assets/videos/gifts/boy_proposing_girl_d_romantic.mp4",
        "cdn_asset_path": "gifts/proposal/v1/icon.webp",
        "cdn_video_path": "gifts/proposal/v1/animation.mp4",
        "animation_type": "video",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": True,
        "show_gift_flight": False,
        "version": 1,
        "sort_order": 110,
    },
    {
        "id": "butterfly",
        "name": "Butterfly",
        "category": "premium",
        "gift_type": "normal",
        "coin_value": 1299,
        "min_combo": 1,
        "max_combo": 1,
        "icon_key": "local_flutter_dash",
        "chat_symbol": "🦋",
        "asset_path": "assets/images/gifts/butterfly.png",
        "video_asset_path": "assets/videos/gifts/pretty_girl_butterfly_animation.mp4",
        "cdn_asset_path": "gifts/butterfly/v1/icon.webp",
        "cdn_video_path": "gifts/butterfly/v1/animation.mp4",
        "animation_type": "video",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": True,
        "show_gift_flight": False,
        "version": 1,
        "sort_order": 120,
    },
    {
        "id": "premium_magic_1",
        "name": "Magic 1",
        "category": "premium",
        "gift_type": "normal",
        "coin_value": 1499,
        "min_combo": 1,
        "max_combo": 1,
        "icon_key": "local_auto_fix_high",
        "chat_symbol": "🪄",
        "asset_path": "assets/images/gifts/premium_magic_1.png",
        "video_asset_path": "assets/videos/gifts/premium_magic_1.mp4",
        "cdn_asset_path": "gifts/premium_magic_1/v1/icon.webp",
        "cdn_video_path": "gifts/premium_magic_1/v1/animation.mp4",
        "animation_type": "video",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": True,
        "show_gift_flight": False,
        "version": 1,
        "sort_order": 130,
    },
    {
        "id": "premium_magic_2",
        "name": "Magic 2",
        "category": "premium",
        "gift_type": "normal",
        "coin_value": 1599,
        "min_combo": 1,
        "max_combo": 1,
        "icon_key": "local_auto_awesome",
        "chat_symbol": "✨",
        "asset_path": "assets/images/gifts/premium_magic_2.png",
        "video_asset_path": "assets/videos/gifts/premium_magic_2.mp4",
        "cdn_asset_path": "gifts/premium_magic_2/v1/icon.webp",
        "cdn_video_path": "gifts/premium_magic_2/v1/animation.mp4",
        "animation_type": "video",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": True,
        "show_gift_flight": False,
        "version": 1,
        "sort_order": 140,
    },
    {
        "id": "premium_magic_3",
        "name": "Magic 3",
        "category": "premium",
        "gift_type": "normal",
        "coin_value": 1699,
        "min_combo": 1,
        "max_combo": 1,
        "icon_key": "local_workspace_premium",
        "chat_symbol": "👑",
        "asset_path": "assets/images/gifts/premium_magic_3.png",
        "video_asset_path": "assets/videos/gifts/premium_magic_3.mp4",
        "cdn_asset_path": "gifts/premium_magic_3/v1/icon.webp",
        "cdn_video_path": "gifts/premium_magic_3/v1/animation.mp4",
        "animation_type": "video",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": True,
        "show_gift_flight": False,
        "version": 1,
        "sort_order": 150,
    },
    {
        "id": "premium_yacht",
        "name": "Yacht",
        "category": "premium",
        "gift_type": "normal",
        "coin_value": 1299,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_sailing",
        "chat_symbol": "🛥️",
        "asset_path": "assets/images/gifts/premium_yacht.png",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/premium_yacht/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": True,
        "show_gift_flight": False,
        "version": 1,
        "sort_order": 160,
    },
    {
        "id": "premium_castle",
        "name": "Castle",
        "category": "premium",
        "gift_type": "normal",
        "coin_value": 1999,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_castle",
        "chat_symbol": "🏰",
        "asset_path": "assets/images/gifts/premium_castle.png",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/premium_castle/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": True,
        "show_gift_flight": False,
        "version": 1,
        "sort_order": 170,
    },
]

LUCKY_GIFTS = [
    {
        "id": "arcane_crystal_wand",
        "name": "Arcane Crystal Wand",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 99,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_auto_fix_high",
        "chat_symbol": "🪄",
        "asset_path": "assets/gifts/lucky/arcane_crystal_wand.png",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/arcane_crystal_wand/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 210,
        "max_multiplier": 100,
    },
    {
        "id": "celestial_rose",
        "name": "Celestial Rose",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 199,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_favorite_border",
        "chat_symbol": "🌹",
        "asset_path": "assets/gifts/lucky/celestial_rose.png",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/celestial_rose/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 220,
        "max_multiplier": 100,
    },
    {
        "id": "eternal_bond_rings",
        "name": "Eternal Bond Rings",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 299,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_diamond",
        "chat_symbol": "💍",
        "asset_path": "assets/gifts/lucky/eternal_bond_rings.png",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/eternal_bond_rings/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 230,
        "max_multiplier": 500,
    },
    {
        "id": "bubble_elephant",
        "name": "Bubble Elephant",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 99,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_pets",
        "chat_symbol": "🐘",
        "asset_path": "assets/gifts/lucky/bubble_elephant.png",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/bubble_elephant/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 240,
        "max_multiplier": 100,
    },
    {
        "id": "sun_fortune_coin",
        "name": "Sun Fortune Coin",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 499,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_wb_sunny",
        "chat_symbol": "☀️",
        "asset_path": "assets/gifts/lucky/sun_fortune_coin.png",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/sun_fortune_coin/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 250,
        "max_multiplier": 500,
    },
    {
        "id": "moonlit_koi",
        "name": "Moonlit Koi",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 299,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_waves",
        "chat_symbol": "🐟",
        "asset_path": "assets/gifts/lucky/moonlit_koi.png",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/moonlit_koi/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 260,
        "max_multiplier": 500,
    },
    {
        "id": "spellbound_tome",
        "name": "Spellbound Tome",
        "category": "lucky",
        "gift_type": "lucky",
        "coin_value": 999,
        "min_combo": 1,
        "max_combo": 999,
        "icon_key": "local_auto_stories",
        "chat_symbol": "📖",
        "asset_path": "assets/gifts/lucky/spellbound_tome.png",
        "video_asset_path": None,
        "cdn_asset_path": "gifts/spellbound_tome/v1/icon.webp",
        "cdn_video_path": None,
        "animation_type": "image",
        "is_enabled": True,
        "show_gift_slide": True,
        "show_premium_broadcast": False,
        "show_gift_flight": True,
        "version": 1,
        "sort_order": 270,
        "max_multiplier": 1000,
    },
]

MULTIPLIER_TABLE = [
    {"multiplier": 1, "weight": 810000, "label": "safe"},
    {"multiplier": 2, "weight": 112000, "label": "small_win"},
    {"multiplier": 5, "weight": 44000, "label": "nice_win"},
    {"multiplier": 10, "weight": 20000, "label": "big_win"},
    {"multiplier": 50, "weight": 8500, "label": "rare_win"},
    {"multiplier": 100, "weight": 4200, "label": "super_win"},
    {"multiplier": 500, "weight": 1100, "label": "mega_win"},
    {"multiplier": 1000, "weight": 200, "label": "legend_win"},
]


def _cdn_url(relative_path: str | None) -> str | None:
    if not relative_path:
        return None
    if relative_path.startswith("http://") or relative_path.startswith("https://"):
        return relative_path
    base = settings.GIFT_CDN_BASE_URL.strip().rstrip("/")
    if not base:
        return None
    clean_path = relative_path.lstrip("/")
    if "oraclecloud.com" in base:
        return f"{base}/{quote(clean_path, safe='')}"
    return f"{base}/{clean_path}"


def _with_dynamic_urls(gift: dict) -> dict:
    item = deepcopy(gift)
    item["asset_url"] = _cdn_url(item.get("cdn_asset_path"))
    item["video_url"] = _cdn_url(item.get("cdn_video_path"))
    item["cdn_enabled"] = bool(settings.GIFT_CDN_BASE_URL.strip())
    item["catalog_version"] = GIFT_CATALOG_VERSION
    item["min_combo"] = max(1, int(item.get("min_combo") or 1))
    item["max_combo"] = max(item["min_combo"], int(item.get("max_combo") or 999))
    return item


def _all_static_gifts() -> list[dict]:
    return sorted([*NORMAL_GIFTS, *LUCKY_GIFTS], key=lambda item: item["sort_order"])


def _static_categories_from_gifts(gifts: list[dict]) -> list[dict]:
    keys = sorted(
        {str(gift.get("category") or "classic").strip().lower() for gift in gifts},
        key=lambda item: (CATEGORY_ORDER.get(item, 500), item),
    )
    return [
        {
            "key": key,
            "label": CATEGORY_LABELS.get(key, key.replace("_", " ").title()),
            "is_enabled": True,
            "sort_order": CATEGORY_ORDER.get(key, 500),
            "source": "static_bootstrap",
        }
        for key in keys
        if key
    ]


def _category_to_payload(category: GiftCatalogCategory) -> dict:
    return {
        "key": category.category_key,
        "label": category.label,
        "is_enabled": category.is_enabled,
        "sort_order": category.sort_order,
        "source": category.source,
    }


def _item_to_gift_dict(item: GiftCatalogItem) -> dict:
    gift = {
        "id": item.gift_id,
        "name": item.name,
        "category": item.category_key,
        "gift_type": item.gift_type,
        "coin_value": item.coin_value,
        "min_combo": item.min_combo,
        "max_combo": item.max_combo,
        "icon_key": item.icon_key,
        "chat_symbol": item.chat_symbol,
        "asset_path": item.asset_path,
        "video_asset_path": item.video_asset_path,
        "cdn_asset_path": item.cdn_asset_path,
        "cdn_video_path": item.cdn_video_path,
        "animation_type": item.animation_type,
        "is_enabled": item.is_enabled,
        "show_gift_slide": item.show_gift_slide,
        "show_premium_broadcast": item.show_premium_broadcast,
        "show_gift_flight": item.show_gift_flight,
        "version": item.version,
        "sort_order": item.sort_order,
    }
    if item.max_multiplier is not None:
        gift["max_multiplier"] = item.max_multiplier
    if item.metadata_json:
        gift["metadata"] = item.metadata_json
    return gift


def _db_seeded(db: Session | None) -> bool:
    if db is None:
        return False
    return db.query(GiftCatalogItem).count() > 0


def seed_default_catalog(db: Session) -> dict:
    seeded_categories = 0
    seeded_items = 0
    for payload in _static_categories_from_gifts(_all_static_gifts()):
        category = db.query(GiftCatalogCategory).filter(
            GiftCatalogCategory.category_key == payload["key"]
        ).first()
        if category is None:
            db.add(GiftCatalogCategory(
                category_key=payload["key"],
                label=payload["label"],
                is_enabled=True,
                sort_order=payload["sort_order"],
                source="admin_db",
            ))
            seeded_categories += 1

    for gift in _all_static_gifts():
        item = db.query(GiftCatalogItem).filter(
            GiftCatalogItem.gift_id == gift["id"]
        ).first()
        if item is None:
            db.add(GiftCatalogItem(
                gift_id=gift["id"],
                name=gift["name"],
                category_key=gift["category"],
                gift_type=gift["gift_type"],
                coin_value=int(gift["coin_value"]),
                min_combo=int(gift.get("min_combo") or 1),
                max_combo=int(gift.get("max_combo") or 999),
                icon_key=gift.get("icon_key"),
                chat_symbol=gift.get("chat_symbol"),
                asset_path=gift.get("asset_path"),
                video_asset_path=gift.get("video_asset_path"),
                cdn_asset_path=gift.get("cdn_asset_path"),
                cdn_video_path=gift.get("cdn_video_path"),
                animation_type=gift.get("animation_type") or "image",
                is_enabled=bool(gift.get("is_enabled", True)),
                show_gift_slide=bool(gift.get("show_gift_slide", True)),
                show_premium_broadcast=bool(gift.get("show_premium_broadcast", False)),
                show_gift_flight=bool(gift.get("show_gift_flight", True)),
                version=int(gift.get("version") or 1),
                sort_order=int(gift.get("sort_order") or 500),
                max_multiplier=gift.get("max_multiplier"),
            ))
            seeded_items += 1
    db.commit()
    return {
        "seeded_categories": seeded_categories,
        "seeded_items": seeded_items,
        "catalog_version": GIFT_CATALOG_VERSION,
    }


def admin_catalog_snapshot(db: Session) -> dict:
    if not _db_seeded(db):
        seed_default_catalog(db)
    categories = db.query(GiftCatalogCategory).order_by(
        GiftCatalogCategory.sort_order.asc(), GiftCatalogCategory.category_key.asc()
    ).all()
    items = db.query(GiftCatalogItem).order_by(
        GiftCatalogItem.sort_order.asc(), GiftCatalogItem.gift_id.asc()
    ).all()
    gifts = [_with_dynamic_urls(_item_to_gift_dict(item)) for item in items]
    return {
        "catalog_version": GIFT_CATALOG_VERSION,
        "cdn_base_url": settings.GIFT_CDN_BASE_URL.strip(),
        "categories": [_category_to_payload(category) for category in categories],
        "items": gifts,
        "normal": [gift for gift in gifts if gift.get("gift_type") == "normal"],
        "lucky": [gift for gift in gifts if gift.get("gift_type") == "lucky"],
        "all": gifts,
        "source": "admin_db",
    }


def list_gifts(db: Session | None = None) -> dict:
    if _db_seeded(db):
        categories = db.query(GiftCatalogCategory).filter(
            GiftCatalogCategory.is_enabled == True
        ).order_by(GiftCatalogCategory.sort_order.asc(), GiftCatalogCategory.category_key.asc()).all()
        enabled_category_keys = {category.category_key for category in categories}
        items = db.query(GiftCatalogItem).filter(
            GiftCatalogItem.is_enabled == True,
            GiftCatalogItem.category_key.in_(enabled_category_keys),
        ).order_by(GiftCatalogItem.sort_order.asc(), GiftCatalogItem.gift_id.asc()).all()
        all_gifts = [_with_dynamic_urls(_item_to_gift_dict(item)) for item in items]
        return {
            "catalog_version": GIFT_CATALOG_VERSION,
            "cdn_base_url": settings.GIFT_CDN_BASE_URL.strip(),
            "categories": [_category_to_payload(category) for category in categories],
            "normal": [gift for gift in all_gifts if gift.get("gift_type") == "normal"],
            "lucky": [gift for gift in all_gifts if gift.get("gift_type") == "lucky"],
            "all": all_gifts,
            "source": "admin_db",
            "rule": "Gift catalog DB is source of truth. Flutter renders categories and gifts from this payload.",
        }

    all_gifts = [_with_dynamic_urls(gift) for gift in _all_static_gifts() if gift.get("is_enabled")]
    return {
        "catalog_version": GIFT_CATALOG_VERSION,
        "cdn_base_url": settings.GIFT_CDN_BASE_URL.strip(),
        "categories": _static_categories_from_gifts(all_gifts),
        "normal": [gift for gift in all_gifts if gift.get("gift_type") == "normal"],
        "lucky": [gift for gift in all_gifts if gift.get("gift_type") == "lucky"],
        "all": all_gifts,
        "source": "static_bootstrap_until_seeded",
        "rule": "Seed the admin DB catalog to make DB the source of truth.",
    }


def find_gift(gift_id: str, db: Session | None = None) -> dict | None:
    if _db_seeded(db):
        item = db.query(GiftCatalogItem).filter(
            GiftCatalogItem.gift_id == gift_id,
            GiftCatalogItem.is_enabled == True,
        ).first()
        if item is None:
            return None
        category = db.query(GiftCatalogCategory).filter(
            GiftCatalogCategory.category_key == item.category_key,
            GiftCatalogCategory.is_enabled == True,
        ).first()
        if category is None:
            return None
        return _with_dynamic_urls(_item_to_gift_dict(item))

    gift = next((gift for gift in _all_static_gifts() if gift["id"] == gift_id), None)
    return _with_dynamic_urls(gift) if gift is not None and gift.get("is_enabled") else None


def validate_gift_combo(gift: dict, quantity: int) -> None:
    min_combo = max(1, int(gift.get("min_combo") or 1))
    max_combo = max(min_combo, int(gift.get("max_combo") or 999))
    if quantity < min_combo or quantity > max_combo:
        raise ValueError(f"Gift combo must be between {min_combo} and {max_combo}")


def roll_lucky_multiplier(gift_id: str, total_coin_value: int, house_risk_score: int = 0, db: Session | None = None) -> dict:
    gift = find_gift(gift_id, db=db)
    if gift is None or gift.get("gift_type") != "lucky":
        raise ValueError("Lucky gift not found")

    max_multiplier = int(gift.get("max_multiplier") or 1)
    risk_penalty = max(min(house_risk_score, 90), 0) / 100
    filtered = []
    for item in MULTIPLIER_TABLE:
        multiplier = int(item["multiplier"])
        if multiplier > max_multiplier:
            continue
        weight = int(item["weight"])
        if multiplier >= 100:
            weight = max(1, int(weight * (1 - risk_penalty)))
        filtered.append({**item, "weight": weight})

    total_weight = sum(int(item["weight"]) for item in filtered)
    pick = random() * total_weight
    cursor = 0.0
    selected = filtered[0]
    for item in filtered:
        cursor += int(item["weight"])
        if pick <= cursor:
            selected = item
            break

    multiplier = int(selected["multiplier"])
    reward = total_coin_value * multiplier
    return {
        "gift_id": gift_id,
        "gift_name": gift["name"],
        "base_coin_value": int(gift["coin_value"]),
        "total_coin_value": total_coin_value,
        "multiplier": multiplier,
        "reward_coin_amount": reward,
        "risk_label": selected["label"],
        "is_global_broadcast_worthy": multiplier >= 500,
        "logic": "Backend-authoritative weighted multiplier roll. 100x/500x are boosted for testing and can be reduced by house risk score.",
    }
