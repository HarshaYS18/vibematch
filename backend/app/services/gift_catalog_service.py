from copy import deepcopy
from random import random
from urllib.parse import quote

from app.core.config import settings

GIFT_CATALOG_VERSION = 1

NORMAL_GIFTS = [
    {
        "id": "rose_bloom",
        "name": "Rose Bloom",
        "category": "classic",
        "gift_type": "normal",
        "coin_value": 9,
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
    return item


def _all_gifts() -> list[dict]:
    return sorted([*NORMAL_GIFTS, *LUCKY_GIFTS], key=lambda item: item["sort_order"])


def list_gifts() -> dict:
    all_gifts = [_with_dynamic_urls(gift) for gift in _all_gifts() if gift.get("is_enabled")]
    normal = [gift for gift in all_gifts if gift.get("gift_type") == "normal"]
    lucky = [gift for gift in all_gifts if gift.get("gift_type") == "lucky"]
    return {
        "catalog_version": GIFT_CATALOG_VERSION,
        "cdn_base_url": settings.GIFT_CDN_BASE_URL.strip(),
        "normal": normal,
        "lucky": lucky,
        "all": all_gifts,
    }


def find_gift(gift_id: str) -> dict | None:
    gift = next((gift for gift in _all_gifts() if gift["id"] == gift_id), None)
    return _with_dynamic_urls(gift) if gift is not None else None


def roll_lucky_multiplier(gift_id: str, total_coin_value: int, house_risk_score: int = 0) -> dict:
    gift = find_gift(gift_id)
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
